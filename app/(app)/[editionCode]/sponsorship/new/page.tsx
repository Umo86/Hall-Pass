import { SectionUnavailable } from "@/components/section-unavailable";
import { notFound, redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { ItemForm } from "@/components/signage/item-form";
import { Page, PageHeader } from "@/components/page-header";
import { signoffRequiredFields } from "@/lib/domain/signage";

export const metadata = { title: "New sponsorship item" };
export const dynamic = "force-dynamic";

export default async function NewSponsorshipItemPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  if (!can(session.actor, { type: "sponsorship.create" })) redirect("../sponsorship");
  const { editionCode } = await params;
  if (!hasFeature(session.actor, "sponsorship")) {
    return <SectionUnavailable feature="sponsorship" backHref={`/${editionCode}/dashboard`} />;
  }
  const ed = await getEditionByCode(editionCode.toUpperCase(), session);
  if (!ed) notFound();

  const options = await itemFormOptions({
    organisationId: session.organisation.id,
    editionId: ed.edition.id,
    kind: "sponsorship_item",
    withWorkflows: true,
    // "Me (Name)" first in the owner picker, grouped by the viewer's department.
    viewer: {
      id: session.user.id,
      departmentId: session.actor.departmentId ?? null,
    },
  });

  return (
    <Page width="narrow" className="gap-4">
      <PageHeader
        title="New sponsorship item"
        description="What sponsors can buy: what it is, who makes it, what it costs and when it must be ordered. Mark it sold when a sponsor buys it."
        back={{ href: `/${editionCode}/sponsorship`, label: "Sponsorship" }}
      />
      <ItemForm
        mode="create"
        kind="sponsorship_item"
        values={{ editionId: ed.edition.id }}
        options={options}
        requiredFields={signoffRequiredFields("sponsorship_item")}
        canSeeCosts={can(session.actor, { type: "costs.view" })}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        editionCode={editionCode}
      />
    </Page>
  );
}
