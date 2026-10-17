"use client";

import Link from "next/link";
import { CalendarPlus, ExternalLink } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { CopyField } from "@/components/copy-field";

/**
 * "Add to calendar": this person's private feed (every event's deadlines,
 * installs and the sign-offs waiting on them) for Outlook, Google or Apple
 * Calendar, with how to add it.
 */
export function AddToCalendar({
  feedUrl,
  canSetUp,
}: {
  /** Null when the site address isn't set, so no feed can be made. */
  feedUrl: string | null;
  /** Admins are told where to switch feeds on. */
  canSetUp: boolean;
}) {
  const webcal = feedUrl?.replace(/^https?:/, "webcal:") ?? null;
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button type="button" variant="outline" size="sm">
          <CalendarPlus aria-hidden /> Add to calendar
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Add to your calendar</DialogTitle>
          <DialogDescription>
            Every event&apos;s deadlines, install dates and the sign-offs waiting on you, kept up to
            date in Outlook, Google Calendar or Apple Calendar.
          </DialogDescription>
        </DialogHeader>
        {feedUrl && webcal ? (
          <div className="grid gap-4">
            <CopyField value={feedUrl} label="Your calendar feed link" />
            <ul className="text-muted-foreground list-disc space-y-1 pl-5 text-sm">
              <li>
                <span className="text-foreground font-medium">Outlook:</span> Add calendar →
                Subscribe from web, then paste the link.
              </li>
              <li>
                <span className="text-foreground font-medium">Google Calendar:</span> Other
                calendars → + → From URL, then paste the link.
              </li>
            </ul>
            <div className="flex flex-wrap items-center gap-3">
              <Button asChild variant="outline" size="sm">
                <a href={webcal}>
                  <ExternalLink aria-hidden /> Open in my calendar app
                </a>
              </Button>
              <p className="text-muted-foreground text-xs">
                The link is yours alone — treat it like a password.
              </p>
            </div>
          </div>
        ) : (
          <p className="text-muted-foreground text-sm">
            Calendar feeds need the site&apos;s address to be set up first.{" "}
            {canSetUp ? (
              <Link href="/settings/system" className="link">
                Set it up in Settings → System
              </Link>
            ) : (
              "Ask a super admin to set it up."
            )}
          </p>
        )}
      </DialogContent>
    </Dialog>
  );
}
