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
  canDelete: boolean;
};

export function LifecycleButtons({
  itemId,
  status,
  canSubmit,
  canHold,
  canDelete,
  listHref,
}: Props) {
  const [dialog, setDialog] = useState<"hold" | "delete" | null>(null);
  const [reason, setReason] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function run(fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) {
    setMessage(null);
    start(async () => {
      const res = await fn();
      setMessage(res.ok ? (res.message ?? null) : (res.error ?? null));
      setDialog(null);
      if (res.ok) router.refresh();
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      {canSubmit && status === "draft" && (
        <Button size="sm" disabled={pending} onClick={() => run(() => submitForReview({ id: itemId }))}>
          Submit for review
        </Button>
      )}
      {canSubmit && status === "changes_requested" && (
        <Button size="sm" disabled={pending} onClick={() => run(() => resubmitSignageItem({ id: itemId }))}>
          Resubmit
        </Button>
      )}
      {canHold && status === "rejected" && (
        <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => reopenSignageItem({ id: itemId }))}>
          Reopen
        </Button>
      )}
      {canHold && status === "on_hold" && (
        <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => resumeSignageItem({ id: itemId }))}>
          Resume
        </Button>
      )}
      {canHold && !["on_hold", "closed"].includes(status) && (
        <Button size="sm" variant="outline" onClick={() => setDialog("hold")}>
          Put on hold
        </Button>
      )}
      {canDelete && (
        <Button size="sm" variant="destructive" onClick={() => setDialog("delete")}>
          Delete
        </Button>
      )}
      {message && <span className="text-muted-foreground text-sm">{message}</span>}

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
