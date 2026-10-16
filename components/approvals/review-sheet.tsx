"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { CheckCircle2, ChevronLeft, ChevronRight, MoreHorizontal, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useConfirm } from "@/components/confirm-dialog";
import { decideApproval } from "@/app/actions/approvals";
import { formatDate, formatDateTime } from "@/lib/format";
import { cn } from "@/lib/utils";
import { ArtworkPreview } from "./artwork-preview";
import {
  DECISION_CONSEQUENCE,
  decisionInputError,
  toastDecision,
  type DecisionKind,
} from "./decide-buttons";
import { STEP_STATE_TONE, overdueLabel, stepStateLabel } from "./step-words";
import type { QueueRow } from "./queue-types";

/**
 * The review queue's sheet: the artwork large, its notes and the version
 * before it, the other sign-offs, a comment box and the decision. After a
 * decision it moves straight on to the next item. Right-hand panel on a
 * desktop, full screen on a phone; ← → (or J K) move between items.
 */
export function ReviewSheet({
  rows,
  index,
  onIndex,
  onClose,
  onDecided,
}: {
  rows: QueueRow[];
  /** Which row is shown; null = closed. */
  index: number | null;
  onIndex: (i: number) => void;
  onClose: () => void;
  onDecided: (instanceId: string) => void;
}) {
  const open = index !== null;
  const safeIndex = index === null ? 0 : Math.min(index, Math.max(0, rows.length - 1));
  const row = open ? (rows[safeIndex] ?? null) : null;

  // Arrow keys and J/K move between items, except while typing.
  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName))) return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if ((e.key === "ArrowRight" || e.key === "j") && safeIndex < rows.length - 1) {
        e.preventDefault();
        onIndex(safeIndex + 1);
      } else if ((e.key === "ArrowLeft" || e.key === "k") && safeIndex > 0) {
        e.preventDefault();
        onIndex(safeIndex - 1);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, safeIndex, rows.length, onIndex]);

  return (
    <DialogPrimitive.Root open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50" />
        <DialogPrimitive.Content
          aria-describedby={undefined}
          className="bg-background data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:slide-out-to-right data-[state=open]:slide-in-from-right fixed inset-0 z-50 flex flex-col shadow-lg duration-200 outline-none sm:left-auto sm:w-[min(56rem,100vw)] sm:border-l"
        >
          <header className="flex items-center gap-2 border-b px-4 py-3">
            <DialogPrimitive.Title className="text-sm font-semibold">
              Review sign-off
            </DialogPrimitive.Title>
            {rows.length > 0 && (
              <span className="text-muted-foreground text-sm tabular-nums" aria-live="polite">
                {safeIndex + 1} of {rows.length}
              </span>
            )}
            <div className="ml-auto flex items-center gap-1">
              <Button
                variant="ghost"
                size="touch"
                aria-label="Previous item"
                disabled={!row || safeIndex === 0}
                onClick={() => onIndex(safeIndex - 1)}
              >
                <ChevronLeft aria-hidden />
              </Button>
              <Button
                variant="ghost"
                size="touch"
                aria-label="Next item"
                disabled={!row || safeIndex >= rows.length - 1}
                onClick={() => onIndex(safeIndex + 1)}
              >
                <ChevronRight aria-hidden />
              </Button>
              <DialogPrimitive.Close asChild>
                <Button variant="ghost" size="touch" aria-label="Close review">
                  <X aria-hidden />
                </Button>
              </DialogPrimitive.Close>
            </div>
          </header>
          {row ? (
            <ReviewItem
              key={row.instanceId}
              row={row}
              hasNext={safeIndex < rows.length - 1}
              onDecided={() => onDecided(row.instanceId)}
            />
          ) : (
            <div className="flex flex-1 flex-col items-center justify-center gap-3 p-6 text-center">
              <CheckCircle2 className="size-10 text-emerald-600" aria-hidden />
              <p className="font-medium">All done — nothing else is waiting on you here.</p>
              <DialogPrimitive.Close asChild>
                <Button variant="outline">Close</Button>
              </DialogPrimitive.Close>
            </div>
          )}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

function ReviewItem({
  row,
  hasNext,
  onDecided,
}: {
  row: QueueRow;
  hasNext: boolean;
  onDecided: () => void;
}) {
  const [comment, setComment] = useState("");
  const [conditions, setConditions] = useState("");
  const [withConditions, setWithConditions] = useState(false);
  const [compare, setCompare] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const commentRef = useRef<HTMLTextAreaElement>(null);
  const router = useRouter();
  const current = row.artwork?.current ?? null;
  const previous = row.artwork?.previous ?? null;

  async function decide(kind: DecisionKind) {
    const missing = decisionInputError(kind, { comment, conditions });
    setError(missing);
    if (missing) {
      if (kind !== "approve_with_conditions") commentRef.current?.focus();
      return;
    }
    if (
      kind === "reject" &&
      !(await confirm({
        title: `Reject ${row.ref}?`,
        description: DECISION_CONSEQUENCE.reject,
        confirmLabel: "Reject",
        destructive: true,
      }))
    ) {
      return;
    }
    start(async () => {
      const res = await decideApproval({
        instanceId: row.instanceId,
        decision: kind,
        comment: comment.trim() || undefined,
        conditionsText: kind === "approve_with_conditions" ? conditions : undefined,
        expectedStatus: "pending",
        expectedLockedVersionId: row.expectedLockedVersionId,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toastDecision(
        kind,
        { stepName: row.stepName, itemName: row.title, itemHref: row.href },
        (h) => router.push(h),
      );
      onDecided();
      router.refresh();
    });
  }

  return (
    <>
      {confirmDialog}
      <div className="flex-1 space-y-4 overflow-y-auto p-4">
        <div className="space-y-1">
          <h2 className="text-base font-semibold">
            <Link href={row.href} className="link">
              {row.ref}
            </Link>{" "}
            — {row.title}
          </h2>
          <p className="text-muted-foreground flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
            <span>{row.stepName}</span>
            <span aria-hidden>·</span>
            <span>{row.eventName}</span>
            {row.dueAt && (
              <>
                <span aria-hidden>·</span>
                <span className={cn(row.overdueDays !== null && "text-destructive font-medium")}>
                  due {formatDateTime(row.dueAt)}
                </span>
              </>
            )}
            {row.overdueDays !== null && <OverduePill days={row.overdueDays} />}
          </p>
        </div>

        {current ? (
          <section className="space-y-2" aria-label="Artwork">
            {previous && (
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  aria-pressed={compare}
                  onClick={() => setCompare((c) => !c)}
                >
                  {compare
                    ? `Show v${current.versionNumber} only`
                    : `Compare with v${previous.versionNumber}`}
                </Button>
              </div>
            )}
            {compare && previous ? (
              <div className="grid gap-3 sm:grid-cols-2">
                <figure className="space-y-1">
                  <figcaption className="text-muted-foreground text-xs">
                    v{previous.versionNumber} (before)
                  </figcaption>
                  <ArtworkPreview version={previous} frameClassName="max-h-[50vh] min-h-40" />
                </figure>
                <figure className="space-y-1">
                  <figcaption className="text-xs font-medium">
                    v{current.versionNumber} (to sign off)
                  </figcaption>
                  <ArtworkPreview version={current} frameClassName="max-h-[50vh] min-h-40" />
                </figure>
              </div>
            ) : (
              <ArtworkPreview version={current} />
            )}
            <p className="text-muted-foreground text-sm">
              v{current.versionNumber} · {current.fileName} · uploaded{" "}
              {formatDate(current.uploadedAt)}
              {current.uploaderName ? ` by ${current.uploaderName}` : ""}
              {current.downloadUrl && (
                <>
                  {" · "}
                  <a href={current.downloadUrl} className="link" target="_blank" rel="noreferrer">
                    Download
                  </a>
                </>
              )}
            </p>
            {current.notes && (
              <p className="bg-muted/50 rounded-md p-3 text-sm">
                <span className="font-medium">Notes with this version:</span> {current.notes}
              </p>
            )}
          </section>
        ) : (
          <p className="text-muted-foreground rounded-lg border border-dashed p-6 text-sm">
            There is no artwork on this item to preview.{" "}
            <Link href={row.href} className="link">
              Open the item
            </Link>
          </p>
        )}

        {row.others.length > 0 && (
          <section className="space-y-1" aria-label="Other sign-offs">
            <h3 className="text-sm font-semibold">Other sign-offs</h3>
            <ul className="space-y-0.5 text-sm">
              {row.others.map((o) => (
                <li key={o.id}>
                  <span className="font-medium">{o.stepName}:</span>{" "}
                  <span className={STEP_STATE_TONE[o.status] ?? "text-muted-foreground"}>
                    {stepStateLabel(o.status, o.who)}
                  </span>
                </li>
              ))}
            </ul>
          </section>
        )}
        <p className="text-sm">
          <Link href={row.href} className="link">
            Open the item page
          </Link>{" "}
          <span className="text-muted-foreground">for its history, comments and details.</span>
        </p>
      </div>

      <footer className="space-y-2 border-t p-4">
        {withConditions && (
          <div className="space-y-1.5">
            <Label htmlFor={`conditions-${row.instanceId}`}>Conditions (required)</Label>
            <Textarea
              id={`conditions-${row.instanceId}`}
              rows={2}
              value={conditions}
              onChange={(e) => setConditions(e.target.value)}
              placeholder="e.g. Amend the logo per brand guidelines before print"
              autoFocus
            />
          </div>
        )}
        <div className="space-y-1.5">
          <Label htmlFor={`comment-${row.instanceId}`}>
            Comment{" "}
            <span className="text-muted-foreground font-normal">(needed to ask for changes)</span>
          </Label>
          <Textarea
            ref={commentRef}
            id={`comment-${row.instanceId}`}
            rows={2}
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder="e.g. The logo needs more clear space"
          />
        </div>
        {error && (
          <p role="alert" className="text-destructive text-sm">
            {error}
          </p>
        )}
        <div className="grid grid-cols-[1fr_1fr_auto] gap-2 sm:flex sm:flex-wrap sm:items-center">
          {withConditions ? (
            <>
              <Button disabled={pending} onClick={() => void decide("approve_with_conditions")}>
                {pending
                  ? "Saving…"
                  : hasNext
                    ? "Approve with conditions & next"
                    : "Approve with conditions"}
              </Button>
              <Button
                variant="outline"
                disabled={pending}
                onClick={() => {
                  setWithConditions(false);
                  setError(null);
                }}
              >
                Cancel
              </Button>
            </>
          ) : (
            <>
              <Button disabled={pending} onClick={() => void decide("approve")}>
                {pending ? "Saving…" : hasNext ? "Approve & next" : "Approve"}
              </Button>
              <Button
                variant="outline"
                disabled={pending}
                onClick={() => void decide("request_changes")}
              >
                Request changes
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label="More decisions"
                    disabled={pending}
                  >
                    <MoreHorizontal aria-hidden />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem
                    onSelect={() => {
                      setError(null);
                      setWithConditions(true);
                    }}
                  >
                    Approve with conditions…
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem variant="destructive" onSelect={() => void decide("reject")}>
                    Reject…
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </>
          )}
        </div>
        <p className="text-muted-foreground text-xs">
          {current
            ? `Your decision is recorded against v${current.versionNumber}.`
            : DECISION_CONSEQUENCE.approve}{" "}
          <span className="hidden sm:inline">Use ← → or J K to move between items.</span>
        </p>
      </footer>
    </>
  );
}

export function OverduePill({ days }: { days: number }) {
  return (
    <span className="bg-destructive inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold text-white">
      {overdueLabel(days)}
    </span>
  );
}
