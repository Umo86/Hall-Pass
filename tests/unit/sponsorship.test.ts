import { describe, expect, it } from "vitest";
import {
  groupSponsorshipRows,
  isOverdueToOrder,
  isUnderAMonth,
  matchesSponsorshipFilter,
  matchesSponsorshipSearch,
  parseGroupBy,
  parseSponsorshipFilter,
  saleState,
  sponsorshipNextLine,
  sponsorshipNextStep,
  sponsorshipProgress,
  sponsorshipStage,
  sponsorshipTotals,
  type SponsorshipNextInput,
  type SponsorshipStage,
} from "@/lib/domain/sponsorship";
import type { NextStep } from "@/lib/domain/signage";

const item = (over: Partial<Parameters<typeof sponsorshipStage>[0]> = {}) => ({
  kind: "sponsorship_item",
  sponsorId: "sp",
  hasArtwork: false,
  status: "draft",
  previousStatus: null,
  ...over,
});

describe("sponsorshipStage", () => {
  it.each<[Partial<Parameters<typeof sponsorshipStage>[0]>, SponsorshipStage]>([
    [{ sponsorId: null }, "for_sale"],
    [{ sponsorId: null, status: "in_review", hasArtwork: true }, "for_sale"],
    [{}, "sold_needs_artwork"],
    [{ status: "awaiting_artwork" }, "sold_needs_artwork"],
    [{ hasArtwork: true }, "artwork_in_signoff"],
    [{ status: "in_review", hasArtwork: true }, "artwork_in_signoff"],
    [{ status: "changes_requested", hasArtwork: true }, "artwork_in_signoff"],
    [{ status: "rejected", hasArtwork: true }, "artwork_in_signoff"],
    [{ status: "approved", hasArtwork: true }, "ready_to_order"],
    [{ status: "approved_with_conditions", hasArtwork: true }, "ready_to_order"],
    [{ status: "in_production", hasArtwork: true }, "ordered"],
    [{ status: "delivered", hasArtwork: true }, "delivered"],
    [{ status: "installed", hasArtwork: true }, "delivered"],
    [{ status: "snagged", hasArtwork: true }, "delivered"],
    [{ status: "closed", hasArtwork: true }, "delivered"],
  ])("%o → %s", (over, stage) => {
    expect(sponsorshipStage(item(over))).toBe(stage);
  });

  it("reads an item on hold as the stage it was held at", () => {
    expect(sponsorshipStage(item({ status: "on_hold", previousStatus: "approved" }))).toBe(
      "ready_to_order",
    );
    expect(sponsorshipStage(item({ status: "on_hold", previousStatus: null }))).toBe(
      "sold_needs_artwork",
    );
  });

  it("sponsor signage always has a sponsor, so it is never for sale", () => {
    expect(sponsorshipStage(item({ kind: "signage", sponsorId: "sp" }))).toBe("sold_needs_artwork");
  });
});

describe("saleState and the totals", () => {
  it("sponsor signage without a price is in the sponsor's package, not a £0 sale", () => {
    expect(saleState({ kind: "signage", sponsorId: "sp", salePrice: null })).toBe("in_package");
    expect(saleState({ kind: "signage", sponsorId: "sp", salePrice: "500.00" })).toBe("sold");
    expect(saleState({ kind: "sponsorship_item", sponsorId: "sp", salePrice: null })).toBe("sold");
    expect(saleState({ kind: "sponsorship_item", sponsorId: null, salePrice: null })).toBe(
      "available",
    );
  });

  it("counts package signage on its own and sums only real sales", () => {
    const t = sponsorshipTotals([
      { kind: "sponsorship_item", sponsorId: null, salePrice: null, costEstimate: "100" },
      { kind: "sponsorship_item", sponsorId: "a", salePrice: "9000.00", costEstimate: "4500" },
      { kind: "sponsorship_item", sponsorId: "a", salePrice: null, costEstimate: "50" },
      { kind: "signage", sponsorId: "a", salePrice: null, costEstimate: "2400" },
      { kind: "signage", sponsorId: "b", salePrice: null, costEstimate: null },
    ]);
    expect(t).toEqual({ available: 1, sold: 2, inPackage: 2, sales: 9000, profit: 4500 });
  });
});

describe("filters, search and grouping", () => {
  const today = "2026-10-16";
  const row = (stage: SponsorshipStage, orderByDate: string | null, sale = "available") => ({
    stage,
    orderByDate,
    sale: sale as "available" | "sold" | "in_package",
  });

  it("overdue to order: past the date and not ordered yet, sold or not", () => {
    expect(isOverdueToOrder(row("for_sale", "2026-10-13"), today)).toBe(true);
    expect(isOverdueToOrder(row("ready_to_order", "2026-10-13", "sold"), today)).toBe(true);
    expect(isOverdueToOrder(row("ordered", "2026-10-13", "sold"), today)).toBe(false);
    expect(isOverdueToOrder(row("for_sale", today), today)).toBe(false);
    expect(isOverdueToOrder(row("for_sale", null), today)).toBe(false);
  });

  it("under a month: today up to (not including) a calendar month away", () => {
    expect(isUnderAMonth(row("for_sale", today), today)).toBe(true);
    expect(isUnderAMonth(row("sold_needs_artwork", "2026-11-15", "sold"), today)).toBe(true);
    expect(isUnderAMonth(row("for_sale", "2026-11-16"), today)).toBe(false);
    expect(isUnderAMonth(row("for_sale", "2026-10-15"), today)).toBe(false); // overdue instead
    expect(isUnderAMonth(row("delivered", "2026-10-20", "sold"), today)).toBe(false);
  });

  it("matches each chip, with urgent as overdue or under a month", () => {
    const overdue = row("for_sale", "2026-10-01");
    const soon = row("artwork_in_signoff", "2026-10-30", "sold");
    const later = row("for_sale", "2027-01-01");
    const pkg = row("sold_needs_artwork", null, "in_package");
    const pick = (f: Parameters<typeof matchesSponsorshipFilter>[0]) =>
      [overdue, soon, later, pkg].filter((r) => matchesSponsorshipFilter(f, r, today));
    expect(pick("all")).toHaveLength(4);
    expect(pick("available")).toEqual([overdue, later]);
    expect(pick("sold")).toEqual([soon]);
    expect(pick("in_package")).toEqual([pkg]);
    expect(pick("overdue")).toEqual([overdue]);
    expect(pick("soon")).toEqual([soon]);
    expect(pick("urgent")).toEqual([overdue, soon]);
  });

  it("parses the URL values, falling back to all / no grouping", () => {
    expect(parseSponsorshipFilter("urgent")).toBe("urgent");
    expect(parseSponsorshipFilter("soon")).toBe("soon");
    expect(parseSponsorshipFilter("nonsense")).toBe("all");
    expect(parseSponsorshipFilter(null)).toBe("all");
    expect(parseGroupBy("sponsor")).toBe("sponsor");
    expect(parseGroupBy("colour")).toBeNull();
  });

  it("search needs every word somewhere in ref, name, sponsor, type or supplier", () => {
    const r = {
      ref: "SIG-BIRM27-031",
      name: "Branded lanyards",
      sponsorName: "BuildCo",
      typeName: "Lanyards",
      supplierName: "Big Print Co",
    };
    expect(matchesSponsorshipSearch("", r)).toBe(true);
    expect(matchesSponsorshipSearch("lanyard", r)).toBe(true);
    expect(matchesSponsorshipSearch("031 buildco", r)).toBe(true);
    expect(matchesSponsorshipSearch("big print", r)).toBe(true);
    expect(matchesSponsorshipSearch("lanyards toolmart", r)).toBe(false);
  });

  it("groups by stage in stage order, and by sponsor with unsold last", () => {
    const rows = [
      {
        id: 1,
        stage: "ordered" as const,
        kind: "sponsorship_item",
        typeName: "Bags",
        sponsorName: "Zed",
      },
      {
        id: 2,
        stage: "for_sale" as const,
        kind: "sponsorship_item",
        typeName: null,
        sponsorName: null,
      },
      {
        id: 3,
        stage: "ordered" as const,
        kind: "signage",
        typeName: "Banner",
        sponsorName: "Acme",
      },
    ];
    expect(
      groupSponsorshipRows(rows, "stage").map((g) => [g.label, g.rows.map((r) => r.id)]),
    ).toEqual([
      ["For sale", [2]],
      ["Ordered", [1, 3]],
    ]);
    expect(groupSponsorshipRows(rows, "sponsor").map((g) => g.label)).toEqual([
      "Acme",
      "Zed",
      "Not sold yet",
    ]);
    expect(groupSponsorshipRows(rows, "type").map((g) => g.label)).toEqual([
      "Bags",
      "Sponsor signage",
      "No type",
    ]);
  });
});

describe("sponsorshipNextLine", () => {
  const base: {
    status: string;
    orderByDate: string | null;
    today: string;
    sponsorName: string | null;
    supplierName: string | null;
    waitingOn: string[];
  } = {
    status: "draft",
    orderByDate: "2026-10-20",
    today: "2026-10-16",
    sponsorName: "BuildCo",
    supplierName: "Big Print Co",
    waitingOn: [],
  };
  it.each<[SponsorshipStage, Partial<typeof base>, string]>([
    ["for_sale", {}, "Next: sell by 20 Oct"],
    ["for_sale", { orderByDate: "2026-10-13" }, "Next: sell it, or move the order-by date"],
    ["for_sale", { orderByDate: null }, "Next: find a sponsor"],
    ["sold_needs_artwork", {}, "Next: get artwork from BuildCo"],
    ["artwork_in_signoff", {}, "Next: send the artwork for sign-off"],
    [
      "artwork_in_signoff",
      { status: "in_review", waitingOn: ["Marketing", "Sales", "Marketing"] },
      "Waiting on Marketing and Sales",
    ],
    [
      "artwork_in_signoff",
      { status: "changes_requested" },
      "Next: new artwork from BuildCo (changes asked)",
    ],
    [
      "ready_to_order",
      { status: "approved", orderByDate: "2026-12-09" },
      "Next: order from Big Print Co by 9 Dec",
    ],
    [
      "ready_to_order",
      { status: "approved", supplierName: null, orderByDate: null },
      "Next: choose a supplier and order",
    ],
    ["ordered", { status: "in_production" }, "Next: delivery from Big Print Co"],
    ["delivered", { status: "delivered" }, "Delivered"],
    ["delivered", { status: "closed" }, "Complete"],
  ])("%s %o → %s", (stage, over, text) => {
    expect(sponsorshipNextLine({ ...base, ...over, stage }).text).toBe(text);
  });

  it("is a warning once the order date has passed and it still isn't ordered", () => {
    expect(
      sponsorshipNextLine({ ...base, stage: "ready_to_order", orderByDate: "2026-10-01" }).tone,
    ).toBe("warning");
    expect(sponsorshipNextLine({ ...base, stage: "for_sale" }).tone).toBe("action");
    expect(sponsorshipNextLine({ ...base, stage: "for_sale", status: "on_hold" }).text).toBe(
      "On hold",
    );
  });
});

describe("sponsorshipProgress", () => {
  it("marks the stages before the current one done", () => {
    expect(sponsorshipProgress("artwork_in_signoff").map((p) => p.state)).toEqual([
      "done",
      "done",
      "current",
      "todo",
      "todo",
    ]);
    expect(sponsorshipProgress("delivered").every((p) => p.state === "done")).toBe(true);
    expect(sponsorshipProgress("for_sale")[0]).toEqual({
      key: "sold",
      label: "Sell",
      state: "current",
    });
  });
});

describe("sponsorshipNextStep (the item page)", () => {
  const baseStep: NextStep = {
    tone: "action",
    title: "Next: upload the artwork",
    action: { type: "link", label: "Upload artwork", href: "?tab=artwork#upload" },
  };
  const input: SponsorshipNextInput = {
    stage: "for_sale",
    status: "draft",
    fieldsReady: true,
    sponsorName: "BuildCo",
    supplierName: "Big Print Co",
    orderByDate: "2026-12-09",
    today: "2026-10-16",
    confirmation: null,
    canSell: true,
    canUpload: true,
    inviteHref: null,
  };

  it("an unsold item's next step is to sell it", () => {
    const { step, sell } = sponsorshipNextStep(baseStep, input);
    expect(sell).toBe(true);
    expect(step.title).toBe("For sale. Next: find a sponsor");
    expect(step.detail).toBe("Sell it by 9 Dec 2026, when it has to be ordered.");
    expect(step.action).toBeNull();
    // Nobody who can't sell is offered the button.
    expect(sponsorshipNextStep(baseStep, { ...input, canSell: false }).sell).toBe(false);
    expect(sponsorshipNextStep(baseStep, { ...input, orderByDate: "2026-10-01" }).step.tone).toBe(
      "warning",
    );
  });

  it("once sold, it asks for the sponsor's artwork (and offers the invite to admins)", () => {
    const { step, sell } = sponsorshipNextStep(baseStep, {
      ...input,
      stage: "sold_needs_artwork",
      inviteHref: "/users?tab=external&invite=1&role=sponsor&scopeId=sp&edition=ed",
    });
    expect(sell).toBe(false);
    expect(step.title).toBe("Sold to BuildCo. Next: get the sponsor's artwork");
    expect(step.action).toEqual({
      type: "link",
      label: "Upload sponsor artwork",
      href: "?tab=artwork#upload",
    });
    expect(step.secondary).toMatchObject({ label: "Invite sponsor to upload" });
    // Missing details come first: the shared step says what to add.
    const missing: NextStep = { tone: "action", title: "Next: add item type", action: null };
    expect(
      sponsorshipNextStep(missing, { ...input, stage: "sold_needs_artwork", fieldsReady: false })
        .step,
    ).toBe(missing);
  });

  it("words print and delivery as ordering", () => {
    const confirm: NextStep = {
      tone: "action",
      title: "Signed off. Next: confirm it has gone to print",
      action: { type: "confirm", instanceId: "i", stepName: "Sent to print", label: "x" },
    };
    const ordered = sponsorshipNextStep(confirm, {
      ...input,
      stage: "ready_to_order",
      status: "approved",
      confirmation: { who: "Big Print Co", canDecide: true },
    }).step;
    expect(ordered.title).toBe("Artwork signed off. Next: order from Big Print Co by 9 Dec 2026");
    expect(ordered.action).toMatchObject({ type: "confirm", label: "Confirm ordered" });

    const waiting: NextStep = { tone: "waiting", title: "…", action: null };
    expect(
      sponsorshipNextStep(waiting, {
        ...input,
        stage: "ordered",
        status: "in_production",
        confirmation: { who: "Big Print Co", canDecide: false },
      }).step.title,
    ).toBe("Ordered. Waiting on Big Print Co to confirm delivery");

    expect(
      sponsorshipNextStep(
        { ...confirm, action: { ...(confirm.action as object), stepName: "Installed" } as never },
        { ...input, stage: "delivered", status: "delivered" },
      ).step.action,
    ).toMatchObject({ label: "Confirm in place" });
  });

  it("leaves items on hold to the shared step", () => {
    const held: NextStep = { tone: "warning", title: "On hold", action: null };
    expect(sponsorshipNextStep(held, { ...input, status: "on_hold" })).toEqual({
      step: held,
      sell: false,
    });
  });
});
