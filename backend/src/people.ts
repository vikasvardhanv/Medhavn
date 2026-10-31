import { db } from "./db.js";
import { sendMail } from "./mailer.js";
import { noticeEmail } from "./templates.js";

export interface Person {
  id: string;
  name: string;
  email: string;
}

export async function people(ids: string[]): Promise<Map<string, Person>> {
  const out = new Map<string, Person>();
  if (ids.length === 0) return out;
  const { data, error } = await db.from("user_profiles").select("auth_id,full_name,email").in("auth_id", ids);
  if (error) throw error;
  for (const p of data ?? []) {
    if (p.auth_id) out.set(p.auth_id, { id: p.auth_id, name: p.full_name || p.email.split("@")[0], email: p.email });
  }
  return out;
}

/** Best-effort heads-up email. Never carries health data. A failure must not fail the request. */
export async function notify(userId: string, heading: string, lines: string[]): Promise<void> {
  try {
    const p = (await people([userId])).get(userId);
    if (p) await sendMail(p.email, noticeEmail(heading, lines));
  } catch (err) {
    console.error("notify failed", err instanceof Error ? err.message : err);
  }
}
