import { Hono } from "hono";
import { config } from "../config.js";

// Proxies medication name search to OpenFDA so the API key never ships in the app.
export const drugs = new Hono();

drugs.get("/suggest", async (c) => {
  // Letters, digits, space and hyphen only: the value is embedded in an OpenFDA search expression.
  const q = (c.req.query("q") ?? "").replace(/[^\p{L}\p{N} -]/gu, "").trim();
  const limit = Math.min(Math.max(Number(c.req.query("limit") ?? 12) || 12, 1), 20);
  if (q.length < 2) return c.json({ suggestions: [] });

  const url = new URL("https://api.fda.gov/drug/label.json");
  url.searchParams.set(
    "search",
    `openfda.brand_name:${q}* OR openfda.generic_name:${q}* OR openfda.substance_name:${q}*`,
  );
  url.searchParams.set("limit", String(limit));
  if (config.openFdaKey) url.searchParams.set("api_key", config.openFdaKey);

  const resp = await fetch(url, { signal: AbortSignal.timeout(5000) }).catch(() => null);
  if (!resp) return c.json({ error: "OpenFDA unreachable" }, 502);
  // OpenFDA answers 404 when nothing matches.
  if (resp.status === 404) return c.json({ suggestions: [] });
  if (!resp.ok) return c.json({ error: "OpenFDA request failed" }, 502);

  const payload = (await resp.json()) as {
    results?: { openfda?: { brand_name?: string[]; generic_name?: string[]; substance_name?: string[] } }[];
  };
  const seen = new Set<string>();
  const suggestions: string[] = [];
  for (const r of payload.results ?? []) {
    for (const name of [...(r.openfda?.brand_name ?? []), ...(r.openfda?.generic_name ?? []), ...(r.openfda?.substance_name ?? [])]) {
      const n = name.trim();
      if (n && !seen.has(n.toLowerCase())) {
        seen.add(n.toLowerCase());
        suggestions.push(n);
      }
    }
  }
  return c.json({ suggestions: suggestions.slice(0, limit) });
});
