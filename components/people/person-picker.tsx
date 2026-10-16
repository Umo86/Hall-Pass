"use client";

import { SelectNative } from "@/components/ui/select-native";
import { groupPeople, personLabel, pickable, type PersonOption } from "./groups";

/**
 * The one person picker: a native select (keyboard and phone friendly) with
 * people grouped by department — "Me" first, then the viewer's department,
 * the others A–Z, then "No department" — each as "Name — Job title". The
 * current choice stays listed (labelled "Suspended", "Can't sign off"…)
 * when that person can no longer be picked, so opening and saving a form
 * never changes it by accident. People come from peopleFor() in
 * lib/people.ts.
 */
export function PersonPicker({
  people,
  meId,
  meDepartmentId,
  value,
  defaultValue,
  onChange,
  blankLabel,
  name,
  id,
  className,
  disabled,
  required,
  "aria-label": ariaLabel,
  "aria-describedby": ariaDescribedBy,
}: {
  people: readonly PersonOption[];
  /** The viewer: shown first as "Me (Name)". */
  meId?: string | null;
  meDepartmentId?: string | null;
  /** Controlled value ("" for the blank option). */
  value?: string;
  defaultValue?: string;
  onChange?: (userId: string) => void;
  /** A first, empty option: "— Choose a person —", "Keep current owner", "Me"… */
  blankLabel?: string;
  name?: string;
  id?: string;
  className?: string;
  disabled?: boolean;
  required?: boolean;
  "aria-label"?: string;
  "aria-describedby"?: string;
}) {
  const current = value ?? defaultValue ?? null;
  const groups = groupPeople(pickable(people, current), { meId, meDepartmentId });
  return (
    <SelectNative
      id={id}
      name={name}
      value={value}
      defaultValue={value === undefined ? defaultValue : undefined}
      onChange={onChange ? (e) => onChange(e.target.value) : undefined}
      className={className}
      disabled={disabled}
      required={required}
      aria-label={ariaLabel}
      aria-describedby={ariaDescribedBy}
    >
      {blankLabel !== undefined && <option value="">{blankLabel}</option>}
      {groups.map((g) =>
        g.key === "me" ? (
          g.people.map((p) => (
            <option key={p.id} value={p.id}>
              {personLabel(p, { meId })}
            </option>
          ))
        ) : (
          <optgroup key={g.key} label={g.label}>
            {g.people.map((p) => (
              <option key={p.id} value={p.id}>
                {personLabel(p, { meId })}
              </option>
            ))}
          </optgroup>
        ),
      )}
    </SelectNative>
  );
}

/** A line under a picker when the current choice can no longer act. */
export function UnavailableNote({
  people,
  userId,
  what,
}: {
  people: readonly PersonOption[];
  userId: string | null | undefined;
  /** "own this item", "sign this off", "work on this task" */
  what: string;
}) {
  const p = userId ? people.find((x) => x.id === userId) : undefined;
  if (!p?.unavailable) return null;
  return (
    <p className="text-xs text-amber-800 dark:text-amber-300">
      {p.name} can&apos;t {what} now ({p.unavailable.toLowerCase()}) — pick someone else.
    </p>
  );
}
