import { notFound, redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { standFormOptions } from "@/lib/queries/stand-designs";
import { StandForm } from "@/components/stand-designs/stand-form";

export const metadata = { title: "New stand" };
export const dynamic = "force-dynamic";

export default async function NewStandPage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  if (!can(session.actor, { type: "stand_design.create" })) redirect("../stand-designs");
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  if (editionIsReadOnly(ed.edition.status)) redirect("../stand-designs");
  const options = await standFormOptions({
    organisationId: session.organisation.id,
    editionId: ed.edition.id,
  });

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">New stand</h1>
        <p className="text-muted-foreground text-sm">
          Set up the stand and choose who approves its design. You&apos;ll upload the design next.
        </p>
      </div>
      <StandForm
        mode="create"
        editionId={ed.edition.id}
        editionCode={editionCode}
        values={{}}
        options={options}
      />
    </div>
  );
}
