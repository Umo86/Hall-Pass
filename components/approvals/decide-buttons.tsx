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
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { decideApproval } from "@/app/actions/approvals";

type DecisionKind = "approve" | "approve_with_conditions" | "request_changes" | "reject" | "confirm";

type Props = {
  instanceId: string;
  stepKind: "approval" | "confirmation";
  stepName: string;
  expectedStatus: string;
  expectedLockedVersionId: string | null;
  requiresPhoto?: boolean;
  compact?: boolean;
};

const LABELS: Record<DecisionKind, string> = {
  approve: "Approve",
  approve_with_conditions: "Approve with conditions",
  request_changes: "Request changes",
  reject: "Reject",
  confirm: "Confirm",
};

const CONSEQUENCE: Record<DecisionKind, string> = {
  approve: "Your approval is recorded against the current version and its SHA-256.",
  approve_with_conditions:
    "Your approval is recorded with the conditions below; they follow the item to installation.",
  request_changes:
    "The item returns to its owner for changes. Steps after yours reset when it is resubmitted.",
  reject: "The item is rejected. Only admin or ops can reopen it.",
  confirm: "This confirmation is recorded against the current version.",
};

export function DecideButtons(props: Props) {
  const [open, setOpen] = useState<DecisionKind | null>(null);
  const [comment, setComment] = useState("");
  const [conditions, setConditions] = useState("");
  const [photoPath, setPhotoPath] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function submit(kind: DecisionKind) {
    setError(null);
    start(async () => {
      const res = await decideApproval({
        instanceId: props.instanceId,
        decision: kind,
        comment: comment || undefined,
        conditionsText: conditions || undefined,
        photoPath: photoPath || undefined,
        expectedStatus: props.expectedStatus,
        expectedLockedVersionId: props.expectedLockedVersionId,
      });
      if (!res.ok) setError(res.error);
      else {
        setOpen(null);
        setComment("");
        setConditions("");
        router.refresh();
      }
    });
  }

  const kinds: DecisionKind[] =
    props.stepKind === "approval"
      ? ["approve", "approve_with_conditions", "request_changes", "reject"]
      : ["confirm"];

  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {kinds.map((kind) => (
        <Button
          key={kind}
          size="sm"
          variant={kind === "approve" || kind === "confirm" ? "default" : kind === "reject" ? "destructive" : "outline"}
          onClick={() => setOpen(kind)}
        >
          {props.compact && kind === "approve_with_conditions" ? "With conditions" : LABELS[kind]}
        </Button>
      ))}
      {error && <span className="text-destructive text-xs">{error}</span>}

      <Dialog open={open !== null} onOpenChange={(o) => !o && setOpen(null)}>
        <DialogContent>
          {open && (
            <>
              <DialogHeader>
                <DialogTitle>
                  {LABELS[open]} — {props.stepName}
                </DialogTitle>
                <DialogDescription>{CONSEQUENCE[open]}</DialogDescription>
              </DialogHeader>
              {open === "approve_with_conditions" && (
                <div className="space-y-1.5">
                  <Label htmlFor="conditions">Conditions (required)</Label>
                  <Textarea
                    id="conditions"
                    value={conditions}
                    onChange={(e) => setConditions(e.target.value)}
                    placeholder="e.g. Amend the logo per brand guidelines before print"
                  />
                </div>
              )}
              <div className="space-y-1.5">
                <Label htmlFor="decide-comment">
                  Comment{open === "request_changes" || open === "reject" ? " (required)" : ""}
                </Label>
                <Textarea
                  id="decide-comment"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                />
              </div>
              {open === "confirm" && props.requiresPhoto && (
                <div className="space-y-1.5">
                  <Label htmlFor="photo-path">Photo reference (required)</Label>
                  <Input
                    id="photo-path"
                    value={photoPath}
                    onChange={(e) => setPhotoPath(e.target.value)}
                    placeholder="Photo file name or reference"
                  />
                </div>
              )}
              {error && <p className="text-destructive text-sm">{error}</p>}
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(null)}>
                  Cancel
                </Button>
                <Button
                  variant={open === "reject" ? "destructive" : "default"}
                  disabled={pending}
                  onClick={() => submit(open)}
                >
                  {LABELS[open]}
                </Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
