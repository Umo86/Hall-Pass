import { AlertTriangle, CheckCircle2, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import type { StatusLine as Status } from "./system-status";

const STYLE = {
  ok: {
    icon: CheckCircle2,
    box: "border-emerald-200 bg-emerald-50/60 dark:border-emerald-900 dark:bg-emerald-950/40",
    tint: "text-emerald-700 dark:text-emerald-400",
  },
  warn: {
    icon: AlertTriangle,
    box: "border-amber-300 bg-amber-50/70 dark:border-amber-800 dark:bg-amber-950/40",
    tint: "text-amber-700 dark:text-amber-400",
  },
  error: {
    icon: XCircle,
    box: "border-red-300 bg-red-50/70 dark:border-red-900 dark:bg-red-950/40",
    tint: "text-red-700 dark:text-red-400",
  },
} as const;

/** One plain-language status: an icon, what it means, and what to do. */
export function StatusLine({ label, status }: { label: string; status: Status }) {
  const s = STYLE[status.tone];
  const Icon = s.icon;
  return (
    <section
      aria-label={label}
      className={cn("flex gap-3 rounded-lg border p-4", s.box)}
      role={status.tone === "error" ? "alert" : undefined}
    >
      <Icon className={cn("mt-0.5 size-5 shrink-0", s.tint)} aria-hidden />
      <div className="min-w-0 space-y-0.5">
        <p className="text-muted-foreground text-xs font-medium tracking-wide uppercase">{label}</p>
        <p className="font-medium">{status.title}</p>
        <p className="text-muted-foreground text-sm">{status.detail}</p>
      </div>
    </section>
  );
}
