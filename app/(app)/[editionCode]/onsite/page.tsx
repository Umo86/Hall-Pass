import { notFound } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { listOnsiteRows } from "@/lib/queries/signage";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { todayInLondon } from "@/lib/today";
import { OnsiteChecklist, type OnsiteCard } from "@/components/onsite/onsite-checklist";

export const metadata = { title: "Onsite" };
export const dynamic = "force-dynamic";

/**
 * The onsite checklist: what to install today, tick it off with a photo,
 * raise a snag on the spot, close what's done. Built for a phone in a hall.
 */
export default async function OnsitePage({ params }: { params: Promise<{ editionCode: string }> }) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const readOnly = editionIsReadOnly(ed.edition.status);
  const rows = await listOnsiteRows(ed.edition.id);
  const canSnag = can(session.actor, { type: "snag.manage" }) && !readOnly;
  const canClose = can(session.actor, { type: "signage.close" }) && !readOnly;
  const photoRequired = session.organisation.settings.install_photo_required;

  const cards: OnsiteCard[] = rows.map((r) => {
    const canConfirm =
      !readOnly &&
      r.installInstance !== null &&
      can(session.actor, {
        type: "approval.decide",
        step: {
          assignedRole: r.installInstance.assignedRole,
          assignedUserId: r.installInstance.assignedUserId,
          assignedDepartmentId: r.installInstance.assignedDepartmentId,
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
      installedAt: r.installedAt,
      openSnags: r.openSnags,
      confirm:
        canConfirm && r.installInstance
          ? {
              instanceId: r.installInstance.id,
              expectedLockedVersionId: r.currentArtworkVersionId,
              requiresPhoto: photoRequired && r.kind === "signage",
            }
          : null,
    };
  });

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Onsite</h1>
        <p className="text-muted-foreground text-sm">
          {ed.edition.code} · tick each sign off as it goes up, raise snags on the spot.
        </p>
      </div>
      <OnsiteChecklist
        editionCode={ed.edition.code}
        cards={cards}
        today={todayInLondon()}
        canSnag={canSnag}
        canClose={canClose}
      />
    </div>
  );
}
