/**
 * Month-grid arithmetic for the deadlines calendar. Pure and ISO-string
 * based (yyyy-MM-dd), weeks run Monday to Sunday per British convention.
 */

export type MonthCell = { iso: string; inMonth: boolean };

function iso(y: number, m: number, d: number): string {
  return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** Weeks (Mon–Sun) covering the month, padded with the neighbours' days. */
export function monthGrid(year: number, month: number): MonthCell[][] {
  const first = new Date(Date.UTC(year, month - 1, 1));
  // getUTCDay: Sunday 0 … Saturday 6 → Monday-first offset.
  const lead = (first.getUTCDay() + 6) % 7;
  const start = new Date(first);
  start.setUTCDate(1 - lead);
  const weeks: MonthCell[][] = [];
  const cursor = new Date(start);
  do {
    const week: MonthCell[] = [];
    for (let i = 0; i < 7; i++) {
      week.push({
        iso: iso(cursor.getUTCFullYear(), cursor.getUTCMonth() + 1, cursor.getUTCDate()),
        inMonth: cursor.getUTCMonth() === month - 1,
      });
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }
    weeks.push(week);
  } while (cursor.getUTCMonth() === month - 1);
  return weeks;
}

export function monthLabel(year: number, month: number): string {
  return new Date(Date.UTC(year, month - 1, 1)).toLocaleDateString("en-GB", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  });
}

export function addMonths(
  year: number,
  month: number,
  delta: number,
): { year: number; month: number } {
  const total = year * 12 + (month - 1) + delta;
  return { year: Math.floor(total / 12), month: (((total % 12) + 12) % 12) + 1 };
}

/** Parses "2027-09"; falls back to the given date's month. */
export function parseMonthParam(
  value: string | undefined,
  fallback: Date,
): { year: number; month: number } {
  const m = value?.match(/^(\d{4})-(\d{2})$/);
  if (m) {
    const year = Number(m[1]);
    const month = Number(m[2]);
    if (month >= 1 && month <= 12) return { year, month };
  }
  return { year: fallback.getUTCFullYear(), month: fallback.getUTCMonth() + 1 };
}
