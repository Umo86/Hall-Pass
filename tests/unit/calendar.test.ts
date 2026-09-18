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
