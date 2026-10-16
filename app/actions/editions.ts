"use server";

import { ownEdition } from "@/lib/domain/signage";

import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";
import { z } from "zod";
import { and, eq, gt, isNull, or, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import {
  editionCounters,
  editionDeadlines,
  editions,
  events,
  externalGrants,
  halls,
  locations,
  signageItems,
  sponsorEntitlements,
  sponsors,
  suppliers,
  venues,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { buildStoragePath, putObject } from "@/lib/storage";
import { formatStandDesignRef, formatStandPanelRef, STAND_SEQ_BASE } from "@/lib/refs";
import {
  DEADLINE_LABELS,
  EVENT_DATE_LABELS,
  assumedEventDates,
  datesLike,
  defaultDeadlines,
  firstDateOutOfOrder,
  type EventDates,
} from "@/lib/deadlines";
import { todayInLondon } from "@/lib/today";
import { ensureSignageWorkflow } from "@/lib/domain/departments";
import { LAST_EVENT_COOKIE, LAST_EVENT_COOKIE_MAX_AGE } from "@/lib/queries/editions";
import { CONFIRMABLE_STEPS } from "@/lib/queries/setup";
import { seriesNameFor } from "@/components/setup/naming";

const DATE_ORDER: Array<keyof EventDates> = [
  "buildStart",
  "buildEnd",
  "openStart",
  "openEnd",
  "breakdownEnd",
];

/** Build-up → open → breakdown must run in order; the message for the first that doesn't. */
function dateOrderMessage(d: EventDates): { field: keyof EventDates; message: string } | null {
  const bad = firstDateOutOfOrder(d);
  if (!bad) return null;
  const prev = DATE_ORDER[DATE_ORDER.indexOf(bad) - 1];
  return {
    field: bad,
    message: `${EVENT_DATE_LABELS[bad]} can't be before ${EVENT_DATE_LABELS[prev].toLowerCase()}`,
  };
}

function checkDateOrder(d: EventDates, ctx: z.RefinementCtx) {
  const bad = dateOrderMessage(d);
  if (bad) ctx.addIssue({ code: "custom", path: [bad.field], message: bad.message });
}

/** The first validation issue, as a message and a field error the form can show inline. */
function firstIssue(error: z.ZodError): ActionResult<never> {
  const issue = error.issues[0];
  return fail(issue.message, { [String(issue.path[0] ?? "form")]: issue.message });
}

const codeSchema = z
  .string()
  .trim()
  .min(2, "The reference code needs at least 2 characters")
  .max(20, "Keep the reference code to 20 characters")
  .regex(/^[A-Z0-9-]+$/i, "Use letters, numbers and dashes only in the reference code");

const datesSchema = z.object({
  buildStart: z.string().date(),
  buildEnd: z.string().date(),
  openStart: z.string().date(),
  openEnd: z.string().date(),
  breakdownEnd: z.string().date(),
});

const blankToNull = (v: unknown) => (typeof v === "string" && v.trim() === "" ? null : v);
const optionalDate = z.preprocess(blankToNull, z.string().date().nullable().optional());
const optionalId = z.preprocess(blankToNull, z.string().uuid().nullable().optional());
const optionalText = (max: number) =>
  z.preprocess(blankToNull, z.string().trim().max(max).nullable().optional());
const optionalMoney = z.preprocess(
  blankToNull,
  z.coerce.number().nonnegative("The budget can't be negative").nullable().optional(),
);

/** Remember the event someone just worked on, for pages without one in the address. */
async function rememberEvent(code: string) {
  try {
    (await cookies()).set(LAST_EVENT_COOKIE, code, {
      path: "/",
      maxAge: LAST_EVENT_COOKIE_MAX_AGE,
      sameSite: "lax",
    });
  } catch {
    // Not fatal: the default event is worked out from the dates instead.
  }
}

/** Event codes are unique across the whole platform (they're in every sign ref). */
async function codeInUse(code: string) {
  const clash = await db.query.editions.findFirst({ where: eq(editions.code, code) });
  return Boolean(clash);
}

function codeTaken(code: string): ActionResult<never> {
  const message = `The reference code ${code} is already in use — choose another`;
  return fail(message, { code: message });
}

/** A short unique code from a name ("NEC Birmingham" → "NECBIRMINGHAM", then -2…). */
async function uniqueCode(
  tx: Tx,
  table: typeof events | typeof venues,
  organisationId: string,
  name: string,
) {
  const base =
    name
      .toUpperCase()
      .replace(/[^A-Z0-9]+/g, "")
      .slice(0, 16) || "EVENT";
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

/** The series called `name` (any case), created when there isn't one. */
async function findOrCreateSeries(tx: Tx, organisationId: string, name: string) {
  const [existing] = await tx
    .select({ id: events.id })
    .from(events)
    .where(
      and(eq(events.organisationId, organisationId), sql`lower(${events.name}) = lower(${name})`),
    )
    .limit(1);
  if (existing) return { id: existing.id, created: false };
  const [created] = await tx
    .insert(events)
    .values({ organisationId, name, code: await uniqueCode(tx, events, organisationId, name) })
    .returning({ id: events.id });
  return { id: created.id, created: true };
}

const createSchema = z
  .object({
    name: z.string().trim().min(1, "Give the event a name").max(200),
    code: codeSchema,
    openStart: z.string().date("Choose the day it opens to visitors"),
    openEnd: z.string().date("Choose the day it closes to visitors"),
    // Assumed from the open dates when left out; confirmed on the setup page.
    buildStart: optionalDate,
    buildEnd: optionalDate,
    breakdownEnd: optionalDate,
    // Pick an existing series, type a new one, or leave both out to use the
    // series named like the event (without its year).
    eventId: optionalId,
    newEventName: optionalText(200),
    venueId: optionalId,
    newVenueName: optionalText(200),
    newVenueAddress: optionalText(500),
    signageBudget: optionalMoney,
  })
  .superRefine((d, ctx) => {
    if (!d.venueId && !d.newVenueName) {
      ctx.addIssue({
        code: "custom",
        path: ["venueId"],
        message: "Choose the venue or add a new one",
      });
    }
    if (d.openEnd < d.openStart) {
      ctx.addIssue({
        code: "custom",
        path: ["openEnd"],
        message: "Closes to visitors can't be before it opens",
      });
    }
  });

/**
 * Create an event from the basics. Build-up and breakdown default to the
 * days around the open dates, the series to one named like the event, and
 * the deadlines to the standard offsets; the organisation gets its signage
 * sign-off workflow if it has none yet.
 */
export async function createEdition(
  input: unknown,
): Promise<ActionResult<{ code: string; id: string }>> {
  const parsed = createSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed.error);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can create events");
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const code = data.code.toUpperCase();
  const assumed = assumedEventDates(data.openStart, data.openEnd);
  const dates: EventDates = {
    buildStart: data.buildStart ?? assumed.buildStart,
    buildEnd: data.buildEnd ?? assumed.buildEnd,
    openStart: data.openStart,
    openEnd: data.openEnd,
    breakdownEnd: data.breakdownEnd ?? assumed.breakdownEnd,
  };
  const order = dateOrderMessage(dates);
  if (order) return fail(order.message, { [order.field]: order.message });
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
  if (data.eventId && !event) return fail("That event series wasn't found");
  if (data.venueId && !venue) return fail("That venue wasn't found");
  if (await codeInUse(code)) return codeTaken(code);
  let editionId = "";
  try {
    await db.transaction(async (tx) => {
      let eventId = event?.id;
      let newSeries = false;
      if (!eventId) {
        const series = await findOrCreateSeries(
          tx,
          orgId,
          data.newEventName ?? seriesNameFor(data.name),
        );
        eventId = series.id;
        newSeries = series.created;
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
          ...dates,
          signageBudget: data.signageBudget?.toString() ?? null,
        })
        .returning();
      editionId = edition.id;
      await tx
        .insert(editionDeadlines)
        .values(defaultDeadlines().map((d) => ({ editionId: edition.id, ...d })));
      // Without a signage workflow no sign could ever be sent for sign-off.
      await ensureSignageWorkflow(tx, orgId);
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: edition.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: edition.id,
        action: "create",
        after: { code, name: data.name, ...dates, newSeries, newVenue: !venue },
        summary: `Created event ${code} — ${data.name}`,
      });
    });
  } catch (err) {
    console.error("createEdition", err);
    return fail("The event couldn't be created — please try again");
  }
  await rememberEvent(code);
  revalidatePath("/", "layout");
  return success({ code, id: editionId }, `${data.name} created`);
}

const cloneSchema = z
  .object({
    sourceEditionId: z.string().uuid(),
    name: z.string().trim().min(1, "Give the event a name").max(200),
    code: codeSchema,
    openStart: z.string().date("Choose the day it opens to visitors"),
    openEnd: z.string().date("Choose the day it closes to visitors"),
    // Default to the source's distance from its open dates.
    buildStart: optionalDate,
    buildEnd: optionalDate,
    breakdownEnd: optionalDate,
    // Default: the source's venue.
    venueId: optionalId,
    include: z
      .object({
        halls: z.boolean().default(true),
        deadlines: z.boolean().default(true),
        sponsors: z.boolean().default(true),
        items: z.boolean().default(true),
        access: z.boolean().default(true),
      })
      .default({ halls: true, deadlines: true, sponsors: true, items: true, access: true }),
  })
  .superRefine((d, ctx) => {
    if (d.openEnd < d.openStart) {
      ctx.addIssue({
        code: "custom",
        path: ["openEnd"],
        message: "Closes to visitors can't be before it opens",
      });
    }
  });

export type CloneCounts = {
  halls: number;
  locations: number;
  deadlines: number;
  sponsors: number;
  items: number;
  access: number;
  /** Partner access left behind because it was for a sponsor or exhibitor of the old event. */
  accessSkipped: number;
};

/**
 * Copy an event (brief §9): whatever is ticked of halls and locations,
 * deadline offsets, sponsors with their packages, items as drafts, and
 * partner portal access. Artwork, sign-offs, actual costs and PO numbers
 * always start again.
 */
export async function cloneEdition(
  input: unknown,
): Promise<ActionResult<{ code: string; counts: CloneCounts }>> {
  const parsed = cloneSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed.error);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can copy events");
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const code = data.code.toUpperCase();
  // Only this organisation's events can be copied.
  const source = await ownEdition(db, orgId, data.sourceEditionId);
  if (!source) return fail("Event not found");
  const inherited = datesLike(source, data.openStart, data.openEnd);
  const dates: EventDates = {
    buildStart: data.buildStart ?? inherited.buildStart,
    buildEnd: data.buildEnd ?? inherited.buildEnd,
    openStart: data.openStart,
    openEnd: data.openEnd,
    breakdownEnd: data.breakdownEnd ?? inherited.breakdownEnd,
  };
  const order = dateOrderMessage(dates);
  if (order) return fail(order.message, { [order.field]: order.message });
  const venueId = data.venueId ?? source.venueId;
  if (venueId !== source.venueId) {
    const venue = await db.query.venues.findFirst({
      where: and(eq(venues.id, venueId), eq(venues.organisationId, orgId)),
    });
    if (!venue) return fail("That venue wasn't found");
  }
  if (await codeInUse(code)) return codeTaken(code);
  // Partner access is given by admins only, so only an admin's copy brings it across.
  const copyAccess = data.include.access && can(session.actor, { type: "users.manage" });
  const include = data.include;
  const counts: CloneCounts = {
    halls: 0,
    locations: 0,
    deadlines: 0,
    sponsors: 0,
    items: 0,
    access: 0,
    accessSkipped: 0,
  };

  try {
    await db.transaction(async (tx) => {
      const [target] = await tx
        .insert(editions)
        .values({
          eventId: source.eventId,
          venueId,
          name: data.name,
          code,
          ...dates,
          clonedFromEditionId: source.id,
          signageBudget: source.signageBudget,
          standRequiredDocTypes: source.standRequiredDocTypes,
          complexStructureTriggers: source.complexStructureTriggers,
          logoPath: source.logoPath,
        })
        .returning();

      // Deadline offsets (not fixed dates — those belonged to the old event);
      // the standard ones when they aren't brought across.
      const dls = include.deadlines
        ? await tx.select().from(editionDeadlines).where(eq(editionDeadlines.editionId, source.id))
        : [];
      await tx.insert(editionDeadlines).values(
        dls.length > 0
          ? dls.map((d) => ({
              editionId: target.id,
              key: d.key,
              label: d.label,
              daysBeforeBuildStart: d.daysBeforeBuildStart,
            }))
          : defaultDeadlines().map((d) => ({ editionId: target.id, ...d })),
      );
      counts.deadlines = dls.length;

      // Halls and locations, keeping the mapping for items.
      const hallMap = new Map<string, string>();
      const locMap = new Map<string, string>();
      if (include.halls) {
        const copied = await copyHallsAndLocations(tx, source.id, target.id);
        copied.halls.forEach((v, k) => hallMap.set(k, v));
        copied.locations.forEach((v, k) => locMap.set(k, v));
        counts.halls = copied.halls.size;
        counts.locations = copied.locations.size;
      }

      // Sponsors come across (the same companies usually return), with what
      // they're entitled to; what they've bought starts again.
      const sponsorMap = new Map<string, string>();
      if (include.sponsors) {
        const sponsorRows = await tx
          .select()
          .from(sponsors)
          .where(eq(sponsors.editionId, source.id));
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
        counts.sponsors = sponsorRows.length;
      }

      // Every item as a draft: artwork, sign-offs, actual costs and POs
      // cleared. Sponsor signage keeps its sponsor; items for sale are unsold
      // again. Stands keep their own numbering and their panels.
      const items = include.items
        ? await tx
            .select()
            .from(signageItems)
            .where(and(eq(signageItems.editionId, source.id), isNull(signageItems.deletedAt)))
            .orderBy(signageItems.seq)
        : [];
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
      counts.items = idMap.size;
      await tx.insert(editionCounters).values([
        { editionId: target.id, key: "signage", value: seq },
        { editionId: target.id, key: "stand_design", value: standNo },
        { editionId: target.id, key: "stand_item", value: standSeq },
      ]);

      // Partner portal access: the venue, suppliers, engineers and H&S keep
      // their way in. Sponsor and exhibitor access belonged to the old
      // event's records, so it stays behind (and is counted, to say so).
      if (copyAccess) {
        const grants = await tx
          .select()
          .from(externalGrants)
          .where(
            and(
              eq(externalGrants.editionId, source.id),
              eq(externalGrants.organisationId, orgId),
              isNull(externalGrants.revokedAt),
              or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, new Date())),
            ),
          );
        const liveSuppliers = new Set(
          (
            await tx
              .select({ id: suppliers.id })
              .from(suppliers)
              .where(and(eq(suppliers.organisationId, orgId), eq(suppliers.isArchived, false)))
          ).map((s) => s.id),
        );
        for (const g of grants) {
          const keep =
            g.scopeType === null
              ? g.role === "structural_engineer" || g.role === "hs"
              : g.scopeType === "venue"
                ? g.scopeId === venueId
                : g.scopeType === "supplier"
                  ? g.scopeId != null && liveSuppliers.has(g.scopeId)
                  : false;
          if (!keep) {
            if (g.scopeType === "sponsor" || g.scopeType === "exhibitor") counts.accessSkipped += 1;
            continue;
          }
          await tx.insert(externalGrants).values({
            userId: g.userId,
            invitedEmail: g.invitedEmail,
            organisationId: orgId,
            editionId: target.id,
            role: g.role,
            scopeType: g.scopeType,
            scopeId: g.scopeId,
            expiresAt: g.expiresAt,
            invitedBy: session.user.id,
            // A fresh token nobody is sent: people who already signed up keep
            // their account; anyone who hadn't yet signs in with their email.
            inviteTokenHash: hashInviteToken(generateInviteToken()),
            acceptedAt: g.acceptedAt,
          });
          counts.access += 1;
        }
      }

      await ensureSignageWorkflow(tx, orgId);
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: target.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: target.id,
        action: "create",
        after: { code, clonedFrom: source.code, ...dates, venueId, include, counts },
        summary: `Copied ${source.code} → ${code} (${counts.items} items as drafts)`,
      });
    });
  } catch (err) {
    console.error("cloneEdition", err);
    return fail("The event couldn't be copied — please try again");
  }
  await rememberEvent(code);
  revalidatePath("/", "layout");
  return success({ code, counts }, `${data.name} created from ${source.name}`);
}

/** Copy one event's halls and locations to another; returns old → new ids. */
async function copyHallsAndLocations(tx: Tx, sourceId: string, targetId: string) {
  const hallRows = await tx
    .select()
    .from(halls)
    .where(eq(halls.editionId, sourceId))
    .orderBy(halls.sortOrder, halls.name);
  const hallMap = new Map<string, string>();
  const locMap = new Map<string, string>();
  for (const h of hallRows) {
    const [nh] = await tx
      .insert(halls)
      .values({ editionId: targetId, name: h.name, sortOrder: h.sortOrder })
      .returning({ id: halls.id });
    hallMap.set(h.id, nh.id);
    const locs = await tx.select().from(locations).where(eq(locations.hallId, h.id));
    for (const l of locs) {
      const [nl] = await tx
        .insert(locations)
        .values({
          hallId: nh.id,
          name: l.name,
          zone: l.zone,
          xPct: l.xPct,
          yPct: l.yPct,
          nearStandNumber: l.nearStandNumber,
        })
        .returning({ id: locations.id });
      locMap.set(l.id, nl.id);
    }
  }
  return { halls: hallMap, locations: locMap };
}

/** The event, if it belongs to the caller's organisation. */
async function editionForSession(session: Session, editionId: string) {
  return ownEdition(db, session.organisation.id, editionId);
}

/** Add a confirmed setup step to the list (no duplicates). */
function withChecked(current: string[] | null, key: string): string[] {
  const list = current ?? [];
  return list.includes(key) ? list : [...list, key];
}

const detailsSchema = datesSchema
  .extend({
    id: z.string().uuid(),
    name: z.string().trim().min(1, "Give the event a name").max(200),
    signageBudget: optionalMoney,
    venueId: optionalId,
    newVenueName: optionalText(200),
    venueAddress: optionalText(500),
    eventId: optionalId,
    newEventName: optionalText(200),
  })
  .superRefine((d, ctx) => {
    if (!d.venueId && !d.newVenueName) {
      ctx.addIssue({
        code: "custom",
        path: ["venueId"],
        message: "Choose the venue or add a new one",
      });
    }
    checkDateOrder(d, ctx);
  });

/**
 * Setup step 1: the event's name, dates, venue (and its address, shared by
 * every event there), series and signage budget. Saving marks the step done.
 */
export async function saveEventDetails(input: unknown): Promise<ActionResult> {
  const parsed = detailsSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed.error);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change event details");
  }
  const data = parsed.data;
  const orgId = session.organisation.id;
  const current = await editionForSession(session, data.id);
  if (!current) return fail("Event not found");
  if (current.status === "archived") return fail("This event is archived and read-only");
  const [venue, series] = await Promise.all([
    data.venueId
      ? db.query.venues.findFirst({
          where: and(eq(venues.id, data.venueId), eq(venues.organisationId, orgId)),
        })
      : null,
    data.eventId
      ? db.query.events.findFirst({
          where: and(eq(events.id, data.eventId), eq(events.organisationId, orgId)),
        })
      : null,
  ]);
  if (data.venueId && !venue) return fail("That venue wasn't found");
  if (data.eventId && !series) return fail("That event series wasn't found");
  try {
    await db.transaction(async (tx) => {
      let venueId = venue?.id;
      if (!venueId) {
        const [created] = await tx
          .insert(venues)
          .values({
            organisationId: orgId,
            name: data.newVenueName!,
            code: await uniqueCode(tx, venues, orgId, data.newVenueName!),
            address: data.venueAddress ?? null,
          })
          .returning({ id: venues.id });
        venueId = created.id;
      } else if (data.venueAddress !== undefined && data.venueAddress !== venue?.address) {
        // The address lives on the venue, shared by every event there.
        await tx
          .update(venues)
          .set({ address: data.venueAddress })
          .where(and(eq(venues.id, venueId), eq(venues.organisationId, orgId)));
      }
      let eventId = series?.id ?? current.eventId;
      if (!series && data.newEventName) {
        eventId = (await findOrCreateSeries(tx, orgId, data.newEventName)).id;
      }
      const set = {
        name: data.name,
        buildStart: data.buildStart,
        buildEnd: data.buildEnd,
        openStart: data.openStart,
        openEnd: data.openEnd,
        breakdownEnd: data.breakdownEnd,
        signageBudget: data.signageBudget?.toString() ?? null,
        venueId,
        eventId,
        setupChecked: withChecked(current.setupChecked, "details"),
      };
      await tx.update(editions).set(set).where(eq(editions.id, current.id));
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: current.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: current.id,
        action: "update",
        before: {
          name: current.name,
          buildStart: current.buildStart,
          buildEnd: current.buildEnd,
          openStart: current.openStart,
          openEnd: current.openEnd,
          breakdownEnd: current.breakdownEnd,
          signageBudget: current.signageBudget,
          venueId: current.venueId,
          eventId: current.eventId,
        },
        after: set,
        summary: `Updated the details of ${current.code}`,
      });
    });
  } catch (err) {
    console.error("saveEventDetails", err);
    return fail("The details couldn't be saved — please try again");
  }
  revalidatePath("/", "layout");
  return success(undefined, "Details saved");
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
  daysBeforeBuildStart: z.coerce
    .number()
    .int("Use whole days")
    .min(0, "Days before build-up can't be negative")
    .max(730, "Keep deadlines within two years of build-up"),
  overrideDate: z.preprocess(blankToNull, z.string().date().nullable().optional()),
});

/**
 * Setup step 3: each deadline as days before build-up starts, or a fixed
 * date that wins. Saving marks the step done.
 */
export async function saveEventDeadlines(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({
      editionId: z.string().uuid(),
      deadlines: z.array(deadlineRowSchema).max(20),
    })
    .safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change deadlines");
  }
  const current = await editionForSession(session, parsed.data.editionId);
  if (!current) return fail("Event not found");
  if (current.status === "archived") return fail("This event is archived and read-only");
  try {
    await db.transaction(async (tx) => {
      for (const d of parsed.data.deadlines) {
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
      await tx
        .update(editions)
        .set({ setupChecked: withChecked(current.setupChecked, "deadlines") })
        .where(eq(editions.id, current.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: current.id,
        actorUserId: session.user.id,
        entityType: "edition",
        entityId: current.id,
        action: "update",
        after: { deadlines: parsed.data.deadlines },
        summary: `Updated the deadlines of ${current.code}`,
      });
    });
  } catch (err) {
    console.error("saveEventDeadlines", err);
    return fail("The deadlines couldn't be saved — please try again");
  }
  revalidatePath("/", "layout");
  return success(undefined, "Deadlines saved");
}

/**
 * Tick off a setup step that can't be read from the data ("These look
 * right"), or hide the dashboard's setup card ("dismissed").
 */
export async function confirmSetupStep(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ editionId: z.string().uuid(), key: z.enum(CONFIRMABLE_STEPS) })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can set up events");
  }
  const current = await editionForSession(session, parsed.data.editionId);
  if (!current) return fail("Event not found");
  if (current.status === "archived") return fail("This event is archived and read-only");
  const { key } = parsed.data;
  const next = withChecked(current.setupChecked, key);
  if (next === current.setupChecked) return success(undefined, "Already done");
  await db.transaction(async (tx) => {
    await tx.update(editions).set({ setupChecked: next }).where(eq(editions.id, current.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: current.id,
      actorUserId: session.user.id,
      entityType: "edition",
      entityId: current.id,
      action: "update",
      before: { setupChecked: current.setupChecked },
      after: { setupChecked: next },
      summary:
        key === "dismissed"
          ? `Hid the setup card for ${current.code}`
          : `Confirmed the ${key} of ${current.code}`,
    });
  });
  revalidatePath("/", "layout");
  return success(
    undefined,
    key === "dismissed" ? "Hidden — setup is still under Event details" : "Marked as done",
  );
}

/**
 * Archive an event (read-only for everyone) or bring it back. Admin-only,
 * as before; an event brought back is Planning until it has finished, then
 * Closed.
 */
export async function setEditionArchived(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only an admin can archive or bring back an event");
  }
  const current = await editionForSession(session, parsed.data.id);
  if (!current) return fail("Event not found");
  const archived = parsed.data.archived;
  if ((current.status === "archived") === archived) {
    return success(undefined, archived ? "Already archived" : "Already active");
  }
  const status = archived
    ? ("archived" as const)
    : current.breakdownEnd < todayInLondon()
      ? ("closed" as const)
      : ("planning" as const);
  await db.transaction(async (tx) => {
    await tx.update(editions).set({ status }).where(eq(editions.id, current.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: current.id,
      actorUserId: session.user.id,
      entityType: "edition",
      entityId: current.id,
      action: "status_change",
      before: { status: current.status },
      after: { status },
      summary: archived ? `Archived ${current.code}` : `Brought back ${current.code}`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, archived ? `${current.name} archived` : `${current.name} is back`);
}

const updateSchema = datesSchema
  .extend({
    id: z.string().uuid(),
    // Deadlines: days before build-up, or a fixed date that wins. Arrives as
    // JSON from a form; leaving it out keeps them as they are.
    deadlines: z.preprocess((v) => {
      if (typeof v !== "string") return v;
      if (!v) return undefined;
      try {
        return JSON.parse(v);
      } catch {
        return v; // not an array → an ordinary validation issue, not a crash
      }
    }, z.array(deadlineRowSchema).max(20).optional()),
    name: z.string().trim().min(1).max(200),
    status: z.enum(["planning", "live", "closed", "archived"]),
    signageBudget: optionalMoney,
    venueId: optionalId,
    venueAddress: optionalText(500),
  })
  .superRefine(checkDateOrder);

/**
 * Edit an event's name, dates, budget and status in one go. Deadlines are
 * worked out from build-up start when read, so they move with it. Archiving
 * (which makes the event read-only) is admin-only; an archived event can only
 * be brought back.
 */
export async function updateEdition(input: unknown): Promise<ActionResult> {
  const parsed = updateSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can edit events");
  }
  const data = parsed.data;
  const current = await editionForSession(session, data.id);
  if (!current) return fail("Event not found");
  const archiving = data.status === "archived" || current.status === "archived";
  if (
    archiving &&
    data.status !== current.status &&
    !can(session.actor, { type: "users.manage" })
  ) {
    return fail("Only an admin can archive or bring back an event");
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
      // The venue's address is kept on the venue, shared by its events.
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
        summary: `Updated event ${current.code}`,
      });
    });
  } catch (err) {
    console.error("updateEdition", err);
    return fail("The event couldn't be saved — please try again");
  }
  revalidatePath("/", "layout");
  return success(undefined, `${current.code} saved`);
}

const LOGO_TYPES = ["image/png", "image/jpeg", "image/webp", "image/svg+xml", "image/gif"];

/**
 * Upload or replace an event's logo. Images are shrunk to at most 512px and
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
    return fail("Only admins and Operations can change event logos");
  }
  const edition = await editionForSession(session, editionId);
  if (!edition) return fail("Event not found");
  if (edition.status === "archived") return fail("This event is archived and read-only");
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
        summary: `Logo ${edition.logoPath ? "replaced" : "added"} for ${edition.code}`,
      });
    });
  } catch (err) {
    console.error("uploadShowLogo", err);
    return fail("Could not read that image — try a PNG or JPG");
  }
  revalidatePath("/", "layout");
  return success(undefined, "Logo saved");
}

/** Take an event's logo off (the file stays in storage for the audit trail). */
export async function removeShowLogo(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ editionId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and Operations can change event logos");
  }
  const edition = await editionForSession(session, parsed.data.editionId);
  if (!edition) return fail("Event not found");
  if (edition.status === "archived") return fail("This event is archived and read-only");
  await db.transaction(async (tx) => {
    await tx.update(editions).set({ logoPath: null }).where(eq(editions.id, edition.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "edition",
      entityId: edition.id,
      action: "update",
      before: { logoPath: edition.logoPath },
      after: { logoPath: null },
      summary: `Logo removed from ${edition.code}`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, "Logo removed");
}
