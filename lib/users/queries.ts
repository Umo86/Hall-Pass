import "server-only";
/**
 * Reads behind Users: the team list (members and open invitations), one
 * person, and the departments with their people and approvers. Teams are
 * small (tens, not thousands), so filtering happens here after one read of
 * each table — always scoped to the organisation.
 */
import { and, asc, eq, inArray, isNull, ne, or } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import type { Db, Tx } from "@/lib/db/client";
import {
  approvers,
  departments,
  externalGrants,
  memberships,
  signageItems,
  staffInvites,
  editions,
  events,
  users,
} from "@/lib/db/schema";
import {
  abilityOn,
  parseFeatures,
  type AbilityKey,
  type Feature,
  type ManagerScope,
  type PermissionOverrides,
  type StaffRole,
} from "@/lib/authz";
import { accessLive, accessState, canReceiveSignoff, type AccessState } from "@/lib/access";
import { formatDayMonth } from "@/lib/format";
import { staffInviteExpired } from "@/lib/auth/staff-invite";
import { inviteStatusText, sortPeople } from "./rules";
import { activeMembership } from "./active";
import { filterPeople, lacksDepartment, type ListFilters } from "./list";

export type SignsOffFor = {
  departmentId: string;
  name: string;
  isMain: boolean;
  /** Invited: becomes main approver when they accept. */
  mainOnAccept: boolean;
};

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
  /**
   * Events they work on (Users → Events; invitations: what they'll get);
   * null = every event. People are organisation-wide: the list isn't
   * filtered by it.
   */
  editionIds: string[] | null;
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
        mainOnAccept: approvers.mainOnAccept,
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
      .map(({ a, d }) => ({
        departmentId: a.departmentId,
        name: d!.name,
        isMain: a.isMain,
        mainOnAccept: a.mainOnAccept,
      }));

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
        editionIds: m.role === "admin" ? null : (m.editionIds ?? null),
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
          editionIds: i.role === "admin" ? null : (i.editionIds ?? null),
        };
      }),
  ];
  return { rows: sortPeople(rows), departments: depts };
}

/** The list's filters (?q, ?dept, ?role incl. "manager", ?status, ?activity=stale). */
export type TeamFilters = ListFilters;

/** Has no department, or only an archived one: they show in the "needs a department" banner. */
export function needsDepartment(r: Pick<TeamRow, "departmentId" | "departmentArchived">) {
  return lacksDepartment(r);
}

export function filterTeam(rows: TeamRow[], f: TeamFilters, now = new Date()): TeamRow[] {
  return filterPeople(rows, f, now);
}

export type PersonDetail = TeamRow & {
  membershipId: string | null;
  /**
   * Every department they sign off for, archived or switched-off ones
   * included. isMain: main approver now, or (invited) when they accept.
   */
  allSignoffs: { departmentId: string; isMain: boolean }[];
  /** Invited: departments they become main approver for when they accept. */
  pendingMainFor: string[];
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
          ne(signageItems.status, "closed"),
          inArray(editions.status, ["planning", "live"]),
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
  // There must always be a super admin with lasting access (active, no end
  // date): the last one can't be demoted, suspended, removed or given an
  // end date (lib/users/manage.ts, anotherLastingSuperAdmin).
  const lasting = rows.filter(
    (r) =>
      r.kind === "member" && r.role === "admin" && r.access === "active" && r.accessEndsAt == null,
  );
  const signoffRows = await db
    .select({
      departmentId: approvers.departmentId,
      isMain: approvers.isMain,
      mainOnAccept: approvers.mainOnAccept,
    })
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
      allSignoffs: [
        ...new Map(
          signoffRows.map((s) => [
            s.departmentId,
            { departmentId: s.departmentId, isMain: s.isMain || s.mainOnAccept },
          ]),
        ).values(),
      ],
      pendingMainFor: [
        ...new Set(signoffRows.filter((s) => s.mainOnAccept).map((s) => s.departmentId)),
      ],
      owned,
      isOnlyAdmin:
        row.kind === "member" &&
        row.role === "admin" &&
        row.access === "active" &&
        row.accessEndsAt == null &&
        !lasting.some((a) => a.id !== row.id),
    },
    departments: depts,
  };
}

export type DepartmentCard = DepartmentInfo & {
  /** Everyone in it, suspended and ended people included. */
  memberCount: number;
  /** Of those, how many are suspended, and whose access has ended. */
  suspendedCount: number;
  endedCount: number;
  /** Department managers of this department (people with access). */
  managers: { userId: string; name: string }[];
  /** How many approvers can sign off now (canReceiveSignoff). */
  signersNow: number;
  approvers: {
    id: string;
    userId: string | null;
    name: string;
    jobTitle: string | null;
    email: string;
    isMain: boolean;
    /** Invited: becomes the main approver when they accept. */
    mainOnAccept: boolean;
    /** active: can sign off; paused: can't sign now; invited: waiting for them to accept; none: no account or a lapsed invitation. */
    state: "active" | "paused" | "invited" | "none";
    /** Why, in a few words, when they can't sign now ("Suspended", "Invitation expired — resend"…). */
    stateText: string | null;
    /** Their person page, when there is one. */
    href: string | null;
    /** Events they work on (invited: what they'll get); null = every event. */
    editionIds: string[] | null;
  }[];
};

/** Departments with who is in each, who manages it and who signs off for it. */
export async function listDepartmentCards(
  db: Db | Tx,
  organisationId: string,
  now = new Date(),
): Promise<DepartmentCard[]> {
  const [depts, members, approverRows, invites] = await Promise.all([
    listDepartmentInfo(db, organisationId),
    db
      .select({
        departmentId: memberships.departmentId,
        userId: memberships.userId,
        role: memberships.role,
        managerScope: memberships.managerScope,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        name: users.fullName,
        email: users.email,
      })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .where(eq(memberships.organisationId, organisationId)),
    db
      .select({
        a: approvers,
        memberUserId: memberships.userId,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        editionIds: memberships.editionIds,
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
      .select({
        id: staffInvites.id,
        email: staffInvites.invitedEmail,
        expiresAt: staffInvites.expiresAt,
        role: staffInvites.role,
        editionIds: staffInvites.editionIds,
      })
      .from(staffInvites)
      .where(
        and(
          eq(staffInvites.organisationId, organisationId),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      ),
  ]);
  const inviteByEmail = new Map(invites.map((i) => [i.email, i]));
  return depts.map((d) => {
    const inDept = members.filter((m) => m.departmentId === d.id);
    const cards = approverRows
      .filter((r) => r.a.departmentId === d.id)
      .map(
        ({ a, memberUserId, role, overrides, userName, suspendedAt, accessEndsAt, editionIds }) => {
          const invite = !memberUserId ? inviteByEmail.get(a.email) : undefined;
          const expired = invite ? staffInviteExpired(invite, now) : false;
          let state: DepartmentCard["approvers"][number]["state"];
          let stateText: string | null = null;
          if (memberUserId && role) {
            const access = accessState({ suspendedAt, accessEndsAt }, now);
            const canSign = canReceiveSignoff(
              { role, overrides: overrides as PermissionOverrides, suspendedAt, accessEndsAt },
              now,
            );
            state = canSign ? "active" : "paused";
            stateText = canSign
              ? null
              : access === "suspended"
                ? "Suspended"
                : access === "ended"
                  ? "Access ended"
                  : role === "viewer"
                    ? "Viewer — can't sign off"
                    : "Sign-off paused";
          } else if (invite && !expired) {
            state = "invited";
            stateText = "Invited — not set up yet";
          } else {
            state = "none";
            stateText = invite ? "Invitation expired — resend" : "No account yet";
          }
          return {
            id: a.id,
            userId: memberUserId ?? null,
            name: userName || a.fullName,
            jobTitle: a.jobTitle,
            email: a.email,
            isMain: a.isMain,
            mainOnAccept: a.mainOnAccept,
            state,
            stateText,
            href: memberUserId ? `/users/${memberUserId}` : invite ? `/users/${invite.id}` : null,
            editionIds: memberUserId
              ? role === "admin"
                ? null
                : (editionIds ?? null)
              : invite && invite.role !== "admin"
                ? (invite.editionIds ?? null)
                : null,
          };
        },
      );
    return {
      ...d,
      memberCount: inDept.length,
      suspendedCount: inDept.filter((m) => accessState(m, now) === "suspended").length,
      endedCount: inDept.filter((m) => accessState(m, now) === "ended").length,
      managers: inDept
        .filter((m) => m.role !== "admin" && m.managerScope === "department" && accessLive(m, now))
        .map((m) => ({ userId: m.userId, name: m.name || m.email })),
      signersNow: cards.filter((c) => c.state === "active").length,
      approvers: cards,
    };
  });
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
      editionIds: memberships.editionIds,
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
      /** Events they work on (the chip only); null = every event. */
      editionIds: r.role === "admin" ? null : (r.editionIds ?? null),
    }));
}

/**
 * Departments for the person form, with each one's main approver (so the
 * form can say who a new main approver replaces, and that someone only
 * invited takes over from a main who can sign when they accept) and anyone
 * else's pending "main when they accept" (which a new choice replaces).
 * `person` marks rows that are theirs.
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
        isMain: approvers.isMain,
        mainOnAccept: approvers.mainOnAccept,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        editionIds: memberships.editionIds,
      })
      .from(approvers)
      .leftJoin(users, eq(users.id, approvers.userId))
      .leftJoin(
        memberships,
        and(
          eq(memberships.userId, approvers.userId),
          eq(memberships.organisationId, approvers.organisationId),
        ),
      )
      .where(
        and(
          eq(approvers.organisationId, organisationId),
          or(eq(approvers.isMain, true), eq(approvers.mainOnAccept, true)),
        ),
      ),
  ]);
  const isPerson = (row: { userId: string | null; email: string }) =>
    person
      ? Boolean(
          (person.userId && row.userId === person.userId) ||
          (!row.userId && row.email === person.email.toLowerCase()),
        )
      : false;
  return depts.map((d) => {
    const main = mains.find((m) => m.departmentId === d.id && m.isMain);
    const pending = mains.find((m) => m.departmentId === d.id && m.mainOnAccept);
    const mine = main ? isPerson(main) : false;
    const pendingMine = pending ? isPerson(pending) : false;
    return {
      id: d.id,
      name: d.name,
      signsOff: d.signsOff,
      isArchived: d.isArchived,
      mainApprover: main ? main.userName || main.name : null,
      /** The main approver's events (Users → Events); null = every event. */
      mainEditionIds: main && main.role && main.role !== "admin" ? (main.editionIds ?? null) : null,
      mainIsThisPerson: Boolean(mine),
      mainCanSign: Boolean(
        main?.userId &&
        main.role &&
        canReceiveSignoff({
          role: main.role,
          overrides: main.overrides as PermissionOverrides,
          suspendedAt: main.suspendedAt,
          accessEndsAt: main.accessEndsAt,
        }),
      ),
      /** Someone else's "main approver when they accept" (a new choice replaces it). */
      pendingMain: pending && !pendingMine ? pending.userName || pending.name : null,
      /** This person is to become main approver when they accept. */
      pendingIsThisPerson: pendingMine,
    };
  });
}

/**
 * People with access who hold an ability (for "ask …" notes, e.g. who can
 * invite partners), super admins first.
 */
export async function abilityHolders(
  db: Db | Tx,
  organisationId: string,
  key: AbilityKey,
): Promise<{ name: string; email: string; role: StaffRole }[]> {
  const rows = await db
    .select({
      name: users.fullName,
      email: users.email,
      role: memberships.role,
      overrides: memberships.permissionOverrides,
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(and(eq(memberships.organisationId, organisationId), activeMembership()))
    .orderBy(asc(users.fullName));
  return rows
    .filter((r) => abilityOn({ role: r.role, overrides: r.overrides as PermissionOverrides }, key))
    .sort((a, b) => Number(b.role === "admin") - Number(a.role === "admin"))
    .map((r) => ({ name: r.name || r.email, email: r.email, role: r.role }));
}

/**
 * Someone a super admin may make a sign-in or reset link for: a member of
 * this organisation, or a partner with a grant in it. Null otherwise, so
 * another organisation's people read as "not found".
 */
export async function accessLinkTarget(
  db: Db | Tx,
  organisationId: string,
  userId: string,
): Promise<{ id: string; email: string; name: string } | null> {
  const [user] = await db
    .select({ id: users.id, email: users.email, name: users.fullName })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  if (!user) return null;
  const [member] = await db
    .select({ id: memberships.id })
    .from(memberships)
    .where(and(eq(memberships.userId, userId), eq(memberships.organisationId, organisationId)))
    .limit(1);
  if (!member) {
    const [grant] = await db
      .select({ id: externalGrants.id })
      .from(externalGrants)
      .where(
        and(eq(externalGrants.userId, userId), eq(externalGrants.organisationId, organisationId)),
      )
      .limit(1);
    if (!grant) return null;
  }
  return { id: user.id, email: user.email, name: user.name || user.email };
}
