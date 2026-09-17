export const metadata = { title: "Accept invitation" };

// Placeholder — external grant acceptance (token check, expiry, set name,
// land in the portal) is built in Phase 0, milestone 0.C.
export default async function InvitePage({ params }: { params: Promise<{ token: string }> }) {
  await params;
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="max-w-sm space-y-2 text-center">
        <h1 className="text-xl font-semibold tracking-tight">Accept invitation</h1>
        <p className="text-muted-foreground text-sm">
          Invitation acceptance is not yet available — it arrives with Phase 0 authentication.
        </p>
      </div>
    </div>
  );
}
