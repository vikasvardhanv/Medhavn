import assert from "node:assert/strict";
import { test } from "node:test";
import { adherenceSummary, perspective } from "../src/sharing.ts";
import { missedDoseAlertEmail, noticeEmail } from "../src/templates.ts";

test("parent and child flip with the point of view, others stay", () => {
  assert.equal(perspective("parent", true), "parent");
  assert.equal(perspective("parent", false), "child");
  assert.equal(perspective("child", false), "parent");
  assert.equal(perspective("friend", false), "friend");
  assert.equal(perspective("spouse", false), "spouse");
});

test("adherence counts taken and missed per day, ignoring pending and old rows", () => {
  const rows = [
    { key: "a|2026-10-30|morning", status: "taken" },
    { key: "a|2026-10-30|evening", status: "skipped" },
    { key: "b|2026-10-31|morning", status: "taken" },
    { key: "b|2026-10-31|night", status: "pending" },
    { key: "a|2026-10-01|morning", status: "taken" },
  ];
  const r = adherenceSummary(rows, "2026-10-25");
  assert.equal(r.taken, 2);
  assert.equal(r.missed, 1);
  assert.equal(r.rate, 67);
  assert.deepEqual(r.byDay.map((d) => d.date), ["2026-10-30", "2026-10-31"]);
  assert.equal(adherenceSummary([], "2026-10-25").rate, null);
});

test("alert email hides medicine names unless they are passed in", () => {
  const doses = [{ itemName: "Metformin", block: "morning", date: "2026-10-31" }];
  assert.ok(!missedDoseAlertEmail("Sam", 1).html.includes("Metformin"));
  assert.ok(missedDoseAlertEmail("Sam", 1, doses).html.includes("Metformin"));
});

test("notice emails escape names", () => {
  assert.ok(!noticeEmail("<b>x</b> asked", ["<i>y</i>"]).html.includes("<b>x</b>"));
});
