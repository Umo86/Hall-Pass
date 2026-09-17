/**
 * Persistence bridge between the pure engine and the approval_instances
 * table. Engine instances with `tmp-` ids are inserted; the rest updated.
 */
import { and, eq } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { approvalInstances, workflowSteps } from "@/lib/db/schema";
import type { Instance, StepDef, WorkflowCondition } from "./types";

export type ApprovalEntityType = "signage_item" | "stand_submission";

export function stepRowToDef(row: typeof workflowSteps.$inferSelect): StepDef {
  return {
    id: row.id,
    sortOrder: row.sortOrder,
    parallelGroup: row.parallelGroup,
    name: row.name,
    kind: row.kind,
    approverType: row.approverType,
    approverRole: row.approverRole,
    approverUserId: row.approverUserId,
    conditions: row.conditions as WorkflowCondition[],
    slaDays: row.slaDays,
    invalidateOnNewVersion: row.invalidateOnNewVersion,
    restartFromHereOnChanges: row.restartFromHereOnChanges,
  };
}

export async function loadStepDefs(db: Db | Tx, workflowId: string): Promise<StepDef[]> {
  const rows = await db
    .select()
    .from(workflowSteps)
    .where(eq(workflowSteps.workflowId, workflowId))
    .orderBy(workflowSteps.sortOrder);
  return rows.map(stepRowToDef);
}

export function rowToInstance(row: typeof approvalInstances.$inferSelect): Instance {
  return {
    id: row.id,
    stepId: row.workflowStepId,
    runNumber: row.runNumber,
    stepName: row.stepNameSnapshot,
    stepKind: row.stepKindSnapshot,
    sortOrder: row.sortOrderSnapshot,
    parallelGroup: row.parallelGroupSnapshot,
    status: row.status,
    assignedRole: row.assignedRole,
    assignedUserId: row.assignedUserId,
    delegatedFromUserId: row.delegatedFromUserId,
    decidedBy: row.decidedBy,
    decidedAt: row.decidedAt,
    decisionComment: row.decisionComment,
    conditionsText: row.conditionsText,
    lockedVersionType: row.lockedVersionType,
    lockedVersionId: row.lockedVersionId,
    lockedSha256: row.lockedSha256,
    pendingSince: row.pendingSince,
    dueAt: row.dueAt,
    holdShiftDays: row.holdShiftDays,
    // Snapshot semantics live on the instance row via the flags below.
    invalidateOnNewVersion: row.invalidateOnNewVersionSnapshot,
    restartFromHereOnChanges: row.restartFromHereSnapshot,
    slaDaysSnapshot: row.slaDaysSnapshot,
    noSupplierFallback: row.noSupplierFallback ?? undefined,
  };
}

export async function loadRun(
  db: Db | Tx,
  entityType: ApprovalEntityType,
  entityId: string,
  runNumber: number,
): Promise<Instance[]> {
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(
      and(
        eq(approvalInstances.entityType, entityType),
        eq(approvalInstances.entityId, entityId),
        eq(approvalInstances.runNumber, runNumber),
      ),
    )
    .orderBy(approvalInstances.sortOrderSnapshot, approvalInstances.createdAt);
  return rows.map(rowToInstance);
}

export async function loadAllRuns(
  db: Db | Tx,
  entityType: ApprovalEntityType,
  entityId: string,
): Promise<Instance[]> {
  const rows = await db
    .select()
    .from(approvalInstances)
    .where(
      and(eq(approvalInstances.entityType, entityType), eq(approvalInstances.entityId, entityId)),
    )
    .orderBy(approvalInstances.runNumber, approvalInstances.sortOrderSnapshot);
  return rows.map(rowToInstance);
}

function instanceToRow(entityType: ApprovalEntityType, entityId: string, i: Instance) {
  return {
    entityType,
    entityId,
    runNumber: i.runNumber,
    workflowStepId: i.stepId,
    stepNameSnapshot: i.stepName,
    stepKindSnapshot: i.stepKind,
    sortOrderSnapshot: i.sortOrder,
    parallelGroupSnapshot: i.parallelGroup,
    status: i.status,
    assignedRole: i.assignedRole,
    assignedUserId: i.assignedUserId,
    delegatedFromUserId: i.delegatedFromUserId,
    decidedBy: i.decidedBy,
    decidedAt: i.decidedAt,
    decisionComment: i.decisionComment,
    conditionsText: i.conditionsText,
    lockedVersionType: i.lockedVersionType,
    lockedVersionId: i.lockedVersionId,
    lockedSha256: i.lockedSha256,
    pendingSince: i.pendingSince,
    dueAt: i.dueAt,
    holdShiftDays: i.holdShiftDays,
    invalidateOnNewVersionSnapshot: i.invalidateOnNewVersion,
    restartFromHereSnapshot: i.restartFromHereOnChanges,
    slaDaysSnapshot: i.slaDaysSnapshot ?? 0,
    noSupplierFallback: i.noSupplierFallback ?? false,
  };
}

/**
 * Write the state of a run back: temp ids insert, real ids update.
 * Returns the instances with their database ids.
 */
export async function persistRun(
  tx: Tx,
  entityType: ApprovalEntityType,
  entityId: string,
  instances: Instance[],
): Promise<Instance[]> {
  const out: Instance[] = [];
  for (const i of instances) {
    if (i.id.startsWith("tmp-")) {
      const [row] = await tx
        .insert(approvalInstances)
        .values(instanceToRow(entityType, entityId, i))
        .returning();
      out.push({ ...i, id: row.id });
    } else {
      await tx
        .update(approvalInstances)
        .set(instanceToRow(entityType, entityId, i))
        .where(eq(approvalInstances.id, i.id));
      out.push(i);
    }
  }
  return out;
}
