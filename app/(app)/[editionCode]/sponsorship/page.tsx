import { SectionUnavailable } from "@/components/section-unavailable";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Download, Gift, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { Page, PageHeader } from "@/components/page-header";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { formatDate, formatMoney } from "@/lib/format";
import { and, count, eq, gt, inArray, isNull, or } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { externalGrants, signageItems, sponsorEntitlements, sponsors } from "@/lib/db/schema";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listSponsorshipRows } from "@/lib/queries/signage";
import { getInlineUrl } from "@/lib/storage";
import { orderCountdown } from "@/lib/countdown";
import { todayInLondon } from "@/lib/today";
import { SponsorsPanel } from "@/components/sponsorship/sponsors-panel";
import { SponsorshipCards, type SponsorshipCard } from "@/components/sponsorship/sponsorship-cards";
import { itemPath } from "@/lib/edition-path";
import {
  notOrderedYet,
  saleState,
  sponsorshipNextLine,
  sponsorshipStage,
  sponsorshipTotals,
} from "@/lib/domain/sponsorship";
import { cn } from "@/lib/utils";

export const metadata = { title: "Sponsorship" };
export const dynamic = "force-dynamic";

/**
 * Sponsorship: what's for sale to sponsors (bags, lanyards, branding) — each
 * with its stage and what happens next — plus the sponsors themselves.
 * Detail pages are shared with signage. Filters live in the address
 * (`?filter=available|sold|in_package|overdue|soon|urgent`, `?q=`,
 * `?sponsor=`, `?view=`, `?group=`).
 */
export default async function SponsorshipPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "sponsorship")) {
    return <SectionUnavailable feature="sponsorship" backHref={`/${editionCode}/dashboard`} />;
  }
  const { tab: rawTab } = await searchParams;
  const tab = rawTab === "sponsors" ? "sponsors" : "items";
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();

  const [rows, sponsorRows] = await Promise.all([
    listSponsorshipRows(ed.edition.id),
    db
      .select()
      .from(sponsors)
      .where(eq(sponsors.editionId, ed.edition.id))
      .orderBy(sponsors.companyName),
  ]);
  const canExport = can(session.actor, { type: "export.run", kind: "sponsor_report" });
  const readOnly = editionIsReadOnly(ed.edition.status);
  const canAdd = can(session.actor, { type: "sponsorship.create" }) && !readOnly;
  // Recording sales and managing sponsors and packages is its own ability.
  const canSell = can(session.actor, { type: "sponsorship.sell" }) && !readOnly;
  // Prices, costs and sponsor spend only for people who see costs.
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  // What can be sold (lanyards, bags…) is a list kept in Settings → Item types.
  const canManageTypes = can(session.actor, { type: "lists.manage" });

  const today = todayInLondon();
  const totals = sponsorshipTotals(rows);

  const tabs = [
    { id: "items", label: `Items (${rows.length})` },
    { id: "sponsors", label: `Sponsors (${sponsorRows.length})` },
  ];

  const cards =
    tab === "items"
      ? await Promise.all(
          rows.map(async (r): Promise<SponsorshipCard> => {
            const imagePath = r.photoPath ?? r.previewPath;
            const imageUrl = imagePath?.includes("/")
              ? await getInlineUrl(r.photoPath ? "photos" : "artwork", imagePath).catch(() => null)
              : null;
            const sale = saleState(r);
            const stage = sponsorshipStage({
              kind: r.kind,
              sponsorId: r.sponsorId,
              hasArtwork: r.currentVersion != null,
              status: r.status,
              previousStatus: r.previousStatus,
            });
            return {
              id: r.id,
              ref: r.ref,
              name: r.name,
              href: itemPath(editionCode, r),
              kind: r.kind,
              typeName: r.typeName,
              quantity: r.quantity,
              status: r.status,
              supplierName: r.supplierName,
              sponsorId: r.sponsorId,
              sponsorName: r.sponsorName,
              sale,
              stage,
              next: sponsorshipNextLine({
                stage,
                status: r.status,
                orderByDate: r.orderByDate,
                today,
                sponsorName: r.sponsorName,
                supplierName: r.supplierName,
                waitingOn: r.waitingOn,
              }),
              costEstimate: canSeeCosts ? r.costEstimate : null,
              salePrice: canSeeCosts ? r.salePrice : null,
              imageUrl,
              orderByDate: r.orderByDate,
              orderByLabel: r.orderByDate ? formatDate(r.orderByDate) : null,
              // Once ordered, the order-by date no longer counts down.
              countdown:
                r.orderByDate && notOrderedYet(stage)
                  ? orderCountdown(r.orderByDate, today, sale !== "available")
                  : null,
            };
          }),
        )
      : [];

  // Counts three to a row on a phone, money two to a row.
  const countTiles: [string, string, string?][] = [
    ["Available", String(totals.available)],
    ["Sold", String(totals.sold)],
    ...(totals.inPackage > 0
      ? ([
          ["In packages", String(totals.inPackage), "Sponsor signage that comes with a package"],
        ] as [string, string, string][])
      : []),
  ];
  const moneyTiles: [string, string][] = canSeeCosts
    ? [
        ["Sales", formatMoney(totals.sales)],
        ["Profit on sales", formatMoney(totals.profit)],
      ]
    : [];

  return (
    <Page width="full" className="max-w-7xl gap-4">
      <PageHeader
        title="Sponsorship"
        description="What's for sale to sponsors, what's sold, and when each item must be ordered."
        meta={
          tab === "items" && canManageTypes ? (
            <Link href="/settings/item-types#sponsorship" className="link">
              Manage item types
            </Link>
          ) : undefined
        }
        actions={
          tab === "items" ? (
            <>
              {canExport && (
                <Button asChild size="sm" variant="outline">
                  <a href={`/api/exports/sponsorship/${ed.edition.code}`}>
                    <Download className="size-4" /> Sponsor report
                  </a>
                </Button>
              )}
              {canAdd && (
                <Button asChild size="sm">
                  <Link href={`/${editionCode}/sponsorship/new`}>
                    <Plus className="size-4" /> Add item
                  </Link>
                </Button>
              )}
            </>
          ) : (
            canSell && (
              <Button asChild size="sm">
                <Link href={`/${editionCode}/sponsorship?tab=sponsors&add=1`} scroll={false}>
                  <Plus className="size-4" /> Add sponsor
                </Link>
              </Button>
            )
          )
        }
      />

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Sponsorship sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={
              t.id === "items"
                ? `/${editionCode}/sponsorship`
                : `/${editionCode}/sponsorship?tab=${t.id}`
            }
            className={cn(
              "inline-flex min-h-11 items-center px-3 text-sm whitespace-nowrap sm:min-h-9",
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground",
            )}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      {tab === "items" && (
        <>
          <dl
            className={cn(
              "grid grid-cols-6 gap-2",
              countTiles.length === 3 ? "sm:grid-cols-5" : "sm:grid-cols-4",
            )}
            aria-label="Sales summary"
          >
            {countTiles.map(([label, value, hint]) => (
              <div
                key={label}
                className={cn(
                  "rounded-lg border p-3 sm:col-span-1",
                  countTiles.length === 3 ? "col-span-2" : "col-span-3",
                )}
                title={hint}
              >
                <dt className="text-muted-foreground truncate text-xs">{label}</dt>
                <dd className="text-lg font-semibold">{value}</dd>
              </div>
            ))}
            {moneyTiles.map(([label, value]) => (
              <div key={label} className="col-span-3 rounded-lg border p-3 sm:col-span-1">
                <dt className="text-muted-foreground truncate text-xs">{label}</dt>
                <dd className="text-lg font-semibold">{value}</dd>
              </div>
            ))}
          </dl>
          {rows.length === 0 ? (
            <EmptyState
              icon={Gift}
              title="Nothing for sale yet"
              description="Add what sponsors can buy — bags, lanyards, branding — with its cost and the date it must be ordered by."
              action={
                canAdd && (
                  <Button size="sm" asChild>
                    <Link href={`/${editionCode}/sponsorship/new`}>
                      <Plus className="size-4" /> Add the first item
                    </Link>
                  </Button>
                )
              }
            />
          ) : (
            <SponsorshipCards
              canSell={canSell}
              sponsors={sponsorRows.map((s) => ({ id: s.id, name: s.companyName }))}
              cards={cards}
              today={today}
            />
          )}
        </>
      )}

      {tab === "sponsors" && (
        <SponsorsTab
          editionId={ed.edition.id}
          editionCode={editionCode}
          sponsorRows={sponsorRows}
          canEdit={canSell}
          canSeeCosts={canSeeCosts}
          canInvite={can(session.actor, { type: "partners.invite" })}
        />
      )}
    </Page>
  );
}

async function SponsorsTab({
  editionId,
  editionCode,
  sponsorRows,
  canEdit,
  canSeeCosts,
  canInvite,
}: {
  editionId: string;
  editionCode: string;
  sponsorRows: (typeof sponsors.$inferSelect)[];
  canEdit: boolean;
  canSeeCosts: boolean;
  canInvite: boolean;
}) {
  const ids = sponsorRows.map((sp) => sp.id);
  const now = new Date();
  const [items, entitlementRows, entitlementLinks, grants] = ids.length
    ? await Promise.all([
        // Every item pointing at a sponsor, deleted ones too: they block removal.
        db
          .select({
            sponsorId: signageItems.sponsorId,
            kind: signageItems.kind,
            salePrice: signageItems.salePrice,
            deletedAt: signageItems.deletedAt,
          })
          .from(signageItems)
          .where(inArray(signageItems.sponsorId, ids)),
        db
          .select()
          .from(sponsorEntitlements)
          .where(inArray(sponsorEntitlements.sponsorId, ids))
          .orderBy(sponsorEntitlements.createdAt),
        db
          .select({ id: signageItems.sponsorEntitlementId, n: count() })
          .from(signageItems)
          .innerJoin(
            sponsorEntitlements,
            eq(signageItems.sponsorEntitlementId, sponsorEntitlements.id),
          )
          .where(inArray(sponsorEntitlements.sponsorId, ids))
          .groupBy(signageItems.sponsorEntitlementId),
        db
          .select({ scopeId: externalGrants.scopeId, acceptedAt: externalGrants.acceptedAt })
          .from(externalGrants)
          .where(
            and(
              eq(externalGrants.scopeType, "sponsor"),
              inArray(externalGrants.scopeId, ids),
              isNull(externalGrants.revokedAt),
              or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, now)),
            ),
          ),
      ])
    : [[], [], [], []];
  const linkedByEnt = new Map(entitlementLinks.map((l) => [l.id, Number(l.n)]));
  return (
    <SponsorsPanel
      editionId={editionId}
      editionCode={editionCode}
      canEdit={canEdit}
      canInvite={canInvite}
      sponsors={sponsorRows.map((sp) => {
        const all = items.filter((i) => i.sponsorId === sp.id);
        const live = all.filter((i) => !i.deletedAt);
        const states = live.map((i) => saleState({ ...i, sponsorId: sp.id }));
        const theirGrants = grants.filter((g) => g.scopeId === sp.id);
        return {
          id: sp.id,
          companyName: sp.companyName,
          contactName: sp.contactName,
          contactEmail: sp.contactEmail,
          packageName: sp.packageName,
          itemCount: live.length,
          soldCount: states.filter((s) => s === "sold").length,
          inPackageCount: states.filter((s) => s === "in_package").length,
          spend: canSeeCosts
            ? live.reduce((n, i) => n + (i.salePrice ? Number(i.salePrice) : 0), 0)
            : 0,
          linked: all.length > 0 || theirGrants.length > 0,
          portal: theirGrants.some((g) => g.acceptedAt)
            ? "access"
            : theirGrants.length > 0
              ? "invited"
              : null,
          entitlements: entitlementRows
            .filter((e) => e.sponsorId === sp.id)
            .map((e) => ({
              id: e.id,
              description: e.description,
              quantity: e.quantity,
              linkedItems: linkedByEnt.get(e.id) ?? 0,
            })),
        };
      })}
    />
  );
}
