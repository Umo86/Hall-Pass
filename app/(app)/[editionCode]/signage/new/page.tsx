import { notFound, redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { itemFormOptions } from "@/lib/queries/item-form-options";
import { ItemForm } from "@/components/signage/item-form";

export const metadata = { title: "New signage item" };
export const dynamic = "force-dynamic";

export default async function NewItemPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  if (!can(session.actor, { type: "signage.create" })) redirect("../signage");
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) notFound();

  const options = await itemFormOptions({
    organisationId: session.organisation.id,
    editionId: ed.edition.id,
    kind: "signage",
    withWorkflows: true,
  });

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">New signage item</h1>
      <ItemForm
        mode="create"
        values={{ editionId: ed.edition.id }}
        options={options}
        canSeeCosts={can(session.actor, { type: "costs.view" })}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        editionCode={editionCode}
      />
    </div>
  );
}
