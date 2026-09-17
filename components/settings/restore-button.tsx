"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { restoreSignageItem } from "@/app/actions/signage";

export function RestoreItemButton({ itemId }: { itemId: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      size="sm"
      variant="outline"
      disabled={pending}
      onClick={() =>
        start(async () => {
          await restoreSignageItem({ id: itemId });
          router.refresh();
        })
      }
    >
      Restore
    </Button>
  );
}
