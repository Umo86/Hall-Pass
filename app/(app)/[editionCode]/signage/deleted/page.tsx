import { notFound } from "next/navigation";
import { Trash2 } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { listDeletedItems } from "@/lib/queries/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { formatDateTime, plural } from "@/lib/format";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SectionUnavailable } from "@/components/section-unavailable";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { RestoreItemButton } from "@/components/signage/restore-item-button";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ editionCode: string }> }) {
  const { editionCode } = await params;
  return { title: `Recently deleted · ${editionCode.toUpperCase()}` };
}

const KIND_LABELS: Record<string, string> = {
  signage: "Sign",
  sponsorship_item: "Sponsorship item",
  stand_design: "Feature stand",
  stand_panel: "Stand panel",
};

/**
 * An event's deleted signs, sponsorship items and stands, with who deleted
 * each and when; Operations and admins can put any of them back.
 */
export default async function DeletedItemsPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "signage")) {
    return <SectionUnavailable feature="signage" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const canRestore =
    can(session.actor, { type: "signage.restore" }) && !editionIsReadOnly(ed.edition.status);
  const rows = can(session.actor, { type: "signage.restore" })
    ? await listDeletedItems(ed.edition.id)
    : [];

  return (
    <Page width="default">
      <PageHeader
        back={{ href: `/${ed.edition.code}/signage`, label: "Signage" }}
        title="Recently deleted"
        description={`Deleted signs, sponsorship items and stands for ${ed.edition.name}. Restore one to put it back as it was; its ref is never reused.`}
        meta={rows.length > 0 ? plural(rows.length, "item") : undefined}
      />
      {!can(session.actor, { type: "signage.restore" }) ? (
        <EmptyState
          icon={Trash2}
          title="Only Operations or an admin can see deleted items"
          description="Ask them if something you need has gone missing."
        />
      ) : rows.length === 0 ? (
        <EmptyState
          icon={Trash2}
          title="Nothing deleted"
          description="Items deleted from this event appear here, so they can be put back."
        />
      ) : (
        <>
          <div className="hidden rounded-lg border sm:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Ref</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead>Kind</TableHead>
                  <TableHead>Deleted by</TableHead>
                  <TableHead>When</TableHead>
                  {canRestore && <TableHead className="sr-only">Restore</TableHead>}
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-medium whitespace-nowrap">{r.ref}</TableCell>
                    <TableCell>{r.name}</TableCell>
                    <TableCell>{KIND_LABELS[r.kind] ?? r.kind}</TableCell>
                    <TableCell>{r.deletedBy ?? "—"}</TableCell>
                    <TableCell className="whitespace-nowrap">
                      {formatDateTime(r.deletedAt)}
                    </TableCell>
                    {canRestore && (
                      <TableCell className="text-right">
                        <RestoreItemButton itemId={r.id} itemRef={r.ref} />
                      </TableCell>
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          <ul className="space-y-2 sm:hidden" aria-label="Deleted items">
            {rows.map((r) => (
              <li
                key={r.id}
                className="flex items-start justify-between gap-3 rounded-lg border p-3 text-sm"
              >
                <div className="min-w-0">
                  <p className="font-medium">{r.ref}</p>
                  <p className="line-clamp-2">{r.name}</p>
                  <p className="text-muted-foreground text-xs">
                    {KIND_LABELS[r.kind] ?? r.kind} · deleted {formatDateTime(r.deletedAt)}
                    {r.deletedBy ? ` by ${r.deletedBy}` : ""}
                  </p>
                </div>
                {canRestore && <RestoreItemButton itemId={r.id} itemRef={r.ref} />}
              </li>
            ))}
          </ul>
        </>
      )}
    </Page>
  );
}
