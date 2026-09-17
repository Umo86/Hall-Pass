"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances, signageItems, standSubmissions } from "@/lib/db/schema";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { signageTransition } from "@/lib/status/signage";
import { standTransition } from "@/lib/status/stand";
import {
  applyDecision,
  applyDelegation,
  ConflictError,
  resubmitAfterChanges,
  WorkflowError,
  type Decision,
  type EntityCtx,
} from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { notify } from "@/lib/notify";
import {
  itemAuthzCtx,
  itemEntityCtx,
  loadItemBundle,
  resolveAssigneeUserIds,
  startItemRun,
} from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, standEntityCtx } from "@/lib/domain/stand";

const decideSchema = z.object({
  instanceId: z.string().uuid(),
  decision: z.enum(["approve", "approve_with_conditions", "request_changes", "reject", "confirm"]),
  comment: z.string().max(5000).optional(),
  conditionsText: z.string().max(5000).optional(),
  expectedStatus: z.string(),
  expectedLockedVersionId: z.string().nullable(),
  photoPath: z.string().max(1000).optional(),
  confirmedDate: z.string().date().optional(),
});

/** Map default-workflow confirmation names to item status events (brief 5.1). */
const CONFIRMATION_EVENTS: Record<string, "sent_to_print" | "delivered" | "installed"> = {
  "Sent to print": "sent_to_print",
  Delivered: "delivered",
  Installed: "installed",
};

export async function decideApproval(input: unknown): Promise<ActionResult> {
  const parsed = decideSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid decision");
  const session = await requireSession();
  const data = parsed.data;

  try {
    const outcome = await db.transaction(async (tx) => {
      // Serialise concurrent decisions on the same instance.
      const [row] = await tx
        .select()
        .from(approvalInstances)
        .where(eq(approvalInstances.id, data.instanceId))
        .for("update");
      if (!row) throw new WorkflowError("Approval step not found");

      const isSignage = row.entityType === "signage_item";
      const bundle = isSignage
        ? await loadItemBundle(tx, row.entityId)
        : await loadStandBundle(tx, row.entityId);
      if (!bundle) throw new WorkflowError("Record not found");

      const stepCtx: ApprovalStepCtx = {
        assignedRole: row.assignedRole,
        assignedUserId: row.assignedUserId,
        entity: isSignage
          ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
          : { type: "stand", sub: standAuthzCtx(bundle as never) },
      };
      if (!can(session.actor, { type: "approval.decide", step: stepCtx })) {
        throw new WorkflowError("This step is not assigned to you");
      }

      const entity: EntityCtx = isSignage
        ? itemEntityCtx(bundle as never)
        : standEntityCtx(bundle as never);

      // Photo requirement for the Installed confirmation.
      if (
        row.stepNameSnapshot === "Installed" &&
        data.decision === "confirm" &&
        session.organisation.settings.install_photo_required &&
        !data.photoPath
      ) {
        throw new WorkflowError("A photo is required to confirm installation");
      }

      const decision: Decision =
        data.decision === "approve"
          ? { type: "approve", comment: data.comment }
          : data.decision === "approve_with_conditions"
            ? {
                type: "approve_with_conditions",
                conditionsText: data.conditionsText ?? "",
                comment: data.comment,
              }
            : data.decision === "request_changes"
              ? { type: "request_changes", comment: data.comment ?? "" }
              : data.decision === "reject"
                ? { type: "reject", comment: data.comment ?? "" }
                : { type: "confirm", comment: data.comment };

      const run = await loadRun(tx, row.entityType, row.entityId, row.runNumber);
      const currentVersionId = isSignage
        ? ((bundle as { item: { currentArtworkVersionId: string | null } }).item
            .currentArtworkVersionId ?? null)
        : String((bundle as { sub: { submissionVersion: number } }).sub.submissionVersion);

      const res = applyDecision(run, {
        instanceId: data.instanceId,
        decision,
        decidedBy: session.user.id,
        now: new Date(),
        entity,
        expectedStatus: data.expectedStatus,
        expectedLockedVersionId: data.expectedLockedVersionId,
        lockedVersionType: isSignage ? "artwork_version" : "submission_version",
        lockedVersionId: currentVersionId,
        lockedSha256: isSignage
          ? ((bundle as { currentSha256?: string | null }).currentSha256 ?? null)
          : null,
      });
      await persistRun(tx, row.entityType, row.entityId, res.instances);

      // Entity status effects.
      let statusNote = "";
      if (isSignage) {
        const b = bundle as Awaited<ReturnType<typeof loadItemBundle>> & object;
        const item = (b as { item: typeof signageItems.$inferSelect }).item;
        const edition = (b as { edition: { id: string; code: string } }).edition;
        let event: Parameters<typeof signageTransition>[1] | null = null;
        if (res.entityEvent.type === "changes_requested") event = "changes_requested";
        else if (res.entityEvent.type === "rejected") event = "rejected";
        else if (res.entityEvent.type === "run_approved") event = "run_approved";
        else if (res.entityEvent.type === "run_approved_with_conditions")
          event = "run_approved_with_conditions";
        else if (data.decision === "confirm") {
          event = CONFIRMATION_EVENTS[row.stepNameSnapshot] ?? null;
        }
        // A mid-run confirmation (e.g. Sent to print while Installed remains)
        // moves the item even though the run is not finished.
        if (event) {
          const next = signageTransition(item.status, event);
          const set: Partial<typeof signageItems.$inferInsert> = { status: next };
          if (event === "installed") {
            set.installedAt = new Date();
            set.installedBy = session.user.id;
            if (data.photoPath) set.installPhotoPath = data.photoPath;
          }
          await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
          statusNote = ` — item now ${next.replace(/_/g, " ")}`;
        }
        // Notify the owner of the decision; notify next assignees.
        if (item.ownerUserId) {
          await notify(tx, {
            userIds: [item.ownerUserId],
            kind: "decision_made",
            title: `${row.stepNameSnapshot}: ${data.decision.replace(/_/g, " ")} — ${item.ref}`,
            body: data.comment || data.conditionsText || undefined,
            link: `/${edition.code}/signage/${item.ref}`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        for (const inst of res.instances.filter(
          (x) => x.status === "pending" && x.id !== data.instanceId,
        )) {
          const assignees = await resolveAssigneeUserIds(
            tx,
            session.organisation.id,
            edition.id,
            (b as { venue: { id: string } }).venue.id,
            item,
            inst,
          );
          await notify(tx, {
            userIds: assignees,
            kind: "approval_requested",
            title: `Approval requested: ${item.ref}`,
            body: `${inst.stepName} for ${item.name}`,
            link: `/${edition.code}/signage/${item.ref}`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: edition.id,
          actorUserId: session.user.id,
          entityType: "signage_item",
          entityId: item.id,
          action: "decide",
          after: {
            step: row.stepNameSnapshot,
            decision: data.decision,
            comment: data.comment,
            conditions: data.conditionsText,
            lockedVersionId: currentVersionId,
          },
          summary: `${row.stepNameSnapshot} ${data.decision.replace(/_/g, " ")} on ${item.ref}`,
        });
      } else {
        const b = bundle as Awaited<ReturnType<typeof loadStandBundle>> & object;
        const sub = (b as { sub: typeof standSubmissions.$inferSelect }).sub;
        const edition = (b as { edition: { id: string; code: string } }).edition;
        let next: typeof sub.status | null = null;
        if (res.entityEvent.type === "changes_requested") {
          next = standTransition(sub.status, "changes_requested");
        } else if (res.entityEvent.type === "rejected") {
          next = standTransition(sub.status, "outcome_rejected");
        } else if (
          res.entityEvent.type === "run_approved" ||
          res.entityEvent.type === "run_approved_with_conditions"
        ) {
          // The final approval step writes the outcome (brief 6.5).
          const finalDecision = res.decided;
          const withConditions =
            res.entityEvent.type === "run_approved_with_conditions" ||
            finalDecision.status === "approved_with_conditions";
          next = standTransition(
            sub.status,
            withConditions ? "outcome_approved_with_conditions" : "outcome_approved",
          );
          await tx
            .update(standSubmissions)
            .set({
              outcome: withConditions ? "approved_with_conditions" : "approved",
              conditionsText: data.conditionsText ?? sub.conditionsText,
            })
            .where(eq(standSubmissions.id, sub.id));
        } else if (data.decision === "confirm" && row.stepNameSnapshot === "Onsite build check") {
          next = standTransition(sub.status, "build_check", {
            hadConditions: Boolean(sub.conditionsText),
            buildCheckNotes: data.comment ?? null,
          });
          await tx
            .update(standSubmissions)
            .set({
              buildCheckDoneAt: new Date(),
              buildCheckBy: session.user.id,
              buildCheckNotes: data.comment ?? null,
              buildCheckPhotoPath: data.photoPath ?? null,
            })
            .where(eq(standSubmissions.id, sub.id));
        }
        if (next && next !== sub.status) {
          await tx
            .update(standSubmissions)
            .set({ status: next })
            .where(eq(standSubmissions.id, sub.id));
          statusNote = ` — submission now ${next.replace(/_/g, " ")}`;
        }
        for (const inst of res.instances.filter(
          (x) => x.status === "pending" && x.id !== data.instanceId,
        )) {
          const assignees = await resolveAssigneeUserIds(
            tx,
            session.organisation.id,
            edition.id,
            (b as { venue: { id: string } }).venue.id,
            null,
            inst,
          );
          await notify(tx, {
            userIds: assignees,
            kind: "approval_requested",
            title: `Stand review requested: ${sub.ref}`,
            body: inst.stepName,
            link: `/${edition.code}/stands/${sub.ref}`,
            entityType: "stand_submission",
            entityId: sub.id,
          });
        }
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: edition.id,
          actorUserId: session.user.id,
          entityType: "stand_submission",
          entityId: sub.id,
          action: "decide",
          after: {
            step: row.stepNameSnapshot,
            decision: data.decision,
            comment: data.comment,
            conditions: data.conditionsText,
            lockedVersion: currentVersionId,
          },
          summary: `${row.stepNameSnapshot} ${data.decision.replace(/_/g, " ")} on ${sub.ref}`,
        });
      }
      return statusNote;
    });
    revalidatePath("/", "layout");
    return success(undefined, `Decision recorded${outcome}`);
  } catch (err) {
    if (err instanceof ConflictError) return fail(err.message);
    if (err instanceof WorkflowError) return fail(err.message);
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

const delegateSchema = z.object({
  instanceId: z.string().uuid(),
  toUserId: z.string().uuid(),
});

export async function delegateApproval(input: unknown): Promise<ActionResult> {
  const parsed = delegateSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .select()
        .from(approvalInstances)
        .where(eq(approvalInstances.id, parsed.data.instanceId))
        .for("update");
      if (!row) throw new WorkflowError("Approval step not found");
      const isSignage = row.entityType === "signage_item";
      const bundle = isSignage
        ? await loadItemBundle(tx, row.entityId)
        : await loadStandBundle(tx, row.entityId);
      if (!bundle) throw new WorkflowError("Record not found");
      const stepCtx: ApprovalStepCtx = {
        assignedRole: row.assignedRole,
        assignedUserId: row.assignedUserId,
        entity: isSignage
          ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
          : { type: "stand", sub: standAuthzCtx(bundle as never) },
      };
      if (!can(session.actor, { type: "approval.delegate", step: stepCtx })) {
        throw new WorkflowError("You cannot delegate this step");
      }
      const run = await loadRun(tx, row.entityType, row.entityId, row.runNumber);
      const updated = applyDelegation(run, {
        instanceId: parsed.data.instanceId,
        toUserId: parsed.data.toUserId,
        fromUserId: session.user.id,
      });
      await persistRun(tx, row.entityType, row.entityId, updated);
      await notify(tx, {
        userIds: [parsed.data.toUserId, session.user.id],
        kind: "delegation",
        title: `Step delegated: ${row.stepNameSnapshot}`,
        body: `Delegated by ${session.user.fullName || session.user.email}`,
        entityType: row.entityType,
        entityId: row.entityId,
      });
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: row.entityType,
        entityId: row.entityId,
        action: "delegate",
        after: { step: row.stepNameSnapshot, toUserId: parsed.data.toUserId },
        summary: `${row.stepNameSnapshot} delegated`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Step delegated — both parties notified");
  } catch (err) {
    if (err instanceof WorkflowError) return fail(err.message);
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

/** Resubmit a signage item after changes were requested (brief 6.3). */
export async function resubmitSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (!can(session.actor, { type: "signage.submit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot resubmit this item");
  }
  let next;
  try {
    next = signageTransition(bundle.item.status, "resubmit");
  } catch {
    return fail("Only items with changes requested can be resubmitted");
  }
  try {
    await db.transaction(async (tx) => {
      const run = await loadRun(tx, "signage_item", bundle.item.id, bundle.item.currentRunNumber);
      const res = resubmitAfterChanges(run, { entity: itemEntityCtx(bundle), now: new Date() });
      if (res.mode === "restart_from_step") {
        await persistRun(tx, "signage_item", bundle.item.id, res.instances);
      } else {
        // Whole run restarts as a new run; the old one stays in history.
        await startItemRun(tx, bundle, new Date());
      }
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
        action: "submit",
        after: { status: next, mode: res.mode },
        summary: `${bundle.item.ref} resubmitted`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Resubmitted for review");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}
