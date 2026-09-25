/**
 * The workflow engine (brief section 6). Pure functions over in-memory
 * instances; a thin persistence layer in the server actions maps these to
 * the approval_instances table. Every rule here is unit tested.
 */
import { stepApplies } from "./conditions";
import { effectiveSignoffs, isDepartmentStep } from "./signoffs";
import {
  ConflictError,
  POSITIVE_STATUSES,
  WorkflowError,
  type Decision,
  type EngineSettings,
  type EntityCtx,
  type EntityEvent,
  type Instance,
  type StepDef,
} from "./types";

function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

let tmpCounter = 0;
function tmpId(stepId: string) {
  tmpCounter += 1;
  return `tmp-${stepId}-${tmpCounter}`;
}

function isSettled(i: Instance): boolean {
  return POSITIVE_STATUSES.includes(i.status);
}

/**
 * Stage key: instances sharing a non-null parallel group run together;
 * a null group means the step runs alone.
 */
function stageKey(i: { parallelGroup: number | null; sortOrder: number }): string {
  return i.parallelGroup != null ? `g:${i.parallelGroup}` : `s:${i.sortOrder}`;
}

/** Ordered stages (arrays of instances), by the minimum sort order within each. */
export function stages(instances: Instance[]): Instance[][] {
  const map = new Map<string, Instance[]>();
  for (const i of instances) {
    if (i.status === "invalidated") continue; // superseded rows are history
    const key = stageKey(i);
    const list = map.get(key) ?? [];
    list.push(i);
    map.set(key, list);
  }
  return [...map.values()].sort(
    (a, b) => Math.min(...a.map((i) => i.sortOrder)) - Math.min(...b.map((i) => i.sortOrder)),
  );
}

type ActivationOpts = {
  entity: EntityCtx;
  now: Date;
};

/**
 * Activation (brief 6.2): the first stage with undecided instances becomes
 * pending; everything after reverts to waiting. Also applies the supplier
 * fallback (brief 6.3) when a supplier step activates with no supplier set.
 */
export function activate(instances: Instance[], opts: ActivationOpts): Instance[] {
  const result = instances.map((i) => ({ ...i }));
  const ordered = stages(result);
  let activeFound = false;
  for (const stage of ordered) {
    const unsettled = stage.filter((i) => !isSettled(i) && i.status !== "skipped");
    if (!activeFound && unsettled.length > 0) {
      activeFound = true;
      for (const i of unsettled) {
        if (i.status === "waiting") {
          i.status = "pending";
          i.pendingSince = opts.now;
          i.dueAt = addDays(opts.now, i.slaDaysSnapshot ?? 0);
        }
        // Already pending (or changes_requested/rejected mid-flight): leave as is.
        if (
          i.status === "pending" &&
          i.assignedRole === "supplier" &&
          opts.entity.kind === "signage" &&
          !opts.entity.supplierId &&
          !i.noSupplierFallback
        ) {
          i.assignedRole = "ops";
          i.noSupplierFallback = true;
        }
      }
    } else if (activeFound) {
      for (const i of stage) {
        if (i.status === "pending") {
          i.status = "waiting";
          i.pendingSince = null;
          i.dueAt = null;
        }
      }
    }
  }
  return result;
}

export type CreateRunInput = {
  steps: StepDef[];
  entity: EntityCtx;
  settings: EngineSettings;
  runNumber: number;
  now: Date;
};

/**
 * Run creation (brief 6.1): one instance per step with snapshots; steps
 * whose conditions are all false are created as `skipped` so the full
 * chain stays visible. Then the first applicable stage activates.
 */
/**
 * Whether a step runs for this entity and who it goes to. Department steps
 * follow the item's sign-off choices (or the category defaults) and may name
 * a person; every other step follows its conditions and configured approver.
 */
function stepSetup(
  step: StepDef,
  entity: EntityCtx,
  settings: EngineSettings,
): Pick<Instance, "status" | "assignedRole" | "assignedUserId" | "assignedDepartmentId"> {
  const department = step.departmentId ?? null;
  const configured = {
    assignedRole: step.approverType === "role" && !department ? step.approverRole : null,
    assignedUserId: step.approverType === "user" ? step.approverUserId : null,
    assignedDepartmentId: department,
  };
  if (entity.kind === "signage" && isDepartmentStep(step)) {
    const choice = effectiveSignoffs([step], entity.category, entity.signoffs ?? null).find(
      (p) => p.stepId === step.id,
    );
    if (!choice) return { status: "skipped", ...configured };
    if (entity.signoffs) {
      // An explicit choice: a named person, or anyone in the department.
      return choice.userId
        ? {
            status: "waiting",
            assignedRole: null,
            assignedUserId: choice.userId,
            assignedDepartmentId: department,
          }
        : {
            status: "waiting",
            assignedRole: department ? null : step.approverRole,
            assignedUserId: null,
            assignedDepartmentId: department,
          };
    }
    return { status: "waiting", ...configured };
  }
  return {
    status: stepApplies(step.conditions, entity, settings) ? "waiting" : "skipped",
    ...configured,
  };
}

export function createRun(input: CreateRunInput): Instance[] {
  const { steps, entity, settings, runNumber, now } = input;
  const instances: Instance[] = [...steps]
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((step) => ({
      id: tmpId(step.id),
      stepId: step.id,
      runNumber,
      stepName: step.name,
      stepKind: step.kind,
      sortOrder: step.sortOrder,
      parallelGroup: step.parallelGroup,
      ...stepSetup(step, entity, settings),
      delegatedFromUserId: null,
      decidedBy: null,
      decidedAt: null,
      decisionComment: null,
      conditionsText: null,
      lockedVersionType: null,
      lockedVersionId: null,
      lockedSha256: null,
      pendingSince: null,
      dueAt: null,
      holdShiftDays: 0,
      invalidateOnNewVersion: step.invalidateOnNewVersion,
      restartFromHereOnChanges: step.restartFromHereOnChanges,
      slaDaysSnapshot: step.slaDays,
    }));
  return activate(instances, { entity, now });
}

export type DecideOpts = {
  instanceId: string;
  decision: Decision;
  decidedBy: string;
  now: Date;
  entity: EntityCtx;
  /** Optimistic concurrency: what the client saw when it opened the screen. */
  expectedStatus: string;
  expectedLockedVersionId: string | null;
  /** The current version the decision locks against. */
  lockedVersionType: "artwork_version" | "submission_version" | null;
  lockedVersionId: string | null;
  lockedSha256: string | null;
};

export type DecideResult = {
  instances: Instance[];
  entityEvent: EntityEvent;
  decided: Instance;
};

/** Decisions (brief 6.3), including the optimistic-lock check. */
export function applyDecision(instances: Instance[], opts: DecideOpts): DecideResult {
  const found = instances.find((i) => i.id === opts.instanceId);
  if (!found) throw new WorkflowError("Approval step not found");

  // Optimistic concurrency: the client decides against what it saw.
  if (found.status !== opts.expectedStatus) throw new ConflictError();
  if ((opts.expectedLockedVersionId ?? null) !== (opts.lockedVersionId ?? null)) {
    throw new ConflictError();
  }
  if (found.status !== "pending") {
    throw new WorkflowError("Only pending steps can be decided");
  }

  const d = opts.decision;
  if (found.stepKind === "approval" && d.type === "confirm") {
    throw new WorkflowError("Approval steps take approve/reject decisions, not confirmations");
  }
  if (found.stepKind === "confirmation" && d.type !== "confirm") {
    throw new WorkflowError("Confirmation steps can only be confirmed");
  }
  if (d.type === "approve_with_conditions" && !d.conditionsText.trim()) {
    throw new WorkflowError("Conditions are required when approving with conditions");
  }
  if (d.type === "request_changes" && !d.comment.trim()) {
    throw new WorkflowError("A comment is required when requesting changes");
  }
  if (d.type === "reject" && !d.comment.trim()) {
    throw new WorkflowError("A comment is required when rejecting");
  }

  const result = instances.map((i) => ({ ...i }));
  const inst = result.find((i) => i.id === opts.instanceId)!;
  inst.decidedBy = opts.decidedBy;
  inst.decidedAt = opts.now;
  inst.decisionComment = "comment" in d ? (d.comment ?? null) : null;
  inst.lockedVersionType = opts.lockedVersionType;
  inst.lockedVersionId = opts.lockedVersionId;
  inst.lockedSha256 = opts.lockedSha256;

  switch (d.type) {
    case "approve":
      inst.status = "approved";
      break;
    case "approve_with_conditions":
      inst.status = "approved_with_conditions";
      inst.conditionsText = d.conditionsText;
      break;
    case "request_changes":
      inst.status = "changes_requested";
      return { instances: result, entityEvent: { type: "changes_requested" }, decided: inst };
    case "reject":
      inst.status = "rejected";
      return { instances: result, entityEvent: { type: "rejected" }, decided: inst };
    case "confirm":
      inst.status = "confirmed";
      break;
  }

  // The run is approved once every approval-kind step is settled. The
  // confirmation steps that follow (sent to print, delivered, installed,
  // build check) then track production on an approved item; they move the
  // entity through their own events in the action, never re-approving it.
  const next = activate(result, { entity: opts.entity, now: opts.now });
  if (inst.stepKind === "approval") {
    const approvals = result.filter((i) => i.status !== "invalidated" && i.stepKind === "approval");
    if (approvals.every(isSettled)) {
      const anyConditions = approvals.some((i) => i.conditionsText && i.conditionsText.trim());
      return {
        instances: next,
        entityEvent: { type: anyConditions ? "run_approved_with_conditions" : "run_approved" },
        decided: inst,
      };
    }
  }
  return { instances: next, entityEvent: { type: "none" }, decided: inst };
}

export type ResubmitResult =
  | { mode: "restart_from_step"; instances: Instance[] }
  | { mode: "new_run" };

/**
 * Changes-requested restart (brief 6.3). If the requesting step restarts
 * from itself (default), every instance from that step onwards resets and
 * earlier approvals stand; otherwise the whole run restarts as a new run.
 */
export function resubmitAfterChanges(
  instances: Instance[],
  opts: { entity: EntityCtx; now: Date },
): ResubmitResult {
  const requester = instances.find((i) => i.status === "changes_requested");
  if (!requester) throw new WorkflowError("No step has requested changes");
  if (!requester.restartFromHereOnChanges) return { mode: "new_run" };

  const fromOrder = requester.sortOrder;
  const result = instances.map((i) => ({ ...i }));
  for (const i of result) {
    if (i.status === "invalidated" || i.status === "skipped") continue;
    if (i.sortOrder >= fromOrder) {
      i.status = "waiting";
      i.decidedBy = null;
      i.decidedAt = null;
      i.decisionComment = null;
      i.conditionsText = null;
      i.lockedVersionType = null;
      i.lockedVersionId = null;
      i.lockedSha256 = null;
      i.pendingSince = null;
      i.dueAt = null;
    }
  }
  return { mode: "restart_from_step", instances: activate(result, opts) };
}

export type InvalidationResult = {
  instances: Instance[];
  /** Instances that were invalidated (for notifying their approvers). */
  invalidated: Instance[];
};

/**
 * Invalidation on new version (brief 6.4). Every decided instance in the
 * current run whose step invalidates on a new version is superseded and a
 * fresh instance is created in position; steps that don't invalidate keep
 * their decision.
 */
export function invalidateOnNewVersion(
  instances: Instance[],
  opts: { entity: EntityCtx; now: Date },
): InvalidationResult {
  const decidedStatuses = ["approved", "approved_with_conditions", "confirmed"];
  const result: Instance[] = [];
  const invalidated: Instance[] = [];

  for (const original of instances) {
    const i = { ...original };
    if (decidedStatuses.includes(i.status) && i.invalidateOnNewVersion) {
      i.status = "invalidated";
      invalidated.push(i);
      result.push(i);
      result.push({
        ...original,
        id: tmpId(i.stepId),
        status: "waiting",
        decidedBy: null,
        decidedAt: null,
        decisionComment: null,
        conditionsText: null,
        lockedVersionType: null,
        lockedVersionId: null,
        lockedSha256: null,
        pendingSince: null,
        dueAt: null,
        delegatedFromUserId: null,
      });
    } else {
      result.push(i);
    }
  }
  if (invalidated.length === 0) return { instances: result, invalidated };
  return { instances: activate(result, opts), invalidated };
}

/** Delegation (brief 6.3): the delegate decides as themselves; both notified. */
export function applyDelegation(
  instances: Instance[],
  opts: { instanceId: string; toUserId: string; fromUserId: string },
): Instance[] {
  const found = instances.find((i) => i.id === opts.instanceId);
  if (!found) throw new WorkflowError("Approval step not found");
  if (found.status !== "pending") throw new WorkflowError("Only pending steps can be delegated");
  return instances.map((i) =>
    i.id === opts.instanceId
      ? { ...i, assignedUserId: opts.toUserId, delegatedFromUserId: opts.fromUserId }
      : i,
  );
}

/** Hold shifting (brief 5.1): on resume, due dates shift by the hold duration. */
export function applyHoldShift(instances: Instance[], days: number): Instance[] {
  if (days <= 0) return instances.map((i) => ({ ...i }));
  return instances.map((i) => {
    if (i.status !== "pending" || !i.dueAt) return { ...i };
    return { ...i, dueAt: addDays(i.dueAt, days), holdShiftDays: i.holdShiftDays + days };
  });
}
