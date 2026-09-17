import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { brandName } from "@/lib/config";

export const metadata = { title: "Sign in" };

// Visual shell only — Supabase authentication is wired up in Phase 0,
// milestone 0.C. Staff sign in with a password (development) or magic
// link; external users sign in by magic link only.
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Signage schedule and design sign-off</p>
        </div>
        <form className="space-y-3" aria-label="Sign in">
          <label className="block space-y-1.5">
            <span className="text-sm font-medium">Email address</span>
            <Input type="email" name="email" autoComplete="email" placeholder="you@example.com" />
          </label>
          <Button type="button" className="w-full" disabled>
            Send magic link
          </Button>
        </form>
        <Separator />
        <p className="text-muted-foreground text-center text-xs">
          Sign-in is not yet available — authentication arrives with Phase 0.
        </p>
      </div>
    </div>
  );
}
