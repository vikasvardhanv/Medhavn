// Supabase Edge Function: Store App Logs
// Deploy to: supabase/functions/store-app-logs

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.54.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface LogEntry {
  level: string;
  category: string;
  message: string;
  timestamp: string;
  app_version: string;
  device_model?: string;
  os_version?: string;
}

interface LogRequest {
  logs: LogEntry[];
}

serve(async (req) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Get auth header
    const authHeader = req.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }

    const token = authHeader.slice(7);

    // Create Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user ID
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response("Invalid token", { status: 401 });
    }

    const userId = user.id;

    // Parse request body
    const body: LogRequest = await req.json();

    if (!body.logs || !Array.isArray(body.logs)) {
      return new Response("Invalid request body", { status: 400 });
    }

    // Sanitize and prepare logs for storage
    const sanitizedLogs = body.logs.map((log) => ({
      user_id: userId,
      level: log.level,
      category: log.category,
      message: sanitizeMessage(log.message), // Remove sensitive data
      timestamp: log.timestamp,
      app_version: log.app_version,
      device_model: log.device_model,
      os_version: log.os_version,
    }));

    // Insert logs into database
    const { error: insertError } = await supabase
      .from("app_logs")
      .insert(sanitizedLogs);

    if (insertError) {
      console.error("Insert error:", insertError);
      return new Response("Failed to store logs", { status: 500 });
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Stored ${sanitizedLogs.length} log entries`,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response("Internal server error", { status: 500 });
  }
});

/**
 * Sanitize log messages to remove sensitive information
 * - Removes database URLs and connection strings
 * - Removes table names and schema references
 * - Removes user emails and IDs from messages
 * - Removes API keys and tokens
 */
function sanitizeMessage(message: string): string {
  let sanitized = message;

  // Remove Supabase URLs
  sanitized = sanitized.replace(
    /https?:\/\/[a-z0-9-]+\.supabase\.co/gi,
    "[BACKEND]"
  );

  // Remove table/schema references
  sanitized = sanitized.replace(/medhavn\.[a-z_]+/gi, "[TABLE]");
  sanitized = sanitized.replace(/\.medication_plans/gi, "[TABLE]");
  sanitized = sanitized.replace(/\.user_consents/gi, "[TABLE]");
  sanitized = sanitized.replace(/\.dose_logs/gi, "[TABLE]");

  // Remove UUIDs (user IDs, token segments)
  sanitized = sanitized.replace(
    /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi,
    "[ID]"
  );

  // Remove email addresses
  sanitized = sanitized.replace(/[^\s@]+@[^\s@]+\.[^\s@]+/gi, "[EMAIL]");

  // Remove API keys/tokens (sequences of 20+ alphanumeric chars)
  sanitized = sanitized.replace(/[a-zA-Z0-9]{20,}/g, "[TOKEN]");

  // Remove RLS policy names (specific pattern)
  sanitized = sanitized.replace(/policy\s+"[^"]+"\s+on\s+\w+/gi, "RLS policy");

  // Remove line numbers and file paths
  sanitized = sanitized.replace(/:[0-9]+$/gm, "");
  sanitized = sanitized.replace(/\/[a-zA-Z0-9/_\-\.]+\.swift/gi, "[FILE]");

  return sanitized;
}
