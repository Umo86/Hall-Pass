"use server";

import { unstable_rethrow } from "next/navigation";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, count, eq, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  memberships,
  staffInvites,
  tasks,
  users,
  workflowSteps,
  workflows,
} from "@/lib/db/schema";
import { can, OVERRIDE_KEYS, type OverrideKey, type PermissionOverrides } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { createStaffInvite, sendInviteEmail } from "@/lib/auth/staff-invite";
import { fail, success, type ActionResult } from "@/lib/actions/result";

const roleSchema = z.enum(["admin", "ops", "marketing", "sales", "event_director", "viewer"]);

// Strict: unknown keys are rejected, so only the whitelisted abilities in
// lib/authz.ts can ever be stored.
const overridesSchema = z
  .object(
    Object.fromEntries(OVERRIDE_KEYS.map((k) => [k, z.boolean().optional()])) as Record<
      OverrideKey,
      z.ZodOptional<z.ZodBoolean>
    >,
  )
  .strict();

/** Change a staff member's role. Admin-only, with self and last-admin guards. */
export async function updateStaffRole(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ membershipId: z.string().uuid(), role: roleSchema }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Only admins manage the team");

  try {
    await db.transaction(async (tx) => {
      const membership = await tx.query.memberships.findFirst({
        where: and(
          eq(memberships.id, parsed.data.membershipId),
          eq(memberships.organisationId, session.organisation.id),
        ),
      });
      if (!membership) throw new Error("Team member not found");
      if (membership.userId === session.user.id) {
        throw new Error("You cannot change your own role — ask another admin");
      }
      if (membership.role === "admin" && parsed.data.role !== "admin") {
        const [admins] = await tx
          .select({ n: count() })
          .from(memberships)
          .where(
            and(
              eq(memberships.organisationId, session.organisation.id),
              eq(memberships.role, "admin"),
            ),
          );
        if (Number(admins.n) <= 1) throw new Error("There must always be at least one admin");
      }
      // A new role starts from that role's defaults.
      await tx
        .update(memberships)
        .set({ role: parsed.data.role, permissionOverrides: {} })
        .where(eq(memberships.id, membership.id));
      const member = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "membership",
        entityId: membership.id,
        action: "settings_change",
        before: { role: membership.role, overrides: membership.permissionOverrides },
        after: { role: parsed.data.role, overrides: {} },
        summary: `${member?.email ?? "user"}: role ${membership.role} → ${parsed.data.role}`,
      });
    });
    revalidatePath("/settings");
    return success(undefined, "Role updated");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update the role");
  }
}

/** Replace a staff member's permission overrides. Admin-only. */
export async function updateStaffOverrides(input: unknown): Promise<ActionResult> {
  const parsed = z
    .object({ membershipId: z.string().uuid(), overrides: overridesSchema })
    .safeParse(input);
  if (!parsed.success) return fail("Invalid permissions");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Only admins manage the team");

  // Drop unset keys so the stored object holds only explicit true/false.
  const overrides: PermissionOverrides = {};
  for (const [k, v] of Object.entries(parsed.data.overrides)) {
    if (typeof v === "boolean") overrides[k as keyof PermissionOverrides] = v;
  }

  try {
    await db.transaction(async (tx) => {
      const membership = await tx.query.memberships.findFirst({
        where: and(
          eq(memberships.id, parsed.data.membershipId),
          eq(memberships.organisationId, session.organisation.id),
        ),
      });
      if (!membership) throw new Error("Team member not found");
      if (membership.role === "admin") throw new Error("Admins always have full access");
      await tx
        .update(memberships)
        .set({ permissionOverrides: overrides })
        .where(eq(memberships.id, membership.id));
      const member = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "membership",
        entityId: membership.id,
        action: "settings_change",
        before: { overrides: membership.permissionOverrides },
        after: { overrides },
        summary: `${member?.email ?? "user"}: permissions updated`,
      });
    });
    revalidatePath("/settings");
    return success(undefined, "Permissions updated — effective on their next page load");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update permissions");
  }
}

/** Invite a staff member; the membership is created at their first sign-in. */
export async function inviteStaff(input: unknown): Promise<ActionResult<{ inviteUrl: string }>> {
  const parsed = z
    .object({ email: z.string().email(), role: roleSchema, overrides: overridesSchema.optional() })
    .safeParse(input);
  if (!parsed.success) return fail("Enter a valid email and role");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Only admins manage the team");

  const email = parsed.data.email.toLowerCase();
  const existingUser = await db.query.users.findFirst({ where: eq(users.email, email) });
  if (existingUser) {
    const membership = await db.query.memberships.findFirst({
      where: and(
        eq(memberships.userId, existingUser.id),
        eq(memberships.organisationId, session.organisation.id),
      ),
    });
    if (membership) return fail("That person is already on the team");
  }

  try {
    const invite = await db.transaction((tx) =>
      createStaffInvite(tx, {
        organisationId: session.organisation.id,
        email,
        role: parsed.data.role,
        overrides: (parsed.data.overrides ?? {}) as PermissionOverrides,
        invitedBy: session.user.id,
        summary: `Invited ${email} to staff as ${parsed.data.role}`,
      }),
    );
    const emailed = await sendInviteEmail({
      to: email,
      inviterName: session.user.fullName || session.user.email,
      reason: `You've been added to the ${session.organisation.brandName} team.`,
      inviteUrl: invite.inviteUrl,
      inviteId: invite.inviteId,
    });
    revalidatePath("/settings");
    return success(
      { inviteUrl: invite.inviteUrl },
      emailed
        ? `Invitation emailed to ${email}`
        : "Invitation created — email isn't set up, so share the link",
    );
  } catch (err) {
    unstable_rethrow(err);
    console.error("inviteStaff", err);
    return fail("Could not save — please try again");
  }
}

export async function revokeStaffInvite(input: unknown): Promise<ActionResult> {
  try {
    const parsed = z.object({ inviteId: z.string().uuid() }).safeParse(input);
    if (!parsed.success) return fail("Invalid request");
    const session = await requireSession();
    if (!can(session.actor, { type: "users.manage" })) return fail("Only admins manage the team");
    await db.transaction(async (tx) => {
      const [invite] = await tx
        .update(staffInvites)
        .set({ revokedAt: new Date() })
        .where(
          and(
            eq(staffInvites.id, parsed.data.inviteId),
            eq(staffInvites.organisationId, session.organisation.id),
            isNull(staffInvites.acceptedAt),
          ),
        )
        .returning();
      if (invite) {
        await writeAudit(tx, {
          organisationId: session.organisation.id,
          actorUserId: session.user.id,
          entityType: "staff_invite",
          entityId: invite.id,
          action: "grant_revoke",
          summary: `Revoked staff invitation for ${invite.invitedEmail}`,
        });
      }
    });
    revalidatePath("/settings");
    return success(undefined, "Invitation revoked");
  } catch (err) {
    unstable_rethrow(err);
    console.error("revokeStaffInvite", err);
    return fail("Could not save — please try again");
  }
}

/**
 * Remove someone who has left. They lose access at once (their calendar
 * feed stops too). Refused while they are named on a sign-off step or hold
 * open sign-offs, so nothing gets stuck; their open tasks move to you.
 */
export async function removeStaffMember(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ membershipId: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) return fail("Only admins manage the team");
  const orgId = session.organisation.id;

  try {
    const name = await db.transaction(async (tx) => {
      const membership = await tx.query.memberships.findFirst({
        where: and(
          eq(memberships.id, parsed.data.membershipId),
          eq(memberships.organisationId, orgId),
        ),
      });
      if (!membership) throw new Error("Team member not found");
      if (membership.userId === session.user.id) throw new Error("You can't remove yourself");
      if (membership.role === "admin") {
        const [admins] = await tx
          .select({ n: count() })
          .from(memberships)
          .where(and(eq(memberships.organisationId, orgId), eq(memberships.role, "admin")));
        if (Number(admins.n) <= 1) throw new Error("There must always be at least one admin");
      }
      const member = await tx.query.users.findFirst({ where: eq(users.id, membership.userId) });
      const who = member?.fullName || member?.email || "This person";

      const named = await tx
        .select({ step: workflowSteps.name, workflow: workflows.name })
        .from(workflowSteps)
        .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
        .where(
          and(
            eq(workflows.organisationId, orgId),
            eq(workflowSteps.approverUserId, membership.userId),
          ),
        );
      if (named.length > 0) {
        throw new Error(
          `${who} is the named approver for ${named.map((n) => `“${n.step}”`).join(", ")} — pick someone else in Workflows first`,
        );
      }
      const [open] = await tx
        .select({ n: count() })
        .from(approvalInstances)
        .where(
          and(
            eq(approvalInstances.assignedUserId, membership.userId),
            eq(approvalInstances.status, "pending"),
          ),
        );
      if (Number(open.n) > 0) {
        throw new Error(`${who} has ${open.n} sign-off(s) waiting — delegate them first`);
      }

      await tx
        .update(tasks)
        .set({ assignedToUserId: session.user.id })
        .where(
          and(
            eq(tasks.organisationId, orgId),
            eq(tasks.assignedToUserId, membership.userId),
            eq(tasks.status, "open"),
          ),
        );
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
      await tx.delete(memberships).where(eq(memberships.id, membership.id));
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "membership",
        entityId: membership.id,
        action: "grant_revoke",
        before: { userId: membership.userId, role: membership.role },
        summary: `Removed ${member?.email ?? "a team member"} from the team`,
      });
      return who;
    });
    revalidatePath("/settings");
    return success(undefined, `${name} removed — their open tasks are now yours`);
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not remove this person");
  }
}
