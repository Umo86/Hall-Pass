"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { roleLabel } from "@/lib/format";
import { departmentFallbackText, firstName } from "@/lib/users/rules";
import { removeUser } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { FieldError } from "./person-fields";

export type RemovalImpactView = {
  name: string;
  openTasks: number;
  ownedItems: number;
  waiting: { count: number; refs: string[] };
  departments: { id: string; name: string; isMain: boolean; others: string[] }[];
  namedSteps: string[];
  candidates: { userId: string; name: string; role: string }[];
};

function count(n: number, one: string, many: string) {
  return `${n} ${n === 1 ? one : many}`;
}

/**
 * "Remove from team", at the bottom of a person's page. The dialog says
 * exactly what happens to their work before anything is removed.
 */
export function RemoveUser({
  userId,
  impact,
  currentUserId,
}: {
  userId: string;
  impact: RemovalImpactView;
  currentUserId: string;
}) {
  const [open, setOpen] = useState(false);
  const [handTo, setHandTo] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const name = firstName(impact.name);
  const blocked = impact.namedSteps.length > 0;
  const needsHandover = impact.waiting.count > 0;
  const moves = [
    impact.openTasks > 0 ? count(impact.openTasks, "open task", "open tasks") : null,
    impact.ownedItems > 0 ? count(impact.ownedItems, "item", "items") : null,
  ].filter(Boolean);
  const candidates = [...impact.candidates].sort(
    (a, b) => Number(b.userId === currentUserId) - Number(a.userId === currentUserId),
  );

  function confirm() {
    setError(null);
    if (needsHandover && !handTo) {
      setError(`Choose who takes over ${name}'s sign-offs`);
      return;
    }
    start(async () => {
      const res = await removeUser({ userId, handToUserId: handTo || null });
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

  return (
    <section
      className="border-destructive/40 space-y-2 rounded-lg border p-4 sm:p-6"
      aria-labelledby="remove-h"
    >
      <h2 id="remove-h" className="text-sm font-semibold">
        Remove from team
      </h2>
      <p className="text-muted-foreground text-sm">
        For someone who has left. They lose access straight away; their work moves to you and
        nothing they did is deleted.
      </p>
      <Button
        type="button"
        variant="outline"
        className="border-destructive/50 text-destructive hover:text-destructive h-11 sm:h-9"
        onClick={() => {
          setError(null);
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
              They lose access straight away, including their calendar feed.
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
            <ul className="space-y-3 text-sm">
              <li>
                {moves.length > 0
                  ? `${moves.join(" and ")} will move to you.`
                  : `${name} has no open tasks or items to move.`}
              </li>
              {needsHandover && (
                <li className="space-y-1.5">
                  <Label htmlFor="handover">
                    {impact.waiting.count === 1
                      ? `A sign-off is waiting on ${name}`
                      : `${impact.waiting.count} sign-offs are waiting on ${name}`}{" "}
                    ({impact.waiting.refs.join(", ")}
                    {impact.waiting.count > impact.waiting.refs.length ? "…" : ""}) — hand{" "}
                    {impact.waiting.count === 1 ? "it" : "them"} to:
                  </Label>
                  <SelectNative
                    id="handover"
                    value={handTo}
                    onChange={(e) => setHandTo(e.target.value)}
                    className="h-11 sm:h-9"
                    aria-invalid={Boolean(error && !handTo)}
                  >
                    <option value="">Choose a person…</option>
                    {candidates.map((c) => (
                      <option key={c.userId} value={c.userId}>
                        {c.userId === currentUserId ? `${c.name} (you)` : c.name} —{" "}
                        {roleLabel(c.role)}
                      </option>
                    ))}
                  </SelectNative>
                </li>
              )}
              {impact.departments.map((d) => (
                <li key={d.id}>
                  {name} signs off for {d.name}
                  {d.isMain ? " (main approver)" : ""}.{" "}
                  <span
                    className={
                      d.others.length === 0 ? "font-medium text-amber-800 dark:text-amber-300" : ""
                    }
                  >
                    {departmentFallbackText(d)}
                  </span>
                </li>
              ))}
            </ul>
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
    </section>
  );
}
