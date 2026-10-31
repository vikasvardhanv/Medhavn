import { Hono } from "hono";
import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { config } from "../config.js";
import { db } from "../db.js";
import { sendMail } from "../mailer.js";
import { allow, clientIp } from "../ratelimit.js";
import { otpEmail } from "../templates.js";

// Signup email verification. Unauthenticated by nature (the account does not exist yet),
// so it is rate limited per IP and per address. The code is generated and checked here,
// never on the device.
const TTL_MS = 10 * 60_000;
const MAX_ATTEMPTS = 5;

const emailBody = z.object({ email: z.string().trim().toLowerCase().email().max(254) });
const verifyBody = emailBody.extend({ code: z.string().regex(/^\d{6}$/) });

const hash = (email: string, code: string) =>
  createHmac("sha256", config.jwtSecret).update(`${email}:${code}`).digest("hex");

export const otp = new Hono();

otp.post("/send", async (c) => {
  const body = emailBody.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid email" }, 400);
  const { email } = body.data;

  const ip = clientIp(c.req.header("x-forwarded-for"));
  if (!allow(`otp-ip:${ip}`, 10, 60 * 60_000) || !allow(`otp-email:${email}`, 3, TTL_MS)) {
    return c.json({ error: "Too many requests" }, 429);
  }

  const code = String(randomInt(100000, 1000000));
  const { error } = await db.from("email_otps").upsert({
    email,
    code_hash: hash(email, code),
    attempts: 0,
    expires_at: new Date(Date.now() + TTL_MS).toISOString(),
    created_at: new Date().toISOString(),
  });
  if (error) throw error;

  try {
    await sendMail(email, otpEmail(code));
  } catch (err) {
    console.error("otp email failed", err instanceof Error ? err.message : err);
    return c.json({ error: "Could not send email" }, 502);
  }
  return c.json({ ok: true });
});

otp.post("/verify", async (c) => {
  const body = verifyBody.safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: "Invalid request" }, 400);
  const { email, code } = body.data;

  const ip = clientIp(c.req.header("x-forwarded-for"));
  if (!allow(`otp-verify-ip:${ip}`, 30, 60 * 60_000)) return c.json({ error: "Too many requests" }, 429);

  const { data: row, error } = await db.from("email_otps").select("*").eq("email", email).maybeSingle();
  if (error) throw error;
  if (!row || new Date(row.expires_at).getTime() < Date.now()) {
    return c.json({ verified: false, error: "Code expired" }, 400);
  }
  if (row.attempts >= MAX_ATTEMPTS) return c.json({ verified: false, error: "Too many attempts" }, 429);

  const a = Buffer.from(hash(email, code));
  const b = Buffer.from(row.code_hash);
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    await db.from("email_otps").update({ attempts: row.attempts + 1 }).eq("email", email);
    return c.json({ verified: false, error: "Incorrect code" }, 400);
  }

  await db.from("email_otps").delete().eq("email", email);
  return c.json({ verified: true });
});
