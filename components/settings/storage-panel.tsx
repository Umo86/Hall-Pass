"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { copyBlobFilesToBucket } from "@/app/actions/storage";

type Totals = { copied: number; skipped: number; failed: { pathname: string; error: string }[] };

/**
 * Settings → Storage: where files live, whether the bucket answers, and
 * the one-click copy from Vercel Blob while both are configured.
 */
export function StoragePanel({
  backend,
  check,
  blobConfigured,
  s3Configured,
  bucket,
}: {
  backend: string;
  /** Result of a live call to the bucket, or null when no bucket is configured. */
  check: { ok: boolean; detail: string } | null;
  blobConfigured: boolean;
  s3Configured: boolean;
  bucket: string | null;
}) {
  const [totals, setTotals] = useState<Totals>({ copied: 0, skipped: 0, failed: [] });
  const [status, setStatus] = useState<"idle" | "running" | "done" | "error">("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function copyAll() {
    setStatus("running");
    setMessage(null);
    setTotals({ copied: 0, skipped: 0, failed: [] });
    start(async () => {
      let cursor: string | null | undefined = undefined;
      let copied = 0;
      let skipped = 0;
      const failed: Totals["failed"] = [];
      for (let round = 0; round < 500; round++) {
        const res = await copyBlobFilesToBucket({ cursor });
        if (!res.ok) {
          setStatus("error");
          setMessage(res.error);
          return;
        }
        const r = res.data!;
        copied += r.copied;
        skipped += r.skipped;
        failed.push(...r.failed);
        setTotals({ copied, skipped, failed: [...failed] });
        if (r.done) {
          setStatus("done");
          setMessage(
            `All files are in the bucket (${copied} copied, ${skipped} already there). You can now remove BLOB_READ_WRITE_TOKEN from Vercel and delete the Blob store.`,
          );
          router.refresh();
          return;
        }
        if (r.failed.length > 0 && !r.nextCursor && !r.incomplete) {
          setStatus("error");
          setMessage(`${r.failed.length} file(s) could not be copied — see below, then try again.`);
          return;
        }
        cursor = r.incomplete ? cursor : r.nextCursor;
      }
      setStatus("error");
      setMessage("Stopped after many rounds — run it again to continue.");
    });
  }

  return (
    <div className="space-y-4 text-sm">
      <dl className="grid grid-cols-[9rem_1fr] gap-x-4 gap-y-1.5">
        <dt className="text-muted-foreground">New files go to</dt>
        <dd className="font-medium">
          {backend === "s3"
            ? `S3-compatible bucket${bucket ? ` “${bucket}”` : ""} (Cloudflare R2 or similar)`
            : backend === "blob"
              ? "Vercel Blob"
              : backend === "supabase"
                ? "Supabase Storage"
                : "This server's disk (does not persist on Vercel)"}
        </dd>
        {check && (
          <>
            <dt className="text-muted-foreground">Bucket check</dt>
            <dd
              className={check.ok ? "text-emerald-700 dark:text-emerald-400" : "text-destructive"}
            >
              {check.ok ? "Reachable — credentials accepted" : `Not working: ${check.detail}`}
            </dd>
          </>
        )}
        <dt className="text-muted-foreground">Vercel Blob</dt>
        <dd>{blobConfigured ? "Configured (token present)" : "Not configured"}</dd>
      </dl>

      {s3Configured && blobConfigured && (
        <div className="rounded-lg border p-4">
          <h3 className="font-semibold">Copy files from Vercel Blob into the bucket</h3>
          <p className="text-muted-foreground mt-1">
            Every file already in Vercel Blob is copied across under the same name, so nothing else
            changes. Files not yet copied still open from Blob in the meantime. Safe to run more
            than once.
          </p>
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <Button onClick={copyAll} disabled={pending || status === "running"}>
              {status === "running" ? "Copying…" : "Copy files now"}
            </Button>
            {status !== "idle" && (
              <span className="text-muted-foreground">
                {totals.copied} copied · {totals.skipped} already there
                {totals.failed.length ? ` · ${totals.failed.length} failed` : ""}
              </span>
            )}
          </div>
          {message && (
            <p className={`mt-2 ${status === "error" ? "text-destructive" : ""}`}>{message}</p>
          )}
          {totals.failed.length > 0 && (
            <ul className="text-destructive mt-2 list-disc pl-5 text-xs">
              {totals.failed.slice(0, 10).map((f) => (
                <li key={f.pathname}>
                  {f.pathname}: {f.error}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {s3Configured && !blobConfigured && (
        <p className="text-muted-foreground">
          Only the bucket is configured — nothing to copy. New uploads and every download use it.
        </p>
      )}
      {!s3Configured && (
        <p className="text-muted-foreground">
          To use a Cloudflare R2 bucket, set S3_BUCKET, S3_ENDPOINT, S3_ACCESS_KEY_ID and
          S3_SECRET_ACCESS_KEY in the hosting settings and redeploy — the README has the steps. This
          page then shows the bucket check and the copy button.
        </p>
      )}
    </div>
  );
}
