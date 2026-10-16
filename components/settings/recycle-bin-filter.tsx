"use client";

import { usePathname, useRouter } from "next/navigation";
import { SelectNative } from "@/components/ui/select-native";

/** Recycle bin: which event to show (in the address, so it survives a reload). */
export function RecycleBinFilter({
  events,
  value,
}: {
  events: { code: string; name: string; count: number }[];
  value: string;
}) {
  const router = useRouter();
  const pathname = usePathname();
  return (
    <SelectNative
      aria-label="Show deleted items from"
      value={value}
      onChange={(e) => {
        const v = e.target.value;
        router.push(v ? `${pathname}?event=${encodeURIComponent(v)}` : pathname, { scroll: false });
      }}
      className="h-11 w-full sm:h-9 sm:w-80"
    >
      <option value="">All events</option>
      {events.map((e) => (
        <option key={e.code} value={e.code}>
          {e.name} ({e.code}) · {e.count} deleted
        </option>
      ))}
    </SelectNative>
  );
}
