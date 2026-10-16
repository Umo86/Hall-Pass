"use client";

import { SelectNative } from "@/components/ui/select-native";
import type { SignoffChoice, SignoffStepOption } from "./item-form";

/**
 * One row per department: tick it to ask for its sign-off, then leave it to
 * anyone in the department or pick the person.
 */
export function SignoffPicker({
  steps,
  plan,
  onChange,
  label = "Sign-off",
}: {
  steps: SignoffStepOption[];
  plan: SignoffChoice[];
  /** Tick or untick a department, or choose who signs it (undefined keeps the current person). */
  onChange: (stepId: string, on: boolean, userId?: string | null) => void;
  label?: string;
}) {
  return (
    <ul className="divide-y rounded-lg border" aria-label={label}>
      {steps.map((step) => {
        const choice = plan.find((p) => p.stepId === step.id);
        const people = step.people;
        // Someone this item names who can't sign it now stays listed, with why.
        const stale = choice?.userId
          ? step.unavailable?.find((u) => u.id === choice.userId)
          : undefined;
        return (
          <li key={step.id} className="flex flex-wrap items-center gap-x-3 gap-y-1.5 px-3 py-2">
            <label className="flex min-w-48 flex-1 items-center gap-2 text-sm">
              <input
                type="checkbox"
                className="size-4"
                checked={Boolean(choice)}
                onChange={(e) => onChange(step.id, e.target.checked)}
                aria-label={`Needs ${step.name}`}
              />
              <span className={choice ? "font-medium" : "text-muted-foreground"}>{step.name}</span>
            </label>
            {choice && (
              <SelectNative
                aria-label={`Who signs ${step.name}`}
                value={choice.userId ?? ""}
                onChange={(e) => onChange(step.id, true, e.target.value || null)}
                className="h-8 w-full sm:w-60"
              >
                <option value="">Anyone in {step.departmentName}</option>
                {stale && (
                  <option value={stale.id}>
                    {stale.name} ({stale.reason})
                  </option>
                )}
                {people.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                    {p.jobTitle ? ` — ${p.jobTitle}` : ""}
                    {p.id === step.defaultUserId ? " (main approver)" : ""}
                  </option>
                ))}
              </SelectNative>
            )}
            {stale && (
              <p className="w-full text-xs text-amber-800 dark:text-amber-300">
                {stale.name} can&apos;t sign this off now ({stale.reason.toLowerCase()}) — pick
                someone else, or leave it to anyone in {step.departmentName}.
              </p>
            )}
            {choice && people.length === 0 && (
              <p className="w-full text-xs text-amber-800 dark:text-amber-300">
                No approvers with an account in {step.departmentName} yet — add them under Users →
                Departments.
              </p>
            )}
          </li>
        );
      })}
    </ul>
  );
}

/** Tick, untick or re-assign one department, keeping the admin's order. */
export function updatePlan(
  steps: SignoffStepOption[],
  current: SignoffChoice[],
  stepId: string,
  on: boolean,
  userId?: string | null,
): SignoffChoice[] {
  const rest = current.filter((p) => p.stepId !== stepId);
  if (!on) return rest;
  const step = steps.find((s) => s.id === stepId);
  const existing = current.find((p) => p.stepId === stepId);
  const chosen = userId !== undefined ? userId : (existing?.userId ?? step?.defaultUserId ?? null);
  return steps
    .filter((s) => s.id === stepId || rest.some((p) => p.stepId === s.id))
    .map((s) =>
      s.id === stepId ? { stepId, userId: chosen } : rest.find((p) => p.stepId === s.id)!,
    );
}
