"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import {
  closeSignageItem,
  holdSignageItem,
  reopenSignageItem,
  resumeSignageItem,
  softDeleteSignageItem,
  submitForReview,
} from "@/app/actions/signage";
import { resubmitSignageItem } from "@/app/actions/approvals";

type Props = {
  itemId: string;
  status: string;
  /** Where to go after deleting: the item's own register. */
  listHref: string;
  canSubmit: boolean;
  canHold: boolean;
  canClose: boolean;
  canDelete: boolean;
};

/** Reopen from these undoes the install and goes back to Delivered. */
const INSTALLED = ["installed", "snagged", "closed"];

export function LifecycleButtons({
  itemId,
  status,
  canSubmit,
  canHold,
  canClose,
  canDelete,
  listHref,
}: Props) {
  const [dialog, setDialog] = useState<"hold" | "reopen" | "delete" | null>(null);
  const [reason, setReason] = useState("");
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  /** Each dialog starts with an empty reason — nothing carries over from the last one. */
  function openDialog(d: "hold" | "reopen" | "delete") {
    setReason("");
    setDialog(d);
  }

  function run(fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) {
    setMessage(null);
    start(async () => {
      const res = await fn();
      setMessage(
        res.ok
          ? res.message
            ? { text: res.message, error: false }
            : null
          : { text: res.error ?? "Something went wrong", error: true },
      );
      setDialog(null);
      if (res.ok) {
        setReason("");
        router.refresh();
      }
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      {canSubmit && status === "draft" && (
        <Button
          size="sm"
          disabled={pending}
          onClick={() => run(() => submitForReview({ id: itemId }))}
        >
          Submit for review
        </Button>
      )}
      {canSubmit && status === "changes_requested" && (
        <Button
          size="sm"
          disabled={pending}
          onClick={() => run(() => resubmitSignageItem({ id: itemId }))}
        >
          Resubmit
        </Button>
      )}
      {canHold && status === "rejected" && (
        <Button
          size="sm"
          variant="outline"
          disabled={pending}
          onClick={() => run(() => reopenSignageItem({ id: itemId }))}
        >
          Reopen
        </Button>
      )}
      {canClose && status === "installed" && (
        <Button
          size="sm"
          disabled={pending}
          onClick={() => run(() => closeSignageItem({ id: itemId }))}
        >
          Close
        </Button>
      )}
      {canHold && INSTALLED.includes(status) && (
        <Button size="sm" variant="outline" onClick={() => openDialog("reopen")}>
          Reopen
        </Button>
      )}
      {canHold && status === "on_hold" && (
        <Button
          size="sm"
          variant="outline"
          disabled={pending}
          onClick={() => run(() => resumeSignageItem({ id: itemId }))}
        >
          Resume
        </Button>
      )}
      {canHold && !["on_hold", "closed"].includes(status) && (
        <Button size="sm" variant="outline" onClick={() => openDialog("hold")}>
          Put on hold
        </Button>
      )}
      {canDelete && (
        <Button size="sm" variant="destructive" onClick={() => openDialog("delete")}>
          Delete
        </Button>
      )}
      {message && (
        <span className={`text-sm ${message.error ? "text-destructive" : "text-muted-foreground"}`}>
          {message.text}
        </span>
      )}

      <Dialog open={dialog === "hold"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Put this item on hold?</DialogTitle>
            <DialogDescription>
              Pending approvals pause and their due dates shift by the time on hold. The item
              returns to its current status on resume.
            </DialogDescription>
          </DialogHeader>
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Reason (required)"
          />
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

      <Dialog open={dialog === "reopen"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Undo the install?</DialogTitle>
            <DialogDescription>
              The item goes back to Delivered, its install photo is cleared and the Installed
              confirmation is back on the list. Snags stay as they are.
            </DialogDescription>
          </DialogHeader>
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why? (required) — e.g. wrong location, reprinted after damage"
          />
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || !reason.trim()}
              onClick={() => run(() => reopenSignageItem({ id: itemId, reason }))}
            >
              Reopen
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialog === "delete"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete this item?</DialogTitle>
            <DialogDescription>
              The item disappears from the schedule and every export. It can be restored from
              Settings → Deleted items; its ref is never reused.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={pending}
              onClick={() =>
                run(async () => {
                  const res = await softDeleteSignageItem({ id: itemId });
                  if (res.ok) router.push(listHref);
                  return res;
                })
              }
            >
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
