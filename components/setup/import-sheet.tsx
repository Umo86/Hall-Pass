"use client";

import { useState } from "react";
import { FileSpreadsheet } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { ImportPanel } from "@/components/reports/import-panel";

/** "Import from Excel": the schedule import in a side panel, without leaving the page. */
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
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button type="button" variant={variant} className={className}>
          <FileSpreadsheet aria-hidden /> Import from Excel
        </Button>
      </SheetTrigger>
      <SheetContent side="right" className="w-full max-w-[100vw] gap-4 p-4 sm:max-w-lg">
        <SheetTitle className="pr-8 text-base">Import signs from Excel</SheetTitle>
        <p className="text-muted-foreground text-sm">
          Already have a schedule in a spreadsheet? Bring it in here — every row becomes a sign.
        </p>
        <ImportPanel editionId={editionId} />
      </SheetContent>
    </Sheet>
  );
}
