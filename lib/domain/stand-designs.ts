// No "server-only" marker: the seed script sets up the stand workflow too.
import { and, eq } from "drizzle-orm";
import type { Db, Tx } from "@/lib/db/client";
import { signageItems, workflows } from "@/lib/db/schema";
import type { SignoffPlan, StepDef } from "@/lib/workflow/types";
import { isDepartmentStep } from "@/lib/workflow/signoffs";
import { syncDepartmentSteps } from "./departments";

export const STAND_DESIGN_WORKFLOW_NAME = "Stand design sign-off";

/**
 * The organisation's stand-design sign-off: one step per department and
 * nothing else, so an approved design simply stays approved. Created the
 * first time a stand is added; department changes keep it in step like
 * every other signage workflow.
 */
export async function ensureStandDesignWorkflow(tx: Db | Tx, organisationId: string) {
  const [existing] = await tx
    .select({ id: workflows.id })
    .from(workflows)
    .where(
      and(
        eq(workflows.organisationId, organisationId),
        eq(workflows.forKind, "stand_design"),
        eq(workflows.isArchived, false),
      ),
    )
    .limit(1);
  if (existing) return existing.id;
  const [row] = await tx
    .insert(workflows)
    .values({
      organisationId,
      name: STAND_DESIGN_WORKFLOW_NAME,
      appliesTo: "signage",
      forKind: "stand_design",
      isDefault: false,
    })
    .returning({ id: workflows.id });
  await syncDepartmentSteps(tx, organisationId);
  return row.id;
}

/**
 * A stand's sign-off plan carried over to one of its panels: the same
 * departments and people, matched by department because the panel's
 * workflow has its own steps. Null (the defaults) stays null.
 */
export function mapPlanToWorkflow(
  plan: SignoffPlan | null,
  fromSteps: Pick<StepDef, "id" | "departmentId">[],
  toSteps: Pick<StepDef, "id" | "departmentId" | "kind" | "defaultFor">[],
): SignoffPlan | null {
  if (!plan) return null;
  const deptOf = new Map(fromSteps.map((s) => [s.id, s.departmentId ?? null]));
  const targets = toSteps.filter((s) => isDepartmentStep(s) && s.departmentId);
  const mapped: SignoffPlan = [];
  for (const entry of plan) {
    const dept = deptOf.get(entry.stepId);
    const target = dept ? targets.find((s) => s.departmentId === dept) : undefined;
    if (target && !mapped.some((m) => m.stepId === target.id)) {
      mapped.push({ stepId: target.id, userId: entry.userId });
    }
  }
  return mapped.length > 0 ? mapped : null;
}

/**
 * For a stand panel, its stand's status (panel graphics wait for the design
 * to be approved); null for anything else.
 */
export async function panelParent(
  db: Db | Tx,
  item: { kind: string; parentItemId: string | null },
): Promise<{ parentStatus: string | null } | null> {
  if (item.kind !== "stand_panel") return null;
  if (!item.parentItemId) return { parentStatus: null };
  const [parent] = await db
    .select({ status: signageItems.status })
    .from(signageItems)
    .where(eq(signageItems.id, item.parentItemId))
    .limit(1);
  return { parentStatus: parent?.status ?? null };
}
