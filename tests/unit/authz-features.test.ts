import { describe, expect, it } from "vitest";
import {
  can,
  featureForAction,
  FEATURES,
  hasFeature,
  type Action,
  type ApprovalStepCtx,
  type ExternalActor,
  type Feature,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";

const ORG = "org-1";
const signage: SignageItemCtx = { editionId: "ed-1", venueId: "v-1", kind: "signage" };
const sponsorship: SignageItemCtx = { ...signage, kind: "sponsorship_item" };
const standDesign: SignageItemCtx = { ...signage, kind: "stand_design" };
const panel: SignageItemCtx = { ...signage, kind: "stand_panel" };

function staff(
  role: StaffRole,
  features: Feature[] | null | undefined,
  extra: Partial<StaffActor> = {},
): StaffActor {
  return { kind: "staff", userId: `${role}-1`, organisationId: ORG, role, features, ...extra };
}

describe("hasFeature: which sections a person can use", () => {
  it("no list (null or missing) means every section — today's behaviour", () => {
    for (const f of FEATURES) {
      expect(hasFeature(staff("marketing", null), f)).toBe(true);
      expect(hasFeature(staff("marketing", undefined), f)).toBe(true);
    }
  });

  it("a list switches on exactly those sections", () => {
    const a = staff("marketing", ["signage", "calendar"]);
    expect(hasFeature(a, "signage")).toBe(true);
    expect(hasFeature(a, "calendar")).toBe(true);
    expect(hasFeature(a, "sponsorship")).toBe(false);
    expect(hasFeature(a, "reports")).toBe(false);
  });

  it("an empty list switches every section off", () => {
    for (const f of FEATURES) {
      if (f === "approvals") continue;
      expect(hasFeature(staff("ops", []), f)).toBe(false);
    }
  });

  it("admins always have every section, whatever is stored", () => {
    for (const f of FEATURES) expect(hasFeature(staff("admin", []), f)).toBe(true);
  });

  it("anyone who signs off for a department always has Approvals", () => {
    expect(hasFeature(staff("viewer", []), "approvals")).toBe(false);
    expect(hasFeature(staff("viewer", [], { signoffDepartmentIds: ["d-1"] }), "approvals")).toBe(
      true,
    );
  });

  it("external portal users have no staff sections", () => {
    const ext: ExternalActor = { kind: "external", userId: "e", organisationId: ORG, grants: [] };
    for (const f of FEATURES) expect(hasFeature(ext, f)).toBe(false);
  });
});

describe("featureForAction: the section each action belongs to", () => {
  const cases: [Action, Feature | null][] = [
    [{ type: "signage.create" }, "signage"],
    [{ type: "sponsorship.create" }, "sponsorship"],
    [{ type: "stand_design.create" }, "stand_designs"],
    [{ type: "signage.edit", item: signage }, "signage"],
    [{ type: "signage.edit", item: sponsorship }, "sponsorship"],
    [{ type: "signage.edit", item: standDesign }, "stand_designs"],
    [{ type: "signage.edit", item: panel }, "stand_designs"],
    [{ type: "artwork.upload", item: sponsorship }, "sponsorship"],
    [{ type: "signage.submit", item: signage }, "signage"],
    [{ type: "comment.external.write", entity: sponsorship }, "sponsorship"],
    [{ type: "stand.review" }, "stands"],
    [{ type: "export.run", kind: "schedule" }, "reports"],
    [{ type: "export.run", kind: "venue_pack" }, "reports"],
    [{ type: "export.run", kind: "certificate" }, null],
    // Never gated: looking at a record, deciding, tasks, settings, users.
    [{ type: "view_edition" }, null],
    [{ type: "signage.view", item: signage }, null],
    [{ type: "task.create" }, null],
    [{ type: "costs.view" }, null],
    [{ type: "settings.manage" }, null],
    [{ type: "users.manage" }, null],
  ];
  it.each(cases)("%o → %s", (action, feature) => {
    expect(featureForAction(action)).toBe(feature);
  });
});

describe("can() respects switched-off sections", () => {
  it("refuses an action in a section the person doesn't have", () => {
    const mkt = staff("marketing", ["sponsorship"]);
    expect(can(mkt, { type: "signage.create" })).toBe(false);
    expect(can(mkt, { type: "signage.edit", item: signage })).toBe(false);
    expect(can(mkt, { type: "artwork.upload", item: signage })).toBe(false);
  });

  it("still allows actions in sections they have, by role as before", () => {
    const mkt = staff("marketing", ["signage"]);
    expect(can(mkt, { type: "signage.create" })).toBe(true);
    expect(can(mkt, { type: "signage.edit", item: signage })).toBe(true);
    // Role rules still apply inside a section: marketing never creates stand designs.
    expect(can(staff("marketing", ["stand_designs"]), { type: "stand_design.create" })).toBe(false);
  });

  it("a granted ability can't reopen a switched-off section", () => {
    const sales = staff("sales", ["sponsorship"], { overrides: { "signage.create": true } });
    expect(can(sales, { type: "signage.create" })).toBe(false);
  });

  it("sponsor report needs Sponsorship or Reports", () => {
    const sales = (f: Feature[]) => staff("sales", f);
    expect(can(sales(["sponsorship"]), { type: "export.run", kind: "sponsor_report" })).toBe(true);
    expect(can(sales(["reports"]), { type: "export.run", kind: "sponsor_report" })).toBe(true);
    expect(can(sales(["signage"]), { type: "export.run", kind: "sponsor_report" })).toBe(false);
  });

  it("other exports need Reports", () => {
    expect(can(staff("ops", ["signage"]), { type: "export.run", kind: "schedule" })).toBe(false);
    expect(can(staff("ops", ["reports"]), { type: "export.run", kind: "schedule" })).toBe(true);
  });

  it("never blocks viewing a record or deciding a sign-off assigned to you", () => {
    const viewer = staff("viewer", [], { signoffDepartmentIds: ["d-1"] });
    const step: ApprovalStepCtx = {
      assignedRole: null,
      assignedUserId: null,
      assignedDepartmentId: "d-1",
      entity: { type: "signage_item", item: signage },
    };
    expect(can(viewer, { type: "signage.view", item: signage })).toBe(true);
    expect(can(viewer, { type: "approval.decide", step })).toBe(true);
    expect(can(viewer, { type: "task.create" })).toBe(true);
  });

  it("admins are never limited by sections", () => {
    const admin = staff("admin", []);
    expect(can(admin, { type: "signage.create" })).toBe(true);
    expect(can(admin, { type: "stand.review" })).toBe(true);
    expect(can(admin, { type: "export.run", kind: "schedule" })).toBe(true);
  });

  it("no list keeps today's role behaviour exactly", () => {
    const roles: StaffRole[] = ["ops", "marketing", "sales", "event_director", "viewer"];
    const actions: Action[] = [
      { type: "signage.create" },
      { type: "sponsorship.create" },
      { type: "stand_design.create" },
      { type: "signage.edit", item: signage },
      { type: "signage.edit", item: sponsorship },
      { type: "stand.review" },
      { type: "export.run", kind: "schedule" },
      { type: "export.run", kind: "sponsor_report" },
    ];
    for (const role of roles) {
      for (const action of actions) {
        expect(can(staff(role, null), action)).toBe(can(staff(role, undefined), action));
        expect(can(staff(role, null), action)).toBe(can(staff(role, [...FEATURES]), action));
      }
    }
  });
});
