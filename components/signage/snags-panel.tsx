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
import { StatusBadge } from "@/components/status-badge";
import { raiseSnag, updateSnag } from "@/app/actions/snags";
import { formatDateTime, statusLabel } from "@/lib/format";
import { ResolveSnagButton } from "./resolve-snag-dialog";

export type SnagView = {
  id: string;
  description: string;
  severity: string;
  status: string;
  photoUrl: string | null;
  resolutionNote: string | null;
  resolutionPhotoUrl: string | null;
  createdAt: string;
  resolvedAt: string | null;
};

type Result = { ok: boolean; error?: string; message?: string };

/**
 * "Raise snag" button and dialog: what's wrong, how bad, a photo. Used on
 * the item page and the Onsite checklist; there, on a delivered item, it is
 * "Report damage" (goods arriving damaged).
 */
export function RaiseSnagButton({
  itemId,
  itemRef,
  size = "sm",
  variant = "outline",
  label = "Raise snag",
  damage = false,
  className,
  onDone,
}: {
  itemId: string;
  itemRef: string;
  size?: "sm" | "default";
  variant?: "outline" | "default" | "secondary";
  label?: string;
  /** Delivered, not yet installed: the snag records damage on arrival. */
  damage?: boolean;
  className?: string;
  onDone?: (res: Result) => void;
}) {
  const [open, setOpen] = useState(false);
  const [description, setDescription] = useState("");
  const [severity, setSeverity] = useState("medium");
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function submit() {
    setError(null);
    start(async () => {
      const fd = new FormData();
      fd.set("itemId", itemId);
      fd.set("description", description);
      fd.set("severity", severity);
      if (file) fd.set("file", file);
      const res = await raiseSnag(fd);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setOpen(false);
      setDescription("");
      setSeverity("medium");
      setFile(null);
      onDone?.(res);
      router.refresh();
    });
  }

  return (
    <>
      <Button
        size={size}
        variant={variant}
        className={className}
        onClick={() => {
          // Nothing carries over from a cancelled attempt.
          setError(null);
          setFile(null);
          setOpen(true);
        }}
      >
        {label}
      </Button>
      <Dialog open={open} onOpenChange={(o) => !o && setOpen(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {damage ? `Report damage on ${itemRef}` : `Raise a snag on ${itemRef}`}
            </DialogTitle>
            <DialogDescription>
              {damage
                ? "It stays Delivered; if it is installed before this is fixed, it is marked Snagged. Operations and the owner are told."
                : "The item is marked Snagged until every snag is resolved. Operations and the owner are told."}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="snag-description">What&apos;s wrong?</Label>
              <Textarea
                id="snag-description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder={
                  damage
                    ? "e.g. Corner crushed in transit, wrong size delivered"
                    : "e.g. Left edge peeling, wrong panel fitted, hung crooked"
                }
                rows={3}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="snag-severity">How bad is it?</Label>
              <select
                id="snag-severity"
                className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                value={severity}
                onChange={(e) => setSeverity(e.target.value)}
              >
                <option value="low">Low — cosmetic</option>
                <option value="medium">Medium — needs fixing before opening</option>
                <option value="high">High — unsafe or unusable</option>
              </select>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="snag-photo">Photo (optional)</Label>
              <FileInput
                id="snag-photo"
                accept="image/*"
                buttonLabel="Take or choose a photo"
                onFileChange={(files) => setFile(files?.[0] ?? null)}
              />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button disabled={pending || !description.trim()} onClick={submit}>
              {damage ? "Report damage" : "Raise snag"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** The snags on an item, with Raise snag and per-snag progress buttons. */
export function SnagsPanel({
  itemId,
  itemRef,
  snags,
  canManage,
  canRaise,
}: {
  itemId: string;
  itemRef: string;
  snags: SnagView[];
  canManage: boolean;
  /** Installed or snagged items only; others show why not. */
  canRaise: boolean;
}) {
  const [pending, start] = useTransition();
  const router = useRouter();

  /** In progress or reopened: no note needed. Resolving goes through its dialog. */
  function move(snagId: string, status: "open" | "in_progress") {
    start(async () => {
      const fd = new FormData();
      fd.set("snagId", snagId);
      fd.set("status", status);
      const res = await updateSnag(fd);
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? `Snag on ${itemRef} updated`);
      router.refresh();
    });
  }

  const open = snags.filter((s) => s.status === "open" || s.status === "in_progress");
  const done = snags.filter((s) => s.status === "resolved" || s.status === "wont_fix");

  return (
    <section
      id="snags"
      aria-labelledby="snags-heading"
      className="flex max-w-4xl scroll-mt-20 flex-col gap-3 rounded-lg border p-4 text-sm"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 id="snags-heading" className="text-sm font-semibold">
            Snags
          </h2>
          {snags.length > 0 && (
            <p className="text-muted-foreground text-xs">
              {open.length} open · {done.length} done
            </p>
          )}
        </div>
        {canManage && canRaise && (
          <RaiseSnagButton
            itemId={itemId}
            itemRef={itemRef}
            onDone={(r) => {
              if (r.ok) toast.success(r.message ?? `Snag raised on ${itemRef}`);
            }}
          />
        )}
      </div>
      {snags.length === 0 && (
        <p className="text-muted-foreground text-sm">
          {canRaise
            ? "No snags. If something is wrong once it is up, raise a snag here."
            : "No snags. Snags can be raised once the item is installed."}
        </p>
      )}
      <ul className="space-y-2">
        {[...open, ...done].map((snag) => (
          <li key={snag.id} className="rounded-md border p-2 text-sm">
            <div className="flex flex-wrap items-center gap-2">
              <StatusBadge status={snag.status} />
              <span className="font-medium">{snag.description}</span>
              <span className="text-muted-foreground text-xs">{statusLabel(snag.severity)}</span>
              <span className="text-muted-foreground text-xs">
                {formatDateTime(snag.createdAt)}
              </span>
              {snag.photoUrl && (
                <a
                  className="text-primary text-xs hover:underline"
                  href={snag.photoUrl}
                  target="_blank"
                  rel="noreferrer"
                >
                  Photo
                </a>
              )}
            </div>
            {(snag.resolutionNote || snag.resolutionPhotoUrl) && (
              <p className="text-muted-foreground mt-1 text-xs">
                {snag.resolutionNote}
                {snag.resolutionPhotoUrl && (
                  <>
                    {snag.resolutionNote ? " · " : ""}
                    <a
                      className="text-primary hover:underline"
                      href={snag.resolutionPhotoUrl}
                      target="_blank"
                      rel="noreferrer"
                    >
                      Photo of the fix
                    </a>
                  </>
                )}
              </p>
            )}
            {canManage && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {snag.status === "open" && (
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={pending}
                    onClick={() => move(snag.id, "in_progress")}
                  >
                    In progress
                  </Button>
                )}
                {(snag.status === "open" || snag.status === "in_progress") && (
                  <>
                    <ResolveSnagButton
                      snagId={snag.id}
                      itemRef={itemRef}
                      description={snag.description}
                      disabled={pending}
                    />
                    <ResolveSnagButton
                      snagId={snag.id}
                      itemRef={itemRef}
                      description={snag.description}
                      outcome="wont_fix"
                      disabled={pending}
                    />
                  </>
                )}
                {(snag.status === "resolved" || snag.status === "wont_fix") && canRaise && (
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={pending}
                    onClick={() => move(snag.id, "open")}
                  >
                    Reopen snag
                  </Button>
                )}
              </div>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
