"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowDown, ArrowUp, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  moveDepartment,
  removeApprover,
  resendApproverInvite,
  saveApprover,
  saveDepartment,
  setDepartmentArchived,
} from "@/app/actions/approvers";

export type ApproverRow = {
  id: string;
  fullName: string;
  jobTitle: string | null;
  email: string;
  isMain: boolean;
  /** "active": can sign off now; "invited": waiting for them to set up; "none": no account or invite. */
  state: "active" | "invited" | "none";
};

export type DepartmentRow = {
  id: string;
  name: string;
  defaultFor: string[];
  signsLast: boolean;
  isArchived: boolean;
  approvers: ApproverRow[];
};

type Result = { ok: boolean; error?: string; message?: string; data?: { inviteUrl?: string } };

const STATE_LABEL: Record<ApproverRow["state"], string> = {
  active: "Active",
  invited: "Invite sent — not set up yet",
  none: "No account yet",
};

/** Approvals → Approvers: departments and the people who sign off for each. */
export function ApproversEditor({
  departments,
  canEdit,
}: {
  departments: DepartmentRow[];
  canEdit: boolean;
}) {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function run(fn: () => Promise<Result>, after?: () => void) {
    setError(null);
    setNotice(null);
    setInviteUrl(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) setError(res.error ?? "Something went wrong");
      else {
        setNotice(res.message ?? null);
        setInviteUrl(res.data?.inviteUrl ?? null);
        after?.();
      }
      router.refresh();
    });
  }

  const active = departments.filter((d) => !d.isArchived);
  const removed = departments.filter((d) => d.isArchived);

  return (
    <div className="space-y-4">
      {(notice || error) && (
        <div
          role="status"
          className={`rounded-lg border p-3 text-sm ${
            error
              ? "border-destructive/40 text-destructive"
              : "border-green-300 text-green-800 dark:border-green-900 dark:text-green-300"
          }`}
        >
          {error ?? notice}
          {inviteUrl && (
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <Input readOnly value={inviteUrl} aria-label="Invitation link" className="h-8 flex-1" />
              <Button
                size="sm"
                variant="outline"
                type="button"
                onClick={() => navigator.clipboard?.writeText(inviteUrl)}
              >
                Copy link
              </Button>
            </div>
          )}
        </div>
      )}

      {active.length === 0 && (
        <p className="text-muted-foreground rounded-lg border border-dashed p-6 text-center text-sm">
          No departments yet. Add one below — for example Operations, Marketing or Senior
          management.
        </p>
      )}

      {active.map((d, i) => (
        <DepartmentCard
          key={d.id}
          dept={d}
          canEdit={canEdit}
          pending={pending}
          first={i === 0}
          last={i === active.length - 1}
          run={run}
        />
      ))}

      {canEdit && <AddDepartment pending={pending} run={run} />}

      {canEdit && removed.length > 0 && (
        <details>
          <summary className="text-muted-foreground cursor-pointer text-xs select-none">
            Removed departments ({removed.length})
          </summary>
          <ul className="mt-2 space-y-1 text-sm">
            {removed.map((d) => (
              <li key={d.id} className="flex items-center gap-2">
                <span className="text-muted-foreground line-through">{d.name}</span>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pending}
                  onClick={() => run(() => setDepartmentArchived({ id: d.id, archived: false }))}
                >
                  Restore
                </Button>
              </li>
            ))}
          </ul>
        </details>
      )}
    </div>
  );
}

function DefaultForFields({ defaultFor, signsLast }: { defaultFor: string[]; signsLast: boolean }) {
  return (
    <fieldset className="flex flex-wrap gap-x-4 gap-y-1 text-sm">
      <legend className="sr-only">When this department signs off</legend>
      <label className="flex items-center gap-1.5">
        <input
          type="checkbox"
          name="organiser"
          className="size-4"
          defaultChecked={defaultFor.includes("organiser")}
        />
        Organiser signage
      </label>
      <label className="flex items-center gap-1.5">
        <input
          type="checkbox"
          name="sponsor"
          className="size-4"
          defaultChecked={defaultFor.includes("sponsor")}
        />
        Sponsor signage
      </label>
      <label className="flex items-center gap-1.5">
        <input type="checkbox" name="signsLast" className="size-4" defaultChecked={signsLast} />
        Signs off after the other departments
      </label>
    </fieldset>
  );
}

function departmentFromForm(form: HTMLFormElement) {
  const f = new FormData(form);
  return {
    name: f.get("name"),
    defaultFor: [f.get("organiser") && "organiser", f.get("sponsor") && "sponsor"].filter(Boolean),
    signsLast: Boolean(f.get("signsLast")),
  };
}

function AddDepartment({
  pending,
  run,
}: {
  pending: boolean;
  run: (fn: () => Promise<Result>, after?: () => void) => void;
}) {
  return (
    <form
      className="space-y-2 rounded-lg border border-dashed p-3"
      aria-label="Add a department"
      onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        run(() => saveDepartment(departmentFromForm(form)), () => form.reset());
      }}
    >
      <p className="text-sm font-medium">Add a department</p>
      <div className="flex flex-wrap gap-2">
        <Input
          name="name"
          placeholder="Department name, e.g. Legal"
          aria-label="Department name"
          className="h-9 max-w-xs"
          required
        />
        <Button type="submit" disabled={pending}>
          Add department
        </Button>
      </div>
      <p className="text-muted-foreground text-xs">Signs off by default for:</p>
      <DefaultForFields defaultFor={["organiser", "sponsor"]} signsLast={false} />
    </form>
  );
}

function DepartmentCard({
  dept,
  canEdit,
  pending,
  first,
  last,
  run,
}: {
  dept: DepartmentRow;
  canEdit: boolean;
  pending: boolean;
  first: boolean;
  last: boolean;
  run: (fn: () => Promise<Result>, after?: () => void) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [editingApprover, setEditingApprover] = useState<string | null>(null);
  const defaults = [
    dept.defaultFor.includes("organiser") && "organiser signage",
    dept.defaultFor.includes("sponsor") && "sponsor signage",
  ].filter(Boolean);

  return (
    <section className="rounded-lg border" aria-label={`${dept.name} approvers`}>
      <header className="flex flex-wrap items-start gap-2 border-b px-3 py-2">
        {editing ? (
          <form
            className="w-full space-y-2"
            onSubmit={(e) => {
              e.preventDefault();
              const form = e.currentTarget;
              run(
                () => saveDepartment({ id: dept.id, ...departmentFromForm(form) }),
                () => setEditing(false),
              );
            }}
          >
            <div className="flex flex-wrap gap-2">
              <Input
                name="name"
                defaultValue={dept.name}
                aria-label="Department name"
                className="h-8 max-w-xs"
                required
                autoFocus
              />
              <Button size="sm" type="submit" disabled={pending}>
                Save
              </Button>
              <Button size="sm" type="button" variant="ghost" onClick={() => setEditing(false)}>
                Cancel
              </Button>
            </div>
            <DefaultForFields defaultFor={dept.defaultFor} signsLast={dept.signsLast} />
          </form>
        ) : (
          <>
            <div className="min-w-0 basis-full sm:basis-0 sm:flex-1">
              <h3 className="font-semibold">{dept.name}</h3>
              <p className="text-muted-foreground text-xs">
                {defaults.length > 0
                  ? `Signs off ${defaults.join(" and ")} by default`
                  : "Only when ticked on an item"}
                {dept.signsLast ? " · after the other departments" : ""}
              </p>
            </div>
            {canEdit && (
              <div className="flex flex-wrap gap-1">
                <Button
                  size="icon"
                  variant="ghost"
                  className="size-8"
                  aria-label={`Move ${dept.name} up`}
                  disabled={pending || first}
                  onClick={() => run(() => moveDepartment({ id: dept.id, direction: "up" }))}
                >
                  <ArrowUp className="size-4" />
                </Button>
                <Button
                  size="icon"
                  variant="ghost"
                  className="size-8"
                  aria-label={`Move ${dept.name} down`}
                  disabled={pending || last}
                  onClick={() => run(() => moveDepartment({ id: dept.id, direction: "down" }))}
                >
                  <ArrowDown className="size-4" />
                </Button>
                <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
                  Edit
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pending}
                  onClick={() => {
                    if (confirm(`Remove ${dept.name} from sign-off? Its approvers are kept.`)) {
                      run(() => setDepartmentArchived({ id: dept.id, archived: true }));
                    }
                  }}
                >
                  Remove
                </Button>
              </div>
            )}
          </>
        )}
      </header>

      <ul className="divide-y">
        {dept.approvers.length === 0 && (
          <li className="text-muted-foreground px-3 py-2 text-sm">
            No approvers yet{canEdit ? " — add the first one below." : "."}
          </li>
        )}
        {dept.approvers.map((a) =>
          editingApprover === a.id ? (
            <li key={a.id} className="px-3 py-2">
              <ApproverForm
                departmentId={dept.id}
                approver={a}
                pending={pending}
                onCancel={() => setEditingApprover(null)}
                run={run}
                onDone={() => setEditingApprover(null)}
              />
            </li>
          ) : (
            <li key={a.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 text-sm">
              <div className="min-w-0 basis-full sm:basis-0 sm:flex-1">
                <p className="font-medium">
                  {a.fullName}
                  {a.isMain && (
                    <span className="ml-2 inline-flex items-center gap-1 rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-900 dark:bg-amber-950 dark:text-amber-200">
                      <Star className="size-3" aria-hidden /> Main approver
                    </span>
                  )}
                </p>
                <p className="text-muted-foreground text-xs">
                  {[a.jobTitle, a.email].filter(Boolean).join(" · ")}
                </p>
              </div>
              <span
                className={`text-xs ${
                  a.state === "active" ? "text-green-700 dark:text-green-400" : "text-amber-800 dark:text-amber-300"
                }`}
              >
                {STATE_LABEL[a.state]}
              </span>
              {canEdit && (
                <span className="flex flex-wrap gap-1">
                  {!a.isMain && (
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={pending}
                      onClick={() =>
                        run(() =>
                          saveApprover({
                            id: a.id,
                            departmentId: dept.id,
                            fullName: a.fullName,
                            jobTitle: a.jobTitle ?? "",
                            email: a.email,
                            isMain: true,
                          }),
                        )
                      }
                    >
                      Make main
                    </Button>
                  )}
                  {a.state !== "active" && (
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={pending}
                      onClick={() => run(() => resendApproverInvite({ id: a.id }))}
                    >
                      Resend invite
                    </Button>
                  )}
                  <Button size="sm" variant="outline" onClick={() => setEditingApprover(a.id)}>
                    Edit
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={pending}
                    onClick={() => {
                      if (confirm(`Remove ${a.fullName} from ${dept.name} approvers?`)) {
                        run(() => removeApprover({ id: a.id }));
                      }
                    }}
                  >
                    Remove
                  </Button>
                </span>
              )}
            </li>
          ),
        )}
      </ul>
      {canEdit && (
        <div className="border-t bg-muted/30 px-3 py-2">
          <ApproverForm departmentId={dept.id} pending={pending} run={run} />
        </div>
      )}
    </section>
  );
}

function ApproverForm({
  departmentId,
  approver,
  pending,
  run,
  onCancel,
  onDone,
}: {
  departmentId: string;
  approver?: ApproverRow;
  pending: boolean;
  run: (fn: () => Promise<Result>, after?: () => void) => void;
  onCancel?: () => void;
  onDone?: () => void;
}) {
  return (
    <form
      className="grid gap-2 sm:grid-cols-[1fr_1fr_1.3fr_auto_auto]"
      aria-label={approver ? `Edit ${approver.fullName}` : "Add an approver"}
      onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const f = new FormData(form);
        run(
          () =>
            saveApprover({
              id: approver?.id,
              departmentId,
              fullName: f.get("fullName"),
              jobTitle: f.get("jobTitle") ?? "",
              email: f.get("email"),
              isMain: Boolean(f.get("isMain")),
            }),
          () => {
            form.reset();
            onDone?.();
          },
        );
      }}
    >
      <Input
        name="fullName"
        placeholder="Name"
        aria-label="Name"
        defaultValue={approver?.fullName}
        className="h-9"
        required
      />
      <Input
        name="jobTitle"
        placeholder="Job title"
        aria-label="Job title"
        defaultValue={approver?.jobTitle ?? ""}
        className="h-9"
      />
      <Input
        name="email"
        type="email"
        placeholder="Email"
        aria-label="Email"
        defaultValue={approver?.email}
        className="h-9"
        required
      />
      <label className="flex items-center gap-1.5 text-sm whitespace-nowrap">
        <input type="checkbox" name="isMain" className="size-4" defaultChecked={approver?.isMain} />
        Main approver
      </label>
      <span className="flex gap-1">
        <Button type="submit" disabled={pending} className="h-9">
          {approver ? "Save" : "Add approver"}
        </Button>
        {onCancel && (
          <Button type="button" variant="ghost" className="h-9" onClick={onCancel}>
            Cancel
          </Button>
        )}
      </span>
    </form>
  );
}
