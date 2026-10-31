/** Strips identifiers and secrets from client log messages before they are stored. */
export function sanitizeMessage(message: string): string {
  return message
    .replace(/https?:\/\/[a-z0-9.-]+\.(supabase\.co|viktron\.ai)/gi, "[BACKEND]")
    .replace(/medhavn\.[a-z_]+/gi, "[TABLE]")
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, "[ID]")
    .replace(/[^\s@]+@[^\s@]+\.[^\s@]+/g, "[EMAIL]")
    .replace(/[a-zA-Z0-9]{20,}/g, "[TOKEN]")
    .replace(/policy\s+"[^"]+"\s+on\s+\w+/gi, "RLS policy")
    .replace(/\/[a-zA-Z0-9/_\-.]+\.swift/gi, "[FILE]")
    .replace(/:[0-9]+$/gm, "");
}
