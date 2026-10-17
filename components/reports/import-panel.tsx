"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { CheckCircle2, Download, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { FileInput } from "@/components/ui/file-input";
import { cn } from "@/lib/utils";
import { importSchedule, type ImportOutcome } from "@/app/actions/import";

const n = (count: number, one: string, many = `${one}s`) => `${count} ${count === 1 ? one : many}`;

/** "12 new signs and 5 updated", "1 new sign". */
function outcomeSummary(o: ImportOutcome): string {
  const parts: string[] = [];
  if (o.created > 0) parts.push(n(o.created, "new sign"));
  if (o.updated > 0) parts.push(`${o.updated} updated`);
  return parts.length ? parts.join(" and ") : "nothing — the sheet had no rows";
}

/** "Also adds 2 halls, 3 locations and 1 supplier." or null. */
function addsSummary(o: ImportOutcome): string | null {
  const a = o.adds;
  if (!a) return null;
  const parts = [
    a.halls ? n(a.halls, "hall") : null,
    a.locations ? n(a.locations, "location") : null,
    a.suppliers ? n(a.suppliers, "supplier") : null,
  ].filter(Boolean) as string[];
  if (parts.length === 0) return null;
  const last = parts.pop();
  return `Also adds ${parts.length ? `${parts.join(", ")} and ${last}` : last}.`;
}

/** "3 owned by the people named, 2 left to you." — only when the sheet has an Owner email column. */
function ownersSummary(o: ImportOutcome): string | null {
  const w = o.owners;
  if (!w) return null;
  return `${w.fromSheet} owned by the people named, ${w.toYou} left to you.`;
}

/**
 * Import a schedule from Excel: download the template, choose the filled-in
 * file, see what it will do ("12 new, 5 updated, 0 errors"), then import.
 * Rows with a ref update that item; the rest become new signs. Nothing is
 * imported if any row has a problem — the rows are listed.
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
  /** The check of the chosen file (a dry run), or the failed import's rows. */
  const [outcome, setOutcome] = useState<ImportOutcome | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [checking, startCheck] = useTransition();
  const [importing, startImport] = useTransition();
  const checkRun = useRef(0);
  const router = useRouter();

  function formFor(f: File, opts: { dryRun: boolean; createMissing: boolean }) {
    const fd = new FormData();
    fd.set("editionId", editionId);
    fd.set("file", f);
    if (opts.createMissing) fd.set("createMissing", "on");
    if (opts.dryRun) fd.set("dryRun", "on");
    return fd;
  }

  /** Check the sheet without importing anything; a newer check wins. */
  function check(f: File | null, withMissing: boolean) {
    setOutcome(null);
    setError(null);
    if (!f) return;
    const run = ++checkRun.current;
    startCheck(async () => {
      const res = await importSchedule(formFor(f, { dryRun: true, createMissing: withMissing }));
      if (run !== checkRun.current) return;
      if (!res.ok) setError(res.error);
      else setOutcome(res.data ?? { created: 0, updated: 0, errors: [] });
    });
  }

  function run() {
    if (!file) return;
    setError(null);
    startImport(async () => {
      const res = await importSchedule(formFor(file, { dryRun: false, createMissing }));
      if (!res.ok) {
        setError(res.error);
        return;
      }
      const result = res.data ?? { created: 0, updated: 0, errors: [] };
      if (result.errors.length > 0) {
        setOutcome(result);
        return;
      }
      toast.success(`Imported ${outcomeSummary(result)}`);
      setOutcome(null);
      setFile(null);
      setPickerKey((k) => k + 1);
      router.refresh();
      onImported?.(result);
    });
  }

  const ready = Boolean(file && outcome && outcome.dryRun && outcome.errors.length === 0);
  const rows = outcome ? outcome.created + outcome.updated : 0;

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
              const next = files?.[0] ?? null;
              setFile(next);
              check(next, createMissing);
            }}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              className="size-4"
              checked={createMissing}
              onChange={(e) => {
                setCreateMissing(e.target.checked);
                check(file, e.target.checked);
              }}
            />
            Add any halls, locations and suppliers the sheet names that aren&apos;t set up yet
          </label>
        </li>
        <li className="grid gap-1.5">
          <p className="font-medium">3. Check and import</p>
          <div aria-live="polite" className="grid gap-1.5">
            {!file && (
              <p className="text-muted-foreground">
                Choose a sheet and it is checked first; nothing changes until you import.
              </p>
            )}
            {checking && (
              <p className="text-muted-foreground flex items-center gap-2">
                <Loader2 className="size-4 animate-spin" aria-hidden /> Checking the sheet…
              </p>
            )}
            {!checking && ready && outcome && (
              <div className="rounded-md border bg-muted/40 px-3 py-2">
                <p className="flex items-center gap-2 font-medium">
                  <CheckCircle2 className="size-4 shrink-0 text-emerald-600" aria-hidden />
                  {outcome.created} new, {outcome.updated} updated, 0 errors
                </p>
                {addsSummary(outcome) && (
                  <p className="text-muted-foreground mt-0.5 text-xs">{addsSummary(outcome)}</p>
                )}
                {ownersSummary(outcome) && (
                  <p className="text-muted-foreground mt-0.5 text-xs">{ownersSummary(outcome)}</p>
                )}
                {outcome.owners && outcome.owners.notes.length > 0 && (
                  <ul className="text-muted-foreground mt-1 list-disc pl-5 text-xs">
                    {outcome.owners.notes.slice(0, 10).map((note) => (
                      <li key={note.row}>
                        Row {note.row}: {note.message}
                      </li>
                    ))}
                    {outcome.owners.notes.length > 10 && (
                      <li>…and {outcome.owners.notes.length - 10} more.</li>
                    )}
                  </ul>
                )}
              </div>
            )}
          </div>
          <Button
            size="sm"
            className="w-fit"
            disabled={!ready || checking || importing}
            onClick={run}
          >
            {importing ? (
              <>
                <Loader2 className="animate-spin" aria-hidden /> Importing…
              </>
            ) : ready ? (
              `Import ${n(rows, "row")}`
            ) : (
              "Import"
            )}
          </Button>
        </li>
      </ol>

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
            {outcome.dryRun ? "Nothing can be imported yet" : "Nothing was imported"} —{" "}
            {n(outcome.errors.length, "row")} {outcome.errors.length === 1 ? "needs" : "need"}{" "}
            fixing first:
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
          <p className="text-muted-foreground mt-2 text-xs">
            Fix them in the spreadsheet, save it and choose it again.
          </p>
        </div>
      )}
    </div>
  );
}
