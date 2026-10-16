"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { parseAsString, useQueryState } from "nuqs";
import { ChevronDown, FileSpreadsheet, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { ImportPanel } from "@/components/reports/import-panel";

/** "Import signs from Excel" in a side panel, opened from a menu or a button. */
export function ImportSignsSheet({
  editionId,
  open,
  onOpenChange,
}: {
  editionId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full max-w-[100vw] gap-4 p-4 sm:max-w-lg">
        <SheetTitle className="pr-8 text-base">Import signs from Excel</SheetTitle>
        <p className="text-muted-foreground text-sm">
          Already have a schedule in a spreadsheet? Bring it in here — every row becomes a sign.
        </p>
        <ImportPanel editionId={editionId} bare onImported={() => onOpenChange(false)} />
      </SheetContent>
    </Sheet>
  );
}

/**
 * The Signage page's main button: add one sign, or import a spreadsheet.
 * `?import=1` (linked from Reports) opens the import panel straight away;
 * the parameter is then taken out of the address so a reload doesn't reopen it.
 */
export function NewSignMenu({
  editionCode,
  editionId,
  canImport,
}: {
  editionCode: string;
  editionId: string;
  canImport: boolean;
}) {
  const [importParam, setImportParam] = useQueryState("import", parseAsString);
  const [importOpen, setImportOpen] = useState(() => canImport && importParam === "1");
  useEffect(() => {
    if (importParam != null) void setImportParam(null);
  }, [importParam, setImportParam]);
  if (!canImport) {
    return (
      <Button size="sm" asChild>
        <Link href={`/${editionCode}/signage/new`}>
          <Plus aria-hidden /> New sign
        </Link>
      </Button>
    );
  }
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button size="sm">
            <Plus aria-hidden /> New sign <ChevronDown aria-hidden />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-52">
          <DropdownMenuItem asChild>
            <Link href={`/${editionCode}/signage/new`}>
              <Plus aria-hidden /> Add a sign
            </Link>
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => setImportOpen(true)}>
            <FileSpreadsheet aria-hidden /> Import from Excel
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      <ImportSignsSheet editionId={editionId} open={importOpen} onOpenChange={setImportOpen} />
    </>
  );
}
