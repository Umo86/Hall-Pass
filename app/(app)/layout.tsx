import { cookies } from "next/headers";
import { and, count, desc, eq, isNull } from "drizzle-orm";
import { AppNav } from "@/components/app-nav";
import { EditionSwitcher } from "@/components/edition-switcher";
import { MobileNav } from "@/components/mobile-nav";
import { SidebarToggle } from "@/components/sidebar-toggle";
import { SIDEBAR_COOKIE } from "@/lib/sidebar";
import { NotificationsBell } from "@/components/notifications-bell";
import { AccountMenu } from "@/components/account-menu";
import { Wordmark } from "@/components/wordmark";
import { db } from "@/lib/db/client";
import { departments, notifications } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { DemoBanner } from "@/components/demo-banner";
import { listEditions } from "@/lib/queries/editions";
import { can, FEATURES, hasFeature } from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { roleLabel } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await requireStaffSession();
  const actor = session.actor;
  const [editions, recentNotifications, [unread], department] = await Promise.all([
    listEditions(session.organisation.id),
    db
      .select()
      .from(notifications)
      .where(eq(notifications.userId, session.user.id))
      .orderBy(desc(notifications.createdAt))
      .limit(12),
    db
      .select({ n: count() })
      .from(notifications)
      .where(and(eq(notifications.userId, session.user.id), isNull(notifications.readAt))),
    actor.departmentId
      ? db.query.departments.findFirst({ where: eq(departments.id, actor.departmentId) })
      : Promise.resolve(undefined),
  ]);

  const sidebarHidden = (await cookies()).get(SIDEBAR_COOKIE)?.value === "hidden";
  const navEditions = editions.map((e) => ({
    code: e.edition.code,
    name: e.edition.name,
    status: e.edition.status,
  }));
  const canSetup = can(actor, { type: "settings.manage" });
  const navOptions = {
    canSetup,
    canSettings: canSetup || can(actor, { type: "users.manage" }),
    showStands: standsEnabled,
    // Null = every section; otherwise the sections this person can use.
    features:
      actor.role === "admin" || actor.features == null
        ? null
        : FEATURES.filter((f) => hasFeature(actor, f)),
  };
  const account = {
    name: session.user.fullName,
    email: session.user.email,
    role: roleLabel(actor.role),
    department: department?.name ?? null,
  };

  return (
    <div
      className="group/app flex min-h-screen flex-col"
      data-sidebar={sidebarHidden ? "hidden" : "shown"}
    >
      <DemoBanner />
      <header className="bg-background sticky top-0 z-40 flex h-14 items-center gap-2 border-b px-3 sm:gap-4 sm:px-4">
        <MobileNav
          editions={navEditions}
          options={navOptions}
          brandName={session.organisation.brandName}
          account={account}
        />
        <SidebarToggle initiallyHidden={sidebarHidden} />
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
            unreadCount={Number(unread?.n ?? 0)}
            notifications={recentNotifications.map((n) => ({
              id: n.id,
              title: n.title,
              link: n.link,
              createdAt: n.createdAt.toISOString(),
              unread: !n.readAt,
            }))}
          />
          <span className="text-muted-foreground hidden text-xs lg:inline">
            {session.user.fullName || session.user.email}
          </span>
          <AccountMenu account={account} />
        </div>
      </header>
      <div className="flex flex-1">
        <aside className="bg-sidebar text-sidebar-foreground hidden w-56 shrink-0 border-r md:block md:group-data-[sidebar=hidden]/app:hidden">
          <AppNav editions={navEditions} options={navOptions} />
        </aside>
        <main id="main" tabIndex={-1} className="min-w-0 flex-1 outline-none">
          {children}
        </main>
      </div>
    </div>
  );
}
