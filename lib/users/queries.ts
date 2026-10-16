import "server-only";
/**
 * Reads behind Users: the team list (members and open invitations), one
 * person, and the departments with their people and approvers. Teams are
 * small (tens, not thousands), so filtering happens here after one read of
 * each table — always scoped to the organisation.
 */
import { and, asc, eq, isNull, ne, or } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import type { Db, Tx } from "@/lib/db/client";
import {
  approvers,
  departments,
  memberships,
  signageItems,
  staffInvites,
  editions,
  events,
  users,
} from "@/lib/db/schema";
import {
  parseFeatures,
  signoffPaused,
  type Feature,
  type ManagerScope,
  type PermissionOverrides,
  type StaffRole,
} from "@/lib/authz";
import { accessLive, accessState, canReceiveSignoff, type AccessState } from "@/lib/access";
import { formatDayMonth } from "@/lib/format";
import { staffInviteExpired } from "@/lib/auth/staff-invite";
import { inviteStatusText, sortPeople } from "./rules";

export type SignsOffFor = { departmentId: string; name: string; isMain: boolean };

export type TeamRow = {
  kind: "member" | "invite";
  /** The user id for members, the invitation id for invited people (both open /users/[id]). */
  id: string;
  name: string;
  email: string;
  isSelf: boolean;
  jobTitle: string | null;
  role: StaffRole;
  departmentId: string | null;
  departmentName: string | null;
  departmentArchived: boolean;
  features: Feature[] | null;
  overrides: PermissionOverrides;
  signsOffFor: SignsOffFor[];
  /** Members: active, suspended or ended (access end date passed); invitations as before. */
  status: "active" | "invited" | "expired" | "suspended" | "ended";
  statusText: string;
  invitedAt: Date | null;
  expiresAt: Date | null;
  invitedByName: string | null;
  /** Adds and changes people in this scope (null = not a manager). */
  managerScope: ManagerScope | null;
  /** Members only: access now (invitations are "active"). */
  access: AccessState;
  suspendedAt: Date | null;
  suspendedByName: string | null;
  /** Access ends at this moment (the end of a London day), if set. */
  accessEndsAt: Date | null;
  /** Last signed-in page load (users.last_seen_at), members only. */
  lastSeenAt: Date | null;
};

/** "Active", "Suspended 3 Oct", "Access ended 3 Oct" or "Access ends 3 Oct". */
export function memberStatusText(
  m: { suspendedAt: Date | null; accessEndsAt: Date | null },
  now = new Date(),
): string {
  const state = accessState(m, now);
  if (state === "suspended") return `Suspended ${formatDayMonth(m.suspendedAt)}`;
  if (state === "ended") return `Access ended ${formatDayMonth(m.accessEndsAt)}`;
  if (m.accessEndsAt) return `Access ends ${formatDayMonth(m.accessEndsAt)}`;
  return "Active";
}

export type DepartmentInfo = {
  id: string;
  name: string;
  signsOff: boolean;
  signsLast: boolean;
  defaultFor: string[];
  isArchived: boolean;
  sortOrder: number;
};

export async function listDepartmentInfo(
  db: Db | Tx,
  organisationId: string,
): Promise<DepartmentInfo[]> {
  return db
    .select({
      id: departments.id,
      name: departments.name,
      signsOff: departments.signsOff,
      signsLast: departments.signsLast,
      defaultFor: departments.defaultFor,
      isArchived: departments.isArchived,
      sortOrder: departments.sortOrder,
    })
    .from(departments)
    .where(eq(departments.organisationId, organisationId))
    .orderBy(asc(departments.sortOrder), asc(departments.name));
}

/** Everyone on the team plus open invitations, sorted by name with you first. */
export async function listTeam(
  db: Db | Tx,
  organisationId: string,
  viewerId: string,
  now = new Date(),
): Promise<{ rows: TeamRow[]; departments: DepartmentInfo[] }> {
  const inviter = alias(users, "inviter");
  const suspender = alias(users, "suspender");
  const [members, invites, depts, approverRows] = await Promise.all([
    db
      .select({
        m: memberships,
        u: users,
        suspenderName: suspender.fullName,
        suspenderEmail: suspender.email,
      })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .leftJoin(suspender, eq(suspender.id, memberships.suspendedBy))
      .where(eq(memberships.organisationId, organisationId)),
    db
      .select({ i: staffInvites, inviterName: inviter.fullName, inviterEmail: inviter.email })
      .from(staffInvites)
      .leftJoin(inviter, eq(inviter.id, staffInvites.invitedBy))
      .where(
        and(
          eq(staffInvites.organisationId, organisationId),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      ),
    listDepartmentInfo(db, organisationId),
    db
      .select({
        departmentId: approvers.departmentId,
        userId: approvers.userId,
        email: approvers.email,
        isMain: approvers.isMain,
      })
      .from(approvers)
      .where(eq(approvers.organisationId, organisationId)),
  ]);
  const deptById = new Map(depts.map((d) => [d.id, d]));
  const signoffsFor = (match: (a: (typeof approverRows)[number]) => boolean): SignsOffFor[] =>
    approverRows
      .filter(match)
      .map((a) => ({ a, d: deptById.get(a.departmentId) }))
      .filter((x) => x.d && !x.d.isArchived && x.d.signsOff)
      .sort((x, y) => x.d!.sortOrder - y.d!.sortOrder)
      .map(({ a, d }) => ({ departmentId: a.departmentId, name: d!.name, isMain: a.isMain }));

  const memberEmails = new Set(members.map(({ u }) => u.email.toLowerCase()));
  const rows: TeamRow[] = [
    ...members.map(({ m, u, suspenderName, suspenderEmail }): TeamRow => {
      const d = m.departmentId ? deptById.get(m.departmentId) : undefined;
      const access = accessState(m, now);
      return {
        kind: "member",
        id: u.id,
        name: u.fullName,
        email: u.email,
        isSelf: u.id === viewerId,
        jobTitle: m.jobTitle,
        role: m.role,
        departmentId: d?.id ?? null,
        departmentName: d?.name ?? null,
        departmentArchived: d?.isArchived ?? false,
        features: parseFeatures(m.features),
        overrides: m.permissionOverrides as PermissionOverrides,
        signsOffFor: signoffsFor(
          (a) => a.userId === u.id || (!a.userId && a.email === u.email.toLowerCase()),
        ),
        status: access,
        statusText: memberStatusText(m, now),
        invitedAt: null,
        expiresAt: null,
        invitedByName: null,
        managerScope: m.role === "admin" ? null : m.managerScope,
        access,
        suspendedAt: m.suspendedAt,
        suspendedByName: m.suspendedBy ? suspenderName || suspenderEmail || null : null,
        accessEndsAt: m.accessEndsAt,
        lastSeenAt: u.lastSeenAt,
      };
    }),
    ...invites
      .filter(({ i }) => !memberEmails.has(i.invitedEmail.toLowerCase()))
      .map(({ i, inviterName, inviterEmail }): TeamRow => {
        const d = i.departmentId ? deptById.get(i.departmentId) : undefined;
        const by = inviterName || inviterEmail || null;
        return {
          kind: "invite",
          id: i.id,
          name: i.fullName,
          email: i.invitedEmail,
          isSelf: false,
          jobTitle: i.jobTitle,
          role: i.role,
          departmentId: d?.id ?? null,
          departmentName: d?.name ?? null,
          departmentArchived: d?.isArchived ?? false,
          features: parseFeatures(i.features),
          overrides: i.permissionOverrides as PermissionOverrides,
          signsOffFor: signoffsFor((a) => !a.userId && a.email === i.invitedEmail),
          status: staffInviteExpired(i, now) ? "expired" : "invited",
          statusText: inviteStatusText(
            { createdAt: i.createdAt, expiresAt: i.expiresAt, inviterName: by },
            now,
          ),
          invitedAt: i.createdAt,
          expiresAt: i.expiresAt,
          invitedByName: by,
          managerScope: i.role === "admin" ? null : i.managerScope,
          access: "active",
          suspendedAt: null,
          suspendedByName: null,
          accessEndsAt: i.accessEndsAt,
          lastSeenAt: null,
        };
      }),
  ];
  return { rows: sortPeople(rows), departments: depts };
}

export type TeamFilters = {
  q?: string;
  /** A department id, or "none" for people without a (live) department. */
  dept?: string;
  role?: string;
  status?: "active" | "invited";
};

/** Has no department, or only an archived one: they show in the "needs a department" banner. */
export function needsDepartment(r: Pick<TeamRow, "departmentId" | "departmentArchived">) {
  return !r.departmentId || r.departmentArchived;
}

export function filterTeam(rows: TeamRow[], f: TeamFilters): TeamRow[] {
  const q = f.q?.trim().toLowerCase();
  return rows.filter((r) => {
    if (q && !`${r.name} ${r.email} ${r.jobTitle ?? ""}`.toLowerCase().includes(q)) return false;
    if (f.dept === "none" ? !needsDepartment(r) : f.dept && r.departmentId !== f.dept) return false;
    if (f.role && r.role !== f.role) return false;
    if (f.status === "active" && (r.kind !== "member" || r.access !== "active")) return false;
    if (f.status === "invited" && r.kind !== "invite") return false;
    return true;
  });
}

export type PersonDetail = TeamRow & {
  membershipId: string | null;
  /** Every department they sign off for, archived or switched-off ones included. */
  allSignoffs: { departmentId: string; isMain: boolean }[];
  /** Items they own, by section — shown when that section is switched off. */
  owned: Partial<Record<Feature, number>>;
  isOnlyAdmin: boolean;
};

/** One person (member by user id, or open invitation by id), or null. */
export async function loadPerson(
  db: Db | Tx,
  organisationId: string,
  id: string,
  viewerId: string,
): Promise<{ person: PersonDetail; departments: DepartmentInfo[] } | null> {
  const { rows, departments: depts } = await listTeam(db, organisationId, viewerId);
  const row = rows.find((r) => r.id === id);
  if (!row) return null;
  const owned: Partial<Record<Feature, number>> = {};
  let membershipId: string | null = null;
  if (row.kind === "member") {
    const [m] = await db
      .select({ id: memberships.id })
      .from(memberships)
      .where(and(eq(memberships.userId, id), eq(memberships.organisationId, organisationId)))
      .limit(1);
    membershipId = m?.id ?? null;
    const items = await db
      .select({ kind: signageItems.kind })
      .from(signageItems)
      .innerJoin(editions, eq(editions.id, signageItems.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(
        and(
          eq(events.organisationId, organisationId),
          eq(signageItems.ownerUserId, id),
          isNull(signageItems.deletedAt),
          ne(editions.status, "archived"),
        ),
      );
    for (const it of items) {
      const f: Feature =
        it.kind === "sponsorship_item"
          ? "sponsorship"
          : it.kind === "stand_design" || it.kind === "stand_panel"
            ? "stand_designs"
            : "signage";
      owned[f] = (owned[f] ?? 0) + 1;
    }
  }
  // The last super admin with access can't be demoted, suspended or removed.
  const admins = rows.filter(
    (r) => r.kind === "member" && r.role === "admin" && r.access === "active",
  );
  const signoffRows = await db
    .select({ departmentId: approvers.departmentId, isMain: approvers.isMain })
    .from(approvers)
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        row.kind === "member"
          ? or(
              eq(approvers.userId, row.id),
              and(isNull(approvers.userId), eq(approvers.email, row.email.toLowerCase())),
            )
          : and(isNull(approvers.userId), eq(approvers.email, row.email.toLowerCase())),
      ),
    );
  return {
    person: {
      ...row,
      membershipId,
      allSignoffs: [...new Map(signoffRows.map((s) => [s.departmentId, s])).values()],
      owned,
      isOnlyAdmin:
        row.kind === "member" &&
        row.role === "admin" &&
        row.access === "active" &&
        admins.length <= 1,
    },
    departments: depts,
  };
}

export type DepartmentCard = DepartmentInfo & {
  memberCount: number;
  approvers: {
    id: string;
    userId: string | null;
    name: string;
    jobTitle: string | null;
    email: string;
    isMain: boolean;
    /** active: can sign off; invited: waiting for them to accept; none: no account or invitation. */
    state: "active" | "paused" | "invited" | "none";
    /** Their person page, when there is one. */
    href: string | null;
  }[];
};

/** Departments with how many people are in each and who signs off for it. */
export async function listDepartmentCards(
  db: Db | Tx,
  organisationId: string,
): Promise<DepartmentCard[]> {
  const [depts, members, approverRows, invites] = await Promise.all([
    listDepartmentInfo(db, organisationId),
    db
      .select({ departmentId: memberships.departmentId })
      .from(memberships)
      .where(eq(memberships.organisationId, organisationId)),
    db
      .select({
        a: approvers,
        memberUserId: memberships.userId,
        overrides: memberships.permissionOverrides,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        userName: users.fullName,
      })
      .from(approvers)
      .leftJoin(
        memberships,
        and(
          eq(memberships.userId, approvers.userId),
          eq(memberships.organisationId, approvers.organisationId),
        ),
      )
      .leftJoin(users, eq(users.id, approvers.userId))
      .where(eq(approvers.organisationId, organisationId))
      .orderBy(asc(approvers.fullName)),
    db
      .select({ id: staffInvites.id, email: staffInvites.invitedEmail })
      .from(staffInvites)
      .where(
        and(
          eq(staffInvites.organisationId, organisationId),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      ),
  ]);
  const inviteByEmail = new Map(invites.map((i) => [i.email, i.id]));
  return depts.map((d) => ({
    ...d,
    memberCount: members.filter((m) => m.departmentId === d.id).length,
    approvers: approverRows
      .filter((r) => r.a.departmentId === d.id)
      .map(({ a, memberUserId, overrides, userName, suspendedAt, accessEndsAt }) => {
        const inviteId = !memberUserId ? inviteByEmail.get(a.email) : undefined;
        // Can't sign now: sign-off paused, suspended or access ended.
        const paused =
          signoffPaused(overrides as PermissionOverrides) ||
          !accessLive({ suspendedAt, accessEndsAt });
        return {
          id: a.id,
          userId: memberUserId ?? null,
          name: userName || a.fullName,
          jobTitle: a.jobTitle,
          email: a.email,
          isMain: a.isMain,
          state: memberUserId
            ? paused
              ? ("paused" as const)
              : ("active" as const)
            : inviteId
              ? ("invited" as const)
              : ("none" as const),
          href: memberUserId ? `/users/${memberUserId}` : inviteId ? `/users/${inviteId}` : null,
        };
      }),
  }));
}

/**
 * Team members to pick from when adding an approver: only people who can
 * sign now (active, not viewers, sign-off not paused — canReceiveSignoff).
 */
export async function memberOptions(db: Db | Tx, organisationId: string) {
  const rows = await db
    .select({
      userId: users.id,
      name: users.fullName,
      email: users.email,
      departmentId: memberships.departmentId,
      role: memberships.role,
      overrides: memberships.permissionOverrides,
      suspendedAt: memberships.suspendedAt,
      accessEndsAt: memberships.accessEndsAt,
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(eq(memberships.organisationId, organisationId))
    .orderBy(asc(users.fullName));
  return rows
    .filter((r) => canReceiveSignoff({ ...r, overrides: r.overrides as PermissionOverrides }))
    .map((r) => ({
      userId: r.userId,
      name: r.name || r.email,
      email: r.email,
      departmentId: r.departmentId,
    }));
}

/**
 * Departments for the person form, with each one's main approver (so the
 * form can say who a new main approver replaces). `person` marks rows that
 * are theirs.
 */
export async function departmentOptions(
  db: Db | Tx,
  organisationId: string,
  person?: { userId: string | null; email: string },
) {
  const [depts, mains] = await Promise.all([
    listDepartmentInfo(db, organisationId),
    db
      .select({
        departmentId: approvers.departmentId,
        userId: approvers.userId,
        email: approvers.email,
        name: approvers.fullName,
        userName: users.fullName,
      })
      .from(approvers)
      .leftJoin(users, eq(users.id, approvers.userId))
      .where(and(eq(approvers.organisationId, organisationId), eq(approvers.isMain, true))),
  ]);
  return depts.map((d) => {
    const main = mains.find((m) => m.departmentId === d.id);
    const mine =
      main && person
        ? (person.userId && main.userId === person.userId) ||
          (!main.userId && main.email === person.email.toLowerCase())
        : false;
    return {
      id: d.id,
      name: d.name,
      signsOff: d.signsOff,
      isArchived: d.isArchived,
      mainApprover: main ? main.userName || main.name : null,
      mainIsThisPerson: Boolean(mine),
    };
  });
}
