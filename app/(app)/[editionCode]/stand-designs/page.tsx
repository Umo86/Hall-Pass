import { SectionUnavailable } from "@/components/section-unavailable";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Box, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { Page, PageHeader } from "@/components/page-header";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { listStandDesigns } from "@/lib/queries/stand-designs";
import { standChip, standNextLine } from "@/lib/domain/stand-designs";
import { StandList, type StandListCard } from "@/components/stand-designs/stand-list";
import { plural } from "@/lib/format";

export const metadata = { title: "Feature stands" };
export const dynamic = "force-dynamic";

/**
 * Feature stands: the stands the organiser designs and builds. Each card
 * says what's next — upload the design, its sign-off, then its panels — and
 * opens the tab where that happens.
 */
export default async function StandDesignsPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "stand_designs")) {
    return <SectionUnavailable feature="stand_designs" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const stands = await listStandDesigns(ed.edition.id);
  const canCreate =
    can(session.actor, { type: "stand_design.create" }) && !editionIsReadOnly(ed.edition.status);

  const cards: StandListCard[] = stands.map((s) => {
    const next = standNextLine({
      status: s.status,
      hasDesign: s.designVersion != null,
      waitingOn: s.waitingOn.map((w) => w.who ?? w.name),
      panels: s.panels,
    });
    return {
      id: s.id,
      ref: s.ref,
      name: s.name,
      status: s.status,
      href: `/${editionCode}/stand-designs/${s.ref}?tab=${next.tab}`,
      standNumber: s.standNumber,
      hallName: s.hallName,
      sponsorName: s.sponsorName,
      size: s.size,
      previewUrl: s.previewUrl,
      designVersion: s.designVersion,
      chip: standChip(s.status, s.designVersion != null),
      // An overdue sign-off reads as a warning.
      next: s.waitingOn.some((w) => w.overdue) ? { ...next, tone: "warning" } : next,
      // Before the design is approved, panels may already be listed.
      panelsNote:
        next.tab === "artwork" && s.panels.total > 0
          ? `${plural(s.panels.total, "panel")} listed`
          : null,
    };
  });

  return (
    <Page width="full" className="max-w-7xl gap-4">
      <PageHeader
        title="Feature stands"
        description="Stands we design and build: the team approves each design, then the graphics for every panel."
        actions={
          canCreate && (
            <Button asChild size="sm">
              <Link href={`/${editionCode}/stand-designs/new`}>
                <Plus className="size-4" /> New stand
              </Link>
            </Button>
          )
        }
      />

      {stands.length === 0 ? (
        <EmptyState
          icon={Box}
          title="No feature stands yet"
          description="Create a stand, choose who approves it and upload the design. List its panels whenever you like; their graphics go for sign-off once the design is approved."
          action={
            canCreate && (
              <Button size="sm" asChild>
                <Link href={`/${editionCode}/stand-designs/new`}>
                  <Plus className="size-4" /> Create the first stand
                </Link>
              </Button>
            )
          }
        />
      ) : (
        <StandList cards={cards} />
      )}
    </Page>
  );
}
