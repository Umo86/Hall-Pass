import Link from "next/link";
import { notFound } from "next/navigation";
import { Download, Gift, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { formatDate, formatMoney } from "@/lib/format";
import { and, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { signageItems, sponsorEntitlements, sponsors } from "@/lib/db/schema";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listSponsorshipRows } from "@/lib/queries/signage";
import { getInlineUrl } from "@/lib/storage";
import { orderCountdown } from "@/lib/countdown";
import { todayInLondon } from "@/lib/today";
import { SponsorsPanel } from "@/components/sponsorship/sponsors-panel";
import { SponsorshipCards, type SponsorshipCard } from "@/components/sponsorship/sponsorship-cards";

export const metadata = { title: "Sponsorship" };
export const dynamic = "force-dynamic";

/**
 * Sponsorship: what's for sale to sponsors (bags, lanyards, branding) as
 * cards — photo, prices, supplier and the order-by countdown — plus the
 * sponsors themselves. Detail pages are shared with signage.
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
  const { tab: rawTab } = await searchParams;
  const tab = rawTab === "sponsors" ? "sponsors" : "items";
  const ed = await getEditionByCode(editionCode.toUpperCase());
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
  const canAdd =
    can(session.actor, { type: "sponsorship.create" }) && !editionIsReadOnly(ed.edition.status);

  const today = todayInLondon();
  const sold = rows.filter((r) => r.sponsorId);
  const available = rows.filter((r) => !r.sponsorId);
  const sum = (list: typeof rows, key: "salePrice" | "costEstimate") =>
    list.reduce((n, r) => n + (r[key] ? Number(r[key]) : 0), 0);
  const salesTotal = sum(sold, "salePrice");
  // Profit only where a sale price has been entered.
  const priced = sold.filter((r) => r.salePrice != null);
  const profitTotal = sum(priced, "salePrice") - sum(priced, "costEstimate");
  const toSellSoon = available.filter(
    (r) => r.orderByDate && orderCountdown(r.orderByDate, today, false).warning,
  ).length;

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
            const isSold = Boolean(r.sponsorId);
            return {
              id: r.id,
              ref: r.ref,
              name: r.name,
              href: `/${editionCode}/${r.kind === "sponsorship_item" ? "sponsorship" : "signage"}/${r.ref}`,
              kind: r.kind,
              typeName: r.typeName,
              quantity: r.quantity,
              status: r.status,
              supplierName: r.supplierName,
              sponsorName: r.sponsorName,
              sold: isSold,
              costEstimate: r.costEstimate,
              salePrice: r.salePrice,
              imageUrl,
              orderByLabel: r.orderByDate ? formatDate(r.orderByDate) : null,
              countdown: r.orderByDate ? orderCountdown(r.orderByDate, today, isSold) : null,
            };
          }),
        )
      : [];

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Sponsorship</h1>
          <p className="text-muted-foreground text-sm">
            What&apos;s for sale to sponsors, what&apos;s sold, and when each item must be ordered.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
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
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Sponsorship sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={
              t.id === "items"
                ? `/${editionCode}/sponsorship`
                : `/${editionCode}/sponsorship?tab=${t.id}`
            }
            className={`px-3 py-2 text-sm whitespace-nowrap ${
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      {tab === "items" && (
        <>
          <dl className="grid grid-cols-2 gap-2 sm:grid-cols-4" aria-label="Sales summary">
            {[
              ["Available", String(available.length)],
              ["Sold", String(sold.length)],
              ["Sales", formatMoney(salesTotal)],
              ["Profit on sales", formatMoney(profitTotal)],
            ].map(([label, value]) => (
              <div key={label} className="rounded-lg border p-3">
                <dt className="text-muted-foreground text-xs">{label}</dt>
                <dd className="text-lg font-semibold">{value}</dd>
              </div>
            ))}
          </dl>
          {toSellSoon > 0 && (
            <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm font-medium">
              {toSellSoon} unsold item{toSellSoon === 1 ? " has" : "s have"} less than a month
              before the order date.
            </p>
          )}
          {rows.length === 0 ? (
            <div className="border-border text-muted-foreground flex h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-sm">
              <Gift className="size-6 opacity-50" aria-hidden />
              Nothing for sale yet.
              {canAdd && (
                <Button size="sm" variant="outline" asChild>
                  <Link href={`/${editionCode}/sponsorship/new`}>Add the first item</Link>
                </Button>
              )}
            </div>
          ) : (
            <SponsorshipCards
              canSell={canAdd}
              sponsors={sponsorRows.map((s) => ({ id: s.id, name: s.companyName }))}
              cards={cards}
            />
          )}
        </>
      )}

      {tab === "sponsors" && (
        <SponsorsTab editionId={ed.edition.id} sponsorRows={sponsorRows} canEdit={canAdd} />
      )}
    </div>
  );
}

async function SponsorsTab({
  editionId,
  sponsorRows,
  canEdit,
}: {
  editionId: string;
  sponsorRows: (typeof sponsors.$inferSelect)[];
  canEdit: boolean;
}) {
  const ids = sponsorRows.map((sp) => sp.id);
  const [items, entitlementRows] = ids.length
    ? await Promise.all([
        db
          .select({ sponsorId: signageItems.sponsorId, salePrice: signageItems.salePrice })
          .from(signageItems)
          .where(and(inArray(signageItems.sponsorId, ids), isNull(signageItems.deletedAt))),
        db.select().from(sponsorEntitlements).where(inArray(sponsorEntitlements.sponsorId, ids)),
      ])
    : [[], []];
  return (
    <SponsorsPanel
      editionId={editionId}
      canEdit={canEdit}
      sponsors={sponsorRows.map((sp) => {
        const bought = items.filter((i) => i.sponsorId === sp.id);
        return {
          id: sp.id,
          companyName: sp.companyName,
          contactName: sp.contactName,
          contactEmail: sp.contactEmail,
          packageName: sp.packageName,
          itemCount: bought.length,
          spend: bought.reduce((n, i) => n + (i.salePrice ? Number(i.salePrice) : 0), 0),
          entitlements: entitlementRows
            .filter((e) => e.sponsorId === sp.id)
            .map((e) => ({ description: e.description, quantity: e.quantity })),
        };
      })}
    />
  );
}
