"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Search, SlidersHorizontal } from "lucide-react";
import { roleLabel } from "@/lib/format";
import { STAFF_ROLES } from "@/lib/users/rules";
import { STALE_DAYS, STATUS_FILTERS } from "@/lib/users/list";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

type Dept = { id: string; name: string; isArchived: boolean };

/**
 * Search and filters for Users → Team. Everything lives in the address
 * (?q, ?dept, ?role — "manager" for managers — ?status and ?activity=stale),
 * so the back button and shared links work. A department manager's list
 * starts on their own department; "All departments" is ?dept=all for them.
 * On a phone the filters open in a dialog behind a "Filters" button.
 */
export function TeamFilters({
  departments,
  showStatus,
  defaultDept = null,
}: {
  departments: Dept[];
  /** People who manage the team also filter by status and last active. */
  showStatus: boolean;
  /** The department the list starts on (a department manager's own). */
  defaultDept?: string | null;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");
  const [open, setOpen] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const rawDept = params.get("dept");
  const dept = rawDept ?? defaultDept ?? "";
  const role = params.get("role") ?? "";
  const status = params.get("status") ?? "";
  const stale = params.get("activity") === "stale";
  const allValue = defaultDept ? "all" : "";
  const deptFiltered = dept !== "" && dept !== "all" && dept !== defaultDept;
  const active = [deptFiltered, role, status, stale].filter(Boolean).length;

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

  function clear() {
    setQ("");
    go({ dept: "", role: "", status: "", activity: "", q: "" });
  }

  const live = departments.filter((d) => !d.isArchived);
  const archived = departments.filter((d) => d.isArchived);

  const fields = (idPrefix: string) => (
    <>
      <SelectNative
        id={`${idPrefix}-dept`}
        aria-label="Department"
        value={dept === "all" ? allValue : dept}
        onChange={(e) =>
          go({ dept: e.target.value === "" && defaultDept ? "all" : e.target.value })
        }
        className="h-11 w-full sm:h-9 sm:w-48"
      >
        <option value={allValue}>All departments</option>
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
        id={`${idPrefix}-role`}
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
        <option value="manager">Managers</option>
      </SelectNative>
      {showStatus && (
        <>
          <SelectNative
            id={`${idPrefix}-status`}
            aria-label="Status"
            value={status}
            onChange={(e) => go({ status: e.target.value })}
            className="h-11 w-full sm:h-9 sm:w-40"
          >
            {STATUS_FILTERS.map((s) => (
              <option key={s.label} value={s.value}>
                {s.value ? s.label : "All statuses"}
              </option>
            ))}
          </SelectNative>
          <label className="flex min-h-11 items-center gap-2 text-sm sm:min-h-0">
            <input
              type="checkbox"
              className="accent-primary size-4"
              checked={stale}
              onChange={(e) => go({ activity: e.target.checked ? "stale" : "" })}
            />
            Not active for {STALE_DAYS} days
          </label>
        </>
      )}
    </>
  );

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2">
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
            placeholder="Search name, email or job title"
            aria-label="Search name, email or job title"
            className="h-11 pl-9 sm:h-9"
          />
        </form>
        <Button
          type="button"
          variant="outline"
          className="h-11 sm:hidden"
          aria-haspopup="dialog"
          onClick={() => setOpen(true)}
        >
          <SlidersHorizontal aria-hidden />
          Filters{active ? ` (${active})` : ""}
        </Button>
        <div className="hidden flex-wrap items-center gap-2 sm:flex">
          {fields("tf")}
          {active > 0 && (
            <Button type="button" variant="ghost" className="h-9" onClick={clear}>
              Clear filters
            </Button>
          )}
        </div>
      </div>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:hidden">
          <DialogHeader>
            <DialogTitle>Filters</DialogTitle>
            <DialogDescription>The list changes as you choose.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">{fields("tfm")}</div>
          <DialogFooter className="gap-2">
            {active > 0 && (
              <Button type="button" variant="ghost" className="h-11" onClick={clear}>
                Clear filters
              </Button>
            )}
            <Button type="button" className="h-11" onClick={() => setOpen(false)}>
              Done
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
