"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * A box that scrolls sideways when its content is wider than the screen.
 * A second, always-visible scrollbar sits on top (with ◀ ▶ buttons), so
 * people don't have to scroll to the bottom of a long table to find it.
 */
export function ScrollX({
  className,
  label = "table",
  children,
}: {
  className?: string;
  label?: string;
  children: React.ReactNode;
}) {
  const box = useRef<HTMLDivElement>(null);
  const bar = useRef<HTMLDivElement>(null);
  const syncing = useRef(false);
  const [contentWidth, setContentWidth] = useState(0);
  const [overflows, setOverflows] = useState(false);
  const [atStart, setAtStart] = useState(true);
  const [atEnd, setAtEnd] = useState(false);

  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const measure = () => {
      setContentWidth(el.scrollWidth);
      setOverflows(el.scrollWidth > el.clientWidth + 1);
      setAtStart(el.scrollLeft <= 0);
      setAtEnd(el.scrollLeft + el.clientWidth >= el.scrollWidth - 1);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    if (el.firstElementChild) ro.observe(el.firstElementChild);
    return () => ro.disconnect();
  }, []);

  // Keep the two scrollbars in step without each one re-triggering the other.
  const follow = (from: HTMLDivElement | null, to: HTMLDivElement | null) => {
    if (!from || !to) return;
    if (syncing.current) {
      syncing.current = false;
    } else if (to.scrollLeft !== from.scrollLeft) {
      syncing.current = true;
      to.scrollLeft = from.scrollLeft;
    }
    const el = box.current;
    if (el) {
      setAtStart(el.scrollLeft <= 0);
      setAtEnd(el.scrollLeft + el.clientWidth >= el.scrollWidth - 1);
    }
  };

  const nudge = (dir: 1 | -1) => {
    const el = box.current;
    if (el) el.scrollBy({ left: dir * el.clientWidth * 0.8, behavior: "smooth" });
  };

  return (
    <div>
      {overflows && (
        <div className="mb-1 flex items-center gap-1">
          <button
            type="button"
            className="text-muted-foreground hover:text-foreground hover:bg-muted rounded p-0.5 disabled:opacity-30"
            aria-label={`Scroll ${label} left`}
            disabled={atStart}
            onClick={() => nudge(-1)}
          >
            <ChevronLeft className="size-4" />
          </button>
          <div
            ref={bar}
            className="scrollbar-visible h-3 min-w-0 flex-1 overflow-x-auto overflow-y-hidden"
            onScroll={() => follow(bar.current, box.current)}
            data-testid="scroll-x-bar"
          >
            <div style={{ width: contentWidth, height: 1 }} />
          </div>
          <button
            type="button"
            className="text-muted-foreground hover:text-foreground hover:bg-muted rounded p-0.5 disabled:opacity-30"
            aria-label={`Scroll ${label} right`}
            disabled={atEnd}
            onClick={() => nudge(1)}
          >
            <ChevronRight className="size-4" />
          </button>
        </div>
      )}
      <div
        ref={box}
        className={cn("scrollbar-visible overflow-auto", className)}
        onScroll={() => follow(box.current, bar.current)}
      >
        {children}
      </div>
    </div>
  );
}
