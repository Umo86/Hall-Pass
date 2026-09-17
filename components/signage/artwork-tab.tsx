"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { FileImage, Upload } from "lucide-react";
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
import { StatusBadge } from "@/components/status-badge";
import { formatDateTime } from "@/lib/format";
import { uploadArtwork } from "@/app/actions/artwork";

export type VersionRow = {
  id: string;
  versionNumber: number;
  fileName: string;
  fileSize: number;
  sha256: string;
  proofStatus: string;
  notes: string | null;
  uploaderName: string | null;
  createdAt: string;
  downloadUrl: string | null;
  isCurrent: boolean;
};

export function ArtworkTab({
  itemId,
  versions,
  canUpload,
  invalidationCount,
  invalidationSteps,
  uploadBlocked,
}: {
  itemId: string;
  versions: VersionRow[];
  canUpload: boolean;
  invalidationCount: number;
  invalidationSteps: string[];
  uploadBlocked: string | null;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [notes, setNotes] = useState("");
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function doUpload() {
    if (!file) return;
    const fd = new FormData();
    fd.set("itemId", itemId);
    fd.set("file", file);
    fd.set("notes", notes);
    setError(null);
    start(async () => {
      const res = await uploadArtwork(fd);
      if (!res.ok) setError(res.error);
      else {
        setFile(null);
        setNotes("");
        setConfirmOpen(false);
        if (fileRef.current) fileRef.current.value = "";
        router.refresh();
      }
    });
  }

  return (
    <div className="space-y-4">
      {canUpload && (
        <div className="rounded-lg border p-4">
          <h3 className="mb-2 text-sm font-semibold">Upload a new version</h3>
          {uploadBlocked ? (
            <p className="text-muted-foreground text-sm">{uploadBlocked}</p>
          ) : (
            <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
              <input
                ref={fileRef}
                type="file"
                accept=".pdf,.ai,.eps,.svg,.png,.jpg,.jpeg,.tif,.tiff,.zip"
                className="text-sm"
                onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              />
              <Textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Notes for this version (optional)"
                className="min-h-9 flex-1"
              />
              <Button
                disabled={!file || pending}
                onClick={() => (invalidationCount > 0 ? setConfirmOpen(true) : doUpload())}
              >
                <Upload className="size-4" /> Upload
              </Button>
            </div>
          )}
          {error && <p className="text-destructive mt-2 text-sm">{error}</p>}
        </div>
      )}

      {versions.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-32 items-center justify-center rounded-lg border border-dashed text-sm">
          No artwork yet — the item stays in “awaiting artwork” until the first upload.
        </div>
      ) : (
        <ol className="space-y-2">
          {versions.map((v) => (
            <li key={v.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
              <FileImage className="text-muted-foreground size-8" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">
                  v{v.versionNumber} — {v.fileName}
                  {v.isCurrent && (
                    <span className="text-muted-foreground ml-2 text-xs">(current)</span>
                  )}
                </p>
                <p className="text-muted-foreground text-xs">
                  {(v.fileSize / 1024).toFixed(0)} KB · SHA-256 {v.sha256.slice(0, 12)}… · uploaded
                  by {v.uploaderName ?? "—"} {formatDateTime(v.createdAt)}
                </p>
                {v.notes && <p className="text-muted-foreground mt-1 text-xs">“{v.notes}”</p>}
              </div>
              <StatusBadge status={v.proofStatus} />
              {v.downloadUrl && (
                <Button size="sm" variant="outline" asChild>
                  <a href={v.downloadUrl}>Download</a>
                </Button>
              )}
            </li>
          ))}
        </ol>
      )}

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              This will invalidate {invalidationCount} approval{invalidationCount === 1 ? "" : "s"}
            </DialogTitle>
            <DialogDescription>
              Uploading a new version supersedes the decisions already made on:{" "}
              {invalidationSteps.join(", ")}. Those steps return to pending and their approvers are
              notified with a link to compare versions. This is never silent.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmOpen(false)}>
              Cancel
            </Button>
            <Button disabled={pending} onClick={doUpload}>
              Upload and invalidate
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
