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
import { buildStoragePath, putObject, sha256Hex } from "@/lib/storage";
import { notify } from "@/lib/notify";
import {
  itemAuthzCtx,
  itemEntityCtx,
  loadItemBundle,
  resolveAssigneeUserIds,
  startItemRun,
  type ItemBundle,
} from "@/lib/domain/signage";

const ARTWORK_TYPES = [
  "application/pdf",
  "application/postscript",
  "application/illustrator",
  "image/svg+xml",
  "image/png",
  "image/jpeg",
  "image/tiff",
  "application/zip",
];
const MAX_ARTWORK_BYTES = 200 * 1024 * 1024;

/**
 * How many approvals a new version would invalidate — shown in the upload
 * dialog ("This will invalidate 3 approvals") before the user confirms.
 */
export async function artworkInvalidationPreview(
  itemId: string,
): Promise<{ count: number; steps: string[] }> {
  const bundle = await loadItemBundle(db, itemId);
  if (!bundle || bundle.item.currentRunNumber === 0) return { count: 0, steps: [] };
  const run = await loadRun(db, "signage_item", itemId, bundle.item.currentRunNumber);
  const decided = run.filter(
    (i) =>
      ["approved", "approved_with_conditions", "confirmed"].includes(i.status) &&
      i.invalidateOnNewVersion,
  );
  return { count: decided.length, steps: decided.map((i) => i.stepName) };
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
  if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot upload artwork for this item");
  }
  if (
    bundle.item.status === "installed" ||
    bundle.item.status === "snagged" ||
    bundle.item.status === "closed"
  ) {
    return fail("This item is installed — an admin or ops user must reopen it before new artwork");
  }
  if (file.size > MAX_ARTWORK_BYTES) return fail("Artwork files are limited to 200 MB");
  if (file.type && !ARTWORK_TYPES.includes(file.type) && !/\.(ai|eps)$/i.test(file.name)) {
    return fail("Unsupported file type — use PDF, AI, EPS, SVG, PNG, JPG, TIFF or ZIP");
  }

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

  return recordArtworkVersion(session, bundle, {
    filePath: storagePath,
    fileName: file.name,
    mimeType: file.type || "application/octet-stream",
    fileSize: file.size,
    sha256,
    notes: typeof notes === "string" && notes.trim() ? notes.trim() : null,
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
          uploadedBy: session.user.id,
          notes: fileMeta.notes,
        })
        .returning();

      const set: Partial<typeof signageItems.$inferInsert> = {
        currentArtworkVersionId: ver.id,
      };

      let summarySuffix = "";
      if (item.status === "awaiting_artwork") {
        set.status = signageTransition(item.status, "artwork_uploaded");
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        await startItemRun(tx, bundle, new Date());
        summarySuffix = " — review started";
      } else if (INVALIDATABLE_STATUSES.includes(item.status)) {
        // Never silently: decided steps configured to invalidate are superseded.
        set.status = signageTransition(item.status, "new_version_after_approval");
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
            body: `${inst.stepName}: approved v${item.currentRunNumber} decision now superseded by v${versionNumber}. Compare the versions and re-approve.`,
            link: `/${bundle.edition.code}/signage/${item.ref}?tab=artwork&compare=${versionNumber}`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        summarySuffix = ` — ${res.invalidated.length} approval(s) invalidated, back in review`;
      } else {
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
      }

      // Approvers with pending instances hear about new artwork.
      if (item.currentRunNumber > 0) {
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
