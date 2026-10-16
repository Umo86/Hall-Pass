"use client";

import { useId, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { useConfirm } from "@/components/confirm-dialog";
import { saveItemType, setItemTypeArchived } from "@/app/actions/lists";
import { plural } from "@/lib/format";

type Kind = "signage" | "sponsorship_item";

export type ItemTypeRow = {
  id: string;
  name: string;
  kind: Kind;
  format: "print" | "digital" | null;
  defaultFixingMethod: string | null;
  requiresVenueApprovalDefault: boolean;
  isArchived: boolean;
  /** Live items using the type. */
  itemCount: number;
};

const FIXINGS: [string, string][] = [
  ["", "— None —"],
  ["rigged", "Rigged (hung)"],
  ["freestanding", "Freestanding"],
  ["wall_mounted", "Wall mounted"],
  ["shell_mounted", "Shell scheme"],
  ["floor", "Floor"],
  ["digital", "Digital"],
  ["other", "Other"],
];
const FIXING_LABEL = new Map(FIXINGS.filter(([v]) => v));

const GROUPS: { kind: Kind; id: string; title: string; hint: string; add: string; noun: string }[] =
  [
    {
      kind: "signage",
      id: "signage",
      title: "Signage",
      hint: "Print or digital, the usual fixing and whether the venue normally approves it.",
      add: "Add signage type",
      noun: "signage type",
    },
    {
      kind: "sponsorship_item",
      id: "sponsorship",
      title: "Sponsorship items",
      hint: "Things sponsors pay to brand — lanyards, bags, registration and the like.",
      add: "Add sponsorship item type",
      noun: "sponsorship item type",
    },
  ];

function describe(t: ItemTypeRow): string {
  if (t.kind === "sponsorship_item") return "";
  return [
    t.format === "digital" ? "Digital" : "Print",
    // "Digital · Digital" says nothing twice.
    t.defaultFixingMethod && !(t.format === "digital" && t.defaultFixingMethod === "digital")
      ? FIXING_LABEL.get(t.defaultFixingMethod)
      : null,
    t.requiresVenueApprovalDefault ? "Venue approves" : null,
  ]
    .filter(Boolean)
    .join(" · ");
}

/**
 * Settings → Item types: what people pick from when they add a sign or a
 * sponsorship item, in two groups with their own Add button. Archiving
 * takes a type off the pickers; items already using it keep it.
 */
export function ItemTypesEditor({ rows, canEdit }: { rows: ItemTypeRow[]; canEdit: boolean }) {
  const [editing, setEditing] = useState<{ row: ItemTypeRow | null; kind: Kind } | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();

  async function toggle(row: ItemTypeRow) {
    if (!row.isArchived) {
      const ok = await confirm({
        title: `Archive ${row.name}?`,
        description: `People can't pick it for new items any more.${
          row.itemCount > 0 ? ` The ${plural(row.itemCount, "item")} already using it keep it.` : ""
        } You can restore it later.`,
        confirmLabel: "Archive",
      });
      if (!ok) return;
    }
    start(async () => {
      const res = await setItemTypeArchived({ id: row.id, archived: !row.isArchived });
      if (!res.ok) toast.error(res.error);
      else {
        toast.success(row.isArchived ? `${row.name} restored` : `${row.name} archived`);
        router.refresh();
      }
    });
  }

  return (
    <div className="space-y-8">
      {GROUPS.map((g) => {
        const list = rows.filter((r) => r.kind === g.kind);
        const active = list.filter((r) => !r.isArchived);
        const archived = list.filter((r) => r.isArchived);
        return (
          <section key={g.kind} id={g.id} aria-labelledby={`${g.id}-title`} className="space-y-3">
            <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <h2 id={`${g.id}-title`} className="text-base font-semibold">
                  {g.title}
                </h2>
                <p className="text-muted-foreground text-sm">{g.hint}</p>
              </div>
              {canEdit && (
                <Button
                  variant="outline"
                  onClick={() => setEditing({ row: null, kind: g.kind })}
                  className="h-11 w-fit sm:h-9"
                >
                  <Plus aria-hidden /> {g.add}
                </Button>
              )}
            </div>
            {active.length === 0 ? (
              <p className="text-muted-foreground rounded-md border border-dashed px-3 py-4 text-center text-sm">
                No {g.title.toLowerCase()} types yet.
              </p>
            ) : (
              <ul className="divide-y rounded-lg border" aria-label={`${g.title} types`}>
                {active.map((t) => (
                  <li key={t.id} className="flex items-center gap-3 px-3 py-2 text-sm">
                    <div className="min-w-0 flex-1">
                      <p className="font-medium break-words">{t.name}</p>
                      <p className="text-muted-foreground text-xs">
                        {[describe(t), plural(t.itemCount, "item")].filter(Boolean).join(" · ")}
                      </p>
                    </div>
                    {canEdit && (
                      <span className="flex shrink-0 gap-1">
                        <Button
                          size="touch"
                          variant="ghost"
                          onClick={() => setEditing({ row: t, kind: t.kind })}
                          aria-label={`Edit ${t.name}`}
                        >
                          <Pencil aria-hidden />
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          className="h-11 md:h-8"
                          disabled={pending}
                          onClick={() => toggle(t)}
                          aria-label={`Archive ${t.name}`}
                        >
                          Archive
                        </Button>
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            )}
            {archived.length > 0 && (
              <details>
                <summary className="text-muted-foreground hover:text-foreground cursor-pointer py-1 text-sm select-none">
                  Archived ({archived.length})
                </summary>
                <ul className="mt-2 divide-y rounded-lg border text-sm">
                  {archived.map((t) => (
                    <li key={t.id} className="flex items-center justify-between gap-2 px-3 py-1.5">
                      <span className="text-muted-foreground break-words">{t.name}</span>
                      {canEdit && (
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={pending}
                          onClick={() => toggle(t)}
                          aria-label={`Restore ${t.name}`}
                        >
                          Restore
                        </Button>
                      )}
                    </li>
                  ))}
                </ul>
              </details>
            )}
          </section>
        );
      })}
      {canEdit && (
        <ItemTypeDialog
          key={editing ? (editing.row?.id ?? `new-${editing.kind}`) : "closed"}
          editing={editing}
          onClose={() => setEditing(null)}
        />
      )}
      {confirmDialog}
    </div>
  );
}

function ItemTypeDialog({
  editing,
  onClose,
}: {
  editing: { row: ItemTypeRow | null; kind: Kind } | null;
  onClose: () => void;
}) {
  const current = editing?.row ?? null;
  const [kind, setKind] = useState<Kind>(editing?.kind ?? "signage");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const ids = useId();
  const errorId = `${ids}-error`;
  const noun = kind === "signage" ? "signage type" : "sponsorship item type";

  return (
    <Dialog open={editing !== null} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{current ? `Edit ${current.name}` : `Add a ${noun}`}</DialogTitle>
          <DialogDescription>
            {kind === "signage"
              ? "People choose from these when they add a sign."
              : "People choose from these when they add a sponsorship item."}
          </DialogDescription>
        </DialogHeader>
        <form
          id="item-type-form"
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            const name = String(fd.get("name") ?? "").trim();
            setError(null);
            start(async () => {
              const res = await saveItemType({
                id: current?.id,
                name,
                kind,
                format: kind === "signage" ? (fd.get("format") ?? "print") : null,
                defaultFixingMethod:
                  kind === "signage" ? fd.get("defaultFixingMethod") || null : null,
                requiresVenueApprovalDefault:
                  kind === "signage" && fd.get("requiresVenueApprovalDefault") === "on",
              });
              if (!res.ok) {
                setError(res.error);
                return;
              }
              toast.success(`${name} saved`);
              onClose();
              router.refresh();
            });
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor={`${ids}-name`}>Name</Label>
            <Input
              id={`${ids}-name`}
              name="name"
              defaultValue={current?.name ?? ""}
              required
              maxLength={100}
              placeholder={kind === "signage" ? "e.g. Pull-up banner" : "e.g. Branded lanyards"}
              aria-describedby={error ? errorId : undefined}
              className="h-11 sm:h-9"
            />
          </div>
          {current && (
            <div className="space-y-1.5">
              <Label htmlFor={`${ids}-kind`}>Used for</Label>
              <SelectNative
                id={`${ids}-kind`}
                value={kind}
                onChange={(e) => setKind(e.target.value as Kind)}
                className="h-11 sm:h-9"
              >
                <option value="signage">Signage</option>
                <option value="sponsorship_item">Sponsorship items</option>
              </SelectNative>
            </div>
          )}
          {kind === "signage" && (
            <>
              <fieldset className="space-y-1.5">
                <legend className="text-sm font-medium">Print or digital</legend>
                <div className="flex gap-4 text-sm">
                  {(["print", "digital"] as const).map((f) => (
                    <label key={f} className="flex min-h-9 items-center gap-2">
                      <input
                        type="radio"
                        name="format"
                        value={f}
                        defaultChecked={(current?.format ?? "print") === f}
                        className="size-4"
                      />
                      {f === "print" ? "Print" : "Digital"}
                    </label>
                  ))}
                </div>
              </fieldset>
              <div className="space-y-1.5">
                <Label htmlFor={`${ids}-fixing`}>Usual fixing</Label>
                <SelectNative
                  id={`${ids}-fixing`}
                  name="defaultFixingMethod"
                  defaultValue={current?.defaultFixingMethod ?? ""}
                  className="h-11 sm:h-9"
                >
                  {FIXINGS.map(([v, l]) => (
                    <option key={v} value={v}>
                      {l}
                    </option>
                  ))}
                </SelectNative>
              </div>
              <label className="flex min-h-9 items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  name="requiresVenueApprovalDefault"
                  className="size-4"
                  defaultChecked={current?.requiresVenueApprovalDefault ?? false}
                />
                Usually needs venue approval
              </label>
            </>
          )}
          {error && (
            <p id={errorId} role="alert" className="text-destructive text-sm">
              {error}
            </p>
          )}
        </form>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="item-type-form" disabled={pending}>
            {pending ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
