/**
 * The event dashboard's rules (pure; unit tested in
 * tests/unit/dashboard-rules.test.ts): the countdown pill, the budget
 * line, signage progress by stage, what is left before each deadline, the
 * "Your next steps" rows and who a sign-off is sitting with. The page and
 * lib/queries/dashboard.ts only fetch and render.
 */
import type { Feature } from "@/lib/authz";
import { addDaysIso, diffDaysIso } from "@/lib/deadlines";
import { SIGNAGE_STAGES, STAGE_LABELS, type SignageStage } from "@/lib/domain/signage";
import {
  isOverdueToOrder,
  matchesSponsorshipFilter,
  saleState,
  sponsorshipStage,
  sponsorshipTotals,
} from "@/lib/domain/sponsorship";
import { formatDate, formatDayMonth, plural, roleLabel } from "@/lib/format";

// ------------------------------------------------------------ countdown

export type CountdownTone =
  "planning" | "build_up" | "open" | "breakdown" | "finished" | "archived";

export type EventCountdown = { label: string; tone: CountdownTone };

const inDays = (n: number) => (n === 1 ? "tomorrow" : `in ${n} days`);

/**
 * Where the event is in words, from its dates and today in London:
 * "Build-up starts in 352 days", "Open now: day 2 of 3", "Breakdown ends
 * tomorrow".
 */
export function eventCountdown(
  e: {
    status: string;
    buildStart: string;
    openStart: string;
    openEnd: string;
    breakdownEnd: string;
  },
  today: string,
): EventCountdown {
  if (e.status === "archived") return { label: "Archived", tone: "archived" };
  if (today < e.buildStart) {
    return {
      label: `Build-up starts ${inDays(diffDaysIso(e.buildStart, today))}`,
      tone: "planning",
    };
  }
  if (today < e.openStart) {
    return {
      label: `Build-up now · opens ${inDays(diffDaysIso(e.openStart, today))}`,
      tone: "build_up",
    };
  }
  if (today <= e.openEnd) {
    const total = diffDaysIso(e.openEnd, e.openStart) + 1;
    const day = diffDaysIso(today, e.openStart) + 1;
    return { label: total === 1 ? "Open today" : `Open now: day ${day} of ${total}`, tone: "open" };
  }
  if (today <= e.breakdownEnd) {
    const left = diffDaysIso(e.breakdownEnd, today);
    return {
      label: left === 0 ? "Breakdown ends today" : `Breakdown ends ${inDays(left)}`,
      tone: "breakdown",
    };
  }
  const ago = diffDaysIso(today, e.breakdownEnd);
  return { label: ago === 1 ? "Finished yesterday" : `Finished ${ago} days ago`, tone: "finished" };
}

/** "1–4 Oct 2027", "28 Sept – 4 Oct 2027", "30 Dec 2027 – 2 Jan 2028". */
export function dateRange(from: string, to: string): string {
  if (from === to) return formatDate(from);
  if (from.slice(0, 7) === to.slice(0, 7)) return `${Number(from.slice(8, 10))}–${formatDate(to)}`;
  if (from.slice(0, 4) === to.slice(0, 4)) {
    return `${formatDayMonth(`${from}T12:00:00Z`)} – ${formatDate(to)}`;
  }
  return `${formatDate(from)} – ${formatDate(to)}`;
}

// --------------------------------------------------------------- budget

export type BudgetSummary =
  | { state: "none" }
  | {
      state: "under" | "on" | "over";
      budget: number;
      /** The larger of the estimate and what has actually been spent. */
      forecast: number;
      basis: "estimate" | "actual";
      /** How far under or over, always positive. */
      difference: number;
      /** Forecast as a share of the budget, 0–100 (100 when over). */
      pct: number;
    };

const toNumber = (v: string | number | null | undefined) =>
  v == null || v === "" || Number.isNaN(Number(v)) ? 0 : Number(v);

/** Over budget by £x, or £x left, against the estimate (or actuals once they are higher). */
export function budgetSummary(input: {
  budget: string | number | null;
  estimate: string | number | null;
  actual: string | number | null;
}): BudgetSummary {
  if (input.budget == null || input.budget === "") return { state: "none" };
  const budget = toNumber(input.budget);
  const estimate = toNumber(input.estimate);
  const actual = toNumber(input.actual);
  const basis = actual > estimate ? "actual" : "estimate";
  const forecast = Math.max(estimate, actual);
  const state = forecast > budget ? "over" : forecast === budget ? "on" : "under";
  const pct = budget > 0 ? Math.min(100, Math.round((forecast / budget) * 100)) : 100;
  return { state, budget, forecast, basis, difference: Math.abs(budget - forecast), pct };
}

// ------------------------------------------------------ signage progress

export type StageProgress = {
  key: SignageStage;
  label: string;
  count: number;
  /** Share of the items counted (Rejected left out), 0–100. */
  pct: number;
  statuses: { status: string; count: number }[];
};

/** The four stages with their counts; Rejected is counted apart. */
export function signageProgress(statusCounts: Record<string, number>): {
  total: number;
  stages: StageProgress[];
  rejected: number;
} {
  const stages = (Object.keys(SIGNAGE_STAGES) as SignageStage[]).map((key) => {
    const statuses = SIGNAGE_STAGES[key]
      .map((status) => ({ status, count: statusCounts[status] ?? 0 }))
      .filter((s) => s.count > 0);
    return {
      key,
      label: STAGE_LABELS[key],
      count: statuses.reduce((n, s) => n + s.count, 0),
      statuses,
    };
  });
  const total = stages.reduce((n, s) => n + s.count, 0);
  return {
    total,
    stages: stages.map((s) => ({ ...s, pct: total ? Math.round((s.count / total) * 100) : 0 })),
    rejected: statusCounts.rejected ?? 0,
  };
}

// ------------------------------------------------------------ deadlines

/** The section each event deadline's work lives in (its link is hidden without it). */
export const DEADLINE_FEATURE: Record<string, Feature> = {
  artwork_due: "signage",
  print_deadline: "signage",
  delivery: "onsite",
  venue_rigging_submission: "reports",
  stand_design_due: "stand_designs",
  insurance_due: "stands",
};

export type DeadlineWork = {
  /** Signs and sponsorship items still without artwork (Needs artwork). */
  needsArtwork: number;
  /** Signed off, not sent to print yet (Ready to print). */
  readyToPrint: number;
  /** Not delivered yet: everything up to and including Sent to print. */
  toDeliver: number;
  /** Items needing venue approval (the venue pack). */
  venueItems: number;
  /** Feature stands still without a design. */
  standDesignsToDo: number;
};

/** How much is left before an event deadline: "3 items still need artwork". */
export function deadlineWorkLabel(key: string, w: DeadlineWork): string | null {
  switch (key) {
    case "artwork_due":
      return w.needsArtwork > 0
        ? `${plural(w.needsArtwork, "item")} still ${w.needsArtwork === 1 ? "needs" : "need"} artwork`
        : "all artwork is in";
    case "print_deadline":
      return w.readyToPrint > 0
        ? `${plural(w.readyToPrint, "item")} ready to print, not sent yet`
        : null;
    case "delivery":
      return w.toDeliver > 0
        ? `${plural(w.toDeliver, "item")} not delivered yet`
        : "everything is delivered";
    case "venue_rigging_submission":
      return w.venueItems > 0
        ? `${plural(w.venueItems, "item")} in the venue pack`
        : "nothing needs venue approval";
    case "stand_design_due":
      return w.standDesignsToDo > 0
        ? `${plural(w.standDesignsToDo, "feature stand")} still ${w.standDesignsToDo === 1 ? "needs" : "need"} a design`
        : null;
    default:
      return null;
  }
}

// ----------------------------------------------------------- next steps

export type NextStepRow = {
  key: "signoffs" | "tasks" | "sponsorship" | "onsite";
  text: string;
  detail: string | null;
  href: string;
  /** Something in it is overdue: shown in red. */
  urgent: boolean;
};

export type NextStepsInput = {
  code: string;
  /** Sign-offs waiting on this person (null: not shown). */
  signoffs: { total: number; overdue: number } | null;
  /** Their open tasks for this event: overdue, and due in the next 7 days. */
  tasks: { overdue: number; dueSoon: number } | null;
  /** Sponsorship items to order within a month (or overdue), and how many of those are unsold. */
  sponsorship: { urgent: number; unsold: number; overdue: number } | null;
  /** Deliveries and installs in the next 7 days. */
  onsite: { deliveries: number; installs: number } | null;
};

/** "Your next steps": only rows with something in them, most pressing first. */
export function nextStepRows(input: NextStepsInput): NextStepRow[] {
  const rows: NextStepRow[] = [];
  const { code, signoffs, tasks, sponsorship, onsite } = input;
  if (signoffs && signoffs.total > 0) {
    rows.push({
      key: "signoffs",
      text: `${plural(signoffs.total, "sign-off")} ${signoffs.total === 1 ? "is" : "are"} waiting on you`,
      detail: signoffs.overdue > 0 ? `${signoffs.overdue} overdue` : null,
      href: `/approvals?tab=mine&event=${code}`,
      urgent: signoffs.overdue > 0,
    });
  }
  if (tasks && tasks.overdue + tasks.dueSoon > 0) {
    const detail = [
      tasks.overdue > 0 ? `${tasks.overdue} overdue` : null,
      tasks.dueSoon > 0 ? `${tasks.dueSoon} due this week` : null,
    ].filter(Boolean);
    rows.push({
      key: "tasks",
      text: `You have ${plural(tasks.overdue + tasks.dueSoon, "task")} due`,
      detail: detail.join(" · "),
      href: `/my-work?event=${code}${tasks.dueSoon === 0 ? "&due=overdue" : ""}#tasks`,
      urgent: tasks.overdue > 0,
    });
  }
  if (sponsorship && sponsorship.urgent > 0) {
    const detail = [
      sponsorship.overdue > 0 ? `${sponsorship.overdue} overdue` : null,
      sponsorship.unsold > 0 ? `${sponsorship.unsold} not sold yet` : null,
    ].filter(Boolean);
    rows.push({
      key: "sponsorship",
      text: `${plural(sponsorship.urgent, "sponsorship item")} to order within a month`,
      detail: detail.length ? detail.join(" · ") : null,
      href: `/${code}/sponsorship?filter=urgent`,
      urgent: sponsorship.overdue > 0 || sponsorship.unsold > 0,
    });
  }
  if (onsite && onsite.deliveries + onsite.installs > 0) {
    const parts = [
      onsite.deliveries > 0 ? plural(onsite.deliveries, "delivery", "deliveries") : null,
      onsite.installs > 0 ? plural(onsite.installs, "install") : null,
    ].filter(Boolean);
    rows.push({
      key: "onsite",
      text: `${parts.join(" and ")} in the next 7 days`,
      detail: null,
      href: `/${code}/onsite`,
      urgent: false,
    });
  }
  return rows;
}

// --------------------------------------------------- sponsorship and onsite

export type SponsorshipDashRow = {
  kind: string;
  sponsorId: string | null;
  salePrice: string | number | null;
  costEstimate: string | number | null;
  status: string;
  previousStatus: string | null;
  hasArtwork: boolean;
  orderByDate: string | null;
};

/**
 * The Sponsorship card, with the Sponsorship page's own rules so the
 * numbers match its filters: sold (?filter=sold) of what's for sale,
 * sales, and how many must be ordered within a month (?filter=urgent).
 */
export function sponsorshipSummary(rows: SponsorshipDashRow[], today: string) {
  const totals = sponsorshipTotals(rows);
  let urgent = 0;
  let urgentUnsold = 0;
  let overdue = 0;
  for (const r of rows) {
    const sale = saleState(r);
    const stage = sponsorshipStage({ ...r, hasArtwork: r.hasArtwork });
    const filterRow = { sale, stage, orderByDate: r.orderByDate };
    if (!matchesSponsorshipFilter("urgent", filterRow, today)) continue;
    urgent++;
    if (sale === "available") urgentUnsold++;
    if (isOverdueToOrder(filterRow, today)) overdue++;
  }
  return {
    forSale: totals.available + totals.sold,
    sold: totals.sold,
    available: totals.available,
    inPackage: totals.inPackage,
    sales: totals.sales,
    urgent,
    urgentUnsold,
    overdue,
  };
}

const ONSITE_KINDS = ["signage", "sponsorship_item", "stand_panel"];

/**
 * Deliveries and installs still to happen from today to a week today, on
 * the items Onsite lists (sent to print or later): waiting to be delivered,
 * or delivered and waiting to go up. Sponsorship items are handed over,
 * not installed.
 */
export function onsiteSoon(
  items: {
    kind: string;
    status: string;
    deliveryDate: string | null;
    installDate: string | null;
  }[],
  today: string,
): { deliveries: number; installs: number } {
  const end = addDaysIso(today, 7);
  const soon = (d: string | null) => Boolean(d && d >= today && d <= end);
  let deliveries = 0;
  let installs = 0;
  for (const i of items) {
    if (!ONSITE_KINDS.includes(i.kind)) continue;
    if (i.status === "in_production" && soon(i.deliveryDate)) deliveries++;
    if (
      i.kind !== "sponsorship_item" &&
      (i.status === "in_production" || i.status === "delivered") &&
      soon(i.installDate)
    ) {
      installs++;
    }
  }
  return { deliveries, installs };
}

// ------------------------------------------------------------ sign-offs

/**
 * Who an open sign-off is sitting with, in the words the Approvals team
 * view uses: the named person, the department, else the role.
 */
export function waitingOnLabel(step: {
  assignedUserId: string | null;
  assigneeName: string | null;
  assignedDepartmentId: string | null;
  departmentName: string | null;
  assignedRole: string | null;
  stepKind: string;
}): string {
  if (step.assignedUserId) return step.assigneeName || "A named person";
  if (step.assignedDepartmentId) return step.departmentName ?? "The department";
  if (step.assignedRole === "supplier" && step.stepKind === "confirmation") {
    return "Supplier or Operations";
  }
  return step.assignedRole ? roleLabel(step.assignedRole) : "Nobody yet";
}

/**
 * Overdue artwork sign-offs, one per item, keeping the order given (most
 * overdue first): what Approvals → All artwork lists with
 * ?filter=waiting&overdue=1. Print, delivery and install confirmations,
 * stands, earlier rounds and items without artwork aren't counted.
 */
export function overdueArtworkSignoffs<
  T extends {
    entityType: string;
    stepKind: string;
    ref: string;
    runNumber: number;
    currentRunNumber: number | null;
    itemHasArtwork: boolean | null;
    itemStatus: string | null;
  },
>(overdue: T[]): T[] {
  const seen = new Set<string>();
  return overdue.filter((p) => {
    if (p.entityType !== "signage_item" || p.stepKind !== "approval") return false;
    if (p.runNumber !== p.currentRunNumber || !p.itemHasArtwork) return false;
    if (p.itemStatus !== "in_review" || seen.has(p.ref)) return false;
    seen.add(p.ref);
    return true;
  });
}

/** "23 days late", "1 day late", "due today". */
export function lateLabel(days: number): string {
  if (days <= 0) return "due today";
  return `${plural(days, "day")} late`;
}
