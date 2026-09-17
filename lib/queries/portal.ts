import "server-only";
import { and, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, halls, locations, signageItems, sponsors, suppliers } from "@/lib/db/schema";
import { can, type ExternalActor, type SignageItemCtx } from "@/lib/authz";

/** Items an external actor may see, with the reason (role) they see them. */
export async function visibleItemsForExternal(actor: ExternalActor) {
  const editionIds = [...new Set(actor.grants.map((g) => g.editionId))];
  if (editionIds.length === 0) return [];
  const rows = await db
    .select({
      item: signageItems,
      edition: editions,
      hallName: halls.name,
      locationName: locations.name,
      supplierName: suppliers.name,
      sponsorName: sponsors.companyName,
    })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .leftJoin(halls, eq(signageItems.hallId, halls.id))
    .leftJoin(locations, eq(signageItems.locationId, locations.id))
    .leftJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
    .leftJoin(sponsors, eq(signageItems.sponsorId, sponsors.id))
    .where(and(inArray(signageItems.editionId, editionIds), isNull(signageItems.deletedAt)));

  return rows.filter((r) => {
    const ctx: SignageItemCtx = {
      editionId: r.edition.id,
      venueId: r.edition.venueId,
      sponsorId: r.item.sponsorId,
      supplierId: r.item.supplierId,
      requiresVenueApproval: r.item.requiresVenueApproval,
    };
    return can(actor, { type: "signage.view", item: ctx });
  });
}
