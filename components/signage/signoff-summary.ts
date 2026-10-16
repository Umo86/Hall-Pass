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

/**
 * "Operations, Marketing (Mia Marketing), Senior management" — and a named
 * person who can't sign now with why: "Marketing (Mia Marketing — can't sign off)".
 */
export function signoffPlanSummary(steps: SignoffStepOption[], plan: SignoffChoice[]): string {
  return plan
    .map((choice) => {
      const step = steps.find((s) => s.id === choice.stepId);
      if (!step) return null;
      const name = step.departmentName || step.name;
      if (!choice.userId) return name;
      const person = step.people.find((p) => p.id === choice.userId);
      if (person) return `${name} (${person.name})`;
      const stale = step.unavailable?.find((u) => u.id === choice.userId);
      return stale ? `${name} (${stale.name} — ${stale.reason.toLowerCase()})` : name;
    })
    .filter(Boolean)
    .join(", ");
}

/** Named people on the plan who can't sign their step now ("Change" is offered). */
export function staleSignoffPeople(
  steps: SignoffStepOption[],
  plan: SignoffChoice[],
): { stepName: string; name: string; reason: string }[] {
  return plan.flatMap((choice) => {
    const step = steps.find((s) => s.id === choice.stepId);
    const stale = choice.userId
      ? step?.unavailable?.find((u) => u.id === choice.userId)
      : undefined;
    return step && stale ? [{ stepName: step.name, name: stale.name, reason: stale.reason }] : [];
  });
}
