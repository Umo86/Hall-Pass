"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CalendarClock, PauseCircle, PlayCircle } from "lucide-react";
import { toast } from "sonner";
import type { HandoverGroup } from "@/lib/users/handover";
import type { PersonStatus } from "@/lib/users/list";
import { reactivateUser, setAccessEnd, suspendUser } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { FieldError } from "./person-fields";
import { PersonStatusChip } from "./person-status";
import {
  defaultHandover,
  HandoverFields,
  missingHandover,
  type HandoverCandidateView,
} from "./handover-fields";
import { localToday } from "./add-user-form";

/**
 * A person's account on their page: whether they can sign in, Suspend…
 * (handing over the sign-offs that name them) or Reactivate, and the date
 * their access ends. Read-only, with the reason, for people the viewer
 * can't change (and on your own page).
 */
export function AccountCard({
  kind,
  id,
  name,
  firstName,
  status,
  statusText,
  suspendedLine,
  accessEndsOn,
  lockedReason,
  handover,
  candidates,
  currentUserId,
  children,
}: {
  kind: "member" | "invite";
  /** User id (member) or invitation id. */
  id: string;
  name: string;
  firstName: string;
  status: PersonStatus;
  statusText: string;
  /** "Suspended since 3 Oct 2026 by Alex Admin". */
  suspendedLine: string | null;
  /** The London date their access ends (for the date field). */
  accessEndsOn: string | null;
  /** Set when the viewer can't change their access (why). */
  lockedReason: string | null;
  handover: HandoverGroup[];
  candidates: HandoverCandidateView[];
  currentUserId: string;
  /** Remove…, below the rest (super admins). */
  children?: React.ReactNode;
}) {
  const [pending, start] = useTransition();
  const [suspending, setSuspending] = useState(false);
  const [choice, setChoice] = useState(() => defaultHandover(handover));
  const [error, setError] = useState<string | null>(null);
  const [date, setDate] = useState(accessEndsOn ?? "");
  const [dateError, setDateError] = useState<string | null>(null);
  const router = useRouter();
  const suspended = status === "suspended";
  const member = kind === "member";

  function suspend() {
    setError(null);
    const missing = missingHandover(handover, choice, firstName);
    if (missing) {
      setError(missing);
      return;
    }
    start(async () => {
      const res = await suspendUser({ userId: id, handTo: handover.length ? choice : null });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toast.success(res.message ?? `${name} suspended`);
      setSuspending(false);
      router.refresh();
    });
  }

  function reactivate() {
    start(async () => {
      const res = await reactivateUser({ userId: id });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? `${name} can sign in again`);
      router.refresh();
    });
  }

  function saveDate(next: string | null) {
    setDateError(null);
    if (next && next < localToday()) {
      setDateError("Choose today or a later date for access to end");
      return;
    }
    start(async () => {
      const res = await setAccessEnd(
        member ? { userId: id, date: next } : { inviteId: id, date: next },
      );
      if (!res.ok) {
        setDateError(res.error);
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? "Saved");
      if (!next) setDate("");
      router.refresh();
    });
  }

  const dateChanged = (date || null) !== (accessEndsOn ?? null);

  return (
    <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-labelledby="account-h">
      <div className="flex flex-wrap items-center gap-2">
        <h2 id="account-h" className="text-sm font-semibold">
          Account
        </h2>
        <PersonStatusChip status={status} text={statusText} />
      </div>
      {suspendedLine && <p className="text-sm">{suspendedLine}</p>}
      {lockedReason ? (
        <p className="text-muted-foreground text-sm">{lockedReason}</p>
      ) : (
        <>
          {member && (
            <div className="space-y-1.5">
              <div className="flex flex-wrap gap-2">
                {suspended ? (
                  <Button
                    type="button"
                    className="h-11 sm:h-9"
                    disabled={pending}
                    onClick={reactivate}
                  >
                    <PlayCircle aria-hidden />
                    Reactivate {firstName}
                  </Button>
                ) : (
                  <Button
                    type="button"
                    variant="outline"
                    className="h-11 sm:h-9"
                    disabled={pending}
                    onClick={() => {
                      setError(null);
                      setChoice(defaultHandover(handover));
                      setSuspending(true);
                    }}
                  >
                    <PauseCircle aria-hidden />
                    Suspend {firstName}…
                  </Button>
                )}
              </div>
              <p className="text-muted-foreground text-xs">
                {suspended
                  ? "Reactivating gives back exactly what they had."
                  : "Suspending stops them signing in until they're reactivated; nothing they have is taken away."}
              </p>
            </div>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="account-end" className="inline-flex items-center gap-1.5">
              <CalendarClock className="size-4" aria-hidden />
              Access ends
            </Label>
            <div className="flex flex-wrap items-center gap-2">
              <Input
                id="account-end"
                type="date"
                min={localToday()}
                value={date}
                onChange={(e) => setDate(e.target.value)}
                aria-invalid={Boolean(dateError)}
                className="h-11 w-auto sm:h-9"
              />
              {dateChanged && date && (
                <Button
                  type="button"
                  className="h-11 sm:h-9"
                  disabled={pending}
                  onClick={() => saveDate(date)}
                >
                  Save end date
                </Button>
              )}
              {accessEndsOn && (
                <Button
                  type="button"
                  variant="ghost"
                  className="h-11 sm:h-9"
                  disabled={pending}
                  onClick={() => saveDate(null)}
                >
                  Clear
                </Button>
              )}
            </div>
            <p className="text-muted-foreground text-xs">
              {accessEndsOn
                ? `They keep access to the end of that day (London time), then can't sign in.`
                : "No end date. Set one for freelancers and temporary staff."}
            </p>
            <FieldError message={dateError} />
          </div>
        </>
      )}
      {children}

      <Dialog open={suspending} onOpenChange={setSuspending}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Suspend {name}?</DialogTitle>
            <DialogDescription>
              They can&apos;t sign in, aren&apos;t sent anything and aren&apos;t offered for work
              until you reactivate them. Their tasks, items and departments stay as they are.
            </DialogDescription>
          </DialogHeader>
          {handover.length > 0 ? (
            <div className="space-y-2">
              <p className="text-sm">
                Sign-offs that name {firstName} go to someone who can sign for that department:
              </p>
              <HandoverFields
                idPrefix="suspend"
                groups={handover}
                candidates={candidates}
                value={choice}
                onChange={setChoice}
                who={firstName}
                currentUserId={currentUserId}
              />
            </div>
          ) : (
            <p className="text-muted-foreground text-sm">
              No sign-offs are waiting on {firstName}.
            </p>
          )}
          <FieldError message={error} />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setSuspending(false)}>
              Cancel
            </Button>
            <Button type="button" variant="destructive" disabled={pending} onClick={suspend}>
              {pending ? "Suspending…" : `Suspend ${firstName}`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}
