"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { saveSupplierService, setSupplierServiceArchived } from "@/app/actions/lists";

export type ServiceRow = { id: string; name: string; isArchived: boolean; supplierCount: number };

/** Settings → Supplier services: what suppliers can be marked as doing. */
export function ServicesEditor({ rows, canEdit }: { rows: ServiceRow[]; canEdit: boolean }) {
  const [error, setError] = useState<string | null>(null);
  const [renaming, setRenaming] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function run(fn: () => Promise<{ ok: boolean; error?: string }>, after?: () => void) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) setError(res.error ?? "Something went wrong");
      else after?.();
      router.refresh();
    });
  }

  const active = rows.filter((r) => !r.isArchived);
  const removed = rows.filter((r) => r.isArchived);

  return (
    <div className="space-y-3">
      <ul className="divide-y rounded-lg border">
        {active.length === 0 && (
          <li className="text-muted-foreground px-3 py-2 text-sm">No services yet.</li>
        )}
        {active.map((s) => (
          <li key={s.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
            {renaming === s.id ? (
              <form
                className="flex flex-1 gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  const name = new FormData(e.currentTarget).get("name");
                  run(() => saveSupplierService({ id: s.id, name }), () => setRenaming(null));
                }}
              >
                <Input name="name" defaultValue={s.name} aria-label={`New name for ${s.name}`} className="h-8" autoFocus />
                <Button size="sm" type="submit" disabled={pending}>
                  Save
                </Button>
                <Button size="sm" type="button" variant="ghost" onClick={() => setRenaming(null)}>
                  Cancel
                </Button>
              </form>
            ) : (
              <>
                <span className="min-w-0 flex-1 font-medium">{s.name}</span>
                <span className="text-muted-foreground text-xs">
                  {s.supplierCount} supplier{s.supplierCount === 1 ? "" : "s"}
                </span>
                {canEdit && (
                  <span className="flex gap-1">
                    <Button size="sm" variant="outline" onClick={() => setRenaming(s.id)}>
                      Rename
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={pending}
                      onClick={() => run(() => setSupplierServiceArchived({ id: s.id, archived: true }))}
                    >
                      Remove
                    </Button>
                  </span>
                )}
              </>
            )}
          </li>
        ))}
      </ul>
      {canEdit && (
        <form
          className="flex max-w-md gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            const form = e.currentTarget;
            const name = new FormData(form).get("name");
            run(() => saveSupplierService({ name }), () => form.reset());
          }}
        >
          <Input name="name" placeholder="e.g. Cleaning" aria-label="New service" className="h-9" required />
          <Button type="submit" disabled={pending}>
            Add service
          </Button>
        </form>
      )}
      {removed.length > 0 && canEdit && (
        <details>
          <summary className="text-muted-foreground cursor-pointer text-xs select-none">
            Removed services ({removed.length})
          </summary>
          <ul className="mt-2 space-y-1 text-sm">
            {removed.map((s) => (
              <li key={s.id} className="flex items-center gap-2">
                <span className="text-muted-foreground line-through">{s.name}</span>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pending}
                  onClick={() => run(() => setSupplierServiceArchived({ id: s.id, archived: false }))}
                >
                  Restore
                </Button>
              </li>
            ))}
          </ul>
        </details>
      )}
      {error && <p className="text-destructive text-sm">{error}</p>}
    </div>
  );
}
