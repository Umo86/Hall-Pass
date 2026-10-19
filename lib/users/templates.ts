/**
 * "Start from" on Add person: common starting points that fill the role,
 * sections, abilities and job title in one click (everything can still be
 * changed before sending). Constants, so they are the same for everyone;
 * templatesFor() leaves out the ones the person adding may not give
 * (personChangeRefusal), so a department manager only sees what they can
 * use. Pure — unit tested in tests/unit/users-templates.test.ts.
 */
import {
  isSuperAdmin,
  personChangeRefusal,
  type Actor,
  type Feature,
  type StaffRole,
} from "@/lib/authz";
import { overridesFor, startingChoices, type AbilityChoices } from "./rules";

export type PersonTemplateId =
  | "blank"
  | "marketing_executive"
  | "freelance_installer"
  | "sales_manager"
  | "operations_coordinator";

export type PersonTemplate = {
  id: PersonTemplateId;
  name: string;
  description: string;
  /** Null for Blank: nothing is chosen. */
  role: StaffRole | null;
  /** Null = every section. */
  features: Feature[] | null;
  /** Abilities changed from the role's defaults. */
  abilities: AbilityChoices;
  jobTitle: string | null;
  /** Usually someone with an end date (a freelancer): the form asks for one. */
  suggestEndDate: boolean;
  /**
   * Users → Events: "keep" leaves the form's choice as it is; "current" sets
   * Only these events with the current event (freelancers are usually hired
   * for one event).
   */
  events: "keep" | "current";
};

export const PERSON_TEMPLATES: readonly PersonTemplate[] = [
  {
    id: "blank",
    name: "Blank",
    description: "Choose everything yourself.",
    role: null,
    features: null,
    abilities: {},
    jobTitle: null,
    suggestEndDate: false,
    events: "keep",
  },
  {
    id: "marketing_executive",
    name: "Marketing executive",
    description: "Adds signage, uploads artwork and follows sponsorship and sign-offs.",
    role: "marketing",
    features: ["signage", "sponsorship", "calendar", "approvals", "reports"],
    abilities: {},
    jobTitle: "Marketing executive",
    suggestEndDate: false,
    events: "keep",
  },
  {
    id: "freelance_installer",
    name: "Freelance installer",
    description:
      "Onsite only: raises and fixes snags and confirms installs. Usually has an end date.",
    role: "viewer",
    features: ["onsite", "calendar"],
    abilities: { "snag.manage": true, "signage.confirm": true },
    jobTitle: "Installer",
    suggestEndDate: true,
    events: "current",
  },
  {
    id: "sales_manager",
    name: "Sales manager",
    description: "Sells sponsorship, follows sign-offs and downloads every report.",
    role: "sales",
    features: ["sponsorship", "calendar", "reports", "approvals"],
    abilities: { "reports.download": true },
    jobTitle: "Sales manager",
    suggestEndDate: false,
    events: "keep",
  },
  {
    id: "operations_coordinator",
    name: "Operations coordinator",
    description: "Runs events day to day, with every section.",
    role: "ops",
    features: null,
    abilities: {},
    jobTitle: "Operations coordinator",
    suggestEndDate: false,
    events: "keep",
  },
];

export function templateById(id: string | null | undefined): PersonTemplate | null {
  return PERSON_TEMPLATES.find((t) => t.id === id) ?? null;
}

/**
 * The abilities a template gives when this person uses it: for anyone but
 * a super admin, abilities only a super admin gives are off.
 */
export function templateChoices(actor: Actor, template: PersonTemplate): AbilityChoices {
  if (!template.role) return {};
  return startingChoices(template.role, template.abilities, { superAdmin: isSuperAdmin(actor) });
}

/**
 * Why this person can't use the template (personChangeRefusal's words), or
 * null when they can. `departmentId` is where the new person would go: a
 * department manager's own department.
 */
export function templateRefusal(
  actor: Actor,
  template: PersonTemplate,
  departmentId: string | null,
): string | null {
  if (!template.role) return null;
  return personChangeRefusal(actor, null, null, {
    role: template.role,
    departmentId,
    features: template.features,
    overrides: overridesFor(template.role, templateChoices(actor, template)),
    managerScope: null,
    signoffs: [],
  });
}

/**
 * The templates this person may start from (Blank always), with the
 * abilities as they would give them.
 */
export function templatesFor(
  actor: Actor,
  opts: { departmentId: string | null },
): PersonTemplate[] {
  return PERSON_TEMPLATES.filter((t) => templateRefusal(actor, t, opts.departmentId) === null).map(
    (t) => ({ ...t, abilities: templateChoices(actor, t) }),
  );
}
