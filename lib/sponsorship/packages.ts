// No "server-only" marker: the seed script creates and sells the demo
// packages with these same helpers, so the two never drift apart.
/**
 * Sponsorship packages: the database work behind app/actions/sponsorship-packages.ts.
 * Each helper runs inside the caller's transaction after authorisation,
 * writes its own audit rows there, and refuses with a PackageRefusal whose
 * message is shown as it is. Lock order everywhere: the package row, then
 * the sponsor row — so two people selling the last place can't both win.
 */
import { and, asc, count, eq, inArray, max, ne, sql } from "drizzle-orm";
import type { Tx } from "@/lib/db/client";
import {
  sponsorEntitlements,
  sponsors,
  sponsorshipPackageLines,
  sponsorshipPackages,
} from "@/lib/db/schema";
import { writeAudit } from "@/lib/audit";
import { formatMoney, plural } from "@/lib/format";
import {
  packagePlacesRefusal,
  planEntitlements,
  priceDiffers,
  saleMode,
  sellRefusal,
  type IncludedLine,
  type SaleMode,
} from "@/lib/domain/sponsorship-packages";
import { sponsorEntitlementRows } from "@/lib/queries/sponsorship-packages";

/** A refusal whose message is shown to the person as it is. */
export class PackageRefusal extends Error {}

/** Who is making the change (actorUserId null in the seed) and the money they see. */
export type Who = { organisationId: string; actorUserId: string | null; currency: string };

/** The seed writes as the system; everyone else as themselves. */
const actorTypeOf = (who: Who) => (who.actorUserId ? ("user" as const) : ("system" as const));

type SponsorRecord = typeof sponsors.$inferSelect;

const money = (v: string | number | null | undefined, currency: string) =>
  v == null || v === "" ? "no price" : formatMoney(v, currency);

const lineWords = (l: IncludedLine) => (l.quantity > 1 ? `${l.quantity} × ` : "") + l.description;

async function lockPackage(tx: Tx, editionId: string, packageId: string) {
  const [pkg] = await tx
    .select()
    .from(sponsorshipPackages)
    .where(and(eq(sponsorshipPackages.id, packageId), eq(sponsorshipPackages.editionId, editionId)))
    .for("update");
  if (!pkg) throw new PackageRefusal("That package isn't on this event — reload the page");
  return pkg;
}

async function lockSponsor(tx: Tx, editionId: string, sponsorId: string) {
  const [sp] = await tx
    .select()
    .from(sponsors)
    .where(and(eq(sponsors.id, sponsorId), eq(sponsors.editionId, editionId)))
    .for("update");
  if (!sp) throw new PackageRefusal("That sponsor isn't on this event — reload the page");
  return sp;
}

async function packageLines(tx: Tx, packageId: string): Promise<IncludedLine[]> {
  const rows = await tx
    .select({
      description: sponsorshipPackageLines.description,
      quantity: sponsorshipPackageLines.quantity,
    })
    .from(sponsorshipPackageLines)
    .where(eq(sponsorshipPackageLines.packageId, packageId))
    .orderBy(asc(sponsorshipPackageLines.sortOrder), asc(sponsorshipPackageLines.createdAt));
  return rows;
}

async function soldCount(tx: Tx, packageId: string, except?: string): Promise<number> {
  const [{ n }] = await tx
    .select({ n: count() })
    .from(sponsors)
    .where(
      except
        ? and(eq(sponsors.packageId, packageId), ne(sponsors.id, except))
        : eq(sponsors.packageId, packageId),
    );
  return Number(n);
}

/** The words for a name already in use in the event (any case), or null. */
async function nameClash(
  tx: Tx,
  editionId: string,
  name: string,
  exceptId?: string,
): Promise<string | null> {
  const [clash] = await tx
    .select({ name: sponsorshipPackages.name, isArchived: sponsorshipPackages.isArchived })
    .from(sponsorshipPackages)
    .where(
      and(
        eq(sponsorshipPackages.editionId, editionId),
        sql`lower(${sponsorshipPackages.name}) = lower(${name})`,
        exceptId ? ne(sponsorshipPackages.id, exceptId) : undefined,
      ),
    )
    .limit(1);
  if (!clash) return null;
  return clash.isArchived
    ? `There's an archived package called ${clash.name} — restore it instead`
    : `There's already a package called ${clash.name} in this event`;
}

/** The words for a unique-name violation that slipped past nameClash (two saves at once). */
export function nameTakenMessage(name: string): string {
  return `There's already a package called ${name} in this event`;
}

export type PackageInput = {
  id?: string;
  name: string;
  /** List price; null = "No price yet". */
  price: number | null;
  /** How many can be sold; null = no limit. */
  places: number | null;
  description: string | null;
  lines: IncludedLine[];
  /** Fill the agreed price of sponsors sold it before it had a price. */
  applyPriceToUnpriced: boolean;
};

/**
 * Add or change a package. A rename keeps its sponsors' package_name in
 * step; what's included is replaced (sponsors who bought it keep what they
 * were sold); places can't go below what's sold.
 */
export async function savePackageTx(
  tx: Tx,
  who: Who,
  edition: { id: string; code: string },
  input: PackageInput,
): Promise<{ id: string; created: boolean; pricedSales: string[] }> {
  const before = input.id ? await lockPackage(tx, edition.id, input.id) : null;
  const clash = await nameClash(tx, edition.id, input.name, input.id);
  if (clash) throw new PackageRefusal(clash);
  const price = input.price == null ? null : input.price.toFixed(2);
  const values = {
    name: input.name,
    description: input.description,
    price,
    places: input.places,
  };
  let id: string;
  let oldLines: IncludedLine[] = [];
  if (before) {
    const sold = await soldCount(tx, before.id);
    const refusal = packagePlacesRefusal(input.places, sold);
    if (refusal) throw new PackageRefusal(refusal);
    oldLines = await packageLines(tx, before.id);
    await tx.update(sponsorshipPackages).set(values).where(eq(sponsorshipPackages.id, before.id));
    if (before.name !== input.name) {
      await tx
        .update(sponsors)
        .set({ packageName: input.name })
        .where(eq(sponsors.packageId, before.id));
    }
    id = before.id;
  } else {
    const [{ top }] = await tx
      .select({ top: max(sponsorshipPackages.sortOrder) })
      .from(sponsorshipPackages)
      .where(eq(sponsorshipPackages.editionId, edition.id));
    const [created] = await tx
      .insert(sponsorshipPackages)
      .values({ ...values, editionId: edition.id, sortOrder: (top ?? 0) + 1 })
      .returning({ id: sponsorshipPackages.id });
    id = created.id;
  }
  // Nothing points at a line: replacing them all is safe.
  await tx.delete(sponsorshipPackageLines).where(eq(sponsorshipPackageLines.packageId, id));
  if (input.lines.length > 0) {
    await tx.insert(sponsorshipPackageLines).values(
      input.lines.map((l, i) => ({
        packageId: id,
        description: l.description,
        quantity: l.quantity,
        sortOrder: i + 1,
      })),
    );
  }

  const lines = input.lines.map((l) => ({ description: l.description, quantity: l.quantity }));
  if (!before) {
    await writeAudit(tx, {
      organisationId: who.organisationId,
      editionId: edition.id,
      actorUserId: who.actorUserId,
      actorType: actorTypeOf(who),
      entityType: "sponsorship_package",
      entityId: id,
      action: "create",
      after: { ...values, lines },
      summary:
        price == null
          ? `Added package ${input.name} (no price yet)`
          : `Added package ${input.name} at ${formatMoney(price, who.currency)}`,
    });
  } else {
    const changedBefore: Record<string, unknown> = {};
    const changedAfter: Record<string, unknown> = {};
    const parts: string[] = [];
    if (before.name !== input.name) {
      changedBefore.name = before.name;
      changedAfter.name = input.name;
      parts.push(`renamed from ${before.name}`);
    }
    if ((before.price ?? null) !== price) {
      changedBefore.price = before.price;
      changedAfter.price = price;
      parts.push(`price ${money(before.price, who.currency)} → ${money(price, who.currency)}`);
    }
    if ((before.places ?? null) !== input.places) {
      changedBefore.places = before.places;
      changedAfter.places = input.places;
      const words = (p: number | null) => (p == null ? "no limit" : plural(p, "place"));
      parts.push(`${words(before.places)} → ${words(input.places)}`);
    }
    if ((before.description ?? null) !== input.description) {
      changedBefore.description = before.description;
      changedAfter.description = input.description;
      parts.push("description");
    }
    if (JSON.stringify(oldLines) !== JSON.stringify(lines)) {
      changedBefore.lines = oldLines;
      changedAfter.lines = lines;
      parts.push("what's included");
    }
    await writeAudit(tx, {
      organisationId: who.organisationId,
      editionId: edition.id,
      actorUserId: who.actorUserId,
      actorType: actorTypeOf(who),
      entityType: "sponsorship_package",
      entityId: id,
      action: "update",
      before: changedBefore,
      after: changedAfter,
      summary: `Changed package ${input.name}: ${parts.join("; ") || "nothing"}`,
    });
  }

  // Sold before it had a price: fill their agreed price when asked.
  const pricedSales: string[] = [];
  if (before && input.applyPriceToUnpriced && price != null) {
    const filled = await tx
      .update(sponsors)
      .set({ packagePrice: price })
      .where(and(eq(sponsors.packageId, id), sql`${sponsors.packagePrice} IS NULL`))
      .returning({ id: sponsors.id, companyName: sponsors.companyName });
    for (const sp of filled) {
      pricedSales.push(sp.companyName);
      await writeAudit(tx, {
        organisationId: who.organisationId,
        editionId: edition.id,
        actorUserId: who.actorUserId,
        actorType: actorTypeOf(who),
        entityType: "sponsor",
        entityId: sp.id,
        action: "update",
        before: { packagePrice: null },
        after: { packageId: id, packagePrice: price },
        summary: `${sp.companyName}'s ${input.name} price set to ${formatMoney(price, who.currency)} (the package price)`,
      });
    }
  }
  return { id, created: !before, pricedSales };
}

export type SellArgs = {
  editionId: string;
  packageId: string;
  sponsorId: string | null;
  newSponsorName: string | null;
  agreedPrice: number;
  priceNote: string | null;
  /** When it was sold; now unless the seed says otherwise. */
  soldAt?: Date;
};

export type SellResult = {
  sponsorId: string;
  companyName: string;
  packageName: string;
  previousPackageName: string | null;
  mode: SaleMode;
  added: number;
  alreadyThere: number;
  removed: number;
  kept: number;
};

/**
 * Sell a package to a sponsor (or a new one), change the package they
 * have, or change the agreed price of the one they have. What's included
 * is copied into their entitlements, tagged with the package, without
 * duplicating lines they already have.
 */
export async function sellPackageTx(tx: Tx, who: Who, args: SellArgs): Promise<SellResult> {
  const pkg = await lockPackage(tx, args.editionId, args.packageId);
  let sponsor: SponsorRecord;
  if (args.sponsorId) {
    sponsor = await lockSponsor(tx, args.editionId, args.sponsorId);
  } else {
    const name = (args.newSponsorName ?? "").trim();
    if (!name) throw new PackageRefusal("Choose the sponsor who bought it");
    const [same] = await tx
      .select({ companyName: sponsors.companyName })
      .from(sponsors)
      .where(
        and(
          eq(sponsors.editionId, args.editionId),
          sql`lower(btrim(${sponsors.companyName})) = lower(${name})`,
        ),
      )
      .limit(1);
    if (same) {
      throw new PackageRefusal(
        `${same.companyName} is already a sponsor — choose them from the list`,
      );
    }
    [sponsor] = await tx
      .insert(sponsors)
      .values({ editionId: args.editionId, companyName: name })
      .returning();
    await writeAudit(tx, {
      organisationId: who.organisationId,
      editionId: args.editionId,
      actorUserId: who.actorUserId,
      actorType: actorTypeOf(who),
      entityType: "sponsor",
      entityId: sponsor.id,
      action: "create",
      after: { companyName: name },
      summary: `Added sponsor ${name}`,
    });
  }

  const mode = saleMode(sponsor.packageId, pkg.id);
  const soldToOthers = await soldCount(tx, pkg.id, sponsor.id);
  const refusal = sellRefusal({
    packageName: pkg.name,
    archived: pkg.isArchived,
    places: pkg.places,
    soldToOthers,
    mode,
    listPrice: pkg.price,
    agreedPrice: args.agreedPrice,
    priceNote: args.priceNote,
  });
  if (refusal) throw new PackageRefusal(refusal);

  const agreed = args.agreedPrice.toFixed(2);
  const differs = priceDiffers(pkg.price, args.agreedPrice);
  const note = differs ? (args.priceNote?.trim() ?? null) : null;
  const base = {
    sponsorId: sponsor.id,
    companyName: sponsor.companyName,
    packageName: pkg.name,
  };
  const audit = {
    organisationId: who.organisationId,
    editionId: args.editionId,
    actorUserId: who.actorUserId,
    actorType: actorTypeOf(who),
    entityType: "sponsor",
    entityId: sponsor.id,
    action: "update" as const,
  };

  if (mode === "edit") {
    await tx
      .update(sponsors)
      .set({ packagePrice: agreed, packagePriceNote: note })
      .where(eq(sponsors.id, sponsor.id));
    await writeAudit(tx, {
      ...audit,
      before: { packagePrice: sponsor.packagePrice, packagePriceNote: sponsor.packagePriceNote },
      after: { packagePrice: agreed, packagePriceNote: note },
      summary: `${sponsor.companyName}'s ${pkg.name}: price ${money(sponsor.packagePrice, who.currency)} → ${formatMoney(agreed, who.currency)}${note ? ` (${note})` : ""}`,
    });
    return {
      ...base,
      previousPackageName: pkg.name,
      mode,
      added: 0,
      alreadyThere: 0,
      removed: 0,
      kept: 0,
    };
  }

  const previous = sponsor.packageId
    ? ((
        await tx
          .select({ name: sponsorshipPackages.name })
          .from(sponsorshipPackages)
          .where(eq(sponsorshipPackages.id, sponsor.packageId))
      )[0]?.name ?? null)
    : null;
  const [existing, toLines] = await Promise.all([
    sponsorEntitlementRows(tx, [sponsor.id]),
    packageLines(tx, pkg.id),
  ]);
  const plan = planEntitlements(existing, {
    fromPackageId: sponsor.packageId,
    toPackageId: pkg.id,
    toLines,
  });
  if (plan.remove.length > 0) {
    await tx.delete(sponsorEntitlements).where(
      and(
        eq(sponsorEntitlements.sponsorId, sponsor.id),
        inArray(
          sponsorEntitlements.id,
          plan.remove.map((e) => e.id),
        ),
      ),
    );
  }
  if (plan.add.length > 0) {
    // A millisecond apart, so they list in the package's order.
    const at = Date.now();
    await tx.insert(sponsorEntitlements).values(
      plan.add.map((l, i) => ({
        sponsorId: sponsor.id,
        description: l.description,
        quantity: l.quantity,
        fromPackageId: pkg.id,
        createdAt: new Date(at + i),
        updatedAt: new Date(at + i),
      })),
    );
  }
  const soldAt = args.soldAt ?? new Date();
  await tx
    .update(sponsors)
    .set({
      packageId: pkg.id,
      packagePrice: agreed,
      packagePriceNote: note,
      packageSoldAt: soldAt,
      packageName: pkg.name,
    })
    .where(eq(sponsors.id, sponsor.id));
  const entitlements = {
    added: plan.add.map(lineWords),
    alreadyThere: plan.alreadyThere.map((a) => lineWords(a.line)),
    removed: plan.remove.map(lineWords),
    kept: plan.keep.map(lineWords),
  };
  const listed =
    note && pkg.price != null ? ` (list ${formatMoney(pkg.price, who.currency)}: ${note})` : "";
  await writeAudit(tx, {
    ...audit,
    before: {
      packageId: sponsor.packageId,
      packageName: previous,
      packagePrice: sponsor.packagePrice,
      packagePriceNote: sponsor.packagePriceNote,
      packageSoldAt: sponsor.packageSoldAt,
    },
    after: {
      packageId: pkg.id,
      packageName: pkg.name,
      packagePrice: agreed,
      packagePriceNote: note,
      packageSoldAt: soldAt,
      entitlements,
    },
    summary:
      mode === "new"
        ? `${sponsor.companyName} bought ${pkg.name} for ${formatMoney(agreed, who.currency)}${listed}`
        : `${sponsor.companyName} moved from ${previous ?? "another package"} to ${pkg.name} for ${formatMoney(agreed, who.currency)}${listed}`,
  });
  return {
    ...base,
    previousPackageName: previous,
    mode,
    added: plan.add.length,
    alreadyThere: plan.alreadyThere.length,
    removed: plan.remove.length,
    kept: plan.keep.length,
  };
}

/**
 * Take a sponsor's package away: its lines nothing counts towards go,
 * lines items count towards stay (still tagged), and the agreed price,
 * reason, sold date and package_name are cleared.
 */
export async function removeSponsorPackageTx(
  tx: Tx,
  who: Who,
  sponsorId: string,
  editionId: string,
): Promise<{ companyName: string; packageName: string; removed: number; kept: number }> {
  const sponsor = await lockSponsor(tx, editionId, sponsorId);
  if (!sponsor.packageId) throw new PackageRefusal(`${sponsor.companyName} has no package`);
  const [pkg] = await tx
    .select({ name: sponsorshipPackages.name })
    .from(sponsorshipPackages)
    .where(eq(sponsorshipPackages.id, sponsor.packageId));
  const packageName = pkg?.name ?? sponsor.packageName ?? "their package";
  const existing = await sponsorEntitlementRows(tx, [sponsor.id]);
  const plan = planEntitlements(existing, {
    fromPackageId: sponsor.packageId,
    toPackageId: null,
    toLines: [],
  });
  if (plan.remove.length > 0) {
    await tx.delete(sponsorEntitlements).where(
      and(
        eq(sponsorEntitlements.sponsorId, sponsor.id),
        inArray(
          sponsorEntitlements.id,
          plan.remove.map((e) => e.id),
        ),
      ),
    );
  }
  await tx
    .update(sponsors)
    .set({
      packageId: null,
      packagePrice: null,
      packagePriceNote: null,
      packageSoldAt: null,
      packageName: null,
    })
    .where(eq(sponsors.id, sponsor.id));
  const parts = [`removed ${plural(plan.remove.length, "line")}`];
  if (plan.keep.length > 0)
    parts.push(`kept ${plural(plan.keep.length, "line")} items count towards`);
  await writeAudit(tx, {
    organisationId: who.organisationId,
    editionId,
    actorUserId: who.actorUserId,
    actorType: actorTypeOf(who),
    entityType: "sponsor",
    entityId: sponsor.id,
    action: "update",
    before: {
      packageId: sponsor.packageId,
      packageName,
      packagePrice: sponsor.packagePrice,
      packagePriceNote: sponsor.packagePriceNote,
      packageSoldAt: sponsor.packageSoldAt,
      entitlements: existing
        .filter((e) => e.fromPackageId === sponsor.packageId)
        .map((e) => lineWords(e)),
    },
    after: {
      packageId: null,
      removed: plan.remove.map(lineWords),
      kept: plan.keep.map(lineWords),
    },
    summary: `${sponsor.companyName} no longer has ${packageName} (${parts.join("; ")})`,
  });
  return {
    companyName: sponsor.companyName,
    packageName,
    removed: plan.remove.length,
    kept: plan.keep.length,
  };
}

/** Archive (no longer offered; its sales stay) or restore a package. */
export async function setPackageArchivedTx(
  tx: Tx,
  who: Who,
  editionId: string,
  packageId: string,
  archived: boolean,
): Promise<{ name: string; changed: boolean }> {
  const pkg = await lockPackage(tx, editionId, packageId);
  if (pkg.isArchived === archived) return { name: pkg.name, changed: false };
  await tx
    .update(sponsorshipPackages)
    .set({ isArchived: archived })
    .where(eq(sponsorshipPackages.id, pkg.id));
  await writeAudit(tx, {
    organisationId: who.organisationId,
    editionId,
    actorUserId: who.actorUserId,
    actorType: actorTypeOf(who),
    entityType: "sponsorship_package",
    entityId: pkg.id,
    action: "update",
    before: { isArchived: pkg.isArchived },
    after: { isArchived: archived },
    summary: `${archived ? "Archived" : "Restored"} package ${pkg.name}`,
  });
  return { name: pkg.name, changed: true };
}

/** Delete a package nothing points at (never sold, no entitlement from it). */
export async function deletePackageTx(
  tx: Tx,
  who: Who,
  editionId: string,
  packageId: string,
): Promise<{ name: string }> {
  const pkg = await lockPackage(tx, editionId, packageId);
  const sold = await soldCount(tx, pkg.id);
  if (sold > 0) {
    throw new PackageRefusal(
      `${plural(sold, "sponsor")} ${sold === 1 ? "has" : "have"} it — archive it instead`,
    );
  }
  const [{ n }] = await tx
    .select({ n: count() })
    .from(sponsorEntitlements)
    .where(eq(sponsorEntitlements.fromPackageId, pkg.id));
  if (Number(n) > 0) throw new PackageRefusal("Entitlements came from it — archive it instead");
  const lines = await packageLines(tx, pkg.id);
  await tx.delete(sponsorshipPackages).where(eq(sponsorshipPackages.id, pkg.id));
  await writeAudit(tx, {
    organisationId: who.organisationId,
    editionId,
    actorUserId: who.actorUserId,
    actorType: actorTypeOf(who),
    entityType: "sponsorship_package",
    entityId: pkg.id,
    action: "update",
    before: {
      name: pkg.name,
      description: pkg.description,
      price: pkg.price,
      places: pkg.places,
      sortOrder: pkg.sortOrder,
      isArchived: pkg.isArchived,
      lines,
    },
    after: { removed: true },
    summary: `Removed package ${pkg.name}`,
  });
  return { name: pkg.name };
}

/**
 * Move a live package up or down one place, renumbering the event's live
 * packages 1..n. At either end nothing changes (and nothing is audited).
 */
export async function movePackageTx(
  tx: Tx,
  who: Who,
  editionId: string,
  packageId: string,
  direction: "up" | "down",
): Promise<{ name: string; moved: boolean }> {
  // Every live package of the event, locked in one order.
  await tx
    .select({ id: sponsorshipPackages.id })
    .from(sponsorshipPackages)
    .where(
      and(eq(sponsorshipPackages.editionId, editionId), eq(sponsorshipPackages.isArchived, false)),
    )
    .orderBy(asc(sponsorshipPackages.id))
    .for("update");
  const live = await tx
    .select({
      id: sponsorshipPackages.id,
      name: sponsorshipPackages.name,
      sortOrder: sponsorshipPackages.sortOrder,
    })
    .from(sponsorshipPackages)
    .where(
      and(eq(sponsorshipPackages.editionId, editionId), eq(sponsorshipPackages.isArchived, false)),
    )
    .orderBy(asc(sponsorshipPackages.sortOrder), asc(sql`lower(${sponsorshipPackages.name})`));
  const at = live.findIndex((p) => p.id === packageId);
  if (at < 0) throw new PackageRefusal("That package isn't on this event — reload the page");
  const name = live[at].name;
  const to = direction === "up" ? at - 1 : at + 1;
  if (to < 0 || to >= live.length) return { name, moved: false };
  const order = [...live];
  [order[at], order[to]] = [order[to], order[at]];
  for (const [i, p] of order.entries()) {
    if (p.sortOrder !== i + 1) {
      await tx
        .update(sponsorshipPackages)
        .set({ sortOrder: i + 1 })
        .where(eq(sponsorshipPackages.id, p.id));
    }
  }
  await writeAudit(tx, {
    organisationId: who.organisationId,
    editionId,
    actorUserId: who.actorUserId,
    actorType: actorTypeOf(who),
    entityType: "sponsorship_package",
    entityId: packageId,
    action: "update",
    before: { sortOrder: live[at].sortOrder },
    after: { sortOrder: to + 1 },
    summary: `Moved package ${name} ${direction}`,
  });
  return { name, moved: true };
}
