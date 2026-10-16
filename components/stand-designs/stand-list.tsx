"use client";

import Link from "next/link";
import { useMemo } from "react";
import { parseAsString, useQueryState } from "nuqs";
import { Box, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusBadge } from "@/components/status-badge";
import { EmptyState } from "@/components/empty-state";
import { STAND_CHIPS, STAND_CHIP_LABELS, type StandChip } from "@/lib/domain/stand-designs";
import { cn } from "@/lib/utils";

export type StandListCard = {
  id: string;
  ref: string;
  name: string;
  status: string;
  href: string;
  standNumber: string | null;
  hallName: string | null;
  sponsorName: string | null;
  size: string | null;
  previewUrl: string | null;
  designVersion: number | null;
  chip: StandChip | null;
  next: { text: string; tone: "action" | "waiting" | "warning" | "done" };
  /** Shown before the design is approved: "2 listed". */
  panelsNote: string | null;
};

const NEXT_TONE = {
  action: "text-foreground font-medium",
  waiting: "text-muted-foreground",
  warning: "text-destructive font-medium",
  done: "text-emerald-700 dark:text-emerald-400",
} as const;

function chipClass(active: boolean) {
  return cn(
    "inline-flex min-h-9 items-center gap-1 rounded-full border px-3 text-sm whitespace-nowrap",
    active ? "bg-foreground text-background border-foreground" : "hover:bg-muted",
  );
}

/**
 * The feature stands as cards, with search (`?q=`) and status chips
 * (`?status=`). Each card says what's next and opens the tab where it's done.
 */
export function StandList({ cards }: { cards: StandListCard[] }) {
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [status, setStatus] = useQueryState("status", parseAsString.withDefault(""));
  const chip = (STAND_CHIPS as readonly string[]).includes(status) ? (status as StandChip) : null;

  const searched = useMemo(() => {
    const words = q.toLowerCase().split(/\s+/).filter(Boolean);
    return cards.filter((c) => {
      const hay = [c.ref, c.name, c.standNumber, c.hallName, c.sponsorName]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return words.every((w) => hay.includes(w));
    });
  }, [cards, q]);
  const shown = chip ? searched.filter((c) => c.chip === chip) : searched;
  const counts = new Map<StandChip, number>();
  for (const c of searched) if (c.chip) counts.set(c.chip, (counts.get(c.chip) ?? 0) + 1);

  return (
    <div className="space-y-3">
      <div className="relative sm:w-72">
        <Search
          className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
          aria-hidden
        />
        <Input
          type="search"
          value={q}
          onChange={(e) => void setQ(e.target.value || null)}
          placeholder="Search name, ref, stand no.…"
          aria-label="Search feature stands"
          className="h-11 pl-8 sm:h-9"
        />
      </div>
      <div className="flex flex-wrap gap-2" role="group" aria-label="Show stands">
        <button
          type="button"
          className={chipClass(!chip)}
          aria-pressed={!chip}
          onClick={() => void setStatus(null)}
        >
          All <span className="opacity-70">({searched.length})</span>
        </button>
        {STAND_CHIPS.filter((k) => counts.get(k) || chip === k).map((k) => (
          <button
            key={k}
            type="button"
            className={chipClass(chip === k)}
            aria-pressed={chip === k}
            onClick={() => void setStatus(k)}
          >
            {STAND_CHIP_LABELS[k]} <span className="opacity-70">({counts.get(k) ?? 0})</span>
          </button>
        ))}
      </div>

      {shown.length === 0 ? (
        <EmptyState
          icon={Box}
          title="No stands match"
          description={
            q
              ? `Nothing matches “${q}”${chip ? ` under ${STAND_CHIP_LABELS[chip]}` : ""}.`
              : undefined
          }
          action={
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                void setQ(null);
                void setStatus(null);
              }}
            >
              Show every stand
            </Button>
          }
        />
      ) : (
        <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3" aria-label="Stands">
          {shown.map((s) => (
            <li key={s.id}>
              <Link
                href={s.href}
                className="hover:border-primary/50 flex h-full flex-col overflow-hidden rounded-lg border transition-colors"
                aria-label={s.name}
              >
                {s.previewUrl ? (
                  <div className="bg-muted flex aspect-[16/9] items-center justify-center overflow-hidden">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={s.previewUrl}
                      alt={`${s.name} design`}
                      loading="lazy"
                      className="size-full object-contain"
                    />
                  </div>
                ) : null}
                <div className="flex flex-1 flex-col gap-2 p-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex min-w-0 items-start gap-3">
                      {!s.previewUrl && (
                        <span className="bg-muted text-muted-foreground flex size-10 shrink-0 items-center justify-center rounded-md">
                          <Box className="size-5" aria-hidden />
                        </span>
                      )}
                      <div className="min-w-0">
                        <p className="truncate font-medium">{s.name}</p>
                        <p className="text-muted-foreground text-xs">
                          {[
                            s.ref,
                            s.standNumber ? `Stand ${s.standNumber}` : null,
                            s.hallName,
                            s.sponsorName,
                          ]
                            .filter(Boolean)
                            .join(" · ")}
                        </p>
                      </div>
                    </div>
                    <StatusBadge status={s.status} />
                  </div>
                  {(s.size || s.designVersion) && (
                    <p className="text-muted-foreground text-xs">
                      {[s.size, s.designVersion ? `Design v${s.designVersion}` : null]
                        .filter(Boolean)
                        .join(" · ")}
                    </p>
                  )}
                  <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t pt-2 text-xs">
                    <span className={NEXT_TONE[s.next.tone]}>{s.next.text}</span>
                    {s.panelsNote && <span className="text-muted-foreground">{s.panelsNote}</span>}
                  </div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
