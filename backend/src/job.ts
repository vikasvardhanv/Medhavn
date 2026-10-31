import { db } from "./db.js";
import { sendMail } from "./mailer.js";
import { people } from "./people.js";
import { findMissedDoses, type CabinetItem, type MissedDose } from "./missedDoses.js";
import { missedDoseAlertEmail } from "./templates.js";

const chunk = <T>(arr: T[], n = 200): T[][] =>
  Array.from({ length: Math.ceil(arr.length / n) }, (_, i) => arr.slice(i * n, i * n + n));

/** One scheduler pass. Safe to run on several instances: alerts are claimed via a unique key. */
export async function runMissedDoseJob(now = new Date()): Promise<{ candidates: number; alerted: number }> {
  // ponytail: loads every cabinet item; page or filter by active users if the table grows past a few thousand rows.
  const { data: items, error } = await db
    .from("med_cabinet_items")
    .select("id,user_id,name,schedule_blocks,frequency,schedule_start_date,schedule_end_date");
  if (error) throw error;

  const { data: profiles, error: pErr } = await db.from("user_profiles").select("auth_id,timezone,full_name");
  if (pErr) throw pErr;
  const tz = new Map<string, string>();
  const names = new Map<string, string>();
  for (const p of profiles ?? []) {
    if (!p.auth_id) continue;
    tz.set(p.auth_id, p.timezone || "UTC");
    if (p.full_name) names.set(p.auth_id, p.full_name);
  }

  let due = findMissedDoses((items ?? []) as CabinetItem[], tz, now);
  const candidates = due.length;
  if (due.length === 0) return { candidates, alerted: 0 };

  // Drop doses the user already took.
  const taken = new Set<string>();
  for (const keys of chunk(due.map((d) => d.key))) {
    const { data, error: sErr } = await db
      .from("pill_dose_statuses")
      .select("user_id,key")
      .eq("status", "taken")
      .in("key", keys);
    if (sErr) throw sErr;
    for (const r of data ?? []) taken.add(`${r.user_id}|${r.key}`);
  }
  due = due.filter((d) => !taken.has(`${d.userId}|${d.key}`));
  if (due.length === 0) return { candidates, alerted: 0 };

  // Claim alerts atomically; only newly inserted rows get emailed.
  const claimed: MissedDose[] = [];
  for (const part of chunk(due)) {
    const { data, error: cErr } = await db
      .from("missed_dose_alerts")
      .upsert(part.map((d) => ({ user_id: d.userId, key: d.key })), {
        onConflict: "user_id,key",
        ignoreDuplicates: true,
      })
      .select("user_id,key");
    if (cErr) throw cErr;
    const won = new Set((data ?? []).map((r) => `${r.user_id}|${r.key}`));
    claimed.push(...part.filter((d) => won.has(`${d.userId}|${d.key}`)));
  }

  const byUser = new Map<string, MissedDose[]>();
  for (const d of claimed) byUser.set(d.userId, [...(byUser.get(d.userId) ?? []), d]);

  let alerted = 0;
  for (const [userId, doses] of byUser) {
    const { data: contacts, error: kErr } = await db
      .from("safe_circle_contacts")
      .select("name,contact_info")
      .eq("user_id", userId);
    if (kErr) throw kErr;
    const isEmail = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);

    // Recipients: SafeCircle contacts get a neutral message. People the user shares with get alerts
    // only if they hold the "alerts" scope, and see medicine names only with "medications".
    const recipients = new Map<string, boolean>(); // email -> may see medicine names
    for (const k of contacts ?? []) if (isEmail(k.contact_info.trim())) recipients.set(k.contact_info.trim(), false);

    const { data: viewers, error: vErr } = await db
      .from("data_shares")
      .select("viewer_id,scopes")
      .eq("owner_id", userId)
      .eq("status", "active")
      .contains("scopes", ["alerts"]);
    if (vErr) throw vErr;
    const viewerProfiles = await people((viewers ?? []).map((v) => v.viewer_id));
    for (const v of viewers ?? []) {
      const email = viewerProfiles.get(v.viewer_id)?.email;
      if (email) recipients.set(email, recipients.get(email) === true || (v.scopes as string[]).includes("medications"));
    }

    const patient = names.get(userId) ?? "A Medhavn user";
    let sent = 0;
    for (const [to, canSeeNames] of recipients) {
      try {
        await sendMail(to, missedDoseAlertEmail(patient, doses.length, canSeeNames ? doses : undefined));
        sent++;
      } catch (err) {
        console.error("missed-dose email failed", err instanceof Error ? err.message : err);
      }
    }
    if (sent > 0) {
      alerted += doses.length;
    } else {
      // Nobody was reached (no recipients, or SMTP failed). Release the claim so a later pass can retry
      // while the dose is still inside the lookback window.
      await db.from("missed_dose_alerts").delete().eq("user_id", userId).in("key", doses.map((d) => d.key));
    }
  }
  return { candidates, alerted };
}

export function startMissedDoseJob(intervalMin: number): NodeJS.Timeout {
  const tick = () =>
    runMissedDoseJob()
      .then((r) => r.candidates > 0 && console.log(`missed-dose job: ${r.candidates} candidates, ${r.alerted} alerted`))
      .catch((err) => console.error("missed-dose job failed", err instanceof Error ? err.message : err));
  tick();
  return setInterval(tick, intervalMin * 60_000);
}
