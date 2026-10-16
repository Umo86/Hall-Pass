import { cn } from "@/lib/utils";
import type { EventCountdown } from "./rules";

const TONE: Record<EventCountdown["tone"], string> = {
  planning: "bg-muted text-foreground",
  build_up: "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200",
  open: "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200",
  breakdown: "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200",
  finished: "bg-muted text-muted-foreground",
  archived: "bg-muted text-muted-foreground",
};

/** "Build-up starts in 352 days", "Open now: day 2 of 3". */
export function CountdownPill({ countdown }: { countdown: EventCountdown }) {
  return (
    <span
      className={cn(
        "inline-flex w-fit items-center rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap",
        TONE[countdown.tone],
      )}
    >
      {countdown.label}
    </span>
  );
}
