"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
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
import { FileInput } from "@/components/ui/file-input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { updateSnag } from "@/app/actions/snags";
import { cn } from "@/lib/utils";

export type SnagOutcome = "resolved" | "wont_fix";

/**
 * Close a snag: resolved (what was done, a photo of the fix if there is
 * one) or won't fix (why). One button and its dialog — used on the item
 * page's Snags card and on Onsite ("Fixed ✓").
 */
export function ResolveSnagButton({
  snagId,
  itemRef,
  description,
  outcome = "resolved",
  label,
  confirmLabel,
  size = "sm",
  variant,
  className,
  disabled,
}: {
  snagId: string;
  itemRef: string;
  /** The snag itself, shown in the dialog. */
  description: string;
  outcome?: SnagOutcome;
  /** Button text; defaults to "Resolved" / "Won't fix". */
  label?: string;
  /** The dialog's own button; defaults to "Resolved" / "Won't fix". */
  confirmLabel?: string;
  size?: "sm" | "default";
  variant?: "default" | "outline" | "secondary";
  className?: string;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const fixed = outcome === "resolved";

  function submit() {
    setError(null);
    start(async () => {
      const fd = new FormData();
      fd.set("snagId", snagId);
      fd.set("status", outcome);
      if (note.trim()) fd.set("note", note.trim());
      if (file) fd.set("file", file);
      const res = await updateSnag(fd);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setOpen(false);
      toast.success(res.message ?? `Snag on ${itemRef} ${fixed ? "resolved" : "closed"}`, {
        description: `${itemRef}: ${description}`,
      });
      router.refresh();
    });
  }

  return (
    <>
      <Button
        type="button"
        size={size}
        variant={variant ?? (fixed ? "default" : "outline")}
        className={className}
        disabled={disabled || pending}
        onClick={() => {
          // Every dialog starts clean: no note or photo from the last snag.
          setNote("");
          setFile(null);
          setError(null);
          setOpen(true);
        }}
      >
        {label ?? (fixed ? "Resolved" : "Won't fix")}
      </Button>
      <Dialog open={open} onOpenChange={(o) => !o && setOpen(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{fixed ? "Mark this snag resolved" : "Mark as won't fix"}</DialogTitle>
            <DialogDescription>
              {itemRef}: “{description}”.{" "}
              {fixed
                ? "Say what was done and add a photo of the fix if you have one. Once its last snag is fixed, an installed item is back to Installed."
                : "Say why it is being left as it is."}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor={`snag-note-${snagId}`}>
                {fixed ? "What was done (optional)" : "Why it stays (required)"}
              </Label>
              <Textarea
                id={`snag-note-${snagId}`}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder={fixed ? "What was done" : "Why it stays"}
                rows={3}
              />
            </div>
            {fixed && (
              <FileInput
                accept="image/*"
                buttonLabel="Add a photo of the fix"
                onFileChange={(files) => setFile(files?.[0] ?? null)}
              />
            )}
            {error && (
              <p role="alert" className="text-destructive text-sm">
                {error}
              </p>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={pending || (!fixed && !note.trim())}
              onClick={submit}
              className={cn(pending && "opacity-80")}
            >
              {pending ? "Saving…" : (confirmLabel ?? (fixed ? "Resolved" : "Won't fix"))}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
