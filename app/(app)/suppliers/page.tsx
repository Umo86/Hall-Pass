import { and, asc, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  contractors,
  signageItems,
  supplierServiceLinks,
  supplierServices,
  suppliers,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { SuppliersView } from "@/components/suppliers/suppliers-view";
import { DirectorySection } from "@/components/settings/directory-section";

export const metadata = { title: "Suppliers" };
export const dynamic = "force-dynamic";

export default async function SuppliersPage() {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  const canEdit = can(session.actor, { type: "settings.manage" });

  const [supplierRows, links, services, itemCounts, contractorRows] = await Promise.all([
    db
      .select()
      .from(suppliers)
      .where(eq(suppliers.organisationId, orgId))
      .orderBy(asc(suppliers.name)),
    db
      .select({
        supplierId: supplierServiceLinks.supplierId,
        serviceId: supplierServiceLinks.serviceId,
      })
      .from(supplierServiceLinks)
      .innerJoin(suppliers, eq(supplierServiceLinks.supplierId, suppliers.id))
      .where(eq(suppliers.organisationId, orgId)),
    db
      .select({ id: supplierServices.id, name: supplierServices.name })
      .from(supplierServices)
      .where(
        and(eq(supplierServices.organisationId, orgId), eq(supplierServices.isArchived, false)),
      )
      .orderBy(asc(supplierServices.sortOrder), asc(supplierServices.name)),
    db
      .select({ supplierId: signageItems.supplierId, n: count() })
      .from(signageItems)
      .innerJoin(suppliers, eq(signageItems.supplierId, suppliers.id))
      .where(and(eq(suppliers.organisationId, orgId), isNull(signageItems.deletedAt)))
      .groupBy(signageItems.supplierId),
    db
      .select()
      .from(contractors)
      .where(eq(contractors.organisationId, orgId))
      .orderBy(asc(contractors.name)),
  ]);

  const activeServices = new Set(services.map((s) => s.id));
  const servicesOf = new Map<string, string[]>();
  for (const l of links) {
    if (!activeServices.has(l.serviceId)) continue;
    servicesOf.set(l.supplierId, [...(servicesOf.get(l.supplierId) ?? []), l.serviceId]);
  }
  const countOf = new Map(itemCounts.map((c) => [c.supplierId, Number(c.n)]));
  const order = new Map(services.map((s, i) => [s.id, i]));

  return (
    <div className="flex max-w-6xl flex-col gap-6 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Suppliers</h1>
        <p className="text-muted-foreground text-sm">
          The companies you work with and what each one can do — signage, screens, staffing and
          more.
        </p>
      </div>
      <SuppliersView
        suppliers={supplierRows.map((s) => ({
          id: s.id,
          name: s.name,
          serviceIds: (servicesOf.get(s.id) ?? []).sort((a, b) => order.get(a)! - order.get(b)!),
          contactName: s.contactName,
          email: s.email,
          phone: s.phone,
          notes: s.notes,
          itemCount: countOf.get(s.id) ?? 0,
        }))}
        services={services}
        canEdit={canEdit}
      />

      <section className="space-y-2">
        <div>
          <h2 className="text-sm font-semibold">Install contractors</h2>
          <p className="text-muted-foreground text-sm">
            Crews who put signage up on site — chosen per item under Dates &amp; install.
          </p>
        </div>
        <DirectorySection
          type="contractor"
          noun="Contractor"
          canEdit={canEdit}
          fields={[
            { key: "name", label: "Name", required: true, listed: true },
            { key: "contactName", label: "Contact name", listed: true },
            { key: "email", label: "Email", type: "email", listed: true },
            { key: "phone", label: "Phone" },
            { key: "insuranceExpiry", label: "Insurance expires", type: "date", listed: true },
          ]}
          rows={contractorRows.map((c) => ({
            id: c.id,
            name: c.name,
            contactName: c.contactName,
            email: c.email,
            phone: c.phone,
            insuranceExpiry: c.insuranceExpiry,
          }))}
        />
      </section>
    </div>
  );
}
