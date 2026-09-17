import { cn } from "@/lib/utils";
import { statusLabel } from "@/lib/format";

/**
 * One colour token per status, used consistently in badges, Kanban columns
 * and floorplan pins — always with the status text (never colour alone).
 */
const STATUS_CLASSES: Record<string, string> = {
  draft: "bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300",
  not_submitted: "bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300",
  awaiting_artwork: "bg-amber-50 text-amber-800 dark:bg-amber-950 dark:text-amber-300",
  submitted: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  in_review: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  pending: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  waiting: "bg-neutral-100 text-neutral-600 dark:bg-neutral-800 dark:text-neutral-400",
  changes_requested: "bg-orange-50 text-orange-800 dark:bg-orange-950 dark:text-orange-300",
  approved: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  approved_with_conditions: "bg-teal-50 text-teal-800 dark:bg-teal-950 dark:text-teal-300",
  confirmed: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  in_production: "bg-violet-50 text-violet-800 dark:bg-violet-950 dark:text-violet-300",
  delivered: "bg-indigo-50 text-indigo-800 dark:bg-indigo-950 dark:text-indigo-300",
  installed: "bg-green-50 text-green-800 dark:bg-green-950 dark:text-green-300",
  build_checked: "bg-green-50 text-green-800 dark:bg-green-950 dark:text-green-300",
  snagged: "bg-rose-50 text-rose-800 dark:bg-rose-950 dark:text-rose-300",
  closed: "bg-neutral-200 text-neutral-700 dark:bg-neutral-700 dark:text-neutral-200",
  rejected: "bg-red-50 text-red-800 dark:bg-red-950 dark:text-red-300",
  invalidated: "bg-neutral-100 text-neutral-400 line-through dark:bg-neutral-800",
  skipped: "bg-neutral-50 text-neutral-400 dark:bg-neutral-900",
  on_hold: "bg-yellow-50 text-yellow-800 dark:bg-yellow-950 dark:text-yellow-300",
  open: "bg-rose-50 text-rose-800 dark:bg-rose-950 dark:text-rose-300",
  resolved: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
};

export function StatusBadge({ status, className }: { status: string; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        STATUS_CLASSES[status] ?? STATUS_CLASSES.draft,
        className,
      )}
    >
      {statusLabel(status)}
    </span>
  );
}
