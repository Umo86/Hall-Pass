import Link from "next/link";
import { notFound } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { hallCopySources, hallsEditorData } from "@/lib/queries/setup";
import { Page, PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { HallsEditor } from "@/components/halls/halls-editor";

export const metadata = { title: "Halls & locations" };
export const dynamic = "force-dynamic";

export default async function HallsPage({ params }: { params: Promise<{ editionCode: string }> }) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();

  const canSetup = can(session.actor, { type: "halls.manage" });
  const canEdit = canSetup && !editionIsReadOnly(ed.edition.status);
  const [data, sources] = await Promise.all([
    hallsEditorData(ed.edition.id),
    canEdit ? hallCopySources(session.organisation.id, ed.edition) : Promise.resolve([]),
  ]);
  const locationCount = data.halls.reduce((n, h) => n + h.locations.length, 0);

  return (
    <Page width="narrow">
      <PageHeader
        title="Halls & locations"
        description={
          canEdit
            ? `Where signs go at ${ed.edition.name}. Every sign needs a hall and a location before it can be sent for sign-off.`
            : `Where signs go at ${ed.edition.name}. Only admins and Operations can add halls.`
        }
        meta={
          data.halls.length > 0
            ? `${data.halls.length} hall${data.halls.length === 1 ? "" : "s"} · ${locationCount} location${locationCount === 1 ? "" : "s"} · ${ed.venue.name}`
            : ed.venue.name
        }
        actions={
          canSetup ? (
            <Button asChild variant="outline" size="sm">
              <Link href={`/${ed.edition.code}/setup`}>Event setup</Link>
            </Button>
          ) : undefined
        }
      />
      <HallsEditor
        editionId={ed.edition.id}
        editionCode={ed.edition.code}
        canEdit={canEdit}
        venueName={ed.venue.name}
        halls={data.halls}
        zones={data.zones}
        copySources={sources}
      />
    </Page>
  );
}
