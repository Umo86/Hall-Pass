"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, PauseCircle, Star } from "lucide-react";
import { toast } from "sonner";
import type { AbilityKey, Feature, ManagerScope, StaffRole } from "@/lib/authz";
import { roleLabel } from "@/lib/format";
import {
  firstName,
  mainApproverNote,
  overridesFor,
  startingChoices,
  type AbilityChoices,
  type Signoff,
} from "@/lib/users/rules";
import {
  canStillSign,
  ITEM_KIND_LABEL,
  itemsLostByChange,
  type ItemKind,
  type WorkAccess,
} from "@/lib/users/handover";
import { updateInvitation, updateUser } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import {
  AbilitiesFields,
  DepartmentField,
  FieldError,
  ManagerField,
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
  managerScope: ManagerScope | null;
};

/** What the viewer may change (computed on the server; checked again there). */
export type EditorAccess = {
  /** Roles they may give; undefined = all (super admins). */
  roles?: StaffRole[];
  /** Abilities they may give; undefined = all. */
  abilities?: AbilityKey[];
  /** "All sections" may be given. */
  allSections: boolean;
  canGrantManager: boolean;
  canNewDepartment: boolean;
  /** Departments they may add or take away sign-off for. */
  signoffDepartments: string[];
  canChooseMain: boolean;
  /** A department manager: the person stays in their department. */
  keepDepartment: boolean;
};

/** Work they have now: items they own and sign-offs naming them. */
export type PersonWork = {
  items: { ref: string; kind: ItemKind; href: string }[];
  signoffs: { ref: string; href: string | null; departmentId: string | null }[];
};

type Errors = Partial<Record<"fullName" | "newDepartmentName" | "form", string>>;

function same(a: PersonFormState, b: PersonFormState) {
  const norm = (s: PersonFormState) =>
    JSON.stringify({
      ...s,
      fullName: s.fullName.trim(),
      jobTitle: s.jobTitle.trim(),
      features: s.features ? [...s.features].sort() : null,
      abilities: Object.fromEntries(
        Object.entries(s.abilities).sort(([x], [y]) => x.localeCompare(y)),
      ),
      signoffs: [...s.signoffs].sort((x, y) => x.departmentId.localeCompare(y.departmentId)),
    });
  return norm(a) === norm(b);
}

function access(s: PersonFormState): WorkAccess {
  return {
    role: s.role,
    features: s.features,
    overrides: overridesFor(s.role, s.abilities, { signoffPaused: s.paused }),
  };
}

function RefList({ refs }: { refs: { ref: string; href: string | null }[] }) {
  return (
    <>
      {refs.slice(0, 5).map((r, i) => (
        <span key={`${r.ref}-${i}`}>
          {i > 0 && ", "}
          {r.href ? (
            <Link href={r.href} className="link">
              {r.ref}
            </Link>
          ) : (
            r.ref
          )}
        </span>
      ))}
      {refs.length > 5 ? ` and ${refs.length - 5} more` : ""}
    </>
  );
}

function kindsText(items: { kind: ItemKind }[]): string {
  const counts = new Map<ItemKind, number>();
  for (const i of items) counts.set(i.kind, (counts.get(i.kind) ?? 0) + 1);
  return [...counts]
    .map(([k, n]) => `${n} ${n === 1 ? ITEM_KIND_LABEL[k].one : ITEM_KIND_LABEL[k].many}`)
    .join(" and ");
}

/**
 * A person's page for super admins and their managers: details, role,
 * manager, sections, abilities and sign-off in one form, saved with one
 * "Save changes" bar. Works for team members and for invitations not yet
 * accepted. Before saving it warns when the change leaves work they own or
 * sign-offs naming them that they could no longer do.
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
  access: can,
  readOnlyReason,
  work,
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
  access: EditorAccess;
  /** Set when the viewer can see but not change this person's access (why). */
  readOnlyReason?: string | null;
  work: PersonWork;
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
  const locked = isSelf ? "You can't change your own access — ask another super admin." : null;
  const accessLocked = readOnlyReason ?? locked;
  const viewer = form.role === "viewer";
  const canSign = (deptId: string) => can.signoffDepartments.includes(deptId);

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
      !to.isArchived &&
      canSign(to.id) &&
      canSign(from)
    ) {
      const rest = before.filter((s) => s.departmentId !== from && s.departmentId !== to.id);
      // The move keeps what they were: a main approver stays a main approver.
      setForm((f) => ({
        ...f,
        department: value,
        signoffs: [...rest, { departmentId: to.id, isMain: wasMain && can.canChooseMain }],
      }));
      setMoved({ from, to: to.id, before });
      return;
    }
    setForm((f) => ({
      ...f,
      department: value,
      signoffs: before,
      managerScope: !value && f.managerScope === "department" ? null : f.managerScope,
    }));
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
            { departmentId: moved.to, isMain: wasMain && can.canChooseMain },
          ]
        : moved.before,
    }));
  }
  const moveOn = moved ? signsFor.has(moved.to) && !signsFor.has(moved.from) : false;

  function pickRole(role: StaffRole) {
    setForm((f) => ({
      ...f,
      role,
      // Back to the role's defaults (with what only a super admin gives off for managers).
      abilities: startingChoices(role, {}, { superAdmin: can.abilities === undefined }),
      managerScope: role === "admin" ? null : f.managerScope,
    }));
  }

  function toggleSignoff(departmentId: string, on: boolean) {
    const d = deptById.get(departmentId);
    setForm((f) => ({
      ...f,
      signoffs: on
        ? [
            ...f.signoffs,
            {
              departmentId,
              isMain:
                can.canChooseMain &&
                (d?.mainApprover === null ||
                  d?.mainIsThisPerson === true ||
                  d?.pendingIsThisPerson === true),
            },
          ]
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
      // Every section ticked is "all sections" — for someone who may give that.
      features: form.role === "admin" || (allVisible && can.allSections) ? null : form.features,
      abilities: form.role === "admin" ? {} : form.abilities,
      // Viewers never sign off: saving takes them off every department's approvers.
      signoffs: viewer ? [] : form.signoffs,
      ...(can.canGrantManager && !isSelf ? { managerScope: form.managerScope } : {}),
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
      const saved = { ...form, newDepartment: "", signoffs: viewer ? [] : form.signoffs };
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
  const deptName =
    form.department === NEW_DEPARTMENT
      ? form.newDepartment.trim() || null
      : ownDept
        ? ownDept.name
        : null;

  // What this change would stop them doing (P0.6): items they own, and sign-offs naming them.
  const lostItems =
    kind === "member" ? itemsLostByChange(work.items, access(baseline), access(form)) : [];
  const stopsSigning = canStillSign(access(baseline)) && !canStillSign(access(form));
  const dropped = new Set(
    baseline.signoffs
      .filter((s) => viewer || !form.signoffs.some((f) => f.departmentId === s.departmentId))
      .map((s) => s.departmentId),
  );
  const lostSignoffs =
    kind === "member"
      ? work.signoffs.filter(
          (w) => stopsSigning || (w.departmentId != null && dropped.has(w.departmentId)),
        )
      : [];

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
              disabled={can.keepDepartment || Boolean(readOnlyReason)}
              allowNew={can.canNewDepartment}
              allowNone={!can.keepDepartment}
              hint={
                can.keepDepartment
                  ? "You manage your own department only, so they stay in it."
                  : null
              }
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
      </section>

      <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="role-h">
        <h2 id="role-h" className="sr-only">
          Role
        </h2>
        <RoleCards
          name="p-role"
          value={form.role}
          onChange={pickRole}
          lockedReason={accessLocked}
          onlyAdmin={isOnlyAdmin && !isSelf}
          allowed={can.roles}
        />
        {roleChanged && form.role !== "admin" && (
          <p className="text-muted-foreground bg-muted/50 rounded-md px-3 py-2 text-sm">
            What they can do goes back to {roleLabel(form.role)} defaults.
          </p>
        )}
      </section>

      <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="manager-h">
        <h2 id="manager-h" className="text-sm font-semibold">
          Manager
        </h2>
        <ManagerField
          name="p-manager"
          value={form.managerScope}
          onChange={(v) => set("managerScope", v)}
          role={form.role}
          departmentName={deptName}
          editable={can.canGrantManager && !isSelf}
          person={name}
        />
      </section>

      {form.role !== "admin" ? (
        <>
          <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-labelledby="sections-h">
            <h2 id="sections-h" className="sr-only">
              Sections
            </h2>
            <SectionsPicker
              id="p-sections"
              value={form.features}
              onChange={(v) => set("features", v)}
              visible={visible}
              disabled={Boolean(accessLocked)}
              owned={kind === "member" ? owned : undefined}
              personName={name}
              allowAll={can.allSections}
            />
          </section>
          <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="abilities-h">
            <h2 id="abilities-h" className="text-sm font-semibold">
              Abilities
            </h2>
            <AbilitiesFields
              id="p-abilities"
              role={form.role}
              value={form.abilities}
              onChange={(v) => set("abilities", v)}
              features={form.features}
              disabled={Boolean(accessLocked)}
              assignable={can.abilities}
              baseline={baseline.role === form.role ? baseline.abilities : {}}
              collapsible={false}
            />
            {accessLocked && <p className="text-muted-foreground text-sm">{accessLocked}</p>}
          </section>
        </>
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
        {viewer ? (
          <p className="text-muted-foreground text-sm">
            Viewers can&apos;t sign off artwork.
            {baseline.signoffs.length > 0 &&
              ` Saving takes ${name} off the approvers of ${baseline.signoffs
                .map((s) => deptById.get(s.departmentId)?.name)
                .filter(Boolean)
                .join(", ")}.`}
          </p>
        ) : (
          <>
            {kind === "member" && !readOnlyReason && (form.paused || form.signoffs.length > 0) && (
              <div className="flex flex-wrap items-center gap-2 text-sm">
                <p className="text-muted-foreground">
                  {form.paused
                    ? `${name} can't sign anything until their sign-off is resumed.`
                    : `Pause it to stop ${name} being asked for a while.`}
                </p>
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  className="h-11 sm:h-8"
                  onClick={() => set("paused", !form.paused)}
                >
                  {form.paused ? "Resume" : "Pause sign-off"}
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
                      editable={canSign(ownSigning.id) && !readOnlyReason}
                      canMain={can.canChooseMain && !readOnlyReason}
                      invited={kind === "invite"}
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
                          editable={canSign(d.id) && !readOnlyReason}
                          canMain={can.canChooseMain && !readOnlyReason}
                          invited={kind === "invite"}
                        />
                      ))}
                    </ul>
                  </details>
                )}
                {!can.canChooseMain && (
                  <p className="text-muted-foreground text-xs">
                    You can change sign-off for the departments you sign off for yourself; the main
                    approver is chosen by whoever manages departments.
                  </p>
                )}
              </>
            )}
          </>
        )}
      </section>

      {dirty && (lostItems.length > 0 || lostSignoffs.length > 0) && (
        <section
          role="note"
          aria-label="What this change leaves behind"
          className="space-y-2 rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200"
        >
          <p className="flex items-center gap-2 font-medium">
            <AlertTriangle className="size-4 shrink-0" aria-hidden />
            Before you save
          </p>
          {lostItems.length > 0 && (
            <p>
              {name} will no longer be able to work on {kindsText(lostItems)} they own:{" "}
              <RefList refs={lostItems} />. Open each to give it to someone who can, or {name} keeps
              getting updates about them.
            </p>
          )}
          {lostSignoffs.length > 0 && (
            <p>
              {lostSignoffs.length === 1
                ? "A sign-off names"
                : `${lostSignoffs.length} sign-offs name`}{" "}
              {name} that they won&apos;t be able to decide: <RefList refs={lostSignoffs} />. When
              you save, those for departments where someone else can sign go back to the department;
              any others stay with {name} to hand on from the item.
            </p>
          )}
        </section>
      )}

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
  editable,
  canMain,
  invited,
}: {
  dept: DepartmentOption;
  label: string;
  checked: boolean;
  isMain: boolean;
  onToggle: (on: boolean) => void;
  onMain: () => void;
  person: string;
  /** The viewer may add or take away sign-off for this department. */
  editable: boolean;
  /** The viewer may choose the main approver (departments.manage). */
  canMain: boolean;
  /** An invitation: they take over from a main approver who can sign when they accept. */
  invited: boolean;
}) {
  const other = dept.mainApprover && !dept.mainIsThisPerson ? dept.mainApprover : null;
  // Main "when they accept": already asked, or an invitee chosen while the main can sign.
  const onAccept =
    invited && (dept.pendingIsThisPerson === true || (Boolean(other) && dept.mainCanSign === true));
  const offNow = dept.isArchived || !dept.signsOff;
  const note =
    invited && offNow
      ? `Only if ${dept.name} signs off artwork when they accept.`
      : mainApproverNote({
          person,
          department: dept.name,
          invited,
          current: other ? { name: firstName(other), canSign: Boolean(dept.mainCanSign) } : null,
          pending: dept.pendingMain ? firstName(dept.pendingMain) : null,
        });
  return (
    <li className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md px-2 py-1">
      <label className="flex min-h-11 flex-1 items-center gap-2 text-sm sm:min-h-8">
        <input
          type="checkbox"
          className="accent-primary size-4"
          checked={checked}
          disabled={!editable}
          onChange={(e) => onToggle(e.target.checked)}
        />
        {label}
      </label>
      {checked && canMain && (
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className={cn("h-11 sm:h-8", isMain && "text-amber-700 dark:text-amber-300")}
          aria-pressed={isMain}
          aria-label={
            onAccept
              ? isMain
                ? `${person} becomes the main approver for ${dept.name} when they accept — cancel`
                : `Make ${person} the main approver for ${dept.name} when they accept`
              : isMain
                ? `${person} is the main approver for ${dept.name} — stop`
                : `Make ${person} the main approver for ${dept.name}`
          }
          onClick={onMain}
        >
          <Star
            className={cn(
              "size-4",
              isMain && (onAccept ? "text-amber-500" : "fill-amber-400 text-amber-500"),
            )}
            aria-hidden
          />
          {isMain ? (onAccept ? "Main when they accept" : "Main approver") : "Make main"}
        </Button>
      )}
      {checked && !canMain && isMain && (
        <span className="inline-flex items-center gap-1 text-xs text-amber-700 dark:text-amber-300">
          <Star
            className={cn("size-3.5 text-amber-500", !dept.pendingIsThisPerson && "fill-amber-400")}
            aria-hidden
          />
          {invited && dept.pendingIsThisPerson ? "Main approver when they accept" : "Main approver"}
        </span>
      )}
      {checked && isMain && (other || dept.pendingMain || (invited && offNow)) && (
        <p className="text-muted-foreground w-full pl-8 text-xs">{note}</p>
      )}
    </li>
  );
}
