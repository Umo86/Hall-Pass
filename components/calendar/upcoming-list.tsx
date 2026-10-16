"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import type { DayGroup } from "@/lib/calendar";
import { ChipView, type ViewChip } from "./chip";

const STEP = 7;

/**
 * The next 30 days as a list (phones by default): Today, Tomorrow, then
 * each day with something on, a week's worth of days at a time.
 */
export function UpcomingList({
  groups,
  monthHref,
}: {
  groups: DayGroup<ViewChip>[];
  monthHref: string;
}) {
  const [shown, setShown] = useState(STEP);
  if (groups.length === 0) {
    return (
      <p className="text-muted-foreground rounded-lg border border-dashed p-4 text-sm">
        Nothing in the next 30 days.{" "}
        <Link href={monthHref} className="link">
          See the month
        </Link>
      </p>
    );
  }
  const visible = groups.slice(0, shown);
  return (
    <div className="space-y-3">
      <ol className="space-y-3" aria-label="Coming up in the next 30 days">
        {visible.map((g) => (
          <li key={g.date} className="rounded-lg border p-3">
            <h3
              className={
                g.heading === "Today"
                  ? "text-primary mb-2 text-sm font-semibold"
                  : "mb-2 text-sm font-medium"
              }
            >
              {g.heading}
            </h3>
            <div className="flex flex-col gap-1">
              {g.chips.map((chip, i) => (
                <ChipView key={`${chip.label}-${i}`} chip={chip} large />
              ))}
            </div>
          </li>
        ))}
      </ol>
      {shown < groups.length ? (
        <Button
          type="button"
          variant="outline"
          className="w-full"
          onClick={() => setShown((n) => n + STEP)}
        >
          Show more ({groups.length - shown} more {groups.length - shown === 1 ? "day" : "days"})
        </Button>
      ) : (
        <p className="text-muted-foreground text-center text-xs">
          That&apos;s the next 30 days.{" "}
          <Link href={monthHref} className="link">
            See the month
          </Link>
        </p>
      )}
    </div>
  );
}
