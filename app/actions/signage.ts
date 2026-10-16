"use server";

import { unstable_rethrow } from "next/navigation";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, desc, eq, inArray, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  auditLog,
  locations,
  memberships,
  signageItems,
  snags,
  suppliers,
  users,
} from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { accessLive } from "@/lib/access";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import {
  IllegalTransitionError,
  INVALIDATABLE_STATUSES,
  signageTransition,
  type SignageStatus,
} from "@/lib/status/signage";
import { applyHoldShift, effectiveSignoffs, sameSignoffs } from "@/lib/workflow";
import { loadRun, loadStepDefs, persistRun } from "@/lib/workflow/persist";
import { nextSignageRef } from "@/lib/refs";
import { notify } from "@/lib/notify";
import {
  askedSummary,
  archivedSupplierMessage,
  assertItemLinks,
  changedSpecKeys,
  defaultSignageWorkflowId,
  itemAuthzCtx,
  loadItemBundle,
  newArtworkSinceChanges,
  normaliseSignoffs,
  notifyPendingAssignees,
  ownEdition,
  resolveItemCreationRecipients,
  resubmitItemInTx,
  startItemRun,
  submitItemInTx,
  syncConfirmationDueDates,
} from "@/lib/domain/signage";
import { diffDaysIso } from "@/lib/deadlines";
import { settleApprovalNotifications } from "@/lib/domain/notifications";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { itemPath } from "@/lib/edition-path";

const itemFields = z.object({
  name: z.string().trim().min(1, "Name is required").max(300),
  description: z.string().max(5000).optional().nullable(),
  category: z.enum(["organiser", "sponsor"]).optional().nullable(),
  // Sign-off choices arrive as JSON from the form's hidden field.
  signoffs: z
    .preprocess(
      (v) => {
        if (typeof v !== "string") return v;
        if (!v) return null;
        try {
          return JSON.parse(v);
        } catch {
          return v; // not an array → an ordinary validation issue, not a crash
        }
      },
      z
        .array(z.object({ stepId: z.string().uuid(), userId: z.string().uuid().nullable() }))
        .max(20)
        .nullable(),
    )
    .optional(),
  itemTypeId: z.string().uuid().optional().nullable(),
  hallId: z.string().uuid().optional().nullable(),
  locationId: z.string().uuid().optional().nullable(),
  standNumber: z.string().trim().max(50).optional().nullable(),
  ownerRole: z.enum(["ops", "marketing"]).default("ops"),
  /** The person responsible; must be on the team (not a viewer). */
  ownerUserId: z.string().uuid().optional().nullable(),
  sponsorId: z.string().uuid().optional().nullable(),
  sponsorEntitlementId: z.string().uuid().optional().nullable(),
  widthMm: z.coerce.number().int().positive().optional().nullable(),
  heightMm: z.coerce.number().int().positive().optional().nullable(),
  depthMm: z.coerce.number().int().positive().optional().nullable(),
  quantity: z.coerce.number().int().positive().default(1),
  sided: z.enum(["single", "double"]).default("single"),
  material: z.string().max(200).optional().nullable(),
  finish: z.string().max(200).optional().nullable(),
  fixingMethod: z
    .enum(["rigged", "freestanding", "wall_mounted", "shell_mounted", "floor", "digital", "other"])
    .optional()
    .nullable(),
  weightKg: z.coerce.number().nonnegative().optional().nullable(),
  requiresVenueApproval: z.coerce.boolean().optional(),
  requiresEventDirector: z.coerce.boolean().optional(),
  budgetLine: z.string().max(200).optional().nullable(),
  costEstimate: z.coerce.number().nonnegative().optional().nullable(),
  costActual: z.coerce.number().nonnegative().optional().nullable(),
  poNumber: z.string().max(100).optional().nullable(),
  supplierId: z.string().uuid().optional().nullable(),
  artworkDueOverride: z.string().date().optional().nullable(),
  printDeadline: z.string().date().optional().nullable(),
  orderByDate: z.string().date().optional().nullable(),
  salePrice: z.coerce.number().nonnegative().optional().nullable(),
  deliveryDate: z.string().date().optional().nullable(),
  installDate: z.string().date().optional().nullable(),
  installSlot: z.enum(["am", "pm", "overnight"]).optional().nullable(),
  installContractorId: z.string().uuid().optional().nullable(),
});

const createSchema = itemFields
  .extend({
    editionId: z.string().uuid(),
    kind: z.enum(["signage", "sponsorship_item"]).default("signage"),
    workflowId: z.string().uuid().optional().nullable(),
  })
  .superRefine((data, ctx) => {
    // Sponsor signage is sold already; sponsorship items can wait for a buyer.
    if (data.kind === "signage" && data.category === "sponsor" && !data.sponsorId) {
      ctx.addIssue({
        code: "custom",
        path: ["sponsorId"],
        message: "Choose the sponsor who bought it",
      });
    }
  });

/**
 * Check a picked owner is on the team and can own things (not a viewer).
 * Returns their role so the item's owning team can follow them.
 */
async function resolveOwner(
  organisationId: string,
  userId: string,
): Promise<{ role: "ops" | "marketing" | null; name: string }> {
  const [row] = await db
    .select({
      role: memberships.role,
      fullName: users.fullName,
      email: users.email,
      suspendedAt: memberships.suspendedAt,
      accessEndsAt: memberships.accessEndsAt,
    })
    .from(memberships)
    .innerJoin(users, eq(memberships.userId, users.id))
    .where(and(eq(memberships.organisationId, organisationId), eq(memberships.userId, userId)))
    .limit(1);
  if (!row) throw new Error("The owner must be someone on your team");
  if (row.role === "viewer") throw new Error("A viewer can't own items — pick someone else");
  if (!accessLive(row)) {
    throw new Error(
      `${row.fullName || row.email}'s access is paused or has ended — pick someone else`,
    );
  }
  return {
    role: row.role === "ops" || row.role === "marketing" ? row.role : null,
    name: row.fullName || row.email,
  };
}

/**
 * Archived suppliers stay on the items that already have them but can't be
 * picked again. Null when the choice is fine (none, unchanged, or live).
 */
async function archivedSupplierError(
  organisationId: string,
  supplierId: string | null | undefined,
  current: string | null = null,
): Promise<string | null> {
  if (!supplierId || supplierId === current) return null;
  const [row] = await db
    .select({ name: suppliers.name, isArchived: suppliers.isArchived })
    .from(suppliers)
    .where(and(eq(suppliers.id, supplierId), eq(suppliers.organisationId, organisationId)))
    .limit(1);
  return row?.isArchived ? archivedSupplierMessage(row.name) : null;
}

function num(v: number | null | undefined): string | null {
  return v == null ? null : String(v);
}

/** Rigged items are always flagged for venue approval (brief 6.1). */
function applyRiggedRule<
  T extends { fixingMethod?: string | null; requiresVenueApproval?: boolean },
>(data: T): T {
  if (data.fixingMethod === "rigged") return { ...data, requiresVenueApproval: true };
  return data;
}

export async function createSignageItem(input: unknown): Promise<ActionResult<{ ref: string }>> {
  const parsed = createSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", zodErrors(parsed.error));
  const session = await requireSession();
  const createAction =
    parsed.data.kind === "sponsorship_item"
      ? ({ type: "sponsorship.create" } as const)
      : ({ type: "signage.create" } as const);
  if (!can(session.actor, createAction)) return fail("You cannot create items");

  const data = applyRiggedRule(parsed.data);
  // Sponsorship items are always sponsor signage; anything else defaults to
  // the organiser's own.
  const category = data.kind === "sponsorship_item" ? "sponsor" : (data.category ?? "organiser");
  // The show and everything linked must be this organisation's.
  if (!(await ownEdition(db, session.organisation.id, data.editionId))) {
    return fail("Event not found");
  }
  const supplierError = await archivedSupplierError(session.organisation.id, data.supplierId);
  if (supplierError) return fail(supplierError, { supplierId: supplierError });
  // Whoever is picked owns it (default: the person creating it); the owning
  // team follows an ops or marketing owner.
  let ownerUserId = session.user.id;
  let ownerRole = data.ownerRole;
  if (!data.ownerUserId || data.ownerUserId === session.user.id) {
    // "Me": the owning team is the creator's own team when it is one of the
    // two that own items; admins and sales keep the form's default.
    const own = session.actor.kind === "staff" ? session.actor.role : null;
    if (own === "ops" || own === "marketing") ownerRole = own;
  } else {
    try {
      const owner = await resolveOwner(session.organisation.id, data.ownerUserId);
      ownerUserId = data.ownerUserId;
      ownerRole = owner.role ?? ownerRole;
    } catch (err) {
      return fail(errMessage(err), { ownerUserId: errMessage(err) });
    }
  }
  try {
    await assertItemLinks(db, {
      organisationId: session.organisation.id,
      editionId: data.editionId,
      links: data,
    });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Check the linked records");
  }
  // The hall always follows the chosen location.
  if (data.locationId) data.hallId = (await hallOfLocation(data.locationId)) ?? data.hallId;
  try {
    const ref = await db.transaction(async (tx) => {
      const workflowId =
        data.workflowId ??
        (await defaultSignageWorkflowId(tx, session.organisation.id, data.itemTypeId ?? null));
      const signoffs = await normaliseSignoffs(tx, {
        organisationId: session.organisation.id,
        workflowId,
        category,
        plan: data.signoffs,
      });
      // Locking not needed here; the counter row lock serialises the seq.
      const [edition] = await tx.execute<{ code: string; status: string }>(
        sql`SELECT code, status FROM editions WHERE id = ${data.editionId}`,
      );
      if (!edition) throw new Error("Event not found");
      if (editionIsReadOnly(edition.status)) throw new Error(EDITION_LOCKED_MESSAGE);
      const { ref, seq } = await nextSignageRef(tx, data.editionId, edition.code);
      const [item] = await tx
        .insert(signageItems)
        .values({
          editionId: data.editionId,
          ref,
          seq,
          name: data.name,
          description: data.description ?? null,
          kind: data.kind,
          category,
          signoffs,
          itemTypeId: data.itemTypeId ?? null,
          hallId: data.hallId ?? null,
          locationId: data.locationId ?? null,
          standNumber: data.standNumber || null,
          ownerRole,
          ownerUserId,
          sponsorId: data.sponsorId ?? null,
          sponsorEntitlementId: data.sponsorEntitlementId ?? null,
          isSponsorDeliverable: Boolean(data.sponsorId),
          soldAt: data.sponsorId ? new Date() : null,
          salePrice: data.sponsorId ? num(data.salePrice) : null,
          orderByDate: data.orderByDate ?? null,
          widthMm: data.widthMm ?? null,
          heightMm: data.heightMm ?? null,
          depthMm: data.depthMm ?? null,
          quantity: data.quantity,
          sided: data.sided,
          material: data.material ?? null,
          finish: data.finish ?? null,
          fixingMethod: data.fixingMethod ?? null,
          weightKg: num(data.weightKg),
          requiresVenueApproval: data.requiresVenueApproval ?? false,
          requiresEventDirector: data.requiresEventDirector ?? false,
          budgetLine: data.budgetLine ?? null,
          costEstimate: num(data.costEstimate),
          supplierId: data.supplierId ?? null,
          artworkDueOverride: data.artworkDueOverride ?? null,
          printDeadline: data.printDeadline ?? null,
          deliveryDate: data.deliveryDate ?? null,
          installDate: data.installDate ?? null,
          installSlot: data.installSlot ?? null,
          installContractorId: data.installContractorId ?? null,
          workflowId,
          createdBy: session.user.id,
        })
        .returning();
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: data.editionId,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: item.id,
        action: "create",
        after: { ref, name: data.name },
        summary: `Created ${ref} — ${data.name}`,
      });
      // The owning team (and sales, for anything sponsorship) hears about
      // every new item straight away, not only at submit-for-review.
      const recipients = await resolveItemCreationRecipients(
        tx,
        session.organisation.id,
        { kind: data.kind, category, ownerRole },
        session.user.id,
      );
      if (ownerUserId !== session.user.id) recipients.push(ownerUserId);
      await notify(tx, {
        userIds: recipients,
        kind: "item_created",
        title: `New ${data.kind === "sponsorship_item" ? "sponsorship item" : "signage"}: ${ref} — ${data.name}`,
        link: itemPath(edition.code, { kind: data.kind, ref }),
        entityType: "signage_item",
        entityId: item.id,
      });
      return ref;
    });
    revalidatePath("/", "layout");
    return success({ ref }, `${ref} created`);
  } catch (err) {
    return fail(errMessage(err));
  }
}

const updateSchema = itemFields.partial().extend({ id: z.string().uuid() });

export async function updateSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = updateSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", zodErrors(parsed.error));
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot edit this item");
  }
  // Costs, PO and supplier: costs.edit, or a sponsorship item they may edit.
  const canEditCosts = can(session.actor, { type: "costs.edit", item: itemAuthzCtx(bundle) });
  const { id, ...patchRaw } = parsed.data;
  const patch = applyRiggedRule(patchRaw);
  // A panel's place, owner and sign-off come from its stand and change there.
  if (bundle.item.kind === "stand_panel") {
    for (const key of [
      "hallId",
      "locationId",
      "standNumber",
      "category",
      "sponsorId",
      "signoffs",
    ] as const) {
      delete patch[key];
    }
  }
  if (patch.locationId) patch.hallId = (await hallOfLocation(patch.locationId)) ?? patch.hallId;
  // A new owner must be on the team; the owning team follows them.
  let newOwner: { id: string; name: string } | null = null;
  if (patch.ownerUserId && patch.ownerUserId !== bundle.item.ownerUserId) {
    try {
      const owner = await resolveOwner(session.organisation.id, patch.ownerUserId);
      newOwner = { id: patch.ownerUserId, name: owner.name };
      if (owner.role) patch.ownerRole = owner.role;
    } catch (err) {
      return fail(errMessage(err), { ownerUserId: errMessage(err) });
    }
  } else {
    delete patch.ownerUserId;
  }

  if (canEditCosts) {
    const supplierError = await archivedSupplierError(
      session.organisation.id,
      patch.supplierId,
      bundle.item.supplierId,
    );
    if (supplierError) return fail(supplierError, { supplierId: supplierError });
  }

  try {
    await assertItemLinks(db, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      links: patch,
      currentSupplierId: bundle.item.supplierId,
    });
    const outcome = await db.transaction(async (tx) => {
      const set: Partial<typeof signageItems.$inferInsert> = {};
      const assign = <K extends keyof typeof patch>(key: K, dbKey: keyof typeof set) => {
        if (patch[key] !== undefined)
          (set as Record<string, unknown>)[dbKey as string] = patch[key];
      };
      assign("name", "name");
      assign("description", "description");
      assign("category", "category");
      assign("itemTypeId", "itemTypeId");
      assign("hallId", "hallId");
      assign("locationId", "locationId");
      assign("standNumber", "standNumber");
      assign("ownerRole", "ownerRole");
      assign("ownerUserId", "ownerUserId");
      assign("sponsorId", "sponsorId");
      assign("sponsorEntitlementId", "sponsorEntitlementId");
      assign("widthMm", "widthMm");
      assign("heightMm", "heightMm");
      assign("depthMm", "depthMm");
      assign("quantity", "quantity");
      assign("sided", "sided");
      assign("material", "material");
      assign("finish", "finish");
      assign("fixingMethod", "fixingMethod");
      assign("requiresVenueApproval", "requiresVenueApproval");
      assign("requiresEventDirector", "requiresEventDirector");
      assign("installDate", "installDate");
      assign("installSlot", "installSlot");
      assign("installContractorId", "installContractorId");
      assign("artworkDueOverride", "artworkDueOverride");
      assign("printDeadline", "printDeadline");
      assign("deliveryDate", "deliveryDate");
      assign("orderByDate", "orderByDate");
      if (patch.weightKg !== undefined) set.weightKg = num(patch.weightKg);
      if (patch.salePrice !== undefined) set.salePrice = num(patch.salePrice);
      // Whoever runs a sponsorship item also buys it: supplier and cost.
      if (canEditCosts) {
        assign("budgetLine", "budgetLine");
        assign("poNumber", "poNumber");
        assign("supplierId", "supplierId");
        if (patch.costEstimate !== undefined) set.costEstimate = num(patch.costEstimate);
        if (patch.costActual !== undefined) set.costActual = num(patch.costActual);
      }
      // Sponsorship items stay sponsor signage.
      if (bundle.item.kind === "sponsorship_item") delete set.category;
      // The form posts every field; keep only real changes so History and
      // the sign-off rules see what actually moved.
      for (const key of Object.keys(set) as Array<keyof typeof set>) {
        if (sameValue((bundle.item as Record<string, unknown>)[key], set[key])) delete set[key];
      }

      const item = bundle.item;
      const nextCategory = (set.category ?? item.category ?? "organiser") as
        "organiser" | "sponsor";
      const nextSponsor = set.sponsorId !== undefined ? set.sponsorId : item.sponsorId;
      // Sold or unsold: the sale date follows the sponsor; no sponsor, no price.
      if (set.sponsorId !== undefined) set.soldAt = nextSponsor ? new Date() : null;
      if (!nextSponsor) {
        if (item.salePrice !== null) set.salePrice = null;
        else delete set.salePrice;
      }
      if (item.kind === "signage" && nextCategory === "sponsor" && !nextSponsor) {
        throw new Error("Sponsor signage needs a sponsor — choose who bought it");
      }

      // Who signs off: compare what would actually run before and after.
      const workflowId =
        item.workflowId ??
        (await defaultSignageWorkflowId(tx, session.organisation.id, item.itemTypeId));
      let signoffsChanged = false;
      if (patch.signoffs !== undefined || set.category !== undefined) {
        const nextPlan =
          patch.signoffs !== undefined
            ? await normaliseSignoffs(tx, {
                organisationId: session.organisation.id,
                workflowId,
                category: nextCategory,
                plan: patch.signoffs,
              })
            : (item.signoffs ?? null);
        const steps = workflowId ? await loadStepDefs(tx, workflowId) : [];
        const before = effectiveSignoffs(steps, item.category, item.signoffs ?? null);
        const after = effectiveSignoffs(steps, nextCategory, nextPlan);
        signoffsChanged = !sameSignoffs(before, after);
        if (JSON.stringify(nextPlan) !== JSON.stringify(item.signoffs ?? null)) {
          set.signoffs = nextPlan;
        }
      }
      if (Object.keys(set).length === 0) return "unchanged" as const;

      const specChanged = changedSpecKeys(item as Record<string, unknown>, set);
      let restarted = false;
      if (signoffsChanged && specChanged.length === 0) {
        if (["installed", "snagged", "closed"].includes(item.status)) {
          throw new Error("This item is already installed — who signs it off can no longer change");
        }
        if (INVALIDATABLE_STATUSES.includes(item.status)) {
          set.status = signageTransition(item.status, "new_version_after_approval");
          restarted = true;
        } else if (item.status === "in_review" && item.currentRunNumber > 0) {
          restarted = true;
        }
      }
      if (specChanged.length > 0) {
        if (["installed", "snagged", "closed"].includes(item.status)) {
          throw new Error(
            `This item is already installed — its ${specChanged.join(", ")} can no longer change`,
          );
        }
        if (INVALIDATABLE_STATUSES.includes(item.status)) {
          // What was approved no longer matches: sign-off starts again.
          set.status = signageTransition(item.status, "new_version_after_approval");
          restarted = true;
        } else if (item.status === "in_review" && item.currentRunNumber > 0) {
          const run = await loadRun(tx, "signage_item", item.id, item.currentRunNumber);
          restarted = run.some(
            (i) =>
              i.stepKind === "approval" &&
              ["approved", "approved_with_conditions"].includes(i.status),
          );
        }
      }

      await tx.update(signageItems).set(set).where(eq(signageItems.id, id));
      // A moved date moves the matching confirmation step's due date too.
      await syncConfirmationDueDates(tx, item, set);
      if (restarted) {
        const updated = { ...bundle, item: { ...item, ...set } as typeof item };
        const instances = await startItemRun(tx, updated, new Date());
        // The old round's requests are over; the new round's are sent next.
        await settleApprovalNotifications(tx, "signage_item", item.id, {
          newlyPending: instances.filter((i) => i.status === "pending").map((i) => i.id),
        });
        await notifyPendingAssignees(tx, updated, instances);
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: id,
        action: "update",
        before: pickKeys(item, Object.keys(set)),
        after: set,
        summary: `Updated ${item.ref} (${Object.keys(set).join(", ")})${
          newOwner && set.ownerUserId ? ` — owner changed to ${newOwner.name}` : ""
        }${restarted ? " — sign-off restarted" : ""}`,
      });
      if (newOwner && set.ownerUserId && newOwner.id !== session.user.id) {
        await notify(tx, {
          userIds: [newOwner.id],
          kind: "item_created",
          title: `You now own ${item.ref} — ${item.name}`,
          link: itemPath(bundle.edition.code, item),
          entityType: "signage_item",
          entityId: item.id,
        });
      }
      return restarted ? ("restarted" as const) : ("saved" as const);
    });
    revalidatePath("/", "layout");
    if (outcome === "unchanged") return success(undefined, "No changes to save");
    return success(
      undefined,
      outcome === "restarted"
        ? `${bundle.item.ref} saved — sign-off has restarted and the approvers have been told`
        : `${bundle.item.ref} saved`,
    );
  } catch (err) {
    return fail(errMessage(err));
  }
}

async function hallOfLocation(locationId: string): Promise<string | null> {
  const [row] = await db
    .select({ hallId: locations.hallId })
    .from(locations)
    .where(eq(locations.id, locationId))
    .limit(1);
  return row?.hallId ?? null;
}

/** Equality for stored vs submitted values ("1200.00" == 1200, null == ""). */
function sameValue(a: unknown, b: unknown): boolean {
  const norm = (v: unknown) => (v === null || v === undefined || v === "" ? "" : v);
  const x = norm(a);
  const y = norm(b);
  if (x === "" || y === "") return x === y;
  const nx = Number(x);
  const ny = Number(y);
  if (
    typeof x !== "boolean" &&
    typeof y !== "boolean" &&
    Number.isFinite(nx) &&
    Number.isFinite(ny)
  ) {
    return nx === ny;
  }
  return String(x) === String(y);
}

export async function softDeleteSignageItem(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    const bundle = await loadItemBundle(db, parsed.data.id, {
      organisationId: session.organisation.id,
    });
    if (!bundle || bundle.item.deletedAt) return fail("Item not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    if (!can(session.actor, { type: "signage.delete" })) return fail("You cannot delete items");
    await db.transaction(async (tx) => {
      await tx
        .update(signageItems)
        .set({ deletedAt: new Date() })
        .where(eq(signageItems.id, parsed.data.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: parsed.data.id,
        action: "soft_delete",
        summary: `Deleted ${bundle.item.ref} — ${bundle.item.name}`,
      });
      // Nobody is asked to sign off a deleted item any more.
      await settleApprovalNotifications(tx, "signage_item", parsed.data.id);
    });
    revalidatePath("/", "layout");
    return success(
      undefined,
      `Deleted ${bundle.item.ref} — restore it from Recently deleted on the Signage page`,
    );
  } catch (err) {
    unstable_rethrow(err);
    console.error("softDeleteSignageItem", err);
    return fail("Could not save — please try again");
  }
}

export async function restoreSignageItem(
  input: unknown,
): Promise<ActionResult<{ ref: string; href: string }>> {
  try {
    const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    const bundle = await loadItemBundle(db, parsed.data.id, {
      organisationId: session.organisation.id,
    });
    if (!bundle || !bundle.item.deletedAt) return fail("Item not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    if (!can(session.actor, { type: "signage.restore" })) return fail("You cannot restore items");
    await db.transaction(async (tx) => {
      await tx
        .update(signageItems)
        .set({ deletedAt: null })
        .where(eq(signageItems.id, parsed.data.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: parsed.data.id,
        action: "restore",
        summary: `Restored ${bundle.item.ref}`,
      });
      await settleApprovalNotifications(tx, "signage_item", parsed.data.id);
    });
    revalidatePath("/", "layout");
    return success(
      { ref: bundle.item.ref, href: itemPath(bundle.edition.code, bundle.item) },
      `Restored ${bundle.item.ref}`,
    );
  } catch (err) {
    unstable_rethrow(err);
    console.error("restoreSignageItem", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Send for sign-off (brief 5.1): checks the fields sign-off needs, then
 * starts the run — or, without artwork yet, marks it ready for artwork so
 * the first upload starts it.
 */
export async function submitForReview(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.submit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot send items for sign-off");
  }
  try {
    const { next, pending } = await db.transaction((tx) =>
      submitItemInTx(tx, bundle, { actorUserId: session.user.id, now: new Date() }),
    );
    revalidatePath("/", "layout");
    const ref = bundle.item.ref;
    return success(
      undefined,
      next === "in_review"
        ? `${ref} sent for sign-off${pending.length ? ` — waiting on ${askedSummary(pending)}` : ""}`
        : `${ref} is ready for artwork — sign-off starts when it is uploaded`,
    );
  } catch (err) {
    return transitionFail(err);
  }
}

/**
 * Send an item back for sign-off after changes were asked for. With no new
 * artwork since the request, it asks first (`confirmRequired`), unless the
 * caller has confirmed sending the same version back.
 */
export async function resubmitItem(
  input: unknown,
): Promise<ActionResult<{ confirmRequired?: string }>> {
  const parsed = z
    .object({ id: z.string().uuid(), confirmSameArtwork: z.boolean().optional() })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.submit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot send this item back for sign-off");
  }
  const item = bundle.item;
  if (item.status !== "changes_requested") {
    return fail("Only items with changes requested can be sent back for sign-off");
  }
  if (!parsed.data.confirmSameArtwork) {
    const run = await loadRun(db, "signage_item", item.id, item.currentRunNumber);
    const request = run
      .filter((i) => i.status === "changes_requested")
      .sort((a, b) => (b.decidedAt?.getTime() ?? 0) - (a.decidedAt?.getTime() ?? 0))[0];
    if (!newArtworkSinceChanges(request?.lockedVersionId ?? null, item.currentArtworkVersionId)) {
      return success({
        confirmRequired: `No new artwork since ${request?.stepName ?? "the sign-off"} asked for changes. Send the same version back for sign-off?`,
      });
    }
  }
  try {
    const { pending } = await db.transaction((tx) =>
      resubmitItemInTx(tx, bundle, { actorUserId: session.user.id, now: new Date() }),
    );
    revalidatePath("/", "layout");
    return success(
      {},
      `${item.ref} sent back for sign-off${pending.length ? ` — waiting on ${askedSummary(pending)}` : ""}`,
    );
  } catch (err) {
    return transitionFail(err);
  }
}

/** Hold / resume / reopen (admin & ops). */
export async function holdSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), reason: z.string().trim().min(1, "A reason is required") })
    .safeParse(input);
  if (!parsed.success) return fail("A reason is required");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.hold" })) return fail("You cannot put items on hold");
  let next;
  try {
    next = signageTransition(bundle.item.status, "hold");
  } catch (err) {
    return transitionFail(err);
  }
  await db.transaction(async (tx) => {
    await tx
      .update(signageItems)
      .set({ status: next, previousStatus: bundle.item.status, onHoldReason: parsed.data.reason })
      .where(eq(signageItems.id, bundle.item.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      action: "status_change",
      before: { status: bundle.item.status },
      after: { status: next, reason: parsed.data.reason },
      summary: `${bundle.item.ref} put on hold`,
    });
    // Sign-off is paused: its requests are settled until it resumes.
    await settleApprovalNotifications(tx, "signage_item", bundle.item.id);
  });
  revalidatePath("/", "layout");
  return success(undefined, `${bundle.item.ref} is on hold — its sign-offs are paused`);
}

export async function resumeSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.resume" })) return fail("You cannot resume items");
  let next: SignageStatus;
  try {
    next = signageTransition(bundle.item.status, "resume", {
      previousStatus: bundle.item.previousStatus ?? undefined,
    });
  } catch (err) {
    return transitionFail(err);
  }
  // Artwork uploaded while held: go straight to review instead of waiting.
  const startReview = next === "awaiting_artwork" && Boolean(bundle.item.currentArtworkVersionId);
  if (startReview) next = "in_review";
  // Due dates shift by how long the item was actually on hold (calendar
  // days), measured from when it was held — not its last edit.
  const [heldAt] = await db
    .select({ at: auditLog.createdAt })
    .from(auditLog)
    .where(
      and(
        eq(auditLog.entityType, "signage_item"),
        eq(auditLog.entityId, bundle.item.id),
        eq(auditLog.action, "status_change"),
        sql`${auditLog.after}->>'status' = 'on_hold'`,
      ),
    )
    .orderBy(desc(auditLog.createdAt))
    .limit(1);
  const heldSince = (heldAt?.at ?? bundle.item.updatedAt).toISOString().slice(0, 10);
  const heldDays = Math.max(0, diffDaysIso(new Date().toISOString().slice(0, 10), heldSince));
  await db.transaction(async (tx) => {
    await tx
      .update(signageItems)
      .set({ status: next, previousStatus: null, onHoldReason: null })
      .where(eq(signageItems.id, bundle.item.id));
    if (startReview) {
      const instances = await startItemRun(tx, bundle, new Date());
      await settleApprovalNotifications(tx, "signage_item", bundle.item.id, {
        newlyPending: instances.filter((i) => i.status === "pending").map((i) => i.id),
      });
      await notifyPendingAssignees(tx, bundle, instances);
    } else if (bundle.item.currentRunNumber > 0 && heldDays > 0) {
      const run = await loadRun(tx, "signage_item", bundle.item.id, bundle.item.currentRunNumber);
      await persistRun(tx, "signage_item", bundle.item.id, applyHoldShift(run, heldDays));
    }
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      action: "status_change",
      before: { status: bundle.item.status },
      after: { status: next, dueDatesShiftedByDays: heldDays },
      summary: `${bundle.item.ref} resumed`,
    });
    if (!startReview) await settleApprovalNotifications(tx, "signage_item", bundle.item.id);
  });
  revalidatePath("/", "layout");
  return success(undefined, `${bundle.item.ref} resumed`);
}

/** Statuses where Reopen undoes the install and takes the item back to Delivered. */
const INSTALLED_STATUSES: SignageStatus[] = ["installed", "snagged", "closed"];

/**
 * Reopen: a rejected item goes back to draft; an installed, snagged or closed
 * one goes back to Delivered (the install is undone and its photo cleared),
 * so the Installed confirmation can be ticked again. Admin and ops only.
 */
export async function reopenSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), reason: z.string().trim().max(2000).optional().nullable() })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.reopen" })) return fail("You cannot reopen items");
  const undoInstall = INSTALLED_STATUSES.includes(bundle.item.status as SignageStatus);
  const reason = parsed.data.reason?.trim() ?? "";
  if (undoInstall && !reason) return fail("Say why the install is being undone");
  let next: SignageStatus;
  try {
    next = signageTransition(bundle.item.status as SignageStatus, "reopen");
  } catch (err) {
    return transitionFail(err);
  }
  await db.transaction(async (tx) => {
    await tx
      .update(signageItems)
      .set(
        undoInstall
          ? { status: next, installedAt: null, installedBy: null, installPhotoPath: null }
          : { status: next },
      )
      .where(eq(signageItems.id, bundle.item.id));
    if (undoInstall && bundle.item.currentRunNumber > 0) {
      // Put the Installed confirmation back on the list, due on the install date.
      await tx
        .update(approvalInstances)
        .set({
          status: "pending",
          decidedBy: null,
          decidedAt: null,
          decisionComment: null,
          confirmedOn: null,
          lockedVersionType: null,
          lockedVersionId: null,
          lockedSha256: null,
          pendingSince: new Date(),
          dueAt: bundle.item.installDate ? new Date(`${bundle.item.installDate}T12:00:00Z`) : null,
        })
        .where(
          and(
            eq(approvalInstances.entityType, "signage_item"),
            eq(approvalInstances.entityId, bundle.item.id),
            eq(approvalInstances.runNumber, bundle.item.currentRunNumber),
            eq(approvalInstances.stepNameSnapshot, "Installed"),
            eq(approvalInstances.status, "confirmed"),
          ),
        );
    }
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      action: "status_change",
      before: { status: bundle.item.status },
      after: { status: next, ...(reason ? { reason } : {}) },
      summary: undoInstall
        ? `${bundle.item.ref} reopened — install undone: ${reason}`
        : `${bundle.item.ref} reopened (previous run kept in history)`,
    });
  });
  revalidatePath("/", "layout");
  return success(
    undefined,
    undoInstall
      ? `${bundle.item.ref} is back to Delivered — confirm Installed again once it is fixed`
      : `${bundle.item.ref} reopened as a draft — the earlier sign-off is kept in History`,
  );
}

/** Mark complete (close): an installed item with no open snags is finished. Admin and ops only. */
export async function closeSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.close" })) {
    return fail("You cannot mark items complete");
  }
  let next: SignageStatus;
  try {
    next = signageTransition(bundle.item.status as SignageStatus, "close");
  } catch (err) {
    return transitionFail(err);
  }
  const [{ open }] = await db
    .select({ open: sql<number>`count(*)::int` })
    .from(snags)
    .where(
      and(eq(snags.signageItemId, bundle.item.id), inArray(snags.status, ["open", "in_progress"])),
    );
  if (Number(open) > 0) {
    return fail(
      `${open} snag${Number(open) === 1 ? " is" : "s are"} still open — resolve them first`,
    );
  }
  try {
    await db.transaction(async (tx) => {
      // Check and close in one statement, so a snag raised at the same
      // moment cannot leave a closed item with an open snag.
      const updated = await tx
        .update(signageItems)
        .set({ status: next })
        .where(
          and(
            eq(signageItems.id, bundle.item.id),
            eq(signageItems.status, "installed"),
            sql`NOT EXISTS (
              SELECT 1 FROM snags
              WHERE signage_item_id = ${bundle.item.id} AND status IN ('open', 'in_progress')
            )`,
          ),
        )
        .returning({ id: signageItems.id });
      if (updated.length === 0) {
        throw new Error(
          "Could not mark it complete — a snag was just raised or the item changed; refresh",
        );
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: bundle.item.id,
        action: "status_change",
        before: { status: bundle.item.status },
        after: { status: next },
        summary: `${bundle.item.ref} marked complete`,
      });
    });
  } catch (err) {
    return fail(errMessage(err));
  }
  revalidatePath("/", "layout");
  return success(undefined, `${bundle.item.ref} marked complete`);
}

// ------------------------------------------------------------------ helpers

function zodErrors(error: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) {
    out[issue.path.join(".")] = issue.message;
  }
  return out;
}

function pickKeys(obj: Record<string, unknown>, keys: string[]): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of keys) out[k] = obj[k];
  return out;
}

function transitionFail(err: unknown): ActionResult<never> {
  if (err instanceof IllegalTransitionError) return fail(err.message);
  return fail(errMessage(err));
}

function errMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return "Something went wrong";
}
