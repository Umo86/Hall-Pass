import { appUrl } from "@/lib/app-url";
import "server-only";
import { and, eq, gt, inArray, isNull, or } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  externalGrants,
  memberships,
  notifications,
  signageItems,
  standSubmissions,
  users,
} from "@/lib/db/schema";
import { brandName } from "@/lib/config";
import { seesEdition } from "@/lib/authz";
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

  // People who have left, are suspended or whose access has ended get no email.
  const { activeRecipientIds } = await import("@/lib/notify");
  const allowed = await activeRecipientIds(
    db,
    rows.map((r) => r.u.id),
  );
  // Partners (no team membership) get portal links. Decided by membership,
  // never by the users.is_external flag.
  const memberRows = await db
    .select({
      userId: memberships.userId,
      role: memberships.role,
      editionIds: memberships.editionIds,
    })
    .from(memberships)
    .where(
      inArray(
        memberships.userId,
        rows.map((r) => r.u.id),
      ),
    );
  const members = new Set(memberRows.map((r) => r.userId));
  // A team member is never emailed about an event since taken away from them
  // (Users → Events); the row is stamped done instead.
  const opensEvent = (userId: string, editionId: string | null) =>
    !editionId || memberRows.some((m) => m.userId === userId && seesEdition(m, editionId));
  // A partner is emailed about an item or stand only while they still hold
  // live access to its event (it may have been revoked since the
  // notification was made); ref and body never reach anyone else.
  const partnerOk = await partnersStillOnEvent(
    rows.filter((r) => !members.has(r.u.id)).map((r) => r.n),
  );
  const base = appUrl();
  const doneIds: string[] = [];
  let sent = 0;
  for (const { n, u } of rows) {
    // Already seen in the app, never emailed, or no longer allowed: nothing to send.
    if (
      n.readAt ||
      IN_APP_ONLY.has(n.kind) ||
      !allowed.has(u.id) ||
      (!members.has(u.id) && !partnerOk.has(n.id)) ||
      (members.has(u.id) && !opensEvent(u.id, n.editionId))
    ) {
      doneIds.push(n.id);
      continue;
    }
    const link = !members.has(u.id)
      ? `${base}/portal/approvals`
      : n.link
        ? `${base}${n.link}`
        : base;
    const { html, text } = await renderNotificationEmail({
      brandName,
      title: n.title,
      bodyText: n.body ?? "There is activity that needs your attention.",
      ctaLabel: `Open in ${brandName}`,
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

/**
 * Of these partners' notifications, the ones they may still be emailed:
 * those about something other than an item or stand, and those about an
 * item or stand on an event where they hold a live grant now.
 */
async function partnersStillOnEvent(
  rows: readonly (typeof notifications.$inferSelect)[],
): Promise<Set<string>> {
  const ok = new Set<string>();
  const about = rows.filter(
    (n) => n.entityId && (n.entityType === "signage_item" || n.entityType === "stand_submission"),
  );
  for (const n of rows) if (!about.includes(n)) ok.add(n.id);
  if (about.length === 0) return ok;
  const ids = (type: string) => [
    ...new Set(about.filter((n) => n.entityType === type).map((n) => n.entityId!)),
  ];
  const [items, stands, grants] = await Promise.all([
    ids("signage_item").length
      ? db
          .select({ id: signageItems.id, editionId: signageItems.editionId })
          .from(signageItems)
          .where(inArray(signageItems.id, ids("signage_item")))
      : [],
    ids("stand_submission").length
      ? db
          .select({ id: standSubmissions.id, editionId: standSubmissions.editionId })
          .from(standSubmissions)
          .where(inArray(standSubmissions.id, ids("stand_submission")))
      : [],
    db
      .select({ userId: externalGrants.userId, editionId: externalGrants.editionId })
      .from(externalGrants)
      .where(
        and(
          inArray(externalGrants.userId, [...new Set(about.map((n) => n.userId))]),
          isNull(externalGrants.revokedAt),
          or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, new Date())),
        ),
      ),
  ]);
  const editionOf = new Map([...items, ...stands].map((r) => [r.id, r.editionId]));
  const live = new Set(grants.map((g) => `${g.userId}:${g.editionId}`));
  for (const n of about) {
    const editionId = editionOf.get(n.entityId!);
    if (editionId && live.has(`${n.userId}:${editionId}`)) ok.add(n.id);
  }
  return ok;
}
