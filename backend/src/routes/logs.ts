import { Hono } from "hono";
import { z } from "zod";
import { db } from "../db.js";
import { sanitizeMessage } from "../sanitize.js";

export const logs = new Hono<{ Variables: { userId: string } }>();

const entry = z.object({
  level: z.string().max(20),
  category: z.string().max(60),
  message: z.string().max(4000),
  timestamp: z.string().datetime({ offset: true }),
  app_version: z.string().max(40),
  device_model: z.string().max(80).optional(),
  os_version: z.string().max(40).optional(),
});
const body = z.object({ logs: z.array(entry).min(1).max(200) });

logs.post("/", async (c) => {
  const parsed = body.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "Invalid request body" }, 400);

  const userId = c.get("userId");
  const rows = parsed.data.logs.map((l) => ({ ...l, user_id: userId, message: sanitizeMessage(l.message) }));
  const { error } = await db.from("app_logs").insert(rows);
  if (error) throw error;
  return c.json({ success: true, message: `Stored ${rows.length} log entries` });
});
