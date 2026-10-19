"use client";

/**
 * The pieces of the person form shared by Add user and a person's page:
 * department, role cards, sections, sign-off and the fine-tuned abilities.
 * Each is controlled by its parent; nothing here saves on its own.
 */
import {
  Box,
  CalendarDays,
  ChevronDown,
  ClipboardCheck,
  FileBarChart,
  Gift,
  HardHat,
  Signpost,
  Star,
  Truck,
  Wrench,
} from "lucide-react";
import {
  ABILITIES,
  FEATURE_LABELS,
  type AbilityKey,
  type Feature,
  type ManagerScope,
  type StaffRole,
} from "@/lib/authz";
import { ROLE_DESCRIPTIONS, roleLabel } from "@/lib/format";
import {
  abilityChanged,
  abilityGroups,
  EDITABLE_ABILITY_KEYS,
  effectiveAbility,
  STAFF_ROLES,
  type AbilityChoices,
} from "@/lib/users/rules";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { cn } from "@/lib/utils";

export const NEW_DEPARTMENT = "__new";

export type DepartmentOption = {
  id: string;
  name: string;
  signsOff: boolean;
  isArchived: boolean;
  /** The current main approver's name, if the department has one. */
  mainApprover: string | null;
  /** The main approver is this person. */
  mainIsThisPerson?: boolean;
  /** The main approver can sign off now (an invitee takes over when they accept). */
  mainCanSign?: boolean;
  /** Someone else becomes main approver when they accept (a new choice replaces it). */
  pendingMain?: string | null;
  /** This person becomes main approver when they accept. */
  pendingIsThisPerson?: boolean;
};

export const FEATURE_ICONS: Record<Feature, React.ComponentType<{ className?: string }>> = {
  signage: Signpost,
  sponsorship: Gift,
  stand_designs: Box,
  stands: HardHat,
  onsite: Wrench,
  calendar: CalendarDays,
  reports: FileBarChart,
  suppliers: Truck,
  approvals: ClipboardCheck,
};

export function FieldError({ id, message }: { id?: string; message?: string | null }) {
  if (!message) return null;
  return (
    <p id={id} role="alert" className="text-destructive text-sm">
      {message}
    </p>
  );
}

export function DepartmentField({
  id,
  departments,
  value,
  onChange,
  newName,
  onNewName,
  error,
  disabled,
  allowNew = true,
  allowNone = true,
  hint,
}: {
  id: string;
  departments: DepartmentOption[];
  /** "" = no department, NEW_DEPARTMENT = make one, otherwise an id. */
  value: string;
  onChange: (value: string) => void;
  newName: string;
  onNewName: (name: string) => void;
  error?: string | null;
  disabled?: boolean;
  /** "+ New department…" (needs departments.manage). */
  allowNew?: boolean;
  /** "No department" (a department manager's people always have theirs). */
  allowNone?: boolean;
  /** A line under the field, e.g. "You add people to Marketing". */
  hint?: string | null;
}) {
  const live = departments.filter((d) => !d.isArchived);
  const current = departments.find((d) => d.id === value && d.isArchived);
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>Department</Label>
      <SelectNative
        id={id}
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
        className="h-11 sm:h-9"
      >
        {allowNone && <option value="">No department</option>}
        {live.map((d) => (
          <option key={d.id} value={d.id}>
            {d.name}
          </option>
        ))}
        {current && <option value={current.id}>{current.name} (archived)</option>}
        {allowNew && <option value={NEW_DEPARTMENT}>+ New department…</option>}
      </SelectNative>
      {hint && <p className="text-muted-foreground text-xs">{hint}</p>}
      {value === NEW_DEPARTMENT && (
        <div className="space-y-1.5 pt-1">
          <Label htmlFor={`${id}-new`}>New department name</Label>
          <Input
            id={`${id}-new`}
            value={newName}
            onChange={(e) => onNewName(e.target.value)}
            placeholder="e.g. Events"
            maxLength={60}
            autoFocus
            aria-invalid={Boolean(error)}
            aria-describedby={`${id}-new-hint`}
          />
          <p id={`${id}-new-hint`} className="text-muted-foreground text-xs">
            It starts as a team for grouping people. Turn on sign-off in Departments if this team
            approves artwork.
          </p>
        </div>
      )}
      <FieldError message={error} />
    </div>
  );
}

export function RoleCards({
  name,
  value,
  onChange,
  lockedReason,
  onlyAdmin,
  allowed,
  error,
}: {
  name: string;
  value: StaffRole | null;
  onChange: (role: StaffRole) => void;
  /** Set when the role can't be changed at all (e.g. your own). */
  lockedReason?: string | null;
  /** The last admin: every other role is off. */
  onlyAdmin?: boolean;
  /** Roles the viewer may give (assignableRoles); the current one always shows. */
  allowed?: readonly StaffRole[];
  error?: string | null;
}) {
  return (
    <fieldset className="space-y-2" aria-describedby={error ? `${name}-error` : undefined}>
      <legend className="text-sm font-medium">Role</legend>
      <div className="grid gap-2 sm:grid-cols-2">
        {/* Locked: only the role they have is worth showing. */}
        {STAFF_ROLES.filter(
          (r) => (!lockedReason || r === value) && (!allowed || allowed.includes(r) || r === value),
        ).map((role) => {
          const disabled = Boolean(lockedReason) || (onlyAdmin === true && role !== "admin");
          const checked = value === role;
          return (
            <label
              key={role}
              className={cn(
                "flex min-h-11 cursor-pointer items-start gap-3 rounded-md border p-3 text-sm transition-colors",
                checked ? "border-primary bg-primary/5 ring-primary ring-1" : "hover:bg-muted/40",
                disabled && "cursor-not-allowed opacity-60",
              )}
            >
              <input
                type="radio"
                name={name}
                value={role}
                checked={checked}
                disabled={disabled}
                onChange={() => onChange(role)}
                className="accent-primary mt-0.5 size-4 shrink-0"
              />
              <span className="min-w-0">
                <span className="block font-medium">{roleLabel(role)}</span>
                <span className="text-muted-foreground block text-xs">
                  {ROLE_DESCRIPTIONS[role]}
                </span>
              </span>
            </label>
          );
        })}
      </div>
      {lockedReason ? (
        <p className="text-muted-foreground text-sm">{lockedReason}</p>
      ) : onlyAdmin ? (
        <p className="text-muted-foreground text-sm">
          There must always be at least one super admin.
        </p>
      ) : null}
      <FieldError id={`${name}-error`} message={error} />
    </fieldset>
  );
}

export function SectionsPicker({
  id,
  value,
  onChange,
  visible,
  disabled,
  owned,
  personName,
  allowAll = true,
}: {
  id: string;
  /** Null = every section. */
  value: Feature[] | null;
  onChange: (value: Feature[] | null) => void;
  visible: Feature[];
  disabled?: boolean;
  /** Items they own, by section, for the "still get updates" note. */
  owned?: Partial<Record<Feature, number>>;
  personName?: string;
  /** "All sections" may be given (a manager without every section gives them one by one). */
  allowAll?: boolean;
}) {
  const all = value === null;
  const offWithItems =
    value && owned
      ? visible.filter((f) => !value.includes(f) && (owned[f] ?? 0) > 0)
      : ([] as Feature[]);
  return (
    <fieldset className="space-y-2" disabled={disabled}>
      <legend className="text-sm font-medium">Sections they can use</legend>
      {(allowAll || all) && (
        <label className="flex min-h-11 items-center gap-2 text-sm sm:min-h-0">
          <input
            type="checkbox"
            className="accent-primary size-4"
            checked={all}
            onChange={(e) => onChange(e.target.checked ? null : allowAll ? [] : [...visible])}
            aria-controls={`${id}-list`}
          />
          All sections
        </label>
      )}
      {!allowAll && (
        <p className="text-muted-foreground text-xs">
          You can give the sections you have yourself.
        </p>
      )}
      {all ? (
        <p className="text-muted-foreground text-xs">
          Untick to choose. My Work, Events, Users and their own sign-offs are always there.
        </p>
      ) : (
        <div id={`${id}-list`} className="space-y-2 rounded-md border p-3">
          <p className="text-muted-foreground text-xs">Tick the sections they use.</p>
          <div className="grid gap-1 sm:grid-cols-2">
            {visible.map((f) => {
              const Icon = FEATURE_ICONS[f];
              return (
                <label key={f} className="flex min-h-11 items-center gap-2 text-sm sm:min-h-8">
                  <input
                    type="checkbox"
                    className="accent-primary size-4"
                    checked={value.includes(f)}
                    onChange={(e) =>
                      onChange(e.target.checked ? [...value, f] : value.filter((x) => x !== f))
                    }
                  />
                  <Icon className="text-muted-foreground size-4" aria-hidden />
                  {FEATURE_LABELS[f]}
                </label>
              );
            })}
          </div>
          {value.length === 0 && (
            <p className="text-muted-foreground text-xs">
              With no sections they see My Work, Events and anything they sign off.
            </p>
          )}
        </div>
      )}
      {offWithItems.map((f) => (
        <p key={f} className="text-muted-foreground text-xs">
          {personName ?? "They"} own{personName ? "s" : ""} {owned![f]}{" "}
          {FEATURE_LABELS[f].toLowerCase()} item{owned![f] === 1 ? "" : "s"} — they&apos;ll still
          get updates about those.
        </p>
      ))}
    </fieldset>
  );
}

/** Why someone can't give an ability, or null when they can. */
export function abilityLockReason(
  key: AbilityKey,
  assignable: readonly AbilityKey[] | undefined,
): string | null {
  if (!assignable || assignable.includes(key)) return null;
  return ABILITIES[key].superAdminGrants
    ? "Only a super admin can give this"
    : "You don't have this yourself, so you can't give it";
}

/**
 * What they can do beyond their role, grouped as the registry groups them.
 * Each row says whether it is the role's default or changed from it; each
 * group says how many are changed and can go back to the role's defaults.
 * Partial defaults show what part (Sales: "Sponsorship report only").
 * Rows the viewer can't give are locked with the reason (they can still be
 * switched off, and back on to what was saved).
 */
export function AbilitiesFields({
  id,
  role,
  value,
  onChange,
  features,
  disabled,
  assignable,
  baseline,
  collapsible = true,
}: {
  id: string;
  role: StaffRole;
  /** Explicit choices; a key left out follows the role. */
  value: AbilityChoices;
  onChange: (value: AbilityChoices) => void;
  /** Sections they have (null = all): abilities in a switched-off section are hidden. */
  features: Feature[] | null;
  disabled?: boolean;
  /** Abilities the viewer may give (assignableAbilities); undefined = all. */
  assignable?: readonly AbilityKey[];
  /** What is saved for them now (rows locked for the viewer may go back to it). */
  baseline?: AbilityChoices;
  /** Add person folds it away; the person page shows it open. */
  collapsible?: boolean;
}) {
  const shown = EDITABLE_ABILITY_KEYS.filter((k) => {
    const f = ABILITIES[k].feature;
    return !(f && features !== null && !features.includes(f));
  });
  const changedKeys = shown.filter((k) => abilityChanged(role, value, k));
  const custom = changedKeys.length > 0;

  function set(key: AbilityKey, on: boolean) {
    const next = { ...value, [key]: on };
    // Back to the role's default: store nothing for it.
    if (!abilityChanged(role, next, key)) delete next[key];
    onChange(next);
  }

  function reset(keys: readonly AbilityKey[]) {
    const next = { ...value };
    for (const k of keys) delete next[k];
    onChange(next);
  }

  const body = (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-muted-foreground text-xs">
          These start from the {roleLabel(role)} role. Change one only when this person needs
          something different.
        </p>
        {custom && !disabled && (
          <button type="button" className="link text-xs" onClick={() => reset(shown)}>
            Back to {roleLabel(role)} defaults
          </button>
        )}
      </div>
      <div id={id} className="space-y-4">
        {abilityGroups(shown).map((g) => {
          const changedHere = g.keys.filter((k) => abilityChanged(role, value, k));
          const legendId = `${id}-${g.group}`;
          return (
            <fieldset
              key={g.group}
              className="space-y-1.5"
              disabled={disabled}
              aria-labelledby={legendId}
            >
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                <p id={legendId} className="text-sm font-medium">
                  {g.label}
                </p>
                {changedHere.length > 0 && (
                  <span className="text-muted-foreground text-xs">
                    {changedHere.length} changed
                  </span>
                )}
                {changedHere.length > 0 && !disabled && (
                  <button
                    type="button"
                    className="link text-xs"
                    onClick={() => reset(g.keys)}
                    aria-label={`${g.label}: back to ${roleLabel(role)} defaults`}
                  >
                    Back to defaults
                  </button>
                )}
              </div>
              <ul className="divide-y rounded-md border">
                {g.keys.map((k) => {
                  const def = ABILITIES[k];
                  const level = effectiveAbility(role, value, k);
                  const partial = def.partial?.[role];
                  const changed = abilityChanged(role, value, k);
                  const lock = abilityLockReason(k, assignable);
                  const savedLevel = effectiveAbility(role, baseline ?? {}, k);
                  const needs = def.requires?.find(
                    (r) => effectiveAbility(role, value, r) !== "yes",
                  );
                  // Turning on: only what the viewer can give, or back to what was saved.
                  const canTurnOn = !needs && (!lock || savedLevel === "yes");
                  const rowDisabled = disabled || (level !== "yes" && !canTurnOn);
                  const rowId = `${id}-${k}`;
                  return (
                    <li key={k} className="flex items-start gap-3 px-3 py-2">
                      <input
                        id={rowId}
                        type="checkbox"
                        className="accent-primary mt-0.5 size-4 shrink-0"
                        checked={level === "yes"}
                        ref={(el) => {
                          if (el) el.indeterminate = level === "partial";
                        }}
                        disabled={rowDisabled}
                        onChange={(e) => set(k, e.target.checked)}
                        aria-describedby={`${rowId}-note`}
                      />
                      <div className="min-w-0 flex-1">
                        <label htmlFor={rowId} className="block text-sm">
                          {def.label}
                        </label>
                        <p id={`${rowId}-note`} className="text-muted-foreground text-xs">
                          {def.description}{" "}
                          <span className={cn(changed && "text-foreground font-medium")}>
                            {changed ? "Changed from role default" : "Role default"}
                            {level === "partial" && partial ? ` · ${partial.label}` : ""}
                          </span>
                          {needs && level !== "yes"
                            ? ` · Needs “${ABILITIES[needs].label}”`
                            : lock && level !== "yes"
                              ? ` · ${lock}`
                              : ""}
                        </p>
                      </div>
                    </li>
                  );
                })}
              </ul>
            </fieldset>
          );
        })}
      </div>
    </div>
  );

  if (!collapsible) return body;
  return (
    <details className="group rounded-md border" open={custom || undefined}>
      <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-sm font-medium select-none [&::-webkit-details-marker]:hidden">
        <span>
          Fine-tune what they can do{" "}
          <span className="text-muted-foreground font-normal">
            {custom ? `(${changedKeys.length} changed from the role)` : "(optional)"}
          </span>
        </span>
        <ChevronDown
          className="text-muted-foreground size-4 shrink-0 transition-transform group-open:rotate-180"
          aria-hidden
        />
      </summary>
      <div className="border-t px-3 py-3">{body}</div>
    </details>
  );
}

/** The manager choices, with what each means. */
const MANAGER_CHOICES: { value: ManagerScope | null; label: string; text: string }[] = [
  {
    value: null,
    label: "Not a manager",
    text: "They can't add or change anyone else's access.",
  },
  {
    value: "department",
    label: "Their department",
    text: "They add people to their department and change, suspend or give an end date to people in it — giving only what they have themselves, never to super admins or other managers.",
  },
  {
    value: "everyone",
    label: "Everyone",
    text: "They add and change people in any department — giving only what they have themselves, never to super admins or other managers.",
  },
];

/** "Manager · Marketing", "Manager · everyone" or "Not a manager". */
export function managerSummary(scope: ManagerScope | null, departmentName: string | null) {
  if (!scope) return "Not a manager";
  return scope === "everyone"
    ? "Manager · everyone"
    : `Manager · ${departmentName ?? "their department"}`;
}

/**
 * Whether they manage people, and whom. Only super admins change it, and
 * never for a super admin (they manage everyone already).
 */
export function ManagerField({
  name,
  value,
  onChange,
  role,
  departmentName,
  editable,
  person,
}: {
  name: string;
  value: ManagerScope | null;
  onChange: (value: ManagerScope | null) => void;
  role: StaffRole | null;
  /** Their department (a department manager needs one). */
  departmentName: string | null;
  /** Super admins (canGrantManager). */
  editable: boolean;
  person: string;
}) {
  if (role === "admin") {
    return (
      <p className="text-muted-foreground text-sm">
        Super admins manage everyone, so they aren&apos;t made managers.
      </p>
    );
  }
  if (!editable) {
    const current = MANAGER_CHOICES.find((c) => c.value === value) ?? MANAGER_CHOICES[0];
    return (
      <div className="space-y-1 text-sm">
        <p className="font-medium">{managerSummary(value, departmentName)}</p>
        <p className="text-muted-foreground">{current.text}</p>
        <p className="text-muted-foreground text-xs">Only a super admin makes someone a manager.</p>
      </div>
    );
  }
  return (
    <fieldset className="space-y-2">
      <legend className="sr-only">Does {person} manage people?</legend>
      <div className="grid gap-2 sm:grid-cols-3">
        {MANAGER_CHOICES.map((c) => {
          const needsDept = c.value === "department" && !departmentName;
          const checked = value === c.value;
          return (
            <label
              key={c.label}
              className={cn(
                "flex min-h-11 cursor-pointer items-start gap-3 rounded-md border p-3 text-sm transition-colors",
                checked ? "border-primary bg-primary/5 ring-primary ring-1" : "hover:bg-muted/40",
                needsDept && "cursor-not-allowed opacity-60",
              )}
            >
              <input
                type="radio"
                name={name}
                checked={checked}
                disabled={needsDept}
                onChange={() => onChange(c.value)}
                className="accent-primary mt-0.5 size-4 shrink-0"
              />
              <span className="min-w-0">
                <span className="block font-medium">
                  {c.value === "department" && departmentName
                    ? `Their department (${departmentName})`
                    : c.label}
                </span>
                <span className="text-muted-foreground block text-xs">
                  {needsDept ? "Give them a department first." : c.text}
                </span>
              </span>
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}

/** A small department tag; archived departments say so. */
export function DepartmentChip({
  name,
  archived,
  main,
  pending,
  className,
}: {
  name: string;
  archived?: boolean;
  main?: boolean;
  /** Becomes main approver when they accept (an outlined star). */
  pending?: boolean;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "bg-muted text-foreground inline-flex max-w-full items-center gap-1 rounded-md px-1.5 py-0.5 text-xs",
        archived && "text-muted-foreground",
        className,
      )}
    >
      {main && (
        <Star
          className="size-3 fill-amber-400 text-amber-500"
          role="img"
          aria-label="Main approver"
        />
      )}
      {!main && pending && (
        <Star
          className="size-3 text-amber-500"
          role="img"
          aria-label="Main approver when they accept"
        />
      )}
      <span className="truncate">
        {name}
        {archived ? " (archived)" : ""}
      </span>
    </span>
  );
}
