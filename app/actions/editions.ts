"use server";

import { ownEdition } from "@/lib/domain/signage";

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
  sponsorEntitlements,
  sponsors,
  venues,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { buildStoragePath, putObject } from "@/lib/storage";
import { formatStandDesignRef, formatStandPanelRef, STAND_SEQ_BASE } from "@/lib/refs";
import { DEADLINE_LABELS } from "@/lib/deadlines";

type ShowDates = {
  buildStart: string;
  buildEnd: string;
  openStart: string;
  openEnd: string;
  breakdownEnd: string;
};

/** Build → open → breakdown must run in order (ISO dates compare as strings). */
function checkDateOrder(d: ShowDates, ctx: z.RefinementCtx) {
  const order: Array<[keyof ShowDates, string]> = [
    ["buildStart", "Build starts"],
    ["buildEnd", "Build ends"],
    ["openStart", "Show opens"],
    ["openEnd", "Show closes"],
    ["breakdownEnd", "Breakdown ends"],
  ];
  for (let i = 1; i < order.length; i++) {
    const [prevKey, prevLabel] = order[i - 1];
    const [key, label] = order[i];
    if (d[key] < d[prevKey]) {
      ctx.addIssue({
        code: "custom",
        path: [key],
        message: `${label} can't be before ${prevLabel.toLowerCase()}`,
      });
      return;
    }
  }
}

const codeSchema = z
  .string()
  .trim()
  .min(2)
  .max(20)
  .regex(/^[A-Z0-9-]+$/i, "Use letters and numbers only");

const datesSchema = z.object({
  buildStart: z.string().date(),
  buildEnd: z.string().date(),
  openStart: z.string().date(),
  openEnd: z.string().date(),
  breakdownEnd: z.string().date(),
});

const blankToNull = (v: unknown) => (typeof v === "string" && v.trim() === "" ? null : v);

const createSchema = datesSchema
  .extend({
    // Pick an existing series and venue, or type new ones in the same form.
    eventId: z.preprocess(blankToNull, z.string().uuid().nullable().optional()),
    newEventName: z.preprocess(blankToNull, z.string().trim().max(200).nullable().optional()),
    venueId: z.preprocess(blankToNull, z.string().uuid().nullable().optional()),
    newVenueName: z.preprocess(blankToNull, z.string().trim().max(200).nullable().optional()),
    newVenueAddress: z.preprocess(blankToNull, z.string().trim().max(500).nullable().optional()),
    name: z.string().trim().min(1, "Give the show a name").max(200),
    code: codeSchema,
    signageBudget: z.preprocess(blankToNull, z.coerce.number().nonnegative().nullable().optional()),
  })
  .superRefine((d, ctx) => {
    if (!d.eventId && !d.newEventName) {
      ctx.addIssue({
        code: "custom",
        path: ["eventId"],
        message: "Choose the show series or type a new one",
      });
    }
    if (!d.venueId && !d.newVenueName) {
      ctx.addIssue({
        code: "custom",
        path: ["venueId"],
        message: "Choose the venue or add a new one",
      });
    }
    checkDateOrder(d, ctx);
  });

/** A short unique code from a name ("NEC Birmingham" → "NECBIRMINGHAM", then -2…). */
async function uniqueCode(
  tx: Parameters<Parameters<typeof db.transaction>[0]>[0],
  table: typeof events | typeof venues,
  organisationId: string,
  name: string,
) {
  const base =
    name
      .toUpperCase()
      .replace(/[^A-Z0-9]+/g, "")
      .slice(0, 16) || "SHOW";
  let code = base;
  for (let n = 2; ; n++) {
    const clash = await tx
      .select({ id: table.id })
      .from(table)
      .where(and(eq(table.organisationId, organisationId), eq(table.code, code)))
      .limit(1);
    if (clash.length === 0) return code;
    code = `${base.slice(0, 16)}-${n}`;
  }
}

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

export async function createEdition(
  input: unknown,
): Promise<ActionResult<{ code: string; id: string }>> {
  const parsed = createSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can create shows");
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const code = data.code.toUpperCase();
  const [event, venue] = await Promise.all([
    data.eventId
      ? db.query.events.findFirst({
          where: and(eq(events.id, data.eventId), eq(events.organisationId, orgId)),
        })
      : null,
    data.venueId
      ? db.query.venues.findFirst({
          where: and(eq(venues.id, data.venueId), eq(venues.organisationId, orgId)),
        })
      : null,
  ]);
  if (data.eventId && !event) return fail("That show series wasn't found");
  if (data.venueId && !venue) return fail("That venue wasn't found");
  const clash = await db.query.editions.findFirst({ where: eq(editions.code, code) });
  if (clash) return fail(`The code ${code} is already used by another show`);
  let editionId = "";
  try {
    await db.transaction(async (tx) => {
      let eventId = event?.id;
      if (!eventId) {
        const [created] = await tx
          .insert(events)
          .values({
            organisationId: orgId,
            name: data.newEventName!,
            code: await uniqueCode(tx, events, orgId, data.newEventName!),
          })
          .returning();
        eventId = created.id;
      }
      let venueId = venue?.id;
      if (!venueId) {
        const [created] = await tx
          .insert(venues)
          .values({
            organisationId: orgId,
            name: data.newVenueName!,
            code: await uniqueCode(tx, venues, orgId, data.newVenueName!),
            address: data.newVenueAddress ?? null,
          })
          .returning();
        venueId = created.id;
      }
      const [edition] = await tx
        .insert(editions)
        .values({
          eventId,
          venueId,
          name: data.name,
          code,
          buildStart: data.buildStart,
          buildEnd: data.buildEnd,
          openStart: data.openStart,
          openEnd: data.openEnd,
          breakdownEnd: data.breakdownEnd,
          signageBudget: data.signageBudget?.toString() ?? null,
        })
        .returning();
      editionId = edition.id;
      await tx
        .insert(editionDeadlines)
        .values(DEFAULT_DEADLINES.map((d) => ({ editionId: edition.id, ...d })));
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: edition.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: edition.id,
        action: "create",
        after: { code, name: data.name, newSeries: !event, newVenue: !venue },
        summary: `Created show ${code} — ${data.name}`,
      });
    });
    revalidatePath("/", "layout");
    return success({ code, id: editionId }, `Show ${code} created`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const cloneSchema = datesSchema
  .extend({
    sourceEditionId: z.string().uuid(),
    name: z.string().trim().min(1).max(200),
    code: codeSchema,
  })
  .superRefine(checkDateOrder);

/**
 * Clone (brief §9 /editions): halls, locations, deadline offsets and signage
 * items as drafts with artwork, approvals, cost actuals and PO cleared.
 */
export async function cloneEdition(input: unknown): Promise<ActionResult<{ code: string }>> {
  const parsed = cloneSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and operations can copy shows");
  }
  const data = parsed.data;
  const code = data.code.toUpperCase();
  // Only this organisation's shows can be copied.
  const source = await ownEdition(db, session.organisation.id, data.sourceEditionId);
  if (!source) return fail("Show not found");
  const clash = await db.query.editions.findFirst({ where: eq(editions.code, code) });
  if (clash) return fail(`Show code ${code} is already in use`);

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
          logoPath: source.logoPath,
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

      // Sponsors come across (the same companies usually return), with what
      // they're entitled to; what they've bought starts again.
      const sponsorRows = await tx.select().from(sponsors).where(eq(sponsors.editionId, source.id));
      const sponsorMap = new Map<string, string>();
      for (const sp of sponsorRows) {
        const [ns] = await tx
          .insert(sponsors)
          .values({
            editionId: target.id,
            companyName: sp.companyName,
            contactName: sp.contactName,
            contactEmail: sp.contactEmail,
            packageName: sp.packageName,
            notes: sp.notes,
          })
          .returning();
        sponsorMap.set(sp.id, ns.id);
        const ents = await tx
          .select()
          .from(sponsorEntitlements)
          .where(eq(sponsorEntitlements.sponsorId, sp.id));
        if (ents.length > 0) {
          await tx.insert(sponsorEntitlements).values(
            ents.map((e) => ({
              sponsorId: ns.id,
              description: e.description,
              quantity: e.quantity,
            })),
          );
        }
      }

      // Every item as a draft: artwork, sign-offs, actual costs and POs
      // cleared. Sponsor signage keeps its sponsor; items for sale are unsold
      // again. Stands keep their own numbering and their panels.
      const items = await tx
        .select()
        .from(signageItems)
        .where(and(eq(signageItems.editionId, source.id), isNull(signageItems.deletedAt)))
        .orderBy(signageItems.seq);
      let seq = 0;
      let standNo = 0;
      let standSeq = 0;
      const idMap = new Map<string, { id: string; ref: string; panels: number }>();
      // Stands before their panels, whatever order they were made in.
      const ordered = [
        ...items.filter((i) => i.kind !== "stand_panel"),
        ...items.filter((i) => i.kind === "stand_panel"),
      ];
      for (const item of ordered) {
        let ref: string;
        let itemSeq: number;
        let parentItemId: string | null = null;
        if (item.kind === "stand_design") {
          standNo += 1;
          standSeq += 1;
          ref = formatStandDesignRef(code, standNo);
          itemSeq = STAND_SEQ_BASE + standSeq;
        } else if (item.kind === "stand_panel") {
          const parent = item.parentItemId ? idMap.get(item.parentItemId) : undefined;
          if (!parent) continue; // its stand wasn't copied
          parent.panels += 1;
          standSeq += 1;
          ref = formatStandPanelRef(parent.ref, parent.panels);
          itemSeq = STAND_SEQ_BASE + standSeq;
          parentItemId = parent.id;
        } else {
          seq += 1;
          ref = `SIG-${code}-${String(seq).padStart(3, "0")}`;
          itemSeq = seq;
        }
        const forSale = item.kind === "sponsorship_item";
        const sponsorId =
          forSale || !item.sponsorId ? null : (sponsorMap.get(item.sponsorId) ?? null);
        const [created] = await tx
          .insert(signageItems)
          .values({
            editionId: target.id,
            ref,
            seq: itemSeq,
            name: item.name,
            description: item.description,
            kind: item.kind,
            parentItemId,
            category: item.category,
            itemTypeId: item.itemTypeId,
            hallId: item.hallId ? (hallMap.get(item.hallId) ?? null) : null,
            locationId: item.locationId ? (locMap.get(item.locationId) ?? null) : null,
            standNumber: item.standNumber,
            ownerRole: item.ownerRole,
            ownerUserId: item.ownerUserId,
            sponsorId,
            sponsorEntitlementId: null,
            isSponsorDeliverable: Boolean(sponsorId),
            signoffs: item.signoffs,
            photoPath: item.photoPath,
            orderByDate: item.orderByDate,
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
          })
          .returning({ id: signageItems.id });
        idMap.set(item.id, { id: created.id, ref, panels: 0 });
      }
      await tx.insert(editionCounters).values([
        { editionId: target.id, key: "signage", value: seq },
        { editionId: target.id, key: "stand_design", value: standNo },
        { editionId: target.id, key: "stand_item", value: standSeq },
      ]);

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: target.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: target.id,
        action: "create",
        after: { code, clonedFrom: source.code, items: idMap.size },
        summary: `Copied ${source.code} → ${code} (${idMap.size} items as drafts)`,
      });
    });
    revalidatePath("/", "layout");
    return success({ code }, `Show ${code} copied from ${source.code}`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const deadlineRowSchema = z.object({
  key: z.enum([
    "stand_design_due",
    "insurance_due",
    "venue_rigging_submission",
    "artwork_due",
    "print_deadline",
    "delivery",
  ]),
  daysBeforeBuildStart: z.coerce.number().int().min(0).max(730),
  overrideDate: z.preprocess(blankToNull, z.string().date().nullable().optional()),
});

const updateSchema = datesSchema
  .extend({
    id: z.string().uuid(),
    // Show deadlines: days before build, or a fixed date that wins. Arrives
    // as JSON from the dialog; leaving it out keeps them as they are.
    deadlines: z.preprocess(
      (v) => (typeof v === "string" ? (v ? JSON.parse(v) : undefined) : v),
      z.array(deadlineRowSchema).max(20).optional(),
    ),
    name: z.string().trim().min(1).max(200),
    status: z.enum(["planning", "live", "closed", "archived"]),
    signageBudget: z.preprocess(blankToNull, z.coerce.number().nonnegative().nullable().optional()),
    venueId: z.preprocess(blankToNull, z.string().uuid().nullable().optional()),
    venueAddress: z.preprocess(blankToNull, z.string().trim().max(500).nullable().optional()),
  })
  .superRefine(checkDateOrder);

/**
 * Edit a show's name, dates, budget and status. Deadlines are worked out
 * from the build start when read, so they move with it. Archiving (which
 * makes the show read-only) is admin-only; an archived show can only be
 * un-archived.
 */
export async function updateEdition(input: unknown): Promise<ActionResult> {
  const parsed = updateSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can edit shows");
  }
  const data = parsed.data;
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, data.id), eq(events.organisationId, session.organisation.id)))
    .limit(1);
  if (!row) return fail("Show not found");
  const current = row.edition;
  const archiving = data.status === "archived" || current.status === "archived";
  if (
    archiving &&
    data.status !== current.status &&
    !can(session.actor, { type: "users.manage" })
  ) {
    return fail("Only an admin can archive or un-archive a show");
  }
  const set =
    current.status === "archived"
      ? { status: data.status }
      : {
          name: data.name,
          status: data.status,
          buildStart: data.buildStart,
          buildEnd: data.buildEnd,
          openStart: data.openStart,
          openEnd: data.openEnd,
          breakdownEnd: data.breakdownEnd,
          signageBudget: data.signageBudget?.toString() ?? null,
          ...(data.venueId ? { venueId: data.venueId } : {}),
        };
  if (data.venueId && current.status !== "archived") {
    const venue = await db.query.venues.findFirst({
      where: and(eq(venues.id, data.venueId), eq(venues.organisationId, session.organisation.id)),
    });
    if (!venue) return fail("That venue wasn't found");
  }
  try {
    await db.transaction(async (tx) => {
      await tx.update(editions).set(set).where(eq(editions.id, current.id));
      if (data.deadlines && current.status !== "archived") {
        for (const d of data.deadlines) {
          await tx
            .insert(editionDeadlines)
            .values({
              editionId: current.id,
              key: d.key,
              label: DEADLINE_LABELS[d.key],
              daysBeforeBuildStart: d.daysBeforeBuildStart,
              overrideDate: d.overrideDate ?? null,
            })
            .onConflictDoUpdate({
              target: [editionDeadlines.editionId, editionDeadlines.key],
              set: {
                daysBeforeBuildStart: d.daysBeforeBuildStart,
                overrideDate: d.overrideDate ?? null,
              },
            });
        }
      }
      // The venue's address is kept on the venue, shared by its shows.
      if (data.venueAddress !== undefined && current.status !== "archived") {
        await tx
          .update(venues)
          .set({ address: data.venueAddress })
          .where(
            and(
              eq(venues.id, data.venueId ?? current.venueId),
              eq(venues.organisationId, session.organisation.id),
            ),
          );
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: current.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: current.id,
        action: "update",
        before: {
          name: current.name,
          status: current.status,
          buildStart: current.buildStart,
          breakdownEnd: current.breakdownEnd,
        },
        after: { ...set, ...(data.deadlines ? { deadlines: data.deadlines } : {}) },
        summary: `Updated show ${current.code}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, `${current.code} saved`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const LOGO_TYPES = ["image/png", "image/jpeg", "image/webp", "image/svg+xml", "image/gif"];

/**
 * Upload or replace a show's logo. Images are shrunk to at most 512px and
 * stored as WebP (SVGs are rasterised, so no scripts are ever served).
 */
export async function uploadShowLogo(formData: FormData): Promise<ActionResult> {
  const editionId = formData.get("editionId");
  const file = formData.get("file");
  if (typeof editionId !== "string" || !z.string().uuid().safeParse(editionId).success) {
    return fail("Invalid request");
  }
  if (!(file instanceof File) || file.size === 0) return fail("Choose an image first");
  if (file.size > 5 * 1024 * 1024) return fail("Logos are limited to 5 MB");
  if (!LOGO_TYPES.includes(file.type)) return fail("Use a PNG, JPG, WebP, GIF or SVG image");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change show logos");
  }
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(editions.id, editionId), eq(events.organisationId, session.organisation.id)))
    .limit(1);
  if (!row) return fail("Show not found");
  if (row.edition.status === "archived") return fail("This show is archived");
  try {
    const { default: sharp } = await import("sharp");
    const webp = await sharp(Buffer.from(await file.arrayBuffer()), { density: 200 })
      .resize({ width: 512, height: 512, fit: "inside", withoutEnlargement: true })
      .webp({ quality: 88 })
      .toBuffer();
    const path = buildStoragePath({
      organisationId: session.organisation.id,
      editionId,
      entityType: "edition",
      entityId: editionId,
      fileName: "logo.webp",
    });
    await putObject("documents", path, webp);
    await db.transaction(async (tx) => {
      await tx.update(editions).set({ logoPath: path }).where(eq(editions.id, editionId));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: editionId,
        action: "update",
        after: { logoPath: path },
        summary: `Logo ${row.edition.logoPath ? "replaced" : "added"} for ${row.edition.code}`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Logo saved");
  } catch (err) {
    console.error("uploadShowLogo", err);
    return fail("Could not read that image — try a PNG or JPG");
  }
}

/** Take a show's logo off (the file stays in storage for the audit trail). */
export async function removeShowLogo(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ editionId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change show logos");
  }
  const [row] = await db
    .select({ edition: editions })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(editions.id, parsed.data.editionId),
        eq(events.organisationId, session.organisation.id),
      ),
    )
    .limit(1);
  if (!row) return fail("Show not found");
  await db.transaction(async (tx) => {
    await tx.update(editions).set({ logoPath: null }).where(eq(editions.id, row.edition.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: row.edition.id,
      actorUserId: session.user.id,
      entityType: "edition",
      entityId: row.edition.id,
      action: "update",
      before: { logoPath: row.edition.logoPath },
      after: { logoPath: null },
      summary: `Logo removed from ${row.edition.code}`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, "Logo removed");
}
