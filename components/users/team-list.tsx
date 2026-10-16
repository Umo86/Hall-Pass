"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { roleLabel } from "@/lib/format";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { cn } from "@/lib/utils";
import { DepartmentChip } from "./person-fields";
import { InviteActions } from "./invite-actions";

export type TeamListRow = {
  kind: "member" | "invite";
  id: string;
  name: string;
  email: string;
  isSelf: boolean;
  jobTitle: string | null;
  role: string;
  departmentName: string | null;
  departmentArchived: boolean;
  sections: string;
  sectionsTitle: string;
  signsOffFor: { name: string; isMain: boolean }[];
  status: "active" | "invited" | "expired" | "suspended" | "ended";
  statusText: string;
};

function StatusChip({ row }: { row: TeamListRow }) {
  const tone =
    row.status === "active"
      ? "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
      : row.status === "invited"
        ? "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300"
        : "bg-amber-50 text-amber-900 dark:bg-amber-950 dark:text-amber-300";
  return (
    <span className={cn("inline-flex rounded-md px-2 py-0.5 text-xs font-medium", tone)}>
      {row.statusText}
    </span>
  );
}

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

/** Users → Team: a table on wide screens, one card per person on a phone. */
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
  const open = (row: TeamListRow) => router.push(`/users/${row.id}`);
  // Clicking anywhere on a row opens the person, except on its own buttons and links.
  const onRowClick = (row: TeamListRow) => (e: React.MouseEvent<HTMLElement>) => {
    const target = e.target as HTMLElement;
    // Dialogs opened from a row are portalled elsewhere but still bubble here.
    if (!e.currentTarget.contains(target) || target.closest("a,button,input")) return;
    open(row);
  };

  return (
    <>
      <div className="hidden rounded-lg border md:block">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{isAdmin ? "Person" : "Name"}</TableHead>
              <TableHead>Department</TableHead>
              <TableHead>Role</TableHead>
              {isAdmin ? <TableHead>Sections</TableHead> : <TableHead>Email</TableHead>}
              <TableHead>Signs off for</TableHead>
              {isAdmin && <TableHead>Status</TableHead>}
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id} className="cursor-pointer" onClick={onRowClick(r)}>
                <TableCell className="max-w-72">
                  <Link href={`/users/${r.id}`} className="font-medium hover:underline">
                    {r.name || r.email}
                  </Link>
                  {r.isSelf && <YouTag />}
                  {isAdmin && (
                    <span className="text-muted-foreground block truncate text-xs">{r.email}</span>
                  )}
                  {!isAdmin && r.jobTitle && (
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
                <TableCell className="whitespace-nowrap">{roleLabel(r.role)}</TableCell>
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
                      <StatusChip row={r} />
                      {r.kind === "invite" && (
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
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      <ul className="space-y-2 md:hidden" aria-label="People">
        {rows.map((r) => (
          <li key={r.id}>
            <Link
              href={`/users/${r.id}`}
              className="hover:bg-muted/40 flex min-h-14 items-center gap-3 rounded-lg border p-3"
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
                    roleLabel(r.role),
                  ].join(" · ")}
                </span>
                {isAdmin ? (
                  r.kind === "invite" && (
                    <span className="block pt-1">
                      <StatusChip row={r} />
                    </span>
                  )
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
