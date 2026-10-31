import { jwtVerify } from "jose";
import type { MiddlewareHandler } from "hono";
import { config } from "./config.js";

const secret = new TextEncoder().encode(config.jwtSecret);

/**
 * Verifies the Supabase access token locally (HS256). The anon key has role "anon"
 * and is rejected, so only signed-in app users get through.
 */
export const requireUser: MiddlewareHandler<{ Variables: { userId: string; email: string } }> = async (c, next) => {
  const header = c.req.header("authorization");
  if (!header?.startsWith("Bearer ")) return c.json({ error: "Unauthorized" }, 401);
  try {
    const { payload } = await jwtVerify(header.slice(7), secret, { algorithms: ["HS256"] });
    if (payload.role !== "authenticated" || !payload.sub) throw new Error("not a user token");
    c.set("userId", payload.sub);
    c.set("email", typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "");
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }
  await next();
};
