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
        <option value="">No department</option>
        {live.map((d) => (
          <option key={d.id} value={d.id}>
            {d.name}
          </option>
        ))}
        {current && <option value={current.id}>{current.name} (archived)</option>}
        <option value={NEW_DEPARTMENT}>+ New department…</option>
      </SelectNative>
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
}) {
  const all = value === null;
  const offWithItems =
    value && owned
      ? visible.filter((f) => !value.includes(f) && (owned[f] ?? 0) > 0)
      : ([] as Feature[]);
  return (
    <fieldset className="space-y-2" disabled={disabled}>
      <legend className="text-sm font-medium">Sections they can use</legend>
      <label className="flex min-h-11 items-center gap-2 text-sm sm:min-h-0">
        <input
          type="checkbox"
          className="accent-primary size-4"
          checked={all}
          onChange={(e) => onChange(e.target.checked ? null : [])}
          aria-controls={`${id}-list`}
        />
        All sections
      </label>
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

export function AbilitiesFields({
  id,
  role,
  value,
  onChange,
  features,
  disabled,
  assignable,
}: {
  id: string;
  role: StaffRole;
  /** Explicit choices; a key left out follows the role. */
  value: AbilityChoices;
  onChange: (value: AbilityChoices) => void;
  /** Sections they have (null = all): abilities in a switched-off section are hidden. */
  features: Feature[] | null;
  disabled?: boolean;
  /** Abilities the viewer may give (assignableAbilities); others are hidden. */
  assignable?: readonly AbilityKey[];
}) {
  const shown = EDITABLE_ABILITY_KEYS.filter((k) => {
    const f = ABILITIES[k].feature;
    if (f && features !== null && !features.includes(f)) return false;
    return !assignable || assignable.includes(k);
  });
  const custom = EDITABLE_ABILITY_KEYS.some((k) => abilityChanged(role, value, k));
  return (
    <details className="group rounded-md border" open={custom || undefined}>
      <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-sm font-medium select-none [&::-webkit-details-marker]:hidden">
        <span>
          Fine-tune what they can do{" "}
          <span className="text-muted-foreground font-normal">
            {custom ? "(changed from the role)" : "(optional)"}
          </span>
        </span>
        <ChevronDown
          className="text-muted-foreground size-4 shrink-0 transition-transform group-open:rotate-180"
          aria-hidden
        />
      </summary>
      <div className="space-y-3 border-t px-3 py-3">
        <p className="text-muted-foreground text-xs">
          These start from the {roleLabel(role)} role. Change one only when this person needs
          something different.
        </p>
        <fieldset id={id} className="space-y-3" disabled={disabled}>
          <legend className="sr-only">What they can do</legend>
          {abilityGroups(shown).map((g) => (
            <div key={g.group} className="space-y-1">
              <p className="text-muted-foreground text-xs font-medium">{g.label}</p>
              <div className="grid gap-1 sm:grid-cols-2">
                {g.keys.map((k) => {
                  const level = effectiveAbility(role, value, k);
                  const partial = ABILITIES[k].partial?.[role];
                  return (
                    <label key={k} className="flex min-h-11 items-center gap-2 text-sm sm:min-h-8">
                      <input
                        type="checkbox"
                        className="accent-primary size-4"
                        checked={level === "yes"}
                        onChange={(e) => onChange({ ...value, [k]: e.target.checked })}
                      />
                      {ABILITIES[k].label}
                      {level === "partial" && partial && (
                        <span className="text-muted-foreground text-xs">({partial.label})</span>
                      )}
                      {abilityChanged(role, value, k) && (
                        <span className="text-muted-foreground text-xs">(changed)</span>
                      )}
                    </label>
                  );
                })}
              </div>
            </div>
          ))}
        </fieldset>
        {custom && !disabled && (
          <button type="button" className="link text-xs" onClick={() => onChange({})}>
            Back to {roleLabel(role)} defaults
          </button>
        )}
      </div>
    </details>
  );
}

/** A small department tag; archived departments say so. */
export function DepartmentChip({
  name,
  archived,
  main,
  className,
}: {
  name: string;
  archived?: boolean;
  main?: boolean;
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
      <span className="truncate">
        {name}
        {archived ? " (archived)" : ""}
      </span>
    </span>
  );
}
