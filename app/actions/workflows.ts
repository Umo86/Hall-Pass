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
import { statusLabel } from "@/lib/format";

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
  .refine((d) => (d.approverType === "role" ? Boolean(d.approverRole) : Boolean(d.approverUserId)), {
    message: "Pick a role or a person",
  });

/**
 * Point a workflow step at a role or a named staff member. Applies to future
 * runs only — in-flight sign-offs keep the snapshot taken when they started.
 */
export async function updateStepApprover(input: unknown): Promise<ActionResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "settings.manage" })) {
    return fail("Only admins and ops manage workflows");
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
          .select({ user: users })
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
        label = member.user.fullName || member.user.email;
        await tx
          .update(workflowSteps)
          .set({ approverType: "user", approverUserId: parsed.data.approverUserId, approverRole: null })
          .where(eq(workflowSteps.id, row.step.id));
      } else {
        label = statusLabel(parsed.data.approverRole!);
        await tx
          .update(workflowSteps)
          .set({ approverType: "role", approverRole: parsed.data.approverRole, approverUserId: null })
          .where(eq(workflowSteps.id, row.step.id));
      }

      await writeAudit(tx, {
        organisationId: session.organisation.id,
        actorUserId: session.user.id,
        entityType: "workflow_step",
        entityId: row.step.id,
        action: "settings_change",
        before: { approverType: row.step.approverType, approverRole: row.step.approverRole, approverUserId: row.step.approverUserId },
        after: { approverType: parsed.data.approverType, approverRole: parsed.data.approverRole ?? null, approverUserId: parsed.data.approverUserId ?? null },
        summary: `${row.workflow.name} · ${row.step.name}: approver → ${label}`,
      });
    });
    revalidatePath("/settings");
    return success(undefined, "Approver updated — applies to future sign-off runs");
  } catch (err) {
    return fail(err instanceof Error ? err.message : "Could not update the approver");
  }
}
