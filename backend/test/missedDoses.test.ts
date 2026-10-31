import assert from "node:assert/strict";
import { test } from "node:test";
import { findMissedDoses, type CabinetItem } from "../src/missedDoses.ts";

const item = (over: Partial<CabinetItem> = {}): CabinetItem => ({
  id: "i1",
  user_id: "u1",
  name: "Metformin",
  schedule_blocks: '["morning"]',
  frequency: "everyDay",
  schedule_start_date: null,
  schedule_end_date: null,
  ...over,
});
const utc = new Map<string, string>();

test("morning block is missed just after 12:00", () => {
  const r = findMissedDoses([item()], utc, new Date("2026-10-31T12:30:00Z"));
  assert.deepEqual(r.map((d) => d.key), ["i1|2026-10-31|morning"]);
});

test("nothing before the block ends", () => {
  assert.equal(findMissedDoses([item()], utc, new Date("2026-10-31T11:59:00Z")).length, 0);
});

test("stops alerting after the lookback window", () => {
  assert.equal(findMissedDoses([item()], utc, new Date("2026-10-31T18:30:00Z")).length, 0);
});

test("night block of yesterday is reported after midnight", () => {
  const r = findMissedDoses([item({ schedule_blocks: '["night"]' })], utc, new Date("2026-10-31T00:30:00Z"));
  assert.deepEqual(r.map((d) => d.key), ["i1|2026-10-30|night"]);
});

test("uses the user's timezone", () => {
  const tz = new Map([["u1", "Asia/Kolkata"]]); // UTC+5:30
  // 07:00Z = 12:30 IST, so morning just ended there.
  const r = findMissedDoses([item()], tz, new Date("2026-10-31T07:00:00Z"));
  assert.deepEqual(r.map((d) => d.key), ["i1|2026-10-31|morning"]);
});

test("skips as-needed items, bad JSON, and dates outside the schedule", () => {
  const now = new Date("2026-10-31T12:30:00Z");
  assert.equal(findMissedDoses([item({ frequency: "asNeeded" })], utc, now).length, 0);
  assert.equal(findMissedDoses([item({ schedule_blocks: "nope" })], utc, now).length, 0);
  assert.equal(findMissedDoses([item({ schedule_end_date: "2026-10-30T00:00:00Z" })], utc, now).length, 0);
  assert.equal(findMissedDoses([item({ schedule_start_date: "2026-11-01T00:00:00Z" })], utc, now).length, 0);
});
