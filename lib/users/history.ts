import "server-only";
/**
 * A person's access history (Users → person page): every audit row about
 * them, newest first. Rows written since Users v2 name the person
 * (audit_log.subject_user_id / subject_email); older ones are found by what
 * they were keyed on — their membership, their staff invitations, approver
 * rows naming their account or email, and their own user record.
 */
import { and, desc, eq, inArray, or, sql, type SQL } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import type { Db, Tx } from "@/lib/db/client";
import { auditLog, memberships, staffInvites, users } from "@/lib/db/schema";

export type AccessHistoryEntry = {
  id: string;
  at: Date;
  action: string;
  summary: string;
  /** Who made the change: a name, or "System" for the daily jobs. */
  actorName: string;
};

export async function accessHistory(
  db: Db | Tx,
  organisationId: string,
  person: { userId?: string | null; email?: string | null },
  opts: { limit?: number } = {},
): Promise<AccessHistoryEntry[]> {
  const userId = person.userId ?? null;
  const email = person.email?.trim().toLowerCase() ?? null;
  if (!userId && !email) return [];
  const [membershipRows, inviteRows] = await Promise.all([
    userId
      ? db
          .select({ id: memberships.id })
          .from(memberships)
          .where(
            and(eq(memberships.userId, userId), eq(memberships.organisationId, organisationId)),
          )
      : Promise.resolve([]),
    email
      ? db
          .select({ id: staffInvites.id })
          .from(staffInvites)
          .where(
            and(
              eq(staffInvites.organisationId, organisationId),
              eq(staffInvites.invitedEmail, email),
            ),
          )
      : Promise.resolve([]),
  ]);
  const matches: SQL[] = [];
  if (userId) {
    matches.push(eq(auditLog.subjectUserId, userId));
    matches.push(and(eq(auditLog.entityType, "user"), eq(auditLog.entityId, userId))!);
    // Membership rows from before subjects were recorded (also ones since removed).
    matches.push(
      and(eq(auditLog.entityType, "membership"), sql`${auditLog.before}->>'userId' = ${userId}`)!,
    );
    matches.push(
      and(eq(auditLog.entityType, "approver"), sql`${auditLog.after}->>'userId' = ${userId}`)!,
    );
  }
  if (email) {
    matches.push(eq(auditLog.subjectEmail, email));
    matches.push(
      and(
        eq(auditLog.entityType, "approver"),
        or(
          sql`lower(${auditLog.after}->>'email') = ${email}`,
          sql`lower(${auditLog.before}->>'email') = ${email}`,
        ),
      )!,
    );
  }
  const membershipIds = membershipRows.map((m) => m.id);
  if (membershipIds.length > 0) {
    matches.push(
      and(eq(auditLog.entityType, "membership"), inArray(auditLog.entityId, membershipIds))!,
    );
  }
  const inviteIds = inviteRows.map((i) => i.id);
  if (inviteIds.length > 0) {
    matches.push(
      and(
        inArray(auditLog.entityType, ["staff_invite", "approver"]),
        inArray(auditLog.entityId, inviteIds),
      )!,
    );
  }
  const actor = alias(users, "actor");
  const rows = await db
    .select({
      id: auditLog.id,
      at: auditLog.createdAt,
      action: auditLog.action,
      summary: auditLog.summary,
      actorType: auditLog.actorType,
      actorName: actor.fullName,
      actorEmail: actor.email,
    })
    .from(auditLog)
    .leftJoin(actor, eq(actor.id, auditLog.actorUserId))
    .where(and(eq(auditLog.organisationId, organisationId), or(...matches)))
    .orderBy(desc(auditLog.createdAt))
    .limit(opts.limit ?? 50);
  return rows.map((r) => ({
    id: r.id,
    at: r.at,
    action: r.action,
    summary: r.summary,
    actorName: r.actorType === "user" ? r.actorName || r.actorEmail || "Someone" : "System",
  }));
}
