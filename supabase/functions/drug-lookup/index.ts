// @ts-nocheck
// Supabase Edge Function: drug-lookup
// Proxies medication name search to OpenFDA so API keys never ship in the iOS app.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type OpenFDALabelResult = {
  openfda?: {
    brand_name?: string[];
    generic_name?: string[];
    substance_name?: string[];
  };
};

type OpenFDAResponse = {
  results?: OpenFDALabelResult[];
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const query = (url.searchParams.get("q") ?? "").trim();
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? "12"), 1), 20);

    if (query.length < 2) {
      return json({ suggestions: [] });
    }

    const openFDAKey = Deno.env.get("OPENFDA_API_KEY") ?? "";
    const search = `openfda.brand_name:${query}*+openfda.generic_name:${query}*+openfda.substance_name:${query}*`;

    const openFDAURL = new URL("https://api.fda.gov/drug/label.json");
    openFDAURL.searchParams.set("search", search);
    openFDAURL.searchParams.set("limit", String(limit));
    if (openFDAKey.length > 0) {
      openFDAURL.searchParams.set("api_key", openFDAKey);
    }

    const resp = await fetch(openFDAURL.toString());
    const payload = (await resp.json()) as OpenFDAResponse | { error?: { message?: string } };

    if (!resp.ok) {
      const message = (payload as { error?: { message?: string } }).error?.message ?? "OpenFDA request failed";
      return json({ error: message }, 502);
    }

    const names = (payload as OpenFDAResponse).results
      ?.flatMap((result) => [
        ...(result.openfda?.brand_name ?? []),
        ...(result.openfda?.generic_name ?? []),
        ...(result.openfda?.substance_name ?? []),
      ])
      .map((name) => name.trim())
      .filter((name) => name.length > 0) ?? [];

    const deduped: string[] = [];
    const seen = new Set<string>();
    for (const name of names) {
      const key = name.toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        deduped.push(name);
      }
      if (deduped.length >= limit) break;
    }

    return json({ suggestions: deduped });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    return json({ error: message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
