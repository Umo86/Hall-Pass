"use client";

import { usePathname, useRouter } from "next/navigation";
import { SelectNative } from "@/components/ui/select-native";

/** "All events" or one event; applies as soon as it is picked, keeping the other filters. */
export function EventFilter({
  events,
  value,
  keep,
}: {
  events: { code: string; name: string }[];
  value: string | null;
  keep: Record<string, string | undefined>;
}) {
  const router = useRouter();
  const pathname = usePathname();
  if (events.length < 2 && !value) return null;
  return (
    <SelectNative
      aria-label="Show tasks for"
      value={value ?? ""}
      className="h-9 w-full sm:w-56"
      onChange={(e) => {
        const params = new URLSearchParams();
        for (const [k, v] of Object.entries(keep)) if (v) params.set(k, v);
        if (e.target.value) params.set("event", e.target.value);
        const qs = params.toString();
        router.push(qs ? `${pathname}?${qs}` : pathname);
      }}
    >
      <option value="">All events</option>
      {events.map((ev) => (
        <option key={ev.code} value={ev.code}>
          {ev.name}
        </option>
      ))}
    </SelectNative>
  );
}
