import { Hono } from "hono";
import { z } from "zod";
import { db } from "../db.js";
import { notify, people } from "../people.js";
import { allow } from "../ratelimit.js";
import { SCOPES, adherenceSummary, type Scope } from "../sharing.js";

export const shares = new Hono<{ Variables: { userId: string; email: string } }>();

const scopeList = z.array(z.enum(SCOPES)).min(1).max(SCOPES.length);
const create = z.object({
  connectionId: z.string().uuid(),
  direction: z.enum(["offer", "request"]), // offer: I share mine. request: I ask to see theirs.
  scopes: scopeList,
});
const respond = z.object({ accept: z.boolean(), scopes: scopeList.optional() });
const patch = z.object({ scopes: scopeList });

type Share = {
  id: string; owner_id: string; viewer_id: string; scopes: Scope[]; initiated_by: string; status: string;
};

const SELECT = "id,owner_id,viewer_id,scopes,initiated_by,status";
const audit = (shareId: string, actor: string, event: string, detail?: object) =>
  db.from("share_audit").insert({ share_id: shareId, actor_id: actor, event, detail: detail ?? null });
const label = (scopes: Scope[]) => scopes.join(", ");

// What I share with others, and what others share with me.
shares.get("/", async (c) => {
  const me = c.get("userId");
  const { data, error } = await db
    .from("data_shares")
    .select(SELECT)
    .or(`owner_id.eq.${me},viewer_id.eq.${me}`)
    .neq("status", "revoked");
  if (error) throw error;
  const rows = (data ?? []) as Share[];
  const names = await people(rows.map((r) => (r.owner_id === me ? r.viewer_id : r.owner_id)));
  const view = (r: Share, otherId: string) => ({
    id: r.id,
    status: r.status,
    scopes: r.scopes,
    initiatedByMe: r.initiated_by === me,
    other: names.get(otherId) ?? { id: otherId, name: "Medhavn user", email: "" },
  });
  return c.json({
    owned: rows.filter((r) => r.owner_id === me).map((r) => view(r, r.viewer_id)),
    viewing: rows.filter((r) => r.viewer_id === me).map((r) => view(r, r.owner_id)),
  });
});

// Propose sharing. The other person must accept; the data owner always decides.
shares.post("/", async (c) => {
  const body = create.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const me = c.get("userId");
  if (!allow(`share:${me}`, 30, 60 * 60_000)) return c.json({ error: "Too many requests" }, 429);

  const { data: conn, error: cErr } = await db
    .from("connections")
    .select("id,user_id,linked_user_id")
    .eq("id", body.data.connectionId)
    .eq("status", "accepted")
    .or(`user_id.eq.${me},linked_user_id.eq.${me}`)
    .maybeSingle();
  if (cErr) throw cErr;
  if (!conn) return c.json({ error: "Connect first" }, 400);

  const other = conn.user_id === me ? conn.linked_user_id : conn.user_id;
  const [owner, viewer] = body.data.direction === "offer" ? [me, other] : [other, me];
  const scopes = [...new Set(body.data.scopes)];

  const { data: existing, error: eErr } = await db
    .from("data_shares")
    .select(SELECT)
    .eq("owner_id", owner)
    .eq("viewer_id", viewer)
    .maybeSingle();
  if (eErr) throw eErr;
  if (existing && (existing.status === "pending" || existing.status === "active")) {
    return c.json({ error: "already_exists", status: existing.status }, 409);
  }

  // A declined or revoked share can be proposed again; it goes back to pending.
  const fields = { scopes, initiated_by: me, status: "pending", responded_at: null, revoked_at: null };
  const result = existing
    ? await db.from("data_shares").update(fields).eq("id", existing.id).select("id").single()
    : await db.from("data_shares").insert({ owner_id: owner, viewer_id: viewer, ...fields }).select("id").single();
  if (result.error) throw result.error;
  await audit(result.data.id, me, existing ? "re-proposed" : "proposed", { scopes, direction: body.data.direction });

  const myName = (await people([me])).get(me)?.name ?? "Someone";
  await notify(
    other,
    body.data.direction === "offer" ? `${myName} wants to share their health info with you` : `${myName} asked to see your health info`,
    [`Shared: ${label(scopes)}.`, "Nothing is shared until you accept."],
  );
  return c.json({ ok: true, id: result.data.id });
});

// Accept or decline. The sender is told. A declined share can be accepted later by the same person.
// When the owner accepts a request they may narrow the scopes.
shares.post("/:id/respond", async (c) => {
  const body = respond.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const me = c.get("userId");

  const { data: share, error } = await db
    .from("data_shares")
    .select(SELECT)
    .eq("id", c.req.param("id"))
    .in("status", ["pending", "declined"])
    .or(`owner_id.eq.${me},viewer_id.eq.${me}`)
    .maybeSingle();
  if (error) throw error;
  const s = share as Share | null;
  if (!s || s.initiated_by === me) return c.json({ error: "Not found" }, 404);

  let scopes = s.scopes;
  if (body.data.accept && me === s.owner_id && body.data.scopes) {
    if (!body.data.scopes.every((x) => s.scopes.includes(x))) return c.json({ error: "Cannot widen the request" }, 400);
    scopes = body.data.scopes;
  }
  const status = body.data.accept ? "active" : "declined";
  const { error: uErr } = await db
    .from("data_shares")
    .update({ status, scopes, responded_at: new Date().toISOString() })
    .eq("id", s.id);
  if (uErr) throw uErr;
  await audit(s.id, me, body.data.accept ? "accepted" : "declined", { scopes });

  const myName = (await people([me])).get(me)?.name ?? "Someone";
  await notify(
    s.initiated_by,
    body.data.accept ? `${myName} accepted your sharing request` : `${myName} declined your sharing request`,
    body.data.accept
      ? [`Shared: ${label(scopes)}.`]
      : [`${myName} declined. If that was a mistake, you can send the request again.`],
  );
  return c.json({ ok: true, status });
});

// The owner changes what is shared.
shares.patch("/:id", async (c) => {
  const body = patch.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const me = c.get("userId");
  const scopes = [...new Set(body.data.scopes)];
  const { data, error } = await db
    .from("data_shares")
    .update({ scopes })
    .eq("id", c.req.param("id"))
    .eq("owner_id", me)
    .eq("status", "active")
    .select("id,viewer_id")
    .maybeSingle();
  if (error) throw error;
  if (!data) return c.json({ error: "Not found" }, 404);
  await audit(data.id, me, "scopes_changed", { scopes });
  return c.json({ ok: true });
});

// Either side can stop sharing at any time. Takes effect immediately.
shares.delete("/:id", async (c) => {
  const me = c.get("userId");
  const { data, error } = await db
    .from("data_shares")
    .update({ status: "revoked", revoked_at: new Date().toISOString() })
    .eq("id", c.req.param("id"))
    .or(`owner_id.eq.${me},viewer_id.eq.${me}`)
    .in("status", ["pending", "active"])
    .select("id,owner_id,viewer_id")
    .maybeSingle();
  if (error) throw error;
  if (!data) return c.json({ error: "Not found" }, 404);
  await audit(data.id, me, "revoked");
  const myName = (await people([me])).get(me)?.name ?? "Someone";
  await notify(
    data.owner_id === me ? data.viewer_id : data.owner_id,
    `${myName} stopped sharing`,
    [data.owner_id === me ? `${myName} no longer shares their health info with you.` : `${myName} no longer wants to see your health info.`],
  );
  return c.json({ ok: true });
});

/** The only gate for reading someone else's data: an ACTIVE share, me as viewer, with a needed scope. */
async function viewerShare(id: string, me: string, needed: Scope[]): Promise<Share | null> {
  const { data, error } = await db
    .from("data_shares")
    .select(SELECT)
    .eq("id", id)
    .eq("viewer_id", me)
    .eq("status", "active")
    .maybeSingle();
  if (error) throw error;
  const s = data as Share | null;
  return s && needed.some((n) => s.scopes.includes(n)) ? s : null;
}

shares.get("/:id/adherence", async (c) => {
  const days = Math.min(Math.max(Number(c.req.query("days") ?? 7) || 7, 1), 30);
  const s = await viewerShare(c.req.param("id"), c.get("userId"), ["adherence", "medications"]);
  if (!s) return c.json({ error: "Not found" }, 404);
  const since = new Date(Date.now() - days * 86_400_000).toISOString().slice(0, 10);
  const { data, error } = await db
    .from("pill_dose_statuses")
    .select("key,status")
    .eq("user_id", s.owner_id)
    .gte("updated_at", new Date(Date.now() - (days + 1) * 86_400_000).toISOString())
    .limit(5000);
  if (error) throw error;
  return c.json({ periodDays: days, ...adherenceSummary(data ?? [], since) });
});

shares.get("/:id/medications", async (c) => {
  const s = await viewerShare(c.req.param("id"), c.get("userId"), ["medications"]);
  if (!s) return c.json({ error: "Not found" }, 404);
  const { data, error } = await db
    .from("med_cabinet_items")
    .select("id,name,dosage_text,schedule_blocks,frequency,remaining_pills")
    .eq("user_id", s.owner_id)
    .order("name");
  if (error) throw error;
  return c.json({ medications: data ?? [] });
});
