import { describe, expect, it } from "vitest";
import { addMonths, daysInMonth, monthGrid, monthLabel, parseMonthParam } from "@/lib/calendar";

describe("monthGrid", () => {
  it("covers September 2027 with Monday-first weeks", () => {
    const weeks = monthGrid(2027, 9);
    // 1 Sep 2027 is a Wednesday: the first week starts Mon 30 Aug.
    expect(weeks[0][0].iso).toBe("2027-08-30");
    expect(weeks[0][0].inMonth).toBe(false);
    expect(weeks[0][2].iso).toBe("2027-09-01");
    expect(weeks[0][2].inMonth).toBe(true);
    const last = weeks.at(-1)!;
    expect(last.some((c) => c.iso === "2027-09-30")).toBe(true);
    for (const week of weeks) expect(week).toHaveLength(7);
  });

  it("handles February in a leap year", () => {
    expect(daysInMonth(2028, 2)).toBe(29);
    const weeks = monthGrid(2028, 2);
    expect(weeks.flat().filter((c) => c.inMonth)).toHaveLength(29);
  });
});

describe("month helpers", () => {
  it("labels and navigates months", () => {
    expect(monthLabel(2027, 9)).toBe("September 2027");
    expect(addMonths(2027, 12, 1)).toEqual({ year: 2028, month: 1 });
    expect(addMonths(2027, 1, -1)).toEqual({ year: 2026, month: 12 });
  });

  it("parses month params with fallback", () => {
    const fb = new Date("2027-03-15T00:00:00Z");
    expect(parseMonthParam("2027-09", fb)).toEqual({ year: 2027, month: 9 });
    expect(parseMonthParam("junk", fb)).toEqual({ year: 2027, month: 3 });
    expect(parseMonthParam(undefined, fb)).toEqual({ year: 2027, month: 3 });
    expect(parseMonthParam("2027-13", fb)).toEqual({ year: 2027, month: 3 });
  });
});

import {
  chipMatchesFilter,
  chipTone,
  dayHeading,
  defaultMonth,
  shortDay,
  orderByKind,
  overdueChips,
  parseCalendarFilter,
  parseCalendarView,
  upcomingGroups,
  type CalendarChip,
} from "@/lib/calendar";

const chip = (over: Partial<CalendarChip>): CalendarChip => ({
  kind: "print",
  date: "2026-10-16",
  label: "Print deadline: Banner",
  name: "Banner",
  href: "/BIRM27/signage/SIG-1",
  mine: false,
  ...over,
});

describe("chip colours and filters", () => {
  const today = "2026-10-16";
  it("turns deadlines solid red once they have passed", () => {
    expect(chipTone(chip({ date: "2026-10-16" }), today)).toBe("deadline");
    expect(chipTone(chip({ date: "2026-10-15" }), today)).toBe("overdue");
    expect(chipTone(chip({ kind: "signoff", date: "2026-10-01" }), today)).toBe("overdue");
    expect(chipTone(chip({ kind: "delivery", date: "2026-10-01" }), today)).toBe("delivery");
    expect(chipTone(chip({ kind: "install" }), today)).toBe("install");
    expect(chipTone(chip({ kind: "event" }), today)).toBe("show");
  });

  it("filters by what a chip is about; event dates always stay", () => {
    expect(parseCalendarFilter("deliveries")).toBe("deliveries");
    expect(parseCalendarFilter("junk")).toBe("all");
    expect(parseCalendarFilter(undefined)).toBe("all");
    const kinds = [
      "event",
      "deadline",
      "artwork",
      "print",
      "sell",
      "order",
      "signoff",
      "task",
      "delivery",
      "install",
    ] as const;
    const pick = (f: Parameters<typeof chipMatchesFilter>[1]) =>
      kinds.filter((kind) => chipMatchesFilter({ kind, mine: kind === "task" }, f));
    expect(pick("all")).toEqual([...kinds]);
    expect(pick("deadlines")).toEqual(["event", "deadline", "artwork", "print", "sell", "order"]);
    expect(pick("deliveries")).toEqual(["event", "delivery", "install"]);
    expect(pick("signoffs")).toEqual(["event", "signoff"]);
    expect(pick("mine")).toEqual(["event", "task"]);
  });
});

describe("overdue strip and upcoming list", () => {
  const today = "2026-10-16";
  const chips = [
    chip({ date: "2026-09-21", kind: "signoff", label: "Sign-off due: B" }),
    chip({ date: "2026-08-01", kind: "artwork", label: "Artwork due: A" }),
    chip({ date: "2026-08-02", kind: "deadline", label: "Deadline: Artwork due" }),
    chip({ date: "2026-10-01", kind: "delivery", label: "Delivery: C" }),
    chip({ date: "2026-10-16", kind: "install", label: "Install: D" }),
    chip({ date: "2026-10-16", kind: "print", label: "Print deadline: E" }),
    chip({ date: "2026-10-17", kind: "event", label: "Build-up starts" }),
    chip({ date: "2026-11-14", kind: "task", label: "Task due: F" }),
    chip({ date: "2026-11-15", kind: "task", label: "Task due: G" }),
  ];

  it("lists every passed item deadline, oldest first, whatever the month", () => {
    expect(overdueChips(chips, today).map((c) => c.label)).toEqual([
      "Artwork due: A",
      "Sign-off due: B",
    ]);
  });

  it("groups the next 30 days under Today, Tomorrow and dates", () => {
    const groups = upcomingGroups(chips, today);
    expect(groups.map((g) => [g.heading, g.chips.map((c) => c.label)])).toEqual([
      ["Today", ["Print deadline: E", "Install: D"]],
      ["Tomorrow", ["Build-up starts"]],
      ["Saturday 14 November", ["Task due: F"]],
    ]);
    expect(upcomingGroups(chips, today, 31).at(-1)?.heading).toBe("Sunday 15 November");
  });

  it("writes day headings", () => {
    expect(dayHeading("2026-10-15", today)).toBe("Yesterday");
    expect(dayHeading("2026-10-19", today)).toBe("Monday 19 October");
    expect(dayHeading("2027-10-01", today)).toBe("Friday 1 October 2027");
    expect(shortDay(today, today)).toBe("Today");
    expect(shortDay("2026-10-17", today)).toBe("Tomorrow");
    expect(shortDay("2026-10-19", today)).toBe("Mon 19 Oct");
  });
});

describe("defaultMonth and views", () => {
  it("opens this month when something is on, else the next month with something", () => {
    expect(defaultMonth(["2026-10-30"], "2026-10-16")).toEqual({ year: 2026, month: 10 });
    expect(defaultMonth(["2026-10-01"], "2026-10-16")).toEqual({ year: 2026, month: 10 });
    expect(defaultMonth(["2026-08-01", "2027-10-01", "2027-01-05"], "2026-10-16")).toEqual({
      year: 2027,
      month: 1,
    });
    expect(defaultMonth(["2026-08-01"], "2026-10-16")).toEqual({ year: 2026, month: 10 });
    expect(defaultMonth([], "2026-10-16")).toEqual({ year: 2026, month: 10 });
  });

  it("parses the view", () => {
    expect(parseCalendarView("month")).toBe("month");
    expect(parseCalendarView("upcoming")).toBe("upcoming");
    expect(parseCalendarView("grid")).toBeNull();
    expect(parseCalendarView(undefined)).toBeNull();
  });
});

describe("orderByKind", () => {
  it("is Sell by until sold, Order by after, and nothing once ordered", () => {
    expect(orderByKind({ kind: "sponsorship_item", sponsorId: null, status: "draft" })).toBe(
      "sell",
    );
    expect(orderByKind({ kind: "sponsorship_item", sponsorId: "s", status: "approved" })).toBe(
      "order",
    );
    expect(orderByKind({ kind: "signage", sponsorId: null, status: "draft" })).toBe("order");
    expect(
      orderByKind({ kind: "sponsorship_item", sponsorId: "s", status: "in_production" }),
    ).toBeNull();
    expect(
      orderByKind({ kind: "sponsorship_item", sponsorId: null, status: "rejected" }),
    ).toBeNull();
  });
});
