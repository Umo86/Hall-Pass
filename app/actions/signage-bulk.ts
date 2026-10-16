"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances, signageItems, suppliers } from "@/lib/db/schema";
import {
  archivedSupplierMessage,
  bulkConfirmSkipReason,
  itemAuthzCtx,
  loadItemBundle,
  syncConfirmationDueDates,
  type BulkConfirmStep,
} from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { todayInLondon } from "@/lib/today";
import { closeSignageItem, softDeleteSignageItem, submitForReview } from "./signage";
import { decideApproval } from "./approvals";

const schema = z.object({
  ids: z.array(z.string().uuid()).min(1).max(500),
  action: z.enum([
    "set_supplier",
    "set_install",
    "submit",
    "delete",
    "close",
    "confirm_print",
    "confirm_delivered",
  ]),
  supplierId: z.string().uuid().optional().nullable(),
  installDate: z.string().date().optional().nullable(),
  installSlot: z.enum(["am", "pm", "overnight"]).optional().nullable(),
  /** Bulk confirmations: the day it really happened (default today). */
  confirmedDate: z.string().date().optional().nullable(),
});

/** One item the bulk action left alone, and why, in a few words. */
export type BulkFailure = { id: string; ref: string; reason: string };

export type BulkOutcome = {
  done: number;
  failed: number;
  failures: BulkFailure[];
};

const CONFIRM_STEPS: Record<"confirm_print" | "confirm_delivered", BulkConfirmStep> = {
  confirm_print: "Sent to print",
  confirm_delivered: "Delivered",
};

const VERBS: Record<z.infer<typeof schema>["action"], string> = {
  set_supplier: "updated",
  set_install: "updated",
  submit: "sent for sign-off",
  delete: "deleted",
  close: "marked complete",
  confirm_print: "confirmed sent to print",
  confirm_delivered: "confirmed delivered",
};

/** "Cannot send for sign-off yet — missing: width" → "missing: width". */
function shortReason(error: string): string {
  return error.replace(/^Cannot send for sign-off yet — /, "");
}

/**
 * Bulk actions on the signage list. Every item is checked and recorded on
 * its own (each item's History shows the change), and the result names each
 * item that was left alone and why, so the list can keep those selected.
 */
export async function bulkSignageAction(input: unknown): Promise<ActionResult<BulkOutcome>> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail("Invalid bulk action");
  const session = await requireSession();
  if (session.actor.kind !== "staff") return fail("Not permitted");
  const { ids, action } = parsed.data;
  const failures: BulkFailure[] = [];
  let done = 0;

  /** The ref for a failure, read only within the caller's organisation. */
  const refOf = async (id: string) => {
    const bundle = await loadItemBundle(db, id, { organisationId: session.organisation.id });
    return bundle?.item.ref ?? "Unknown item";
  };

  const finish = () => {
    revalidatePath("/", "layout");
    const verb = VERBS[action];
    const message =
      failures.length === 0
        ? `${done} ${verb}`
        : `${done} ${verb}, ${failures.length} left as they were`;
    return success<BulkOutcome>({ done, failed: failures.length, failures }, message);
  };

  if (action === "submit" || action === "close" || action === "delete") {
    if (action === "close" && !can(session.actor, { type: "signage.close" })) {
      return fail("You cannot mark items complete");
    }
    if (action === "delete" && !can(session.actor, { type: "signage.delete" })) {
      return fail("You cannot delete items");
    }
    const run =
      action === "submit"
        ? submitForReview
        : action === "close"
          ? closeSignageItem
          : softDeleteSignageItem;
    for (const id of ids) {
      const res = await run({ id });
      if (res.ok) done += 1;
      else failures.push({ id, ref: await refOf(id), reason: shortReason(res.error) });
    }
    return finish();
  }

  if (action === "confirm_print" || action === "confirm_delivered") {
    const step = CONFIRM_STEPS[action];
    const confirmedDate = parsed.data.confirmedDate ?? todayInLondon();
    if (confirmedDate > todayInLondon()) return fail("The date cannot be in the future");
    for (const id of ids) {
      const bundle = await loadItemBundle(db, id, { organisationId: session.organisation.id });
      if (!bundle || bundle.item.deletedAt) {
        failures.push({ id, ref: bundle?.item.ref ?? "Unknown item", reason: "not found" });
        continue;
      }
      const item = bundle.item;
      if (editionIsReadOnly(bundle.edition.status)) {
        failures.push({ id, ref: item.ref, reason: "the event is archived" });
        continue;
      }
      // The current round's waiting steps; the one to confirm is among them.
      const pending = await db
        .select()
        .from(approvalInstances)
        .where(
          and(
            eq(approvalInstances.entityType, "signage_item"),
            eq(approvalInstances.entityId, id),
            eq(approvalInstances.runNumber, item.currentRunNumber),
            eq(approvalInstances.status, "pending"),
          ),
        );
      const instance = pending.find(
        (p) => p.stepNameSnapshot === step && p.stepKindSnapshot === "confirmation",
      );
      const stepCtx: ApprovalStepCtx | null = instance
        ? {
            assignedRole: instance.assignedRole,
            assignedDepartmentId: instance.assignedDepartmentId,
            stepKind: instance.stepKindSnapshot,
            assignedUserId: instance.assignedUserId,
            entity: { type: "signage_item", item: itemAuthzCtx(bundle) },
          }
        : null;
      const reason = bulkConfirmSkipReason(step, {
        status: item.status,
        supplierId: item.supplierId,
        pendingStepNames: pending
          .filter((p) => p.stepKindSnapshot === "confirmation")
          .map((p) => p.stepNameSnapshot),
        canDecide: stepCtx ? can(session.actor, { type: "approval.decide", step: stepCtx }) : false,
      });
      if (reason || !instance) {
        failures.push({ id, ref: item.ref, reason: reason ?? "nothing waiting to confirm" });
        continue;
      }
      // The same decision as confirming it on the item: checked, recorded
      // and audited by the approvals action.
      const res = await decideApproval({
        instanceId: instance.id,
        decision: "confirm",
        confirmedDate,
        expectedStatus: "pending",
        expectedLockedVersionId: item.currentArtworkVersionId,
      });
      if (res.ok) done += 1;
      else failures.push({ id, ref: item.ref, reason: res.error });
    }
    return finish();
  }

  // Field updates (supplier / install date + slot): checked and recorded
  // item by item, so each item's History shows the change.
  if (action === "set_supplier" && !can(session.actor, { type: "costs.edit" })) {
    return fail("You cannot set suppliers");
  }
  if (action === "set_supplier" && parsed.data.supplierId) {
    const [own] = await db
      .select({ id: suppliers.id, name: suppliers.name, isArchived: suppliers.isArchived })
      .from(suppliers)
      .where(
        and(
          eq(suppliers.id, parsed.data.supplierId),
          eq(suppliers.organisationId, session.organisation.id),
        ),
      );
    if (!own) return fail("Supplier not found");
    if (own.isArchived) return fail(archivedSupplierMessage(own.name));
  }
  const set: Partial<typeof signageItems.$inferInsert> = {};
  if (action === "set_supplier") set.supplierId = parsed.data.supplierId ?? null;
  if (action === "set_install") {
    set.installDate = parsed.data.installDate ?? null;
    set.installSlot = parsed.data.installSlot ?? null;
  }
  for (const id of ids) {
    try {
      const bundle = await loadItemBundle(db, id, { organisationId: session.organisation.id });
      const reason = !bundle
        ? "not found"
        : bundle.item.deletedAt
          ? "deleted"
          : editionIsReadOnly(bundle.edition.status)
            ? "the event is archived"
            : !can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })
              ? "you can't change it"
              : action === "set_install" && bundle.item.kind !== "signage"
                ? "not a sign (no install date)"
                : null;
      if (!bundle || reason) {
        failures.push({ id, ref: bundle?.item.ref ?? "Unknown item", reason: reason! });
        continue;
      }
      const item = bundle.item as unknown as Record<string, unknown>;
      await db.transaction(async (tx) => {
        await tx.update(signageItems).set(set).where(eq(signageItems.id, id));
        if (action === "set_install") await syncConfirmationDueDates(tx, bundle.item, set);
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: bundle.edition.id,
          actorUserId: session.user.id,
          entityType: "signage_item",
          entityId: id,
          action: "update",
          before: Object.fromEntries(Object.keys(set).map((k) => [k, item[k] ?? null])),
          after: set,
          summary: `${bundle.item.ref}: ${action === "set_supplier" ? "supplier" : "install date"} changed (bulk)`,
        });
      });
      done += 1;
    } catch (err) {
      console.error("bulk update", id, err);
      failures.push({ id, ref: await refOf(id), reason: "could not be saved" });
    }
  }
  return finish();
}
