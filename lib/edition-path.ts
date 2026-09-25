/**
 * Single source of truth for reading the edition code out of a pathname.
 * Top-level segments that are app routes rather than edition codes.
 */
export const RESERVED_SEGMENTS = [
  "editions",
  "approvals",
  "my-work",
  "reset-password",
  "settings",
  "suppliers",
  "portal",
  "login",
  "invite",
  "q",
  "api",
  "auth",
];

/** The edition code a pathname is scoped to, or null on a global page. */
export function editionCodeFromPath(pathname: string): string | null {
  const first = pathname.split("/").filter(Boolean)[0];
  if (first && !RESERVED_SEGMENTS.includes(first)) return first;
  return null;
}

/** Where staff land after signing in: their own work. */
export const STAFF_HOME = "/my-work";
/** Where external users land. */
export const PORTAL_HOME = "/portal/approvals";

/**
 * A same-site path to continue to after sign-in, or null. Only plain
 * paths are accepted, never another site ("//evil.test", "/\\evil.test").
 */
export function safeNext(value: unknown): string | null {
  if (typeof value !== "string" || !value.startsWith("/")) return null;
  if (value.startsWith("//") || value.startsWith("/\\")) return null;
  if (value.startsWith("/login") || value.startsWith("/auth/")) return null;
  return value;
}
