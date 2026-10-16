"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { CheckCircle2, ChevronDown, Circle, Clock, MinusCircle } from "lucide-react";
import { cn } from "@/lib/utils";

/** The parts of a setup step the checklist shows (see lib/queries/setup.ts). */
export type ChecklistStep = {
  key: string;
  title: string;
  reason: string;
  level: "essential" | "recommended" | "optional";
  state: "done" | "todo" | "waiting" | "optional";
  detail: string;
  shared: boolean;
};

type SetupContextValue = {
  /** Build-up start as typed in the details form, so deadline dates move live. */
  buildStart: string;
  setBuildStart: (v: string) => void;
  /** Close a finished step and open the next one still to do. */
  advance: (fromKey: string) => void;
};

const SetupContext = createContext<SetupContextValue | null>(null);

export function useSetup(): SetupContextValue {
  const ctx = useContext(SetupContext);
  return (
    ctx ?? {
      buildStart: "",
      setBuildStart: () => {},
      advance: () => {},
    }
  );
}

const STATE_TEXT: Record<ChecklistStep["state"], string> = {
  done: "Done",
  todo: "To do",
  waiting: "Waiting",
  optional: "Optional",
};

function StateIcon({ state }: { state: ChecklistStep["state"] }) {
  const common = "size-5 shrink-0";
  switch (state) {
    case "done":
      return <CheckCircle2 className={cn(common, "text-emerald-600")} aria-hidden />;
    case "waiting":
      return <Clock className={cn(common, "text-amber-600")} aria-hidden />;
    case "optional":
      return <MinusCircle className={cn(common, "text-muted-foreground")} aria-hidden />;
    default:
      return <Circle className={cn(common, "text-muted-foreground")} aria-hidden />;
  }
}

/** Steps open on load: the one in the address (#deadlines), else the first unfinished. */
function firstOpen(steps: ChecklistStep[]): string | null {
  return (
    steps.find((s) => s.state === "todo" || s.state === "waiting")?.key ??
    steps.find((s) => s.state !== "done")?.key ??
    null
  );
}

/**
 * The event setup checklist: one card per step with its state, why it
 * matters, what the data says, and the form or link to finish it. The first
 * unfinished step starts open; finished steps fold away behind "Edit".
 */
export function SetupChecklist({
  steps,
  panels,
  initialBuildStart,
  readOnly = false,
}: {
  steps: ChecklistStep[];
  /** Someone who can't change setup: finished steps say "View", not "Edit". */
  readOnly?: boolean;
  /** What each step shows when open (forms, links, lists), by step key. */
  panels: Record<string, React.ReactNode>;
  initialBuildStart: string;
}) {
  const [open, setOpen] = useState<Set<string>>(() => {
    const key = firstOpen(steps);
    return new Set(key ? [key] : []);
  });
  const [buildStart, setBuildStart] = useState(initialBuildStart);

  // "Edit details" links land on /CODE/setup#details: open and show that step.
  useEffect(() => {
    function fromHash() {
      const key = window.location.hash.slice(1);
      if (!key || !steps.some((s) => s.key === key)) return;
      setOpen((prev) => new Set(prev).add(key));
      requestAnimationFrame(() => document.getElementById(key)?.scrollIntoView({ block: "start" }));
    }
    fromHash();
    window.addEventListener("hashchange", fromHash);
    return () => window.removeEventListener("hashchange", fromHash);
  }, [steps]);

  const advance = useCallback(
    (fromKey: string) => {
      const index = steps.findIndex((s) => s.key === fromKey);
      const unfinished = (s: ChecklistStep) =>
        s.key !== fromKey && (s.state === "todo" || s.state === "waiting");
      const next =
        steps.slice(index + 1).find(unfinished) ?? steps.slice(0, index).find(unfinished);
      setOpen((prev) => {
        const out = new Set(prev);
        out.delete(fromKey);
        if (next) out.add(next.key);
        return out;
      });
      if (next) {
        requestAnimationFrame(() =>
          document.getElementById(next.key)?.scrollIntoView({ block: "nearest" }),
        );
      }
    },
    [steps],
  );

  const value = useMemo(() => ({ buildStart, setBuildStart, advance }), [buildStart, advance]);

  return (
    <SetupContext.Provider value={value}>
      <ol className="flex flex-col gap-3">
        {steps.map((step, i) => {
          const isOpen = open.has(step.key);
          const panelId = `step-${step.key}-panel`;
          return (
            <li
              key={step.key}
              id={step.key}
              className={cn(
                "scroll-mt-20 rounded-lg border",
                isOpen && step.state !== "done" && "border-foreground/20 shadow-xs",
              )}
            >
              <button
                type="button"
                className="hover:bg-muted/40 flex w-full items-start gap-3 rounded-lg p-4 text-left"
                aria-expanded={isOpen}
                aria-controls={panelId}
                onClick={() =>
                  setOpen((prev) => {
                    const out = new Set(prev);
                    if (out.has(step.key)) out.delete(step.key);
                    else out.add(step.key);
                    return out;
                  })
                }
              >
                <StateIcon state={step.state} />
                <span className="min-w-0 flex-1 space-y-0.5">
                  <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
                    <span className="text-sm font-semibold">
                      <span className="text-muted-foreground tabular-nums">{i + 1}.</span>{" "}
                      {step.title}
                      <span className="sr-only">{`, ${STATE_TEXT[step.state]}.`}</span>
                    </span>
                    {step.level !== "essential" && (
                      <span className="text-muted-foreground rounded border px-1.5 text-[11px] leading-5">
                        {step.level === "recommended" ? "Recommended" : "Optional"}
                      </span>
                    )}
                    {step.shared && (
                      <span className="text-muted-foreground rounded border px-1.5 text-[11px] leading-5">
                        Shared by all events
                      </span>
                    )}
                    {step.state === "waiting" && (
                      <span className="rounded bg-amber-50 px-1.5 text-[11px] leading-5 font-medium text-amber-800 dark:bg-amber-950 dark:text-amber-300">
                        Waiting
                      </span>
                    )}
                  </span>
                  <span className="text-muted-foreground block text-sm">{step.detail}</span>
                </span>
                <span className="text-muted-foreground flex shrink-0 items-center gap-1 text-xs font-medium">
                  {step.state === "done" && !isOpen ? (readOnly ? "View" : "Edit") : null}
                  <ChevronDown
                    className={cn("size-4 transition-transform", isOpen && "rotate-180")}
                    aria-hidden
                  />
                </span>
              </button>
              {isOpen && (
                <div id={panelId} className="space-y-4 border-t px-4 pt-3 pb-4">
                  <p className="text-muted-foreground text-sm">{step.reason}</p>
                  {panels[step.key]}
                </div>
              )}
            </li>
          );
        })}
      </ol>
    </SetupContext.Provider>
  );
}
