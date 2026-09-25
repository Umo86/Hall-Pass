import { describe, expect, it } from "vitest";
import { can, type ApprovalStepCtx, type StaffActor } from "@/lib/authz";

const ORG_A = "org-a";
const ORG_B = "org-b";
const admin = (organisationId: string): StaffActor => ({
  kind: "staff",
  userId: `admin-${organisationId}`,
  organisationId,
  role: "admin",
});
const item = (organisationId: string) => ({ organisationId, editionId: "ed-1", venueId: "v-1" });

describe("tenancy: no one acts on another organisation's records", () => {
  it("even an admin can't view, edit, upload to or submit another organisation's item", () => {
    for (const type of [
      "signage.view",
      "signage.edit",
      "artwork.upload",
      "signage.submit",
    ] as const) {
      expect(can(admin(ORG_A), { type, item: item(ORG_A) })).toBe(true);
      expect(can(admin(ORG_B), { type, item: item(ORG_A) })).toBe(false);
    }
  });

  it("nor decide or delegate its sign-offs", () => {
    const step: ApprovalStepCtx = {
      assignedRole: null,
      assignedUserId: null,
      entity: { type: "signage_item", item: item(ORG_A) },
    };
    expect(can(admin(ORG_A), { type: "approval.decide", step })).toBe(true);
    expect(can(admin(ORG_B), { type: "approval.decide", step })).toBe(false);
    expect(can(admin(ORG_B), { type: "approval.delegate", step })).toBe(false);
  });

  it("nor its stands", () => {
    const sub = { organisationId: ORG_A, editionId: "ed-1", venueId: "v-1", exhibitorId: "x-1" };
    expect(can(admin(ORG_B), { type: "stand.view", sub })).toBe(false);
    expect(can(admin(ORG_A), { type: "stand.view", sub })).toBe(true);
  });
});
