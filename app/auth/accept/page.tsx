import { AcceptAccount } from "@/components/auth/accept-account";
import { brandName } from "@/lib/config";
import { supabasePublicKey } from "@/lib/auth/supabase-server";

export const metadata = { title: "Set up your account" };
export const dynamic = "force-dynamic";

/**
 * Where the invitation email lands. The link signs the invited person in
 * (Supabase puts the session in the address); they then choose their name
 * and password. Nobody else can reach a working version of this page.
 */
export default function AcceptPage() {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Set up your account</p>
        </div>
        <AcceptAccount
          supabaseUrl={process.env.NEXT_PUBLIC_SUPABASE_URL ?? ""}
          supabaseKey={supabasePublicKey() ?? ""}
        />
      </div>
    </div>
  );
}
