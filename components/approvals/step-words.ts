/**
 * The words for sign-off steps, decided once and used everywhere a step is
 * shown (Approvals, the item's chain, the review sheet, the portal). Pure, so
 * it is unit tested and safe in client components.
 */
import { diffDaysIso } from "@/lib/deadlines";
import { todayInLondon } from "@/lib/today";

/** What a step's state is called; "pending" depends on who it is with. */
export function stepStateLabel(status: string, who?: string | null): string {
  switch (status) {
    case "pending":
      return who ? `Waiting on ${who}` : "Their turn";
    case "waiting":
      return "Not started";
    case "approved":
      return "Approved";
    case "approved_with_conditions":
      return "Approved (conditions)";
    case "changes_requested":
      return "Changes requested";
    case "rejected":
      return "Rejected";
    case "confirmed":
      return "Confirmed";
    case "invalidated":
      return "Superseded";
    case "skipped":
      return "Skipped";
    default:
      return status.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase());
  }
}

/** One colour per step state, always shown with its words. */
export const STEP_STATE_CLASSES: Record<string, string> = {
  pending: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  waiting: "bg-neutral-100 text-neutral-600 dark:bg-neutral-800 dark:text-neutral-400",
  approved: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  approved_with_conditions: "bg-teal-50 text-teal-800 dark:bg-teal-950 dark:text-teal-300",
  confirmed: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  changes_requested: "bg-orange-50 text-orange-800 dark:bg-orange-950 dark:text-orange-300",
  rejected: "bg-red-50 text-red-800 dark:bg-red-950 dark:text-red-300",
  invalidated: "bg-neutral-100 text-neutral-500 dark:bg-neutral-800 dark:text-neutral-400",
  skipped: "bg-neutral-50 text-neutral-500 dark:bg-neutral-900 dark:text-neutral-400",
};

/** Text colour for a step's one-line status (e.g. on artwork tiles). */
export const STEP_STATE_TONE: Record<string, string> = {
  pending: "text-sky-700 dark:text-sky-400",
  waiting: "text-muted-foreground",
  approved: "text-emerald-700 dark:text-emerald-400",
  approved_with_conditions: "text-teal-700 dark:text-teal-400",
  confirmed: "text-emerald-700 dark:text-emerald-400",
  changes_requested: "text-orange-700 dark:text-orange-400",
  rejected: "text-destructive",
  invalidated: "text-muted-foreground",
  skipped: "text-muted-foreground",
};

/** A sign-off is a decision on the artwork; a confirmation records that something happened. */
export function stepKindLabel(kind: string): string {
  return kind === "confirmation" ? "Confirmation" : "Sign-off";
}

/**
 * Who a step is with, in words: a named person, else the department, else
 * the role ("Operations", "Venue"). Null when nothing is known.
 */
export function waitingOnLabel(step: {
  assigneeName?: string | null;
  assignedUserId?: string | null;
  departmentName?: string | null;
  roleName?: string | null;
}): string | null {
  if (step.assignedUserId || step.assigneeName) return step.assigneeName || "a named person";
  if (step.departmentName) return step.departmentName;
  return step.roleName || null;
}

/** True when the moment has passed (a due date that is now overdue). */
export function isPast(at: Date | string | null | undefined, now: number = Date.now()): boolean {
  if (!at) return false;
  return (typeof at === "string" ? new Date(at) : at).getTime() < now;
}

/** Whole days a due date is behind today (London); 0 when due earlier today. */
export function daysOverdue(dueAt: Date | string, today: string = todayInLondon()): number {
  const due = typeof dueAt === "string" ? new Date(dueAt) : dueAt;
  return Math.max(0, diffDaysIso(today, todayInLondon(due)));
}

/** "Overdue", "Overdue 1 day", "Overdue 21 days". */
export function overdueLabel(days: number): string {
  if (days <= 0) return "Overdue";
  return `Overdue ${days} day${days === 1 ? "" : "s"}`;
}

export type DecisionKind =
  "approve" | "approve_with_conditions" | "request_changes" | "reject" | "confirm";

/** The toast after a decision: "Approved — Marketing sign-off", "Delivered confirmed". */
export function decisionToast(kind: DecisionKind, stepName: string): string {
  switch (kind) {
    case "approve":
      return `Approved — ${stepName}`;
    case "approve_with_conditions":
      return `Approved with conditions — ${stepName}`;
    case "request_changes":
      return `Changes requested — ${stepName}`;
    case "reject":
      return `Rejected — ${stepName}`;
    case "confirm":
      return `${stepName} confirmed`;
  }
}

export type BulkResult = { ref: string; ok: boolean; error?: string; needsPhoto?: boolean };

/** "12 confirmed, 1 needs a photo, 1 couldn't be confirmed". */
export function bulkConfirmSummary(results: BulkResult[]): string {
  const done = results.filter((r) => r.ok).length;
  const photo = results.filter((r) => !r.ok && r.needsPhoto).length;
  const failed = results.filter((r) => !r.ok && !r.needsPhoto).length;
  const parts = [`${done} confirmed`];
  if (photo > 0) parts.push(`${photo} need${photo === 1 ? "s" : ""} a photo`);
  if (failed > 0) parts.push(`${failed} couldn't be confirmed`);
  return parts.join(", ");
}
