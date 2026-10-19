"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { db } from "@/lib/db/client";
import { can, missingAbilityMessage } from "@/lib/authz";
import { requireSession, type Session } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { EDITION_LOCKED_MESSAGE, editionIsReadOnly } from "@/lib/edition-lock";
import { ownEdition } from "@/lib/domain/signage";
import {
  duplicateLine,
  parseIncludedLines,
  type SaleMode,
} from "@/lib/domain/sponsorship-packages";
import { organisationCurrency, plural } from "@/lib/format";
import { ownPackage, ownSponsor } from "@/lib/sponsorship/own";
import {
  deletePackageTx,
  movePackageTx,
  nameTakenMessage,
  PackageRefusal,
  removeSponsorPackageTx,
  savePackageTx,
  sellPackageTx,
  setPackageArchivedTx,
  type Who,
} from "@/lib/sponsorship/packages";

/**
 * Sponsorship packages: a priced catalogue per event, and selling a package
 * to a sponsor at an agreed price. Managing and selling both need
 * sponsorship.sell for the event (which needs costs.view); every record is
 * loaded through the event-scoped loaders, so an event the person can't
 * open is "not found". The database work and audit rows are in
 * lib/sponsorship/packages.ts.
 */

const optText = z
  .string()
  .trim()
  .max(300)
  .optional()
  .nullable()
  .transform((v) => (v ? v : null));

const money = z.preprocess(
  (v) => (v === "" || v == null ? null : v),
  z.coerce
    .number({ message: "Enter an amount" })
    .nonnegative("Enter an amount")
    .max(9_999_999_999, "That's too large")
    .nullable(),
);

const requiredMoney = z.preprocess(
  (v) => (v === "" || v == null ? undefined : v),
  z.coerce
    .number({ message: "Enter the agreed price" })
    .nonnegative("Enter the agreed price")
    .max(9_999_999_999, "That's too large"),
);

const packageSchema = z.object({
  editionId: z.string().uuid(),
  id: z.string().uuid().optional(),
  name: z
    .string()
    .trim()
    .min(1, "Give the package a name")
    .max(120, "Keep the name to 120 characters"),
  price: money,
  places: z.preprocess(
    (v) => (v === "" || v == null ? null : v),
    z.coerce
      .number({ message: "Enter a whole number" })
      .int("Enter a whole number")
      .min(1, "At least 1, or leave it empty for no limit")
      .max(10_000, "Keep it to 10,000 or fewer")
      .nullable(),
  ),
  description: optText,
  lines: z.string().max(5000, "Keep what's included shorter").optional().default(""),
  // A real boolean from the client (z.coerce.boolean() would read "false" as true).
  applyPriceToUnpriced: z.boolean().optional().default(false),
});

const sellSchema = z
  .object({
    packageId: z.string().uuid(),
    sponsorId: z.string().uuid().optional().nullable(),
    newSponsorName: z
      .string()
      .trim()
      .max(200)
      .optional()
      .nullable()
      .transform((v) => v || null),
    agreedPrice: requiredMoney,
    priceNote: z
      .string()
      .trim()
      .max(200, "Keep the reason to 200 characters")
      .optional()
      .nullable()
      .transform((v) => v || null),
  })
  .refine((d) => d.sponsorId || d.newSponsorName, {
    message: "Choose the sponsor who bought it",
  });

const packageIdSchema = z.object({ packageId: z.string().uuid() });

function whoFor(session: Session): Who {
  return {
    organisationId: session.organisation.id,
    actorUserId: session.user.id,
    currency: organisationCurrency(session.organisation.settings),
  };
}

/** Refusals are shown as they are; anything else is logged and kept from the browser. */
function failure(where: string, err: unknown): ActionResult<never> {
  unstable_rethrow(err);
  if (err instanceof PackageRefusal) return fail(err.message);
  console.error(where, err);
  return fail("Could not save — please try again");
}

const isUniqueViolation = (err: unknown) =>
  typeof err === "object" &&
  err !== null &&
  ((err as { code?: string }).code === "23505" ||
    (err as { cause?: { code?: string } }).cause?.code === "23505");

/** The edition behind a package input, if this person may change its packages now. */
async function packageFor(session: Session, packageId: string) {
  const found = await ownPackage(db, session.organisation.id, packageId, session.actor);
  if (!found) return { error: "Package not found" } as const;
  if (!can(session.actor, { type: "sponsorship.sell", editionId: found.edition.id })) {
    return { error: missingAbilityMessage("sponsorship.sell") } as const;
  }
  if (editionIsReadOnly(found.edition.status)) return { error: EDITION_LOCKED_MESSAGE } as const;
  return found;
}

/** Add a package, or change one (its sales keep what they were sold). */
export async function savePackage(input: unknown): Promise<ActionResult<{ id: string }>> {
  const parsed = packageSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const data = parsed.data;
  const lines = parseIncludedLines(data.lines);
  const twice = duplicateLine(lines);
  if (twice) return fail(`“${twice}” is listed twice`);
  if (lines.length > 100) return fail("Keep it to 100 lines");
  const session = await requireSession();
  const edition = await ownEdition(db, session.organisation.id, data.editionId, session.actor);
  if (!edition) return fail("Event not found");
  if (!can(session.actor, { type: "sponsorship.sell", editionId: edition.id })) {
    return fail(missingAbilityMessage("sponsorship.sell"));
  }
  if (editionIsReadOnly(edition.status)) return fail(EDITION_LOCKED_MESSAGE);
  try {
    const saved = await db.transaction((tx) =>
      savePackageTx(tx, whoFor(session), edition, {
        id: data.id,
        name: data.name,
        price: data.price,
        places: data.places,
        description: data.description,
        lines,
        applyPriceToUnpriced: data.applyPriceToUnpriced,
      }),
    );
    revalidatePath(`/${edition.code}`, "layout");
    const priced =
      saved.pricedSales.length === 0
        ? ""
        : saved.pricedSales.length === 1
          ? ` — price set for ${saved.pricedSales[0]} too`
          : ` — price set for ${plural(saved.pricedSales.length, "sponsor")} too`;
    return success({ id: saved.id }, `${data.name} ${saved.created ? "added" : "saved"}${priced}`);
  } catch (err) {
    if (isUniqueViolation(err)) return fail(nameTakenMessage(data.name));
    return failure("savePackage", err);
  }
}

/** Archive a package (no longer offered; its sales stay) or restore it. */
export async function setPackageArchived(input: unknown): Promise<ActionResult> {
  const parsed = packageIdSchema.extend({ archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const found = await packageFor(session, parsed.data.packageId);
  if ("error" in found) return fail(found.error);
  try {
    const res = await db.transaction((tx) =>
      setPackageArchivedTx(
        tx,
        whoFor(session),
        found.edition.id,
        found.package.id,
        parsed.data.archived,
      ),
    );
    revalidatePath(`/${found.edition.code}`, "layout");
    return success(undefined, `${parsed.data.archived ? "Archived" : "Restored"} ${res.name}`);
  } catch (err) {
    return failure("setPackageArchived", err);
  }
}

/** Delete a package nothing points at; one ever sold is archived instead. */
export async function deletePackage(input: unknown): Promise<ActionResult> {
  const parsed = packageIdSchema.safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const found = await packageFor(session, parsed.data.packageId);
  if ("error" in found) return fail(found.error);
  try {
    const res = await db.transaction((tx) =>
      deletePackageTx(tx, whoFor(session), found.edition.id, found.package.id),
    );
    revalidatePath(`/${found.edition.code}`, "layout");
    return success(undefined, `Removed ${res.name}`);
  } catch (err) {
    return failure("deletePackage", err);
  }
}

/** Move a live package up or down the list. */
export async function movePackage(input: unknown): Promise<ActionResult> {
  const parsed = packageIdSchema.extend({ direction: z.enum(["up", "down"]) }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const found = await packageFor(session, parsed.data.packageId);
  if ("error" in found) return fail(found.error);
  try {
    const res = await db.transaction((tx) =>
      movePackageTx(tx, whoFor(session), found.edition.id, found.package.id, parsed.data.direction),
    );
    if (res.moved) revalidatePath(`/${found.edition.code}`, "layout");
    return success(undefined, res.moved ? `Moved ${res.name} ${parsed.data.direction}` : undefined);
  } catch (err) {
    return failure("movePackage", err);
  }
}

export type SellPackageResult = {
  mode: SaleMode;
  added: number;
  alreadyThere: number;
  removed: number;
  kept: number;
};

/** Sell a package to a sponsor (or a new one), change it, or change its agreed price. */
export async function sellPackage(input: unknown): Promise<ActionResult<SellPackageResult>> {
  const parsed = sellSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const data = parsed.data;
  const session = await requireSession();
  const found = await packageFor(session, data.packageId);
  if ("error" in found) return fail(found.error);
  try {
    const res = await db.transaction((tx) =>
      sellPackageTx(tx, whoFor(session), {
        editionId: found.edition.id,
        packageId: found.package.id,
        sponsorId: data.sponsorId ?? null,
        newSponsorName: data.sponsorId ? null : data.newSponsorName,
        agreedPrice: data.agreedPrice,
        priceNote: data.priceNote,
      }),
    );
    revalidatePath(`/${found.edition.code}`, "layout");
    const message =
      res.mode === "edit"
        ? `${res.companyName}'s ${res.packageName} saved`
        : res.mode === "change"
          ? `${res.companyName} now has ${res.packageName} (was ${res.previousPackageName})`
          : `${res.companyName} bought ${res.packageName}`;
    const { mode, added, alreadyThere, removed, kept } = res;
    return success({ mode, added, alreadyThere, removed, kept }, message);
  } catch (err) {
    return failure("sellPackage", err);
  }
}

/** Take a sponsor's package away (lines items count towards stay). */
export async function removeSponsorPackage(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ sponsorId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  const found = await ownSponsor(parsed.data.sponsorId, session.organisation.id, session.actor);
  if (found.error !== undefined) return fail(found.error);
  const { sponsor, edition } = found;
  if (!can(session.actor, { type: "sponsorship.sell", editionId: edition.id })) {
    return fail(missingAbilityMessage("sponsorship.sell"));
  }
  try {
    const res = await db.transaction((tx) =>
      removeSponsorPackageTx(tx, whoFor(session), sponsor.id, edition.id),
    );
    revalidatePath(`/${edition.code}`, "layout");
    return success(
      undefined,
      `Removed ${res.packageName} from ${res.companyName}${
        res.kept > 0 ? ` — kept ${plural(res.kept, "line")} items count towards` : ""
      }`,
    );
  } catch (err) {
    return failure("removeSponsorPackage", err);
  }
}
