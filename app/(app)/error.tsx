"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";

/** Shown when a page fails to load, instead of a blank screen. */
export default function PageError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);
  return (
    <div className="mx-auto flex max-w-md flex-col items-start gap-3 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Something went wrong</h1>
      <p className="text-muted-foreground text-sm">
        This page didn&apos;t load properly. It&apos;s usually a brief connection problem — try
        again, and if it keeps happening let your admin know
        {error.digest ? ` (reference ${error.digest})` : ""}.
      </p>
      <Button onClick={reset}>Try again</Button>
    </div>
  );
}
