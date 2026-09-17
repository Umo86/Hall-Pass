"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { importSchedule, type ImportOutcome } from "@/app/actions/import";

export function ImportPanel({ editionId }: { editionId: string }) {
  const [file, setFile] = useState<File | null>(null);
  const [createMissing, setCreateMissing] = useState(false);
  const [outcome, setOutcome] = useState<ImportOutcome | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <div className="space-y-3 rounded-lg border p-4">
      <h3 className="text-sm font-semibold">Import an existing schedule (Excel)</h3>
      <p className="text-muted-foreground text-sm">
        {/* eslint-disable-next-line @next/next/no-html-link-for-pages -- file download */}
        <a href="/api/exports/import-template" className="text-primary underline-offset-2 hover:underline" download>
          Download the template
        </a>
        , fill it in and upload. Rows with a Ref update that item; rows without create new items.
      </p>
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="file"
          accept=".xlsx"
          className="text-sm"
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            className="size-4"
            checked={createMissing}
            onChange={(e) => setCreateMissing(e.target.checked)}
          />
          Create missing suppliers and locations
        </label>
        <Button
          size="sm"
          disabled={!file || pending}
          onClick={() => {
            if (!file) return;
            const fd = new FormData();
            fd.set("editionId", editionId);
            fd.set("file", file);
            if (createMissing) fd.set("createMissing", "on");
            setError(null);
            setOutcome(null);
            setMessage(null);
            start(async () => {
              const res = await importSchedule(fd);
              if (!res.ok) setError(res.error);
              else {
                setOutcome(res.data ?? null);
                setMessage(res.message ?? null);
                router.refresh();
              }
            });
          }}
        >
          {pending ? "Importing…" : "Import"}
        </Button>
      </div>
      {message && <p className="text-sm text-green-700 dark:text-green-400">{message}</p>}
      {error && <p className="text-destructive text-sm">{error}</p>}
      {outcome && outcome.errors.length > 0 && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm dark:border-red-900 dark:bg-red-950">
          <p className="mb-1 font-medium text-red-800 dark:text-red-300">
            Nothing was imported — {outcome.errors.length} row(s) need fixing:
          </p>
          <ul className="list-disc pl-5">
            {outcome.errors.slice(0, 20).map((e) => (
              <li key={e.row}>
                Row {e.row}: {e.message}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
