/**
 * Sponsorship packages, written before the code: what's included, how a
 * sale changes a sponsor's entitlements, places, the sold line, revenue
 * (defined once, here) and what reaches people who can't see costs.
 */
import { describe, expect, it } from "vitest";
import {
  duplicateLine,
  formatIncludedLines,
  lineKey,
  packageAvailability,
  packageCards,
  packageCounts,
  packagePlacesRefusal,
  packageSoldLine,
  packagesLine,
  parseIncludedLines,
  placesLeft,
  planEntitlements,
  priceDiffers,
  saleMode,
  sellRefusal,
  sponsorshipRevenue,
  stillToSellNote,
  toRevenuePackages,
  type PackageRowInput,
  type PlanEntitlement,
  type RevenuePackage,
} from "@/lib/domain/sponsorship-packages";
import { currencySymbol, organisationCurrency } from "@/lib/format";

describe("parseIncludedLines", () => {
  it("reads “6 x Logo”, “6× Logo” and plain lines, skipping blanks", () => {
    expect(
      parseIncludedLines("6 x Logo on banners\n\n  6× Flags \nEntrance branding\n   "),
    ).toEqual([
      { quantity: 6, description: "Logo on banners" },
      { quantity: 6, description: "Flags" },
      { quantity: 1, description: "Entrance branding" },
    ]);
  });

  it("parses entitlements exactly as saveSponsor always has", () => {
    // The rules saveSponsor's parseEntitlements had: "N x" or "N×" in any
    // case, at least 1, anything else is one of the line as written.
    expect(parseIncludedLines("0 x Banners\n12X Lanyards\n3 lanyards\nx Logo")).toEqual([
      { quantity: 1, description: "Banners" },
      { quantity: 12, description: "Lanyards" },
      { quantity: 1, description: "3 lanyards" },
      { quantity: 1, description: "x Logo" },
    ]);
  });

  it("formats lines back for the editor, quantity 1 as just the words", () => {
    const text = formatIncludedLines([
      { quantity: 6, description: "Logo on hanging banners" },
      { quantity: 1, description: "Entrance feature branding" },
    ]);
    expect(text).toBe("6 x Logo on hanging banners\nEntrance feature branding");
    expect(parseIncludedLines(text)).toEqual([
      { quantity: 6, description: "Logo on hanging banners" },
      { quantity: 1, description: "Entrance feature branding" },
    ]);
  });
});

describe("lineKey and duplicateLine", () => {
  it("matches trimmed, spaces collapsed, any case", () => {
    expect(lineKey("  Logo   on\tBanners ")).toBe("logo on banners");
    expect(lineKey("LOGO ON BANNERS")).toBe(lineKey("logo on banners"));
  });

  it("names a line listed twice, ignoring case and spaces", () => {
    expect(
      duplicateLine([
        { quantity: 2, description: "Logo on banners" },
        { quantity: 1, description: "Entrance" },
        { quantity: 1, description: "logo  on BANNERS" },
      ]),
    ).toBe("logo  on BANNERS");
    expect(duplicateLine([{ quantity: 1, description: "One" }])).toBeNull();
    expect(duplicateLine([])).toBeNull();
  });
});

const ent = (over: Partial<PlanEntitlement> & { id: string }): PlanEntitlement => ({
  description: over.id,
  quantity: 1,
  fromPackageId: null,
  linkedItems: 0,
  ...over,
});

describe("planEntitlements", () => {
  const gold = [
    { description: "Banners", quantity: 2 },
    { description: "Logo in the event guide", quantity: 1 },
  ];

  it("a first sale adds every line", () => {
    const plan = planEntitlements([], { fromPackageId: null, toPackageId: "gold", toLines: gold });
    expect(plan).toEqual({ add: gold, remove: [], keep: [], alreadyThere: [] });
  });

  it("a line the sponsor already has (any case or spacing) is left as it is and not added again", () => {
    const own = ent({ id: "e1", description: "  banners ", quantity: 1 });
    const plan = planEntitlements([own], {
      fromPackageId: null,
      toPackageId: "gold",
      toLines: gold,
    });
    expect(plan.add).toEqual([{ description: "Logo in the event guide", quantity: 1 }]);
    expect(plan.alreadyThere).toEqual([{ line: gold[0], existing: own }]);
    expect(plan.remove).toEqual([]);
  });

  it("the same line twice in a package is added once", () => {
    const plan = planEntitlements([], {
      fromPackageId: null,
      toPackageId: "gold",
      toLines: [
        { description: "Banners", quantity: 2 },
        { description: "BANNERS", quantity: 3 },
      ],
    });
    expect(plan.add).toEqual([{ description: "Banners", quantity: 2 }]);
  });

  it("changing package removes the old package's lines nothing counts towards and keeps the rest", () => {
    const own = ent({ id: "own", description: "Own line" });
    const free = ent({ id: "free", description: "Seminar branding", fromPackageId: "seminar" });
    const used = ent({
      id: "used",
      description: "Seminar banners",
      fromPackageId: "seminar",
      linkedItems: 1,
    });
    const plan = planEntitlements([own, free, used], {
      fromPackageId: "seminar",
      toPackageId: "gold",
      toLines: gold,
    });
    expect(plan.remove).toEqual([free]);
    expect(plan.keep).toEqual([used]);
    expect(plan.add).toEqual(gold);
  });

  it("lines kept from the old package still stop the new one adding the same line", () => {
    const used = ent({
      id: "used",
      description: "banners",
      fromPackageId: "seminar",
      linkedItems: 2,
    });
    const free = ent({
      id: "free",
      description: "Logo in the event guide",
      fromPackageId: "seminar",
    });
    const plan = planEntitlements([used, free], {
      fromPackageId: "seminar",
      toPackageId: "gold",
      toLines: gold,
    });
    expect(plan.alreadyThere.map((a) => a.existing.id)).toEqual(["used"]);
    // The removed one doesn't count as already there: it is added again, tagged gold.
    expect(plan.add).toEqual([{ description: "Logo in the event guide", quantity: 1 }]);
    expect(plan.remove).toEqual([free]);
  });

  it("removing a package never touches lines the sponsor had before or lines from an earlier package", () => {
    const own = ent({ id: "own" });
    const earlier = ent({ id: "earlier", fromPackageId: "bronze" });
    const current = ent({ id: "current", fromPackageId: "gold" });
    const plan = planEntitlements([own, earlier, current], {
      fromPackageId: "gold",
      toPackageId: null,
      toLines: [],
    });
    expect(plan).toEqual({ add: [], remove: [current], keep: [], alreadyThere: [] });
  });

  it("editing the same package changes no entitlements", () => {
    const current = ent({ id: "current", fromPackageId: "gold" });
    expect(
      planEntitlements([current], { fromPackageId: "gold", toPackageId: "gold", toLines: gold }),
    ).toEqual({ add: [], remove: [], keep: [], alreadyThere: [] });
    expect(planEntitlements([], { fromPackageId: null, toPackageId: null, toLines: gold })).toEqual(
      { add: [], remove: [], keep: [], alreadyThere: [] },
    );
  });
});

describe("priceDiffers", () => {
  it("compares to the penny; no list price never differs", () => {
    expect(priceDiffers("25000.00", 25000)).toBe(false);
    expect(priceDiffers(25000, 25000.004)).toBe(false);
    expect(priceDiffers("25000.00", 22500)).toBe(true);
    expect(priceDiffers("10.00", 10.01)).toBe(true);
    expect(priceDiffers(null, 9000)).toBe(false);
    expect(priceDiffers("", 9000)).toBe(false);
  });
});

describe("places", () => {
  it("places left: null is no limit, never below 0", () => {
    expect(placesLeft(null, 4)).toBeNull();
    expect(placesLeft(3, 1)).toBe(2);
    expect(placesLeft(1, 3)).toBe(0);
  });

  it("can't offer fewer places than are sold; empty means no limit", () => {
    expect(packagePlacesRefusal(null, 5)).toBeNull();
    expect(packagePlacesRefusal(2, 2)).toBeNull();
    expect(packagePlacesRefusal(3, 2)).toBeNull();
    expect(packagePlacesRefusal(1, 2)).toBe(
      "2 are already sold — offer at least 2, or leave it empty for no limit",
    );
    expect(packagePlacesRefusal(0, 1)).toBe(
      "1 is already sold — offer at least 1, or leave it empty for no limit",
    );
  });

  it("saleMode: new, change or edit", () => {
    expect(saleMode(null, "gold")).toBe("new");
    expect(saleMode("seminar", "gold")).toBe("change");
    expect(saleMode("gold", "gold")).toBe("edit");
  });
});

describe("sellRefusal", () => {
  const base = {
    packageName: "Gold",
    archived: false,
    places: 2 as number | null,
    soldToOthers: 0,
    mode: "new" as const,
    listPrice: "10000.00" as string | number | null,
    agreedPrice: 10000,
    priceNote: null as string | null,
  };

  it("archived refuses a new sale or a change but not an edit", () => {
    const words = "Gold is archived — restore it to sell it";
    expect(sellRefusal({ ...base, archived: true })).toBe(words);
    expect(sellRefusal({ ...base, archived: true, mode: "change" })).toBe(words);
    expect(sellRefusal({ ...base, archived: true, mode: "edit" })).toBeNull();
  });

  it("sold out refuses a new sale and a change, not an edit; no limit never sells out", () => {
    const words = "Gold is sold out (2 of 2) — offer more places under Edit package first";
    expect(sellRefusal({ ...base, soldToOthers: 2 })).toBe(words);
    expect(sellRefusal({ ...base, soldToOthers: 2, mode: "change" })).toBe(words);
    expect(sellRefusal({ ...base, soldToOthers: 1 })).toBeNull();
    expect(sellRefusal({ ...base, soldToOthers: 2, mode: "edit" })).toBeNull();
    expect(sellRefusal({ ...base, places: null, soldToOthers: 500 })).toBeNull();
  });

  it("a different price needs a reason; the same price or no list price doesn't", () => {
    const words = "Say why the price is different (e.g. a discount)";
    expect(sellRefusal({ ...base, agreedPrice: 9000 })).toBe(words);
    expect(sellRefusal({ ...base, agreedPrice: 9000, priceNote: "   " })).toBe(words);
    expect(sellRefusal({ ...base, agreedPrice: 9000, mode: "edit" })).toBe(words);
    expect(sellRefusal({ ...base, agreedPrice: 9000, priceNote: "Early booking" })).toBeNull();
    expect(sellRefusal({ ...base, agreedPrice: 10000 })).toBeNull();
    expect(sellRefusal({ ...base, listPrice: null, agreedPrice: 9000 })).toBeNull();
  });
});

describe("packageSoldLine and packageAvailability", () => {
  it.each([
    [3, 1, "1 of 3 sold · 2 left", "left"],
    [3, 3, "Sold out", "sold_out"],
    [1, 2, "Sold out", "sold_out"],
    [3, 0, "Not sold yet · 3 places", "left"],
    [1, 0, "Not sold yet · 1 place", "left"],
    [null, 2, "2 sold · no limit", "unlimited"],
    [null, 0, "Not sold yet · no limit", "unlimited"],
  ] as const)("%s places, %s sold → %s", (places, sold, line, availability) => {
    expect(packageSoldLine(places, sold)).toBe(line);
    expect(packageAvailability(places, sold)).toBe(availability);
  });
});

const pkg = (over: Partial<RevenuePackage> = {}): RevenuePackage => ({
  price: "10000.00",
  places: 2,
  archived: false,
  sales: [],
  ...over,
});

describe("sponsorshipRevenue", () => {
  it("adds packages sold and items sold into total revenue", () => {
    const rev = sponsorshipRevenue(
      [
        pkg({ price: "25000", places: 1, sales: [{ agreedPrice: "22500.00" }] }),
        pkg({ price: "8000", places: 2, sales: [{ agreedPrice: "8000.00" }] }),
        pkg({ price: "12000", places: 3 }),
      ],
      { sold: 2, sales: 21500 },
    );
    expect(rev).toEqual({
      packages: { sold: 2, value: 30500, unpriced: 0 },
      items: { sold: 2, value: 21500 },
      total: 52000,
      remaining: { value: 44000, places: 4, unlimited: 0, unpriced: 0 },
    });
  });

  it("counts sales of archived packages but not their unsold places", () => {
    const rev = sponsorshipRevenue(
      [pkg({ archived: true, places: 5, sales: [{ agreedPrice: 4000 }] })],
      { sold: 0, sales: 0 },
    );
    expect(rev.packages).toEqual({ sold: 1, value: 4000, unpriced: 0 });
    expect(rev.remaining).toEqual({ value: 0, places: 0, unlimited: 0, unpriced: 0 });
    expect(rev.total).toBe(4000);
  });

  it("still to sell covers limited, priced places only, and counts what it leaves out", () => {
    const rev = sponsorshipRevenue(
      [
        pkg({ price: "1000", places: 3, sales: [{ agreedPrice: "1000" }] }),
        pkg({ price: "500", places: null }),
        pkg({ price: null, places: 2 }),
        // Sold out with no price: nothing left to sell, so nothing left out.
        pkg({ price: null, places: 1, sales: [{ agreedPrice: "300" }] }),
      ],
      { sold: 0, sales: 0 },
    );
    expect(rev.remaining).toEqual({ value: 2000, places: 2, unlimited: 1, unpriced: 1 });
    expect(stillToSellNote(rev)).toBe("Not counted: 1 package with no limit, 1 with no price yet.");
    expect(
      stillToSellNote({ ...rev, remaining: { ...rev.remaining, unlimited: 2, unpriced: 0 } }),
    ).toBe("Not counted: 2 packages with no limit.");
    expect(
      stillToSellNote({ ...rev, remaining: { ...rev.remaining, unlimited: 0, unpriced: 3 } }),
    ).toBe("Not counted: 3 packages with no price yet.");
    expect(
      stillToSellNote({ ...rev, remaining: { ...rev.remaining, unlimited: 0, unpriced: 0 } }),
    ).toBeNull();
  });

  it("a sale without an agreed price counts as sold, adds nothing and is counted as unpriced", () => {
    const rev = sponsorshipRevenue(
      [pkg({ price: null, places: null, sales: [{ agreedPrice: null }, { agreedPrice: "50" }] })],
      { sold: 1, sales: 100 },
    );
    expect(rev.packages).toEqual({ sold: 2, value: 50, unpriced: 1 });
    expect(rev.total).toBe(150);
  });

  it("is never negative when more are sold than offered", () => {
    const rev = sponsorshipRevenue(
      [
        pkg({
          price: "100",
          places: 1,
          sales: [{ agreedPrice: "100" }, { agreedPrice: "100" }, { agreedPrice: "100" }],
        }),
      ],
      { sold: 0, sales: 0 },
    );
    expect(rev.remaining.value).toBe(0);
    expect(rev.remaining.places).toBe(0);
  });
});

const row = (over: Partial<PackageRowInput> = {}): PackageRowInput => ({
  id: "gold",
  name: "Gold",
  description: "Top billing",
  price: "10000.00",
  places: 2,
  sortOrder: 1,
  isArchived: false,
  lines: [{ id: "l1", description: "Banners", quantity: 2 }],
  sales: [
    {
      sponsorId: "s1",
      companyName: "BuildCo",
      agreedPrice: "9000.00",
      priceNote: "Early booking",
      soldAt: new Date("2026-10-01T10:00:00Z"),
    },
  ],
  referenced: true,
  ...over,
});

describe("packageCards", () => {
  it("hides prices, agreed prices and reasons from people who can't see costs", () => {
    const [hidden] = packageCards([row()], { canSeeCosts: false });
    expect(hidden.price).toBeNull();
    expect(hidden.soldValue).toBeNull();
    expect(hidden.stillToSell).toBeNull();
    expect(hidden.sales).toEqual([
      {
        sponsorId: "s1",
        companyName: "BuildCo",
        agreedPrice: null,
        priceNote: null,
        soldAt: "2026-10-01T10:00:00.000Z",
      },
    ]);
    expect(JSON.stringify(hidden)).not.toMatch(/9000|10000|Early booking/);
    // Counts, names and lines stay.
    expect(hidden).toMatchObject({
      name: "Gold",
      sold: 1,
      left: 1,
      availability: "left",
      soldLine: "1 of 2 sold · 1 left",
      lines: [{ description: "Banners", quantity: 2 }],
    });
  });

  it("gives sellers the price, what was sold and what is still to sell", () => {
    const [card] = packageCards([row()], { canSeeCosts: true });
    expect(card).toMatchObject({
      price: "10000.00",
      soldValue: 9000,
      stillToSell: 10000,
      sales: [{ agreedPrice: "9000.00", priceNote: "Early booking" }],
    });
    const [unpriced] = packageCards([row({ price: null })], { canSeeCosts: true });
    expect(unpriced.stillToSell).toBeNull();
    const [archived] = packageCards([row({ isArchived: true })], { canSeeCosts: true });
    expect(archived.stillToSell).toBe(0);
  });

  it("feeds revenue from the same rows", () => {
    expect(toRevenuePackages([row()])).toEqual([
      { price: "10000.00", places: 2, archived: false, sales: [{ agreedPrice: "9000.00" }] },
    ]);
  });
});

describe("package counts for the dashboard", () => {
  it("counts live packages, every sale and the limited places left", () => {
    const counts = packageCounts([
      pkg({ places: 1, sales: [{ agreedPrice: "1" }] }),
      pkg({ places: 2, sales: [{ agreedPrice: "1" }] }),
      pkg({ places: 3 }),
      pkg({ archived: true, places: 9, sales: [{ agreedPrice: "1" }] }),
    ]);
    expect(counts).toEqual({ count: 3, sold: 3, placesLeft: 4, unlimited: 0 });
    expect(packagesLine(counts)).toBe("3 packages sold · 4 places left");
    expect(packagesLine({ count: 1, sold: 1, placesLeft: 1, unlimited: 0 })).toBe(
      "1 package sold · 1 place left",
    );
    expect(packagesLine({ count: 2, sold: 0, placesLeft: 0, unlimited: 2 })).toBe(
      "0 packages sold · 2 with no limit",
    );
    expect(packagesLine({ count: 1, sold: 1, placesLeft: 0, unlimited: 0 })).toBe(
      "1 package sold · no places left",
    );
  });
});

describe("organisationCurrency and currencySymbol", () => {
  it("GBP unless the organisation has EUR or USD; empty settings are GBP", () => {
    expect(organisationCurrency({ currency: "EUR" })).toBe("EUR");
    expect(organisationCurrency({ currency: "USD" })).toBe("USD");
    expect(organisationCurrency({ currency: "JPY" })).toBe("GBP");
    expect(organisationCurrency({})).toBe("GBP");
    expect(organisationCurrency(null)).toBe("GBP");
    expect(organisationCurrency(undefined)).toBe("GBP");
    expect(currencySymbol("GBP")).toBe("£");
    expect(currencySymbol("EUR")).toBe("€");
    expect(currencySymbol("USD")).toBe("US$");
  });
});
