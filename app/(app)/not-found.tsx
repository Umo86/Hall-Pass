import Link from "next/link";
import { Button } from "@/components/ui/button";

/**
 * A record or page that doesn't exist, belongs to another event, or is in an
 * event the person hasn't been given (Users → Events) — all answer the same.
 */
export default function NotFound() {
  return (
    <div className="mx-auto flex max-w-md flex-col items-start gap-3 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Not found</h1>
      <p className="text-muted-foreground text-sm">
        This page doesn&apos;t exist, belongs to a different event, or is in an event you
        haven&apos;t been given. Check the event in the top bar, ask a super admin or your manager
        if you need it, or start again from your work.
      </p>
      <Button asChild>
        <Link href="/my-work">Go to My Work</Link>
      </Button>
    </div>
  );
}
