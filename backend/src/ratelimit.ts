import type { MiddlewareHandler } from "hono";

// Fixed-window counter in process memory. Fine for one instance; use Redis if this scales out.
const hits = new Map<string, { count: number; resetAt: number }>();

/** Returns true when the call is allowed. */
export function allow(bucket: string, max: number, windowMs: number, now = Date.now()): boolean {
  const entry = hits.get(bucket);
  if (!entry || entry.resetAt <= now) {
    hits.set(bucket, { count: 1, resetAt: now + windowMs });
    if (hits.size > 10_000) for (const [k, v] of hits) if (v.resetAt <= now) hits.delete(k);
    return true;
  }
  entry.count += 1;
  return entry.count <= max;
}

export function clientIp(forwardedFor: string | undefined): string {
  return forwardedFor?.split(",")[0]?.trim() || "unknown";
}

/** Per-user limiter. Mount after requireUser. */
export const rateLimitUser =
  (name: string, max: number, windowMs: number): MiddlewareHandler =>
  async (c, next) => {
    if (!allow(`${name}:${c.get("userId")}`, max, windowMs)) {
      return c.json({ error: "Too many requests" }, 429);
    }
    await next();
  };
