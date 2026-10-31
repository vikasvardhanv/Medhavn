import { Hono } from "hono";
import { z } from "zod";
import { db } from "../db.js";

export const profile = new Hono<{ Variables: { userId: string; email: string } }>();

const body = z.object({ sex: z.enum(["female", "male", "other", "prefer_not"]) });

profile.get("/", async (c) => {
  const { data, error } = await db.from("user_profiles").select("sex").eq("auth_id", c.get("userId")).maybeSingle();
  if (error) throw error;
  return c.json({ sex: data?.sex ?? null });
});

profile.put("/", async (c) => {
  const parsed = body.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "Invalid request" }, 400);
  const { error } = await db.from("user_profiles").update({ sex: parsed.data.sex }).eq("auth_id", c.get("userId"));
  if (error) throw error;
  return c.json({ ok: true });
});
