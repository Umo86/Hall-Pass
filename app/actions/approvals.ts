"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances, memberships, signageItems, standSubmissions } from "@/lib/db/schema";
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
  newlyPending,
  notifyPendingAssignees,
  resolveAssigneeUserIds,
  startItemRun,
} from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, standEntityCtx } from "@/lib/domain/stand";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { buildStoragePath, putObject } from "@/lib/storage";

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
      if (editionIsReadOnly(bundle.edition.status)) throw new WorkflowError(EDITION_LOCKED_MESSAGE);
      assertItemOpen(bundle);

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

      // A photo must be one uploaded for this record (uploadInstallPhoto).
      if (
        data.photoPath &&
        !photoPathBelongsTo(
          data.photoPath,
          session.organisation.id,
          bundle.edition.id,
          row.entityType,
          row.entityId,
        )
      ) {
        throw new WorkflowError("That photo does not belong to this item — take it again");
      }

      // Photo requirement for the Installed confirmation.
      if (
        row.stepNameSnapshot === "Installed" &&
        data.decision === "confirm" &&
        isSignage &&
        (bundle as { item: { kind: string } }).item.kind === "signage" &&
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
        await notifyPendingAssignees(
          tx,
          b as NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>,
          newlyPending(run, res.instances),
        );
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
          summary: decisionSummary(row.stepNameSnapshot, data),
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
          summary: decisionSummary(row.stepNameSnapshot, data),
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
      if (editionIsReadOnly(bundle.edition.status)) throw new WorkflowError(EDITION_LOCKED_MESSAGE);
      assertItemOpen(bundle);
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
      const [target] = await tx
        .select({ role: memberships.role })
        .from(memberships)
        .where(
          and(
            eq(memberships.userId, parsed.data.toUserId),
            eq(memberships.organisationId, session.organisation.id),
          ),
        )
        .limit(1);
      if (!target || target.role === "viewer") {
        throw new WorkflowError("Pick a team member who can sign off");
      }
      if (parsed.data.toUserId === (row.assignedUserId ?? session.user.id)) {
        throw new WorkflowError("This step is already with that person");
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
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
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
        const persisted = await persistRun(tx, "signage_item", bundle.item.id, res.instances);
        await notifyPendingAssignees(tx, bundle, newlyPending(run, persisted));
      } else {
        // Whole run restarts as a new run; the old one stays in history.
        const instances = await startItemRun(tx, bundle, new Date());
        await notifyPendingAssignees(tx, bundle, instances);
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

/** Deleted or held items take no decisions until restored or resumed. */
const DECISION_WORDS: Record<string, string> = {
  approve: "approved",
  approve_with_conditions: "approved with conditions",
  request_changes: "changes requested",
  reject: "rejected",
  confirm: "confirmed",
};

/** "Marketing sign-off: changes requested — “Logo too small”" for the History tab. */
function decisionSummary(
  step: string,
  data: { decision: string; comment?: string; conditionsText?: string },
) {
  const note = data.conditionsText?.trim() || data.comment?.trim();
  return `${step}: ${DECISION_WORDS[data.decision] ?? data.decision}${note ? ` — “${note}”` : ""}`;
}

function photoPrefix(orgId: string, editionId: string, entityType: string, entityId: string) {
  return `${orgId}/${editionId}/${entityType}/${entityId}/`;
}

function photoPathBelongsTo(
  path: string,
  orgId: string,
  editionId: string,
  entityType: string,
  entityId: string,
) {
  return (
    path.startsWith(photoPrefix(orgId, editionId, entityType, entityId)) &&
    !path.includes("..") &&
    !path.includes("//")
  );
}

const PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_PHOTO_BYTES = 15 * 1024 * 1024;

/**
 * Store an install / build-check photo for a pending confirmation step and
 * return its path, which the confirmation then carries (checked above).
 */
export async function uploadInstallPhoto(
  formData: FormData,
): Promise<ActionResult<{ photoPath: string }>> {
  const instanceId = formData.get("instanceId");
  const file = formData.get("file");
  if (typeof instanceId !== "string" || !(file instanceof File))
    return fail("Choose a photo first");
  if (!z.string().uuid().safeParse(instanceId).success) return fail("Invalid request");
  if (file.size === 0) return fail("That photo is empty — take it again");
  if (file.size > MAX_PHOTO_BYTES) return fail("That photo is too large (15 MB max)");
  if (!PHOTO_TYPES.includes(file.type)) return fail("Use a JPG, PNG or WebP photo");

  const session = await requireSession();
  try {
    const row = await db.query.approvalInstances.findFirst({
      where: eq(approvalInstances.id, instanceId),
    });
    if (!row || row.status !== "pending" || row.stepKindSnapshot !== "confirmation") {
      return fail("This step is no longer waiting for a photo");
    }
    const isSignage = row.entityType === "signage_item";
    const bundle = isSignage
      ? await loadItemBundle(db, row.entityId)
      : await loadStandBundle(db, row.entityId);
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    const stepCtx: ApprovalStepCtx = {
      assignedRole: row.assignedRole,
      assignedUserId: row.assignedUserId,
      entity: isSignage
        ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
        : { type: "stand", sub: standAuthzCtx(bundle as never) },
    };
    if (!can(session.actor, { type: "approval.decide", step: stepCtx })) {
      return fail("This step is not assigned to you");
    }
    const ext = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg";
    const photoPath = buildStoragePath({
      organisationId: session.organisation.id,
      editionId: bundle.edition.id,
      entityType: row.entityType,
      entityId: row.entityId,
      fileName: `install-photo.${ext}`,
    });
    await putObject("photos", photoPath, Buffer.from(await file.arrayBuffer()));
    return success({ photoPath }, "Photo added");
  } catch (err) {
    console.error("uploadInstallPhoto", err);
    return fail("Could not save the photo — check your signal and try again");
  }
}

function assertItemOpen(bundle: object) {
  const item = (bundle as { item?: { deletedAt: Date | null; status: string } }).item;
  if (!item) return;
  if (item.deletedAt) throw new WorkflowError("This item has been deleted");
  if (item.status === "on_hold") {
    throw new WorkflowError("This item is on hold — decisions resume when it is resumed");
  }
}
