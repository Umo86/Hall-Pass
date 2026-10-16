"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
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
import { markSold, markUnsold } from "@/app/actions/sponsorship";
import { formatMoney } from "@/lib/format";
import { cn } from "@/lib/utils";

export type SellItem = {
  id: string;
  ref: string;
  name: string;
  costEstimate: string | null;
};

/** Undo a sale from a toast or a button: back to for sale, with its own toast. */
async function undoSale(item: SellItem, refresh: () => void) {
  const res = await markUnsold({ itemId: item.id });
  if (res.ok) toast.success(res.message ?? `${item.ref} is for sale again`);
  else toast.error(res.error);
  refresh();
}

/**
 * "Mark as sold": who bought it (or a new sponsor) and for how much. Used
 * on the cards, the list and the item page. The toast names the sale and
 * offers Undo.
 */
export function SellButton({
  item,
  sponsors,
  variant = "default",
  size = "sm",
  className,
}: {
  item: SellItem;
  sponsors: { id: string; name: string }[];
  variant?: "default" | "outline";
  size?: "sm" | "default";
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const [sponsorId, setSponsorId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    setError(null);
    start(async () => {
      const res = await markSold({
        itemId: item.id,
        sponsorId: sponsorId && sponsorId !== "new" ? sponsorId : null,
        newSponsorName: sponsorId === "new" ? String(f.get("newSponsorName") ?? "") : null,
        salePrice: String(f.get("salePrice") ?? ""),
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setOpen(false);
      toast.success(res.message ?? `${item.ref} sold`, {
        description: item.name,
        action: { label: "Undo", onClick: () => void undoSale(item, router.refresh) },
      });
      router.refresh();
    });
  }

  return (
    <>
      <Button
        type="button"
        size={size}
        variant={variant}
        className={className}
        onClick={() => {
          // A fresh dialog each time: nothing carries over from a cancelled sale.
          setSponsorId("");
          setError(null);
          setOpen(true);
        }}
      >
        Mark as sold
      </Button>
      <Dialog open={open} onOpenChange={(o) => !o && setOpen(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Mark as sold</DialogTitle>
            <DialogDescription>
              {item.name} ({item.ref}) — who bought it and for how much. Next comes the
              sponsor&apos;s artwork.
            </DialogDescription>
          </DialogHeader>
          <form key={String(open)} className="grid gap-3" onSubmit={onSubmit}>
            <div className="space-y-1.5">
              <Label htmlFor={`sell-sponsor-${item.id}`}>Sponsor</Label>
              <SelectNative
                id={`sell-sponsor-${item.id}`}
                value={sponsorId}
                onChange={(e) => setSponsorId(e.target.value)}
                required
              >
                <option value="">— Choose sponsor —</option>
                {sponsors.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
                <option value="new">+ New sponsor…</option>
              </SelectNative>
            </div>
            {sponsorId === "new" && (
              <div className="space-y-1.5">
                <Label htmlFor={`sell-new-${item.id}`}>New sponsor&apos;s company name</Label>
                <Input id={`sell-new-${item.id}`} name="newSponsorName" required autoFocus />
              </div>
            )}
            <div className="space-y-1.5">
              <Label htmlFor={`sell-price-${item.id}`}>Sale price (£)</Label>
              <Input
                id={`sell-price-${item.id}`}
                name="salePrice"
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                required
              />
              {item.costEstimate && (
                <p className="text-muted-foreground text-xs">
                  Cost price {formatMoney(item.costEstimate)}
                </p>
              )}
            </div>
            {error && (
              <p role="alert" className="text-destructive text-sm">
                {error}
              </p>
            )}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" disabled={pending}>
                {pending ? "Saving…" : "Save sale"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** "Undo sale" behind a confirm that says what happens; the toast confirms it. */
export function UndoSaleButton({ item, className }: { item: SellItem; className?: string }) {
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  return (
    <>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className={cn(className)}
        disabled={pending}
        onClick={async () => {
          const ok = await confirm({
            title: `Undo the sale of ${item.name}?`,
            description:
              "It goes back to for sale: the sponsor and sale price are cleared. Its artwork and sign-off stay as they are.",
            confirmLabel: "Undo sale",
          });
          if (ok) start(() => undoSale(item, router.refresh));
        }}
      >
        Undo sale
      </Button>
      {confirmDialog}
    </>
  );
}
