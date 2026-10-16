"use client";

import { useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CheckCheck } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { markAllNotificationsRead, markNotificationRead } from "@/app/actions/notifications";

/** "Mark all read" on the notifications page. */
export function MarkAllReadButton({ disabled }: { disabled?: boolean }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      variant="outline"
      size="sm"
      disabled={disabled || pending}
      onClick={() =>
        start(async () => {
          const res = await markAllNotificationsRead();
          if (!res.ok) toast.error(res.error);
          else toast.success("All notifications marked read");
          router.refresh();
        })
      }
    >
      <CheckCheck aria-hidden /> {pending ? "Marking…" : "Mark all read"}
    </Button>
  );
}

/** A notification's link: opening it marks it read. */
export function NotificationLink({
  id,
  href,
  unread,
  children,
  className,
}: {
  id: string;
  href: string;
  unread: boolean;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <Link
      href={href}
      className={className}
      onClick={() => {
        if (unread) void markNotificationRead({ id });
      }}
    >
      {children}
    </Link>
  );
}

/** "Mark read" for one notification without opening it. */
export function MarkReadButton({ id, label }: { id: string; label: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      variant="ghost"
      size="sm"
      disabled={pending}
      aria-label={`Mark read: ${label}`}
      onClick={() =>
        start(async () => {
          const res = await markNotificationRead({ id });
          if (!res.ok) toast.error(res.error);
          router.refresh();
        })
      }
    >
      Mark read
    </Button>
  );
}
