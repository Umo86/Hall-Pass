"use client";

import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { MoreHorizontal, Search } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useConfirm } from "@/components/confirm-dialog";
import { setEditionArchived } from "@/app/actions/editions";
import { cn } from "@/lib/utils";

export type EventPhaseKey =
  "planning" | "build_up" | "open" | "breakdown" | "finished" | "archived";

export type EventCard = {
  id: string;
  code: string;
  name: string;
  /** Where the card goes: setup while essentials are missing, else the dashboard. */
  href: string;
  /** "Open 5–7 Oct 2027 · NEC Birmingham". */
  line: string;
  series: string;
  phase: EventPhaseKey;
  phaseLabel: string;
  setup: { done: number; total: number } | null;
  logoUrl: string | null;
  archived: boolean;
};

const PHASE_CLASSES: Record<EventPhaseKey, string> = {
  planning: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  build_up: "bg-amber-50 text-amber-800 dark:bg-amber-950 dark:text-amber-300",
  open: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  breakdown: "bg-violet-50 text-violet-800 dark:bg-violet-950 dark:text-violet-300",
  finished: "bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300",
  archived: "bg-neutral-200 text-neutral-700 dark:bg-neutral-700 dark:text-neutral-200",
};

function PhaseBadge({ phase, label }: { phase: EventPhaseKey; label: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        PHASE_CLASSES[phase],
      )}
    >
      {label}
    </span>
  );
}

function CardMenu({
  event,
  canArchive,
  confirm,
}: {
  event: EventCard;
  canArchive: boolean;
  confirm: ReturnType<typeof useConfirm>[1];
}) {
  const router = useRouter();
  const [pending, start] = useTransition();

  async function archive(archived: boolean) {
    const ok = await confirm(
      archived
        ? {
            title: `Archive ${event.name}?`,
            description:
              "It becomes read-only for everyone: nothing in it can be changed until a super admin brings it back. It moves to the Archived list.",
            confirmLabel: "Archive event",
            destructive: true,
          }
        : {
            title: `Bring back ${event.name}?`,
            description: "People can change its signs, sign-offs and details again.",
            confirmLabel: "Bring it back",
          },
    );
    if (!ok) return;
    start(async () => {
      const res = await setEditionArchived({ id: event.id, archived });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? "Saved");
      router.refresh();
    });
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="relative z-10 size-8"
          aria-label={`More for ${event.name}`}
          disabled={pending}
        >
          <MoreHorizontal aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-48">
        {!event.archived && (
          <DropdownMenuItem asChild>
            <Link href={`/${event.code}/setup#details`}>Edit details</Link>
          </DropdownMenuItem>
        )}
        <DropdownMenuItem asChild>
          <Link href={`/${event.code}/dashboard`}>Open dashboard</Link>
        </DropdownMenuItem>
        {canArchive && (
          <>
            <DropdownMenuSeparator />
            {event.archived ? (
              <DropdownMenuItem onSelect={() => void archive(false)}>Bring back…</DropdownMenuItem>
            ) : (
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onSelect={() => void archive(true)}
              >
                Archive event…
              </DropdownMenuItem>
            )}
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/**
 * The organisation's events as cards (compact rows on a phone). The whole
 * card opens the event; setup people get a small menu.
 */
export function EventsList({
  events,
  canSetup,
  canArchive,
  emptyText,
}: {
  events: EventCard[];
  canSetup: boolean;
  canArchive: boolean;
  emptyText: string;
}) {
  const [query, setQuery] = useState("");
  const [confirmDialog, confirm] = useConfirm();
  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return events;
    return events.filter((e) =>
      [e.name, e.code, e.line, e.series].some((v) => v.toLowerCase().includes(q)),
    );
  }, [events, query]);

  return (
    <div className="space-y-3">
      {confirmDialog}
      {events.length > 6 && (
        <div className="relative max-w-sm">
          <Search
            className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
            aria-hidden
          />
          <Input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by name, code or venue"
            aria-label="Search events"
            className="pl-8"
          />
        </div>
      )}
      {shown.length === 0 ? (
        <p className="text-muted-foreground rounded-lg border border-dashed p-6 text-center text-sm">
          {events.length === 0 ? emptyText : `No events match “${query}”.`}
        </p>
      ) : (
        <ul className="grid gap-2 sm:gap-3 md:grid-cols-2 xl:grid-cols-3">
          {shown.map((e) => (
            <li
              key={e.id}
              className="hover:bg-muted/40 focus-within:ring-ring relative flex items-start gap-3 rounded-lg border p-3 focus-within:ring-2 sm:p-4"
            >
              <div className="bg-muted/40 hidden size-12 shrink-0 items-center justify-center overflow-hidden rounded-md border sm:flex">
                {e.logoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={e.logoUrl} alt="" className="max-h-full max-w-full object-contain" />
                ) : (
                  <span className="text-muted-foreground text-xs font-semibold">
                    {e.code.slice(0, 4)}
                  </span>
                )}
              </div>
              <div className="min-w-0 flex-1 space-y-1">
                <Link
                  href={e.href}
                  className="block truncate font-semibold outline-none after:absolute after:inset-0 after:rounded-lg"
                >
                  {e.name}
                </Link>
                <p className="text-muted-foreground truncate text-sm">{e.line}</p>
                <div className="flex flex-wrap items-center gap-1.5 pt-0.5">
                  <PhaseBadge phase={e.phase} label={e.phaseLabel} />
                  {e.setup && e.setup.done < e.setup.total && (
                    <span className="inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-medium tabular-nums">
                      Setup {e.setup.done}/{e.setup.total}
                    </span>
                  )}
                  <span className="text-muted-foreground font-mono text-xs">{e.code}</span>
                </div>
              </div>
              {canSetup && <CardMenu event={e} canArchive={canArchive} confirm={confirm} />}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
