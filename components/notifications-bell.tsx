"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Bell,
  CalendarClock,
  CheckCheck,
  ClipboardCheck,
  FileText,
  Info,
  ListTodo,
  Settings,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { markAllNotificationsRead, markNotificationRead } from "@/app/actions/notifications";
import { formatDateTime } from "@/lib/format";
import { notificationGroup, type NotificationGroup } from "@/lib/notification-kinds";
import { cn } from "@/lib/utils";

export type BellNotification = {
  id: string;
  title: string;
  link: string | null;
  createdAt: string;
  unread: boolean;
  /** Optional so older callers keep working. */
  body?: string | null;
  kind?: string;
  /** A sign-off request whose step is no longer waiting on you. */
  done?: boolean;
};

const POLL_MS = 30_000;

const GROUP_ICONS: Record<NotificationGroup, React.ComponentType<{ className?: string }>> = {
  approval: ClipboardCheck,
  task: ListTodo,
  date: CalendarClock,
  item: FileText,
  other: Info,
};

export function NotificationsBell({
  notifications,
  unreadCount,
}: {
  notifications: BellNotification[];
  unreadCount: number;
}) {
  const [pending, start] = useTransition();
  const router = useRouter();
  // Live badge: polls a tiny count endpoint and refreshes the server-rendered
  // dropdown when it changes, so new notifications appear without navigating.
  const [polled, setPolled] = useState<number | null>(null);
  const [readIds, setReadIds] = useState<Set<string>>(() => new Set());
  const liveCount = polled ?? unreadCount;
  const shownRef = useRef(liveCount);
  useEffect(() => {
    shownRef.current = liveCount;
  }, [liveCount]);

  useEffect(() => {
    let stopped = false;
    async function poll() {
      if (document.hidden) return;
      try {
        const res = await fetch("/api/notifications/unread", { cache: "no-store" });
        if (!res.ok) return;
        const { unread } = (await res.json()) as { unread: number };
        if (stopped || typeof unread !== "number") return;
        if (unread !== shownRef.current) {
          setPolled(unread);
          router.refresh(); // re-render the dropdown list server-side
        }
      } catch {
        // Offline or transient failure — try again next tick.
      }
    }
    const id = setInterval(poll, POLL_MS);
    document.addEventListener("visibilitychange", poll);
    return () => {
      stopped = true;
      clearInterval(id);
      document.removeEventListener("visibilitychange", poll);
    };
  }, [router]);

  const isUnread = (n: BellNotification) => n.unread && !readIds.has(n.id);
  // Done requests are no longer new, whether or not they were opened.
  const fresh = notifications.filter((n) => isUnread(n) && !n.done);
  const earlier = notifications.filter((n) => !isUnread(n) || n.done);

  function markRead(n: BellNotification) {
    if (!isUnread(n)) return;
    setReadIds((s) => new Set(s).add(n.id));
    setPolled(Math.max(0, liveCount - 1));
    void markNotificationRead({ id: n.id });
  }

  const item = (n: BellNotification) => {
    const Icon = GROUP_ICONS[notificationGroup(n.kind ?? "")];
    const unread = isUnread(n);
    const content = (
      <span className="flex w-full min-w-0 items-start gap-2.5">
        <Icon
          className={cn(
            "mt-0.5 size-4 shrink-0",
            n.done ? "text-muted-foreground/60" : "text-muted-foreground",
          )}
        />
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span
            className={cn(
              "text-sm leading-snug",
              unread && !n.done ? "font-medium" : "text-muted-foreground",
            )}
          >
            {n.title}
          </span>
          {n.body && (
            <span className="text-muted-foreground truncate text-xs" title={n.body}>
              {n.body}
            </span>
          )}
          <span className="text-muted-foreground flex items-center gap-2 text-xs">
            {formatDateTime(n.createdAt)}
            {n.done && (
              <span className="rounded bg-emerald-50 px-1.5 font-medium text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
                Done
              </span>
            )}
          </span>
        </span>
        {unread && !n.done && (
          <span className="bg-primary mt-1.5 size-2 shrink-0 rounded-full" aria-label="Unread" />
        )}
      </span>
    );
    return n.link ? (
      <DropdownMenuItem key={n.id} asChild onSelect={() => markRead(n)}>
        <Link href={n.link}>{content}</Link>
      </DropdownMenuItem>
    ) : (
      <DropdownMenuItem key={n.id} onSelect={() => markRead(n)}>
        {content}
      </DropdownMenuItem>
    );
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="touch"
          aria-label={`Notifications (${liveCount} unread)`}
          title="Notifications"
          className="relative"
        >
          <Bell className="size-4" aria-hidden />
          {liveCount > 0 && (
            <span className="bg-destructive absolute top-1 right-1 flex size-4 items-center justify-center rounded-full text-[10px] font-semibold text-white">
              {liveCount > 9 ? "9+" : liveCount}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="end"
        className="max-h-[75vh] w-[min(26rem,calc(100vw-1.5rem))] overflow-y-auto"
      >
        <DropdownMenuLabel>Notifications</DropdownMenuLabel>
        {liveCount > 0 && (
          <DropdownMenuItem
            disabled={pending}
            onSelect={(e) => {
              e.preventDefault(); // keep the menu open on what was just read
              start(async () => {
                const res = await markAllNotificationsRead();
                if (!res.ok) {
                  toast.error(res.error);
                  return;
                }
                setReadIds(new Set(notifications.map((n) => n.id)));
                setPolled(0);
                router.refresh();
              });
            }}
          >
            <CheckCheck aria-hidden /> Mark all read
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        {notifications.length === 0 ? (
          <p className="text-muted-foreground px-2 py-4 text-center text-sm">All caught up.</p>
        ) : (
          <>
            {fresh.length > 0 && (
              <DropdownMenuGroup aria-label="New">
                <DropdownMenuLabel className="text-muted-foreground text-xs font-medium">
                  New
                </DropdownMenuLabel>
                {fresh.map(item)}
              </DropdownMenuGroup>
            )}
            {earlier.length > 0 && (
              <DropdownMenuGroup aria-label="Earlier">
                <DropdownMenuLabel className="text-muted-foreground text-xs font-medium">
                  Earlier
                </DropdownMenuLabel>
                {earlier.map(item)}
              </DropdownMenuGroup>
            )}
          </>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link href="/notifications">
            <Bell aria-hidden /> See all
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link href="/account">
            <Settings aria-hidden /> Notification settings
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
