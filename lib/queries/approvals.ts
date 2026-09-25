import "server-only";
import { and, eq, inArray, isNull, or, sql, type SQL } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances } from "@/lib/db/schema";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { standsEnabled } from "@/lib/config";
import { rowToInstance } from "@/lib/workflow/persist";

/**
 * Which pending steps could be this person's, narrowed in SQL so My Work
 * doesn't load every open sign-off in the organisation. can() still makes
 * the final call on each row.
 */
function candidateFilter(session: Session, all: boolean): SQL | undefined {
  const actor = session.actor;
  const me = eq(approvalInstances.assignedUserId, actor.userId);
  if (actor.kind === "staff") {
    if (actor.role === "admin") {
      return all ? undefined : or(me, eq(approvalInstances.assignedRole, "admin"));
    }
    const depts = actor.departmentIds ?? [];
    return or(
      me,
      and(isNull(approvalInstances.assignedUserId), eq(approvalInstances.assignedRole, actor.role)),
      depts.length > 0
        ? and(
            isNull(approvalInstances.assignedUserId),
            inArray(approvalInstances.assignedDepartmentId, depts),
          )
        : undefined,
    );
  }
  const roles = [...new Set(actor.grants.map((g) => g.role))];
  if (roles.length === 0) return me;
  return or(
    me,
    and(isNull(approvalInstances.assignedUserId), inArray(approvalInstances.assignedRole, roles)),
  );
}

/**
 * My Work sign-offs: pending steps the current user can decide. Admins see
 * the ones addressed to them unless `all` is set. Deleted, held and archived
 * items are left out until they are restored or resumed.
 */
export async function pendingInstancesForUser(
  existing?: Session,
  opts: { all?: boolean } = {},
) {
  const session = existing ?? (await requireSession());
  const filter = candidateFilter(session, opts.all ?? false);
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(
      and(
        eq(approvalInstances.status, "pending"),
        standsEnabled ? undefined : eq(approvalInstances.entityType, "signage_item"),
        filter,
      ),
    )
    .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`);

  const bundles = await Promise.all(
    rows.map((row) =>
      row.entityType === "signage_item"
        ? loadItemBundle(db, row.entityId)
        : loadStandBundle(db, row.entityId),
    ),
  );

  const now = Date.now();
  const out = [];
  for (const [index, row] of rows.entries()) {
    const bundle = bundles[index];
    if (!bundle) continue;
    if (editionIsReadOnly(bundle.edition.status)) continue;
    const isSignage = row.entityType === "signage_item";
    if (isSignage) {
      const item = (bundle as NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>).item;
      if (item.deletedAt || item.status === "on_hold") continue;
    }
    const stepCtx: ApprovalStepCtx = {
      assignedRole: row.assignedRole,
      assignedDepartmentId: row.assignedDepartmentId,
      assignedUserId: row.assignedUserId,
      entity: isSignage
        ? { type: "signage_item", item: itemAuthzCtx(bundle as never) }
        : { type: "stand", sub: standAuthzCtx(bundle as never) },
    };
    if (!can(session.actor, { type: "approval.decide", step: stepCtx })) continue;
    out.push({
      row: rowToInstance(row),
      raw: row,
      bundle,
      isSignage,
      isOverdue: Boolean(row.dueAt && row.dueAt.getTime() < now),
    });
  }
  return out;
}
