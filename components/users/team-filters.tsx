"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Search, SlidersHorizontal, X } from "lucide-react";
import { roleLabel } from "@/lib/format";
import { STAFF_ROLES } from "@/lib/users/rules";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { segmentClass, SegmentGroup } from "@/components/ui/segmented";
import { cn } from "@/lib/utils";

/**
 * Search and filters for Users → Team. Everything lives in the address
 * (?q, ?dept, ?role, ?status), so the back button and shared links work.
 * On a phone the filters fold behind a "Filters" button.
 */
export function TeamFilters({
  departments,
  showStatus,
}: {
  departments: { id: string; name: string; isArchived: boolean }[];
  /** Admins also filter by Active / Invited. */
  showStatus: boolean;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");
  const [open, setOpen] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dept = params.get("dept") ?? "";
  const role = params.get("role") ?? "";
  const status = params.get("status") ?? "";
  const active = [dept, role, status].filter(Boolean).length;

  /** Typing replaces the history entry, so Back doesn't step through every letter. */
  function go(changes: Record<string, string>, mode: "push" | "replace" = "push") {
    const next = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(changes)) {
      if (v) next.set(k, v);
      else next.delete(k);
    }
    next.delete("page");
    const qs = next.toString();
    router[mode](qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }

  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );

  function typed(value: string) {
    setQ(value);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => go({ q: value.trim() }, "replace"), 300);
  }

  const live = departments.filter((d) => !d.isArchived);
  const archived = departments.filter((d) => d.isArchived);

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <form
          role="search"
          className="relative min-w-0 flex-1 sm:max-w-xs"
          onSubmit={(e) => {
            e.preventDefault();
            go({ q: q.trim() });
          }}
        >
          <Search
            className="text-muted-foreground pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2"
            aria-hidden
          />
          <Input
            type="search"
            value={q}
            onChange={(e) => typed(e.target.value)}
            placeholder="Search name or email"
            aria-label="Search name or email"
            className="h-11 pl-9 sm:h-9"
          />
        </form>
        <Button
          type="button"
          variant="outline"
          className="h-11 sm:hidden"
          aria-expanded={open}
          aria-controls="team-filters"
          onClick={() => setOpen((o) => !o)}
        >
          <SlidersHorizontal aria-hidden />
          Filters{active ? ` (${active})` : ""}
        </Button>
        <div
          id="team-filters"
          className={cn(
            "flex-wrap items-center gap-2",
            open
              ? "fixed inset-x-0 bottom-0 z-50 flex border-t bg-background p-4 shadow-lg"
              : "hidden",
            "sm:static sm:z-auto sm:flex sm:border-0 sm:bg-transparent sm:p-0 sm:shadow-none",
          )}
        >
          <div className="flex w-full items-center justify-between sm:hidden">
            <p className="text-sm font-medium">Filters</p>
            <Button
              type="button"
              variant="ghost"
              size="touch"
              aria-label="Close filters"
              onClick={() => setOpen(false)}
            >
              <X aria-hidden />
            </Button>
          </div>
          <SelectNative
            aria-label="Department"
            value={dept}
            onChange={(e) => go({ dept: e.target.value })}
            className="h-11 w-full sm:h-9 sm:w-48"
          >
            <option value="">All departments</option>
            {live.map((d) => (
              <option key={d.id} value={d.id}>
                {d.name}
              </option>
            ))}
            {archived.map((d) => (
              <option key={d.id} value={d.id}>
                {d.name} (archived)
              </option>
            ))}
            <option value="none">No department</option>
          </SelectNative>
          <SelectNative
            aria-label="Role"
            value={role}
            onChange={(e) => go({ role: e.target.value })}
            className="h-11 w-full sm:h-9 sm:w-44"
          >
            <option value="">All roles</option>
            {STAFF_ROLES.map((r) => (
              <option key={r} value={r}>
                {roleLabel(r)}
              </option>
            ))}
          </SelectNative>
          {showStatus && (
            <SegmentGroup label="Status" className="w-full sm:w-auto">
              {[
                ["", "All"],
                ["active", "Active"],
                ["invited", "Invited"],
              ].map(([value, label]) => (
                <button
                  key={label}
                  type="button"
                  className={cn(segmentClass(status === value), "h-11 flex-1 sm:h-9 sm:flex-none")}
                  aria-pressed={status === value}
                  onClick={() => go({ status: value })}
                >
                  {label}
                </button>
              ))}
            </SegmentGroup>
          )}
          {active > 0 && (
            <Button
              type="button"
              variant="ghost"
              className="h-11 sm:h-9"
              onClick={() => {
                setQ("");
                go({ dept: "", role: "", status: "", q: "" });
              }}
            >
              Clear filters
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
