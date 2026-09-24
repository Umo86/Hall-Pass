"use client";

import { useState, useTransition } from "react";
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
import { bulkSignageAction } from "@/app/actions/signage-bulk";

type Props = {
  selectedIds: string[];
  suppliers: { id: string; name: string }[];
  canEditCosts: boolean;
  canDelete: boolean;
  onDone: () => void;
};

export function BulkActionsBar({ selectedIds, suppliers, canEditCosts, canDelete, onDone }: Props) {
  const [dialog, setDialog] = useState<"supplier" | "install" | "delete" | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [supplierId, setSupplierId] = useState(suppliers[0]?.id ?? "");
  const [installDate, setInstallDate] = useState("");
  const [installSlot, setInstallSlot] = useState("");

  function run(input: Parameters<typeof bulkSignageAction>[0]) {
    start(async () => {
      const res = await bulkSignageAction(input);
      setMessage(res.ok ? (res.message ?? "Done") : res.error);
      setDialog(null);
      if (res.ok) onDone();
    });
  }

  return (
    <div className="bg-muted/60 flex flex-wrap items-center gap-2 rounded-lg border px-3 py-2 text-sm">
      <span className="font-medium">{selectedIds.length} selected</span>
      {canEditCosts && (
        <Button size="sm" variant="outline" onClick={() => setDialog("supplier")}>
          Set supplier
        </Button>
      )}
      <Button size="sm" variant="outline" onClick={() => setDialog("install")}>
        Set install date
      </Button>
      <Button
        size="sm"
        variant="outline"
        disabled={pending}
        onClick={() => run({ ids: selectedIds, action: "submit" })}
      >
        Submit for review
      </Button>
      {canDelete && (
        <Button size="sm" variant="destructive" onClick={() => setDialog("delete")}>
          Delete
        </Button>
      )}
      {message && <span className="text-muted-foreground">{message}</span>}

      <Dialog open={dialog === "supplier"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Set supplier</DialogTitle>
            <DialogDescription>Applies to {selectedIds.length} selected item(s).</DialogDescription>
          </DialogHeader>
          <select
            className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
            value={supplierId}
            onChange={(e) => setSupplierId(e.target.value)}
          >
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
          <DialogFooter>
            <Button
              disabled={pending || !supplierId}
              onClick={() => run({ ids: selectedIds, action: "set_supplier", supplierId })}
            >
              Apply
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialog === "install"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Set install date and slot</DialogTitle>
            <DialogDescription>Applies to {selectedIds.length} selected item(s).</DialogDescription>
          </DialogHeader>
          <div className="flex gap-2">
            <Input
              type="date"
              value={installDate}
              onChange={(e) => setInstallDate(e.target.value)}
            />
            <select
              className="border-input h-9 rounded-md border bg-transparent px-3 text-sm"
              value={installSlot}
              onChange={(e) => setInstallSlot(e.target.value)}
            >
              <option value="">No slot</option>
              <option value="am">AM</option>
              <option value="pm">PM</option>
              <option value="overnight">Overnight</option>
            </select>
          </div>
          <DialogFooter>
            <Button
              disabled={pending || !installDate}
              onClick={() =>
                run({
                  ids: selectedIds,
                  action: "set_install",
                  installDate,
                  installSlot: (installSlot || null) as "am" | "pm" | "overnight" | null,
                })
              }
            >
              Apply
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialog === "delete"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete {selectedIds.length} item(s)?</DialogTitle>
            <DialogDescription>
              Deleted items disappear from the schedule and every export. They can be restored from
              Settings → Deleted items.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={pending}
              onClick={() => run({ ids: selectedIds, action: "delete" })}
            >
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
