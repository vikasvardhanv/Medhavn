// @ts-nocheck
// Supabase Edge Function: send-email
// Sends transactional emails via Resend. API key is stored as a Supabase secret.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { Resend } from "npm:resend@^2.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SendEmailRequest = {
  to: string;
  subject: string;
  html: string;
  from?: string;
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
      return json({ error: "RESEND_API_KEY secret is not set" }, 500);
    }

    const body = (await req.json()) as SendEmailRequest;
    const { to, subject, html, from = "medhavnapp@resend.dev" } = body;

    if (!to || !subject || !html) {
      return json({ error: "Missing required fields: to, subject, html" }, 400);
    }

    const resend = new Resend(apiKey);
    const { data, error } = await resend.emails.send({ from, to, subject, html });

    if (error) {
      return json({ error: error.message }, 502);
    }

    return json({ id: data?.id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    return json({ error: message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
