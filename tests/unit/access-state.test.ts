/**
 * Access state (Users v2), written before lib/access.ts: suspended people and
 * people whose access end date has passed can't sign in, aren't told about
 * anything and can't be handed sign-offs. End dates are London dates.
 */
import { describe, expect, it } from "vitest";
import {
  accessBlockMessage,
  accessEndPlan,
  accessEndsAtFromLondonDate,
  accessLive,
  accessState,
  canReceiveSignoff,
  londonDateOfAccessEnd,
} from "@/lib/access";

const now = new Date("2026-10-16T12:00:00Z");

describe("accessState", () => {
  it("active with nothing set", () => {
    expect(accessState({}, now)).toBe("active");
    expect(accessState({ suspendedAt: null, accessEndsAt: null }, now)).toBe("active");
  });
  it("suspended whenever suspendedAt is set", () => {
    expect(accessState({ suspendedAt: new Date("2026-10-01") }, now)).toBe("suspended");
    // Suspension is named even when the end date has also passed.
    expect(
      accessState(
        { suspendedAt: new Date("2026-10-01"), accessEndsAt: new Date("2026-10-02") },
        now,
      ),
    ).toBe("suspended");
  });
  it("ended once the end date is reached — equal to now counts as ended", () => {
    expect(accessState({ accessEndsAt: new Date(now.getTime()) }, now)).toBe("ended");
    expect(accessState({ accessEndsAt: new Date(now.getTime() - 1) }, now)).toBe("ended");
    expect(accessState({ accessEndsAt: new Date(now.getTime() + 1) }, now)).toBe("active");
  });
  it("accessLive is accessState === active", () => {
    expect(accessLive({}, now)).toBe(true);
    expect(accessLive({ accessEndsAt: now }, now)).toBe(false);
    expect(accessLive({ suspendedAt: now }, now)).toBe(false);
  });
});

describe("canReceiveSignoff", () => {
  const p = { role: "marketing" as const, overrides: {}, suspendedAt: null, accessEndsAt: null };
  it("an active, unpaused team member can", () => {
    expect(canReceiveSignoff(p, now)).toBe(true);
    expect(canReceiveSignoff({ ...p, role: "admin" }, now)).toBe(true);
  });
  it("viewers can't", () => {
    expect(canReceiveSignoff({ ...p, role: "viewer" }, now)).toBe(false);
  });
  it("a paused sign-off can't", () => {
    expect(canReceiveSignoff({ ...p, overrides: { "approval.decide": false } }, now)).toBe(false);
  });
  it("suspended or ended people can't", () => {
    expect(canReceiveSignoff({ ...p, suspendedAt: new Date("2026-10-01") }, now)).toBe(false);
    expect(canReceiveSignoff({ ...p, accessEndsAt: now }, now)).toBe(false);
    expect(canReceiveSignoff({ ...p, accessEndsAt: new Date("2026-10-17") }, now)).toBe(true);
  });
});

describe("access end dates are the end of that London day", () => {
  it("in summer time", () => {
    expect(accessEndsAtFromLondonDate("2026-10-16").toISOString()).toBe("2026-10-16T22:59:59.999Z");
  });
  it("in winter time, including the day the clocks go back", () => {
    expect(accessEndsAtFromLondonDate("2026-12-01").toISOString()).toBe("2026-12-01T23:59:59.999Z");
    expect(accessEndsAtFromLondonDate("2026-10-25").toISOString()).toBe("2026-10-25T23:59:59.999Z");
    expect(accessEndsAtFromLondonDate("2026-03-29").toISOString()).toBe("2026-03-29T22:59:59.999Z");
  });
  it("round-trips to the London date", () => {
    for (const d of ["2026-10-16", "2026-10-25", "2026-03-29", "2027-01-01"]) {
      expect(londonDateOfAccessEnd(accessEndsAtFromLondonDate(d))).toBe(d);
    }
  });
  it("refuses something that isn't a date", () => {
    expect(() => accessEndsAtFromLondonDate("16/10/2026")).toThrow();
    expect(() => accessEndsAtFromLondonDate("2026-02-30")).toThrow();
  });
  it("the person still has access during their last day", () => {
    const end = accessEndsAtFromLondonDate("2026-10-16");
    expect(accessState({ accessEndsAt: end }, new Date("2026-10-16T22:00:00Z"))).toBe("active");
    expect(accessState({ accessEndsAt: end }, new Date("2026-10-16T23:00:00Z"))).toBe("ended");
  });
});

describe("what the sign-in page says", () => {
  it("names the person to ask", () => {
    expect(accessBlockMessage({ state: "suspended", askName: "Sam Smith" })).toBe(
      "Your access is paused — ask Sam Smith",
    );
    expect(accessBlockMessage({ state: "ended", askName: "Sam Smith" })).toBe(
      "Your access has ended — ask Sam Smith",
    );
  });
  it("falls back to a super admin when nobody is named", () => {
    expect(accessBlockMessage({ state: "suspended", askName: null })).toBe(
      "Your access is paused — ask a super admin",
    );
  });
});

describe("the daily access-end job's plan", () => {
  const now = new Date("2026-10-17T06:00:00Z");
  const today = "2026-10-17";
  const row = (
    id: string,
    end: string | null,
    extra: Partial<Parameters<typeof accessEndPlan>[0][number]> = {},
  ) => ({
    id,
    accessEndsAt: end ? accessEndsAtFromLondonDate(end) : null,
    suspendedAt: null,
    endedRecordedAt: null,
    ...extra,
  });
  it("records an end that has passed, once", () => {
    const ended = row("a", "2026-10-16");
    expect(accessEndPlan([ended], { now, today }).ended).toEqual(["a"]);
    const recorded = { ...ended, endedRecordedAt: new Date("2026-10-17T05:00:00Z") };
    expect(accessEndPlan([recorded], { now, today }).ended).toEqual([]);
    // Moved to a later date that has also passed: recorded again.
    const moved = { ...recorded, accessEndsAt: new Date("2026-10-17T05:30:00Z") };
    expect(accessEndPlan([moved], { now, today }).ended).toEqual(["a"]);
  });
  it("leaves people whose end is still to come, or who have none", () => {
    expect(accessEndPlan([row("b", "2026-10-17"), row("c", null)], { now, today })).toEqual({
      ended: [],
      warn: [],
    });
  });
  it("warns a week ahead, not for suspended people", () => {
    expect(accessEndPlan([row("d", "2026-10-24")], { now, today }).warn).toEqual(["d"]);
    expect(accessEndPlan([row("e", "2026-10-25")], { now, today }).warn).toEqual([]);
    expect(
      accessEndPlan([row("f", "2026-10-24", { suspendedAt: new Date() })], { now, today }).warn,
    ).toEqual([]);
  });
});
