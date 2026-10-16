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
  canSuspendPerson,
  parseFeatures,
  personChangeRefusal,
  signoffPaused,
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
import {
  departmentIdsForUser,
  departmentSignerIds,
  syncDepartmentSteps,
} from "@/lib/domain/departments";
import { applyDelegation } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { notify } from "@/lib/notify";
import { activeMembership } from "./active";
import {
  normaliseFeatures,
  overridesFor,
  signoffChanges,
  type AbilityChoices,
  type Signoff,
} from "./rules";
import { externalAccountLabel } from "./external";
import {
  canWorkOwnItem,
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
 * `exceptUserId` still has access — so two super admins can't demote,
 * suspend or remove each other at the same moment and leave nobody.
 */
async function anotherActiveSuperAdmin(
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
  return rows.some((r) => r.userId !== exceptUserId && accessLive(r));
}

const LAST_ADMIN = "There must always be at least one super admin with access";

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

/** Departments this person signs off for now. */
export async function currentSignoffs(
  db: Db | Tx,
  organisationId: string,
  person: Pick<Person, "userId" | "email">,
): Promise<Signoff[]> {
  const rows = await db
    .select({ departmentId: approvers.departmentId, isMain: approvers.isMain })
    .from(approvers)
    .where(personRows(organisationId, person));
  const seen = new Map<string, boolean>();
  for (const r of rows) seen.set(r.departmentId, (seen.get(r.departmentId) ?? false) || r.isMain);
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
 * Make the person an approver for exactly these departments. New ones must
 * be live departments that sign off; ones they already have are kept even
 * if since archived. One main approver per department. Someone only
 * invited never takes "main approver" from a main who can sign now: they
 * join as an approver and the current main stays (`mainKept`), so nobody
 * is demoted for an invitation that may never be accepted. Returns whether
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
  mainKept: { departmentId: string; name: string }[];
}> {
  // Approver rows keep emails in lower case.
  person = { ...person, email: person.email.toLowerCase() };
  const unique = [...new Map(desired.map((s) => [s.departmentId, s.isMain])).entries()].map(
    ([departmentId, isMain]) => ({ departmentId, isMain }),
  );
  const mainKept: { departmentId: string; name: string }[] = [];
  if (!person.userId) {
    for (const s of unique.filter((x) => x.isMain)) {
      const current = await otherMain(tx, ctx.organisationId, s.departmentId, person.email);
      if (current?.canSign) {
        s.isMain = false;
        mainKept.push({ departmentId: s.departmentId, name: current.name });
      }
    }
  }
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
  // One main approver per department (a unique index): clear the others
  // before this person becomes main.
  for (const s of unique.filter((x) => x.isMain)) {
    await tx
      .update(approvers)
      .set({ isMain: false })
      .where(
        and(
          eq(approvers.organisationId, ctx.organisationId),
          eq(approvers.departmentId, s.departmentId),
          ne(approvers.email, person.email),
        ),
      );
  }
  const where = personRows(ctx.organisationId, person);
  if (changes.remove.length > 0) {
    await tx.delete(approvers).where(and(where, inArray(approvers.departmentId, changes.remove)));
  }
  for (const a of changes.add) {
    await tx
      .insert(approvers)
      .values({
        organisationId: ctx.organisationId,
        departmentId: a.departmentId,
        fullName: person.fullName || person.email,
        jobTitle: person.jobTitle,
        email: person.email,
        userId: person.userId,
        isMain: a.isMain,
      })
      .onConflictDoUpdate({
        target: [approvers.departmentId, approvers.email],
        set: { userId: person.userId, isMain: a.isMain, fullName: person.fullName || person.email },
      });
  }
  for (const u of changes.update) {
    await tx
      .update(approvers)
      .set({ isMain: u.isMain })
      .where(and(where, eq(approvers.departmentId, u.departmentId)));
  }
  // Keep their name on the approver list in step with their profile.
  if (unique.length > 0) {
    await tx
      .update(approvers)
      .set({ fullName: person.fullName || person.email, jobTitle: person.jobTitle })
      .where(where);
  }
  const changed = changes.add.length + changes.remove.length + changes.update.length > 0;
  return { changed, before, after: unique, removed: changes.remove, mainKept };
}

/** An invitation nobody has accepted or cancelled for this email, expired or not. */
async function openInviteFor(db: Db | Tx, organisationId: string, email: string) {
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
  const grants = await tx
    .select()
    .from(externalGrants)
    .where(
      and(
        user
          ? or(eq(externalGrants.userId, user.id), eq(externalGrants.invitedEmail, email))
          : eq(externalGrants.invitedEmail, email),
        isNull(externalGrants.revokedAt),
      ),
    )
    .limit(1);
  if (grants.length > 0) {
    const label = grants[0] ? await externalAccountLabel(tx, ctx.organisationId, grants[0]) : null;
    throw new UserError(
      `This email is used by an external portal account${label ? ` (${label})` : ""}. Use a different email.`,
    );
  }
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

function cleanText(value: string | null | undefined): string | null {
  const v = value?.trim();
  return v ? v : null;
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
  mainKept: { departmentId: string; name: string }[];
}> {
  const actor = await loadActor(tx, ctx);
  const email = input.email.trim().toLowerCase();
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  const overrides = overridesFor(input.role, input.abilities);
  const managerScope = input.role === "admin" ? null : (input.managerScope ?? null);
  const accessEndsAt = accessEndFromInput(input.accessEndsOn) ?? null;
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
    }),
  );
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
      after: { email, signsOffFor: signoff.after, mainKept: signoff.mainKept },
      summary: `${fullName || email} will sign off artwork once they accept`,
      subjectEmail: email,
    });
    await syncDepartmentSteps(tx, ctx.organisationId);
  }
  return { ...invite, departmentName: dept?.name ?? null, mainKept: signoff.mainKept };
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
  input: PersonInput & { userId: string; signoffPaused: boolean },
): Promise<{ name: string; changed: string[]; signoffsMoved: number; signoffsKept: number }> {
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
    }),
  );
  if (input.role === "viewer" && input.signoffs.length > 0) throw new UserError(VIEWER_SIGNOFF);
  const losesAdmin = membership.role === "admin" && input.role !== "admin";
  const adminGetsEnd =
    membership.role === "admin" && input.role === "admin" && accessEndsAt != null;
  if (
    (losesAdmin || adminGetsEnd) &&
    !(await anotherActiveSuperAdmin(tx, ctx.organisationId, user.id))
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
    })
    .where(eq(memberships.id, membership.id));
  // Main approver routing skips people who can't sign: re-sync when that changes.
  const wasPaused = signoffPaused(membership.permissionOverrides as PermissionOverrides);
  const pausedChanged = wasPaused !== input.signoffPaused;
  const roleSignChange = (membership.role === "viewer") !== (input.role === "viewer");
  if (signoff.changed || pausedChanged || roleSignChange) {
    await syncDepartmentSteps(tx, ctx.organisationId);
  }

  // Sign-offs naming them that they no longer sign for: back to the department.
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
  };
  const changed = (Object.keys(beforeRow) as (keyof typeof beforeRow)[]).filter((k) =>
    k === "signsOffFor" ? signoff.changed : stable(beforeRow[k]) !== stable(afterRow[k]),
  );
  if (changed.length > 0) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "membership",
      entityId: membership.id,
      action: "settings_change",
      before: beforeRow,
      after: { ...afterRow, signoffsHandedBack: handed.moved },
      summary: `${user.email}: ${changed.join(", ")} changed`,
      subjectUserId: user.id,
      subjectEmail: user.email,
    });
  }
  return {
    name: fullName || user.fullName || user.email,
    changed,
    signoffsMoved: handed.moved,
    signoffsKept: handed.kept,
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
): Promise<{ name: string; mainKept: { departmentId: string; name: string }[] }> {
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
      },
    ),
  );
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
  return { name: fullName || invite.invitedEmail, mainKept: signoff.mainKept };
}

/**
 * Cancel an invitation: the link stops working, and the sign-offs it was
 * going to give them go back to the department.
 */
export async function cancelInviteTx(tx: Tx, ctx: Ctx, inviteId: string): Promise<string> {
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
    .returning({ id: approvers.id });
  if (dropped.length > 0) await syncDepartmentSteps(tx, ctx.organisationId);
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "staff_invite",
    entityId: invite.id,
    action: "grant_revoke",
    before: { email: invite.invitedEmail, approverRows: dropped.length },
    summary: `Cancelled the invitation for ${invite.invitedEmail}`,
    subjectEmail: invite.invitedEmail,
  });
  return invite.fullName || invite.invitedEmail;
}

/**
 * A fresh link for an open (or expired) invitation, valid for another
 * STAFF_INVITE_DAYS. The earlier link stops working: links are stored only
 * as hashes, so the old one can't be shown again.
 */
export async function renewInviteLinkTx(
  tx: Tx,
  ctx: Ctx,
  inviteId: string,
): Promise<{ invite: OpenInvite; inviteUrl: string; expiresAt: Date }> {
  const { invite } = await managedInvite(tx, ctx, inviteId);
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
  opts: { departmentIds?: readonly string[] | null } = {},
): Promise<(HandoverStep & { editionId: string })[]> {
  if (opts.departmentIds && opts.departmentIds.length === 0) return [];
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
          eq(approvalInstances.assignedUserId, userId),
          live,
          dept,
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
          eq(approvalInstances.assignedUserId, userId),
          live,
          dept,
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
async function departmentSigners(
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
      { userId: r.userId!, name: r.name || r.email, isMain: r.isMain },
    ]);
  }
  return { names: new Map(depts.map((d) => [d.id, d.name])), signers };
}

export type HandoverCandidate = {
  userId: string;
  name: string;
  role: StaffRole;
  departmentId: string | null;
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
    }));
}

/** What the Suspend and Remove dialogs offer for someone's sign-offs. */
export type HandoverPlan = { groups: HandoverGroup[]; candidates: HandoverCandidate[] };

/** The sign-offs naming someone, grouped by department, with who could take each group. */
export async function handoverPlan(
  db: Db | Tx,
  organisationId: string,
  userId: string,
): Promise<HandoverPlan> {
  const [steps, { names, signers }, candidates] = await Promise.all([
    signoffsNaming(db, organisationId, userId),
    departmentSigners(db, organisationId, userId),
    handoverCandidates(db, organisationId, userId),
  ]);
  return {
    groups: handoverGroups(steps, { departmentNames: names, signers }),
    candidates,
  };
}

/** Items someone still works on: not deleted or complete, in an event being planned or live. */
function workableItem(): SQL {
  return and(
    isNull(signageItems.deletedAt),
    ne(signageItems.status, "closed"),
    inArray(editions.status, ["planning", "live"]),
  )!;
}

/** The items they own that are still being worked on (the same count everywhere). */
export async function workableOwnedItems(db: Db | Tx, organisationId: string, userId: string) {
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

/** Who can be handed someone's items and tasks: people with access who aren't viewers. */
export type WorkCandidate = {
  userId: string;
  name: string;
  role: StaffRole;
  features: Feature[] | null;
  overrides: PermissionOverrides;
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
    })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
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
};

/** What removing (or suspending) someone would change, for the confirm dialogs. */
export async function getRemovalImpact(
  db: Db | Tx,
  organisationId: string,
  userId: string,
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
    handoverPlan(db, organisationId, userId),
    stepsNaming(db, organisationId, userId),
    db
      .select({ departmentId: approvers.departmentId, isMain: approvers.isMain, dept: departments })
      .from(approvers)
      .innerJoin(departments, eq(departments.id, approvers.departmentId))
      .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId))),
    workCandidates(db, organisationId, userId),
    departmentSigners(db, organisationId, userId),
  ]);
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
      refs: [...new Set(steps.map((w) => w.ref))].slice(0, 5),
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
  };
}

/**
 * Point the item plans (each item's chosen sign-off people for the next
 * round) that name this person back at the department. `stepIds` limits it
 * to some departments' steps; null = all of them.
 */
async function clearPlanEntries(
  tx: Tx,
  organisationId: string,
  userId: string,
  stepIds: readonly string[] | null,
): Promise<void> {
  if (stepIds && stepIds.length === 0) return;
  const only = stepIds
    ? sql`AND s->>'stepId' = ANY(string_to_array(${stepIds.join(",")}, ','))`
    : sql``;
  await tx.execute(sql`
    UPDATE signage_items SET signoffs = (
      SELECT jsonb_agg(
        CASE WHEN s->>'userId' = ${userId} ${only} THEN s || '{"userId": null}'::jsonb ELSE s END
      ) FROM jsonb_array_elements(signoffs) AS s
    )
    WHERE signoffs @> ${JSON.stringify([{ userId }])}::jsonb
      AND edition_id IN (
        SELECT ed.id FROM editions ed JOIN events ev ON ev.id = ed.event_id
        WHERE ev.organisation_id = ${organisationId}
      )
  `);
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
  ctx: Ctx,
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
  const told = new Map<string, string[]>();
  const backToDept = new Map<string, { name: string; refs: string[] }>();
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
          if (target) told.set(target, [...(told.get(target) ?? []), s.ref]);
          else if (g.departmentId) {
            const entry = backToDept.get(g.departmentId) ?? {
              name: g.departmentName ?? "the department",
              refs: [],
            };
            entry.refs.push(s.ref);
            backToDept.set(g.departmentId, entry);
          }
        }
        moved++;
      }
      await writeAudit(tx, {
        organisationId: orgId,
        editionId: opts.editionOf.get(first.id) ?? null,
        actorUserId: ctx.actorUserId,
        entityType: first.entityType,
        entityId,
        action: "delegate",
        before: { assignedUserId: opts.userId },
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
  for (const [userId, refs] of told) {
    await notify(tx, {
      userIds: [userId],
      kind: "delegation",
      title:
        refs.length === 1
          ? `A sign-off is now yours: ${refs[0]}`
          : `${refs.length} sign-offs are now yours`,
      body: `${opts.who} ${opts.why}; ${by} their sign-offs to you.`,
      link: "/approvals",
    });
  }
  for (const [departmentId, { name, refs }] of backToDept) {
    await notify(tx, {
      userIds: (await departmentSignerIds(tx, orgId, departmentId)).filter(
        (id) => id !== opts.userId,
      ),
      kind: "delegation",
      title:
        refs.length === 1
          ? `A ${name} sign-off is back with your department: ${refs[0]}`
          : `${refs.length} ${name} sign-offs are back with your department`,
      body: `${opts.who} ${opts.why}, so anyone who signs off for ${name} can decide.`,
      link: "/approvals",
    });
  }
  return moved;
}

/**
 * Hand over every sign-off naming someone who is being suspended or
 * removed: each department's to the person picked for it (by default its
 * main approver, else another approver who can sign), or back to the
 * department. Refused when a group has nobody to go to. Their item plans
 * stop naming them too.
 */
async function handOverSignoffsTx(
  tx: Tx,
  ctx: Ctx,
  opts: {
    userId: string;
    who: string;
    why: string;
    choice?: HandoverChoice | null;
    fallback?: string | null;
  },
): Promise<number> {
  const orgId = ctx.organisationId;
  const steps = await signoffsNaming(tx, orgId, opts.userId);
  await clearPlanEntries(tx, orgId, opts.userId, null);
  if (steps.length === 0) return 0;
  const [{ names, signers }, candidates] = await Promise.all([
    departmentSigners(tx, orgId, opts.userId),
    handoverCandidates(tx, orgId, opts.userId),
  ]);
  const groups = handoverGroups(steps, { departmentNames: names, signers });
  const ok = new Set(candidates.map((c) => c.userId));
  const res = resolveHandover(groups, opts.choice, {
    personId: opts.userId,
    who: opts.who,
    canReceive: (id) => ok.has(id),
    fallback: opts.fallback,
  });
  if (!res.ok) throw new UserError(res.error);
  return moveSignoffs(tx, ctx, {
    ...opts,
    groups,
    targets: res.targets,
    editionOf: new Map(steps.map((s) => [s.id, s.editionId])),
  });
}

/**
 * Someone stops signing for some departments (taken off the approvers,
 * moved, made a viewer or paused): sign-offs naming them for those
 * departments go back to the department when someone else there can sign;
 * the rest stay with them (named, so they can still be handed on from the
 * item). Their item plans for those departments name nobody. Used by the
 * person page and Users → Departments.
 */
export async function stopSigningTx(
  tx: Tx,
  ctx: Ctx,
  opts: { userId: string; who: string; why: string; departmentIds: string[] | null },
): Promise<{ moved: number; kept: number }> {
  const orgId = ctx.organisationId;
  const stepIds = opts.departmentIds
    ? await departmentStepIds(tx, orgId, opts.departmentIds)
    : null;
  await clearPlanEntries(tx, orgId, opts.userId, stepIds);
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

/** The membership and user for someone on the team, or a refusal. */
async function loadMember(tx: Tx, ctx: Ctx, userId: string) {
  const membership = await tx.query.memberships.findFirst({
    where: and(eq(memberships.userId, userId), eq(memberships.organisationId, ctx.organisationId)),
  });
  if (!membership) throw new UserError("This person isn't on the team any more — reload the page");
  const user = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
  return { membership, user, who: user?.fullName || user?.email || "This person" };
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
}> {
  const orgId = ctx.organisationId;
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
    !(await anotherActiveSuperAdmin(tx, orgId, membership.userId))
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
  let workAccess: { role: StaffRole; features: Feature[] | null; overrides: PermissionOverrides };
  let workToName = ctx.actorName;
  if (workTo === ctx.actorUserId) {
    workAccess = { role: actor.role, features: actor.features ?? null, overrides: {} };
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
    userId: membership.userId,
    who,
    why: "left the team",
    choice: input.handTo,
    fallback: input.handToUserId,
  });

  // Open tasks (subtasks included), one audit row each.
  const movedTasks = await tx
    .update(tasks)
    .set({ assignedToUserId: workTo })
    .where(
      and(
        eq(tasks.organisationId, orgId),
        eq(tasks.assignedToUserId, membership.userId),
        ne(tasks.status, "done"),
      ),
    )
    .returning({ id: tasks.id, title: tasks.title, editionId: tasks.editionId });
  for (const t of movedTasks) {
    await writeAudit(tx, {
      organisationId: orgId,
      editionId: t.editionId,
      actorUserId: ctx.actorUserId,
      entityType: "task",
      entityId: t.id,
      action: "update",
      before: { assignedToUserId: membership.userId },
      after: { assignedToUserId: workTo },
      summary: `Task “${t.title}” moved to ${workToName} after ${who} left the team`,
      subjectUserId: membership.userId,
    });
  }
  if (movedTasks.length > 0 && workTo !== ctx.actorUserId) {
    await notify(tx, {
      userIds: [workTo],
      kind: "task_assigned",
      title:
        movedTasks.length === 1
          ? `A task is now yours: ${movedTasks[0].title}`
          : `${movedTasks.length} tasks are now yours`,
      body: `${who} left the team; ${ctx.actorName} gave you their open tasks.`,
      link: "/my-work",
    });
  }

  // Items still being worked on; finished ones and archived events keep their owner.
  const owned = await workableOwnedItems(tx, orgId, membership.userId);
  let itemsToYou = 0;
  const toWorker: string[] = [];
  for (const it of owned) {
    const to = canWorkOwnItem(workAccess, it.kind) ? workTo : ctx.actorUserId;
    if (to === ctx.actorUserId && workTo !== ctx.actorUserId) itemsToYou++;
    if (to === workTo && workTo !== ctx.actorUserId) toWorker.push(it.ref);
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
      signoffsHandedOver: handedOver,
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
    !(await anotherActiveSuperAdmin(tx, ctx.organisationId, membership.userId));
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
          .where(
            and(inArray(externalGrants.invitedEmail, emails), isNull(externalGrants.revokedAt)),
          ),
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
