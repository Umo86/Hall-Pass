import { NextResponse } from "next/server";
import {
  blobEnabled,
  contentTypeFor,
  s3Enabled,
  s3PutStream,
  s3Stat,
  type Bucket,
} from "@/lib/storage";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

const BUCKETS: Bucket[] = ["artwork", "documents", "photos", "floorplans", "exports"];

function isAuthorised(request: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  return request.headers.get("authorization") === `Bearer ${secret}`;
}

/**
 * One-off move of every file from Vercel Blob into the S3/R2 bucket, under
 * the same key, so nothing in the database changes. Safe to run again: a
 * file already in the bucket with the same size is skipped. Works in
 * batches so it fits a function's time limit — call it until `done` is true.
 *
 *   curl -X POST -H "Authorization: Bearer $CRON_SECRET" \
 *     "https://<app>/api/admin/storage/migrate?limit=50"
 *
 * Needs BLOB_READ_WRITE_TOKEN and the S3_* variables set at the same time.
 * Add `dryRun=1` to count without copying.
 */
export async function POST(request: Request) {
  if (!isAuthorised(request)) {
    return NextResponse.json({ error: "Unauthorised" }, { status: 401 });
  }
  if (!s3Enabled())
    return NextResponse.json({ error: "S3_* variables are not set" }, { status: 400 });
  if (!blobEnabled()) {
    return NextResponse.json({ error: "BLOB_READ_WRITE_TOKEN is not set" }, { status: 400 });
  }
  const url = new URL(request.url);
  const limit = Math.min(500, Math.max(1, Number(url.searchParams.get("limit") ?? 50)));
  const dryRun = url.searchParams.get("dryRun") === "1";
  const cursor = url.searchParams.get("cursor") ?? undefined;

  const { list } = await import("@vercel/blob");
  const page = await list({ cursor, limit });
  let copied = 0;
  let skipped = 0;
  const failed: { pathname: string; error: string }[] = [];
  const started = Date.now();

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
    // Leave time to return before the function limit.
    if (Date.now() - started > (maxDuration - 30) * 1000) break;
  }

  return NextResponse.json({
    ok: failed.length === 0,
    dryRun,
    inThisBatch: page.blobs.length,
    copied,
    skipped,
    failed,
    done: !page.hasMore && failed.length === 0,
    ...(page.hasMore ? { nextCursor: page.cursor } : {}),
  });
}
