/**
 * In-app notifications. This module records the notification rows; their
 * email counterparts are sent right after the response (lib/email/dispatch)
 * so a failed send never fails the transaction, with the daily cron as the
 * safety net.
 */
import { after } from "next/server";
import {
  editions,
  events,
  exhibitors,
  externalGrants,
  memberships,
  notifications,
  signageItems,
  standSubmissions,
  users,
} from "@/lib/db/schema";
import type { Db, Tx } from "@/lib/db/client";
import { and, eq, gt, inArray, isNull, notInArray, or, sql } from "drizzle-orm";
import { seesEdition, type StaffRole } from "@/lib/authz";
import { linkEditionCode } from "@/lib/edition-path";
import { activeMembership } from "@/lib/users/active";

export type NotifyInput = {
  userIds: string[];
  kind: string;
  title: string;
  body?: string;
  link?: string;
  entityType?:
    "signage_item" | "stand_submission" | "exhibitor" | "contractor" | "supplier" | "edition";
  entityId?: string;
  /**
   * Where the record lives. Partners (no team membership) are then kept
   * only with a live grant in that organisation — and on that event, when
   * one is given — instead of a live grant anywhere.
   */
  scope?: RecipientScope;
  /**
   * The one event a message with no record is about (a summary naming refs
   * of a single event: soleEditionId). Stored like a record's event, so the
   * bell and late emails hide it from someone later taken off that event,
   * and team members who can't open it aren't told. Unlike `scope`, it
   * doesn't narrow which partners are told.
   */
  editionId?: string | null;
};

export type RecipientScope = { organisationId: string; editionId?: string | null };

/**
 * The event a notification is about (Users → Events): the scope's event,
 * else the event given for a message without a record, else its record's
 * event (item, stand, exhibitor, event), else the event code at the start of
 * its link — looked up in the scope's organisation when one is given. Null:
 * about no one event ("/approvals", "/my-work" naming several events' work).
 */
export async function notificationEditionId(
  exec: Db | Tx,
  input: Pick<NotifyInput, "scope" | "editionId" | "entityType" | "entityId" | "link">,
): Promise<string | null> {
  if (input.scope?.editionId) return input.scope.editionId;
  if (input.editionId) return input.editionId;
  if (input.entityId) {
    switch (input.entityType) {
      case "edition":
        return input.entityId;
      case "signage_item": {
        const [r] = await exec
          .select({ id: signageItems.editionId })
          .from(signageItems)
          .where(eq(signageItems.id, input.entityId))
          .limit(1);
        if (r) return r.id;
        break;
      }
      case "stand_submission": {
        const [r] = await exec
          .select({ id: standSubmissions.editionId })
          .from(standSubmissions)
          .where(eq(standSubmissions.id, input.entityId))
          .limit(1);
        if (r) return r.id;
        break;
      }
      case "exhibitor": {
        const [r] = await exec
          .select({ id: exhibitors.editionId })
          .from(exhibitors)
          .where(eq(exhibitors.id, input.entityId))
          .limit(1);
        if (r) return r.id;
        break;
      }
    }
  }
  const code = linkEditionCode(input.link);
  if (!code) return null;
  const [r] = await exec
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(events.id, editions.eventId))
    .where(
      and(
        eq(editions.code, code),
        input.scope ? eq(events.organisationId, input.scope.organisationId) : undefined,
      ),
    )
    .limit(1);
  return r?.id ?? null;
}

/**
 * Of these people, the ones who may still be told anything: team members
 * whose access is active (not suspended, end date not reached), and portal
 * users with a live invitation (in `scope`, when given). People who have
 * left, been suspended or whose access has ended are dropped — the last
 * line of defence behind every recipient list. Whether a partner can see
 * the record itself is the caller's check (recipientsWhoCanSee). With
 * `opts.editionId`, team members who can't open that event are dropped too
 * (Users → Events); partners are unchanged (their grants decide).
 */
export async function activeRecipientIds(
  exec: Db | Tx,
  userIds: readonly string[],
  scope?: RecipientScope,
  opts: { editionId?: string | null } = {},
): Promise<Set<string>> {
  const ids = [...new Set(userIds)].filter(Boolean);
  if (ids.length === 0) return new Set();
  const members = await exec
    .select({
      userId: memberships.userId,
      active: sql<boolean>`${activeMembership()}`,
      role: memberships.role,
      editionIds: memberships.editionIds,
    })
    .from(memberships)
    .where(inArray(memberships.userId, ids));
  const keep = new Set<string>();
  const hasMembership = new Set<string>();
  for (const m of members) {
    hasMembership.add(m.userId);
    if (!m.active) continue;
    if (
      opts.editionId &&
      !seesEdition({ role: m.role as StaffRole, editionIds: m.editionIds }, opts.editionId)
    ) {
      continue;
    }
    keep.add(m.userId);
  }
  const others = ids.filter((id) => !hasMembership.has(id));
  if (others.length > 0) {
    const grants = await exec
      .select({ userId: externalGrants.userId })
      .from(externalGrants)
      .where(
        and(
          inArray(externalGrants.userId, others),
          isNull(externalGrants.revokedAt),
          or(isNull(externalGrants.expiresAt), gt(externalGrants.expiresAt, new Date())),
          scope ? eq(externalGrants.organisationId, scope.organisationId) : undefined,
          scope?.editionId ? eq(externalGrants.editionId, scope.editionId) : undefined,
        ),
      );
    for (const g of grants) if (g.userId) keep.add(g.userId);
  }
  return keep;
}

export async function notify(tx: Tx, input: NotifyInput): Promise<void> {
  const wanted = [...new Set(input.userIds)].filter(Boolean);
  if (wanted.length === 0) return;
  // The event it is about: nobody who can't open it is told, and the row
  // keeps it so the bell and late emails stay filtered after a change.
  const editionId = await notificationEditionId(tx, input);
  const allowed = await activeRecipientIds(tx, wanted, input.scope, { editionId });
  const ids = wanted.filter((id) => allowed.has(id));
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
      editionId,
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
