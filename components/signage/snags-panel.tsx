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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { StatusBadge } from "@/components/status-badge";
import { raiseSnag, updateSnag } from "@/app/actions/snags";
import { formatDateTime, statusLabel } from "@/lib/format";

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
 * the item page and the Onsite checklist.
 */
export function RaiseSnagButton({
  itemId,
  itemRef,
  size = "sm",
  variant = "outline",
  onDone,
}: {
  itemId: string;
  itemRef: string;
  size?: "sm" | "default";
  variant?: "outline" | "default" | "secondary";
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
      <Button size={size} variant={variant} onClick={() => setOpen(true)}>
        Raise snag
      </Button>
      <Dialog open={open} onOpenChange={(o) => !o && setOpen(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Raise a snag on {itemRef}</DialogTitle>
            <DialogDescription>
              The item is marked Snagged until every snag is resolved. Operations and the owner are
              told.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="snag-description">What&apos;s wrong?</Label>
              <Textarea
                id="snag-description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="e.g. Left edge peeling, wrong panel fitted, hung crooked"
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
              <Input
                id="snag-photo"
                type="file"
                accept="image/*"
                capture="environment"
                onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button disabled={pending || !description.trim()} onClick={submit}>
              Raise snag
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
  const [closing, setClosing] = useState<{ id: string; status: "resolved" | "wont_fix" } | null>(
    null,
  );
  const [note, setNote] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function move(snagId: string, status: string, withNote = false) {
    setMessage(null);
    start(async () => {
      const fd = new FormData();
      fd.set("snagId", snagId);
      fd.set("status", status);
      if (withNote) {
        if (note.trim()) fd.set("note", note.trim());
        if (file) fd.set("file", file);
      }
      const res = await updateSnag(fd);
      setMessage(
        res.ok
          ? { text: res.message ?? "Updated", error: false }
          : { text: res.error, error: true },
      );
      if (res.ok) {
        setClosing(null);
        setNote("");
        setFile(null);
        router.refresh();
      }
    });
  }

  const open = snags.filter((s) => s.status === "open" || s.status === "in_progress");
  const done = snags.filter((s) => s.status === "resolved" || s.status === "wont_fix");

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <p className="text-muted-foreground">
          Snags{" "}
          {snags.length > 0 && (
            <span>
              · {open.length} open, {done.length} done
            </span>
          )}
        </p>
        {canManage && canRaise && (
          <RaiseSnagButton
            itemId={itemId}
            itemRef={itemRef}
            onDone={(r) => setMessage(r.ok ? { text: r.message ?? "Raised", error: false } : null)}
          />
        )}
        {message && (
          <span
            className={`text-sm ${message.error ? "text-destructive" : "text-muted-foreground"}`}
          >
            {message.text}
          </span>
        )}
      </div>
      {snags.length === 0 && (
        <p className="text-muted-foreground text-sm">
          {canRaise ? "No snags." : "No snags. Snags can be raised once the item is installed."}
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
                    <Button
                      size="sm"
                      disabled={pending}
                      onClick={() => setClosing({ id: snag.id, status: "resolved" })}
                    >
                      Resolved
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={pending}
                      onClick={() => setClosing({ id: snag.id, status: "wont_fix" })}
                    >
                      Won&apos;t fix
                    </Button>
                  </>
                )}
                {(snag.status === "resolved" || snag.status === "wont_fix") && (
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

      <Dialog open={closing !== null} onOpenChange={(o) => !o && setClosing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {closing?.status === "resolved" ? "Mark this snag resolved" : "Mark as won't fix"}
            </DialogTitle>
            <DialogDescription>
              {closing?.status === "resolved"
                ? "Say what was done and add a photo of the fix if you have one."
                : "Say why it is being left as it is."}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <Textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={closing?.status === "resolved" ? "What was done" : "Why it stays"}
              rows={3}
            />
            <Input
              type="file"
              accept="image/*"
              capture="environment"
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setClosing(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || (closing?.status === "wont_fix" && !note.trim())}
              onClick={() => closing && move(closing.id, closing.status, true)}
            >
              {closing?.status === "resolved" ? "Resolved" : "Won't fix"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
