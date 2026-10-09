import "server-only";
import {
  blobEnabled,
  contentTypeFor,
  s3Enabled,
  s3PutStream,
  s3Stat,
  type Bucket,
} from "@/lib/storage";

const BUCKETS: Bucket[] = ["artwork", "documents", "photos", "floorplans", "exports"];

export type CopyBatchResult = {
  ok: boolean;
  dryRun: boolean;
  inThisBatch: number;
  processed: number;
  copied: number;
  skipped: number;
  failed: { pathname: string; error: string }[];
  /** Stopped on the time budget part-way through the page: run the same cursor again. */
  incomplete: boolean;
  done: boolean;
  nextCursor?: string | null;
  note?: string;
};

/**
 * Copy one page of files from Vercel Blob into the S3/R2 bucket under the
 * same key, so nothing in the database changes. Safe to run again: a file
 * already in the bucket with the same size is skipped. Call until `done`.
 */
export async function copyBlobBatch(opts: {
  cursor?: string;
  limit?: number;
  dryRun?: boolean;
  /** Stop before this much time has passed; the rest of the page is left for the next call. */
  budgetMs?: number;
}): Promise<CopyBatchResult> {
  if (!s3Enabled()) throw new Error("The S3_* variables are not set");
  if (!blobEnabled()) throw new Error("BLOB_READ_WRITE_TOKEN is not set");
  const limit = Math.min(500, Math.max(1, opts.limit ?? 50));
  const dryRun = Boolean(opts.dryRun);
  const budgetMs = opts.budgetMs ?? 270_000;

  const { list } = await import("@vercel/blob");
  const page = await list({ cursor: opts.cursor, limit });
  let copied = 0;
  let skipped = 0;
  const failed: { pathname: string; error: string }[] = [];
  const started = Date.now();
  let stoppedEarly = false;

  for (const blob of page.blobs) {
    const [bucket, ...rest] = blob.pathname.split("/");
    const storagePath = rest.join("/");
    if (!BUCKETS.includes(bucket as Bucket) || !storagePath) {
      failed.push({ pathname: blob.pathname, error: "Not under a known bucket" });
      continue;
    }
    try {
      const existing = await s3Stat(bucket as Bucket, storagePath);
      if (existing && existing.size === blob.size) {
        skipped += 1;
        continue;
      }
      if (dryRun) {
        copied += 1;
        continue;
      }
      const res = await fetch(blob.url);
      if (!res.ok || !res.body) throw new Error(`Blob fetch failed: ${res.status}`);
      const type = res.headers.get("content-type") || contentTypeFor(blob.pathname);
      await s3PutStream(blob.pathname, res.body, type);
      copied += 1;
    } catch (err) {
      failed.push({
        pathname: blob.pathname,
        error: err instanceof Error ? err.message : String(err),
      });
    }
    if (Date.now() - started >= budgetMs) {
      stoppedEarly = true;
      break;
    }
  }

  return {
    ok: failed.length === 0,
    dryRun,
    inThisBatch: page.blobs.length,
    processed: copied + skipped + failed.length,
    copied,
    skipped,
    failed,
    incomplete: stoppedEarly,
    done: !stoppedEarly && !page.hasMore && failed.length === 0,
    ...(stoppedEarly
      ? {
          nextCursor: opts.cursor ?? null,
          note: "Time limit reached — run again with the same cursor",
        }
      : page.hasMore
        ? { nextCursor: page.cursor }
        : {}),
  };
}
