import { InviteForm } from "@/components/auth/invite-form";
import { inviteDetails } from "@/app/actions/invites";
import { brandName } from "@/lib/config";
import { roleLabel } from "@/lib/format";
import { getSession } from "@/lib/auth/actor";
import { db } from "@/lib/db/client";
import { approvers } from "@/lib/db/schema";
import { eq } from "drizzle-orm";

export const metadata = { title: "Accept invitation" };
export const dynamic = "force-dynamic";

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
  const signedInAsInvitee =
    details.ok && session?.user.email.toLowerCase() === details.invitedEmail.toLowerCase();
  // Approvers were added by name, so the form can start with it.
  const approver = details.ok
    ? await db.query.approvers.findFirst({
        where: eq(approvers.email, details.invitedEmail.toLowerCase()),
      })
    : undefined;

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">
            {details.ok && approver
              ? "You're invited to sign off signage artwork"
              : details.ok && details.kind === "staff"
                ? `You're invited to join the team as ${roleLabel(details.role)}`
                : "Accept your invitation"}
          </p>
        </div>
        {details.ok ? (
          <InviteForm
            token={token}
            invitedEmail={details.invitedEmail}
            initialName={name?.slice(0, 200) ?? approver?.fullName ?? ""}
            needsPassword={!signedInAsInvitee}
          />
        ) : (
          <p className="text-destructive text-center text-sm">{details.error}</p>
        )}
      </div>
    </div>
  );
}
