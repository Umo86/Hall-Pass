"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, inArray, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import {
  approvalInstances,
  memberships,
  reminderLog,
  signageItems,
  standSubmissions,
  users,
} from "@/lib/db/schema";
import {
  abilityOn,
  can,
  seesEdition,
  type ApprovalStepCtx,
  type PermissionOverrides,
} from "@/lib/authz";
import { loadTeam, taskRefusal } from "@/lib/people";
import { canReceiveSignoff } from "@/lib/access";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { actorScope } from "@/lib/queries/edition-scope";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { signageTransition } from "@/lib/status/signage";
import { standTransition } from "@/lib/status/stand";
import {
  applyDecision,
  applyDelegation,
  ConflictError,
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
  resubmitItemInTx,
} from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, standEntityCtx } from "@/lib/domain/stand";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { buildStoragePath, putObject } from "@/lib/storage";
import { itemPath } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";
import { statusLabel } from "@/lib/format";
import { settleApprovalNotifications, stepHolderIds } from "@/lib/domain/notifications";
import { reminderMessages, type ManualReminder } from "@/lib/domain/notifications-digest";
import { daysOverdue } from "@/components/approvals/step-words";

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
  const res = await decideOne(session, parsed.data);
  if (res.ok) revalidatePath("/", "layout");
  return res;
}

const confirmManySchema = z
  .object({
    rows: z
      .array(
        z
          .object({
            instanceId: z.string().uuid(),
            expectedLockedVersionId: z.string().nullable(),
          })
          .strict(),
      )
      .min(1, "Select something to confirm first")
      .max(200),
    confirmedDate: z.string().date(),
  })
  .strict();

export type ConfirmManyResult = { results: { instanceId: string; ok: boolean; error?: string }[] };

/**
 * Confirm several print, delivery or install steps with one date (Approvals
 * → To confirm). Each is decided on its own, in its own transaction, with
 * the same checks and audit row as confirming it alone; the pages are
 * revalidated once at the end rather than once per step.
 */
export async function confirmApprovals(input: unknown): Promise<ActionResult<ConfirmManyResult>> {
  const parsed = confirmManySchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0]?.message ?? "Invalid request");
  const session = await requireSession();
  const results: ConfirmManyResult["results"] = [];
  for (const row of parsed.data.rows) {
    const res = await decideOne(session, {
      instanceId: row.instanceId,
      decision: "confirm",
      confirmedDate: parsed.data.confirmedDate,
      expectedStatus: "pending",
      expectedLockedVersionId: row.expectedLockedVersionId,
    });
    results.push(
      res.ok
        ? { instanceId: row.instanceId, ok: true }
        : { instanceId: row.instanceId, ok: false, error: res.error },
    );
  }
  if (results.some((r) => r.ok)) revalidatePath("/", "layout");
  return success({ results });
}

/** One decision in its own transaction; the caller revalidates. */
async function decideOne(
  session: Session,
  data: z.infer<typeof decideSchema>,
): Promise<ActionResult> {
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
        ? await loadItemBundle(tx, row.entityId, actorScope(session))
        : await loadStandBundle(tx, row.entityId, actorScope(session));
      if (!bundle) throw new WorkflowError("Record not found");
      if (editionIsReadOnly(bundle.edition.status)) throw new WorkflowError(EDITION_LOCKED_MESSAGE);
      assertItemOpen(bundle);

      const stepCtx: ApprovalStepCtx = {
        assignedRole: row.assignedRole,
        assignedDepartmentId: row.assignedDepartmentId,
        stepKind: row.stepKindSnapshot,
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

      // Nothing goes "to print" without a printer to send it to.
      if (
        data.decision === "confirm" &&
        row.stepNameSnapshot === "Sent to print" &&
        isSignage &&
        !(bundle as { item: { supplierId: string | null } }).item.supplierId
      ) {
        throw new WorkflowError(
          "Set the supplier on the Details tab first (anyone who can edit costs can) before confirming it has gone to print",
        );
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

      // Who the step was with, to tell them when someone else decides it.
      const holdersBefore =
        row.stepKindSnapshot === "approval"
          ? await stepHolderIds(
              tx,
              {
                organisationId: bundle.organisation.id,
                editionId: bundle.edition.id,
                venueId: bundle.venue.id,
                item: isSignage
                  ? (bundle as { item: typeof signageItems.$inferSelect }).item
                  : null,
              },
              row,
            )
          : [];
      const onBehalf = holdersBefore.length > 0 && !holdersBefore.includes(session.user.id);
      const deciderName = session.user.fullName || session.user.email;

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
      // The real-world date of a confirmation (defaults to today).
      const confirmedOn =
        data.decision === "confirm" ? (data.confirmedDate ?? todayInLondon()) : null;
      if (confirmedOn && confirmedOn > todayInLondon()) {
        throw new WorkflowError("The date cannot be in the future");
      }
      if (confirmedOn) {
        await tx
          .update(approvalInstances)
          .set({ confirmedOn })
          .where(eq(approvalInstances.id, data.instanceId));
      }
      const confirmedAt = confirmedOn ? new Date(`${confirmedOn}T12:00:00Z`) : new Date();

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
          let next = signageTransition(item.status, event);
          const set: Partial<typeof signageItems.$inferInsert> = { status: next };
          if (event === "sent_to_print") set.sentToPrintAt = confirmedAt;
          if (event === "delivered") set.deliveredAt = confirmedAt;
          if (event === "installed") {
            set.installedAt = confirmedAt;
            set.installedBy = session.user.id;
            if (data.photoPath) set.installPhotoPath = data.photoPath;
            // Installed again after a Reopen while snags are still open: it
            // is installed but snagged, not cleanly installed.
            const [openSnags] = await tx.execute<{ n: number }>(
              sql`SELECT count(*)::int AS n FROM snags
                  WHERE signage_item_id = ${item.id} AND status IN ('open', 'in_progress')`,
            );
            if (Number(openSnags?.n ?? 0) > 0) {
              next = signageTransition(next, "snag_opened");
              set.status = next;
            }
          }
          await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
          statusNote = ` — item now ${statusLabel(next)}`;
        }
        // Signed off with nobody to print it: tell Operations now, not at "Sent to print".
        const needsPrint = res.instances.some(
          (i) =>
            i.stepKind === "confirmation" &&
            i.stepName === "Sent to print" &&
            i.status !== "skipped" &&
            i.status !== "invalidated",
        );
        if (
          (event === "run_approved" || event === "run_approved_with_conditions") &&
          !item.supplierId &&
          needsPrint
        ) {
          // Whoever can set the supplier (costs.edit; Operations by default),
          // with access — super admins can, but aren't chased for it.
          const team = await loadTeam(tx, session.organisation.id);
          const setters = team.filter(
            (m) =>
              m.role !== "admin" &&
              !taskRefusal(m) &&
              abilityOn(m, "costs.edit") &&
              (m.features === null || m.features.includes("signage")) &&
              seesEdition(m, edition.id),
          );
          await notify(tx, {
            userIds: setters.map((o) => o.userId),
            kind: "supplier_needed",
            title: `${item.ref} is approved but has no supplier — set one before it can go to print`,
            body: `${item.name}, ${edition.code}. Choose the supplier on the item's Details tab.`,
            link: itemPath(edition.code, item),
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        // Notify the owner of the decision; notify next assignees.
        if (item.ownerUserId) {
          await notify(tx, {
            userIds: [item.ownerUserId],
            kind: "decision_made",
            title: `${row.stepNameSnapshot}: ${DECISION_WORDS[data.decision] ?? data.decision} — ${item.ref}`,
            body: data.comment || data.conditionsText || undefined,
            link: itemPath(edition.code, item),
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        // "Please sign off" for this item is done for everyone whose turn is
        // over; then the people whose turn starts now are told.
        const started = newlyPending(run, res.instances);
        await settleApprovalNotifications(tx, "signage_item", item.id, {
          newlyPending: started.map((i) => i.id),
        });
        await notifyPendingAssignees(
          tx,
          b as NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>,
          started,
        );
        if (onBehalf) {
          await notify(tx, {
            userIds: holdersBefore,
            kind: "decision_made",
            title: `${deciderName} decided ${row.stepNameSnapshot} on ${item.ref} for you: ${DECISION_WORDS[data.decision]}`,
            body: data.comment || data.conditionsText || undefined,
            link: `${itemPath(edition.code, item)}?tab=artwork`,
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
            confirmedOn,
            lockedVersionId: currentVersionId,
            ...(onBehalf ? { onBehalfOf: holdersBefore } : {}),
          },
          summary: `${decisionSummary(row.stepNameSnapshot, data)}${onBehalf ? ` — for ${await namesOf(tx, holdersBefore)}` : ""}`,
          ...(onBehalf ? { subjectUserId: subjectOf(row.assignedUserId, holdersBefore) } : {}),
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
          statusNote = ` — submission now ${statusLabel(next)}`;
        }
        await settleApprovalNotifications(tx, "stand_submission", sub.id, {
          newlyPending: newlyPending(run, res.instances).map((i) => i.id),
        });
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
        if (onBehalf) {
          await notify(tx, {
            userIds: holdersBefore,
            kind: "decision_made",
            title: `${deciderName} decided ${row.stepNameSnapshot} on ${sub.ref} for you: ${DECISION_WORDS[data.decision]}`,
            body: data.comment || data.conditionsText || undefined,
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
            ...(onBehalf ? { onBehalfOf: holdersBefore } : {}),
          },
          summary: `${decisionSummary(row.stepNameSnapshot, data)}${onBehalf ? ` — for ${await namesOf(tx, holdersBefore)}` : ""}`,
          ...(onBehalf ? { subjectUserId: subjectOf(row.assignedUserId, holdersBefore) } : {}),
        });
      }
      return statusNote;
    });
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
        ? await loadItemBundle(tx, row.entityId, actorScope(session))
        : await loadStandBundle(tx, row.entityId, actorScope(session));
      if (!bundle) throw new WorkflowError("Record not found");
      if (editionIsReadOnly(bundle.edition.status)) throw new WorkflowError(EDITION_LOCKED_MESSAGE);
      assertItemOpen(bundle);
      const stepCtx: ApprovalStepCtx = {
        assignedRole: row.assignedRole,
        assignedDepartmentId: row.assignedDepartmentId,
        stepKind: row.stepKindSnapshot,
        assignedUserId: row.assignedUserId,
        entity: isSignage
          ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
          : { type: "stand", sub: standAuthzCtx(bundle as never) },
      };
      if (!can(session.actor, { type: "approval.delegate", step: stepCtx })) {
        throw new WorkflowError("You cannot delegate this step");
      }
      const [target] = await tx
        .select({
          role: memberships.role,
          overrides: memberships.permissionOverrides,
          suspendedAt: memberships.suspendedAt,
          accessEndsAt: memberships.accessEndsAt,
          editionIds: memberships.editionIds,
          fullName: users.fullName,
          email: users.email,
        })
        .from(memberships)
        .innerJoin(users, eq(users.id, memberships.userId))
        .where(
          and(
            eq(memberships.userId, parsed.data.toUserId),
            eq(memberships.organisationId, session.organisation.id),
          ),
        )
        .limit(1);
      // Only someone who can sign now: active, not a viewer, sign-off not paused.
      if (
        !target ||
        !canReceiveSignoff({ ...target, overrides: target.overrides as PermissionOverrides })
      ) {
        throw new WorkflowError("Pick a team member who can sign off");
      }
      // Users → Events: never to someone who can't open the event.
      if (!seesEdition(target, bundle.edition.id)) {
        throw new WorkflowError(
          `${target.fullName || target.email} can't open this event — pick someone who can`,
        );
      }
      // A department-wide step can be taken by anyone; only refuse a no-op.
      if (row.assignedUserId && parsed.data.toUserId === row.assignedUserId) {
        throw new WorkflowError("This step is already with that person");
      }
      // Who it was waiting on before, to record and tell them.
      const holdersBefore = await stepHolderIds(
        tx,
        {
          organisationId: bundle.organisation.id,
          editionId: bundle.edition.id,
          venueId: bundle.venue.id,
          item: isSignage ? (bundle as { item: typeof signageItems.$inferSelect }).item : null,
        },
        row,
      );
      const run = await loadRun(tx, row.entityType, row.entityId, row.runNumber);
      const updated = applyDelegation(run, {
        instanceId: parsed.data.instanceId,
        toUserId: parsed.data.toUserId,
        fromUserId: session.user.id,
      });
      await persistRun(tx, row.entityType, row.entityId, updated);
      // The step left everyone it was with; their requests are settled
      // before the delegate is told (so theirs stays unread).
      await settleApprovalNotifications(tx, row.entityType, row.entityId);
      const ref = isSignage
        ? (bundle as { item: { ref: string } }).item.ref
        : (bundle as { sub: { ref: string } }).sub.ref;
      const link = isSignage
        ? `${itemPath(bundle.edition.code, (bundle as { item: { kind: string; ref: string } }).item)}?tab=artwork`
        : `/${bundle.edition.code}/stands/${ref}`;
      const actorName = session.user.fullName || session.user.email;
      const toName = await namesOf(tx, [parsed.data.toUserId]);
      await notify(tx, {
        userIds: [parsed.data.toUserId, session.user.id],
        kind: "delegation",
        title: `Step delegated: ${row.stepNameSnapshot} on ${ref}`,
        body: `Delegated by ${actorName}`,
        link,
        entityType: row.entityType,
        entityId: row.entityId,
      });
      // The people it was waiting on hear it has moved (unless they moved it).
      const others = holdersBefore.filter(
        (id) => id !== session.user.id && id !== parsed.data.toUserId,
      );
      if (others.length > 0) {
        await notify(tx, {
          userIds: others,
          kind: "delegation",
          title: `${row.stepNameSnapshot} on ${ref} is now with ${toName}`,
          body: `${actorName} handed it to ${toName}; you don't need to do anything.`,
          link,
          entityType: row.entityType,
          entityId: row.entityId,
        });
      }
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: row.entityType,
        entityId: row.entityId,
        action: "delegate",
        before: {
          step: row.stepNameSnapshot,
          assignedUserId: row.assignedUserId,
          holders: holdersBefore,
        },
        after: {
          step: row.stepNameSnapshot,
          toUserId: parsed.data.toUserId,
          fromUserId: row.assignedUserId,
        },
        summary: `${row.stepNameSnapshot} delegated to ${toName}${holdersBefore.length ? ` (was with ${await namesOf(tx, holdersBefore)})` : ""}`,
        subjectUserId: subjectOf(row.assignedUserId, holdersBefore),
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Step delegated — both parties notified");
  } catch (err) {
    if (err instanceof WorkflowError) return fail(err.message);
    return fail(err instanceof Error ? err.message : "Something went wrong");
  }
}

/**
 * Resubmit a signage item after changes were requested (brief 6.3). The
 * work is resubmitItemInTx (lib/domain/signage.ts), shared with the item
 * page's "Send back for sign-off" and upload-and-send.
 */
export async function resubmitSignageItem(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const bundle = await loadItemBundle(db, parsed.data.id, actorScope(session));
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "signage.submit", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot resubmit this item");
  }
  if (bundle.item.status !== "changes_requested") {
    return fail("Only items with changes requested can be resubmitted");
  }
  try {
    await db.transaction((tx) =>
      resubmitItemInTx(tx, bundle, { actorUserId: session.user.id, now: new Date() }),
    );
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
      ? await loadItemBundle(db, row.entityId, actorScope(session))
      : await loadStandBundle(db, row.entityId, actorScope(session));
    if (!bundle) return fail("Record not found");
    if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
    const stepCtx: ApprovalStepCtx = {
      assignedRole: row.assignedRole,
      assignedDepartmentId: row.assignedDepartmentId,
      stepKind: row.stepKindSnapshot,
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

const remindSchema = z.union([
  z.object({ instanceId: z.string().uuid() }),
  z.object({ instanceIds: z.array(z.string().uuid()).min(1).max(200) }),
]);

export type RemindResult = { reminded: number; alreadyToday: number; nobody: number };

/**
 * Chase sign-offs by hand ("Remind" / "Remind all" on Approvals →
 * Everyone's): tells whoever each step is waiting on, at most once a day per
 * step (the reminder log), and records it in the item's History. Who may
 * chase is approval.remind in lib/authz.ts (whoever can send the item for
 * sign-off; stands: whoever reviews them).
 */
export async function remindApproval(input: unknown): Promise<ActionResult<RemindResult>> {
  const parsed = remindSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const ids = [
    ...new Set("instanceId" in parsed.data ? [parsed.data.instanceId] : parsed.data.instanceIds),
  ];
  const session = await requireSession();
  if (session.actor.kind !== "staff") return fail("You cannot send reminders");
  const today = todayInLondon();
  const from = session.user.fullName || session.user.email;
  try {
    const result = await db.transaction(async (tx) => {
      const rows = await tx
        .select()
        .from(approvalInstances)
        .where(inArray(approvalInstances.id, ids));
      if (rows.length !== ids.length) throw new WorkflowError("Approval step not found");
      const reminders: ManualReminder[] = [];
      let alreadyToday = 0;
      let nobody = 0;
      for (const row of rows) {
        if (row.status !== "pending") {
          throw new WorkflowError(`${row.stepNameSnapshot} has already been decided`);
        }
        const isSignage = row.entityType === "signage_item";
        const bundle = isSignage
          ? await loadItemBundle(tx, row.entityId, actorScope(session))
          : await loadStandBundle(tx, row.entityId, actorScope(session));
        if (!bundle) throw new WorkflowError("Record not found");
        if (editionIsReadOnly(bundle.edition.status))
          throw new WorkflowError(EDITION_LOCKED_MESSAGE);
        assertItemOpen(bundle);
        const step: ApprovalStepCtx = {
          assignedRole: row.assignedRole,
          assignedDepartmentId: row.assignedDepartmentId,
          stepKind: row.stepKindSnapshot,
          assignedUserId: row.assignedUserId,
          entity: isSignage
            ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
            : { type: "stand", sub: standAuthzCtx(bundle as never) },
        };
        if (!can(session.actor, { type: "approval.remind", step })) {
          throw new WorkflowError("You cannot chase this sign-off");
        }
        const item = isSignage ? (bundle as { item: typeof signageItems.$inferSelect }).item : null;
        const ref = item ? item.ref : (bundle as { sub: { ref: string } }).sub.ref;
        const holders = (
          await stepHolderIds(
            tx,
            {
              organisationId: bundle.organisation.id,
              editionId: bundle.edition.id,
              venueId: bundle.venue.id,
              item,
            },
            row,
          )
        ).filter((id) => id !== session.user.id);
        if (holders.length === 0) {
          nobody++;
          continue;
        }
        // Once a day per step, whoever presses Remind.
        const logged = await tx
          .insert(reminderLog)
          .values({
            targetType: "approval_instance",
            targetId: row.id,
            kind: "chaser",
            sentOn: today,
          })
          .onConflictDoNothing()
          .returning({ id: reminderLog.id });
        if (logged.length === 0) {
          alreadyToday++;
          continue;
        }
        reminders.push({
          instanceId: row.id,
          ref,
          stepName: row.stepNameSnapshot,
          overdueDays:
            row.dueAt && row.dueAt.getTime() < Date.now() ? daysOverdue(row.dueAt, today) : 0,
          link: item
            ? `${itemPath(bundle.edition.code, item)}?tab=artwork`
            : `/${bundle.edition.code}/stands/${ref}`,
          entityType: row.entityType,
          entityId: row.entityId,
          assigneeIds: holders,
          editionId: bundle.edition.id,
        });
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          editionId: bundle.edition.id,
          actorUserId: session.user.id,
          entityType: row.entityType,
          entityId: row.entityId,
          action: "escalate",
          after: { step: row.stepNameSnapshot, instanceId: row.id, reminded: holders },
          summary: `Reminder sent for ${row.stepNameSnapshot} (${holders.length} ${holders.length === 1 ? "person" : "people"})`,
        });
      }
      for (const msg of reminderMessages(from, reminders, { listLink: "/approvals" })) {
        await notify(tx, {
          userIds: [msg.userId],
          kind: "approval_reminder",
          title: msg.title,
          body: msg.body,
          link: msg.link,
          editionId: msg.editionId,
          ...(msg.entity ? { entityType: msg.entity.type, entityId: msg.entity.id } : {}),
        });
      }
      return { reminded: reminders.length, alreadyToday, nobody };
    });
    revalidatePath("/approvals");
    const parts = [
      result.reminded > 0
        ? `${result.reminded === 1 ? "Reminder" : `${result.reminded} reminders`} sent`
        : null,
      result.alreadyToday > 0 ? `${result.alreadyToday} already reminded today` : null,
      result.nobody > 0 ? `${result.nobody} with nobody who can sign yet` : null,
    ].filter(Boolean);
    return success(result, parts.join(" · ") || "Nothing to remind");
  } catch (err) {
    if (err instanceof WorkflowError) return fail(err.message);
    console.error("remindApproval", err);
    return fail("Could not send the reminder — please try again");
  }
}

/**
 * The person an on-behalf decision or a delegation is about: the named
 * person on the step, or its only holder (none when several could act).
 */
function subjectOf(assignedUserId: string | null, holders: readonly string[]): string | null {
  if (assignedUserId) return assignedUserId;
  return holders.length === 1 ? holders[0] : null;
}

/** "Mia Marketing", "Mia Marketing and Olivia Ops", "3 people". */
async function namesOf(tx: Tx, ids: readonly string[]): Promise<string> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return "nobody";
  if (unique.length > 3) return `${unique.length} people`;
  const rows = await tx
    .select({ id: users.id, fullName: users.fullName, email: users.email })
    .from(users)
    .where(inArray(users.id, unique));
  const names = unique.map((id) => {
    const r = rows.find((x) => x.id === id);
    return r?.fullName || r?.email || "someone";
  });
  return names.length === 1 ? names[0] : `${names.slice(0, -1).join(", ")} and ${names.at(-1)}`;
}
