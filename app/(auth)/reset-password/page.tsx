import { NewPasswordForm } from "@/components/auth/new-password-form";
import { brandName } from "@/lib/config";

export const metadata = { title: "Choose a new password" };
export const dynamic = "force-dynamic";

/** Where the "Forgot password" email lands (signed in by the link). */
export default function ResetPasswordPage() {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Choose a new password</p>
        </div>
        <NewPasswordForm />
      </div>
    </div>
  );
}
