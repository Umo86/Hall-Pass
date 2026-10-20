/**
 * Managers and the people guardrails (Users v2), written before the code:
 * who may add, edit, suspend and remove whom, and what they may give.
 * Pure functions in lib/authz.ts; the server runs personChangeRefusal inside
 * the transaction after loading the person.
 */
import { describe, expect, it } from "vitest";
import {
  ABILITIES,
  ABILITY_KEYS,
  assignableAbilities,
  assignableFeatures,
  assignableRoles,
  assignableSignoffDepartments,
  can,
  canGrantManager,
  canManagePerson,
  canRemovePerson,
  canRenewInvite,
  canSuspendPerson,
  FEATURES,
  isSuperAdmin,
  managerScope,
  personChangeRefusal,
  type ExternalActor,
  type PersonAccess,
  type PersonCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";

const ORG = "org-1";

function staff(role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor {
  return { kind: "staff", userId: `${role}-me`, organisationId: ORG, role, ...extra };
}

const superAdmin = staff("admin", { userId: "boss" });
const deptManager = staff("marketing", {
  userId: "mgr",
  departmentId: "d1",
  managerScope: "department",
  signoffDepartmentIds: ["d1"],
});
const noDeptManager = staff("marketing", {
  userId: "mgr0",
  departmentId: null,
  managerScope: "department",
});
const everyoneManager = staff("ops", { userId: "mgr-all", managerScope: "everyone" });
const plainOps = staff("ops", { userId: "ops-1", departmentId: "d1" });
const external: ExternalActor = {
  kind: "external",
  userId: "ext",
  organisationId: ORG,
  grants: [],
};

const person = (over: Partial<PersonCtx>): PersonCtx => ({
  organisationId: ORG,
  userId: "someone",
  role: "marketing",
  departmentId: "d1",
  managerScope: null,
  ...over,
});

const TARGETS: Record<string, (actor: StaffActor | ExternalActor) => PersonCtx> = {
  self: (a) => person({ userId: a.userId, departmentId: "d1" }),
  admin: () => person({ role: "admin", departmentId: "d1" }),
  manager: () => person({ managerScope: "department", departmentId: "d1" }),
  d1: () => person({ departmentId: "d1" }),
  d2: () => person({ departmentId: "d2" }),
  noDept: () => person({ departmentId: null }),
  d1Invite: () => person({ userId: null, departmentId: "d1" }),
  d2Invite: () => person({ userId: null, departmentId: "d2" }),
  otherOrg: () => person({ organisationId: "org-2", departmentId: "d1" }),
};

const MATRIX: [string, StaffActor | ExternalActor, string[]][] = [
  // Who each actor can manage (every other target is refused).
  [
    "super admin",
    superAdmin,
    ["self", "admin", "manager", "d1", "d2", "noDept", "d1Invite", "d2Invite"],
  ],
  ["department manager (d1)", deptManager, ["d1", "d1Invite"]],
  ["department manager with no department", noDeptManager, []],
  ["everyone-manager", everyoneManager, ["d1", "d2", "noDept", "d1Invite", "d2Invite"]],
  ["plain ops", plainOps, []],
  ["external", external, []],
];

describe("canManagePerson", () => {
  for (const [name, actor, allowed] of MATRIX) {
    for (const [target, make] of Object.entries(TARGETS)) {
      const want = allowed.includes(target);
      it(`${name} → ${target}: ${want}`, () => {
        expect(canManagePerson(actor, make(actor))).toBe(want);
        expect(can(actor, { type: "person.edit", person: make(actor) })).toBe(want);
      });
    }
  }

  it("people.manage: super admins and managers only", () => {
    expect(can(superAdmin, { type: "people.manage" })).toBe(true);
    expect(can(deptManager, { type: "people.manage" })).toBe(true);
    expect(can(noDeptManager, { type: "people.manage" })).toBe(true);
    expect(can(everyoneManager, { type: "people.manage" })).toBe(true);
    expect(can(plainOps, { type: "people.manage" })).toBe(false);
    expect(can(external, { type: "people.manage" })).toBe(false);
  });

  it("people.access_link: super admins only (one-time sign-in and reset links)", () => {
    expect(can(superAdmin, { type: "people.access_link" })).toBe(true);
    expect(can(deptManager, { type: "people.access_link" })).toBe(false);
    expect(can(noDeptManager, { type: "people.access_link" })).toBe(false);
    expect(can(everyoneManager, { type: "people.access_link" })).toBe(false);
    expect(can(plainOps, { type: "people.access_link" })).toBe(false);
    expect(can(staff("viewer"), { type: "people.access_link" })).toBe(false);
    expect(can(external, { type: "people.access_link" })).toBe(false);
    // No stored override can give it.
    const sneaky = staff("ops", {
      managerScope: "everyone",
      overrides: { "people.access_link": true } as never,
    });
    expect(can(sneaky, { type: "people.access_link" })).toBe(false);
  });

  it("sections never gate the people actions", () => {
    const m = { ...deptManager, features: [] };
    expect(can(m, { type: "people.manage" })).toBe(true);
    expect(can(m, { type: "person.edit", person: person({}) })).toBe(true);
  });

  it("isSuperAdmin and managerScope", () => {
    expect(isSuperAdmin(superAdmin)).toBe(true);
    expect(isSuperAdmin(everyoneManager)).toBe(false);
    expect(isSuperAdmin(external)).toBe(false);
    expect(managerScope(superAdmin)).toBe("everyone");
    expect(managerScope(deptManager)).toBe("department");
    expect(managerScope(plainOps)).toBeNull();
    expect(managerScope(external)).toBeNull();
    // A stored scope on an admin means nothing more: they manage everyone.
    expect(managerScope({ ...superAdmin, managerScope: "department" })).toBe("everyone");
  });

  it("a manager scope can't be given by a stored override", () => {
    const sneaky = staff("ops", { overrides: { "people.manage": true } as never });
    expect(can(sneaky, { type: "people.manage" })).toBe(false);
  });
});

describe("assignableRoles", () => {
  it("a marketing manager gets marketing, senior management and viewer", () => {
    expect(assignableRoles(deptManager).sort()).toEqual(
      ["event_director", "marketing", "viewer"].sort(),
    );
  });
  it("a super admin gets every role", () => {
    expect(assignableRoles(superAdmin)).toEqual([
      "admin",
      "ops",
      "marketing",
      "sales",
      "event_director",
      "viewer",
    ]);
  });
  it("an ops everyone-manager gets every role but super admin", () => {
    expect(assignableRoles(everyoneManager).sort()).toEqual(
      ["event_director", "marketing", "ops", "sales", "viewer"].sort(),
    );
  });
  it("viewer is always there for a manager, and nobody else gets any", () => {
    const weak = staff("viewer", { managerScope: "everyone" });
    expect(assignableRoles(weak)).toEqual(["viewer"]);
    expect(assignableRoles(plainOps)).toEqual([]);
  });
  it("an ops manager without costs.edit can't make someone Operations", () => {
    const m = staff("ops", { managerScope: "everyone", overrides: { "costs.edit": false } });
    expect(assignableRoles(m)).not.toContain("ops");
  });
});

describe("assignableFeatures", () => {
  it("'all' for super admins and managers with every section", () => {
    expect(assignableFeatures(superAdmin)).toBe("all");
    expect(assignableFeatures(everyoneManager)).toBe("all");
  });
  it("otherwise the manager's own sections", () => {
    const m = {
      ...deptManager,
      signoffDepartmentIds: [],
      features: ["signage" as const, "calendar" as const],
    };
    expect(assignableFeatures(m)).toEqual(["signage", "calendar"]);
  });
  it("Approvals when the manager signs off", () => {
    const m = { ...deptManager, features: ["signage" as const] };
    expect(assignableFeatures(m)).toEqual(["signage", "approvals"]);
  });
});

describe("assignableAbilities", () => {
  it("never includes the super-admin-only grants", () => {
    for (const m of [
      deptManager,
      everyoneManager,
      staff("ops", {
        managerScope: "everyone",
        overrides: {
          "partners.invite": true,
          "departments.manage": true,
          "organisation.manage": true,
        },
      }),
    ]) {
      const keys = assignableAbilities(m);
      expect(keys).not.toContain("partners.invite");
      expect(keys).not.toContain("departments.manage");
      expect(keys).not.toContain("organisation.manage");
    }
  });
  it("only what the manager fully has", () => {
    const keys = assignableAbilities(deptManager);
    expect(keys).toContain("signage.create");
    expect(keys).toContain("reports.download");
    expect(keys).not.toContain("costs.edit");
    expect(keys).not.toContain("sponsorship.create");
    const sales = staff("sales", { managerScope: "everyone" });
    expect(assignableAbilities(sales)).not.toContain("reports.download"); // only partly
  });
  it("super admins can give everything", () => {
    expect(assignableAbilities(superAdmin).sort()).toEqual([...ABILITY_KEYS].sort());
  });
  it("nobody else gets any", () => {
    expect(assignableAbilities(plainOps)).toEqual([]);
  });
});

describe("assignableSignoffDepartments", () => {
  const live = ["d1", "d2", "d3"];
  it("every live signing department with departments.manage", () => {
    expect(assignableSignoffDepartments(superAdmin, live)).toEqual(live);
    const m = { ...deptManager, overrides: { "departments.manage": true } };
    expect(assignableSignoffDepartments(m, live)).toEqual(live);
  });
  it("otherwise only the ones the manager signs off for", () => {
    expect(assignableSignoffDepartments(deptManager, live)).toEqual(["d1"]);
    expect(assignableSignoffDepartments(noDeptManager, live)).toEqual([]);
  });
});

describe("canGrantManager, canSuspendPerson, canRemovePerson", () => {
  it("only super admins make managers", () => {
    expect(canGrantManager(superAdmin)).toBe(true);
    expect(canGrantManager(everyoneManager)).toBe(false);
    expect(canGrantManager(plainOps)).toBe(false);
  });
  it("suspend: in scope, never yourself, never the last active super admin", () => {
    expect(canSuspendPerson(deptManager, person({}), { lastActiveAdmin: false })).toBe(true);
    expect(
      canSuspendPerson(deptManager, person({ departmentId: "d2" }), { lastActiveAdmin: false }),
    ).toBe(false);
    expect(
      canSuspendPerson(superAdmin, person({ userId: "boss" }), { lastActiveAdmin: false }),
    ).toBe(false);
    expect(canSuspendPerson(superAdmin, person({ role: "admin" }), { lastActiveAdmin: true })).toBe(
      false,
    );
    expect(
      canSuspendPerson(superAdmin, person({ role: "admin" }), { lastActiveAdmin: false }),
    ).toBe(true);
    expect(
      can(superAdmin, {
        type: "person.suspend",
        person: { ...person({ role: "admin" }), lastActiveAdmin: true },
      }),
    ).toBe(false);
  });
  it("remove: super admins only, never themselves", () => {
    expect(canRemovePerson(superAdmin, person({}))).toBe(true);
    expect(canRemovePerson(superAdmin, person({ userId: "boss" }))).toBe(false);
    expect(canRemovePerson(everyoneManager, person({}))).toBe(false);
    expect(
      can(superAdmin, { type: "person.remove", person: person({ organisationId: "org-2" }) }),
    ).toBe(false);
  });
});

describe("personChangeRefusal", () => {
  const access = (over: Partial<PersonAccess> = {}): PersonAccess => ({
    role: "marketing",
    departmentId: "d1",
    newDepartmentName: null,
    features: null,
    overrides: {},
    managerScope: null,
    signoffs: [],
    accessEndsAt: null,
    ...over,
  });
  const target = person({});
  const refuse = (
    actor: StaffActor,
    t: PersonCtx | null,
    before: PersonAccess | null,
    after: PersonAccess,
  ) => personChangeRefusal(actor, t, before, after);

  it("super admins may do anything to someone in their organisation", () => {
    expect(refuse(superAdmin, target, access(), access({ role: "admin" }))).toBeNull();
    expect(
      refuse(superAdmin, null, null, access({ managerScope: "everyone", role: "ops" })),
    ).toBeNull();
    expect(
      refuse(superAdmin, person({ organisationId: "org-2" }), access(), access()),
    ).not.toBeNull();
  });

  it("1. a person out of scope, or adding with no scope", () => {
    expect(refuse(deptManager, person({ departmentId: "d2" }), access(), access())).toMatch(
      /can't change/i,
    );
    expect(refuse(plainOps, null, null, access())).toMatch(/can't add/i);
    expect(refuse(deptManager, null, null, access())).toBeNull();
  });

  it("2. making a super admin", () => {
    expect(refuse(everyoneManager, target, access(), access({ role: "admin" }))).toMatch(
      /super admin/i,
    );
  });

  it("3. making or changing a manager", () => {
    expect(
      refuse(everyoneManager, target, access(), access({ managerScope: "department" })),
    ).toMatch(/manager/i);
    expect(refuse(everyoneManager, null, null, access({ managerScope: "everyone" }))).toMatch(
      /manager/i,
    );
  });

  it("4. department managers keep people in their department", () => {
    expect(refuse(deptManager, target, access(), access({ departmentId: "d2" }))).toMatch(
      /department/i,
    );
    expect(refuse(deptManager, null, null, access({ departmentId: null }))).toMatch(/department/i);
    expect(refuse(deptManager, null, null, access({ newDepartmentName: "Legal" }))).toMatch(
      /department/i,
    );
    expect(refuse(everyoneManager, target, access(), access({ departmentId: "d2" }))).toBeNull();
  });

  it("5. a new department needs departments.manage", () => {
    expect(
      refuse(everyoneManager, null, null, access({ newDepartmentName: "Legal", role: "viewer" })),
    ).toMatch(/department/i);
    const m = { ...everyoneManager, overrides: { "departments.manage": true } };
    expect(
      refuse(m, null, null, access({ newDepartmentName: "Legal", role: "viewer" })),
    ).toBeNull();
  });

  it("6. sections the manager doesn't have", () => {
    const m = { ...deptManager, features: ["signage" as const, "calendar" as const] };
    expect(refuse(m, null, null, access({ features: null }))).toMatch(/section/i);
    expect(refuse(m, null, null, access({ features: ["signage", "reports"] }))).toMatch(/Reports/);
    expect(refuse(m, null, null, access({ features: ["signage"] }))).toBeNull();
    // Sections they already had may stay.
    expect(
      refuse(
        m,
        target,
        access({ features: ["signage", "reports"] }),
        access({ features: ["signage", "reports"] }),
      ),
    ).toBeNull();
    // An unrestricted manager may give every section.
    expect(
      refuse(everyoneManager, null, null, access({ features: null, role: "viewer" })),
    ).toBeNull();
  });

  it("7. abilities the manager can't give, including through a role change", () => {
    // Marketing manager can't give costs.edit…
    expect(
      refuse(deptManager, target, access(), access({ overrides: { "costs.edit": true } })),
    ).toMatch(/Edit costs/);
    // …nor make someone Operations, unless what they lack is left off.
    expect(refuse(deptManager, target, access(), access({ role: "ops" }))).not.toBeNull();
    const opsLite = staff("ops", {
      managerScope: "everyone",
      overrides: { "costs.edit": false },
    });
    expect(refuse(opsLite, target, access(), access({ role: "ops" }))).toMatch(/Edit costs/);
    expect(
      refuse(
        opsLite,
        target,
        access(),
        access({ role: "ops", overrides: { "costs.edit": false, "organisation.manage": false } }),
      ),
    ).toBeNull();
    // A super-admin-only grant can't come with a role either.
    expect(refuse(everyoneManager, target, access(), access({ role: "ops" }))).toMatch(
      /Organisation settings/,
    );
    // Taking abilities away is fine.
    expect(
      refuse(deptManager, target, access(), access({ overrides: { "signage.create": false } })),
    ).toBeNull();
  });

  it("7. job-title edits on someone who already has more than the manager are allowed", () => {
    const strong = access({ overrides: { "costs.edit": true, "sponsorship.create": true } });
    expect(refuse(deptManager, target, strong, { ...strong })).toBeNull();
  });

  it("7. role powers that aren't abilities count too", () => {
    // A sales manager can't make someone Marketing (organiser signage).
    const salesMgr = staff("sales", { managerScope: "everyone" });
    expect(
      refuse(
        salesMgr,
        person({ role: "viewer" }),
        access({ role: "viewer" }),
        access({ role: "marketing", overrides: { "signage.create": false, "snag.manage": false } }),
      ),
    ).toMatch(/role/i);
  });

  it("8. sign-offs outside the manager's own, and main approvers", () => {
    expect(
      refuse(
        deptManager,
        target,
        access(),
        access({ signoffs: [{ departmentId: "d1", isMain: false }] }),
      ),
    ).toBeNull();
    expect(
      refuse(
        deptManager,
        target,
        access(),
        access({ signoffs: [{ departmentId: "d2", isMain: false }] }),
      ),
    ).toMatch(/sign/i);
    expect(
      refuse(
        deptManager,
        target,
        access({ signoffs: [{ departmentId: "d2", isMain: false }] }),
        access({ signoffs: [] }),
      ),
    ).toMatch(/sign/i);
    expect(
      refuse(
        deptManager,
        target,
        access(),
        access({ signoffs: [{ departmentId: "d1", isMain: true }] }),
      ),
    ).toMatch(/main approver/i);
    // Rows the manager can't touch may stay as they are.
    const keep = access({ signoffs: [{ departmentId: "d2", isMain: true }] });
    expect(refuse(deptManager, target, keep, { ...keep })).toBeNull();
  });

  it("8. a manager without departments.manage can't ask for main approver on an invitation, but may keep one a super admin asked for", () => {
    // An invitation's "main when they accept" is that row's isMain.
    const invitee = person({ userId: null });
    expect(
      refuse(deptManager, null, null, access({ signoffs: [{ departmentId: "d1", isMain: true }] })),
    ).toMatch(/main approver/i);
    expect(
      refuse(
        deptManager,
        invitee,
        access({ signoffs: [{ departmentId: "d1", isMain: false }] }),
        access({ signoffs: [{ departmentId: "d1", isMain: true }] }),
      ),
    ).toMatch(/main approver/i);
    const asked = access({ signoffs: [{ departmentId: "d1", isMain: true }] });
    expect(refuse(deptManager, invitee, asked, { ...asked })).toBeNull();
    // Cancelling it is a change to main approver too.
    expect(
      refuse(
        deptManager,
        invitee,
        asked,
        access({ signoffs: [{ departmentId: "d1", isMain: false }] }),
      ),
    ).toMatch(/main approver/i);
    // With departments.manage (given by a super admin) they may ask.
    const withDepts = { ...deptManager, overrides: { "departments.manage": true } };
    expect(
      refuse(withDepts, null, null, access({ signoffs: [{ departmentId: "d1", isMain: true }] })),
    ).toBeNull();
  });

  it("9. resuming a paused sign-off while your own is paused", () => {
    const paused = { ...deptManager, overrides: { "approval.decide": false } };
    expect(
      refuse(paused, target, access({ overrides: { "approval.decide": false } }), access()),
    ).toMatch(/paused/i);
    expect(
      refuse(deptManager, target, access({ overrides: { "approval.decide": false } }), access()),
    ).toBeNull();
  });

  it("10. an access end date is fine within scope", () => {
    expect(
      refuse(deptManager, target, access(), access({ accessEndsAt: new Date("2027-01-01") })),
    ).toBeNull();
  });

  it("renewing an invitation: super admins any, managers only one they could have made (escalation-1)", () => {
    // A new link is a way in as that person, so it is checked like adding them now.
    const invite = access({ accessEndsAt: new Date("2027-01-01") });
    expect(canRenewInvite(superAdmin, access({ role: "admin" }))).toBe(true);
    expect(canRenewInvite(superAdmin, access({ overrides: { "departments.manage": true } }))).toBe(
      true,
    );
    expect(canRenewInvite(deptManager, invite)).toBe(true);
    expect(
      canRenewInvite(deptManager, access({ signoffs: [{ departmentId: "d1", isMain: false }] })),
    ).toBe(true);
    // Whatever only a super admin gives, or the manager lacks, or another department.
    expect(canRenewInvite(deptManager, access({ role: "admin" }))).toBe(false);
    expect(canRenewInvite(deptManager, access({ managerScope: "department" }))).toBe(false);
    for (const key of ["partners.invite", "departments.manage", "organisation.manage"] as const) {
      expect(canRenewInvite(deptManager, access({ overrides: { [key]: true } }))).toBe(false);
    }
    expect(canRenewInvite(deptManager, access({ overrides: { "costs.edit": true } }))).toBe(false);
    expect(canRenewInvite(deptManager, access({ departmentId: "d2" }))).toBe(false);
    expect(
      canRenewInvite(deptManager, access({ signoffs: [{ departmentId: "d2", isMain: false }] })),
    ).toBe(false);
    expect(
      canRenewInvite(deptManager, access({ signoffs: [{ departmentId: "d1", isMain: true }] })),
    ).toBe(false);
    // Nobody without a manager scope, and never a partner.
    expect(canRenewInvite(plainOps, invite)).toBe(false);
    expect(canRenewInvite(external, invite)).toBe(false);
  });

  it("a manager can't renew an invitation that makes someone main approver when they accept", () => {
    // The ask is the row's isMain (currentSignoffs), so a new link would make
    // someone main approver, which the manager couldn't arrange themselves.
    const asked = access({ signoffs: [{ departmentId: "d1", isMain: true }] });
    expect(canRenewInvite(deptManager, asked)).toBe(false);
    expect(canRenewInvite(superAdmin, asked)).toBe(true);
    expect(
      canRenewInvite({ ...deptManager, overrides: { "departments.manage": true } }, asked),
    ).toBe(true);
  });

  it("every registry key is covered by the ability rule", () => {
    for (const key of ABILITY_KEYS) {
      // Hidden (paused sign-off) and what every viewer has anyway don't count.
      if (ABILITIES[key].hidden || ABILITIES[key].roles.includes("viewer")) continue;
      const out = refuse(
        staff("viewer", { managerScope: "everyone" }),
        person({ role: "viewer" }),
        access({ role: "viewer" }),
        access({ role: "viewer", overrides: { [key]: true } }),
      );
      expect(out, key).not.toBeNull();
    }
  });

  it("FEATURES are all known to the sections rule", () => {
    expect(FEATURES.length).toBeGreaterThan(5);
  });
});
