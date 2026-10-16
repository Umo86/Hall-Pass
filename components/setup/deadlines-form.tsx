"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { saveEventDeadlines } from "@/app/actions/editions";
import { deadlineDate } from "@/lib/deadlines";
import { useSetup } from "./setup-checklist";
import { weekdayDate } from "./format";

export type DeadlineRow = {
  key: string;
  label: string;
  daysBeforeBuildStart: number;
  overrideDate: string | null;
};

/**
 * Setup step 3: each deadline as days before build-up starts, with the date
 * worked out as you type (and moving with build-up start in step 1), or a
 * fixed date instead. A table on wide screens, one card per deadline on a
 * phone.
 */
export function DeadlinesForm({
  editionId,
  deadlines,
  confirmed,
  canEdit,
}: {
  editionId: string;
  deadlines: DeadlineRow[];
  confirmed: boolean;
  canEdit: boolean;
}) {
  const router = useRouter();
  const { buildStart, advance } = useSetup();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState(() =>
    deadlines.map((d) => ({
      ...d,
      days: String(d.daysBeforeBuildStart),
      fixed: d.overrideDate ?? "",
    })),
  );

  function update(key: string, patch: Partial<{ days: string; fixed: string }>) {
    setRows((rs) => rs.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const res = await saveEventDeadlines({
        editionId,
        deadlines: rows.map((r) => ({
          key: r.key,
          daysBeforeBuildStart: r.days,
          overrideDate: r.fixed || null,
        })),
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toast.success(confirmed ? (res.message ?? "Saved") : "Deadlines confirmed");
      advance("deadlines");
      router.refresh();
    });
  }

  return (
    <form onSubmit={submit} className="space-y-3">
      <p className="text-muted-foreground text-sm">
        Build-up starts{" "}
        <span className="text-foreground font-medium">{weekdayDate(buildStart)}</span>. Each
        deadline is counted back from it unless you fix a date.
      </p>
      <Table className="sm:table">
        <TableHeader className="hidden sm:table-header-group">
          <TableRow>
            <TableHead>Deadline</TableHead>
            <TableHead>Days before build-up</TableHead>
            <TableHead>Date</TableHead>
            <TableHead>Fix a date instead</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody className="flex flex-col gap-2 sm:table-row-group">
          {rows.map((r) => {
            const date = deadlineDate(buildStart, r.days, r.fixed || null);
            return (
              <TableRow
                key={r.key}
                className="grid grid-cols-2 gap-x-3 gap-y-2 rounded-lg border p-3 sm:table-row sm:rounded-none sm:border-0 sm:border-b sm:p-0"
              >
                <TableCell className="col-span-2 p-0 font-medium sm:p-2">{r.label}</TableCell>
                <TableCell className="p-0 sm:p-2">
                  <div className="relative sm:w-28">
                    <Input
                      type="number"
                      inputMode="numeric"
                      min="0"
                      max="730"
                      value={r.days}
                      disabled={!canEdit || Boolean(r.fixed)}
                      onChange={(e) => update(r.key, { days: e.target.value })}
                      aria-label={`${r.label}: days before build-up`}
                      className="pr-12"
                    />
                    <span className="text-muted-foreground pointer-events-none absolute inset-y-0 right-2 flex items-center text-xs">
                      days
                    </span>
                  </div>
                </TableCell>
                <TableCell className="self-center p-0 sm:p-2">
                  <span className="text-sm tabular-nums" aria-live="polite">
                    {date ? weekdayDate(date) : "—"}
                  </span>
                  {r.fixed && <span className="text-muted-foreground ml-1 text-xs">(fixed)</span>}
                </TableCell>
                <TableCell className="col-span-2 p-0 sm:p-2">
                  <div className="flex items-center gap-1">
                    <Input
                      type="date"
                      value={r.fixed}
                      disabled={!canEdit}
                      onChange={(e) => update(r.key, { fixed: e.target.value })}
                      aria-label={`${r.label}: fixed date`}
                      className="sm:w-40"
                    />
                    {r.fixed && canEdit && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => update(r.key, { fixed: "" })}
                        aria-label={`Clear the fixed date for ${r.label}`}
                      >
                        Clear
                      </Button>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
      {error && (
        <p className="text-destructive text-sm" role="alert">
          {error}
        </p>
      )}
      {canEdit && (
        <Button type="submit" disabled={pending} className="w-full sm:w-auto">
          {pending ? "Saving…" : confirmed ? "Save deadlines" : "These look right"}
        </Button>
      )}
    </form>
  );
}
