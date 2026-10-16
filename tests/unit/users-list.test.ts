/**
 * The Users list's words and filters (lib/users/list.ts): one status per
 * row, "Last active" in London days, the manager badge, and the ?dept,
 * ?role (incl. manager), ?status and ?activity=stale filters.
 */
import { describe, expect, it } from "vitest";
import {
  daysSinceActive,
  filterPeople,
  isStale,
  lastActiveText,
  managerBadgeText,
  parseStatusFilter,
  PERSON_STATUS_CLASSES,
  PERSON_STATUSES,
  personStatus,
  STATUS_FILTERS,
  type ListPerson,
} from "@/lib/users/list";

// 16 Oct 2026, 10:00 in London (BST, UTC+1).
const NOW = new Date("2026-10-16T09:00:00Z");

describe("personStatus", () => {
  it("is the row's status, with 'ending' for active people who have an end date", () => {
    expect(personStatus({ status: "active", accessEndsAt: null })).toBe("active");
    expect(personStatus({ status: "active", accessEndsAt: new Date("2026-11-01") })).toBe("ending");
    expect(personStatus({ status: "suspended", accessEndsAt: new Date("2026-11-01") })).toBe(
      "suspended",
    );
    expect(personStatus({ status: "ended", accessEndsAt: new Date("2026-10-01") })).toBe("ended");
    expect(personStatus({ status: "expired", accessEndsAt: null })).toBe("expired");
  });

  it("has one distinct colour per status and a filter for each", () => {
    const tones = PERSON_STATUSES.map((s) => PERSON_STATUS_CLASSES[s]);
    expect(new Set(tones).size).toBe(PERSON_STATUSES.length);
    expect(STATUS_FILTERS.map((f) => f.value).filter(Boolean)).toEqual(
      expect.arrayContaining([...PERSON_STATUSES]),
    );
    expect(parseStatusFilter("suspended")).toBe("suspended");
    expect(parseStatusFilter("bogus")).toBeUndefined();
    expect(parseStatusFilter(undefined)).toBeUndefined();
  });
});

describe("lastActiveText", () => {
  it("says Today and Yesterday by London date, not 24 hours", () => {
    // 00:30 London on the 16th is still today; 23:30 London on the 15th is yesterday.
    expect(lastActiveText(new Date("2026-10-15T23:30:00Z"), NOW)).toBe("Today");
    expect(lastActiveText(new Date("2026-10-15T22:30:00Z"), NOW)).toBe("Yesterday");
  });

  it("counts days up to a week, then shows the date", () => {
    expect(lastActiveText(new Date("2026-10-13T12:00:00Z"), NOW)).toBe("3 days ago");
    expect(lastActiveText(new Date("2026-10-10T12:00:00Z"), NOW)).toBe("6 days ago");
    expect(lastActiveText(new Date("2026-10-09T12:00:00Z"), NOW)).toBe("9 Oct");
    expect(lastActiveText(new Date("2025-12-24T12:00:00Z"), NOW)).toBe("24 Dec 2025");
  });

  it("says Never signed in when there's no record", () => {
    expect(lastActiveText(null, NOW)).toBe("Never signed in");
    expect(daysSinceActive(null, NOW)).toBeNull();
  });

  it("treats 30 days or more, or never, as not active lately (members only)", () => {
    const member = (lastSeenAt: Date | null) => ({ kind: "member" as const, lastSeenAt });
    expect(isStale(member(new Date("2026-09-16T12:00:00Z")), NOW)).toBe(true);
    expect(isStale(member(new Date("2026-09-17T12:00:00Z")), NOW)).toBe(false);
    expect(isStale(member(null), NOW)).toBe(true);
    expect(isStale({ kind: "invite", lastSeenAt: null }, NOW)).toBe(false);
  });
});

describe("managerBadgeText", () => {
  it("names the department or everyone, and never super admins", () => {
    expect(managerBadgeText({ role: "marketing", managerScope: "department" }, "Marketing")).toBe(
      "Manager · Marketing",
    );
    expect(managerBadgeText({ role: "ops", managerScope: "everyone" }, null)).toBe(
      "Manager · everyone",
    );
    expect(managerBadgeText({ role: "ops", managerScope: null }, "Operations")).toBeNull();
    expect(managerBadgeText({ role: "admin", managerScope: "everyone" }, null)).toBeNull();
  });
});

describe("filterPeople", () => {
  const base: ListPerson = {
    kind: "member",
    name: "Sam Smith",
    email: "sam@x.test",
    jobTitle: "Designer",
    role: "marketing",
    departmentId: "mkt",
    departmentArchived: false,
    status: "active",
    managerScope: null,
    accessEndsAt: null,
    lastSeenAt: new Date("2026-10-15T12:00:00Z"),
  };
  const rows: (ListPerson & { id: string })[] = [
    { ...base, id: "sam" },
    { ...base, id: "mona", name: "Mona", managerScope: "department" },
    {
      ...base,
      id: "olly",
      name: "Olly",
      role: "ops",
      departmentId: "ops",
      managerScope: "everyone",
    },
    { ...base, id: "ada", name: "Ada", role: "admin", departmentId: null },
    { ...base, id: "sus", name: "Sue", status: "suspended" },
    { ...base, id: "end", name: "Ed", status: "ended" },
    { ...base, id: "fin", name: "Fin", accessEndsAt: new Date("2026-12-01") },
    { ...base, id: "inv", name: "Ivy", kind: "invite", status: "invited", lastSeenAt: null },
    { ...base, id: "exp", name: "Exp", kind: "invite", status: "expired", lastSeenAt: null },
    { ...base, id: "old", name: "Old", lastSeenAt: new Date("2026-08-01T12:00:00Z") },
    { ...base, id: "arc", name: "Arc", departmentArchived: true },
  ];
  const ids = (f: Parameters<typeof filterPeople>[1]) =>
    filterPeople(rows, f, NOW).map((r) => r.id);

  it("searches names, emails and job titles", () => {
    expect(ids({ q: "olly" })).toEqual(["olly"]);
    expect(ids({ q: "DESIGNER" })).toHaveLength(rows.length);
  });

  it("filters by department, or people without a live one", () => {
    expect(ids({ dept: "ops" })).toEqual(["olly"]);
    expect(ids({ dept: "none" })).toEqual(["ada", "arc"]);
  });

  it("filters by role, and role=manager for managers (not super admins)", () => {
    expect(ids({ role: "admin" })).toEqual(["ada"]);
    expect(ids({ role: "manager" })).toEqual(["mona", "olly"]);
  });

  it("filters by status: Active includes people whose end date is ahead", () => {
    expect(ids({ status: "active" })).toEqual(
      expect.arrayContaining(["sam", "mona", "olly", "ada", "fin", "old", "arc"]),
    );
    expect(ids({ status: "active" })).not.toContain("sus");
    expect(ids({ status: "ending" })).toEqual(["fin"]);
    expect(ids({ status: "suspended" })).toEqual(["sus"]);
    expect(ids({ status: "ended" })).toEqual(["end"]);
    expect(ids({ status: "invited" })).toEqual(["inv"]);
    expect(ids({ status: "expired" })).toEqual(["exp"]);
  });

  it("filters members not active for 30 days", () => {
    expect(ids({ activity: "stale" })).toEqual(["old"]);
  });

  it("combines filters", () => {
    expect(ids({ dept: "mkt", role: "manager" })).toEqual(["mona"]);
    expect(ids({ dept: "mkt", status: "suspended", q: "sue" })).toEqual(["sus"]);
  });
});
