import Link from "next/link";
import { CalendarPlus } from "lucide-react";
import { cn } from "@/lib/utils";

export type SetupContact = { name: string; email: string };

/** "Ask Alex Admin or Olivia Ops", with each name a mail link. */
export function AskContacts({
  contacts,
  prefix = "Ask",
  suffix,
}: {
  contacts: SetupContact[];
  prefix?: string;
  suffix?: string;
}) {
  if (contacts.length === 0)
    return (
      <>
        {prefix} a super admin{suffix ? ` ${suffix}` : ""}.
      </>
    );
  const shown = contacts.slice(0, 3);
  return (
    <>
      {prefix}{" "}
      {shown.map((c, i) => (
        <span key={c.email}>
          {i > 0 && (i === shown.length - 1 ? " or " : ", ")}
          <a href={`mailto:${c.email}`} className="link">
            {c.name}
          </a>
        </span>
      ))}
      {contacts.length > shown.length ? " (or someone else who can)" : ""}
      {suffix ? ` ${suffix}` : ""}.
    </>
  );
}

/**
 * What someone sees before their organisation has created an event: who to
 * ask, instead of an empty screen.
 */
export function NoEventsYet({
  brandName,
  contacts,
  className,
  betweenSeasons = false,
}: {
  brandName: string;
  contacts: SetupContact[];
  className?: string;
  /** Every event is archived (the next one isn't created yet). */
  betweenSeasons?: boolean;
}) {
  return (
    <section
      aria-labelledby="no-events-title"
      className={cn("flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:p-5", className)}
    >
      <span className="bg-muted text-muted-foreground flex size-10 shrink-0 items-center justify-center rounded-full">
        <CalendarPlus className="size-5" aria-hidden />
      </span>
      <div className="space-y-1.5 text-sm">
        <h2 id="no-events-title" className="font-semibold">
          {betweenSeasons ? "No event running" : "Nothing set up yet"}
        </h2>
        <p className="text-muted-foreground">
          {betweenSeasons
            ? "Every event is archived. Once the next one is created, its signage and sign-offs appear here."
            : `Your team hasn't created an event in ${brandName} yet. Once one is created, its signage and sign-offs appear here.`}
        </p>
        <p>
          <AskContacts contacts={contacts} suffix="to create one" />
        </p>
        <p>
          <Link href="/account" className="link">
            Meanwhile, choose how you&apos;re notified →
          </Link>
        </p>
      </div>
    </section>
  );
}

/**
 * My Work between seasons for someone who creates events: every event is
 * archived, so offer the next one — My Work itself (and its tasks) stays.
 */
export function CreateNextEvent({ className }: { className?: string }) {
  return (
    <section
      aria-labelledby="next-event-title"
      className={cn("flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:p-5", className)}
    >
      <span className="bg-muted text-muted-foreground flex size-10 shrink-0 items-center justify-center rounded-full">
        <CalendarPlus className="size-5" aria-hidden />
      </span>
      <div className="space-y-1.5 text-sm">
        <h2 id="next-event-title" className="font-semibold">
          Create your next event
        </h2>
        <p className="text-muted-foreground">
          Every event is archived. Copy last year&apos;s to bring its halls, deadlines and partners
          across, or start a new one.
        </p>
        <p>
          <Link href="/start" className="link">
            Create the next event →
          </Link>
        </p>
      </div>
    </section>
  );
}
