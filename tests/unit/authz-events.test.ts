/**
 * Events per person (Users → Events), written before the code. A team
 * member limited to some events (editionIds) can do nothing in any other;
 * everyone without a list, every super admin and every partner answers
 * exactly as before (the frozen v1 snapshot).
 */
import { describe, expect, it } from "vitest";
import snapshot from "./fixtures/authz-v1-snapshot.json";
import { snapshotActions, snapshotActors } from "./fixtures/authz-snapshot-cases";
import {
  can,
  editionOf,
  editionScope,
  opensEdition,
  seesAllEditions,
  seesEdition,
  type Action,
  type ApprovalStepCtx,
  type ExternalActor,
  type SignageItemCtx,
  type StaffActor,
  type StaffRole,
  type StandSubmissionCtx,
} from "@/lib/authz";

const ORG = "org-1";
const A = "ed-1"; // the snapshot's event
const B = "ed-2";

function staff(role: StaffRole, extra: Partial<StaffActor> = {}): StaffActor {
  return { kind: "staff", userId: "me", organisationId: ORG, role, ...extra };
}

/** Swap every event id in an action (records, steps, tasks and editionId). */
function onEdition(action: Action, editionId: string): Action {
  const json = JSON.stringify(action).replaceAll(`"${A}"`, `"${editionId}"`);
  return JSON.parse(json) as Action;
}

describe("actors without a list answer as the frozen snapshot", () => {
  const actions = snapshotActions();
  const actors = snapshotActors();

  it("editionIds null on every staff actor gives the same answers", () => {
    const mismatches: string[] = [];
    for (const [actorKey, actor] of actors) {
      const expected = (snapshot.results as Record<string, string>)[actorKey];
      const withNull = actor.kind === "staff" ? { ...actor, editionIds: null } : actor;
      actions.forEach(([actionKey, action], i) => {
        const got = can(withNull, action) ? "1" : "0";
        if (got !== expected[i]) mismatches.push(`${actorKey} | ${actionKey}`);
      });
    }
    expect(mismatches).toEqual([]);
  });

  it("a limited actor inside their event answers as the snapshot", () => {
    const mismatches: string[] = [];
    for (const [actorKey, actor] of actors) {
      if (actor.kind !== "staff") continue;
      const expected = (snapshot.results as Record<string, string>)[actorKey];
      const limited: StaffActor = { ...actor, editionIds: [A] };
      actions.forEach(([actionKey, action], i) => {
        const got = can(limited, action) ? "1" : "0";
        if (got !== expected[i]) mismatches.push(`${actorKey} | ${actionKey}`);
      });
    }
    expect(mismatches).toEqual([]);
  });

  it("a limited actor is refused every snapshot action naming a record in another event", () => {
    const allowed: string[] = [];
    for (const [actorKey, actor] of actors) {
      if (actor.kind !== "staff" || actor.role === "admin") continue;
      const limited: StaffActor = { ...actor, editionIds: [B] };
      for (const [actionKey, action] of actions) {
        if (editionOf(action) === undefined) continue;
        if (can(limited, action)) allowed.push(`${actorKey} | ${actionKey}`);
      }
    }
    expect(allowed).toEqual([]);
  });

  it("partners answer exactly as the snapshot whatever is stored", () => {
    for (const [actorKey, actor] of actors) {
      if (actor.kind !== "external") continue;
      const expected = (snapshot.results as Record<string, string>)[actorKey];
      actions.forEach(([, action], i) => {
        expect(can(actor, action) ? "1" : "0").toBe(expected[i]);
      });
    }
  });
});

const base = { organisationId: ORG, venueId: "v-1" };
const signOn = (editionId: string): SignageItemCtx => ({ ...base, editionId, kind: "signage" });
const standOn = (editionId: string): StandSubmissionCtx => ({
  ...base,
  editionId,
  exhibitorId: "ex-1",
});
const steps = (editionId: string): Record<string, ApprovalStepCtx> => ({
  department: {
    assignedDepartmentId: "d-mine",
    stepKind: "approval",
    entity: { type: "signage_item", item: signOn(editionId) },
  },
  named: {
    assignedUserId: "me",
    stepKind: "approval",
    entity: { type: "signage_item", item: signOn(editionId) },
  },
  role: {
    assignedRole: "ops",
    stepKind: "approval",
    entity: { type: "signage_item", item: signOn(editionId) },
  },
  confirmation: {
    assignedRole: "supplier",
    stepKind: "confirmation",
    entity: { type: "signage_item", item: signOn(editionId) },
  },
  stand: {
    assignedRole: "ops",
    stepKind: "confirmation",
    entity: { type: "stand", sub: standOn(editionId) },
  },
});

/** Every action that can name an event, about `editionId`. */
function actionsOn(editionId: string): [string, Action][] {
  const item = signOn(editionId);
  const sponsorshipItem: SignageItemCtx = { ...item, kind: "sponsorship_item" };
  const sub = standOn(editionId);
  const out: [string, Action][] = [
    ["signage.view", { type: "signage.view", item }],
    ["signage.edit", { type: "signage.edit", item }],
    ["signage.submit", { type: "signage.submit", item }],
    ["artwork.upload", { type: "artwork.upload", item }],
    ["costs.edit@item", { type: "costs.edit", item: sponsorshipItem }],
    ["comment.external.write@item", { type: "comment.external.write", entity: item }],
    ["comment.external.write@stand", { type: "comment.external.write", entity: sub }],
    ["stand.view", { type: "stand.view", sub }],
    [
      "task.update",
      { type: "task.update", task: { assignedToUserId: "me", createdByUserId: "me", editionId } },
    ],
    [
      "task.delete",
      { type: "task.delete", task: { assignedToUserId: "me", createdByUserId: "me", editionId } },
    ],
  ];
  for (const [name, step] of Object.entries(steps(editionId))) {
    for (const type of ["approval.decide", "approval.delegate", "approval.remind"] as const) {
      out.push([`${type}@${name}`, { type, step }]);
    }
  }
  for (const type of [
    "view_edition",
    "signage.create",
    "sponsorship.create",
    "stand_design.create",
    "task.create",
    "task.assign",
    "signage.delete",
    "signage.restore",
    "signage.bulk",
    "signage.import",
    "signage.hold",
    "signage.resume",
    "signage.reopen",
    "signage.close",
    "approval.chase",
    "stand.review",
    "costs.view",
    "sponsorship.sell",
    "comment.internal.write",
    "comment.internal.read",
    "snag.manage",
    "events.edit",
    "halls.manage",
    "partners.invite",
    "event.setup",
  ] as const) {
    out.push([type, { type, editionId } as Action]);
  }
  out.push(["export.run", { type: "export.run", kind: "schedule", editionId }]);
  return out;
}

describe("the events rule", () => {
  const limitedRoles: StaffRole[] = ["ops", "marketing", "sales", "event_director", "viewer"];

  it("every action naming a record or event outside their list is refused", () => {
    const allowed: string[] = [];
    for (const role of limitedRoles) {
      const actor = staff(role, { editionIds: [A], signoffDepartmentIds: ["d-mine"] });
      for (const [name, action] of actionsOn(B)) {
        if (can(actor, action)) allowed.push(`${role} | ${name}`);
      }
    }
    expect(allowed).toEqual([]);
  });

  it("inside their list the same actions answer as for someone without a list", () => {
    for (const role of limitedRoles) {
      const free = staff(role, { signoffDepartmentIds: ["d-mine"] });
      const limited = staff(role, { editionIds: [A, B], signoffDepartmentIds: ["d-mine"] });
      for (const [name, action] of actionsOn(B)) {
        expect(`${role} | ${name}: ${can(limited, action)}`).toBe(
          `${role} | ${name}: ${can(free, action)}`,
        );
      }
    }
  });

  it("no ability reopens another event (granted abilities, every section)", () => {
    const actor = staff("ops", {
      editionIds: [A],
      overrides: { "costs.view": true, "sponsorship.sell": true, "approval.chase": true },
    });
    expect(can(actor, { type: "costs.view", editionId: B })).toBe(false);
    expect(can(actor, { type: "sponsorship.sell", editionId: B })).toBe(false);
    expect(can(actor, { type: "approval.chase", editionId: B })).toBe(false);
    expect(can(actor, { type: "costs.view", editionId: A })).toBe(true);
  });

  it("tasks with no event and actions with no event are never event-checked", () => {
    const actor = staff("marketing", { editionIds: [A] });
    const task = { assignedToUserId: "me", createdByUserId: "me" };
    expect(can(actor, { type: "task.update", task })).toBe(true);
    expect(can(actor, { type: "task.update", task: { ...task, editionId: null } })).toBe(true);
    expect(can(actor, { type: "task.create" })).toBe(true);
    expect(can(actor, { type: "view_edition" })).toBe(true);
    expect(can(actor, { type: "signage.create" })).toBe(true);
    expect(can(actor, { type: "events.create" })).toBe(false); // marketing never could
    expect(can(staff("ops", { editionIds: [A] }), { type: "events.create" })).toBe(true);
    // The people rules' probes use "" — none.
    expect(can(actor, { type: "signage.edit", item: { ...signOn(""), kind: "signage" } })).toBe(
      true,
    );
  });

  it("super admins are never limited, even with editionIds stored", () => {
    const admin = staff("admin", { editionIds: [A] });
    for (const [name, action] of actionsOn(B)) {
      expect(`${name}: ${can(admin, action)}`).toBe(`${name}: true`);
    }
    expect(editionScope(admin)).toBeNull();
    expect(seesEdition(admin, B)).toBe(true);
  });

  it("view_edition without an id stays true for every staff role, limited or not", () => {
    for (const role of ["admin", ...limitedRoles] as StaffRole[]) {
      expect(can(staff(role), { type: "view_edition" })).toBe(true);
      expect(can(staff(role, { editionIds: [A] }), { type: "view_edition" })).toBe(true);
      expect(can(staff(role, { editionIds: [A] }), { type: "view_edition", editionId: A })).toBe(
        true,
      );
    }
  });

  it("another organisation's record is refused before the events rule", () => {
    const actor = staff("ops");
    const item = { ...signOn(A), organisationId: "org-2" };
    expect(can(actor, { type: "signage.view", item })).toBe(false);
  });
});

describe("partners", () => {
  const sponsor: ExternalActor = {
    kind: "external",
    userId: "p",
    organisationId: ORG,
    grants: [
      {
        role: "sponsor",
        editionId: A,
        scopeType: "sponsor",
        scopeId: "sp-1",
        expiresAt: null,
        revokedAt: null,
      },
      {
        role: "venue",
        editionId: B,
        scopeType: "venue",
        scopeId: "v-1",
        expiresAt: null,
        revokedAt: new Date("2026-01-01"),
      },
    ],
  };

  it("view_edition with an id stays false; their grant rules decide records", () => {
    expect(can(sponsor, { type: "view_edition", editionId: A })).toBe(false);
    const item: SignageItemCtx = { ...signOn(A), sponsorId: "sp-1", status: "draft" };
    expect(can(sponsor, { type: "signage.view", item })).toBe(true);
    expect(can(sponsor, { type: "artwork.upload", item })).toBe(true);
    expect(can(sponsor, { type: "signage.view", item: { ...item, editionId: B } })).toBe(false);
  });

  it("their scope is their live grants' events; seesEdition is false, opensEdition true", () => {
    expect(editionScope(sponsor)).toEqual([A]);
    expect(seesEdition(sponsor, A)).toBe(false);
    expect(opensEdition(sponsor, A)).toBe(true);
    expect(opensEdition(sponsor, B)).toBe(true);
  });
});

describe("helpers", () => {
  it("editionScope: null for super admins and people without a list", () => {
    expect(editionScope(staff("ops"))).toBeNull();
    expect(editionScope(staff("ops", { editionIds: null }))).toBeNull();
    expect(editionScope(staff("ops", { editionIds: [A] }))).toEqual([A]);
    expect(editionScope({ role: "marketing", editionIds: [B] })).toEqual([B]);
    expect(editionScope({ role: "admin", editionIds: [B] })).toBeNull();
    expect(editionScope({ role: "viewer" })).toBeNull();
  });

  it("seesEdition, seesAllEditions and opensEdition for staff", () => {
    const limited = staff("ops", { editionIds: [A] });
    expect(seesEdition(limited, A)).toBe(true);
    expect(seesEdition(limited, B)).toBe(false);
    expect(seesAllEditions(limited, [A])).toBe(true);
    expect(seesAllEditions(limited, [A, B])).toBe(false);
    expect(seesAllEditions(limited, [])).toBe(true);
    expect(seesAllEditions(staff("ops"), [A, B])).toBe(true);
    expect(opensEdition(limited, A)).toBe(true);
    expect(opensEdition(limited, B)).toBe(false);
    expect(opensEdition(staff("viewer"), B)).toBe(true);
  });

  it("editionOf: item, sub, step (both kinds), entity, task, editionId; '' is none", () => {
    expect(editionOf({ type: "signage.view", item: signOn(A) })).toBe(A);
    expect(editionOf({ type: "stand.view", sub: standOn(B) })).toBe(B);
    expect(editionOf({ type: "approval.decide", step: steps(A).department })).toBe(A);
    expect(editionOf({ type: "approval.decide", step: steps(B).stand })).toBe(B);
    expect(editionOf({ type: "comment.external.write", entity: standOn(A) })).toBe(A);
    expect(
      editionOf({
        type: "task.update",
        task: { assignedToUserId: "x", createdByUserId: "y", editionId: B },
      }),
    ).toBe(B);
    expect(
      editionOf({ type: "task.update", task: { assignedToUserId: "x", createdByUserId: "y" } }),
    ).toBeUndefined();
    expect(editionOf({ type: "costs.view", editionId: A })).toBe(A);
    expect(editionOf({ type: "costs.view" })).toBeUndefined();
    expect(editionOf({ type: "costs.view", editionId: "" })).toBeUndefined();
    expect(editionOf({ type: "signage.edit", item: signOn("") })).toBeUndefined();
    expect(editionOf({ type: "users.manage" })).toBeUndefined();
    expect(editionOf(onEdition({ type: "signage.view", item: signOn(A) }, B))).toBe(B);
  });
});
