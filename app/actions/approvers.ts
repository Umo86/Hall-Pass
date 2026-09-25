"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { and, asc, eq, max, ne } from "drizzle-orm";
import { db, type Tx } from "@/lib/db/client";
import { approvers, departments, memberships, users } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession, type Session } from "@/lib/auth/actor";
import { createStaffInvite, deliverInvite } from "@/lib/auth/staff-invite";
import { openStaffInviteFor } from "@/lib/auth/claim-staff-invite";
import { syncDepartmentSteps } from "@/lib/domain/departments";
import { fail, success, type ActionResult } from "@/lib/actions/result";

const NOT_ALLOWED = "Only admins manage approvers";

function refresh() {
  revalidatePath("/approvals");
  revalidatePath("/", "layout");
}

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

const departmentSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(1, "Give the department a name").max(60),
  defaultFor: z
    .array(z.enum(["organiser", "sponsor"]))
    .max(2)
    .default([]),
  signsLast: z.boolean().default(false),
});

/**
 * Add or change a department. Its sign-off step follows: named after it,
 * on by default for the signage chosen, signing with or after the others.
 * Applies to sign-offs started from now on.
 */
export async function saveDepartment(input: unknown): Promise<ActionResult> {
  const parsed = departmentSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  const data = parsed.data;

  try {
    await db.transaction(async (tx) => {
      const values = { name: data.name, defaultFor: data.defaultFor, signsLast: data.signsLast };
      if (data.id) {
        const before = await orgDepartment(tx, orgId, data.id);
        await tx.update(departments).set(values).where(eq(departments.id, data.id));
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "department",
          entityId: data.id,
          action: "settings_change",
          before: { name: before.name, defaultFor: before.defaultFor, signsLast: before.signsLast },
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
          .values({ ...values, organisationId: orgId, sortOrder: (top ?? 0) + 1 })
          .returning();
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "department",
          entityId: row.id,
          action: "create",
          after: values,
          summary: `Department “${data.name}” added`,
        });
      }
      await syncDepartmentSteps(tx, orgId);
    });
    refresh();
    return success(
      undefined,
      data.id ? "Department saved" : `${data.name} added — now add its approvers`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (isUniqueViolation(err)) return fail("There is already a department with that name");
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("saveDepartment", err);
    return fail("Could not save — please try again");
  }
}

/** Remove a department from sign-off (or bring it back). Nothing is deleted. */
export async function setDepartmentArchived(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid(), archived: z.boolean() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
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
        summary: `Department “${dept.name}” ${parsed.data.archived ? "removed from sign-off" : "restored"}`,
      });
      await syncDepartmentSteps(tx, orgId);
      return dept.name;
    });
    refresh();
    return success(
      undefined,
      parsed.data.archived
        ? `${name} removed — sign-offs already waiting on it can still be decided`
        : `${name} restored`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("setDepartmentArchived", err);
    return fail("Could not save — please try again");
  }
}

/** Move a department up or down the list (its place in the sign-off order). */
export async function moveDepartment(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ id: z.string().uuid(), direction: z.enum(["up", "down"]) })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    await db.transaction(async (tx) => {
      const list = await tx
        .select()
        .from(departments)
        .where(and(eq(departments.organisationId, orgId), eq(departments.isArchived, false)))
        .orderBy(asc(departments.sortOrder), asc(departments.name));
      const at = list.findIndex((d) => d.id === parsed.data.id);
      const to = parsed.data.direction === "up" ? at - 1 : at + 1;
      if (at < 0 || to < 0 || to >= list.length) return;
      [list[at], list[to]] = [list[to], list[at]];
      for (const [i, d] of list.entries()) {
        if (d.sortOrder !== i + 1) {
          await tx
            .update(departments)
            .set({ sortOrder: i + 1 })
            .where(eq(departments.id, d.id));
        }
      }
      await syncDepartmentSteps(tx, orgId);
    });
    refresh();
    return success();
  } catch (err) {
    unstable_rethrow(err);
    console.error("moveDepartment", err);
    return fail("Could not save — please try again");
  }
}

const approverSchema = z.object({
  id: z.string().uuid().optional(),
  departmentId: z.string().uuid(),
  fullName: z.string().trim().min(1, "Enter the person's name").max(200),
  jobTitle: z
    .string()
    .trim()
    .max(200)
    .optional()
    .transform((v) => v || null),
  email: z.string().trim().toLowerCase().email("Enter a valid email address"),
  isMain: z.boolean().default(false),
});

type InviteToSend = { inviteId: string; inviteUrl: string } | null;

/**
 * Link the approver to an existing team account, or invite them to create
 * one (view-only access; an admin can change it in Settings → Team). An
 * open invitation is reused rather than sending another.
 */
async function connectAccount(
  tx: Tx,
  session: Session,
  approver: { id: string; email: string; departmentName: string },
): Promise<InviteToSend | "pending"> {
  const orgId = session.organisation.id;
  const [member] = await tx
    .select({ userId: users.id })
    .from(users)
    .innerJoin(
      memberships,
      and(eq(memberships.userId, users.id), eq(memberships.organisationId, orgId)),
    )
    .where(eq(users.email, approver.email))
    .limit(1);
  if (member) {
    await tx.update(approvers).set({ userId: member.userId }).where(eq(approvers.id, approver.id));
    return null;
  }
  await tx.update(approvers).set({ userId: null }).where(eq(approvers.id, approver.id));
  const open = await openStaffInviteFor(approver.email);
  if (open && open.organisationId === orgId) return "pending";
  return createStaffInvite(tx, {
    organisationId: orgId,
    email: approver.email,
    role: "viewer",
    invitedBy: session.user.id,
    summary: `Invited ${approver.email} to sign off for ${approver.departmentName}`,
  });
}

async function emailInvite(
  session: Session,
  invite: InviteToSend | "pending",
  to: { email: string; name: string; departmentName: string },
): Promise<{ message: string; inviteUrl?: string }> {
  if (invite === null) return { message: `${to.name} can sign off for ${to.departmentName} now` };
  if (invite === "pending") {
    return { message: `${to.name} saved — they already have an invitation waiting` };
  }
  const delivery = await deliverInvite({
    email: to.email,
    name: to.name,
    inviterName: session.user.fullName || session.user.email,
    reason: `You've been added as an approver for ${to.departmentName} at ${session.organisation.brandName}. You'll get an email whenever signage artwork needs your sign-off.`,
    inviteUrl: invite.inviteUrl,
    inviteId: invite.inviteId,
  });
  return delivery.emailed
    ? { message: `${to.name} added — invitation emailed to ${to.email}` }
    : {
        message: `${to.name} added — email isn't set up here, so send them this link yourself`,
        inviteUrl: delivery.fallbackUrl,
      };
}

/** Add or change an approver: name, job title, email, main approver. */
export async function saveApprover(input: unknown): Promise<ActionResult<{ inviteUrl?: string }>> {
  const parsed = approverSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  const data = parsed.data;

  try {
    const { invite, departmentName } = await db.transaction(async (tx) => {
      const dept = await orgDepartment(tx, orgId, data.departmentId);
      const values = {
        fullName: data.fullName,
        jobTitle: data.jobTitle,
        email: data.email,
        isMain: data.isMain,
      };
      let id = data.id;
      let emailChanged = true;
      if (id) {
        const before = await tx.query.approvers.findFirst({
          where: and(eq(approvers.id, id), eq(approvers.organisationId, orgId)),
        });
        if (!before) throw new Error("Approver not found — reload the page");
        emailChanged = before.email !== data.email;
        await tx.update(approvers).set(values).where(eq(approvers.id, id));
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "approver",
          entityId: id,
          action: "settings_change",
          before: {
            fullName: before.fullName,
            jobTitle: before.jobTitle,
            email: before.email,
            isMain: before.isMain,
          },
          after: values,
          summary: `Approver ${data.fullName} (${dept.name}) updated`,
        });
      } else {
        const [row] = await tx
          .insert(approvers)
          .values({ ...values, organisationId: orgId, departmentId: dept.id })
          .returning();
        id = row.id;
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "approver",
          entityId: id,
          action: "create",
          after: { ...values, department: dept.name },
          summary: `${data.fullName} added as an approver for ${dept.name}`,
        });
      }
      if (data.isMain) {
        // One main approver per department.
        await tx
          .update(approvers)
          .set({ isMain: false })
          .where(and(eq(approvers.departmentId, dept.id), ne(approvers.id, id)));
      }
      const invite = emailChanged
        ? await connectAccount(tx, session, { id, email: data.email, departmentName: dept.name })
        : null;
      await syncDepartmentSteps(tx, orgId);
      return { invite, departmentName: dept.name };
    });
    const out = await emailInvite(session, invite, {
      email: data.email,
      name: data.fullName,
      departmentName,
    });
    refresh();
    return success(
      { inviteUrl: out.inviteUrl },
      data.id && !invite ? `${data.fullName} saved` : out.message,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (isUniqueViolation(err)) return fail("That email is already an approver in this department");
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("saveApprover", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Take someone off a department's approvers. Sign-offs already waiting on
 * them by name stay with them (hand them on from the item if needed).
 */
export async function removeApprover(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
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
        before: { fullName: row.fullName, email: row.email, department: dept.name },
        summary: `${row.fullName} removed from ${dept.name} approvers`,
      });
      await syncDepartmentSteps(tx, orgId);
      return row.fullName;
    });
    refresh();
    return success(undefined, `${name} removed`);
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Error && err.message.includes("reload")) return fail(err.message);
    console.error("removeApprover", err);
    return fail("Could not save — please try again");
  }
}

/** Send a fresh invitation to an approver who hasn't set up their account. */
export async function resendApproverInvite(
  input: unknown,
): Promise<ActionResult<{ inviteUrl?: string }>> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail(NOT_ALLOWED);
  const orgId = session.organisation.id;
  try {
    const { row, deptName, invite } = await db.transaction(async (tx) => {
      const row = await tx.query.approvers.findFirst({
        where: and(eq(approvers.id, parsed.data.id), eq(approvers.organisationId, orgId)),
      });
      if (!row) throw new Error("Approver not found — reload the page");
      if (row.userId) throw new Error(`${row.fullName} already has an account`);
      const dept = await orgDepartment(tx, orgId, row.departmentId);
      const invite = await createStaffInvite(tx, {
        organisationId: orgId,
        email: row.email,
        role: "viewer",
        invitedBy: session.user.id,
        summary: `Invitation re-sent to ${row.email} (${dept.name} approver)`,
      });
      return { row, deptName: dept.name, invite };
    });
    const out = await emailInvite(session, invite, {
      email: row.email,
      name: row.fullName,
      departmentName: deptName,
    });
    refresh();
    return success(
      { inviteUrl: out.inviteUrl },
      out.inviteUrl ? out.message : `Invitation sent again to ${row.email}`,
    );
  } catch (err) {
    unstable_rethrow(err);
    if (err instanceof Error && /reload|already has/.test(err.message)) return fail(err.message);
    console.error("resendApproverInvite", err);
    return fail("Could not send — please try again");
  }
}
