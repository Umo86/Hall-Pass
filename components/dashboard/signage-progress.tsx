import Link from "next/link";
import { ChevronDown } from "lucide-react";
import { StatusBadge } from "@/components/status-badge";
import { plural } from "@/lib/format";
import { cn } from "@/lib/utils";
import type { StageProgress } from "./rules";

/** One colour per stage, always shown with its name. */
const STAGE_COLOUR: Record<StageProgress["key"], string> = {
  getting_ready: "bg-slate-400 dark:bg-slate-500",
  in_signoff: "bg-amber-500",
  production: "bg-sky-600",
  onsite: "bg-emerald-600",
};

/**
 * Signage progress: one bar across the four stages, each stage a link to
 * the list filtered to it, Rejected as a footnote, and the per-status
 * counts behind a disclosure.
 */
export function SignageProgress({
  code,
  total,
  stages,
  rejected,
}: {
  code: string;
  total: number;
  stages: StageProgress[];
  rejected: number;
}) {
  const list = `/${code}/signage`;
  return (
    <div className="flex flex-col gap-4">
      <div
        className="bg-muted flex h-3 w-full overflow-hidden rounded-full"
        role="img"
        aria-label={stages.map((s) => `${s.label}: ${s.count}`).join(", ")}
      >
        {stages
          .filter((s) => s.count > 0)
          .map((s) => (
            <div
              key={s.key}
              className={cn("h-full", STAGE_COLOUR[s.key])}
              style={{ width: `${(s.count / Math.max(total, 1)) * 100}%` }}
              title={`${s.label}: ${s.count}`}
            />
          ))}
      </div>

      <ul className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        {stages.map((s) => (
          <li key={s.key}>
            <Link
              href={`${list}?stage=${s.key}`}
              className="hover:bg-muted/50 focus-visible:ring-ring flex h-full flex-col gap-1 rounded-md border px-3 py-2 focus-visible:ring-2 focus-visible:outline-none"
            >
              <span className="text-muted-foreground flex items-center gap-1.5 text-xs font-medium">
                <span className={cn("size-2.5 shrink-0 rounded-full", STAGE_COLOUR[s.key])} />
                {s.label}
              </span>
              <span className="flex items-baseline gap-1.5">
                <span className="text-lg font-semibold tabular-nums">{s.count}</span>
                <span className="text-muted-foreground text-xs tabular-nums">{s.pct}%</span>
              </span>
            </Link>
          </li>
        ))}
      </ul>

      {rejected > 0 && (
        <p className="text-muted-foreground text-xs">
          <Link href={`${list}?status=rejected`} className="hover:text-foreground underline">
            {plural(rejected, "item")} rejected
          </Link>{" "}
          — not counted above.
        </p>
      )}

      <details className="group">
        <summary className="text-muted-foreground hover:text-foreground inline-flex cursor-pointer list-none items-center gap-1 text-sm select-none [&::-webkit-details-marker]:hidden">
          <ChevronDown className="size-4 transition-transform group-open:rotate-180" aria-hidden />
          Signage by status
        </summary>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {stages
            .filter((s) => s.statuses.length > 0)
            .map((s) => (
              <div key={s.key}>
                <p className="text-muted-foreground mb-1.5 text-xs font-medium">{s.label}</p>
                <div className="flex flex-wrap gap-1.5">
                  {s.statuses.map(({ status, count }) => (
                    <Link
                      key={status}
                      href={`${list}?status=${status}`}
                      className="hover:bg-muted/50 flex items-center gap-1.5 rounded-md border px-2 py-1"
                    >
                      <StatusBadge status={status} />
                      <span className="text-sm font-semibold tabular-nums">{count}</span>
                    </Link>
                  ))}
                </div>
              </div>
            ))}
        </div>
      </details>
    </div>
  );
}
