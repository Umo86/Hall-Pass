"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, MoreHorizontal } from "lucide-react";
import { toast } from "sonner";
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
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { decideApproval, uploadInstallPhoto } from "@/app/actions/approvals";
import { cn } from "@/lib/utils";
import { decisionToast, type DecisionKind } from "./step-words";

export type { DecisionKind };

/** Shrink a phone photo (longest side ≤ 2000px, JPEG) before upload. */
async function downscale(file: File): Promise<Blob> {
  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, 2000 / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    canvas.getContext("2d")?.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, "image/jpeg", 0.85),
    );
    return blob ?? file;
  } catch {
    return file; // Could not decode here — send the original.
  }
}

/** Today as YYYY-MM-DD in the browser's own time zone. */
export function localToday(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export type DecisionTarget = {
  instanceId: string;
  stepKind: "approval" | "confirmation";
  stepName: string;
  expectedStatus: string;
  expectedLockedVersionId: string | null;
  requiresPhoto?: boolean;
  /** The record's ref (labels) and page (the toast's "Open item"). */
  itemRef?: string;
  itemHref?: string;
  /** The record's name, shown in the toast after deciding. */
  itemName?: string;
  /** Called once a decision is recorded (e.g. to move on to the next item). */
  onDecided?: (kind: DecisionKind) => void;
  /**
   * Deciding a step that is someone else's (admins, from Everyone's): who it
   * is with, shown as a warning; they are told about the decision.
   */
  onBehalfOf?: { who: string; people: string[] };
};

type Props = DecisionTarget & {
  compact?: boolean;
  /** Text for the confirm button (default "Confirm"), e.g. "Installed ✓" onsite. */
  confirmLabel?: string;
  className?: string;
};

export const DECISION_LABELS: Record<DecisionKind, string> = {
  approve: "Approve",
  approve_with_conditions: "Approve with conditions",
  request_changes: "Request changes",
  reject: "Reject",
  confirm: "Confirm",
};

export const DECISION_CONSEQUENCE: Record<DecisionKind, string> = {
  approve: "Your approval is recorded against the current artwork version.",
  approve_with_conditions:
    "Your approval is recorded with the conditions below; they follow the item to installation.",
  request_changes:
    "The item returns to its owner for changes. Steps after yours reset when it is resubmitted.",
  reject: "The item is rejected. Only someone with “Hold, reopen and mark complete” can reopen it.",
  confirm: "Recorded against the current version, with the date it actually happened.",
};

const APPROVAL_KINDS: DecisionKind[] = [
  "approve",
  "approve_with_conditions",
  "request_changes",
  "reject",
];

/** Missing words a decision needs, or null. Shared with the review sheet. */
export function decisionInputError(
  kind: DecisionKind,
  input: { comment: string; conditions: string },
): string | null {
  if (kind === "approve_with_conditions" && !input.conditions.trim()) {
    return "Write the conditions the approval comes with";
  }
  if (kind === "request_changes" && !input.comment.trim()) {
    return "Say what needs to change in a comment";
  }
  if (kind === "reject" && !input.comment.trim()) return "Say why it is rejected";
  return null;
}

/** The success toast, with "Open item" when the record's page is known. */
export function toastDecision(
  kind: DecisionKind,
  target: Pick<DecisionTarget, "stepName" | "itemName" | "itemHref">,
  push: (href: string) => void,
) {
  toast.success(decisionToast(kind, target.stepName), {
    description: target.itemName,
    action: target.itemHref
      ? { label: "Open item", onClick: () => push(target.itemHref!) }
      : undefined,
  });
}

/**
 * The decision dialog on its own: open it with a decision (or let the person
 * choose one, for "Decide on their behalf…"). Comment, conditions, the date a
 * confirmation happened and the install photo are asked for here.
 */
export function useDecisionDialog(target: DecisionTarget): {
  openDecision: (kind: DecisionKind, opts?: { choose?: boolean }) => void;
  dialog: React.ReactNode;
} {
  const [open, setOpen] = useState<DecisionKind | null>(null);
  const [choose, setChoose] = useState(false);
  const [comment, setComment] = useState("");
  const [conditions, setConditions] = useState("");
  const [photoPath, setPhotoPath] = useState("");
  const [confirmedDate, setConfirmedDate] = useState(() => localToday());
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  async function takePhoto(file: File | undefined) {
    if (!file) return;
    setError(null);
    setUploading(true);
    setPhotoPath("");
    try {
      const blob = await downscale(file);
      const fd = new FormData();
      fd.set("instanceId", target.instanceId);
      fd.set(
        "file",
        new File([blob], blob === file ? file.name : "photo.jpg", {
          type: blob.type || file.type,
        }),
      );
      const res = await uploadInstallPhoto(fd);
      if (!res.ok) {
        setError(res.error);
        setPhotoPreview(null);
      } else {
        setPhotoPath(res.data!.photoPath);
        setPhotoPreview(URL.createObjectURL(blob));
      }
    } catch {
      setError("Could not upload the photo — check your signal and try again");
    } finally {
      setUploading(false);
    }
  }

  function close() {
    setOpen(null);
    setChoose(false);
    setError(null);
  }

  function submit(kind: DecisionKind) {
    const missing = decisionInputError(kind, { comment, conditions });
    setError(missing);
    if (missing) return;
    start(async () => {
      const res = await decideApproval({
        instanceId: target.instanceId,
        decision: kind,
        comment: comment || undefined,
        conditionsText: conditions || undefined,
        photoPath: photoPath || undefined,
        confirmedDate: kind === "confirm" && confirmedDate ? confirmedDate : undefined,
        expectedStatus: target.expectedStatus,
        expectedLockedVersionId: target.expectedLockedVersionId,
      });
      if (!res.ok) setError(res.error);
      else {
        setOpen(null);
        setChoose(false);
        setComment("");
        setConditions("");
        setPhotoPath("");
        setPhotoPreview(null);
        toastDecision(kind, target, router.push);
        // decideApproval revalidates, which refreshes the page; no second render.
        target.onDecided?.(kind);
      }
    });
  }

  function openDecision(kind: DecisionKind, opts?: { choose?: boolean }) {
    // A fresh dialog: no error from the last attempt, today's date for confirmations.
    setError(null);
    if (kind === "confirm") setConfirmedDate(localToday());
    setChoose(Boolean(opts?.choose));
    setOpen(kind);
  }

  const dialog = (
    <Dialog open={open !== null} onOpenChange={(o) => !o && close()}>
      <DialogContent>
        {open && (
          <>
            <DialogHeader>
              <DialogTitle>
                {choose ? "Decide on their behalf" : DECISION_LABELS[open]} — {target.stepName}
              </DialogTitle>
              <DialogDescription>
                {target.itemRef ? `${target.itemRef}. ` : ""}
                {DECISION_CONSEQUENCE[open]}
              </DialogDescription>
            </DialogHeader>
            {target.onBehalfOf && (
              <p
                role="note"
                className="flex gap-2 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
              >
                <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
                <span>
                  You are deciding for {target.onBehalfOf.who}.{" "}
                  {target.onBehalfOf.people.length > 0
                    ? `${listNames(target.onBehalfOf.people)} will be told.`
                    : "It is recorded under your name."}
                </span>
              </p>
            )}
            {choose && target.stepKind === "approval" && (
              <div className="space-y-1.5">
                <Label htmlFor="decide-kind">Decision</Label>
                <SelectNative
                  id="decide-kind"
                  value={open}
                  onChange={(e) => {
                    setError(null);
                    setOpen(e.target.value as DecisionKind);
                  }}
                >
                  {APPROVAL_KINDS.map((k) => (
                    <option key={k} value={k}>
                      {DECISION_LABELS[k]}
                    </option>
                  ))}
                </SelectNative>
              </div>
            )}
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
                placeholder={
                  open === "request_changes" ? "e.g. The logo needs more clear space" : undefined
                }
              />
            </div>
            {open === "confirm" && (
              <div className="space-y-1.5">
                <Label htmlFor="confirmed-date">When did this happen?</Label>
                <input
                  id="confirmed-date"
                  type="date"
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                  value={confirmedDate}
                  max={localToday()}
                  onChange={(e) => setConfirmedDate(e.target.value)}
                />
              </div>
            )}
            {open === "confirm" && target.requiresPhoto && (
              <div className="space-y-1.5">
                <Label htmlFor="install-photo">Photo of the installed item (required)</Label>
                <input
                  id="install-photo"
                  type="file"
                  accept="image/*"
                  capture="environment"
                  className="block w-full text-sm file:mr-3 file:rounded-md file:border file:bg-transparent file:px-3 file:py-1.5 file:text-sm"
                  onChange={(e) => void takePhoto(e.target.files?.[0])}
                />
                {uploading && <p className="text-muted-foreground text-xs">Uploading photo…</p>}
                {photoPreview && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={photoPreview}
                    alt="Install photo preview"
                    className="max-h-40 rounded-md border object-contain"
                  />
                )}
              </div>
            )}
            {error && (
              <p role="alert" className="text-destructive text-sm">
                {error}
              </p>
            )}
            <DialogFooter>
              <Button variant="outline" onClick={close}>
                Cancel
              </Button>
              <Button
                variant={open === "reject" ? "destructive" : "default"}
                disabled={
                  pending ||
                  uploading ||
                  (open === "confirm" && Boolean(target.requiresPhoto) && !photoPath)
                }
                onClick={() => submit(open)}
              >
                {pending ? "Saving…" : DECISION_LABELS[open]}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );

  return { openDecision, dialog };
}

function listNames(names: string[]): string {
  if (names.length <= 2) return names.join(" and ");
  return `${names.slice(0, 2).join(", ")} and ${names.length - 2} more`;
}

/**
 * The decision buttons for one step. Compact (lists): Approve and Request
 * changes, with the other decisions under "More decisions"; full width on a
 * phone. Confirmations get one button. Full: every decision as a button.
 */
export function DecideButtons(props: Props) {
  const { openDecision, dialog } = useDecisionDialog(props);

  if (props.stepKind === "confirmation") {
    return (
      <div className={cn("flex flex-wrap items-center gap-1.5", props.className)}>
        <Button size="sm" onClick={() => openDecision("confirm")}>
          {props.confirmLabel ?? DECISION_LABELS.confirm}
        </Button>
        {dialog}
      </div>
    );
  }

  if (props.compact) {
    return (
      <div
        className={cn(
          "grid w-full grid-cols-[1fr_1fr_auto] items-center gap-1.5 sm:flex sm:w-auto sm:flex-wrap",
          props.className,
        )}
      >
        <Button size="sm" onClick={() => openDecision("approve")}>
          Approve
        </Button>
        <Button size="sm" variant="outline" onClick={() => openDecision("request_changes")}>
          Request changes
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              size="icon"
              variant="ghost"
              className="size-8"
              aria-label={`More decisions${props.itemRef ? ` on ${props.itemRef}` : ""}`}
            >
              <MoreHorizontal aria-hidden />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => openDecision("approve_with_conditions")}>
              Approve with conditions…
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" onSelect={() => openDecision("reject")}>
              Reject…
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        {dialog}
      </div>
    );
  }

  return (
    <div className={cn("flex flex-wrap items-center gap-1.5", props.className)}>
      {APPROVAL_KINDS.map((kind) => (
        <Button
          key={kind}
          size="sm"
          variant={kind === "approve" ? "default" : kind === "reject" ? "destructive" : "outline"}
          onClick={() => openDecision(kind)}
        >
          {DECISION_LABELS[kind]}
        </Button>
      ))}
      {dialog}
    </div>
  );
}

/**
 * "Decide on their behalf…" for admins looking at someone else's step: a
 * menu item that opens the decision dialog with a warning naming whose step
 * it is.
 */
export function DecideOnBehalf(
  props: DecisionTarget & { onBehalfOf: { who: string; people: string[] } },
) {
  const { openDecision, dialog } = useDecisionDialog(props);
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            size="icon"
            variant="ghost"
            className="size-8"
            aria-label={`More for ${props.itemRef ?? props.stepName}`}
          >
            <MoreHorizontal aria-hidden />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onSelect={() =>
              openDecision(props.stepKind === "confirmation" ? "confirm" : "approve", {
                choose: true,
              })
            }
          >
            Decide on their behalf…
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      {dialog}
    </>
  );
}
