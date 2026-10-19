/**
 * "Start from" templates (lib/users/templates.ts): the constants, and that
 * people only see the templates they may give — personChangeRefusal decides,
 * so a department manager never sees a role or ability above their own.
 */
import { describe, expect, it } from "vitest";
import { personChangeRefusal, type StaffActor } from "@/lib/authz";
import { overridesFor, startingChoices } from "@/lib/users/rules";
import {
  PERSON_TEMPLATES,
  templateById,
  templateChoices,
  templateRefusal,
  templatesFor,
} from "@/lib/users/templates";

const ORG = "org-1";
const staff = (over: Partial<StaffActor> = {}): StaffActor => ({
  kind: "staff",
  userId: "me",
  organisationId: ORG,
  role: "marketing",
  departmentId: "mkt",
  features: null,
  ...over,
});
const ids = (actor: StaffActor) =>
  templatesFor(actor, { departmentId: actor.departmentId ?? null }).map((t) => t.id);

describe("templates", () => {
  it("are the agreed five, Blank first", () => {
    expect(PERSON_TEMPLATES.map((t) => t.id)).toEqual([
      "blank",
      "marketing_executive",
      "freelance_installer",
      "sales_manager",
      "operations_coordinator",
    ]);
    expect(templateById("freelance_installer")).toMatchObject({
      role: "viewer",
      features: ["onsite", "calendar"],
      abilities: { "snag.manage": true, "signage.confirm": true },
      suggestEndDate: true,
    });
    expect(templateById("sales_manager")).toMatchObject({
      role: "sales",
      features: ["sponsorship", "calendar", "reports", "approvals"],
      abilities: { "reports.download": true },
    });
    expect(templateById("marketing_executive")?.features).toEqual([
      "signage",
      "sponsorship",
      "calendar",
      "approvals",
      "reports",
    ]);
    expect(templateById("operations_coordinator")).toMatchObject({ role: "ops", features: null });
    expect(templateById("nope")).toBeNull();
  });

  it("only the installer starts at Only these events with the current event", () => {
    expect(PERSON_TEMPLATES.filter((t) => t.events === "current").map((t) => t.id)).toEqual([
      "freelance_installer",
    ]);
    expect(PERSON_TEMPLATES.every((t) => t.events === "keep" || t.events === "current")).toBe(true);
  });

  it("only the installer suggests an end date", () => {
    expect(PERSON_TEMPLATES.filter((t) => t.suggestEndDate).map((t) => t.id)).toEqual([
      "freelance_installer",
    ]);
  });

  it("store only real differences from the role", () => {
    for (const t of PERSON_TEMPLATES) {
      if (!t.role) continue;
      expect(overridesFor(t.role, t.abilities)).toEqual(
        Object.fromEntries(Object.entries(t.abilities)),
      );
    }
  });
});

describe("templatesFor", () => {
  it("gives super admins every template", () => {
    expect(ids(staff({ role: "admin", departmentId: null }))).toEqual(
      PERSON_TEMPLATES.map((t) => t.id),
    );
  });

  it("gives someone who isn't a manager only Blank", () => {
    expect(ids(staff({ role: "ops", managerScope: null }))).toEqual(["blank"]);
  });

  it("gives a Marketing department manager only what Marketing can give", () => {
    // No Operations role, no Sales abilities, no "Confirm print, delivery and install".
    expect(ids(staff({ managerScope: "department" }))).toEqual(["blank", "marketing_executive"]);
  });

  it("switch off what only a super admin gives when a manager uses them", () => {
    const ops = staff({ role: "ops", managerScope: "everyone" });
    const coordinator = templatesFor(ops, { departmentId: null }).find(
      (t) => t.id === "operations_coordinator",
    );
    expect(coordinator?.abilities).toEqual({ "organisation.manage": false });
    const admin = staff({ role: "admin", departmentId: null });
    expect(
      templatesFor(admin, { departmentId: null }).find((t) => t.id === "operations_coordinator")
        ?.abilities,
    ).toEqual({});
    expect(startingChoices("marketing", {}, { superAdmin: false })).toEqual({});
    expect(startingChoices("ops", {}, { superAdmin: true })).toEqual({});
  });

  it("gives an Operations manager for everyone every template", () => {
    expect(ids(staff({ role: "ops", managerScope: "everyone", departmentId: "ops" }))).toEqual(
      PERSON_TEMPLATES.map((t) => t.id),
    );
  });

  it("leaves out templates with sections the manager doesn't have", () => {
    const actor = staff({
      role: "ops",
      managerScope: "everyone",
      features: ["signage", "onsite", "calendar"],
    });
    expect(ids(actor)).toEqual(["blank", "freelance_installer"]);
    expect(templateRefusal(actor, templateById("operations_coordinator")!, null)).toMatch(
      /sections you have yourself/,
    );
  });

  it("agree with personChangeRefusal for every template and actor", () => {
    const actors = [
      staff({ role: "admin", departmentId: null }),
      staff({ managerScope: "department" }),
      staff({ role: "sales", managerScope: "department", departmentId: "sales" }),
      staff({ role: "ops", managerScope: "everyone" }),
      staff({ role: "event_director", managerScope: "everyone" }),
    ];
    for (const actor of actors) {
      const shown = new Set(ids(actor));
      for (const t of PERSON_TEMPLATES) {
        if (!t.role) {
          expect(shown.has(t.id)).toBe(true);
          continue;
        }
        const refusal = personChangeRefusal(actor, null, null, {
          role: t.role,
          departmentId: actor.departmentId ?? null,
          features: t.features,
          overrides: overridesFor(t.role, templateChoices(actor, t)),
          managerScope: null,
          signoffs: [],
        });
        expect(shown.has(t.id)).toBe(refusal === null);
      }
    }
  });
});
