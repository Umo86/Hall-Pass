"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, desc, eq, sql } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { auditLog, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import {
  IllegalTransitionError,
  INVALIDATABLE_STATUSES,
  signageTransition,
  type SignageStatus,
} from "@/lib/status/signage";
import { applyHoldShift } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { nextSignageRef } from "@/lib/refs";
import { notify } from "@/lib/notify";
import {
  changedSpecKeys,
  defaultSignageWorkflowId,
  itemAuthzCtx,
  loadItemBundle,
  missingSubmitFields,
  notifyPendingAssignees,
  resolveItemCreationRecipients,
  startItemRun,
} from "@/lib/domain/signage";
import { diffDaysIso } from "@/lib/deadlines";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";

const itemFields = z.object({
  name: z.string().trim().min(1, "Name is required").max(300),
  description: z.string().max(5000).optional().nullable(),
  category: z.enum(["directional", "venue", "sponsorship"]).optional().nullable(),
  itemTypeId: z.string().uuid().optional().nullable(),
  hallId: z.string().uuid().optional().nullable(),
  locationId: z.string().uuid().optional().nullable(),
  ownerRole: z.enum(["ops", "marketing"]).default("ops"),
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
    if (data.kind === "signage" && !data.category) {
      ctx.addIssue({
        code: "custom",
        path: ["category"],
        message: "Choose a category — directional, venue or sponsorship",
      });
    }
  });

function num(v: number | null | undefined): string | null {
  return v == null ? null : String(v);
}

/** Rigged items are always flagged for venue approval (brief 6.1). */
function applyRiggedRule<T extends { fixingMethod?: string | null; requiresVenueApproval?: boolean }>(
  data: T,
): T {
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
  try {
    const ref = await db.transaction(async (tx) => {
      // Locking not needed here; the counter row lock serialises the seq.
      const [edition] = await tx.execute<{ code: string; status: string }>(
        sql`SELECT code, status FROM editions WHERE id = ${data.editionId}`,
      );
      if (!edition) throw new Error("Edition not found");
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
          category: data.kind === "signage" ? (data.category ?? null) : null,
          itemTypeId: data.itemTypeId ?? null,
          hallId: data.hallId ?? null,
          locationId: data.locationId ?? null,
          ownerRole: data.ownerRole,
          ownerUserId: session.user.id,
          sponsorId: data.sponsorId ?? null,
          sponsorEntitlementId: data.sponsorEntitlementId ?? null,
          isSponsorDeliverable: Boolean(data.sponsorId),
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
          workflowId: data.workflowId ?? null,
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
        { kind: data.kind, category: data.category ?? null, ownerRole: data.ownerRole },
        session.user.id,
      );
      await notify(tx, {
        userIds: recipients,
        kind: "item_created",
        title: `New ${data.kind === "sponsorship_item" ? "sponsorship item" : "signage"}: ${ref} — ${data.name}`,
        link: `/${edition.code}/signage/${ref}`,
        entityType: "signage_item",
        entityId: item.id,
      });
      return ref;
    });
    revalidatePath("/", "layout");
    return success({ ref }, `Created ${ref}`);
  } catch (err) {
    return fail(errMessage(err));
  }
}

const updateSchema = itemFields.partial().extend({ id: z.string().uuid() });

export async function updateSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = updateSchema.safeParse(input);
  if (!parsed.success) return fail("Check the highlighted fields", zodErrors(parsed.error));
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot edit this item");
  }
  const canEditCosts = can(session.actor, { type: "costs.edit" });
  const { id, ...patchRaw } = parsed.data;
  const patch = applyRiggedRule(patchRaw);

  try {
    const outcome = await db.transaction(async (tx) => {
      const set: Partial<typeof signageItems.$inferInsert> = {};
      const assign = <K extends keyof typeof patch>(key: K, dbKey: keyof typeof set) => {
        if (patch[key] !== undefined) (set as Record<string, unknown>)[dbKey as string] = patch[key];
      };
      assign("name", "name");
      assign("description", "description");
      assign("category", "category");
      assign("itemTypeId", "itemTypeId");
      assign("hallId", "hallId");
      assign("locationId", "locationId");
      assign("ownerRole", "ownerRole");
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
      if (patch.weightKg !== undefined) set.weightKg = num(patch.weightKg);
      if (canEditCosts) {
        assign("budgetLine", "budgetLine");
        assign("poNumber", "poNumber");
        assign("supplierId", "supplierId");
        if (patch.costEstimate !== undefined) set.costEstimate = num(patch.costEstimate);
        if (patch.costActual !== undefined) set.costActual = num(patch.costActual);
      }
      // The form posts every field; keep only real changes so History and
      // the sign-off rules see what actually moved.
      for (const key of Object.keys(set) as Array<keyof typeof set>) {
        if (sameValue((bundle.item as Record<string, unknown>)[key], set[key])) delete set[key];
      }
      if (Object.keys(set).length === 0) return "unchanged" as const;

      const item = bundle.item;
      const specChanged = changedSpecKeys(item as Record<string, unknown>, set);
      let restarted = false;
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
            (i) => i.stepKind === "approval" && ["approved", "approved_with_conditions"].includes(i.status),
          );
        }
      }

      await tx.update(signageItems).set(set).where(eq(signageItems.id, id));
      if (restarted) {
        const updated = { ...bundle, item: { ...item, ...set } as typeof item };
        const instances = await startItemRun(tx, updated, new Date());
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
          restarted ? " — spec changed, sign-off restarted" : ""
        }`,
      });
      return restarted ? ("restarted" as const) : ("saved" as const);
    });
    revalidatePath("/", "layout");
    if (outcome === "unchanged") return success(undefined, "No changes to save");
    return success(
      undefined,
      outcome === "restarted"
        ? "Saved — the spec changed, so sign-off has restarted and approvers have been told"
        : "Saved",
    );
  } catch (err) {
    return fail(errMessage(err));
  }
}

/** Equality for stored vs submitted values ("1200.00" == 1200, null == ""). */
function sameValue(a: unknown, b: unknown): boolean {
  const norm = (v: unknown) => (v === null || v === undefined || v === "" ? "" : v);
  const x = norm(a);
  const y = norm(b);
  if (x === "" || y === "") return x === y;
  const nx = Number(x);
  const ny = Number(y);
  if (typeof x !== "boolean" && typeof y !== "boolean" && Number.isFinite(nx) && Number.isFinite(ny)) {
    return nx === ny;
  }
  return String(x) === String(y);
}

export async function softDeleteSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
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
  });
  revalidatePath("/", "layout");
  return success(undefined, `Deleted ${bundle.item.ref} (restorable from Settings)`);
}

export async function restoreSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
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
  });
  revalidatePath("/", "layout");
  return success(undefined, `Restored ${bundle.item.ref}`);
}

/** Submit for review (brief 5.1): validates required fields, starts the run. */
export async function submitForReview(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.submit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot submit items for review");
  }
  const i = bundle.item;
  const missing = missingSubmitFields(i);
  if (missing.length > 0) {
    return fail(`Cannot submit yet — missing: ${missing.join(", ")}`);
  }
  // Items created by import (or before a workflow existed) get the default.
  let workflowId = i.workflowId;
  if (!workflowId) {
    workflowId = await defaultSignageWorkflowId(db, session.organisation.id, i.itemTypeId);
    if (!workflowId) return fail("No sign-off workflow is set up yet — ask an admin");
  }

  const hasArtwork = Boolean(i.currentArtworkVersionId);
  let next;
  try {
    next = signageTransition(i.status, "submit_for_review", { hasArtwork });
  } catch (err) {
    return transitionFail(err);
  }

  try {
    await db.transaction(async (tx) => {
      await tx
        .update(signageItems)
        .set({ status: next, workflowId })
        .where(eq(signageItems.id, i.id));
      if (next === "in_review") {
        const instances = await startItemRun(
          tx,
          { ...bundle, item: { ...i, workflowId } },
          new Date(),
        );
        await notifyPendingAssignees(tx, bundle, instances);
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: i.id,
        action: "submit",
        before: { status: i.status },
        after: { status: next },
        summary: `${i.ref} submitted for review`,
      });
    });
    revalidatePath("/", "layout");
    return success(
      undefined,
      next === "in_review" ? "Submitted — review started" : "Submitted — awaiting artwork",
    );
  } catch (err) {
    return fail(errMessage(err));
  }
}

/** Hold / resume / reopen (admin & ops). */
export async function holdSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), reason: z.string().trim().min(1, "A reason is required") })
    .safeParse(input);
  if (!parsed.success) return fail("A reason is required");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
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
  });
  revalidatePath("/", "layout");
  return success(undefined, "Item on hold — pending approvals are paused");
}

export async function resumeSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
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
  });
  revalidatePath("/", "layout");
  return success(undefined, "Item resumed");
}

export async function reopenSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
  if (!bundle) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.reopen" })) return fail("You cannot reopen items");
  let next;
  try {
    next = signageTransition(bundle.item.status, "reopen");
  } catch (err) {
    return transitionFail(err);
  }
  await db.transaction(async (tx) => {
    await tx
      .update(signageItems)
      .set({ status: next })
      .where(eq(signageItems.id, bundle.item.id));
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      action: "status_change",
      before: { status: bundle.item.status },
      after: { status: next },
      summary: `${bundle.item.ref} reopened (previous run kept in history)`,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, "Item reopened as draft — the previous run is kept in history");
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
