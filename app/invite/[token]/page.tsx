import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { eq, sql } from "drizzle-orm";
import { InviteForm } from "@/components/auth/invite-form";
import { findValidGrant, inviteDetails } from "@/lib/users/invite-lookup";
import { grantScopeName } from "@/lib/users/external";
import { db } from "@/lib/db/client";
import { editions, users } from "@/lib/db/schema";
import { brandName } from "@/lib/config";
import { formatDate, roleLabel } from "@/lib/format";
import { getSession } from "@/lib/auth/actor";
import { signOut } from "@/app/actions/auth";
import { PORTAL_HOME } from "@/lib/edition-path";
import { AccentRule, Wordmark } from "@/components/wordmark";
import { Button } from "@/components/ui/button";

/**
 * A partner invitation in words: which event, for which company, until
 * when — and whether the invited email already has an account (they sign
 * in, and the new access is added to it).
 */
async function partnerContext(token: string) {
  const { grant } = await findValidGrant(token);
  if (!grant) return null;
  const [[edition], scopeName, [account]] = await Promise.all([
    db.select({ name: editions.name }).from(editions).where(eq(editions.id, grant.editionId)),
    grantScopeName(db, grant.organisationId, grant),
    db
      .select({ id: users.id })
      .from(users)
      .where(sql`lower(${users.email}) = ${grant.invitedEmail.toLowerCase()}`)
      .limit(1),
  ]);
  return {
    eventName: edition?.name ?? null,
    scopeName,
    endsAt: grant.expiresAt,
    hasAccount: Boolean(account),
    claimed: Boolean(grant.userId && grant.acceptedAt),
  };
}

export const metadata = { title: "Accept invitation" };
export const dynamic = "force-dynamic";

/** The same frame as the sign-in page: brand at the top, one card in the middle. */
function InviteShell({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <div className="bg-muted/40 flex min-h-screen flex-col">
      <div className="mx-auto flex w-full max-w-5xl items-center px-6 py-5">
        <Link
          href="/login"
          className="text-muted-foreground hover:text-foreground flex items-center gap-2 text-sm"
        >
          <ArrowLeft className="size-4" aria-hidden /> <Wordmark name={brandName} size="sm" />
        </Link>
      </div>
      <div className="flex flex-1 items-start justify-center px-4 pt-6 pb-16 sm:items-center sm:pt-0">
        <main className="bg-background w-full max-w-md space-y-5 rounded-xl border p-6 shadow-sm sm:p-8">
          <div className="space-y-2">
            <Wordmark name={brandName} />
            <AccentRule className="w-12" />
            <h1 className="text-xl font-semibold tracking-tight text-balance">{heading}</h1>
          </div>
          {children}
        </main>
      </div>
    </div>
  );
}

function article(word: string) {
  return /^[aeiou]/i.test(word) ? "an" : "a";
}

/** "Marketing", "Marketing and Sales", "Marketing, Sales and Finance". */
function andList(names: readonly string[]): string {
  return names.length <= 1
    ? (names[0] ?? "")
    : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

export default async function InvitePage({
  params,
  searchParams,
}: {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ name?: string }>;
}) {
  const { token } = await params;
  const { name } = await searchParams;
  const [details, session] = await Promise.all([inviteDetails(token), getSession()]);

  if (!details.ok) {
    const heading =
      details.reason === "expired"
        ? "This invitation has expired"
        : details.reason === "used"
          ? "This invitation has already been used"
          : details.reason === "revoked"
            ? "This invitation was cancelled"
            : "Invitation not found";
    const body =
      details.reason === "expired"
        ? `Ask ${details.inviterName ?? "whoever invited you"} to send a new one — the new link works straight away.`
        : details.reason === "used"
          ? "Your account is already set up. Sign in with your email instead."
          : details.reason === "revoked"
            ? "Ask whoever invited you if you still need access."
            : "This invitation link is not valid. Check you copied the whole link, or ask for a new one.";
    return (
      <InviteShell heading={heading}>
        <p role="alert" className="text-muted-foreground text-sm">
          {body}
        </p>
        <Button asChild className="w-full">
          <Link href="/login">Go to sign in</Link>
        </Button>
      </InviteShell>
    );
  }

  const signedInAsInvitee =
    session?.user.email.toLowerCase() === details.invitedEmail.toLowerCase();
  const brand = details.brandName ?? brandName;
  const role = roleLabel(details.role);
  const heading =
    details.kind === "staff"
      ? `You're invited to join ${brand} as ${role}${details.departmentName ? ` in ${details.departmentName}` : ""}`
      : `You're invited to ${brand} as ${article(role)} ${role.toLowerCase()}`;
  const partner = details.kind === "external" ? await partnerContext(token) : null;
  const forWhat = partner ? [partner.eventName, partner.scopeName].filter(Boolean).join(" · ") : "";
  const what = partner && (
    <p className="text-sm">
      {forWhat && <span className="font-medium">{forWhat}</span>}
      {partner.endsAt && (
        <span className="text-muted-foreground">
          {forWhat ? " · " : ""}access until the end of {formatDate(partner.endsAt)}
        </span>
      )}
    </p>
  );

  // Already on their account (signing in claimed it): straight to the portal.
  if (partner?.claimed && signedInAsInvitee && session?.actor.kind === "external") {
    return (
      <InviteShell heading="This access is on your account">
        {what}
        <p className="text-muted-foreground text-sm">
          You can see it in the portal now — nothing else to do.
        </p>
        <Button asChild className="w-full">
          <Link href={PORTAL_HOME}>Open the portal</Link>
        </Button>
      </InviteShell>
    );
  }

  // Signed in as someone else: sign out first (signing in again would loop back here).
  if (partner && session && !signedInAsInvitee) {
    return (
      <InviteShell heading={heading}>
        {what}
        <p className="text-muted-foreground text-sm">
          This invitation is for <span className="font-medium">{details.invitedEmail}</span>, but
          you&apos;re signed in as <span className="font-medium">{session.user.email}</span>. Sign
          out, then open the link again.
        </p>
        <form action={signOut}>
          <Button type="submit" className="w-full">
            Sign out
          </Button>
        </form>
      </InviteShell>
    );
  }

  // They have an account already: signing in with it adds this access.
  if (partner && (partner.hasAccount || partner.claimed) && !signedInAsInvitee) {
    return (
      <InviteShell heading={heading}>
        {what}
        <p className="text-muted-foreground text-sm">
          You already have an account with{" "}
          <span className="font-medium">{details.invitedEmail}</span>. Sign in with it and this
          access is added straight away.
        </p>
        <Button asChild className="w-full">
          <Link href={`/login?next=${encodeURIComponent(`/invite/${token}`)}`}>
            Sign in to accept
          </Link>
        </Button>
      </InviteShell>
    );
  }

  return (
    <InviteShell heading={heading}>
      {what}
      {details.kind === "staff" && details.events && details.events.length > 0 && (
        <p className="text-muted-foreground text-sm">
          You&rsquo;ll work on {andList(details.events.map((e) => e.name))}.
        </p>
      )}
      {details.kind === "staff" && details.signsOff && (
        <p className="text-muted-foreground text-sm">
          {details.mainFor.length > 0
            ? `You'll also sign off signage artwork, as the main approver for ${andList(details.mainFor)} — you'll get an email whenever something needs you.`
            : "You'll also sign off signage artwork — you'll get an email whenever something needs you."}
        </p>
      )}
      <InviteForm
        token={token}
        invitedEmail={details.invitedEmail}
        initialName={name?.slice(0, 200) || details.fullName}
        needsPassword={!signedInAsInvitee}
      />
    </InviteShell>
  );
}
