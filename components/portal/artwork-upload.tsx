"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { FileInput } from "@/components/ui/file-input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { recordUploadedArtwork, uploadArtwork } from "@/app/actions/artwork";
import { ARTWORK_EXTENSIONS } from "@/lib/artwork-rules";

/** Streaming SHA-256, so large files hash without loading into memory. */
async function sha256OfFile(file: File): Promise<string> {
  const { createSHA256 } = await import("hash-wasm");
  const hasher = await createSHA256();
  const chunk = 8 * 1024 * 1024;
  for (let offset = 0; offset < file.size; offset += chunk) {
    hasher.update(new Uint8Array(await file.slice(offset, offset + chunk).arrayBuffer()));
  }
  return hasher.digest("hex");
}

/** A presigned PUT from the server, then the file straight to the bucket. */
async function putToBucket(
  file: File,
  itemId: string,
  onProgress: (pct: number) => void,
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
    xhr.setRequestHeader("Content-Type", signed.contentType!);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    };
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error("Upload failed"));
    xhr.onerror = () => reject(new Error("Upload failed — check your connection and try again"));
    xhr.send(file);
  });
  return signed.pathname;
}

/**
 * A sponsor's upload box in the portal (P4.2): choose the file, add a note
 * if wanted, upload. The server decides what happens next — the item goes
 * for sign-off when it is ready, and the team is told.
 */
export function PortalArtworkUpload({
  itemId,
  status,
  directUpload,
  uploadPrefix,
  changeRequest,
}: {
  itemId: string;
  status: string;
  directUpload: "s3" | "blob" | null;
  /** Vercel Blob only: the folder this item's files go in. */
  uploadPrefix: string | null;
  /** What was asked for, when changes were requested. */
  changeRequest?: { stepName: string; comment: string | null } | null;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [pickerKey, setPickerKey] = useState(0);
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const direct = directUpload === "s3" || (directUpload === "blob" && uploadPrefix);

  function finished(message: string | undefined) {
    setFile(null);
    setNotes("");
    setProgress(null);
    setPickerKey((k) => k + 1);
    toast.success(message ?? "Artwork uploaded");
    router.refresh();
  }

  function upload() {
    if (!file) return;
    setError(null);
    start(async () => {
      try {
        if (direct) {
          setProgress("Preparing…");
          const sha256 = await sha256OfFile(file);
          let pathname: string;
          if (directUpload === "s3") {
            pathname = await putToBucket(file, itemId, (pct) => setProgress(`Uploading ${pct}%`));
          } else {
            const clean = file.name.replace(/[^\w.-]+/g, "_").slice(0, 120);
            pathname = `${uploadPrefix}${crypto.randomUUID()}-${clean}`;
            const { upload: put } = await import("@vercel/blob/client");
            await put(pathname, file, {
              access: "public",
              handleUploadUrl: "/api/blob/upload",
              clientPayload: JSON.stringify({ itemId }),
              multipart: file.size > 50 * 1024 * 1024,
              onUploadProgress: ({ percentage }) => setProgress(`Uploading ${percentage}%`),
            });
          }
          setProgress("Saving…");
          const res = await recordUploadedArtwork({
            itemId,
            fileName: file.name,
            pathname,
            mimeType: file.type || "application/octet-stream",
            fileSize: file.size,
            sha256,
            notes,
            sendForSignoff: true,
          });
          if (!res.ok) {
            setError(res.error);
            setProgress(null);
          } else finished(res.message);
          return;
        }
        setProgress("Uploading…");
        const fd = new FormData();
        fd.set("itemId", itemId);
        fd.set("file", file);
        fd.set("notes", notes);
        fd.set("sendForSignoff", "on");
        const res = await uploadArtwork(fd);
        if (!res.ok) {
          setError(res.error);
          setProgress(null);
        } else finished(res.message);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Upload failed");
        setProgress(null);
      }
    });
  }

  const heading =
    status === "changes_requested" ? "Upload the corrected artwork" : "Upload your artwork";

  return (
    <section
      aria-labelledby="portal-upload"
      className="space-y-3 rounded-lg border border-sky-300 bg-sky-50/60 p-4 dark:border-sky-900 dark:bg-sky-950/30"
    >
      <div className="space-y-1">
        <h2 id="portal-upload" className="text-sm font-semibold">
          {heading}
        </h2>
        <p className="text-muted-foreground text-sm">
          Once it&rsquo;s uploaded it goes to the team for sign-off, and you can follow it here.
        </p>
      </div>
      {changeRequest && (
        <div className="rounded-md border border-orange-200 bg-orange-50 px-3 py-2 text-sm text-orange-900 dark:border-orange-900 dark:bg-orange-950 dark:text-orange-200">
          <p className="font-medium">Changes asked for ({changeRequest.stepName})</p>
          {changeRequest.comment && <p>&ldquo;{changeRequest.comment}&rdquo;</p>}
        </div>
      )}
      <div className="space-y-1.5">
        <FileInput
          key={pickerKey}
          inputRef={fileRef}
          accept={ARTWORK_EXTENSIONS}
          buttonLabel="Choose a file"
          disabled={pending}
          onFileChange={(files) => {
            setFile(files?.[0] ?? null);
            setError(null);
          }}
        />
        <p className="text-muted-foreground text-xs">
          PDF, AI, EPS, SVG, PNG, JPG, TIFF, WebP or ZIP, or MP4, MOV or WebM video — up to{" "}
          {direct ? "2 GB" : "200 MB"}
        </p>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="portal-upload-notes">
          A note for the team <span className="text-muted-foreground font-normal">(optional)</span>
        </Label>
        <Textarea
          id="portal-upload-notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="e.g. Logo updated as asked"
          className="min-h-9"
          disabled={pending}
        />
      </div>
      <Button
        type="button"
        className="h-11 w-full sm:h-9 sm:w-auto"
        disabled={!file || pending}
        onClick={upload}
      >
        <Upload aria-hidden /> {pending ? "Uploading…" : "Upload artwork"}
      </Button>
      <div aria-live="polite">
        {progress && <p className="text-muted-foreground text-sm">{progress}</p>}
      </div>
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
    </section>
  );
}
