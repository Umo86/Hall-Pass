/**
 * Who signs an item off, in words — shared by the form (client) and the
 * item page's read-only details (server). No React here.
 */
import type { SignoffChoice, SignoffStepOption } from "./item-form";

/** The defaults admins set for organiser or sponsor signage. */
export function defaultSignoffPlan(steps: SignoffStepOption[], category: string): SignoffChoice[] {
  return steps
    .filter((s) => s.defaultFor.includes(category))
    .map((s) => ({ stepId: s.id, userId: s.defaultUserId }));
}

/** "Operations, Marketing (Mia Marketing), Senior management". */
export function signoffPlanSummary(steps: SignoffStepOption[], plan: SignoffChoice[]): string {
  return plan
    .map((choice) => {
      const step = steps.find((s) => s.id === choice.stepId);
      if (!step) return null;
      const person = choice.userId ? step.people.find((p) => p.id === choice.userId) : null;
      const name = step.departmentName || step.name;
      return person ? `${name} (${person.name})` : name;
    })
    .filter(Boolean)
    .join(", ");
}
