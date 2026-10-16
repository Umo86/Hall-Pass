/**
 * Pure rules behind Users: abilities as differences from the role, the
 * sections picker, sign-off changes and the words shown in lists. No
 * database and no React, so the forms and the server agree and it can all
 * be unit tested (tests/unit/users.test.ts).
 */
import {
  FEATURES,
  OVERRIDE_ROLE_DEFAULTS,
  type Feature,
  type OverrideKey,
  type PermissionOverrides,
  type StaffRole,
} from "@/lib/authz";
import { formatDayMonth, ROLE_LABELS } from "@/lib/format";

/** Staff roles in the order they are offered. */
export const STAFF_ROLES: readonly StaffRole[] = [
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  "viewer",
];

/**
 * What an admin can fine-tune per person on top of their role. Sign-off
 * (approval.decide) is not one of them any more: it is "Signs off artwork".
 */
export const ABILITY_KEYS = [
  "signage.create",
  "sponsorship.create",
  "costs.edit",
  "settings.manage",
] as const satisfies readonly OverrideKey[];
export type AbilityKey = (typeof ABILITY_KEYS)[number];
export type Abilities = Record<AbilityKey, boolean>;

export const ABILITY_LABELS: Record<AbilityKey, string> = {
  "signage.create": "Add and edit signage",
  "sponsorship.create": "Add sponsorship items",
  "costs.edit": "Edit costs and PO numbers",
  "settings.manage": "Set up events, halls, suppliers and lists",
};

/** The section an ability belongs to: it is only offered while that section is on. */
export const ABILITY_FEATURE: Record<AbilityKey, Feature | null> = {
  "signage.create": "signage",
  "sponsorship.create": "sponsorship",
  "costs.edit": null,
  "settings.manage": null,
};

export function roleHasByDefault(key: OverrideKey, role: StaffRole): boolean {
  return OVERRIDE_ROLE_DEFAULTS[key].includes(role);
}

/** What the person can do now: their stored differences over the role defaults. */
export function effectiveAbilities(role: StaffRole, overrides: PermissionOverrides): Abilities {
  return Object.fromEntries(
    ABILITY_KEYS.map((k) => [k, overrides[k] ?? roleHasByDefault(k, role)]),
  ) as Abilities;
}

/** The role's own defaults, for when the role changes. */
export function defaultAbilities(role: StaffRole): Abilities {
  return effectiveAbilities(role, {});
}

/** A stored "approval.decide: false" — their sign-off has been paused. */
export function signoffPaused(overrides: PermissionOverrides | null | undefined): boolean {
  return overrides?.["approval.decide"] === false;
}

/**
 * The overrides to store: only abilities that differ from the role's
 * defaults, plus a paused sign-off. Admins never have overrides.
 */
export function overridesFor(
  role: StaffRole,
  abilities: Partial<Abilities>,
  opts: { signoffPaused?: boolean } = {},
): PermissionOverrides {
  if (role === "admin") return {};
  const out: PermissionOverrides = {};
  for (const k of ABILITY_KEYS) {
    const v = abilities[k];
    if (typeof v === "boolean" && v !== roleHasByDefault(k, role)) out[k] = v;
  }
  if (opts.signoffPaused) out["approval.decide"] = false;
  return out;
}

/** Sections offered in the picker (Exhibitor stands only while stands are switched on). */
export function visibleFeatures(standsEnabled: boolean): Feature[] {
  return FEATURES.filter((f) => standsEnabled || f !== "stands");
}

/**
 * Clean a sections list for storing: known keys only, no repeats, in the
 * standard order. Every section = null ("All sections").
 */
export function normaliseFeatures(
  features: readonly string[] | null | undefined,
): Feature[] | null {
  if (features == null) return null;
  const set = new Set(features);
  const list = FEATURES.filter((f) => set.has(f));
  return list.length === FEATURES.length ? null : list;
}

/** Are these the same sections? (null = all) */
export function sameFeatures(a: readonly string[] | null, b: readonly string[] | null): boolean {
  const x = normaliseFeatures(a);
  const y = normaliseFeatures(b);
  if (x === null || y === null) return x === y;
  return x.length === y.length && x.every((f, i) => f === y[i]);
}

/** "All sections", "4 of 9" or "No sections". */
export function featuresSummary(features: readonly Feature[] | null, visible: readonly Feature[]) {
  if (features == null) return "All sections";
  const n = features.filter((f) => visible.includes(f)).length;
  if (n === 0) return "No sections";
  if (n === visible.length) return "All sections";
  return `${n} of ${visible.length}`;
}

/**
 * The role to suggest for someone joining a department: the role with the
 * same name ("Marketing" → Marketing). Admin is never suggested.
 */
export function roleForDepartment(name: string | null | undefined): StaffRole | null {
  const wanted = name?.trim().toLowerCase();
  if (!wanted) return null;
  for (const role of STAFF_ROLES) {
    if (role === "admin") continue;
    const label = ROLE_LABELS[role].toLowerCase();
    if (label === wanted || label.replace(/\s*\(.*\)$/, "") === wanted) return role;
  }
  return null;
}

/** One department someone signs off for. */
export type Signoff = { departmentId: string; isMain: boolean };

/**
 * What changes between the departments someone signs off for now and what
 * the form asks for: rows to add, rows to remove and main-approver changes.
 */
export function signoffChanges(current: readonly Signoff[], desired: readonly Signoff[]) {
  const now = new Map(current.map((s) => [s.departmentId, s.isMain]));
  const next = new Map(desired.map((s) => [s.departmentId, s.isMain]));
  return {
    add: [...next]
      .filter(([id]) => !now.has(id))
      .map(([departmentId, isMain]) => ({
        departmentId,
        isMain,
      })),
    remove: [...now.keys()].filter((id) => !next.has(id)),
    update: [...next]
      .filter(([id, main]) => now.has(id) && now.get(id) !== main)
      .map(([departmentId, isMain]) => ({ departmentId, isMain })),
  };
}

/** "Invited 3 Oct by Alex", or "Invite expired". */
export function inviteStatusText(
  invite: { createdAt: Date; expiresAt: Date | null; inviterName?: string | null },
  now = new Date(),
): string {
  if (invite.expiresAt && invite.expiresAt.getTime() <= now.getTime()) return "Invite expired";
  const by = invite.inviterName?.trim().split(/\s+/)[0];
  return `Invited ${formatDayMonth(invite.createdAt)}${by ? ` by ${by}` : ""}`;
}

/** Name A–Z, with the person looking at the list first. */
export function sortPeople<T extends { name: string; email: string; isSelf?: boolean }>(
  rows: readonly T[],
): T[] {
  return [...rows].sort(
    (a, b) =>
      Number(Boolean(b.isSelf)) - Number(Boolean(a.isSelf)) ||
      (a.name || a.email).localeCompare(b.name || b.email, "en-GB", { sensitivity: "base" }) ||
      a.email.localeCompare(b.email),
  );
}

/** "Sam" from "Sam Smith"; the email's first part when there is no name. */
export function firstName(name: string | null | undefined, email?: string): string {
  const first = name?.trim().split(/\s+/)[0];
  return first || email?.split("@")[0] || "They";
}

/**
 * What happens to a department's sign-offs when someone leaves it: the
 * other approvers take over, or nobody is left to sign.
 */
export function departmentFallbackText(dept: {
  name: string;
  isMain: boolean;
  others: readonly string[];
}): string {
  if (dept.others.length === 0) {
    return `${dept.name} will have no approvers — add one first or its sign-offs will wait.`;
  }
  const names =
    dept.others.length <= 2
      ? dept.others.join(" and ")
      : `${dept.others.slice(0, 2).join(", ")} and ${dept.others.length - 2} more`;
  return `Sign-offs for ${dept.name} will go to ${names}.`;
}
