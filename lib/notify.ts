/**
 * In-app notifications. This module records the notification rows; their
 * email counterparts are sent right after the response (lib/email/dispatch)
 * so a failed send never fails the transaction, with the daily cron as the
 * safety net.
 */
import { after } from "next/server";
import { notifications, users } from "@/lib/db/schema";
import type { Tx } from "@/lib/db/client";
import { inArray } from "drizzle-orm";

export type NotifyInput = {
  userIds: string[];
  kind: string;
  title: string;
  body?: string;
  link?: string;
  entityType?:
    | "signage_item"
    | "stand_submission"
    | "exhibitor"
    | "contractor"
    | "supplier"
    | "edition";
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
