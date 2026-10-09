"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq, inArray, sql } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { memberships, signageItems, snags } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { notify } from "@/lib/notify";
import { itemPath, type ItemKind } from "@/lib/edition-path";
import { buildStoragePath, putObject } from "@/lib/storage";
import { loadItemBundle, type ItemBundle } from "@/lib/domain/signage";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { signageTransition, type SignageStatus } from "@/lib/status/signage";

const PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_PHOTO_BYTES = 15 * 1024 * 1024;
/** Snags are raised on things that get installed: signs and stand panels. */
const SNAGGABLE_KINDS = ["signage", "stand_panel"];
const OPEN_STATUSES = ["open", "in_progress"] as const;

const raiseSchema = z.object({
  itemId: z.string().uuid(),
  description: z.string().trim().min(1, "Describe the problem").max(2000),
  severity: z.enum(["low", "medium", "high"]).default("medium"),
});

const updateSchema = z.object({
  snagId: z.string().uuid(),
  status: z.enum(["open", "in_progress", "resolved", "wont_fix"]),
  note: z.string().trim().max(2000).optional().nullable(),
});

function formValues(formData: FormData): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of formData.entries()) if (typeof v === "string") out[k] = v;
  return out;
}

/** Store an optional photo from the form; returns its path or null. */
async function savePhoto(
  formData: FormData,
  bundle: ItemBundle,
  fileName: string,
): Promise<{ path: string | null } | { error: string }> {
  const file = formData.get("file");
  if (!(file instanceof File) || file.size === 0) return { path: null };
  if (file.size > MAX_PHOTO_BYTES) return { error: "That photo is too large (15 MB max)" };
  if (!PHOTO_TYPES.includes(file.type)) return { error: "Use a JPG, PNG or WebP photo" };
  const ext = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg";
  const path = buildStoragePath({
    organisationId: bundle.organisation.id,
    editionId: bundle.edition.id,
    entityType: "signage_item",
    entityId: bundle.item.id,
    fileName: `${fileName}.${ext}`,
  });
  await putObject("photos", path, Buffer.from(await file.arrayBuffer()));
  return { path };
}

async function opsUserIds(organisationId: string): Promise<string[]> {
  const rows = await db
    .select({ userId: memberships.userId })
    .from(memberships)
    .where(and(eq(memberships.organisationId, organisationId), eq(memberships.role, "ops")));
  return rows.map((r) => r.userId);
}

async function openSnagCount(tx: Tx, itemId: string): Promise<number> {
  const [{ n }] = await tx
    .select({ n: sql<number>`count(*)::int` })
    .from(snags)
    .where(and(eq(snags.signageItemId, itemId), inArray(snags.status, [...OPEN_STATUSES])));
  return Number(n);
}

/**
 * Raise a snag on an installed sign or panel: what's wrong, how bad, and a
 * photo if there is one. The item goes to Snagged until every snag is
 * resolved. Admin, ops and marketing.
 */
export async function raiseSnag(formData: FormData): Promise<ActionResult> {
  const parsed = raiseSchema.safeParse(formValues(formData));
  if (!parsed.success) return fail(parsed.error.issues[0]?.message ?? "Check the form");
  const session = await requireSession();
  if (!can(session.actor, { type: "snag.manage" })) return fail("You cannot raise snags");
  const bundle = await loadItemBundle(db, parsed.data.itemId, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Item not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  if (!SNAGGABLE_KINDS.includes(bundle.item.kind)) return fail("Snags are for signs and panels");
  if (!["installed", "snagged"].includes(bundle.item.status)) {
    return fail("Snags are raised once the item is installed — confirm Installed first");
  }
  const photo = await savePhoto(formData, bundle, "snag-photo").catch(() => ({
    error: "Could not save the photo — check your signal and try again",
  }));
  if ("error" in photo) return fail(photo.error);

  const { item, edition } = bundle;
  const next: SignageStatus | null =
    item.status === "installed" ? signageTransition("installed", "snag_opened") : null;
  await db.transaction(async (tx) => {
    const [snag] = await tx
      .insert(snags)
      .values({
        editionId: edition.id,
        signageItemId: item.id,
        description: parsed.data.description,
        severity: parsed.data.severity,
        photoPath: photo.path,
        assignedUserId: item.ownerUserId,
        assignedSupplierId: item.supplierId,
        assignedContractorId: item.installContractorId,
      })
      .returning();
    if (next) {
      await tx.update(signageItems).set({ status: next }).where(eq(signageItems.id, item.id));
    }
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: item.id,
      action: next ? "status_change" : "update",
      before: { status: item.status },
      after: {
        status: next ?? item.status,
        snagId: snag.id,
        severity: parsed.data.severity,
        description: parsed.data.description,
      },
      summary: `Snag raised on ${item.ref}: ${parsed.data.description}`,
    });
    const recipients = [...(await opsUserIds(session.organisation.id)), item.ownerUserId].filter(
      (id): id is string => Boolean(id) && id !== session.user.id,
    );
    await notify(tx, {
      userIds: recipients,
      kind: "snag",
      title: `Snag on ${item.ref} — ${item.name}`,
      body: parsed.data.description,
      link: itemPath(edition.code, { kind: item.kind as ItemKind, ref: item.ref }),
      entityType: "signage_item",
      entityId: item.id,
    });
  });
  revalidatePath("/", "layout");
  return success(undefined, next ? "Snag raised — item marked Snagged" : "Snag raised");
}

/**
 * Move a snag along: in progress, resolved (with a note and photo if wanted),
 * won't fix, or back to open. When the last open snag on a Snagged item is
 * cleared, the item returns to Installed.
 */
export async function updateSnag(formData: FormData): Promise<ActionResult> {
  const parsed = updateSchema.safeParse(formValues(formData));
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "snag.manage" })) return fail("You cannot update snags");
  const [snag] = await db.select().from(snags).where(eq(snags.id, parsed.data.snagId)).limit(1);
  if (!snag?.signageItemId) return fail("Snag not found");
  const bundle = await loadItemBundle(db, snag.signageItemId, {
    organisationId: session.organisation.id,
  });
  if (!bundle || bundle.item.deletedAt) return fail("Snag not found");
  if (editionIsReadOnly(bundle.edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  const closing = parsed.data.status === "resolved" || parsed.data.status === "wont_fix";
  const photo = closing
    ? await savePhoto(formData, bundle, "snag-fixed").catch(() => ({
        error: "Could not save the photo — check your signal and try again",
      }))
    : { path: null };
  if ("error" in photo) return fail(photo.error);

  const { item, edition } = bundle;
  let next: SignageStatus | null = null;
  await db.transaction(async (tx) => {
    await tx
      .update(snags)
      .set({
        status: parsed.data.status,
        resolutionNote: closing ? parsed.data.note || null : snag.resolutionNote,
        resolutionPhotoPath: closing ? (photo.path ?? snag.resolutionPhotoPath) : null,
        resolvedAt: closing ? new Date() : null,
        resolvedBy: closing ? session.user.id : null,
      })
      .where(eq(snags.id, snag.id));
    const stillOpen = await openSnagCount(tx, item.id);
    if (item.status === "snagged" && stillOpen === 0) {
      next = signageTransition("snagged", "snags_cleared");
    } else if (item.status === "installed" && stillOpen > 0) {
      // A resolved snag reopened on an installed item.
      next = signageTransition("installed", "snag_opened");
    }
    if (next) {
      await tx.update(signageItems).set({ status: next }).where(eq(signageItems.id, item.id));
    }
    const label = {
      open: "reopened",
      in_progress: "in progress",
      resolved: "resolved",
      wont_fix: "won't fix",
    }[parsed.data.status];
    await writeAudit(tx, {
      organisationId: session.organisation.id,
      editionId: edition.id,
      actorUserId: session.user.id,
      entityType: "signage_item",
      entityId: item.id,
      action: next ? "status_change" : "update",
      before: { status: item.status, snagStatus: snag.status },
      after: {
        status: next ?? item.status,
        snagId: snag.id,
        snagStatus: parsed.data.status,
        ...(parsed.data.note ? { note: parsed.data.note } : {}),
      },
      summary: `Snag on ${item.ref} ${label}: ${snag.description}${
        next === "installed" ? " — all snags cleared" : ""
      }`,
    });
    if (closing) {
      await notify(tx, {
        userIds: [item.ownerUserId].filter(
          (id): id is string => Boolean(id) && id !== session.user.id,
        ),
        kind: "snag",
        title: `Snag ${label} on ${item.ref} — ${item.name}`,
        body: parsed.data.note || snag.description,
        link: itemPath(edition.code, { kind: item.kind as ItemKind, ref: item.ref }),
        entityType: "signage_item",
        entityId: item.id,
      });
    }
  });
  revalidatePath("/", "layout");
  return success(
    undefined,
    next === "installed"
      ? "All snags cleared — item back to Installed"
      : next === "snagged"
        ? "Snag reopened — item marked Snagged"
        : "Snag updated",
  );
}
