"use client";

import { useId, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useConfirm } from "@/components/confirm-dialog";
import { saveSupplierService, setSupplierServiceArchived } from "@/app/actions/lists";
import { plural } from "@/lib/format";

export type ServiceRow = { id: string; name: string; isArchived: boolean; supplierCount: number };

type Result = { ok: boolean; error?: string };

/**
 * "What they do": the list of services suppliers can be ticked for. Rename,
 * archive (suppliers stop showing it; restore brings it back) and add.
 */
export function ServicesEditor({ rows, canEdit }: { rows: ServiceRow[]; canEdit: boolean }) {
  const [error, setError] = useState<string | null>(null);
  const [renaming, setRenaming] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const ids = useId();
  const errorId = `${ids}-error`;

  function run(fn: () => Promise<Result>, done: string, after?: () => void) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) {
        setError(res.error ?? "Something went wrong — please try again");
        return;
      }
      toast.success(done);
      after?.();
      router.refresh();
    });
  }

  async function archive(s: ServiceRow) {
    const ok = await confirm({
      title: `Archive ${s.name}?`,
      description:
        s.supplierCount > 0
          ? `${plural(s.supplierCount, "supplier")} will stop showing it, and it won't be offered when you add a supplier. You can restore it later and they get it back.`
          : "It won't be offered when you add a supplier. You can restore it later.",
      confirmLabel: "Archive",
    });
    if (ok)
      run(() => setSupplierServiceArchived({ id: s.id, archived: true }), `${s.name} archived`);
  }

  const active = rows.filter((r) => !r.isArchived);
  const archived = rows.filter((r) => r.isArchived);

  return (
    <div className="space-y-3">
      {active.length === 0 ? (
        <p className="text-muted-foreground rounded-md border border-dashed px-3 py-4 text-center text-sm">
          Nothing on the list yet. Add the kinds of work your suppliers do — printing, AV, staffing…
        </p>
      ) : (
        <ul className="divide-y rounded-lg border" aria-label="What suppliers do">
          {active.map((s) => (
            <li key={s.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
              {renaming === s.id ? (
                <form
                  className="flex flex-1 flex-wrap gap-2"
                  onSubmit={(e) => {
                    e.preventDefault();
                    const name = String(new FormData(e.currentTarget).get("name") ?? "").trim();
                    run(
                      () => saveSupplierService({ id: s.id, name }),
                      `Renamed to ${name}`,
                      () => setRenaming(null),
                    );
                  }}
                >
                  <Input
                    name="name"
                    defaultValue={s.name}
                    aria-label={`New name for ${s.name}`}
                    aria-describedby={error ? errorId : undefined}
                    className="h-9 min-w-0 flex-1"
                    maxLength={80}
                    required
                    autoFocus
                  />
                  <Button size="sm" type="submit" disabled={pending}>
                    Save
                  </Button>
                  <Button size="sm" type="button" variant="ghost" onClick={() => setRenaming(null)}>
                    Cancel
                  </Button>
                </form>
              ) : (
                <>
                  <span className="min-w-0 flex-1 font-medium break-words">{s.name}</span>
                  <span className="text-muted-foreground text-xs whitespace-nowrap">
                    {plural(s.supplierCount, "supplier")}
                  </span>
                  {canEdit && (
                    <span className="flex gap-1">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setRenaming(s.id)}
                        aria-label={`Rename ${s.name}`}
                      >
                        Rename
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={pending}
                        onClick={() => archive(s)}
                        aria-label={`Archive ${s.name}`}
                      >
                        Archive
                      </Button>
                    </span>
                  )}
                </>
              )}
            </li>
          ))}
        </ul>
      )}
      {canEdit && (
        <form
          className="flex max-w-md gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            const form = e.currentTarget;
            const name = String(new FormData(form).get("name") ?? "").trim();
            run(
              () => saveSupplierService({ name }),
              `${name} added`,
              () => form.reset(),
            );
          }}
        >
          <Input
            name="name"
            placeholder="e.g. Cleaning"
            aria-label="New service"
            aria-describedby={error ? errorId : undefined}
            className="h-11 sm:h-9"
            maxLength={80}
            required
          />
          <Button type="submit" disabled={pending} className="h-11 sm:h-9">
            Add
          </Button>
        </form>
      )}
      {error && (
        <p id={errorId} role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      {archived.length > 0 && canEdit && (
        <details>
          <summary className="text-muted-foreground cursor-pointer py-1 text-sm select-none">
            Archived ({archived.length})
          </summary>
          <ul className="mt-2 divide-y rounded-lg border text-sm">
            {archived.map((s) => (
              <li key={s.id} className="flex items-center justify-between gap-2 px-3 py-1.5">
                <span className="text-muted-foreground break-words">{s.name}</span>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pending}
                  aria-label={`Restore ${s.name}`}
                  onClick={() =>
                    run(
                      () => setSupplierServiceArchived({ id: s.id, archived: false }),
                      `${s.name} restored`,
                    )
                  }
                >
                  Restore
                </Button>
              </li>
            ))}
          </ul>
        </details>
      )}
      {confirmDialog}
    </div>
  );
}
