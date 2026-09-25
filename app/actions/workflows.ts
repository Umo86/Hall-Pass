"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users, workflows, workflowSteps } from "@/lib/db/schema";
import { can } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";
import { roleLabel } from "@/lib/format";
import { defaultSignageWorkflowId } from "@/lib/domain/signage";

const APPROVER_ROLES = [
  // Staff (viewer excluded — read-only by definition)
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  // External
  "venue",
  "structural_engineer",
  "hs",
  "supplier",
  "sponsor",
  "contractor",
] as const;

const schema = z
  .object({
    stepId: z.string().uuid(),
    approverType: z.enum(["role", "user"]),
    approverRole: z.enum(APPROVER_ROLES).optional().nullable(),
    approverUserId: z.string().uuid().optional().nullable(),
  })
  .refine(
    (d) => (d.approverType === "role" ? Boolean(d.approverRole) : Boolean(d.approverUserId)),
    {
      message: "Pick a role or a person",
    },
  );

/**
 * Point a workflow step at a role or a named staff member. Applies to future
 * runs only — in-flight sign-offs keep the snapshot taken when they started.
 */
export async function updateStepApprover(input: unknown): Promise<ActionResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" })) {
    return fail("Only admins choose who signs off");
  }

  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .select({ step: workflowSteps, workflow: workflows })
        .from(workflowSteps)
        .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
        .where(
          and(
            eq(workflowSteps.id, parsed.data.stepId),
            eq(workflows.organisationId, session.organisation.id),
          ),
        )
        .limit(1);
      if (!row) throw new Error("Step not found");

      let label: string;
      if (parsed.data.approverType === "user") {
        const [member] = await tx
          .select({ user: users, membership: memberships })
          .from(memberships)
          .innerJoin(users, eq(memberships.userId, users.id))
          .where(
            and(
              eq(memberships.userId, parsed.data.approverUserId!),
              eq(memberships.organisationId, session.organisation.id),
            ),
          )
          .limit(1);
        if (!member) throw new Error("That person is not a staff member of this organisation");
        if (member.membership.role === "viewer") {
          throw new Error("Viewers are read-only and can't sign off — pick someone else");
        }
        if (
          (member.membership.permissionOverrides as Record<string, unknown>)?.[
            "approval.decide"
          ] === false
        ) {
          throw new Error(
            "That person's sign-off permission is switched off in Team — pick someone else",
          );
        }
        label = member.user.fullName || member.user.email;
        await tx
          .update(workflowSteps)
          .set({
            approverType: "user",
            approverUserId: parsed.data.approverUserId,
            approverRole: null,
          })
          .where(eq(workflowSteps.id, row.step.id));
      } else {
        label = roleLabel(parsed.data.approverRole!);
        await tx
          .update(workflowSteps)
          .set({
            approverType: "role",
            approverRole: parsed.data.approverRole,
            approverUserId: null,
          })
          .where(eq(workflowSteps.id, row.step.id));
      }

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "workflow_step",
        entityId: row.step.id,
        action: "settings_change",
        before: {
          approverType: row.step.approverType,
          approverRole: row.step.approverRole,
          approverUserId: row.step.approverUserId,
        },
        after: {
          approverType: parsed.data.approverType,
          approverRole: parsed.data.approverRole ?? null,
          approverUserId: parsed.data.approverUserId ?? null,
        },
        summary: `${row.workflow.name} · ${row.step.name}: approver → ${label}`,
      });
    });
    revalidatePath("/settings");
    return success(undefined, "Approver updated — applies to future sign-off runs");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update the approver");
  }
}

const DEPARTMENTS = ["ops", "marketing", "sales", "event_director", "admin"] as const;

const signoffStepSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(1, "Give the sign-off a name").max(100),
  department: z.enum(DEPARTMENTS),
  defaultUserId: z.string().uuid().nullable().optional(),
  defaultFor: z.array(z.enum(["organiser", "sponsor"])).max(2),
  slaDays: z.coerce.number().int().min(0).max(60).default(3),
});

/**
 * Add or change a department sign-off (Settings → Sign-off): its name, the
 * department, who in it signs by default, and which kinds of signage get it
 * by default. New steps sign off alongside Operations and Marketing.
 * Applies to future sign-offs only.
 */
export async function saveSignoffStep(input: unknown): Promise<ActionResult> {
  const parsed = signoffStepSchema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" }))
    return fail("Only admins choose who signs off");
  const orgId = session.organisation.id;
  const data = parsed.data;

  try {
    await db.transaction(async (tx) => {
      if (data.defaultUserId) {
        const [member] = await tx
          .select({ role: memberships.role, overrides: memberships.permissionOverrides })
          .from(memberships)
          .where(
            and(eq(memberships.userId, data.defaultUserId), eq(memberships.organisationId, orgId)),
          )
          .limit(1);
        if (!member) throw new Error("That person is not on the team");
        if ((member.overrides as Record<string, unknown>)?.["approval.decide"] === false) {
          throw new Error("That person's sign-off permission is switched off in Team");
        }
        if (member.role !== data.department && member.role !== "admin") {
          throw new Error(`Pick someone from ${roleLabel(data.department)}`);
        }
      }
      const values = {
        name: data.name,
        approverRole: data.department,
        approverType: data.defaultUserId ? ("user" as const) : ("role" as const),
        approverUserId: data.defaultUserId ?? null,
        defaultFor: data.defaultFor,
        slaDays: data.slaDays,
      };
      if (data.id) {
        const [row] = await tx
          .select({ step: workflowSteps })
          .from(workflowSteps)
          .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
          .where(and(eq(workflowSteps.id, data.id), eq(workflows.organisationId, orgId)))
          .limit(1);
        if (!row) throw new Error("Sign-off step not found");
        await tx.update(workflowSteps).set(values).where(eq(workflowSteps.id, data.id));
        await writeAudit(tx, {
          organisationId: orgId,
          actorUserId: session.user.id,
          entityType: "workflow_step",
          entityId: data.id,
          action: "settings_change",
          before: {
            name: row.step.name,
            department: row.step.approverRole,
            defaultUserId: row.step.approverUserId,
            defaultFor: row.step.defaultFor,
          },
          after: { ...values },
          summary: `Sign-off “${data.name}” updated`,
        });
        return;
      }
      // New department: signs off alongside the first group.
      const workflowId = await defaultSignageWorkflowId(tx, orgId, null);
      if (!workflowId) throw new Error("No signage workflow found");
      const steps = await tx
        .select()
        .from(workflowSteps)
        .where(eq(workflowSteps.workflowId, workflowId));
      const firstGroup = steps.filter((s) => s.parallelGroup === 1);
      const insertAt = firstGroup.length ? Math.max(...firstGroup.map((s) => s.sortOrder)) + 1 : 1;
      for (const s of steps.filter((s) => s.sortOrder >= insertAt)) {
        await tx
          .update(workflowSteps)
          .set({ sortOrder: s.sortOrder + 1 })
          .where(eq(workflowSteps.id, s.id));
      }
      const [row] = await tx
        .insert(workflowSteps)
        .values({
          ...values,
          workflowId,
          sortOrder: insertAt,
          parallelGroup: firstGroup.length ? 1 : null,
          kind: "approval",
          conditions: ["always"],
        })
        .returning();
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "workflow_step",
        entityId: row.id,
        action: "create",
        after: { ...values },
        summary: `Sign-off “${data.name}” added`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Saved — applies to sign-offs started from now on");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not save the sign-off");
  }
}

/** Retire a department sign-off; sign-offs already running keep it. */
export async function archiveSignoffStep(input: unknown): Promise<ActionResult> {
  const parsed = z.object({ id: z.string().uuid() }).safeParse(input);
  if (!parsed.success) return fail("Invalid request");
  const session = await requireSession();
  if (!can(session.actor, { type: "users.manage" }))
    return fail("Only admins choose who signs off");
  try {
    await db.transaction(async (tx) => {
      const [row] = await tx
        .select({ step: workflowSteps })
        .from(workflowSteps)
        .innerJoin(workflows, eq(workflowSteps.workflowId, workflows.id))
        .where(
          and(
            eq(workflowSteps.id, parsed.data.id),
            eq(workflows.organisationId, session.organisation.id),
          ),
        )
        .limit(1);
      if (!row) throw new Error("Sign-off step not found");
      if ((row.step.defaultFor ?? []).length === 0) {
        throw new Error("Only department sign-offs can be removed here");
      }
      const others = await tx
        .select({ id: workflowSteps.id, defaultFor: workflowSteps.defaultFor })
        .from(workflowSteps)
        .where(
          and(
            eq(workflowSteps.workflowId, row.step.workflowId),
            eq(workflowSteps.isArchived, false),
          ),
        );
      if (
        others.filter((o) => o.id !== row.step.id && (o.defaultFor ?? []).length > 0).length === 0
      ) {
        throw new Error("Keep at least one department sign-off");
      }
      await tx
        .update(workflowSteps)
        .set({ isArchived: true })
        .where(eq(workflowSteps.id, row.step.id));
      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "workflow_step",
        entityId: row.step.id,
        action: "settings_change",
        after: { archived: true },
        summary: `Sign-off “${row.step.name}” removed`,
      });
    });
    revalidatePath("/", "layout");
    return success(undefined, "Removed — items already in sign-off keep it");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not remove the sign-off");
  }
}
