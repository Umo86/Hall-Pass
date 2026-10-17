"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import type { Feature, PermissionOverrides, StaffRole } from "@/lib/authz";
import { departmentFallbackText, firstName } from "@/lib/users/rules";
import {
  canWorkOwnItem,
  ITEM_KIND_LABEL,
  type HandoverGroup,
  type ItemKind,
} from "@/lib/users/handover";
import { removeUser } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { PersonPicker } from "@/components/people/person-picker";
import type { PersonOption } from "@/components/people/groups";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { FieldError } from "./person-fields";
import {
  defaultHandover,
  HandoverFields,
  missingHandover,
  type HandoverCandidateView,
} from "./handover-fields";

export type RemovalImpactView = {
  name: string;
  openTasks: number;
  ownedItems: number;
  ownedByKind: Partial<Record<ItemKind, number>>;
  handover: { groups: HandoverGroup[]; candidates: HandoverCandidateView[] };
  departments: { id: string; name: string; isMain: boolean; others: string[] }[];
  namedSteps: string[];
  /** Live partner access they hold here; removing them revokes it. */
  partnerAccess?: string[];
  workCandidates: {
    userId: string;
    name: string;
    role: StaffRole;
    features: Feature[] | null;
    overrides: PermissionOverrides;
    jobTitle: string | null;
    departmentId: string | null;
    departmentName: string | null;
  }[];
};

function count(n: number, one: string, many: string) {
  return `${n} ${n === 1 ? one : many}`;
}

/**
 * "Remove from team" (super admins), at the bottom of a person's page. The
 * dialog says what happens to their work and lets you choose who takes
 * each department's sign-offs and who gets their tasks and items (you by
 * default) before anything is removed.
 */
export function RemoveUser({
  userId,
  impact,
  currentUserId,
  currentUserName,
}: {
  userId: string;
  impact: RemovalImpactView;
  currentUserId: string;
  currentUserName: string;
}) {
  const [open, setOpen] = useState(false);
  const [choice, setChoice] = useState(() => defaultHandover(impact.handover.groups));
  const [workTo, setWorkTo] = useState(currentUserId);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const name = firstName(impact.name);
  const blocked = impact.namedSteps.length > 0;
  const groups = impact.handover.groups;
  const hasWork = impact.openTasks + impact.ownedItems > 0;
  const worker = impact.workCandidates.find((c) => c.userId === workTo);
  // Kinds of item the person picked can't work on: those come to you.
  const toYou = useMemo(() => {
    if (!worker) return [] as [ItemKind, number][];
    return (Object.entries(impact.ownedByKind) as [ItemKind, number][]).filter(
      ([kind]) => !canWorkOwnItem(worker, kind),
    );
  }, [worker, impact.ownedByKind]);
  // The one person picker: you first, then your department, then the rest.
  const me = impact.workCandidates.find((c) => c.userId === currentUserId);
  const people: PersonOption[] = [
    ...(me
      ? []
      : [
          {
            id: currentUserId,
            name: currentUserName,
            jobTitle: null,
            departmentId: null,
            departmentName: null,
            unavailable: null,
          },
        ]),
    ...impact.workCandidates.map((c) => ({
      id: c.userId,
      name: c.name,
      jobTitle: c.jobTitle,
      departmentId: c.departmentId,
      departmentName: c.departmentName,
      unavailable: null,
    })),
  ];

  function confirm() {
    setError(null);
    const missing = missingHandover(groups, choice, name);
    if (missing) {
      setError(missing);
      return;
    }
    start(async () => {
      const res = await removeUser({
        userId,
        handTo: groups.length ? choice : null,
        workToUserId: workTo === currentUserId ? null : workTo,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toast.success(res.message ?? `${impact.name} removed`);
      setOpen(false);
      router.push("/users");
      router.refresh();
    });
  }

  const moves = [
    impact.openTasks > 0 ? count(impact.openTasks, "open task", "open tasks") : null,
    impact.ownedItems > 0
      ? count(impact.ownedItems, "item still being worked on", "items still being worked on")
      : null,
  ].filter(Boolean);

  return (
    <div className="border-destructive/40 space-y-2 rounded-md border p-3">
      <h3 className="text-sm font-semibold">Remove from team</h3>
      <p className="text-muted-foreground text-sm">
        For someone who has left. They lose access straight away; you choose who takes over their
        work. What they did stays in every item&apos;s history.
      </p>
      <Button
        type="button"
        variant="outline"
        className="border-destructive/50 text-destructive hover:text-destructive h-11 sm:h-9"
        onClick={() => {
          setError(null);
          setChoice(defaultHandover(groups));
          setOpen(true);
        }}
      >
        Remove {name}…
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Remove {impact.name} from the team?</DialogTitle>
            <DialogDescription>
              They lose access straight away, including their calendar feed. To pause their access
              instead, suspend them.
            </DialogDescription>
          </DialogHeader>
          {blocked ? (
            <p
              role="alert"
              className="flex gap-2 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200"
            >
              <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
              {name} is named on {impact.namedSteps.join(", ")}. Pick someone else in that workflow
              first.
            </p>
          ) : (
            <div className="space-y-4 text-sm">
              {hasWork ? (
                <div className="space-y-1.5">
                  <Label htmlFor="remove-work-to">
                    {name} has {moves.join(" and ")} — hand them to:
                  </Label>
                  <PersonPicker
                    id="remove-work-to"
                    people={people}
                    meId={currentUserId}
                    meDepartmentId={me?.departmentId ?? null}
                    value={workTo}
                    onChange={setWorkTo}
                    className="h-11 sm:h-9"
                  />
                  {toYou.length > 0 && (
                    <p className="text-muted-foreground text-xs">
                      {worker?.name} can&apos;t work on{" "}
                      {toYou
                        .map(([k, n]) => count(n, ITEM_KIND_LABEL[k].one, ITEM_KIND_LABEL[k].many))
                        .join(" or ")}
                      , so {toYou.length === 1 && toYou[0][1] === 1 ? "it moves" : "those move"} to
                      you.
                    </p>
                  )}
                  <p className="text-muted-foreground text-xs">
                    Finished items and archived events keep {name} as owner.
                  </p>
                </div>
              ) : (
                <p>{name} has no open tasks or items to hand over.</p>
              )}
              {groups.length > 0 && (
                <HandoverFields
                  idPrefix="remove"
                  groups={groups}
                  candidates={impact.handover.candidates}
                  value={choice}
                  onChange={setChoice}
                  who={name}
                  currentUserId={currentUserId}
                />
              )}
              {impact.departments.length > 0 && (
                <ul className="space-y-1">
                  {impact.departments.map((d) => (
                    <li key={d.id}>
                      {name} signs off for {d.name}
                      {d.isMain ? " (main approver)" : ""}.{" "}
                      <span
                        className={
                          d.others.length === 0
                            ? "font-medium text-amber-800 dark:text-amber-300"
                            : ""
                        }
                      >
                        {departmentFallbackText(d)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
              {(impact.partnerAccess?.length ?? 0) > 0 && (
                <p>
                  {name} also has portal access here ({impact.partnerAccess!.join(", ")}). Removing
                  them revokes it, so they can&apos;t sign in to the portal either.
                </p>
              )}
            </div>
          )}
          <FieldError message={error} />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            {!blocked && (
              <Button type="button" variant="destructive" disabled={pending} onClick={confirm}>
                {pending ? "Removing…" : `Remove ${name}`}
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
