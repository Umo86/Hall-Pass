"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, ArrowDown, ArrowUp, Building2, Star, UserPlus } from "lucide-react";
import { toast } from "sonner";
import {
  addApprover,
  cancelMainOnAccept,
  moveDepartment,
  removeApprover,
  saveDepartment,
  setDepartmentArchived,
  setDepartmentSignsOff,
  setMainApprover,
} from "@/app/actions/approvers";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { EmptyState } from "@/components/empty-state";
import { useConfirm } from "@/components/confirm-dialog";
import { cn } from "@/lib/utils";

export type DepartmentCardData = {
  id: string;
  name: string;
  signsOff: boolean;
  signsLast: boolean;
  defaultFor: string[];
  isArchived: boolean;
  memberCount: number;
  suspendedCount: number;
  endedCount: number;
  managers: { userId: string; name: string }[];
  /** Approvers who can sign off now. */
  signersNow: number;
  approvers: {
    id: string;
    userId: string | null;
    name: string;
    jobTitle: string | null;
    email: string;
    isMain: boolean;
    /** Invited: becomes the main approver when they accept. */
    mainOnAccept: boolean;
    state: "active" | "paused" | "invited" | "none";
    /** Why they can't sign now, in a few words. */
    stateText: string | null;
    href: string | null;
  }[];
};

export type MemberOption = { userId: string; name: string; email: string };

type Result = { ok: true; message?: string } | { ok: false; error: string };

function Switch({
  checked,
  onChange,
  label,
  disabled,
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
  label: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className="group inline-flex min-h-11 items-center gap-2 text-sm disabled:opacity-60 sm:min-h-0"
    >
      <span
        className={cn(
          "relative inline-flex h-5 w-9 shrink-0 rounded-full border transition-colors",
          checked ? "bg-primary border-primary" : "bg-input border-input",
        )}
        aria-hidden
      >
        <span
          className={cn(
            "absolute top-0.5 size-3.5 rounded-full bg-white shadow-sm ring-1 ring-black/10 transition-transform",
            checked ? "translate-x-[18px]" : "translate-x-0.5",
          )}
        />
      </span>
      <span>Signs off artwork</span>
    </button>
  );
}

/**
 * Users → Departments: one card per department. People who manage
 * departments edit them; everyone else reads them, and managers get "Add
 * person to {department}" on the departments they add people to.
 */
export function DepartmentsPanel({
  departments,
  members,
  canEdit,
  addTo = [],
}: {
  departments: DepartmentCardData[];
  members: MemberOption[];
  canEdit: boolean;
  /** Departments the viewer adds people to ("all", or ids). */
  addTo?: "all" | string[];
}) {
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const live = departments.filter((d) => !d.isArchived);
  const archived = departments.filter((d) => d.isArchived);
  const signing = live.filter((d) => d.signsOff);

  function run(fn: () => Promise<Result>, after?: () => void) {
    start(async () => {
      const res = await fn();
      if (!res.ok) toast.error(res.error);
      else {
        toast.success(res.message ?? "Saved");
        after?.();
      }
      router.refresh();
    });
  }

  return (
    <div className="space-y-4">
      <p className="text-muted-foreground max-w-3xl text-sm">
        Everyone can belong to one department. Departments that{" "}
        <span className="text-foreground font-medium">sign off artwork</span> get a sign-off step on
        signage; the <span className="text-foreground font-medium">main approver</span> gets every
        item unless someone else is picked, otherwise anyone listed can sign.
        {canEdit ? "" : " Changing them needs “Manage departments and who signs off”."}
      </p>

      {live.length === 0 && (
        <EmptyState
          icon={Building2}
          title="No departments yet"
          description="Add the teams you work in — for example Operations, Marketing or Senior management."
        />
      )}

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        {live.map((d) => (
          <DepartmentCard
            key={d.id}
            dept={d}
            members={members}
            canEdit={canEdit}
            pending={pending}
            first={signing[0]?.id === d.id}
            last={signing[signing.length - 1]?.id === d.id}
            run={run}
            confirm={confirm}
            canAdd={addTo === "all" || addTo.includes(d.id)}
          />
        ))}
      </div>

      {canEdit && <AddDepartment pending={pending} run={run} />}

      {archived.length > 0 && (
        <details className="rounded-lg border">
          <summary className="min-h-11 cursor-pointer px-3 py-2.5 text-sm font-medium select-none">
            Archived ({archived.length})
          </summary>
          <ul className="divide-y border-t">
            {archived.map((d) => (
              <li key={d.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
                <span className="min-w-0 flex-1">
                  {d.name}
                  <span className="text-muted-foreground">
                    {" "}
                    · {d.memberCount} {d.memberCount === 1 ? "person" : "people"}
                  </span>
                </span>
                {canEdit && (
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-11 sm:h-8"
                    disabled={pending}
                    aria-label={`Restore ${d.name}`}
                    onClick={() => run(() => setDepartmentArchived({ id: d.id, archived: false }))}
                  >
                    Restore
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </details>
      )}
      {confirmDialog}
    </div>
  );
}

function AddDepartment({
  pending,
  run,
}: {
  pending: boolean;
  run: (fn: () => Promise<Result>, after?: () => void) => void;
}) {
  const [name, setName] = useState("");
  const [signsOff, setSignsOff] = useState(false);
  return (
    <form
      className="space-y-3 rounded-lg border border-dashed p-4"
      aria-label="Add a department"
      onSubmit={(e) => {
        e.preventDefault();
        run(
          () =>
            saveDepartment({
              name,
              signsOff,
              defaultFor: ["organiser", "sponsor"],
              signsLast: false,
            }),
          () => {
            setName("");
            setSignsOff(false);
          },
        );
      }}
    >
      <p className="text-sm font-medium">Add a department</p>
      <div className="flex flex-wrap items-center gap-3">
        <Input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Department name, e.g. Legal"
          aria-label="Department name"
          className="h-11 max-w-xs sm:h-9"
          maxLength={60}
          required
        />
        <Switch
          checked={signsOff}
          onChange={setSignsOff}
          label="New department signs off artwork"
        />
        <Button type="submit" disabled={pending || !name.trim()} className="h-11 sm:h-9">
          Add department
        </Button>
      </div>
      <p className="text-muted-foreground text-xs">
        Leave sign-off off for teams that don&apos;t approve artwork; you can switch it on later.
      </p>
    </form>
  );
}

function DepartmentCard({
  dept,
  members,
  canEdit,
  pending,
  first,
  last,
  run,
  confirm,
  canAdd,
}: {
  dept: DepartmentCardData;
  members: MemberOption[];
  canEdit: boolean;
  pending: boolean;
  first: boolean;
  last: boolean;
  run: (fn: () => Promise<Result>, after?: () => void) => void;
  confirm: ReturnType<typeof useConfirm>[1];
  /** The viewer adds people to this department. */
  canAdd: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [adding, setAdding] = useState("");
  const [addMain, setAddMain] = useState(false);
  const people = `${dept.memberCount} ${dept.memberCount === 1 ? "person" : "people"}`;
  const counts = [
    people,
    dept.suspendedCount > 0 ? `${dept.suspendedCount} suspended` : null,
    dept.endedCount > 0 ? `${dept.endedCount} access ended` : null,
  ]
    .filter(Boolean)
    .join(" · ");
  // Approvers listed, but none of them can sign now (paused, suspended, ended…).
  const nobodySigns = dept.signsOff && dept.approvers.length > 0 && dept.signersNow === 0;
  const rules = [
    dept.defaultFor.includes("organiser") && "organiser signage",
    dept.defaultFor.includes("sponsor") && "sponsor signage",
  ].filter(Boolean);
  const listed = new Set(dept.approvers.map((a) => a.userId).filter(Boolean));
  const choices = members.filter((m) => !listed.has(m.userId));
  const hasMain = dept.approvers.some((a) => a.isMain);

  async function archive() {
    const ok = await confirm({
      title: `Archive ${dept.name}?`,
      description:
        dept.memberCount > 0
          ? `${people} ${dept.memberCount === 1 ? "is" : "are"} in ${dept.name}. They keep their access; their department will show as archived.${dept.signsOff ? " It stops signing off new artwork; sign-offs already waiting can still be decided." : ""}`
          : `Nobody is in ${dept.name}.${dept.signsOff ? " It stops signing off new artwork." : ""} You can restore it later.`,
      confirmLabel: "Archive",
      destructive: true,
    });
    if (ok) run(() => setDepartmentArchived({ id: dept.id, archived: true }));
  }

  return (
    <section
      className="flex min-w-0 flex-col rounded-lg border"
      aria-label={`${dept.name} department`}
    >
      <header className="flex flex-wrap items-start gap-x-3 gap-y-2 border-b px-4 py-3">
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold">{dept.name}</h3>
          <Link href={`/users?dept=${dept.id}`} className="link text-sm">
            {counts}
          </Link>
          {dept.managers.length > 0 && (
            <p className="text-muted-foreground text-xs">
              Managed by {dept.managers.map((m) => m.name).join(", ")}
            </p>
          )}
        </div>
        {canEdit ? (
          <Switch
            checked={dept.signsOff}
            disabled={pending}
            label={`${dept.name} signs off artwork`}
            onChange={(next) => run(() => setDepartmentSignsOff({ id: dept.id, signsOff: next }))}
          />
        ) : (
          <span className="text-muted-foreground text-sm">
            {dept.signsOff ? "Signs off artwork" : "No sign-off"}
          </span>
        )}
      </header>

      {editing && canEdit ? (
        <form
          className="space-y-3 border-b px-4 py-3"
          aria-label={`Edit ${dept.name}`}
          onSubmit={(e) => {
            e.preventDefault();
            const f = new FormData(e.currentTarget);
            run(
              () =>
                saveDepartment({
                  id: dept.id,
                  name: f.get("name"),
                  defaultFor: [
                    f.get("organiser") && "organiser",
                    f.get("sponsor") && "sponsor",
                  ].filter(Boolean),
                  signsLast: Boolean(f.get("signsLast")),
                }),
              () => setEditing(false),
            );
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor={`dept-name-${dept.id}`}>Name</Label>
            <Input
              id={`dept-name-${dept.id}`}
              name="name"
              defaultValue={dept.name}
              maxLength={60}
              className="h-11 max-w-xs sm:h-9"
              required
              autoFocus
            />
          </div>
          {dept.signsOff && (
            <fieldset className="space-y-1 text-sm">
              <legend className="text-muted-foreground mb-1 text-xs">
                Signs off by default for
              </legend>
              <label className="flex min-h-11 items-center gap-2 sm:min-h-0">
                <input
                  type="checkbox"
                  name="organiser"
                  className="accent-primary size-4"
                  defaultChecked={dept.defaultFor.includes("organiser")}
                />
                Organiser signage
              </label>
              <label className="flex min-h-11 items-center gap-2 sm:min-h-0">
                <input
                  type="checkbox"
                  name="sponsor"
                  className="accent-primary size-4"
                  defaultChecked={dept.defaultFor.includes("sponsor")}
                />
                Sponsor signage
              </label>
              <label className="flex min-h-11 items-center gap-2 sm:min-h-0">
                <input
                  type="checkbox"
                  name="signsLast"
                  className="accent-primary size-4"
                  defaultChecked={dept.signsLast}
                />
                Signs off after the other departments
              </label>
            </fieldset>
          )}
          {!dept.signsOff && (
            <>
              <input
                type="hidden"
                name="organiser"
                value={dept.defaultFor.includes("organiser") ? "1" : ""}
              />
              <input
                type="hidden"
                name="sponsor"
                value={dept.defaultFor.includes("sponsor") ? "1" : ""}
              />
              <input type="hidden" name="signsLast" value={dept.signsLast ? "1" : ""} />
            </>
          )}
          <div className="flex gap-2">
            <Button type="submit" size="sm" className="h-11 sm:h-8" disabled={pending}>
              Save
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              className="h-11 sm:h-8"
              onClick={() => setEditing(false)}
            >
              Cancel
            </Button>
          </div>
        </form>
      ) : (
        dept.signsOff && (
          <p className="text-muted-foreground border-b px-4 py-2 text-xs">
            {rules.length > 0
              ? `Signs off ${rules.join(" and ")} by default`
              : "Signs off only when ticked on an item"}
            {dept.signsLast ? " · after the other departments" : ""}
          </p>
        )
      )}

      {nobodySigns && (
        <p
          role="note"
          className="flex gap-2 border-b border-amber-300 bg-amber-50 px-4 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200"
        >
          <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span>
            Nobody can sign off for {dept.name} now — items sent for sign-off will wait.
            {canEdit ? " Add someone who can below." : " Ask whoever manages departments."}
          </span>
        </p>
      )}

      {dept.signsOff && (
        <div className="flex-1">
          <ul className="divide-y" aria-label={`${dept.name} approvers`}>
            {dept.approvers.length === 0 && (
              <li className="px-4 py-3 text-sm text-amber-900 dark:text-amber-200">
                Nobody signs off for {dept.name} yet — items sent for sign-off will wait
                {canEdit ? ". Add someone below." : "."}
              </li>
            )}
            {dept.approvers.map((a) => (
              <li key={a.id} className="flex flex-wrap items-center gap-x-2 gap-y-1 px-4 py-2">
                {canEdit ? (
                  <Button
                    type="button"
                    variant="ghost"
                    size="touch"
                    disabled={pending}
                    aria-pressed={a.isMain || a.mainOnAccept}
                    aria-label={
                      a.isMain
                        ? `${a.name} is the main approver for ${dept.name} — stop`
                        : a.mainOnAccept
                          ? `${a.name} becomes the main approver for ${dept.name} when they accept — cancel`
                          : `Make ${a.name} the main approver for ${dept.name}`
                    }
                    title={
                      a.isMain
                        ? "Main approver"
                        : a.mainOnAccept
                          ? "Main approver when they accept"
                          : "Make main approver"
                    }
                    onClick={() =>
                      run(() =>
                        a.mainOnAccept
                          ? cancelMainOnAccept({ id: a.id })
                          : setMainApprover({ id: a.id, isMain: !a.isMain }),
                      )
                    }
                  >
                    <Star
                      className={cn(
                        "size-4",
                        a.isMain
                          ? "fill-amber-400 text-amber-500"
                          : a.mainOnAccept
                            ? "text-amber-500"
                            : "text-muted-foreground",
                      )}
                      aria-hidden
                    />
                  </Button>
                ) : a.isMain ? (
                  <Star
                    className="size-4 fill-amber-400 text-amber-500"
                    role="img"
                    aria-label="Main approver"
                  />
                ) : (
                  a.mainOnAccept && (
                    <Star
                      className="size-4 text-amber-500"
                      role="img"
                      aria-label="Main approver when they accept"
                    />
                  )
                )}
                {/* At least 10rem for the name: the buttons wrap under it on phones. */}
                <div className="min-w-0 grow basis-40 text-sm">
                  <p className="font-medium">
                    {a.href ? (
                      <Link href={a.href} className="hover:underline">
                        {a.name}
                      </Link>
                    ) : (
                      a.name
                    )}
                    {a.isMain && (
                      <span className="text-muted-foreground font-normal"> · main approver</span>
                    )}
                    {a.mainOnAccept && (
                      <span className="text-muted-foreground font-normal">
                        {" "}
                        · main approver when they accept
                      </span>
                    )}
                  </p>
                  <p className="text-muted-foreground truncate text-xs">
                    {[a.jobTitle, a.email, a.stateText].filter(Boolean).join(" · ")}
                  </p>
                </div>
                {canEdit && (
                  <div className="ml-auto flex shrink-0 flex-wrap items-center gap-1">
                    {a.mainOnAccept && (
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        className="h-11 sm:h-8"
                        disabled={pending}
                        aria-label={`${a.name} won't become the main approver for ${dept.name}`}
                        onClick={() => run(() => cancelMainOnAccept({ id: a.id }))}
                      >
                        Don&apos;t make main
                      </Button>
                    )}
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      className="h-11 sm:h-8"
                      disabled={pending}
                      aria-label={`Remove ${a.name} from ${dept.name} approvers`}
                      onClick={async () => {
                        const others = dept.signersNow - (a.state === "active" ? 1 : 0);
                        const ok = await confirm({
                          title: `Remove ${a.name} from ${dept.name} approvers?`,
                          description: [
                            "They stay on the team.",
                            others > 0
                              ? `${dept.name} sign-offs that name them go back to everyone who signs off for ${dept.name}.`
                              : `Nobody else can sign off for ${dept.name}, so sign-offs that name them stay with them, and new ones will wait until you add someone.`,
                            a.isMain && others > 0
                              ? `${dept.name} will have no main approver, so everyone left in it is asked.`
                              : null,
                            a.mainOnAccept
                              ? "They won't become main approver when they accept."
                              : null,
                          ]
                            .filter(Boolean)
                            .join(" "),
                          confirmLabel: "Remove",
                          destructive: true,
                        });
                        if (ok) run(() => removeApprover({ id: a.id }));
                      }}
                    >
                      Remove
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
          {canEdit && (
            <form
              className="flex flex-wrap items-center gap-2 border-t px-4 py-3"
              aria-label={`Add an approver to ${dept.name}`}
              onSubmit={(e) => {
                e.preventDefault();
                if (!adding) return;
                run(
                  () => addApprover({ departmentId: dept.id, userId: adding, isMain: addMain }),
                  () => {
                    setAdding("");
                    setAddMain(false);
                  },
                );
              }}
            >
              <SelectNative
                aria-label={`Team member to add to ${dept.name} approvers`}
                value={adding}
                onChange={(e) => {
                  setAdding(e.target.value);
                  setAddMain(!hasMain);
                }}
                className="h-11 w-full sm:h-8 sm:w-56"
              >
                <option value="">Add an approver…</option>
                {choices.map((m) => (
                  <option key={m.userId} value={m.userId}>
                    {m.name}
                  </option>
                ))}
              </SelectNative>
              {adding && (
                <label className="flex min-h-11 items-center gap-1.5 text-sm sm:min-h-0">
                  <input
                    type="checkbox"
                    className="accent-primary size-4"
                    checked={addMain}
                    onChange={(e) => setAddMain(e.target.checked)}
                  />
                  Main approver
                </label>
              )}
              {adding && (
                <Button type="submit" size="sm" className="h-11 sm:h-8" disabled={pending}>
                  Add
                </Button>
              )}
              <Link
                href={`/users/new?department=${dept.id}&signsOff=1`}
                className="link inline-flex min-h-11 items-center gap-1 text-sm sm:min-h-0"
              >
                <UserPlus className="size-3.5" aria-hidden />
                Invite someone new…
              </Link>
            </form>
          )}
        </div>
      )}

      {canAdd && !canEdit && (
        <footer className="border-t px-4 py-2">
          <Link
            href={`/users/new?department=${dept.id}`}
            className="link inline-flex min-h-11 items-center gap-1 text-sm sm:min-h-0"
          >
            <UserPlus className="size-3.5" aria-hidden />
            Add person to {dept.name}
          </Link>
        </footer>
      )}

      {canEdit && !editing && (
        <footer className="flex flex-wrap items-center gap-1 border-t px-2 py-1.5">
          <Button
            type="button"
            size="sm"
            variant="ghost"
            className="h-11 sm:h-8"
            onClick={() => setEditing(true)}
            aria-label={`Edit ${dept.name}`}
          >
            Edit
          </Button>
          {dept.signsOff && (
            <>
              <Button
                type="button"
                size="touch"
                variant="ghost"
                aria-label={`Move ${dept.name} earlier in the sign-off order`}
                disabled={pending || first}
                onClick={() => run(() => moveDepartment({ id: dept.id, direction: "up" }))}
              >
                <ArrowUp aria-hidden />
              </Button>
              <Button
                type="button"
                size="touch"
                variant="ghost"
                aria-label={`Move ${dept.name} later in the sign-off order`}
                disabled={pending || last}
                onClick={() => run(() => moveDepartment({ id: dept.id, direction: "down" }))}
              >
                <ArrowDown aria-hidden />
              </Button>
            </>
          )}
          <Button
            type="button"
            size="sm"
            variant="ghost"
            className="text-destructive hover:text-destructive ml-auto h-11 sm:h-8"
            disabled={pending}
            onClick={archive}
            aria-label={`Archive ${dept.name}`}
          >
            Archive
          </Button>
        </footer>
      )}
    </section>
  );
}
