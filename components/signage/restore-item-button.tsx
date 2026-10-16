"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { restoreSignageItem } from "@/app/actions/signage";

/** Restore a deleted item, with a toast that opens it. */
export function RestoreItemButton({ itemId, itemRef }: { itemId: string; itemRef: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      size="sm"
      variant="outline"
      disabled={pending}
      aria-label={`Restore ${itemRef}`}
      onClick={() =>
        start(async () => {
          const res = await restoreSignageItem({ id: itemId });
          if (!res.ok) {
            toast.error(res.error);
            return;
          }
          const href = res.data?.href;
          toast.success(res.message ?? `Restored ${itemRef}`, {
            action: href
              ? { label: `Open ${itemRef}`, onClick: () => router.push(href) }
              : undefined,
          });
          router.refresh();
        })
      }
    >
      <RotateCcw aria-hidden /> {pending ? "Restoring…" : "Restore"}
    </Button>
  );
}
