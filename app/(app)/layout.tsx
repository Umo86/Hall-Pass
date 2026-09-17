import { Bell, Search } from "lucide-react";
import { AppNav } from "@/components/app-nav";
import { EditionSwitcher } from "@/components/edition-switcher";
import { SignOutButton } from "@/components/auth/sign-out-button";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { requireStaffSession } from "@/lib/auth/actor";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await requireStaffSession();

  return (
    <div className="flex min-h-screen flex-col">
      <header className="bg-background sticky top-0 z-40 flex h-14 items-center gap-4 border-b px-4">
        <div className="text-sm font-semibold tracking-tight">{session.organisation.brandName}</div>
        <EditionSwitcher />
        <div className="ml-auto flex items-center gap-2">
          <div className="relative hidden md:block">
            <Search
              className="text-muted-foreground absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
              aria-hidden
            />
            <Input type="search" placeholder="Search" className="h-8 w-56 pl-8" />
          </div>
          <Button variant="ghost" size="icon" aria-label="Notifications">
            <Bell className="size-4" aria-hidden />
          </Button>
          <span className="text-muted-foreground hidden text-xs sm:inline">
            {session.user.fullName || session.user.email} · {session.actor.role}
          </span>
          <SignOutButton />
        </div>
      </header>
      <div className="flex flex-1">
        <aside className="bg-sidebar text-sidebar-foreground hidden w-56 shrink-0 border-r md:block">
          <AppNav />
        </aside>
        <main className="min-w-0 flex-1">{children}</main>
      </div>
    </div>
  );
}
