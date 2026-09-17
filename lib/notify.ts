/**
 * In-app notifications. Email delivery (react-email + Resend with retry)
 * happens in lib/email; this module records the notification rows and
 * fires emails best-effort so a failed send never fails the transaction.
 */
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
  if (rows.length > 0) await tx.insert(notifications).values(rows);
}
