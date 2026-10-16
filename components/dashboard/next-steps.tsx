import Link from "next/link";
import { CheckCircle2, ChevronRight, Gift, ListTodo, PenLine, Truck } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";
import type { NextStepRow } from "./rules";

const ICONS: Record<NextStepRow["key"], LucideIcon> = {
  signoffs: PenLine,
  tasks: ListTodo,
  sponsorship: Gift,
  onsite: Truck,
};

/**
 * "Your next steps": what is waiting on the person looking, for this
 * event only, each line going straight to the work.
 */
export function NextSteps({
  rows,
  eventName,
  setupPending = false,
}: {
  rows: NextStepRow[];
  eventName: string;
  /** The setup card is showing above, so "all caught up" would be untrue. */
  setupPending?: boolean;
}) {
  return (
    <section aria-labelledby="next-steps-title" className="rounded-lg border p-4">
      <h2 id="next-steps-title" className="mb-2 text-sm font-semibold">
        Your next steps
      </h2>
      {rows.length === 0 ? (
        <p className="text-muted-foreground flex items-center gap-2 text-sm">
          <CheckCircle2 className="size-4 shrink-0 text-emerald-600" aria-hidden />
          {setupPending
            ? `Nothing else is waiting on you on ${eventName}.`
            : `You're all caught up on ${eventName}.`}
        </p>
      ) : (
        <ul className="-mx-2 divide-y">
          {rows.map((row) => {
            const Icon = ICONS[row.key];
            return (
              <li key={row.key}>
                <Link
                  href={row.href}
                  className="hover:bg-muted/50 focus-visible:ring-ring flex min-h-11 items-center gap-3 rounded-md px-2 py-2 text-sm focus-visible:ring-2 focus-visible:outline-none"
                >
                  <span
                    className={cn(
                      "flex size-8 shrink-0 items-center justify-center rounded-full",
                      row.urgent
                        ? "bg-destructive/10 text-destructive"
                        : "bg-muted text-muted-foreground",
                    )}
                  >
                    <Icon className="size-4" aria-hidden />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="font-medium">{row.text}</span>
                    {row.detail && (
                      <span
                        className={cn(
                          "block text-xs sm:ml-2 sm:inline",
                          row.urgent ? "text-destructive font-medium" : "text-muted-foreground",
                        )}
                      >
                        {row.detail}
                      </span>
                    )}
                  </span>
                  <ChevronRight className="text-muted-foreground size-4 shrink-0" aria-hidden />
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
