import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { departments, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { roleLabel } from "@/lib/format";
import { emailConfigured } from "@/lib/email/dispatch";
import { calendarFeedUrl } from "@/lib/feed-url";
import { can } from "@/lib/authz";
import { Page, PageHeader } from "@/components/page-header";
import { CopyField } from "@/components/copy-field";
import { NameForm } from "@/components/account/name-form";
import { NotificationPrefsForm } from "@/components/settings/notification-prefs";

export const metadata = { title: "My account" };
export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const session = await requireStaffSession();
  const actor = session.actor;
  const [me, department] = await Promise.all([
    db.query.users.findFirst({ where: eq(users.id, session.user.id) }),
    actor.departmentId
      ? db.query.departments.findFirst({ where: eq(departments.id, actor.departmentId) })
      : Promise.resolve(undefined),
  ]);
  const feed = calendarFeedUrl(session.user.id);
  const isAdmin = can(actor, { type: "users.manage" });

  return (
    <Page width="narrow">
      <PageHeader
        title="My account"
        description="Your details, your calendar feed and what you're notified about."
      />

      <section className="space-y-3 rounded-lg border p-4">
        <h2 className="text-sm font-semibold">Your details</h2>
        <NameForm initial={me?.fullName ?? session.user.fullName} />
        <dl className="grid grid-cols-[7rem_1fr] gap-x-3 gap-y-1.5 text-sm">
          <dt className="text-muted-foreground">Email</dt>
          <dd>{session.user.email}</dd>
          <dt className="text-muted-foreground">Role</dt>
          <dd>{roleLabel(actor.role)}</dd>
          <dt className="text-muted-foreground">Department</dt>
          <dd>{department?.name ?? "Not set"}</dd>
        </dl>
        <p className="text-muted-foreground text-xs">
          {isAdmin
            ? "Change roles and departments in Users."
            : "An admin sets your role and department in Users."}
        </p>
      </section>

      <section className="space-y-3 rounded-lg border p-4">
        <h2 className="text-sm font-semibold">Calendar feed</h2>
        {feed ? (
          <>
            <p className="text-muted-foreground text-sm">
              Add every deadline, install date and your waiting sign-offs to Google Calendar,
              Outlook or Apple Calendar (&ldquo;add calendar from URL&rdquo;). The link is personal
              to you; treat it like a password.
            </p>
            <CopyField value={feed} label="Calendar feed link" />
          </>
        ) : (
          <p className="text-muted-foreground text-sm">
            {isAdmin
              ? "Calendar feeds need the site address: set APP_URL in your hosting settings."
              : "Calendar feeds aren't switched on for this site yet."}
          </p>
        )}
      </section>

      <section className="space-y-3 rounded-lg border p-4">
        <h2 className="text-sm font-semibold">Notifications</h2>
        <p className="text-muted-foreground text-sm">
          Untick anything you don&rsquo;t want to hear about. These apply to the bell and to the
          emails that mirror it.
        </p>
        {!emailConfigured() && (
          <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
            Email is off for your organisation, so notifications only appear in the bell.
          </p>
        )}
        <NotificationPrefsForm initial={me?.notificationPrefs ?? {}} />
      </section>
    </Page>
  );
}
