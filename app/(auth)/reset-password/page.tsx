import Link from "next/link";
import { NewPasswordForm } from "@/components/auth/new-password-form";
import { brandName } from "@/lib/config";
import { resetTokenUserId } from "@/lib/auth/links";

export const metadata = { title: "Choose a new password" };
export const dynamic = "force-dynamic";

/**
 * Where the "Forgot password?" email (or a super admin's reset link) lands:
 * the token is in the address. Saving the password signs them in.
 */
export default async function ResetPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const { token } = await searchParams;
  const valid = token ? Boolean(await resetTokenUserId(token).catch(() => null)) : false;
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Choose a new password</p>
        </div>
        {valid && token ? (
          <NewPasswordForm token={token} />
        ) : (
          <div className="space-y-3 text-center">
            <p className="text-destructive text-sm">This link has expired or was already used.</p>
            <Link href="/login" className="text-sm underline">
              Ask for a new one
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
