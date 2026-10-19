/**
 * Who can be handed work in an event (lib/people.ts) once people can be
 * limited to some events: nobody is offered work in an event they can't
 * open, someone already holding it is kept and labelled, and open
 * department sign-offs follow whoever can open the item's event. Without
 * an editionId everything answers as tests/unit/people.test.ts.
 */
import { describe, expect, it } from "vitest";
import {
  checkPick,
  eligibleIds,
  memberActor,
  personOptions,
  refusalFor,
  refusalMessage,
  rerouteDepartmentSteps,
  type OpenDeptStep,
  type PeoplePurpose,
  type TeamMember,
} from "@/lib/people";
import type { StaffRole } from "@/lib/authz";
import { openingEvent, type PersonOption } from "@/components/people/groups";

const ORG = "org-1";
const NOW = new Date("2026-10-16T12:00:00Z");
const A = "ed-a";
const B = "ed-b";

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
    signoffDepartmentIds: ["d-mkt"],
    editionIds: null,
    ...extra,
  };
}

const opts = { organisationId: ORG, now: NOW };
const limitedA = member("lim", "ops", { editionIds: [A] });
const free = member("free", "ops");
const admin = member("boss", "admin", { editionIds: [A] });

describe("refusalFor with an event", () => {
  const purposes: PeoplePurpose[] = [
    { type: "owner", item: { kind: "signage" }, editionId: B },
    { type: "signoff", departmentId: "d-mkt", editionId: B },
    { type: "task", editionId: B },
    { type: "confirm", editionId: B },
  ];

  it("someone who can't open the event: code event, 'Can't open this event'", () => {
    for (const p of purposes) {
      expect(refusalFor(p, limitedA, opts)).toEqual({
        code: "event",
        label: "Can't open this event",
      });
      expect(refusalFor(p, free, opts)).toBeNull();
      expect(refusalFor(p, admin, opts)).toBeNull();
    }
  });

  it("inside their events, or with no event given, answers as before", () => {
    for (const p of purposes) {
      expect(refusalFor({ ...p, editionId: A }, limitedA, opts)).toBeNull();
      expect(refusalFor({ ...p, editionId: undefined }, limitedA, opts)).toBeNull();
      expect(refusalFor({ ...p, editionId: null }, limitedA, opts)).toBeNull();
    }
  });

  it("access comes first: a suspended limited person reads Suspended", () => {
    const suspended = { ...limitedA, suspendedAt: new Date("2026-10-01") };
    expect(refusalFor({ type: "task", editionId: B }, suspended, opts)?.code).toBe("suspended");
  });

  it("refusalMessage says so", () => {
    expect(
      refusalMessage(
        "Sam",
        { code: "event", label: "Can't open this event" },
        { type: "task", editionId: B },
      ),
    ).toBe("Sam can't open this event — pick someone else");
  });

  it("checkPick refuses with those words", async () => {
    const res = await checkPick(
      {} as never,
      ORG,
      "lim",
      { type: "task", editionId: B },
      {
        team: [limitedA, free],
      },
    );
    expect(res).toEqual({ ok: false, error: "lim can't open this event — pick someone else" });
  });

  it("pickers leave them out, but keep a current holder labelled", () => {
    const team = [limitedA, free];
    const purpose: PeoplePurpose = { type: "task", editionId: B };
    expect(eligibleIds(team, purpose, opts)).toEqual(["free"]);
    const options = personOptions(team, purpose, { ...opts, include: ["lim"] });
    expect(options.map((o) => [o.id, o.unavailable])).toEqual([
      ["free", null],
      ["lim", "Can't open this event"],
    ]);
  });

  it("options carry a limited person's events (for client-side filtering)", () => {
    const options = personOptions([limitedA, free], { type: "task" }, opts);
    expect(options.find((o) => o.id === "lim")?.editionIds).toEqual([A]);
    expect(options.find((o) => o.id === "free")?.editionIds).toBeUndefined();
  });

  it("memberActor carries the list (never for super admins)", () => {
    expect(memberActor(limitedA, ORG).editionIds).toEqual([A]);
    expect(memberActor(admin, ORG).editionIds).toBeNull();
    expect(memberActor(free, ORG).editionIds).toBeNull();
  });
});

describe("rerouteDepartmentSteps per event", () => {
  // mia: main, limited to A; max: sees every event; lim: limited to A; gone: can't sign.
  const editionsOf: Record<string, string[] | null> = {
    mia: [A],
    max: null,
    lim: [A],
    sus: null,
  };
  const sees = (u: string, e?: string | null) => {
    const list = editionsOf[u];
    return !e || list === null || (list ?? []).includes(e);
  };
  const routing = (people: string[], main: string | null) => ({
    signersOf: (_d: string, e?: string | null) => new Set(people.filter((u) => sees(u, e))),
    mainOf: (_d: string, e?: string | null) => (main && sees(main, e) ? main : null),
    canSign: (u: string, e?: string | null) => u !== "sus" && u in editionsOf && sees(u, e),
    opens: (u: string, e: string) => u in editionsOf && sees(u, e),
  });
  const step = (over: Partial<OpenDeptStep>): OpenDeptStep => ({
    id: "s1",
    status: "pending",
    stepKind: "approval",
    assignedUserId: null,
    assignedDepartmentId: "d-mkt",
    delegatedFromUserId: null,
    ...over,
  });

  it("a limited main keeps their own event and hands others to the department", () => {
    const r = routing(["mia", "max"], "mia");
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max", editionId: A })], {
        followsDefaults: true,
        ...r,
      }),
    ).toEqual([{ id: "s1", from: "max", to: "mia" }]);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "mia", editionId: B })], {
        followsDefaults: true,
        ...r,
      }),
    ).toEqual([{ id: "s1", from: "mia", to: null }]);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: null, editionId: B })], {
        followsDefaults: true,
        ...r,
      }),
    ).toEqual([]);
  });

  it("nobody who signs can open it and the named person can't: the department, and onStranded", () => {
    const stranded: string[] = [];
    const r = routing(["mia", "lim"], "mia");
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "mia", editionId: B })], {
        followsDefaults: false,
        ...r,
        onStranded: (id) => stranded.push(id),
      }),
    ).toEqual([{ id: "s1", from: "mia", to: null }]);
    expect(stranded).toEqual(["s1"]);
  });

  it("nobody else can sign but the named person can open it: it stays named", () => {
    const stranded: string[] = [];
    const r = routing([], null);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max", editionId: B })], {
        followsDefaults: true,
        ...r,
        onStranded: (id) => stranded.push(id),
      }),
    ).toEqual([]);
    expect(stranded).toEqual([]);
  });

  it("nobody can sign and the named person is suspended: stays named (today's rule)", () => {
    const r = routing([], null);
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "sus", editionId: A })], {
        followsDefaults: true,
        ...r,
      }),
    ).toEqual([]);
  });

  it("delegated to someone who can't open the event: back to the main or the department", () => {
    const r = routing(["mia", "max"], "max");
    expect(
      rerouteDepartmentSteps(
        [step({ assignedUserId: "lim", delegatedFromUserId: "max", editionId: B })],
        { followsDefaults: false, ...r },
      ),
    ).toEqual([{ id: "s1", from: "lim", to: "max" }]);
    const noMain = routing(["mia", "max"], "mia");
    expect(
      rerouteDepartmentSteps(
        [step({ assignedUserId: "lim", delegatedFromUserId: "max", editionId: B })],
        { followsDefaults: false, ...noMain },
      ),
    ).toEqual([{ id: "s1", from: "lim", to: null }]);
  });

  it("with no editionId, a limited main is treated as today (event-blind)", () => {
    const r = routing(["mia", "max"], "mia");
    expect(
      rerouteDepartmentSteps([step({ assignedUserId: "max" })], { followsDefaults: true, ...r }),
    ).toEqual([{ id: "s1", from: "max", to: "mia" }]);
  });
});

describe("openingEvent (a form that picks the event: the task form)", () => {
  const people: PersonOption[] = [
    {
      id: "free",
      name: "Free",
      jobTitle: null,
      departmentId: null,
      departmentName: null,
      unavailable: null,
    },
    {
      id: "lim",
      name: "Lim",
      jobTitle: null,
      departmentId: null,
      departmentName: null,
      unavailable: null,
      editionIds: [A],
    },
  ];

  it("no event: everyone, unchanged", () => {
    expect(openingEvent(people, null)).toEqual(people);
    expect(openingEvent(people, "")).toEqual(people);
  });

  it("an event: only those who can open it", () => {
    expect(openingEvent(people, A).map((p) => p.id)).toEqual(["free", "lim"]);
    expect(openingEvent(people, B).map((p) => p.id)).toEqual(["free"]);
  });

  it("the current pick stays, labelled", () => {
    const kept = openingEvent(people, B, "lim");
    expect(kept.map((p) => [p.id, p.unavailable])).toEqual([
      ["free", null],
      ["lim", "Can't open this event"],
    ]);
  });
});
