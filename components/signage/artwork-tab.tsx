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
import { recordUploadedArtwork, uploadArtwork } from "@/app/actions/artwork";

/** Streaming SHA-256 so multi-gigabyte files hash without loading into memory. */
async function sha256OfFile(file: File): Promise<string> {
  const { createSHA256 } = await import("hash-wasm");
  const hasher = await createSHA256();
  const chunk = 8 * 1024 * 1024;
  for (let offset = 0; offset < file.size; offset += chunk) {
    hasher.update(new Uint8Array(await file.slice(offset, offset + chunk).arrayBuffer()));
  }
  return hasher.digest("hex");
}

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
  previewUrl: string | null;
  mimeType: string;
  isCurrent: boolean;
  /** Demo records carry no real file. */
  sample?: boolean;
};

function VersionPreview({ version, className }: { version: VersionRow; className?: string }) {
  if (!version.previewUrl) {
    return (
      <div
        className={`text-muted-foreground flex items-center justify-center rounded-lg border border-dashed p-6 text-xs ${className ?? ""}`}
      >
        {version.sample
          ? "Sample record — no file attached."
          : "No preview for this file type — download to view."}
      </div>
    );
  }
  return (
    <div className={`space-y-1 ${className ?? ""}`}>
      {version.mimeType === "application/pdf" ? (
        <iframe
          src={version.previewUrl}
          title={`Preview of v${version.versionNumber} — ${version.fileName}`}
          className="h-[480px] w-full rounded-lg border"
        />
      ) : (
        // eslint-disable-next-line @next/next/no-img-element -- artwork previews have unknown dimensions
        <img
          src={version.previewUrl}
          alt={`Preview of v${version.versionNumber} — ${version.fileName}`}
          className="bg-muted/30 max-h-[480px] w-full rounded-lg border object-contain"
        />
      )}
      {/* Phone browsers often won't show a PDF inside a frame. */}
      <a
        href={version.previewUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="text-muted-foreground text-xs underline"
      >
        Open full size
      </a>
    </div>
  );
}

export function ArtworkTab({
  itemId,
  versions,
  canUpload,
  invalidationCount,
  invalidationSteps,
  uploadBlocked,
  uploadPrefix = null,
}: {
  itemId: string;
  versions: VersionRow[];
  canUpload: boolean;
  invalidationCount: number;
  invalidationSteps: string[];
  uploadBlocked: string | null;
  /** Set when Vercel Blob is configured: enables direct browser uploads. */
  uploadPrefix?: string | null;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [notes, setNotes] = useState("");
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const current = versions.find((v) => v.isCurrent) ?? versions[0] ?? null;
  const [compare, setCompare] = useState(false);
  const [leftId, setLeftId] = useState<string | null>(null);
  const [rightId, setRightId] = useState<string | null>(null);
  const left = versions.find((v) => v.id === leftId) ?? versions[1] ?? current;
  const right = versions.find((v) => v.id === rightId) ?? current;

  function done() {
    setFile(null);
    setNotes("");
    setConfirmOpen(false);
    setProgress(null);
    if (fileRef.current) fileRef.current.value = "";
    router.refresh();
  }

  function doUpload() {
    if (!file) return;
    setError(null);
    start(async () => {
      if (uploadPrefix) {
        // Browser → Vercel Blob directly, so gigabyte files skip the server.
        try {
          setProgress("Preparing…");
          const sha256 = await sha256OfFile(file);
          const clean = file.name.replace(/[^\w.-]+/g, "_").slice(0, 120);
          const pathname = `${uploadPrefix}${crypto.randomUUID()}-${clean}`;
          const { upload } = await import("@vercel/blob/client");
          await upload(pathname, file, {
            access: "public",
            handleUploadUrl: "/api/blob/upload",
            clientPayload: JSON.stringify({ itemId }),
            multipart: file.size > 50 * 1024 * 1024,
            onUploadProgress: ({ percentage }) => setProgress(`Uploading ${percentage}%`),
          });
          setProgress("Recording version…");
          const res = await recordUploadedArtwork({
            itemId,
            fileName: file.name,
            pathname,
            mimeType: file.type || "application/octet-stream",
            fileSize: file.size,
            sha256,
            notes,
          });
          if (!res.ok) {
            setError(res.error);
            setProgress(null);
          } else done();
        } catch (err) {
          setError(err instanceof Error ? err.message : "Upload failed");
          setProgress(null);
        }
        return;
      }
      const fd = new FormData();
      fd.set("itemId", itemId);
      fd.set("file", file);
      fd.set("notes", notes);
      const res = await uploadArtwork(fd);
      if (!res.ok) setError(res.error);
      else done();
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
          {progress && <p className="text-muted-foreground mt-2 text-sm">{progress}</p>}
          {error && <p className="text-destructive mt-2 text-sm">{error}</p>}
        </div>
      )}

      {current && (
        <div className="rounded-lg border p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-sm font-semibold">
              {compare ? "Compare versions" : `Preview — v${current.versionNumber}`}
            </h3>
            {versions.length > 1 && (
              <Button size="sm" variant="outline" onClick={() => setCompare((c) => !c)}>
                {compare ? "Single view" : "Compare versions"}
              </Button>
            )}
          </div>
          {compare && left && right ? (
            <div className="grid gap-4 sm:grid-cols-2">
              {[
                { chosen: left, set: setLeftId, label: "Left" },
                { chosen: right, set: setRightId, label: "Right" },
              ].map(({ chosen, set, label }) => (
                <div key={label} className="space-y-2">
                  <select
                    aria-label={`${label} version`}
                    className="w-full rounded-md border px-2 py-1.5 text-sm"
                    value={chosen.id}
                    onChange={(e) => set(e.target.value)}
                  >
                    {versions.map((v) => (
                      <option key={v.id} value={v.id}>
                        v{v.versionNumber} — {v.fileName}
                        {v.isCurrent ? " (current)" : ""}
                      </option>
                    ))}
                  </select>
                  <VersionPreview version={chosen} />
                  <p className="text-muted-foreground text-xs">
                    Uploaded {formatDateTime(chosen.createdAt)}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <VersionPreview version={current} />
          )}
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
                  {(v.fileSize / 1024).toFixed(0)} KB · uploaded
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
