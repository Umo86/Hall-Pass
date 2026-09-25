"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { signageItems, sponsors } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { buildStoragePath, putObject } from "@/lib/storage";
import { fail, success, type ActionResult } from "@/lib/actions/result";

type Bundle = NonNullable<Awaited<ReturnType<typeof loadItemBundle>>>;

/** The item, if this person may sell it or change its photo. */
async function editableItem(
  session: Session,
  itemId: string,
): Promise<{ bundle: Bundle; error?: never } | { error: string; bundle?: never }> {
  const bundle = await loadItemBundle(db, itemId);
  if (!bundle || bundle.item.deletedAt) return { error: "Item not found" };
  if (bundle.organisation.id !== session.organisation.id) return { error: "Item not found" };
  if (editionIsReadOnly(bundle.edition.status)) return { error: EDITION_LOCKED_MESSAGE };
  if (!can(session.actor, { type: "signage.edit", item: itemAuthzCtx(bundle) })) {
    return { error: "You cannot change this item" };
  }
  return { bundle };
}

function refresh(bundle: Bundle) {
  revalidatePath(`/${bundle.edition.code}`, "layout");
}

const soldSchema = z
  .object({
    itemId: z.string().uuid(),
    sponsorId: z.string().uuid().optional().nullable(),
    /** A sponsor who isn't on the list yet. */
    newSponsorName: z
      .string()
      .trim()
      .max(200)
      .optional()
      .nullable()
      .transform((v) => v || null),
    salePrice: z.coerce
      .number({ message: "Enter the sale price" })
      .nonnegative("Enter the sale price"),
  })
  .refine((d) => d.sponsorId || d.newSponsorName, {
    message: "Choose the sponsor who bought it",
  });

/** Mark an item sold: who bought it and for how much. */
export async function markSold(input: unknown): Promise<ActionResult> {
  const parsed = soldSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("Only Sales, Operations and admins record sales");
  }
  const found = await editableItem(session, parsed.data.itemId);
  if (found.error !== undefined) return fail(found.error);
  const { bundle } = found;
  const data = parsed.data;

  try {
    const sponsorName = await db.transaction(async (tx) => {
      let sponsorId = data.sponsorId ?? null;
      let name = data.newSponsorName;
      if (sponsorId) {
        const [sp] = await tx
          .select()
          .from(sponsors)
          .where(and(eq(sponsors.id, sponsorId), eq(sponsors.editionId, bundle.edition.id)));
        if (!sp) throw new Error("That sponsor isn't on this show — reload the page");
        name = sp.companyName;
      } else {
        const [sp] = await tx
          .insert(sponsors)
          .values({ editionId: bundle.edition.id, companyName: name! })
          .returning();
        sponsorId = sp.id;
        await writeAudit(tx, {
          organisationId: bundle.organisation.id,
          editionId: bundle.edition.id,
          actorUserId: session.user.id,
          entityType: "sponsor",
          entityId: sp.id,
          action: "create",
          after: { companyName: name },
          summary: `Added sponsor ${name}`,
        });
      }
      const before = {
        sponsorId: bundle.item.sponsorId,
        salePrice: bundle.item.salePrice,
      };
      const after = {
        sponsorId,
        salePrice: data.salePrice.toFixed(2),
        soldAt: new Date(),
        isSponsorDeliverable: true,
      };
      await tx.update(signageItems).set(after).where(eq(signageItems.id, bundle.item.id));
      await writeAudit(tx, {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: bundle.item.id,
        action: "update",
        before,
        after: { sponsorId, salePrice: after.salePrice },
        summary: `Sold ${bundle.item.ref} to ${name} for £${data.salePrice.toFixed(2)}`,
      });
      return name;
    });
    refresh(bundle);
    return success(undefined, `Sold to ${sponsorName}`);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("markSold", err);
    return fail("Could not save — please try again");
  }
}

/** Undo a sale (e.g. the sponsor pulled out): back to available. */
export async function markUnsold(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ itemId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "sponsorship.create" })) {
    return fail("Only Sales, Operations and admins record sales");
  }
  const found = await editableItem(session, parsed.data.itemId);
  if (found.error !== undefined) return fail(found.error);
  const { bundle } = found;
  if (bundle.item.kind !== "sponsorship_item") {
    return fail("Sponsor signage always has a sponsor — change it on the item instead");
  }
  try {
    await db.transaction(async (tx) => {
      await tx
        .update(signageItems)
        .set({ sponsorId: null, sponsorEntitlementId: null, salePrice: null, soldAt: null })
        .where(eq(signageItems.id, bundle.item.id));
      await writeAudit(tx, {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: bundle.item.id,
        action: "update",
        before: { sponsorId: bundle.item.sponsorId, salePrice: bundle.item.salePrice },
        after: { sponsorId: null, salePrice: null },
        summary: `${bundle.item.ref} is available again (sale undone)`,
      });
    });
    refresh(bundle);
    return success(undefined, "Marked as available");
  } catch (err) {
    unstable_rethrow(err);
    console.error("markUnsold", err);
    return fail("Could not save — please try again");
  }
}

const PHOTO_TYPES = [
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
];

/** A product photo for the item's card: resized to 1000px WebP. */
export async function uploadItemPhoto(formData: FormData): Promise<ActionResult> {
  const itemId = formData.get("itemId");
  const file = formData.get("file");
  if (typeof itemId !== "string" || !z.string().uuid().safeParse(itemId).success) {
    return fail("Invalid request");
  }
  if (!(file instanceof File) || file.size === 0) return fail("Choose a photo first");
  if (file.size > 10 * 1024 * 1024) return fail("Photos are limited to 10 MB");
  if (!PHOTO_TYPES.includes(file.type)) return fail("Use a JPG, PNG, WebP or HEIC photo");
  const session = await requireSession();
  const found = await editableItem(session, itemId);
  if (found.error !== undefined) return fail(found.error);
  const { bundle } = found;
  try {
    const { default: sharp } = await import("sharp");
    const webp = await sharp(Buffer.from(await file.arrayBuffer()))
      .rotate()
      .resize({ width: 1000, height: 1000, fit: "inside", withoutEnlargement: true })
      .webp({ quality: 85 })
      .toBuffer();
    const path = buildStoragePath({
      organisationId: bundle.organisation.id,
      editionId: bundle.edition.id,
      entityType: "signage_item",
      entityId: bundle.item.id,
      fileName: "photo.webp",
    });
    await putObject("photos", path, webp);
    await db.transaction(async (tx) => {
      await tx.update(signageItems).set({ photoPath: path }).where(eq(signageItems.id, itemId));
      await writeAudit(tx, {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: itemId,
        action: "upload",
        after: { photoPath: path },
        summary: `Photo ${bundle.item.photoPath ? "replaced" : "added"} for ${bundle.item.ref}`,
      });
    });
    refresh(bundle);
    return success(undefined, "Photo saved");
  } catch (err) {
    unstable_rethrow(err);
    console.error("uploadItemPhoto", err);
    return fail("Could not read that photo — try a JPG or PNG");
  }
}

export async function removeItemPhoto(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ itemId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const found = await editableItem(session, parsed.data.itemId);
  if (found.error !== undefined) return fail(found.error);
  const { bundle } = found;
  try {
    await db.transaction(async (tx) => {
      await tx
        .update(signageItems)
        .set({ photoPath: null })
        .where(eq(signageItems.id, bundle.item.id));
      await writeAudit(tx, {
        organisationId: bundle.organisation.id,
        editionId: bundle.edition.id,
        actorUserId: session.user.id,
        entityType: "signage_item",
        entityId: bundle.item.id,
        action: "update",
        before: { photoPath: bundle.item.photoPath },
        after: { photoPath: null },
        summary: `Photo removed from ${bundle.item.ref}`,
      });
    });
    refresh(bundle);
    return success(undefined, "Photo removed");
  } catch (err) {
    unstable_rethrow(err);
    console.error("removeItemPhoto", err);
    return fail("Could not save — please try again");
  }
}
