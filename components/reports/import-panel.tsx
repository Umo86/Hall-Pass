"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { CheckCircle2, Download } from "lucide-react";
import { Button } from "@/components/ui/button";
import { FileInput } from "@/components/ui/file-input";
import { cn } from "@/lib/utils";
import { importSchedule, type ImportOutcome } from "@/app/actions/import";

/** "12 new signs and 5 updated", "1 new sign". */
function outcomeSummary(o: ImportOutcome): string {
  const parts: string[] = [];
  if (o.created > 0) parts.push(`${o.created} new sign${o.created === 1 ? "" : "s"}`);
  if (o.updated > 0) parts.push(`${o.updated} updated`);
  return parts.length ? parts.join(" and ") : "nothing — the sheet had no rows";
}

/**
 * Import a schedule from Excel: download the template, choose the filled-in
 * file, import. Rows with a ref update that item; the rest become new signs.
 * Nothing is imported if any row has a problem — the rows are listed.
 */
export function ImportPanel({
  editionId,
  onImported,
  bare = false,
  className,
}: {
  editionId: string;
  /** After a successful import (e.g. to close a side panel). */
  onImported?: (outcome: ImportOutcome) => void;
  /** No border or heading — for a sheet or dialog that has its own title. */
  bare?: boolean;
  className?: string;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [pickerKey, setPickerKey] = useState(0);
  const [createMissing, setCreateMissing] = useState(false);
  const [outcome, setOutcome] = useState<ImportOutcome | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function run() {
    if (!file) return;
    const fd = new FormData();
    fd.set("editionId", editionId);
    fd.set("file", file);
    if (createMissing) fd.set("createMissing", "on");
    setError(null);
    setOutcome(null);
    start(async () => {
      const res = await importSchedule(fd);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      const result = res.data ?? { created: 0, updated: 0, errors: [] };
      setOutcome(result);
      if (result.errors.length === 0) {
        toast.success(`Imported ${outcomeSummary(result)}`);
        setFile(null);
        setPickerKey((k) => k + 1);
        router.refresh();
        onImported?.(result);
      }
    });
  }

  return (
    <div className={cn("grid gap-4", !bare && "rounded-lg border p-4", className)}>
      {!bare && <h3 className="text-sm font-semibold">Import signs from Excel</h3>}
      <ol className="grid gap-4 text-sm">
        <li className="grid gap-1.5">
          <p>
            <span className="font-medium">1. Get the template.</span>{" "}
            <span className="text-muted-foreground">
              One row per sign. Rows with a Ref update that item; rows without one become new signs.
            </span>
          </p>
          <Button asChild size="sm" variant="outline" className="w-fit">
            <a href="/api/exports/import-template" download>
              <Download aria-hidden /> Download the template
            </a>
          </Button>
        </li>
        <li className="grid gap-1.5">
          <p className="font-medium">2. Choose your filled-in sheet (.xlsx)</p>
          <FileInput
            key={pickerKey}
            accept=".xlsx"
            buttonLabel="Choose a spreadsheet"
            onFileChange={(files) => {
              setFile(files?.[0] ?? null);
              setOutcome(null);
              setError(null);
            }}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              className="size-4"
              checked={createMissing}
              onChange={(e) => setCreateMissing(e.target.checked)}
            />
            Add any halls, locations and suppliers the sheet names that aren&apos;t set up yet
          </label>
        </li>
        <li className="grid gap-1.5">
          <p className="font-medium">3. Import</p>
          <Button size="sm" className="w-fit" disabled={!file || pending} onClick={run}>
            {pending ? "Importing…" : "Import"}
          </Button>
        </li>
      </ol>

      <div aria-live="polite">
        {outcome && outcome.errors.length === 0 && (
          <p className="flex items-start gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200">
            <CheckCircle2 className="mt-0.5 size-4 shrink-0" aria-hidden />
            Imported {outcomeSummary(outcome)}.
          </p>
        )}
      </div>
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      {outcome && outcome.errors.length > 0 && (
        <div
          role="alert"
          className="rounded-md border border-red-200 bg-red-50 p-3 text-sm dark:border-red-900 dark:bg-red-950"
        >
          <p className="mb-1 font-medium text-red-800 dark:text-red-300">
            Nothing was imported — {outcome.errors.length} row
            {outcome.errors.length === 1 ? " needs" : "s need"} fixing first:
          </p>
          <ul className="list-disc pl-5">
            {outcome.errors.slice(0, 20).map((e) => (
              <li key={e.row}>
                Row {e.row}: {e.message}
              </li>
            ))}
          </ul>
          {outcome.errors.length > 20 && (
            <p className="text-muted-foreground mt-1">…and {outcome.errors.length - 20} more.</p>
          )}
        </div>
      )}
    </div>
  );
}
