import Link from "next/link";
import { and, count, desc, eq, inArray, isNotNull } from "drizzle-orm";
import { Trash2 } from "lucide-react";
import { db } from "@/lib/db/client";
import { auditLog, editions, events, signageItems, users } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { formatDateTime, plural } from "@/lib/format";
import { PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { RestoreItemButton } from "@/components/signage/restore-item-button";
import { SectionLocked, settingsAccess } from "@/components/settings/access";
import { RecycleBinFilter } from "@/components/settings/recycle-bin-filter";

export const metadata = { title: "Recycle bin · Settings" };
export const dynamic = "force-dynamic";

const PAGE = 50;

const KIND_LABELS: Record<string, string> = {
  signage: "Sign",
  sponsorship_item: "Sponsorship item",
  stand_design: "Feature stand",
  stand_panel: "Stand panel",
};

function one(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}

/** Deleted items from every event, newest first, with an event filter. */
export default async function RecycleBinPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { session, canOpen } = await settingsAccess();
  const header = (
    <PageHeader
      title="Recycle bin"
      description="Deleted signs, sponsorship items and stands from every event. Restore one to put it back as it was; its ref is never reused."
    />
  );
  if (!canOpen("recycle-bin")) {
    return (
      <>
        {header}
        <SectionLocked id="recycle-bin" />
      </>
    );
  }
  const params = await searchParams;
  const orgId = session.organisation.id;
  const canRestore = can(session.actor, { type: "signage.restore" });
  const limit = Math.min(1000, Math.max(PAGE, Number(one(params.limit)) || PAGE));

  // Events with something deleted, for the filter.
  const perEvent = await db
    .select({ id: editions.id, code: editions.code, name: editions.name, n: count() })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(events.organisationId, orgId), isNotNull(signageItems.deletedAt)))
    .groupBy(editions.id, editions.code, editions.name)
    .orderBy(desc(editions.code));
  const wanted = one(params.event)?.toUpperCase();
  const chosen = perEvent.find((e) => e.code === wanted) ?? null;
  const total = chosen ? Number(chosen.n) : perEvent.reduce((n, e) => n + Number(e.n), 0);

  const rows = await db
    .select({
      id: signageItems.id,
      ref: signageItems.ref,
      name: signageItems.name,
      kind: signageItems.kind,
      deletedAt: signageItems.deletedAt,
      eventCode: editions.code,
      eventName: editions.name,
      eventStatus: editions.status,
    })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(events.organisationId, orgId),
        isNotNull(signageItems.deletedAt),
        chosen ? eq(editions.id, chosen.id) : undefined,
      ),
    )
    .orderBy(desc(signageItems.deletedAt))
    .limit(limit);

  // Who deleted each one, from the audit log.
  const deletes = rows.length
    ? await db
        .select({
          entityId: auditLog.entityId,
          name: users.fullName,
          email: users.email,
        })
        .from(auditLog)
        .leftJoin(users, eq(auditLog.actorUserId, users.id))
        .where(
          and(
            eq(auditLog.organisationId, orgId),
            eq(auditLog.entityType, "signage_item"),
            eq(auditLog.action, "soft_delete"),
            inArray(
              auditLog.entityId,
              rows.map((r) => r.id),
            ),
          ),
        )
        .orderBy(desc(auditLog.createdAt))
    : [];
  const by = new Map<string, string | null>();
  for (const d of deletes) {
    if (d.entityId && !by.has(d.entityId)) by.set(d.entityId, d.name || d.email || null);
  }
  const more = total - rows.length;
  const moreHref = `/settings/recycle-bin?${new URLSearchParams({
    ...(chosen ? { event: chosen.code } : {}),
    limit: String(limit + PAGE),
  }).toString()}`;

  const restore = (r: (typeof rows)[number]) =>
    !canRestore ? null : editionIsReadOnly(r.eventStatus) ? (
      <span className="text-muted-foreground text-xs">Event archived</span>
    ) : (
      <RestoreItemButton itemId={r.id} itemRef={r.ref} />
    );

  return (
    <>
      {header}
      {perEvent.length > 0 && (
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <RecycleBinFilter
            value={chosen?.code ?? ""}
            events={perEvent.map((e) => ({ code: e.code, name: e.name, count: Number(e.n) }))}
          />
          {chosen && (
            <Link href={`/${chosen.code}/signage/deleted`} className="link text-sm">
              Open {chosen.code}&rsquo;s Recently deleted
            </Link>
          )}
        </div>
      )}
      {rows.length === 0 ? (
        <EmptyState
          icon={Trash2}
          title="The recycle bin is empty"
          description="Items deleted from any event appear here, so they can be put back."
        />
      ) : (
        <>
          <p className="text-muted-foreground -mt-2 text-sm">
            {plural(total, "deleted item")}
            {chosen ? ` on ${chosen.code}` : ""}
            {!canRestore && " · only Operations and admins can restore them"}
          </p>
          <div className="hidden rounded-lg border md:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Ref</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead>Kind</TableHead>
                  <TableHead>Event</TableHead>
                  <TableHead>Deleted by</TableHead>
                  <TableHead>When</TableHead>
                  {canRestore && (
                    <TableHead>
                      <span className="sr-only">Restore</span>
                    </TableHead>
                  )}
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-medium whitespace-nowrap">{r.ref}</TableCell>
                    <TableCell className="max-w-72 break-words">{r.name}</TableCell>
                    <TableCell className="whitespace-nowrap">
                      {KIND_LABELS[r.kind] ?? r.kind}
                    </TableCell>
                    <TableCell>
                      <Link
                        href={`/${r.eventCode}/signage/deleted`}
                        className="link whitespace-nowrap"
                        title={r.eventName}
                      >
                        {r.eventCode}
                      </Link>
                    </TableCell>
                    <TableCell className="whitespace-nowrap">{by.get(r.id) ?? "—"}</TableCell>
                    <TableCell className="whitespace-nowrap">
                      {formatDateTime(r.deletedAt)}
                    </TableCell>
                    {canRestore && <TableCell className="text-right">{restore(r)}</TableCell>}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          <ul className="space-y-2 md:hidden" aria-label="Deleted items">
            {rows.map((r) => (
              <li
                key={r.id}
                className="flex items-start justify-between gap-3 rounded-lg border p-3 text-sm"
              >
                <div className="min-w-0">
                  <p className="font-medium">{r.ref}</p>
                  <p className="line-clamp-2 break-words">{r.name}</p>
                  <p className="text-muted-foreground text-xs">
                    {KIND_LABELS[r.kind] ?? r.kind} ·{" "}
                    <Link href={`/${r.eventCode}/signage/deleted`} className="link">
                      {r.eventCode}
                    </Link>{" "}
                    · deleted {formatDateTime(r.deletedAt)}
                    {by.get(r.id) ? ` by ${by.get(r.id)}` : ""}
                  </p>
                </div>
                {restore(r)}
              </li>
            ))}
          </ul>
          {more > 0 && (
            <div className="flex justify-center">
              <Button asChild variant="outline">
                <Link href={moreHref} scroll={false}>
                  Show {Math.min(PAGE, more)} more ({more} not shown)
                </Link>
              </Button>
            </div>
          )}
        </>
      )}
    </>
  );
}
