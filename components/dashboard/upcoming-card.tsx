import Link from "next/link";
import { shortDay } from "@/lib/calendar";
import { CardFooterLink, DashCard } from "./card";
import type { UpcomingDeadline } from "@/lib/queries/dashboard";

/**
 * Deadlines in the next 7 days: event deadlines say how much is left and
 * open the work they are about; item dates open the item.
 */
export function UpcomingCard({
  rows,
  total,
  today,
  calendarHref,
  canOpen,
}: {
  rows: UpcomingDeadline[];
  total: number;
  today: string;
  /** Null when the viewer has no Calendar. */
  calendarHref: string | null;
  /** Can this person open a link to that section? */
  canOpen: (feature: UpcomingDeadline["feature"]) => boolean;
}) {
  const more = total - rows.length;
  return (
    <DashCard
      title="Deadlines in the next 7 days"
      footer={
        more > 0 && calendarHref ? (
          <CardFooterLink href={calendarHref}>{more} more on the calendar</CardFooterLink>
        ) : more > 0 ? (
          <p className="text-muted-foreground text-sm">and {more} more</p>
        ) : null
      }
    >
      {rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No deadlines this week.</p>
      ) : (
        <ul className="-mx-2 text-sm">
          {rows.map((d) => {
            const body = (
              <>
                <span className="min-w-0">
                  <span className="block truncate">{d.label}</span>
                  {d.detail && (
                    <span className="text-muted-foreground block truncate text-xs">{d.detail}</span>
                  )}
                </span>
                <span
                  className={
                    d.date === today
                      ? "text-destructive shrink-0 font-semibold"
                      : "shrink-0 font-medium"
                  }
                >
                  {shortDay(d.date, today)}
                </span>
              </>
            );
            return (
              <li key={d.id}>
                {canOpen(d.feature) ? (
                  <Link
                    href={d.href}
                    className="hover:bg-muted/50 flex items-start justify-between gap-3 rounded-md px-2 py-1"
                  >
                    {body}
                  </Link>
                ) : (
                  <div className="flex items-start justify-between gap-3 px-2 py-1">{body}</div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </DashCard>
  );
}
