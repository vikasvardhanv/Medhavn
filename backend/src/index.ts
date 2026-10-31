import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { secureHeaders } from "hono/secure-headers";
import { requireUser } from "./auth.js";
import { config } from "./config.js";
import { startMissedDoseJob } from "./job.js";
import { rateLimitUser } from "./ratelimit.js";
import { drugs } from "./routes/drugs.js";
import { email } from "./routes/email.js";
import { logs } from "./routes/logs.js";
import { otp } from "./routes/otp.js";
import { referrals } from "./routes/referrals.js";

const app = new Hono();

app.use("*", secureHeaders());
app.use("*", bodyLimit({ maxSize: 256 * 1024, onError: (c) => c.json({ error: "Payload too large" }, 413) }));

app.get("/health", (c) => c.json({ status: "ok", service: "medhavn-backend" }));

// Unauthenticated: signup verification only.
app.route("/v1/otp", otp);

// Everything else needs a signed-in Supabase user.
app.use("/v1/email/*", requireUser, rateLimitUser("email", 20, 60 * 60_000));
app.use("/v1/drugs/*", requireUser, rateLimitUser("drugs", 120, 60_000));
app.use("/v1/logs", requireUser, rateLimitUser("logs", 30, 60_000));
app.use("/v1/referrals/*", requireUser);
app.use("/v1/referrals", requireUser);
app.route("/v1/email", email);
app.route("/v1/drugs", drugs);
app.route("/v1/logs", logs);
app.route("/v1/referrals", referrals);

app.notFound((c) => c.json({ error: "Not found" }, 404));
app.onError((err, c) => {
  console.error("unhandled", err instanceof Error ? err.message : err);
  return c.json({ error: "Internal server error" }, 500);
});

const server = serve({ fetch: app.fetch, port: config.port }, (info) =>
  console.log(`medhavn-backend listening on :${info.port}`),
);

const timer = config.job.enabled ? startMissedDoseJob(config.job.intervalMin) : undefined;

for (const sig of ["SIGTERM", "SIGINT"] as const) {
  process.on(sig, () => {
    if (timer) clearInterval(timer);
    server.close(() => process.exit(0));
  });
}
