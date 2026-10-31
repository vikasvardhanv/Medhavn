import { Hono } from "hono";
import { z } from "zod";
import { config } from "../config.js";
import { db } from "../db.js";
import { sendMail } from "../mailer.js";
import { allow } from "../ratelimit.js";
import { generateCode, isFamily, normalizeEmail, RELATIONSHIPS, type Relationship } from "../referral.js";
import { referralEmail } from "../templates.js";

export const referrals = new Hono<{ Variables: { userId: string; email: string } }>();

const invite = z.object({
  email: z.string().trim().email().max(254),
  relationship: z.enum(RELATIONSHIPS).default("friend"),
});
const claim = z.object({ code: z.string().trim().toUpperCase().optional() });

/** The user's own referral code, created on first use. */
async function ensureProfile(userId: string): Promise<{ code: string; name: string }> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const { data, error } = await db
      .from("user_profiles")
      .select("referral_code,full_name")
      .eq("auth_id", userId)
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new Error("profile row missing for user");
    if (data.referral_code) return { code: data.referral_code, name: data.full_name || "A friend" };

    const { error: uErr } = await db
      .from("user_profiles")
      .update({ referral_code: generateCode() })
      .eq("auth_id", userId)
      .is("referral_code", null);
    // 23505 = the random code collided with another user's; loop and draw again.
    if (uErr && uErr.code !== "23505") throw uErr;
  }
  throw new Error("could not allocate a referral code");
}

// Progress, the user's code, and who they invited.
referrals.get("/", async (c) => {
  const userId = c.get("userId");
  const { code } = await ensureProfile(userId);
  const { data, error } = await db
    .from("referrals")
    .select("referee_email,relationship,status,invited_at,signed_up_at")
    .eq("referrer_id", userId)
    .order("invited_at", { ascending: false });
  if (error) throw error;
  const list = data ?? [];
  return c.json({
    code,
    appStoreUrl: config.appStoreUrl,
    signedUpCount: list.filter((r) => r.status === "signed_up").length,
    referrals: list,
  });
});

// Invite someone by email. Stores the referral first, so a tap is tracked even if the mail is slow.
referrals.post("/", async (c) => {
  const body = invite.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const userId = c.get("userId");
  if (!allow(`referral:${userId}`, 20, 60 * 60_000)) return c.json({ error: "Too many requests" }, 429);

  const email = normalizeEmail(body.data.email);
  const relationship: Relationship = body.data.relationship;
  if (email === c.get("email")) return c.json({ error: "You cannot invite yourself" }, 400);

  const { data: existing, error: eErr } = await db
    .from("referrals")
    .select("id,status")
    .eq("referrer_id", userId)
    .eq("referee_email", email)
    .maybeSingle();
  if (eErr) throw eErr;
  if (existing?.status === "signed_up") return c.json({ error: "Already on Medhavn" }, 409);

  const { code, name } = await ensureProfile(userId);
  const write = existing
    ? await db.from("referrals").update({ relationship }).eq("id", existing.id)
    : await db.from("referrals").insert({ referrer_id: userId, referee_email: email, relationship });
  if (write.error) throw write.error;

  try {
    await sendMail(
      email,
      referralEmail({ inviterName: name, code, appStoreUrl: config.appStoreUrl, family: isFamily(relationship) }),
    );
  } catch (err) {
    console.error("referral email failed", err instanceof Error ? err.message : err);
    // Do not count an invite that never went out.
    if (!existing) await db.from("referrals").delete().eq("referrer_id", userId).eq("referee_email", email);
    return c.json({ error: "Could not send email" }, 502);
  }
  return c.json({ ok: true, code });
});

// Called by a new user after signing up. Matches an emailed invite by address, or a typed code.
// Safe to call on every login: it does nothing once the user is linked.
referrals.post("/claim", async (c) => {
  const body = claim.safeParse(await c.req.json().catch(() => ({})));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const userId = c.get("userId");
  const email = c.get("email");
  if (!email) return c.json({ error: "Token has no email" }, 400);
  // A mistyped code must not block the match-by-email path below, so it is ignored rather than rejected.
  const code = body.data.code && /^[A-Z0-9]{8}$/.test(body.data.code) ? body.data.code : undefined;

  const { data: done, error: dErr } = await db.from("referrals").select("id").eq("referee_id", userId).maybeSingle();
  if (dErr) throw dErr;
  if (done) return c.json({ claimed: false, reason: "already_linked" });

  // 1) An invite sent to this address, oldest first.
  let { data: row, error: rErr } = await db
    .from("referrals")
    .select("id,referrer_id,relationship")
    .eq("referee_email", email)
    .eq("status", "invited")
    .order("invited_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (rErr) throw rErr;

  // 2) Otherwise a referral code typed at sign-up.
  if (!row && code) {
    const { data: owner, error: oErr } = await db
      .from("user_profiles")
      .select("auth_id")
      .eq("referral_code", code)
      .maybeSingle();
    if (oErr) throw oErr;
    if (owner?.auth_id && owner.auth_id !== userId) {
      const ins = await db
        .from("referrals")
        .upsert({ referrer_id: owner.auth_id, referee_email: email, relationship: "friend" }, { onConflict: "referrer_id,referee_email" })
        .select("id,referrer_id,relationship")
        .single();
      if (ins.error) throw ins.error;
      row = ins.data;
    }
  }
  if (!row || row.referrer_id === userId) return c.json({ claimed: false, reason: "no_referral" });

  const { error: uErr } = await db
    .from("referrals")
    .update({ status: "signed_up", referee_id: userId, signed_up_at: new Date().toISOString() })
    .eq("id", row.id);
  // 23505: a concurrent call already linked this user.
  if (uErr) return uErr.code === "23505" ? c.json({ claimed: false, reason: "already_linked" }) : Promise.reject(uErr);

  if (isFamily(row.relationship as Relationship)) {
    const { error: fErr } = await db
      .from("family_links")
      .upsert(
        { user_id: row.referrer_id, linked_user_id: userId, relationship: row.relationship, status: "pending" },
        { onConflict: "user_id,linked_user_id", ignoreDuplicates: true },
      );
    if (fErr) throw fErr;
  }
  return c.json({ claimed: true, relationship: row.relationship });
});
