import { appUrl } from "@/lib/app-url";
import "server-only";
import { eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { notifications, users } from "@/lib/db/schema";
import { brandName } from "@/lib/config";
import { renderNotificationEmail } from "./template";
import { sendEmail } from "./send";

/**
 * Sends the email counterpart of unemailed in-app notifications. Called
 * post-response from actions (best effort) and from the daily cron as the
 * safety net. Externals always receive portal links.
 */
export async function dispatchNotificationEmails(limit = 100): Promise<number> {
  const rows = await db
    .select({ n: notifications, u: users })
    .from(notifications)
    .innerJoin(users, eq(notifications.userId, users.id))
    .where(isNull(notifications.emailedAt))
    .limit(limit);
  if (rows.length === 0) return 0;

  const base = appUrl();
  const sentIds: string[] = [];
  for (const { n, u } of rows) {
    const link = u.isExternal ? `${base}/portal/approvals` : n.link ? `${base}${n.link}` : base;
    const { html, text } = await renderNotificationEmail({
      brandName,
      title: n.title,
      bodyText: n.body ?? "There is activity that needs your attention.",
      ctaLabel: "Open in Hall Pass",
      ctaUrl: link,
    });
    await sendEmail({
      to: u.email,
      subject: n.title,
      html,
      text,
      template: n.kind,
      entityType: n.entityType,
      entityId: n.entityId,
    });
    sentIds.push(n.id);
  }
  if (sentIds.length > 0) {
    await db
      .update(notifications)
      .set({ emailedAt: new Date() })
      .where(inArray(notifications.id, sentIds));
  }
  return sentIds.length;
}
