/**
 * Which event is "current" when the address doesn't say, where each event
 * is in its life, naming a new event, and "Add several" halls. Pure.
 */
import { describe, expect, it } from "vitest";
import { eventGroup, eventPhase, pickDefaultEdition, sortForGroup } from "@/lib/queries/editions";
import { bumpYear, exampleSignRef, seriesNameFor, suggestCode } from "@/components/setup/naming";
import { dateRange, dateRangeWithYear, shortDate, weekdayDate } from "@/components/setup/format";
import { describeBulk, parseBulkHalls } from "@/components/halls/bulk";

const ev = (code: string, openStart: string, openEnd: string, status = "planning") => ({
  code,
  status,
  openStart,
  openEnd,
});

describe("the default event", () => {
  const today = "2026-10-14";
  const past = ev("BIRM26", "2026-03-03", "2026-03-05");
  const soon = ev("LON27", "2027-03-02", "2027-03-04");
  const later = ev("BIRM27", "2027-10-05", "2027-10-07");
  const live = ev("NOW26", "2026-10-13", "2026-10-15");

  it("is the one last opened", () => {
    expect(pickDefaultEdition([past, soon, later], { lastCode: "BIRM27", today })).toBe("BIRM27");
    expect(pickDefaultEdition([past, soon, later], { lastCode: "birm27", today })).toBe("BIRM27");
  });

  it("otherwise the earliest that hasn't closed yet (one open today counts)", () => {
    expect(pickDefaultEdition([later, past, soon], { today })).toBe("LON27");
    expect(pickDefaultEdition([later, live, soon], { lastCode: null, today })).toBe("NOW26");
  });

  it("otherwise the most recent past one", () => {
    const older = ev("BIRM25", "2025-03-03", "2025-03-05");
    expect(pickDefaultEdition([older, past], { today })).toBe("BIRM26");
  });

  it("ignores a remembered event that no longer exists", () => {
    expect(pickDefaultEdition([past, soon], { lastCode: "GONE", today })).toBe("LON27");
  });

  it("never picks an archived event while a live one exists", () => {
    const archived = ev("OLD", "2027-01-01", "2027-01-02", "archived");
    expect(pickDefaultEdition([archived, later], { lastCode: "OLD", today })).toBe("BIRM27");
    expect(pickDefaultEdition([archived, past], { today })).toBe("BIRM26");
  });

  it("falls back to archived events only when there's nothing else", () => {
    const a = ev("A", "2025-01-01", "2025-01-02", "archived");
    const b = ev("B", "2026-01-01", "2026-01-02", "archived");
    expect(pickDefaultEdition([a, b], { today })).toBe("B");
    expect(pickDefaultEdition([], { today })).toBeNull();
  });
});

describe("event phase", () => {
  const dates = {
    status: "planning",
    buildStart: "2027-10-01",
    openStart: "2027-10-05",
    openEnd: "2027-10-07",
    breakdownEnd: "2027-10-08",
  };
  it.each([
    ["2027-09-30", "planning"],
    ["2027-10-01", "build_up"],
    ["2027-10-04", "build_up"],
    ["2027-10-05", "open"],
    ["2027-10-07", "open"],
    ["2027-10-08", "breakdown"],
    ["2027-10-09", "finished"],
  ])("on %s it is %s", (today, phase) => {
    expect(eventPhase(dates, today)).toBe(phase);
  });
  it("archived stays archived", () => {
    expect(eventPhase({ ...dates, status: "archived" }, "2027-10-05")).toBe("archived");
  });
  it("groups into upcoming & live until breakdown ends, then past", () => {
    expect(eventGroup(dates, "2027-10-08")).toBe("upcoming");
    expect(eventGroup(dates, "2027-10-09")).toBe("past");
    expect(eventGroup({ ...dates, status: "archived" }, "2027-01-01")).toBe("archived");
  });
  it("sorts upcoming soonest first and the rest newest first", () => {
    const rows = [
      { code: "B", openStart: "2027-10-05" },
      { code: "A", openStart: "2027-03-01" },
    ];
    expect(sortForGroup(rows, "upcoming").map((r) => r.code)).toEqual(["A", "B"]);
    expect(sortForGroup(rows, "past").map((r) => r.code)).toEqual(["B", "A"]);
  });
});

describe("naming a new event", () => {
  it("suggests a reference code from the name", () => {
    expect(suggestCode("UKCW London 2027")).toBe("UKCWLON27");
    expect(suggestCode("Build Show Manchester 2028")).toBe("BUISHOWMAN28");
    expect(suggestCode("Expo")).toBe("EXPO");
    expect(suggestCode("")).toBe("EVENT");
    expect(suggestCode("!!")).toBe("EVENT");
  });
  it("never suggests a code already taken", () => {
    expect(suggestCode("UKCW London 2027", ["UKCWLON27"])).toBe("UKCWLON27-2");
    expect(suggestCode("UKCW London 2027", ["ukcwlon27", "UKCWLON27-2"])).toBe("UKCWLON27-3");
  });
  it("moves the year on for a copy", () => {
    expect(bumpYear("UKCW Birmingham 2027")).toBe("UKCW Birmingham 2028");
    expect(bumpYear("2027 Expo (from 2026)")).toBe("2027 Expo (from 2027)");
    expect(bumpYear("Spring Expo")).toBe("Spring Expo");
  });
  it("names the series after the event without its year", () => {
    expect(seriesNameFor("UKCW London 2027")).toBe("UKCW London");
    expect(seriesNameFor("2027 – Spring Expo")).toBe("Spring Expo");
    expect(seriesNameFor("Grand Designs Live")).toBe("Grand Designs Live");
    expect(seriesNameFor("2027")).toBe("2027");
  });
  it("shows what sign refs will look like", () => {
    expect(exampleSignRef("LON27")).toBe("SIG-LON27-001");
    expect(exampleSignRef("")).toBe("SIG-CODE-001");
  });
});

describe("short dates", () => {
  it("writes ranges the British way", () => {
    expect(dateRange("2027-10-03", "2027-10-04")).toBe("3–4 Oct");
    expect(dateRange("2027-09-30", "2027-10-01")).toMatch(/^30 Sept? – 1 Oct$/);
    expect(dateRange("2027-10-05", "2027-10-05")).toBe("5 Oct");
    expect(dateRangeWithYear("2027-10-05", "2027-10-07")).toBe("5–7 Oct 2027");
    expect(dateRangeWithYear("2027-12-31", "2028-01-02")).toMatch(/^31 Dec 2027 – 2 Jan 2028$/);
    expect(shortDate("2027-10-08")).toBe("8 Oct");
    expect(weekdayDate("2027-09-10")).toMatch(/^Fri,? 10 Sept? 2027$/);
    expect(shortDate("nope")).toBe("—");
  });
});

describe("adding several halls at once", () => {
  it("reads one hall per line with its locations after a colon", () => {
    expect(
      parseBulkHalls("Hall 1: Main entrance, Registration\n\n  Hall 2  \nHall 3: Seminar theatre"),
    ).toEqual([
      { name: "Hall 1", locations: ["Main entrance", "Registration"] },
      { name: "Hall 2", locations: [] },
      { name: "Hall 3", locations: ["Seminar theatre"] },
    ]);
  });
  it("merges a hall named twice and drops repeats and blanks", () => {
    expect(parseBulkHalls("Hall 1: A, a, , B\nhall 1: C\n: orphan")).toEqual([
      { name: "Hall 1", locations: ["A", "B", "C"] },
    ]);
  });
  it("describes what will be added", () => {
    expect(describeBulk(parseBulkHalls("Hall 1: A, B\nHall 2"))).toBe("2 halls and 2 locations");
    expect(describeBulk(parseBulkHalls("Hall 1"))).toBe("1 hall");
  });
});
