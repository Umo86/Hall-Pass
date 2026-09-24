import { describe, expect, it } from "vitest";
import {
  can,
  OVERRIDE_KEYS,
  type Action,
  type ApprovalStepCtx,
  type OverrideKey,
  type PermissionOverrides,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
  type TaskCtx,
} from "@/lib/authz";

const ORG = "org-1";
const EDITION = "ed-1";
const VENUE = "venue-1";

function staff(role: StaffRole, overrides?: PermissionOverrides, userId = `${role}-user`): StaffActor {
  return { kind: "staff", userId, organisationId: ORG, role, overrides };
}

const item: SignageItemCtx = { editionId: EDITION, venueId: VENUE };
const sponsorshipItem: SignageItemCtx = { ...item, kind: "sponsorship_item" };

const step = (over: Partial<ApprovalStepCtx> = {}): ApprovalStepCtx => ({
  assignedRole: "marketing",
  assignedUserId: null,
  entity: { type: "signage_item", item },
  ...over,
});

/** A concrete action for each override key (assignment-free where possible). */
const ACTION_FOR: Record<OverrideKey, Action> = {
  "signage.create": { type: "signage.create" },
  "sponsorship.create": { type: "sponsorship.create" },
  "costs.edit": { type: "costs.edit" },
  // Assigned to a different named user, so only admin passes by default and a
  // `true` override (which must not bypass assignment) changes nothing.
  "approval.decide": {
    type: "approval.decide",
    step: step({ assignedRole: null, assignedUserId: "someone-else" }),
  },
  "settings.manage": { type: "settings.manage" },
};

/** Role defaults for each override key (viewer has none of them). */
const ROLE_DEFAULT: Record<OverrideKey, StaffRole[]> = {
  "signage.create": ["admin", "ops", "marketing"],
  "sponsorship.create": ["admin", "ops", "sales"],
  "costs.edit": ["admin", "ops"],
  "approval.decide": ["admin"], // everyone else needs the step assigned
  "settings.manage": ["admin", "ops"],
};

describe("permission overrides matrix", () => {
  const nonAdminRoles: StaffRole[] = ["ops", "marketing", "sales", "event_director", "viewer"];

  for (const key of OVERRIDE_KEYS) {
    describe(key, () => {
      for (const role of nonAdminRoles) {
        const byDefault = ROLE_DEFAULT[key].includes(role);
        it(`${role}: absent → role default (${byDefault})`, () => {
          expect(can(staff(role), ACTION_FOR[key])).toBe(byDefault);
          expect(can(staff(role, {}), ACTION_FOR[key])).toBe(byDefault);
        });
        it(`${role}: false blocks`, () => {
          expect(can(staff(role, { [key]: false }), ACTION_FOR[key])).toBe(false);
        });
        if (key !== "approval.decide") {
          it(`${role}: true grants`, () => {
            expect(can(staff(role, { [key]: true }), ACTION_FOR[key])).toBe(true);
          });
        }
      }

      it("admin is immune to overrides", () => {
        expect(can(staff("admin", { [key]: false }), ACTION_FOR[key])).toBe(true);
      });
    });
  }

  it("approval.decide: true never bypasses step assignment", () => {
    const sales = staff("sales", { "approval.decide": true });
    expect(can(sales, { type: "approval.decide", step: step() })).toBe(false); // marketing step
    expect(
      can(sales, { type: "approval.decide", step: step({ assignedRole: "sales" }) }),
    ).toBe(true); // their own step still works
    expect(
      can(sales, {
        type: "approval.decide",
        step: step({ assignedRole: null, assignedUserId: "sales-user" }),
      }),
    ).toBe(true); // named assignment still works
  });

  it("approval.decide: false blocks even the assigned user", () => {
    const marketing = staff("marketing", { "approval.decide": false });
    expect(can(marketing, { type: "approval.decide", step: step() })).toBe(false);
    const named = staff("marketing", { "approval.decide": false }, "named");
    expect(
      can(named, {
        type: "approval.decide",
        step: step({ assignedRole: null, assignedUserId: "named" }),
      }),
    ).toBe(false);
  });

  it("unknown override keys are ignored", () => {
    const actor = staff("viewer", { "users.manage": true } as PermissionOverrides);
    expect(can(actor, { type: "users.manage" })).toBe(false);
  });

  it("viewer with signage.create override can create", () => {
    expect(can(staff("viewer", { "signage.create": true }), { type: "signage.create" })).toBe(true);
  });
});

describe("sponsorship.create defaults", () => {
  const rows: Array<[StaffRole, boolean]> = [
    ["admin", true],
    ["ops", true],
    ["sales", true],
    ["marketing", false],
    ["event_director", false],
    ["viewer", false],
  ];
  for (const [role, allowed] of rows) {
    it(`${role} → ${allowed}`, () => {
      expect(can(staff(role), { type: "sponsorship.create" })).toBe(allowed);
    });
  }
});

describe("task actions", () => {
  const mine: TaskCtx = { assignedToUserId: "ops-user", createdByUserId: "ops-user" };
  const assignedToMe: TaskCtx = { assignedToUserId: "ops-user", createdByUserId: "admin-user" };
  const someoneElses: TaskCtx = { assignedToUserId: "x", createdByUserId: "y" };

  it("everyone may keep a personal list, viewers included", () => {
    for (const role of ["admin", "ops", "marketing", "sales", "event_director", "viewer"] as const) {
      expect(can(staff(role), { type: "task.create" })).toBe(true);
    }
  });

  it("viewers may not assign tasks to others", () => {
    expect(can(staff("viewer"), { type: "task.assign" })).toBe(false);
    expect(can(staff("sales"), { type: "task.assign" })).toBe(true);
  });

  it("update: assignee, creator or admin", () => {
    expect(can(staff("ops"), { type: "task.update", task: mine })).toBe(true);
    expect(can(staff("ops"), { type: "task.update", task: assignedToMe })).toBe(true);
    expect(can(staff("ops"), { type: "task.update", task: someoneElses })).toBe(false);
    expect(can(staff("admin"), { type: "task.update", task: someoneElses })).toBe(true);
  });

  it("delete: creator or admin only", () => {
    expect(can(staff("ops"), { type: "task.delete", task: mine })).toBe(true);
    expect(can(staff("ops"), { type: "task.delete", task: assignedToMe })).toBe(false);
    expect(can(staff("admin"), { type: "task.delete", task: assignedToMe })).toBe(true);
  });
});

describe("sales and sponsorship items", () => {
  it("sales edit, upload and submit sponsorship items without a sponsor attached", () => {
    const sales = staff("sales");
    expect(can(sales, { type: "signage.edit", item: sponsorshipItem })).toBe(true);
    expect(can(sales, { type: "artwork.upload", item: sponsorshipItem })).toBe(true);
    expect(can(sales, { type: "signage.submit", item: sponsorshipItem })).toBe(true);
    expect(can(sales, { type: "signage.edit", item })).toBe(false);
    expect(can(sales, { type: "signage.submit", item })).toBe(false);
  });
});

describe("overrides carry granted users through to sign-off", () => {
  const own = (userId: string, kind: "signage" | "sponsorship_item" = "signage"): SignageItemCtx => ({
    ...item,
    kind,
    ownerUserId: userId,
  });

  it("sales granted 'add signage' can edit, upload and submit their own signage", () => {
    const sales = staff("sales", { "signage.create": true });
    for (const type of ["signage.edit", "artwork.upload", "signage.submit"] as const) {
      expect(can(sales, { type, item: own("sales-user") })).toBe(true);
      // …but not somebody else's
      expect(can(sales, { type, item: own("someone-else") })).toBe(false);
    }
  });

  it("event director granted 'add sponsorship items' can submit their own", () => {
    const director = staff("event_director", { "sponsorship.create": true });
    expect(
      can(director, { type: "signage.submit", item: own("event_director-user", "sponsorship_item") }),
    ).toBe(true);
  });

  it("'edit costs' also reveals costs", () => {
    expect(can(staff("sales"), { type: "costs.view" })).toBe(false);
    expect(can(staff("sales", { "costs.edit": true }), { type: "costs.view" })).toBe(true);
  });
});
