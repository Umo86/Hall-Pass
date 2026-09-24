import { notFound } from "next/navigation";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { suppliers } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { listScheduleRows } from "@/lib/queries/signage";
import { ScheduleView } from "@/components/schedule/schedule-view";

export const metadata = { title: "Signage schedule" };
export const dynamic = "force-dynamic";

export default async function SignagePage({
  params,
}: {
  params: Promise<{ editionCode: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) notFound();
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  // Cost figures never leave the server for people who can't see costs.
  const rows = (await listScheduleRows(ed.edition.id)).map((r) =>
    canSeeCosts ? r : { ...r, costEstimate: null, costActual: null, poNumber: null },
  );
  const supplierRows = await db
    .select({ id: suppliers.id, name: suppliers.name })
    .from(suppliers)
    .where(eq(suppliers.organisationId, session.organisation.id));

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">
        Signage schedule{" "}
        <span className="text-muted-foreground text-base font-normal">
          {ed.edition.code} · {rows.length} items
        </span>
      </h1>
      <ScheduleView
        editionCode={ed.edition.code}
        rows={rows}
        suppliers={supplierRows}
        canSeeCosts={canSeeCosts}
        canEdit={can(session.actor, { type: "signage.create" })}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        canDelete={can(session.actor, { type: "signage.delete" })}
      />
    </div>
  );
}
