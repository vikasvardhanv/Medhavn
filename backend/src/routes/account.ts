import { Hono } from "hono";
import { db } from "../db.js";

export const account = new Hono<{ Variables: { userId: string; email: string } }>();

// Permanent. Every medhavn table references auth.users ON DELETE CASCADE, so removing
// the auth user removes plans, doses, shares and connections. Email-keyed rows are cleared first.
account.delete("/", async (c) => {
  const id = c.get("userId");
  const email = c.get("email");
  if (email) {
    await db.from("email_otps").delete().eq("email", email);
    await db.from("referrals").delete().eq("referee_email", email);
  }
  const { error } = await db.auth.admin.deleteUser(id);
  if (error) throw error;
  return c.json({ ok: true });
});
