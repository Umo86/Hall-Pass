import Link from "next/link";
import { Button } from "@/components/ui/button";

/** A record or page that doesn't exist, or belongs to another show. */
export default function NotFound() {
  return (
    <div className="mx-auto flex max-w-md flex-col items-start gap-3 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Not found</h1>
      <p className="text-muted-foreground text-sm">
        This page doesn&apos;t exist, or the item you&apos;re after belongs to a different show.
        Check the show in the top bar, or start again from your work.
      </p>
      <Button asChild>
        <Link href="/my-work">Go to My Work</Link>
      </Button>
    </div>
  );
}
