import { SectionUnavailable } from "@/components/section-unavailable";
import { notFound } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { listOnsiteRows } from "@/lib/queries/signage";
import { stepIsMine } from "@/lib/domain/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getInlineUrl } from "@/lib/storage";
import { todayInLondon } from "@/lib/today";
import { Page, PageHeader } from "@/components/page-header";
import { OnsiteChecklist, type OnsiteCard } from "@/components/onsite/onsite-checklist";
import { onsiteAction } from "@/components/onsite/rules";

export const metadata = { title: "Onsite" };
export const dynamic = "force-dynamic";

/**
 * The onsite checklist: what arrives and goes up today, tick it off (with a
 * photo where required), report damage and snags on the spot, mark them
 * fixed, close what's done. Built for a phone in a hall.
 */
export default async function OnsitePage({ params }: { params: Promise<{ editionCode: string }> }) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "onsite")) {
    return <SectionUnavailable feature="onsite" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const readOnly = editionIsReadOnly(ed.edition.status);
  const rows = await listOnsiteRows(ed.edition.id);
  const canSnag = can(session.actor, { type: "snag.manage" }) && !readOnly;
  const canClose = can(session.actor, { type: "signage.close" }) && !readOnly;
  const canUndoClose = canClose && can(session.actor, { type: "signage.reopen" });
  const photoRequired = session.organisation.settings.install_photo_required;
  const actor = session.actor;

  const cards: OnsiteCard[] = await Promise.all(
    rows.map(async (r) => {
      const p = r.pendingConfirmation;
      const canDecide =
        !readOnly &&
        p !== null &&
        can(actor, {
          type: "approval.decide",
          step: {
            assignedRole: p.assignedRole,
            assignedUserId: p.assignedUserId,
            assignedDepartmentId: p.assignedDepartmentId,
            stepKind: "confirmation",
            entity: {
              type: "signage_item",
              item: {
                organisationId: session.organisation.id,
                editionId: ed.edition.id,
                venueId: ed.venue.id,
                kind: r.kind as "signage",
                status: r.status,
                ...r.authz,
              },
            },
          },
        });
      return {
        id: r.id,
        ref: r.ref,
        name: r.name,
        kind: r.kind,
        status: r.status,
        hallId: r.hallId,
        hallName: r.hallName,
        locationName: r.locationName,
        standNumber: r.standNumber,
        installDate: r.installDate,
        installSlot: r.installSlot,
        contractorName: r.contractorName,
        supplierName: r.supplierName,
        installedAt: r.installedAt,
        openSnags: r.openSnags,
        snags: await Promise.all(
          r.openSnagList.map(async (s) => ({
            id: s.id,
            description: s.description,
            severity: s.severity,
            photoUrl: s.photoPath?.includes("/")
              ? await getInlineUrl("photos", s.photoPath).catch(() => null)
              : null,
          })),
        ),
        expectedLockedVersionId: r.currentArtworkVersionId,
        action: onsiteAction({
          kind: r.kind,
          status: r.status,
          photoForSigns: photoRequired,
          pending: p
            ? {
                id: p.id,
                stepName: p.stepName,
                isInstall: p.isInstall,
                who: p.who,
                canDecide,
                viewerHolds:
                  actor.kind === "staff" &&
                  stepIsMine(
                    {
                      stepKind: "confirmation",
                      assignedRole: p.assignedRole,
                      assignedUserId: p.assignedUserId,
                      assignedDepartmentId: p.assignedDepartmentId,
                    },
                    actor,
                  ),
              }
            : null,
        }),
      };
    }),
  );

  return (
    <Page width="default" className="gap-4">
      <PageHeader
        title="Onsite"
        description="Tick off deliveries and installs as they happen, report damage and snags on the spot, close what's done."
        meta={ed.edition.code}
      />
      <OnsiteChecklist
        editionCode={ed.edition.code}
        cards={cards}
        today={todayInLondon()}
        canSnag={canSnag}
        canClose={canClose}
        canUndoClose={canUndoClose}
      />
    </Page>
  );
}
