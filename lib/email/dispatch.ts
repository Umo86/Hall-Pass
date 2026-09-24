import { appUrl } from "@/lib/app-url";
import "server-only";
import { and, eq, gt, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { notifications, users } from "@/lib/db/schema";
import { brandName } from "@/lib/config";
import { renderNotificationEmail } from "./template";
import { sendEmail } from "./send";

/** Kinds that stay in the app: one email per new item would bury real requests. */
const IN_APP_ONLY = new Set(["item_created"]);

/** Older notifications are not emailed late (e.g. when email is first switched on). */
const MAX_AGE_MS = 3 * 86_400_000;

export function emailConfigured(): boolean {
  return Boolean(process.env.RESEND_API_KEY);
}

/**
 * Sends the email counterpart of in-app notifications. Called right after
 * each notify() (post-response) and from the daily cron as the safety net.
 * A row is stamped only once its email is actually sent (or it needs none),
 * so failures are retried. Externals always receive portal links.
 */
export async function dispatchNotificationEmails(
  opts: { ids?: string[]; limit?: number } = {},
): Promise<number> {
  if (!emailConfigured()) return 0;
  if (opts.ids && opts.ids.length === 0) return 0;
  const rows = await db
    .select({ n: notifications, u: users })
    .from(notifications)
    .innerJoin(users, eq(notifications.userId, users.id))
    .where(
      and(
        isNull(notifications.emailedAt),
        gt(notifications.createdAt, new Date(Date.now() - MAX_AGE_MS)),
        opts.ids ? inArray(notifications.id, opts.ids) : undefined,
      ),
    )
    .limit(opts.limit ?? 100);
  if (rows.length === 0) return 0;

  const base = appUrl();
  const doneIds: string[] = [];
  let sent = 0;
  for (const { n, u } of rows) {
    // Already seen in the app, or never emailed: nothing to send.
    if (n.readAt || IN_APP_ONLY.has(n.kind)) {
      doneIds.push(n.id);
      continue;
    }
    const link = u.isExternal ? `${base}/portal/approvals` : n.link ? `${base}${n.link}` : base;
    const { html, text } = await renderNotificationEmail({
      brandName,
      title: n.title,
      bodyText: n.body ?? "There is activity that needs your attention.",
      ctaLabel: "Open in Hall Pass",
      ctaUrl: link,
    });
    const ok = await sendEmail({
      to: u.email,
      subject: n.title,
      html,
      text,
      template: n.kind,
      entityType: n.entityType,
      entityId: n.entityId,
    });
    if (ok) {
      doneIds.push(n.id);
      sent++;
    }
  }
  if (doneIds.length > 0) {
    await db
      .update(notifications)
      .set({ emailedAt: new Date() })
      .where(inArray(notifications.id, doneIds));
  }
  return sent;
}
