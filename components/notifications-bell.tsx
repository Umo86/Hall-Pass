"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Bell } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { markAllNotificationsRead } from "@/app/actions/notifications";

export type BellNotification = {
  id: string;
  title: string;
  link: string | null;
  createdAt: string;
  unread: boolean;
};

const POLL_MS = 30_000;

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

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label={`Notifications (${liveCount} unread)`} className="relative">
          <Bell className="size-4" aria-hidden />
          {liveCount > 0 && (
            <span className="bg-destructive absolute top-1 right-1 flex size-4 items-center justify-center rounded-full text-[10px] font-semibold text-white">
              {liveCount > 9 ? "9+" : liveCount}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-96">
        <DropdownMenuLabel className="flex items-center justify-between">
          Notifications
          {liveCount > 0 && (
            <button
              className="text-muted-foreground text-xs underline-offset-2 hover:underline"
              disabled={pending}
              onClick={() =>
                start(async () => {
                  await markAllNotificationsRead();
                  setPolled(0);
                  router.refresh();
                })
              }
            >
              Mark all read
            </button>
          )}
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        {notifications.length === 0 ? (
          <p className="text-muted-foreground px-2 py-4 text-center text-sm">All caught up.</p>
        ) : (
          notifications.map((n) => (
            <DropdownMenuItem key={n.id} asChild>
              <Link href={n.link ?? "#"} className="flex flex-col items-start gap-0.5">
                <span className={`text-sm ${n.unread ? "font-medium" : "text-muted-foreground"}`}>
                  {n.title}
                </span>
              </Link>
            </DropdownMenuItem>
          ))
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
