"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Check, ChevronsUpDown, Layers, Plus, Search } from "lucide-react";
import { editionCodeFromPath, switchShowPath } from "@/lib/edition-path";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { LAST_EVENT_COOKIE, LAST_EVENT_COOKIE_MAX_AGE } from "@/components/setup/last-event";
import { cn } from "@/lib/utils";

export type SwitcherEvent = {
  code: string;
  name: string;
  /** Upcoming & live (soonest first), past (newest first), archived. */
  group: "upcoming" | "past" | "archived";
  /** "5–7 Oct 2027 · NEC Birmingham". */
  line: string;
};

/** A search box appears once there are this many events. */
const SEARCH_FROM = 8;

const GROUP_LABELS: Record<SwitcherEvent["group"], string> = {
  upcoming: "Upcoming & live",
  past: "Past",
  archived: "Archived",
};

/**
 * The event picker in the header. Switching keeps you in the same section
 * of the other event. The event you were last in is remembered (cookie) for
 * pages that aren't about one event.
 */
export function EditionSwitcher({
  editions,
  defaultCode,
  navCode,
  canSetup,
}: {
  /** Already in display order within each group. */
  editions: SwitcherEvent[];
  /** The event pages without one in their address use. */
  defaultCode: string | null;
  /** The event the side navigation was worked out for (its setup progress). */
  navCode: string | null;
  canSetup: boolean;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [lastCode, setLastCode] = useState(defaultCode);
  const searchRef = useRef<HTMLInputElement>(null);
  const refreshedFor = useRef<string | null>(navCode);

  const pathCode = editionCodeFromPath(pathname)?.toUpperCase() ?? null;
  const inPath = pathCode ? editions.find((e) => e.code.toUpperCase() === pathCode) : undefined;
  // The event being looked at becomes the remembered one (for pages without one).
  if (inPath && inPath.code !== lastCode) setLastCode(inPath.code);
  const current =
    inPath ??
    editions.find((e) => e.code === lastCode) ??
    editions.find((e) => e.code === defaultCode) ??
    editions.find((e) => e.group !== "archived") ??
    editions[0];

  // Remember the event being looked at; when it isn't the one the side
  // navigation was built for, refresh once so its setup progress is right.
  useEffect(() => {
    if (!inPath) return;
    document.cookie = `${LAST_EVENT_COOKIE}=${encodeURIComponent(inPath.code)}; path=/; max-age=${LAST_EVENT_COOKIE_MAX_AGE}; samesite=lax`;
    if (canSetup && inPath.code !== navCode && refreshedFor.current !== inPath.code) {
      refreshedFor.current = inPath.code;
      router.refresh();
    }
  }, [inPath, navCode, canSetup, router]);

  const searching = query.trim().length > 0;
  const groups = useMemo(() => {
    const q = query.trim().toLowerCase();
    const matches = q
      ? editions.filter((e) => [e.name, e.code, e.line].some((v) => v.toLowerCase().includes(q)))
      : editions.filter((e) => e.group !== "archived");
    return (["upcoming", "past", "archived"] as const)
      .map((g) => ({ group: g, items: matches.filter((e) => e.group === g) }))
      .filter((g) => g.items.length > 0);
  }, [editions, query]);

  if (editions.length === 0) return null;

  return (
    <DropdownMenu
      onOpenChange={(open) => {
        if (!open) {
          setQuery("");
          return;
        }
        // The menu focuses itself when it opens; then hand focus to the search box.
        window.setTimeout(() => searchRef.current?.focus(), 0);
      }}
    >
      <DropdownMenuTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="max-w-[10rem] min-w-0 shrink gap-2 sm:max-w-none"
          aria-label={
            current ? `Event: ${current.name} (${current.code}). Choose another` : "Choose event"
          }
        >
          {/* Phones show the name (codes mean little at a glance); wider screens both. */}
          <span className="min-w-0 truncate font-medium sm:hidden">
            {current?.name ?? "Choose event"}
          </span>
          <span className="hidden font-medium sm:inline">{current?.code ?? "Choose event"}</span>
          <span className="text-muted-foreground hidden max-w-48 truncate sm:inline">
            {current?.name}
          </span>
          <ChevronsUpDown className="size-3.5 shrink-0 opacity-50" aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="start"
        className="max-h-[min(32rem,80vh)] w-80 max-w-[calc(100vw-1.5rem)] overflow-y-auto"
      >
        {editions.length >= SEARCH_FROM && (
          <div className="relative p-1">
            <Search
              className="text-muted-foreground pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2"
              aria-hidden
            />
            <input
              ref={searchRef}
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              // Letters go to the box, not the menu's type-to-jump.
              onKeyDown={(e) => {
                if (!["ArrowDown", "ArrowUp", "Escape", "Tab"].includes(e.key)) e.stopPropagation();
              }}
              placeholder="Find an event"
              aria-label="Find an event"
              className="border-input focus-visible:ring-ring h-8 w-full rounded-md border bg-transparent pr-2 pl-8 text-sm outline-none focus-visible:ring-2"
            />
          </div>
        )}
        {groups.length === 0 && (
          <p className="text-muted-foreground px-2 py-3 text-sm">
            {searching ? `No events match “${query}”.` : "No upcoming or past events."}
          </p>
        )}
        {groups.map((g, i) => (
          <DropdownMenuGroup key={g.group}>
            {i > 0 && <DropdownMenuSeparator />}
            <DropdownMenuLabel className="text-muted-foreground text-xs font-semibold">
              {GROUP_LABELS[g.group]}
            </DropdownMenuLabel>
            {g.items.map((e) => {
              const isCurrent = e.code === current?.code;
              return (
                <DropdownMenuItem
                  key={e.code}
                  onSelect={() => router.push(switchShowPath(pathname, e.code))}
                  className="items-start gap-2"
                  data-code={e.code}
                  aria-current={isCurrent ? "true" : undefined}
                >
                  <Check
                    className={cn("mt-0.5 size-4 shrink-0", !isCurrent && "invisible")}
                    aria-hidden
                  />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium">{e.name}</span>
                    <span className="text-muted-foreground block truncate text-xs">
                      {e.code} · {e.line}
                    </span>
                  </span>
                </DropdownMenuItem>
              );
            })}
          </DropdownMenuGroup>
        ))}
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link href="/events">
            <Layers aria-hidden /> All events
          </Link>
        </DropdownMenuItem>
        {canSetup && (
          <DropdownMenuItem asChild>
            <Link href="/start">
              <Plus aria-hidden /> New event
            </Link>
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
