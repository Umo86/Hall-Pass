import Link from "next/link";
import { inArray } from "drizzle-orm";
import { Inbox } from "lucide-react";
import { db } from "@/lib/db/client";
import { editions } from "@/lib/db/schema";
import { requirePortalSession } from "@/lib/auth/actor";
import type { ExternalActor } from "@/lib/authz";
import { visibleItemsForExternal } from "@/lib/queries/portal";
import { formatDate, slotLabel, statusLabel } from "@/lib/format";
import { todayInLondon } from "@/lib/today";
import { StatusBadge } from "@/components/status-badge";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SegmentedLinks } from "@/components/ui/segmented";
import { Button } from "@/components/ui/button";
import { SelectNative } from "@/components/ui/select-native";

export const metadata = { title: "My Items" };
export const dynamic = "force-dynamic";

type Row = Awaited<ReturnType<typeof visibleItemsForExternal>>[number];
type PortalEvent = {
  id: string;
  code: string;
  name: string;
  openStart: string;
  upcoming: boolean;
};

/** Is this partner the item's supplier (delivery, install and PO are theirs to see)? */
function suppliesIt(actor: ExternalActor, r: Row): boolean {
  return actor.grants.some(
    (g) =>
      g.role === "supplier" &&
      g.scopeType === "supplier" &&
      g.scopeId != null &&
      g.scopeId === r.item.supplierId &&
      g.editionId === r.item.editionId,
  );
}

function Items({ rows, actor }: { rows: Row[]; actor: ExternalActor }) {
  const supply = rows.some((r) => suppliesIt(actor, r));
  const install = (r: Row) =>
    r.item.installDate
      ? `${formatDate(r.item.installDate)}${r.item.installSlot ? ` ${slotLabel(r.item.installSlot)}` : ""}`
      : "—";
  return (
    <>
      <div className="hidden overflow-x-auto rounded-lg border md:block">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-muted/50 text-muted-foreground border-b text-left">
              <th className="px-3 py-2 font-medium">Ref</th>
              <th className="px-3 py-2 font-medium">Name</th>
              <th className="px-3 py-2 font-medium">Status</th>
              <th className="px-3 py-2 font-medium">Size (mm)</th>
              <th className="px-3 py-2 font-medium">Qty</th>
              <th className="px-3 py-2 font-medium">Material / finish</th>
              <th className="px-3 py-2 font-medium">Fixing</th>
              <th className="px-3 py-2 font-medium">Location</th>
              {supply && (
                <>
                  <th className="px-3 py-2 font-medium">Delivery</th>
                  <th className="px-3 py-2 font-medium">Install</th>
                  <th className="px-3 py-2 font-medium">PO</th>
                </>
              )}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const theirs = suppliesIt(actor, r);
              return (
                <tr key={r.item.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium whitespace-nowrap">
                    <Link
                      href={`/portal/items/${r.item.ref}`}
                      className="text-primary hover:underline"
                    >
                      {r.item.ref}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{r.item.name}</td>
                  <td className="px-3 py-2">
                    <StatusBadge status={r.item.status} />
                  </td>
                  <td className="px-3 py-2">
                    {r.item.widthMm && r.item.heightMm
                      ? `${r.item.widthMm} × ${r.item.heightMm}`
                      : "—"}
                  </td>
                  <td className="px-3 py-2">{r.item.quantity}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {[r.item.material, r.item.finish].filter(Boolean).join(" / ") || "—"}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">
                    {r.item.fixingMethod ? statusLabel(r.item.fixingMethod) : "—"}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">
                    {[r.hallName, r.locationName].filter(Boolean).join(" · ") || "—"}
                  </td>
                  {supply && (
                    <>
                      <td className="px-3 py-2">
                        {theirs ? formatDate(r.item.deliveryDate) : "—"}
                      </td>
                      <td className="px-3 py-2">{theirs ? install(r) : "—"}</td>
                      <td className="px-3 py-2">{theirs ? (r.item.poNumber ?? "—") : "—"}</td>
                    </>
                  )}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <ul className="space-y-2 md:hidden" aria-label="Items">
        {rows.map((r) => {
          const theirs = suppliesIt(actor, r);
          return (
            <li key={r.item.id}>
              <Link
                href={`/portal/items/${r.item.ref}`}
                className="hover:bg-muted/50 block space-y-1 rounded-lg border p-3"
              >
                <span className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-primary text-sm font-medium">{r.item.ref}</span>
                  <StatusBadge status={r.item.status} />
                </span>
                <span className="block text-sm break-words">{r.item.name}</span>
                <span className="text-muted-foreground block text-xs">
                  {[r.hallName, r.locationName].filter(Boolean).join(" · ") || "No location yet"}
                </span>
                {theirs && (
                  <span className="text-muted-foreground block text-xs">
                    Delivery {formatDate(r.item.deliveryDate)} · Install {install(r)}
                    {r.item.poNumber ? ` · PO ${r.item.poNumber}` : ""}
                  </span>
                )}
              </Link>
            </li>
          );
        })}
      </ul>
    </>
  );
}

/**
 * Everything shared with this partner, one event at a time (current and
 * upcoming first), or every event grouped. A supplier sees delivery,
 * install and PO for the items they supply.
 */
export default async function PortalItemsPage({
  searchParams,
}: {
  searchParams: Promise<{ event?: string }>;
}) {
  const session = await requirePortalSession();
  const { event } = await searchParams;
  const actor = session.actor;
  const rows = (await visibleItemsForExternal(actor)).sort((a, b) => a.item.seq - b.item.seq);
  const today = todayInLondon();

  // The events their access is for, soonest upcoming first, then the past ones.
  const editionIds = [...new Set(actor.grants.map((g) => g.editionId))];
  const eventRows = editionIds.length
    ? await db
        .select({
          id: editions.id,
          code: editions.code,
          name: editions.name,
          openStart: editions.openStart,
          openEnd: editions.openEnd,
          status: editions.status,
        })
        .from(editions)
        .where(inArray(editions.id, editionIds))
    : [];
  const all: PortalEvent[] = eventRows.map((e) => ({
    id: e.id,
    code: e.code,
    name: e.name,
    openStart: e.openStart,
    upcoming: e.status !== "archived" && e.openEnd >= today,
  }));
  const events = [
    ...all.filter((e) => e.upcoming).sort((a, b) => a.openStart.localeCompare(b.openStart)),
    ...all.filter((e) => !e.upcoming).sort((a, b) => b.openStart.localeCompare(a.openStart)),
  ];
  const chosen =
    event === "all" ? null : (events.find((e) => e.code === event) ?? events[0] ?? null);
  const supplier = actor.grants.some((g) => g.role === "supplier");
  const inEvent = (id: string) => rows.filter((r) => r.item.editionId === id);
  const shown = chosen ? inEvent(chosen.id) : rows;

  return (
    <Page className="mx-auto">
      <PageHeader
        title="My items"
        description={
          supplier
            ? "Open an item for its spec label and sign-off progress. Artwork is released to suppliers once it is signed off."
            : "Open an item for its artwork, spec label and sign-off progress."
        }
        meta={`${shown.length} ${shown.length === 1 ? "item" : "items"}${chosen ? ` · ${chosen.name}` : ""}`}
      />

      {events.length > 4 ? (
        // Many events (a supplier kept on year after year): a picker, not a row of tabs.
        <form method="get" className="flex flex-wrap items-end gap-2" aria-label="Choose an event">
          <div className="space-y-1">
            <label htmlFor="portal-event" className="text-sm font-medium">
              Event
            </label>
            <SelectNative
              id="portal-event"
              name="event"
              defaultValue={chosen?.code ?? "all"}
              className="h-11 max-w-sm sm:h-9"
            >
              {events.map((e) => (
                <option key={e.id} value={e.code}>
                  {e.name} ({inEvent(e.id).length})
                </option>
              ))}
              <option value="all">All events ({rows.length})</option>
            </SelectNative>
          </div>
          <Button type="submit" variant="outline" className="h-11 sm:h-9">
            Show
          </Button>
        </form>
      ) : events.length > 1 ? (
        <SegmentedLinks
          label="Event"
          items={[
            ...events.map((e) => ({
              label: e.name,
              href: `/portal/items?event=${encodeURIComponent(e.code)}`,
              active: chosen?.id === e.id,
              count: inEvent(e.id).length,
            })),
            {
              label: "All events",
              href: "/portal/items?event=all",
              active: chosen === null,
              count: rows.length,
            },
          ]}
        />
      ) : null}

      {shown.length === 0 ? (
        <EmptyState
          icon={Inbox}
          title={chosen ? `Nothing shared with you for ${chosen.name} yet` : "Nothing shared yet"}
          description="Items appear here as soon as the team links them to you. You are emailed when something needs you."
        />
      ) : chosen ? (
        <Items rows={shown} actor={actor} />
      ) : (
        events
          .filter((e) => inEvent(e.id).length > 0)
          .map((e) => (
            <section key={e.id} className="space-y-2" aria-labelledby={`event-${e.code}`}>
              <h2 id={`event-${e.code}`} className="text-sm font-semibold">
                {e.name}{" "}
                <span className="text-muted-foreground font-normal">
                  · {e.upcoming ? "opens" : "opened"} {formatDate(e.openStart)}
                </span>
              </h2>
              <Items rows={inEvent(e.id)} actor={actor} />
            </section>
          ))
      )}
    </Page>
  );
}
