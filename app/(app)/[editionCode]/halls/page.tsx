import { notFound } from "next/navigation";
import { and, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { halls, locations, signageItems } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getEditionByCode } from "@/lib/queries/editions";
import { HallsEditor } from "@/components/halls/halls-editor";

export const metadata = { title: "Halls & locations" };
export const dynamic = "force-dynamic";

export default async function HallsPage({ params }: { params: Promise<{ editionCode: string }> }) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();

  const [hallRows, locationRows, byHall, byLocation] = await Promise.all([
    db
      .select()
      .from(halls)
      .where(eq(halls.editionId, ed.edition.id))
      .orderBy(halls.sortOrder, halls.name),
    db
      .select({ loc: locations })
      .from(locations)
      .innerJoin(halls, eq(locations.hallId, halls.id))
      .where(eq(halls.editionId, ed.edition.id))
      .orderBy(locations.name),
    db
      .select({ id: signageItems.hallId, n: count() })
      .from(signageItems)
      .where(and(eq(signageItems.editionId, ed.edition.id), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.hallId),
    db
      .select({ id: signageItems.locationId, n: count() })
      .from(signageItems)
      .where(and(eq(signageItems.editionId, ed.edition.id), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.locationId),
  ]);
  const hallCounts = new Map(byHall.map((r) => [r.id, Number(r.n)]));
  const locCounts = new Map(byLocation.map((r) => [r.id, Number(r.n)]));
  const canEdit =
    can(session.actor, { type: "settings.manage" }) && !editionIsReadOnly(ed.edition.status);

  return (
    <div className="flex max-w-3xl flex-col gap-4 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Halls &amp; locations</h1>
        <p className="text-muted-foreground text-sm">
          Where signs go at {ed.edition.name}. Every sign needs a hall and a location before it can
          be sent for sign-off.
        </p>
      </div>
      <HallsEditor
        editionId={ed.edition.id}
        canEdit={canEdit}
        halls={hallRows.map((h) => ({
          id: h.id,
          name: h.name,
          itemCount: hallCounts.get(h.id) ?? 0,
          locations: locationRows
            .filter(({ loc }) => loc.hallId === h.id)
            .map(({ loc }) => ({
              id: loc.id,
              name: loc.name,
              zone: loc.zone,
              itemCount: locCounts.get(loc.id) ?? 0,
            })),
        }))}
      />
    </div>
  );
}
