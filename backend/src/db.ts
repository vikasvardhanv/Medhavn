import { createClient } from "@supabase/supabase-js";
import { config } from "./config.js";

// Service-role client on the medhavn schema. Bypasses RLS: always scope queries by user_id.
export const db = createClient(config.supabaseUrl, config.serviceKey, {
  db: { schema: "medhavn" },
  auth: { persistSession: false, autoRefreshToken: false },
});
