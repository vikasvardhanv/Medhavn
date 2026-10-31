import assert from "node:assert/strict";
import { test } from "node:test";
import { generateCode, isFamily, normalizeEmail } from "../src/referral.ts";
import { referralEmail } from "../src/templates.ts";

test("codes are 8 unambiguous characters", () => {
  for (let i = 0; i < 200; i++) assert.match(generateCode(), /^[A-HJKMNP-Z2-9]{8}$/);
});

test("only family relationships create links", () => {
  assert.ok(isFamily("parent") && isFamily("child") && isFamily("spouse") && isFamily("sibling"));
  assert.ok(!isFamily("friend") && !isFamily("other"));
});

test("emails are normalised for matching", () => {
  assert.equal(normalizeEmail("  Mom@Example.COM "), "mom@example.com");
});

test("referral email carries the store link and the code, and escapes the name", () => {
  const m = referralEmail({ inviterName: "<b>Sam</b>", code: "ABCD2345", appStoreUrl: "https://apps.apple.com/app/id1", family: true });
  assert.ok(m.html.includes("https://apps.apple.com/app/id1"));
  assert.ok(m.html.includes("ABCD2345"));
  assert.ok(!m.html.includes("<b>Sam</b>"));
  assert.ok(!referralEmail({ inviterName: "Sam", code: "ABCD2345", appStoreUrl: "", family: false }).html.includes("Download Medhavn"));
});
