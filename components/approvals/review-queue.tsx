"use client";

import { useCallback, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FileText } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { decideApproval } from "@/app/actions/approvals";
import { formatDate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { DecideButtons, localToday } from "./decide-buttons";
import { OverduePill, ReviewSheet } from "./review-sheet";
import { STEP_STATE_TONE, bulkConfirmSummary, stepStateLabel, type BulkResult } from "./step-words";
import { groupByEvent, type QueueRow } from "./queue-types";

/**
 * Approvals → Waiting on me: artwork to sign off (with thumbnails and a
 * review sheet that moves on after each decision) and, separately, the
 * print, delivery and install confirmations — which can be ticked and
 * confirmed together with one date.
 */
export function ReviewQueue({
  approvals,
  confirmations,
  initialReviewId,
}: {
  approvals: QueueRow[];
  confirmations: QueueRow[];
  /** Open the review sheet on this sign-off (from My Work's "Review"). */
  initialReviewId?: string | null;
}) {
  // Rows decided here leave the list straight away; the refresh confirms it.
  const [done, setDone] = useState<Set<string>>(() => new Set());
  const reviewable = useMemo(
    () => approvals.filter((r) => r.entity === "signage" && !done.has(r.instanceId)),
    [approvals, done],
  );
  const [reviewIndex, setReviewIndex] = useState<number | null>(() => {
    if (!initialReviewId) return null;
    const i = approvals
      .filter((r) => r.entity === "signage")
      .findIndex((r) => r.instanceId === initialReviewId);
    return i >= 0 ? i : null;
  });
  const markDone = useCallback((id: string) => setDone((d) => new Set(d).add(id)), []);
  const openReview = (id: string) => {
    const i = reviewable.findIndex((r) => r.instanceId === id);
    if (i >= 0) setReviewIndex(i);
  };
  const visibleApprovals = approvals.filter((r) => !done.has(r.instanceId));
  const visibleConfirmations = confirmations.filter((r) => !done.has(r.instanceId));

  return (
    <div className="space-y-8">
      {visibleApprovals.length > 0 && (
        <section className="space-y-3" aria-labelledby="queue-artwork">
          <h2 id="queue-artwork" className="text-sm font-semibold">
            Artwork to sign off ({visibleApprovals.length})
          </h2>
          {groupByEvent(visibleApprovals).map((group) => (
            <EventGroup key={group.eventCode} name={group.eventName} count={group.rows.length}>
              {group.rows.map((row) => (
                <ApprovalRow
                  key={row.instanceId}
                  row={row}
                  onReview={row.entity === "signage" ? () => openReview(row.instanceId) : null}
                  onDecided={() => markDone(row.instanceId)}
                />
              ))}
            </EventGroup>
          ))}
        </section>
      )}
      {visibleConfirmations.length > 0 && (
        <ConfirmationSection rows={visibleConfirmations} onConfirmed={markDone} />
      )}
      <ReviewSheet
        rows={reviewable}
        index={reviewIndex}
        onIndex={setReviewIndex}
        onClose={() => setReviewIndex(null)}
        onDecided={markDone}
      />
    </div>
  );
}

function EventGroup({
  name,
  count,
  children,
}: {
  name: string;
  count: number;
  children: React.ReactNode;
}) {
  return (
    <section aria-label={`${name}, ${count} waiting`} className="space-y-2">
      <h3 className="bg-background/95 supports-[backdrop-filter]:bg-background/80 sticky top-14 z-10 -mx-1 flex items-center gap-2 px-1 py-1 text-xs font-semibold tracking-wide text-muted-foreground uppercase backdrop-blur">
        {name}
        <span className="bg-muted text-foreground rounded-full px-1.5 tabular-nums">{count}</span>
      </h3>
      <ol className="space-y-2">{children}</ol>
    </section>
  );
}

function Due({ row }: { row: QueueRow }) {
  if (!row.dueAt) return null;
  return (
    <>
      <span aria-hidden>·</span>
      <span className={cn(row.overdueDays !== null && "text-destructive font-medium")}>
        due {formatDate(row.dueAt)}
      </span>
      {row.overdueDays !== null && <OverduePill days={row.overdueDays} />}
    </>
  );
}

function Thumb({ row, onReview }: { row: QueueRow; onReview: (() => void) | null }) {
  const current = row.artwork?.current;
  const inner = current?.thumbUrl ? (
    // eslint-disable-next-line @next/next/no-img-element -- signed artwork URLs
    <img src={current.thumbUrl} alt="" className="size-full object-contain" />
  ) : (
    <span className="text-muted-foreground flex flex-col items-center gap-1 text-[11px]">
      <FileText className="size-5" aria-hidden />
      {current ? `v${current.versionNumber}` : "No artwork"}
    </span>
  );
  const cls =
    "bg-muted flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-md border sm:size-24";
  if (!onReview) return <div className={cls}>{inner}</div>;
  return (
    <button
      type="button"
      onClick={onReview}
      className={cn(
        cls,
        "hover:ring-ring focus-visible:ring-ring hover:ring-2 focus-visible:ring-2 focus-visible:outline-none",
      )}
      aria-label={`Review ${row.ref} artwork`}
    >
      {inner}
    </button>
  );
}

function ApprovalRow({
  row,
  onReview,
  onDecided,
}: {
  row: QueueRow;
  onReview: (() => void) | null;
  onDecided: () => void;
}) {
  const current = row.artwork?.current;
  return (
    <li className="flex flex-col gap-3 rounded-lg border p-3 sm:flex-row sm:items-start">
      <div className="flex min-w-0 flex-1 gap-3">
        <Thumb row={row} onReview={onReview} />
        <div className="min-w-0 flex-1 space-y-1">
          <p className="text-sm">
            <Link href={row.href} className="link font-medium">
              {row.ref}
            </Link>{" "}
            —{" "}
            {onReview ? (
              <button type="button" onClick={onReview} className="text-left hover:underline">
                {row.title}
              </button>
            ) : (
              row.title
            )}
          </p>
          <p className="text-muted-foreground flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs">
            <span>{row.stepName}</span>
            <Due row={row} />
          </p>
          {current && (
            <p className="text-muted-foreground text-xs">
              Artwork v{current.versionNumber}, uploaded {formatDate(current.uploadedAt)}
              {current.uploaderName ? ` by ${current.uploaderName}` : ""}
            </p>
          )}
          {row.others.length > 0 && (
            <ul className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs" aria-label="Other sign-offs">
              {row.others.map((o) => (
                <li key={o.id}>
                  {o.stepName}:{" "}
                  <span className={STEP_STATE_TONE[o.status] ?? "text-muted-foreground"}>
                    {stepStateLabel(o.status, o.who)}
                  </span>
                </li>
              ))}
            </ul>
          )}
          {onReview && (
            <button type="button" onClick={onReview} className="link text-sm">
              Review artwork
            </button>
          )}
        </div>
      </div>
      <DecideButtons
        instanceId={row.instanceId}
        stepKind={row.kind}
        stepName={row.stepName}
        expectedStatus="pending"
        expectedLockedVersionId={row.expectedLockedVersionId}
        requiresPhoto={row.requiresPhoto}
        itemRef={row.ref}
        itemName={row.title}
        itemHref={row.href}
        onDecided={onDecided}
        compact
      />
    </li>
  );
}

function ConfirmationSection({
  rows,
  onConfirmed,
}: {
  rows: QueueRow[];
  onConfirmed: (id: string) => void;
}) {
  const [selected, setSelected] = useState<Set<string>>(() => new Set());
  const [date, setDate] = useState(() => localToday());
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [failures, setFailures] = useState<BulkResult[]>([]);
  const [pending, start] = useTransition();
  const router = useRouter();
  const chosen = rows.filter((r) => selected.has(r.instanceId));
  const steps = [...new Set(chosen.map((r) => r.stepName))];
  const allSelected = rows.length > 0 && chosen.length === rows.length;

  function toggle(id: string, on: boolean) {
    setSelected((s) => {
      const next = new Set(s);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  function confirmChosen() {
    const list = chosen;
    setFailures([]);
    start(async () => {
      const results: BulkResult[] = [];
      setProgress({ done: 0, total: list.length });
      for (const [i, row] of list.entries()) {
        if (row.requiresPhoto) {
          results.push({ ref: row.ref, ok: false, needsPhoto: true });
        } else {
          const res = await decideApproval({
            instanceId: row.instanceId,
            decision: "confirm",
            confirmedDate: date,
            expectedStatus: "pending",
            expectedLockedVersionId: row.expectedLockedVersionId,
          });
          results.push(
            res.ok ? { ref: row.ref, ok: true } : { ref: row.ref, ok: false, error: res.error },
          );
          if (res.ok) onConfirmed(row.instanceId);
        }
        setProgress({ done: i + 1, total: list.length });
      }
      setProgress(null);
      setSelected(new Set());
      const summary = bulkConfirmSummary(results);
      const failed = results.filter((r) => !r.ok);
      if (failed.length === 0) toast.success(summary);
      else toast.warning(summary);
      setFailures(failed);
      router.refresh();
    });
  }

  return (
    <section className="space-y-3" aria-labelledby="queue-confirm">
      <div className="flex flex-wrap items-center gap-3">
        <h2 id="queue-confirm" className="text-sm font-semibold">
          To confirm: print, delivery, install ({rows.length})
        </h2>
        <label className="text-muted-foreground ml-auto flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            className="size-4"
            checked={allSelected}
            onChange={(e) =>
              setSelected(e.target.checked ? new Set(rows.map((r) => r.instanceId)) : new Set())
            }
          />
          Select all
        </label>
      </div>
      {failures.length > 0 && (
        <div
          role="status"
          className="space-y-1 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm dark:border-amber-800 dark:bg-amber-950/40"
        >
          <p className="font-medium">Not confirmed:</p>
          <ul className="list-disc pl-5">
            {failures.map((f) => (
              <li key={f.ref}>
                {f.ref} —{" "}
                {f.needsPhoto ? "needs a photo; confirm it on its own with the photo" : f.error}
              </li>
            ))}
          </ul>
          <Button size="sm" variant="ghost" onClick={() => setFailures([])}>
            Dismiss
          </Button>
        </div>
      )}
      {groupByEvent(rows).map((group) => (
        <EventGroup key={group.eventCode} name={group.eventName} count={group.rows.length}>
          {group.rows.map((row) => (
            <li
              key={row.instanceId}
              className={cn(
                "flex flex-wrap items-center gap-3 rounded-lg border p-3",
                selected.has(row.instanceId) && "border-primary bg-muted/40",
              )}
            >
              <input
                type="checkbox"
                className="size-5 shrink-0"
                aria-label={`Select ${row.ref} (${row.stepName})`}
                checked={selected.has(row.instanceId)}
                onChange={(e) => toggle(row.instanceId, e.target.checked)}
              />
              <div className="min-w-0 flex-1">
                <p className="text-sm">
                  <Link href={row.href} className="link font-medium">
                    {row.ref}
                  </Link>{" "}
                  — {row.title}
                </p>
                <p className="text-muted-foreground flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs">
                  <span className="text-foreground font-medium">{row.stepName}</span>
                  <Due row={row} />
                  {row.requiresPhoto && <span>· needs a photo</span>}
                </p>
              </div>
              <Link href={row.href} className="link hidden text-sm sm:inline">
                Open item
              </Link>
              <DecideButtons
                instanceId={row.instanceId}
                stepKind="confirmation"
                stepName={row.stepName}
                expectedStatus="pending"
                expectedLockedVersionId={row.expectedLockedVersionId}
                requiresPhoto={row.requiresPhoto}
                itemRef={row.ref}
                itemName={row.title}
                itemHref={row.href}
                onDecided={() => onConfirmed(row.instanceId)}
              />
            </li>
          ))}
        </EventGroup>
      ))}
      {chosen.length > 0 && (
        <div
          role="region"
          aria-label="Confirm selected"
          className="bg-background sticky bottom-0 z-20 -mx-1 flex flex-wrap items-end gap-3 rounded-lg border p-3 shadow-lg"
        >
          <p className="text-sm font-medium">{chosen.length} selected</p>
          <div className="grid gap-1">
            <Label htmlFor="bulk-date" className="text-xs">
              When did it happen?
            </Label>
            <input
              id="bulk-date"
              type="date"
              className="border-input h-9 rounded-md border bg-transparent px-3 text-sm"
              value={date}
              max={localToday()}
              onChange={(e) => setDate(e.target.value)}
            />
          </div>
          <Button disabled={pending || !date} onClick={confirmChosen}>
            {progress
              ? `Confirming ${progress.done} of ${progress.total}…`
              : `Confirm ${chosen.length}${steps.length === 1 ? ` as ${steps[0]}` : ""}`}
          </Button>
          <Button variant="ghost" disabled={pending} onClick={() => setSelected(new Set())}>
            Clear
          </Button>
        </div>
      )}
    </section>
  );
}
