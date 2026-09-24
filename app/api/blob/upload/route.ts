import { NextResponse } from "next/server";
import { handleUpload, type HandleUploadBody } from "@vercel/blob/client";
import { db } from "@/lib/db/client";
import { requireSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { artworkBlockedReason } from "@/lib/artwork-rules";

const MAX_DIRECT_UPLOAD_BYTES = 2 * 1024 * 1024 * 1024; // 2 GB

/**
 * Issues short-lived tokens for direct browser → Vercel Blob uploads, so
 * multi-gigabyte artwork never passes through the server. The token is
 * scoped to the exact item folder the caller may write to; the version row
 * is only recorded afterwards by the recordUploadedArtwork action, which
 * re-checks everything.
 */
export async function POST(request: Request) {
  const body = (await request.json()) as HandleUploadBody;
  try {
    const session = await requireSession();
    const result = await handleUpload({
      body,
      request,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        const payload = JSON.parse(clientPayload ?? "{}") as { itemId?: string };
        if (!payload.itemId) throw new Error("Missing itemId");
        const bundle = await loadItemBundle(db, payload.itemId);
        if (!bundle || bundle.item.deletedAt) throw new Error("Item not found");
        if (editionIsReadOnly(bundle.edition.status)) throw new Error("Edition is read-only");
        const blocked = artworkBlockedReason(bundle.item.status);
        if (blocked) throw new Error(blocked);
        if (!can(session.actor, { type: "artwork.upload", item: itemAuthzCtx(bundle) })) {
          throw new Error("You cannot upload artwork for this item");
        }
        const prefix = `artwork/${bundle.organisation.id}/${bundle.edition.id}/signage_item/${bundle.item.id}/`;
        if (!pathname.startsWith(prefix) || pathname.includes("..")) {
          throw new Error("Invalid upload path");
        }
        return {
          maximumSizeInBytes: MAX_DIRECT_UPLOAD_BYTES,
          addRandomSuffix: false,
          allowOverwrite: false,
        };
      },
      // Recording happens via the follow-up server action, not this webhook,
      // so localhost development (unreachable by the webhook) works the same.
      onUploadCompleted: async () => {},
    });
    return NextResponse.json(result);
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Upload refused" },
      { status: 400 },
    );
  }
}
