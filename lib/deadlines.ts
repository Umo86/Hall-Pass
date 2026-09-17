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
