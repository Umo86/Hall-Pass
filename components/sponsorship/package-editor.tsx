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
import { Textarea } from "@/components/ui/textarea";
import { savePackage } from "@/app/actions/sponsorship-packages";
import { formatIncludedLines, type PackageCard } from "@/lib/domain/sponsorship-packages";
import { currencySymbol } from "@/lib/format";

/**
 * Add or edit a package: its name, price, how many can be sold, a short
 * description and what's included. Sponsors who already bought it keep
 * what they were sold; a price set on a package sold before it had one can
 * fill in their agreed price too (ticked).
 */
export function PackageEditorDialog({
  editionId,
  current,
  currency,
  open,
  onClose,
}: {
  editionId: string;
  current: PackageCard | null;
  currency: string;
  open: boolean;
  onClose: () => void;
}) {
  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="break-words">
            {current ? `Edit ${current.name}` : "Add package"}
          </DialogTitle>
          <DialogDescription>
            What sponsors can buy as a package: its price, what&apos;s included and how many you can
            sell.
          </DialogDescription>
        </DialogHeader>
        {/* A fresh form per package, so nothing carries over. */}
        <EditorForm
          key={`${current?.id ?? "new"}-${String(open)}`}
          editionId={editionId}
          current={current}
          currency={currency}
          onClose={onClose}
        />
      </DialogContent>
    </Dialog>
  );
}

function EditorForm({
  editionId,
  current,
  currency,
  onClose,
}: {
  editionId: string;
  current: PackageCard | null;
  currency: string;
  onClose: () => void;
}) {
  const [price, setPrice] = useState(current?.price != null ? String(Number(current.price)) : "");
  const [applyPrice, setApplyPrice] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const sym = currencySymbol(currency);
  const sold = current?.sales.length ?? 0;
  // Sold before the package had a price: offered the new price too.
  const unpriced =
    current?.price == null ? (current?.sales ?? []).filter((s) => s.agreedPrice == null) : [];
  const offerApply = unpriced.length > 0 && price.trim() !== "";

  return (
    <form
      className="grid min-w-0 gap-3"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        setError(null);
        start(async () => {
          const res = await savePackage({
            editionId,
            id: current?.id,
            name: fd.get("name"),
            price,
            places: fd.get("places"),
            description: fd.get("description"),
            lines: fd.get("lines"),
            applyPriceToUnpriced: offerApply && applyPrice,
          });
          if (!res.ok) {
            setError(res.error);
            return;
          }
          toast.success(res.message ?? "Package saved");
          onClose();
          router.refresh();
        });
      }}
    >
      <div className="space-y-1.5">
        <Label htmlFor="pkg-name">Name</Label>
        <Input
          id="pkg-name"
          name="name"
          defaultValue={current?.name ?? ""}
          maxLength={120}
          required
          autoFocus={!current}
        />
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="min-w-0 space-y-1.5">
          <Label htmlFor="pkg-price">Price ({sym}, optional)</Label>
          <Input
            id="pkg-price"
            name="price"
            type="number"
            inputMode="decimal"
            min="0"
            step="0.01"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
          />
          <p className="text-muted-foreground text-xs">Leave empty if it isn&apos;t priced yet.</p>
        </div>
        <div className="min-w-0 space-y-1.5">
          <Label htmlFor="pkg-places">How many to sell (optional)</Label>
          <Input
            id="pkg-places"
            name="places"
            type="number"
            inputMode="numeric"
            min="1"
            step="1"
            defaultValue={current?.places ?? ""}
          />
          <p className="text-muted-foreground text-xs">Leave empty for no limit.</p>
        </div>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="pkg-description">Short description (optional)</Label>
        <Input
          id="pkg-description"
          name="description"
          defaultValue={current?.description ?? ""}
          maxLength={300}
        />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="pkg-lines">What&apos;s included (one per line)</Label>
        <Textarea
          id="pkg-lines"
          name="lines"
          rows={4}
          defaultValue={current ? formatIncludedLines(current.lines) : ""}
          placeholder={"6 x Logo on hanging banners\nEntrance feature branding"}
        />
        {sold > 0 && (
          <p className="text-muted-foreground text-xs">
            Changes apply to the next sale.{" "}
            {sold === 1
              ? "The sponsor who already has it keeps"
              : `The ${sold} sponsors who already have it keep`}{" "}
            what they were sold.
          </p>
        )}
      </div>
      {offerApply && (
        <label className="flex min-h-11 items-start gap-2.5 text-sm sm:min-h-0">
          <input
            type="checkbox"
            className="mt-0.5 size-4 shrink-0"
            checked={applyPrice}
            onChange={(e) => setApplyPrice(e.target.checked)}
          />
          <span className="min-w-0 break-words">
            {unpriced.length === 1
              ? `Use this price for ${unpriced[0].companyName} too (sold before the package had a price)`
              : `Use this price for the ${unpriced.length} sponsors sold it before it had a price`}
          </span>
        </label>
      )}
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      <DialogFooter>
        <Button type="button" variant="outline" onClick={onClose}>
          Cancel
        </Button>
        <Button type="submit" disabled={pending}>
          {pending ? "Saving…" : "Save"}
        </Button>
      </DialogFooter>
    </form>
  );
}
