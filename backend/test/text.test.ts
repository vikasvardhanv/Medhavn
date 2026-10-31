import assert from "node:assert/strict";
import { test } from "node:test";
import { sanitizeMessage } from "../src/sanitize.ts";
import { escapeHtml, safeCircleInviteEmail } from "../src/templates.ts";

test("sanitize strips emails, ids, tables and backend urls", () => {
  const out = sanitizeMessage(
    "fail for a@b.com id 123e4567-e89b-12d3-a456-426614174000 on medhavn.dose_logs at https://supabasemedhavn.viktron.ai",
  );
  assert.ok(!out.includes("a@b.com"));
  assert.ok(!out.includes("123e4567"));
  assert.ok(!out.includes("dose_logs"));
  assert.ok(!out.includes("viktron"));
});

test("templates escape user-supplied names", () => {
  assert.equal(escapeHtml(`<b>"x"</b>`), "&lt;b&gt;&quot;x&quot;&lt;/b&gt;");
  assert.ok(!safeCircleInviteEmail("<script>alert(1)</script>").html.includes("<script>"));
});
