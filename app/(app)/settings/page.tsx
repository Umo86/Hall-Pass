import { and, asc, count, desc, eq, isNotNull, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  itemTypes,
  memberships,
  signageItems,
  sponsors,
  staffInvites,
  supplierServiceLinks,
  supplierServices,
  suppliers,
  users,
  venues,
} from "@/lib/db/schema";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, type PermissionOverrides } from "@/lib/authz";
import { formatDate, formatDateTime, roleLabel } from "@/lib/format";
import { InviteExternalForm, RevokeGrantButton } from "@/components/settings/invite-form";
import { TeamTable } from "@/components/settings/team-table";
import { DirectorySection } from "@/components/settings/directory-section";
import { standsEnabled } from "@/lib/config";
import { ItemTypesEditor } from "@/components/settings/item-types-editor";
import { ServicesEditor } from "@/components/settings/services-editor";
import { RestoreItemButton } from "@/components/settings/restore-button";
import { icalToken } from "@/lib/ical";
import { appUrl } from "@/lib/app-url";
import { NotificationPrefsForm } from "@/components/settings/notification-prefs";
import { emailConfigured } from "@/lib/email/dispatch";

export const metadata = { title: "Settings" };
export const dynamic = "force-dynamic";

type TabId = "general" | "team" | "types" | "services" | "venues" | "deleted";

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireStaffSession();
  const canManage = can(session.actor, { type: "settings.manage" });
  const canUsers = can(session.actor, { type: "users.manage" });
  const tabs: { id: TabId; label: string }[] = [
    { id: "general", label: "My settings" },
    { id: "team", label: "Team" },
    ...(canManage || canUsers
      ? ([
          { id: "types", label: "Signage types" },
          { id: "services", label: "Supplier services" },
          { id: "venues", label: "Venues" },
          { id: "deleted", label: "Deleted items" },
        ] as { id: TabId; label: string }[])
      : []),
  ];
  const { tab: rawTab } = await searchParams;
  // Sign-off moved to Approvals → Approvers.
  if (rawTab === "signoff") redirect("/approvals?tab=approvers");
  const tab: TabId = tabs.some((t) => t.id === rawTab) ? (rawTab as TabId) : "general";

  const [me] = await db.select().from(users).where(eq(users.id, session.user.id));
  const [
    staff,
    grants,
    types,
    deleted,
    editionRows,
    venueRows,
    supplierRows,
    exhibitorRows,
    sponsorRows,
    pendingInvites,
    eventRows,
    serviceRows,
  ] = await Promise.all([
    db
      .select({ m: memberships, u: users })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organisationId, session.organisation.id)),
    db
      .select({ g: externalGrants, u: users })
      .from(externalGrants)
      .leftJoin(users, eq(externalGrants.userId, users.id))
      .where(eq(externalGrants.organisationId, session.organisation.id))
      .orderBy(desc(externalGrants.createdAt)),
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
    db
      .select({ edition: editions })
      .from(editions)
      .innerJoin(events, eq(editions.eventId, events.id))
      .where(eq(events.organisationId, session.organisation.id))
      .then((rows) => rows.map((r) => r.edition)),
    db.select().from(venues).where(eq(venues.organisationId, session.organisation.id)),
    db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
    db.select().from(exhibitors),
    db.select().from(sponsors),
    db
      .select()
      .from(staffInvites)
      .where(
        and(
          eq(staffInvites.organisationId, session.organisation.id),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      )
      .orderBy(desc(staffInvites.createdAt)),
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
            href={t.id === "general" ? "/settings" : `/settings?tab=${t.id}`}
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

      {tab === "general" && (
        <>
          <section>
            <h2 className="mb-2 text-sm font-semibold">Organisation</h2>
            <p className="text-muted-foreground text-sm">
              {session.organisation.brandName} · currency {session.organisation.settings.currency} ·
              escalate after {session.organisation.settings.escalate_after_days} days overdue ·
              install photo{" "}
              {session.organisation.settings.install_photo_required ? "required" : "optional"}
            </p>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Calendar feed</h2>
            <p className="text-muted-foreground mb-2 text-sm">
              Subscribe to every deadline, install date and your pending sign-offs from your own
              calendar (Google Calendar, Outlook or Apple Calendar — &ldquo;add calendar from
              URL&rdquo;). The link is personal to you; treat it like a password.
            </p>
            <FeedLink userId={session.user.id} />
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">My notifications</h2>
            <p className="text-muted-foreground mb-2 text-sm">
              Untick anything you don&rsquo;t want to be notified about. These apply to in-app
              notifications and the emails that mirror them.
            </p>
            {!emailConfigured() && (
              <p className="mb-2 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
                Email is off, so notifications only appear in the app (the bell). An admin can
                switch email on by adding a Resend API key in the hosting settings.
              </p>
            )}
            <NotificationPrefsForm initial={me?.notificationPrefs ?? {}} />
          </section>
        </>
      )}

      {tab === "team" && (
        <>
          <section>
            <h2 className="mb-2 text-sm font-semibold">Team</h2>
            {canUsers && (
              <p className="text-muted-foreground mb-2 text-sm">
                Set each person&rsquo;s role, fine-tune what they can do under Permissions, and
                invite new staff. Approving stays tied to sign-off assignment — the checkbox can
                only take it away.
              </p>
            )}
            <TeamTable
              members={staff.map(({ m, u }) => ({
                membershipId: m.id,
                userId: u.id,
                name: u.fullName,
                email: u.email,
                role: m.role,
                overrides: m.permissionOverrides as PermissionOverrides,
              }))}
              invites={pendingInvites.map((inv) => ({
                id: inv.id,
                email: inv.invitedEmail,
                role: inv.role,
              }))}
              currentUserId={session.user.id}
              canManage={canUsers}
            />
          </section>

          {canUsers && (
            <section>
              <h2 className="mb-2 text-sm font-semibold">External access</h2>
              <div className="mb-4 rounded-lg border p-4">
                <h3 className="mb-3 text-sm font-medium">Invite an external party</h3>
                <InviteExternalForm
                  editions={editionRows.map((e) => ({ id: e.id, label: `${e.code} — ${e.name}` }))}
                  venues={venueRows.map((v) => ({ id: v.id, label: v.name }))}
                  suppliers={supplierRows.map((sp) => ({ id: sp.id, label: sp.name }))}
                  exhibitors={exhibitorRows.map((x) => ({
                    id: x.id,
                    label: `${x.companyName} (${x.standNumber})`,
                    editionId: x.editionId,
                  }))}
                  sponsors={sponsorRows.map((sp) => ({
                    id: sp.id,
                    label: sp.companyName,
                    editionId: sp.editionId,
                  }))}
                  showStandRoles={standsEnabled}
                />
              </div>
              <div className="overflow-x-auto rounded-lg border">
                <table className="w-full text-sm">
                  <tbody>
                    {grants.map(({ g, u }) => (
                      <tr key={g.id} className="border-b last:border-0">
                        <td className="px-3 py-2 font-medium">{u?.fullName || g.invitedEmail}</td>
                        <td className="px-3 py-2">{roleLabel(g.role)}</td>
                        <td className="text-muted-foreground px-3 py-2">
                          {g.revokedAt
                            ? `Revoked ${formatDateTime(g.revokedAt)}`
                            : g.acceptedAt
                              ? `Accepted ${formatDateTime(g.acceptedAt)}`
                              : "Invited"}
                          {g.expiresAt ? ` · expires ${formatDate(g.expiresAt)}` : ""}
                        </td>
                        <td className="px-3 py-2 text-right">
                          {!g.revokedAt && <RevokeGrantButton grantId={g.id} />}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}
        </>
      )}

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
              kind: t.kind,
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

function FeedLink({ userId }: { userId: string }) {
  let url: string | null = null;
  try {
    const base = appUrl();
    url = base ? `${base}/api/ical/${icalToken(userId)}` : null;
  } catch {
    url = null;
  }
  if (!url) {
    return (
      <p className="text-muted-foreground text-sm">
        The calendar feed isn&apos;t switched on for this site yet — ask your administrator.
      </p>
    );
  }
  return (
    <input
      readOnly
      value={url}
      className="bg-muted/40 w-full max-w-xl rounded-md border px-3 py-2 font-mono text-xs"
    />
  );
}
