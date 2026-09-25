"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
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
import { saveItemType, setItemTypeArchived } from "@/app/actions/lists";

export type ItemTypeRow = {
  id: string;
  name: string;
  kind: "signage" | "sponsorship_item";
  format: "print" | "digital" | null;
  defaultFixingMethod: string | null;
  requiresVenueApprovalDefault: boolean;
  isArchived: boolean;
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

function describe(t: ItemTypeRow) {
  if (t.kind === "sponsorship_item") return "Sponsorship item";
  return t.format === "digital" ? "Digital signage" : "Print signage";
}

/** Settings → Signage types: the list people pick from when adding items. */
export function ItemTypesEditor({ rows, canEdit }: { rows: ItemTypeRow[]; canEdit: boolean }) {
  const [editing, setEditing] = useState<ItemTypeRow | "new" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [kind, setKind] = useState<"signage" | "sponsorship_item">("signage");
  const router = useRouter();
  const current = editing === "new" ? null : editing;
  const active = rows.filter((r) => !r.isArchived);
  const hidden = rows.filter((r) => r.isArchived);

  function open(row: ItemTypeRow | "new") {
    setError(null);
    setKind(row === "new" ? "signage" : row.kind);
    setEditing(row);
  }

  function toggle(row: ItemTypeRow) {
    setError(null);
    start(async () => {
      const res = await setItemTypeArchived({ id: row.id, archived: !row.isArchived });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  const list = (items: ItemTypeRow[]) => (
    <ul className="divide-y rounded-lg border">
      {items.map((t) => (
        <li key={t.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 text-sm">
          <span className={`min-w-0 flex-1 font-medium ${t.isArchived ? "text-muted-foreground line-through" : ""}`}>
            {t.name}
          </span>
          <span className="text-muted-foreground text-xs">
            {describe(t)}
            {t.requiresVenueApprovalDefault ? " · venue approval" : ""}
          </span>
          {canEdit && (
            <span className="flex gap-1">
              {!t.isArchived && (
                <Button size="sm" variant="outline" onClick={() => open(t)}>
                  Edit
                </Button>
              )}
              <Button size="sm" variant="ghost" disabled={pending} onClick={() => toggle(t)}>
                {t.isArchived ? "Restore" : "Hide"}
              </Button>
            </span>
          )}
        </li>
      ))}
    </ul>
  );

  return (
    <div className="space-y-3">
      {active.length === 0 ? (
        <p className="text-muted-foreground text-sm">No signage types yet.</p>
      ) : (
        list(active)
      )}
      {canEdit && (
        <Button size="sm" variant="outline" onClick={() => open("new")}>
          <Plus className="size-4" /> Add a type
        </Button>
      )}
      {hidden.length > 0 && (
        <details>
          <summary className="text-muted-foreground cursor-pointer text-xs select-none">
            Hidden types ({hidden.length})
          </summary>
          <div className="mt-2">{list(hidden)}</div>
        </details>
      )}
      {error && !editing && <p className="text-destructive text-sm">{error}</p>}

      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{current ? `Edit ${current.name}` : "Add a signage type"}</DialogTitle>
            <DialogDescription>
              People choose from these when they add signage or sponsorship items.
            </DialogDescription>
          </DialogHeader>
          <form
            id="item-type-form"
            className="grid gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const fd = new FormData(e.currentTarget);
              setError(null);
              start(async () => {
                const res = await saveItemType({
                  id: current?.id,
                  name: fd.get("name"),
                  kind: fd.get("kind"),
                  format: fd.get("format") ?? null,
                  defaultFixingMethod: fd.get("defaultFixingMethod") ?? null,
                  requiresVenueApprovalDefault: fd.get("requiresVenueApprovalDefault") === "on",
                });
                if (!res.ok) setError(res.error);
                else {
                  setEditing(null);
                  router.refresh();
                }
              });
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="type-name">Name</Label>
              <Input id="type-name" name="name" defaultValue={current?.name ?? ""} required placeholder="e.g. Pull-up banner" />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="type-kind">Used for</Label>
              <SelectNative
                id="type-kind"
                name="kind"
                value={kind}
                onChange={(e) => setKind(e.target.value as typeof kind)}
              >
                <option value="signage">Signage</option>
                <option value="sponsorship_item">Sponsorship item (bags, lanyards…)</option>
              </SelectNative>
            </div>
            {kind === "signage" && (
              <>
                <fieldset className="space-y-1.5">
                  <legend className="text-sm font-medium">Print or digital</legend>
                  <div className="flex gap-4 text-sm">
                    {(["print", "digital"] as const).map((f) => (
                      <label key={f} className="flex items-center gap-2">
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
                  <Label htmlFor="type-fixing">Usual fixing</Label>
                  <SelectNative
                    id="type-fixing"
                    name="defaultFixingMethod"
                    defaultValue={current?.defaultFixingMethod ?? ""}
                  >
                    {FIXINGS.map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </SelectNative>
                </div>
                <label className="flex items-center gap-2 text-sm">
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
            {error && <p className="text-destructive text-sm">{error}</p>}
          </form>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button type="submit" form="item-type-form" disabled={pending}>
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
