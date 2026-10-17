"use server";

import { revalidatePath } from "next/cache";

import { desc, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { artworkVersions, signageItems, sponsors } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { INVALIDATABLE_STATUSES, signageTransition } from "@/lib/status/signage";
import { invalidateOnNewVersion } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { z } from "zod";
import {
  MAX_DIRECT_UPLOAD_BYTES,
  buildStoragePath,
  getObject,
  putObject,
  s3Delete,
  s3Enabled,
  s3Stat,
  sha256Hex,
} from "@/lib/storage";
import { notify } from "@/lib/notify";
import { recipientsWhoCanSee } from "@/lib/users/external";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import {
  ARTWORK_TYPE_MESSAGE,
  artworkBlockedReason,
  artworkTypeAllowed,
} from "@/lib/artwork-rules";
import {
  askedSummary,
  itemAuthzCtx,
  itemEntityCtx,
  loadItemBundle,
  missingSubmitFields,
  notifyPendingAssignees,
  resolveAssigneeUserIds,
  resubmitItemInTx,
  startItemRun,
  submitItemInTx,
  type ItemBundle,
} from "@/lib/domain/signage";
import { itemPath } from "@/lib/edition-path";
import { panelParent } from "@/lib/domain/stand-designs";
import { settleApprovalNotifications } from "@/lib/domain/notifications";

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

/** What an upload did: the new version, and the item's status afterwards. */
export type UploadOutcome = { version: number; status: string };

/**
 * Direct upload through the server (dev/local backend and small files).
 * `sendForSignoff=on` also sends a draft for sign-off, or a "changes
 * requested" item back for sign-off, in the same step.
 */
export async function uploadArtwork(formData: FormData): Promise<ActionResult<UploadOutcome>> {
  const itemId = formData.get("itemId");
  const notes = formData.get("notes");
  const file = formData.get("file");
  const sendForSignoff = formData.get("sendForSignoff") === "on";
  if (typeof itemId !== "string" || !(file instanceof File)) return fail("Invalid upload");

  const session = await requireSession();
  const bundle = await loadItemBundle(db, itemId, { organisationId: session.organisation.id });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot upload artwork for this item");
  }
  const blocked = artworkBlockedReason(bundle.item.status, await panelParent(db, bundle.item));
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
    sendForSignoff,
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
  sendForSignoff: z.boolean().optional(),
});

export async function recordUploadedArtwork(
  rawInput: unknown,
): Promise<ActionResult<UploadOutcome>> {
  const parsed = uploadedSchema.safeParse(rawInput);
  if (!parsed.success) return fail("Invalid upload details");
  const input = parsed.data;
  const session = await requireSession();
  const bundle = await loadItemBundle(db, input.itemId, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
    return fail("You cannot upload artwork for this item");
  }
  const blocked = artworkBlockedReason(bundle.item.status, await panelParent(db, bundle.item));
  if (blocked) return fail(blocked);
  if (!artworkTypeAllowed(input.mimeType, input.fileName)) return fail(ARTWORK_TYPE_MESSAGE);
  const prefix = `artwork/${bundle.organisation.id}/${bundle.edition.id}/signage_item/${bundle.item.id}/`;
  if (!input.pathname.startsWith(prefix) || input.pathname.includes("..")) {
    return fail("Invalid upload path");
  }
  if (!/^[0-9a-f]{64}$/.test(input.sha256)) return fail("Invalid file hash");
  const storagePath = input.pathname.slice("artwork/".length);
  let fileSize = input.fileSize;
  if (s3Enabled()) {
    // The bucket is the source of truth for what actually arrived: a
    // presigned PUT cannot cap the size up front, so an oversized object is
    // removed here rather than recorded.
    const stat = await s3Stat("artwork", storagePath).catch(() => null);
    if (!stat) return fail("The uploaded file could not be found — try the upload again");
    if (stat.size > MAX_DIRECT_UPLOAD_BYTES) {
      await s3Delete("artwork", storagePath).catch(() => {});
      return fail("Artwork files are limited to 2 GB");
    }
    fileSize = stat.size;
  }
  let uploaded: Buffer | null = null;
  try {
    uploaded = fileSize <= 32 * 1024 * 1024 ? await getObject("artwork", storagePath) : null;
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
    fileSize,
    sha256: input.sha256,
    previewPath,
    notes: input.notes?.trim() ? input.notes.trim() : null,
    sendForSignoff: input.sendForSignoff ?? false,
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
    /** Draft: send for sign-off; changes requested: send back for sign-off. */
    sendForSignoff?: boolean;
  },
): Promise<ActionResult<UploadOutcome>> {
  const item = bundle.item;
  const ctx = itemAuthzCtx(bundle);
  // A sponsor uploading in the portal (P4.2): the upload is how they hand the
  // artwork over, so it sends their own item for sign-off when it is ready —
  // they have no separate "send" (signage.submit stays staff-only).
  const sponsorUpload =
    session.actor.kind === "external" && can(session.actor, { type: "artwork.upload", item: ctx });
  // Sending it on needs the right to submit as well as to upload.
  const mayAlsoSend =
    (Boolean(fileMeta.sendForSignoff) || sponsorUpload) &&
    ["draft", "changes_requested"].includes(item.status) &&
    (sponsorUpload || can(session.actor, { type: "signage.submit", item: ctx }));
  try {
    const outcome = await db.transaction(async (tx) => {
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
      let status: string = item.status;
      let note = "";
      if (item.status === "awaiting_artwork") {
        set.status = signageTransition(item.status, "artwork_uploaded");
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        const instances = await startItemRun(tx, bundle, new Date());
        await settleApprovalNotifications(tx, "signage_item", item.id, {
          newlyPending: instances.filter((i) => i.status === "pending").map((i) => i.id),
        });
        await notifyPendingAssignees(tx, bundle, instances);
        reviewStarted = true;
        status = "in_review";
        summarySuffix = " — sign-off started";
        const asked = instances.filter((i) => i.status === "pending");
        note = ` and sent for sign-off${asked.length ? ` — waiting on ${askedSummary(asked)}` : ""}`;
      } else if (INVALIDATABLE_STATUSES.includes(item.status) || item.status === "in_review") {
        // Never silently: decided steps configured to invalidate are superseded,
        // including approvals already given earlier in the current review.
        if (item.status !== "in_review") {
          set.status = signageTransition(item.status, "new_version_after_approval");
          status = set.status;
        }
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        const run = await loadRun(tx, "signage_item", item.id, item.currentRunNumber);
        const res = invalidateOnNewVersion(run, { entity: itemEntityCtx(bundle), now: new Date() });
        await persistRun(tx, "signage_item", item.id, res.instances);
        // Requests for steps the new version superseded are over.
        await settleApprovalNotifications(tx, "signage_item", item.id);
        for (const inst of res.invalidated) {
          // A partner who decided (a venue or sponsor approver) hears only
          // while their live grants here still show them the item.
          const approvers = await recipientsWhoCanSee(
            tx,
            session.organisation.id,
            inst.decidedBy ? [inst.decidedBy] : [],
            { sees: (a) => can(a, { type: "signage.view", item: ctx }) },
          );
          await notify(tx, {
            userIds: approvers,
            scope: { organisationId: session.organisation.id, editionId: bundle.edition.id },
            kind: "approval_invalidated",
            title: `New artwork supersedes your approval — ${item.ref}`,
            body: `${inst.stepName}: your approval of the previous artwork is superseded by v${versionNumber}. Compare the versions and re-approve.`,
            link: `${itemPath(bundle.edition.code, item)}?tab=artwork&compare=${versionNumber}`,
            entityType: "signage_item",
            entityId: item.id,
          });
        }
        summarySuffix =
          res.invalidated.length > 0
            ? ` — ${res.invalidated.length} approval(s) invalidated, back in review`
            : "";
        if (res.invalidated.length > 0) {
          note = ` — ${res.invalidated.length} sign-off${res.invalidated.length === 1 ? "" : "s"} superseded, back in sign-off`;
        }
      } else {
        await tx.update(signageItems).set(set).where(eq(signageItems.id, item.id));
        const updated = { ...bundle, item: { ...item, currentArtworkVersionId: ver.id } };
        const missing = missingSubmitFields(item);
        if (mayAlsoSend && (item.status === "changes_requested" || missing.length === 0)) {
          // In a savepoint: if it can't be sent, the upload itself still stands.
          try {
            const back = item.status === "changes_requested";
            const opts = { actorUserId: session.user.id, now: new Date() };
            const res = await tx.transaction((sp) =>
              back ? resubmitItemInTx(sp, updated, opts) : submitItemInTx(sp, updated, opts),
            );
            // Sent for sign-off just now: anyone not asked this time is done.
            await settleApprovalNotifications(tx, "signage_item", item.id);
            reviewStarted = true;
            status = res.next;
            note = ` and sent ${back ? "back " : ""}for sign-off${res.pending.length ? ` — waiting on ${askedSummary(res.pending)}` : ""}`;
          } catch (err) {
            note = `, but not sent for sign-off: ${err instanceof Error ? err.message : "please try again"}`;
          }
        } else if (mayAlsoSend) {
          note = `. Add ${missing.join(", ")} to send it for sign-off`;
        }
      }

      // A sponsor hears plainly what happened (no internal names or errors),
      // and the team hears that the sponsor has delivered.
      if (sponsorUpload) {
        const detailsMissing = item.status === "draft" && missingSubmitFields(item).length > 0;
        note = reviewStarted
          ? " and sent for sign-off"
          : detailsMissing
            ? " — the team will send it for sign-off once its details are complete"
            : " — the team will send it for sign-off";
        const [sponsor] = item.sponsorId
          ? await tx
              .select({ name: sponsors.companyName })
              .from(sponsors)
              .where(eq(sponsors.id, item.sponsorId))
              .limit(1)
          : [];
        const uploader = session.user.fullName || session.user.email;
        const who = sponsor?.name ?? uploader;
        await notify(tx, {
          userIds: [item.ownerUserId ?? item.createdBy].filter((id): id is string => Boolean(id)),
          kind: "artwork_uploaded",
          title: `${who} uploaded artwork for ${item.name} (${item.ref})`,
          body: `${uploader} uploaded v${versionNumber} (${fileMeta.fileName})${
            reviewStarted
              ? " and it has gone for sign-off."
              : detailsMissing
                ? ". It goes for sign-off once its details are complete — open the item to finish them."
                : ". Open the item to send it for sign-off."
          }`,
          link: `${itemPath(bundle.edition.code, item)}?tab=artwork`,
          entityType: "signage_item",
          entityId: item.id,
        });
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
            link: `${itemPath(bundle.edition.code, item)}?tab=artwork`,
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
        summary: `Artwork v${versionNumber} uploaded for ${item.ref}${sponsorUpload ? " by the sponsor" : ""}${summarySuffix}`,
      });
      return { version: versionNumber, status, note };
    });
    revalidatePath("/", "layout");
    return success(
      { version: outcome.version, status: outcome.status },
      `v${outcome.version} uploaded${outcome.note}`,
    );
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Upload failed");
  }
}

export type { ItemBundle };
