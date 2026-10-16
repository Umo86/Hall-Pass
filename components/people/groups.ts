/**
 * How a list of people is offered in a picker: "Me" first, then the
 * viewer's own department, then the other departments A–Z, then people with
 * no department. Each person reads "Name — Job title"; someone who can no
 * longer act (kept because the record is already with them) carries why, so
 * nothing silently disappears. Pure and client-safe (no database) — the
 * list itself comes from peopleFor() in lib/people.ts. Unit tested in
 * tests/unit/people.test.ts.
 */

/** One person a picker can offer. */
export type PersonOption = {
  id: string;
  /** Full name, or email when there is none. */
  name: string;
  jobTitle: string | null;
  departmentId: string | null;
  departmentName: string | null;
  /**
   * Why they can't be picked for this now ("Suspended", "Access ended",
   * "Can't sign off", "No longer has Signage"…). Null: they can.
   */
  unavailable: string | null;
};

export type PersonGroup = { key: string; label: string; people: PersonOption[] };

export const NO_DEPARTMENT = "No department";

const byName = (a: PersonOption, b: PersonOption) =>
  a.name.localeCompare(b.name, "en-GB", { sensitivity: "base" });

/**
 * Group people for a picker. `meId` (the viewer) goes first in a group of
 * their own; their department comes next. Duplicates (same id) are dropped.
 */
export function groupPeople(
  people: readonly PersonOption[],
  opts: { meId?: string | null; meDepartmentId?: string | null } = {},
): PersonGroup[] {
  const seen = new Set<string>();
  const unique = people.filter((p) => (seen.has(p.id) ? false : (seen.add(p.id), true)));
  const groups: PersonGroup[] = [];
  const me = opts.meId ? unique.find((p) => p.id === opts.meId) : undefined;
  if (me) groups.push({ key: "me", label: "You", people: [me] });
  const rest = unique.filter((p) => p !== me);
  const depts = new Map<string, { label: string; people: PersonOption[] }>();
  const none: PersonOption[] = [];
  for (const p of rest) {
    if (!p.departmentId) {
      none.push(p);
      continue;
    }
    const entry = depts.get(p.departmentId) ?? {
      label: p.departmentName || NO_DEPARTMENT,
      people: [],
    };
    entry.people.push(p);
    depts.set(p.departmentId, entry);
  }
  const ordered = [...depts.entries()].sort(([idA, a], [idB, b]) => {
    if (idA === opts.meDepartmentId) return -1;
    if (idB === opts.meDepartmentId) return 1;
    return a.label.localeCompare(b.label, "en-GB", { sensitivity: "base" });
  });
  for (const [id, g] of ordered) {
    groups.push({ key: id, label: g.label, people: g.people.sort(byName) });
  }
  if (none.length > 0) {
    groups.push({ key: "none", label: NO_DEPARTMENT, people: none.sort(byName) });
  }
  return groups;
}

/** "Sam Lee — Marketing Manager", "Me (Sam Lee)", "Jo Bloggs (Suspended)". */
export function personLabel(p: PersonOption, opts: { meId?: string | null } = {}): string {
  const base =
    p.id === opts.meId ? `Me (${p.name})` : p.jobTitle ? `${p.name} — ${p.jobTitle}` : p.name;
  return p.unavailable ? `${base} (${p.unavailable})` : base;
}

/** Only the people who can be picked now, plus `keepId` (the current choice) whatever its state. */
export function pickable(people: readonly PersonOption[], keepId?: string | null): PersonOption[] {
  return people.filter((p) => !p.unavailable || p.id === keepId);
}

/** The person's name for a toast or summary ("them" when unknown). */
export function nameOf(people: readonly PersonOption[], id: string | null | undefined): string {
  return (id && people.find((p) => p.id === id)?.name) || "them";
}
