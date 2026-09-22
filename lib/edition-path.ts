/**
 * Single source of truth for reading the edition code out of a pathname.
 * Top-level segments that are app routes rather than edition codes.
 */
export const RESERVED_SEGMENTS = [
  "editions",
  "approvals",
  "settings",
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
