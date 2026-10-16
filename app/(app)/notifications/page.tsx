import Link from "next/link";
import { and, count, desc, eq, isNull } from "drizzle-orm";
import {
  BellOff,
  CalendarClock,
  ClipboardCheck,
  FileText,
  Info,
  ListTodo,
  Settings,
} from "lucide-react";
import { db } from "@/lib/db/client";
import { notifications } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { pendingEntityIdsForUser } from "@/lib/queries/approvals";
import {
  isApprovalRequestKind,
  notificationGroup,
  type NotificationGroup,
} from "@/lib/notification-kinds";
import { formatDateTime } from "@/lib/format";
import { cn } from "@/lib/utils";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SegmentedLinks } from "@/components/ui/segmented";
import { Button } from "@/components/ui/button";
import { MarkAllReadButton, MarkReadButton, NotificationLink } from "./notification-actions";

export const metadata = { title: "Notifications" };
export const dynamic = "force-dynamic";

const PAGE_SIZE = 50;

/** The same icons as the bell. */
const GROUP_ICONS: Record<NotificationGroup, React.ComponentType<{ className?: string }>> = {
  approval: ClipboardCheck,
  task: ListTodo,
  date: CalendarClock,
  item: FileText,
  other: Info,
};

/** Every notification you have had, newest first, 50 to a page. */
export default async function NotificationsPage({
  searchParams,
}: {
  searchParams: Promise<{ filter?: string; page?: string }>;
}) {
  const session = await requireStaffSession();
  const params = await searchParams;
  const unreadOnly = params.filter === "unread";
  const page = Math.max(1, Math.min(1000, Number.parseInt(params.page ?? "1", 10) || 1));
  const mine = eq(notifications.userId, session.user.id);
  const where = unreadOnly ? and(mine, isNull(notifications.readAt)) : mine;

  const [rows, [{ n: total }], [{ n: unread }]] = await Promise.all([
    db
      .select()
      .from(notifications)
      .where(where)
      .orderBy(desc(notifications.createdAt))
      .limit(PAGE_SIZE)
      .offset((page - 1) * PAGE_SIZE),
    db.select({ n: count() }).from(notifications).where(where),
    db
      .select({ n: count() })
      .from(notifications)
      .where(and(mine, isNull(notifications.readAt))),
  ]);
  const stillMine = await pendingEntityIdsForUser(
    session,
    rows.filter((r) => isApprovalRequestKind(r.kind) && r.entityId).map((r) => r.entityId!),
  );
  const pages = Math.max(1, Math.ceil(Number(total) / PAGE_SIZE));
  const href = (p: { filter?: string; page?: number }) => {
    const q = new URLSearchParams();
    if (p.filter) q.set("filter", p.filter);
    if (p.page && p.page > 1) q.set("page", String(p.page));
    const s = q.toString();
    return s ? `/notifications?${s}` : "/notifications";
  };

  return (
    <Page width="narrow">
      <PageHeader
        title="Notifications"
        description={`Everything ${session.organisation.brandName} has told you, newest first. Sign-off requests show as Done once they are no longer waiting on you.`}
        meta={`${unread} unread`}
        actions={
          <>
            <MarkAllReadButton disabled={Number(unread) === 0} />
            <Button asChild variant="ghost" size="sm">
              <Link href="/account">
                <Settings aria-hidden /> Notification settings
              </Link>
            </Button>
          </>
        }
      />
      <SegmentedLinks
        label="Which notifications"
        items={[
          { label: "All", href: href({}), active: !unreadOnly },
          {
            label: "Unread",
            href: href({ filter: "unread" }),
            active: unreadOnly,
            count: Number(unread),
          },
        ]}
      />
      {rows.length === 0 ? (
        <EmptyState
          icon={BellOff}
          title={unreadOnly ? "Nothing unread" : "No notifications yet"}
          description={
            unreadOnly
              ? "You're all caught up."
              : "Sign-off requests, decisions, tasks and reminders appear here."
          }
          action={
            unreadOnly ? (
              <Button asChild variant="outline">
                <Link href="/notifications">Show all</Link>
              </Button>
            ) : undefined
          }
        />
      ) : (
        <ol className="divide-y rounded-lg border" aria-label="Notifications">
          {rows.map((n) => {
            const Icon = GROUP_ICONS[notificationGroup(n.kind)];
            const isUnread = !n.readAt;
            const done =
              isApprovalRequestKind(n.kind) && Boolean(n.entityId) && !stillMine.has(n.entityId!);
            const body = (
              <>
                <span
                  className={cn(
                    "block text-sm",
                    isUnread && !done ? "font-medium" : "text-muted-foreground",
                  )}
                >
                  {n.title}
                </span>
                {n.body && (
                  <span className="text-muted-foreground block text-xs whitespace-pre-line">
                    {n.body}
                  </span>
                )}
              </>
            );
            return (
              <li key={n.id} className="flex items-start gap-3 p-3">
                <Icon className="text-muted-foreground mt-0.5 size-4 shrink-0" aria-hidden />
                <div className="min-w-0 flex-1 space-y-0.5">
                  {n.link ? (
                    <NotificationLink
                      id={n.id}
                      href={n.link}
                      unread={isUnread}
                      className="block hover:underline"
                    >
                      {body}
                    </NotificationLink>
                  ) : (
                    body
                  )}
                  <p className="text-muted-foreground flex flex-wrap items-center gap-2 text-xs">
                    {formatDateTime(n.createdAt)}
                    {done && (
                      <span className="rounded bg-emerald-50 px-1.5 font-medium text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
                        Done
                      </span>
                    )}
                    {isUnread && !done && (
                      <span className="bg-primary/10 text-primary rounded px-1.5 font-medium">
                        New
                      </span>
                    )}
                  </p>
                </div>
                {isUnread && <MarkReadButton id={n.id} label={n.title} />}
              </li>
            );
          })}
        </ol>
      )}
      {pages > 1 && (
        <nav className="flex items-center justify-between text-sm" aria-label="Pages">
          {page > 1 ? (
            <Link
              className="link"
              href={href({ filter: unreadOnly ? "unread" : undefined, page: page - 1 })}
            >
              ← Newer
            </Link>
          ) : (
            <span />
          )}
          <span className="text-muted-foreground">
            Page {page} of {pages}
          </span>
          {page < pages ? (
            <Link
              className="link"
              href={href({ filter: unreadOnly ? "unread" : undefined, page: page + 1 })}
            >
              Older →
            </Link>
          ) : (
            <span />
          )}
        </nav>
      )}
    </Page>
  );
}
