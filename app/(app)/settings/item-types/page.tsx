import { and, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { itemTypes, signageItems } from "@/lib/db/schema";
import { PageHeader } from "@/components/page-header";
import { SectionLocked, settingsAccess } from "@/components/settings/access";
import { ItemTypesEditor } from "@/components/settings/item-types-editor";

export const metadata = { title: "Item types · Settings" };
export const dynamic = "force-dynamic";

export default async function ItemTypesPage() {
  const { session, canOpen, canManage } = await settingsAccess();
  const header = (
    <PageHeader
      title="Item types"
      description="What people pick from when they add a sign or a sponsorship item. Archiving a type takes it off the list; items already using it keep it."
    />
  );
  if (!canOpen("item-types")) {
    return (
      <>
        {header}
        <SectionLocked id="item-types" />
      </>
    );
  }
  const orgId = session.organisation.id;
  const [types, used] = await Promise.all([
    db
      .select()
      .from(itemTypes)
      .where(eq(itemTypes.organisationId, orgId))
      .orderBy(itemTypes.sortOrder, itemTypes.name),
    db
      .select({ typeId: signageItems.itemTypeId, n: count() })
      .from(signageItems)
      .innerJoin(itemTypes, eq(signageItems.itemTypeId, itemTypes.id))
      .where(and(eq(itemTypes.organisationId, orgId), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.itemTypeId),
  ]);
  const usedBy = new Map(used.map((u) => [u.typeId, Number(u.n)]));
  return (
    <>
      {header}
      <ItemTypesEditor
        canEdit={canManage}
        rows={types.map((t) => ({
          id: t.id,
          name: t.name,
          kind: t.kind as "signage" | "sponsorship_item",
          format: t.format,
          defaultFixingMethod: t.defaultFixingMethod,
          requiresVenueApprovalDefault: t.requiresVenueApprovalDefault,
          isArchived: t.isArchived,
          itemCount: usedBy.get(t.id) ?? 0,
        }))}
      />
    </>
  );
}
