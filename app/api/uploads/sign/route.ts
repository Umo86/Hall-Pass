import { NextResponse } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db/client";
import { requireSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import {
  artworkBlockedReason,
  artworkTypeAllowed,
  ARTWORK_TYPE_MESSAGE,
} from "@/lib/artwork-rules";
import { panelParent } from "@/lib/domain/stand-designs";
import {
  MAX_DIRECT_UPLOAD_BYTES,
  buildStoragePath,
  contentTypeFor,
  createDirectUploadUrl,
  s3Enabled,
} from "@/lib/storage";

export const dynamic = "force-dynamic";

const schema = z.object({
  itemId: z.string().uuid(),
  fileName: z.string().trim().min(1).max(300),
  contentType: z.string().trim().max(200).optional(),
  fileSize: z.number().int().positive(),
});

/**
 * Issues a presigned PUT so the browser uploads artwork straight into the
 * S3/R2 bucket — multi-gigabyte files never pass through the server. The
 * path is chosen here (never by the client) under the item's own folder;
 * the version row is recorded afterwards by recordUploadedArtwork, which
 * checks the object really arrived and how big it is.
 */
export async function POST(request: Request) {
  if (!s3Enabled()) {
    return NextResponse.json({ error: "Direct uploads are not configured" }, { status: 404 });
  }
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  const input = parsed.data;
  try {
    const session = await requireSession();
    const bundle = await loadItemBundle(db, input.itemId, {
      organisationId: session.organisation.id,
    });
    if (!bundle || bundle.item.deletedAt) throw new Error("Item not found");
    if (editionIsReadOnly(bundle.edition.status)) throw new Error("Edition is read-only");
    const blocked = artworkBlockedReason(bundle.item.status, await panelParent(db, bundle.item));
    if (blocked) throw new Error(blocked);
    if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
      throw new Error("You cannot upload artwork for this item");
    }
    if (input.fileSize > MAX_DIRECT_UPLOAD_BYTES)
      throw new Error("Artwork files are limited to 2 GB");
    const contentType = input.contentType || contentTypeFor(input.fileName);
    if (!artworkTypeAllowed(contentType, input.fileName)) throw new Error(ARTWORK_TYPE_MESSAGE);
    const storagePath = buildStoragePath({
      organisationId: bundle.organisation.id,
      editionId: bundle.edition.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      fileName: input.fileName,
    });
    const signed = await createDirectUploadUrl("artwork", storagePath, contentType);
    return NextResponse.json({
      url: signed.url,
      contentType: signed.contentType,
      // The same shape recordUploadedArtwork expects: "artwork/<storage path>".
      pathname: signed.key,
      expiresInSeconds: signed.expiresInSeconds,
    });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Upload refused" },
      { status: 400 },
    );
  }
}
