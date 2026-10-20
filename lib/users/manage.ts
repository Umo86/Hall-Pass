import "server-only";
/**
 * The database side of Users: invite, edit, suspend and remove people, end
 * their access on a date, and the departments they sign off for. Each
 * function runs inside the caller's transaction and writes its own audit
 * rows (with the person as the subject, for access history);
 * app/actions/users.ts does the parsing, the first authorisation check and
 * revalidation around them. Who may change whom is decided here, after the
 * person is loaded, by the pure people rules in lib/authz.ts
 * (personChangeRefusal, canManagePerson, canSuspendPerson, canRemovePerson).
 * Who takes over someone's sign-offs, items and tasks is decided by the
 * pure rules in ./handover.ts. Messages thrown as UserError are safe to show.
 */
import { and, asc, count, eq, inArray, isNull, max, ne, or, sql, type SQL } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import {
  approvalInstances,
  approvers,
  departments,
  editions,
  events,
  externalGrants,
  memberships,
  signageItems,
  staffInvites,
  standSubmissions,
  tasks,
  users,
  workflowSteps,
  workflows,
} from "@/lib/db/schema";
import {
  canManagePerson,
  canRemovePerson,
  canRenewInvite,
  canSuspendPerson,
  editionScope,
  isSuperAdmin,
  parseFeatures,
  personChangeRefusal,
  seesAllEditions,
  seesEdition,
  signoffPaused,
  type Actor,
  type Feature,
  type ManagerScope,
  type PermissionOverrides,
  type PersonAccess,
  type PersonCtx,
  type StaffActor,
  type StaffRole,
} from "@/lib/authz";
import {
  accessEndsAtFromLondonDate,
  accessLive,
  canReceiveSignoff,
  londonDateOfAccessEnd,
} from "@/lib/access";
import { writeAudit } from "@/lib/audit";
import { appUrl } from "@/lib/app-url";
import { itemPath } from "@/lib/edition-path";
import { formatDate, roleLabel } from "@/lib/format";
import { todayInLondon } from "@/lib/today";
import { createStaffInvite, STAFF_INVITE_DAYS } from "@/lib/auth/staff-invite";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { revokeSessionsTx } from "@/lib/auth/accounts";
import {
  departmentIdsForUser,
  departmentSignerIds,
  syncDepartmentSteps,
} from "@/lib/domain/departments";
import { applyDelegation } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { notify } from "@/lib/notify";
import { soleEditionId } from "@/lib/domain/notifications-digest";
import { activeMembership } from "./active";
import {
  mainOnAcceptOutcome,
  mainTakeover,
  normaliseEditionIds,
  normaliseFeatures,
  overridesFor,
  removedEditions,
  sameEditions,
  signoffChanges,
  type AbilityChoices,
  type MainTakeover,
  type Signoff,
} from "./rules";
import { externalAccountLabel, liveGrantSql, livePartnerGrantsFor } from "./external";
import {
  canWorkOwnItem,
  eventHandoverGroups,
  handoverGroups,
  resolveHandover,
  type HandoverChoice,
  type HandoverGroup,
  type HandoverSigner,
  type HandoverStep,
  type ItemKind,
} from "./handover";
import { looksLikeEmail, MAX_PASTED_PEOPLE } from "./paste";

/** A refusal whose message can be shown as it is. */
export class UserError extends Error {
  constructor(
    message: string,
    readonly detail?: Record<string, string>,
  ) {
    super(message);
    this.name = "UserError";
  }
}

/**
 * Who is acting. The actor's own access (role, abilities, manager scope,
 * department, sign-off departments) is read again inside the transaction,
 * so a decision never rests on a stale session. `actorName` is used in
 * the messages people receive about hand-overs.
 */
export type Ctx = { organisationId: string; actorUserId: string; actorName?: string };

/**
 * Nobody signed in: the daily job (an access end date passing) handing
 * sign-offs back. Audited as the cron or the system, with no actor.
 */
export type SystemCtx = {
  organisationId: string;
  actorUserId: null;
  actorName?: undefined;
  actorType: "cron" | "system";
};

/** The audit actor for a person or the system. */
function auditActor(ctx: Ctx | SystemCtx) {
  return ctx.actorUserId === null
    ? { actorUserId: null, actorType: ctx.actorType }
    : { actorUserId: ctx.actorUserId, actorType: "user" as const };
}

/** What the Add person form and the person page both send. */
export type PersonInput = {
  fullName: string;
  jobTitle: string | null;
  departmentId: string | null;
  /** "+ New department…": created as a team with no sign-off step. */
  newDepartmentName?: string | null;
  role: StaffRole;
  /** Null = every section. */
  features: Feature[] | null;
  /** Explicit choices on top of the role (lib/users/rules.ts). */
  abilities: AbilityChoices;
  /** Departments they sign off for. */
  signoffs: Signoff[];
  /** Adds and changes people (super admins only set it); undefined = unchanged. */
  managerScope?: ManagerScope | null;
  /** Access ends at the end of this London date (YYYY-MM-DD); null = no end; undefined = unchanged. */
  accessEndsOn?: string | null;
  /**
   * Events they work on (Users → Events): null = every event, including new
   * ones; undefined = unchanged on updates (Add always sends it).
   */
  editionIds?: string[] | null;
};

type DepartmentRow = typeof departments.$inferSelect;
type MembershipRow = typeof memberships.$inferSelect;

const DAY = 24 * 60 * 60 * 1000;

/** The words for a viewer given sign-off (canReceiveSignoff: viewers never sign). */
const VIEWER_SIGNOFF = "Viewers can't sign off artwork — choose another role or untick sign-off";

/** The acting team member, read fresh in this transaction. */
async function loadActor(tx: Tx, ctx: Ctx): Promise<StaffActor> {
  const m = await tx.query.memberships.findFirst({
    where: and(
      eq(memberships.userId, ctx.actorUserId),
      eq(memberships.organisationId, ctx.organisationId),
    ),
  });
  if (!m || !accessLive(m)) throw new UserError("You can't change people's access");
  return {
    kind: "staff",
    userId: m.userId,
    organisationId: m.organisationId,
    role: m.role,
    overrides: m.permissionOverrides as PermissionOverrides,
    departmentId: m.departmentId,
    features: parseFeatures(m.features),
    managerScope: m.role === "admin" ? null : m.managerScope,
    signoffDepartmentIds: await departmentIdsForUser(tx, m.organisationId, m.userId),
    editionIds: m.role === "admin" ? null : (m.editionIds ?? null),
  };
}

function memberCtx(m: MembershipRow): PersonCtx {
  return {
    organisationId: m.organisationId,
    userId: m.userId,
    role: m.role,
    departmentId: m.departmentId,
    managerScope: m.managerScope,
  };
}

function inviteCtx(i: typeof staffInvites.$inferSelect): PersonCtx {
  return {
    organisationId: i.organisationId,
    userId: null,
    role: i.role,
    departmentId: i.departmentId,
    managerScope: i.managerScope,
  };
}

function refuse(message: string | null) {
  if (message) throw new UserError(message);
}

/** A London date from the form as the moment access ends; it can't be in the past. */
function accessEndFromInput(date: string | null | undefined): Date | null | undefined {
  if (date === undefined) return undefined;
  if (date === null || date === "") return null;
  let at: Date;
  try {
    at = accessEndsAtFromLondonDate(date);
  } catch {
    throw new UserError("Enter the end date as a date");
  }
  if (date < todayInLondon()) throw new UserError("Choose today or a later date for access to end");
  return at;
}

/** JSON with sorted keys, so stored jsonb and fresh objects compare equal. */
function stable(value: unknown): string {
  return JSON.stringify(value, (_k, v) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(
          Object.entries(v as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b)),
        )
      : v,
  );
}

/**
 * Lock the organisation's super admins and say whether someone other than
 * `exceptUserId` has lasting access: not suspended and no end date. Every
 * change that suspends, removes, demotes or puts an end date on a super
 * admin needs one, so the organisation can never run out of super admins
 * later — "has access right now" isn't enough, as two super admins could
 * give each other end dates and nobody would be left once both passed.
 * The lock stops two such changes at the same moment leaving nobody.
 */
async function anotherLastingSuperAdmin(
  tx: Tx,
  organisationId: string,
  exceptUserId: string,
): Promise<boolean> {
  const rows = await tx
    .select({
      userId: memberships.userId,
      suspendedAt: memberships.suspendedAt,
      accessEndsAt: memberships.accessEndsAt,
    })
    .from(memberships)
    .where(and(eq(memberships.organisationId, organisationId), eq(memberships.role, "admin")))
    .for("update");
  return rows.some(
    (r) => r.userId !== exceptUserId && r.suspendedAt == null && r.accessEndsAt == null,
  );
}

const LAST_ADMIN =
  "There must always be a super admin whose access doesn't end — give another super admin access with no end date first";

/**
 * Take the organisation's people lock for the rest of the transaction, so
 * changes that hand over sign-offs (suspend, remove, stop signing, end
 * dates, edits) run one after another: two at once could each pick the
 * other person as the one taking over, and both would end up suspended
 * holding each other's sign-offs. Callers outside this file that end in
 * stopSigningTx (Users → Departments) take it before changing anything.
 */
export async function lockPeople(tx: Tx, organisationId: string): Promise<void> {
  await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${`people:${organisationId}`}))`);
}

/**
 * The department chosen in the form: an existing one of this organisation,
 * or a new one made on the spot (a team with no sign-off step yet).
 * `keepId` is the department they already have, which may be archived.
 */
async function resolveDepartment(
  tx: Tx,
  ctx: Ctx,
  input: { departmentId: string | null; newDepartmentName?: string | null },
  keepId: string | null = null,
): Promise<DepartmentRow | null> {
  const newName = input.newDepartmentName?.trim();
  if (newName) {
    const [existing] = await tx
      .select()
      .from(departments)
      .where(
        and(
          eq(departments.organisationId, ctx.organisationId),
          sql`lower(${departments.name}) = ${newName.toLowerCase()}`,
        ),
      )
      .limit(1);
    if (existing) {
      if (existing.isArchived) {
        throw new UserError(
          `${existing.name} is archived — restore it under Departments, or use another name`,
        );
      }
      return existing;
    }
    const [{ top }] = await tx
      .select({ top: max(departments.sortOrder) })
      .from(departments)
      .where(eq(departments.organisationId, ctx.organisationId));
    const [row] = await tx
      .insert(departments)
      .values({
        organisationId: ctx.organisationId,
        name: newName,
        signsOff: false,
        defaultFor: ["organiser", "sponsor"],
        sortOrder: (top ?? 0) + 1,
      })
      .returning();
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "department",
      entityId: row.id,
      action: "create",
      after: { name: row.name, signsOff: false },
      summary: `Department “${row.name}” added`,
    });
    return row;
  }
  if (!input.departmentId) return null;
  const dept = await tx.query.departments.findFirst({
    where: and(
      eq(departments.id, input.departmentId),
      eq(departments.organisationId, ctx.organisationId),
    ),
  });
  if (!dept) throw new UserError("That department no longer exists — reload the page");
  if (dept.isArchived && dept.id !== keepId) {
    throw new UserError(`${dept.name} is archived — pick another department`);
  }
  return dept;
}

type Person = { userId: string | null; email: string; fullName: string; jobTitle: string | null };

/** Approver rows belonging to this person (by account, or by email until they accept). */
function personRows(organisationId: string, person: Pick<Person, "userId" | "email">) {
  const byEmail = and(isNull(approvers.userId), eq(approvers.email, person.email.toLowerCase()));
  return and(
    eq(approvers.organisationId, organisationId),
    person.userId ? or(eq(approvers.userId, person.userId), byEmail) : byEmail,
  );
}

/**
 * Departments this person signs off for now. isMain is the form-level value
 * the people rules read: main approver now, or (an invitation) when they
 * accept.
 */
export async function currentSignoffs(
  db: Db | Tx,
  organisationId: string,
  person: Pick<Person, "userId" | "email">,
): Promise<Signoff[]> {
  const rows = await db
    .select({
      departmentId: approvers.departmentId,
      isMain: approvers.isMain,
      mainOnAccept: approvers.mainOnAccept,
    })
    .from(approvers)
    .where(personRows(organisationId, person));
  const seen = new Map<string, boolean>();
  for (const r of rows) {
    seen.set(r.departmentId, (seen.get(r.departmentId) ?? false) || r.isMain || r.mainOnAccept);
  }
  return [...seen].map(([departmentId, isMain]) => ({ departmentId, isMain }));
}

/** A department's main approver other than `email`, and whether they can sign now. */
async function otherMain(tx: Tx, organisationId: string, departmentId: string, email: string) {
  const [row] = await tx
    .select({
      name: approvers.fullName,
      userName: users.fullName,
      userId: approvers.userId,
      role: memberships.role,
      overrides: memberships.permissionOverrides,
      suspendedAt: memberships.suspendedAt,
      accessEndsAt: memberships.accessEndsAt,
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
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        eq(approvers.departmentId, departmentId),
        eq(approvers.isMain, true),
        ne(approvers.email, email),
      ),
    )
    .limit(1);
  if (!row) return null;
  const canSign =
    row.userId != null &&
    row.role != null &&
    canReceiveSignoff({
      role: row.role,
      overrides: row.overrides as PermissionOverrides,
      suspendedAt: row.suspendedAt,
      accessEndsAt: row.accessEndsAt,
    });
  return { name: row.userName || row.name, canSign };
}

/**
 * One main approver per department (a unique index): before someone becomes
 * main, whoever is main now stops being it — with an audit row naming them,
 * so their own access history shows it, in the same transaction. `keep`
 * picks out the row becoming main (left alone). Used by the person page,
 * invitations and Users → Departments.
 */
export async function clearOtherMainsTx(
  tx: Tx,
  opts: {
    organisationId: string;
    /** Null with actorType "system": someone accepting their invitation took over. */
    actorUserId: string | null;
    actorType?: "user" | "system";
    departmentId: string;
    keep: SQL;
    newMainName: string;
    /** Why, in a few words ("they accepted their invitation"). */
    because?: string;
  },
): Promise<number> {
  const demoted = await tx
    .update(approvers)
    .set({ isMain: false })
    .where(
      and(
        eq(approvers.organisationId, opts.organisationId),
        eq(approvers.departmentId, opts.departmentId),
        eq(approvers.isMain, true),
        opts.keep,
      ),
    )
    .returning();
  if (demoted.length === 0) return 0;
  const dept = await tx.query.departments.findFirst({
    where: eq(departments.id, opts.departmentId),
  });
  for (const row of demoted) {
    await writeAudit(tx, {
      organisationId: opts.organisationId,
      actorUserId: opts.actorUserId,
      actorType: opts.actorType ?? "user",
      entityType: "approver",
      entityId: row.id,
      action: "settings_change",
      before: { isMain: true, userId: row.userId, email: row.email },
      after: { isMain: false, userId: row.userId, email: row.email, newMain: opts.newMainName },
      summary: `${row.fullName || row.email} is no longer the main approver for ${dept?.name ?? "the department"} — ${opts.newMainName} is${opts.because ? ` (${opts.because})` : ""}`,
      subjectUserId: row.userId,
      subjectEmail: row.email,
    });
  }
  return demoted.length;
}

/** Someone else's "main when they accept" that a newer choice replaced. */
export type PendingDropped = { departmentId: string; departmentName: string; name: string };

/** A department where this save cancelled the person's own "main when they accept". */
export type AskCancelled = {
  departmentId: string;
  departmentName: string;
  /** Who stays main approver; null when the department has none. */
  currentMain: string | null;
};

/** A department where the person takes over as main approver when they accept. */
export type MainOnAcceptNote = {
  departmentId: string;
  departmentName: string;
  currentMain: string;
};

/**
 * One "main approver when they accept" per department, and the newest
 * choice wins: before someone is chosen as main (now or when they accept),
 * any other pending ask in the department is cancelled — audited on the
 * invitee, so their access history says so. `keep` picks out the row being
 * chosen (left alone).
 */
export async function dropPendingMainsTx(
  tx: Tx,
  opts: {
    organisationId: string;
    actorUserId: string;
    departmentId: string;
    keep: SQL;
    newMainName: string;
    newMainWhen: MainTakeover;
  },
): Promise<PendingDropped[]> {
  const dropped = await tx
    .update(approvers)
    .set({ mainOnAccept: false, mainOnAcceptBy: null })
    .where(
      and(
        eq(approvers.organisationId, opts.organisationId),
        eq(approvers.departmentId, opts.departmentId),
        eq(approvers.mainOnAccept, true),
        opts.keep,
      ),
    )
    .returning();
  if (dropped.length === 0) return [];
  const dept = await tx.query.departments.findFirst({
    where: eq(departments.id, opts.departmentId),
  });
  const departmentName = dept?.name ?? "the department";
  const out: PendingDropped[] = [];
  for (const row of dropped) {
    const name = row.fullName || row.email;
    await writeAudit(tx, {
      organisationId: opts.organisationId,
      actorUserId: opts.actorUserId,
      entityType: "approver",
      entityId: row.id,
      action: "settings_change",
      before: { mainOnAccept: true, email: row.email },
      after: { mainOnAccept: false, email: row.email, newMain: opts.newMainName },
      summary: `${name} will no longer become the main approver for ${departmentName} when they accept — ${opts.newMainName} ${opts.newMainWhen === "now" ? "is main approver now" : "will instead"}`,
      subjectUserId: row.userId,
      subjectEmail: row.email,
    });
    out.push({ departmentId: opts.departmentId, departmentName, name });
  }
  return out;
}

/**
 * Make the person an approver for exactly these departments. New ones must
 * be live departments that sign off; ones they already have are kept even
 * if since archived. One main approver per department. Someone only
 * invited who is chosen as main while the current main can sign takes over
 * when they accept (`mainOnAccept`, the ask on their approver row), so
 * nobody is demoted for an invitation that may never be accepted; anyone
 * else chosen is main now. The newest choice wins: someone else's pending
 * ask in that department is cancelled (`pendingDropped`). Rows whose
 * form-level choice is unchanged are left exactly as stored. Returns whether
 * anything changed (the caller then syncs the sign-off steps).
 */
export async function setSignoffs(
  tx: Tx,
  ctx: Ctx,
  person: Person,
  desired: Signoff[],
): Promise<{
  changed: boolean;
  before: Signoff[];
  after: Signoff[];
  removed: string[];
  /** Departments where they take over when they accept. */
  mainOnAccept: MainOnAcceptNote[];
  /** Other people's pending asks this change replaced (newest choice wins). */
  pendingDropped: PendingDropped[];
  /** Their own pending asks this change cancelled (unticked, moved, or no longer signing). */
  askCancelled: AskCancelled[];
}> {
  // Approver rows keep emails in lower case.
  person = { ...person, email: person.email.toLowerCase() };
  const who = person.fullName || person.email;
  const unique = [...new Map(desired.map((s) => [s.departmentId, s.isMain])).entries()].map(
    ([departmentId, isMain]) => ({ departmentId, isMain }),
  );
  const before = await currentSignoffs(tx, ctx.organisationId, person);
  const changes = signoffChanges(before, unique);
  if (changes.add.length > 0) {
    const ids = changes.add.map((a) => a.departmentId);
    const found = await tx
      .select()
      .from(departments)
      .where(and(eq(departments.organisationId, ctx.organisationId), inArray(departments.id, ids)));
    for (const a of changes.add) {
      const d = found.find((f) => f.id === a.departmentId);
      if (!d) throw new UserError("That department no longer exists — reload the page");
      if (d.isArchived) throw new UserError(`${d.name} is archived, so nobody can sign off for it`);
      if (!d.signsOff) {
        throw new UserError(
          `${d.name} doesn't sign off artwork — switch on sign-off for it under Departments first`,
        );
      }
    }
  }
  const where = personRows(ctx.organisationId, person);
  const stored = await tx
    .select({
      id: approvers.id,
      departmentId: approvers.departmentId,
      mainOnAccept: approvers.mainOnAccept,
    })
    .from(approvers)
    .where(where);
  const touched = [...new Set([...unique.map((s) => s.departmentId), ...changes.remove])];
  const deptNames = new Map(
    touched.length === 0
      ? []
      : (
          await tx
            .select({ id: departments.id, name: departments.name })
            .from(departments)
            .where(
              and(
                eq(departments.organisationId, ctx.organisationId),
                inArray(departments.id, touched),
              ),
            )
        ).map((d) => [d.id, d.name]),
  );
  const deptName = (id: string) => deptNames.get(id) ?? "the department";

  // Who becomes main, and when. Done before any write: the one-main and
  // one-ask indexes aren't the upsert's target, so others are cleared first.
  const when = new Map<string, MainTakeover>();
  const mainOnAccept: MainOnAcceptNote[] = [];
  const pendingDropped: PendingDropped[] = [];
  for (const s of unique.filter((x) => x.isMain)) {
    const newly = !before.some((b) => b.departmentId === s.departmentId && b.isMain);
    if (!newly) continue;
    const current = person.userId
      ? null
      : await otherMain(tx, ctx.organisationId, s.departmentId, person.email);
    const w = mainTakeover({
      hasAccount: Boolean(person.userId),
      currentMainCanSign: Boolean(current?.canSign),
    });
    when.set(s.departmentId, w);
    pendingDropped.push(
      ...(await dropPendingMainsTx(tx, {
        organisationId: ctx.organisationId,
        actorUserId: ctx.actorUserId,
        departmentId: s.departmentId,
        keep: ne(approvers.email, person.email),
        newMainName: who,
        newMainWhen: w,
      })),
    );
    if (w === "now") {
      await clearOtherMainsTx(tx, {
        organisationId: ctx.organisationId,
        actorUserId: ctx.actorUserId,
        departmentId: s.departmentId,
        keep: ne(approvers.email, person.email),
        newMainName: who,
      });
    } else {
      mainOnAccept.push({
        departmentId: s.departmentId,
        departmentName: deptName(s.departmentId),
        currentMain: current!.name,
      });
    }
  }
  const storedMain = (departmentId: string, isMain: boolean) => {
    const w = when.get(departmentId) ?? "now";
    const ask = isMain && w === "on_accept";
    return {
      isMain: isMain && w === "now",
      mainOnAccept: ask,
      mainOnAcceptBy: ask ? ctx.actorUserId : null,
    };
  };

  // Asks that this change cancels: rows taken away, or no longer main.
  const askCancelled = stored.filter(
    (r) =>
      r.mainOnAccept &&
      (changes.remove.includes(r.departmentId) ||
        changes.update.some((u) => u.departmentId === r.departmentId && !u.isMain)),
  );

  if (changes.remove.length > 0) {
    await tx.delete(approvers).where(and(where, inArray(approvers.departmentId, changes.remove)));
  }
  const asked = new Map<string, string>();
  for (const a of changes.add) {
    const [row] = await tx
      .insert(approvers)
      .values({
        organisationId: ctx.organisationId,
        departmentId: a.departmentId,
        fullName: who,
        jobTitle: person.jobTitle,
        email: person.email,
        userId: person.userId,
        ...storedMain(a.departmentId, a.isMain),
      })
      .onConflictDoUpdate({
        target: [approvers.departmentId, approvers.email],
        set: { userId: person.userId, fullName: who, ...storedMain(a.departmentId, a.isMain) },
      })
      .returning({ id: approvers.id, mainOnAccept: approvers.mainOnAccept });
    if (row?.mainOnAccept) asked.set(a.departmentId, row.id);
  }
  for (const u of changes.update) {
    const rows = await tx
      .update(approvers)
      .set(
        u.isMain
          ? storedMain(u.departmentId, true)
          : { isMain: false, mainOnAccept: false, mainOnAcceptBy: null },
      )
      .where(and(where, eq(approvers.departmentId, u.departmentId)))
      .returning({ id: approvers.id, mainOnAccept: approvers.mainOnAccept });
    const row = rows.find((r) => r.mainOnAccept);
    if (row) asked.set(u.departmentId, row.id);
  }
  // Keep their name on the approver list in step with their profile.
  if (unique.length > 0) {
    await tx.update(approvers).set({ fullName: who, jobTitle: person.jobTitle }).where(where);
  }
  for (const m of mainOnAccept) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "approver",
      entityId: asked.get(m.departmentId) ?? null,
      action: "settings_change",
      before: { mainOnAccept: false },
      after: { mainOnAccept: true, email: person.email, currentMain: m.currentMain },
      summary: `${who} will become the main approver for ${m.departmentName} when they accept — ${m.currentMain} stays until then`,
      subjectUserId: person.userId,
      subjectEmail: person.email,
    });
  }
  for (const r of askCancelled) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "approver",
      entityId: r.id,
      action: "settings_change",
      before: { mainOnAccept: true },
      after: { mainOnAccept: false, email: person.email },
      summary: `${who} will no longer become the main approver for ${deptName(r.departmentId)} when they accept`,
      subjectUserId: person.userId,
      subjectEmail: person.email,
    });
  }
  const cancelledNotes: AskCancelled[] = [];
  for (const r of askCancelled) {
    const main = await otherMain(tx, ctx.organisationId, r.departmentId, person.email);
    cancelledNotes.push({
      departmentId: r.departmentId,
      departmentName: deptName(r.departmentId),
      currentMain: main?.name ?? null,
    });
  }
  const changed = changes.add.length + changes.remove.length + changes.update.length > 0;
  return {
    changed,
    before,
    after: unique,
    removed: changes.remove,
    mainOnAccept,
    pendingDropped,
    askCancelled: cancelledNotes,
  };
}

/** An invitation nobody has accepted or cancelled for this email, expired or not. */
export async function openInviteFor(db: Db | Tx, organisationId: string, email: string) {
  const [open] = await db
    .select({
      id: staffInvites.id,
      fullName: staffInvites.fullName,
      expiresAt: staffInvites.expiresAt,
    })
    .from(staffInvites)
    .where(
      and(
        eq(staffInvites.organisationId, organisationId),
        eq(staffInvites.invitedEmail, email),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
      ),
    )
    .limit(1);
  if (!open) return null;
  return { ...open, expired: open.expiresAt != null && open.expiresAt.getTime() <= Date.now() };
}

/**
 * Refuse emails already in use: a team member, another organisation, a
 * portal account, or an invitation still open here (never replaced
 * silently — its page has Resend).
 */
async function assertEmailFree(tx: Tx, ctx: Ctx, email: string) {
  await assertNoOtherAccess(tx, ctx, email);
  const open = await openInviteFor(tx, ctx.organisationId, email);
  if (open) {
    const who = open.fullName || email;
    throw new UserError(
      open.expired
        ? `${who}'s invitation has expired — open their page to send a new one`
        : `${who} is already invited — open their page to send it again`,
      { existingInviteId: open.id },
    );
  }
}

/**
 * Refuse an email whose owner already has other access: on the team here
 * or in another organisation, or live partner access here or elsewhere.
 * Checked when inviting and again when an invitation is sent again (it may
 * have expired while they became a partner).
 */
async function assertNoOtherAccess(tx: Tx, ctx: Ctx, email: string) {
  email = email.trim().toLowerCase();
  const user = await tx.query.users.findFirst({ where: eq(users.email, email) });
  if (user) {
    const member = await tx.query.memberships.findFirst({ where: eq(memberships.userId, user.id) });
    if (member?.organisationId === ctx.organisationId) {
      throw new UserError(`${user.fullName || email} is already on the team`, {
        existingUserId: user.id,
      });
    }
    if (member) {
      throw new UserError(
        "This email belongs to an account in another organisation. Use a different email.",
      );
    }
  }
  // Only live partner access blocks (expired and revoked grants don't): here,
  // revoke it first; in another organisation, a neutral refusal.
  let [here] = await livePartnerGrantsFor(tx, ctx.organisationId, email);
  if (!here && user) {
    // An account that claimed access here under another address.
    [here] = await tx
      .select()
      .from(externalGrants)
      .where(
        and(
          eq(externalGrants.organisationId, ctx.organisationId),
          eq(externalGrants.userId, user.id),
          liveGrantSql(),
        ),
      )
      .limit(1);
  }
  if (here) {
    const label = await externalAccountLabel(tx, ctx.organisationId, here);
    throw new UserError(
      `This email has portal access here (${label}) — revoke it in Users → External first, then invite them to the team`,
    );
  }
  const [elsewhere] = await tx
    .select({ id: externalGrants.id })
    .from(externalGrants)
    .where(
      and(
        user
          ? or(
              eq(externalGrants.userId, user.id),
              sql`lower(${externalGrants.invitedEmail}) = ${email}`,
            )
          : sql`lower(${externalGrants.invitedEmail}) = ${email}`,
        ne(externalGrants.organisationId, ctx.organisationId),
        liveGrantSql(),
      ),
    )
    .limit(1);
  if (elsewhere) {
    throw new UserError(
      "This email belongs to a portal account in another organisation. Use a different email.",
    );
  }
}

function cleanText(value: string | null | undefined): string | null {
  const v = value?.trim();
  return v ? v : null;
}

/** Every event (edition) of the organisation, archived ones included. */
export async function orgEditionIds(db: Db | Tx, organisationId: string): Promise<string[]> {
  const rows = await db
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(events.id, editions.eventId))
    .where(eq(events.organisationId, organisationId));
  return rows.map((r) => r.id);
}

/**
 * Every id must be one of the organisation's events (an array can't carry a
 * foreign key; events are never deleted in the app).
 */
async function validEditionIds(
  tx: Tx,
  organisationId: string,
  ids: readonly string[] | null,
): Promise<void> {
  if (!ids || ids.length === 0) return;
  const wanted = [...new Set(ids)];
  const rows = await tx
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(events.id, editions.eventId))
    .where(and(eq(events.organisationId, organisationId), inArray(editions.id, wanted)));
  if (rows.length !== wanted.length) {
    throw new UserError("That event wasn't found — reload the page");
  }
}

/**
 * A limited actor's form lists only the events they can open: the person's
 * other events are kept as they are (rule 6b then refuses taking any away).
 */
function keepHiddenEditions(
  actor: Actor,
  before: readonly string[] | null,
  submitted: string[] | null,
): string[] | null {
  if (editionScope(actor) === null || submitted === null) return submitted;
  return normaliseEditionIds([
    ...submitted,
    ...(before ?? []).filter((id) => !seesEdition(actor, id)),
  ]);
}

/** "BIRM28", "BIRM28 and LOND28", or null for more (codes for audit words and refusals). */
async function editionCodesOf(db: Db | Tx, ids: readonly string[]): Promise<string[]> {
  if (ids.length === 0) return [];
  const rows = await db
    .select({ code: editions.code })
    .from(editions)
    .where(inArray(editions.id, [...ids]))
    .orderBy(asc(editions.code));
  return rows.map((r) => r.code);
}

/**
 * Invite someone to the team with everything the form asked for: the
 * invitation carries their name, job title, department, role, sections,
 * abilities, manager scope and access end date; sign-off rows wait (user id
 * empty) until they accept. Managers may only add within their scope and
 * give what they have themselves (personChangeRefusal).
 */
export async function inviteUserTx(
  tx: Tx,
  ctx: Ctx,
  input: PersonInput & { email: string },
): Promise<{
  inviteId: string;
  inviteUrl: string;
  expiresAt: Date;
  departmentName: string | null;
  mainOnAccept: MainOnAcceptNote[];
  pendingDropped: PendingDropped[];
}> {
  // People changes one after another (re-entrant: Add several takes it first).
  await lockPeople(tx, ctx.organisationId);
  const actor = await loadActor(tx, ctx);
  const email = input.email.trim().toLowerCase();
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  const overrides = overridesFor(input.role, input.abilities);
  const managerScope = input.role === "admin" ? null : (input.managerScope ?? null);
  const accessEndsAt = accessEndFromInput(input.accessEndsOn) ?? null;
  // Users → Events: super admins are never limited.
  const editionIds = input.role === "admin" ? null : normaliseEditionIds(input.editionIds ?? null);
  refuse(
    personChangeRefusal(actor, null, null, {
      role: input.role,
      departmentId: input.departmentId,
      newDepartmentName: input.newDepartmentName,
      features,
      overrides,
      managerScope,
      signoffs: input.signoffs,
      accessEndsAt,
      editionIds,
    }),
  );
  await validEditionIds(tx, ctx.organisationId, editionIds);
  if (input.role === "viewer" && input.signoffs.length > 0) throw new UserError(VIEWER_SIGNOFF);
  await assertEmailFree(tx, ctx, email);
  const dept = await resolveDepartment(tx, ctx, input);
  const invite = await createStaffInvite(tx, {
    organisationId: ctx.organisationId,
    email,
    role: input.role,
    overrides,
    fullName,
    jobTitle,
    departmentId: dept?.id ?? null,
    features,
    managerScope,
    accessEndsAt,
    editionIds,
    invitedBy: ctx.actorUserId,
    summary: `Invited ${email} as ${roleLabel(input.role)}${dept ? ` (${dept.name})` : ""}`,
  });
  const signoff = await setSignoffs(
    tx,
    ctx,
    { userId: null, email, fullName, jobTitle },
    input.signoffs,
  );
  if (signoff.changed) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "approver",
      entityId: invite.inviteId,
      action: "create",
      after: { email, signsOffFor: signoff.after, mainOnAccept: signoff.mainOnAccept },
      summary: `${fullName || email} will sign off artwork once they accept`,
      subjectEmail: email,
    });
    await syncDepartmentSteps(tx, ctx.organisationId);
  }
  return {
    ...invite,
    departmentName: dept?.name ?? null,
    mainOnAccept: signoff.mainOnAccept,
    pendingDropped: signoff.pendingDropped,
  };
}

/**
 * Change a team member: details, department, role, sections, sign-off,
 * abilities, manager scope and access end date — within what the actor may
 * change (personChangeRefusal) and never leaving the organisation without a
 * super admin who has access. Sign-offs that name them for a department
 * they no longer sign for (or at all, once they can't sign) go back to that
 * department when someone else there can sign.
 */
export async function updateMemberTx(
  tx: Tx,
  ctx: Ctx,
  input: PersonInput & {
    userId: string;
    signoffPaused: boolean;
    /** Who takes their sign-offs in events taken away from them (Users → Events). */
    eventHandover?: HandoverChoice | null;
  },
): Promise<{
  name: string;
  changed: string[];
  signoffsMoved: number;
  signoffsKept: number;
  /** Pending "main when they accept" asks cancelled by making them main now. */
  pendingDropped: PendingDropped[];
  /** Sign-offs handed over because events were taken away from them. */
  eventSignoffsMoved: number;
}> {
  await lockPeople(tx, ctx.organisationId);
  const actor = await loadActor(tx, ctx);
  const membership = await tx.query.memberships.findFirst({
    where: and(
      eq(memberships.userId, input.userId),
      eq(memberships.organisationId, ctx.organisationId),
    ),
  });
  if (!membership) throw new UserError("This person isn't on the team any more — reload the page");
  const user = await tx.query.users.findFirst({ where: eq(users.id, input.userId) });
  if (!user) throw new UserError("This person isn't on the team any more — reload the page");
  const isSelf = input.userId === ctx.actorUserId;
  if (isSelf && input.role !== membership.role) {
    throw new UserError("You can't change your own role — ask another super admin");
  }
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  if (isSelf && input.role !== "admin") {
    const mine = normaliseFeatures(membership.features);
    if (JSON.stringify(mine) !== JSON.stringify(features)) {
      throw new UserError("You can't change your own sections — ask another super admin");
    }
  }
  const managerScope =
    input.role === "admin"
      ? null
      : input.managerScope === undefined
        ? membership.managerScope
        : input.managerScope;
  const endInput = accessEndFromInput(input.accessEndsOn);
  const accessEndsAt = endInput === undefined ? membership.accessEndsAt : endInput;
  if (
    isSelf &&
    (accessEndsAt?.getTime() ?? null) !== (membership.accessEndsAt?.getTime() ?? null)
  ) {
    throw new UserError("You can't set an end date on your own access — ask another super admin");
  }
  const overrides = overridesFor(input.role, input.abilities, {
    signoffPaused: input.signoffPaused,
  });
  // Users → Events: super admins are never limited; undefined = unchanged.
  const editionsBefore =
    membership.role === "admin" ? null : normaliseEditionIds(membership.editionIds);
  const editionIds =
    input.role === "admin"
      ? null
      : input.editionIds === undefined
        ? editionsBefore
        : keepHiddenEditions(actor, editionsBefore, normaliseEditionIds(input.editionIds));
  if (isSelf && !sameEditions(editionsBefore, editionIds)) {
    throw new UserError("You can't change your own events — ask another super admin");
  }
  const beforeSignoffs = await currentSignoffs(tx, ctx.organisationId, {
    userId: user.id,
    email: user.email,
  });
  const before: PersonAccess = {
    role: membership.role,
    departmentId: membership.departmentId,
    features: normaliseFeatures(membership.features),
    overrides: membership.permissionOverrides as PermissionOverrides,
    managerScope: membership.managerScope,
    signoffs: beforeSignoffs,
    accessEndsAt: membership.accessEndsAt,
    editionIds: editionsBefore,
  };
  refuse(
    personChangeRefusal(actor, memberCtx(membership), before, {
      role: input.role,
      departmentId: input.departmentId,
      newDepartmentName: input.newDepartmentName,
      features,
      overrides,
      managerScope,
      signoffs: input.signoffs,
      accessEndsAt,
      editionIds,
    }),
  );
  if (!sameEditions(editionsBefore, editionIds)) {
    await validEditionIds(tx, ctx.organisationId, editionIds);
  }
  if (input.role === "viewer" && input.signoffs.length > 0) throw new UserError(VIEWER_SIGNOFF);
  const losesAdmin = membership.role === "admin" && input.role !== "admin";
  // A new or moved end date on a super admin (an unchanged one isn't re-checked).
  const adminGetsEnd =
    membership.role === "admin" &&
    input.role === "admin" &&
    accessEndsAt != null &&
    accessEndsAt.getTime() !== membership.accessEndsAt?.getTime();
  if (
    (losesAdmin || adminGetsEnd) &&
    !(await anotherLastingSuperAdmin(tx, ctx.organisationId, user.id))
  ) {
    throw new UserError(LAST_ADMIN);
  }
  const dept = await resolveDepartment(tx, ctx, input, membership.departmentId);
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);

  const signoff = await setSignoffs(
    tx,
    ctx,
    { userId: user.id, email: user.email, fullName: fullName || user.fullName, jobTitle },
    input.signoffs,
  );
  if (fullName && fullName !== user.fullName) {
    await tx.update(users).set({ fullName }).where(eq(users.id, user.id));
  }
  await tx
    .update(memberships)
    .set({
      role: input.role,
      permissionOverrides: overrides,
      departmentId: dept?.id ?? null,
      features,
      jobTitle,
      managerScope,
      accessEndsAt,
      editionIds,
    })
    .where(eq(memberships.id, membership.id));
  const wasPaused = signoffPaused(membership.permissionOverrides as PermissionOverrides);
  const pausedChanged = wasPaused !== input.signoffPaused;
  const roleSignChange = (membership.role === "viewer") !== (input.role === "viewer");

  // Sign-offs naming them that they no longer sign for: back to the department
  // (before the re-sync below, whose routing would otherwise move them first,
  // unannounced).
  const who = fullName || user.fullName || user.email;
  const stopsSigning =
    (input.role === "viewer" && membership.role !== "viewer") ||
    (input.signoffPaused && !wasPaused);
  const handed =
    stopsSigning || signoff.removed.length > 0
      ? await stopSigningTx(tx, ctx, {
          userId: user.id,
          who,
          departmentIds: stopsSigning ? null : signoff.removed,
          why: stopsSigning
            ? input.signoffPaused
              ? "has their sign-off paused"
              : "can no longer sign off"
            : "no longer signs off for the department",
        })
      : { moved: 0, kept: 0 };
  // Events taken away: their sign-offs there go back to the department (or
  // to whoever was picked); tasks and items there stay, listed on the page.
  const eventsChanged = !sameEditions(editionsBefore, editionIds);
  const lost = eventsChanged
    ? removedEditions(editionsBefore, editionIds, await orgEditionIds(tx, ctx.organisationId))
    : [];
  const leftEvents =
    lost.length > 0
      ? await leaveEventsTx(tx, ctx, {
          actor,
          userId: user.id,
          who,
          editionIds: lost,
          choice: input.eventHandover,
        })
      : { moved: 0 };
  // Main approver routing skips people who can't sign (or can't open an
  // event): re-sync when that changes.
  if (
    signoff.changed ||
    pausedChanged ||
    roleSignChange ||
    (eventsChanged && signoff.after.length > 0)
  ) {
    await syncDepartmentSteps(tx, ctx.organisationId);
  }

  const beforeRow = {
    fullName: user.fullName,
    jobTitle: membership.jobTitle,
    departmentId: membership.departmentId,
    role: membership.role,
    features: normaliseFeatures(membership.features),
    overrides: membership.permissionOverrides,
    managerScope: membership.managerScope,
    accessEndsAt: membership.accessEndsAt?.toISOString() ?? null,
    signsOffFor: signoff.before,
    editionIds: editionsBefore,
  };
  const afterRow = {
    fullName: fullName || user.fullName,
    jobTitle,
    departmentId: dept?.id ?? null,
    role: input.role,
    features,
    overrides,
    managerScope,
    accessEndsAt: accessEndsAt?.toISOString() ?? null,
    signsOffFor: signoff.after,
    editionIds,
  };
  const changed = (Object.keys(beforeRow) as (keyof typeof beforeRow)[]).filter((k) =>
    k === "signsOffFor"
      ? signoff.changed
      : k === "editionIds"
        ? eventsChanged
        : stable(beforeRow[k]) !== stable(afterRow[k]),
  );
  if (changed.length > 0) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "membership",
      entityId: membership.id,
      action: "settings_change",
      before: beforeRow,
      after: {
        ...afterRow,
        signoffsHandedBack: handed.moved,
        ...(eventsChanged
          ? { eventsRemoved: lost.length, eventSignoffsHandedOver: leftEvents.moved }
          : {}),
      },
      // Never event codes in summaries ("events changed"); the ids are in before/after.
      summary: `${user.email}: ${changed.map((k) => (k === "editionIds" ? "events" : k)).join(", ")} changed`,
      subjectUserId: user.id,
      subjectEmail: user.email,
    });
  }
  return {
    name: fullName || user.fullName || user.email,
    changed,
    signoffsMoved: handed.moved,
    signoffsKept: handed.kept,
    pendingDropped: signoff.pendingDropped,
    eventSignoffsMoved: leftEvents.moved,
  };
}

type OpenInvite = typeof staffInvites.$inferSelect;

async function openInvite(tx: Tx, ctx: Ctx, inviteId: string): Promise<OpenInvite> {
  const invite = await tx.query.staffInvites.findFirst({
    where: and(
      eq(staffInvites.id, inviteId),
      eq(staffInvites.organisationId, ctx.organisationId),
      isNull(staffInvites.acceptedAt),
      isNull(staffInvites.revokedAt),
    ),
  });
  if (!invite) {
    throw new UserError("This invitation has already been accepted or cancelled — reload the page");
  }
  return invite;
}

/** The invitation, refused unless the actor may change it (canManagePerson). */
async function managedInvite(tx: Tx, ctx: Ctx, inviteId: string) {
  const actor = await loadActor(tx, ctx);
  const invite = await openInvite(tx, ctx, inviteId);
  if (!canManagePerson(actor, inviteCtx(invite))) {
    throw new UserError("You can't change this invitation");
  }
  return { actor, invite };
}

/** Change what an invitation will give someone before they accept it. */
export async function updateInviteTx(
  tx: Tx,
  ctx: Ctx,
  input: PersonInput & { inviteId: string },
): Promise<{
  name: string;
  mainOnAccept: MainOnAcceptNote[];
  pendingDropped: PendingDropped[];
  askCancelled: AskCancelled[];
}> {
  // First, so an invitation accepted meanwhile is refused by openInvite.
  await lockPeople(tx, ctx.organisationId);
  const actor = await loadActor(tx, ctx);
  const invite = await openInvite(tx, ctx, input.inviteId);
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  const overrides = overridesFor(input.role, input.abilities);
  const managerScope =
    input.role === "admin"
      ? null
      : input.managerScope === undefined
        ? invite.managerScope
        : input.managerScope;
  const endInput = accessEndFromInput(input.accessEndsOn);
  const accessEndsAt = endInput === undefined ? invite.accessEndsAt : endInput;
  const editionsBefore = invite.role === "admin" ? null : normaliseEditionIds(invite.editionIds);
  const editionIds =
    input.role === "admin"
      ? null
      : input.editionIds === undefined
        ? editionsBefore
        : keepHiddenEditions(actor, editionsBefore, normaliseEditionIds(input.editionIds));
  const beforeSignoffs = await currentSignoffs(tx, ctx.organisationId, {
    userId: null,
    email: invite.invitedEmail,
  });
  refuse(
    personChangeRefusal(
      actor,
      inviteCtx(invite),
      {
        role: invite.role,
        departmentId: invite.departmentId,
        features: normaliseFeatures(invite.features),
        overrides: invite.permissionOverrides as PermissionOverrides,
        managerScope: invite.managerScope,
        signoffs: beforeSignoffs,
        accessEndsAt: invite.accessEndsAt,
        editionIds: editionsBefore,
      },
      {
        role: input.role,
        departmentId: input.departmentId,
        newDepartmentName: input.newDepartmentName,
        features,
        overrides,
        managerScope,
        signoffs: input.signoffs,
        accessEndsAt,
        editionIds,
      },
    ),
  );
  if (!sameEditions(editionsBefore, editionIds)) {
    await validEditionIds(tx, ctx.organisationId, editionIds);
  }
  if (input.role === "viewer" && input.signoffs.length > 0) throw new UserError(VIEWER_SIGNOFF);
  const dept = await resolveDepartment(tx, ctx, input, invite.departmentId);
  const signoff = await setSignoffs(
    tx,
    ctx,
    { userId: null, email: invite.invitedEmail, fullName, jobTitle },
    input.signoffs,
  );
  await tx
    .update(staffInvites)
    .set({
      fullName,
      jobTitle,
      role: input.role,
      permissionOverrides: overrides,
      departmentId: dept?.id ?? null,
      features,
      managerScope,
      accessEndsAt,
      editionIds,
    })
    .where(eq(staffInvites.id, invite.id));
  if (signoff.changed) await syncDepartmentSteps(tx, ctx.organisationId);
  const beforeRow = {
    fullName: invite.fullName,
    jobTitle: invite.jobTitle,
    role: invite.role,
    departmentId: invite.departmentId,
    features: normaliseFeatures(invite.features),
    overrides: invite.permissionOverrides,
    managerScope: invite.managerScope,
    accessEndsAt: invite.accessEndsAt?.toISOString() ?? null,
    editionIds: editionsBefore,
  };
  const afterRow = {
    fullName,
    jobTitle,
    role: input.role,
    departmentId: dept?.id ?? null,
    features,
    overrides,
    managerScope,
    accessEndsAt: accessEndsAt?.toISOString() ?? null,
    editionIds,
  };
  // Only real changes are recorded.
  if (signoff.changed || stable(beforeRow) !== stable(afterRow)) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "staff_invite",
      entityId: invite.id,
      action: "settings_change",
      before: { ...beforeRow, signsOffFor: signoff.before },
      after: { ...afterRow, signsOffFor: signoff.after },
      summary: `Invitation for ${invite.invitedEmail} changed`,
      subjectEmail: invite.invitedEmail,
    });
  }
  return {
    name: fullName || invite.invitedEmail,
    mainOnAccept: signoff.mainOnAccept,
    pendingDropped: signoff.pendingDropped,
    askCancelled: signoff.askCancelled,
  };
}

/**
 * Cancel an invitation: the link stops working, and the sign-offs it was
 * going to give them go back to the department.
 */
export async function cancelInviteTx(tx: Tx, ctx: Ctx, inviteId: string): Promise<string> {
  await lockPeople(tx, ctx.organisationId);
  await managedInvite(tx, ctx, inviteId);
  const [invite] = await tx
    .update(staffInvites)
    .set({ revokedAt: new Date() })
    .where(
      and(
        eq(staffInvites.id, inviteId),
        eq(staffInvites.organisationId, ctx.organisationId),
        isNull(staffInvites.acceptedAt),
        isNull(staffInvites.revokedAt),
      ),
    )
    .returning();
  if (!invite) {
    throw new UserError("This invitation has already been accepted or cancelled — reload the page");
  }
  const dropped = await tx
    .delete(approvers)
    .where(
      and(
        eq(approvers.organisationId, ctx.organisationId),
        eq(approvers.email, invite.invitedEmail),
        isNull(approvers.userId),
      ),
    )
    .returning({
      id: approvers.id,
      departmentId: approvers.departmentId,
      mainOnAccept: approvers.mainOnAccept,
    });
  if (dropped.length > 0) await syncDepartmentSteps(tx, ctx.organisationId);
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "staff_invite",
    entityId: invite.id,
    action: "grant_revoke",
    before: {
      email: invite.invitedEmail,
      approverRows: dropped.length,
      // Departments they were going to be main approver for when they accepted.
      mainOnAccept: dropped.filter((d) => d.mainOnAccept).map((d) => d.departmentId),
    },
    summary: `Cancelled the invitation for ${invite.invitedEmail}`,
    subjectEmail: invite.invitedEmail,
  });
  return invite.fullName || invite.invitedEmail;
}

/** A pending "main approver when they accept" on an invitee's approver row. */
export type PendingMainAsk = { approverId: string; departmentId: string; askedBy: string | null };

/**
 * The asks waiting on this email's approver rows (not linked yet), locked
 * until the acceptance commits. Read before the rows are linked, which
 * clears them.
 */
export async function pendingMainAsksTx(
  tx: Tx,
  organisationId: string,
  email: string,
): Promise<PendingMainAsk[]> {
  return tx
    .select({
      approverId: approvers.id,
      departmentId: approvers.departmentId,
      askedBy: approvers.mainOnAcceptBy,
    })
    .from(approvers)
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        eq(approvers.email, email.toLowerCase()),
        isNull(approvers.userId),
        eq(approvers.mainOnAccept, true),
      ),
    )
    .for("update");
}

/**
 * Carry out the asks of someone who has just accepted their invitation
 * (lib/auth/claim-staff-invite.ts, after their approver rows are linked):
 * each department whose ask can be carried out — it still signs off and
 * they can sign off now (mainOnAcceptOutcome) — gets them as main approver;
 * the main until now stops being it (a row in their access history) and
 * both are told. Otherwise nothing changes and whoever asked is told. The
 * hand-over rows are by the system, naming who arranged it; the asker's
 * abilities aren't checked again. The caller re-syncs the sign-off steps
 * afterwards, which moves open default sign-offs to the new main. Returns
 * the departments they became main approver for.
 */
export async function applyMainOnAcceptTx(
  tx: Tx,
  opts: {
    organisationId: string;
    user: { id: string; email: string; name: string };
    asks: readonly PendingMainAsk[];
  },
): Promise<{ promoted: string[] }> {
  const promoted: string[] = [];
  if (opts.asks.length === 0) return { promoted };
  const orgId = opts.organisationId;
  const { user } = opts;
  const email = user.email.toLowerCase();
  const m = await tx.query.memberships.findFirst({
    where: and(eq(memberships.userId, user.id), eq(memberships.organisationId, orgId)),
  });
  const canSign = m
    ? canReceiveSignoff({
        role: m.role,
        overrides: m.permissionOverrides as PermissionOverrides,
        suspendedAt: m.suspendedAt,
        accessEndsAt: m.accessEndsAt,
      })
    : false;
  // Users → Events: a new main limited to some events only gets those
  // events' default sign-offs; the rest go to everyone in the department.
  const limitedTo = m && m.role !== "admin" && m.editionIds ? m.editionIds : null;
  const codes = limitedTo ? await editionCodesOf(tx, limitedTo) : [];
  const theirEvents =
    codes.length > 0 && codes.length <= 2 ? codes.join(" and ") : "the events you work on";
  const depts = await tx
    .select()
    .from(departments)
    .where(
      and(
        eq(departments.organisationId, orgId),
        inArray(
          departments.id,
          opts.asks.map((a) => a.departmentId),
        ),
      ),
    );
  for (const ask of opts.asks) {
    const dept = depts.find((d) => d.id === ask.departmentId);
    if (!dept) continue; // deleted: the row (and the ask) went with it
    const outcome = mainOnAcceptOutcome({
      departmentArchived: dept.isArchived,
      signsOff: dept.signsOff,
      canSign,
    });
    const askerName = ask.askedBy ? await nameOf(tx, ask.askedBy) : null;
    const [old] = await tx
      .select({ userId: approvers.userId, name: approvers.fullName, userName: users.fullName })
      .from(approvers)
      .leftJoin(users, eq(users.id, approvers.userId))
      .where(
        and(
          eq(approvers.organisationId, orgId),
          eq(approvers.departmentId, dept.id),
          eq(approvers.isMain, true),
          ne(approvers.id, ask.approverId),
        ),
      )
      .limit(1);
    const oldName = old ? old.userName || old.name : null;
    if (outcome === "promote") {
      await clearOtherMainsTx(tx, {
        organisationId: orgId,
        actorUserId: null,
        actorType: "system",
        departmentId: dept.id,
        keep: ne(approvers.id, ask.approverId),
        newMainName: user.name,
        because: "they accepted their invitation",
      });
      await tx.update(approvers).set({ isMain: true }).where(eq(approvers.id, ask.approverId));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: null,
        actorType: "system",
        entityType: "approver",
        entityId: ask.approverId,
        action: "settings_change",
        before: { isMain: false, mainOnAccept: true, askedBy: ask.askedBy },
        after: { isMain: true, userId: user.id },
        summary: `${user.name} is now the main approver for ${dept.name} — they accepted their invitation${askerName ? `, as ${askerName} arranged` : ""}`,
        subjectUserId: user.id,
        subjectEmail: email,
      });
      if (old?.userId) {
        await notify(tx, {
          userIds: [old.userId],
          kind: "main_approver",
          title: `${user.name} is now the main approver for ${dept.name}`,
          body: `They accepted their invitation and take over from you, as arranged when they were invited. ${dept.name} sign-offs that go to the main approver now go to them; any picked for you on an item stay with you.${
            limitedTo
              ? ` Sign-offs in events ${user.name} doesn't work on go to everyone in ${dept.name}, you included.`
              : ""
          }`,
          link: "/users?tab=departments",
          scope: { organisationId: orgId },
        });
      }
      await notify(tx, {
        userIds: [user.id],
        kind: "main_approver",
        title: `You're the main approver for ${dept.name}`,
        body: limitedTo
          ? `${dept.name} sign-offs come to you unless someone else is picked on the item — in ${theirEvents}; sign-offs in other events go to everyone in ${dept.name}.`
          : `${dept.name} sign-offs come to you unless someone else is picked on the item.`,
        link: "/approvals",
        scope: { organisationId: orgId },
      });
      promoted.push(dept.id);
      continue;
    }
    const stays = oldName ? `${oldName} stays main approver` : "nobody stays main approver";
    await writeAudit(tx, {
      organisationId: orgId,
      actorUserId: null,
      actorType: "system",
      entityType: "approver",
      entityId: ask.approverId,
      action: "settings_change",
      before: { isMain: false, mainOnAccept: true, askedBy: ask.askedBy },
      after: { isMain: false, mainOnAccept: false, userId: user.id, outcome },
      summary:
        outcome === "department_off"
          ? `${user.name} accepted their invitation but isn't the main approver for ${dept.name} — ${dept.name} doesn't sign off artwork at the moment`
          : `${user.name} accepted their invitation but isn't the main approver for ${dept.name} — they can't sign off at the moment, so ${stays}`,
      subjectUserId: user.id,
      subjectEmail: email,
    });
    if (ask.askedBy) {
      await notify(tx, {
        userIds: [ask.askedBy],
        kind: "main_approver",
        title: `${user.name} joined, but isn't the main approver for ${dept.name}`,
        body:
          outcome === "department_off"
            ? `${dept.name} doesn't sign off artwork at the moment, so nothing changed. Make them main under Users → Departments if it signs off again.`
            : `They can't sign off at the moment, so ${oldName ? `${oldName} stays main approver` : `${dept.name} still has no main approver`}. Make them main under Users → Departments once they can.`,
        link: `/users/${user.id}`,
        scope: { organisationId: orgId },
      });
    }
  }
  return { promoted };
}

/** What an open invitation will give whoever accepts it, as the people rules see it. */
async function inviteAccess(tx: Tx, invite: OpenInvite): Promise<PersonAccess> {
  return {
    role: invite.role,
    departmentId: invite.departmentId,
    features: invite.role === "admin" ? null : normaliseFeatures(invite.features),
    overrides: invite.permissionOverrides as PermissionOverrides,
    managerScope: invite.managerScope,
    signoffs: await currentSignoffs(tx, invite.organisationId, {
      userId: null,
      email: invite.invitedEmail,
    }),
    accessEndsAt: invite.accessEndsAt,
    // A limited manager may renew only an invitation whose events they could give.
    editionIds: invite.role === "admin" ? null : normaliseEditionIds(invite.editionIds),
  };
}

export const RENEW_NOT_YOURS =
  "Only a super admin can send this invitation again — it gives access you can't give";

/**
 * A fresh link for an open (or expired) invitation, valid for another
 * STAFF_INVITE_DAYS. The earlier link stops working: links are stored only
 * as hashes, so the old one can't be shown again. A new link is a working
 * way in as that person, so a manager may only renew an invitation they
 * could have made themselves (personChangeRefusal as if adding them now);
 * and nobody renews one for an email that has since got other access (a
 * partner account, or a team elsewhere).
 */
export async function renewInviteLinkTx(
  tx: Tx,
  ctx: Ctx,
  inviteId: string,
): Promise<{ invite: OpenInvite; inviteUrl: string; expiresAt: Date }> {
  const { actor, invite } = await managedInvite(tx, ctx, inviteId);
  if (!isSuperAdmin(actor) && !canRenewInvite(actor, await inviteAccess(tx, invite))) {
    throw new UserError(RENEW_NOT_YOURS);
  }
  await assertNoOtherAccess(tx, ctx, invite.invitedEmail);
  const token = generateInviteToken();
  const expiresAt = new Date(Date.now() + STAFF_INVITE_DAYS * DAY);
  await tx
    .update(staffInvites)
    .set({ inviteTokenHash: hashInviteToken(token), expiresAt })
    .where(eq(staffInvites.id, invite.id));
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "staff_invite",
    entityId: invite.id,
    action: "invite",
    summary: `New invitation link for ${invite.invitedEmail}`,
    subjectEmail: invite.invitedEmail,
  });
  return { invite, inviteUrl: `${appUrl()}/invite/${token}`, expiresAt };
}

/** A fresh link for an external invitation nobody has accepted yet. */
export async function renewGrantLinkTx(tx: Tx, ctx: Ctx, grantId: string): Promise<string> {
  const token = generateInviteToken();
  const [grant] = await tx
    .update(externalGrants)
    .set({ inviteTokenHash: hashInviteToken(token) })
    .where(
      and(
        eq(externalGrants.id, grantId),
        eq(externalGrants.organisationId, ctx.organisationId),
        isNull(externalGrants.acceptedAt),
        isNull(externalGrants.revokedAt),
      ),
    )
    .returning();
  if (!grant) throw new UserError("This invitation has been accepted or revoked — reload the page");
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    editionId: grant.editionId,
    actorUserId: ctx.actorUserId,
    entityType: "external_grant",
    entityId: grant.id,
    action: "invite",
    summary: `New invitation link for ${grant.invitedEmail}`,
    subjectUserId: grant.userId,
    subjectEmail: grant.invitedEmail,
  });
  return `${appUrl()}/invite/${token}`;
}

/** Sign-offs waiting on this person by name, in this organisation (pending now). */
export async function signoffsWaitingOn(db: Db | Tx, organisationId: string, userId: string) {
  const [items, stands] = await Promise.all([
    db
      .select({
        id: approvalInstances.id,
        entityType: approvalInstances.entityType,
        entityId: approvalInstances.entityId,
        runNumber: approvalInstances.runNumber,
        stepName: approvalInstances.stepNameSnapshot,
        ref: signageItems.ref,
        editionId: editions.id,
      })
      .from(approvalInstances)
      .innerJoin(signageItems, eq(signageItems.id, approvalInstances.entityId))
      .innerJoin(editions, eq(editions.id, signageItems.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(
        and(
          eq(approvalInstances.entityType, "signage_item"),
          eq(approvalInstances.assignedUserId, userId),
          eq(approvalInstances.status, "pending"),
          eq(events.organisationId, organisationId),
        ),
      ),
    db
      .select({
        id: approvalInstances.id,
        entityType: approvalInstances.entityType,
        entityId: approvalInstances.entityId,
        runNumber: approvalInstances.runNumber,
        stepName: approvalInstances.stepNameSnapshot,
        ref: standSubmissions.ref,
        editionId: editions.id,
      })
      .from(approvalInstances)
      .innerJoin(standSubmissions, eq(standSubmissions.id, approvalInstances.entityId))
      .innerJoin(editions, eq(editions.id, standSubmissions.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(
        and(
          eq(approvalInstances.entityType, "stand_submission"),
          eq(approvalInstances.assignedUserId, userId),
          eq(approvalInstances.status, "pending"),
          eq(events.organisationId, organisationId),
        ),
      ),
  ]);
  return [...items, ...stands].sort((a, b) => a.ref.localeCompare(b.ref));
}

/** Steps in each item's (and stand's) current round matching `where`, with their pages. */
async function currentRoundSteps(
  db: Db | Tx,
  organisationId: string,
  where: SQL,
): Promise<(HandoverStep & { editionId: string })[]> {
  const step = {
    id: approvalInstances.id,
    entityType: approvalInstances.entityType,
    entityId: approvalInstances.entityId,
    runNumber: approvalInstances.runNumber,
    status: approvalInstances.status,
    stepName: approvalInstances.stepNameSnapshot,
    departmentId: approvalInstances.assignedDepartmentId,
    code: editions.code,
    editionId: editions.id,
  };
  const [items, stands] = await Promise.all([
    db
      .select({ ...step, ref: signageItems.ref, kind: signageItems.kind })
      .from(approvalInstances)
      .innerJoin(
        signageItems,
        and(
          eq(signageItems.id, approvalInstances.entityId),
          eq(signageItems.currentRunNumber, approvalInstances.runNumber),
        ),
      )
      .innerJoin(editions, eq(editions.id, signageItems.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(
        and(
          eq(approvalInstances.entityType, "signage_item"),
          where,
          isNull(signageItems.deletedAt),
          eq(events.organisationId, organisationId),
        ),
      ),
    db
      .select({ ...step, ref: standSubmissions.ref })
      .from(approvalInstances)
      .innerJoin(
        standSubmissions,
        and(
          eq(standSubmissions.id, approvalInstances.entityId),
          eq(standSubmissions.currentRunNumber, approvalInstances.runNumber),
        ),
      )
      .innerJoin(editions, eq(editions.id, standSubmissions.editionId))
      .innerJoin(events, eq(events.id, editions.eventId))
      .where(
        and(
          eq(approvalInstances.entityType, "stand_submission"),
          where,
          eq(events.organisationId, organisationId),
        ),
      ),
  ]);
  return [
    ...items.map((r) => ({
      id: r.id,
      entityType: r.entityType,
      entityId: r.entityId,
      runNumber: r.runNumber,
      status: r.status,
      stepName: r.stepName,
      ref: r.ref,
      departmentId: r.departmentId,
      editionId: r.editionId,
      href: itemPath(r.code, { kind: r.kind, ref: r.ref }),
    })),
    ...stands.map((r) => ({
      id: r.id,
      entityType: r.entityType,
      entityId: r.entityId,
      runNumber: r.runNumber,
      status: r.status,
      stepName: r.stepName,
      ref: r.ref,
      departmentId: r.departmentId,
      editionId: r.editionId,
      href: `/${r.code}/stands/${encodeURIComponent(r.ref)}`,
    })),
  ].sort((a, b) => a.ref.localeCompare(b.ref));
}

/**
 * Steps in an item's current round that name this person and can still
 * reach them: waiting on them now, not started yet, sent back for changes,
 * or decided but redone after new artwork (those are copied with the same
 * person). Optionally only some departments' steps. Deleted items and older
 * rounds are left alone.
 */
export async function signoffsNaming(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  opts: {
    departmentIds?: readonly string[] | null;
    /** Only steps on items and stands in these events (Users → Events). */
    editionIds?: readonly string[] | null;
  } = {},
): Promise<(HandoverStep & { editionId: string })[]> {
  if (opts.departmentIds && opts.departmentIds.length === 0) return [];
  if (opts.editionIds && opts.editionIds.length === 0) return [];
  const live = or(
    inArray(approvalInstances.status, ["pending", "waiting", "changes_requested"]),
    and(
      inArray(approvalInstances.status, ["approved", "approved_with_conditions", "confirmed"]),
      eq(approvalInstances.invalidateOnNewVersionSnapshot, true),
    ),
  )!;
  const dept: SQL | undefined = opts.departmentIds
    ? inArray(approvalInstances.assignedDepartmentId, [...opts.departmentIds])
    : undefined;
  const inEvents: SQL | undefined = opts.editionIds
    ? inArray(editions.id, [...opts.editionIds])
    : undefined;
  return currentRoundSteps(
    db,
    organisationId,
    and(eq(approvalInstances.assignedUserId, userId), live, dept, inEvents)!,
  );
}

/**
 * Open sign-offs waiting on a whole department (naming nobody) in these
 * events, in departments this person signs for, where nobody else who can
 * sign for the department can open the event — they become nobody's once
 * the person stops working on those events (leaveEventsTx).
 */
export async function strandedEventSignoffs(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  editionIds: readonly string[],
  signers?: ReadonlyMap<string, readonly HandoverSigner[]>,
): Promise<(HandoverStep & { editionId: string })[]> {
  if (editionIds.length === 0) return [];
  const mine = await db
    .select({ departmentId: approvers.departmentId })
    .from(approvers)
    .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId)));
  if (mine.length === 0) return [];
  const others = signers ?? (await departmentSigners(db, organisationId, userId)).signers;
  const steps = await currentRoundSteps(
    db,
    organisationId,
    and(
      isNull(approvalInstances.assignedUserId),
      inArray(approvalInstances.assignedDepartmentId, [
        ...new Set(mine.map((m) => m.departmentId)),
      ]),
      inArray(approvalInstances.status, ["pending", "waiting", "changes_requested"]),
      inArray(editions.id, [...editionIds]),
    )!,
  );
  return steps
    .filter(
      (st) =>
        st.departmentId &&
        !(others.get(st.departmentId) ?? []).some((sg) =>
          seesEdition(signerHolder(sg), st.editionId),
        ),
    )
    .map((st) => ({ ...st, departmentWide: true }));
}

/** A hand-over signer as the events rule sees them. */
function signerHolder(sg: Pick<HandoverSigner, "role" | "editionIds">) {
  return { role: sg.role ?? ("ops" as StaffRole), editionIds: sg.editionIds ?? null };
}

/**
 * Open sign-offs waiting on a whole department (naming nobody) where this
 * person is the last one who can sign for it. Once they can't sign, nobody
 * can decide these, so suspending or removing them hands these over with
 * their own (a person must be picked), and the daily job's "access ended"
 * notice lists them. `signers` is departmentSigners without them, when the
 * caller already has it.
 */
export async function strandedDepartmentSignoffs(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  signers?: ReadonlyMap<string, readonly HandoverSigner[]>,
): Promise<(HandoverStep & { editionId: string })[]> {
  const mine = await db
    .select({ departmentId: approvers.departmentId })
    .from(approvers)
    .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId)));
  if (mine.length === 0) return [];
  const others = signers ?? (await departmentSigners(db, organisationId, userId)).signers;
  const lonely = [...new Set(mine.map((m) => m.departmentId))].filter(
    (d) => (others.get(d)?.length ?? 0) === 0,
  );
  if (lonely.length === 0) return [];
  const steps = await currentRoundSteps(
    db,
    organisationId,
    and(
      isNull(approvalInstances.assignedUserId),
      inArray(approvalInstances.assignedDepartmentId, lonely),
      inArray(approvalInstances.status, ["pending", "waiting", "changes_requested"]),
    )!,
  );
  return steps.map((st) => ({ ...st, departmentWide: true }));
}

/**
 * Sign-off steps that name this person directly. Department steps don't
 * count: they follow the approver list, which removal updates.
 */
async function stepsNaming(db: Db | Tx, organisationId: string, userId: string) {
  return db
    .select({ step: workflowSteps.name, workflow: workflows.name })
    .from(workflowSteps)
    .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflowSteps.approverUserId, userId),
        isNull(workflowSteps.departmentId),
      ),
    );
}

/**
 * Every department's name, and who else can sign for it now (an approver
 * with access, not a viewer, sign-off not paused — canReceiveSignoff).
 */
export async function departmentSigners(
  db: Db | Tx,
  organisationId: string,
  exceptUserId: string,
): Promise<{ names: Map<string, string>; signers: Map<string, HandoverSigner[]> }> {
  const [depts, rows] = await Promise.all([
    db
      .select({ id: departments.id, name: departments.name })
      .from(departments)
      .where(eq(departments.organisationId, organisationId)),
    db
      .select({
        departmentId: approvers.departmentId,
        userId: approvers.userId,
        isMain: approvers.isMain,
        name: users.fullName,
        email: users.email,
        role: memberships.role,
        overrides: memberships.permissionOverrides,
        suspendedAt: memberships.suspendedAt,
        accessEndsAt: memberships.accessEndsAt,
        editionIds: memberships.editionIds,
      })
      .from(approvers)
      .innerJoin(
        memberships,
        and(
          eq(memberships.userId, approvers.userId),
          eq(memberships.organisationId, approvers.organisationId),
        ),
      )
      .innerJoin(users, eq(users.id, approvers.userId))
      .where(and(eq(approvers.organisationId, organisationId), ne(approvers.userId, exceptUserId))),
  ]);
  const signers = new Map<string, HandoverSigner[]>();
  for (const r of rows) {
    if (!canReceiveSignoff({ ...r, overrides: r.overrides as PermissionOverrides })) continue;
    signers.set(r.departmentId, [
      ...(signers.get(r.departmentId) ?? []),
      {
        userId: r.userId!,
        name: r.name || r.email,
        isMain: r.isMain,
        role: r.role,
        editionIds: r.role === "admin" ? null : (r.editionIds ?? null),
      },
    ]);
  }
  return { names: new Map(depts.map((d) => [d.id, d.name])), signers };
}

export type HandoverCandidate = {
  userId: string;
  name: string;
  role: StaffRole;
  departmentId: string | null;
  /** Events they work on; null = every event (a group goes only to someone who can open its events). */
  editionIds: string[] | null;
};

/**
 * People who can take over sign-offs: anyone who can sign now
 * (canReceiveSignoff — active, not a viewer, sign-off not paused).
 */
export async function handoverCandidates(
  db: Db | Tx,
  organisationId: string,
  exceptId: string,
): Promise<HandoverCandidate[]> {
  const rows = await db
    .select({
      userId: users.id,
      name: users.fullName,
      email: users.email,
      role: memberships.role,
      departmentId: memberships.departmentId,
      overrides: memberships.permissionOverrides,
      suspendedAt: memberships.suspendedAt,
      accessEndsAt: memberships.accessEndsAt,
      editionIds: memberships.editionIds,
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(and(eq(memberships.organisationId, organisationId), ne(memberships.userId, exceptId)))
    .orderBy(asc(users.fullName));
  return rows
    .filter((r) => canReceiveSignoff({ ...r, overrides: r.overrides as PermissionOverrides }))
    .map((r) => ({
      userId: r.userId,
      name: r.name || r.email,
      role: r.role,
      departmentId: r.departmentId,
      editionIds: r.role === "admin" ? null : (r.editionIds ?? null),
    }));
}

/** What the Suspend and Remove dialogs offer for someone's sign-offs. */
export type HandoverPlan = {
  groups: HandoverGroup[];
  candidates: HandoverCandidate[];
  /**
   * The person looking isn't a super admin: a department's sign-offs go
   * only to its own approvers or back to it (resolveHandover's limitedFor),
   * so the dialog offers nobody else for them.
   */
  signersOnly?: boolean;
};

/**
 * The sign-offs naming someone (and those waiting on a department only
 * they can sign for), grouped by department, with who could take each
 * group. `viewer` is who will make the change, for what they may pick.
 */
export async function handoverPlan(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  opts: { viewer?: StaffActor | null } = {},
): Promise<HandoverPlan> {
  const [steps, { names, signers }, candidates] = await Promise.all([
    signoffsNaming(db, organisationId, userId),
    departmentSigners(db, organisationId, userId),
    handoverCandidates(db, organisationId, userId),
  ]);
  const stranded = await strandedDepartmentSignoffs(db, organisationId, userId, signers);
  const limitedFor = opts.viewer && !isSuperAdmin(opts.viewer) ? opts.viewer.userId : null;
  const groups = handoverGroups([...steps, ...stranded], { departmentNames: names, signers });
  const viewer = opts.viewer;
  return {
    // A viewer limited to some events never sees refs or links in the others
    // (still counted, so each group still needs its choice).
    groups: viewer
      ? groups.map((g) => ({ ...g, steps: g.steps.map((st) => hideStep(viewer, st)) }))
      : groups,
    candidates: limitedFor ? candidates.filter((c) => c.userId !== limitedFor) : candidates,
    signersOnly: Boolean(limitedFor),
  };
}

/** A step in an event the viewer can't open, without anything that names it. */
function hideStep(viewer: Actor, st: HandoverStep): HandoverStep {
  if (!st.editionId || seesEdition(viewer, st.editionId)) return st;
  return { ...st, entityId: "", ref: "", stepName: "", href: null, editionId: "", hidden: true };
}

/** Items someone still works on: not deleted or complete, in an event being planned or live. */
function workableItem(): SQL {
  return and(
    isNull(signageItems.deletedAt),
    ne(signageItems.status, "closed"),
    inArray(editions.status, ["planning", "live"]),
  )!;
}

export type OwnedItem = {
  id: string;
  ref: string;
  name: string;
  kind: ItemKind;
  editionId: string;
  code: string;
  href: string;
  hidden?: false;
};
/** An owned item in an event the viewer can't open: counted, never named. */
export type HiddenOwnedItem = { hidden: true; kind: ItemKind };

/**
 * The items they own that are still being worked on (the same count
 * everywhere). With a `viewer` limited to some events, items in the others
 * come back as { hidden: true } (no ref, name or link).
 */
export async function workableOwnedItems(
  db: Db | Tx,
  organisationId: string,
  userId: string,
): Promise<OwnedItem[]>;
export async function workableOwnedItems(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  opts: { viewer: Actor },
): Promise<(OwnedItem | HiddenOwnedItem)[]>;
export async function workableOwnedItems(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  opts: { viewer?: Actor } = {},
): Promise<(OwnedItem | HiddenOwnedItem)[]> {
  const items = await ownedItemsOf(db, organisationId, userId);
  const viewer = opts.viewer;
  if (!viewer) return items;
  return items.map((it) =>
    seesEdition(viewer, it.editionId) ? it : { hidden: true as const, kind: it.kind },
  );
}

async function ownedItemsOf(
  db: Db | Tx,
  organisationId: string,
  userId: string,
): Promise<OwnedItem[]> {
  const rows = await db
    .select({
      id: signageItems.id,
      ref: signageItems.ref,
      name: signageItems.name,
      kind: signageItems.kind,
      editionId: signageItems.editionId,
      code: editions.code,
    })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(events.organisationId, organisationId),
        eq(signageItems.ownerUserId, userId),
        workableItem(),
      ),
    )
    .orderBy(asc(signageItems.ref));
  return rows.map((r) => ({
    ...r,
    kind: r.kind as ItemKind,
    href: itemPath(r.code, { kind: r.kind, ref: r.ref }),
  }));
}

/** Their open tasks (for the person page's note about tasks in events they can't open). */
export async function openTasksOf(db: Db | Tx, organisationId: string, userId: string) {
  return db
    .select({ id: tasks.id, title: tasks.title, editionId: tasks.editionId })
    .from(tasks)
    .where(
      and(
        eq(tasks.organisationId, organisationId),
        eq(tasks.assignedToUserId, userId),
        ne(tasks.status, "done"),
      ),
    )
    .orderBy(asc(tasks.title));
}

/** Who can be handed someone's items and tasks: people with access who aren't viewers. */
export type WorkCandidate = {
  userId: string;
  name: string;
  role: StaffRole;
  features: Feature[] | null;
  overrides: PermissionOverrides;
  /** For the person picker (grouped by department, "Name — Job title"). */
  jobTitle: string | null;
  departmentId: string | null;
  departmentName: string | null;
  /** Events they work on; null = every event. */
  editionIds: string[] | null;
};

export async function workCandidates(
  db: Db | Tx,
  organisationId: string,
  exceptId: string,
): Promise<WorkCandidate[]> {
  const rows = await db
    .select({
      userId: users.id,
      name: users.fullName,
      email: users.email,
      role: memberships.role,
      features: memberships.features,
      overrides: memberships.permissionOverrides,
      jobTitle: memberships.jobTitle,
      departmentId: memberships.departmentId,
      departmentName: departments.name,
      editionIds: memberships.editionIds,
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .leftJoin(departments, eq(departments.id, memberships.departmentId))
    .where(
      and(
        eq(memberships.organisationId, organisationId),
        ne(memberships.userId, exceptId),
        ne(memberships.role, "viewer"),
        activeMembership(),
      ),
    )
    .orderBy(asc(users.fullName));
  return rows.map((r) => ({
    userId: r.userId,
    name: r.name || r.email,
    role: r.role,
    features: r.role === "admin" ? null : parseFeatures(r.features),
    overrides: (r.overrides ?? {}) as PermissionOverrides,
    jobTitle: r.jobTitle?.trim() || null,
    departmentId: r.departmentId,
    departmentName: r.departmentName,
    editionIds: r.role === "admin" ? null : (r.editionIds ?? null),
  }));
}

export type RemovalImpact = {
  name: string;
  openTasks: number;
  /** Items still being worked on (the ones that move). */
  ownedItems: number;
  ownedByKind: Partial<Record<ItemKind, number>>;
  /** Sign-offs naming them: waiting now or later in the current round. */
  waiting: { count: number; now: number; refs: string[] };
  handover: HandoverPlan;
  departments: { id: string; name: string; isMain: boolean; others: string[] }[];
  /** Workflow steps that name them; these must be changed first. */
  namedSteps: string[];
  /** Who could be handed the sign-offs (kept for older callers). */
  candidates: HandoverCandidate[];
  workCandidates: WorkCandidate[];
  /** Live partner access they hold here, revoked when they are removed. */
  partnerAccess: string[];
};

/** What removing (or suspending) someone would change, for the confirm dialogs. */
export async function getRemovalImpact(
  db: Db | Tx,
  organisationId: string,
  userId: string,
  opts: { viewer?: StaffActor | null } = {},
): Promise<RemovalImpact | null> {
  const [row] = await db
    .select({ user: users })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(and(eq(memberships.userId, userId), eq(memberships.organisationId, organisationId)))
    .limit(1);
  if (!row) return null;
  const [[tasksOpen], items, plan, named, mine, people, { signers }] = await Promise.all([
    db
      .select({ n: count() })
      .from(tasks)
      .where(
        and(
          eq(tasks.organisationId, organisationId),
          eq(tasks.assignedToUserId, userId),
          ne(tasks.status, "done"),
        ),
      ),
    workableOwnedItems(db, organisationId, userId),
    handoverPlan(db, organisationId, userId, opts),
    stepsNaming(db, organisationId, userId),
    db
      .select({ departmentId: approvers.departmentId, isMain: approvers.isMain, dept: departments })
      .from(approvers)
      .innerJoin(departments, eq(departments.id, approvers.departmentId))
      .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId))),
    workCandidates(db, organisationId, userId),
    departmentSigners(db, organisationId, userId),
  ]);
  const grants = await livePartnerAccessOf(db, organisationId, {
    userId,
    email: row.user.email,
  });
  const partnerAccess = await Promise.all(
    grants.map((g) => externalAccountLabel(db, organisationId, g)),
  );
  const live = mine.filter((m) => !m.dept.isArchived && m.dept.signsOff);
  const steps = plan.groups.flatMap((g) => g.steps);
  const byKind: Partial<Record<ItemKind, number>> = {};
  for (const it of items) byKind[it.kind] = (byKind[it.kind] ?? 0) + 1;
  return {
    name: row.user.fullName || row.user.email,
    openTasks: Number(tasksOpen.n),
    ownedItems: items.length,
    ownedByKind: byKind,
    waiting: {
      count: steps.length,
      now: steps.filter((s) => s.status === "pending").length,
      // Refs in events the viewer can't open are never named (handoverPlan hid them).
      refs: [...new Set(steps.filter((w) => !w.hidden).map((w) => w.ref))].slice(0, 5),
    },
    handover: plan,
    departments: live.map((m) => ({
      id: m.departmentId,
      name: m.dept.name,
      isMain: m.isMain,
      others: (signers.get(m.departmentId) ?? []).map((s) => s.name),
    })),
    namedSteps: named.map((n) => `“${n.step}” (${n.workflow})`),
    candidates: plan.candidates,
    workCandidates: people,
    partnerAccess,
  };
}

/**
 * Point the item plans (each item's chosen sign-off people for the next
 * round) that name this person back at the department, with an audit row
 * per item changed so its history shows the plan moving. `stepIds` limits
 * it to some departments' steps; null = all of them.
 */
async function clearPlanEntries(
  tx: Tx,
  ctx: Ctx | SystemCtx,
  opts: {
    userId: string;
    who: string;
    why: string;
    stepIds: readonly string[] | null;
    /** Only items in these events (Users → Events); null/missing = every event. */
    editionIds?: readonly string[] | null;
  },
): Promise<number> {
  const { userId, stepIds } = opts;
  if (stepIds && stepIds.length === 0) return 0;
  if (opts.editionIds && opts.editionIds.length === 0) return 0;
  const orgEditions = tx
    .select({ id: editions.id })
    .from(editions)
    .innerJoin(events, eq(events.id, editions.eventId))
    .where(eq(events.organisationId, ctx.organisationId));
  const rows = await tx
    .select({
      id: signageItems.id,
      ref: signageItems.ref,
      editionId: signageItems.editionId,
      signoffs: signageItems.signoffs,
    })
    .from(signageItems)
    .where(
      and(
        sql`${signageItems.signoffs} @> ${JSON.stringify([{ userId }])}::jsonb`,
        inArray(signageItems.editionId, orgEditions),
        opts.editionIds ? inArray(signageItems.editionId, [...opts.editionIds]) : undefined,
      ),
    )
    .for("update");
  let changed = 0;
  for (const r of rows) {
    const before = r.signoffs ?? [];
    const after = before.map((p) =>
      p.userId === userId && (!stepIds || stepIds.includes(p.stepId)) ? { ...p, userId: null } : p,
    );
    if (after.every((p, i) => p.userId === before[i].userId)) continue;
    await tx.update(signageItems).set({ signoffs: after }).where(eq(signageItems.id, r.id));
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      editionId: r.editionId,
      ...auditActor(ctx),
      entityType: "signage_item",
      entityId: r.id,
      action: "update",
      before: { signoffs: before },
      after: { signoffs: after },
      summary: `${r.ref}: the sign-off plan no longer names ${opts.who}, who ${opts.why} — that step goes to the department`,
      subjectUserId: userId,
    });
    changed++;
  }
  return changed;
}

/** The workflow steps that belong to these departments (for clearing plans). */
async function departmentStepIds(tx: Tx, organisationId: string, departmentIds: string[]) {
  if (departmentIds.length === 0) return [];
  const rows = await tx
    .select({ id: workflowSteps.id })
    .from(workflowSteps)
    .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        inArray(workflowSteps.departmentId, departmentIds),
      ),
    );
  return rows.map((r) => r.id);
}

async function nameOf(tx: Tx, userId: string): Promise<string> {
  const u = await tx.query.users.findFirst({ where: eq(users.id, userId) });
  return u ? u.fullName || u.email : "someone else";
}

/**
 * Move the given steps: each group to its target (a person, or null for
 * everyone who signs off for the department). Steps waiting now are
 * delegated (the engine keeps who it came from); later ones are re-pointed
 * so they reach the new person when they start. One audit row per item,
 * and whoever now has a sign-off waiting is told.
 */
async function moveSignoffs(
  tx: Tx,
  ctx: Ctx | SystemCtx,
  opts: {
    userId: string;
    who: string;
    why: string;
    groups: HandoverGroup[];
    targets: Map<string, string | null>;
    editionOf: Map<string, string>;
  },
): Promise<number> {
  const orgId = ctx.organisationId;
  let moved = 0;
  // Per person told: the refs, and the event of each (one event → kept with it).
  const told = new Map<string, { refs: string[]; editionIds: (string | null)[] }>();
  // Per department and event: only people who can open the event are told.
  const backToDept = new Map<
    string,
    { departmentId: string; editionId: string | null; name: string; refs: string[] }
  >();
  const names = new Map<string, string>();
  for (const g of opts.groups) {
    if (!opts.targets.has(g.key)) continue;
    const target = opts.targets.get(g.key) ?? null;
    if (target && !names.has(target)) names.set(target, await nameOf(tx, target));
    const to = target ? names.get(target)! : `everyone who signs off for ${g.departmentName}`;
    const byEntity = new Map<string, HandoverStep[]>();
    for (const s of g.steps) byEntity.set(s.entityId, [...(byEntity.get(s.entityId) ?? []), s]);
    for (const [entityId, list] of byEntity) {
      const first = list[0];
      for (const s of list) {
        if (s.status === "pending" && target) {
          const run = await loadRun(tx, s.entityType, s.entityId, s.runNumber);
          const updated = applyDelegation(run, {
            instanceId: s.id,
            toUserId: target,
            fromUserId: opts.userId,
          });
          await persistRun(tx, s.entityType, s.entityId, updated);
        } else {
          // Decided steps keep who decided; only who a redo goes to changes.
          const decided = !["pending", "waiting", "changes_requested"].includes(s.status);
          await tx
            .update(approvalInstances)
            .set(
              decided
                ? { assignedUserId: target }
                : { assignedUserId: target, delegatedFromUserId: opts.userId },
            )
            .where(eq(approvalInstances.id, s.id));
        }
        if (s.status === "pending") {
          if (target) {
            const entry = told.get(target) ?? { refs: [], editionIds: [] };
            entry.refs.push(s.ref);
            entry.editionIds.push(opts.editionOf.get(s.id) ?? null);
            told.set(target, entry);
          } else if (g.departmentId) {
            const editionId = opts.editionOf.get(s.id) ?? null;
            const key = `${g.departmentId}|${editionId ?? ""}`;
            const entry = backToDept.get(key) ?? {
              departmentId: g.departmentId,
              editionId,
              name: g.departmentName ?? "the department",
              refs: [],
            };
            entry.refs.push(s.ref);
            backToDept.set(key, entry);
          }
        }
        moved++;
      }
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: opts.editionOf.get(first.id) ?? null,
        ...auditActor(ctx),
        entityType: first.entityType,
        entityId,
        action: "delegate",
        before: first.departmentWide
          ? { assignedUserId: null, assignedDepartmentId: first.departmentId }
          : { assignedUserId: opts.userId },
        after: {
          steps: list.map((s) => ({ step: s.stepName, status: s.status })),
          fromUserId: opts.userId,
          toUserId: target,
          toDepartmentId: target ? null : g.departmentId,
        },
        summary: `${first.ref}: ${list.map((s) => s.stepName).join(", ")} handed to ${to} after ${opts.who} ${opts.why}`,
        subjectUserId: opts.userId,
      });
    }
  }
  const by = ctx.actorName ? `${ctx.actorName} handed` : "they were handed";
  for (const [userId, { refs, editionIds }] of told) {
    await notify(tx, {
      userIds: [userId],
      kind: "delegation",
      title:
        refs.length === 1
          ? `A sign-off is now yours: ${refs[0]}`
          : `${refs.length} sign-offs are now yours`,
      body: `${opts.who} ${opts.why}; ${by} their sign-offs to you.`,
      link: "/approvals",
      editionId: soleEditionId(editionIds),
    });
  }
  for (const { departmentId, editionId, name, refs } of backToDept.values()) {
    await notify(tx, {
      userIds: (await departmentSignerIds(tx, orgId, departmentId, { editionId })).filter(
        (id) => id !== opts.userId,
      ),
      kind: "delegation",
      title:
        refs.length === 1
          ? `A ${name} sign-off is back with your department: ${refs[0]}`
          : `${refs.length} ${name} sign-offs are back with your department`,
      body: `${opts.who} ${opts.why}, so anyone who signs off for ${name} can decide.`,
      link: "/approvals",
      ...(editionId ? { scope: { organisationId: orgId, editionId } } : {}),
    });
  }
  return moved;
}

/**
 * Hand over every sign-off naming someone who is being suspended or
 * removed — and those waiting on a department only they can sign for — each
 * department's to the person picked for it (by default its main approver,
 * else another approver who can sign), or back to the department. Refused
 * when a group has nobody to go to. A manager who isn't a super admin may
 * only hand a department's sign-offs to its own approvers or back to it
 * (resolveHandover's limitedFor). Their item plans stop naming them too.
 */
async function handOverSignoffsTx(
  tx: Tx,
  ctx: Ctx,
  opts: {
    actor: StaffActor;
    userId: string;
    who: string;
    why: string;
    choice?: HandoverChoice | null;
    fallback?: string | null;
  },
): Promise<number> {
  const orgId = ctx.organisationId;
  const named = await signoffsNaming(tx, orgId, opts.userId);
  await clearPlanEntries(tx, ctx, { ...opts, stepIds: null });
  const [{ names, signers }, candidates] = await Promise.all([
    departmentSigners(tx, orgId, opts.userId),
    handoverCandidates(tx, orgId, opts.userId),
  ]);
  const steps = [...named, ...(await strandedDepartmentSignoffs(tx, orgId, opts.userId, signers))];
  if (steps.length === 0) return 0;
  const groups = handoverGroups(steps, { departmentNames: names, signers });
  const ok = new Map(candidates.map((c) => [c.userId, c]));
  const res = resolveHandover(groups, opts.choice, {
    personId: opts.userId,
    who: opts.who,
    // Someone who can sign, and open every event the group's sign-offs are in.
    canReceive: (id, g) => {
      const c = ok.get(id);
      return Boolean(c) && seesAllEditions(c!, g.editionIds);
    },
    fallback: opts.fallback,
    limitedFor: isSuperAdmin(opts.actor) ? null : opts.actor.userId,
  });
  if (!res.ok) throw new UserError(res.error);
  return moveSignoffs(tx, ctx, {
    ...opts,
    groups,
    targets: res.targets,
    editionOf: new Map(steps.map((st) => [st.id, st.editionId])),
  });
}

/**
 * Someone stops signing for some departments (taken off the approvers,
 * moved, made a viewer or paused): sign-offs naming them for those
 * departments go back to the department when someone else there can sign;
 * the rest stay with them (named, so they can still be handed on from the
 * item). Their item plans for those departments name nobody. Used by the
 * person page, Users → Departments and the daily job when someone's access
 * ends (with a SystemCtx).
 */
export async function stopSigningTx(
  tx: Tx,
  ctx: Ctx | SystemCtx,
  opts: { userId: string; who: string; why: string; departmentIds: string[] | null },
): Promise<{ moved: number; kept: number }> {
  const orgId = ctx.organisationId;
  await lockPeople(tx, orgId);
  const stepIds = opts.departmentIds
    ? await departmentStepIds(tx, orgId, opts.departmentIds)
    : null;
  await clearPlanEntries(tx, ctx, { ...opts, stepIds });
  const steps = await signoffsNaming(tx, orgId, opts.userId, {
    departmentIds: opts.departmentIds,
  });
  if (steps.length === 0) return { moved: 0, kept: 0 };
  const { names, signers } = await departmentSigners(tx, orgId, opts.userId);
  const groups = handoverGroups(steps, { departmentNames: names, signers });
  const targets = new Map<string, string | null>(
    groups.filter((g) => g.departmentId && g.signers.length > 0).map((g) => [g.key, null]),
  );
  const moved = await moveSignoffs(tx, ctx, {
    ...opts,
    groups,
    targets,
    editionOf: new Map(steps.map((s) => [s.id, s.editionId])),
  });
  return { moved, kept: steps.length - moved };
}

/**
 * Someone stops working on some events (Users → Events, narrowing): their
 * item plans there name nobody; sign-offs waiting on them there — and those
 * waiting on a department only they could open the event for — go back to
 * the department when someone else there can open the event, else to the
 * person picked (refused without one). One audit row per item. Tasks and
 * items they own there stay with them (the person page lists them).
 */
export async function leaveEventsTx(
  tx: Tx,
  ctx: Ctx,
  opts: {
    actor: StaffActor;
    userId: string;
    who: string;
    editionIds: readonly string[];
    choice?: HandoverChoice | null;
  },
): Promise<{ moved: number }> {
  const orgId = ctx.organisationId;
  if (opts.editionIds.length === 0) return { moved: 0 };
  await lockPeople(tx, orgId);
  const codes = await editionCodesOf(tx, opts.editionIds);
  const where = codes.length > 0 && codes.length <= 2 ? codes.join(" and ") : null;
  const why = where ? `no longer works on ${where}` : "no longer works on some events";
  await clearPlanEntries(tx, ctx, {
    userId: opts.userId,
    who: opts.who,
    why,
    stepIds: null,
    editionIds: opts.editionIds,
  });
  const named = await signoffsNaming(tx, orgId, opts.userId, { editionIds: opts.editionIds });
  const [{ names, signers }, candidates] = await Promise.all([
    departmentSigners(tx, orgId, opts.userId),
    handoverCandidates(tx, orgId, opts.userId),
  ]);
  const stranded = await strandedEventSignoffs(tx, orgId, opts.userId, opts.editionIds, signers);
  const steps = [...named, ...stranded];
  if (steps.length === 0) return { moved: 0 };
  const groups = eventHandoverGroups(steps, { departmentNames: names, signers });
  const limitedFor = isSuperAdmin(opts.actor) ? null : opts.actor.userId;
  // Say which event nobody else can open, rather than the generic words.
  for (const g of groups) {
    if (opts.choice?.[g.key] || g.defaultTo || (limitedFor && g.departmentId)) continue;
    if (!g.departmentName) continue;
    const there = await editionCodesOf(tx, g.editionIds);
    throw new UserError(
      `Nobody else in ${g.departmentName} can open ${there.length > 0 && there.length <= 2 ? there.join(" and ") : "those events"} — choose who takes ${opts.who}'s ${g.departmentName} sign-offs there`,
    );
  }
  const ok = new Map(candidates.map((c) => [c.userId, c]));
  const res = resolveHandover(groups, opts.choice, {
    personId: opts.userId,
    who: opts.who,
    canReceive: (id, g) => {
      const c = ok.get(id);
      return Boolean(c) && seesAllEditions(c!, g.editionIds);
    },
    limitedFor,
  });
  if (!res.ok) throw new UserError(res.error);
  const moved = await moveSignoffs(tx, ctx, {
    userId: opts.userId,
    who: opts.who,
    why,
    groups,
    targets: res.targets,
    editionOf: new Map(steps.map((st) => [st.id, st.editionId])),
  });
  return { moved };
}

/** The membership and user for someone on the team, or a refusal. */
async function loadMember(tx: Tx, ctx: Ctx, userId: string) {
  const membership = await tx.query.memberships.findFirst({
    where: and(eq(memberships.userId, userId), eq(memberships.organisationId, ctx.organisationId)),
  });
  if (!membership) throw new UserError("This person isn't on the team any more — reload the page");
  const user = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
  return { membership, user, who: user?.fullName || user?.email || "This person" };
}

/** Their live partner access in this organisation (by account or email), for the Remove dialog. */
async function livePartnerAccessOf(
  db: Db | Tx,
  organisationId: string,
  person: { userId: string; email: string | null },
) {
  return db
    .select()
    .from(externalGrants)
    .where(
      and(
        eq(externalGrants.organisationId, organisationId),
        person.email
          ? or(
              eq(externalGrants.userId, person.userId),
              sql`lower(${externalGrants.invitedEmail}) = ${person.email.toLowerCase()}`,
            )
          : eq(externalGrants.userId, person.userId),
        liveGrantSql(),
      ),
    );
}

/** Revoke someone's live partner access in this organisation, one audit row each. */
async function revokeLivePartnerAccessTx(
  tx: Tx,
  ctx: Ctx,
  person: { userId: string; email: string | null; why: string },
): Promise<number> {
  const live = await livePartnerAccessOf(tx, ctx.organisationId, person);
  const now = new Date();
  for (const g of live) {
    await tx
      .update(externalGrants)
      .set({ revokedAt: now, updatedAt: now })
      .where(eq(externalGrants.id, g.id));
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      editionId: g.editionId,
      actorUserId: ctx.actorUserId,
      entityType: "external_grant",
      entityId: g.id,
      action: "grant_revoke",
      before: { revokedAt: null, email: g.invitedEmail, role: g.role },
      after: { revokedAt: now.toISOString() },
      summary: `Portal access for ${g.invitedEmail} (${await externalAccountLabel(tx, ctx.organisationId, g)}) revoked ${person.why}`,
      subjectUserId: g.userId ?? person.userId,
      subjectEmail: g.invitedEmail,
    });
  }
  return live.length;
}

/**
 * Remove someone who has left (super admins only). Sign-offs naming them
 * go to someone who can sign for each department (handOverSignoffsTx); their
 * open tasks and the items they own that are still being worked on go to
 * the person picked (the super admin removing them by default), with an
 * audit row each — items of a kind that person can't work on go to the
 * super admin instead; they stop being an approver, so each department's
 * step falls back to its next main approver or the whole department.
 * Refused only while a workflow step names them directly (outside the
 * departments).
 */
export async function removeMemberTx(
  tx: Tx,
  ctx: Ctx & { actorName: string },
  input: {
    userId: string;
    handTo?: HandoverChoice | null;
    handToUserId?: string | null;
    workToUserId?: string | null;
  },
): Promise<{
  name: string;
  items: number;
  tasks: number;
  handedOver: number;
  workToName: string;
  itemsToYou: number;
  partnerAccessRevoked: number;
  /** Tasks in events the person picked can't open, given to the remover instead. */
  tasksToYou: number;
}> {
  const orgId = ctx.organisationId;
  await lockPeople(tx, orgId);
  const actor = await loadActor(tx, ctx);
  const { membership, user: member, who } = await loadMember(tx, ctx, input.userId);
  if (membership.userId === ctx.actorUserId) {
    throw new UserError("You can't remove yourself — ask another super admin");
  }
  if (!canRemovePerson(actor, memberCtx(membership))) {
    throw new UserError("Only a super admin can remove people");
  }
  if (
    membership.role === "admin" &&
    !(await anotherLastingSuperAdmin(tx, orgId, membership.userId))
  ) {
    throw new UserError(LAST_ADMIN);
  }

  const named = await stepsNaming(tx, orgId, membership.userId);
  if (named.length > 0) {
    throw new UserError(
      `${who} is the named approver for ${named.map((n) => `“${n.step}”`).join(", ")} — pick someone else in that workflow first`,
    );
  }

  // Who takes their tasks and items: someone with access who isn't a viewer.
  const workTo = input.workToUserId || ctx.actorUserId;
  let workAccess: {
    role: StaffRole;
    features: Feature[] | null;
    overrides: PermissionOverrides;
    editionIds: string[] | null;
  };
  let workToName = ctx.actorName;
  if (workTo === ctx.actorUserId) {
    workAccess = {
      role: actor.role,
      features: actor.features ?? null,
      overrides: {},
      editionIds: actor.editionIds ?? null,
    };
  } else {
    const candidate = (await workCandidates(tx, orgId, membership.userId)).find(
      (c) => c.userId === workTo,
    );
    if (!candidate) {
      throw new UserError("Pick someone with access who isn't a viewer to take over their work");
    }
    workAccess = candidate;
    workToName = candidate.name;
  }

  const handedOver = await handOverSignoffsTx(tx, ctx, {
    actor,
    userId: membership.userId,
    who,
    why: "left the team",
    choice: input.handTo,
    fallback: input.handToUserId,
  });

  // Open tasks (subtasks included), one audit row each. A task in an event
  // the person picked can't open goes to the remover (a super admin) instead.
  const movedTasks = await tx
    .select({ id: tasks.id, title: tasks.title, editionId: tasks.editionId })
    .from(tasks)
    .where(
      and(
        eq(tasks.organisationId, orgId),
        eq(tasks.assignedToUserId, membership.userId),
        ne(tasks.status, "done"),
      ),
    )
    .for("update");
  const tasksToWorker: string[] = [];
  const tasksToWorkerEditions: (string | null)[] = [];
  let tasksToYou = 0;
  for (const t of movedTasks) {
    const to = !t.editionId || seesEdition(workAccess, t.editionId) ? workTo : ctx.actorUserId;
    if (to === ctx.actorUserId && workTo !== ctx.actorUserId) tasksToYou++;
    if (to === workTo && workTo !== ctx.actorUserId) {
      tasksToWorker.push(t.title);
      tasksToWorkerEditions.push(t.editionId);
    }
    await tx.update(tasks).set({ assignedToUserId: to }).where(eq(tasks.id, t.id));
    await writeAudit(tx, {
      organisationId: orgId,
      editionId: t.editionId,
      actorUserId: ctx.actorUserId,
      entityType: "task",
      entityId: t.id,
      action: "update",
      before: { assignedToUserId: membership.userId },
      after: { assignedToUserId: to },
      summary: `Task “${t.title}” moved to ${to === workTo ? workToName : ctx.actorName} after ${who} left the team`,
      subjectUserId: membership.userId,
    });
  }
  if (tasksToWorker.length > 0) {
    await notify(tx, {
      userIds: [workTo],
      kind: "task_assigned",
      title:
        tasksToWorker.length === 1
          ? `A task is now yours: ${tasksToWorker[0]}`
          : `${tasksToWorker.length} tasks are now yours`,
      body: `${who} left the team; ${ctx.actorName} gave you their open tasks.`,
      link: "/my-work",
      editionId: soleEditionId(tasksToWorkerEditions),
    });
  }

  // Items still being worked on; finished ones and archived events keep their owner.
  const owned = await workableOwnedItems(tx, orgId, membership.userId);
  let itemsToYou = 0;
  const toWorker: string[] = [];
  const toWorkerEditions: string[] = [];
  for (const it of owned) {
    // Only to someone who can work on that kind of item and open its event.
    const to =
      canWorkOwnItem(workAccess, it.kind) && seesEdition(workAccess, it.editionId)
        ? workTo
        : ctx.actorUserId;
    if (to === ctx.actorUserId && workTo !== ctx.actorUserId) itemsToYou++;
    if (to === workTo && workTo !== ctx.actorUserId) {
      toWorker.push(it.ref);
      toWorkerEditions.push(it.editionId);
    }
    await tx.update(signageItems).set({ ownerUserId: to }).where(eq(signageItems.id, it.id));
    await writeAudit(tx, {
      organisationId: orgId,
      editionId: it.editionId,
      actorUserId: ctx.actorUserId,
      entityType: "signage_item",
      entityId: it.id,
      action: "update",
      before: { ownerUserId: membership.userId },
      after: { ownerUserId: to },
      summary: `${it.ref}: owner changed to ${to === workTo ? workToName : ctx.actorName} after ${who} left the team`,
      subjectUserId: membership.userId,
    });
  }
  if (toWorker.length > 0) {
    await notify(tx, {
      userIds: [workTo],
      kind: "item_assigned",
      title:
        toWorker.length === 1
          ? `You now own ${toWorker[0]}`
          : `You now own ${toWorker.length} items`,
      body: `${who} left the team; ${ctx.actorName} gave you the items they owned.`,
      link: "/my-work",
      editionId: soleEditionId(toWorkerEditions),
    });
  }

  if (member) {
    const revoked = await tx
      .update(staffInvites)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(staffInvites.organisationId, orgId),
          eq(staffInvites.invitedEmail, member.email.toLowerCase()),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      )
      .returning({ id: staffInvites.id });
    for (const r of revoked) {
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: ctx.actorUserId,
        entityType: "staff_invite",
        entityId: r.id,
        action: "grant_revoke",
        summary: `Invitation for ${member.email} cancelled when they were removed`,
        subjectUserId: member.id,
        subjectEmail: member.email,
      });
    }
  }
  // Partner access here ends too: without a membership the next page load
  // would otherwise sign them in to the portal.
  const grantsRevoked = await revokeLivePartnerAccessTx(tx, ctx, {
    userId: membership.userId,
    email: member?.email ?? null,
    why: `when ${who} was removed from the team`,
  });
  // They no longer sign off for anyone: each department's step falls back.
  const dropped = await tx
    .delete(approvers)
    .where(
      and(
        eq(approvers.organisationId, orgId),
        member
          ? or(
              eq(approvers.userId, membership.userId),
              and(isNull(approvers.userId), eq(approvers.email, member.email.toLowerCase())),
            )
          : eq(approvers.userId, membership.userId),
      ),
    )
    .returning({ departmentId: approvers.departmentId, isMain: approvers.isMain });
  // Signed out everywhere, now (Better Auth sessions; no cookie cache).
  const sessionsEnded = await revokeSessionsTx(tx, membership.userId);
  await tx.delete(memberships).where(eq(memberships.id, membership.id));
  if (dropped.length > 0) await syncDepartmentSteps(tx, orgId);
  await writeAudit(tx, {
    organisationId: orgId,
    actorUserId: ctx.actorUserId,
    entityType: "membership",
    entityId: membership.id,
    action: "grant_revoke",
    before: {
      userId: membership.userId,
      role: membership.role,
      departmentId: membership.departmentId,
      signsOffFor: dropped,
    },
    after: {
      tasksMovedTo: workTo,
      itemsMovedTo: workTo,
      itemsMovedToRemover: itemsToYou,
      tasksMovedToRemover: tasksToYou,
      signoffsHandedOver: handedOver,
      partnerAccessRevoked: grantsRevoked,
      sessionsEnded,
    },
    summary: `Removed ${member?.email ?? "a team member"} from the team`,
    subjectUserId: membership.userId,
    subjectEmail: member?.email ?? null,
  });
  return {
    name: who,
    items: owned.length,
    tasks: movedTasks.length,
    handedOver,
    workToName,
    itemsToYou,
    partnerAccessRevoked: grantsRevoked,
    tasksToYou,
  };
}

/** Why the actor can't suspend, reactivate or end this person's access, or null. */
async function suspendRefusal(
  tx: Tx,
  ctx: Ctx,
  actor: StaffActor,
  membership: MembershipRow,
  opts: { removesAccess: boolean },
): Promise<string | null> {
  if (membership.userId === ctx.actorUserId) {
    return "You can't change your own access — ask another super admin";
  }
  // Scope first, so nobody out of scope learns anything about the person.
  if (!canSuspendPerson(actor, memberCtx(membership), { lastActiveAdmin: false })) {
    return "You can't change this person's access";
  }
  const lastActiveAdmin =
    opts.removesAccess &&
    membership.role === "admin" &&
    !(await anotherLastingSuperAdmin(tx, ctx.organisationId, membership.userId));
  if (lastActiveAdmin) return LAST_ADMIN;
  return null;
}

/**
 * Suspend someone: they can't sign in, aren't told about anything and
 * aren't offered anywhere until reactivated. Sign-offs naming them go to
 * someone who can sign for each department (handOverSignoffsTx: by default
 * the department's main approver or another approver; a person must be
 * picked where nobody else signs); their approver rows, tasks and items
 * stay, so reactivating restores the rest. Refused while a workflow step
 * names them directly.
 */
export async function suspendMemberTx(
  tx: Tx,
  ctx: Ctx & { actorName: string },
  input: { userId: string; handTo?: HandoverChoice | null; handToUserId?: string | null },
): Promise<{ name: string; handedOver: number }> {
  await lockPeople(tx, ctx.organisationId);
  const actor = await loadActor(tx, ctx);
  const { membership, user, who } = await loadMember(tx, ctx, input.userId);
  refuse(await suspendRefusal(tx, ctx, actor, membership, { removesAccess: true }));
  if (membership.suspendedAt) throw new UserError(`${who} is already suspended`);
  const named = await stepsNaming(tx, ctx.organisationId, membership.userId);
  if (named.length > 0) {
    throw new UserError(
      `${who} is the named approver for ${named.map((n) => `“${n.step}”`).join(", ")} — pick someone else in that workflow first`,
    );
  }
  const handedOver = await handOverSignoffsTx(tx, ctx, {
    actor,
    userId: membership.userId,
    who,
    why: "is suspended",
    choice: input.handTo,
    fallback: input.handToUserId,
  });
  const now = new Date();
  await tx
    .update(memberships)
    .set({ suspendedAt: now, suspendedBy: ctx.actorUserId })
    .where(eq(memberships.id, membership.id));
  // Signed out everywhere, now (Better Auth sessions; no cookie cache).
  const sessionsEnded = await revokeSessionsTx(tx, membership.userId);
  // A main approver who is suspended isn't named on new sign-offs.
  await syncDepartmentSteps(tx, ctx.organisationId);
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "membership",
    entityId: membership.id,
    action: "grant_revoke",
    before: { suspendedAt: null },
    after: {
      suspendedAt: now.toISOString(),
      suspendedBy: ctx.actorUserId,
      signoffsHandedOver: handedOver,
      sessionsEnded,
    },
    summary: `Suspended ${user?.email ?? who}`,
    subjectUserId: membership.userId,
    subjectEmail: user?.email ?? null,
  });
  return { name: who, handedOver };
}

/** Give a suspended person their access back, exactly as it was. */
export async function reactivateMemberTx(
  tx: Tx,
  ctx: Ctx,
  input: { userId: string },
): Promise<{ name: string; accessEnded: boolean }> {
  const actor = await loadActor(tx, ctx);
  const { membership, user, who } = await loadMember(tx, ctx, input.userId);
  refuse(await suspendRefusal(tx, ctx, actor, membership, { removesAccess: false }));
  if (!membership.suspendedAt) throw new UserError(`${who} isn't suspended`);
  await tx
    .update(memberships)
    .set({ suspendedAt: null, suspendedBy: null })
    .where(eq(memberships.id, membership.id));
  await syncDepartmentSteps(tx, ctx.organisationId);
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "membership",
    entityId: membership.id,
    action: "settings_change",
    before: { suspendedAt: membership.suspendedAt.toISOString() },
    after: { suspendedAt: null },
    summary: `Reactivated ${user?.email ?? who}`,
    subjectUserId: membership.userId,
    subjectEmail: user?.email ?? null,
  });
  // Reactivating doesn't move an end date that has already passed.
  return { name: who, accessEnded: !accessLive({ accessEndsAt: membership.accessEndsAt }) };
}

/**
 * Set or clear the date someone's access ends (the end of that London day),
 * for a team member or an open invitation. Today or later only.
 */
export async function setAccessEndTx(
  tx: Tx,
  ctx: Ctx,
  input: { userId?: string; inviteId?: string; date: string | null },
): Promise<{ name: string; endsAt: Date | null }> {
  const endsAt = accessEndFromInput(input.date) ?? null;
  const summaryFor = (email: string) =>
    endsAt
      ? `Access for ${email} ends ${formatDate(londonDateOfAccessEnd(endsAt))}`
      : `End date cleared for ${email}`;
  // First, invitations too: an invitation accepted meanwhile is refused by
  // openInvite rather than given an end date its membership never sees.
  await lockPeople(tx, ctx.organisationId);
  if (input.inviteId) {
    const { invite } = await managedInvite(tx, ctx, input.inviteId);
    await tx
      .update(staffInvites)
      .set({ accessEndsAt: endsAt })
      .where(eq(staffInvites.id, invite.id));
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "staff_invite",
      entityId: invite.id,
      action: "settings_change",
      before: { accessEndsAt: invite.accessEndsAt?.toISOString() ?? null },
      after: { accessEndsAt: endsAt?.toISOString() ?? null },
      summary: summaryFor(invite.invitedEmail),
      subjectEmail: invite.invitedEmail,
    });
    return { name: invite.fullName || invite.invitedEmail, endsAt };
  }
  if (!input.userId) throw new UserError("Choose a person");
  const actor = await loadActor(tx, ctx);
  const { membership, user, who } = await loadMember(tx, ctx, input.userId);
  refuse(await suspendRefusal(tx, ctx, actor, membership, { removesAccess: endsAt != null }));
  await tx
    .update(memberships)
    .set({ accessEndsAt: endsAt })
    .where(eq(memberships.id, membership.id));
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "membership",
    entityId: membership.id,
    action: "settings_change",
    before: { accessEndsAt: membership.accessEndsAt?.toISOString() ?? null },
    after: { accessEndsAt: endsAt?.toISOString() ?? null },
    summary: summaryFor(user?.email ?? who),
    subjectUserId: membership.userId,
    subjectEmail: user?.email ?? null,
  });
  return { name: who, endsAt };
}

// ---------------------------------------------------------------------------
// Add several people at once.
// ---------------------------------------------------------------------------

export type PreviewReason =
  "ready" | "on_team" | "invited" | "other_org" | "portal" | "bad_email" | "duplicate";

export type PreviewRow = {
  line: number;
  name: string;
  email: string;
  jobTitle: string | null;
  reason: PreviewReason;
  /** on_team: their user id; invited: the invitation id (both open /users/[id]). */
  existingId?: string;
};

export type PastedRow = { line: number; name: string; email: string; jobTitle: string | null };

/**
 * What would happen to each pasted person (read only): ready to invite, or
 * why not — already on the team or invited (with their page), another
 * organisation's or a portal account, not an email, or a repeat.
 */
export async function previewInviteRows(
  db: Db | Tx,
  organisationId: string,
  rows: readonly PastedRow[],
): Promise<PreviewRow[]> {
  const emails = [...new Set(rows.map((r) => r.email.trim().toLowerCase()).filter(looksLikeEmail))];
  const [accounts, invites, grants] = emails.length
    ? await Promise.all([
        db
          .select({ id: users.id, email: users.email, organisationId: memberships.organisationId })
          .from(users)
          .leftJoin(memberships, eq(memberships.userId, users.id))
          .where(inArray(sql`lower(${users.email})`, emails)),
        db
          .select({ id: staffInvites.id, email: staffInvites.invitedEmail })
          .from(staffInvites)
          .where(
            and(
              eq(staffInvites.organisationId, organisationId),
              inArray(staffInvites.invitedEmail, emails),
              isNull(staffInvites.acceptedAt),
              isNull(staffInvites.revokedAt),
            ),
          ),
        db
          .select({ email: externalGrants.invitedEmail, userId: externalGrants.userId })
          .from(externalGrants)
          // Live partner access only, as assertEmailFree: ended and revoked don't block.
          .where(and(inArray(externalGrants.invitedEmail, emails), liveGrantSql())),
      ])
    : [[], [], []];
  const seen = new Set<string>();
  return rows.map((r): PreviewRow => {
    const email = r.email.trim().toLowerCase();
    const base = { line: r.line, name: r.name.trim(), email, jobTitle: r.jobTitle };
    if (!looksLikeEmail(email)) return { ...base, reason: "bad_email" };
    if (seen.has(email)) return { ...base, reason: "duplicate" };
    seen.add(email);
    const account = accounts.filter((a) => a.email.toLowerCase() === email);
    const here = account.find((a) => a.organisationId === organisationId);
    if (here) return { ...base, reason: "on_team", existingId: here.id };
    if (account.some((a) => a.organisationId)) return { ...base, reason: "other_org" };
    const accountIds = new Set(account.map((a) => a.id));
    if (grants.some((g) => g.email.toLowerCase() === email || accountIds.has(g.userId ?? ""))) {
      return { ...base, reason: "portal" };
    }
    const invite = invites.find((i) => i.email === email);
    if (invite) return { ...base, reason: "invited", existingId: invite.id };
    return { ...base, reason: "ready" };
  });
}

export type InviteRowResult = PreviewRow & {
  ok: boolean;
  /** Why it wasn't invited, in words (refusals from the rules included). */
  error?: string;
  inviteId?: string;
  inviteUrl?: string;
};

/** The settings every pasted person gets. */
export type SharedPersonInput = Omit<PersonInput, "fullName" | "jobTitle" | "signoffs"> & {
  jobTitle?: string | null;
};

/**
 * Invite several people with the same settings: each ready row in its own
 * savepoint through inviteUserTx (so one refusal doesn't undo the others),
 * the others left out with their reason. The caller sends the emails after
 * the transaction commits.
 */
export async function inviteRowsTx(
  tx: Tx,
  ctx: Ctx,
  rows: readonly PastedRow[],
  shared: SharedPersonInput,
): Promise<{ results: InviteRowResult[]; departmentName: string | null }> {
  // Once, before the loop (inviteUserTx takes it again: re-entrant).
  await lockPeople(tx, ctx.organisationId);
  const preview = await previewInviteRows(tx, ctx.organisationId, rows);
  const ready = preview.filter((r) => r.reason === "ready").length;
  if (ready > MAX_PASTED_PEOPLE) {
    throw new UserError(`Invite up to ${MAX_PASTED_PEOPLE} people at a time — split the list`);
  }
  const results: InviteRowResult[] = [];
  let departmentName: string | null = null;
  for (const row of preview) {
    if (row.reason !== "ready") {
      results.push({ ...row, ok: false });
      continue;
    }
    try {
      const out = await tx.transaction((sp) =>
        inviteUserTx(sp, ctx, {
          ...shared,
          email: row.email,
          fullName: row.name || row.email,
          jobTitle: row.jobTitle ?? shared.jobTitle ?? null,
          signoffs: [],
          managerScope: null,
        }),
      );
      departmentName = out.departmentName;
      results.push({ ...row, ok: true, inviteId: out.inviteId, inviteUrl: out.inviteUrl });
    } catch (err) {
      if (!(err instanceof UserError)) throw err;
      results.push({ ...row, ok: false, error: err.message });
    }
  }
  return { results, departmentName };
}

// ---------------------------------------------------------------------------
// The same change for several people (the list's bulk bar).
// ---------------------------------------------------------------------------

export type BulkPeopleAction = "resend" | "suspend" | "reactivate" | "end_date" | "cancel";

export type BulkPeopleRow = {
  id: string;
  name: string;
  ok: boolean;
  /** Why it was left alone, in a few words. */
  reason?: string;
  /** Resend: the new link, for the caller to send. */
  inviteUrl?: string;
  invite?: { email: string; name: string; role: StaffRole };
};

/**
 * Resend, suspend, reactivate, set an end date or cancel for several people
 * (user ids and invitation ids). Each runs in its own transaction through
 * the same function as on their page, so the same checks and audit rows
 * apply; refusals come back as reasons. Suspending uses each department's
 * default hand-over (its main approver or another approver), so people
 * whose sign-offs have nobody to go to are left for their own page.
 */
export async function bulkPeople(
  db: Db,
  ctx: Ctx & { actorName: string },
  input: { ids: readonly string[]; action: BulkPeopleAction; date?: string | null },
): Promise<BulkPeopleRow[]> {
  const orgId = ctx.organisationId;
  const ids = [...new Set(input.ids)];
  if (ids.length === 0) return [];
  const [members, invites] = await Promise.all([
    db
      .select({ id: users.id, name: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .where(and(eq(memberships.organisationId, orgId), inArray(memberships.userId, ids))),
    db
      .select({
        id: staffInvites.id,
        name: staffInvites.fullName,
        email: staffInvites.invitedEmail,
        role: staffInvites.role,
      })
      .from(staffInvites)
      .where(
        and(
          eq(staffInvites.organisationId, orgId),
          inArray(staffInvites.id, ids),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      ),
  ]);
  const rows: BulkPeopleRow[] = [];
  for (const id of ids) {
    const member = members.find((m) => m.id === id);
    const invite = invites.find((i) => i.id === id);
    if (!member && !invite) {
      rows.push({ id, name: "Someone", ok: false, reason: "No longer on the list — reload" });
      continue;
    }
    const name = member ? member.name || member.email : invite!.name || invite!.email;
    try {
      switch (input.action) {
        case "resend": {
          if (!invite) throw new UserError("Already on the team");
          const { inviteUrl } = await db.transaction((tx) => renewInviteLinkTx(tx, ctx, id));
          rows.push({
            id,
            name,
            ok: true,
            inviteUrl,
            invite: { email: invite.email, name: invite.name, role: invite.role },
          });
          continue;
        }
        case "cancel":
          if (!invite) throw new UserError("Not an invitation — they're on the team");
          await db.transaction((tx) => cancelInviteTx(tx, ctx, id));
          break;
        case "end_date":
          await db.transaction((tx) =>
            setAccessEndTx(
              tx,
              ctx,
              member
                ? { userId: id, date: input.date ?? null }
                : { inviteId: id, date: input.date ?? null },
            ),
          );
          break;
        case "suspend":
          if (!member) throw new UserError("Not on the team yet — cancel the invitation instead");
          await db.transaction((tx) => suspendMemberTx(tx, ctx, { userId: id }));
          break;
        case "reactivate":
          if (!member) throw new UserError("Not on the team yet");
          await db.transaction((tx) => reactivateMemberTx(tx, ctx, { userId: id }));
          break;
      }
      rows.push({ id, name, ok: true });
    } catch (err) {
      if (!(err instanceof UserError)) throw err;
      rows.push({ id, name, ok: false, reason: err.message });
    }
  }
  return rows;
}
