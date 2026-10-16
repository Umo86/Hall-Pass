/**
 * The abilities registry (Users v2), written before the refactor.
 *
 * (a) A frozen snapshot of can() taken from lib/authz.ts before the registry
 *     existed (fixtures/authz-v1-snapshot.json, from
 *     fixtures/generate-authz-snapshot.ts): the refactored can() must give
 *     exactly the same answer for every role × fixture. The only allowed
 *     difference is the one decided in DECISIONS.md: a stored
 *     costs.edit=false now also blocks costs on sponsorship items the person
 *     can edit (before, the item action let them through).
 * (b)–(k) the registry and its rules, per docs in lib/authz.ts.
 */
import { describe, expect, it } from "vitest";
import snapshot from "./fixtures/authz-v1-snapshot.json";
import {
  costItems,
  EXPORT_KINDS,
  ROLES,
  snapshotActions,
  snapshotActors,
} from "./fixtures/authz-snapshot-cases";
import {
  ABILITIES,
  ABILITY_KEYS,
  abilityFor,
  abilityLevel,
  abilityOn,
  can,
  confirmsForSuppliers,
  signoffPaused,
  storedAbility,
  SETTINGS_ABILITIES,
  type AbilityKey,
  type Action,
  type ApprovalStepCtx,
  type Feature,
  type PermissionOverrides,
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
const stand: StandSubmissionCtx = { ...base, exhibitorId: "ex-1" };
const NON_ADMIN: StaffRole[] = ["ops", "marketing", "sales", "event_director", "viewer"];

function staff(
  role: StaffRole,
  overrides?: PermissionOverrides,
  extra: Partial<StaffActor> = {},
): StaffActor {
  return { kind: "staff", userId: "me", organisationId: ORG, role, overrides, ...extra };
}

const step = (over: Partial<ApprovalStepCtx>): ApprovalStepCtx => ({
  stepKind: "approval",
  entity: { type: "signage_item", item: sign },
  ...over,
});
const supplierPrint = step({ assignedRole: "supplier", stepKind: "confirmation" });
const opsInstalled = step({ assignedRole: "ops", stepKind: "confirmation" });
const opsApproval = step({ assignedRole: "ops", stepKind: "approval" });
const namedMe = step({ assignedUserId: "me" });
const namedOther = step({ assignedUserId: "someone-else" });
const standStep: ApprovalStepCtx = {
  assignedRole: "venue",
  stepKind: "approval",
  entity: { type: "stand", sub: stand },
};

describe("(a) the refactored can() reproduces the frozen v1 snapshot", () => {
  const actions = snapshotActions();
  const actors = snapshotActors();

  it("covers the same fixtures as the snapshot", () => {
    expect(actions.map(([k]) => k)).toEqual(snapshot.actions);
    expect(actors.map(([k]) => k)).toEqual(Object.keys(snapshot.results));
    expect(costItems().map(([k]) => k)).toEqual(snapshot.costItems);
  });

  it("gives the same answer for every actor × action", () => {
    const mismatches: string[] = [];
    for (const [actorKey, actor] of actors) {
      const expected = (snapshot.results as Record<string, string>)[actorKey];
      actions.forEach(([actionKey, action], i) => {
        const got = can(actor, action) ? "1" : "0";
        if (got !== expected[i]) {
          mismatches.push(`${actorKey} | ${actionKey}: was ${expected[i]}, now ${got}`);
        }
      });
    }
    expect(mismatches).toEqual([]);
  });

  it("costs on an item match, except a stored costs.edit=false on sponsorship items", () => {
    const items = costItems();
    const mismatches: string[] = [];
    for (const [actorKey, actor] of actors) {
      const expected = (snapshot.costs as Record<string, string>)[actorKey];
      items.forEach(([itemKey, item], i) => {
        let want = expected[i];
        // The one documented change: costs.edit=false now blocks both halves
        // (admins still ignore anything stored).
        if (
          actorKey.includes("costs.edit=false") &&
          !actorKey.startsWith("admin") &&
          item.kind === "sponsorship_item"
        ) {
          want = "0";
        }
        const got = can(actor, { type: "costs.edit", item }) ? "1" : "0";
        if (got !== want) mismatches.push(`${actorKey} | ${itemKey}: want ${want}, now ${got}`);
      });
    }
    expect(mismatches).toEqual([]);
  });

  it("the exception is real: sales with costs.edit=false could set costs on sponsorship items before", () => {
    const i = snapshot.costItems.indexOf("sponsorshipItem:other");
    expect((snapshot.costs as Record<string, string>)["sales+costs.edit=false"][i]).toBe("1");
    expect(
      can(staff("sales", { "costs.edit": false }), { type: "costs.edit", item: sponsorshipItem }),
    ).toBe(false);
  });
});

/** Every action that each ability governs, for the matrix below. */
const MAPPED: Record<AbilityKey, Action[]> = {
  "signage.create": [{ type: "signage.create" }],
  "signage.delete": [{ type: "signage.delete" }, { type: "signage.restore" }],
  "signage.lifecycle": [
    { type: "signage.hold" },
    { type: "signage.resume" },
    { type: "signage.reopen" },
    { type: "signage.close" },
  ],
  "signage.bulk": [{ type: "signage.bulk" }],
  "approval.decide": [{ type: "approval.decide", step: namedOther }],
  "approval.delegate": [{ type: "approval.delegate", step: namedOther }],
  "approval.chase": [{ type: "approval.chase" }, { type: "approval.remind", step: standStep }],
  "costs.view": [{ type: "costs.view" }],
  "costs.edit": [{ type: "costs.edit" }, { type: "costs.edit", item: sign }],
  "sponsorship.create": [{ type: "sponsorship.create" }],
  "sponsorship.sell": [{ type: "sponsorship.sell" }],
  "events.create": [{ type: "events.create" }],
  "events.edit": [{ type: "events.edit" }],
  "halls.manage": [{ type: "halls.manage" }],
  "suppliers.manage": [{ type: "suppliers.manage" }],
  "lists.manage": [{ type: "lists.manage" }],
  "organisation.manage": [{ type: "organisation.manage" }],
  "signage.confirm": [
    { type: "approval.decide", step: supplierPrint },
    { type: "approval.decide", step: opsInstalled },
  ],
  "snag.manage": [{ type: "snag.manage" }],
  "reports.download": EXPORT_KINDS.map((kind) => ({ type: "export.run", kind }) as Action),
  "task.assign": [{ type: "task.assign" }],
  "partners.invite": [{ type: "partners.invite" }],
  "departments.manage": [{ type: "departments.manage" }],
};

/** What each mapped action gives a role with nothing stored. */
function roleDefault(key: AbilityKey, role: StaffRole, action: Action): boolean {
  const def = ABILITIES[key];
  if (key === "approval.decide" || key === "approval.delegate") return role === "admin";
  if (key === "signage.bulk") return ABILITIES["signage.create"].roles.includes(role);
  if (action.type === "export.run") {
    if (def.roles.includes(role)) return true;
    return def.partial?.[role]?.kinds.includes(action.kind) ?? false;
  }
  return def.roles.includes(role);
}

describe("(b) the registry", () => {
  it("every key has a label, description, group and default roles", () => {
    for (const key of ABILITY_KEYS) {
      const def = ABILITIES[key];
      expect(def.label.length, key).toBeGreaterThan(3);
      expect(def.description.length, key).toBeGreaterThan(10);
      expect(def.group, key).toBeTruthy();
      expect(def.roles.length, key).toBeGreaterThan(0);
      expect(def.roles, key).toContain("admin");
    }
    expect(Object.keys(MAPPED).sort()).toEqual([...ABILITY_KEYS].sort());
  });

  it("each action maps to at most one key, and the mapped actions name that key", () => {
    for (const key of ABILITY_KEYS) {
      for (const action of MAPPED[key]) {
        const mapped = abilityFor(action);
        if (key === "signage.confirm") expect(mapped).toBe("approval.decide");
        else expect(mapped, `${key} ← ${action.type}`).toBe(key);
      }
    }
  });

  it("super-admin-only powers are never keys and ignore anything stored", () => {
    for (const k of ["users.manage", "system.manage", "events.archive", "settings.manage"]) {
      expect((ABILITY_KEYS as readonly string[]).includes(k)).toBe(false);
    }
    for (const role of NON_ADMIN) {
      const o = { "users.manage": true, "system.manage": true, "events.archive": true };
      const a = staff(role, o as PermissionOverrides);
      expect(can(a, { type: "users.manage" })).toBe(false);
      expect(can(a, { type: "system.manage" })).toBe(false);
      expect(can(a, { type: "events.archive" })).toBe(false);
    }
    for (const t of ["users.manage", "system.manage", "events.archive"] as const) {
      expect(can(staff("admin"), { type: t })).toBe(true);
    }
  });

  it("only organisation, partner and department powers are kept for super admins to give", () => {
    const keys = ABILITY_KEYS.filter((k) => ABILITIES[k].superAdminGrants);
    expect(keys.sort()).toEqual(["departments.manage", "organisation.manage", "partners.invite"]);
  });
});

describe("(c) every key: absent → role default, false blocks, true grants or only gates", () => {
  for (const key of ABILITY_KEYS) {
    describe(key, () => {
      const def = ABILITIES[key];
      for (const role of NON_ADMIN) {
        it(`${role}`, () => {
          for (const action of MAPPED[key]) {
            const label = `${key} ${role} ${JSON.stringify(action).slice(0, 60)}`;
            expect(can(staff(role), action), `${label} absent`).toBe(
              roleDefault(key, role, action),
            );
            expect(can(staff(role, {}), action), `${label} {}`).toBe(
              roleDefault(key, role, action),
            );
            expect(can(staff(role, { [key]: false }), action), `${label} false`).toBe(false);
            const granted = can(staff(role, { [key]: true }), action);
            if (def.kind === "grant" || key === "signage.bulk") {
              expect(granted, `${label} true grants`).toBe(true);
            } else {
              // Gates never bypass the step assignment.
              expect(granted, `${label} true doesn't bypass`).toBe(false);
            }
          }
        });
      }
      it("admins ignore anything stored", () => {
        for (const action of MAPPED[key]) {
          expect(can(staff("admin", { [key]: false }), action)).toBe(true);
        }
      });
    });
  }

  it("abilityOn and abilityLevel agree with the defaults", () => {
    expect(abilityOn(staff("marketing"), "signage.create")).toBe(true);
    expect(abilityOn(staff("sales"), "signage.create")).toBe(false);
    expect(abilityLevel(staff("sales"), "reports.download")).toBe("partial");
    expect(abilityLevel(staff("sales", { "reports.download": false }), "reports.download")).toBe(
      "no",
    );
    expect(abilityLevel(staff("viewer"), "reports.download")).toBe("no");
    expect(abilityLevel(staff("ops"), "reports.download")).toBe("yes");
    expect(abilityLevel(staff("admin", { "costs.view": false }), "costs.view")).toBe("yes");
  });
});

describe("(d) old stored values still count", () => {
  it("settings.manage true gives a marketing person all six setup abilities", () => {
    const a = staff("marketing", { "settings.manage": true });
    for (const k of SETTINGS_ABILITIES) {
      expect(can(a, { type: k }), k).toBe(true);
      expect(storedAbility(a.overrides, k)).toBe(true);
    }
  });

  it("settings.manage false takes all six away from Operations", () => {
    const a = staff("ops", { "settings.manage": false });
    for (const k of SETTINGS_ABILITIES) expect(can(a, { type: k }), k).toBe(false);
    expect(can(a, { type: "settings.manage" })).toBe(false);
  });

  it("a new key wins over the old one", () => {
    const a = staff("ops", { "settings.manage": false, "halls.manage": true });
    for (const k of SETTINGS_ABILITIES) {
      expect(can(a, { type: k }), k).toBe(k === "halls.manage");
    }
  });

  it("sponsorship.create true carries selling, unless selling is stored false", () => {
    expect(
      can(staff("marketing", { "sponsorship.create": true }), { type: "sponsorship.sell" }),
    ).toBe(true);
    expect(
      can(staff("marketing", { "sponsorship.create": true, "sponsorship.sell": false }), {
        type: "sponsorship.sell",
      }),
    ).toBe(false);
    expect(can(staff("sales", { "sponsorship.create": false }), { type: "sponsorship.sell" })).toBe(
      false,
    );
  });

  it("the derived settings.manage is any of the six", () => {
    for (const role of ROLES) {
      for (const k of SETTINGS_ABILITIES) {
        for (const v of [true, false]) {
          const a = staff(role, { [k]: v });
          const any = SETTINGS_ABILITIES.some((s) => can(a, { type: s }));
          expect(can(a, { type: "settings.manage" }), `${role} ${k}=${v}`).toBe(any);
        }
      }
    }
    expect(can(staff("marketing", { "lists.manage": true }), { type: "settings.manage" })).toBe(
      true,
    );
  });

  it("event setup is dates, halls, lists or suppliers", () => {
    expect(can(staff("ops"), { type: "event.setup" })).toBe(true);
    expect(can(staff("marketing"), { type: "event.setup" })).toBe(false);
    for (const k of ["events.edit", "halls.manage", "lists.manage", "suppliers.manage"] as const) {
      expect(can(staff("marketing", { [k]: true }), { type: "event.setup" }), k).toBe(true);
    }
    expect(can(staff("marketing", { "organisation.manage": true }), { type: "event.setup" })).toBe(
      false,
    );
    expect(can(staff("marketing", { "events.create": true }), { type: "event.setup" })).toBe(false);
  });
});

describe("(e) reports.download", () => {
  const run = (a: StaffActor, kind: string) => can(a, { type: "export.run", kind });
  it("sales get the sponsorship report only by default", () => {
    expect(run(staff("sales"), "sponsor_report")).toBe(true);
    expect(run(staff("sales"), "certificate")).toBe(false);
    expect(run(staff("sales"), "schedule")).toBe(false);
  });
  it("a stored true gives every report, a stored false none", () => {
    for (const kind of EXPORT_KINDS) {
      expect(run(staff("sales", { "reports.download": true }), kind)).toBe(true);
      expect(run(staff("sales", { "reports.download": false }), kind)).toBe(false);
      expect(run(staff("viewer", { "reports.download": true }), kind)).toBe(true);
    }
  });
  it("sections still come first", () => {
    const a = staff("viewer", { "reports.download": true }, { features: ["calendar"] });
    expect(run(a, "schedule")).toBe(false);
    expect(run(a, "sponsor_report")).toBe(false);
    expect(run(a, "certificate")).toBe(true); // certificates belong to no section
  });
});

describe("(f) signage.bulk", () => {
  it("follows signage.create, including a granted one", () => {
    expect(can(staff("marketing"), { type: "signage.bulk" })).toBe(true);
    expect(can(staff("sales"), { type: "signage.bulk" })).toBe(false);
    expect(can(staff("sales", { "signage.create": true }), { type: "signage.bulk" })).toBe(true);
    expect(can(staff("marketing", { "signage.create": false }), { type: "signage.bulk" })).toBe(
      false,
    );
  });
  it("false blocks import; a viewer given bulk can bulk but not import", () => {
    const blocked = staff("ops", { "signage.bulk": false });
    expect(can(blocked, { type: "signage.bulk" })).toBe(false);
    expect(can(blocked, { type: "signage.import" })).toBe(false);
    const viewer = staff("viewer", { "signage.bulk": true });
    expect(can(viewer, { type: "signage.bulk" })).toBe(true);
    expect(can(viewer, { type: "signage.import" })).toBe(false);
    expect(can(staff("marketing"), { type: "signage.import" })).toBe(true);
  });
});

describe("(g) signage.confirm", () => {
  const decide = (a: StaffActor, s: ApprovalStepCtx) =>
    can(a, { type: "approval.decide", step: s });
  it("Operations decide supplier print and delivery, and the ops Installed step", () => {
    expect(decide(staff("ops"), supplierPrint)).toBe(true);
    expect(decide(staff("ops"), opsInstalled)).toBe(true);
  });
  it("an ops false removes those but keeps a step named for them", () => {
    const ops = staff("ops", { "signage.confirm": false });
    expect(decide(ops, supplierPrint)).toBe(false);
    expect(decide(ops, opsInstalled)).toBe(false);
    expect(decide(ops, step({ assignedUserId: "me", stepKind: "confirmation" }))).toBe(true);
    expect(decide(ops, opsApproval)).toBe(true); // an ops approval step isn't a confirmation
  });
  it("marketing given it confirms supplier and ops steps, not ops approval steps", () => {
    const mkt = staff("marketing", { "signage.confirm": true });
    expect(decide(mkt, supplierPrint)).toBe(true);
    expect(decide(mkt, opsInstalled)).toBe(true);
    expect(decide(mkt, opsApproval)).toBe(false);
  });
  it("a paused sign-off beats a granted confirm", () => {
    const mkt = staff("marketing", { "signage.confirm": true, "approval.decide": false });
    expect(decide(mkt, supplierPrint)).toBe(false);
    expect(signoffPaused(mkt.overrides)).toBe(true);
  });
  it("confirmsForSuppliers matches can()", () => {
    const variants: PermissionOverrides[] = [
      {},
      { "signage.confirm": true },
      { "signage.confirm": false },
      { "approval.decide": false },
      { "signage.confirm": true, "approval.decide": false },
    ];
    for (const role of ROLES) {
      for (const o of variants) {
        const a = staff(role, o);
        expect(confirmsForSuppliers(a), `${role} ${JSON.stringify(o)}`).toBe(
          decide(a, supplierPrint),
        );
      }
    }
  });
});

describe("(h) approval.chase", () => {
  const remind = (a: StaffActor, s: ApprovalStepCtx) =>
    can(a, { type: "approval.remind", step: s });
  const onItem = (item: SignageItemCtx) =>
    step({ assignedDepartmentId: "d-1", entity: { type: "signage_item", item } });
  it("admins and Operations see everyone's sign-offs by default", () => {
    expect(can(staff("admin"), { type: "approval.chase" })).toBe(true);
    expect(can(staff("ops"), { type: "approval.chase" })).toBe(true);
    for (const r of ["marketing", "sales", "event_director", "viewer"] as const) {
      expect(can(staff(r), { type: "approval.chase" })).toBe(false);
    }
    expect(can(staff("marketing", { "approval.chase": true }), { type: "approval.chase" })).toBe(
      true,
    );
  });
  it("marketing false blocks their own sponsor-item reminder", () => {
    expect(remind(staff("marketing"), onItem(sponsorSign))).toBe(true);
    expect(remind(staff("marketing", { "approval.chase": false }), onItem(sponsorSign))).toBe(
      false,
    );
  });
  it("a viewer given it can remind on stands", () => {
    expect(remind(staff("viewer"), standStep)).toBe(false);
    expect(remind(staff("viewer", { "approval.chase": true }), standStep)).toBe(true);
  });
  it("sections still apply first", () => {
    const v = staff("viewer", { "approval.chase": true }, { features: ["signage"] });
    expect(remind(v, standStep)).toBe(false);
    expect(remind(v, onItem(sign))).toBe(true);
  });
});

describe("(i) approval.delegate", () => {
  const delegate = (a: StaffActor, s: ApprovalStepCtx) =>
    can(a, { type: "approval.delegate", step: s });
  it("a viewer can't by default", () => {
    expect(delegate(staff("viewer"), namedMe)).toBe(false);
  });
  it("a viewer given it can delegate their own named step only", () => {
    const v = staff("viewer", { "approval.delegate": true });
    expect(delegate(v, namedMe)).toBe(true);
    expect(delegate(v, namedOther)).toBe(false);
    expect(delegate(v, step({ assignedRole: "marketing" }))).toBe(false);
  });
  it("false stops anyone but admins", () => {
    expect(delegate(staff("ops", { "approval.delegate": false }), namedMe)).toBe(false);
    expect(delegate(staff("admin", { "approval.delegate": false }), namedOther)).toBe(true);
  });
});

describe("(j) costs", () => {
  it("costs.view false takes costs.edit with it", () => {
    const ops = staff("ops", { "costs.view": false });
    expect(can(ops, { type: "costs.view" })).toBe(false);
    expect(can(ops, { type: "costs.edit" })).toBe(false);
    expect(
      can(staff("ops", { "costs.view": false, "costs.edit": true }), { type: "costs.edit" }),
    ).toBe(false);
    expect(can(ops, { type: "sponsorship.sell" })).toBe(false);
  });
  it("sales set costs on sponsorship items they can edit, unless stored false", () => {
    expect(can(staff("sales"), { type: "costs.edit" })).toBe(false);
    expect(can(staff("sales"), { type: "costs.edit", item: sponsorshipItem })).toBe(true);
    expect(can(staff("sales"), { type: "costs.edit", item: sign })).toBe(false);
    expect(
      can(staff("sales", { "costs.edit": false }), { type: "costs.edit", item: sponsorshipItem }),
    ).toBe(false);
    expect(can(staff("viewer"), { type: "costs.edit", item: sponsorshipItem })).toBe(false);
  });
});

describe("(k) sections and tenancy come first", () => {
  const offSignage: Feature[] = ["calendar"];
  it("a granted ability never reopens a switched-off section", () => {
    expect(
      can(staff("viewer", { "signage.bulk": true }, { features: offSignage }), {
        type: "signage.bulk",
      }),
    ).toBe(false);
    expect(
      can(staff("sales", { "sponsorship.sell": true }, { features: offSignage }), {
        type: "sponsorship.sell",
      }),
    ).toBe(false);
    expect(
      can(staff("marketing", { "signage.create": true }, { features: ["sponsorship"] }), {
        type: "signage.create",
      }),
    ).toBe(false);
  });
  it("nobody acts on another organisation's records, whatever is stored", () => {
    const other = { ...sponsorshipItem, organisationId: "org-2" };
    expect(can(staff("admin"), { type: "costs.edit", item: other })).toBe(false);
    expect(can(staff("sales", { "costs.edit": true }), { type: "costs.edit", item: other })).toBe(
      false,
    );
  });
});
