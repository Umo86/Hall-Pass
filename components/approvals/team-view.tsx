"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BellRing } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { remindApproval } from "@/app/actions/approvals";
import { formatDate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { DecideOnBehalf } from "./decide-buttons";
import { OverduePill } from "./review-sheet";

export type TeamRowView = {
  instanceId: string;
  ref: string;
  name: string;
  href: string;
  eventName: string;
  stepName: string;
  stepKind: "approval" | "confirmation";
  dueAt: string | null;
  overdueDays: number | null;
  waitingOn: string;
  groupKey: string;
  people: string[];
  expectedLockedVersionId: string | null;
  canRemind: boolean;
  remindedToday: boolean;
  /** In the viewer's own Waiting on me (so not "on their behalf"). */
  isMine: boolean;
  canDecide: boolean;
  requiresPhoto: boolean;
};

/**
 * Approvals → Everyone's: every open sign-off grouped by who it is waiting
 * on, to chase. Remind tells them (once a day per sign-off); deciding for
 * someone else is tucked away under "Decide on their behalf…".
 */
export function TeamView({ rows }: { rows: TeamRowView[] }) {
  // One group per name: a department's sign-offs and its role's
  // confirmations ("Operations") sit together.
  const groups = new Map<string, TeamRowView[]>();
  for (const r of rows) groups.set(r.waitingOn, [...(groups.get(r.waitingOn) ?? []), r]);
  const ordered = [...groups.values()].sort(
    (a, b) =>
      b.filter((r) => r.overdueDays !== null).length -
        a.filter((r) => r.overdueDays !== null).length || b.length - a.length,
  );
  return (
    <div className="space-y-6">
      {ordered.map((list) => (
        <TeamGroup key={list[0].waitingOn} rows={list} />
      ))}
    </div>
  );
}

function TeamGroup({ rows }: { rows: TeamRowView[] }) {
  const who = rows[0].waitingOn;
  const overdue = rows.filter((r) => r.overdueDays !== null).length;
  const people = [...new Set(rows.flatMap((r) => r.people))];
  const remindable = rows.filter((r) => r.canRemind && !r.remindedToday).map((r) => r.instanceId);
  return (
    <section aria-label={`Waiting on ${who}`} className="space-y-2 rounded-lg border p-3">
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <div className="min-w-0 flex-1">
          <h3 className="text-sm font-semibold">
            {who}: {rows.length} waiting
            {overdue > 0 && <span className="text-destructive">, {overdue} overdue</span>}
          </h3>
          {people.length > 0 && (
            <p className="text-muted-foreground truncate text-xs">{people.join(", ")}</p>
          )}
        </div>
        {remindable.length > 0 && (
          <RemindButton
            ids={remindable}
            label={`Remind all (${remindable.length})`}
            variant="outline"
          />
        )}
      </div>
      <ol className="divide-y">
        {rows.map((row) => (
          <li
            key={row.instanceId}
            className="flex flex-col gap-2 py-2 sm:flex-row sm:items-center sm:gap-x-3"
          >
            <div className="min-w-0 flex-1">
              <p className="text-sm">
                <Link href={row.href} className="link font-medium">
                  {row.ref}
                </Link>{" "}
                — {row.name}
              </p>
              <p className="text-muted-foreground flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs">
                <span>{row.stepName}</span>
                <span aria-hidden>·</span>
                <span>{row.eventName}</span>
                {row.dueAt && (
                  <>
                    <span aria-hidden>·</span>
                    <span
                      className={cn(row.overdueDays !== null && "text-destructive font-medium")}
                    >
                      due {formatDate(row.dueAt)}
                    </span>
                  </>
                )}
                {row.overdueDays !== null && <OverduePill days={row.overdueDays} />}
              </p>
              <p className="text-xs">
                <span className="text-muted-foreground">Waiting on:</span> {row.waitingOn}
              </p>
            </div>
            <div className="-ml-3 flex items-center gap-1 sm:ml-0">
              <Button asChild size="sm" variant="ghost">
                <Link href={row.href} aria-label={`Open ${row.ref}`}>
                  Open
                </Link>
              </Button>
              {row.canRemind &&
                (row.remindedToday ? (
                  <span className="text-muted-foreground px-2 text-xs">Reminded today</span>
                ) : (
                  <RemindButton ids={[row.instanceId]} label="Remind" refLabel={row.ref} />
                ))}
              {row.isMine ? (
                <Button asChild size="sm" variant="outline">
                  <Link href={`/approvals?tab=mine&q=${encodeURIComponent(row.ref)}`}>Decide</Link>
                </Button>
              ) : (
                row.canDecide && (
                  <DecideOnBehalf
                    instanceId={row.instanceId}
                    stepKind={row.stepKind}
                    stepName={row.stepName}
                    expectedStatus="pending"
                    expectedLockedVersionId={row.expectedLockedVersionId}
                    requiresPhoto={row.requiresPhoto}
                    itemRef={row.ref}
                    itemName={row.name}
                    itemHref={row.href}
                    onBehalfOf={{ who: row.waitingOn, people: row.people }}
                  />
                )
              )}
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}

function RemindButton({
  ids,
  label,
  refLabel,
  variant = "ghost",
}: {
  ids: string[];
  label: string;
  refLabel?: string;
  variant?: "ghost" | "outline";
}) {
  const [pending, start] = useTransition();
  const [sent, setSent] = useState(false);
  const router = useRouter();
  return (
    <Button
      size="sm"
      variant={variant}
      disabled={pending || sent}
      aria-label={refLabel ? `Remind about ${refLabel}` : undefined}
      onClick={() =>
        start(async () => {
          const res = await remindApproval({ instanceIds: ids });
          if (!res.ok) {
            toast.error(res.error);
            return;
          }
          setSent(true);
          toast.success(res.message ?? "Reminder sent");
          router.refresh();
        })
      }
    >
      <BellRing aria-hidden />
      {pending ? "Sending…" : sent ? "Reminded" : label}
    </Button>
  );
}
