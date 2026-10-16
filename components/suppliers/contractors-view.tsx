"use client";

import { useState } from "react";
import { HardHat, Mail, Pencil, Phone, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import {
  DirectoryDialog,
  type DirectoryField,
  type DirectoryRow,
} from "@/components/settings/directory-section";
import { formatDate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { insuranceStatus } from "./rules";

export type ContractorRow = {
  id: string;
  name: string;
  contactName: string | null;
  email: string | null;
  phone: string | null;
  insuranceExpiry: string | null;
};

const FIELDS: DirectoryField[] = [
  { key: "name", label: "Company name", required: true, placeholder: "Stand Builders Ltd" },
  { key: "contactName", label: "Contact name" },
  { key: "email", label: "Email", type: "email" },
  { key: "phone", label: "Phone", type: "tel" },
  { key: "insuranceExpiry", label: "Insurance expires", type: "date" },
];

function Insurance({ expiry, today }: { expiry: string | null; today: string }) {
  const status = insuranceStatus(expiry, today);
  if (status.tone === "none") return <span className="text-muted-foreground">Not given</span>;
  return (
    <span className="inline-flex flex-wrap items-center gap-1.5">
      <span className="whitespace-nowrap">{formatDate(expiry)}</span>
      {status.label && (
        <span
          className={cn(
            "rounded-md px-1.5 py-0.5 text-xs font-medium whitespace-nowrap",
            status.tone === "expired"
              ? "bg-red-50 text-red-800 dark:bg-red-950 dark:text-red-300"
              : "bg-amber-50 text-amber-900 dark:bg-amber-950 dark:text-amber-300",
          )}
        >
          {status.label}
        </span>
      )}
    </span>
  );
}

/** Suppliers → Install contractors: the crews who put signage up on site. */
export function ContractorsView({
  rows,
  canEdit,
  today,
  tabs,
}: {
  rows: ContractorRow[];
  canEdit: boolean;
  /** Today in London (YYYY-MM-DD), for the insurance warnings. */
  today: string;
  tabs: React.ReactNode;
}) {
  const [editing, setEditing] = useState<DirectoryRow | "new" | null>(null);
  const expired = rows.filter((r) => insuranceStatus(r.insuranceExpiry, today).tone === "expired");

  return (
    <>
      <PageHeader
        title="Suppliers"
        description="The companies you work with, what each one does and how to reach them."
        actions={
          canEdit && (
            <Button onClick={() => setEditing("new")}>
              <Plus aria-hidden /> Add install contractor
            </Button>
          )
        }
      />
      {tabs}
      <p className="text-muted-foreground -mt-2 max-w-prose text-sm">
        Crews who put signage up on site. You choose one per item under More details on the item
        form.
        {expired.length > 0 &&
          ` ${expired.length === 1 ? "One contractor's" : `${expired.length} contractors'`} insurance has expired — check it before they go on site.`}
      </p>

      {rows.length === 0 ? (
        <EmptyState
          icon={HardHat}
          title="No install contractors yet"
          description="Add the crews who install your signage, with their insurance expiry date so you can see when it needs checking."
          action={
            canEdit && (
              <Button onClick={() => setEditing("new")}>
                <Plus aria-hidden /> Add install contractor
              </Button>
            )
          }
        />
      ) : (
        <>
          <div className="hidden rounded-lg border sm:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Company</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Email / phone</TableHead>
                  <TableHead>Insurance expires</TableHead>
                  {canEdit && (
                    <TableHead className="w-12">
                      <span className="sr-only">Edit</span>
                    </TableHead>
                  )}
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-medium">{r.name}</TableCell>
                    <TableCell>
                      {r.contactName ?? <span className="text-muted-foreground">—</span>}
                    </TableCell>
                    <TableCell>
                      <span className="flex flex-col">
                        {r.email && (
                          <a href={`mailto:${r.email}`} className="break-all hover:underline">
                            {r.email}
                          </a>
                        )}
                        {r.phone && (
                          <a
                            href={`tel:${r.phone.replace(/\s+/g, "")}`}
                            className="hover:underline"
                          >
                            {r.phone}
                          </a>
                        )}
                        {!r.email && !r.phone && <span className="text-muted-foreground">—</span>}
                      </span>
                    </TableCell>
                    <TableCell>
                      <Insurance expiry={r.insuranceExpiry} today={today} />
                    </TableCell>
                    {canEdit && (
                      <TableCell>
                        <Button
                          size="icon"
                          variant="ghost"
                          onClick={() => setEditing(r)}
                          aria-label={`Edit ${r.name}`}
                        >
                          <Pencil aria-hidden />
                        </Button>
                      </TableCell>
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          <ul className="space-y-2 sm:hidden" aria-label="Install contractors">
            {rows.map((r) => (
              <li
                key={r.id}
                className="flex items-start justify-between gap-2 rounded-lg border p-3"
              >
                <div className="min-w-0 space-y-1 text-sm">
                  <p className="font-semibold break-words">{r.name}</p>
                  {r.contactName && <p>{r.contactName}</p>}
                  {r.email && (
                    <a
                      href={`mailto:${r.email}`}
                      className="flex min-h-9 items-center gap-1.5 break-all hover:underline"
                    >
                      <Mail className="text-muted-foreground size-3.5 shrink-0" aria-hidden />
                      {r.email}
                    </a>
                  )}
                  {r.phone && (
                    <a
                      href={`tel:${r.phone.replace(/\s+/g, "")}`}
                      className="flex min-h-9 items-center gap-1.5 hover:underline"
                    >
                      <Phone className="text-muted-foreground size-3.5 shrink-0" aria-hidden />
                      {r.phone}
                    </a>
                  )}
                  <p className="text-muted-foreground text-xs">
                    Insurance: <Insurance expiry={r.insuranceExpiry} today={today} />
                  </p>
                </div>
                {canEdit && (
                  <Button
                    size="touch"
                    variant="ghost"
                    onClick={() => setEditing(r)}
                    aria-label={`Edit ${r.name}`}
                  >
                    <Pencil aria-hidden />
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </>
      )}
      {canEdit && (
        <DirectoryDialog
          type="contractor"
          noun="install contractor"
          fields={FIELDS}
          current={editing === "new" ? null : editing}
          open={editing !== null}
          onClose={() => setEditing(null)}
        />
      )}
    </>
  );
}
