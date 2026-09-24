import { notFound, redirect } from "next/navigation";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  halls,
  itemTypes,
  locations,
  sponsorEntitlements,
  sponsors,
  suppliers,
  workflows,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
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

  const [typeRows, hallRows, locationRows, sponsorRows, entRows, supplierRows, contractorRows, wfRows] =
    await Promise.all([
      db
        .select()
        .from(itemTypes)
        .where(and(eq(itemTypes.organisationId, session.organisation.id), eq(itemTypes.kind, "signage"))),
      db.select().from(halls).where(eq(halls.editionId, ed.edition.id)),
      db
        .select({ id: locations.id, name: locations.name, hallId: locations.hallId })
        .from(locations)
        .innerJoin(halls, eq(locations.hallId, halls.id))
        .where(eq(halls.editionId, ed.edition.id)),
      db.select().from(sponsors).where(eq(sponsors.editionId, ed.edition.id)),
      db
        .select()
        .from(sponsorEntitlements)
        .innerJoin(sponsors, eq(sponsorEntitlements.sponsorId, sponsors.id))
        .where(eq(sponsors.editionId, ed.edition.id)),
      db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
      db.select().from(contractors).where(eq(contractors.organisationId, session.organisation.id)),
      db.select().from(workflows).where(eq(workflows.organisationId, session.organisation.id)),
    ]);

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">New signage item</h1>
      <ItemForm
        mode="create"
        values={{ editionId: ed.edition.id }}
        options={{
          itemTypes: typeRows.map((t) => ({ id: t.id, name: t.name })),
          halls: hallRows.map((h) => ({ id: h.id, name: h.name })),
          locations: locationRows,
          sponsors: sponsorRows.map((sp) => ({ id: sp.id, name: sp.companyName })),
          entitlements: entRows.map((e) => ({
            id: e.sponsor_entitlements.id,
            sponsorId: e.sponsor_entitlements.sponsorId,
            description: e.sponsor_entitlements.description,
          })),
          suppliers: supplierRows.map((sp) => ({ id: sp.id, name: sp.name })),
          contractors: contractorRows.map((c) => ({ id: c.id, name: c.name })),
          workflows: wfRows
            .filter((w) => w.appliesTo === "signage" && !w.isArchived)
            .map((w) => ({ id: w.id, name: w.name })),
        }}
        canSeeCosts={can(session.actor, { type: "costs.view" })}
        canEditCosts={can(session.actor, { type: "costs.edit" })}
        editionCode={editionCode}
      />
    </div>
  );
}
