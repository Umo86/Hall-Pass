import { describe, expect, it } from "vitest";
import {
  defaultSignageSteps,
  defaultSignoffs,
  effectiveSignoffs,
  isDepartmentStep,
  sameSignoffs,
} from "@/lib/workflow";

const ids = (plan: { stepId: string }[]) => plan.map((p) => p.stepId).sort();

describe("sign-off defaults", () => {
  it("only approval steps with defaults are departments", () => {
    const departments = defaultSignageSteps.filter(isDepartmentStep).map((s) => s.name);
    expect(departments).toEqual([
      "Operations sign-off",
      "Marketing sign-off",
      "Sales sign-off",
      "Senior management sign-off",
    ]);
  });

  it("organiser signage: Operations, Marketing, Senior management", () => {
    expect(ids(defaultSignoffs(defaultSignageSteps, "organiser"))).toEqual(
      ["sig-marketing", "sig-ops", "sig-senior"].sort(),
    );
  });

  it("sponsor signage adds Sales; no category means organiser", () => {
    expect(ids(defaultSignoffs(defaultSignageSteps, "sponsor"))).toContain("sig-sales");
    expect(ids(defaultSignoffs(defaultSignageSteps, null))).not.toContain("sig-sales");
  });

  it("a step's default person comes with the default", () => {
    const steps = defaultSignageSteps.map((s) =>
      s.id === "sig-senior" ? { ...s, approverType: "user" as const, approverUserId: "dana" } : s,
    );
    const senior = defaultSignoffs(steps, "organiser").find((p) => p.stepId === "sig-senior");
    expect(senior?.userId).toBe("dana");
  });

  it("an item's own choices win, and unknown steps are dropped", () => {
    const plan = [
      { stepId: "sig-marketing", userId: "u1" },
      { stepId: "gone", userId: null },
    ];
    expect(effectiveSignoffs(defaultSignageSteps, "organiser", plan)).toEqual([
      { stepId: "sig-marketing", userId: "u1" },
    ]);
    expect(effectiveSignoffs(defaultSignageSteps, "organiser", null)).toHaveLength(3);
  });

  it("compares plans regardless of order", () => {
    const a = [
      { stepId: "x", userId: null },
      { stepId: "y", userId: "u" },
    ];
    expect(sameSignoffs(a, [...a].reverse())).toBe(true);
    expect(sameSignoffs(a, [{ stepId: "x", userId: null }])).toBe(false);
    expect(sameSignoffs(a, [a[0], { stepId: "y", userId: "v" }])).toBe(false);
  });
});
