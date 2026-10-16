"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MoreHorizontal } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useConfirm } from "@/components/confirm-dialog";
import {
  closeSignageItem,
  holdSignageItem,
  reopenSignageItem,
  resubmitItem,
  resumeSignageItem,
  softDeleteSignageItem,
  submitForReview,
} from "@/app/actions/signage";

type Result = { ok: true; message?: string } | { ok: false; error: string };

/** Reopen from these undoes the install and goes back to Delivered. */
const INSTALLED = ["installed", "snagged", "closed"];

/**
 * The header's "More" menu: everything that is not the item's next step —
 * put on hold, undo the install, delete (last, in red). The next step's own
 * button lives in the next-step card.
 */
export function LifecycleButtons({
  itemId,
  itemRef,
  status,
  canHold,
  canReopen,
  canDelete,
  listHref,
}: {
  itemId: string;
  itemRef: string;
  status: string;
  canHold: boolean;
  canReopen: boolean;
  canDelete: boolean;
  /** Where to go after deleting: the item's own list. */
  listHref: string;
}) {
  const [dialog, setDialog] = useState<"hold" | "undo" | null>(null);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();

  const canPutOnHold = canHold && !["on_hold", "closed"].includes(status);
  const canUndoInstall = canReopen && INSTALLED.includes(status);
  if (!canPutOnHold && !canUndoInstall && !canDelete) return null;

  /** Each dialog starts with an empty reason — nothing carries over from the last one. */
  function open(d: "hold" | "undo") {
    setReason("");
    setError(null);
    setDialog(d);
  }

  function run(fn: () => Promise<Result>, after?: () => void) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) {
        setError(res.error);
        if (!dialog) toast.error(res.error);
        return;
      }
      setDialog(null);
      setReason("");
      toast.success(res.message ?? "Saved");
      if (after) after();
      else router.refresh();
    });
  }

  async function onDelete() {
    const ok = await confirm({
      title: `Delete ${itemRef}?`,
      description:
        "It disappears from the list and every export. You can restore it from Recently deleted on the Signage page; its ref is never reused.",
      confirmLabel: "Delete",
      destructive: true,
    });
    if (!ok) return;
    run(
      () => softDeleteSignageItem({ id: itemId }),
      () => router.push(listHref),
    );
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" size="sm" disabled={pending}>
            <MoreHorizontal aria-hidden /> More
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-48">
          {canPutOnHold && (
            <DropdownMenuItem onSelect={() => open("hold")}>Put on hold</DropdownMenuItem>
          )}
          {canUndoInstall && (
            <DropdownMenuItem onSelect={() => open("undo")}>Undo install</DropdownMenuItem>
          )}
          {canDelete && (canPutOnHold || canUndoInstall) && <DropdownMenuSeparator />}
          {canDelete && (
            <DropdownMenuItem
              className="text-destructive focus:text-destructive"
              onSelect={() => void onDelete()}
            >
              Delete
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      {confirmDialog}

      <Dialog open={dialog === "hold"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Put {itemRef} on hold?</DialogTitle>
            <DialogDescription>
              Its sign-offs pause and their due dates move on by the time it is held. Resume puts it
              back where it was.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="hold-reason">Reason (required)</Label>
            <Textarea
              id="hold-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Waiting for the sponsor's new logo"
            />
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || !reason.trim()}
              onClick={() => run(() => holdSignageItem({ id: itemId, reason }))}
            >
              Put on hold
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialog === "undo"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Undo the install of {itemRef}?</DialogTitle>
            <DialogDescription>
              It goes back to Delivered, its install photo is cleared and the Installed confirmation
              is waiting again. Snags stay as they are.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="undo-reason">Why? (required)</Label>
            <Textarea
              id="undo-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Why? e.g. wrong location, reprinted after damage"
            />
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || !reason.trim()}
              onClick={() => run(() => reopenSignageItem({ id: itemId, reason }))}
            >
              Undo install
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

export type NextStepButtonAction =
  | { type: "submit"; label: string }
  | { type: "resubmit"; label: string; confirm: boolean }
  | { type: "close"; label: string }
  | { type: "resume"; label: string }
  | { type: "reopen"; label: string };

/**
 * The next step's own button (send for sign-off, send back, mark complete,
 * resume, reopen), with a confirm where the step has consequences.
 */
export function NextStepButton({
  itemId,
  itemRef,
  action,
  variant = "default",
  disabledReason,
}: {
  itemId: string;
  itemRef: string;
  action: NextStepButtonAction;
  variant?: "default" | "outline";
  /** Shown instead of acting, e.g. "Add size and fixing method first". */
  disabledReason?: string | null;
}) {
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();

  function done(res: Result) {
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(res.message ?? "Saved");
    router.refresh();
  }

  async function onClick() {
    switch (action.type) {
      case "submit":
        start(async () => done(await submitForReview({ id: itemId })));
        return;
      case "resume":
        start(async () => done(await resumeSignageItem({ id: itemId })));
        return;
      case "reopen": {
        const ok = await confirm({
          title: `Reopen ${itemRef} as a draft?`,
          description:
            "It starts again as a draft so it can be changed and sent for sign-off again. The rejected sign-off stays in its History.",
          confirmLabel: "Reopen",
        });
        if (ok) start(async () => done(await reopenSignageItem({ id: itemId })));
        return;
      }
      case "close": {
        const ok = await confirm({
          title: `Mark ${itemRef} complete?`,
          description:
            "Everything is installed and snag-free. This sign is finished; you can reopen it if needed.",
          confirmLabel: "Mark complete",
        });
        if (ok) start(async () => done(await closeSignageItem({ id: itemId })));
        return;
      }
      case "resubmit": {
        if (action.confirm) {
          const ok = await confirm({
            title: "Send the same version back?",
            description:
              "No new artwork has been uploaded since the changes were asked for. Send the same version back for sign-off anyway?",
            confirmLabel: "Send it back",
          });
          if (!ok) return;
          start(async () => done(await resubmitItem({ id: itemId, confirmSameArtwork: true })));
          return;
        }
        start(async () => {
          const res = await resubmitItem({ id: itemId });
          // The server checks too: if the artwork changed back meanwhile, say so.
          if (res.ok && res.data?.confirmRequired) {
            toast.error(res.data.confirmRequired);
            router.refresh();
            return;
          }
          done(res);
        });
        return;
      }
    }
  }

  return (
    <>
      <Button
        size="sm"
        variant={variant}
        disabled={pending || Boolean(disabledReason)}
        title={disabledReason ?? undefined}
        onClick={() => void onClick()}
      >
        {pending ? "Working…" : action.label}
        {disabledReason && <span className="sr-only"> — {disabledReason}</span>}
      </Button>
      {confirmDialog}
    </>
  );
}
