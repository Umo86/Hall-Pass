/**
 * Keeping sign-off notifications honest: "Please sign off", reminders and
 * delegations are settled (marked read) once the person no longer has a
 * step waiting on that record — decided by them or a colleague, delegated,
 * superseded by a new version, or the item held, deleted or archived.
 *
 * Call settleApprovalNotifications(tx, type, id) in the same transaction as
 * any change that can end someone's turn; the daily cron runs it as a
 * safety net for anything missed.
 */
import { and, eq, inArray, isNull } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { approvalInstances, memberships, notifications } from "@/lib/db/schema";
import { loadItemBundle, resolveAssigneeUserIds } from "@/lib/domain/signage";
import { loadStandBundle } from "@/lib/domain/stand";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { resolveNotifications } from "@/lib/notify";
import { APPROVAL_REQUEST_KINDS } from "@/lib/notification-kinds";

export type ApprovalEntityType = "signage_item" | "stand_submission";

type PendingStep = {
  assignedRole: string | null;
  assignedUserId: string | null;
  assignedDepartmentId?: string | null;
  stepKindSnapshot?: string;
  stepKind?: string;
};

/**
 * Everyone who could act on one step: its assignees, plus Operations for a
 * supplier's confirmation (they can confirm it themselves).
 */
export async function stepHolderIds(
  exec: Db | Tx,
  ctx: {
    organisationId: string;
    editionId: string;
    venueId: string;
    item: { supplierId: string | null; sponsorId: string | null } | null;
  },
  step: PendingStep,
): Promise<string[]> {
  const ids = await resolveAssigneeUserIds(
    exec,
    ctx.organisationId,
    ctx.editionId,
    ctx.venueId,
    ctx.item,
    step,
  );
  const kind = step.stepKindSnapshot ?? step.stepKind;
  if (kind === "confirmation" && step.assignedRole === "supplier" && !step.assignedUserId) {
    const ops = await exec
      .select({ userId: memberships.userId })
      .from(memberships)
      .where(and(eq(memberships.organisationId, ctx.organisationId), eq(memberships.role, "ops")));
    ids.push(...ops.map((o) => o.userId));
  }
  return [...new Set(ids)];
}

/**
 * The people who still have a sign-off step waiting on a record. Nobody,
 * when the record is gone, held or in an archived event.
 */
export async function approvalHolderIds(
  exec: Db | Tx,
  entityType: ApprovalEntityType,
  entityId: string,
  opts: { ignoreInstanceIds?: string[] } = {},
): Promise<Set<string>> {
  const holders = new Set<string>();
  let ctx: Parameters<typeof stepHolderIds>[1] | null = null;
  if (entityType === "signage_item") {
    const bundle = await loadItemBundle(exec, entityId);
    if (
      bundle &&
      !bundle.item.deletedAt &&
      bundle.item.status !== "on_hold" &&
      !editionIsReadOnly(bundle.edition.status)
    ) {
      ctx = {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        venueId: bundle.venue.id,
        item: bundle.item,
      };
    }
  } else {
    const bundle = await loadStandBundle(exec, entityId);
    if (bundle && !editionIsReadOnly(bundle.edition.status)) {
      ctx = {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        venueId: bundle.venue.id,
        item: null,
      };
    }
  }
  if (!ctx) return holders;
  const pending = await exec
    .select()
    .from(approvalInstances)
    .where(
      and(
        eq(approvalInstances.entityType, entityType),
        eq(approvalInstances.entityId, entityId),
        eq(approvalInstances.status, "pending"),
      ),
    );
  const ignore = new Set(opts.ignoreInstanceIds ?? []);
  for (const step of pending) {
    if (ignore.has(step.id)) continue;
    for (const id of await stepHolderIds(exec, ctx, step)) holders.add(id);
  }
  return holders;
}

/**
 * Settle the sign-off requests on a record for everyone whose turn is over.
 * Returns how many notifications were settled.
 *
 * After a decision, call it before telling the people whose turn has just
 * started, passing those steps as `newlyPending`: everything asked of
 * anyone so far is then settled except for steps that are still running,
 * and the new requests (sent afterwards) stay unread.
 */
export async function settleApprovalNotifications(
  exec: Db | Tx,
  entityType: ApprovalEntityType,
  entityId: string,
  opts: { newlyPending?: string[] } = {},
): Promise<number> {
  const holders = await approvalHolderIds(exec, entityType, entityId, {
    ignoreInstanceIds: opts.newlyPending,
  });
  return resolveNotifications(exec, {
    entityType,
    entityId,
    kinds: APPROVAL_REQUEST_KINDS,
    exceptUserIds: [...holders],
  });
}

/**
 * Daily safety net: settle unread sign-off requests whose step ended
 * somewhere that doesn't settle them itself (a new version, a hold, a
 * delete). Looks at up to `limit` records per run.
 */
export async function settleStaleApprovalNotifications(
  exec: Db | Tx,
  limit = 500,
): Promise<{ records: number; settled: number }> {
  const open = await exec
    .selectDistinct({ entityType: notifications.entityType, entityId: notifications.entityId })
    .from(notifications)
    .where(
      and(
        isNull(notifications.readAt),
        inArray(notifications.kind, [...APPROVAL_REQUEST_KINDS]),
        inArray(notifications.entityType, ["signage_item", "stand_submission"]),
      ),
    )
    .limit(limit);
  let settled = 0;
  for (const row of open) {
    if (!row.entityId || !row.entityType) continue;
    settled += await settleApprovalNotifications(
      exec,
      row.entityType as ApprovalEntityType,
      row.entityId,
    );
  }
  return { records: open.length, settled };
}
