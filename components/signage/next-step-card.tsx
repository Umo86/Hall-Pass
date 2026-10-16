import Link from "next/link";
import { Check, Circle, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { cn } from "@/lib/utils";
import type { NextStep, NextStepAction, ProgressStep, ReadinessLine } from "@/lib/domain/signage";
import { NextStepButton } from "./lifecycle-buttons";

const TONES: Record<NextStep["tone"], string> = {
  action: "border-sky-200 bg-sky-50/60 dark:border-sky-900 dark:bg-sky-950/30",
  waiting: "bg-muted/30",
  warning: "border-amber-300 bg-amber-50/70 dark:border-amber-900 dark:bg-amber-950/30",
  done: "border-emerald-200 bg-emerald-50/60 dark:border-emerald-900 dark:bg-emerald-950/30",
};

/** Where a checklist line takes you to fix it. */
function lineHref(line: ReadinessLine): string | null {
  if (line.done) return null;
  if (line.key === "artwork") return "?tab=artwork#upload";
  return line.field ? `?tab=details&edit=1#${line.field}` : null;
}

/**
 * "What happens next" at the top of every item page: one sentence, who it
 * waits on, at most one main button (plus one quieter one), the sign-off
 * checklist while it is a draft, and a slim stepper of the item's stages.
 */
export function NextStepCard({
  step,
  progress,
  lines,
  itemId,
  itemRef,
  currentVersionId,
  requiresInstallPhoto,
  canEditFields,
}: {
  step: NextStep;
  progress: ProgressStep[];
  lines: ReadinessLine[];
  itemId: string;
  itemRef: string;
  currentVersionId: string | null;
  requiresInstallPhoto: boolean;
  /** Checklist lines link to the form only for people who can change it. */
  canEditFields: boolean;
}) {
  const action = (a: NextStepAction | null | undefined, primary: boolean) => {
    if (!a) return null;
    switch (a.type) {
      case "link":
        return (
          <Button asChild size="sm" variant={primary ? "default" : "outline"}>
            <Link href={a.href}>{a.label}</Link>
          </Button>
        );
      case "confirm":
        return (
          <DecideButtons
            instanceId={a.instanceId}
            stepKind="confirmation"
            stepName={a.stepName}
            expectedStatus="pending"
            expectedLockedVersionId={currentVersionId}
            requiresPhoto={a.stepName === "Installed" && requiresInstallPhoto}
            confirmLabel={a.label}
          />
        );
      default:
        return (
          <NextStepButton
            itemId={itemId}
            itemRef={itemRef}
            action={a}
            variant={primary ? "default" : "outline"}
            disabledReason={a.type === "submit" ? a.disabledReason : null}
          />
        );
    }
  };

  return (
    <section
      aria-label="Next step"
      className={cn("flex flex-col gap-3 rounded-lg border p-4", TONES[step.tone])}
    >
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-0.5">
          <p className="text-muted-foreground text-xs font-medium">
            {step.tone === "done" ? "Where it is" : "Next step"}
          </p>
          <h2 id="next-step-title" className="font-semibold">
            {step.title}
          </h2>
          {step.detail && <p className="text-muted-foreground text-sm">{step.detail}</p>}
        </div>
        {(step.action || step.secondary) && (
          <div className="flex shrink-0 flex-wrap items-center gap-2">
            {action(step.secondary, false)}
            {action(step.action, true)}
          </div>
        )}
      </div>

      {step.showChecklist && lines.length > 1 && (
        <ul className="grid gap-1 text-sm sm:grid-cols-2" aria-label="Needed for sign-off">
          {lines.map((line) => {
            const href = canEditFields || line.key === "artwork" ? lineHref(line) : null;
            const Icon = line.done ? Check : line.blocking ? X : Circle;
            const text = (
              <>
                <Icon
                  aria-hidden
                  className={cn(
                    "size-4 shrink-0",
                    line.done
                      ? "text-emerald-600 dark:text-emerald-400"
                      : line.blocking
                        ? "text-destructive"
                        : "text-muted-foreground",
                  )}
                />
                <span>{line.label}</span>
                <span className="sr-only">{line.done ? " — done" : " — still needed"}</span>
              </>
            );
            return (
              <li key={`${line.key}-${line.label}`}>
                {href ? (
                  <Link
                    href={href}
                    className="inline-flex items-center gap-2 py-0.5 hover:underline"
                  >
                    {text}
                  </Link>
                ) : (
                  <span
                    className={cn(
                      "inline-flex items-center gap-2 py-0.5",
                      line.done && "text-muted-foreground",
                    )}
                  >
                    {text}
                  </span>
                )}
              </li>
            );
          })}
        </ul>
      )}

      <ol
        className="relative flex gap-1 overflow-x-auto border-t pt-3 text-xs"
        aria-label="Progress"
      >
        {progress.map((p, i) => (
          <li
            key={p.key}
            aria-current={p.state === "current" ? "step" : undefined}
            className={cn(
              "flex shrink-0 items-center gap-1.5",
              p.state === "current"
                ? "text-foreground font-semibold"
                : p.state === "done"
                  ? "text-muted-foreground"
                  : "text-muted-foreground/80",
            )}
          >
            {i > 0 && <span aria-hidden className="bg-border mx-1 h-px w-3 sm:w-6" />}
            <span
              aria-hidden
              className={cn(
                "flex size-4 items-center justify-center rounded-full border",
                p.state === "done" && "border-emerald-600 bg-emerald-600 text-white",
                p.state === "current" && "border-primary bg-primary text-primary-foreground",
              )}
            >
              {p.state === "done" && <Check className="size-3" />}
            </span>
            {/* On a phone only the current stage is named; the dots show the rest. */}
            <span className={p.state === "current" ? undefined : "sr-only sm:not-sr-only"}>
              {p.label}
            </span>
            <span className="sr-only">
              {p.state === "done" ? " (done)" : p.state === "current" ? " (now)" : ""}
            </span>
          </li>
        ))}
      </ol>
    </section>
  );
}
