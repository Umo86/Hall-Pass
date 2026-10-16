"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ChevronRight } from "lucide-react";
import type { PersonStatus } from "@/lib/users/list";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { DepartmentChip } from "./person-fields";
import { InviteActions } from "./invite-actions";
import { ManagerBadge, PersonStatusChip } from "./person-status";
import { BulkOutcomePanel, UsersBulkBar, type BulkUsersOutcome } from "./bulk-bar";

export type TeamListRow = {
  kind: "member" | "invite";
  id: string;
  name: string;
  email: string;
  isSelf: boolean;
  jobTitle: string | null;
  role: string;
  roleText: string;
  /** "Manager · Marketing", or null. */
  managerBadge: string | null;
  departmentName: string | null;
  departmentArchived: boolean;
  sections: string;
  sectionsTitle: string;
  signsOffFor: { name: string; isMain: boolean }[];
  status: PersonStatus;
  statusText: string;
  /** "Today", "3 days ago", "Never signed in"; null for invitations. */
  lastActive: string | null;
  lastActiveTitle: string | null;
  /** The viewer may change this person (a checkbox for the bulk bar). */
  manageable: boolean;
};

function YouTag() {
  return (
    <span className="bg-primary/10 text-primary ml-1.5 rounded px-1.5 py-0.5 text-[11px] font-medium">
      You
    </span>
  );
}

function SignsOff({ list }: { list: TeamListRow["signsOffFor"] }) {
  if (list.length === 0) return <span className="text-muted-foreground">—</span>;
  return (
    <span className="flex flex-wrap gap-1">
      {list.map((s) => (
        <DepartmentChip key={s.name} name={s.name} main={s.isMain} />
      ))}
    </span>
  );
}

function Pick({
  row,
  checked,
  onChange,
}: {
  row: TeamListRow;
  checked: boolean;
  onChange: (on: boolean) => void;
}) {
  return (
    <input
      type="checkbox"
      className="accent-primary size-4"
      checked={checked}
      onChange={(e) => onChange(e.target.checked)}
      aria-label={`Select ${row.name || row.email}`}
    />
  );
}

/**
 * Users → Team: a table on wide screens, one card per person on a phone.
 * People who manage the team can tick the rows they may change and use the
 * bulk bar; the outcome stays on screen, with anyone left alone still ticked.
 */
export function TeamList({
  rows,
  isAdmin,
  emailOn,
}: {
  rows: TeamListRow[];
  isAdmin: boolean;
  emailOn: boolean;
}) {
  const router = useRouter();
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [outcome, setOutcome] = useState<BulkUsersOutcome | null>(null);
  const manageable = useMemo(() => rows.filter((r) => r.manageable), [rows]);
  // Rows can leave the list after a change (filters): keep only ones still shown.
  const picked = manageable.filter((r) => selected.has(r.id));
  const bulk = isAdmin && manageable.length > 0;
  const allOn = picked.length > 0 && picked.length === manageable.length;

  const toggle = (id: string, on: boolean) =>
    setSelected((s) => {
      const next = new Set(s);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });

  // Clicking anywhere on a row opens the person, except on its own buttons and links.
  const onRowClick = (row: TeamListRow) => (e: React.MouseEvent<HTMLElement>) => {
    const target = e.target as HTMLElement;
    // Dialogs opened from a row are portalled elsewhere but still bubble here.
    if (!e.currentTarget.contains(target) || target.closest("a,button,input,label")) return;
    router.push(`/users/${row.id}`);
  };

  return (
    <>
      {outcome && <BulkOutcomePanel outcome={outcome} onClose={() => setOutcome(null)} />}
      {picked.length > 0 && (
        <UsersBulkBar
          picked={picked.map((p) => ({
            id: p.id,
            name: p.name || p.email,
            kind: p.kind,
            status: p.status,
          }))}
          onClear={() => setSelected(new Set())}
          onOutcome={(o) => {
            setOutcome(o);
            // Keep the people left alone selected, so they can be retried.
            const failed = new Set(o.result?.rows.filter((r) => !r.ok).map((r) => r.id) ?? []);
            setSelected(o.result ? failed : new Set(picked.map((p) => p.id)));
          }}
        />
      )}
      <div className="hidden rounded-lg border md:block">
        <Table>
          <TableHeader>
            <TableRow>
              {bulk && (
                <TableHead className="w-10">
                  <input
                    type="checkbox"
                    className="accent-primary size-4"
                    checked={allOn}
                    ref={(el) => {
                      if (el) el.indeterminate = picked.length > 0 && !allOn;
                    }}
                    onChange={(e) =>
                      setSelected(
                        e.target.checked ? new Set(manageable.map((r) => r.id)) : new Set(),
                      )
                    }
                    aria-label="Select everyone you can change on this page"
                  />
                </TableHead>
              )}
              <TableHead>{isAdmin ? "Person" : "Name"}</TableHead>
              <TableHead>Department</TableHead>
              <TableHead>Role</TableHead>
              {isAdmin ? <TableHead>Sections</TableHead> : <TableHead>Email</TableHead>}
              <TableHead>Signs off for</TableHead>
              {isAdmin && <TableHead>Status</TableHead>}
              {isAdmin && <TableHead className="whitespace-nowrap">Last active</TableHead>}
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((r) => (
              <TableRow
                key={r.id}
                className="cursor-pointer"
                onClick={onRowClick(r)}
                data-state={selected.has(r.id) ? "selected" : undefined}
              >
                {bulk && (
                  <TableCell>
                    {r.manageable && (
                      <Pick
                        row={r}
                        checked={selected.has(r.id)}
                        onChange={(on) => toggle(r.id, on)}
                      />
                    )}
                  </TableCell>
                )}
                <TableCell className="max-w-72">
                  <Link href={`/users/${r.id}`} className="font-medium hover:underline">
                    {r.name || r.email}
                  </Link>
                  {r.isSelf && <YouTag />}
                  {isAdmin && (
                    <span className="text-muted-foreground block truncate text-xs">{r.email}</span>
                  )}
                  {r.jobTitle && (
                    <span className="text-muted-foreground block truncate text-xs">
                      {r.jobTitle}
                    </span>
                  )}
                </TableCell>
                <TableCell>
                  {r.departmentName ? (
                    <DepartmentChip name={r.departmentName} archived={r.departmentArchived} />
                  ) : (
                    <span className="text-muted-foreground">—</span>
                  )}
                </TableCell>
                <TableCell>
                  <span className="block whitespace-nowrap">{r.roleText}</span>
                  {r.managerBadge && <ManagerBadge text={r.managerBadge} className="mt-1" />}
                </TableCell>
                {isAdmin ? (
                  <TableCell className="whitespace-nowrap" title={r.sectionsTitle}>
                    {r.sections}
                  </TableCell>
                ) : (
                  <TableCell>
                    <a href={`mailto:${r.email}`} className="link text-sm">
                      {r.email}
                    </a>
                  </TableCell>
                )}
                <TableCell>
                  <SignsOff list={r.signsOffFor} />
                </TableCell>
                {isAdmin && (
                  <TableCell>
                    <div className="flex flex-wrap items-center gap-2">
                      <PersonStatusChip status={r.status} text={r.statusText} />
                      {r.kind === "invite" && r.manageable && (
                        <InviteActions
                          inviteId={r.id}
                          name={r.name}
                          email={r.email}
                          emailOn={emailOn}
                        />
                      )}
                    </div>
                  </TableCell>
                )}
                {isAdmin && (
                  <TableCell
                    className="text-muted-foreground whitespace-nowrap"
                    title={r.lastActiveTitle ?? undefined}
                  >
                    {r.lastActive ?? "—"}
                  </TableCell>
                )}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      <ul className="space-y-2 md:hidden" aria-label="People">
        {rows.map((r) => (
          <li key={r.id} className="flex items-stretch gap-2">
            {bulk && (
              <label className="flex w-11 shrink-0 items-center justify-center rounded-lg border">
                {r.manageable && (
                  <Pick row={r} checked={selected.has(r.id)} onChange={(on) => toggle(r.id, on)} />
                )}
              </label>
            )}
            <Link
              href={`/users/${r.id}`}
              className="hover:bg-muted/40 flex min-h-14 min-w-0 flex-1 items-center gap-3 rounded-lg border p-3"
            >
              <span className="min-w-0 flex-1 space-y-0.5">
                <span className="block font-medium break-words">
                  {r.name || r.email}
                  {r.isSelf && <YouTag />}
                </span>
                <span className="text-muted-foreground block text-sm">
                  {[
                    r.departmentName
                      ? `${r.departmentName}${r.departmentArchived ? " (archived)" : ""}`
                      : "No department",
                    r.roleText,
                  ].join(" · ")}
                </span>
                {r.managerBadge && <ManagerBadge text={r.managerBadge} />}
                {isAdmin ? (
                  <span className="flex flex-wrap items-center gap-x-2 gap-y-1 pt-1">
                    <PersonStatusChip status={r.status} text={r.statusText} />
                    {r.lastActive && (
                      <span className="text-muted-foreground text-xs">
                        Last active: {r.lastActive}
                      </span>
                    )}
                  </span>
                ) : (
                  <span className="text-muted-foreground block truncate text-xs">{r.email}</span>
                )}
              </span>
              <ChevronRight className="text-muted-foreground size-4 shrink-0" aria-hidden />
            </Link>
          </li>
        ))}
      </ul>
    </>
  );
}
