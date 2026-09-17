import { describe, expect, it } from "vitest";
import {
  can,
  type Action,
  type Actor,
  type ExternalActor,
  type GrantInfo,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
  type StandSubmissionCtx,
} from "@/lib/authz";

const ORG = "org-1";
const EDITION = "ed-1";
const VENUE = "venue-1";
const SUPPLIER = "sup-1";
const SPONSOR = "spo-1";
const EXHIBITOR = "exh-1";

function staff(role: StaffRole, userId = `${role}-user`): StaffActor {
  return { kind: "staff", userId, organisationId: ORG, role };
}

function external(grants: Partial<GrantInfo>[]): ExternalActor {
  return {
    kind: "external",
    userId: "ext-user",
    organisationId: ORG,
    grants: grants.map((g) => ({
      role: "venue",
      editionId: EDITION,
      scopeType: null,
      scopeId: null,
      expiresAt: null,
      revokedAt: null,
      ...g,
    })),
  };
}

const plainItem: SignageItemCtx = { editionId: EDITION, venueId: VENUE };
const sponsorItem: SignageItemCtx = { ...plainItem, sponsorId: SPONSOR };
const venueItem: SignageItemCtx = { ...plainItem, requiresVenueApproval: true };
const supplierItem: SignageItemCtx = { ...plainItem, supplierId: SUPPLIER };

const sub: StandSubmissionCtx = {
  editionId: EDITION,
  venueId: VENUE,
  exhibitorId: EXHIBITOR,
};

const allStaff: StaffRole[] = ["admin", "ops", "marketing", "sales", "event_director", "viewer"];

/** Assert exactly these roles are allowed; every other staff role is denied. */
function expectRoles(action: Action, allowed: StaffRole[]) {
  for (const role of allStaff) {
    expect(can(staff(role), action), `${role} → ${action.type}`).toBe(allowed.includes(role));
  }
}

describe("staff permission matrix (brief 3.3)", () => {
  it("view all editions and records — every role", () => {
    expectRoles({ type: "view_edition" }, allStaff);
    expectRoles({ type: "signage.view", item: plainItem }, allStaff);
    expectRoles({ type: "stand.view", sub }, allStaff);
  });

  it("create and edit signage items", () => {
    expectRoles({ type: "signage.create" }, ["admin", "ops", "marketing"]);
    expectRoles({ type: "signage.edit", item: plainItem }, ["admin", "ops", "marketing"]);
    // sales: sponsor items only
    expect(can(staff("sales"), { type: "signage.edit", item: sponsorItem })).toBe(true);
    expect(can(staff("sales"), { type: "signage.edit", item: plainItem })).toBe(false);
  });

  it("delete and restore signage items — admin and ops only", () => {
    expectRoles({ type: "signage.delete" }, ["admin", "ops"]);
    expectRoles({ type: "signage.restore" }, ["admin", "ops"]);
  });

  it("upload artwork", () => {
    expectRoles({ type: "artwork.upload", item: plainItem }, ["admin", "ops", "marketing"]);
    expect(can(staff("sales"), { type: "artwork.upload", item: sponsorItem })).toBe(true);
    expect(can(staff("sales"), { type: "artwork.upload", item: plainItem })).toBe(false);
  });

  it("submit item for review", () => {
    expectRoles({ type: "signage.submit", item: plainItem }, ["admin", "ops", "marketing"]);
  });

  it("decide approval steps — role-assigned steps decidable only by that role, admin any", () => {
    for (const stepRole of ["ops", "marketing", "sales", "event_director"] as const) {
      const action: Action = {
        type: "approval.decide",
        step: { assignedRole: stepRole, entity: { type: "signage_item", item: plainItem } },
      };
      for (const actorRole of allStaff) {
        const expected = actorRole === "admin" || actorRole === stepRole;
        expect(can(staff(actorRole), action), `${actorRole} decides ${stepRole} step`).toBe(expected);
      }
    }
  });

  it("user-assigned steps decidable only by that user (and admin)", () => {
    const action: Action = {
      type: "approval.decide",
      step: {
        assignedRole: null,
        assignedUserId: "ops-user",
        entity: { type: "signage_item", item: plainItem },
      },
    };
    expect(can(staff("ops", "ops-user"), action)).toBe(true);
    expect(can(staff("ops", "someone-else"), action)).toBe(false);
    expect(can(staff("admin"), action)).toBe(true);
  });

  it("delegate a step assigned to me — everyone but viewer, only own steps", () => {
    const myStep: Action = {
      type: "approval.delegate",
      step: { assignedRole: "marketing", entity: { type: "signage_item", item: plainItem } },
    };
    expect(can(staff("marketing"), myStep)).toBe(true);
    expect(can(staff("sales"), myStep)).toBe(false); // not their step
    expect(can(staff("admin"), myStep)).toBe(true);
    expect(can(staff("viewer"), myStep)).toBe(false);
  });

  it("hold, resume, reopen — admin and ops only", () => {
    expectRoles({ type: "signage.hold" }, ["admin", "ops"]);
    expectRoles({ type: "signage.resume" }, ["admin", "ops"]);
    expectRoles({ type: "signage.reopen" }, ["admin", "ops"]);
  });

  it("change requests", () => {
    expectRoles({ type: "change_request.raise" }, ["admin", "ops", "marketing", "sales"]);
    expectRoles({ type: "change_request.approve" }, ["admin", "ops"]);
  });

  it("review stand submissions — admin and ops only", () => {
    expectRoles({ type: "stand.review" }, ["admin", "ops"]);
  });

  it("costs: view and edit", () => {
    expectRoles({ type: "costs.view" }, ["admin", "ops", "marketing", "event_director"]);
    expectRoles({ type: "costs.edit" }, ["admin", "ops"]);
  });

  it("internal comments — write for all but viewer; read for all", () => {
    expectRoles({ type: "comment.internal.write" }, [
      "admin",
      "ops",
      "marketing",
      "sales",
      "event_director",
    ]);
    expectRoles({ type: "comment.internal.read" }, allStaff);
  });

  it("onsite: confirm install and snags", () => {
    expectRoles({ type: "onsite.confirm_install" }, ["admin", "ops", "marketing"]);
    expectRoles({ type: "snag.manage" }, ["admin", "ops", "marketing"]);
  });

  it("exports — sales only sponsor report; viewer none", () => {
    expectRoles({ type: "export.run", kind: "schedule" }, [
      "admin",
      "ops",
      "marketing",
      "event_director",
    ]);
    expect(can(staff("sales"), { type: "export.run", kind: "sponsor_report" })).toBe(true);
    expect(can(staff("sales"), { type: "export.run", kind: "schedule" })).toBe(false);
    expect(can(staff("viewer"), { type: "export.run", kind: "sponsor_report" })).toBe(false);
  });

  it("settings — admin and ops; users and grants — admin only", () => {
    expectRoles({ type: "settings.manage" }, ["admin", "ops"]);
    expectRoles({ type: "users.manage" }, ["admin"]);
  });

  it("staff never submit a stand on behalf of an exhibitor", () => {
    expectRoles({ type: "stand.submit", sub }, []);
  });
});

describe("external scoping (brief 3.2)", () => {
  const venueActor = external([{ role: "venue", scopeType: "venue", scopeId: VENUE }]);

  it("venue sees only items flagged requires_venue_approval at their venue", () => {
    expect(can(venueActor, { type: "signage.view", item: venueItem })).toBe(true);
    expect(can(venueActor, { type: "signage.view", item: plainItem })).toBe(false);
    const otherVenueItem = { ...venueItem, venueId: "venue-2" };
    expect(can(venueActor, { type: "signage.view", item: otherVenueItem })).toBe(false);
  });

  it("venue sees stand submissions only once the venue step is active", () => {
    expect(can(venueActor, { type: "stand.view", sub })).toBe(false);
    expect(can(venueActor, { type: "stand.view", sub: { ...sub, venueStepActive: true } })).toBe(
      true,
    );
  });

  it("venue decides the venue step and nothing else", () => {
    const venueStep: Action = {
      type: "approval.decide",
      step: { assignedRole: "venue", entity: { type: "signage_item", item: venueItem } },
    };
    const opsStep: Action = {
      type: "approval.decide",
      step: { assignedRole: "ops", entity: { type: "signage_item", item: venueItem } },
    };
    expect(can(venueActor, venueStep)).toBe(true);
    expect(can(venueActor, opsStep)).toBe(false);
  });

  it("venue never edits, exports, sees costs or manages settings", () => {
    expect(can(venueActor, { type: "signage.edit", item: venueItem })).toBe(false);
    expect(can(venueActor, { type: "costs.view" })).toBe(false);
    expect(can(venueActor, { type: "export.run", kind: "schedule" })).toBe(false);
    expect(can(venueActor, { type: "settings.manage" })).toBe(false);
    expect(can(venueActor, { type: "comment.internal.read" })).toBe(false);
  });

  it("structural engineer sees stands at/past the engineer step, edition-scoped", () => {
    const eng = external([{ role: "structural_engineer" }]);
    expect(can(eng, { type: "stand.view", sub })).toBe(false);
    expect(can(eng, { type: "stand.view", sub: { ...sub, engineerStepActive: true } })).toBe(true);
    const otherEdition = { ...sub, editionId: "ed-2", engineerStepActive: true };
    expect(can(eng, { type: "stand.view", sub: otherEdition })).toBe(false);
    expect(
      can(eng, {
        type: "approval.decide",
        step: { assignedRole: "structural_engineer", entity: { type: "stand", sub } },
      }),
    ).toBe(true);
  });

  it("H&S sees stands at/past the H&S step", () => {
    const hs = external([{ role: "hs" }]);
    expect(can(hs, { type: "stand.view", sub: { ...sub, hsStepActive: true } })).toBe(true);
    expect(can(hs, { type: "stand.view", sub })).toBe(false);
  });

  it("supplier sees only items with matching supplier_id, decides supplier confirmations", () => {
    const sup = external([{ role: "supplier", scopeType: "supplier", scopeId: SUPPLIER }]);
    expect(can(sup, { type: "signage.view", item: supplierItem })).toBe(true);
    expect(can(sup, { type: "signage.view", item: plainItem })).toBe(false);
    expect(
      can(sup, {
        type: "approval.decide",
        step: { assignedRole: "supplier", entity: { type: "signage_item", item: supplierItem } },
      }),
    ).toBe(true);
    expect(
      can(sup, {
        type: "approval.decide",
        step: {
          assignedRole: "supplier",
          entity: { type: "signage_item", item: { ...plainItem, supplierId: "sup-2" } },
        },
      }),
    ).toBe(false);
  });

  it("sponsor sees only their items and decides the sponsor step", () => {
    const spo = external([{ role: "sponsor", scopeType: "sponsor", scopeId: SPONSOR }]);
    expect(can(spo, { type: "signage.view", item: sponsorItem })).toBe(true);
    expect(can(spo, { type: "signage.view", item: plainItem })).toBe(false);
    expect(
      can(spo, {
        type: "approval.decide",
        step: { assignedRole: "sponsor", entity: { type: "signage_item", item: sponsorItem } },
      }),
    ).toBe(true);
  });

  it("exhibitor and contractor see and submit only their own submission", () => {
    const exh = external([{ role: "exhibitor", scopeType: "exhibitor", scopeId: EXHIBITOR }]);
    expect(can(exh, { type: "stand.view", sub })).toBe(true);
    expect(can(exh, { type: "stand.submit", sub })).toBe(true);
    const otherSub = { ...sub, exhibitorId: "exh-2" };
    expect(can(exh, { type: "stand.view", sub: otherSub })).toBe(false);
    expect(can(exh, { type: "stand.submit", sub: otherSub })).toBe(false);
  });

  it("expired or revoked grants lose access immediately", () => {
    const past = new Date(Date.now() - 1000);
    const expired = external([
      { role: "venue", scopeType: "venue", scopeId: VENUE, expiresAt: past },
    ]);
    expect(can(expired, { type: "signage.view", item: venueItem })).toBe(false);
    const revoked = external([
      { role: "venue", scopeType: "venue", scopeId: VENUE, revokedAt: past },
    ]);
    expect(can(revoked, { type: "signage.view", item: venueItem })).toBe(false);
  });

  it("externals can write external comments only on records they can see", () => {
    expect(can(venueActor, { type: "comment.external.write", entity: venueItem })).toBe(true);
    expect(can(venueActor, { type: "comment.external.write", entity: plainItem })).toBe(false);
  });
});

describe("misc", () => {
  it("staff decide is denied for a step assigned to an external role", () => {
    const venueStep: Action = {
      type: "approval.decide",
      step: { assignedRole: "venue", entity: { type: "signage_item", item: venueItem } },
    };
    expect(can(staff("ops"), venueStep)).toBe(false);
    expect(can(staff("admin"), venueStep)).toBe(true); // admin can decide any step
  });

  it("unknown actors get nothing by default", () => {
    const noGrants: Actor = { kind: "external", userId: "x", organisationId: ORG, grants: [] };
    expect(can(noGrants, { type: "view_edition" })).toBe(false);
    expect(can(noGrants, { type: "signage.view", item: plainItem })).toBe(false);
  });
});
