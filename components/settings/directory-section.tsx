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
import { saveDirectoryEntry } from "@/app/actions/directory";

export type DirectoryField = {
  key: string;
  label: string;
  type?: "text" | "email" | "date" | "select";
  required?: boolean;
  options?: { value: string; label: string }[];
  /** Shown as a column in the list. */
  listed?: boolean;
  placeholder?: string;
};

type Row = { id: string } & Record<string, string | null>;

/**
 * A small list with add/edit dialogs for one kind of reference data
 * (events, venues, suppliers, contractors). Everything is plain text.
 */
export function DirectorySection({
  type,
  noun,
  fields,
  rows,
  canEdit,
}: {
  type: "event" | "venue" | "supplier" | "contractor";
  noun: string;
  fields: DirectoryField[];
  rows: Row[];
  canEdit: boolean;
}) {
  const [editing, setEditing] = useState<Row | "new" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const listed = fields.filter((f) => f.listed);
  const current = editing === "new" ? null : editing;

  return (
    <div className="space-y-2">
      {rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No {noun.toLowerCase()}s yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-b last:border-0">
                  {listed.map((f, i) => (
                    <td
                      key={f.key}
                      className={`px-3 py-2 ${i === 0 ? "font-medium" : "text-muted-foreground"}`}
                    >
                      {f.options?.find((o) => o.value === r[f.key])?.label ?? r[f.key] ?? "—"}
                    </td>
                  ))}
                  {canEdit && (
                    <td className="px-3 py-2 text-right">
                      <Button size="sm" variant="outline" onClick={() => setEditing(r)}>
                        Edit
                      </Button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {canEdit && (
        <Button size="sm" variant="outline" onClick={() => setEditing("new")}>
          <Plus className="size-4" /> Add {noun.toLowerCase()}
        </Button>
      )}

      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{current ? `Edit ${noun.toLowerCase()}` : `Add ${noun.toLowerCase()}`}</DialogTitle>
            <DialogDescription>Only the name is required unless marked.</DialogDescription>
          </DialogHeader>
          <form
            key={current?.id ?? "new"}
            className="grid gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const fd = new FormData(e.currentTarget);
              const values = Object.fromEntries(fields.map((f) => [f.key, fd.get(f.key) ?? ""]));
              setError(null);
              start(async () => {
                const res = await saveDirectoryEntry({ type, id: current?.id, values });
                if (!res.ok) setError(res.error);
                else {
                  setEditing(null);
                  router.refresh();
                }
              });
            }}
          >
            {fields.map((f) => (
              <div key={f.key} className="space-y-1.5">
                <Label htmlFor={`${type}-${f.key}`}>
                  {f.label}
                  {f.required ? "" : " (optional)"}
                </Label>
                {f.type === "select" ? (
                  <SelectNative
                    id={`${type}-${f.key}`}
                    name={f.key}
                    defaultValue={current?.[f.key] ?? f.options?.[0]?.value}
                  >
                    {f.options?.map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </SelectNative>
                ) : (
                  <Input
                    id={`${type}-${f.key}`}
                    name={f.key}
                    type={f.type ?? "text"}
                    required={f.required}
                    placeholder={f.placeholder}
                    defaultValue={current?.[f.key] ?? ""}
                  />
                )}
              </div>
            ))}
            {error && <p className="text-destructive text-sm">{error}</p>}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setEditing(null)}>
                Cancel
              </Button>
              <Button type="submit" disabled={pending}>
                Save
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
