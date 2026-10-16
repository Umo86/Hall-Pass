import { describe, expect, it } from "vitest";
import {
  budgetSummary,
  dateRange,
  deadlineWorkLabel,
  eventCountdown,
  lateLabel,
  nextStepRows,
  onsiteSoon,
  overdueArtworkSignoffs,
  signageProgress,
  sponsorshipSummary,
  waitingOnLabel,
  type SponsorshipDashRow,
} from "@/components/dashboard/rules";
import { deadlineHref } from "@/lib/edition-path";

const dates = {
  status: "planning",
  buildStart: "2027-10-01",
  openStart: "2027-10-05",
  openEnd: "2027-10-07",
  breakdownEnd: "2027-10-08",
};

describe("eventCountdown", () => {
  it("counts down to build-up", () => {
    expect(eventCountdown(dates, "2026-10-14")).toEqual({
      label: "Build-up starts in 352 days",
      tone: "planning",
    });
    expect(eventCountdown(dates, "2027-09-30").label).toBe("Build-up starts tomorrow");
  });

  it("says when it opens during build-up", () => {
    expect(eventCountdown(dates, "2027-10-01")).toEqual({
      label: "Build-up now · opens in 4 days",
      tone: "build_up",
    });
    expect(eventCountdown(dates, "2027-10-04").label).toBe("Build-up now · opens tomorrow");
  });

  it("counts the open days", () => {
    expect(eventCountdown(dates, "2027-10-05")).toEqual({
      label: "Open now: day 1 of 3",
      tone: "open",
    });
    expect(eventCountdown(dates, "2027-10-06").label).toBe("Open now: day 2 of 3");
    expect(eventCountdown({ ...dates, openEnd: "2027-10-05" }, "2027-10-05").label).toBe(
      "Open today",
    );
  });

  it("counts down breakdown and then says it is over", () => {
    expect(eventCountdown(dates, "2027-10-08")).toEqual({
      label: "Breakdown ends today",
      tone: "breakdown",
    });
    expect(eventCountdown({ ...dates, breakdownEnd: "2027-10-09" }, "2027-10-08").label).toBe(
      "Breakdown ends tomorrow",
    );
    expect(eventCountdown(dates, "2027-10-09").label).toBe("Finished yesterday");
    expect(eventCountdown(dates, "2027-10-20").label).toBe("Finished 12 days ago");
  });

  it("archived wins over the dates", () => {
    expect(eventCountdown({ ...dates, status: "archived" }, "2027-10-06")).toEqual({
      label: "Archived",
      tone: "archived",
    });
  });
});

describe("dateRange", () => {
  it("writes the shortest clear range", () => {
    expect(dateRange("2027-10-01", "2027-10-04")).toBe("1–4 Oct 2027");
    expect(dateRange("2027-09-28", "2027-10-04")).toBe("28 Sept – 4 Oct 2027");
    expect(dateRange("2027-12-30", "2028-01-02")).toBe("30 Dec 2027 – 2 Jan 2028");
    expect(dateRange("2027-10-05", "2027-10-05")).toBe("5 Oct 2027");
  });
});

describe("budgetSummary", () => {
  it("has nothing to say without a budget", () => {
    expect(budgetSummary({ budget: null, estimate: "100", actual: "0" })).toEqual({
      state: "none",
    });
  });

  it("flags an estimate over budget", () => {
    expect(budgetSummary({ budget: "85000", estimate: "91270", actual: "0" })).toEqual({
      state: "over",
      budget: 85000,
      forecast: 91270,
      basis: "estimate",
      difference: 6270,
      pct: 100,
    });
  });

  it("shows what is left, using actuals once they pass the estimate", () => {
    const s = budgetSummary({ budget: "10000", estimate: "4000", actual: "5000" });
    expect(s).toMatchObject({ state: "under", forecast: 5000, basis: "actual", difference: 5000 });
    expect(s.state !== "none" && s.pct).toBe(50);
    expect(budgetSummary({ budget: 500, estimate: 500, actual: null }).state).toBe("on");
  });

  it("a zero budget with any spend is over", () => {
    expect(budgetSummary({ budget: "0", estimate: "10", actual: "0" })).toMatchObject({
      state: "over",
      pct: 100,
    });
  });
});

describe("signageProgress", () => {
  it("groups statuses into the four stages and keeps Rejected apart", () => {
    const p = signageProgress({
      draft: 40,
      awaiting_artwork: 3,
      on_hold: 1,
      in_review: 21,
      changes_requested: 2,
      approved: 40,
      in_production: 2,
      delivered: 2,
      installed: 21,
      closed: 13,
      rejected: 16,
    });
    expect(p.total).toBe(145);
    expect(p.rejected).toBe(16);
    expect(p.stages.map((s) => [s.key, s.count])).toEqual([
      ["getting_ready", 44],
      ["in_signoff", 23],
      ["production", 44],
      ["onsite", 34],
    ]);
    expect(p.stages[0].label).toBe("Getting ready");
    // Only statuses with something in them are listed.
    expect(p.stages[3].statuses).toEqual([
      { status: "installed", count: 21 },
      { status: "closed", count: 13 },
    ]);
    expect(p.stages.reduce((n, s) => n + s.pct, 0)).toBeGreaterThanOrEqual(99);
  });

  it("copes with no signs", () => {
    const p = signageProgress({});
    expect(p.total).toBe(0);
    expect(p.stages.every((s) => s.count === 0 && s.pct === 0)).toBe(true);
  });
});

describe("deadline links and what is left", () => {
  it("links each event deadline to its work, not the calendar", () => {
    expect(deadlineHref("BIRM27", "artwork_due")).toBe("/BIRM27/signage?show=needs_artwork");
    expect(deadlineHref("BIRM27", "print_deadline")).toBe("/BIRM27/signage?show=ready_to_print");
    expect(deadlineHref("BIRM27", "delivery")).toBe("/BIRM27/onsite");
    expect(deadlineHref("BIRM27", "venue_rigging_submission")).toBe("/BIRM27/reports#venue");
    expect(deadlineHref("BIRM27", "stand_design_due")).toBe("/BIRM27/stand-designs");
    expect(deadlineHref("BIRM27", "insurance_due")).toBe("/BIRM27/stands");
    expect(deadlineHref("BIRM27", "something_else")).toBe("/BIRM27/calendar");
  });

  const work = {
    needsArtwork: 3,
    readyToPrint: 1,
    toDeliver: 12,
    venueItems: 0,
    standDesignsToDo: 1,
  };
  it("says how much is left", () => {
    expect(deadlineWorkLabel("artwork_due", work)).toBe("3 items still need artwork");
    expect(deadlineWorkLabel("artwork_due", { ...work, needsArtwork: 1 })).toBe(
      "1 item still needs artwork",
    );
    expect(deadlineWorkLabel("artwork_due", { ...work, needsArtwork: 0 })).toBe(
      "all artwork is in",
    );
    expect(deadlineWorkLabel("print_deadline", work)).toBe("1 item ready to print, not sent yet");
    expect(deadlineWorkLabel("print_deadline", { ...work, readyToPrint: 0 })).toBeNull();
    expect(deadlineWorkLabel("delivery", work)).toBe("12 items not delivered yet");
    expect(deadlineWorkLabel("venue_rigging_submission", work)).toBe(
      "nothing needs venue approval",
    );
    expect(deadlineWorkLabel("stand_design_due", work)).toBe(
      "1 feature stand still needs a design",
    );
    expect(deadlineWorkLabel("insurance_due", work)).toBeNull();
  });
});

describe("nextStepRows", () => {
  const none = { code: "BIRM27", signoffs: null, tasks: null, sponsorship: null, onsite: null };

  it("is empty when nothing is waiting", () => {
    expect(nextStepRows(none)).toEqual([]);
    expect(
      nextStepRows({
        ...none,
        signoffs: { total: 0, overdue: 0 },
        tasks: { overdue: 0, dueSoon: 0 },
        sponsorship: { urgent: 0, unsold: 0, overdue: 0 },
        onsite: { deliveries: 0, installs: 0 },
      }),
    ).toEqual([]);
  });

  it("lists sign-offs, tasks, sponsorship and onsite with their links", () => {
    const rows = nextStepRows({
      code: "BIRM27",
      signoffs: { total: 5, overdue: 2 },
      tasks: { overdue: 1, dueSoon: 2 },
      sponsorship: { urgent: 4, unsold: 3, overdue: 1 },
      onsite: { deliveries: 2, installs: 1 },
    });
    expect(rows).toEqual([
      {
        key: "signoffs",
        text: "5 sign-offs are waiting on you",
        detail: "2 overdue",
        href: "/approvals?tab=mine&event=BIRM27",
        urgent: true,
      },
      {
        key: "tasks",
        text: "You have 3 tasks due",
        detail: "1 overdue · 2 due this week",
        href: "/my-work?event=BIRM27#tasks",
        urgent: true,
      },
      {
        key: "sponsorship",
        text: "4 sponsorship items to order within a month",
        detail: "1 overdue · 3 not sold yet",
        href: "/BIRM27/sponsorship?filter=urgent",
        urgent: true,
      },
      {
        key: "onsite",
        text: "2 deliveries and 1 install in the next 7 days",
        detail: null,
        href: "/BIRM27/onsite",
        urgent: false,
      },
    ]);
  });

  it("uses the singular and links only overdue tasks when that is all there is", () => {
    const [signoff, task] = nextStepRows({
      ...none,
      signoffs: { total: 1, overdue: 0 },
      tasks: { overdue: 2, dueSoon: 0 },
    });
    expect(signoff).toMatchObject({ text: "1 sign-off is waiting on you", urgent: false });
    expect(signoff.detail).toBeNull();
    expect(task.href).toBe("/my-work?event=BIRM27&due=overdue#tasks");
    const [onsite] = nextStepRows({ ...none, onsite: { deliveries: 0, installs: 3 } });
    expect(onsite.text).toBe("3 installs in the next 7 days");
  });
});

describe("sponsorshipSummary", () => {
  const row = (over: Partial<SponsorshipDashRow>): SponsorshipDashRow => ({
    kind: "sponsorship_item",
    sponsorId: null,
    salePrice: null,
    costEstimate: null,
    status: "draft",
    previousStatus: null,
    hasArtwork: false,
    orderByDate: null,
    ...over,
  });
  const today = "2026-10-16";

  it("counts sold of what is for sale, sales, and what must be ordered soon", () => {
    const s = sponsorshipSummary(
      [
        row({ sponsorId: "s1", salePrice: "1500" }),
        row({ sponsorId: "s2", salePrice: "500", orderByDate: "2026-10-20" }),
        row({ orderByDate: "2026-10-30" }),
        row({ orderByDate: "2026-10-01" }),
        row({ orderByDate: "2027-03-01" }),
        // Already sent to print: the order-by date no longer counts.
        row({
          sponsorId: "s3",
          salePrice: "100",
          status: "in_production",
          orderByDate: "2026-10-18",
        }),
        // Sponsor signage in a package is neither for sale nor sold.
        row({ kind: "signage", sponsorId: "s1" }),
      ],
      today,
    );
    expect(s).toEqual({
      forSale: 6,
      sold: 3,
      available: 3,
      inPackage: 1,
      sales: 2100,
      urgent: 3,
      urgentUnsold: 2,
      overdue: 1,
    });
  });
});

describe("onsiteSoon", () => {
  it("counts deliveries and installs still to happen this week, as Onsite lists them", () => {
    const today = "2026-10-16";
    const item = (
      kind: string,
      status: string,
      deliveryDate: string | null,
      installDate: string | null,
    ) => ({
      kind,
      status,
      deliveryDate,
      installDate,
    });
    expect(
      onsiteSoon(
        [
          item("signage", "in_production", "2026-10-16", "2026-10-23"), // delivery + install
          item("signage", "delivered", "2026-10-17", "2026-10-18"), // install only
          item("signage", "installed", null, "2026-10-18"), // done
          item("sponsorship_item", "in_production", "2026-10-20", "2026-10-18"), // delivery only
          item("stand_panel", "delivered", null, "2026-10-19"), // install
          item("signage", "approved", "2026-10-17", "2026-10-17"), // not sent to print: not on Onsite
          item("signage", "in_production", "2026-10-15", "2026-10-24"), // both outside the week
          item("stand_design", "in_production", "2026-10-17", "2026-10-17"), // not an Onsite item
        ],
        today,
      ),
    ).toEqual({ deliveries: 2, installs: 3 });
  });
});

describe("waitingOnLabel and lateLabel", () => {
  const step = {
    assignedUserId: null,
    assigneeName: null,
    assignedDepartmentId: null,
    departmentName: null,
    assignedRole: null,
    stepKind: "approval",
  };
  it("names who a sign-off sits with like the team view", () => {
    expect(waitingOnLabel({ ...step, assignedUserId: "u", assigneeName: "Dana Director" })).toBe(
      "Dana Director",
    );
    expect(
      waitingOnLabel({ ...step, assignedDepartmentId: "d", departmentName: "Operations" }),
    ).toBe("Operations");
    expect(waitingOnLabel({ ...step, assignedRole: "supplier", stepKind: "confirmation" })).toBe(
      "Supplier or Operations",
    );
    expect(waitingOnLabel({ ...step, assignedRole: "venue" })).toBe("Venue");
    expect(waitingOnLabel(step)).toBe("Nobody yet");
  });

  it("says how late", () => {
    expect(lateLabel(0)).toBe("due today");
    expect(lateLabel(1)).toBe("1 day late");
    expect(lateLabel(23)).toBe("23 days late");
  });
});

describe("overdueArtworkSignoffs", () => {
  const step = (over: Partial<Parameters<typeof overdueArtworkSignoffs>[0][number]> = {}) => ({
    entityType: "signage_item",
    stepKind: "approval",
    ref: "SIG-1",
    runNumber: 2,
    currentRunNumber: 2,
    itemHasArtwork: true,
    itemStatus: "in_review",
    ...over,
  });

  it("counts overdue artwork sign-offs once per item, most overdue first", () => {
    const rows = [
      step({ ref: "SIG-1" }),
      step({ ref: "SIG-2" }),
      step({ ref: "SIG-1", stepKind: "approval" }),
    ];
    expect(overdueArtworkSignoffs(rows).map((r) => r.ref)).toEqual(["SIG-1", "SIG-2"]);
  });

  it("leaves out confirmations, stands, earlier rounds and items not waiting with artwork", () => {
    const rows = [
      step({ ref: "C", stepKind: "confirmation" }),
      step({ ref: "S", entityType: "stand_submission" }),
      step({ ref: "R", runNumber: 1 }),
      step({ ref: "A", itemHasArtwork: false }),
      step({ ref: "P", itemStatus: "approved" }),
      step({ ref: "OK" }),
    ];
    expect(overdueArtworkSignoffs(rows).map((r) => r.ref)).toEqual(["OK"]);
  });
});
