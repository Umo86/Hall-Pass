import { NextResponse } from "next/server";
import { copyBlobBatch } from "@/lib/storage-migrate";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

function isAuthorised(request: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  return request.headers.get("authorization") === `Bearer ${secret}`;
}

/**
 * One-off move of every file from Vercel Blob into the S3/R2 bucket (the
 * same job as the button under Settings → Storage, for scripts):
 *
 *   curl -X POST -H "Authorization: Bearer $CRON_SECRET" \
 *     "https://<app>/api/admin/storage/migrate?limit=50"
 *
 * Repeat with `&cursor=<nextCursor>` until `done` is true; a reply with
 * `incomplete: true` means run the same cursor again. Add `dryRun=1` to
 * count without copying. Needs BLOB_READ_WRITE_TOKEN and the S3_* variables
 * set at the same time.
 */
export async function POST(request: Request) {
  if (!isAuthorised(request)) {
    return NextResponse.json({ error: "Unauthorised" }, { status: 401 });
  }
  const url = new URL(request.url);
  try {
    const result = await copyBlobBatch({
      cursor: url.searchParams.get("cursor") ?? undefined,
      limit: Number(url.searchParams.get("limit") ?? 50),
      dryRun: url.searchParams.get("dryRun") === "1",
      budgetMs: (maxDuration - 30) * 1000,
    });
    return NextResponse.json(result);
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Copy failed" },
      { status: 400 },
    );
  }
}
