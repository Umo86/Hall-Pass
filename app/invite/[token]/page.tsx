import { InviteForm } from "@/components/auth/invite-form";
import { inviteDetails } from "@/app/actions/invites";
import { brandName } from "@/lib/config";

export const metadata = { title: "Accept invitation" };
export const dynamic = "force-dynamic";

export default async function InvitePage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const details = await inviteDetails(token);

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Accept your invitation</p>
        </div>
        {details.ok ? (
          <InviteForm token={token} invitedEmail={details.invitedEmail} />
        ) : (
          <p className="text-destructive text-center text-sm">{details.error}</p>
        )}
      </div>
    </div>
  );
}
