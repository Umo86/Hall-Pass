/**
 * Who on the team has access now (Users v2): the SQL twin of accessState()
 * in lib/access.ts. Every picker, validator and recipient list that builds a
 * list of team members adds activeMembership(), so suspended people and
 * people whose access end date has passed are never offered, asked or told.
 * The Users list and people's own history pages stay unfiltered.
 */
import { and, eq, gt, inArray, isNull, or, sql, type SQL } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { memberships } from "@/lib/db/schema";
import {
  confirmsForSuppliers,
  signoffPaused,
  type PermissionOverrides,
  type StaffRole,
} from "@/lib/authz";

/** Not suspended, and the access end date (if any) still ahead. */
export function activeMembership(): SQL {
  return and(
    isNull(memberships.suspendedAt),
    or(isNull(memberships.accessEndsAt), gt(memberships.accessEndsAt, sql`now()`)),
  )!;
}

export type ActiveMember = {
  userId: string;
  role: StaffRole;
  overrides: PermissionOverrides;
  departmentId: string | null;
};

/** The organisation's active team members, optionally only some roles or people. */
export async function activeMembers(
  db: Db | Tx,
  organisationId: string,
  opts: { roles?: readonly StaffRole[]; userIds?: readonly string[] } = {},
): Promise<ActiveMember[]> {
  if (opts.userIds && opts.userIds.length === 0) return [];
  const rows = await db
    .select({
      userId: memberships.userId,
      role: memberships.role,
      overrides: memberships.permissionOverrides,
      departmentId: memberships.departmentId,
    })
    .from(memberships)
    .where(
      and(
        eq(memberships.organisationId, organisationId),
        activeMembership(),
        opts.roles ? inArray(memberships.role, [...opts.roles]) : undefined,
        opts.userIds ? inArray(memberships.userId, [...opts.userIds]) : undefined,
      ),
    );
  return rows.map((r) => ({ ...r, overrides: (r.overrides ?? {}) as PermissionOverrides }));
}

/**
 * Who confirms print, delivery and install for suppliers (signage.confirm:
 * Operations by default; never someone whose sign-off is paused). Admins can
 * confirm anything but aren't asked.
 */
export async function productionConfirmerIds(
  db: Db | Tx,
  organisationId: string,
): Promise<string[]> {
  const members = await activeMembers(db, organisationId);
  return members.filter((m) => m.role !== "admin" && confirmsForSuppliers(m)).map((m) => m.userId);
}

/** Active members of these roles whose sign-off isn't paused. */
export async function activeSignersWithRole(
  db: Db | Tx,
  organisationId: string,
  role: StaffRole,
): Promise<string[]> {
  const members = await activeMembers(db, organisationId, { roles: [role] });
  return members.filter((m) => !signoffPaused(m.overrides)).map((m) => m.userId);
}
