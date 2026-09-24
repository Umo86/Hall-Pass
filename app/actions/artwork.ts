"use server";

import { revalidatePath } from "next/cache";

import { desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { artworkVersions, signageItems } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { INVALIDATABLE_STATUSES, signageTransition } from "@/lib/status/signage";
import { invalidateOnNewVersion } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { z } from "zod";
import { buildStoragePath, getObject, putObject, sha256Hex } from "@/lib/storage";
import { notify } from "@/lib/notify";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { ARTWORK_TYPE_MESSAGE, artworkBlockedReason, artworkTypeAllowed } from "@/lib/artwork-rules";
import {
  itemAuthzCtx,
  itemEntityCtx,
  loadItemBundle,
  notifyPendingAssignees,
  resolveAssigneeUserIds,
  startItemRun,
  type ItemBundle,
} from "@/lib/domain/signage";

const MAX_ARTWORK_BYTES = 200 * 1024 * 1024;
const PREVIEWABLE = ["image/png", "image/jpeg", "image/tiff", "image/svg+xml"];

/** Rasterised webp preview for image formats (SVG included, so scripts never render). */
async function generatePreview(bytes: Buffer, mimeType: string): Promise<Buffer | null> {
  if (!PREVIEWABLE.includes(mimeType)) return null;
  try {
    const { default: sharp } = await import("sharp");
    return await sharp(bytes, { density: 150 })
      .resize({ width: 1400, height: 1400, fit: "inside", withoutEnlargement: true })
      .webp({ quality: 82 })
      .toBuffer();
  } catch {
    return null; // An unreadable file still uploads; it just has no preview.
  }
}


/** Direct upload through the server (dev/local backend and small files). */
export async function uploadArtwork(
  formData: FormData,
): Promise<ActionResult<{ version: number }>> {
  const itemId = formData.get("itemId");
  const notes = formData.get("notes");
  const file = formData.get("file");
  if (typeof itemId !== "string" || !(file instanceof File)) return fail("Invalid upload");

  const session = await requireSession();
  const bundle = await loadItemBundle(db, itemId);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot upload artwork for this item");
  }
  const blocked = artworkBlockedReason(bundle.item.status);
  if (blocked) return fail(blocked);
  if (file.size > MAX_ARTWORK_BYTES) return fail("Artwork files are limited to 200 MB");
  if (!artworkTypeAllowed(file.type, file.name)) return fail(ARTWORK_TYPE_MESSAGE);

  const bytes = Buffer.from(await file.arrayBuffer());
  const sha256 = sha256Hex(bytes);
  const storagePath = buildStoragePath({
    organisationId: session.organisation.id,
    editionId: bundle.edition.id,
    entityType: "signage_item",
    entityId: itemId,
    fileName: file.name,
  });
  await putObject("artwork", storagePath, bytes);

  const preview = await generatePreview(bytes, file.type);
  let previewPath: string | null = null;
  if (preview) {
    previewPath = `${storagePath}.preview.webp`;
    await putObject("artwork", previewPath, preview);
  }

  return recordArtworkVersion(session, bundle, {
    filePath: storagePath,
    fileName: file.name,
    mimeType: file.type || "application/octet-stream",
    fileSize: file.size,
    sha256,
    previewPath,
    notes: typeof notes === "string" && notes.trim() ? notes.trim() : null,
  });
}

/**
 * Records a version that the browser uploaded straight to Vercel Blob
 * (multi-gigabyte files never pass through the server). The token route
 * already authorised the write; this re-checks and creates the version row.
 */
const uploadedSchema = z.object({
  itemId: z.string().uuid(),
  fileName: z.string().min(1).max(300),
  pathname: z.string().min(1).max(1000),
  mimeType: z.string().max(200),
  fileSize: z.number().int().positive(),
  sha256: z.string(),
  notes: z.string().max(2000).optional(),
});

export async function recordUploadedArtwork(
  rawInput: unknown,
): Promise<ActionResult<{ version: number }>> {
  const parsed = uploadedSchema.safeParse(rawInput);
  if (!parsed.success) return fail("Invalid upload details");
  const input = parsed.data;
  const session = await requireSession();
  const bundle = await loadItemBundle(db, input.itemId);
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot upload artwork for this item");
  }
  const blocked = artworkBlockedReason(bundle.item.status);
  if (blocked) return fail(blocked);
  if (!artworkTypeAllowed(input.mimeType, input.fileName)) return fail(ARTWORK_TYPE_MESSAGE);
  const prefix = `artwork/${bundle.organisation.id}/${bundle.edition.id}/signage_item/${bundle.item.id}/`;
  if (!input.pathname.startsWith(prefix) || input.pathname.includes("..")) {
    return fail("Invalid upload path");
  }
  if (!/^[0-9a-f]{64}$/.test(input.sha256)) return fail("Invalid file hash");
  const storagePath = input.pathname.slice("artwork/".length);
  let uploaded: Buffer | null = null;
  try {
    uploaded = input.fileSize <= 32 * 1024 * 1024 ? await getObject("artwork", storagePath) : null;
  } catch {
    return fail("The uploaded file could not be found — try the upload again");
  }
  let previewPath: string | null = null;
  if (uploaded) {
    const preview = await generatePreview(uploaded, input.mimeType);
    if (preview) {
      previewPath = `${storagePath}.preview.webp`;
      await putObject("artwork", previewPath, preview);
    }
  }
  return recordArtworkVersion(session, bundle, {
    filePath: storagePath,
    fileName: input.fileName,
    mimeType: input.mimeType || "application/octet-stream",
    fileSize: input.fileSize,
    sha256: input.sha256,
    previewPath,
    notes: input.notes?.trim() ? input.notes.trim() : null,
  });
}

/** Shared: record the version and drive status + invalidation. */
async function recordArtworkVersion(
  session: Session,
  bundle: ItemBundle,
  fileMeta: {
    filePath: string;
    fileName: string;
    mimeType: string;
    fileSize: number;
    sha256: string;
    previewPath?: string | null;
    notes: string | null;
  },
): Promise<ActionResult<{ version: number }>> {
  const item = bundle.item;
  try {
    const version = await db.transaction(async (tx) => {
      const [latest] = await tx
        .select({ v: artworkVersions.versionNumber })
        .from(artworkVersions)
        .where(eq(artworkVersions.signageItemId, item.id))
        .orderBy(desc(artworkVersions.versionNumber))
        .limit(1);
      const versionNumber = (latest?.v ?? 0) + 1;
      const [ver] = await tx
        .insert(artworkVersions)
        .values({
          signageItemId: item.id,
          versionNumber,
          filePath: fileMeta.filePath,
          fileName: fileMeta.fileName,
          mimeType: fileMeta.mimeType,
          fileSize: fileMeta.fileSize,
          sha256: fileMeta.sha256,
          previewPath: fileMeta.previewPath ?? null,
          uploadedBy: session.user.id,
          notes: fileMeta.notes,
        })
        .returning();

      const set: Partial<typeof signageItems.$inferInsert> = {
        currentArtworkVersionId: ver.id,
      };

      let summarySuffix = "";
      let reviewStarted = false;
      if (item.status === "awaiting_artwork") {
        set.status = signageTransition(item.status, "artwork_uploaded");
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        const instances = await startItemRun(tx, bundle, new Date());
        await notifyPendingAssignees(tx, bundle, instances);
        reviewStarted = true;
        summarySuffix = " — review started";
      } else if (INVALIDATABLE_STATUSES.includes(item.status) || item.status === "in_review") {
        // Never silently: decided steps configured to invalidate are superseded,
        // including approvals already given earlier in the current review.
        if (item.status !== "in_review") {
          set.status = signageTransition(item.status, "new_version_after_approval");
        }
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        const run = await loadRun(tx, "signage_item", item.id, item.currentRunNumber);
        const res = invalidateOnNewVersion(run, { entity: itemEntityCtx(bundle), now: new Date() });
        await persistRun(tx, "signage_item", item.id, res.instances);
        for (const inst of res.invalidated) {
          const approvers = inst.decidedBy ? [inst.decidedBy] : [];
          await notify(tx, {
            userIds: approvers,
            kind: "approval_invalidated",
            title: `New artwork supersedes your approval — ${item.ref}`,
            body: `${inst.stepName}: your approval of the previous artwork is superseded by v${versionNumber}. Compare the versions and re-approve.`,
            link: `/${bundle.edition.code}/signage/${item.ref}?tab=artwork&compare=${versionNumber}`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        summarySuffix =
          res.invalidated.length > 0
            ? ` — ${res.invalidated.length} approval(s) invalidated, back in review`
            : "";
      } else {
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
      }

      // Approvers with pending instances hear about new artwork.
      if (!reviewStarted && item.currentRunNumber > 0) {
        const run = await loadRun(tx, "signage_item", item.id, item.currentRunNumber);
        for (const inst of run.filter((i) => i.status === "pending")) {
          const assignees = await resolveAssigneeUserIds(
            tx,
            session.organisation.id,
            bundle.edition.id,
            bundle.venue.id,
            item,
            inst,
          );
          await notify(tx, {
            userIds: assignees,
            kind: "artwork_uploaded",
            title: `New artwork v${versionNumber}: ${item.ref}`,
            link: `/${bundle.edition.code}/signage/${item.ref}?tab=artwork`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
      }

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: item.id,
        action: "upload",
        after: { version: versionNumber, sha256: fileMeta.sha256, fileName: fileMeta.fileName },
        summary: `Artwork v${versionNumber} uploaded for ${item.ref}${summarySuffix}`,
      });
      return versionNumber;
    });
    revalidatePath("/", "layout");
    return success({ version }, `Artwork v${version} uploaded`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Upload failed");
  }
}

export type { ItemBundle };
