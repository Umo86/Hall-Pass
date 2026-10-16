"use client";

import { useState, useTransition } from "react";
import { MoreHorizontal, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { useConfirm } from "@/components/confirm-dialog";
import { bulkSignageAction, type BulkOutcome } from "@/app/actions/signage-bulk";

/** What a bulk action did, kept on screen until dismissed. */
export type BulkResult = {
  ok: boolean;
  message: string;
  failures: BulkOutcome["failures"];
};

type Props = {
  selectedIds: string[];
  suppliers: { id: string; name: string }[];
  canEditCosts: boolean;
  canDelete: boolean;
  canClose: boolean;
  /** The result, whatever happened; the list keeps the failed rows selected. */
  onResult: (result: BulkResult) => void;
  onClear: () => void;
};

/** Today as YYYY-MM-DD in the browser's own time zone. */
function localToday(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

const plural = (n: number) => `${n} item${n === 1 ? "" : "s"}`;

/**
 * Actions on the selected rows: send for sign-off, confirm sent to print or
 * delivered (with the day it happened), and under More the supplier, the
 * install date, mark complete and delete.
 */
export function BulkActionsBar({
  selectedIds,
  suppliers,
  canEditCosts,
  canDelete,
  canClose,
  onResult,
  onClear,
}: Props) {
  const [dialog, setDialog] = useState<
    "supplier" | "install" | "confirm_print" | "confirm_delivered" | null
  >(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const [supplierId, setSupplierId] = useState(suppliers[0]?.id ?? "");
  const [installDate, setInstallDate] = useState("");
  const [installSlot, setInstallSlot] = useState("");
  const [confirmedDate, setConfirmedDate] = useState(localToday);
  const n = selectedIds.length;

  function run(input: Parameters<typeof bulkSignageAction>[0]) {
    start(async () => {
      const res = await bulkSignageAction(input);
      setDialog(null);
      onResult(
        res.ok
          ? {
              ok: (res.data?.failed ?? 0) === 0,
              message: res.message ?? "Done",
              failures: res.data?.failures ?? [],
            }
          : { ok: false, message: res.error, failures: [] },
      );
    });
  }

  function openConfirm(kind: "confirm_print" | "confirm_delivered") {
    setConfirmedDate(localToday());
    setDialog(kind);
  }

  async function closeAll() {
    const ok = await confirm({
      title: `Mark ${plural(n)} complete?`,
      description:
        "Only installed items with no open snags are marked complete; anything else is left as it is and listed.",
      confirmLabel: "Mark complete",
    });
    if (ok) run({ ids: selectedIds, action: "close" });
  }

  async function deleteAll() {
    const ok = await confirm({
      title: `Delete ${plural(n)}?`,
      description:
        "They disappear from the list and every export. You can restore them from Recently deleted on the Signage page; refs are never reused.",
      confirmLabel: "Delete",
      destructive: true,
    });
    if (ok) run({ ids: selectedIds, action: "delete" });
  }

  const confirmStep = dialog === "confirm_print" ? "sent to print" : "delivered";

  return (
    <div
      role="region"
      aria-label="Selected items"
      className="bg-muted/60 flex flex-wrap items-center gap-2 rounded-lg border px-3 py-2 text-sm"
    >
      <span className="font-medium">{n} selected</span>
      <Button size="sm" variant="ghost" onClick={onClear} aria-label="Clear the selection">
        <X aria-hidden />
      </Button>
      <span className="bg-border mx-1 hidden h-5 w-px sm:block" aria-hidden />
      <Button
        size="sm"
        variant="outline"
        disabled={pending}
        onClick={() => run({ ids: selectedIds, action: "submit" })}
      >
        Send for sign-off
      </Button>
      <Button
        size="sm"
        variant="outline"
        disabled={pending}
        onClick={() => openConfirm("confirm_print")}
      >
        Confirm sent to print
      </Button>
      <Button
        size="sm"
        variant="outline"
        disabled={pending}
        onClick={() => openConfirm("confirm_delivered")}
      >
        Confirm delivered
      </Button>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button size="sm" variant="outline" disabled={pending}>
            <MoreHorizontal aria-hidden /> More
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-48">
          {canEditCosts && (
            <DropdownMenuItem onSelect={() => setDialog("supplier")}>Set supplier</DropdownMenuItem>
          )}
          <DropdownMenuItem onSelect={() => setDialog("install")}>
            Set install date
          </DropdownMenuItem>
          {canClose && (
            <DropdownMenuItem onSelect={() => void closeAll()}>Mark complete</DropdownMenuItem>
          )}
          {canDelete && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onSelect={() => void deleteAll()}
              >
                Delete
              </DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      {pending && <span className="text-muted-foreground">Working…</span>}
      {confirmDialog}

      <Dialog open={dialog === "supplier"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Set the supplier</DialogTitle>
            <DialogDescription>For the {plural(n)} selected.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="bulk-supplier">Supplier</Label>
            <SelectNative
              id="bulk-supplier"
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
            >
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </SelectNative>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || !supplierId}
              onClick={() => run({ ids: selectedIds, action: "set_supplier", supplierId })}
            >
              Set supplier
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialog === "install"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Set the install date and slot</DialogTitle>
            <DialogDescription>For the {plural(n)} selected.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="grid gap-1.5">
              <Label htmlFor="bulk-install-date">Install date</Label>
              <Input
                id="bulk-install-date"
                type="date"
                value={installDate}
                onChange={(e) => setInstallDate(e.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="bulk-install-slot">Slot</Label>
              <SelectNative
                id="bulk-install-slot"
                value={installSlot}
                onChange={(e) => setInstallSlot(e.target.value)}
              >
                <option value="">No slot</option>
                <option value="am">AM</option>
                <option value="pm">PM</option>
                <option value="overnight">Overnight</option>
              </SelectNative>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
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
              Set install date
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={dialog === "confirm_print" || dialog === "confirm_delivered"}
        onOpenChange={(o) => !o && setDialog(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm {confirmStep}</DialogTitle>
            <DialogDescription>
              For the {plural(n)} selected that are waiting for it.{" "}
              {dialog === "confirm_print"
                ? "Items not signed off yet, or with no supplier, are left as they are and listed."
                : "Items not sent to print yet are left as they are and listed."}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="bulk-confirmed-date">When did this happen?</Label>
            <Input
              id="bulk-confirmed-date"
              type="date"
              value={confirmedDate}
              max={localToday()}
              onChange={(e) => setConfirmedDate(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending || !confirmedDate}
              onClick={() =>
                dialog &&
                (dialog === "confirm_print" || dialog === "confirm_delivered") &&
                run({ ids: selectedIds, action: dialog, confirmedDate })
              }
            >
              Confirm {confirmStep}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
