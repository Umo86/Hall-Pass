/**
 * Short date wording for the setup screens ("3 Oct", "3–4 Oct",
 * "30 Sep – 1 Oct"). Plain dates are calendar days, so they are formatted in
 * UTC: no timezone can move them. Pure; safe on server and client.
 */

const DAY_MONTH = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  timeZone: "UTC",
});
const DAY_MONTH_YEAR = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "UTC",
});
const WEEKDAY_DATE = new Intl.DateTimeFormat("en-GB", {
  weekday: "short",
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "UTC",
});

function asDate(iso: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) return null;
  const d = new Date(`${iso}T00:00:00Z`);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** "3 Oct". */
export function shortDate(iso: string): string {
  const d = asDate(iso);
  return d ? DAY_MONTH.format(d) : "—";
}

/** "3 Oct 2027". */
export function longDate(iso: string): string {
  const d = asDate(iso);
  return d ? DAY_MONTH_YEAR.format(d) : "—";
}

/** "Fri 10 Sep 2027". */
export function weekdayDate(iso: string): string {
  const d = asDate(iso);
  return d ? WEEKDAY_DATE.format(d) : "—";
}

/** "3–4 Oct", "30 Sep – 1 Oct", or one day when they're the same. */
export function dateRange(from: string, to: string): string {
  const a = asDate(from);
  const b = asDate(to);
  if (!a || !b) return "—";
  if (from === to) return DAY_MONTH.format(a);
  if (a.getUTCMonth() === b.getUTCMonth() && a.getUTCFullYear() === b.getUTCFullYear()) {
    return `${a.getUTCDate()}–${DAY_MONTH.format(b)}`;
  }
  return `${DAY_MONTH.format(a)} – ${DAY_MONTH.format(b)}`;
}

/** "5–7 Oct 2027" with the year once, for one-line summaries. */
export function dateRangeWithYear(from: string, to: string): string {
  const a = asDate(from);
  const b = asDate(to);
  if (!a || !b) return "—";
  if (a.getUTCFullYear() !== b.getUTCFullYear()) {
    return `${DAY_MONTH_YEAR.format(a)} – ${DAY_MONTH_YEAR.format(b)}`;
  }
  return `${dateRange(from, to)} ${b.getUTCFullYear()}`;
}
