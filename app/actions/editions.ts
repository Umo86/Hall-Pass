"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editionCounters,
  editionDeadlines,
  editions,
  events,
  halls,
  locations,
  signageItems,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";

const createSchema = z.object({
  eventId: z.string().uuid(),
  venueId: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  code: z
    .string()
    .trim()
    .min(2)
    .max(20)
    .regex(/^[A-Z0-9-]+$/i, "Use letters and numbers only"),
  buildStart: z.string().date(),
  buildEnd: z.string().date(),
  openStart: z.string().date(),
  openEnd: z.string().date(),
  breakdownEnd: z.string().date(),
  signageBudget: z.coerce.number().nonnegative().optional().nullable(),
});

const DEFAULT_DEADLINES = [
  { key: "stand_design_due" as const, label: "Stand designs due", daysBeforeBuildStart: 42 },
  { key: "insurance_due" as const, label: "Insurance documents due", daysBeforeBuildStart: 28 },
  {
    key: "venue_rigging_submission" as const,
    label: "Venue rigging submission",
    daysBeforeBuildStart: 28,
  },
  { key: "artwork_due" as const, label: "Artwork due", daysBeforeBuildStart: 21 },
  { key: "print_deadline" as const, label: "Print deadline", daysBeforeBuildStart: 14 },
  { key: "delivery" as const, label: "Delivery to venue", daysBeforeBuildStart: 3 },
];

export async function createEdition(input: unknown): Promise<ActionResult<{ code: string }>> {
  const parsed = createSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admin and ops can create editions");
  }
  const data = parsed.data;
  const code = data.code.toUpperCase();
  const clash = await db.query.editions.findFirst({ where: eq(editions.code, code) });
  if (clash) return fail(`Edition code ${code} is already in use`);
  try {
    await db.transaction(async (tx) => {
      const [edition] = await tx
        .insert(editions)
        .values({ ...data, code, signageBudget: data.signageBudget?.toString() ?? null })
        .returning();
      await tx
        .insert(editionDeadlines)
        .values(DEFAULT_DEADLINES.map((d) => ({ editionId: edition.id, ...d })));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: edition.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: edition.id,
        action: "create",
        after: { code, name: data.name },
        summary: `Created edition ${code}`,
      });
    });
    revalidatePath("/", "layout");
    return success({ code }, `Edition ${code} created`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const cloneSchema = z.object({
  sourceEditionId: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  code: z.string().trim().min(2).max(20),
  buildStart: z.string().date(),
  buildEnd: z.string().date(),
  openStart: z.string().date(),
  openEnd: z.string().date(),
  breakdownEnd: z.string().date(),
  includeExhibitors: z.coerce.boolean().default(false),
});

/**
 * Clone (brief §9 /editions): halls, locations, deadline offsets and signage
 * items as drafts with artwork, approvals, cost actuals and PO cleared.
 */
export async function cloneEdition(input: unknown): Promise<ActionResult<{ code: string }>> {
  const parsed = cloneSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admin and ops can clone editions");
  }
  const data = parsed.data;
  const code = data.code.toUpperCase();
  const source = await db.query.editions.findFirst({
    where: eq(editions.id, data.sourceEditionId),
  });
  if (!source) return fail("Source edition not found");
  const clash = await db.query.editions.findFirst({ where: eq(editions.code, code) });
  if (clash) return fail(`Edition code ${code} is already in use`);

  try {
    await db.transaction(async (tx) => {
      const [target] = await tx
        .insert(editions)
        .values({
          eventId: source.eventId,
          venueId: source.venueId,
          name: data.name,
          code,
          buildStart: data.buildStart,
          buildEnd: data.buildEnd,
          openStart: data.openStart,
          openEnd: data.openEnd,
          breakdownEnd: data.breakdownEnd,
          clonedFromEditionId: source.id,
          signageBudget: source.signageBudget,
          standRequiredDocTypes: source.standRequiredDocTypes,
          complexStructureTriggers: source.complexStructureTriggers,
        })
        .returning();

      // Deadline offsets (not override dates — those were edition-specific).
      const dls = await tx
        .select()
        .from(editionDeadlines)
        .where(eq(editionDeadlines.editionId, source.id));
      if (dls.length > 0) {
        await tx.insert(editionDeadlines).values(
          dls.map((d) => ({
            editionId: target.id,
            key: d.key,
            label: d.label,
            daysBeforeBuildStart: d.daysBeforeBuildStart,
          })),
        );
      }

      // Halls and locations, keeping the mapping for items.
      const hallRows = await tx.select().from(halls).where(eq(halls.editionId, source.id));
      const hallMap = new Map<string, string>();
      for (const h of hallRows) {
        const [nh] = await tx
          .insert(halls)
          .values({ editionId: target.id, name: h.name, sortOrder: h.sortOrder })
          .returning();
        hallMap.set(h.id, nh.id);
      }
      const locMap = new Map<string, string>();
      for (const h of hallRows) {
        const locs = await tx.select().from(locations).where(eq(locations.hallId, h.id));
        for (const l of locs) {
          const [nl] = await tx
            .insert(locations)
            .values({
              hallId: hallMap.get(h.id)!,
              name: l.name,
              zone: l.zone,
              xPct: l.xPct,
              yPct: l.yPct,
              nearStandNumber: l.nearStandNumber,
            })
            .returning();
          locMap.set(l.id, nl.id);
        }
      }

      // Signage items as drafts, artwork/approvals/actuals/PO cleared.
      const items = await tx
        .select()
        .from(signageItems)
        .where(and(eq(signageItems.editionId, source.id), isNull(signageItems.deletedAt)));
      let seq = 0;
      for (const item of items) {
        seq += 1;
        await tx.insert(signageItems).values({
          editionId: target.id,
          ref: `SIG-${code}-${String(seq).padStart(3, "0")}`,
          seq,
          name: item.name,
          description: item.description,
          itemTypeId: item.itemTypeId,
          hallId: item.hallId ? (hallMap.get(item.hallId) ?? null) : null,
          locationId: item.locationId ? (locMap.get(item.locationId) ?? null) : null,
          ownerRole: item.ownerRole,
          ownerUserId: item.ownerUserId,
          sponsorId: null, // sponsors are edition-scoped
          isSponsorDeliverable: false,
          widthMm: item.widthMm,
          heightMm: item.heightMm,
          depthMm: item.depthMm,
          quantity: item.quantity,
          sided: item.sided,
          material: item.material,
          finish: item.finish,
          fixingMethod: item.fixingMethod,
          weightKg: item.weightKg,
          requiresVenueApproval: item.requiresVenueApproval,
          requiresEventDirector: item.requiresEventDirector,
          budgetLine: item.budgetLine,
          costEstimate: item.costEstimate,
          supplierId: item.supplierId,
          workflowId: item.workflowId,
          status: "draft",
          createdBy: session.user.id,
        });
      }
      await tx
        .insert(editionCounters)
        .values({ editionId: target.id, key: "signage", value: seq });

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: target.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: target.id,
        action: "create",
        after: { code, clonedFrom: source.code, items: seq },
        summary: `Cloned ${source.code} → ${code} (${seq} items as drafts)`,
      });
    });
    revalidatePath("/", "layout");
    return success({ code }, `Edition ${code} cloned from ${source.code}`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

export async function listEditionsWithEvents() {
  await requireSession();
  return db
    .select()
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .orderBy(editions.buildStart);
}
