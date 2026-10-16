"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
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
import { FileInput } from "@/components/ui/file-input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { formatDateTime } from "@/lib/format";
import { recordUploadedArtwork, uploadArtwork } from "@/app/actions/artwork";
import { ARTWORK_EXTENSIONS, isVideoArtwork } from "@/lib/artwork-rules";

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

/**
 * Ask the server for a presigned PUT, then send the file straight to the
 * bucket with progress. Resolves to the stored pathname ("artwork/…").
 */
async function putToBucket(
  file: File,
  itemId: string,
  onProgress: (percentage: number) => void,
): Promise<string> {
  const res = await fetch("/api/uploads/sign", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      itemId,
      fileName: file.name,
      contentType: file.type || undefined,
      fileSize: file.size,
    }),
  });
  const signed = (await res.json().catch(() => ({}))) as {
    url?: string;
    contentType?: string;
    pathname?: string;
    error?: string;
  };
  if (!res.ok || !signed.url || !signed.pathname || !signed.contentType) {
    throw new Error(signed.error ?? "Upload refused");
  }
  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", signed.url!);
    // Must match the signed request exactly.
    xhr.setRequestHeader("Content-Type", signed.contentType!);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    };
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? resolve()
        : reject(new Error(`Upload failed (${xhr.status}) — check the bucket's CORS settings`));
    xhr.onerror = () => reject(new Error("Upload failed — check your connection and try again"));
    xhr.send(file);
  });
  return signed.pathname;
}

/** "840 KB", "12.4 MB", "1.2 GB". */
function fileSizeLabel(bytes: number): string {
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
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
      ) : isVideoArtwork(version.mimeType, version.fileName) ? (
        // Digital signage: play the video itself; no still is generated.
        <video
          src={version.previewUrl}
          controls
          preload="metadata"
          playsInline
          aria-label={`Preview of v${version.versionNumber} — ${version.fileName}`}
          className="bg-muted/30 max-h-[480px] w-full rounded-lg border"
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
        className="link text-muted-foreground inline-block py-1 text-xs"
      >
        Open full size
      </a>
    </div>
  );
}

/** Statuses where an upload is the next thing to do, so the box starts open. */
const UPLOAD_FIRST = ["draft", "awaiting_artwork", "changes_requested"];

/**
 * The artwork: the current version's preview first, then (from the page)
 * the viewer's own decision, the versions, and the upload box — open when
 * an upload is what comes next, otherwise one "Upload new version" picker.
 */
export function ArtworkTab({
  itemId,
  versions,
  canUpload,
  invalidationCount,
  invalidationSteps,
  panelWarning,
  uploadBlocked,
  uploadPrefix = null,
  directUpload = null,
  status,
  initialCompare = null,
  changeRequest = null,
  canSendForSignoff = false,
  sendBlockedReason = null,
  autoFocusUpload = false,
  noun = "artwork",
  decision,
}: {
  itemId: string;
  versions: VersionRow[];
  canUpload: boolean;
  invalidationCount: number;
  invalidationSteps: string[];
  /** Stand designs: panels that may no longer fit once the design changes. */
  panelWarning?: string | null;
  uploadBlocked: string | null;
  /** Vercel Blob only: the folder the browser may write to. */
  uploadPrefix?: string | null;
  /** Browser → storage directly (S3/R2 presigned PUT, or Vercel Blob); null = via the server. */
  directUpload?: "s3" | "blob" | null;
  /** The item's status: decides whether the upload box starts open. */
  status?: string;
  /** `?compare=3` from a notification: compare v3 with the version before it. */
  initialCompare?: number | null;
  /** Changes requested: who asked and what they said, shown in the upload box. */
  changeRequest?: { stepName: string; deciderName: string | null; comment: string | null } | null;
  /** May send it for (or back for) sign-off straight after the upload. */
  canSendForSignoff?: boolean;
  /** Why it can't be sent yet (e.g. "Add size and fixing method first"). */
  sendBlockedReason?: string | null;
  /** Just created: put the focus on the file picker. */
  autoFocusUpload?: boolean;
  noun?: "artwork" | "design" | "graphic";
  /** The viewer's own pending decision, shown right under the preview. */
  decision?: React.ReactNode;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const compareRef = useRef<HTMLDivElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [pickerKey, setPickerKey] = useState(0);
  const [notes, setNotes] = useState("");
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [pending, start] = useTransition();
  const router = useRouter();
  const startsOpen = !status || UPLOAD_FIRST.includes(status) || versions.length === 0;
  const [expanded, setExpanded] = useState(startsOpen);
  const [sendAfter, setSendAfter] = useState(true);
  const sendable = canSendForSignoff && (status === "draft" || status === "changes_requested");

  const current = versions.find((v) => v.isCurrent) ?? versions[0] ?? null;
  const fromLink = initialCompare
    ? versions.find((v) => v.versionNumber === initialCompare)
    : undefined;
  const before = fromLink
    ? versions
        .filter((v) => v.versionNumber < fromLink.versionNumber)
        .sort((a, b) => b.versionNumber - a.versionNumber)[0]
    : undefined;
  const [compare, setCompare] = useState(Boolean(fromLink && before));
  const [leftId, setLeftId] = useState<string | null>(before?.id ?? null);
  const [rightId, setRightId] = useState<string | null>(fromLink?.id ?? null);
  const left = versions.find((v) => v.id === leftId) ?? versions[1] ?? current;
  const right = versions.find((v) => v.id === rightId) ?? current;

  useEffect(() => {
    if (compare && fromLink) compareRef.current?.scrollIntoView({ block: "start" });
    // Only when arriving from a "compare the versions" link.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (autoFocusUpload) fileRef.current?.focus();
  }, [autoFocusUpload]);

  function choose(files: FileList | null) {
    const next = files?.[0] ?? null;
    setFile(next);
    setError(null);
    setSuccess(null);
    if (next) setExpanded(true);
  }

  /** A dropped file goes into the real input, so it behaves like a chosen one. */
  function onDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragging(false);
    const dropped = e.dataTransfer.files?.[0];
    const input = fileRef.current;
    if (!dropped || !input) return;
    const dt = new DataTransfer();
    dt.items.add(dropped);
    input.files = dt.files;
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  function done(message: string | undefined, nextStatus: string | undefined) {
    setFile(null);
    setNotes("");
    setConfirmOpen(false);
    setProgress(null);
    setPickerKey((k) => k + 1);
    setSuccess(message ?? "Uploaded");
    toast.success(message ?? "Uploaded");
    if (nextStatus && !UPLOAD_FIRST.includes(nextStatus)) setExpanded(false);
    router.refresh();
  }

  function doUpload() {
    if (!file) return;
    setError(null);
    setSuccess(null);
    const send = sendable && sendAfter && !sendBlockedReason;
    start(async () => {
      if (directUpload === "s3" || (directUpload === "blob" && uploadPrefix)) {
        // Browser → storage directly, so gigabyte files skip the server.
        try {
          setProgress("Preparing…");
          const sha256 = await sha256OfFile(file);
          let pathname: string;
          if (directUpload === "s3") {
            pathname = await putToBucket(file, itemId, (pct) => setProgress(`Uploading ${pct}%`));
          } else {
            const clean = file.name.replace(/[^\w.-]+/g, "_").slice(0, 120);
            pathname = `${uploadPrefix}${crypto.randomUUID()}-${clean}`;
            const { upload } = await import("@vercel/blob/client");
            await upload(pathname, file, {
              access: "public",
              handleUploadUrl: "/api/blob/upload",
              clientPayload: JSON.stringify({ itemId }),
              multipart: file.size > 50 * 1024 * 1024,
              onUploadProgress: ({ percentage }) => setProgress(`Uploading ${percentage}%`),
            });
          }
          setProgress("Recording version…");
          const res = await recordUploadedArtwork({
            itemId,
            fileName: file.name,
            pathname,
            mimeType: file.type || "application/octet-stream",
            fileSize: file.size,
            sha256,
            notes,
            sendForSignoff: send,
          });
          if (!res.ok) {
            setError(res.error);
            setProgress(null);
          } else done(res.message, res.data?.status);
        } catch (err) {
          setError(err instanceof Error ? err.message : "Upload failed");
          setProgress(null);
        }
        return;
      }
      setProgress("Uploading…");
      const fd = new FormData();
      fd.set("itemId", itemId);
      fd.set("file", file);
      fd.set("notes", notes);
      if (send) fd.set("sendForSignoff", "on");
      const res = await uploadArtwork(fd);
      if (!res.ok) {
        setError(res.error);
        setProgress(null);
      } else done(res.message, res.data?.status);
    });
  }

  const heading =
    status === "changes_requested"
      ? "Upload the corrected version"
      : versions.length === 0
        ? `Upload the ${noun}`
        : "Upload a new version";

  return (
    <div className="space-y-4">
      {current ? (
        <div ref={compareRef} className="rounded-lg border p-4">
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
                    className="border-input w-full rounded-md border bg-transparent px-2 py-1.5 text-sm"
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
      ) : (
        <div className="text-muted-foreground flex h-32 flex-col items-center justify-center gap-1 rounded-lg border border-dashed px-4 text-center text-sm">
          <FileImage className="size-6" aria-hidden />
          No {noun} yet — sign-off can start once it is uploaded.
        </div>
      )}

      {decision}

      {versions.length > 0 && (
        <section aria-labelledby="versions-heading" className="space-y-2">
          <h3 id="versions-heading" className="text-sm font-semibold">
            Versions
          </h3>
          <ol className="space-y-2">
            {versions.map((v) => (
              <li key={v.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
                <FileImage className="text-muted-foreground size-8" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium break-words">
                    v{v.versionNumber} — {v.fileName}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {fileSizeLabel(v.fileSize)} · uploaded by {v.uploaderName ?? "—"}{" "}
                    {formatDateTime(v.createdAt)}
                  </p>
                  {v.notes && <p className="text-muted-foreground mt-1 text-xs">“{v.notes}”</p>}
                </div>
                <span
                  className={cn(
                    "rounded-md px-2 py-0.5 text-xs font-medium",
                    v.isCurrent
                      ? "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300"
                      : "bg-muted text-muted-foreground",
                  )}
                >
                  {v.isCurrent ? "Current" : "Earlier"}
                </span>
                {v.downloadUrl && (
                  <Button size="sm" variant="outline" asChild>
                    <a href={v.downloadUrl} aria-label={`Download v${v.versionNumber}`}>
                      Download
                    </a>
                  </Button>
                )}
              </li>
            ))}
          </ol>
        </section>
      )}

      {canUpload && (
        <section
          id="upload"
          aria-label={expanded ? heading : "Upload a new version"}
          className="scroll-mt-20 rounded-lg border p-4"
        >
          {expanded && <h3 className="mb-2 text-sm font-semibold">{heading}</h3>}
          {expanded && changeRequest && (
            <div className="mb-3 rounded-md border border-orange-200 bg-orange-50 px-3 py-2 text-sm text-orange-900 dark:border-orange-900 dark:bg-orange-950 dark:text-orange-200">
              <p className="font-medium">
                {changeRequest.deciderName ?? changeRequest.stepName} asked for changes
                {changeRequest.deciderName ? ` (${changeRequest.stepName})` : ""}
              </p>
              {changeRequest.comment && <p>“{changeRequest.comment}”</p>}
            </div>
          )}
          {uploadBlocked ? (
            <p className="text-muted-foreground text-sm">{uploadBlocked}</p>
          ) : (
            <div
              onDragOver={(e) => {
                e.preventDefault();
                setDragging(true);
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={onDrop}
              className={cn(
                expanded
                  ? "flex flex-col items-start gap-2 rounded-lg border-2 border-dashed p-4"
                  : "flex flex-wrap items-center justify-between gap-2",
                dragging && "border-primary bg-primary/5",
              )}
            >
              {expanded ? (
                <p className="flex items-center gap-2 text-sm">
                  <Upload className="text-muted-foreground size-4" aria-hidden />
                  Drop the file here, or choose it
                </p>
              ) : (
                <p className="text-muted-foreground text-sm">
                  Need to change it? A new version goes back for sign-off.
                </p>
              )}
              <FileInput
                key={pickerKey}
                inputRef={fileRef}
                accept={ARTWORK_EXTENSIONS}
                buttonLabel={expanded ? "Choose a file" : "Upload new version"}
                onFileChange={choose}
                className={expanded ? undefined : "[&>span]:hidden"}
              />
              {expanded && (
                <p className="text-muted-foreground text-xs">
                  {file
                    ? `${file.name} · ${fileSizeLabel(file.size)}`
                    : `PDF, AI, EPS, SVG, PNG, JPG, TIFF, WebP or ZIP, or MP4, MOV or WebM video — up to ${directUpload ? "2 GB" : "200 MB"}`}
                </p>
              )}
            </div>
          )}
          {expanded && !uploadBlocked && (
            <div className="mt-3 grid gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="version-notes">Notes for this version (optional)</Label>
                <Textarea
                  id="version-notes"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="e.g. Logo enlarged as asked"
                  className="min-h-9"
                />
              </div>
              {sendable && (
                <div className="space-y-1">
                  <label className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      className="size-4"
                      checked={sendAfter && !sendBlockedReason}
                      disabled={Boolean(sendBlockedReason)}
                      onChange={(e) => setSendAfter(e.target.checked)}
                    />
                    {status === "changes_requested"
                      ? "Send back for sign-off after upload"
                      : "Send for sign-off after upload"}
                  </label>
                  {sendBlockedReason && (
                    <p className="text-muted-foreground pl-6 text-xs">
                      {sendBlockedReason}; you can send it for sign-off afterwards.
                    </p>
                  )}
                </div>
              )}
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  disabled={!file || pending}
                  onClick={() =>
                    invalidationCount > 0 || panelWarning ? setConfirmOpen(true) : doUpload()
                  }
                >
                  <Upload className="size-4" aria-hidden /> {pending ? "Uploading…" : "Upload"}
                </Button>
                {!startsOpen && (
                  <Button
                    variant="ghost"
                    disabled={pending}
                    onClick={() => {
                      setExpanded(false);
                      setFile(null);
                      setPickerKey((k) => k + 1);
                      setError(null);
                    }}
                  >
                    Cancel
                  </Button>
                )}
              </div>
            </div>
          )}
          <div aria-live="polite">
            {progress && <p className="text-muted-foreground mt-2 text-sm">{progress}</p>}
            {success && !progress && (
              <p className="mt-2 text-sm text-green-700 dark:text-green-400">{success}</p>
            )}
          </div>
          {error && (
            <p role="alert" className="text-destructive mt-2 text-sm">
              {error}
            </p>
          )}
        </section>
      )}

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {invalidationCount > 0
                ? `This supersedes ${invalidationCount} sign-off${invalidationCount === 1 ? "" : "s"}`
                : "Upload a new version of the design?"}
            </DialogTitle>
            <DialogDescription>
              {invalidationCount > 0 && (
                <>
                  A new version replaces the decisions already made on:{" "}
                  {invalidationSteps.join(", ")}. Those sign-offs are asked again, with a link to
                  compare the versions. This is never silent.{" "}
                </>
              )}
              {panelWarning && <span className="font-medium">{panelWarning}</span>}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={pending}
              onClick={() => {
                // Close first so the progress and any error show on the page.
                setConfirmOpen(false);
                doUpload();
              }}
            >
              {invalidationCount > 0 ? "Upload and ask again" : "Upload"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
