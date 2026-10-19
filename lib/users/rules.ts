/**
 * Pure rules behind Users: abilities as differences from the role, the
 * sections picker, sign-off changes and the words shown in lists. No
 * database and no React, so the forms and the server agree and it can all
 * be unit tested (tests/unit/users.test.ts).
 */
import {
  ABILITIES,
  ABILITY_GROUP_LABELS,
  ABILITY_GROUPS,
  ABILITY_KEYS,
  abilityLevel,
  FEATURES,
  STAFF_ROLES,
  storedAbility,
  type AbilityGroup,
  type AbilityKey,
  type AbilityLevel,
  type Feature,
  type PermissionOverrides,
  type StaffRole,
} from "@/lib/authz";
import { formatDayMonth, ROLE_LABELS } from "@/lib/format";

export { signoffPaused, STAFF_ROLES } from "@/lib/authz";
export type { AbilityKey, AbilityLevel } from "@/lib/authz";

/**
 * What can be fine-tuned per person on top of their role, in the form's
 * order. Sign-off (approval.decide) is not one of them: it is "Signs off
 * artwork", and a stored false shows as "Sign-off paused".
 */
export const EDITABLE_ABILITY_KEYS: readonly AbilityKey[] = ABILITY_KEYS.filter(
  (k) => !ABILITIES[k].hidden,
);

export const ABILITY_LABELS = Object.fromEntries(
  ABILITY_KEYS.map((k) => [k, ABILITIES[k].label]),
) as Record<AbilityKey, string>;

/** The section an ability belongs to: it is only offered while that section is on. */
export const ABILITY_FEATURE = Object.fromEntries(
  ABILITY_KEYS.map((k) => [k, ABILITIES[k].feature]),
) as Record<AbilityKey, Feature | null>;

/** The editable abilities by group, in the form's order (empty groups left out). */
export function abilityGroups(
  keys: readonly AbilityKey[] = EDITABLE_ABILITY_KEYS,
): { group: AbilityGroup; label: string; keys: AbilityKey[] }[] {
  return ABILITY_GROUPS.map((group) => ({
    group,
    label: ABILITY_GROUP_LABELS[group],
    keys: keys.filter((k) => ABILITIES[k].group === group),
  })).filter((g) => g.keys.length > 0);
}

/**
 * The form's choices: an explicit on or off per ability; a key left out
 * follows the role (and, for abilities that derive from another, that one).
 */
export type AbilityChoices = Partial<Record<AbilityKey, boolean>>;
/** @deprecated Use AbilityChoices. */
export type Abilities = AbilityChoices;

/** The choices stored for someone, older keys read through (settings.manage → the six). */
export function abilityChoices(overrides: PermissionOverrides | null | undefined): AbilityChoices {
  const out: AbilityChoices = {};
  for (const k of EDITABLE_ABILITY_KEYS) {
    const v = storedAbility(overrides, k);
    if (v !== undefined) out[k] = v;
  }
  return out;
}

/** The role's own defaults, for when the role changes: nothing chosen. */
export function defaultAbilities(role: StaffRole): AbilityChoices {
  void role;
  return {};
}

/** Whether they would have the ability: "yes", "partial" or "no". */
export function effectiveAbility(
  role: StaffRole,
  choices: AbilityChoices,
  key: AbilityKey,
): AbilityLevel {
  return abilityLevel({ role, overrides: choices }, key);
}

/** Every ability's level for someone with this role and what is stored for them. */
export function effectiveAbilities(
  role: StaffRole,
  overrides: PermissionOverrides | null | undefined,
): Record<AbilityKey, AbilityLevel> {
  return Object.fromEntries(
    ABILITY_KEYS.map((k) => [k, abilityLevel({ role, overrides: overrides ?? {} }, k)]),
  ) as Record<AbilityKey, AbilityLevel>;
}

/** What the ability would be with nothing chosen for it (other choices kept). */
export function abilityDefault(
  role: StaffRole,
  choices: AbilityChoices,
  key: AbilityKey,
): AbilityLevel {
  const rest = { ...choices };
  delete rest[key];
  return abilityLevel({ role, overrides: rest }, key);
}

/** Does this choice differ from what the role would give anyway? */
export function abilityChanged(role: StaffRole, choices: AbilityChoices, key: AbilityKey): boolean {
  const v = choices[key];
  if (typeof v !== "boolean") return false;
  return abilityDefault(role, choices, key) !== (v ? "yes" : "no");
}

/** Does the role have this ability by default (fully)? */
export function roleHasByDefault(key: AbilityKey, role: StaffRole): boolean {
  return abilityLevel({ role }, key) === "yes";
}

/**
 * The overrides to store: only choices that differ from the role's
 * defaults, plus a paused sign-off. Only the registry's keys are written;
 * an older settings.manage is dropped (its six abilities are written out
 * when they differ). Admins never have overrides.
 */
export function overridesFor(
  role: StaffRole,
  choices: AbilityChoices,
  opts: { signoffPaused?: boolean } = {},
): PermissionOverrides {
  if (role === "admin") return {};
  const out: PermissionOverrides = {};
  for (const k of EDITABLE_ABILITY_KEYS) {
    if (abilityChanged(role, choices, k)) out[k] = choices[k];
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

/**
 * One department someone signs off for. isMain: main approver — for someone
 * only invited, now or when they accept, whichever setSignoffs decided
 * (mainTakeover).
 */
export type Signoff = { departmentId: string; isMain: boolean };

export type MainTakeover = "now" | "on_accept";

/**
 * When someone chosen as main approver takes over: now, unless they are
 * only invited and the current main can sign — then when they accept.
 */
export function mainTakeover(p: {
  hasAccount: boolean;
  currentMainCanSign: boolean;
}): MainTakeover {
  return !p.hasAccount && p.currentMainCanSign ? "on_accept" : "now";
}

export type MainOnAcceptOutcome = "promote" | "department_off" | "cant_sign";

/**
 * At acceptance: carried out only if the department still signs off and they
 * can sign off now (canReceiveSignoff — event-blind on purpose).
 */
export function mainOnAcceptOutcome(p: {
  departmentArchived: boolean;
  signsOff: boolean;
  canSign: boolean;
}): MainOnAcceptOutcome {
  if (p.departmentArchived || !p.signsOff) return "department_off";
  return p.canSign ? "promote" : "cant_sign";
}

/**
 * What choosing this person as main approver does, in words (Add one, the
 * person and invitation pages). `current` is someone else who is main now;
 * `pending` someone else's "main when they accept", which this choice
 * replaces (the newest choice wins).
 */
export function mainApproverNote(p: {
  person: string;
  department: string;
  invited: boolean;
  current: { name: string; canSign: boolean } | null;
  pending: string | null;
  /** eventsSummary of a new main limited to some events; null/omitted = every event. */
  newMainEvents?: string | null;
}): string {
  // Starts a sentence: "This person only works on…" before a name is typed.
  const who = p.person.charAt(0).toUpperCase() + p.person.slice(1);
  const events = p.newMainEvents
    ? ` ${who} only works on ${p.newMainEvents.replace(/ only$/, "")}, so ${p.department} sign-offs in other events go to everyone in ${p.department}.`
    : "";
  return mainApproverWords(p) + events;
}

function mainApproverWords(p: {
  person: string;
  department: string;
  invited: boolean;
  current: { name: string; canSign: boolean } | null;
  pending: string | null;
}): string {
  const waits = p.invited && Boolean(p.current?.canSign);
  const first = !p.current
    ? `${p.department} has no main approver yet.`
    : !p.current.canSign
      ? `Replaces ${p.current.name}, who can't sign off at the moment.`
      : waits
        ? `${p.current.name} stays main approver until ${p.person} accepts, then ${p.person} takes over.`
        : `Replaces ${p.current.name} as main approver.`;
  if (!p.pending) return first;
  return waits
    ? `${first} ${p.pending} was going to take over when they accept — ${p.person} will instead.`
    : `${first} ${p.pending} won't take over when they accept.`;
}

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
 * firstName for the middle of a sentence on a form where nothing may be
 * typed yet: "this person" then (it takes "accepts", "sees"), never "They".
 */
export function nameInSentence(name: string | null | undefined, email?: string | null): string {
  const first = name?.trim().split(/\s+/)[0] || email?.trim().split("@")[0];
  return first || "this person";
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

/**
 * The choices someone who isn't a super admin starts from for a role:
 * abilities only a super admin gives (Organisation settings, Invite
 * partners, Manage departments) are switched off, so a manager can give
 * the role at all (personChangeRefusal rule 7).
 */
export function startingChoices(
  role: StaffRole,
  choices: AbilityChoices,
  opts: { superAdmin: boolean },
): AbilityChoices {
  if (opts.superAdmin || role === "admin") return choices;
  const out: AbilityChoices = { ...choices };
  for (const k of EDITABLE_ABILITY_KEYS) {
    if (!ABILITIES[k].superAdminGrants) continue;
    if (abilityLevel({ role, overrides: out }, k) !== "no") out[k] = false;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Events per person (Users → Events). A list of edition ids, or null for
// every event including new ones.
// ---------------------------------------------------------------------------

/** Clean an events list for storing: null stays null; no repeats, sorted. An empty list stays empty (refused). */
export function normaliseEditionIds(ids: readonly string[] | null | undefined): string[] | null {
  if (ids == null) return null;
  return [...new Set(ids)].sort();
}

/** Are these the same events? (null = every event) */
export function sameEditions(
  a: readonly string[] | null | undefined,
  b: readonly string[] | null | undefined,
): boolean {
  const x = normaliseEditionIds(a);
  const y = normaliseEditionIds(b);
  if (x === null || y === null) return x === y;
  return x.length === y.length && x.every((id, i) => id === y[i]);
}

/**
 * "All events", "BIRM27 only" or "3 events". `codeOf` gives a code only for
 * events the viewer can open (null otherwise), so nothing names an event
 * they haven't been given.
 */
export function eventsSummary(
  ids: readonly string[] | null,
  codeOf: (id: string) => string | null,
): string {
  if (ids === null) return "All events";
  if (ids.length === 1) {
    const code = codeOf(ids[0]);
    return code ? `${code} only` : "1 event";
  }
  return `${ids.length} events`;
}

/** The chip's title: "Only 3 events: BIRM27, LOND27 and 1 other" (codes the viewer can open). */
export function eventsTitle(
  ids: readonly string[] | null,
  codeOf: (id: string) => string | null,
): string {
  if (ids === null) return "All events";
  const known = ids.map(codeOf).filter((c): c is string => Boolean(c));
  const hidden = ids.length - known.length;
  if (ids.length === 1) return known.length ? `Only ${known[0]}` : "Only 1 event";
  if (known.length === 0) return `Only ${ids.length} events`;
  const parts = [...known];
  if (hidden > 0) parts.push(`${hidden} other${hidden === 1 ? "" : "s"}`);
  const list =
    parts.length === 1 ? parts[0] : `${parts.slice(0, -1).join(", ")} and ${parts.at(-1)}`;
  return `Only ${ids.length} events: ${list}`;
}

/** The events someone loses with this change (before null = every event; after null = none lost). */
export function removedEditions(
  before: readonly string[] | null,
  after: readonly string[] | null,
  all: readonly string[],
): string[] {
  if (after === null) return [];
  const had = before === null ? all : before;
  const keep = new Set(after);
  return [...new Set(had)].filter((id) => !keep.has(id));
}
