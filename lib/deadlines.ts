/**
 * Deadline calculations (brief 7.1). All pure; dates are ISO `yyyy-MM-dd`
 * strings (Postgres `date` columns) and arithmetic is calendar-day based,
 * timezone-free by construction.
 */

export type DeadlineKey =
  | "artwork_due"
  | "venue_rigging_submission"
  | "print_deadline"
  | "delivery"
  | "stand_design_due"
  | "insurance_due";

/** The show-level deadlines, in the order they fall before build. */
export const DEADLINE_KEYS: DeadlineKey[] = [
  "stand_design_due",
  "insurance_due",
  "venue_rigging_submission",
  "artwork_due",
  "print_deadline",
  "delivery",
];

export const DEADLINE_LABELS: Record<DeadlineKey, string> = {
  stand_design_due: "Stand designs due",
  insurance_due: "Insurance documents due",
  venue_rigging_submission: "Venue rigging submission",
  artwork_due: "Artwork due",
  print_deadline: "Print deadline",
  delivery: "Delivery to venue",
};

export type EditionDeadlineRow = {
  key: DeadlineKey;
  daysBeforeBuildStart: number;
  overrideDate: string | null;
};

export type EditionForDeadlines = {
  buildStart: string;
  deadlines: EditionDeadlineRow[];
};

export function addDaysIso(iso: string, days: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function diffDaysIso(a: string, b: string): number {
  const [ay, am, ad] = a.split("-").map(Number);
  const [by, bm, bd] = b.split("-").map(Number);
  const ms = Date.UTC(ay, am - 1, ad) - Date.UTC(by, bm - 1, bd);
  return Math.round(ms / 86_400_000);
}

/** Effective date = override_date ?? build_start − days_before_build_start. */
export function effectiveDeadline(edition: EditionForDeadlines, key: DeadlineKey): string | null {
  const row = edition.deadlines.find((d) => d.key === key);
  if (!row) return null;
  if (row.overrideDate) return row.overrideDate;
  return addDaysIso(edition.buildStart, -row.daysBeforeBuildStart);
}

/** Item override wins, else the edition's artwork_due. */
export function artworkDue(
  item: { artworkDueOverride: string | null },
  edition: EditionForDeadlines,
): string | null {
  return item.artworkDueOverride ?? effectiveDeadline(edition, "artwork_due");
}

/** Item-level print deadline, else the edition's. */
export function printDeadline(
  item: { printDeadline: string | null },
  edition: EditionForDeadlines,
): string | null {
  return item.printDeadline ?? effectiveDeadline(edition, "print_deadline");
}

export function standDesignDue(edition: EditionForDeadlines): string | null {
  return effectiveDeadline(edition, "stand_design_due");
}

export function insuranceDue(edition: EditionForDeadlines): string | null {
  return effectiveDeadline(edition, "insurance_due");
}

/**
 * Hold shifting: a deadline computed for an entity that spent `holdShiftDays`
 * on hold moves later by that many days.
 */
export function shiftForHold(deadline: string | null, holdShiftDays: number): string | null {
  if (!deadline || holdShiftDays <= 0) return deadline;
  return addDaysIso(deadline, holdShiftDays);
}

/**
 * Standard offsets (days before build-up starts) a new event's deadlines
 * start with, and what an event without a row for a deadline falls back to.
 */
export const DEFAULT_DEADLINE_OFFSETS: Record<DeadlineKey, number> = {
  stand_design_due: 42,
  insurance_due: 28,
  venue_rigging_submission: 28,
  artwork_due: 21,
  print_deadline: 14,
  delivery: 3,
};

/** The full set of deadlines for a new event, in the order they fall. */
export function defaultDeadlines(): Array<{
  key: DeadlineKey;
  label: string;
  daysBeforeBuildStart: number;
}> {
  return DEADLINE_KEYS.map((key) => ({
    key,
    label: DEADLINE_LABELS[key],
    daysBeforeBuildStart: DEFAULT_DEADLINE_OFFSETS[key],
  }));
}

/** Is this a real calendar date written yyyy-MM-dd? */
export function isIsoDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [y, m, d] = value.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

/**
 * A deadline's date as the setup page shows it while someone types: a fixed
 * date wins, otherwise the days before build-up starts. Null while the
 * build-up date or the number of days isn't usable yet.
 */
export function deadlineDate(
  buildStart: string,
  daysBefore: number | string,
  overrideDate?: string | null,
): string | null {
  if (overrideDate && isIsoDate(overrideDate)) return overrideDate;
  if (typeof daysBefore === "string" && daysBefore.trim() === "") return null;
  const days = typeof daysBefore === "string" ? Number(daysBefore) : daysBefore;
  if (!isIsoDate(buildStart) || !Number.isFinite(days) || days < 0 || days > 730) return null;
  return addDaysIso(buildStart, -Math.round(days));
}

/** An event's five dates, in the order they fall. */
export type EventDates = {
  buildStart: string;
  buildEnd: string;
  openStart: string;
  openEnd: string;
  breakdownEnd: string;
};

/**
 * The build-up and breakdown dates assumed when an event is created from its
 * open dates only: build-up the two days before it opens, breakdown ending
 * the day after it closes. People confirm or change them on the setup page.
 */
export function assumedEventDates(
  openStart: string,
  openEnd: string,
): Pick<EventDates, "buildStart" | "buildEnd" | "breakdownEnd"> {
  return {
    buildStart: addDaysIso(openStart, -2),
    buildEnd: addDaysIso(openStart, -1),
    breakdownEnd: addDaysIso(openEnd, 1),
  };
}

/** 52 weeks: next year's event on the same weekday. */
export const SAME_WEEKDAY_NEXT_YEAR = 364;

/**
 * Dates for a copy of `source` that opens and closes on the given days:
 * build-up and breakdown keep the source's distance from its open dates.
 */
export function datesLike(source: EventDates, openStart: string, openEnd: string): EventDates {
  return {
    buildStart: addDaysIso(openStart, diffDaysIso(source.buildStart, source.openStart)),
    buildEnd: addDaysIso(openStart, diffDaysIso(source.buildEnd, source.openStart)),
    openStart,
    openEnd,
    breakdownEnd: addDaysIso(openEnd, diffDaysIso(source.breakdownEnd, source.openEnd)),
  };
}

/** The first date that is out of order (build → open → breakdown), or null. */
export function firstDateOutOfOrder(d: EventDates): keyof EventDates | null {
  const order: Array<keyof EventDates> = [
    "buildStart",
    "buildEnd",
    "openStart",
    "openEnd",
    "breakdownEnd",
  ];
  for (let i = 1; i < order.length; i++) {
    if (d[order[i]] < d[order[i - 1]]) return order[i];
  }
  return null;
}

/** People's names for the five dates. */
export const EVENT_DATE_LABELS: Record<keyof EventDates, string> = {
  buildStart: "Build-up starts",
  buildEnd: "Build-up ends",
  openStart: "Opens to visitors",
  openEnd: "Closes to visitors",
  breakdownEnd: "Breakdown ends",
};
