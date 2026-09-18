import { desc, eq, isNotNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  editions,
  exhibitors,
  externalGrants,
  itemTypes,
  memberships,
  signageItems,
  sponsors,
  suppliers,
  users,
  venues,
  workflows,
  workflowSteps,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { formatDate, formatDateTime, statusLabel } from "@/lib/format";
import { InviteExternalForm, RevokeGrantButton } from "@/components/settings/invite-form";
import { RestoreItemButton } from "@/components/settings/restore-button";
import { icalToken } from "@/lib/ical";
import { appUrl } from "@/lib/app-url";
import { NotificationPrefsForm } from "@/components/settings/notification-prefs";

export const metadata = { title: "Settings" };
export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const session = await requireStaffSession();
  const canManage = can(session.actor, { type: "settings.manage" });
  const canUsers = can(session.actor, { type: "users.manage" });

  const [me] = await db.select().from(users).where(eq(users.id, session.user.id));
  const [staff, grants, types, wfs, steps, deleted, editionRows, venueRows, supplierRows, exhibitorRows, sponsorRows] =
    await Promise.all([
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
      db.select().from(itemTypes).where(eq(itemTypes.organisationId, session.organisation.id)).orderBy(itemTypes.sortOrder),
      db.select().from(workflows).where(eq(workflows.organisationId, session.organisation.id)),
      db.select().from(workflowSteps).orderBy(workflowSteps.sortOrder),
      db
        .select()
        .from(signageItems)
        .where(isNotNull(signageItems.deletedAt))
        .orderBy(desc(signageItems.deletedAt))
        .limit(50),
      db.select().from(editions),
      db.select().from(venues).where(eq(venues.organisationId, session.organisation.id)),
      db.select().from(suppliers).where(eq(suppliers.organisationId, session.organisation.id)),
      db.select().from(exhibitors),
      db.select().from(sponsors),
    ]);

  return (
    <div className="flex max-w-5xl flex-col gap-8 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Settings</h1>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Organisation</h2>
        <p className="text-muted-foreground text-sm">
          {session.organisation.brandName} · currency {session.organisation.settings.currency} ·
          Event Director threshold £
          {session.organisation.settings.cost_threshold_for_director.toLocaleString("en-GB")} ·
          escalate after {session.organisation.settings.escalate_after_days} days overdue ·
          install photo {session.organisation.settings.install_photo_required ? "required" : "optional"}
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
        <NotificationPrefsForm initial={me?.notificationPrefs ?? {}} />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Staff</h2>
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <tbody>
              {staff.map(({ m, u }) => (
                <tr key={m.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{u.fullName || u.email}</td>
                  <td className="text-muted-foreground px-3 py-2">{u.email}</td>
                  <td className="px-3 py-2">{statusLabel(m.role)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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
              }))}
              sponsors={sponsorRows.map((sp) => ({ id: sp.id, label: sp.companyName }))}
            />
          </div>
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <tbody>
                {grants.map(({ g, u }) => (
                  <tr key={g.id} className="border-b last:border-0">
                    <td className="px-3 py-2 font-medium">{u?.fullName || g.invitedEmail}</td>
                    <td className="px-3 py-2">{statusLabel(g.role)}</td>
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

      <section>
        <h2 className="mb-2 text-sm font-semibold">Item types</h2>
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <tbody>
              {types.map((t) => (
                <tr key={t.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{t.name}</td>
                  <td className="text-muted-foreground px-3 py-2">{t.code}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {t.defaultFixingMethod ? statusLabel(t.defaultFixingMethod) : "—"}
                  </td>
                  <td className="px-3 py-2">
                    {t.requiresVenueApprovalDefault ? "Venue approval by default" : ""}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Workflows</h2>
        <div className="space-y-4">
          {wfs.map((wf) => (
            <div key={wf.id} className="rounded-lg border p-4">
              <p className="mb-2 text-sm font-medium">
                {wf.name}{" "}
                <span className="text-muted-foreground font-normal">
                  ({wf.appliesTo}
                  {wf.isDefault ? ", default" : ""})
                </span>
              </p>
              <ol className="text-muted-foreground space-y-1 text-sm">
                {steps
                  .filter((st) => st.workflowId === wf.id)
                  .map((st) => (
                    <li key={st.id}>
                      {st.sortOrder}. {st.name} — {st.kind} ·{" "}
                      {st.approverRole ? statusLabel(st.approverRole) : "named user"} · SLA{" "}
                      {st.slaDays}d
                      {st.parallelGroup != null ? ` · group ${st.parallelGroup}` : ""}
                      {st.invalidateOnNewVersion ? " · invalidates on new version" : ""}
                      {st.conditions.filter((c) => c !== "always").length > 0
                        ? ` · when ${st.conditions.join(" or ")}`
                        : ""}
                    </li>
                  ))}
              </ol>
            </div>
          ))}
        </div>
        <p className="text-muted-foreground mt-2 text-xs">
          Workflow editing arrives with the Phase 3 builder; runs always use snapshots so edits
          never change work in flight.
        </p>
      </section>

      {canManage && (
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
        Calendar feeds need CRON_SECRET and the app URL configured on the server.
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
