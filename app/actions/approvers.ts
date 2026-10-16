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
import { ensureSignageWorkflow, syncDepartmentSteps } from "@/lib/domain/departments";
import { fail, success, type ActionResult } from "@/lib/actions/result";

/**
 * Departments and who signs off for each (Users → Departments). A
 * department either signs off artwork (it gets a sign-off step and
 * approvers) or is a team for grouping people only.
 */

const NOT_ALLOWED = missingAbilityMessage("departments.manage");

function refresh() {
  revalidatePath("/users", "layout");
  revalidatePath("/approvals");
  revalidatePath("/", "layout");
}

/** A refusal whose message is safe to show as it is. */
class SafeError extends Error {}

function isUniqueViolation(err: unknown): boolean {
  const e = err as { code?: string; cause?: { code?: string } };
  return e?.code === "23505" || e?.cause?.code === "23505";
}

async function orgDepartment(tx: Tx, organisationId: string, id: string) {
  const dept = await tx.query.departments.findFirst({
    where: and(eq(departments.id, id), eq(departments.organisationId, organisationId)),
  });
  if (!dept) throw new Error("Department not found — reload the page");
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
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
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
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
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
      return dept.name;
    });
    refresh();
    return success(
      undefined,
      parsed.data.signsOff
        ? `${name} now signs off artwork`
        : `${name} no longer signs off artwork — sign-offs already waiting can still be decided`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
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
      const dept = await orgDepartment(tx, orgId, data.departmentId);
      if (dept.isArchived || !dept.signsOff) {
        throw new Error(`${dept.name} doesn't sign off artwork — reload the page`);
      }
      const [member] = await tx
        .select({ user: users, membership: memberships })
        .from(memberships)
        .innerJoin(users, eq(users.id, memberships.userId))
        .where(and(eq(memberships.userId, data.userId), eq(memberships.organisationId, orgId)))
        .limit(1);
      if (!member) throw new Error("That person isn't on the team — reload the page");
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
        throw new SafeError(`${who} can't sign off at the moment — pick someone else`);
      }
      const email = member.user.email.toLowerCase();
      if (data.isMain) {
        // One main approver per department: clear the others first.
        await tx
          .update(approvers)
          .set({ isMain: false })
          .where(and(eq(approvers.departmentId, dept.id), ne(approvers.email, email)));
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
          set: { userId: member.user.id, fullName: who, isMain: data.isMain },
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
      return `${who} now signs off for ${dept.name}`;
    });
    refresh();
    return success(undefined, name);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("addApprover", err);
    return fail("Could not save — please try again");
  }
}

/** Make an approver the department's main approver (or stop them being it). */
export async function setMainApprover(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), isMain: z.boolean() }).strict().safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const message = await db.transaction(async (tx) => {
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new Error("Approver not found — reload the page");
      const dept = await orgDepartment(tx, orgId, row.departmentId);
      if (parsed.data.isMain) {
        // One main approver per department: clear the others first.
        await tx
          .update(approvers)
          .set({ isMain: false })
          .where(and(eq(approvers.departmentId, dept.id), ne(approvers.id, row.id)));
      }
      await tx
        .update(approvers)
        .set({ isMain: parsed.data.isMain })
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
        ? `${row.fullName} is now the main approver for ${dept.name}`
        : `${dept.name} has no main approver — everyone in it is asked`;
    });
    refresh();
    return success(undefined, message);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("setMainApprover", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Take someone off a department's approvers. Sign-offs already waiting on
 * them by name stay with them (hand them on from the item if needed). Their
 * team membership is untouched.
 */
export async function removeApprover(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "departments.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const name = await db.transaction(async (tx) => {
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new Error("Approver not found — reload the page");
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
        },
        subjectUserId: row.userId,
        subjectEmail: row.email,
        summary: `${row.fullName} removed from ${dept.name} approvers`,
      });
      await syncDepartmentSteps(tx, orgId);
      return row.fullName;
    });
    refresh();
    return success(undefined, `${name} removed`);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof SafeError) return fail(err.message);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("removeApprover", err);
    return fail("Could not save — please try again");
  }
}
