/**
 * Sponsorship packages (pure; unit tested in tests/unit/sponsorship-packages.test.ts).
 *
 * A package is what sponsors can buy at one event: a price, what's included
 * and how many can be sold. Selling one copies what's included into the
 * sponsor's entitlements, tagged with the package, at an agreed price. These
 * functions decide how a sale changes a sponsor's entitlements, when a sale
 * is refused, the sold line on a card, and revenue — defined once here, so
 * the page, the dashboard and the sponsor report agree. No schema import:
 * client components use it too (the sell dialog's preview).
 */
import { plural } from "@/lib/format";

export type IncludedLine = { description: string; quantity: number };

/**
 * "6 x Logo" / "6× Logo" / "Logo" per line → lines (blank lines skipped,
 * quantity at least 1). The rules sponsors' entitlements always used.
 */
export function parseIncludedLines(text: string): IncludedLine[] {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const m = line.match(/^(\d+)\s*[x×]\s*(.+)$/i);
      return m
        ? { quantity: Math.max(1, Number(m[1])), description: m[2].trim() }
        : { quantity: 1, description: line };
    });
}

/** The editor's textarea: "6 x Logo on banners" (quantity 1 → just the words). */
export function formatIncludedLines(lines: readonly IncludedLine[]): string {
  return lines
    .map((l) => (l.quantity > 1 ? `${l.quantity} x ${l.description}` : l.description))
    .join("\n");
}

/** Trimmed, spaces collapsed, lower case: how duplicate lines are matched. */
export function lineKey(description: string): string {
  return description.trim().replace(/\s+/g, " ").toLowerCase();
}

/** The description listed a second time in one package, or null. */
export function duplicateLine(lines: readonly IncludedLine[]): string | null {
  const seen = new Set<string>();
  for (const l of lines) {
    const k = lineKey(l.description);
    if (seen.has(k)) return l.description;
    seen.add(k);
  }
  return null;
}

const pence = (v: string | number) => Math.round(Number(v) * 100);

/** Agreed price ≠ list price, to the penny; never when there is no list price. */
export function priceDiffers(listPrice: string | number | null, agreed: number): boolean {
  if (listPrice == null || listPrice === "") return false;
  return pence(listPrice) !== pence(agreed);
}

/** Places left: null = no limit; never below 0. */
export function placesLeft(places: number | null, sold: number): number | null {
  return places == null ? null : Math.max(0, places - sold);
}

/** Why a package can't offer that many places, or null (empty = no limit). */
export function packagePlacesRefusal(places: number | null, sold: number): string | null {
  if (places == null || places >= sold) return null;
  return `${sold} ${sold === 1 ? "is" : "are"} already sold — offer at least ${sold}, or leave it empty for no limit`;
}

/** A first package, a different one, or the price of the one they have. */
export type SaleMode = "new" | "change" | "edit";

export function saleMode(currentPackageId: string | null, packageId: string): SaleMode {
  if (currentPackageId === null) return "new";
  return currentPackageId === packageId ? "edit" : "change";
}

/** Why this sale can't go ahead, or null (checked again on the server under the row lock). */
export function sellRefusal(input: {
  packageName: string;
  archived: boolean;
  places: number | null;
  /** Sponsors other than this one who have the package. */
  soldToOthers: number;
  mode: SaleMode;
  listPrice: string | number | null;
  agreedPrice: number;
  priceNote: string | null;
}): string | null {
  const { packageName: name, places } = input;
  if (input.archived && input.mode !== "edit") return `${name} is archived — restore it to sell it`;
  if (input.mode !== "edit" && places != null && input.soldToOthers >= places) {
    return `${name} is sold out (${places} of ${places}) — offer more places under Edit package first`;
  }
  if (priceDiffers(input.listPrice, input.agreedPrice) && !input.priceNote?.trim()) {
    return "Say why the price is different (e.g. a discount)";
  }
  return null;
}

export type PlanEntitlement = {
  id: string;
  description: string;
  quantity: number;
  /** The package whose sale added it; null = added by hand. */
  fromPackageId: string | null;
  /** Items pointing at it, deleted ones included (they hold the foreign key). */
  linkedItems: number;
};

export type EntitlementPlan<E extends PlanEntitlement = PlanEntitlement> = {
  /** New lines, tagged with the new package. */
  add: IncludedLine[];
  /** The current package's lines nothing counts towards. */
  remove: E[];
  /** The current package's lines items count towards: they stay, still tagged. */
  keep: E[];
  /** New lines they already have (any case or spacing): left as they are. */
  alreadyThere: { line: IncludedLine; existing: E }[];
};

/**
 * What a package change does to a sponsor's entitlements. Lines from the
 * current package that nothing counts towards go; lines items count
 * towards stay; lines they had before (or from an earlier package) are
 * never touched; a new line they already have isn't added twice. The same
 * package → nothing.
 */
export function planEntitlements<E extends PlanEntitlement>(
  existing: readonly E[],
  change: {
    fromPackageId: string | null;
    toPackageId: string | null;
    toLines: readonly IncludedLine[];
  },
): EntitlementPlan<E> {
  const plan: EntitlementPlan<E> = { add: [], remove: [], keep: [], alreadyThere: [] };
  if (change.fromPackageId === change.toPackageId) return plan;
  if (change.fromPackageId !== null) {
    for (const e of existing) {
      if (e.fromPackageId !== change.fromPackageId) continue;
      (e.linkedItems > 0 ? plan.keep : plan.remove).push(e);
    }
  }
  const removed = new Set(plan.remove.map((e) => e.id));
  const known = new Map<string, E>();
  for (const e of existing) {
    if (!removed.has(e.id) && !known.has(lineKey(e.description))) {
      known.set(lineKey(e.description), e);
    }
  }
  if (change.toPackageId === null) return plan;
  const adding = new Set<string>();
  for (const line of change.toLines) {
    const k = lineKey(line.description);
    const there = known.get(k);
    if (there) plan.alreadyThere.push({ line, existing: there });
    else if (!adding.has(k)) {
      adding.add(k);
      plan.add.push(line);
    }
  }
  return plan;
}

export type PackageAvailability = "sold_out" | "left" | "unlimited";

export function packageAvailability(places: number | null, sold: number): PackageAvailability {
  if (places == null) return "unlimited";
  return sold >= places ? "sold_out" : "left";
}

/** "1 of 3 sold · 2 left", "Sold out", "Not sold yet · 3 places", "2 sold · no limit", "Not sold yet · no limit". */
export function packageSoldLine(places: number | null, sold: number): string {
  if (places == null) return sold === 0 ? "Not sold yet · no limit" : `${sold} sold · no limit`;
  if (sold >= places) return "Sold out";
  if (sold === 0) return `Not sold yet · ${plural(places, "place")}`;
  return `${sold} of ${places} sold · ${places - sold} left`;
}

/** The chip on a package card. */
export function availabilityLabel(places: number | null, sold: number): string {
  const a = packageAvailability(places, sold);
  if (a === "unlimited") return "No limit";
  if (a === "sold_out") return "Sold out";
  return `${placesLeft(places, sold)} left`;
}

// ---------------------------------------------------------------- revenue

export type RevenuePackage = {
  price: string | number | null;
  places: number | null;
  archived: boolean;
  sales: { agreedPrice: string | number | null }[];
};

export type SponsorshipRevenue = {
  /** Every sale, archived packages' too; value from agreed prices. */
  packages: { sold: number; value: number; unpriced: number };
  /** Sponsorship items sold (sponsorshipTotals' sold and sales). */
  items: { sold: number; value: number };
  total: number;
  /** Places left × price over live packages with a limit and a price, and what that leaves out. */
  remaining: { value: number; places: number; unlimited: number; unpriced: number };
};

const amount = (v: string | number | null) => (v == null || v === "" ? 0 : Number(v));

/**
 * Sponsorship revenue: packages sold (agreed prices) plus items sold (sale
 * prices) — the same figures on the Sponsorship page, the dashboard and the
 * sponsor report. Still to sell counts only what it can price.
 */
export function sponsorshipRevenue(
  packages: readonly RevenuePackage[],
  items: { sold: number; sales: number },
): SponsorshipRevenue {
  const out: SponsorshipRevenue = {
    packages: { sold: 0, value: 0, unpriced: 0 },
    items: { sold: items.sold, value: items.sales },
    total: 0,
    remaining: { value: 0, places: 0, unlimited: 0, unpriced: 0 },
  };
  for (const p of packages) {
    for (const s of p.sales) {
      out.packages.sold++;
      if (s.agreedPrice == null || s.agreedPrice === "") out.packages.unpriced++;
      else out.packages.value += Number(s.agreedPrice);
    }
    if (p.archived) continue;
    const left = placesLeft(p.places, p.sales.length);
    if (left === null) out.remaining.unlimited++;
    else if (p.price == null || p.price === "") {
      if (left > 0) out.remaining.unpriced++;
    } else {
      out.remaining.value += left * amount(p.price);
      out.remaining.places += left;
    }
  }
  out.total = out.packages.value + out.items.value;
  return out;
}

/** "Not counted: 1 package with no limit, 1 with no price yet." — or null. */
export function stillToSellNote(revenue: SponsorshipRevenue): string | null {
  const { unlimited, unpriced } = revenue.remaining;
  if (!unlimited && !unpriced) return null;
  const parts: string[] = [];
  if (unlimited) parts.push(`${plural(unlimited, "package")} with no limit`);
  if (unpriced) {
    parts.push(
      unlimited
        ? `${unpriced} with no price yet`
        : `${plural(unpriced, "package")} with no price yet`,
    );
  }
  return `Not counted: ${parts.join(", ")}.`;
}

/** Counts for the dashboard and people who can't see costs. */
export type PackageCounts = {
  /** Live (not archived) packages. */
  count: number;
  /** Every sale, archived packages' too. */
  sold: number;
  /** Places left over live packages with a limit. */
  placesLeft: number;
  /** Live packages with no limit. */
  unlimited: number;
};

export function packageCounts(packages: readonly RevenuePackage[]): PackageCounts {
  const out: PackageCounts = { count: 0, sold: 0, placesLeft: 0, unlimited: 0 };
  for (const p of packages) {
    out.sold += p.sales.length;
    if (p.archived) continue;
    out.count++;
    const left = placesLeft(p.places, p.sales.length);
    if (left === null) out.unlimited++;
    else out.placesLeft += left;
  }
  return out;
}

/** "2 packages sold · 4 places left" (the dashboard's link). */
export function packagesLine(c: PackageCounts): string {
  const parts = [`${plural(c.sold, "package")} sold`];
  if (c.placesLeft > 0) parts.push(`${plural(c.placesLeft, "place")} left`);
  if (c.unlimited > 0) parts.push(`${c.unlimited} with no limit`);
  if (c.placesLeft === 0 && c.unlimited === 0) parts.push("no places left");
  return parts.join(" · ");
}

// ---------------------------------------------------------------- cards

/** A package as the server loads it (lib/queries/sponsorship-packages.ts: listPackages). */
export type PackageRowInput = {
  id: string;
  name: string;
  description: string | null;
  price: string | null;
  places: number | null;
  sortOrder: number;
  isArchived: boolean;
  lines: { id: string; description: string; quantity: number }[];
  sales: {
    sponsorId: string;
    companyName: string;
    agreedPrice: string | null;
    priceNote: string | null;
    soldAt: Date | string | null;
  }[];
  /** A sponsor has it or an entitlement came from it: it can't be deleted. */
  referenced: boolean;
};

/** What reaches the browser. Money fields are null for people who can't see costs. */
export type PackageCard = {
  id: string;
  name: string;
  description: string | null;
  price: string | null;
  places: number | null;
  isArchived: boolean;
  lines: { id: string; description: string; quantity: number }[];
  sales: {
    sponsorId: string;
    companyName: string;
    agreedPrice: string | null;
    priceNote: string | null;
    soldAt: string | null;
  }[];
  sold: number;
  left: number | null;
  availability: PackageAvailability;
  soldLine: string;
  referenced: boolean;
  /** Σ agreed prices; null without costs. */
  soldValue: number | null;
  /** Places left × price (0 when archived); null without costs, a price or a limit. */
  stillToSell: number | null;
};

/** Package cards for the page; prices, agreed prices and reasons only with costs. */
export function packageCards(
  rows: readonly PackageRowInput[],
  opts: { canSeeCosts: boolean },
): PackageCard[] {
  const money = opts.canSeeCosts;
  return rows.map((r) => {
    const sold = r.sales.length;
    const left = placesLeft(r.places, sold);
    return {
      id: r.id,
      name: r.name,
      description: r.description,
      price: money ? r.price : null,
      places: r.places,
      isArchived: r.isArchived,
      lines: r.lines.map((l) => ({ id: l.id, description: l.description, quantity: l.quantity })),
      sales: r.sales.map((s) => ({
        sponsorId: s.sponsorId,
        companyName: s.companyName,
        agreedPrice: money ? s.agreedPrice : null,
        priceNote: money ? s.priceNote : null,
        soldAt: s.soldAt == null ? null : new Date(s.soldAt).toISOString(),
      })),
      sold,
      left,
      availability: packageAvailability(r.places, sold),
      soldLine: packageSoldLine(r.places, sold),
      referenced: r.referenced,
      soldValue: money ? r.sales.reduce((n, s) => n + amount(s.agreedPrice), 0) : null,
      stillToSell: !money
        ? null
        : r.isArchived
          ? 0
          : left === null || r.price == null || r.price === ""
            ? null
            : left * Number(r.price),
    };
  });
}

/** sponsorshipRevenue's input from loaded packages. */
export function toRevenuePackages(rows: readonly PackageRowInput[]): RevenuePackage[] {
  return rows.map((r) => ({
    price: r.price,
    places: r.places,
    archived: r.isArchived,
    sales: r.sales.map((s) => ({ agreedPrice: s.agreedPrice })),
  }));
}

/** A package as the sell dialog offers it (sellers always see prices). */
export type SellPackage = {
  id: string;
  name: string;
  price: string | null;
  places: number | null;
  /** Sponsors who have it. */
  sold: number;
  isArchived: boolean;
  lines: IncludedLine[];
};

/** The sell dialog's view of a package card. */
export function toSellPackage(p: PackageCard): SellPackage {
  return {
    id: p.id,
    name: p.name,
    price: p.price,
    places: p.places,
    sold: p.sold,
    isArchived: p.isArchived,
    lines: p.lines.map((l) => ({ description: l.description, quantity: l.quantity })),
  };
}
