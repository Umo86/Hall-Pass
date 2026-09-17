import Link from "next/link";
import { brandName } from "@/lib/config";

// External users get a reduced navigation: My Sign-offs, My Items, My Submission.
export default function PortalLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="bg-background sticky top-0 z-40 flex h-14 items-center gap-6 border-b px-4">
        <div className="text-sm font-semibold tracking-tight">{brandName}</div>
        <nav className="flex items-center gap-4 text-sm" aria-label="Portal navigation">
          <Link href="/portal/approvals" className="text-muted-foreground hover:text-foreground">
            My Sign-offs
          </Link>
          <Link href="/portal/items" className="text-muted-foreground hover:text-foreground">
            My Items
          </Link>
          <Link href="/portal/submission" className="text-muted-foreground hover:text-foreground">
            My Submission
          </Link>
        </nav>
      </header>
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
