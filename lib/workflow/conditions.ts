import type { EngineSettings, EntityCtx, WorkflowCondition } from "./types";

/**
 * Condition semantics (brief 6.1). Conditions on a step have any-of
 * semantics: the step applies if at least one condition evaluates true.
 */
export function evaluateCondition(
  condition: WorkflowCondition,
  entity: EntityCtx,
  settings: EngineSettings,
): boolean {
  switch (condition) {
    case "always":
      return true;
    case "if_sponsored":
      return entity.kind === "signage" && entity.sponsorId != null;
    case "if_requires_venue_approval":
      return entity.kind === "signage" && entity.requiresVenueApproval;
    case "if_requires_event_director":
      return entity.kind === "signage" && entity.requiresEventDirector;
    case "if_cost_over_threshold":
      return (
        entity.kind === "signage" &&
        entity.costEstimate != null &&
        entity.costEstimate > settings.costThresholdForDirector
      );
    case "if_rigged":
      return entity.kind === "signage" && entity.fixingMethod === "rigged";
    case "if_complex_structure":
      return entity.kind === "stand" && entity.isComplex;
    case "if_venue_requires_stand_approval":
      return entity.kind === "stand" && entity.venueRequiresStandApproval;
  }
}

export function stepApplies(
  conditions: WorkflowCondition[],
  entity: EntityCtx,
  settings: EngineSettings,
): boolean {
  if (conditions.length === 0) return true;
  return conditions.some((c) => evaluateCondition(c, entity, settings));
}
