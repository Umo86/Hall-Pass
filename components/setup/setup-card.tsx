"use client";

import { useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ListChecks } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { confirmSetupStep } from "@/app/actions/editions";

/**
 * The dashboard's "Finish setting up" card, shown to admins and Operations
 * until every essential step is done (or they hide it).
 */
export function SetupCard({
  editionId,
  code,
  done,
  total,
  next,
}: {
  editionId: string;
  code: string;
  done: number;
  total: number;
  next: { key: string; title: string } | null;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  return (
    <section
      aria-labelledby="setup-card-title"
      className="flex flex-col gap-3 rounded-lg border border-sky-200 bg-sky-50/60 p-4 sm:flex-row sm:items-center dark:border-sky-900 dark:bg-sky-950/40"
    >
      <span className="hidden size-9 shrink-0 items-center justify-center rounded-full bg-sky-100 text-sky-800 sm:flex dark:bg-sky-900 dark:text-sky-200">
        <ListChecks className="size-4" aria-hidden />
      </span>
      <div className="min-w-0 flex-1 space-y-1.5">
        <h2 id="setup-card-title" className="text-sm font-semibold">
          Finish setting up — {done} of {total} done
        </h2>
        <div
          className="h-1.5 w-full max-w-sm overflow-hidden rounded-full bg-sky-100 dark:bg-sky-900"
          role="progressbar"
          aria-label="Setup progress"
          aria-valuemin={0}
          aria-valuemax={total}
          aria-valuenow={done}
        >
          <div className="h-full rounded-full bg-sky-600" style={{ width: `${pct}%` }} />
        </div>
        {next && <p className="text-muted-foreground text-sm">Next: {next.title}</p>}
      </div>
      <div className="flex items-center gap-2">
        <Button asChild className="flex-1 sm:flex-none">
          <Link href={`/${code}/setup${next ? `#${next.key}` : ""}`}>Continue</Link>
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          disabled={pending}
          onClick={() =>
            start(async () => {
              const res = await confirmSetupStep({ editionId, key: "dismissed" });
              if (!res.ok) {
                toast.error(res.error);
                return;
              }
              toast.success(res.message ?? "Hidden");
              router.refresh();
            })
          }
        >
          Hide
        </Button>
      </div>
    </section>
  );
}
