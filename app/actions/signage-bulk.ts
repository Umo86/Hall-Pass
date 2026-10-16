"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances, signageItems, suppliers } from "@/lib/db/schema";
import {
  archivedSupplierMessage,
  bulkConfirmSkipReason,
  itemAuthzCtx,
  loadItemBundle,
  notifyOwnerChange,
  syncConfirmationDueDates,
  type BulkConfirmStep,
  type OwnerChange,
} from "@/lib/domain/signage";
import {
  loadTeam,
  ownerRoleOf,
  refusalFor,
  refusalMessage,
  type OwnableItem,
  type TeamMember,
} from "@/lib/people";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { can, missingAbilityMessage, type ApprovalStepCtx } from "@/lib/authz";
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
    "set_owner",
  ]),
  supplierId: z.string().uuid().optional().nullable(),
  /** Change owner: who gets the items. */
  ownerUserId: z.string().uuid().optional().nullable(),
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
  set_owner: "given to a new owner",
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
  // Bulk is its own ability; each item below still checks what may change on it.
  if (!can(session.actor, { type: "signage.bulk" })) {
    return fail(missingAbilityMessage("signage.bulk"));
  }
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

  if (action === "set_owner") {
    if (!parsed.data.ownerUserId) return fail("Choose who gets the items");
    const res = await changeOwners(session, ids, parsed.data.ownerUserId);
    if ("error" in res) return fail(res.error);
    done = res.done;
    failures.push(...res.failures);
    const out = finish();
    return out.ok
      ? success<BulkOutcome>(
          out.data!,
          failures.length === 0
            ? `${done} ${done === 1 ? "item" : "items"} given to ${res.toName}`
            : `${done} given to ${res.toName}, ${failures.length} left as they were`,
        )
      : out;
  }

  // Field updates (supplier / install date + slot): checked and recorded
  // item by item, so each item's History shows the change. The supplier is
  // part of costs: costs.edit, or a sponsorship item they may edit.
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
              : action === "set_supplier" &&
                  !can(session.actor, { type: "costs.edit", item: itemAuthzCtx(bundle) })
                ? "you can't set its supplier"
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

type BulkSession = Awaited<ReturnType<typeof requireSession>>;

/**
 * Bulk "Change owner": each item is checked on its own — the right to edit
 * it (whoever may edit an item may give it away), the event, and that the
 * new owner can work on that kind of item (lib/people.ts) — then changed
 * with its own audit row. A stand's panels go with it. The new owner gets
 * one message for them all; each previous owner hears which of theirs moved.
 */
async function changeOwners(
  session: BulkSession,
  ids: string[],
  toUserId: string,
): Promise<{ done: number; failures: BulkFailure[]; toName: string } | { error: string }> {
  const orgId = session.organisation.id;
  const team = await loadTeam(db, orgId);
  const to = team.find((m) => m.userId === toUserId);
  // Nobody can be given anything while their access is paused or ended.
  const access = checkPickSync(team, toUserId, orgId);
  if (access) return { error: access };
  const failures: BulkFailure[] = [];
  const changed: OwnerChange[] = [];
  let done = 0;
  for (const id of ids) {
    const bundle = await loadItemBundle(db, id, { organisationId: orgId });
    const item = bundle?.item;
    const refusal = !bundle
      ? "not found"
      : bundle.item.deletedAt
        ? "deleted"
        : editionIsReadOnly(bundle.edition.status)
          ? "the event is archived"
          : bundle.item.kind === "stand_panel"
            ? "a panel goes with its stand — change the stand's owner"
            : !can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })
              ? "you can't change it"
              : bundle.item.ownerUserId === toUserId
                ? `already ${to!.name}'s`
                : ownerRefusalWords(team, toUserId, bundle.item, orgId);
    if (!bundle || !item || refusal) {
      failures.push({ id, ref: item?.ref ?? "Unknown item", reason: refusal ?? "not found" });
      continue;
    }
    try {
      const role = ownerRoleOf(to!);
      await db.transaction(async (tx) => {
        const set = { ownerUserId: toUserId, ...(role ? { ownerRole: role } : {}) };
        await tx.update(signageItems).set(set).where(eq(signageItems.id, id));
        await writeAudit(tx, {
          organisationId: orgId,
          editionId: bundle.edition.id,
          actorUserId: session.user.id,
          entityType: "signage_item",
          entityId: id,
          action: "update",
          before: { ownerUserId: item.ownerUserId, ownerRole: item.ownerRole },
          after: set,
          summary: `${item.ref}: owner changed to ${to!.name} (bulk)`,
        });
        if (item.kind === "stand_design") {
          // Its panels are the stand's owner's too.
          const panels = await tx
            .update(signageItems)
            .set(set)
            .where(and(eq(signageItems.parentItemId, id), isNull(signageItems.deletedAt)))
            .returning({ id: signageItems.id, ref: signageItems.ref });
          for (const p of panels) {
            await writeAudit(tx, {
              organisationId: orgId,
              editionId: bundle.edition.id,
              actorUserId: session.user.id,
              entityType: "signage_item",
              entityId: p.id,
              action: "update",
              after: set,
              summary: `${p.ref}: owner changed to ${to!.name} with its stand ${item.ref}`,
            });
          }
        }
      });
      changed.push({
        id,
        ref: item.ref,
        name: item.name,
        kind: item.kind,
        editionCode: bundle.edition.code,
        fromUserId: item.ownerUserId,
      });
      done += 1;
    } catch (err) {
      console.error("bulk owner", id, err);
      failures.push({ id, ref: item.ref, reason: "could not be saved" });
    }
  }
  if (changed.length > 0) {
    await db.transaction((tx) =>
      notifyOwnerChange(tx, {
        actor: { id: session.user.id, name: session.user.fullName || session.user.email },
        to: { id: toUserId, name: to!.name },
        items: changed,
      }),
    );
  }
  return { done, failures, toName: to!.name };
}

/** Why the person can't be given anything at all (not on the team, suspended, ended). */
function checkPickSync(team: TeamMember[], userId: string, organisationId: string): string | null {
  const m = team.find((x) => x.userId === userId);
  const refusal = refusalFor({ type: "task" }, m, { organisationId });
  return refusal ? refusalMessage(m?.name ?? "That person", refusal, { type: "task" }) : null;
}

/** "Sam can't work on sponsor signage" for one item, or null when they can own it. */
function ownerRefusalWords(
  team: TeamMember[],
  userId: string,
  item: { kind: OwnableItem["kind"]; sponsorId: string | null; category: string | null },
  organisationId: string,
): string | null {
  const m = team.find((x) => x.userId === userId);
  const ownable: OwnableItem = {
    kind: item.kind,
    sponsored: Boolean(item.sponsorId) || item.category === "sponsor",
  };
  const refusal = refusalFor({ type: "owner", item: ownable }, m, { organisationId });
  if (!refusal) return null;
  return refusalMessage(m?.name ?? "That person", refusal, {
    type: "owner",
    item: ownable,
  }).replace(/ — pick someone else$/, "");
}
