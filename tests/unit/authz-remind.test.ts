/**
 * approval.remind — who may press Remind on someone else's sign-off
 * (Approvals → Everyone's). Admins and Operations always; otherwise whoever
 * could send that item for sign-off (signage.submit) or review that stand
 * (stand.review); never portal users. Sections apply as for signage.submit.
 * Written before the permission.
 */
import { describe, expect, it } from "vitest";
import {
  can,
  featureForAction,
  type ApprovalStepCtx,
  type ExternalActor,
  type Feature,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
  type StandSubmissionCtx,
} from "@/lib/authz";

const ORG = "org-1";
const base = { organisationId: ORG, editionId: "ed-1", venueId: "v-1" };
const sign: SignageItemCtx = { ...base, kind: "signage" };
const sponsorSign: SignageItemCtx = { ...base, kind: "signage", sponsorId: "sp-1" };
const sponsorshipItem: SignageItemCtx = { ...base, kind: "sponsorship_item" };
const standDesign: SignageItemCtx = { ...base, kind: "stand_design" };
const stand: StandSubmissionCtx = { ...base, exhibitorId: "ex-1" };

/** A department sign-off on the item — not the reminder's own step. */
const stepOn = (item: SignageItemCtx): ApprovalStepCtx => ({
  assignedRole: null,
  assignedUserId: null,
  assignedDepartmentId: "d-marketing",
  stepKind: "approval",
  entity: { type: "signage_item", item },
});
const standStep: ApprovalStepCtx = {
  assignedRole: "venue",
  assignedUserId: null,
  stepKind: "approval",
  entity: { type: "stand", sub: stand },
};

function staff(role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor {
  return { kind: "staff", userId: `${role}-1`, organisationId: ORG, role, ...extra };
}
const remind = (actor: StaffActor | ExternalActor, step: ApprovalStepCtx) =>
  can(actor, { type: "approval.remind", step });

describe("approval.remind: who can chase a sign-off", () => {
  it("admin — any signage or stand sign-off, sections or not", () => {
    const admin = staff("admin", { features: [] });
    for (const item of [sign, sponsorSign, sponsorshipItem, standDesign]) {
      expect(remind(admin, stepOn(item))).toBe(true);
    }
    expect(remind(admin, standStep)).toBe(true);
  });

  it("admin — never another organisation's sign-off", () => {
    const other = { ...sign, organisationId: "org-2" };
    expect(remind(staff("admin"), stepOn(other))).toBe(false);
  });

  it("ops — every signage item, stand design and stand", () => {
    const ops = staff("ops");
    for (const item of [sign, sponsorSign, sponsorshipItem, standDesign]) {
      expect(remind(ops, stepOn(item))).toBe(true);
    }
    expect(remind(ops, standStep)).toBe(true);
  });

  it("ops — not in a section switched off for them", () => {
    const ops = staff("ops", { features: ["sponsorship"] });
    expect(remind(ops, stepOn(sign))).toBe(false);
    expect(remind(ops, stepOn(standDesign))).toBe(false);
    expect(remind(ops, standStep)).toBe(false);
    expect(remind(ops, stepOn(sponsorshipItem))).toBe(true);
  });

  it("marketing — signage and sponsorship items they could send, not stands", () => {
    const mkt = staff("marketing");
    expect(remind(mkt, stepOn(sign))).toBe(true);
    expect(remind(mkt, stepOn(sponsorSign))).toBe(true);
    expect(remind(mkt, stepOn(sponsorshipItem))).toBe(true);
    expect(remind(mkt, stepOn(standDesign))).toBe(false);
    expect(remind(mkt, standStep)).toBe(false);
  });

  it("marketing — not when Signage is switched off for them", () => {
    expect(remind(staff("marketing", { features: ["calendar"] }), stepOn(sign))).toBe(false);
  });

  it("sales — sponsor signage and sponsorship items only", () => {
    const sales = staff("sales");
    expect(remind(sales, stepOn(sponsorSign))).toBe(true);
    expect(remind(sales, stepOn(sponsorshipItem))).toBe(true);
    expect(remind(sales, stepOn(sign))).toBe(false);
    expect(remind(sales, stepOn(standDesign))).toBe(false);
    expect(remind(sales, standStep)).toBe(false);
  });

  it("sales — their own item when granted 'add signage'", () => {
    const sales = staff("sales", { overrides: { "signage.create": true } });
    expect(remind(sales, stepOn({ ...sign, ownerUserId: "sales-1" }))).toBe(true);
    expect(remind(sales, stepOn({ ...sign, ownerUserId: "someone-else" }))).toBe(false);
  });

  it("senior management — never, even for a step that is theirs to decide", () => {
    const director = staff("event_director", { signoffDepartmentIds: ["d-marketing"] });
    expect(remind(director, stepOn(sign))).toBe(false);
    expect(remind(director, stepOn(sponsorSign))).toBe(false);
    expect(remind(director, standStep)).toBe(false);
  });

  it("viewer — never", () => {
    const viewer = staff("viewer", { signoffDepartmentIds: ["d-marketing"] });
    expect(remind(viewer, stepOn(sign))).toBe(false);
    expect(remind(viewer, stepOn(sponsorshipItem))).toBe(false);
    expect(remind(viewer, standStep)).toBe(false);
  });

  it("portal users — never, even on a step they could decide", () => {
    const venue: ExternalActor = {
      kind: "external",
      userId: "venue-1",
      organisationId: ORG,
      grants: [
        {
          role: "venue",
          editionId: "ed-1",
          scopeType: "venue",
          scopeId: "v-1",
          expiresAt: null,
          revokedAt: null,
        },
      ],
    };
    const venueStep: ApprovalStepCtx = {
      assignedRole: "venue",
      stepKind: "approval",
      entity: { type: "signage_item", item: { ...sign, requiresVenueApproval: true } },
    };
    expect(can(venue, { type: "approval.decide", step: venueStep })).toBe(true);
    expect(remind(venue, venueStep)).toBe(false);
    expect(remind(venue, standStep)).toBe(false);
  });
});

describe("approval.remind belongs to the item's section", () => {
  const cases: [ApprovalStepCtx, Feature][] = [
    [stepOn(sign), "signage"],
    [stepOn(sponsorshipItem), "sponsorship"],
    [stepOn(standDesign), "stand_designs"],
    [standStep, "stands"],
  ];
  it.each(cases)("%o → %s", (step, feature) => {
    expect(featureForAction({ type: "approval.remind", step })).toBe(feature);
  });
});
