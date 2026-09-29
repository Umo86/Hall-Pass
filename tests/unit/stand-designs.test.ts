import { describe, expect, it } from "vitest";
import { mapPlanToWorkflow } from "@/lib/domain/stand-designs";
import { artworkBlockedReason, PANEL_BLOCKED_MESSAGE } from "@/lib/artwork-rules";
import { formatStandDesignRef, formatStandPanelRef } from "@/lib/refs";
import { itemPath } from "@/lib/edition-path";
import { can, type StaffActor } from "@/lib/authz";
import type { StaffRole } from "@/lib/authz";

describe("mapPlanToWorkflow", () => {
  const standSteps = [
    { id: "s-ops", departmentId: "d-ops" },
    { id: "s-mkt", departmentId: "d-mkt" },
    { id: "s-snr", departmentId: "d-snr" },
  ];
  const panelSteps: Parameters<typeof mapPlanToWorkflow>[2] = [
    { id: "p-mkt", departmentId: "d-mkt", kind: "approval", defaultFor: ["organiser"] },
    { id: "p-ops", departmentId: "d-ops", kind: "approval", defaultFor: ["organiser"] },
    { id: "p-venue", departmentId: null, kind: "approval", defaultFor: [] },
    { id: "p-print", departmentId: null, kind: "confirmation", defaultFor: [] },
  ];

  it("carries the stand's departments and people onto the panel's steps", () => {
    expect(
      mapPlanToWorkflow(
        [
          { stepId: "s-ops", userId: "olivia" },
          { stepId: "s-mkt", userId: null },
        ],
        standSteps,
        panelSteps,
      ),
    ).toEqual([
      { stepId: "p-ops", userId: "olivia" },
      { stepId: "p-mkt", userId: null },
    ]);
  });

  it("drops departments the panel workflow doesn't have, and keeps defaults as defaults", () => {
    expect(
      mapPlanToWorkflow([{ stepId: "s-snr", userId: "dana" }], standSteps, panelSteps),
    ).toBeNull();
    expect(mapPlanToWorkflow(null, standSteps, panelSteps)).toBeNull();
  });
});

describe("panel graphics wait for the stand design", () => {
  it("blocks a panel until its stand is approved", () => {
    expect(artworkBlockedReason("draft", { parentStatus: "in_review" })).toBe(
      PANEL_BLOCKED_MESSAGE,
    );
    expect(artworkBlockedReason("draft", { parentStatus: null })).toBe(PANEL_BLOCKED_MESSAGE);
    expect(artworkBlockedReason("draft", { parentStatus: "approved" })).toBeNull();
    expect(artworkBlockedReason("draft", { parentStatus: "approved_with_conditions" })).toBeNull();
  });

  it("leaves other items alone, and installed items stay blocked", () => {
    expect(artworkBlockedReason("draft", null)).toBeNull();
    expect(artworkBlockedReason("installed", { parentStatus: "approved" })).toMatch(/installed/);
  });
});

describe("stand refs and links", () => {
  it("numbers stands and their panels", () => {
    expect(formatStandDesignRef("BIRM27", 7)).toBe("STB-BIRM27-007");
    expect(formatStandPanelRef("STB-BIRM27-007", 2)).toBe("STB-BIRM27-007-P2");
  });

  it("links each kind of item to its own section", () => {
    expect(itemPath("BIRM27", { kind: "signage", ref: "SIG-BIRM27-001" })).toBe(
      "/BIRM27/signage/SIG-BIRM27-001",
    );
    expect(itemPath("BIRM27", { kind: "sponsorship_item", ref: "SIG-BIRM27-002" })).toBe(
      "/BIRM27/sponsorship/SIG-BIRM27-002",
    );
    expect(itemPath("BIRM27", { kind: "stand_design", ref: "STB-BIRM27-001" })).toBe(
      "/BIRM27/stand-designs/STB-BIRM27-001",
    );
    expect(itemPath("BIRM27", { kind: "stand_panel", ref: "STB-BIRM27-001-P1" })).toBe(
      "/BIRM27/stand-panels/STB-BIRM27-001-P1",
    );
  });
});

describe("who sets up and works on stands", () => {
  const staff = (role: StaffRole): StaffActor => ({
    kind: "staff",
    userId: `${role}-user`,
    organisationId: "org-1",
    role,
  });
  const stand = {
    organisationId: "org-1",
    editionId: "ed-1",
    venueId: "venue-1",
    kind: "stand_design" as const,
  };

  it("admins and operations create stands; others don't", () => {
    for (const role of ["admin", "ops"] as const) {
      expect(can(staff(role), { type: "stand_design.create" })).toBe(true);
    }
    for (const role of ["marketing", "sales", "event_director", "viewer"] as const) {
      expect(can(staff(role), { type: "stand_design.create" })).toBe(false);
    }
  });

  it("only admins and operations edit stands or upload their designs", () => {
    for (const type of ["signage.edit", "artwork.upload", "signage.submit"] as const) {
      expect(can(staff("ops"), { type, item: stand })).toBe(true);
      expect(can(staff("marketing"), { type, item: stand })).toBe(false);
      expect(can(staff("sales"), { type, item: { ...stand, sponsorId: "spo-1" } })).toBe(false);
    }
    // Panels likewise.
    expect(
      can(staff("marketing"), { type: "signage.edit", item: { ...stand, kind: "stand_panel" } }),
    ).toBe(false);
  });
});
