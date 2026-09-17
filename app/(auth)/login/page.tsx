import { redirect } from "next/navigation";
import { LoginForm } from "@/components/auth/login-form";
import { brandName } from "@/lib/config";
import { devAuthEnabled, getSession } from "@/lib/auth/actor";
import { supabaseConfigured } from "@/lib/auth/supabase-server";

export const metadata = { title: "Sign in" };
export const dynamic = "force-dynamic";

async function devUserList(): Promise<{ email: string; label: string }[]> {
  if (!devAuthEnabled()) return [];
  try {
    const { db } = await import("@/lib/db/client");
    const users = await db.query.users.findMany({ limit: 24 });
    return users
      .sort((a, b) => Number(a.isExternal) - Number(b.isExternal))
      .map((u) => ({
        email: u.email,
        label: u.fullName ? `${u.fullName}` : u.email.split("@")[0],
      }));
  } catch {
    return [];
  }
}

export default async function LoginPage() {
  const session = await getSession().catch(() => null);
  if (session) redirect(session.actor.kind === "staff" ? "/editions" : "/portal/approvals");

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Signage schedule and design sign-off</p>
        </div>
        <LoginForm
          supabaseEnabled={supabaseConfigured()}
          devEnabled={devAuthEnabled()}
          devUsers={await devUserList()}
        />
      </div>
    </div>
  );
}
