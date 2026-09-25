import { describe, expect, it } from "vitest";
import { orderCountdown } from "@/lib/countdown";

describe("order-by countdown", () => {
  it("counts months and days", () => {
    const c = orderCountdown("2026-12-01", "2026-09-25", false);
    expect([c.months, c.days]).toEqual([2, 6]);
    expect(c.label).toBe("2 months 6 days left");
    expect(c.tone).toBe("ok");
    expect(c.warning).toBeNull();
  });

  it("warns when there is under a month to sell", () => {
    const c = orderCountdown("2026-10-10", "2026-09-25", false);
    expect(c.label).toBe("15 days left");
    expect(c.tone).toBe("urgent");
    expect(c.warning).toBe("Less than 1 month to sell");
  });

  it("exactly one month is not yet a warning", () => {
    const c = orderCountdown("2026-10-25", "2026-09-25", false);
    expect(c.label).toBe("1 month left");
    expect(c.warning).toBeNull();
  });

  it("sold items only need ordering: amber, no selling warning", () => {
    const c = orderCountdown("2026-10-10", "2026-09-25", true);
    expect(c.tone).toBe("soon");
    expect(c.warning).toBeNull();
  });

  it("today and past dates", () => {
    expect(orderCountdown("2026-09-25", "2026-09-25", false).label).toBe("Order today");
    const past = orderCountdown("2026-09-21", "2026-09-25", false);
    expect(past.label).toBe("4 days overdue");
    expect(past.tone).toBe("overdue");
    expect(past.warning).toBe("Order date has passed");
    expect(orderCountdown("2026-09-24", "2026-09-25", true).label).toBe("1 day overdue");
  });

  it("handles month ends", () => {
    const c = orderCountdown("2027-02-28", "2027-01-31", false);
    expect(c.label).toBe("1 month left");
  });
});
