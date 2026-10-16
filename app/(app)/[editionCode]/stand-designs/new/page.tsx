import { SectionUnavailable } from "@/components/section-unavailable";
import { notFound, redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { standFormOptions } from "@/lib/queries/stand-designs";
import { StandForm } from "@/components/stand-designs/stand-form";
import { Page, PageHeader } from "@/components/page-header";

export const metadata = { title: "New feature stand" };
export const dynamic = "force-dynamic";

export default async function NewStandPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  if (!can(session.actor, { type: "stand_design.create" })) redirect("../stand-designs");
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "stand_designs")) {
    return <SectionUnavailable feature="stand_designs" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  if (editionIsReadOnly(ed.edition.status)) redirect("../stand-designs");
  const options = await standFormOptions({
    organisationId: session.organisation.id,
    editionId: ed.edition.id,
    includeSupplierId: null,
  });

  return (
    <Page width="narrow" className="gap-4">
      <PageHeader
        title="New feature stand"
        description="Set up the stand and choose who approves its design. You'll upload the design next."
        back={{ href: `/${editionCode}/stand-designs`, label: "Feature stands" }}
      />
      <StandForm
        mode="create"
        editionId={ed.edition.id}
        editionCode={editionCode}
        values={{}}
        options={options}
      />
    </Page>
  );
}
