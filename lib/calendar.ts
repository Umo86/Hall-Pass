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

// ---------------------------------------------------------------------------
// What the calendar shows (pure; tests/unit/calendar.test.ts). The page
// builds one chip per dated thing; these rules decide its colour, which
// filter it belongs to, what is overdue, and what the phone list shows.

/** What a chip is about; drives its icon, colour and filter. */
export type ChipKind =
  | "event"
  | "deadline"
  | "artwork"
  | "print"
  | "sell"
  | "order"
  | "signoff"
  | "task"
  | "delivery"
  | "install";

export type CalendarChip = {
  kind: ChipKind;
  date: string;
  /** The full words: "Print deadline: Hall 1 entrance banner". */
  label: string;
  /** What the chip shows after its icon: the item name, or the label. */
  name: string;
  href: string | null;
  /** Mine: an item I own, a sign-off waiting on me, or my own task. */
  mine: boolean;
};

/** Things with a date that must be met: all red. */
const RED_KINDS: ChipKind[] = ["deadline", "artwork", "print", "sell", "order", "signoff", "task"];

export function isDeadlineChip(kind: ChipKind): boolean {
  return RED_KINDS.includes(kind);
}

export type ChipTone = "deadline" | "overdue" | "show" | "delivery" | "install";

/** Every deadline is red, solid once it has passed; the rest by type. */
export function chipTone(chip: Pick<CalendarChip, "kind" | "date">, today: string): ChipTone {
  if (isDeadlineChip(chip.kind)) return chip.date < today ? "overdue" : "deadline";
  if (chip.kind === "delivery") return "delivery";
  if (chip.kind === "install") return "install";
  return "show";
}

export const CALENDAR_FILTERS = ["all", "deadlines", "deliveries", "signoffs", "mine"] as const;
export type CalendarFilter = (typeof CALENDAR_FILTERS)[number];

export const CALENDAR_FILTER_LABELS: Record<CalendarFilter, string> = {
  all: "Everything",
  deadlines: "Deadlines",
  deliveries: "Deliveries & installs",
  signoffs: "Sign-offs",
  mine: "Only mine",
};

export function parseCalendarFilter(value: string | undefined | null): CalendarFilter {
  return (CALENDAR_FILTERS as readonly string[]).includes(value ?? "")
    ? (value as CalendarFilter)
    : "all";
}

/** Event dates stay on every view so the month keeps its bearings. */
export function chipMatchesFilter(chip: Pick<CalendarChip, "kind" | "mine">, f: CalendarFilter) {
  if (chip.kind === "event") return true;
  switch (f) {
    case "deadlines":
      return ["deadline", "artwork", "print", "sell", "order"].includes(chip.kind);
    case "deliveries":
      return chip.kind === "delivery" || chip.kind === "install";
    case "signoffs":
      return chip.kind === "signoff";
    case "mine":
      return chip.mine;
    default:
      return true;
  }
}

/** The event's own deadlines first on each day, then the rest of the red, then the others. */
const KIND_RANK: Record<ChipKind, number> = {
  deadline: 0,
  signoff: 1,
  task: 2,
  artwork: 3,
  print: 4,
  sell: 5,
  order: 6,
  event: 7,
  delivery: 8,
  install: 9,
};

export function sortChips<T extends Pick<CalendarChip, "kind" | "date" | "label">>(chips: T[]) {
  return [...chips].sort(
    (a, b) =>
      a.date.localeCompare(b.date) ||
      KIND_RANK[a.kind] - KIND_RANK[b.kind] ||
      a.label.localeCompare(b.label, "en-GB"),
  );
}

/**
 * The backlog: every deadline dated before today. Item chips are only made
 * for work still open, so anything here still needs doing. The event's own
 * deadlines are left out: once passed they stay on their day in the month,
 * and the items behind them are listed here themselves. Oldest first.
 */
export function overdueChips<T extends CalendarChip>(chips: T[], today: string): T[] {
  return sortChips(
    chips.filter((c) => isDeadlineChip(c.kind) && c.kind !== "deadline" && c.date < today),
  );
}

const DAY_MS = 86_400_000;

function addDays(isoDate: string, days: number): string {
  const [y, m, d] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d) + days * DAY_MS).toISOString().slice(0, 10);
}

/** "Today", "Tomorrow", "Yesterday", else "Monday 19 October" (with the year when it differs). */
export function dayHeading(isoDate: string, today: string): string {
  if (isoDate === today) return "Today";
  if (isoDate === addDays(today, 1)) return "Tomorrow";
  if (isoDate === addDays(today, -1)) return "Yesterday";
  const [y, m, d] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d))
    .toLocaleDateString("en-GB", {
      weekday: "long",
      day: "numeric",
      month: "long",
      ...(isoDate.slice(0, 4) !== today.slice(0, 4) ? { year: "numeric" } : {}),
      timeZone: "UTC",
    })
    .replace(",", "");
}

/** For narrow columns: "Today", "Tomorrow", else "Mon 19 Oct". */
export function shortDay(isoDate: string, today: string): string {
  if (isoDate === today) return "Today";
  if (isoDate === addDays(today, 1)) return "Tomorrow";
  const [y, m, d] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d))
    .toLocaleDateString("en-GB", {
      weekday: "short",
      day: "numeric",
      month: "short",
      timeZone: "UTC",
    })
    .replace(",", "");
}

export type DayGroup<T> = { date: string; heading: string; chips: T[] };

/** Days from today with something on, for the next `days` days (today included). */
export function upcomingGroups<T extends CalendarChip>(
  chips: T[],
  today: string,
  days = 30,
): DayGroup<T>[] {
  const end = addDays(today, days - 1);
  const groups = new Map<string, T[]>();
  for (const chip of sortChips(chips.filter((c) => c.date >= today && c.date <= end))) {
    groups.set(chip.date, [...(groups.get(chip.date) ?? []), chip]);
  }
  return [...groups.entries()].map(([date, list]) => ({
    date,
    heading: dayHeading(date, today),
    chips: list,
  }));
}

/**
 * The month to open on: this month when something is on in it, else the
 * month of the next thing coming up, else this month.
 */
export function defaultMonth(dates: string[], today: string): { year: number; month: number } {
  const current = today.slice(0, 7);
  const pick = (ym: string) => ({ year: Number(ym.slice(0, 4)), month: Number(ym.slice(5, 7)) });
  if (dates.some((d) => d.startsWith(current))) return pick(current);
  const next = dates.filter((d) => d >= today).sort()[0];
  return pick(next ? next.slice(0, 7) : current);
}

export type CalendarView = "upcoming" | "month";

/** `?view=`: null means the default (Upcoming on phones, the month on wider screens). */
export function parseCalendarView(value: string | undefined | null): CalendarView | null {
  return value === "upcoming" || value === "month" ? value : null;
}

const ORDERED = ["in_production", "delivered", "installed", "snagged", "closed", "rejected"];

/**
 * An item's order-by date: a sponsorship item still for sale must be sold
 * by then ("Sell by"); anything else must be ordered ("Order by"). Once
 * sent to print or later it no longer counts.
 */
export function orderByKind(item: {
  kind: string;
  sponsorId: string | null;
  status: string;
}): "sell" | "order" | null {
  const status = item.status;
  if (ORDERED.includes(status)) return null;
  return item.kind === "sponsorship_item" && !item.sponsorId ? "sell" : "order";
}
