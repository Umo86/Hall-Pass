import Link from "next/link";
import {
  CalendarDays,
  Flag,
  Hammer,
  ImageUp,
  ListTodo,
  PenLine,
  Printer,
  ShoppingCart,
  Tag,
  Truck,
  type LucideIcon,
} from "lucide-react";
import type { CalendarChip, ChipKind, ChipTone } from "@/lib/calendar";
import { cn } from "@/lib/utils";

/** Every deadline is red (solid once it has passed); the rest by type. */
export const TONE_CLASSES: Record<ChipTone, string> = {
  deadline: "bg-red-600 text-white font-medium",
  overdue: "bg-red-900 text-white font-semibold",
  show: "bg-violet-100 text-violet-900 dark:bg-violet-950 dark:text-violet-200",
  delivery: "bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200",
  install: "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200",
};

export const KIND_ICONS: Record<ChipKind, LucideIcon> = {
  event: CalendarDays,
  deadline: Flag,
  artwork: ImageUp,
  print: Printer,
  sell: Tag,
  order: ShoppingCart,
  signoff: PenLine,
  task: ListTodo,
  delivery: Truck,
  install: Hammer,
};

export type ViewChip = CalendarChip & { tone: ChipTone };

/**
 * One thing on the calendar: a small icon for what it is, then the item's
 * name. The full words ("Print deadline: …") are its title and accessible
 * name, with "overdue" added once a deadline has passed.
 */
export function ChipView({ chip, large = false }: { chip: ViewChip; large?: boolean }) {
  const Icon = KIND_ICONS[chip.kind];
  const label = chip.tone === "overdue" ? `${chip.label} — overdue` : chip.label;
  const cls = cn(
    "flex min-w-0 items-center gap-1 rounded px-1 py-0.5",
    large ? "min-h-8 px-2 text-sm leading-5" : "text-[11px] leading-4",
    TONE_CLASSES[chip.tone],
  );
  const body = (
    <>
      <Icon className={cn("shrink-0", large ? "size-4" : "size-3")} aria-hidden />
      <span className="truncate">{chip.name}</span>
    </>
  );
  return chip.href ? (
    <Link
      href={chip.href}
      className={cn(
        cls,
        "focus-visible:ring-ring hover:opacity-85 focus-visible:ring-2 focus-visible:outline-none",
      )}
      title={label}
      aria-label={label}
    >
      {body}
    </Link>
  ) : (
    <span className={cls} title={label} role="img" aria-label={label}>
      {body}
    </span>
  );
}
