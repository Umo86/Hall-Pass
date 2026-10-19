import { SectionUnavailable } from "@/components/section-unavailable";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Download, Gift, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { Page, PageHeader } from "@/components/page-header";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { formatDate, formatMoney, organisationCurrency, plural } from "@/lib/format";
import { eq, inArray } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { signageItems, sponsors, sponsorshipPackages } from "@/lib/db/schema";
import { sponsorPortalAccess } from "@/lib/users/external";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listSponsorshipRows } from "@/lib/queries/signage";
import { getInlineUrl } from "@/lib/storage";
import { orderCountdown } from "@/lib/countdown";
import { todayInLondon } from "@/lib/today";
import { SponsorsPanel } from "@/components/sponsorship/sponsors-panel";
import { PackagesPanel } from "@/components/sponsorship/packages-panel";
import type { SellSponsor } from "@/components/sponsorship/sell-package-dialog";
import {
  listPackages,
  sponsorEntitlementRows,
  toRevenuePackages,
  type PackageRow,
  type SponsorEntitlementRow,
} from "@/lib/queries/sponsorship-packages";
import {
  packageCards,
  packageCounts,
  sponsorshipRevenue,
  stillToSellNote,
  toSellPackage,
  type PlanEntitlement,
} from "@/lib/domain/sponsorship-packages";
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
 * `?sponsor=`, `?view=`, `?group=`). Packages (`?tab=packages`) are what
 * sponsors buy as a whole, at an agreed price, with revenue beside items.
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
  const tab = rawTab === "sponsors" || rawTab === "packages" ? rawTab : "items";
  const ed = await getEditionByCode(editionCode.toUpperCase(), session);
  if (!ed) notFound();

  const editionId = ed.edition.id;
  const [rows, sponsorRows, packages] = await Promise.all([
    listSponsorshipRows(editionId),
    db
      .select({
        sponsor: sponsors,
        packageName: sponsorshipPackages.name,
        packageArchived: sponsorshipPackages.isArchived,
        packageListPrice: sponsorshipPackages.price,
      })
      .from(sponsors)
      .leftJoin(sponsorshipPackages, eq(sponsorshipPackages.id, sponsors.packageId))
      .where(eq(sponsors.editionId, editionId))
      .orderBy(sponsors.companyName),
    // Every tab: the tab counts and the sell options need them.
    listPackages(db, editionId),
  ]);
  const canExport = can(session.actor, {
    type: "export.run",
    kind: "sponsor_report",
    editionId,
  });
  const readOnly = editionIsReadOnly(ed.edition.status);
  const canAdd = can(session.actor, { type: "sponsorship.create" }) && !readOnly;
  // Recording sales and managing sponsors and packages is its own ability.
  const canSell = can(session.actor, { type: "sponsorship.sell", editionId }) && !readOnly;
  // Prices, costs and sponsor spend only for people who see costs.
  const canSeeCosts = can(session.actor, { type: "costs.view", editionId });
  const currency = organisationCurrency(session.organisation.settings);
  const livePackages = packages.filter((p) => !p.isArchived).length;
  // What can be sold (lanyards, bags…) is a list kept in Settings → Item types.
  const canManageTypes = can(session.actor, { type: "lists.manage" });

  const today = todayInLondon();
  const totals = sponsorshipTotals(rows);

  const tabs = [
    { id: "items", label: `Items (${rows.length})` },
    { id: "packages", label: `Packages (${livePackages})` },
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
          ) : tab === "packages" ? (
            <>
              {canExport && (
                <Button asChild size="sm" variant="outline">
                  <a href={`/api/exports/sponsorship/${ed.edition.code}`}>
                    <Download className="size-4" /> Sponsor report
                  </a>
                </Button>
              )}
              {canSell && (
                <Button asChild size="sm">
                  <Link href={`/${editionCode}/sponsorship?tab=packages&add=1`} scroll={false}>
                    <Plus className="size-4" /> Add package
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
              sponsors={sponsorRows.map((s) => ({
                id: s.sponsor.id,
                name: s.sponsor.companyName,
                packageName: s.packageName,
              }))}
              cards={cards}
              today={today}
            />
          )}
        </>
      )}

      {tab === "packages" && (
        <PackagesTab
          editionId={editionId}
          editionCode={editionCode}
          packages={packages}
          sponsorRows={sponsorRows}
          itemTotals={totals}
          canSell={canSell}
          canSeeCosts={canSeeCosts}
          currency={currency}
        />
      )}

      {tab === "sponsors" && (
        <SponsorsTab
          editionId={editionId}
          editionCode={editionCode}
          sponsorRows={sponsorRows}
          packages={packages}
          canEdit={canSell}
          canSeeCosts={canSeeCosts}
          canInvite={can(session.actor, { type: "partners.invite" })}
          organisationId={session.organisation.id}
          currency={currency}
        />
      )}
    </Page>
  );
}

type SponsorWithPackage = {
  sponsor: typeof sponsors.$inferSelect;
  packageName: string | null;
  packageArchived: boolean | null;
  packageListPrice: string | null;
};

/** The sell dialog's sponsors: each with the package they have and its agreed price. */
function sellSponsors(rows: SponsorWithPackage[], canSeeCosts: boolean): SellSponsor[] {
  return rows.map((r) => ({
    id: r.sponsor.id,
    name: r.sponsor.companyName,
    packageId: r.sponsor.packageId,
    packageName: r.packageName,
    agreedPrice: canSeeCosts ? r.sponsor.packagePrice : null,
    priceNote: canSeeCosts ? r.sponsor.packagePriceNote : null,
  }));
}

function bySponsor(rows: SponsorEntitlementRow[]): Record<string, PlanEntitlement[]> {
  const out: Record<string, PlanEntitlement[]> = {};
  for (const r of rows) (out[r.sponsorId] ??= []).push(r);
  return out;
}

/**
 * Packages: revenue tiles (money only with costs), then a card per package.
 * Revenue is sponsorshipRevenue over the packages and the Items tab's own
 * totals, so the page, dashboard and sponsor report agree.
 */
async function PackagesTab({
  editionId,
  editionCode,
  packages,
  sponsorRows,
  itemTotals,
  canSell,
  canSeeCosts,
  currency,
}: {
  editionId: string;
  editionCode: string;
  packages: PackageRow[];
  sponsorRows: SponsorWithPackage[];
  itemTotals: { sold: number; sales: number };
  canSell: boolean;
  canSeeCosts: boolean;
  currency: string;
}) {
  const entitlementRows = canSell
    ? await sponsorEntitlementRows(
        db,
        sponsorRows.map((r) => r.sponsor.id),
      )
    : [];
  const revenuePackages = toRevenuePackages(packages);
  const revenue = sponsorshipRevenue(revenuePackages, itemTotals);
  const counts = packageCounts(revenuePackages);
  const note = stillToSellNote(revenue);
  const money = (v: number) => formatMoney(v, currency);
  const tiles: { label: string; value: string; sub?: string }[] = canSeeCosts
    ? [
        {
          label: "Packages sold",
          value: String(revenue.packages.sold),
          sub:
            money(revenue.packages.value) +
            (revenue.packages.unpriced > 0
              ? ` · ${revenue.packages.unpriced} ${revenue.packages.unpriced === 1 ? "has" : "have"} no price yet`
              : ""),
        },
        { label: "Items sold", value: String(revenue.items.sold), sub: money(revenue.items.value) },
        { label: "Total revenue", value: money(revenue.total) },
        {
          label: "Still to sell",
          value: money(revenue.remaining.value),
          sub: plural(revenue.remaining.places, "place"),
        },
      ]
    : [
        { label: "Packages sold", value: String(counts.sold) },
        {
          label: "Places left",
          value: String(counts.placesLeft),
          sub: counts.unlimited > 0 ? `${counts.unlimited} with no limit` : undefined,
        },
      ];
  return (
    <>
      {packages.length > 0 && (
        <div className="space-y-1.5">
          <dl
            data-money={canSeeCosts || undefined}
            className="grid grid-cols-2 gap-2 sm:data-[money]:grid-cols-4"
            aria-label="Revenue summary"
          >
            {tiles.map((t) => (
              <div key={t.label} className="min-w-0 rounded-lg border p-3">
                <dt className="text-muted-foreground truncate text-xs">{t.label}</dt>
                <dd className="truncate text-lg font-semibold tabular-nums">{t.value}</dd>
                {t.sub && <dd className="text-muted-foreground truncate text-xs">{t.sub}</dd>}
              </div>
            ))}
          </dl>
          {canSeeCosts && note && <p className="text-muted-foreground text-xs">{note}</p>}
        </div>
      )}
      <PackagesPanel
        editionId={editionId}
        editionCode={editionCode}
        packages={packageCards(packages, { canSeeCosts })}
        canSell={canSell}
        canSeeCosts={canSeeCosts}
        currency={currency}
        sponsors={canSell ? sellSponsors(sponsorRows, canSeeCosts) : []}
        entitlements={bySponsor(entitlementRows)}
      />
    </>
  );
}

async function SponsorsTab({
  editionId,
  editionCode,
  sponsorRows,
  packages,
  canEdit,
  canSeeCosts,
  canInvite,
  organisationId,
  currency,
}: {
  editionId: string;
  editionCode: string;
  sponsorRows: SponsorWithPackage[];
  packages: PackageRow[];
  canEdit: boolean;
  canSeeCosts: boolean;
  canInvite: boolean;
  organisationId: string;
  currency: string;
}) {
  const ids = sponsorRows.map((r) => r.sponsor.id);
  const [items, entitlementRows, access] = ids.length
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
        sponsorEntitlementRows(db, ids),
        // The same answer as the item page: live grants only.
        sponsorPortalAccess(db, organisationId, ids),
      ])
    : [[], [], new Map<string, "access" | "invited">()];
  // Sellers always see costs, so the sell options carry prices.
  const sellPackages = packageCards(packages, { canSeeCosts }).map(toSellPackage);
  return (
    <SponsorsPanel
      editionId={editionId}
      editionCode={editionCode}
      canEdit={canEdit}
      canInvite={canInvite}
      canSeeCosts={canSeeCosts}
      packages={sellPackages}
      currency={currency}
      sponsors={sponsorRows.map(
        ({ sponsor: sp, packageName, packageArchived, packageListPrice }) => {
          const all = items.filter((i) => i.sponsorId === sp.id);
          const live = all.filter((i) => !i.deletedAt);
          const states = live.map((i) => saleState({ ...i, sponsorId: sp.id }));
          const portal = access.get(sp.id) ?? null;
          return {
            id: sp.id,
            companyName: sp.companyName,
            contactName: sp.contactName,
            contactEmail: sp.contactEmail,
            package: sp.packageId
              ? {
                  id: sp.packageId,
                  name: packageName ?? sp.packageName ?? "Package",
                  archived: Boolean(packageArchived),
                  agreedPrice: canSeeCosts ? sp.packagePrice : null,
                  listPrice: canSeeCosts ? packageListPrice : null,
                  note: canSeeCosts ? sp.packagePriceNote : null,
                  soldAt: sp.packageSoldAt ? sp.packageSoldAt.toISOString() : null,
                }
              : null,
            itemCount: live.length,
            soldCount: states.filter((s) => s === "sold").length,
            inPackageCount: states.filter((s) => s === "in_package").length,
            spend: canSeeCosts
              ? live.reduce((n, i) => n + (i.salePrice ? Number(i.salePrice) : 0), 0)
              : 0,
            linked: all.length > 0 || portal !== null || sp.packageId !== null,
            portal,
            entitlements: entitlementRows
              .filter((e) => e.sponsorId === sp.id)
              .map((e) => ({
                id: e.id,
                description: e.description,
                quantity: e.quantity,
                linkedItems: e.linkedItems,
                fromPackageId: e.fromPackageId,
                fromPackageName: e.fromPackageName,
              })),
          };
        },
      )}
    />
  );
}
