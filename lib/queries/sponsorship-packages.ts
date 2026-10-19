// No "server-only" marker: the seed script sells the demo packages through
// lib/sponsorship/packages.ts, which reads entitlements here.
/**
 * Sponsorship packages as the pages, dashboard, export and package actions
 * read them. Each takes one event (or its sponsors) already checked by the
 * caller: the page through getEditionByCode, the actions through
 * ownEdition / ownPackage / ownSponsor.
 */
import { and, asc, count, eq, inArray, isNotNull, sql } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  signageItems,
  sponsorEntitlements,
  sponsors,
  sponsorshipPackageLines,
  sponsorshipPackages,
} from "@/lib/db/schema";
import type { PackageRowInput, PlanEntitlement } from "@/lib/domain/sponsorship-packages";

export { toRevenuePackages } from "@/lib/domain/sponsorship-packages";

export type PackageRow = PackageRowInput;

/**
 * The event's packages with what's included, who bought each and whether
 * anything points at it: live ones first by (sort order, name), then archived.
 */
export async function listPackages(executor: Db | Tx, editionId: string): Promise<PackageRow[]> {
  const pkgs = await executor
    .select()
    .from(sponsorshipPackages)
    .where(eq(sponsorshipPackages.editionId, editionId))
    .orderBy(
      asc(sponsorshipPackages.isArchived),
      asc(sponsorshipPackages.sortOrder),
      asc(sql`lower(${sponsorshipPackages.name})`),
    );
  if (pkgs.length === 0) return [];
  const ids = pkgs.map((p) => p.id);
  const [lines, sales, fromRows] = await Promise.all([
    executor
      .select()
      .from(sponsorshipPackageLines)
      .where(inArray(sponsorshipPackageLines.packageId, ids))
      .orderBy(asc(sponsorshipPackageLines.sortOrder), asc(sponsorshipPackageLines.createdAt)),
    executor
      .select({
        packageId: sponsors.packageId,
        sponsorId: sponsors.id,
        companyName: sponsors.companyName,
        agreedPrice: sponsors.packagePrice,
        priceNote: sponsors.packagePriceNote,
        soldAt: sponsors.packageSoldAt,
      })
      .from(sponsors)
      .where(and(eq(sponsors.editionId, editionId), inArray(sponsors.packageId, ids)))
      .orderBy(asc(sql`lower(${sponsors.companyName})`)),
    executor
      .select({ packageId: sponsorEntitlements.fromPackageId, n: count() })
      .from(sponsorEntitlements)
      .where(inArray(sponsorEntitlements.fromPackageId, ids))
      .groupBy(sponsorEntitlements.fromPackageId),
  ]);
  const fromCount = new Map(fromRows.map((r) => [r.packageId, Number(r.n)]));
  return pkgs.map((p) => {
    const sold = sales.filter((s) => s.packageId === p.id);
    return {
      id: p.id,
      name: p.name,
      description: p.description,
      price: p.price,
      places: p.places,
      sortOrder: p.sortOrder,
      isArchived: p.isArchived,
      lines: lines
        .filter((l) => l.packageId === p.id)
        .map((l) => ({ id: l.id, description: l.description, quantity: l.quantity })),
      sales: sold.map((s) => ({
        sponsorId: s.sponsorId,
        companyName: s.companyName,
        agreedPrice: s.agreedPrice,
        priceNote: s.priceNote,
        soldAt: s.soldAt,
      })),
      referenced: sold.length > 0 || (fromCount.get(p.id) ?? 0) > 0,
    };
  });
}

export type SponsorEntitlementRow = PlanEntitlement & {
  sponsorId: string;
  /** The package whose sale added it, by name; null = added by hand. */
  fromPackageName: string | null;
};

/**
 * Each sponsor's entitlements in the order they were added, with how many
 * items count towards each (deleted ones too — they still point at it) and
 * the package each came from.
 */
export async function sponsorEntitlementRows(
  executor: Db | Tx,
  sponsorIds: readonly string[],
): Promise<SponsorEntitlementRow[]> {
  if (sponsorIds.length === 0) return [];
  const ids = [...sponsorIds];
  const [rows, links] = await Promise.all([
    executor
      .select({
        id: sponsorEntitlements.id,
        sponsorId: sponsorEntitlements.sponsorId,
        description: sponsorEntitlements.description,
        quantity: sponsorEntitlements.quantity,
        fromPackageId: sponsorEntitlements.fromPackageId,
        fromPackageName: sponsorshipPackages.name,
      })
      .from(sponsorEntitlements)
      .leftJoin(sponsorshipPackages, eq(sponsorshipPackages.id, sponsorEntitlements.fromPackageId))
      .where(inArray(sponsorEntitlements.sponsorId, ids))
      .orderBy(asc(sponsorEntitlements.createdAt), asc(sponsorEntitlements.id)),
    executor
      .select({ id: signageItems.sponsorEntitlementId, n: count() })
      .from(signageItems)
      .innerJoin(sponsorEntitlements, eq(signageItems.sponsorEntitlementId, sponsorEntitlements.id))
      .where(
        and(
          inArray(sponsorEntitlements.sponsorId, ids),
          isNotNull(signageItems.sponsorEntitlementId),
        ),
      )
      .groupBy(signageItems.sponsorEntitlementId),
  ]);
  const linked = new Map(links.map((l) => [l.id, Number(l.n)]));
  return rows.map((r) => ({ ...r, linkedItems: linked.get(r.id) ?? 0 }));
}
