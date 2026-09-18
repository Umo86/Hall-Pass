import Link from "next/link";
import { SignOutButton } from "@/components/auth/sign-out-button";
import { requirePortalSession } from "@/lib/auth/actor";
import { Wordmark } from "@/components/wordmark";

export const dynamic = "force-dynamic";

// External users get a reduced navigation: My Sign-offs, My Items, My Submission.
export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const session = await requirePortalSession();
  const roles = new Set(session.actor.grants.map((g) => g.role));
  const showItems = roles.has("supplier") || roles.has("sponsor") || roles.has("venue");
  const showSubmission = roles.has("exhibitor") || roles.has("contractor");

  return (
    <div className="flex min-h-screen flex-col">
      <header className="bg-background sticky top-0 z-40 flex h-14 items-center gap-6 border-b px-4">
        <Wordmark name={session.organisation.brandName} size="sm" />
        <nav className="flex items-center gap-4 text-sm" aria-label="Portal navigation">
          <Link href="/portal/approvals" className="text-muted-foreground hover:text-foreground">
            My Sign-offs
          </Link>
          {showItems && (
            <Link href="/portal/items" className="text-muted-foreground hover:text-foreground">
              My Items
            </Link>
          )}
          {showSubmission && (
            <Link href="/portal/submission" className="text-muted-foreground hover:text-foreground">
              My Submission
            </Link>
          )}
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <span className="text-muted-foreground hidden text-xs sm:inline">
            {session.user.fullName || session.user.email}
          </span>
          <SignOutButton />
        </div>
      </header>
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
