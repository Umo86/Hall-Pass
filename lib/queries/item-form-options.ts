import "server-only";
import { and, asc, desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  halls,
  itemTypes,
  locations,
  sponsorEntitlements,
  sponsors,
  suppliers,
  workflows,
} from "@/lib/db/schema";
import type { ItemFormOptions } from "@/components/signage/item-form";

/**
 * Everything the item form's pickers need, for one kind of item. Workflows
 * are only loaded for the create form (the default one first).
 */
export async function itemFormOptions(opts: {
  organisationId: string;
  editionId: string;
  kind: "signage" | "sponsorship_item";
  withWorkflows?: boolean;
}): Promise<ItemFormOptions> {
  const isSignage = opts.kind === "signage";
  const [typeRows, hallRows, locationRows, sponsorRows, entRows, supplierRows, contractorRows, wfRows] =
    await Promise.all([
      db
        .select({ id: itemTypes.id, name: itemTypes.name })
        .from(itemTypes)
        .where(and(eq(itemTypes.organisationId, opts.organisationId), eq(itemTypes.kind, opts.kind)))
        .orderBy(asc(itemTypes.sortOrder), asc(itemTypes.name)),
      isSignage
        ? db
            .select({ id: halls.id, name: halls.name })
            .from(halls)
            .where(eq(halls.editionId, opts.editionId))
            .orderBy(asc(halls.sortOrder), asc(halls.name))
        : [],
      isSignage
        ? db
            .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
            .from(locations)
            .innerJoin(halls, eq(locations.hallId, halls.id))
            .where(eq(halls.editionId, opts.editionId))
            .orderBy(asc(locations.name))
        : [],
      db
        .select({ id: sponsors.id, name: sponsors.companyName })
        .from(sponsors)
        .where(eq(sponsors.editionId, opts.editionId))
        .orderBy(asc(sponsors.companyName)),
      db
        .select({
          id: sponsorEntitlements.id,
          sponsorId: sponsorEntitlements.sponsorId,
          description: sponsorEntitlements.description,
        })
        .from(sponsorEntitlements)
        .innerJoin(sponsors, eq(sponsorEntitlements.sponsorId, sponsors.id))
        .where(eq(sponsors.editionId, opts.editionId)),
      db
        .select({ id: suppliers.id, name: suppliers.name })
        .from(suppliers)
        .where(eq(suppliers.organisationId, opts.organisationId))
        .orderBy(asc(suppliers.name)),
      isSignage
        ? db
            .select({ id: contractors.id, name: contractors.name })
            .from(contractors)
            .where(eq(contractors.organisationId, opts.organisationId))
            .orderBy(asc(contractors.name))
        : [],
      opts.withWorkflows
        ? db
            .select({ id: workflows.id, name: workflows.name })
            .from(workflows)
            .where(
              and(
                eq(workflows.organisationId, opts.organisationId),
                eq(workflows.appliesTo, "signage"),
                eq(workflows.isArchived, false),
              ),
            )
            .orderBy(desc(workflows.isDefault), asc(workflows.name))
        : [],
    ]);
  return {
    itemTypes: typeRows,
    halls: hallRows,
    locations: locationRows,
    sponsors: sponsorRows,
    entitlements: entRows,
    suppliers: supplierRows,
    contractors: contractorRows,
    workflows: wfRows,
  };
}
