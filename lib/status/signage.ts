/**
 * Signage item status machine (brief 5.1). Pure function: given the current
 * status, an event and context, returns the next status or throws.
 */

export type SignageStatus =
  | "draft"
  | "awaiting_artwork"
  | "in_review"
  | "changes_requested"
  | "approved"
  | "approved_with_conditions"
  | "in_production"
  | "delivered"
  | "installed"
  | "snagged"
  | "closed"
  | "rejected"
  | "on_hold";

export type SignageEvent =
  | "submit_for_review" // from draft; context decides awaiting_artwork vs in_review
  | "artwork_uploaded" // first upload while awaiting_artwork starts the review
  | "changes_requested"
  | "rejected"
  | "run_approved" // all steps positive, no conditions anywhere
  | "run_approved_with_conditions"
  | "resubmit"
  | "sent_to_print"
  | "delivered"
  | "installed"
  | "snag_opened"
  | "snags_cleared"
  | "close"
  | "reopen" // from rejected, admin/ops
  | "new_version_after_approval" // invalidation returns the item to review
  | "hold"
  | "resume";

export type SignageContext = {
  hasArtwork?: boolean;
  /** Status stored when the item was put on hold. */
  previousStatus?: SignageStatus | null;
};

export class IllegalTransitionError extends Error {
  constructor(
    public readonly from: string,
    public readonly event: string,
  ) {
    super(`Illegal transition: ${event} is not allowed from ${from}`);
    this.name = "IllegalTransitionError";
  }
}

export const TERMINAL_SIGNAGE_STATUSES: SignageStatus[] = ["closed"];

/** Statuses from which a new artwork version triggers invalidation + return to review. */
export const INVALIDATABLE_STATUSES: SignageStatus[] = [
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
];

export function signageTransition(
  current: SignageStatus,
  event: SignageEvent,
  ctx: SignageContext = {},
): SignageStatus {
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
    case "draft":
      if (event === "submit_for_review") return ctx.hasArtwork ? "in_review" : "awaiting_artwork";
      break;
    case "awaiting_artwork":
      if (event === "artwork_uploaded") return "in_review";
      break;
    case "in_review":
      if (event === "changes_requested") return "changes_requested";
      if (event === "rejected") return "rejected";
      if (event === "run_approved") return "approved";
      if (event === "run_approved_with_conditions") return "approved_with_conditions";
      break;
    case "changes_requested":
      if (event === "resubmit") return "in_review";
      break;
    case "approved":
    case "approved_with_conditions":
      if (event === "sent_to_print") return "in_production";
      if (event === "new_version_after_approval") return "in_review";
      break;
    case "in_production":
      if (event === "delivered") return "delivered";
      if (event === "new_version_after_approval") return "in_review";
      break;
    case "delivered":
      if (event === "installed") return "installed";
      if (event === "new_version_after_approval") return "in_review";
      break;
    case "installed":
      if (event === "snag_opened") return "snagged";
      if (event === "close") return "closed";
      break;
    case "snagged":
      if (event === "snags_cleared") return "installed";
      break;
    case "rejected":
      if (event === "reopen") return "draft";
      break;
    case "closed":
    case "on_hold":
      break;
  }
  throw new IllegalTransitionError(current, event);
}
