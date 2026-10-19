"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { and, asc, eq, max, ne } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { approvers, departments, memberships, users } from "@/lib/db/schema";
import { can, missingAbilityMessage, type PermissionOverrides } from "@/lib/authz";
import { canReceiveSignoff } from "@/lib/access";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import {
  departmentSignerIds,
  ensureSignageWorkflow,
  syncDepartmentSteps,
} from "@/lib/domain/departments";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import {
  clearOtherMainsTx,
  dropPendingMainsTx,
  lockPeople,
  openInviteFor,
  stopSigningTx,
  UserError,
  type PendingDropped,
} from "@/lib/users/manage";
import { askCancelledText, mainTakeover } from "@/lib/users/rules";

/**
 * Departments and who signs off for each (Users → Departments). A
 * department either signs off artwork (it gets a sign-off step and
 * approvers) or is a team for grouping people only. Every action needs
 * "Manage departments and who signs off" (departments.manage). Refusals are
 * UserError (lib/users/manage.ts), whose words are safe to show; anything
 * else is logged and shown as "Could not save".
 */

const NOT_ALLOWED = missingAbilityMessage("departments.manage");

function refresh() {
  revalidatePath("/users", "layout");
  revalidatePath("/approvals");
  revalidatePath("/", "layout");
}

/** ". Sam won't take over Marketing when they accept" for each ask a choice replaced. */
function droppedWords(dropped: readonly PendingDropped[]): string {
  return dropped
    .map((d) => `. ${d.name} won't take over ${d.departmentName} when they accept`)
    .join("");
}

/** The department's main approver now (other than `exceptId`) and whether they can sign. */
async function currentMain(tx: Tx, organisationId: string, departmentId: string, exceptId: string) {
  const [row] = await tx
    .select({ userId: approvers.userId, name: approvers.fullName, userName: users.fullName })
    .from(approvers)
    .leftJoin(users, eq(users.id, approvers.userId))
    .where(
      and(
        eq(approvers.organisationId, organisationId),
        eq(approvers.departmentId, departmentId),
        eq(approvers.isMain, true),
        ne(approvers.id, exceptId),
      ),
    )
    .limit(1);
  if (!row) return null;
  const signers = await departmentSignerIds(tx, organisationId, departmentId);
  return {
    name: row.userName || row.name,
    canSign: Boolean(row.userId && signers.includes(row.userId)),
  };
}

function isUniqueViolation(err: unknown): boolean {
  const e = err as { code?: string; cause?: { code?: string } };
  return e?.code === "23505" || e?.cause?.code === "23505";
}

async function orgDepartment(tx: Tx, organisationId: string, id: string) {
  const dept = await tx.query.departments.findFirst({
    where: and(eq(departments.id, id), eq(departments.organisationId, organisationId)),
  });
  if (!dept) throw new UserError("Department not found — reload the page");
  return dept;
}

const departmentSchema = z
  .object({
    id: z.string().uuid().optional(),
    name: z.string().trim().min(1, "Give the department a name").max(60),
    defaultFor: z
      .array(z.enum(["organiser", "sponsor"]))
      .max(2)
      .default([]),
    signsLast: z.boolean().default(false),
    /** Approves artwork. New departments sign off unless told otherwise; edits keep it. */
    signsOff: z.boolean().optional(),
  })
  .strict();

/**
 * Add or change a department. When it signs off, its sign-off step
 * follows: named after it, on by default for the signage chosen, signing
 * with or after the others. Applies to sign-offs started from now on.
 */
export async function saveDepartment(input: unknown): Promise<ActionResult> {
  const parsed = departmentSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  const data = parsed.data;

  try {
    await db.transaction(async (tx) => {
      const values = {
        name: data.name,
        defaultFor: data.defaultFor,
        signsLast: data.signsLast,
        ...(data.signsOff === undefined ? {} : { signsOff: data.signsOff }),
      };
      if (data.id) {
        const before = await orgDepartment(tx, orgId, data.id);
        await tx.update(departments).set(values).where(eq(departments.id, data.id));
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "department",
          entityId: data.id,
          action: "settings_change",
          before: {
            name: before.name,
            defaultFor: before.defaultFor,
            signsLast: before.signsLast,
            signsOff: before.signsOff,
          },
          after: values,
          summary: `Department “${data.name}” updated`,
        });
      } else {
        const [{ top }] = await tx
          .select({ top: max(departments.sortOrder) })
          .from(departments)
          .where(eq(departments.organisationId, orgId));
        const [row] = await tx
          .insert(departments)
          .values({
            ...values,
            signsOff: data.signsOff ?? true,
            organisationId: orgId,
            sortOrder: (top ?? 0) + 1,
          })
          .returning();
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "department",
          entityId: row.id,
          action: "create",
          after: { ...values, signsOff: data.signsOff ?? true },
          summary: `Department “${data.name}” added`,
        });
      }
      // A brand-new organisation has no signage workflow until a department signs off.
      if (data.signsOff !== false) await ensureSignageWorkflow(tx, orgId);
      await syncDepartmentSteps(tx, orgId);
    });
    refresh();
    return success(
      undefined,
      data.id
        ? "Department saved"
        : data.signsOff === false
          ? `${data.name} added`
          : `${data.name} added — now add who signs off for it`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (isUniqueViolation(err)) return fail("There is already a department with that name");
    if (err instanceof UserError) return fail(err.message);
    console.error("saveDepartment", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Archive a department (or bring it back). Nothing is deleted: its people
 * keep their access and show the department as archived; sign-offs already
 * waiting on it can still be decided.
 */
export async function setDepartmentArchived(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const name = await db.transaction(async (tx) => {
      const dept = await orgDepartment(tx, orgId, parsed.data.id);
      await tx
        .update(departments)
        .set({ isArchived: parsed.data.archived })
        .where(eq(departments.id, dept.id));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "department",
        entityId: dept.id,
        action: "settings_change",
        before: { archived: dept.isArchived },
        after: { archived: parsed.data.archived },
        summary: `Department “${dept.name}” ${parsed.data.archived ? "archived" : "restored"}`,
      });
      await syncDepartmentSteps(tx, orgId);
      return dept.name;
    });
    refresh();
    return success(
      undefined,
      parsed.data.archived ? `${name} archived — its people keep their access` : `${name} restored`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    console.error("setDepartmentArchived", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Switch a department's artwork sign-off on or off. Off: it is a team for
 * grouping people only and its step leaves new sign-offs; its approvers
 * are kept for when it is switched back on.
 */
export async function setDepartmentSignsOff(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), signsOff: z.boolean() })
    .strict()
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const name = await db.transaction(async (tx) => {
      const dept = await orgDepartment(tx, orgId, parsed.data.id);
      await tx
        .update(departments)
        .set({ signsOff: parsed.data.signsOff })
        .where(eq(departments.id, dept.id));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "department",
        entityId: dept.id,
        action: "settings_change",
        before: { signsOff: dept.signsOff },
        after: { signsOff: parsed.data.signsOff },
        summary: `Department “${dept.name}” ${parsed.data.signsOff ? "now signs off artwork" : "no longer signs off artwork"}`,
      });
      if (parsed.data.signsOff) await ensureSignageWorkflow(tx, orgId);
      await syncDepartmentSteps(tx, orgId);
      const signers = parsed.data.signsOff
        ? (await departmentSignerIds(tx, orgId, dept.id)).length
        : 0;
      return { name: dept.name, signers };
    });
    refresh();
    return success(
      undefined,
      parsed.data.signsOff
        ? name.signers > 0
          ? `${name.name} now signs off artwork`
          : `${name.name} now signs off artwork — add who signs off for it, or its sign-offs will wait`
        : `${name.name} no longer signs off artwork — sign-offs already waiting can still be decided`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    console.error("setDepartmentSignsOff", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Move a department earlier or later in the sign-off order: it swaps places
 * with the next department that signs off (teams without sign-off don't
 * take part in the order).
 */
export async function moveDepartment(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), direction: z.enum(["up", "down"]) })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    await db.transaction(async (tx) => {
      const list = await tx
        .select()
        .from(departments)
        .where(and(eq(departments.organisationId, orgId), eq(departments.isArchived, false)))
        .orderBy(asc(departments.sortOrder), asc(departments.name));
      const at = list.findIndex((d) => d.id === parsed.data.id);
      if (at < 0) return;
      const step = parsed.data.direction === "up" ? -1 : 1;
      let to = at + step;
      while (to >= 0 && to < list.length && !list[to].signsOff) to += step;
      if (to < 0 || to >= list.length) return;
      [list[at], list[to]] = [list[to], list[at]];
      for (const [i, d] of list.entries()) {
        if (d.sortOrder !== i + 1) {
          await tx
            .update(departments)
            .set({ sortOrder: i + 1 })
            .where(eq(departments.id, d.id));
        }
      }
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "department",
        entityId: parsed.data.id,
        action: "settings_change",
        after: { direction: parsed.data.direction },
        summary: `Department “${list[to].name}” moved ${parsed.data.direction === "up" ? "earlier" : "later"} in the sign-off order`,
      });
      await syncDepartmentSteps(tx, orgId);
    });
    refresh();
    return success(undefined, "Sign-off order changed");
  } catch (err) {
    unstable_rethrow(err);
    console.error("moveDepartment", err);
    return fail("Could not save — please try again");
  }
}

const addApproverSchema = z
  .object({
    departmentId: z.string().uuid(),
    userId: z.string().uuid(),
    isMain: z.boolean().default(false),
  })
  .strict();

/**
 * Make a team member an approver for a department (Users → Departments).
 * People not on the team yet are added through Add user, which invites
 * them with sign-off already ticked.
 */
export async function addApprover(input: unknown): Promise<ActionResult> {
  const parsed = addApproverSchema.safeParse(input);
  if (!parsed.success) return fail("Pick a person from the list");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  const data = parsed.data;
  try {
    const name = await db.transaction(async (tx) => {
      // People changes (main approvers included) run one after another.
      await lockPeople(tx, orgId);
      const dept = await orgDepartment(tx, orgId, data.departmentId);
      if (dept.isArchived || !dept.signsOff) {
        throw new UserError(`${dept.name} doesn't sign off artwork — reload the page`);
      }
      const [member] = await tx
        .select({ user: users, membership: memberships })
        .from(memberships)
        .innerJoin(users, eq(users.id, memberships.userId))
        .where(and(eq(memberships.userId, data.userId), eq(memberships.organisationId, orgId)))
        .limit(1);
      if (!member) throw new UserError("That person isn't on the team — reload the page");
      const who = member.user.fullName || member.user.email;
      // Only someone who can sign now: active, not a viewer, sign-off not paused.
      if (
        !canReceiveSignoff({
          role: member.membership.role,
          overrides: member.membership.permissionOverrides as PermissionOverrides,
          suspendedAt: member.membership.suspendedAt,
          accessEndsAt: member.membership.accessEndsAt,
        })
      ) {
        throw new UserError(`${who} can't sign off at the moment — pick someone else`);
      }
      const email = member.user.email.toLowerCase();
      let dropped: PendingDropped[] = [];
      if (data.isMain) {
        // One main approver per department: clear the others first (audited).
        await clearOtherMainsTx(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          departmentId: dept.id,
          keep: ne(approvers.email, email),
          newMainName: who,
        });
        // The newest choice wins: a pending "main when they accept" is cancelled.
        dropped = await dropPendingMainsTx(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          departmentId: dept.id,
          keep: ne(approvers.email, email),
          newMainName: who,
          newMainWhen: "now",
        });
      }
      const [row] = await tx
        .insert(approvers)
        .values({
          organisationId: orgId,
          departmentId: dept.id,
          fullName: who,
          jobTitle: member.membership.jobTitle,
          email,
          userId: member.user.id,
          isMain: data.isMain,
        })
        .onConflictDoUpdate({
          target: [approvers.departmentId, approvers.email],
          set: {
            userId: member.user.id,
            fullName: who,
            isMain: data.isMain,
            mainOnAccept: false,
            mainOnAcceptBy: null,
          },
        })
        .returning();
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "approver",
        entityId: row.id,
        action: "create",
        after: { userId: member.user.id, department: dept.name, isMain: data.isMain },
        subjectUserId: member.user.id,
        subjectEmail: email,
        summary: `${who} added as an approver for ${dept.name}`,
      });
      await syncDepartmentSteps(tx, orgId);
      return `${who} now signs off for ${dept.name}${droppedWords(dropped)}`;
    });
    refresh();
    return success(undefined, name);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    console.error("addApprover", err);
    return fail("Could not save — please try again");
  }
}

/** "Sam won't become the main approver for Marketing — Jo stays main approver". */
function cancelledWords(who: string, dept: string, main: { name: string } | null): string {
  return askCancelledText(who, dept, main?.name ?? null);
}

/** Clear a pending ask (Don't make main, or the outlined star), audited on the invitee. */
async function cancelAskTx(
  tx: Tx,
  session: { user: { id: string } },
  orgId: string,
  row: typeof approvers.$inferSelect,
  deptName: string,
) {
  await tx
    .update(approvers)
    .set({ mainOnAccept: false, mainOnAcceptBy: null })
    .where(eq(approvers.id, row.id));
  await writeAudit(tx, {
    organisationId: orgId,
    actorUserId: session.user.id,
    entityType: "approver",
    entityId: row.id,
    action: "settings_change",
    before: { mainOnAccept: true },
    after: { mainOnAccept: false, email: row.email },
    subjectUserId: row.userId,
    subjectEmail: row.email,
    summary: `${row.fullName} will no longer become the main approver for ${deptName} when they accept`,
  });
  return cancelledWords(
    row.fullName,
    deptName,
    await currentMain(tx, orgId, row.departmentId, row.id),
  );
}

/**
 * Make an approver the department's main approver (or stop them being it).
 * Someone only invited, while the main can sign, becomes main when they
 * accept (an ask on their row); anyone else is main now. The newest choice
 * wins: a pending ask in the department is cancelled.
 */
export async function setMainApprover(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), isMain: z.boolean() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const message = await db.transaction(async (tx) => {
      // People changes run one after another (an acceptance can't interleave).
      await lockPeople(tx, orgId);
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new UserError("Approver not found — reload the page");
      const dept = await orgDepartment(tx, orgId, row.departmentId);
      if (!parsed.data.isMain && row.mainOnAccept) {
        return cancelAskTx(tx, session, orgId, row, dept.name);
      }
      if (parsed.data.isMain) {
        const current = row.userId ? null : await currentMain(tx, orgId, dept.id, row.id);
        const when = mainTakeover({
          hasAccount: Boolean(row.userId),
          currentMainCanSign: Boolean(current?.canSign),
        });
        if (when === "on_accept") {
          if (!(await openInviteFor(tx, orgId, row.email))) {
            throw new UserError(
              `${row.fullName} hasn't been invited — add them under Users → Add person first, then make them main`,
            );
          }
          const words = `${row.fullName} becomes the main approver for ${dept.name} when they accept — ${current!.name} stays until then`;
          if (row.mainOnAccept) return words;
          const dropped = await dropPendingMainsTx(tx, {
            organisationId: orgId,
            actorUserId: session.user.id,
            departmentId: dept.id,
            keep: ne(approvers.id, row.id),
            newMainName: row.fullName || row.email,
            newMainWhen: "on_accept",
          });
          await tx
            .update(approvers)
            .set({ mainOnAccept: true, mainOnAcceptBy: session.user.id })
            .where(eq(approvers.id, row.id));
          await writeAudit(tx, {
            organisationId: orgId,
            actorUserId: session.user.id,
            entityType: "approver",
            entityId: row.id,
            action: "settings_change",
            before: { mainOnAccept: false },
            after: { mainOnAccept: true, email: row.email, currentMain: current!.name },
            subjectUserId: row.userId,
            subjectEmail: row.email,
            summary: `${row.fullName} will become the main approver for ${dept.name} when they accept — ${current!.name} stays until then`,
          });
          return `${words}${droppedWords(dropped)}`;
        }
      }
      let dropped: PendingDropped[] = [];
      if (parsed.data.isMain) {
        // One main approver per department: clear the others first (audited).
        await clearOtherMainsTx(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          departmentId: dept.id,
          keep: ne(approvers.id, row.id),
          newMainName: row.fullName || row.email,
        });
        dropped = await dropPendingMainsTx(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          departmentId: dept.id,
          keep: ne(approvers.id, row.id),
          newMainName: row.fullName || row.email,
          newMainWhen: "now",
        });
      }
      await tx
        .update(approvers)
        // Main now replaces their own ask, if they had one (it can't be both).
        .set(
          parsed.data.isMain
            ? { isMain: true, mainOnAccept: false, mainOnAcceptBy: null }
            : { isMain: false },
        )
        .where(eq(approvers.id, row.id));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "approver",
        entityId: row.id,
        action: "settings_change",
        before: { isMain: row.isMain },
        after: { isMain: parsed.data.isMain, userId: row.userId, email: row.email },
        subjectUserId: row.userId,
        subjectEmail: row.email,
        summary: parsed.data.isMain
          ? `${row.fullName} is now the main approver for ${dept.name}`
          : `${row.fullName} is no longer the main approver for ${dept.name}`,
      });
      await syncDepartmentSteps(tx, orgId);
      return parsed.data.isMain
        ? `${row.fullName} is now the main approver for ${dept.name}${droppedWords(dropped)}`
        : `${dept.name} has no main approver — everyone in it is asked`;
    });
    refresh();
    return success(undefined, message);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    if (isUniqueViolation(err)) return fail("Could not save — please try again");
    console.error("setMainApprover", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Departments → Don't make main: the invitee won't take over as main
 * approver when they accept. Its own action (not setMainApprover with
 * false), so a stale page can't demote someone who has just accepted.
 */
export async function cancelMainOnAccept(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const message = await db.transaction(async (tx) => {
      await lockPeople(tx, orgId);
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new UserError("Approver not found — reload the page");
      if (!row.mainOnAccept) {
        throw new UserError(
          row.userId
            ? `${row.fullName} has accepted their invitation — reload the page`
            : `${row.fullName} isn't due to become main approver — reload the page`,
        );
      }
      const dept = await orgDepartment(tx, orgId, row.departmentId);
      return cancelAskTx(tx, session, orgId, row, dept.name);
    });
    refresh();
    return success(undefined, message);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    console.error("cancelMainOnAccept", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Take someone off a department's approvers. Sign-offs for that department
 * that name them (waiting now or later in the round) go back to the
 * department when someone else there can sign; otherwise they stay with
 * them, named, to be handed on from the item. Their team membership is
 * untouched.
 */
export async function removeApprover(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const name = await db.transaction(async (tx) => {
      // People changes that hand sign-offs on run one after another
      // (stopSigningTx below), taken before anything here is changed.
      await lockPeople(tx, orgId);
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new UserError("Approver not found — reload the page");
      const dept = await orgDepartment(tx, orgId, row.departmentId);
      await tx.delete(approvers).where(eq(approvers.id, row.id));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "approver",
        entityId: row.id,
        action: "grant_revoke",
        before: {
          fullName: row.fullName,
          email: row.email,
          userId: row.userId,
          department: dept.name,
          mainOnAccept: row.mainOnAccept,
        },
        subjectUserId: row.userId,
        subjectEmail: row.email,
        summary: `${row.fullName} removed from ${dept.name} approvers`,
      });
      // Their named sign-offs first, so the re-sync's routing doesn't move them unannounced.
      const handed = row.userId
        ? await stopSigningTx(
            tx,
            {
              organisationId: orgId,
              actorUserId: session.user.id,
              actorName: session.user.fullName || session.user.email,
            },
            {
              userId: row.userId,
              who: row.fullName,
              why: `was taken off the ${dept.name} approvers`,
              departmentIds: [dept.id],
            },
          )
        : { moved: 0, kept: 0 };
      await syncDepartmentSteps(tx, orgId);
      const left = (await departmentSignerIds(tx, orgId, dept.id)).length;
      return [
        `${row.fullName} removed from ${dept.name} approvers${
          row.mainOnAccept ? " — they won't become main approver when they accept" : ""
        }`,
        handed.moved > 0
          ? `${handed.moved} sign-off${handed.moved === 1 ? "" : "s"} went back to ${dept.name}`
          : null,
        handed.kept > 0
          ? `${handed.kept} sign-off${handed.kept === 1 ? " still names" : "s still name"} them — hand ${handed.kept === 1 ? "it" : "them"} on from the item`
          : null,
        left === 0 && dept.signsOff && !dept.isArchived
          ? `Nobody can sign off for ${dept.name} now — add someone, or its sign-offs will wait`
          : null,
      ]
        .filter(Boolean)
        .join(". ");
    });
    refresh();
    return success(undefined, name);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof UserError) return fail(err.message);
    console.error("removeApprover", err);
    return fail("Could not save — please try again");
  }
}
