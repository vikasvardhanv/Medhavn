import { randomInt } from "node:crypto";

export const RELATIONSHIPS = ["friend", "parent", "child", "spouse", "sibling", "other"] as const;
export type Relationship = (typeof RELATIONSHIPS)[number];

// Relationships that create a (pending) family link when the invitee signs up.
const FAMILY = new Set<Relationship>(["parent", "child", "spouse", "sibling"]);
export const isFamily = (r: Relationship) => FAMILY.has(r);

export const normalizeEmail = (e: string) => e.trim().toLowerCase();

// No 0/O/1/I/L so a code read from a screen is hard to mistype.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export function generateCode(pick: (max: number) => number = randomInt): string {
  return Array.from({ length: 8 }, () => ALPHABET[pick(ALPHABET.length)]).join("");
}
