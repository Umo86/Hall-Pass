import Link from "next/link";
import { notFound } from "next/navigation";
import { Download, Gift, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/status-badge";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { formatDate, formatMoney } from "@/lib/format";
import { and, count, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { signageItems, sponsorEntitlements, sponsors } from "@/lib/db/schema";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listSponsorshipRows } from "@/lib/queries/signage";
import { SponsorsPanel } from "@/components/sponsorship/sponsors-panel";

export const metadata = { title: "Sponsorship items" };
export const dynamic = "force-dynamic";

/**
 * The sponsorship register: sold deliverables (bags, lanyards, branding)
 * managed by sales and ops. Detail pages are shared with signage — the same
 * sign-off chain, artwork versions and comments apply.
 */
export default async function SponsorshipPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) notFound();

  const [rows, sponsorRows, itemCounts] = await Promise.all([
    listSponsorshipRows(ed.edition.id),
    db.select().from(sponsors).where(eq(sponsors.editionId, ed.edition.id)).orderBy(sponsors.companyName),
    db
      .select({ sponsorId: signageItems.sponsorId, n: count() })
      .from(signageItems)
      .where(and(eq(signageItems.editionId, ed.edition.id), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.sponsorId),
  ]);
  const entitlementRows = sponsorRows.length
    ? await db
        .select()
        .from(sponsorEntitlements)
        .where(inArray(sponsorEntitlements.sponsorId, sponsorRows.map((sp) => sp.id)))
    : [];
  const counts = new Map(itemCounts.map((r) => [r.sponsorId, Number(r.n)]));
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const canExport = can(session.actor, { type: "export.run", kind: "sponsor_report" });
  const canAdd =
    can(session.actor, { type: "sponsorship.create" }) && !editionIsReadOnly(ed.edition.status);

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Sponsorship items</h1>
          <p className="text-muted-foreground text-sm">
            Sold deliverables — branded bags, lanyards and venue branding — with the same
            artwork sign-off as signage.
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
                <Plus className="size-4" /> Add sponsorship item
              </Link>
            </Button>
          )}
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-sm">
          <Gift className="size-6 opacity-50" aria-hidden />
          No sponsorship items yet.
          {canAdd && (
            <Button size="sm" variant="outline" asChild>
              <Link href={`/${editionCode}/sponsorship/new`}>Add the first item</Link>
            </Button>
          )}
        </div>
      ) : (
        <div className="max-h-[70vh] overflow-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted sticky top-0 z-10">
              <tr className="text-muted-foreground border-b text-left">
                <th className="px-3 py-2 font-medium">Ref</th>
                <th className="px-3 py-2 font-medium">Name</th>
                <th className="px-3 py-2 font-medium">Type</th>
                <th className="px-3 py-2 font-medium">Sponsor</th>
                <th className="px-3 py-2 font-medium">Status</th>
                <th className="px-3 py-2 font-medium">Qty</th>
                <th className="px-3 py-2 font-medium">Artwork</th>
                <th className="px-3 py-2 font-medium">Artwork due</th>
                {canSeeCosts && <th className="px-3 py-2 font-medium">Estimate</th>}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-muted/30 border-b last:border-0">
                  <td className="px-3 py-2 font-medium whitespace-nowrap">
                    <Link href={`/${editionCode}/sponsorship/${r.ref}`} className="hover:underline">
                      {r.ref}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{r.name}</td>
                  <td className="text-muted-foreground px-3 py-2">{r.typeName ?? "—"}</td>
                  <td className="px-3 py-2">{r.sponsorName ?? "—"}</td>
                  <td className="px-3 py-2">
                    <StatusBadge status={r.status} />
                  </td>
                  <td className="px-3 py-2">{r.quantity}</td>
                  <td className="px-3 py-2">{r.currentVersion ? `v${r.currentVersion}` : "—"}</td>
                  <td className="px-3 py-2 whitespace-nowrap">
                    {r.artworkDueOverride ? formatDate(r.artworkDueOverride) : "—"}
                  </td>
                  {canSeeCosts && <td className="px-3 py-2">{formatMoney(r.costEstimate)}</td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <SponsorsPanel
        editionId={ed.edition.id}
        canEdit={canAdd}
        sponsors={sponsorRows.map((sp) => ({
          id: sp.id,
          companyName: sp.companyName,
          contactName: sp.contactName,
          contactEmail: sp.contactEmail,
          packageName: sp.packageName,
          itemCount: counts.get(sp.id) ?? 0,
          entitlements: entitlementRows
            .filter((e) => e.sponsorId === sp.id)
            .map((e) => ({ description: e.description, quantity: e.quantity })),
        }))}
      />
    </div>
  );
}
