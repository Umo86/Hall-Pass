import { formatDate, formatDateTime, roleLabel } from "@/lib/format";
import { cn } from "@/lib/utils";
import { DecideButtons } from "./decide-buttons";
import { DelegateButton } from "./delegate-button";
import type { PersonOption } from "@/components/people/groups";
import { STEP_STATE_CLASSES, isPast, stepStateLabel, waitingOnLabel } from "./step-words";

export type ChainInstance = {
  id: string;
  runNumber: number;
  stepName: string;
  stepKind: "approval" | "confirmation";
  sortOrder: number;
  status: string;
  assignedRole: string | null;
  assignedUserId: string | null;
  /** Department sign-offs: the department's name. */
  assignedDepartmentName?: string | null;
  deciderName: string | null;
  decidedAt: Date | null;
  decisionComment: string | null;
  conditionsText: string | null;
  lockedVersionLabel: string | null;
  dueAt: Date | null;
  delegatedFromName?: string | null;
  noSupplierFallback?: boolean;
  /** Name of the named person the step is assigned to, if any. */
  assigneeName?: string | null;
  /** For confirmations: the date it actually happened (YYYY-MM-DD). */
  confirmedOn?: string | null;
};

/** Who a step is with, in words ("Dana Director", "Marketing", "Supplier or Operations"). */
function holderOf(inst: ChainInstance): string | null {
  if (inst.noSupplierFallback) return "Operations (no supplier set)";
  if (
    inst.stepKind === "confirmation" &&
    inst.assignedRole === "supplier" &&
    !inst.assignedUserId
  ) {
    return "Supplier or Operations";
  }
  return waitingOnLabel({
    assignedUserId: inst.assignedUserId,
    assigneeName: inst.assignedUserId ? (inst.assigneeName ?? null) : null,
    departmentName: inst.assignedDepartmentName ?? null,
    roleName: inst.assignedRole ? roleLabel(inst.assignedRole) : null,
  });
}

/** A step's state in the decided words, e.g. "Waiting on Marketing", "Not started". */
export function StepStateBadge({
  status,
  who,
  className,
}: {
  status: string;
  who?: string | null;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        STEP_STATE_CLASSES[status] ?? STEP_STATE_CLASSES.waiting,
        status === "invalidated" && "line-through",
        className,
      )}
    >
      {stepStateLabel(status, who)}
    </span>
  );
}

export function ApprovalChain({
  instances,
  currentRun,
  canDecideIds,
  canDelegateIds,
  currentVersionId,
  requiresInstallPhoto,
  delegatableUsers,
  itemRef,
}: {
  instances: ChainInstance[];
  currentRun: number;
  canDecideIds: Set<string>;
  canDelegateIds: Set<string>;
  currentVersionId: string | null;
  requiresInstallPhoto: boolean;
  delegatableUsers: PersonOption[];
  /** The record's ref, for the toast after a decision. */
  itemRef?: string;
}) {
  const runs = new Map<number, ChainInstance[]>();
  for (const i of instances) runs.set(i.runNumber, [...(runs.get(i.runNumber) ?? []), i]);
  const runNumbers = [...runs.keys()].sort((a, b) => b - a);

  return (
    <div className="space-y-6">
      {runNumbers.map((run) => {
        const steps = runs.get(run)!;
        // Sign-offs first, then the production confirmations, each under its
        // own heading when a round has both.
        const groups = (["approval", "confirmation"] as const)
          .map((kind) => ({ kind, steps: steps.filter((s) => s.stepKind === kind) }))
          .filter((g) => g.steps.length > 0);
        return (
          <div key={run} className="space-y-3">
            {runNumbers.length > 1 && (
              <h3 className="text-muted-foreground text-xs font-semibold tracking-wide uppercase">
                Round {run}
                {run === currentRun ? " (current)" : ""}
              </h3>
            )}
            {groups.map((group) => (
              <div key={group.kind} className="space-y-2">
                {groups.length > 1 && (
                  <h4 className="text-muted-foreground text-xs font-medium">
                    {group.kind === "approval"
                      ? "Sign-off"
                      : "Production and install — confirmed when each happens"}
                  </h4>
                )}
                <ol className="space-y-2">
                  {group.steps.map((inst) => (
                    <ChainStep
                      key={inst.id}
                      inst={inst}
                      isCurrentRun={run === currentRun}
                      canDecide={canDecideIds.has(inst.id)}
                      canDelegate={canDelegateIds.has(inst.id)}
                      currentVersionId={currentVersionId}
                      requiresInstallPhoto={requiresInstallPhoto}
                      delegatableUsers={delegatableUsers}
                      itemRef={itemRef}
                    />
                  ))}
                </ol>
              </div>
            ))}
          </div>
        );
      })}
    </div>
  );
}

function ChainStep({
  inst,
  isCurrentRun,
  canDecide,
  canDelegate,
  currentVersionId,
  requiresInstallPhoto,
  delegatableUsers,
  itemRef,
}: {
  inst: ChainInstance;
  isCurrentRun: boolean;
  canDecide: boolean;
  canDelegate: boolean;
  currentVersionId: string | null;
  requiresInstallPhoto: boolean;
  delegatableUsers: PersonOption[];
  itemRef?: string;
}) {
  const overdue = inst.status === "pending" && isPast(inst.dueAt);
  const superseded = inst.status === "invalidated";
  const who = holderOf(inst);
  return (
    <li
      className={cn(
        "rounded-lg border p-3",
        superseded && "opacity-60",
        inst.status === "pending" && "border-sky-300 dark:border-sky-800",
      )}
    >
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-medium">{inst.stepName}</span>
        <StepStateBadge status={inst.status} who={who} />
        {inst.status === "waiting" && who && (
          <span className="text-muted-foreground text-sm">then {who}</span>
        )}
        {inst.status === "pending" && inst.dueAt && (
          <span
            className={cn(
              "text-sm",
              overdue ? "text-destructive font-medium" : "text-muted-foreground",
            )}
          >
            due {formatDateTime(inst.dueAt)}
            {overdue ? " — overdue" : ""}
          </span>
        )}
        <div className="flex w-full items-center gap-2 sm:ml-auto sm:w-auto">
          {isCurrentRun && canDecide && (
            <DecideButtons
              instanceId={inst.id}
              stepKind={inst.stepKind}
              stepName={inst.stepName}
              expectedStatus={inst.status}
              expectedLockedVersionId={currentVersionId}
              requiresPhoto={inst.stepName === "Installed" && requiresInstallPhoto}
              itemRef={itemRef}
              compact
            />
          )}
          {isCurrentRun && canDelegate && inst.status === "pending" && (
            <DelegateButton
              instanceId={inst.id}
              users={delegatableUsers}
              currentUserId={inst.assignedUserId}
            />
          )}
        </div>
      </div>
      {(inst.decidedAt || inst.decisionComment || inst.conditionsText) && (
        <div className="text-muted-foreground mt-2 space-y-1 text-sm">
          {inst.decidedAt && (
            <p>
              {superseded ? (
                <>
                  Superseded — was decided by {inst.deciderName ?? "someone"} against{" "}
                  {inst.lockedVersionLabel ?? "an earlier version"}; a newer version replaced it
                </>
              ) : (
                <>
                  {inst.stepKind === "confirmation" && inst.confirmedOn
                    ? `Confirmed by ${inst.deciderName ?? "—"} — done ${formatDate(inst.confirmedOn)} (recorded ${formatDateTime(inst.decidedAt)})`
                    : `Decided by ${inst.deciderName ?? "—"} on ${formatDateTime(inst.decidedAt)}`}
                  {inst.lockedVersionLabel ? ` against ${inst.lockedVersionLabel}` : ""}
                </>
              )}
              {inst.delegatedFromName ? ` (delegated by ${inst.delegatedFromName})` : ""}
            </p>
          )}
          {inst.decisionComment && <p>“{inst.decisionComment}”</p>}
          {inst.conditionsText && (
            <p className="text-teal-800 dark:text-teal-300">Conditions: {inst.conditionsText}</p>
          )}
        </div>
      )}
    </li>
  );
}
