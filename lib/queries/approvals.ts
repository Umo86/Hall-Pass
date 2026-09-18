import "server-only";
import { sql } from "drizzle-orm";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances } from "@/lib/db/schema";
import { can, type ApprovalStepCtx } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx } from "@/lib/domain/stand";
import { rowToInstance } from "@/lib/workflow/persist";

/** My Sign-offs: pending instances assigned to the current user. */
export async function pendingInstancesForUser(existing?: Session) {
  const session = existing ?? (await requireSession());
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(eq(approvalInstances.status, "pending"))
    .orderBy(sql`${approvalInstances.dueAt} ASC NULLS LAST`);

  const now = Date.now();
  const out = [];
  for (const row of rows) {
    const isSignage = row.entityType === "signage_item";
    const bundle = isSignage
      ? await loadItemBundle(db, row.entityId)
      : await loadStandBundle(db, row.entityId);
    if (!bundle) continue;
    const stepCtx: ApprovalStepCtx = {
      assignedRole: row.assignedRole,
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
