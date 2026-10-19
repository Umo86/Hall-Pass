/**
 * Events per person and the people rules (rule 6b of personChangeRefusal),
 * written before the code: a manager limited to some events gives and takes
 * only the events they can open themselves; hidden events stay; nobody gets
 * an empty list.
 */
import { describe, expect, it } from "vitest";
import {
  assignableEditions,
  canExtendToCopy,
  canRenewInvite,
  personChangeRefusal,
  type PersonAccess,
  type PersonCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";
import { templateRefusal, templatesFor, PERSON_TEMPLATES } from "@/lib/users/templates";

const ORG = "org-1";
const A = "ed-a";
const B = "ed-b";
const C = "ed-c";

function staff(role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor {
  return { kind: "staff", userId: `${role}-me`, organisationId: ORG, role, ...extra };
}

const superAdmin = staff("admin", { userId: "boss" });
const freeManager = staff("ops", { userId: "mgr-all", managerScope: "everyone" });
const limitedManager = staff("ops", {
  userId: "mgr-a",
  managerScope: "everyone",
  editionIds: [A, C],
});
const person: PersonCtx = {
  organisationId: ORG,
  userId: "sam",
  role: "marketing",
  departmentId: "d1",
  managerScope: null,
};
const access = (editionIds: readonly string[] | null | undefined): PersonAccess => ({
  role: "marketing",
  departmentId: "d1",
  features: null,
  overrides: {},
  managerScope: null,
  signoffs: [],
  ...(editionIds === undefined ? {} : { editionIds }),
});

const GIVE_OTHER = "You can only give the events you can open yourself";
const GIVE_ALL = "You can only give the events you can open yourself — tick them one by one";
const TAKE = "You can only take away events you can open yourself — ask a super admin";
const EMPTY = "Tick at least one event, or choose All events";

describe("personChangeRefusal rule 6b", () => {
  const cases: [string, StaffActor, PersonAccess | null, PersonAccess, string | null][] = [
    ["super admin: anything", superAdmin, access(null), access([B]), null],
    ["super admin: back to all", superAdmin, access([B]), access(null), null],
    ["super admin: empty list", superAdmin, access(null), access([]), EMPTY],
    ["unlimited manager: any list", freeManager, access(null), access([B]), null],
    ["unlimited manager: all", freeManager, access([B]), access(null), null],
    ["unlimited manager: empty", freeManager, access(null), access([]), EMPTY],
    ["limited: give own", limitedManager, access([A]), access([A, C]), null],
    ["limited: give other", limitedManager, access([A]), access([A, B]), GIVE_OTHER],
    ["limited: All when they had a list", limitedManager, access([A]), access(null), GIVE_ALL],
    ["limited: keep All unchanged", limitedManager, access(null), access(null), null],
    ["limited: take away from All", limitedManager, access(null), access([A]), TAKE],
    ["limited: take away own", limitedManager, access([A, C]), access([A]), null],
    ["limited: take away hidden", limitedManager, access([A, B]), access([A]), TAKE],
    ["limited: keep hidden + own", limitedManager, access([A, B]), access([B, C]), null],
    ["limited: empty list", limitedManager, access([A]), access([]), EMPTY],
    ["limited: undefined skips", limitedManager, access(undefined), access(undefined), null],
    ["limited: undefined after skips", limitedManager, access([B]), access(undefined), null],
  ];
  for (const [name, actor, before, after, want] of cases) {
    it(name, () => {
      expect(personChangeRefusal(actor, before ? person : null, before, after)).toBe(want);
    });
  }

  it("adding someone: a limited manager gives only their events, never All", () => {
    expect(personChangeRefusal(limitedManager, null, null, access([A]))).toBeNull();
    expect(personChangeRefusal(limitedManager, null, null, access([B]))).toBe(GIVE_OTHER);
    expect(personChangeRefusal(limitedManager, null, null, access(null))).toBe(GIVE_ALL);
    expect(personChangeRefusal(freeManager, null, null, access(null))).toBeNull();
  });

  it("the rule comes after scope: out of scope is still out of scope", () => {
    const dm = staff("marketing", {
      userId: "dm",
      departmentId: "d2",
      managerScope: "department",
      editionIds: [A],
    });
    expect(personChangeRefusal(dm, person, access([A]), access([A]))).toBe(
      "You can't change this person's access",
    );
  });
});

describe("assignableEditions", () => {
  const all = [A, B, C];
  it("'all' for super admins and anyone without a list", () => {
    expect(assignableEditions(superAdmin, all)).toBe("all");
    expect(assignableEditions(staff("admin", { editionIds: [A] }), all)).toBe("all");
    expect(assignableEditions(freeManager, all)).toBe("all");
  });
  it("otherwise the actor's own events, in the given order", () => {
    expect(assignableEditions(limitedManager, all)).toEqual([A, C]);
    expect(assignableEditions(limitedManager, [C, B])).toEqual([C]);
  });
  it("partners give nothing", () => {
    expect(
      assignableEditions({ kind: "external", userId: "x", organisationId: ORG, grants: [] }, all),
    ).toEqual([]);
  });
});

describe("canRenewInvite with a limited invitation", () => {
  it("a limited manager renews only an invitation within their events", () => {
    expect(canRenewInvite(limitedManager, access([A]))).toBe(true);
    expect(canRenewInvite(limitedManager, access([A, B]))).toBe(false);
    expect(canRenewInvite(limitedManager, access(null))).toBe(false);
    expect(canRenewInvite(freeManager, access(null))).toBe(true);
    expect(canRenewInvite(freeManager, access([B]))).toBe(true);
    expect(canRenewInvite(superAdmin, access([B]))).toBe(true);
  });
});

describe("canExtendToCopy", () => {
  it("super admins always; managers in scope who can open the source", () => {
    expect(canExtendToCopy(superAdmin, person, B)).toBe(true);
    expect(canExtendToCopy(freeManager, person, B)).toBe(true);
    expect(canExtendToCopy(limitedManager, person, A)).toBe(true);
    expect(canExtendToCopy(limitedManager, person, B)).toBe(false);
    expect(canExtendToCopy(limitedManager, { ...person, role: "admin" }, A)).toBe(false);
    expect(canExtendToCopy(staff("ops"), person, A)).toBe(false); // not a manager
    expect(canExtendToCopy(freeManager, { ...person, organisationId: "org-2" }, A)).toBe(false);
  });
});

describe("templates are unchanged for limited managers", () => {
  it("the same templates as for the same manager without a list", () => {
    const free = { ...limitedManager, editionIds: null };
    expect(templatesFor(limitedManager, { departmentId: null }).map((t) => t.id)).toEqual(
      templatesFor(free, { departmentId: null }).map((t) => t.id),
    );
    for (const t of PERSON_TEMPLATES) {
      expect(templateRefusal(limitedManager, t, null)).toBe(templateRefusal(free, t, null));
    }
  });
});
