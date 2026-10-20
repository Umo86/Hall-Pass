import { blobEnabled, s3Enabled, s3Probe, storageBackend } from "@/lib/storage";
import { emailConfigured } from "@/lib/email/dispatch";
import { authBaseURL, authConfigured, authSecretSource, devAuthEnabled } from "@/lib/auth/config";
import { calendarFeedUrl } from "@/lib/feed-url";
import { PageHeader } from "@/components/page-header";
import { SectionLocked, settingsAccess } from "@/components/settings/access";
import { StoragePanel } from "@/components/settings/storage-panel";
import { StatusLine } from "@/components/settings/status-line";
import { emailStatus, signInStatus, storageStatus } from "@/components/settings/system-status";

export const metadata = { title: "System · Settings" };
export const dynamic = "force-dynamic";

/** Settings → System (admins): is file storage safe, does email work, how sign-in works — in plain words first. */
export default async function SystemPage() {
  const { session, canOpen } = await settingsAccess();
  const header = (
    <PageHeader
      title="System"
      description="Where files are kept, whether email works and how people sign in. These come from the hosting settings, which your developer looks after; this page checks them."
    />
  );
  if (!canOpen("system")) {
    return (
      <>
        {header}
        <SectionLocked id="system" />
      </>
    );
  }
  const backend = storageBackend();
  const check = s3Enabled() ? await s3Probe() : null;
  const storage = storageStatus({ backend, check, hosted: Boolean(process.env.VERCEL) });
  const email = emailStatus(emailConfigured());
  const secretSource = authSecretSource();
  const demo = devAuthEnabled();
  const signIn = signInStatus({ configured: authConfigured(), demo, emailOn: emailConfigured() });
  const feedsOn = calendarFeedUrl(session.user.id) !== null;

  return (
    <>
      {header}
      <div className="grid gap-3 lg:grid-cols-2">
        <StatusLine label="File storage" status={storage} />
        <StatusLine label="Email" status={email} />
        <StatusLine label="Sign-in" status={signIn} />
        <StatusLine
          label="Calendar feeds"
          status={
            feedsOn
              ? {
                  tone: "ok",
                  title: "Calendar feeds are on",
                  detail:
                    "Everyone can add their deadlines to Google, Outlook or Apple Calendar from My account.",
                }
              : {
                  tone: "warn",
                  title: "Calendar feeds are off",
                  detail:
                    "They need the site's address in the hosting settings. Ask your developer to set it.",
                }
          }
        />
      </div>

      <details className="rounded-lg border" open={storage.tone === "error"}>
        <summary className="cursor-pointer px-4 py-3 text-sm font-medium select-none">
          Technical details
        </summary>
        <div className="space-y-6 border-t px-4 py-4">
          <section className="space-y-3">
            <h2 className="text-sm font-semibold">File storage</h2>
            <StoragePanel
              backend={backend}
              check={check}
              blobConfigured={blobEnabled()}
              s3Configured={s3Enabled()}
              bucket={process.env.S3_BUCKET ?? null}
            />
          </section>
          <section className="space-y-1 text-sm">
            <h2 className="font-semibold">Email</h2>
            <p className="text-muted-foreground">
              {emailConfigured()
                ? "Sending through Resend (RESEND_API_KEY and EMAIL_FROM are set). The sender is EMAIL_FROM."
                : "Set RESEND_API_KEY and EMAIL_FROM in the hosting settings and redeploy to send email."}
            </p>
          </section>
          <section className="space-y-1 text-sm">
            <h2 className="font-semibold">Sign-in</h2>
            <p className="text-muted-foreground">
              {secretSource === "env"
                ? "Better Auth, in this database. Sessions and links are signed with BETTER_AUTH_SECRET."
                : secretSource === "derived"
                  ? "Better Auth, in this database. Sessions and links are signed with a secret derived from CRON_SECRET (BETTER_AUTH_SECRET isn't set)."
                  : "Real sign-in is off: set BETTER_AUTH_SECRET (openssl rand -base64 32) and redeploy."}{" "}
              {authConfigured() &&
                `Sign-in and reset links point at ${new URL(authBaseURL()).host}.`}{" "}
              {demo
                ? "Demo sign-in is on (DEV_AUTH=1, or local development); it is never on for Vercel production."
                : "Demo sign-in is off."}
            </p>
          </section>
          <section className="space-y-1 text-sm">
            <h2 className="font-semibold">Calendar feeds</h2>
            <p className="text-muted-foreground">
              {feedsOn
                ? "Feed links are built from the site address and signed per person."
                : "Set NEXT_PUBLIC_APP_URL (or deploy on Vercel, which provides the address) so feed links can be made."}
            </p>
          </section>
        </div>
      </details>
    </>
  );
}
