/**
 * How many partners' portal access a copied event brings across — the same
 * rule cloneEdition applies, so the copy form's "Portal access (N)" says
 * what will happen. Pure; tested in tests/unit/copy-access.test.ts.
 *
 * Each grant on the old event that would come across (not revoked; a
 * supplier not archived; not someone now on the team) is described by
 * whether it is for the old event's venue and when it ends, as days after
 * the old event's last breakdown day. An end date moves with the event, so
 * the copy keeps the same distance from its own last breakdown day, and
 * the grant comes across only while that moved date is today or later —
 * access that ended with last year's event comes back for this year's.
 */
import { addDaysIso } from "@/lib/deadlines";

export type CopyableGrant = {
  /** For the old event's venue: comes across only to the same venue. */
  venue: boolean;
  /** Days after the old event's last breakdown day it ends; null = no end date. */
  endOffsetDays: number | null;
};

export function copiedAccessCount(
  grants: readonly CopyableGrant[],
  opts: {
    /** The new event's last breakdown day, or null while its dates aren't valid yet. */
    breakdownEnd: string | null;
    sameVenue: boolean;
    /** Today in London (YYYY-MM-DD). */
    today: string;
  },
): number {
  return grants.filter((g) => {
    if (g.venue && !opts.sameVenue) return false;
    if (g.endOffsetDays == null || opts.breakdownEnd == null) return true;
    return addDaysIso(opts.breakdownEnd, g.endOffsetDays) >= opts.today;
  }).length;
}
