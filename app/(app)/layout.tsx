import { and, desc, eq, isNull } from "drizzle-orm";
import { AppNav } from "@/components/app-nav";
import { EditionSwitcher } from "@/components/edition-switcher";
import { MobileNav } from "@/components/mobile-nav";
import { NotificationsBell } from "@/components/notifications-bell";
import { SignOutButton } from "@/components/auth/sign-out-button";
import { Wordmark } from "@/components/wordmark";
import { db } from "@/lib/db/client";
import { notifications } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { listEditions } from "@/lib/queries/editions";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await requireStaffSession();
  const editions = await listEditions();
  const recentNotifications = await db
    .select()
    .from(notifications)
    .where(eq(notifications.userId, session.user.id))
    .orderBy(desc(notifications.createdAt))
    .limit(12);
  const unread = await db
    .select({ id: notifications.id })
    .from(notifications)
    .where(and(eq(notifications.userId, session.user.id), isNull(notifications.readAt)));

  return (
    <div className="flex min-h-screen flex-col">
      <header className="bg-background sticky top-0 z-40 flex h-14 items-center gap-2 border-b px-3 sm:gap-4 sm:px-4">
        <MobileNav
          editions={editions.map((e) => ({ code: e.edition.code, status: e.edition.status }))}
          brandName={session.organisation.brandName}
        />
        <Wordmark name={session.organisation.brandName} size="sm" />
        <EditionSwitcher
          editions={editions.map((e) => ({
            code: e.edition.code,
            name: e.edition.name,
            status: e.edition.status,
          }))}
        />
        <div className="ml-auto flex items-center gap-2">
          <NotificationsBell
            unreadCount={unread.length}
            notifications={recentNotifications.map((n) => ({
              id: n.id,
              title: n.title,
              link: n.link,
              createdAt: n.createdAt.toISOString(),
              unread: !n.readAt,
            }))}
          />
          <span className="text-muted-foreground hidden text-xs sm:inline">
            {session.user.fullName || session.user.email} · {session.actor.role}
          </span>
          <SignOutButton />
        </div>
      </header>
      <div className="flex flex-1">
        <aside className="bg-sidebar text-sidebar-foreground hidden w-56 shrink-0 border-r md:block">
          <AppNav
            editions={editions.map((e) => ({ code: e.edition.code, status: e.edition.status }))}
          />
        </aside>
        <main className="min-w-0 flex-1">{children}</main>
      </div>
    </div>
  );
}
