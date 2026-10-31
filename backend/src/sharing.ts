import type { Relationship } from "./referral.js";

export const SCOPES = ["alerts", "adherence", "medications"] as const;
export type Scope = (typeof SCOPES)[number];

const INVERSE: Partial<Record<Relationship, Relationship>> = { parent: "child", child: "parent" };

/** A connection stores what the invitee is to the inviter. Flip it for the invitee's point of view. */
export function perspective(relationship: Relationship, iAmInviter: boolean): Relationship {
  return iAmInviter ? relationship : (INVERSE[relationship] ?? relationship);
}

export interface DoseRow {
  key: string; // itemId|yyyy-MM-dd|block
  status: string; // taken | skipped | pending
}

/** Counts per day and overall. Contains no medicine names. */
export function adherenceSummary(rows: DoseRow[], sinceDate: string) {
  const byDay = new Map<string, { taken: number; missed: number }>();
  for (const r of rows) {
    const date = r.key.split("|")[1];
    if (!date || date < sinceDate) continue;
    if (r.status !== "taken" && r.status !== "skipped") continue;
    const day = byDay.get(date) ?? { taken: 0, missed: 0 };
    if (r.status === "taken") day.taken++;
    else day.missed++;
    byDay.set(date, day);
  }
  const perDay = [...byDay.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([date, v]) => ({ date, ...v }));
  const taken = perDay.reduce((n, d) => n + d.taken, 0);
  const missed = perDay.reduce((n, d) => n + d.missed, 0);
  return { taken, missed, rate: taken + missed > 0 ? Math.round((taken / (taken + missed)) * 100) : null, byDay: perDay };
}
