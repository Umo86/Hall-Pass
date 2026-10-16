import { SectionUnavailable } from "@/components/section-unavailable";
import { notFound, redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode, editionForDeadlines } from "@/lib/queries/editions";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { signoffRequiredFields } from "@/lib/domain/signage";
import { effectiveDeadline } from "@/lib/deadlines";
import { Page, PageHeader } from "@/components/page-header";
import { ItemForm } from "@/components/signage/item-form";

export const metadata = { title: "New sign" };
export const dynamic = "force-dynamic";

export default async function NewItemPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  if (!can(session.actor, { type: "signage.create" })) redirect("../signage");
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "signage")) {
    return <SectionUnavailable feature="signage" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();

  const [options, deadlines] = await Promise.all([
    itemFormOptions({
      organisationId: session.organisation.id,
      editionId: ed.edition.id,
      kind: "signage",
      withWorkflows: true,
    }),
    editionForDeadlines(ed.edition.id),
  ]);

  return (
    <Page width="narrow" className="max-w-4xl">
      <PageHeader
        back={{ href: `/${ed.edition.code}/signage`, label: "Signage" }}
        title="New sign"
        description="What it is, where it goes and its size. The artwork comes next; everything else can wait."
      />
      <ItemForm
        mode="create"
        values={{ editionId: ed.edition.id }}
        options={options}
        canSeeCosts={can(session.actor, { type: "costs.view" })}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        editionCode={ed.edition.code}
        requiredFields={signoffRequiredFields("signage")}
        eventArtworkDue={deadlines ? effectiveDeadline(deadlines, "artwork_due") : null}
      />
    </Page>
  );
}
