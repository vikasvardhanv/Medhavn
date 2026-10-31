import { Hono } from "hono";
import { z } from "zod";
import { db } from "../db.js";
import { notify, people } from "../people.js";
import { allow } from "../ratelimit.js";
import { RELATIONSHIPS, normalizeEmail, type Relationship } from "../referral.js";
import { perspective } from "../sharing.js";

export const connections = new Hono<{ Variables: { userId: string; email: string } }>();

const create = z.object({
  email: z.string().trim().email().max(254),
  relationship: z.enum(RELATIONSHIPS).default("friend"),
});
const respond = z.object({ accept: z.boolean() });

type Row = { id: string; user_id: string; linked_user_id: string; relationship: Relationship; status: string; created_at: string };

// Everyone I am connected to, including declined ones so a mistaken decline can be undone.
connections.get("/", async (c) => {
  const me = c.get("userId");
  const { data, error } = await db
    .from("connections")
    .select("id,user_id,linked_user_id,relationship,status,created_at")
    .or(`user_id.eq.${me},linked_user_id.eq.${me}`)
    .order("created_at", { ascending: false });
  if (error) throw error;
  const rows = (data ?? []) as Row[];
  const names = await people(rows.map((r) => (r.user_id === me ? r.linked_user_id : r.user_id)));
  return c.json({
    connections: rows.map((r) => {
      const outgoing = r.user_id === me;
      const otherId = outgoing ? r.linked_user_id : r.user_id;
      return {
        id: r.id,
        status: r.status,
        direction: outgoing ? "outgoing" : "incoming",
        relationship: perspective(r.relationship, outgoing), // what the other person is to me
        other: names.get(otherId) ?? { id: otherId, name: "Medhavn user", email: "" },
        createdAt: r.created_at,
      };
    }),
  });
});

// Ask an existing Medhavn user to connect. Someone not on Medhavn yet is invited via /v1/referrals instead.
connections.post("/", async (c) => {
  const body = create.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const me = c.get("userId");
  if (!allow(`connect:${me}`, 20, 60 * 60_000)) return c.json({ error: "Too many requests" }, 429);

  const email = normalizeEmail(body.data.email);
  if (email === c.get("email")) return c.json({ error: "You cannot connect with yourself" }, 400);

  const { data: target, error: tErr } = await db.from("user_profiles").select("auth_id").eq("email", email).maybeSingle();
  if (tErr) throw tErr;
  if (!target?.auth_id) return c.json({ error: "not_a_user" }, 404);
  const other = target.auth_id as string;

  const { data: existing, error: eErr } = await db
    .from("connections")
    .select("id,user_id,status")
    .or(`and(user_id.eq.${me},linked_user_id.eq.${other}),and(user_id.eq.${other},linked_user_id.eq.${me})`)
    .maybeSingle();
  if (eErr) throw eErr;

  const myName = (await people([me])).get(me)?.name ?? "Someone";
  if (existing) {
    // The sender may try again after a decline. Anything else is already in progress.
    if (existing.status === "declined" && existing.user_id === me) {
      const { error } = await db
        .from("connections")
        .update({ status: "pending", relationship: body.data.relationship, responded_at: null })
        .eq("id", existing.id);
      if (error) throw error;
      await notify(other, `${myName} asked to connect on Medhavn`, [`${myName} sent you a connection request.`]);
      return c.json({ ok: true, id: existing.id, retried: true });
    }
    return c.json({ error: "already_connected", status: existing.status }, 409);
  }

  const { data: row, error } = await db
    .from("connections")
    .insert({ user_id: me, linked_user_id: other, relationship: body.data.relationship, status: "pending" })
    .select("id")
    .single();
  if (error) throw error;
  await notify(other, `${myName} asked to connect on Medhavn`, [`${myName} sent you a connection request.`]);
  return c.json({ ok: true, id: row.id });
});

// Accept or decline. A decline can be reversed later by the same person, and the sender is told either way.
connections.post("/:id/respond", async (c) => {
  const body = respond.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const me = c.get("userId");

  const { data: row, error } = await db
    .from("connections")
    .select("id,user_id,status")
    .eq("id", c.req.param("id"))
    .eq("linked_user_id", me)
    .in("status", ["pending", "declined"])
    .maybeSingle();
  if (error) throw error;
  if (!row) return c.json({ error: "Not found" }, 404);

  const status = body.data.accept ? "accepted" : "declined";
  const { error: uErr } = await db
    .from("connections")
    .update({ status, responded_at: new Date().toISOString() })
    .eq("id", row.id);
  if (uErr) throw uErr;

  const myName = (await people([me])).get(me)?.name ?? "Someone";
  await notify(
    row.user_id,
    body.data.accept ? `${myName} accepted your connection` : `${myName} declined your connection request`,
    body.data.accept
      ? [`You and ${myName} are now connected on Medhavn.`]
      : [`${myName} declined your connection request. If that was a mistake, you can send the request again.`],
  );
  return c.json({ ok: true, status });
});

// Either person can remove the connection. Any sharing between them stops at the same time.
connections.delete("/:id", async (c) => {
  const me = c.get("userId");
  const { data: row, error } = await db
    .from("connections")
    .select("id,user_id,linked_user_id")
    .eq("id", c.req.param("id"))
    .or(`user_id.eq.${me},linked_user_id.eq.${me}`)
    .maybeSingle();
  if (error) throw error;
  if (!row) return c.json({ error: "Not found" }, 404);

  const { error: sErr } = await db
    .from("data_shares")
    .update({ status: "revoked", revoked_at: new Date().toISOString() })
    .or(
      `and(owner_id.eq.${row.user_id},viewer_id.eq.${row.linked_user_id}),and(owner_id.eq.${row.linked_user_id},viewer_id.eq.${row.user_id})`,
    )
    .in("status", ["pending", "active"]);
  if (sErr) throw sErr;
  const { error: dErr } = await db.from("connections").delete().eq("id", row.id);
  if (dErr) throw dErr;
  return c.json({ ok: true });
});
