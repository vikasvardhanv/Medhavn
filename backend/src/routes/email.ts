import { Hono } from "hono";
import { z } from "zod";
import { sendMail } from "../mailer.js";
import { referralEmail, safeCircleInviteEmail } from "../templates.js";

// Purpose-specific senders. Clients pick a template and give a recipient; they never supply HTML or From.
export const email = new Hono<{ Variables: { userId: string } }>();

const invite = z.object({
  name: z.string().trim().min(1).max(80),
  email: z.string().trim().email().max(254),
});
const referral = z.object({
  email: z.string().trim().email().max(254),
  code: z.string().regex(/^[A-Za-z0-9-]{4,24}$/).optional(),
});

async function send(to: string, mail: { subject: string; html: string }) {
  try {
    await sendMail(to, mail);
    return { ok: true } as const;
  } catch (err) {
    console.error("email failed", err instanceof Error ? err.message : err);
    return { ok: false } as const;
  }
}

email.post("/safecircle-invite", async (c) => {
  const body = invite.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const res = await send(body.data.email, safeCircleInviteEmail(body.data.name));
  return res.ok ? c.json({ ok: true }) : c.json({ error: "Could not send email" }, 502);
});

email.post("/referral", async (c) => {
  const body = referral.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const res = await send(body.data.email, referralEmail(body.data.code));
  return res.ok ? c.json({ ok: true }) : c.json({ error: "Could not send email" }, 502);
});
