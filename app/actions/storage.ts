"use server";

import { z } from "zod";
import { requireSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { copyBlobBatch, type CopyBatchResult } from "@/lib/storage-migrate";
import { createDirectUploadUrl, s3Delete, s3Enabled, s3Stat } from "@/lib/storage";
import { randomUUID } from "node:crypto";

const CHECK_PREFIX = "_checks/";

/**
 * Settings → Storage → "Test a browser upload", step 1: a presigned PUT for
 * a tiny throwaway object. The browser then uploads it directly, which is
 * the only way to prove the bucket's CORS policy allows the app. Admins only.
 */
export async function startStorageSelfTest(): Promise<
  ActionResult<{ url: string; contentType: string; storagePath: string }>
> {
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Admins only");
  if (!s3Enabled()) return fail("No bucket is configured");
  try {
    const storagePath = `${CHECK_PREFIX}${randomUUID()}.txt`;
    const signed = await createDirectUploadUrl("exports", storagePath, "text/plain");
    return success({ url: signed.url, contentType: signed.contentType, storagePath });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not sign the test upload");
  }
}

/** Step 2: confirm the test object arrived, then remove it. */
export async function finishStorageSelfTest(
  input: unknown,
): Promise<ActionResult<{ size: number }>> {
  const parsed = z.object({ storagePath: z.string().min(1).max(200) }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Admins only");
  const { storagePath } = parsed.data;
  if (!storagePath.startsWith(CHECK_PREFIX) || storagePath.includes("..")) {
    return fail("Invalid request");
  }
  try {
    const stat = await s3Stat("exports", storagePath);
    if (!stat) return fail("The browser reported success but the object is not in the bucket");
    await s3Delete("exports", storagePath).catch(() => {});
    return success({ size: stat.size });
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not check the bucket");
  }
}

const schema = z.object({
  cursor: z.string().max(2000).optional().nullable(),
  dryRun: z.boolean().optional(),
});

/**
 * Settings → Storage → "Copy files from Vercel Blob": one small batch per
 * call so it fits comfortably in a function's time limit; the button keeps
 * calling until the reply says done. Admins only.
 */
export async function copyBlobFilesToBucket(
  input: unknown,
): Promise<ActionResult<CopyBatchResult>> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only admins can move the file store");
  }
  try {
    const result = await copyBlobBatch({
      cursor: parsed.data.cursor ?? undefined,
      limit: 20,
      dryRun: parsed.data.dryRun,
      budgetMs: 45_000,
    });
    return success(result);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Copy failed");
  }
}
