import Link from "next/link";
import { cn } from "@/lib/utils";
import { CardFooterLink, DashCard } from "./card";
import { lateLabel } from "./rules";
import type { OverdueSignoff } from "@/lib/queries/dashboard";

/**
 * Who the event's open sign-offs are sitting with. Each line opens the
 * Approvals list where they can be chased: that person's or team's
 * sign-offs for the team view (admins, Operations; `row.href`), else the
 * artwork waiting for sign-off (`href`).
 */
const SITTING_ROWS = 8;

export function SittingWithCard({
  rows,
  total,
  href,
}: {
  rows: { label: string; count: number; overdue: number; href?: string }[];
  total: number;
  href: string;
}) {
  const more = rows.length - SITTING_ROWS;
  return (
    <DashCard
      title="Sitting with"
      count={<span className="text-muted-foreground font-normal">({total} open sign-offs)</span>}
      footer={
        more > 0 ? (
          <CardFooterLink href={href}>
            {more} more {more === 1 ? "person or team" : "people and teams"}
          </CardFooterLink>
        ) : null
      }
    >
      {rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">Nothing is waiting on anyone.</p>
      ) : (
        <ul className="-mx-2 text-sm">
          {rows.slice(0, SITTING_ROWS).map((row) => (
            <li key={row.label}>
              <Link
                href={row.href ?? href}
                className="hover:bg-muted/50 flex min-h-9 items-center justify-between gap-3 rounded-md px-2 py-1"
              >
                <span className="min-w-0 truncate">{row.label}</span>
                <span className="flex shrink-0 items-baseline gap-2 tabular-nums">
                  {row.overdue > 0 && (
                    <span className="text-destructive text-xs">{row.overdue} late</span>
                  )}
                  <span className="font-semibold">{row.count}</span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </DashCard>
  );
}

/**
 * Overdue sign-offs, most overdue first (highlighted): the item's name,
 * then its ref, who it is with and how late.
 */
export function OverdueCard({
  rows,
  total,
  seeAllHref,
}: {
  rows: OverdueSignoff[];
  total: number;
  seeAllHref: string;
}) {
  return (
    <DashCard
      title="Overdue sign-offs"
      count={
        total > 0 ? (
          <span className="bg-destructive rounded-full px-1.5 py-0.5 text-xs font-semibold text-white tabular-nums">
            {total}
          </span>
        ) : undefined
      }
      footer={
        total > rows.length ? (
          <CardFooterLink href={seeAllHref}>See all {total} overdue</CardFooterLink>
        ) : null
      }
    >
      {rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">Nothing is overdue.</p>
      ) : (
        <ul className="-mx-2 space-y-0.5 text-sm">
          {rows.map((row, i) => (
            <li key={row.id}>
              <Link
                href={row.href}
                title={`${row.stepName} — ${row.name}`}
                className={cn(
                  "hover:bg-muted/50 block rounded-md px-2 py-1.5",
                  i === 0 && "bg-destructive/5 hover:bg-destructive/10",
                )}
              >
                <span className="block truncate font-medium">{row.name}</span>
                <span className="text-muted-foreground block truncate text-xs">
                  {row.ref} · with {row.waitingOn} ·{" "}
                  <span className="text-destructive">{lateLabel(row.daysLate)}</span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </DashCard>
  );
}
