import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { InviteForm } from "@/components/auth/invite-form";
import { inviteDetails } from "@/lib/users/invite-lookup";
import { brandName } from "@/lib/config";
import { roleLabel } from "@/lib/format";
import { getSession } from "@/lib/auth/actor";
import { AccentRule, Wordmark } from "@/components/wordmark";
import { Button } from "@/components/ui/button";

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

  return (
    <InviteShell heading={heading}>
      {details.kind === "staff" && details.signsOff && (
        <p className="text-muted-foreground text-sm">
          You&apos;ll also sign off signage artwork — you&apos;ll get an email whenever something
          needs you.
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
