import Link from "next/link";
import { History } from "lucide-react";
import type { AccessHistoryEntry } from "@/lib/users/history";
import { formatDateTime } from "@/lib/format";

/**
 * A person's access history on their page: every change to who they are
 * and what they can do, newest first — when (London time), who made it, and
 * what changed. The last 20, with "Show all".
 */
export function AccessHistory({
  entries,
  showAllHref,
  showingAll,
}: {
  entries: AccessHistoryEntry[];
  /** Link to the full history, when there may be more. */
  showAllHref: string | null;
  showingAll: boolean;
}) {
  return (
    <section className="space-y-3 rounded-lg border p-4 sm:p-6" aria-labelledby="history-h">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 id="history-h" className="inline-flex items-center gap-1.5 text-sm font-semibold">
          <History className="size-4" aria-hidden />
          Access history
        </h2>
        {showAllHref && !showingAll && (
          <Link href={showAllHref} className="link text-sm" scroll={false}>
            Show all
          </Link>
        )}
      </div>
      {entries.length === 0 ? (
        <p className="text-muted-foreground text-sm">Nothing recorded yet.</p>
      ) : (
        <ol className="divide-y" aria-label="Access history">
          {entries.map((e) => (
            <li key={e.id} className="grid gap-x-4 gap-y-0.5 py-2 text-sm sm:grid-cols-[11rem_1fr]">
              <span className="text-muted-foreground tabular-nums">
                <time dateTime={e.at.toISOString()}>{formatDateTime(e.at)}</time>
              </span>
              <span className="min-w-0 break-words">
                {e.summary}
                <span className="text-muted-foreground"> — {e.actorName}</span>
              </span>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}
