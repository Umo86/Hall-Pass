/**
 * In-app notifications. This module records the notification rows; their
 * email counterparts are sent right after the response (lib/email/dispatch)
 * so a failed send never fails the transaction, with the daily cron as the
 * safety net.
 */
import { after } from "next/server";
import { notifications, users } from "@/lib/db/schema";
import type { Db, Tx } from "@/lib/db/client";
import { and, eq, inArray, isNull, notInArray } from "drizzle-orm";

export type NotifyInput = {
  userIds: string[];
  kind: string;
  title: string;
  body?: string;
  link?: string;
  entityType?:
    "signage_item" | "stand_submission" | "exhibitor" | "contractor" | "supplier" | "edition";
  entityId?: string;
};

export async function notify(tx: Tx, input: NotifyInput): Promise<void> {
  const ids = [...new Set(input.userIds)].filter(Boolean);
  if (ids.length === 0) return;
  const recipients = await tx.select().from(users).where(inArray(users.id, ids));
  const rows = recipients
    .filter((u) => u.notificationPrefs[input.kind] !== false) // per-kind mute
    .map((u) => ({
      userId: u.id,
      kind: input.kind,
      title: input.title,
      body: input.body ?? null,
      link: input.link ?? null,
      entityType: input.entityType ?? null,
      entityId: input.entityId ?? null,
    }));
  if (rows.length === 0) return;
  const inserted = await tx.insert(notifications).values(rows).returning({ id: notifications.id });
  const newIds = inserted.map((r) => r.id);
  try {
    // Runs after the response (and after this transaction commits); rows from
    // a rolled-back transaction simply aren't found.
    after(async () => {
      const { dispatchNotificationEmails } = await import("@/lib/email/dispatch");
      await dispatchNotificationEmails({ ids: newIds });
    });
  } catch {
    // Outside a request (seed, tests): the daily cron sends these instead.
  }
}

/**
 * Mark a record's notifications read for everyone except `exceptUserIds` —
 * used when the thing they asked for has been done (a sign-off decided,
 * delegated or no longer needed). Returns how many were settled. A settled
 * notification is also never emailed late (lib/email/dispatch skips read ones).
 */
export async function resolveNotifications(
  exec: Db | Tx,
  opts: {
    entityType: NonNullable<NotifyInput["entityType"]>;
    entityId: string;
    kinds: readonly string[];
    exceptUserIds?: string[];
  },
): Promise<number> {
  if (opts.kinds.length === 0) return 0;
  const keep = [...new Set(opts.exceptUserIds ?? [])].filter(Boolean);
  const rows = await exec
    .update(notifications)
    .set({ readAt: new Date() })
    .where(
      and(
        eq(notifications.entityType, opts.entityType),
        eq(notifications.entityId, opts.entityId),
        inArray(notifications.kind, [...opts.kinds]),
        isNull(notifications.readAt),
        keep.length > 0 ? notInArray(notifications.userId, keep) : undefined,
      ),
    )
    .returning({ id: notifications.id });
  return rows.length;
}
