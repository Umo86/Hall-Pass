import { StatusBadge } from "@/components/status-badge";
import { formatDateTime, roleLabel, statusLabel } from "@/lib/format";
import { DecideButtons } from "./decide-buttons";
import { DelegateButton } from "./delegate-button";

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
};

export function ApprovalChain({
  instances,
  currentRun,
  canDecideIds,
  canDelegateIds,
  currentVersionId,
  requiresInstallPhoto,
  delegatableUsers,
}: {
  instances: ChainInstance[];
  currentRun: number;
  canDecideIds: Set<string>;
  canDelegateIds: Set<string>;
  currentVersionId: string | null;
  requiresInstallPhoto: boolean;
  delegatableUsers: { id: string; name: string }[];
}) {
  const runs = new Map<number, ChainInstance[]>();
  for (const i of instances) runs.set(i.runNumber, [...(runs.get(i.runNumber) ?? []), i]);
  const runNumbers = [...runs.keys()].sort((a, b) => b - a);

  return (
    <div className="space-y-6">
      {runNumbers.map((run) => (
        <div key={run}>
          {runNumbers.length > 1 && (
            <h3 className="text-muted-foreground mb-2 text-xs font-semibold tracking-wide uppercase">
              Round {run}
              {run === currentRun ? " (current)" : ""}
            </h3>
          )}
          <ol className="space-y-2">
            {runs.get(run)!.map((inst) => {
              const overdue =
                inst.status === "pending" && inst.dueAt && inst.dueAt.getTime() < Date.now();
              const superseded = inst.status === "invalidated";
              return (
                <li
                  key={inst.id}
                  className={`rounded-lg border p-3 ${superseded ? "opacity-60" : ""} ${
                    inst.status === "pending" ? "border-sky-300 dark:border-sky-800" : ""
                  }`}
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusBadge status={inst.status} />
                    <span className="font-medium">{inst.stepName}</span>
                    <span className="text-muted-foreground text-sm">
                      {inst.assignedUserId
                        ? (inst.assigneeName ?? "a named person")
                        : inst.assignedDepartmentName
                          ? `Anyone in ${inst.assignedDepartmentName}`
                          : inst.assignedRole
                          ? roleLabel(inst.assignedRole)
                          : ""}
                      {inst.noSupplierFallback ? " (no supplier set — assigned to ops)" : ""}
                    </span>
                    {inst.status === "pending" && inst.dueAt && (
                      <span
                        className={`text-sm ${overdue ? "text-destructive font-medium" : "text-muted-foreground"}`}
                      >
                        due {formatDateTime(inst.dueAt)}
                        {overdue ? " — overdue" : ""}
                      </span>
                    )}
                    <div className="ml-auto flex items-center gap-2">
                      {run === currentRun && canDecideIds.has(inst.id) && (
                        <DecideButtons
                          instanceId={inst.id}
                          stepKind={inst.stepKind}
                          stepName={inst.stepName}
                          expectedStatus={inst.status}
                          expectedLockedVersionId={currentVersionId}
                          requiresPhoto={inst.stepName === "Installed" && requiresInstallPhoto}
                          compact
                        />
                      )}
                      {run === currentRun &&
                        canDelegateIds.has(inst.id) &&
                        inst.status === "pending" && (
                          <DelegateButton instanceId={inst.id} users={delegatableUsers} />
                        )}
                    </div>
                  </div>
                  {(inst.decidedAt || inst.decisionComment || inst.conditionsText) && (
                    <div className="text-muted-foreground mt-2 space-y-1 text-sm">
                      {inst.decidedAt && (
                        <p>
                          {superseded ? (
                            <>
                              {statusLabel(inst.status)} — was decided by {inst.deciderName ?? "someone"}{" "}
                              against {inst.lockedVersionLabel ?? "an earlier version"}, superseded by a
                              newer version
                            </>
                          ) : (
                            <>
                              Decided by {inst.deciderName ?? "—"} on {formatDateTime(inst.decidedAt)}
                              {inst.lockedVersionLabel ? ` against ${inst.lockedVersionLabel}` : ""}
                            </>
                          )}
                          {inst.delegatedFromName ? ` (delegated by ${inst.delegatedFromName})` : ""}
                        </p>
                      )}
                      {inst.decisionComment && <p>“{inst.decisionComment}”</p>}
                      {inst.conditionsText && (
                        <p className="text-teal-800 dark:text-teal-300">
                          Conditions: {inst.conditionsText}
                        </p>
                      )}
                    </div>
                  )}
                </li>
              );
            })}
          </ol>
        </div>
      ))}
    </div>
  );
}
