"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2 } from "lucide-react";
import { toast } from "sonner";
import type { AbilityKey, Feature, StaffRole } from "@/lib/authz";
import {
  defaultAbilities,
  firstName,
  roleForDepartment,
  type AbilityChoices,
} from "@/lib/users/rules";
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
  NEW_DEPARTMENT,
  RoleCards,
  SectionsPicker,
  type DepartmentOption,
} from "./person-fields";

type Errors = Partial<Record<"fullName" | "email" | "role" | "newDepartmentName" | "form", string>>;

/** Users → Add user: one column, everything optional except name, email and role. */
export function AddUserForm({
  departments,
  visible,
  initial,
  access,
}: {
  departments: DepartmentOption[];
  visible: Feature[];
  initial: { departmentId: string; signsOff: boolean; fullName: string; email: string };
  /** What the viewer may give (managers); omitted for super admins. */
  access?: { roles: StaffRole[]; abilities: AbilityKey[] };
}) {
  const startDept = departments.find((d) => d.id === initial.departmentId && !d.isArchived);
  const [fullName, setFullName] = useState(initial.fullName);
  const [email, setEmail] = useState(initial.email);
  const [jobTitle, setJobTitle] = useState("");
  const [dept, setDept] = useState(startDept?.id ?? "");
  const [newDept, setNewDept] = useState("");
  const [role, setRole] = useState<StaffRole | null>(roleForDepartment(startDept?.name));
  const [roleTouched, setRoleTouched] = useState(false);
  const [features, setFeatures] = useState<Feature[] | null>(null);
  const [abilities, setAbilities] = useState<AbilityChoices>(
    defaultAbilities(roleForDepartment(startDept?.name) ?? "viewer"),
  );
  const [signsOff, setSignsOff] = useState(initial.signsOff && Boolean(startDept?.signsOff));
  const [isMain, setIsMain] = useState(startDept ? startDept.mainApprover === null : false);
  const [errors, setErrors] = useState<Errors>({});
  const [existing, setExisting] = useState<string | null>(null);
  const [done, setDone] = useState<InviteUserResult | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const chosen = useMemo(() => departments.find((d) => d.id === dept) ?? null, [departments, dept]);

  function pickDepartment(value: string) {
    setDept(value);
    const d = departments.find((x) => x.id === value);
    if (!roleTouched && d) {
      const suggested = roleForDepartment(d.name);
      if (suggested) {
        setRole(suggested);
        setAbilities(defaultAbilities(suggested));
      }
    }
    setIsMain(d ? d.mainApprover === null : false);
    if (!d?.signsOff) setSignsOff(false);
  }

  function pickRole(next: StaffRole) {
    setRole(next);
    setRoleTouched(true);
    setAbilities(defaultAbilities(next));
    setErrors((e) => ({ ...e, role: undefined }));
  }

  /** Ready for the next person: same department, role and sections, new details. */
  function reset() {
    setDone(null);
    setFullName("");
    setEmail("");
    setJobTitle("");
    // The person just added may now be the main approver.
    setIsMain(false);
    setErrors({});
    setExisting(null);
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
        features: allVisible ? null : features,
        abilities,
        signoffs: signsOff && chosen?.signsOff ? [{ departmentId: chosen.id, isMain }] : [],
      });
      if (res.ok) {
        toast.success(res.message ?? "Invitation sent");
        setDone(res.data!);
        router.refresh();
        return;
      }
      const fe = res.fieldErrors ?? {};
      if (fe.existingUserId) {
        setExisting(fe.existingUserId);
        setErrors({ email: res.error });
        return;
      }
      setErrors({
        fullName: fe.fullName,
        email: fe.email,
        role: fe.role,
        newDepartmentName: fe.newDepartmentName,
        form: fe.fullName || fe.email || fe.role || fe.newDepartmentName ? undefined : res.error,
      });
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
          <Button type="button" onClick={reset}>
            Add another person
          </Button>
          <Button asChild variant="outline">
            <Link href="/users">Done</Link>
          </Button>
        </div>
      </section>
    );
  }

  return (
    <form onSubmit={submit} className="space-y-6" noValidate aria-label="Add user">
      <section className="space-y-4 rounded-lg border p-4 sm:p-6">
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
                    <Link href={`/users/${existing}`} className="link">
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
          />
        </div>
        <RoleCards
          name="add-role"
          value={role}
          onChange={pickRole}
          allowed={access?.roles}
          error={errors.role}
        />
      </section>

      {role !== "admin" ? (
        <section className="space-y-4 rounded-lg border p-4 sm:p-6">
          <SectionsPicker
            id="add-sections"
            value={features}
            onChange={setFeatures}
            visible={visible}
          />
          {chosen?.signsOff && (
            <div className="space-y-2">
              <label className="flex min-h-11 items-center gap-2 text-sm font-medium sm:min-h-0">
                <input
                  type="checkbox"
                  className="accent-primary size-4"
                  checked={signsOff}
                  onChange={(e) => setSignsOff(e.target.checked)}
                />
                Signs off {chosen.name} artwork
              </label>
              {signsOff && (
                <div className="ml-6 space-y-1">
                  <label className="flex min-h-11 items-start gap-2 text-sm sm:min-h-0">
                    <input
                      type="checkbox"
                      className="accent-primary mt-0.5 size-4"
                      checked={isMain}
                      onChange={(e) => setIsMain(e.target.checked)}
                    />
                    <span>
                      Main approver
                      <span className="text-muted-foreground block text-xs">
                        Gets every item unless someone else is picked.{" "}
                        {chosen.mainApprover
                          ? `Replaces ${chosen.mainApprover}.`
                          : `${chosen.name} has no main approver yet.`}
                      </span>
                    </span>
                  </label>
                </div>
              )}
            </div>
          )}
          {role && (
            <AbilitiesFields
              id="add-abilities"
              role={role}
              value={abilities}
              onChange={setAbilities}
              features={features}
              assignable={access?.abilities}
            />
          )}
        </section>
      ) : (
        <p className="text-muted-foreground rounded-lg border p-4 text-sm">
          Admins can use every section and change anything, including users and settings.
        </p>
      )}

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
