import "server-only";
/**
 * The database side of Users: invite, edit and remove people, and the
 * departments they sign off for. Each function runs inside the caller's
 * transaction and writes its own audit rows; app/actions/users.ts does the
 * parsing, authorisation and revalidation around them. Messages thrown as
 * UserError are safe to show.
 */
import { and, asc, count, eq, inArray, isNull, max, ne, or, sql } from "drizzle-orm";
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
import type { Feature, StaffRole } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { appUrl } from "@/lib/app-url";
import { roleLabel } from "@/lib/format";
import { createStaffInvite, STAFF_INVITE_DAYS } from "@/lib/auth/staff-invite";
import { generateInviteToken, hashInviteToken } from "@/lib/auth/invite-token";
import { syncDepartmentSteps } from "@/lib/domain/departments";
import { applyDelegation } from "@/lib/workflow";
import { loadRun, persistRun } from "@/lib/workflow/persist";
import { notify } from "@/lib/notify";
import {
  normaliseFeatures,
  overridesFor,
  signoffChanges,
  type Abilities,
  type Signoff,
} from "./rules";
import { externalAccountLabel } from "./external";

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

export type Ctx = { organisationId: string; actorUserId: string };

/** What the Add user form and the person page both send. */
export type PersonInput = {
  fullName: string;
  jobTitle: string | null;
  departmentId: string | null;
  /** "+ New department…": created as a team with no sign-off step. */
  newDepartmentName?: string | null;
  role: StaffRole;
  /** Null = every section. */
  features: Feature[] | null;
  abilities: Partial<Abilities>;
  /** Departments they sign off for. */
  signoffs: Signoff[];
};

type DepartmentRow = typeof departments.$inferSelect;

const DAY = 24 * 60 * 60 * 1000;

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

/**
 * Make the person an approver for exactly these departments. New ones must
 * be live departments that sign off; ones they already have are kept even
 * if since archived. One main approver per department. Returns whether
 * anything changed (the caller then syncs the sign-off steps).
 */
export async function setSignoffs(
  tx: Tx,
  ctx: Ctx,
  person: Person,
  desired: Signoff[],
): Promise<{ changed: boolean; before: Signoff[]; after: Signoff[] }> {
  // Approver rows keep emails in lower case.
  person = { ...person, email: person.email.toLowerCase() };
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
  // One main approver per department.
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
  // Keep their name on the approver list in step with their profile.
  if (unique.length > 0) {
    await tx
      .update(approvers)
      .set({ fullName: person.fullName || person.email, jobTitle: person.jobTitle })
      .where(where);
  }
  const changed = changes.add.length + changes.remove.length + changes.update.length > 0;
  return { changed, before, after: unique };
}

/** Refuse emails already in use: a team member, another organisation, or a portal account. */
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
}

function cleanText(value: string | null | undefined): string | null {
  const v = value?.trim();
  return v ? v : null;
}

/**
 * Invite someone to the team with everything the form asked for: the
 * invitation carries their name, job title, department, role, sections and
 * abilities; sign-off rows wait (user id empty) until they accept.
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
}> {
  const email = input.email.trim().toLowerCase();
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  await assertEmailFree(tx, ctx, email);
  const dept = await resolveDepartment(tx, ctx, input);
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  const overrides = overridesFor(input.role, input.abilities);
  const invite = await createStaffInvite(tx, {
    organisationId: ctx.organisationId,
    email,
    role: input.role,
    overrides,
    fullName,
    jobTitle,
    departmentId: dept?.id ?? null,
    features,
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
      after: { email, signsOffFor: signoff.after },
      summary: `${fullName || email} will sign off artwork once they accept`,
    });
    await syncDepartmentSteps(tx, ctx.organisationId);
  }
  return { ...invite, departmentName: dept?.name ?? null };
}

/** Change a team member: details, department, role, sections, sign-off and abilities. */
export async function updateMemberTx(
  tx: Tx,
  ctx: Ctx,
  input: PersonInput & { userId: string; signoffPaused: boolean },
): Promise<{ name: string; changed: string[] }> {
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
    throw new UserError("You can't change your own role — ask another admin");
  }
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  if (isSelf && input.role !== "admin") {
    const mine = normaliseFeatures(membership.features);
    if (JSON.stringify(mine) !== JSON.stringify(features)) {
      throw new UserError("You can't change your own sections — ask another admin");
    }
  }
  if (membership.role === "admin" && input.role !== "admin") {
    const [admins] = await tx
      .select({ n: count() })
      .from(memberships)
      .where(
        and(eq(memberships.organisationId, ctx.organisationId), eq(memberships.role, "admin")),
      );
    if (Number(admins.n) <= 1) throw new UserError("There must always be at least one admin");
  }
  const dept = await resolveDepartment(tx, ctx, input, membership.departmentId);
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  const overrides = overridesFor(input.role, input.abilities, {
    signoffPaused: input.signoffPaused,
  });

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
    })
    .where(eq(memberships.id, membership.id));
  if (signoff.changed) await syncDepartmentSteps(tx, ctx.organisationId);

  const before = {
    fullName: user.fullName,
    jobTitle: membership.jobTitle,
    departmentId: membership.departmentId,
    role: membership.role,
    features: normaliseFeatures(membership.features),
    overrides: membership.permissionOverrides,
    signsOffFor: signoff.before,
  };
  const after = {
    fullName: fullName || user.fullName,
    jobTitle,
    departmentId: dept?.id ?? null,
    role: input.role,
    features,
    overrides,
    signsOffFor: signoff.after,
  };
  const changed = (Object.keys(before) as (keyof typeof before)[]).filter((k) =>
    k === "signsOffFor" ? signoff.changed : JSON.stringify(before[k]) !== JSON.stringify(after[k]),
  );
  if (changed.length > 0) {
    await writeAudit(tx, {
      organisationId: ctx.organisationId,
      actorUserId: ctx.actorUserId,
      entityType: "membership",
      entityId: membership.id,
      action: "settings_change",
      before,
      after,
      summary: `${user.email}: ${changed.join(", ")} changed`,
    });
  }
  return { name: fullName || user.fullName || user.email, changed };
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

/** Change what an invitation will give someone before they accept it. */
export async function updateInviteTx(
  tx: Tx,
  ctx: Ctx,
  input: PersonInput & { inviteId: string },
): Promise<{ name: string }> {
  const invite = await openInvite(tx, ctx, input.inviteId);
  const dept = await resolveDepartment(tx, ctx, input, invite.departmentId);
  const fullName = input.fullName.trim();
  const jobTitle = cleanText(input.jobTitle);
  const features = input.role === "admin" ? null : normaliseFeatures(input.features);
  const overrides = overridesFor(input.role, input.abilities);
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
    })
    .where(eq(staffInvites.id, invite.id));
  if (signoff.changed) await syncDepartmentSteps(tx, ctx.organisationId);
  await writeAudit(tx, {
    organisationId: ctx.organisationId,
    actorUserId: ctx.actorUserId,
    entityType: "staff_invite",
    entityId: invite.id,
    action: "settings_change",
    before: {
      fullName: invite.fullName,
      jobTitle: invite.jobTitle,
      role: invite.role,
      departmentId: invite.departmentId,
      features: invite.features,
      overrides: invite.permissionOverrides,
      signsOffFor: signoff.before,
    },
    after: {
      fullName,
      jobTitle,
      role: input.role,
      departmentId: dept?.id ?? null,
      features,
      overrides,
      signsOffFor: signoff.after,
    },
    summary: `Invitation for ${invite.invitedEmail} changed`,
  });
  return { name: fullName || invite.invitedEmail };
}

/**
 * Cancel an invitation: the link stops working, and the sign-offs it was
 * going to give them go back to the department.
 */
export async function cancelInviteTx(tx: Tx, ctx: Ctx, inviteId: string): Promise<string> {
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
  const invite = await openInvite(tx, ctx, inviteId);
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

/** Sign-offs waiting on this person by name, in this organisation. */
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

/** People who can take over sign-offs: anyone on the team except viewers. */
export async function handoverCandidates(db: Db | Tx, organisationId: string, exceptId: string) {
  const rows = await db
    .select({ userId: users.id, name: users.fullName, email: users.email, role: memberships.role })
    .from(memberships)
    .innerJoin(users, eq(users.id, memberships.userId))
    .where(
      and(
        eq(memberships.organisationId, organisationId),
        ne(memberships.role, "viewer"),
        ne(memberships.userId, exceptId),
      ),
    )
    .orderBy(asc(users.fullName));
  return rows.map((r) => ({ userId: r.userId, name: r.name || r.email, role: r.role }));
}

export type RemovalImpact = {
  name: string;
  openTasks: number;
  ownedItems: number;
  waiting: { count: number; refs: string[] };
  departments: { id: string; name: string; isMain: boolean; others: string[] }[];
  /** Workflow steps that name them; these must be changed first. */
  namedSteps: string[];
  candidates: { userId: string; name: string; role: StaffRole }[];
};

/** What removing someone would change, for the confirm dialog. */
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
  const [[tasksOpen], [items], waiting, named, mine, candidates] = await Promise.all([
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
    db
      .select({ n: count() })
      .from(signageItems)
      .innerJoin(editions, eq(signageItems.editionId, editions.id))
      .innerJoin(events, eq(editions.eventId, events.id))
      .where(
        and(
          eq(events.organisationId, organisationId),
          eq(signageItems.ownerUserId, userId),
          isNull(signageItems.deletedAt),
        ),
      ),
    signoffsWaitingOn(db, organisationId, userId),
    stepsNaming(db, organisationId, userId),
    db
      .select({ departmentId: approvers.departmentId, isMain: approvers.isMain, dept: departments })
      .from(approvers)
      .innerJoin(departments, eq(departments.id, approvers.departmentId))
      .where(and(eq(approvers.organisationId, organisationId), eq(approvers.userId, userId))),
    handoverCandidates(db, organisationId, userId),
  ]);
  const live = mine.filter((m) => !m.dept.isArchived && m.dept.signsOff);
  const others = live.length
    ? await db
        .select({ departmentId: approvers.departmentId, name: approvers.fullName })
        .from(approvers)
        .innerJoin(
          memberships,
          and(
            eq(memberships.userId, approvers.userId),
            eq(memberships.organisationId, approvers.organisationId),
          ),
        )
        .where(
          and(
            eq(approvers.organisationId, organisationId),
            inArray(
              approvers.departmentId,
              live.map((m) => m.departmentId),
            ),
            ne(approvers.userId, userId),
          ),
        )
    : [];
  return {
    name: row.user.fullName || row.user.email,
    openTasks: Number(tasksOpen.n),
    ownedItems: Number(items.n),
    waiting: { count: waiting.length, refs: [...new Set(waiting.map((w) => w.ref))].slice(0, 5) },
    departments: live.map((m) => ({
      id: m.departmentId,
      name: m.dept.name,
      isMain: m.isMain,
      others: others.filter((o) => o.departmentId === m.departmentId).map((o) => o.name),
    })),
    namedSteps: named.map((n) => `“${n.step}” (${n.workflow})`),
    candidates,
  };
}

/**
 * Remove someone who has left. Sign-offs waiting on them go to the person
 * picked; their open tasks and items move to the admin removing them; they
 * stop being an approver, so each department's step falls back to its next
 * main approver or the whole department. Refused only while a workflow step
 * names them directly (outside the departments).
 */
export async function removeMemberTx(
  tx: Tx,
  ctx: Ctx & { actorName: string },
  input: { userId: string; handToUserId?: string | null },
): Promise<{ name: string; items: number; tasks: number; handedOver: number }> {
  const orgId = ctx.organisationId;
  const membership = await tx.query.memberships.findFirst({
    where: and(eq(memberships.userId, input.userId), eq(memberships.organisationId, orgId)),
  });
  if (!membership) throw new UserError("This person isn't on the team any more — reload the page");
  if (membership.userId === ctx.actorUserId) {
    throw new UserError("You can't remove yourself — ask another admin");
  }
  if (membership.role === "admin") {
    const [admins] = await tx
      .select({ n: count() })
      .from(memberships)
      .where(and(eq(memberships.organisationId, orgId), eq(memberships.role, "admin")));
    if (Number(admins.n) <= 1) throw new UserError("There must always be at least one admin");
  }
  const member = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
  const who = member?.fullName || member?.email || "This person";

  const named = await stepsNaming(tx, orgId, membership.userId);
  if (named.length > 0) {
    throw new UserError(
      `${who} is the named approver for ${named.map((n) => `“${n.step}”`).join(", ")} — pick someone else in that workflow first`,
    );
  }

  // Sign-offs waiting on them by name go to the person picked.
  const waiting = await signoffsWaitingOn(tx, orgId, membership.userId);
  if (waiting.length > 0) {
    if (!input.handToUserId) {
      throw new UserError(
        `${waiting.length === 1 ? "A sign-off is" : `${waiting.length} sign-offs are`} waiting on ${who} — choose who takes ${waiting.length === 1 ? "it" : "them"} over`,
      );
    }
    const [target] = await tx
      .select({ role: memberships.role, name: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(users.id, memberships.userId))
      .where(and(eq(memberships.userId, input.handToUserId), eq(memberships.organisationId, orgId)))
      .limit(1);
    if (!target || target.role === "viewer" || input.handToUserId === membership.userId) {
      throw new UserError("Pick a team member who can sign off");
    }
    for (const w of waiting) {
      const run = await loadRun(tx, w.entityType, w.entityId, w.runNumber);
      const updated = applyDelegation(run, {
        instanceId: w.id,
        toUserId: input.handToUserId,
        fromUserId: membership.userId,
      });
      await persistRun(tx, w.entityType, w.entityId, updated);
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: ctx.actorUserId,
        entityType: w.entityType,
        entityId: w.entityId,
        action: "delegate",
        after: { step: w.stepName, fromUserId: membership.userId, toUserId: input.handToUserId },
        summary: `${w.ref}: ${w.stepName} handed to ${target.name || target.email} after ${who} left the team`,
      });
    }
    await notify(tx, {
      userIds: [input.handToUserId],
      kind: "delegation",
      title:
        waiting.length === 1
          ? `A sign-off is now yours: ${waiting[0].ref}`
          : `${waiting.length} sign-offs are now yours`,
      body: `${who} has left the team; ${ctx.actorName} handed their sign-offs to you.`,
      link: "/approvals",
    });
  }

  const movedTasks = await tx
    .update(tasks)
    .set({ assignedToUserId: ctx.actorUserId })
    .where(
      and(
        eq(tasks.organisationId, orgId),
        eq(tasks.assignedToUserId, membership.userId),
        ne(tasks.status, "done"),
      ),
    )
    .returning({ id: tasks.id });
  // Their items pass to the admin doing the removal, and any sign-off on an
  // item naming them personally falls back to the department.
  const owned = await tx
    .select({ id: signageItems.id, ref: signageItems.ref, editionId: signageItems.editionId })
    .from(signageItems)
    .innerJoin(editions, eq(signageItems.editionId, editions.id))
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(
      and(
        eq(events.organisationId, orgId),
        eq(signageItems.ownerUserId, membership.userId),
        isNull(signageItems.deletedAt),
      ),
    );
  for (const it of owned) {
    await tx
      .update(signageItems)
      .set({ ownerUserId: ctx.actorUserId })
      .where(eq(signageItems.id, it.id));
    await writeAudit(tx, {
      organisationId: orgId,
      editionId: it.editionId,
      actorUserId: ctx.actorUserId,
      entityType: "signage_item",
      entityId: it.id,
      action: "update",
      before: { ownerUserId: membership.userId },
      after: { ownerUserId: ctx.actorUserId },
      summary: `${it.ref}: owner reassigned after ${who} left the team`,
    });
  }
  await tx.execute(sql`
    UPDATE signage_items SET signoffs = (
      SELECT jsonb_agg(
        CASE WHEN s->>'userId' = ${membership.userId} THEN s || '{"userId": null}'::jsonb ELSE s END
      ) FROM jsonb_array_elements(signoffs) AS s
    )
    WHERE signoffs @> ${JSON.stringify([{ userId: membership.userId }])}::jsonb
      AND edition_id IN (
        SELECT ed.id FROM editions ed JOIN events ev ON ev.id = ed.event_id
        WHERE ev.organisation_id = ${orgId}
      )
  `);
  if (member) {
    await tx
      .update(staffInvites)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(staffInvites.organisationId, orgId),
          eq(staffInvites.invitedEmail, member.email.toLowerCase()),
          isNull(staffInvites.acceptedAt),
          isNull(staffInvites.revokedAt),
        ),
      );
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
      tasksMovedTo: ctx.actorUserId,
      itemsMovedTo: ctx.actorUserId,
      signoffsHandedTo: waiting.length > 0 ? input.handToUserId : null,
    },
    summary: `Removed ${member?.email ?? "a team member"} from the team`,
  });
  return { name: who, items: owned.length, tasks: movedTasks.length, handedOver: waiting.length };
}
