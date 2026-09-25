"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, CalendarClock, Gift, Truck } from "lucide-react";
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
import { StatusBadge } from "@/components/status-badge";
import { markSold, markUnsold } from "@/app/actions/sponsorship";
import { formatMoney } from "@/lib/format";
import type { CountdownTone } from "@/lib/countdown";

export type SponsorshipCard = {
  id: string;
  ref: string;
  name: string;
  href: string;
  kind: "signage" | "sponsorship_item";
  typeName: string | null;
  quantity: number;
  status: string;
  supplierName: string | null;
  sponsorName: string | null;
  sold: boolean;
  costEstimate: string | null;
  salePrice: string | null;
  imageUrl: string | null;
  orderByLabel: string | null;
  countdown: { label: string; tone: CountdownTone; warning: string | null } | null;
};

type Filter = "all" | "available" | "sold" | "urgent";

const TONE: Record<CountdownTone, string> = {
  ok: "text-muted-foreground",
  soon: "text-amber-800 dark:text-amber-300",
  urgent: "text-destructive font-medium",
  overdue: "text-destructive font-medium",
};

/** Sponsorship items as cards: photo, prices, supplier and the order-by countdown. */
export function SponsorshipCards({
  cards,
  sponsors,
  canSell,
}: {
  cards: SponsorshipCard[];
  sponsors: { id: string; name: string }[];
  canSell: boolean;
}) {
  const [filter, setFilter] = useState<Filter>("all");
  const [selling, setSelling] = useState<SponsorshipCard | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const urgent = (c: SponsorshipCard) =>
    !c.sold && (c.countdown?.tone === "urgent" || c.countdown?.tone === "overdue");
  const counts: Record<Filter, number> = {
    all: cards.length,
    available: cards.filter((c) => !c.sold).length,
    sold: cards.filter((c) => c.sold).length,
    urgent: cards.filter(urgent).length,
  };
  const shown = cards.filter((c) =>
    filter === "available"
      ? !c.sold
      : filter === "sold"
        ? c.sold
        : filter === "urgent"
          ? urgent(c)
          : true,
  );
  const filters: [Filter, string][] = [
    ["all", "All"],
    ["available", "Available"],
    ["sold", "Sold"],
    ["urgent", "Under a month to sell"],
  ];

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2" role="group" aria-label="Show items">
        {filters.map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setFilter(key)}
            aria-pressed={filter === key}
            className={`rounded-full border px-3 py-1 text-sm ${
              filter === key ? "bg-foreground text-background border-foreground" : "hover:bg-muted"
            } ${key === "urgent" && counts.urgent > 0 && filter !== key ? "border-destructive/50 text-destructive" : ""}`}
          >
            {label} <span className="opacity-70">({counts[key]})</span>
          </button>
        ))}
      </div>

      {shown.length === 0 ? (
        <p className="text-muted-foreground rounded-lg border border-dashed p-8 text-center text-sm">
          Nothing here.
        </p>
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" aria-label="Sponsorship items">
          {shown.map((c) => {
            const profit =
              c.sold && c.salePrice != null && c.costEstimate != null
                ? Number(c.salePrice) - Number(c.costEstimate)
                : null;
            return (
              <li
                key={c.id}
                aria-label={c.name}
                className={`flex flex-col overflow-hidden rounded-lg border ${
                  urgent(c) ? "border-destructive/50" : ""
                }`}
              >
                <Link href={c.href} className="bg-muted relative block aspect-[4/3]" tabIndex={-1}>
                  {c.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={c.imageUrl} alt={c.name} className="size-full object-cover" />
                  ) : (
                    <span className="text-muted-foreground flex size-full flex-col items-center justify-center gap-1 text-xs">
                      <Gift className="size-8 opacity-40" aria-hidden />
                      No photo yet
                    </span>
                  )}
                  <span
                    className={`absolute top-2 left-2 rounded-full px-2 py-0.5 text-xs font-semibold ${
                      c.sold
                        ? "bg-emerald-600 text-white"
                        : "bg-background/90 text-foreground border"
                    }`}
                  >
                    {c.sold ? "Sold" : "Available"}
                  </span>
                </Link>
                <div className="flex flex-1 flex-col gap-2 p-3 text-sm">
                  <div>
                    <Link href={c.href} className="font-medium hover:underline">
                      {c.name}
                    </Link>
                    <p className="text-muted-foreground text-xs">
                      {c.ref} · {c.kind === "signage" ? "Sponsor signage" : (c.typeName ?? "Item")}
                      {c.quantity > 1 ? ` · Qty ${c.quantity.toLocaleString("en-GB")}` : ""}
                    </p>
                  </div>

                  {c.countdown && (
                    <div className={`flex items-center gap-1.5 text-xs ${TONE[c.countdown.tone]}`}>
                      <CalendarClock className="size-3.5 shrink-0" aria-hidden />
                      <span>
                        Order by {c.orderByLabel} — {c.countdown.label}
                      </span>
                    </div>
                  )}
                  {c.countdown?.warning && (
                    <p className="bg-destructive/10 text-destructive flex items-center gap-1.5 rounded px-2 py-1 text-xs font-semibold">
                      <AlertTriangle className="size-3.5 shrink-0" aria-hidden />
                      {c.countdown.warning}
                    </p>
                  )}

                  <dl className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
                    <dt className="text-muted-foreground">Cost price</dt>
                    <dd className="text-right font-medium">{formatMoney(c.costEstimate)}</dd>
                    {c.sold && (
                      <>
                        <dt className="text-muted-foreground">Sale price</dt>
                        <dd className="text-right font-medium">{formatMoney(c.salePrice)}</dd>
                        {profit != null && (
                          <>
                            <dt className="text-muted-foreground">Profit</dt>
                            <dd
                              className={`text-right font-medium ${profit < 0 ? "text-destructive" : "text-emerald-700 dark:text-emerald-400"}`}
                            >
                              {formatMoney(profit)}
                            </dd>
                          </>
                        )}
                      </>
                    )}
                  </dl>

                  <p className="text-muted-foreground flex items-center gap-1.5 text-xs">
                    <Truck className="size-3.5 shrink-0" aria-hidden />
                    {c.supplierName ?? "No supplier yet"}
                  </p>
                  {c.sold && (
                    <p className="text-xs">
                      <span className="text-muted-foreground">Sponsor: </span>
                      <span className="font-medium">{c.sponsorName}</span>
                    </p>
                  )}

                  <div className="mt-auto flex flex-wrap items-center gap-2 pt-1">
                    <StatusBadge status={c.status} />
                    {canSell && !c.sold && (
                      <Button
                        size="sm"
                        className="ml-auto"
                        onClick={() => {
                          setError(null);
                          setSelling(c);
                        }}
                      >
                        Mark as sold
                      </Button>
                    )}
                    {canSell && c.sold && c.kind === "sponsorship_item" && (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="ml-auto"
                        disabled={pending}
                        onClick={() => {
                          if (!confirm(`Undo the sale of ${c.name}? It goes back to available.`)) {
                            return;
                          }
                          start(async () => {
                            const res = await markUnsold({ itemId: c.id });
                            if (!res.ok) alert(res.error);
                            router.refresh();
                          });
                        }}
                      >
                        Undo sale
                      </Button>
                    )}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      )}

      <SellDialog
        key={selling?.id ?? "none"}
        card={selling}
        sponsors={sponsors}
        pending={pending}
        error={error}
        onClose={() => setSelling(null)}
        onSubmit={(input) => {
          setError(null);
          start(async () => {
            const res = await markSold(input);
            if (!res.ok) setError(res.error);
            else {
              setSelling(null);
              router.refresh();
            }
          });
        }}
      />
    </div>
  );
}

function SellDialog({
  card,
  sponsors,
  pending,
  error,
  onClose,
  onSubmit,
}: {
  card: SponsorshipCard | null;
  sponsors: { id: string; name: string }[];
  pending: boolean;
  error: string | null;
  onClose: () => void;
  onSubmit: (input: {
    itemId: string;
    sponsorId: string | null;
    newSponsorName: string | null;
    salePrice: string;
  }) => void;
}) {
  const [sponsorId, setSponsorId] = useState("");
  return (
    <Dialog open={card !== null} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Mark as sold</DialogTitle>
          <DialogDescription>{card?.name} — who bought it and for how much.</DialogDescription>
        </DialogHeader>
        <form
          key={card?.id}
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (!card) return;
            const f = new FormData(e.currentTarget);
            onSubmit({
              itemId: card.id,
              sponsorId: sponsorId && sponsorId !== "new" ? sponsorId : null,
              newSponsorName: sponsorId === "new" ? String(f.get("newSponsorName") ?? "") : null,
              salePrice: String(f.get("salePrice") ?? ""),
            });
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor="sell-sponsor">Sponsor</Label>
            <SelectNative
              id="sell-sponsor"
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
              <Label htmlFor="sell-new">New sponsor&apos;s company name</Label>
              <Input id="sell-new" name="newSponsorName" required autoFocus />
            </div>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="sell-price">Sale price (£)</Label>
            <Input id="sell-price" name="salePrice" type="number" min="0" step="0.01" required />
            {card?.costEstimate && (
              <p className="text-muted-foreground text-xs">
                Cost price {formatMoney(card.costEstimate)}
              </p>
            )}
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={pending}>
              Save sale
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
