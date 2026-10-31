// Pure missed-dose detection. No I/O so it can be unit tested.
// Mirrors the iOS app: an item is due every day in each of its schedule blocks,
// and a block expires at a fixed local hour (AppState.checkForMissedDoses).

export const BLOCK_END_HOUR: Record<string, number> = {
  morning: 12,
  afternoon: 17,
  evening: 22,
  night: 24,
};

export interface CabinetItem {
  id: string;
  user_id: string;
  name: string;
  schedule_blocks: string; // JSON array of block names
  frequency: string | null;
  schedule_start_date: string | null;
  schedule_end_date: string | null;
}

export interface MissedDose {
  userId: string;
  itemId: string;
  itemName: string;
  block: string;
  date: string; // yyyy-MM-dd, user-local
  key: string; // itemId|yyyy-MM-dd|block, same format as pill_dose_statuses.key
}

/** Wall-clock parts of `now` in `timeZone`. Falls back to UTC for an invalid zone. */
export function localParts(now: Date, timeZone: string) {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-CA", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    }).formatToParts(now);
  } catch {
    return localParts(now, "UTC");
  }
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  return { y: get("year"), m: get("month"), d: get("day"), h: get("hour"), min: get("minute") };
}

function parseBlocks(raw: string): string[] {
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? v.filter((b) => typeof b === "string" && b in BLOCK_END_HOUR) : [];
  } catch {
    return [];
  }
}

/**
 * Doses whose block ended within the last `lookbackMin` minutes (today or yesterday's night block).
 * The caller removes the ones already marked taken or already alerted.
 */
export function findMissedDoses(
  items: CabinetItem[],
  timezoneByUser: Map<string, string>,
  now: Date,
  lookbackMin = 360,
): MissedDose[] {
  const out: MissedDose[] = [];
  for (const item of items) {
    if (item.frequency === "asNeeded") continue;
    const blocks = parseBlocks(item.schedule_blocks);
    if (blocks.length === 0) continue;

    const { y, m, d, h, min } = localParts(now, timezoneByUser.get(item.user_id) ?? "UTC");
    const nowLocalMin = Date.UTC(y, m - 1, d, h, min) / 60000;

    for (const offset of [0, -1]) {
      const date = new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
      if (item.schedule_start_date && date < item.schedule_start_date.slice(0, 10)) continue;
      if (item.schedule_end_date && date > item.schedule_end_date.slice(0, 10)) continue;

      for (const block of blocks) {
        const endMin = Date.UTC(y, m - 1, d + offset, BLOCK_END_HOUR[block]) / 60000;
        const elapsed = nowLocalMin - endMin;
        if (elapsed < 0 || elapsed > lookbackMin) continue;
        out.push({
          userId: item.user_id,
          itemId: item.id,
          itemName: item.name,
          block,
          date,
          key: `${item.id}|${date}|${block}`,
        });
      }
    }
  }
  return out;
}
