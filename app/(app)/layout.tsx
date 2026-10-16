import { cookies, headers } from "next/headers";
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
import {
  LAST_EVENT_COOKIE,
  eventGroup,
  listEditions,
  pickDefaultEdition,
  sortForGroup,
} from "@/lib/queries/editions";
import { getSetupStatus } from "@/lib/queries/setup";
import { editionCodeFromPath } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";
import { dateRangeWithYear } from "@/components/setup/format";
import { can, FEATURES, hasFeature } from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { roleLabel } from "@/lib/format";
import { countPendingForUser, pendingEntityIdsForUser } from "@/lib/queries/approvals";
import { myTaskSummary } from "@/lib/queries/tasks";
import { isApprovalRequestKind } from "@/lib/notification-kinds";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await requireStaffSession();
  const actor = session.actor;
  const [editions, recentNotifications, [unread], department, signoffs, myTasks] =
    await Promise.all([
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
      // Counts next to Approvals and My Work: two small SQL counts, no bundles.
      countPendingForUser(session),
      myTaskSummary({ organisationId: session.organisation.id, userId: session.user.id }),
    ]);
  // "Please sign off" notifications whose step is no longer yours show as Done.
  const stillMine = await pendingEntityIdsForUser(
    session,
    recentNotifications
      .filter((n) => isApprovalRequestKind(n.kind) && n.entityId)
      .map((n) => n.entityId!),
  );

  const cookieStore = await cookies();
  const sidebarHidden = cookieStore.get(SIDEBAR_COOKIE)?.value === "hidden";
  const canSetup = can(actor, { type: "settings.manage" });
  const today = todayInLondon();

  // The event pages without one in their address use: the last one opened,
  // else the next one coming up (see pickDefaultEdition).
  const defaultCode = pickDefaultEdition(
    editions.map((e) => ({
      code: e.edition.code,
      status: e.edition.status,
      openStart: e.edition.openStart,
      openEnd: e.edition.openEnd,
    })),
    { lastCode: cookieStore.get(LAST_EVENT_COOKIE)?.value ?? null, today },
  );
  // The event in the address (set by proxy.ts) or the default one: its setup
  // progress drives the "Setup 3/6" item in the side navigation.
  const pathCode = editionCodeFromPath(
    ((await headers()).get("x-hp-path") ?? "").split("?")[0],
  )?.toUpperCase();
  const current =
    editions.find((e) => e.edition.code === pathCode) ??
    editions.find((e) => e.edition.code === defaultCode) ??
    null;
  const setupStatus =
    // Only while the event is still to come: nobody sets up a finished one.
    canSetup && current && eventGroup(current.edition, today) === "upcoming"
      ? await getSetupStatus(current.edition, session.organisation.id, {
          canSetup,
          canUsers: can(actor, { type: "users.manage" }),
          canAddSigns: can(actor, { type: "signage.create" }),
        })
      : null;

  // The default event first, so the side navigation shows it on pages
  // without an event in their address.
  const ordered = [
    ...editions.filter((e) => e.edition.code === defaultCode),
    ...editions.filter((e) => e.edition.code !== defaultCode),
  ];
  const navEditions = ordered.map((e) => ({
    code: e.edition.code,
    name: e.edition.name,
    status: e.edition.status,
  }));
  const switcherEditions = (["upcoming", "past", "archived"] as const).flatMap((group) =>
    sortForGroup(
      editions
        .filter((e) => eventGroup(e.edition, today) === group)
        .map((e) => ({
          code: e.edition.code,
          name: e.edition.name,
          openStart: e.edition.openStart,
          group,
          line: `${dateRangeWithYear(e.edition.openStart, e.edition.openEnd)} · ${e.venue.name}`,
        })),
      group,
    ).map(({ code, name, group: g, line }) => ({ code, name, group: g, line })),
  );
  const navOptions = {
    canSetup,
    setup:
      current && setupStatus
        ? {
            code: current.edition.code,
            done: setupStatus.summary.done,
            total: setupStatus.summary.total,
          }
        : null,
    canSettings: canSetup || can(actor, { type: "users.manage" }),
    counts: {
      approvals: signoffs.total,
      approvalsOverdue: signoffs.overdue > 0,
      myWork: myTasks.overdue + myTasks.dueToday,
    },
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
          editions={switcherEditions}
          defaultCode={defaultCode}
          navCode={current?.edition.code ?? null}
          canSetup={canSetup}
        />
        <div className="ml-auto flex items-center gap-2">
          <NotificationsBell
            unreadCount={Number(unread?.n ?? 0)}
            notifications={recentNotifications.map((n) => ({
              id: n.id,
              title: n.title,
              body: n.body,
              kind: n.kind,
              link: n.link,
              createdAt: n.createdAt.toISOString(),
              unread: !n.readAt,
              done:
                isApprovalRequestKind(n.kind) && Boolean(n.entityId) && !stillMine.has(n.entityId!),
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
