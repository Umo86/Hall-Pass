/**
 * Pure helpers for partner portal access shown next to a supplier or venue.
 * Unit tested in tests/unit/suppliers-rules.test.ts.
 */

export type GrantStatus = "invited" | "active" | "expired" | "revoked";

/** Where one grant stands right now. */
export function grantStatus(
  g: { revokedAt: Date | null; expiresAt: Date | null; acceptedAt: Date | null },
  now: Date = new Date(),
): GrantStatus {
  if (g.revokedAt) return "revoked";
  if (g.expiresAt && g.expiresAt.getTime() <= now.getTime()) return "expired";
  return g.acceptedAt ? "active" : "invited";
}

/**
 * "2 people can sign in · 1 invited", or "No portal access". Counts people,
 * not grants: someone with access to three events is one person.
 */
export function portalSummary(grants: { status: GrantStatus; email: string }[]): string {
  const key = (e: string) => e.trim().toLowerCase();
  const active = new Set(grants.filter((g) => g.status === "active").map((g) => key(g.email)));
  const invited = new Set(
    grants
      .filter((g) => g.status === "invited" && !active.has(key(g.email)))
      .map((g) => key(g.email)),
  );
  const parts: string[] = [];
  if (active.size > 0) {
    parts.push(`${active.size === 1 ? "1 person" : `${active.size} people`} can sign in`);
  }
  if (invited.size > 0) {
    parts.push(
      active.size > 0
        ? `${invited.size} invited`
        : `${invited.size === 1 ? "1 person" : `${invited.size} people`} invited`,
    );
  }
  return parts.length ? parts.join(" · ") : "No portal access";
}

export const GRANT_STATUS_LABELS: Record<GrantStatus, string> = {
  invited: "Invited",
  active: "Can sign in",
  expired: "Expired",
  revoked: "Revoked",
};
