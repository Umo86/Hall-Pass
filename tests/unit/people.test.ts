/**
 * Who can be handed what (lib/people.ts and components/people/groups.ts):
 * owners by item kind, sign-off people, task assignees, the labels kept on
 * people who can no longer act, how pickers group people, and where open
 * department sign-offs go when routing changes. Pure — no database.
 */
import { describe, expect, it } from "vitest";
import {
  canOwnItem,
  eligibleIds,
  kindWords,
  ownerRefusal,
  personOptions,
  personOptionsForAny,
  refusalMessage,
  rerouteDepartmentSteps,
  signoffRefusal,
  taskRefusal,
  type OwnableItem,
  type TeamMember,
} from "@/lib/people";
import { groupPeople, personLabel, pickable, type PersonOption } from "@/components/people/groups";
import { snagClosedRecipients } from "@/lib/domain/signage";
import { panelSyncPatch } from "@/lib/domain/stand-designs";
import { supplierCantSignIn } from "@/components/onsite/rules";
import type { StaffRole } from "@/lib/authz";

const ORG = "org-1";
const NOW = new Date("2026-10-16T12:00:00Z");

function member(id: string, role: StaffRole, extra: Partial<TeamMember> = {}): TeamMember {
  return {
    userId: id,
    name: id,
    email: `${id}@test`,
    jobTitle: null,
    role,
    overrides: {},
    features: null,
    departmentId: null,
    departmentName: null,
    managerScope: null,
    suspendedAt: null,
    accessEndsAt: null,
    signoffDepartmentIds: [],
    ...extra,
  };
}

const opts = { organisationId: ORG, now: NOW };
const organiser: OwnableItem = { kind: "signage", sponsored: false };
const sponsorSign: OwnableItem = { kind: "signage", sponsored: true };
const sponsorship: OwnableItem = { kind: "sponsorship_item" };
const stand: OwnableItem = { kind: "stand_design" };
const panel: OwnableItem = { kind: "stand_panel" };

describe("who can own an item", () => {
  // role × kind: the work an owner is chased for (edit, artwork, send).
  const table: [StaffRole, OwnableItem, boolean][] = [
    ["admin", organiser, true],
    ["admin", stand, true],
    ["ops", organiser, true],
    ["ops", sponsorSign, true],
    ["ops", sponsorship, true],
    ["ops", stand, true],
    ["ops", panel, true],
    ["marketing", organiser, true],
    ["marketing", sponsorSign, true],
    ["marketing", sponsorship, true],
    ["marketing", stand, false],
    ["marketing", panel, false],
    ["sales", organiser, false],
    ["sales", sponsorSign, true],
    ["sales", sponsorship, true],
    ["sales", stand, false],
    ["event_director", organiser, false],
    ["event_director", sponsorSign, false],
    ["event_director", sponsorship, false],
    ["viewer", organiser, false],
    ["viewer", sponsorship, false],
  ];
  it.each(table)("%s owning %o → %s", (role, item, expected) => {
    expect(canOwnItem(member("p", role), item, opts)).toBe(expected);
  });

  it("refuses suspended and ended people, and people who have left", () => {
    expect(ownerRefusal(member("p", "ops", { suspendedAt: NOW }), organiser, opts)).toEqual({
      code: "suspended",
      label: "Suspended",
    });
    expect(
      ownerRefusal(
        member("p", "ops", { accessEndsAt: new Date("2026-10-15T22:59:59Z") }),
        organiser,
        opts,
      ),
    ).toEqual({ code: "ended", label: "Access ended" });
    // An end date still ahead is fine.
    expect(
      ownerRefusal(
        member("p", "ops", { accessEndsAt: new Date("2026-10-20T22:59:59Z") }),
        organiser,
        opts,
      ),
    ).toBeNull();
    expect(ownerRefusal(undefined, organiser, opts)).toEqual({
      code: "left",
      label: "No longer on the team",
    });
  });

  it("names the section someone no longer has", () => {
    const noSignage = member("p", "marketing", { features: ["sponsorship"] });
    expect(ownerRefusal(noSignage, organiser, opts)).toEqual({
      code: "section",
      label: "No longer has Signage",
    });
    expect(canOwnItem(noSignage, sponsorship, opts)).toBe(true);
    expect(ownerRefusal(member("p", "ops", { features: ["signage"] }), stand, opts)?.label).toBe(
      "No longer has Feature stands",
    );
  });

  it("counts people granted Add signage for their own items", () => {
    const granted = member("p", "viewer", { overrides: { "signage.create": true } });
    expect(canOwnItem(granted, organiser, opts)).toBe(true);
    // …but not a stand, which stays with Operations.
    expect(canOwnItem(granted, stand, opts)).toBe(false);
  });

  it("explains a refusal in words for the server", () => {
    const sam = member("Sam", "sales");
    const refusal = ownerRefusal(sam, organiser, opts)!;
    expect(refusalMessage("Sam", refusal, { type: "owner", item: organiser })).toBe(
      "Sam can't work on signage — pick someone else",
    );
    expect(
      refusalMessage("Dana", ownerRefusal(member("Dana", "event_director"), sponsorSign, opts)!, {
        type: "owner",
        item: sponsorSign,
      }),
    ).toBe("Dana can't work on sponsor signage — pick someone else");
    expect(refusalMessage("Jo", { code: "suspended", label: "Suspended" }, { type: "task" })).toBe(
      "Jo's access is suspended — pick someone else",
    );
    expect(
      refusalMessage(
        "Mia",
        { code: "section", label: "No longer has Signage" },
        { type: "owner", item: organiser },
      ),
    ).toBe("Mia doesn't have Signage — pick someone else");
    expect(kindWords(stand)).toBe("feature stands");
  });
});

describe("who can be handed a sign-off or a task", () => {
  it("sign-off: active, not a viewer, not paused, and in the department when given", () => {
    expect(signoffRefusal(member("a", "marketing"), { now: NOW })).toBeNull();
    expect(signoffRefusal(member("v", "viewer"), { now: NOW })?.label).toBe("Can't sign off");
    expect(
      signoffRefusal(member("p", "ops", { overrides: { "approval.decide": false } }), { now: NOW })
        ?.label,
    ).toBe("Can't sign off");
    expect(signoffRefusal(member("s", "ops", { suspendedAt: NOW }), { now: NOW })?.label).toBe(
      "Suspended",
    );
    const inMkt = member("m", "marketing", { signoffDepartmentIds: ["d-mkt"] });
    expect(signoffRefusal(inMkt, { departmentId: "d-mkt", now: NOW })).toBeNull();
    expect(signoffRefusal(inMkt, { departmentId: "d-ops", now: NOW })?.label).toBe(
      "Can't sign off",
    );
  });

  it("tasks: anyone with access, viewers included", () => {
    expect(taskRefusal(member("v", "viewer"), { now: NOW })).toBeNull();
    expect(taskRefusal(member("s", "ops", { suspendedAt: NOW }), { now: NOW })?.label).toBe(
      "Suspended",
    );
  });
});

describe("picker lists", () => {
  const team = [
    member("ops", "ops", { departmentId: "d-ops", departmentName: "Operations" }),
    member("mkt", "marketing", {
      departmentId: "d-mkt",
      departmentName: "Marketing",
      jobTitle: "Marketing Manager",
    }),
    member("sales", "sales", { departmentId: "d-sales", departmentName: "Sales" }),
    member("gone", "marketing", { suspendedAt: NOW }),
    member("viewer", "viewer"),
  ];

  it("offers only people who can, and keeps the current holder labelled", () => {
    const list = personOptions(
      team,
      { type: "owner", item: organiser },
      {
        ...opts,
        include: ["gone", "sales"],
      },
    );
    expect(list.map((p) => [p.id, p.unavailable])).toEqual([
      ["ops", null],
      ["mkt", null],
      ["gone", "Suspended"],
      ["sales", "Can't work on signage"],
    ]);
  });

  it("labels someone who has left with the name they had", () => {
    const list = personOptions(
      team,
      { type: "task" },
      {
        ...opts,
        include: ["left-1"],
        formerNames: new Map([["left-1", "Lee Left"]]),
      },
    );
    expect(list.find((p) => p.id === "left-1")).toMatchObject({
      name: "Lee Left",
      unavailable: "No longer on the team",
    });
  });

  it("lists anyone who can do any of several things once (bulk owner)", () => {
    const list = personOptionsForAny(
      team,
      [
        { type: "owner", item: organiser },
        { type: "owner", item: sponsorSign },
      ],
      opts,
    );
    expect(list.map((p) => p.id)).toEqual(["ops", "mkt", "sales"]);
    expect(eligibleIds(team, { type: "task" }, opts)).toEqual(["ops", "mkt", "sales", "viewer"]);
  });

  it("groups people: me first, my department, the rest A–Z, then no department", () => {
    const people: PersonOption[] = [
      {
        id: "z",
        name: "Zed",
        jobTitle: null,
        departmentId: null,
        departmentName: null,
        unavailable: null,
      },
      {
        id: "b",
        name: "Bea",
        jobTitle: null,
        departmentId: "d2",
        departmentName: "Sales",
        unavailable: null,
      },
      {
        id: "a",
        name: "Abe",
        jobTitle: "Lead",
        departmentId: "d1",
        departmentName: "Marketing",
        unavailable: null,
      },
      {
        id: "me",
        name: "Me Person",
        jobTitle: null,
        departmentId: "d2",
        departmentName: "Sales",
        unavailable: null,
      },
      {
        id: "c",
        name: "Cat",
        jobTitle: null,
        departmentId: "d2",
        departmentName: "Sales",
        unavailable: null,
      },
    ];
    const groups = groupPeople(people, { meId: "me", meDepartmentId: "d2" });
    expect(groups.map((g) => [g.label, g.people.map((p) => p.id)])).toEqual([
      ["You", ["me"]],
      ["Sales", ["b", "c"]],
      ["Marketing", ["a"]],
      ["No department", ["z"]],
    ]);
    expect(personLabel(people[2])).toBe("Abe — Lead");
    expect(personLabel(people[3], { meId: "me" })).toBe("Me (Me Person)");
    expect(personLabel({ ...people[0], unavailable: "Suspended" })).toBe("Zed (Suspended)");
  });

  it("hides people who can't be picked unless they are the current choice", () => {
    const people: PersonOption[] = [
      {
        id: "ok",
        name: "Ok",
        jobTitle: null,
        departmentId: null,
        departmentName: null,
        unavailable: null,
      },
      {
        id: "x",
        name: "X",
        jobTitle: null,
        departmentId: null,
        departmentName: null,
        unavailable: "Suspended",
      },
    ];
    expect(pickable(people).map((p) => p.id)).toEqual(["ok"]);
    expect(pickable(people, "x").map((p) => p.id)).toEqual(["ok", "x"]);
  });
});

describe("where open department sign-offs go", () => {
  const signers = new Map([
    ["d-mkt", new Set(["mia", "max"])],
    ["d-ops", new Set(["olly"])],
  ]);
  const routing = (mains: Record<string, string | null>) => ({
    signersOf: (id: string) => signers.get(id) ?? new Set<string>(),
    mainOf: (id: string) => mains[id] ?? null,
    // Olly (Operations) can sign; "gone" can't sign anything any more.
    canSign: (id: string) => id !== "gone",
  });
  const step = (over: Partial<Parameters<typeof rerouteDepartmentSteps>[0][number]>) => ({
    id: "s1",
    status: "pending",
    stepKind: "approval",
    assignedUserId: null,
    assignedDepartmentId: "d-mkt",
    delegatedFromUserId: null,
    ...over,
  });

  it("items on the defaults follow the department's current main approver", () => {
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max" })], {
        followsDefaults: true,
        ...routing({ "d-mkt": "mia" }),
      }),
    ).toEqual([{ id: "s1", from: "max", to: "mia" }]);
    // No main any more: anyone in the department.
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "mia" })], {
        followsDefaults: true,
        ...routing({}),
      }),
    ).toEqual([{ id: "s1", from: "mia", to: null }]);
    // A new main where there was none.
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: null, status: "waiting" })], {
        followsDefaults: true,
        ...routing({ "d-mkt": "mia" }),
      }),
    ).toEqual([{ id: "s1", from: null, to: "mia" }]);
  });

  it("keeps a chosen person who can still sign, and a delegation", () => {
    const r = routing({ "d-mkt": "mia" });
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max" })], { followsDefaults: false, ...r }),
    ).toEqual([]);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max", delegatedFromUserId: "mia" })], {
        followsDefaults: true,
        ...r,
      }),
    ).toEqual([]);
  });

  it("keeps a step handed back to the whole department, even on the defaults", () => {
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: null, delegatedFromUserId: "max" })], {
        followsDefaults: true,
        ...routing({ "d-mkt": "mia" }),
      }),
    ).toEqual([]);
  });

  it("keeps a step delegated outside the department while the delegate can sign", () => {
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "olly", delegatedFromUserId: "mia" })], {
        followsDefaults: false,
        ...routing({ "d-mkt": "mia" }),
      }),
    ).toEqual([]);
  });

  it("moves a step from someone who no longer signs for the department", () => {
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "gone" })], {
        followsDefaults: false,
        ...routing({ "d-mkt": "mia" }),
      }),
    ).toEqual([{ id: "s1", from: "gone", to: "mia" }]);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "gone", delegatedFromUserId: "x" })], {
        followsDefaults: false,
        ...routing({}),
      }),
    ).toEqual([{ id: "s1", from: "gone", to: null }]);
  });

  it("never moves a step to a department nobody can sign for", () => {
    const r = routing({});
    for (const followsDefaults of [true, false]) {
      expect(
        rerouteDepartmentSteps([step({ assignedUserId: "gone", assignedDepartmentId: "d-none" })], {
          followsDefaults,
          ...r,
        }),
      ).toEqual([]);
    }
    expect(
      rerouteDepartmentSteps(
        [
          step({
            assignedUserId: "gone",
            delegatedFromUserId: "x",
            assignedDepartmentId: "d-none",
          }),
        ],
        { followsDefaults: false, ...r },
      ),
    ).toEqual([]);
  });

  it("leaves decided steps, confirmations and non-department steps alone", () => {
    const r = { followsDefaults: true, ...routing({ "d-mkt": "mia" }) };
    expect(
      rerouteDepartmentSteps(
        [
          step({ id: "a", status: "approved", assignedUserId: "gone" }),
          step({ id: "b", stepKind: "confirmation", assignedUserId: "gone" }),
          step({ id: "c", assignedDepartmentId: null, assignedUserId: "gone" }),
        ],
        r,
      ),
    ).toEqual([]);
  });
});

describe("snags and onsite", () => {
  it("a closed snag tells the raiser and the owner, never whoever closed it", () => {
    expect(
      snagClosedRecipients({ raisedByUserId: "mkt", ownerUserId: "ops", actorUserId: "fixer" }),
    ).toEqual(["mkt", "ops"]);
    expect(
      snagClosedRecipients({ raisedByUserId: "mkt", ownerUserId: "mkt", actorUserId: "ops" }),
    ).toEqual(["mkt"]);
    expect(
      snagClosedRecipients({ raisedByUserId: null, ownerUserId: "ops", actorUserId: "ops" }),
    ).toEqual([]);
  });

  it("says a supplier can't sign in only to someone who can confirm for them", () => {
    const base = {
      canDecide: true,
      assignedRole: "supplier",
      assignedUserId: null,
      supplierName: "Big Print Co",
      supplierHasAccess: false,
    };
    expect(supplierCantSignIn(base)).toBe("Big Print Co can't sign in — confirm it yourself");
    expect(supplierCantSignIn({ ...base, supplierHasAccess: true })).toBeNull();
    expect(supplierCantSignIn({ ...base, canDecide: false })).toBeNull();
    expect(supplierCantSignIn({ ...base, assignedRole: "ops" })).toBeNull();
    expect(supplierCantSignIn({ ...base, supplierName: null })).toBeNull();
  });
});

describe("panels follow their stand's owner", () => {
  const place = {
    hallId: "h",
    locationId: null,
    standNumber: "A1",
    category: "organiser",
    sponsorId: null,
  };
  it("whatever the panel's status", () => {
    for (const status of ["draft", "in_review", "installed", "closed"]) {
      expect(
        panelSyncPatch(
          { ...place, ownerUserId: "new", ownerRole: "ops" },
          { ...place, status, signoffs: null, ownerUserId: "old", ownerRole: "ops" },
          null,
        ),
      ).toEqual({ ownerUserId: "new" });
    }
  });
  it("and say nothing when it already matches", () => {
    expect(
      panelSyncPatch(
        { ...place, ownerUserId: "same", ownerRole: "ops" },
        { ...place, status: "draft", signoffs: null, ownerUserId: "same", ownerRole: "ops" },
        null,
      ),
    ).toEqual({});
  });
});
