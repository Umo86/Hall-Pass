/**
 * Sponsorship rules (pure; unit tested in tests/unit/sponsorship.test.ts).
 *
 * A sponsorship item is sold, then the sponsor's artwork is signed off, then
 * it is ordered from the supplier by the order-by date and delivered. These
 * functions turn an item's sale and status into that one stage, the "Next:"
 * line on its card, the list filters and the item page's next step. The
 * status machine itself is untouched: a stage is only a reading of it.
 */
import { orderCountdown } from "@/lib/countdown";
import { formatDate } from "@/lib/format";
import type { NextStep, NextStepAction, ProgressStep } from "@/lib/domain/signage";

export const SPONSORSHIP_STAGES = [
  "for_sale",
  "sold_needs_artwork",
  "artwork_in_signoff",
  "ready_to_order",
  "ordered",
  "delivered",
] as const;

export type SponsorshipStage = (typeof SPONSORSHIP_STAGES)[number];

export const SPONSORSHIP_STAGE_LABELS: Record<SponsorshipStage, string> = {
  for_sale: "For sale",
  sold_needs_artwork: "Needs artwork",
  artwork_in_signoff: "Artwork sign-off",
  ready_to_order: "Ready to order",
  ordered: "Ordered",
  delivered: "Delivered",
};

type StageInput = {
  kind: string;
  sponsorId: string | null;
  hasArtwork: boolean;
  status: string;
  /** The status it was put on hold from. */
  previousStatus?: string | null;
};

/**
 * Where a sponsorship item (or sponsor signage) is: for sale until it has a
 * sponsor; then its artwork, sign-off, order and delivery. On hold reads as
 * the stage it was held at.
 */
export function sponsorshipStage(item: StageInput): SponsorshipStage {
  const status = item.status === "on_hold" ? (item.previousStatus ?? "draft") : item.status;
  if (item.kind === "sponsorship_item" && !item.sponsorId) return "for_sale";
  switch (status) {
    case "delivered":
    case "installed":
    case "snagged":
    case "closed":
      return "delivered";
    case "in_production":
      return "ordered";
    case "approved":
    case "approved_with_conditions":
      return "ready_to_order";
    case "in_review":
    case "changes_requested":
    case "rejected":
      return "artwork_in_signoff";
    default:
      return item.hasArtwork ? "artwork_in_signoff" : "sold_needs_artwork";
  }
}

/** Stages before the order is placed: the order-by date still matters. */
export function notOrderedYet(stage: SponsorshipStage): boolean {
  return stage !== "ordered" && stage !== "delivered";
}

export type SaleState = "available" | "sold" | "in_package";

export const SALE_LABELS: Record<SaleState, string> = {
  available: "Available",
  sold: "Sold",
  in_package: "In package",
};

/**
 * Sold, still available, or part of a sponsor's package: sponsor signage
 * comes with what the sponsor bought, so without a price of its own it is
 * "In package", never a £0 sale.
 */
export function saleState(item: {
  kind: string;
  sponsorId: string | null;
  salePrice: string | number | null;
}): SaleState {
  if (!item.sponsorId) return "available";
  if (item.kind !== "sponsorship_item" && (item.salePrice === null || item.salePrice === "")) {
    return "in_package";
  }
  return "sold";
}

export type TotalsRow = {
  kind: string;
  sponsorId: string | null;
  salePrice: string | number | null;
  costEstimate: string | number | null;
};

/**
 * The summary tiles: what's available, sold and in packages, sales (sale
 * prices only) and profit on the sales that have a price.
 */
export function sponsorshipTotals(rows: TotalsRow[]): {
  available: number;
  sold: number;
  inPackage: number;
  sales: number;
  profit: number;
} {
  let available = 0;
  let sold = 0;
  let inPackage = 0;
  let sales = 0;
  let profit = 0;
  for (const r of rows) {
    const state = saleState(r);
    if (state === "available") available++;
    else if (state === "in_package") inPackage++;
    else {
      sold++;
      if (r.salePrice !== null && r.salePrice !== "") {
        sales += Number(r.salePrice);
        profit += Number(r.salePrice) - (r.costEstimate ? Number(r.costEstimate) : 0);
      }
    }
  }
  return { available, sold, inPackage, sales, profit };
}

// ---------------------------------------------------------------- filters

/** The chips above the list, as they appear in `?filter=`. */
export const SPONSORSHIP_FILTERS = [
  "all",
  "available",
  "sold",
  "in_package",
  "overdue",
  "soon",
] as const;

/**
 * `urgent` is accepted too (links from elsewhere): overdue or under a month,
 * i.e. both of the last two chips.
 */
export type SponsorshipFilter = (typeof SPONSORSHIP_FILTERS)[number] | "urgent";

export const SPONSORSHIP_FILTER_LABELS: Record<SponsorshipFilter, string> = {
  all: "All",
  available: "Available",
  sold: "Sold",
  in_package: "In package",
  overdue: "Overdue to order",
  soon: "Under a month",
  urgent: "Overdue or under a month",
};

export function parseSponsorshipFilter(raw: string | null | undefined): SponsorshipFilter {
  if (raw === "urgent") return "urgent";
  return (SPONSORSHIP_FILTERS as readonly string[]).includes(raw ?? "")
    ? (raw as SponsorshipFilter)
    : "all";
}

type FilterRow = {
  sale: SaleState;
  stage: SponsorshipStage;
  orderByDate: string | null;
};

/** The order-by date has passed and it isn't ordered yet. */
export function isOverdueToOrder(row: FilterRow, today: string): boolean {
  return Boolean(row.orderByDate && notOrderedYet(row.stage) && row.orderByDate < today);
}

/** Under a calendar month to the order-by date (today included), not ordered yet. */
export function isUnderAMonth(row: FilterRow, today: string): boolean {
  if (!row.orderByDate || !notOrderedYet(row.stage) || row.orderByDate < today) return false;
  return orderCountdown(row.orderByDate, today, false).months === 0;
}

export function matchesSponsorshipFilter(
  filter: SponsorshipFilter,
  row: FilterRow,
  today: string,
): boolean {
  switch (filter) {
    case "available":
    case "sold":
    case "in_package":
      return row.sale === filter;
    case "overdue":
      return isOverdueToOrder(row, today);
    case "soon":
      return isUnderAMonth(row, today);
    case "urgent":
      return isOverdueToOrder(row, today) || isUnderAMonth(row, today);
    default:
      return true;
  }
}

/** Every search word must appear in the ref, name, sponsor, type or supplier. */
export function matchesSponsorshipSearch(
  q: string,
  row: {
    ref: string;
    name: string;
    sponsorName: string | null;
    typeName: string | null;
    supplierName: string | null;
  },
): boolean {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const hay = [row.ref, row.name, row.sponsorName, row.typeName, row.supplierName]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  return words.every((w) => hay.includes(w));
}

export type SponsorshipGroupBy = "stage" | "type" | "sponsor";

export function parseGroupBy(raw: string | null | undefined): SponsorshipGroupBy | null {
  return raw === "stage" || raw === "type" || raw === "sponsor" ? raw : null;
}

/**
 * Rows grouped by stage (in stage order), type or sponsor (A–Z, with "Not
 * sold yet" / "No type" last). Rows keep their order within a group.
 */
export function groupSponsorshipRows<
  T extends {
    stage: SponsorshipStage;
    kind: string;
    typeName: string | null;
    sponsorName: string | null;
  },
>(rows: T[], by: SponsorshipGroupBy): { key: string; label: string; rows: T[] }[] {
  const groups = new Map<string, { key: string; label: string; rows: T[]; order: string }>();
  for (const row of rows) {
    let key: string;
    let label: string;
    let order: string;
    if (by === "stage") {
      key = row.stage;
      label = SPONSORSHIP_STAGE_LABELS[row.stage];
      order = String(SPONSORSHIP_STAGES.indexOf(row.stage)).padStart(2, "0");
    } else if (by === "type") {
      label = row.kind === "signage" ? "Sponsor signage" : (row.typeName ?? "No type");
      key = label;
      order = `${row.typeName || row.kind === "signage" ? "0" : "1"}${label.toLowerCase()}`;
    } else {
      label = row.sponsorName ?? "Not sold yet";
      key = label;
      order = `${row.sponsorName ? "0" : "1"}${label.toLowerCase()}`;
    }
    const g = groups.get(key) ?? { key, label, rows: [], order };
    g.rows.push(row);
    groups.set(key, g);
  }
  return [...groups.values()]
    .sort((a, b) => a.order.localeCompare(b.order))
    .map(({ key, label, rows: list }) => ({ key, label, rows: list }));
}

// ------------------------------------------------------------- next lines

export type NextLineTone = "action" | "waiting" | "warning" | "done";

/** "13 Oct" from an ISO date, read at midday so no time zone moves the day. */
function dayMonth(iso: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: "Europe/London",
  }).format(new Date(`${iso}T12:00:00Z`));
}

function joinWords(words: string[]): string {
  const list = [...new Set(words.filter(Boolean))];
  if (list.length <= 1) return list[0] ?? "";
  return `${list.slice(0, -1).join(", ")} and ${list[list.length - 1]}`;
}

/**
 * The one line on a card that says what happens next: "Next: sell by 5 Oct",
 * "Next: get artwork from BuildCo", "Waiting on Marketing",
 * "Next: order from Big Print Co by 9 Dec".
 */
export function sponsorshipNextLine(input: {
  stage: SponsorshipStage;
  status: string;
  orderByDate: string | null;
  today: string;
  sponsorName: string | null;
  supplierName: string | null;
  /** Who the current sign-off waits on. */
  waitingOn: string[];
}): { text: string; tone: NextLineTone } {
  const { stage, status, orderByDate, today } = input;
  const late = Boolean(orderByDate && orderByDate < today);
  if (status === "on_hold") return { text: "On hold", tone: "warning" };
  switch (stage) {
    case "for_sale":
      if (!orderByDate) return { text: "Next: find a sponsor", tone: "action" };
      return late
        ? { text: "Next: sell it, or move the order-by date", tone: "warning" }
        : { text: `Next: sell by ${dayMonth(orderByDate)}`, tone: "action" };
    case "sold_needs_artwork":
      return {
        text: `Next: get artwork from ${input.sponsorName ?? "the sponsor"}`,
        tone: late ? "warning" : "action",
      };
    case "artwork_in_signoff":
      if (status === "changes_requested") {
        return {
          text: `Next: new artwork from ${input.sponsorName ?? "the sponsor"} (changes asked)`,
          tone: "action",
        };
      }
      if (status === "rejected") return { text: "Artwork rejected", tone: "warning" };
      if (status === "in_review") {
        return input.waitingOn.length
          ? { text: `Waiting on ${joinWords(input.waitingOn)}`, tone: "waiting" }
          : { text: "In sign-off", tone: "waiting" };
      }
      return { text: "Next: send the artwork for sign-off", tone: "action" };
    case "ready_to_order": {
      const by = orderByDate ? ` by ${dayMonth(orderByDate)}` : "";
      return {
        text: input.supplierName
          ? `Next: order from ${input.supplierName}${by}`
          : `Next: choose a supplier and order${by}`,
        tone: late ? "warning" : "action",
      };
    }
    case "ordered":
      return {
        text: `Next: delivery from ${input.supplierName ?? "the supplier"}`,
        tone: "waiting",
      };
    case "delivered":
      return { text: status === "closed" ? "Complete" : "Delivered", tone: "done" };
  }
}

/** The stepper on a sponsorship item's page: sell, artwork, sign-off, order, delivery. */
export function sponsorshipProgress(stage: SponsorshipStage): ProgressStep[] {
  const steps: [string, string][] = [
    ["sold", "Sell"],
    ["artwork", "Artwork"],
    ["signoff", "Sign-off"],
    ["order", "Order"],
    ["delivered", "Delivery"],
  ];
  const current = {
    for_sale: 0,
    sold_needs_artwork: 1,
    artwork_in_signoff: 2,
    ready_to_order: 3,
    ordered: 4,
    delivered: steps.length,
  }[stage];
  return steps.map(([key, label], i) => ({
    key,
    label,
    state: i < current ? "done" : i === current ? "current" : "todo",
  }));
}

export type SponsorshipNextInput = {
  stage: SponsorshipStage;
  status: string;
  /** Everything sign-off needs is filled in. */
  fieldsReady: boolean;
  sponsorName: string | null;
  supplierName: string | null;
  orderByDate: string | null;
  today: string;
  /** The production confirmation waiting now, if any. */
  confirmation: { who: string; canDecide: boolean } | null;
  canSell: boolean;
  canUpload: boolean;
  /** Where an admin invites the sponsor to upload; null for everyone else. */
  inviteHref: string | null;
};

/**
 * The item page's next step for a sponsorship item, built on the shared one
 * (`base`, from nextStep): sell it first, then get the sponsor's artwork,
 * then the shared sign-off steps, worded as order and delivery. `sell` asks
 * the page to show the Mark as sold button.
 */
export function sponsorshipNextStep(
  base: NextStep,
  input: SponsorshipNextInput,
): { step: NextStep; sell: boolean } {
  const { stage, status } = input;
  const sponsor = input.sponsorName ?? "the sponsor";
  const keep = { step: base, sell: false };
  if (status === "on_hold") return keep;
  const confirmAction = (label: string): NextStepAction | null =>
    base.action?.type === "confirm" ? { ...base.action, label } : base.action;
  const waitingWho = input.confirmation && !input.confirmation.canDecide;

  switch (stage) {
    case "for_sale": {
      if (!["draft", "awaiting_artwork"].includes(status)) {
        // Unsold but already further on (a sale undone later): its own next
        // step stands, with Mark as sold beside it.
        return { step: base, sell: input.canSell };
      }
      const late = Boolean(input.orderByDate && input.orderByDate < input.today);
      return {
        step: {
          tone: late ? "warning" : "action",
          title: "For sale. Next: find a sponsor",
          detail: input.orderByDate
            ? late
              ? `The order-by date (${formatDate(input.orderByDate)}) has passed — sell it now or move the date.`
              : `Sell it by ${formatDate(input.orderByDate)}, when it has to be ordered.`
            : "Mark it sold when a sponsor buys it.",
          action: null,
        },
        sell: input.canSell,
      };
    }
    case "sold_needs_artwork":
      if (status === "draft" && !input.fieldsReady) return keep;
      return {
        step: {
          tone: "action",
          title: `Sold to ${sponsor}. Next: get the sponsor's artwork`,
          detail: input.inviteHref
            ? "Upload it here, or invite the sponsor to upload it themselves."
            : "Upload it here when the sponsor sends it.",
          action: input.canUpload
            ? { type: "link", label: "Upload sponsor artwork", href: "?tab=artwork#upload" }
            : null,
          secondary: input.inviteHref
            ? { type: "link", label: "Invite sponsor to upload", href: input.inviteHref }
            : null,
        },
        sell: false,
      };
    case "artwork_in_signoff":
      if (status === "draft" && input.fieldsReady) {
        return {
          step: { ...base, title: "The sponsor's artwork is in. Next: send it for sign-off" },
          sell: false,
        };
      }
      return keep;
    case "ready_to_order": {
      const by = input.orderByDate ? ` by ${formatDate(input.orderByDate)}` : "";
      if (base.action?.type === "confirm") {
        return {
          step: {
            ...base,
            title: `Artwork signed off. Next: order from ${input.supplierName ?? "the supplier"}${by}`,
            action: confirmAction("Confirm ordered"),
          },
          sell: false,
        };
      }
      if (base.tone === "warning" && !input.supplierName) {
        return {
          step: {
            ...base,
            title: `Artwork signed off. Next: choose who makes it${by}`,
            detail: "Set the supplier first — nothing is ordered without one.",
          },
          sell: false,
        };
      }
      if (waitingWho) {
        return {
          step: {
            ...base,
            title: `Artwork signed off. Waiting on ${input.confirmation!.who} to confirm the order`,
          },
          sell: false,
        };
      }
      return keep;
    }
    case "ordered":
      if (base.action?.type === "confirm") {
        return {
          step: {
            ...base,
            title: `Ordered. Next: confirm delivery${input.supplierName ? ` from ${input.supplierName}` : ""}`,
            action: confirmAction("Confirm delivered"),
          },
          sell: false,
        };
      }
      if (waitingWho) {
        return {
          step: {
            ...base,
            title: `Ordered. Waiting on ${input.confirmation!.who} to confirm delivery`,
          },
          sell: false,
        };
      }
      return keep;
    case "delivered":
      if (status === "delivered" && base.action?.type === "confirm") {
        return {
          step: {
            ...base,
            title: "Delivered. Next: confirm it is in place",
            detail: base.detail ?? "Handed out or set up at the event.",
            action: confirmAction("Confirm in place"),
          },
          sell: false,
        };
      }
      if (status === "delivered" && waitingWho) {
        return {
          step: {
            ...base,
            title: `Delivered. Waiting on ${input.confirmation!.who} to confirm it is in place`,
          },
          sell: false,
        };
      }
      if (status === "installed") {
        return { step: { ...base, title: "In place. Next: mark it complete" }, sell: false };
      }
      if (status === "closed") {
        return { step: { ...base, title: "Complete — delivered and in place" }, sell: false };
      }
      return keep;
  }
}
