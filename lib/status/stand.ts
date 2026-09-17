/**
 * Stand submission status machine (brief 5.2). Pure function.
 */
import { IllegalTransitionError } from "./signage";

export type StandStatus =
  | "not_submitted"
  | "submitted"
  | "in_review"
  | "changes_requested"
  | "approved"
  | "approved_with_conditions"
  | "rejected"
  | "build_checked"
  | "closed"
  | "on_hold";

export type StandEvent =
  | "submit" // requires required docs + max height; moves to in_review immediately
  | "changes_requested"
  | "outcome_approved"
  | "outcome_approved_with_conditions"
  | "outcome_rejected"
  | "resubmit"
  | "build_check"
  | "close" // when the edition closes
  | "hold"
  | "resume";

export type StandContext = {
  requiredDocsPresent?: boolean;
  maxHeightSet?: boolean;
  /** Mandatory when conditions existed on the outcome. */
  buildCheckNotes?: string | null;
  hadConditions?: boolean;
  previousStatus?: StandStatus | null;
};

export function standTransition(
  current: StandStatus,
  event: StandEvent,
  ctx: StandContext = {},
): StandStatus {
  if (event === "hold") {
    if (current === "closed" || current === "on_hold") {
      throw new IllegalTransitionError(current, event);
    }
    return "on_hold";
  }
  if (event === "resume") {
    if (current !== "on_hold") throw new IllegalTransitionError(current, event);
    if (!ctx.previousStatus) throw new IllegalTransitionError(current, `${event} (no previous status)`);
    return ctx.previousStatus;
  }

  switch (current) {
    case "not_submitted":
      if (event === "submit") {
        if (!ctx.requiredDocsPresent) {
          throw new IllegalTransitionError(current, `${event} (required documents missing)`);
        }
        if (!ctx.maxHeightSet) {
          throw new IllegalTransitionError(current, `${event} (max height not set)`);
        }
        // "Moves to in_review immediately" — submitted is a recorded moment,
        // the resting status is in_review.
        return "in_review";
      }
      break;
    case "submitted":
      // Transitional status; kept for completeness if persisted mid-flight.
      if (event === "changes_requested") return "changes_requested";
      break;
    case "in_review":
      if (event === "changes_requested") return "changes_requested";
      if (event === "outcome_approved") return "approved";
      if (event === "outcome_approved_with_conditions") return "approved_with_conditions";
      if (event === "outcome_rejected") return "rejected";
      break;
    case "changes_requested":
      if (event === "resubmit") {
        if (!ctx.requiredDocsPresent) {
          throw new IllegalTransitionError(current, `${event} (required documents missing)`);
        }
        return "in_review";
      }
      break;
    case "approved":
    case "approved_with_conditions":
      if (event === "build_check") {
        if (ctx.hadConditions && !ctx.buildCheckNotes) {
          throw new IllegalTransitionError(current, `${event} (notes mandatory when conditions exist)`);
        }
        return "build_checked";
      }
      break;
    case "rejected":
      if (event === "resubmit") {
        if (!ctx.requiredDocsPresent) {
          throw new IllegalTransitionError(current, `${event} (required documents missing)`);
        }
        return "in_review";
      }
      break;
    case "build_checked":
      if (event === "close") return "closed";
      break;
    case "closed":
    case "on_hold":
      break;
  }
  throw new IllegalTransitionError(current, event);
}

/** Complexity computation (brief 4.6): any trigger true, or max height > 4000 mm. */
export function computeIsComplex(sub: {
  isDoubleDeck: boolean;
  hasPlatformOver600mm: boolean;
  hasRampedRaisedFloor: boolean;
  hasRigging: boolean;
  hasCeilingOrRoof: boolean;
  hasTieredSeating: boolean;
  maxHeightMm: number | null;
}): boolean {
  return (
    sub.isDoubleDeck ||
    sub.hasPlatformOver600mm ||
    sub.hasRampedRaisedFloor ||
    sub.hasRigging ||
    sub.hasCeilingOrRoof ||
    sub.hasTieredSeating ||
    (sub.maxHeightMm != null && sub.maxHeightMm > 4000)
  );
}
