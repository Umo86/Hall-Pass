"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { restoreSignageItem } from "@/app/actions/signage";

export function RestoreItemButton({ itemId }: { itemId: string }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  return (
    <span className="inline-flex flex-wrap items-center gap-2">
      <Button
        size="sm"
        variant="outline"
        disabled={pending}
        onClick={() =>
          start(async () => {
            const res = await restoreSignageItem({ id: itemId });
            setError(res.ok ? null : res.error);
            router.refresh();
          })
        }
      >
        Restore
      </Button>
      {error && <span className="text-destructive text-xs">{error}</span>}
    </span>
  );
}
