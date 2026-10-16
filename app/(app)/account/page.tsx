import Link from "next/link";
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
import { NotificationPrefsForm } from "@/components/account/notification-prefs";

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
  const isAdmin = can(actor, { type: "system.manage" });
  const emailOn = emailConfigured();

  return (
    <Page width="narrow">
      <PageHeader
        title="My account"
        description="Your details, your calendar feed and what you're told about."
      />

      <section className="space-y-3 rounded-lg border p-4" aria-labelledby="account-details">
        <h2 id="account-details" className="text-sm font-semibold">
          Your details
        </h2>
        <NameForm initial={me?.fullName ?? session.user.fullName} />
        <dl className="grid grid-cols-[7rem_minmax(0,1fr)] gap-x-3 gap-y-1.5 text-sm">
          <dt className="text-muted-foreground">Email</dt>
          <dd className="break-all">{session.user.email}</dd>
          <dt className="text-muted-foreground">Role</dt>
          <dd>{roleLabel(actor.role)}</dd>
          <dt className="text-muted-foreground">Department</dt>
          <dd>{department?.name ?? "None yet"}</dd>
        </dl>
        <p className="text-muted-foreground text-xs">
          {isAdmin ? (
            <>
              Roles and departments are set in{" "}
              <Link href={`/users/${session.user.id}`} className="link">
                Users
              </Link>
              .
            </>
          ) : (
            "An admin sets your role and department. Ask one if they look wrong."
          )}
        </p>
      </section>

      {(feed || isAdmin) && (
        <section className="space-y-3 rounded-lg border p-4" aria-labelledby="account-feed">
          <h2 id="account-feed" className="text-sm font-semibold">
            Calendar feed
          </h2>
          {feed ? (
            <>
              <p className="text-muted-foreground text-sm">
                Add every deadline, install date and the sign-offs waiting on you to Google
                Calendar, Outlook or Apple Calendar (&ldquo;add calendar from URL&rdquo;). The link
                is yours alone — treat it like a password.
              </p>
              <CopyField value={feed} label="Calendar feed link" />
            </>
          ) : (
            <p className="text-muted-foreground text-sm">
              Calendar feeds are off for this site, so nobody has a feed link yet. See{" "}
              <Link href="/settings/system" className="link">
                Settings → System
              </Link>{" "}
              for what&rsquo;s needed.
            </p>
          )}
        </section>
      )}

      <section className="space-y-3 rounded-lg border p-4" aria-labelledby="account-notifications">
        <h2 id="account-notifications" className="text-sm font-semibold">
          Notifications
        </h2>
        <p className="text-muted-foreground text-sm">
          Untick anything you don&rsquo;t want to hear about.{" "}
          {emailOn
            ? "These apply to the bell and to the emails that go with it."
            : "These apply to the bell."}
        </p>
        {!emailOn && (
          <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
            Email notifications are off for your organisation, so you&rsquo;ll see them in the bell.
            {isAdmin && (
              <>
                {" "}
                <Link href="/settings/system" className="link">
                  See Settings → System
                </Link>
              </>
            )}
          </p>
        )}
        <NotificationPrefsForm initial={me?.notificationPrefs ?? {}} />
      </section>
    </Page>
  );
}
