import type { SignageCategory, SignoffPlan, StepDef } from "./types";

/** A department step: one people choose per item (Operations, Marketing…). */
export function isDepartmentStep(
  step: Pick<StepDef, "defaultFor" | "kind"> & { departmentId?: string | null },
): boolean {
  return step.kind === "approval" && (Boolean(step.departmentId) || (step.defaultFor?.length ?? 0) > 0);
}

/** The sign-offs an item of this category gets when nobody has changed them. */
export function defaultSignoffs(
  steps: Pick<
    StepDef,
    "id" | "kind" | "defaultFor" | "approverType" | "approverUserId" | "departmentId"
  >[],
  category: SignageCategory | null | undefined,
): SignoffPlan {
  const cat = category ?? "organiser";
  return steps
    .filter((s) => isDepartmentStep(s) && (s.defaultFor ?? []).includes(cat))
    .map((s) => ({ stepId: s.id, userId: s.approverType === "user" ? s.approverUserId : null }));
}

/** The item's own choices, or the defaults for its category. */
export function effectiveSignoffs(
  steps: Parameters<typeof defaultSignoffs>[0],
  category: SignageCategory | null | undefined,
  plan: SignoffPlan | null | undefined,
): SignoffPlan {
  if (!plan) return defaultSignoffs(steps, category);
  const known = new Set(steps.filter(isDepartmentStep).map((s) => s.id));
  return plan.filter((p) => known.has(p.stepId));
}

/** Same steps and people, in any order? */
export function sameSignoffs(a: SignoffPlan, b: SignoffPlan): boolean {
  if (a.length !== b.length) return false;
  const key = (p: SignoffPlan[number]) => `${p.stepId}:${p.userId ?? ""}`;
  const set = new Set(a.map(key));
  return b.every((p) => set.has(key(p)));
}
