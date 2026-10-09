"use server";

import { z } from "zod";
import { requireSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { copyBlobBatch, type CopyBatchResult } from "@/lib/storage-migrate";

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
