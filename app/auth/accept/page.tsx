import type { ReactNode } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { AcceptAccount } from "@/components/auth/accept-account";
import { brandName } from "@/lib/config";
import { authConfigured } from "@/lib/auth/config";
import { getAuthSession } from "@/lib/auth/session";
import { hasPassword } from "@/lib/auth/accounts";
import { safeNext } from "@/lib/edition-path";

export const metadata = { title: "Set up your account" };
export const dynamic = "force-dynamic";

function Frame({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="space-y-1 text-center">
          <h1 className="text-xl font-semibold tracking-tight">{brandName}</h1>
          <p className="text-muted-foreground text-sm">Set up your account</p>
        </div>
        {children}
      </div>
    </div>
  );
}

function Problem({ message }: { message: string }) {
  return (
    <div className="space-y-3 text-center">
      <p className="text-destructive text-sm">{message}</p>
      <Link href="/login" className="text-sm underline">
        Go to sign in
      </Link>
    </div>
  );
}

/**
 * Where an email link lands someone invited who has no account yet: the
 * link has signed them in; they choose their name and password here.
 * Anyone signed in who already has a password goes straight on.
 */
export default async function AcceptPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  if (!authConfigured()) {
    return (
      <Frame>
        <Problem message="Sign-in isn't set up on this site." />
      </Frame>
    );
  }
  const session = await getAuthSession();
  if (!session?.user) {
    return (
      <Frame>
        <Problem message="Open this page from the invitation email we sent you." />
      </Frame>
    );
  }
  if (await hasPassword(session.user.id)) {
    redirect(safeNext((await searchParams).next) ?? "/");
  }
  return (
    <Frame>
      <AcceptAccount email={session.user.email} name={session.user.name ?? ""} />
    </Frame>
  );
}
