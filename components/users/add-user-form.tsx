"use client";

import Link from "next/link";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CalendarClock, CheckCircle2 } from "lucide-react";
import { toast } from "sonner";
import type { AbilityKey, Feature, ManagerScope, StaffRole } from "@/lib/authz";
import {
  firstName,
  roleForDepartment,
  startingChoices,
  type AbilityChoices,
} from "@/lib/users/rules";
import type { PersonTemplate, PersonTemplateId } from "@/lib/users/templates";
import { inviteUser, type InviteUserResult } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { CopyField } from "@/components/copy-field";
import { absoluteLink } from "./invite-actions";
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
import { TemplatePicker } from "./template-picker";

type Errors = Partial<
  Record<"fullName" | "email" | "role" | "newDepartmentName" | "accessEndsOn" | "form", string>
>;

/** What the person adding may give (computed on the server; checked again there). */
export type AddAccess = {
  /** Roles they may give; undefined = all (super admins). */
  roles?: StaffRole[];
  /** Abilities they may give; undefined = all. */
  abilities?: AbilityKey[];
  /** They may give "All sections" (otherwise only the sections in `visible`). */
  allSections: boolean;
  /** Super admins make managers. */
  canGrantManager: boolean;
  /** "+ New department…" (departments.manage). */
  canNewDepartment: boolean;
  /** Departments they may make someone sign off for. */
  signoffDepartments: string[];
  /** Main approver choice (departments.manage). */
  canChooseMain: boolean;
  /** A department manager adds people to this department only. */
  lockedDepartment: { id: string; name: string } | null;
};

/** Today in the browser (YYYY-MM-DD), the earliest end date allowed. */
export function localToday(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** The template's sections, as offered here (null = every section). */
export function templateFeatures(t: PersonTemplate, visible: Feature[]): Feature[] | null {
  if (t.features === null) return null;
  return t.features.filter((f) => visible.includes(f));
}

/** Users → Add one person: one column, everything optional except name, email and role. */
export function AddUserForm({
  departments,
  visible,
  initial,
  access,
  templates,
}: {
  departments: DepartmentOption[];
  visible: Feature[];
  initial: { departmentId: string; signsOff: boolean; fullName: string; email: string };
  access: AddAccess;
  templates: PersonTemplate[];
}) {
  const locked = access.lockedDepartment;
  const startDept = departments.find(
    (d) => d.id === (locked?.id ?? initial.departmentId) && !d.isArchived,
  );
  const [templateId, setTemplateId] = useState<PersonTemplateId>("blank");
  const [fullName, setFullName] = useState(initial.fullName);
  const [email, setEmail] = useState(initial.email);
  const [jobTitle, setJobTitle] = useState("");
  const [dept, setDept] = useState(startDept?.id ?? "");
  const [newDept, setNewDept] = useState("");
  const suggested = roleForDepartment(startDept?.name);
  const role0 = suggested && (!access.roles || access.roles.includes(suggested)) ? suggested : null;
  const [role, setRole] = useState<StaffRole | null>(role0);
  const [roleTouched, setRoleTouched] = useState(false);
  const [features, setFeatures] = useState<Feature[] | null>(
    access.allSections ? null : [...visible],
  );
  const [abilities, setAbilities] = useState<AbilityChoices>(() =>
    role0 ? startingChoices(role0, {}, { superAdmin: access.abilities === undefined }) : {},
  );
  const [signsOff, setSignsOff] = useState(initial.signsOff && Boolean(startDept?.signsOff));
  const [isMain, setIsMain] = useState(
    startDept ? startDept.mainApprover === null || !startDept.mainCanSign : false,
  );
  const [manager, setManager] = useState<ManagerScope | null>(null);
  const [accessEnd, setAccessEnd] = useState("");
  const [endPrompt, setEndPrompt] = useState(false);
  const [errors, setErrors] = useState<Errors>({});
  const [existing, setExisting] = useState<{ href: string } | null>(null);
  const [done, setDone] = useState<(InviteUserResult & { note?: string }) | null>(null);
  const [pending, start] = useTransition();
  const endRef = useRef<HTMLInputElement>(null);
  const router = useRouter();

  const chosen = useMemo(() => departments.find((d) => d.id === dept) ?? null, [departments, dept]);
  const canSignHere =
    chosen?.signsOff && !chosen.isArchived && access.signoffDepartments.includes(chosen.id);
  const viewer = role === "viewer";
  const mainKept = Boolean(chosen?.mainApprover && chosen.mainCanSign);

  function pickDepartment(value: string) {
    setDept(value);
    const d = departments.find((x) => x.id === value);
    if (!roleTouched && templateId === "blank" && d) {
      const s = roleForDepartment(d.name);
      if (s && (!access.roles || access.roles.includes(s))) {
        setRole(s);
        setAbilities(startingChoices(s, {}, { superAdmin: access.abilities === undefined }));
      }
    }
    setIsMain(d ? d.mainApprover === null || !d.mainCanSign : false);
    if (!d?.signsOff) setSignsOff(false);
    if (!value || value === NEW_DEPARTMENT) setManager((m) => (m === "department" ? null : m));
  }

  const superAdmin = access.abilities === undefined;

  function pickRole(next: StaffRole) {
    setRole(next);
    setRoleTouched(true);
    setAbilities(startingChoices(next, {}, { superAdmin }));
    if (next === "admin") setManager(null);
    if (next === "viewer") setSignsOff(false);
    setErrors((e) => ({ ...e, role: undefined }));
  }

  function pickTemplate(t: PersonTemplate) {
    setTemplateId(t.id);
    if (!t.role) return;
    setRole(t.role);
    setRoleTouched(true);
    const tf = templateFeatures(t, visible);
    setFeatures(tf === null && !access.allSections ? [...visible] : tf);
    setAbilities({ ...t.abilities });
    if (t.role === "viewer") setSignsOff(false);
    if (t.jobTitle && (!jobTitle || templates.some((x) => x.jobTitle === jobTitle))) {
      setJobTitle(t.jobTitle);
    }
    setEndPrompt(t.suggestEndDate);
    if (t.suggestEndDate) setTimeout(() => endRef.current?.focus(), 0);
  }

  /** Ready for the next person: same department, role and sections, new details. */
  function reset() {
    setDone(null);
    setFullName("");
    setEmail("");
    // The person just added may now be the main approver.
    setIsMain(false);
    setErrors({});
    setExisting(null);
    router.refresh();
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const next: Errors = {};
    if (!fullName.trim()) next.fullName = "Enter their name";
    if (!email.trim()) next.email = "Enter their email address";
    if (!role) next.role = "Choose a role";
    if (dept === NEW_DEPARTMENT && !newDept.trim()) {
      next.newDepartmentName = "Name the new department";
    }
    if (accessEnd && accessEnd < localToday()) {
      next.accessEndsOn = "Choose today or a later date for access to end";
    }
    setErrors(next);
    setExisting(null);
    if (Object.keys(next).length > 0 || !role) return;
    const allVisible = features !== null && visible.every((f) => features.includes(f));
    start(async () => {
      const res = await inviteUser({
        fullName,
        email,
        jobTitle: jobTitle || null,
        departmentId: dept && dept !== NEW_DEPARTMENT ? dept : null,
        newDepartmentName: dept === NEW_DEPARTMENT ? newDept : null,
        role,
        features: role === "admin" || (allVisible && access.allSections) ? null : features,
        abilities: role === "admin" ? {} : abilities,
        signoffs:
          signsOff && canSignHere && !viewer && chosen
            ? [{ departmentId: chosen.id, isMain: access.canChooseMain && isMain && !mainKept }]
            : [],
        ...(access.canGrantManager && role !== "admin" ? { managerScope: manager } : {}),
        accessEndsOn: accessEnd || null,
      });
      if (res.ok) {
        toast.success(res.message ?? "Invitation sent");
        setDone(res.data!);
        router.refresh();
        return;
      }
      const fe = res.fieldErrors ?? {};
      if (fe.existingUserId || fe.existingInviteId) {
        setExisting({ href: `/users/${fe.existingUserId ?? fe.existingInviteId}` });
        setErrors({ email: res.error });
        return;
      }
      setErrors({
        fullName: fe.fullName,
        email: fe.email,
        role: fe.role,
        newDepartmentName: fe.newDepartmentName,
        accessEndsOn: fe.accessEndsOn,
        form:
          fe.fullName || fe.email || fe.role || fe.newDepartmentName || fe.accessEndsOn
            ? undefined
            : res.error,
      });
      if (!fe.fullName && !fe.email) toast.error(res.error);
    });
  }

  if (done) {
    return (
      <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-live="polite">
        <div className="flex items-start gap-3">
          <CheckCircle2 className="mt-0.5 size-5 shrink-0 text-emerald-600" aria-hidden />
          <div className="space-y-1">
            <h2 className="font-semibold">
              {done.emailed
                ? `Invitation sent to ${done.email}`
                : `${done.name || done.email} is invited`}
            </h2>
            <p className="text-muted-foreground text-sm">
              {done.emailed
                ? "They'll get an email to set up their password. They show as Invited until then."
                : "Email isn't set up here, so send them this link yourself."}
            </p>
          </div>
        </div>
        {!done.emailed && done.inviteUrl && (
          <div className="space-y-1.5">
            <CopyField value={absoluteLink(done.inviteUrl)} label="Invitation link" />
            <p className="text-muted-foreground text-xs">
              Only send it to {firstName(done.name, done.email)} — it creates their account.
            </p>
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          <Button type="button" onClick={reset} className="h-11 sm:h-9">
            Add another person
          </Button>
          <Button asChild variant="outline" className="h-11 sm:h-9">
            <Link href={`/users/${done.inviteId}`}>Open their page</Link>
          </Button>
          <Button asChild variant="ghost" className="h-11 sm:h-9">
            <Link href="/users">Done</Link>
          </Button>
        </div>
      </section>
    );
  }

  const name = firstName(fullName, email);

  return (
    <form onSubmit={submit} className="space-y-6" noValidate aria-label="Add person">
      {templates.length > 1 && (
        <section className="rounded-lg border p-4 sm:p-6">
          <TemplatePicker
            name="add-template"
            templates={templates}
            value={templateId}
            onChange={pickTemplate}
          />
        </section>
      )}

      <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-labelledby="add-details-h">
        <h2 id="add-details-h" className="text-sm font-semibold">
          Details
        </h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="add-name">Full name</Label>
            <Input
              id="add-name"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              autoComplete="off"
              maxLength={200}
              aria-invalid={Boolean(errors.fullName)}
              className="h-11 sm:h-9"
              autoFocus
            />
            <FieldError message={errors.fullName} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="add-email">Email</Label>
            <Input
              id="add-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="off"
              aria-invalid={Boolean(errors.email)}
              className="h-11 sm:h-9"
            />
            {errors.email && (
              <p role="alert" className="text-destructive text-sm">
                {errors.email}
                {existing && (
                  <>
                    {" "}
                    <Link href={existing.href} className="link">
                      Open their page
                    </Link>
                  </>
                )}
              </p>
            )}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="add-title">
              Job title <span className="text-muted-foreground font-normal">(optional)</span>
            </Label>
            <Input
              id="add-title"
              value={jobTitle}
              onChange={(e) => setJobTitle(e.target.value)}
              maxLength={200}
              className="h-11 sm:h-9"
            />
          </div>
          <DepartmentField
            id="add-department"
            departments={departments}
            value={dept}
            onChange={pickDepartment}
            newName={newDept}
            onNewName={setNewDept}
            error={errors.newDepartmentName}
            disabled={Boolean(locked)}
            allowNew={access.canNewDepartment}
            allowNone={!locked}
            hint={locked ? `You add people to ${locked.name}` : null}
          />
        </div>
      </section>

      <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-labelledby="add-role-h">
        <h2 id="add-role-h" className="sr-only">
          Role
        </h2>
        <RoleCards
          name="add-role"
          value={role}
          onChange={pickRole}
          allowed={access.roles}
          error={errors.role}
        />
        {access.roles && (
          <p className="text-muted-foreground text-xs">
            You can give the roles, sections and abilities you have yourself.
          </p>
        )}
      </section>

      {access.canGrantManager && role && role !== "admin" && (
        <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="add-mgr-h">
          <h2 id="add-mgr-h" className="text-sm font-semibold">
            Manager
          </h2>
          <ManagerField
            name="add-manager"
            value={manager}
            onChange={setManager}
            role={role}
            departmentName={
              dept === NEW_DEPARTMENT ? newDept.trim() || null : (chosen?.name ?? null)
            }
            editable
            person={name}
          />
        </section>
      )}

      {role && role !== "admin" ? (
        <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-label="Sections">
          <SectionsPicker
            id="add-sections"
            value={features}
            onChange={setFeatures}
            visible={visible}
            allowAll={access.allSections}
          />
          <AbilitiesFields
            id="add-abilities"
            role={role}
            value={abilities}
            onChange={setAbilities}
            features={features}
            assignable={access.abilities}
          />
        </section>
      ) : role === "admin" ? (
        <p className="text-muted-foreground rounded-lg border p-4 text-sm">
          Super admins use every section and can change anything, including people, managers and
          system settings.
        </p>
      ) : null}

      {canSignHere && chosen && (
        <section className="space-y-2 rounded-lg border p-4 sm:p-6" aria-labelledby="add-sign-h">
          <h2 id="add-sign-h" className="text-sm font-semibold">
            Signs off
          </h2>
          {viewer ? (
            <p className="text-muted-foreground text-sm">
              Viewers can&apos;t sign off artwork. Choose another role if {name} should.
            </p>
          ) : (
            <>
              <label className="flex min-h-11 items-center gap-2 text-sm font-medium sm:min-h-0">
                <input
                  type="checkbox"
                  className="accent-primary size-4"
                  checked={signsOff}
                  onChange={(e) => setSignsOff(e.target.checked)}
                />
                Signs off {chosen.name} artwork
              </label>
              {signsOff && access.canChooseMain && (
                <div className="ml-6 space-y-1">
                  <label className="flex min-h-11 items-start gap-2 text-sm sm:min-h-0">
                    <input
                      type="checkbox"
                      className="accent-primary mt-0.5 size-4"
                      checked={isMain && !mainKept}
                      disabled={mainKept}
                      onChange={(e) => setIsMain(e.target.checked)}
                    />
                    <span>
                      Main approver
                      <span className="text-muted-foreground block text-xs">
                        {mainKept
                          ? `${chosen.mainApprover} stays main approver until ${name} has accepted — you can make ${name} main under Departments then.`
                          : `Gets every item unless someone else is picked. ${
                              chosen.mainApprover
                                ? `Replaces ${chosen.mainApprover}, who can't sign off at the moment.`
                                : `${chosen.name} has no main approver yet.`
                            }`}
                      </span>
                    </span>
                  </label>
                </div>
              )}
            </>
          )}
        </section>
      )}

      <section className="space-y-2 rounded-lg border p-4 sm:p-6" aria-labelledby="add-end-h">
        <h2 id="add-end-h" className="text-sm font-semibold">
          Access ends <span className="text-muted-foreground font-normal">(optional)</span>
        </h2>
        {endPrompt && !accessEnd && (
          <p className="flex items-start gap-2 rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
            <CalendarClock className="mt-0.5 size-4 shrink-0" aria-hidden />
            Freelancers usually have an end date — when does their work finish?
          </p>
        )}
        <div className="flex flex-wrap items-center gap-2">
          <Label htmlFor="add-end" className="sr-only">
            Access ends on
          </Label>
          <Input
            ref={endRef}
            id="add-end"
            type="date"
            min={localToday()}
            value={accessEnd}
            onChange={(e) => setAccessEnd(e.target.value)}
            aria-invalid={Boolean(errors.accessEndsOn)}
            className="h-11 w-auto sm:h-9"
          />
          {accessEnd && (
            <Button
              type="button"
              variant="ghost"
              className="h-11 sm:h-9"
              onClick={() => setAccessEnd("")}
            >
              Clear
            </Button>
          )}
        </div>
        <p className="text-muted-foreground text-xs">
          They keep access to the end of that day (London time), then can&apos;t sign in. Leave it
          empty for no end.
        </p>
        <FieldError message={errors.accessEndsOn} />
      </section>

      <FieldError message={errors.form} />
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="flex gap-2">
          <Button type="submit" disabled={pending} className="h-11 flex-1 sm:h-9 sm:flex-none">
            {pending ? "Sending…" : "Send invitation"}
          </Button>
          <Button asChild variant="outline" className="h-11 sm:h-9">
            <Link href="/users">Cancel</Link>
          </Button>
        </div>
        <p className="text-muted-foreground text-xs">
          They&apos;ll get an email to set up their password. You can change any of this later.
        </p>
      </div>
    </form>
  );
}
