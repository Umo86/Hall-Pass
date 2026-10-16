"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { PauseCircle, Star } from "lucide-react";
import { toast } from "sonner";
import type { AbilityKey, Feature, StaffRole } from "@/lib/authz";
import { roleLabel } from "@/lib/format";
import { defaultAbilities, firstName, type AbilityChoices, type Signoff } from "@/lib/users/rules";
import { updateInvitation, updateUser } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import {
  AbilitiesFields,
  DepartmentField,
  FieldError,
  NEW_DEPARTMENT,
  RoleCards,
  SectionsPicker,
  type DepartmentOption,
} from "./person-fields";

export type PersonFormState = {
  fullName: string;
  jobTitle: string;
  /** "" = none, NEW_DEPARTMENT, or a department id. */
  department: string;
  newDepartment: string;
  role: StaffRole;
  features: Feature[] | null;
  abilities: AbilityChoices;
  signoffs: Signoff[];
  paused: boolean;
};

type Errors = Partial<Record<"fullName" | "newDepartmentName" | "form", string>>;

function same(a: PersonFormState, b: PersonFormState) {
  const norm = (s: PersonFormState) =>
    JSON.stringify({
      ...s,
      fullName: s.fullName.trim(),
      jobTitle: s.jobTitle.trim(),
      features: s.features ? [...s.features].sort() : null,
      signoffs: [...s.signoffs].sort((x, y) => x.departmentId.localeCompare(y.departmentId)),
    });
  return norm(a) === norm(b);
}

/**
 * A person's page for admins: one form, saved with one "Save changes" bar.
 * Works for team members and for invitations not yet accepted.
 */
export function PersonEditor({
  kind,
  id,
  email,
  isSelf,
  isOnlyAdmin,
  initial,
  departments,
  visible,
  owned,
  access,
  readOnlyReason,
}: {
  kind: "member" | "invite";
  /** The user id (member) or invitation id. */
  id: string;
  email: string;
  isSelf: boolean;
  isOnlyAdmin: boolean;
  initial: PersonFormState;
  departments: DepartmentOption[];
  visible: Feature[];
  owned: Partial<Record<Feature, number>>;
  /** What the viewer may give (managers); omitted for super admins. */
  access?: { roles: StaffRole[]; abilities: AbilityKey[] };
  /** Set when the viewer can see but not change this person's access. */
  readOnlyReason?: string | null;
}) {
  const [baseline, setBaseline] = useState(initial);
  const [form, setForm] = useState(initial);
  const [moved, setMoved] = useState<{ from: string; to: string; before: Signoff[] } | null>(null);
  const [errors, setErrors] = useState<Errors>({});
  const [pending, start] = useTransition();
  const router = useRouter();
  const dirty = !same(form, baseline);
  const name = firstName(form.fullName, email);
  const set = <K extends keyof PersonFormState>(key: K, value: PersonFormState[K]) =>
    setForm((f) => ({ ...f, [key]: value }));
  const deptById = useMemo(() => new Map(departments.map((d) => [d.id, d])), [departments]);
  const signsFor = new Map(form.signoffs.map((s) => [s.departmentId, s.isMain]));

  function pickDepartment(value: string) {
    // Work from the sign-offs as they were before any earlier move.
    const before = moved ? moved.before : form.signoffs;
    const from = moved ? moved.from : form.department;
    const wasMain = before.find((s) => s.departmentId === from)?.isMain;
    const to = deptById.get(value);
    // Signing off for the old department? Offer to move it to the new one.
    if (
      from &&
      from !== NEW_DEPARTMENT &&
      wasMain !== undefined &&
      to &&
      to.id !== from &&
      to.signsOff &&
      !to.isArchived
    ) {
      const rest = before.filter((s) => s.departmentId !== from && s.departmentId !== to.id);
      // The move keeps what they were: a main approver stays a main approver.
      setForm((f) => ({
        ...f,
        department: value,
        signoffs: [...rest, { departmentId: to.id, isMain: wasMain }],
      }));
      setMoved({ from, to: to.id, before });
      return;
    }
    setForm((f) => ({ ...f, department: value, signoffs: before }));
    setMoved(null);
  }

  function toggleMove(on: boolean) {
    if (!moved) return;
    const wasMain = moved.before.find((s) => s.departmentId === moved.from)?.isMain ?? false;
    setForm((f) => ({
      ...f,
      signoffs: on
        ? [
            ...moved.before.filter(
              (s) => s.departmentId !== moved.from && s.departmentId !== moved.to,
            ),
            { departmentId: moved.to, isMain: wasMain },
          ]
        : moved.before,
    }));
  }
  const moveOn = moved ? signsFor.has(moved.to) && !signsFor.has(moved.from) : false;

  function pickRole(role: StaffRole) {
    setForm((f) => ({ ...f, role, abilities: defaultAbilities(role) }));
  }

  function toggleSignoff(departmentId: string, on: boolean) {
    const d = deptById.get(departmentId);
    setForm((f) => ({
      ...f,
      signoffs: on
        ? [...f.signoffs, { departmentId, isMain: d?.mainApprover === null }]
        : f.signoffs.filter((s) => s.departmentId !== departmentId),
    }));
  }

  function toggleMain(departmentId: string) {
    setForm((f) => ({
      ...f,
      signoffs: f.signoffs.map((s) =>
        s.departmentId === departmentId ? { ...s, isMain: !s.isMain } : s,
      ),
    }));
  }

  function discard() {
    setForm(baseline);
    setMoved(null);
    setErrors({});
  }

  function save() {
    const next: Errors = {};
    if (!form.fullName.trim()) next.fullName = "Enter their name";
    if (form.department === NEW_DEPARTMENT && !form.newDepartment.trim()) {
      next.newDepartmentName = "Name the new department";
    }
    setErrors(next);
    if (Object.keys(next).length > 0) return;
    const allVisible = form.features !== null && visible.every((f) => form.features!.includes(f));
    const payload = {
      fullName: form.fullName,
      jobTitle: form.jobTitle || null,
      departmentId: form.department && form.department !== NEW_DEPARTMENT ? form.department : null,
      newDepartmentName: form.department === NEW_DEPARTMENT ? form.newDepartment : null,
      role: form.role,
      features: allVisible ? null : form.features,
      abilities: form.abilities,
      signoffs: form.signoffs,
    };
    start(async () => {
      const res =
        kind === "member"
          ? await updateUser({ ...payload, userId: id, signoffPaused: form.paused })
          : await updateInvitation({ ...payload, inviteId: id });
      if (!res.ok) {
        setErrors({
          fullName: res.fieldErrors?.fullName,
          newDepartmentName: res.fieldErrors?.newDepartmentName,
          form: res.error,
        });
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? "Saved");
      const saved = { ...form, newDepartment: "" };
      setBaseline(saved);
      setForm(saved);
      setMoved(null);
      router.refresh();
    });
  }

  const ownDept = form.department && deptById.get(form.department);
  const signing = departments.filter((d) => (d.signsOff && !d.isArchived) || signsFor.has(d.id));
  const others = signing.filter((d) => d.id !== form.department);
  const ownSigning = ownDept && signing.find((d) => d.id === ownDept.id);
  const roleChanged = form.role !== baseline.role;

  return (
    <div className="space-y-4">
      <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-labelledby="details-h">
        <h2 id="details-h" className="text-sm font-semibold">
          Details
        </h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="p-name">Name</Label>
            <Input
              id="p-name"
              value={form.fullName}
              onChange={(e) => set("fullName", e.target.value)}
              maxLength={200}
              aria-invalid={Boolean(errors.fullName)}
              className="h-11 sm:h-9"
            />
            <FieldError message={errors.fullName} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="p-title">
              Job title <span className="text-muted-foreground font-normal">(optional)</span>
            </Label>
            <Input
              id="p-title"
              value={form.jobTitle}
              onChange={(e) => set("jobTitle", e.target.value)}
              maxLength={200}
              className="h-11 sm:h-9"
            />
          </div>
          <div className="space-y-2">
            <DepartmentField
              id="p-department"
              departments={departments}
              value={form.department}
              onChange={pickDepartment}
              newName={form.newDepartment}
              onNewName={(v) => set("newDepartment", v)}
              error={errors.newDepartmentName}
            />
            {moved && (
              <label className="flex min-h-11 items-center gap-2 text-sm sm:min-h-0">
                <input
                  type="checkbox"
                  className="accent-primary size-4"
                  checked={moveOn}
                  onChange={(e) => toggleMove(e.target.checked)}
                />
                Move their sign-off to {deptById.get(moved.to)?.name} too
              </label>
            )}
          </div>
        </div>
        <RoleCards
          name="p-role"
          value={form.role}
          onChange={pickRole}
          lockedReason={
            readOnlyReason ??
            (isSelf ? "You can't change your own access — ask another super admin." : null)
          }
          onlyAdmin={isOnlyAdmin && !isSelf}
          allowed={access?.roles}
        />
        {roleChanged && form.role !== "admin" && (
          <p className="text-muted-foreground rounded-md bg-muted/50 px-3 py-2 text-sm">
            What they can do goes back to {roleLabel(form.role)} defaults.
          </p>
        )}
      </section>

      {form.role !== "admin" ? (
        <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-label="Sections">
          <SectionsPicker
            id="p-sections"
            value={form.features}
            onChange={(v) => set("features", v)}
            visible={visible}
            disabled={isSelf || Boolean(readOnlyReason)}
            owned={kind === "member" ? owned : undefined}
            personName={name}
          />
          <AbilitiesFields
            id="p-abilities"
            role={form.role}
            value={form.abilities}
            onChange={(v) => set("abilities", v)}
            features={form.features}
            disabled={isSelf || Boolean(readOnlyReason)}
            assignable={access?.abilities}
          />
        </section>
      ) : (
        <p className="text-muted-foreground rounded-lg border p-4 text-sm">
          Super admins use every section and can change anything, including people, managers and
          system settings.
        </p>
      )}

      <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="signoff-h">
        <div className="flex flex-wrap items-center gap-2">
          <h2 id="signoff-h" className="text-sm font-semibold">
            Signs off artwork for
          </h2>
          {form.paused && (
            <span className="inline-flex items-center gap-1 rounded-md bg-amber-50 px-2 py-0.5 text-xs font-medium text-amber-900 dark:bg-amber-950 dark:text-amber-200">
              <PauseCircle className="size-3.5" aria-hidden /> Sign-off paused
            </span>
          )}
        </div>
        {form.paused && (
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <p className="text-muted-foreground">
              {name} can&apos;t sign anything until their sign-off is resumed.
            </p>
            <Button
              type="button"
              size="sm"
              variant="outline"
              className="h-11 sm:h-8"
              onClick={() => set("paused", false)}
            >
              Resume
            </Button>
          </div>
        )}
        {signing.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            No department signs off artwork yet. Switch sign-off on for one in Departments.
          </p>
        ) : (
          <>
            {ownDept && !ownSigning && (
              <p className="text-muted-foreground text-sm">
                {ownDept.name} doesn&apos;t sign off artwork.
              </p>
            )}
            <ul className="space-y-1">
              {ownSigning && (
                <SignoffRow
                  dept={ownSigning}
                  label={`${ownSigning.name} (their department)`}
                  checked={signsFor.has(ownSigning.id)}
                  isMain={signsFor.get(ownSigning.id) ?? false}
                  onToggle={(on) => toggleSignoff(ownSigning.id, on)}
                  onMain={() => toggleMain(ownSigning.id)}
                  person={name}
                />
              )}
            </ul>
            {others.length > 0 && (
              <details
                className="rounded-md border"
                open={others.some((d) => signsFor.has(d.id)) || !ownSigning || undefined}
              >
                <summary className="min-h-11 cursor-pointer px-3 py-2.5 text-sm select-none">
                  {ownSigning ? "Also signs off for…" : "Signs off for…"}
                </summary>
                <ul className="space-y-1 border-t px-1 py-1">
                  {others.map((d) => (
                    <SignoffRow
                      key={d.id}
                      dept={d}
                      label={`${d.name}${d.isArchived ? " (archived)" : !d.signsOff ? " (no sign-off)" : ""}`}
                      checked={signsFor.has(d.id)}
                      isMain={signsFor.get(d.id) ?? false}
                      onToggle={(on) => toggleSignoff(d.id, on)}
                      onMain={() => toggleMain(d.id)}
                      person={name}
                    />
                  ))}
                </ul>
              </details>
            )}
          </>
        )}
      </section>

      {dirty && (
        <div
          className="bg-background/95 supports-[backdrop-filter]:bg-background/80 sticky bottom-0 z-20 -mx-4 flex flex-wrap items-center gap-2 border-t px-4 py-3 backdrop-blur sm:mx-0 sm:rounded-lg sm:border"
          role="region"
          aria-label="Unsaved changes"
        >
          <p className="text-muted-foreground min-w-0 flex-1 text-sm">You have unsaved changes.</p>
          {errors.form && <span className="sr-only">{errors.form}</span>}
          <Button type="button" variant="outline" className="h-11 sm:h-9" onClick={discard}>
            Discard
          </Button>
          <Button type="button" className="h-11 sm:h-9" disabled={pending} onClick={save}>
            {pending ? "Saving…" : "Save changes"}
          </Button>
        </div>
      )}
    </div>
  );
}

function SignoffRow({
  dept,
  label,
  checked,
  isMain,
  onToggle,
  onMain,
  person,
}: {
  dept: DepartmentOption;
  label: string;
  checked: boolean;
  isMain: boolean;
  onToggle: (on: boolean) => void;
  onMain: () => void;
  person: string;
}) {
  const other = dept.mainApprover && !dept.mainIsThisPerson ? dept.mainApprover : null;
  return (
    <li className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md px-2 py-1">
      <label className="flex min-h-11 flex-1 items-center gap-2 text-sm sm:min-h-8">
        <input
          type="checkbox"
          className="accent-primary size-4"
          checked={checked}
          onChange={(e) => onToggle(e.target.checked)}
        />
        {label}
      </label>
      {checked && (
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className={cn("h-11 sm:h-8", isMain && "text-amber-700 dark:text-amber-300")}
          aria-pressed={isMain}
          aria-label={
            isMain
              ? `${person} is the main approver for ${dept.name} — stop`
              : `Make ${person} the main approver for ${dept.name}`
          }
          onClick={onMain}
        >
          <Star className={cn("size-4", isMain && "fill-amber-400 text-amber-500")} aria-hidden />
          {isMain ? "Main approver" : "Make main"}
        </Button>
      )}
      {checked && isMain && other && (
        <p className="text-muted-foreground w-full pl-8 text-xs">
          Replaces {other} as main approver.
        </p>
      )}
    </li>
  );
}
