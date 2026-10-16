"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, CheckCircle2, Copy, X } from "lucide-react";
import { toast } from "sonner";
import { bulkUsers, type BulkUserAction, type BulkUsersResult } from "@/app/actions/users";
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
import { useConfirm } from "@/components/confirm-dialog";
import { absoluteLink } from "./invite-actions";

export type BulkPick = {
  id: string;
  name: string;
  kind: "member" | "invite";
  status: "active" | "ending" | "invited" | "expired" | "suspended" | "ended";
};

/** What a bulk change did, kept on screen until dismissed. */
export type BulkUsersOutcome = { ok: boolean; message: string; result: BulkUsersResult | null };

const people = (n: number) => `${n} ${n === 1 ? "person" : "people"}`;

/** Today in the browser (YYYY-MM-DD), the earliest end date allowed. */
function localToday(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/**
 * The bar over the Users list while people are selected: send invitations
 * again, suspend or reactivate, set an end date, or cancel invitations.
 * Each person is changed on their own on the server; the outcome lists
 * anyone left alone and why.
 */
export function UsersBulkBar({
  picked,
  onOutcome,
  onClear,
}: {
  picked: BulkPick[];
  onOutcome: (outcome: BulkUsersOutcome) => void;
  onClear: () => void;
}) {
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const [dateOpen, setDateOpen] = useState(false);
  const [date, setDate] = useState("");
  const router = useRouter();
  const n = picked.length;
  const invites = picked.filter((p) => p.kind === "invite").length;
  const members = picked.filter((p) => p.kind === "member");
  const canSuspend = members.filter((p) => p.status !== "suspended").length;
  const canReactivate = members.filter((p) => p.status === "suspended").length;

  function run(action: BulkUserAction, extra: { date?: string | null } = {}) {
    start(async () => {
      const res = await bulkUsers({ ids: picked.map((p) => p.id), action, ...extra });
      setDateOpen(false);
      if (!res.ok) {
        toast.error(res.error);
        onOutcome({ ok: false, message: res.error, result: null });
        return;
      }
      const result = res.data!;
      if (result.failed === 0) toast.success(res.message ?? "Done");
      else toast.warning(res.message ?? "Some were left as they were");
      onOutcome({ ok: result.failed === 0, message: res.message ?? "Done", result });
      router.refresh();
    });
  }

  async function suspend() {
    const ok = await confirm({
      title: `Suspend ${people(canSuspend)}?`,
      description:
        "They can't sign in or be told about anything until they're reactivated; their tasks and items stay with them. Sign-offs waiting on them go to each department's main approver or another approver — anyone whose sign-offs have nobody to go to is left for you to suspend from their page.",
      confirmLabel: "Suspend",
      destructive: true,
    });
    if (ok) run("suspend");
  }

  async function cancel() {
    const ok = await confirm({
      title: `Cancel ${invites === 1 ? "1 invitation" : `${invites} invitations`}?`,
      description:
        "Their links stop working and any sign-off the invitations were going to give goes back to the department. You can invite them again later.",
      confirmLabel: "Cancel invitations",
      cancelLabel: "Keep them",
      destructive: true,
    });
    if (ok) run("cancel");
  }

  const button = "h-11 sm:h-8";
  return (
    <div
      role="region"
      aria-label="Selected people"
      className="bg-muted/60 flex flex-wrap items-center gap-2 rounded-lg border px-3 py-2 text-sm"
    >
      <span className="font-medium">{n} selected</span>
      <Button
        size="sm"
        variant="ghost"
        className={button}
        onClick={onClear}
        aria-label="Clear the selection"
      >
        <X aria-hidden />
      </Button>
      <span className="bg-border mx-1 hidden h-5 w-px sm:block" aria-hidden />
      <Button
        size="sm"
        variant="outline"
        className={button}
        disabled={pending || invites === 0}
        onClick={() => run("resend")}
      >
        Resend
      </Button>
      <Button
        size="sm"
        variant="outline"
        className={button}
        disabled={pending || canSuspend === 0}
        onClick={() => void suspend()}
      >
        Suspend
      </Button>
      <Button
        size="sm"
        variant="outline"
        className={button}
        disabled={pending || canReactivate === 0}
        onClick={() => run("reactivate")}
      >
        Reactivate
      </Button>
      <Button
        size="sm"
        variant="outline"
        className={button}
        disabled={pending}
        onClick={() => {
          setDate("");
          setDateOpen(true);
        }}
      >
        Set end date
      </Button>
      <Button
        size="sm"
        variant="ghost"
        className={`${button} text-destructive hover:text-destructive`}
        disabled={pending || invites === 0}
        onClick={() => void cancel()}
      >
        Cancel invitation
      </Button>
      {pending && <span className="text-muted-foreground">Working…</span>}
      {confirmDialog}

      <Dialog open={dateOpen} onOpenChange={setDateOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>When does their access end?</DialogTitle>
            <DialogDescription>
              For the {people(n)} selected. Access lasts to the end of that day (London time); after
              it they can&apos;t sign in.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="bulk-end-date">Access ends on</Label>
            <Input
              id="bulk-end-date"
              type="date"
              min={localToday()}
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="h-11 sm:h-9"
            />
          </div>
          <DialogFooter className="gap-2 sm:justify-between">
            <Button
              variant="ghost"
              disabled={pending}
              onClick={() => run("end_date", { date: null })}
            >
              Remove their end dates
            </Button>
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setDateOpen(false)}>
                Cancel
              </Button>
              <Button disabled={pending || !date} onClick={() => run("end_date", { date })}>
                Set end date
              </Button>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

/** What the last bulk change did: who was left alone and why, and any links to pass on. */
export function BulkOutcomePanel({
  outcome,
  onClose,
}: {
  outcome: BulkUsersOutcome;
  onClose: () => void;
}) {
  const rows = outcome.result?.rows ?? [];
  const failures = rows.filter((r) => !r.ok);
  const links = rows.filter((r) => r.ok && r.inviteUrl);
  const allLinks = links.map((r) => `${r.name}: ${absoluteLink(r.inviteUrl!)}`).join("\n");
  return (
    <div
      role="status"
      className={
        outcome.ok
          ? "space-y-2 rounded-lg border border-emerald-300 bg-emerald-50 px-3 py-2 text-sm text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-200"
          : "space-y-2 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200"
      }
    >
      <div className="flex items-start gap-2">
        {outcome.ok ? (
          <CheckCircle2 className="mt-0.5 size-4 shrink-0" aria-hidden />
        ) : (
          <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
        )}
        <p className="flex-1 font-medium">{outcome.message}</p>
        <Button
          size="sm"
          variant="ghost"
          className="h-11 sm:h-7"
          onClick={onClose}
          aria-label="Dismiss"
        >
          <X aria-hidden />
        </Button>
      </div>
      {failures.length > 0 && (
        <ul className="list-disc space-y-0.5 pl-9" aria-label="Left as they were">
          {failures.map((f) => (
            <li key={f.id}>
              <span className="font-medium">{f.name}</span> — {f.reason}
            </li>
          ))}
        </ul>
      )}
      {links.length > 0 && (
        <div className="space-y-1.5 pl-6">
          <p>Email isn&apos;t set up here — send each person their new link:</p>
          <ul className="space-y-0.5 font-mono text-xs break-all">
            {links.map((l) => (
              <li key={l.id}>
                {l.name}: {absoluteLink(l.inviteUrl!)}
              </li>
            ))}
          </ul>
          <Button
            size="sm"
            variant="outline"
            className="h-11 sm:h-8"
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(allLinks);
                toast.success("Links copied");
              } catch {
                toast.error("Couldn't copy — select the links and copy them yourself");
              }
            }}
          >
            <Copy aria-hidden />
            Copy all links
          </Button>
        </div>
      )}
    </div>
  );
}
