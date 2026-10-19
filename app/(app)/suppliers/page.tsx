import { cookies } from "next/headers";
import { and, asc, count, eq, inArray, isNotNull, isNull, sql } from "drizzle-orm";
import { editionScopeSql, sessionScope } from "@/lib/queries/edition-scope";
import { SectionUnavailable } from "@/components/section-unavailable";
import { db } from "@/lib/db/client";
import {
  contractors,
  editions,
  events,
  externalGrants,
  signageItems,
  snags,
  supplierServiceLinks,
  supplierServices,
  suppliers,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { pickDefaultEdition } from "@/lib/queries/editions";
import { LAST_EVENT_COOKIE } from "@/components/setup/last-event";
import { SIGNAGE_KINDS } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";
import { formatDate } from "@/lib/format";
import { defaultEventId, externalEvents } from "@/lib/users/external";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { Page } from "@/components/page-header";
import { SuppliersView, type SupplierRow } from "@/components/suppliers/suppliers-view";
import { ContractorsView } from "@/components/suppliers/contractors-view";
import { SuppliersTabs } from "@/components/suppliers/suppliers-tabs";
import { supplierRemoval } from "@/components/suppliers/rules";
import { portalGrantsByScope } from "@/components/portal/grants";

export const metadata = { title: "Suppliers" };
export const dynamic = "force-dynamic";

function one(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}

export default async function SuppliersPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireStaffSession();
  if (!hasFeature(session.actor, "suppliers")) return <SectionUnavailable feature="suppliers" />;
  const orgId = session.organisation.id;
  const canEdit = can(session.actor, { type: "suppliers.manage" });
  const canEditServices = can(session.actor, { type: "lists.manage" });
  const canInvite = can(session.actor, { type: "partners.invite" });
  const params = await searchParams;
  const tab = one(params.tab) === "contractors" ? "contractors" : "suppliers";
  const today = todayInLondon();

  const [[supplierCount], [contractorCount]] = await Promise.all([
    db
      .select({ n: count() })
      .from(suppliers)
      .where(and(eq(suppliers.organisationId, orgId), eq(suppliers.isArchived, false))),
    db.select({ n: count() }).from(contractors).where(eq(contractors.organisationId, orgId)),
  ]);
  const tabs = (
    <SuppliersTabs
      tab={tab}
      suppliers={Number(supplierCount.n)}
      contractors={Number(contractorCount.n)}
    />
  );

  if (tab === "contractors") {
    const rows = await db
      .select()
      .from(contractors)
      .where(eq(contractors.organisationId, orgId))
      .orderBy(asc(contractors.name));
    return (
      <Page>
        <ContractorsView
          tabs={tabs}
          canEdit={canEdit}
          today={today}
          rows={rows.map((c) => ({
            id: c.id,
            name: c.name,
            contactName: c.contactName,
            email: c.email,
            phone: c.phone,
            insuranceExpiry: c.insuranceExpiry,
          }))}
        />
      </Page>
    );
  }

  // The event the "Items on …" column and "Used on …" filter are about.
  const scope = sessionScope(session);
  const editionRows = await db
    .select({
      id: editions.id,
      code: editions.code,
      name: editions.name,
      status: editions.status,
      openStart: editions.openStart,
      openEnd: editions.openEnd,
    })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    // Users → Events: the current event is chosen among theirs.
    .where(and(eq(events.organisationId, orgId), editionScopeSql(scope, editions.id)));
  const lastCode = (await cookies()).get(LAST_EVENT_COOKIE)?.value ?? null;
  const currentCode = pickDefaultEdition(editionRows, { lastCode, today });
  const current = editionRows.find((e) => e.code === currentCode) ?? null;

  const [supplierRows, links, serviceRows, eventCounts, totals, usage, grants, inviteEventList] =
    await Promise.all([
      db
        .select()
        .from(suppliers)
        .where(eq(suppliers.organisationId, orgId))
        .orderBy(asc(suppliers.name)),
      db
        .select({
          supplierId: supplierServiceLinks.supplierId,
          serviceId: supplierServiceLinks.serviceId,
        })
        .from(supplierServiceLinks)
        .innerJoin(suppliers, eq(supplierServiceLinks.supplierId, suppliers.id))
        .where(eq(suppliers.organisationId, orgId)),
      db
        .select({
          id: supplierServices.id,
          name: supplierServices.name,
          isArchived: supplierServices.isArchived,
        })
        .from(supplierServices)
        .where(eq(supplierServices.organisationId, orgId))
        .orderBy(asc(supplierServices.sortOrder), asc(supplierServices.name)),
      // Live signs and sponsorship items on the current event (what its Signage list shows).
      current
        ? db
            .select({ supplierId: signageItems.supplierId, n: count() })
            .from(signageItems)
            .where(
              and(
                eq(signageItems.editionId, current.id),
                isNull(signageItems.deletedAt),
                isNotNull(signageItems.supplierId),
                inArray(signageItems.kind, [...SIGNAGE_KINDS]),
              ),
            )
            .groupBy(signageItems.supplierId)
        : Promise.resolve([] as { supplierId: string | null; n: number }[]),
      db
        .select({
          supplierId: signageItems.supplierId,
          live: sql<number>`count(*) filter (where ${signageItems.deletedAt} is null)`,
          deleted: sql<number>`count(*) filter (where ${signageItems.deletedAt} is not null)`,
        })
        .from(signageItems)
        .innerJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
        .where(eq(suppliers.organisationId, orgId))
        .groupBy(signageItems.supplierId),
      // What else stops an archived supplier being deleted.
      canEdit
        ? Promise.all([
            db
              .select({ supplierId: snags.assignedSupplierId, n: count() })
              .from(snags)
              .innerJoin(suppliers, eq(snags.assignedSupplierId, suppliers.id))
              .where(eq(suppliers.organisationId, orgId))
              .groupBy(snags.assignedSupplierId),
            db
              .select({ supplierId: externalGrants.scopeId, n: count() })
              .from(externalGrants)
              .where(
                and(
                  eq(externalGrants.organisationId, orgId),
                  eq(externalGrants.scopeType, "supplier"),
                ),
              )
              .groupBy(externalGrants.scopeId),
          ])
        : Promise.resolve([[], []] as [
            { supplierId: string | null; n: number }[],
            { supplierId: string | null; n: number }[],
          ]),
      canEdit ? portalGrantsByScope(orgId, "supplier", scope) : Promise.resolve(new Map()),
      // Archived events take no new invitations (the server refuses them too).
      canInvite
        ? externalEvents(db, orgId, today, scope).then((list) => list.filter((e) => !e.archived))
        : Promise.resolve([]),
    ]);

  const activeServices = serviceRows.filter((s) => !s.isArchived);
  const activeIds = new Set(activeServices.map((s) => s.id));
  const order = new Map(activeServices.map((s, i) => [s.id, i]));
  const servicesOf = new Map<string, string[]>();
  for (const l of links) {
    if (!activeIds.has(l.serviceId)) continue;
    servicesOf.set(l.supplierId, [...(servicesOf.get(l.supplierId) ?? []), l.serviceId]);
  }
  const onEvent = new Map(eventCounts.map((c) => [c.supplierId, Number(c.n)]));
  const totalOf = new Map(totals.map((t) => [t.supplierId, t]));
  const [snagCounts, grantCounts] = usage;
  const snagsOf = new Map(snagCounts.map((c) => [c.supplierId, Number(c.n)]));
  const grantsEverOf = new Map(grantCounts.map((c) => [c.supplierId, Number(c.n)]));

  const rows: SupplierRow[] = supplierRows.map((s) => {
    const t = totalOf.get(s.id);
    const myGrants = (grants as Awaited<ReturnType<typeof portalGrantsByScope>>).get(s.id) ?? [];
    const liveGrants = myGrants.filter((g) => g.status !== "expired").length;
    const removal = supplierRemoval(s.name, {
      liveItems: Number(t?.live ?? 0),
      deletedItems: Number(t?.deleted ?? 0),
      snags: snagsOf.get(s.id) ?? 0,
      liveGrants,
      pastGrants: Math.max(0, (grantsEverOf.get(s.id) ?? 0) - liveGrants),
    });
    return {
      id: s.id,
      name: s.name,
      serviceIds: (servicesOf.get(s.id) ?? []).sort((a, b) => order.get(a)! - order.get(b)!),
      contactName: s.contactName,
      email: s.email,
      phone: s.phone,
      notes: s.notes,
      itemsOnEvent: onEvent.get(s.id) ?? 0,
      itemsTotal: Number(t?.live ?? 0),
      isArchived: s.isArchived,
      removal: {
        canDelete: removal.canDelete,
        reason: removal.reason,
        deletedItems: Number(t?.deleted ?? 0),
      },
      grants: myGrants,
    };
  });

  const liveRows = rows.filter((r) => !r.isArchived);
  const servicesWithCounts = activeServices.map((s) => ({
    id: s.id,
    name: s.name,
    supplierCount: liveRows.filter((r) => r.serviceIds.includes(s.id)).length,
  }));
  // How many live suppliers tick each service, archived services included.
  const liveIds = new Set(liveRows.map((r) => r.id));
  const supplierCountOf = new Map<string, number>();
  for (const l of links) {
    if (liveIds.has(l.supplierId)) {
      supplierCountOf.set(l.serviceId, (supplierCountOf.get(l.serviceId) ?? 0) + 1);
    }
  }

  const inviteEvents = inviteEventList.map((e) => ({
    id: e.id,
    label: `${e.name} · ${formatDate(e.openStart)}`,
    upcoming: e.upcoming,
  }));

  return (
    <Page>
      <SuppliersView
        tabs={tabs}
        suppliers={rows}
        services={servicesWithCounts}
        serviceRows={serviceRows.map((s) => ({
          id: s.id,
          name: s.name,
          isArchived: s.isArchived,
          supplierCount: supplierCountOf.get(s.id) ?? 0,
        }))}
        canEdit={canEdit}
        canEditServices={canEditServices}
        canInvite={canInvite}
        emailOn={invitesCanBeEmailed()}
        currentEvent={current ? { code: current.code, name: current.name } : null}
        inviteEvents={inviteEvents}
        defaultEventId={defaultEventId(inviteEventList, current?.code ?? lastCode)}
        openManage={one(params.manage) === "services"}
      />
    </Page>
  );
}
