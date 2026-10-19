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
import { sellPackage } from "@/app/actions/sponsorship-packages";
import {
  planEntitlements,
  priceDiffers,
  saleMode,
  sellRefusal,
  type PlanEntitlement,
  type SellPackage,
} from "@/lib/domain/sponsorship-packages";
import { currencySymbol, formatMoney } from "@/lib/format";
import { cn } from "@/lib/utils";

export type { SellPackage };

/** A sponsor as the sell dialog offers it, with the package they have. */
export type SellSponsor = {
  id: string;
  name: string;
  packageId: string | null;
  packageName: string | null;
  agreedPrice: string | null;
  priceNote: string | null;
};

const lineWords = (l: { description: string; quantity: number }) =>
  `${l.quantity > 1 ? `${l.quantity} × ` : ""}${l.description}`;

/**
 * "Sell": who bought a package and at what agreed price, from a package
 * card (the package is fixed) or a sponsor's card (the sponsor is fixed).
 * Picking a sponsor who has it already changes their price; one who has
 * another package changes it. The preview of their entitlements uses the
 * same planEntitlements as the server; the server's toast counts are the
 * ones that stand.
 */
export function SellPackageButton({
  fixed,
  initialPackageId,
  packages,
  sponsors,
  entitlements,
  currency,
  label = "Sell",
  variant = "default",
  size = "sm",
  disabled,
  disabledReason,
  className,
}: {
  fixed: { packageId: string } | { sponsorId: string };
  /** With a fixed sponsor: the package to start on ("" = choose one). */
  initialPackageId?: string;
  packages: SellPackage[];
  sponsors: SellSponsor[];
  /** Each sponsor's entitlements, for the preview. */
  entitlements: Record<string, PlanEntitlement[]>;
  currency: string;
  label?: string;
  variant?: "default" | "outline" | "ghost";
  size?: "sm" | "default";
  disabled?: boolean;
  disabledReason?: string;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const [sponsorId, setSponsorId] = useState("");
  const [newName, setNewName] = useState("");
  const [packageId, setPackageId] = useState("");
  const [price, setPrice] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const sym = currencySymbol(currency);

  const fixedPackage = "packageId" in fixed ? fixed.packageId : null;
  const fixedSponsor = "sponsorId" in fixed ? fixed.sponsorId : null;
  const chosenSponsorId = fixedSponsor ?? (sponsorId === "new" ? "" : sponsorId);
  const sponsor = sponsors.find((s) => s.id === chosenSponsorId) ?? null;
  const pkg = packages.find((p) => p.id === (fixedPackage ?? packageId)) ?? null;
  const isNew = !fixedSponsor && sponsorId === "new";
  const mode = pkg && (sponsor || isNew) ? saleMode(sponsor?.packageId ?? null, pkg.id) : null;

  /** The price to start from: what they agreed (editing), else the list price. */
  function startPrice(p: SellPackage | null, sp: SellSponsor | null) {
    if (!p) return { price: "", note: "" };
    if (sp && sp.packageId === p.id && sp.agreedPrice != null) {
      return { price: String(Number(sp.agreedPrice)), note: sp.priceNote ?? "" };
    }
    return { price: p.price != null ? String(Number(p.price)) : "", note: "" };
  }

  function openDialog() {
    const sp = fixedSponsor ? (sponsors.find((s) => s.id === fixedSponsor) ?? null) : null;
    const startPkg = fixedPackage ?? initialPackageId ?? "";
    const p = packages.find((x) => x.id === startPkg) ?? null;
    const s0 = startPrice(p, sp);
    setSponsorId("");
    setNewName("");
    setPackageId(fixedPackage ? "" : startPkg);
    setPrice(s0.price);
    setNote(s0.note);
    setError(null);
    setOpen(true);
  }

  function chooseSponsor(id: string) {
    setSponsorId(id);
    const s0 = startPrice(pkg, sponsors.find((s) => s.id === id) ?? null);
    setPrice(s0.price);
    setNote(s0.note);
  }

  function choosePackage(id: string) {
    setPackageId(id);
    const s0 = startPrice(packages.find((p) => p.id === id) ?? null, sponsor);
    setPrice(s0.price);
    setNote(s0.note);
  }

  const agreed = price.trim() === "" ? null : Number(price);
  const differs =
    pkg && agreed !== null && !Number.isNaN(agreed) && priceDiffers(pkg.price, agreed);
  const plan =
    pkg && mode && mode !== "edit"
      ? planEntitlements(entitlements[sponsor?.id ?? ""] ?? [], {
          fromPackageId: sponsor?.packageId ?? null,
          toPackageId: pkg.id,
          toLines: pkg.lines,
        })
      : null;
  const whoName = sponsor?.name ?? (newName.trim() || "the sponsor");

  const title = fixedPackage
    ? `Sell ${pkg?.name ?? "package"}`
    : sponsor && pkg && sponsor.packageId === pkg.id
      ? `${sponsor.name}'s ${pkg.name}`
      : `Sell a package to ${sponsor?.name ?? "this sponsor"}`;

  function placesText(p: SellPackage) {
    if (p.places == null) return "no limit";
    const left = Math.max(0, p.places - p.sold);
    return left === 0 ? "sold out" : `${left} left`;
  }

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    if (!pkg) return setError("Choose the package they bought");
    if (!sponsor && !isNew) return setError("Choose the sponsor who bought it");
    if (isNew && !newName.trim()) return setError("Enter the new sponsor's company name");
    if (agreed === null || Number.isNaN(agreed) || agreed < 0) {
      return setError("Enter the agreed price");
    }
    const refusal = sellRefusal({
      packageName: pkg.name,
      archived: pkg.isArchived,
      places: pkg.places,
      soldToOthers: pkg.sold - (sponsor?.packageId === pkg.id ? 1 : 0),
      mode: mode ?? "new",
      listPrice: pkg.price,
      agreedPrice: agreed,
      priceNote: note,
    });
    if (refusal) return setError(refusal);
    start(async () => {
      const res = await sellPackage({
        packageId: pkg.id,
        sponsorId: isNew ? null : sponsor?.id,
        newSponsorName: isNew ? newName : null,
        agreedPrice: price,
        priceNote: differs ? note : null,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setOpen(false);
      const d = res.data;
      const parts =
        d && d.mode !== "edit"
          ? [
              d.added > 0 ? `Added ${d.added} to their entitlements` : "Nothing new to add",
              d.alreadyThere > 0
                ? `${d.alreadyThere} ${d.alreadyThere === 1 ? "was" : "were"} already there`
                : null,
              d.removed > 0 ? `${d.removed} from the old package removed` : null,
              d.kept > 0 ? `${d.kept} kept (items count towards them)` : null,
            ].filter(Boolean)
          : [];
      toast.success(res.message ?? "Sale saved", {
        description: parts.length > 0 ? parts.join(" · ") : undefined,
      });
      router.refresh();
    });
  }

  const submitLabel = mode === "edit" ? "Save" : mode === "change" ? "Change package" : "Save sale";

  return (
    <>
      {disabled ? (
        <span title={disabledReason} className={cn("inline-flex", className)}>
          <Button
            type="button"
            size={size}
            variant={variant}
            disabled
            className="min-h-11 sm:min-h-9"
          >
            {label}
          </Button>
        </span>
      ) : (
        <Button
          type="button"
          size={size}
          variant={variant}
          className={cn("min-h-11 sm:min-h-9", className)}
          onClick={openDialog}
        >
          {label}
        </Button>
      )}
      <Dialog open={open} onOpenChange={(o) => !o && setOpen(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="break-words">{title}</DialogTitle>
            <DialogDescription>
              Who bought it and the price agreed. What&apos;s included is added to their
              entitlements.
            </DialogDescription>
          </DialogHeader>
          <form key={String(open)} className="grid min-w-0 gap-3" onSubmit={onSubmit} noValidate>
            {!fixedSponsor && (
              <div className="space-y-1.5">
                <Label htmlFor="sp-sell-sponsor">Sponsor</Label>
                <SelectNative
                  id="sp-sell-sponsor"
                  value={sponsorId}
                  onChange={(e) => chooseSponsor(e.target.value)}
                  required
                >
                  <option value="">— Choose sponsor —</option>
                  {sponsors.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                      {s.packageId && pkg && s.packageId === pkg.id
                        ? " — already has it"
                        : s.packageName
                          ? ` — has ${s.packageName}`
                          : ""}
                    </option>
                  ))}
                  <option value="new">+ New sponsor…</option>
                </SelectNative>
              </div>
            )}
            {isNew && (
              <div className="space-y-1.5">
                <Label htmlFor="sp-sell-new">New sponsor&apos;s company name</Label>
                <Input
                  id="sp-sell-new"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  maxLength={200}
                  required
                  autoFocus
                />
              </div>
            )}
            {!fixedPackage && (
              <div className="space-y-1.5">
                <Label htmlFor="sp-sell-package">Package</Label>
                <SelectNative
                  id="sp-sell-package"
                  value={packageId}
                  onChange={(e) => choosePackage(e.target.value)}
                  required
                >
                  <option value="">— Choose package —</option>
                  {packages
                    .filter((p) => !p.isArchived || p.id === sponsor?.packageId)
                    .map((p) => {
                      const theirs = p.id === sponsor?.packageId;
                      const soldOut = !theirs && p.places != null && p.sold >= p.places;
                      return (
                        <option key={p.id} value={p.id} disabled={soldOut}>
                          {[
                            p.name,
                            p.price != null ? formatMoney(p.price, currency) : "no price yet",
                            theirs ? "theirs now" : placesText(p),
                          ].join(" · ")}
                        </option>
                      );
                    })}
                </SelectNative>
              </div>
            )}
            <div className="space-y-1.5">
              <Label htmlFor="sp-sell-price">Agreed price ({sym})</Label>
              <Input
                id="sp-sell-price"
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                required
              />
              {pkg && pkg.price == null && (
                <p className="text-muted-foreground text-xs">
                  This package has no price yet — enter what they agreed to pay.
                </p>
              )}
            </div>
            {differs && pkg?.price != null && agreed !== null && (
              <div className="space-y-1.5">
                <Label htmlFor="sp-sell-note">Why is it different?</Label>
                <Input
                  id="sp-sell-note"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="e.g. 10% early-booking discount"
                  maxLength={200}
                  required
                />
                <p className="text-muted-foreground text-xs">
                  List price {formatMoney(pkg.price, currency)} —{" "}
                  {formatMoney(Math.abs(Number(pkg.price) - agreed), currency)}{" "}
                  {agreed < Number(pkg.price) ? "less" : "more"}
                </p>
              </div>
            )}
            {plan && (
              <div className="space-y-2 rounded-md border p-2.5 text-xs" aria-label="What changes">
                <PreviewList
                  title={`Added to ${whoName}'s entitlements`}
                  lines={plan.add.map(lineWords)}
                  empty="Nothing new to add"
                />
                {plan.alreadyThere.length > 0 && (
                  <PreviewList
                    title="Already on their list (left as it is)"
                    lines={plan.alreadyThere.map((a) => lineWords(a.existing))}
                  />
                )}
                {plan.remove.length > 0 && (
                  <PreviewList
                    title={`From ${sponsor?.packageName ?? "their old package"}: removed`}
                    lines={plan.remove.map(lineWords)}
                  />
                )}
                {plan.keep.length > 0 && (
                  <PreviewList
                    title="Kept (items count towards them)"
                    lines={plan.keep.map(lineWords)}
                  />
                )}
              </div>
            )}
            {mode === "edit" && pkg && (
              <p className="text-muted-foreground text-xs">
                They already have {pkg.name}: only the agreed price and its reason change.
              </p>
            )}
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
                {pending ? "Saving…" : submitLabel}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}

function PreviewList({ title, lines, empty }: { title: string; lines: string[]; empty?: string }) {
  return (
    <div className="min-w-0">
      <p className="font-medium">{title}</p>
      {lines.length === 0 ? (
        <p className="text-muted-foreground">{empty}</p>
      ) : (
        <ul className="text-muted-foreground mt-0.5 list-disc space-y-0.5 pl-4 break-words">
          {lines.map((l, i) => (
            <li key={`${l}-${i}`}>{l}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
