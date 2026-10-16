import { and, asc, count, desc, eq, isNotNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editions,
  events,
  itemTypes,
  signageItems,
  supplierServiceLinks,
  supplierServices,
  venues,
} from "@/lib/db/schema";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { formatDateTime } from "@/lib/format";
import { DirectorySection } from "@/components/settings/directory-section";
import { ItemTypesEditor } from "@/components/settings/item-types-editor";
import { ServicesEditor } from "@/components/settings/services-editor";
import { RestoreItemButton } from "@/components/settings/restore-button";
import { blobEnabled, s3Enabled, s3Probe, storageBackend } from "@/lib/storage";
import { StoragePanel } from "@/components/settings/storage-panel";

export const metadata = { title: "Settings" };
export const dynamic = "force-dynamic";

type TabId = "types" | "services" | "venues" | "deleted" | "storage";

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireStaffSession();
  const canManage = can(session.actor, { type: "settings.manage" });
  const canUsers = can(session.actor, { type: "users.manage" });
  const tabs: { id: TabId; label: string }[] = [
    ...(canManage || canUsers
      ? ([
          { id: "types", label: "Signage types" },
          { id: "services", label: "Supplier services" },
          { id: "venues", label: "Venues" },
          { id: "deleted", label: "Deleted items" },
        ] as { id: TabId; label: string }[])
      : []),
    ...(canUsers ? [{ id: "storage" as const, label: "Storage" }] : []),
  ];
  const { tab: rawTab } = await searchParams;
  // Sign-off moved to Users → Departments (Approvals → Who signs off shows it).
  if (rawTab === "signoff") redirect("/users?tab=departments");
  // Personal settings moved to My account.
  if (rawTab === "general") redirect("/account");
  // The team, invitations and external access moved to Users.
  if (rawTab === "team") redirect("/users");
  if (tabs.length === 0) {
    return (
      <div className="flex max-w-5xl flex-col gap-3 p-4 sm:p-6">
        <h1 className="text-xl font-semibold tracking-tight">Settings</h1>
        <p className="text-muted-foreground text-sm">
          Settings are looked after by admins and operations. Your own details and notifications are
          in{" "}
          <Link href="/account" className="link">
            My account
          </Link>
          ; the team is in{" "}
          <Link href="/users" className="link">
            Users
          </Link>
          .
        </p>
      </div>
    );
  }
  const tab: TabId = tabs.some((t) => t.id === rawTab) ? (rawTab as TabId) : tabs[0].id;

  const [types, deleted, venueRows, eventRows, serviceRows] = await Promise.all([
    db
      .select()
      .from(itemTypes)
      .where(eq(itemTypes.organisationId, session.organisation.id))
      .orderBy(itemTypes.sortOrder),
    db
      .select({ item: signageItems })
      .from(signageItems)
      .innerJoin(editions, eq(signageItems.editionId, editions.id))
      .innerJoin(events, eq(editions.eventId, events.id))
      .where(
        and(isNotNull(signageItems.deletedAt), eq(events.organisationId, session.organisation.id)),
      )
      .orderBy(desc(signageItems.deletedAt))
      .limit(50)
      .then((rows) => rows.map((r) => r.item)),
    db.select().from(venues).where(eq(venues.organisationId, session.organisation.id)),
    db
      .select()
      .from(events)
      .where(eq(events.organisationId, session.organisation.id))
      .orderBy(events.name),
    db
      .select({
        id: supplierServices.id,
        name: supplierServices.name,
        isArchived: supplierServices.isArchived,
        supplierCount: count(supplierServiceLinks.supplierId),
      })
      .from(supplierServices)
      .leftJoin(supplierServiceLinks, eq(supplierServiceLinks.serviceId, supplierServices.id))
      .where(eq(supplierServices.organisationId, session.organisation.id))
      .groupBy(supplierServices.id)
      .orderBy(asc(supplierServices.sortOrder), asc(supplierServices.name)),
  ]);

  return (
    <div className="flex max-w-5xl flex-col gap-6 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">Settings</h1>
      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Settings sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={t.id === tabs[0].id ? "/settings" : `/settings?tab=${t.id}`}
            className={`px-3 py-2 text-sm whitespace-nowrap ${
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      {tab === "types" && (
        <section className="space-y-3">
          <div>
            <h2 className="text-sm font-semibold">Signage types</h2>
            <p className="text-muted-foreground text-sm">
              What people can choose when they add an item — marked print or digital. Hiding a type
              removes it from the list; items already using it keep it.
            </p>
          </div>
          <ItemTypesEditor
            rows={types.map((t) => ({
              id: t.id,
              name: t.name,
              kind: t.kind as "signage" | "sponsorship_item",
              format: t.format,
              defaultFixingMethod: t.defaultFixingMethod,
              requiresVenueApprovalDefault: t.requiresVenueApprovalDefault,
              isArchived: t.isArchived,
            }))}
            canEdit={canManage}
          />
        </section>
      )}

      {tab === "services" && (
        <section className="space-y-3">
          <div>
            <h2 className="text-sm font-semibold">Supplier services</h2>
            <p className="text-muted-foreground text-sm">
              The kinds of work suppliers do. You tick these on each supplier under{" "}
              <Link href="/suppliers" className="underline">
                Suppliers
              </Link>
              , and people can then find the right company quickly.
            </p>
          </div>
          <ServicesEditor
            rows={serviceRows.map((r) => ({ ...r, supplierCount: Number(r.supplierCount) }))}
            canEdit={canManage}
          />
        </section>
      )}

      {tab === "venues" && (
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold">Venues &amp; show series</h2>
            <p className="text-muted-foreground text-sm">
              Venues (with their address) and the show series each show belongs to. You can also add
              both straight from the New show form.
            </p>
          </div>
          <DirectorySection
            type="event"
            noun="Show series"
            canEdit={canManage}
            fields={[
              {
                key: "name",
                label: "Name",
                required: true,
                listed: true,
                placeholder: "UK Construction Week",
              },
              {
                key: "code",
                label: "Short code",
                required: true,
                listed: true,
                placeholder: "UKCW",
              },
            ]}
            rows={eventRows.map((e) => ({ id: e.id, name: e.name, code: e.code }))}
          />
          <DirectorySection
            type="venue"
            noun="Venue"
            canEdit={canManage}
            fields={[
              {
                key: "name",
                label: "Name",
                required: true,
                listed: true,
                placeholder: "NEC Birmingham",
              },
              {
                key: "code",
                label: "Short code",
                required: true,
                listed: true,
                placeholder: "NEC",
              },
              { key: "address", label: "Address", listed: true },
              { key: "riggingContactName", label: "Rigging contact" },
              { key: "riggingContactEmail", label: "Rigging contact email", type: "email" },
            ]}
            rows={venueRows.map((v) => ({
              id: v.id,
              name: v.name,
              code: v.code,
              address: v.address,
              riggingContactName: v.riggingContactName,
              riggingContactEmail: v.riggingContactEmail,
            }))}
          />
        </section>
      )}

      {tab === "storage" && canUsers && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">File storage</h2>
          <p className="text-muted-foreground mb-3 text-sm">
            Artwork, panel graphics, photos, documents, exports and videos. Which store is used
            comes from the hosting settings; this page checks it and moves files between stores.
          </p>
          <StoragePanel
            backend={storageBackend()}
            check={s3Enabled() ? await s3Probe() : null}
            blobConfigured={blobEnabled()}
            s3Configured={s3Enabled()}
            bucket={process.env.S3_BUCKET ?? null}
          />
        </section>
      )}

      {tab === "deleted" && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Deleted items</h2>
          {deleted.length === 0 ? (
            <p className="text-muted-foreground text-sm">Nothing has been deleted.</p>
          ) : (
            <div className="overflow-x-auto rounded-lg border">
              <table className="w-full text-sm">
                <tbody>
                  {deleted.map((item) => (
                    <tr key={item.id} className="border-b last:border-0">
                      <td className="px-3 py-2 font-medium">{item.ref}</td>
                      <td className="px-3 py-2">{item.name}</td>
                      <td className="text-muted-foreground px-3 py-2">
                        Deleted {formatDateTime(item.deletedAt)}
                      </td>
                      <td className="px-3 py-2 text-right">
                        <RestoreItemButton itemId={item.id} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}
    </div>
  );
}
