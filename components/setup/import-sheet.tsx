"use client";

import { useState } from "react";
import { FileSpreadsheet } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ImportSignsSheet } from "@/components/schedule/new-sign-menu";

/**
 * An "Import from Excel" button that opens the Signage page's import
 * panel, so the import looks and works the same wherever it is started.
 */
export function ImportSheet({
  editionId,
  variant = "outline",
  className,
}: {
  editionId: string;
  variant?: "default" | "outline";
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <Button type="button" variant={variant} className={className} onClick={() => setOpen(true)}>
        <FileSpreadsheet aria-hidden /> Import from Excel
      </Button>
      <ImportSignsSheet editionId={editionId} open={open} onOpenChange={setOpen} />
    </>
  );
}
