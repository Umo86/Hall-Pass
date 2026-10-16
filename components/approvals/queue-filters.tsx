"use client";

import { useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { cn } from "@/lib/utils";

/**
 * The event picker and search box above a list. The event applies as soon
 * as it is picked; the search on Enter. Other filters in the address are kept.
 */
export function ListFilters({
  events,
  eventCode,
  search,
  keep,
  searchLabel = "Search by name or ref",
  className,
}: {
  events: { code: string; name: string }[];
  eventCode: string | null;
  search: string;
  /** Other parameters to keep (tab, filter, all…). */
  keep: Record<string, string | undefined>;
  searchLabel?: string;
  className?: string;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [q, setQ] = useState(search);

  function go(next: { event?: string | null; q?: string }) {
    const params = new URLSearchParams();
    for (const [k, v] of Object.entries(keep)) if (v) params.set(k, v);
    const ev = next.event !== undefined ? next.event : eventCode;
    if (ev) params.set("event", ev);
    const text = (next.q ?? q).trim();
    if (text) params.set("q", text);
    const qs = params.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname);
  }

  return (
    <form
      role="search"
      className={cn("flex flex-wrap items-center gap-2", className)}
      onSubmit={(e) => {
        e.preventDefault();
        go({});
      }}
    >
      {events.length > 1 && (
        <SelectNative
          aria-label="Event"
          value={eventCode ?? ""}
          onChange={(e) => go({ event: e.target.value || null })}
          className="h-9 w-full sm:w-56"
        >
          <option value="">All events</option>
          {events.map((ev) => (
            <option key={ev.code} value={ev.code}>
              {ev.name}
            </option>
          ))}
        </SelectNative>
      )}
      <div className="relative w-full sm:w-64">
        <Search
          className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
          aria-hidden
        />
        <Input
          type="search"
          aria-label={searchLabel}
          placeholder={`${searchLabel}…`}
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="h-9 pl-8"
        />
      </div>
    </form>
  );
}
