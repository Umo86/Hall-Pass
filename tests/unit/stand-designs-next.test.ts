import { describe, expect, it } from "vitest";
import { panelSyncPatch, standChip, standNextLine } from "@/lib/domain/stand-designs";

describe("standNextLine", () => {
  const none = { total: 0, approved: 0 };
  it.each<[string, boolean, string[], { total: number; approved: number }, string, string]>([
    ["draft", false, [], none, "Next: upload the design", "artwork"],
    ["draft", true, [], none, "Next: send the design for sign-off", "artwork"],
    ["awaiting_artwork", false, [], none, "Next: upload the design", "artwork"],
    [
      "in_review",
      true,
      ["Marketing", "Operations"],
      none,
      "Waiting on Marketing and Operations",
      "artwork",
    ],
    ["in_review", true, [], none, "In sign-off", "artwork"],
    ["changes_requested", true, [], none, "Next: upload a new version (changes asked)", "artwork"],
    ["approved", true, [], none, "Next: add the panels", "panels"],
    ["approved", true, [], { total: 5, approved: 2 }, "Panels: 2 of 5 approved", "panels"],
    [
      "approved_with_conditions",
      true,
      [],
      { total: 1, approved: 1 },
      "Panels: 1 of 1 approved",
      "panels",
    ],
    ["on_hold", true, [], none, "On hold", "artwork"],
    ["rejected", true, [], none, "Design rejected", "artwork"],
  ])(
    "%s (design %s, waiting on %o, panels %o) → %s",
    (status, hasDesign, waitingOn, panels, text, tab) => {
      const line = standNextLine({ status, hasDesign, waitingOn, panels });
      expect(line.text).toBe(text);
      expect(line.tab).toBe(tab);
    },
  );

  it("is done once every panel is approved", () => {
    expect(
      standNextLine({
        status: "approved",
        hasDesign: true,
        waitingOn: [],
        panels: { total: 2, approved: 2 },
      }).tone,
    ).toBe("done");
  });
});

describe("standChip", () => {
  it.each<[string, boolean, string | null]>([
    ["draft", false, "needs_design"],
    ["awaiting_artwork", false, "needs_design"],
    ["draft", true, "not_sent"],
    ["in_review", true, "in_signoff"],
    ["changes_requested", true, "changes_requested"],
    ["approved", true, "approved"],
    ["closed", true, "approved"],
    ["on_hold", true, "on_hold"],
    ["rejected", true, null],
  ])("%s with design %s → %s", (status, hasDesign, chip) => {
    expect(standChip(status, hasDesign)).toBe(chip);
  });
});

describe("panelSyncPatch: panels follow their stand", () => {
  const stand = {
    hallId: "h2",
    locationId: "l2",
    standNumber: "B10",
    category: "sponsor",
    sponsorId: "sp",
  };
  const plan = [{ stepId: "p-mkt", userId: null }];
  const panel = {
    hallId: "h1",
    locationId: "l1",
    standNumber: "A01",
    category: "organiser",
    sponsorId: null,
    signoffs: null,
    status: "draft",
  };

  it("a draft panel takes the stand's place, owner and sign-off plan", () => {
    expect(panelSyncPatch(stand, panel, plan)).toEqual({
      hallId: "h2",
      locationId: "l2",
      standNumber: "B10",
      category: "sponsor",
      sponsorId: "sp",
      isSponsorDeliverable: true,
      signoffs: plan,
    });
  });

  it("a panel already in sign-off only moves place: its sign-off is left alone", () => {
    expect(panelSyncPatch(stand, { ...panel, status: "in_review" }, plan)).toEqual({
      hallId: "h2",
      locationId: "l2",
      standNumber: "B10",
    });
  });

  it("an installed or closed panel keeps where it went", () => {
    expect(panelSyncPatch(stand, { ...panel, status: "installed" }, plan)).toEqual({});
    expect(panelSyncPatch(stand, { ...panel, status: "closed" }, plan)).toEqual({});
  });

  it("nothing to do when they already match", () => {
    expect(panelSyncPatch(stand, { ...stand, signoffs: plan, status: "draft" }, plan)).toEqual({});
  });
});
