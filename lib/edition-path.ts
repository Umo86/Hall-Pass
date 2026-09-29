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

export type ItemKind = "signage" | "sponsorship_item" | "stand_design" | "stand_panel";

/** Which section of a show each kind of item lives in. */
export const ITEM_SECTION: Record<ItemKind, string> = {
  signage: "signage",
  sponsorship_item: "sponsorship",
  stand_design: "stand-designs",
  stand_panel: "stand-panels",
};

/** The page of a signage, sponsorship, stand or panel item. */
export function itemPath(editionCode: string, item: { kind: string; ref: string }): string {
  const section = ITEM_SECTION[item.kind as ItemKind] ?? "signage";
  return `/${editionCode}/${section}/${encodeURIComponent(item.ref)}`;
}

/**
 * Where to go when switching to another show from `pathname`: the same
 * section of that show. A record's page (an item, a stand) belongs to one
 * show only, so its list is used instead; panels live under Stand designs.
 */
export function switchShowPath(pathname: string, code: string): string {
  const parts = pathname.split("/").filter(Boolean);
  if (!parts[0] || RESERVED_SEGMENTS.includes(parts[0])) return `/${code}/dashboard`;
  const section = parts[1] ?? "dashboard";
  return `/${code}/${section === "stand-panels" ? "stand-designs" : section}`;
}

/** Kinds shown in the Signage and Sponsorship sections (not stands or panels). */
export const SIGNAGE_KINDS = ["signage", "sponsorship_item"] as const;

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
