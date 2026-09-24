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
import { decideApproval, uploadInstallPhoto } from "@/app/actions/approvals";

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
  approve: "Your approval is recorded against the current artwork version.",
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
      fd.set("instanceId", props.instanceId);
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
        setPhotoPath("");
        setPhotoPreview(null);
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
              {error && <p className="text-destructive text-sm">{error}</p>}
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(null)}>
                  Cancel
                </Button>
                <Button
                  variant={open === "reject" ? "destructive" : "default"}
                  disabled={
                    pending ||
                    uploading ||
                    (open === "confirm" && Boolean(props.requiresPhoto) && !photoPath)
                  }
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
