"use client";

import Link from "next/link";
import { useMemo } from "react";
import { parseAsString, useQueryState } from "nuqs";
import {
  AlertTriangle,
  CalendarClock,
  Gift,
  LayoutGrid,
  List,
  Search,
  Truck,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import { EmptyState } from "@/components/empty-state";
import { SellButton, UndoSaleButton } from "@/components/sponsorship/sell-dialog";
import { formatMoney } from "@/lib/format";
import type { CountdownTone } from "@/lib/countdown";
import {
  SALE_LABELS,
  SPONSORSHIP_FILTER_LABELS,
  SPONSORSHIP_FILTERS,
  groupSponsorshipRows,
  matchesSponsorshipFilter,
  matchesSponsorshipSearch,
  parseGroupBy,
  parseSponsorshipFilter,
  type NextLineTone,
  type SaleState,
  type SponsorshipFilter,
  type SponsorshipStage,
} from "@/lib/domain/sponsorship";
import { cn } from "@/lib/utils";

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
  sponsorId: string | null;
  sponsorName: string | null;
  sale: SaleState;
  stage: SponsorshipStage;
  /** "Next: sell by 5 Oct", "Waiting on Marketing". */
  next: { text: string; tone: NextLineTone };
  costEstimate: string | null;
  salePrice: string | null;
  imageUrl: string | null;
  orderByDate: string | null;
  orderByLabel: string | null;
  countdown: { label: string; tone: CountdownTone; warning: string | null } | null;
};

type Sponsors = { id: string; name: string }[];

const TONE: Record<CountdownTone, string> = {
  ok: "text-muted-foreground",
  soon: "text-amber-800 dark:text-amber-300",
  urgent: "text-destructive font-medium",
  overdue: "text-destructive font-medium",
};

const NEXT_TONE: Record<NextLineTone, string> = {
  action: "text-foreground font-medium",
  waiting: "text-muted-foreground",
  warning: "text-destructive font-medium",
  done: "text-emerald-700 dark:text-emerald-400",
};

const SALE_CHIP: Record<SaleState, string> = {
  available: "bg-background text-foreground border",
  sold: "bg-emerald-600 text-white",
  in_package: "bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200",
};

function SaleChip({ sale, className }: { sale: SaleState; className?: string }) {
  return (
    <span
      className={cn(
        "rounded-full px-2 py-0.5 text-xs font-semibold whitespace-nowrap",
        SALE_CHIP[sale],
        className,
      )}
    >
      {SALE_LABELS[sale]}
    </span>
  );
}

function chipClass(active: boolean, alert = false) {
  return cn(
    "inline-flex min-h-9 items-center gap-1 rounded-full border px-3 text-sm whitespace-nowrap",
    active ? "bg-foreground text-background border-foreground" : "hover:bg-muted",
    alert && !active && "border-destructive/50 text-destructive",
  );
}

/**
 * The sponsorship items: search, filter chips (in the URL as `?filter=`),
 * Cards or List (`?view=`; List on phones unless chosen), grouping by
 * stage, type or sponsor (`?group=`) and one sponsor (`?sponsor=`).
 */
export function SponsorshipCards({
  cards,
  sponsors,
  canSell,
  today,
}: {
  cards: SponsorshipCard[];
  sponsors: Sponsors;
  canSell: boolean;
  /** Today in London (YYYY-MM-DD), for the order-by filters. */
  today: string;
}) {
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [rawFilter, setFilter] = useQueryState("filter", parseAsString.withDefault(""));
  const [view, setView] = useQueryState("view", parseAsString.withDefault(""));
  const [rawGroup, setGroup] = useQueryState("group", parseAsString.withDefault(""));
  const [sponsorFilter, setSponsorFilter] = useQueryState("sponsor", parseAsString.withDefault(""));
  const filter = parseSponsorshipFilter(rawFilter);
  const group = parseGroupBy(rawGroup);
  const sponsorName =
    sponsorFilter && (sponsors.find((s) => s.id === sponsorFilter)?.name ?? "Unknown sponsor");

  // Chips count within the search and sponsor, so a number matches what a click shows.
  const scoped = useMemo(
    () =>
      cards.filter(
        (c) => (!sponsorFilter || c.sponsorId === sponsorFilter) && matchesSponsorshipSearch(q, c),
      ),
    [cards, q, sponsorFilter],
  );
  const counts = useMemo(() => {
    const out = {} as Record<SponsorshipFilter, number>;
    for (const f of [...SPONSORSHIP_FILTERS, "urgent" as const]) {
      out[f] = scoped.filter((c) => matchesSponsorshipFilter(f, c, today)).length;
    }
    return out;
  }, [scoped, today]);
  const shown = scoped.filter((c) => matchesSponsorshipFilter(filter, c, today));
  const groups = group
    ? groupSponsorshipRows(shown, group)
    : [{ key: "all", label: "", rows: shown }];
  const filtered = filter !== "all" || q.trim() !== "" || sponsorFilter !== "";

  const isActive = (f: SponsorshipFilter) =>
    filter === f || (filter === "urgent" && (f === "overdue" || f === "soon"));
  // "In package" only when there is sponsor signage to show.
  const chips = SPONSORSHIP_FILTERS.filter(
    (f) => f !== "in_package" || cards.some((c) => c.sale === "in_package"),
  );

  const body = (mode: "cards" | "list") =>
    groups.map((g) => (
      <section key={g.key} aria-label={g.label || undefined} className="space-y-2">
        {g.label && (
          <h2 className="text-muted-foreground text-xs font-semibold tracking-wide uppercase">
            {g.label} · {g.rows.length}
          </h2>
        )}
        {mode === "cards" ? (
          <ul
            className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3"
            aria-label="Sponsorship items"
          >
            {g.rows.map((c) => (
              <ItemCard key={c.id} c={c} canSell={canSell} sponsors={sponsors} />
            ))}
          </ul>
        ) : (
          <ul className="divide-y rounded-lg border" aria-label="Sponsorship items">
            {g.rows.map((c) => (
              <ItemRow key={c.id} c={c} canSell={canSell} sponsors={sponsors} />
            ))}
          </ul>
        )}
      </section>
    ));

  return (
    <div className="space-y-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
        <div className="relative sm:w-72">
          <Search
            className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
            aria-hidden
          />
          <Input
            type="search"
            value={q}
            onChange={(e) => void setQ(e.target.value || null)}
            placeholder="Search name, ref, sponsor…"
            aria-label="Search sponsorship items"
            className="h-11 pl-8 sm:h-9"
          />
        </div>
        <div className="flex flex-wrap items-center gap-2 sm:ml-auto">
          <SegmentGroup label="Show as">
            {(["cards", "list"] as const).map((v) => {
              // No choice made yet: Cards from sm up, List on phones.
              const auto = view !== "cards" && view !== "list";
              const active = view === v;
              return (
                <button
                  key={v}
                  type="button"
                  aria-pressed={active}
                  onClick={() => void setView(v)}
                  className={cn(
                    segmentClass(active),
                    "h-11 sm:h-9",
                    auto &&
                      (v === "list"
                        ? "max-sm:bg-primary max-sm:text-primary-foreground"
                        : "sm:bg-primary sm:text-primary-foreground"),
                  )}
                >
                  {v === "cards" ? (
                    <LayoutGrid className="size-4" aria-hidden />
                  ) : (
                    <List className="size-4" aria-hidden />
                  )}
                  {v === "cards" ? "Cards" : "List"}
                </button>
              );
            })}
          </SegmentGroup>
          <SelectNative
            value={group ?? ""}
            onChange={(e) => void setGroup(e.target.value || null)}
            aria-label="Group by"
            className="h-11 w-auto min-w-0 flex-1 sm:h-9 sm:flex-none"
          >
            <option value="">No grouping</option>
            <option value="stage">Group by stage</option>
            <option value="type">Group by type</option>
            <option value="sponsor">Group by sponsor</option>
          </SelectNative>
        </div>
      </div>

      <div
        className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:overflow-visible sm:px-0 sm:pb-0"
        role="group"
        aria-label="Show items"
      >
        {chips.map((key) => (
          <button
            key={key}
            type="button"
            onClick={() => void setFilter(key === "all" ? null : key)}
            aria-pressed={isActive(key)}
            className={chipClass(
              isActive(key),
              (key === "overdue" || key === "soon") && counts[key] > 0,
            )}
          >
            {SPONSORSHIP_FILTER_LABELS[key]} <span className="opacity-70">({counts[key]})</span>
          </button>
        ))}
        {sponsorName && (
          <button
            type="button"
            onClick={() => void setSponsorFilter(null)}
            className={cn(chipClass(true), "gap-1.5")}
            aria-label={`Showing ${sponsorName} only — show every sponsor`}
          >
            Sponsor: {sponsorName}
            <X className="size-3.5" aria-hidden />
          </button>
        )}
      </div>

      {shown.length === 0 ? (
        <EmptyState
          icon={Gift}
          title="Nothing matches"
          description={
            filter !== "all"
              ? `No items under “${SPONSORSHIP_FILTER_LABELS[filter]}”${q ? ` matching “${q}”` : ""}${sponsorName ? ` for ${sponsorName}` : ""}.`
              : `Nothing matches “${q}”${sponsorName ? ` for ${sponsorName}` : ""}.`
          }
          action={
            filtered && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  void setQ(null);
                  void setFilter(null);
                  void setSponsorFilter(null);
                }}
              >
                Show everything
              </Button>
            )
          }
        />
      ) : view === "cards" || view === "list" ? (
        <div className="space-y-4">{body(view)}</div>
      ) : (
        <>
          <div className="hidden space-y-4 sm:block">{body("cards")}</div>
          <div className="space-y-4 sm:hidden">{body("list")}</div>
        </>
      )}
    </div>
  );
}

function Countdown({ c }: { c: SponsorshipCard }) {
  if (!c.countdown) return null;
  return (
    <div className={cn("flex items-center gap-1.5 text-xs", TONE[c.countdown.tone])}>
      <CalendarClock className="size-3.5 shrink-0" aria-hidden />
      <span>
        Order by {c.orderByLabel} — {c.countdown.label}
      </span>
    </div>
  );
}

function Actions({
  c,
  canSell,
  sponsors,
}: {
  c: SponsorshipCard;
  canSell: boolean;
  sponsors: Sponsors;
}) {
  if (!canSell) return null;
  const item = { id: c.id, ref: c.ref, name: c.name, costEstimate: c.costEstimate };
  if (c.sale === "available") return <SellButton item={item} sponsors={sponsors} />;
  if (c.sale === "sold" && c.kind === "sponsorship_item") return <UndoSaleButton item={item} />;
  return null;
}

/** One item as a card: a photo only when there is one, then prices, dates and what's next. */
function ItemCard({
  c,
  canSell,
  sponsors,
}: {
  c: SponsorshipCard;
  canSell: boolean;
  sponsors: Sponsors;
}) {
  const profit =
    c.sale === "sold" && c.salePrice != null && c.costEstimate != null
      ? Number(c.salePrice) - Number(c.costEstimate)
      : null;
  return (
    <li
      aria-label={c.name}
      className={cn(
        "flex flex-col overflow-hidden rounded-lg border",
        c.next.tone === "warning" && "border-destructive/50",
      )}
    >
      {c.imageUrl && (
        <Link href={c.href} className="bg-muted relative block aspect-[4/3]" tabIndex={-1}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={c.imageUrl} alt={c.name} loading="lazy" className="size-full object-cover" />
          <SaleChip sale={c.sale} className="absolute top-2 left-2 shadow-sm" />
        </Link>
      )}
      <div className="flex flex-1 flex-col gap-2 p-3 text-sm">
        <div className="flex items-start gap-3">
          {!c.imageUrl && (
            <span className="bg-muted text-muted-foreground flex size-10 shrink-0 items-center justify-center rounded-md">
              <Gift className="size-5" aria-hidden />
            </span>
          )}
          <div className="min-w-0 flex-1">
            <Link href={c.href} className="font-medium hover:underline">
              {c.name}
            </Link>
            <p className="text-muted-foreground text-xs">
              {c.ref} · {c.kind === "signage" ? "Sponsor signage" : (c.typeName ?? "Item")}
              {c.quantity > 1 ? ` · Qty ${c.quantity.toLocaleString("en-GB")}` : ""}
            </p>
          </div>
          {!c.imageUrl && <SaleChip sale={c.sale} />}
        </div>

        <Countdown c={c} />
        {/* Past the date the countdown already says "overdue". */}
        {c.countdown?.warning && c.countdown.tone !== "overdue" && (
          <p className="bg-destructive/10 text-destructive flex items-center gap-1.5 rounded px-2 py-1 text-xs font-semibold">
            <AlertTriangle className="size-3.5 shrink-0" aria-hidden />
            {c.countdown.warning}
          </p>
        )}

        <dl className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
          <dt className="text-muted-foreground">Cost price</dt>
          <dd className="text-right font-medium">{formatMoney(c.costEstimate)}</dd>
          {c.sale === "sold" && (
            <>
              <dt className="text-muted-foreground">Sale price</dt>
              <dd className="text-right font-medium">{formatMoney(c.salePrice)}</dd>
              {profit != null && (
                <>
                  <dt className="text-muted-foreground">Profit</dt>
                  <dd
                    className={cn(
                      "text-right font-medium",
                      profit < 0 ? "text-destructive" : "text-emerald-700 dark:text-emerald-400",
                    )}
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
        {c.sponsorName && (
          <p className="text-xs">
            <span className="text-muted-foreground">
              {c.sale === "in_package" ? "In the package of " : "Sponsor: "}
            </span>
            <span className="font-medium">{c.sponsorName}</span>
          </p>
        )}

        <div className="mt-auto flex flex-wrap items-center gap-2 border-t pt-2">
          <p className={cn("min-w-0 flex-1 text-xs", NEXT_TONE[c.next.tone])}>{c.next.text}</p>
          <Actions c={c} canSell={canSell} sponsors={sponsors} />
        </div>
      </div>
    </li>
  );
}

/** One item as a row: thumbnail, name and sponsor, what's next, the date, then price or sell. */
function ItemRow({
  c,
  canSell,
  sponsors,
}: {
  c: SponsorshipCard;
  canSell: boolean;
  sponsors: Sponsors;
}) {
  return (
    <li
      aria-label={c.name}
      className="grid grid-cols-[3rem_minmax(0,1fr)] gap-x-3 gap-y-1.5 p-3 text-sm sm:grid-cols-[3rem_minmax(0,2fr)_minmax(0,2fr)_minmax(0,1.5fr)_auto] sm:items-center"
    >
      <Link
        href={c.href}
        tabIndex={-1}
        className="bg-muted text-muted-foreground row-span-2 flex size-12 items-center justify-center overflow-hidden rounded-md sm:row-span-1"
      >
        {c.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={c.imageUrl} alt="" loading="lazy" className="size-full object-cover" />
        ) : (
          <Gift className="size-5" aria-hidden />
        )}
      </Link>
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <Link href={c.href} className="font-medium hover:underline">
            {c.name}
          </Link>
          <SaleChip sale={c.sale} />
        </div>
        <p className="text-muted-foreground truncate text-xs">
          {c.ref}
          {c.sponsorName ? ` · ${c.sponsorName}` : ""}
          {c.kind === "signage" ? " · Sponsor signage" : c.typeName ? ` · ${c.typeName}` : ""}
        </p>
      </div>
      <p className={cn("text-xs", NEXT_TONE[c.next.tone])}>{c.next.text}</p>
      <div className="col-start-2 sm:col-start-auto">
        {c.countdown ? (
          <Countdown c={c} />
        ) : (
          <span className="text-muted-foreground text-xs">No order-by date</span>
        )}
      </div>
      <div className="col-start-2 flex items-center justify-between gap-2 sm:col-start-auto sm:justify-end">
        <span className="text-xs font-medium sm:text-right">
          {c.sale === "sold"
            ? formatMoney(c.salePrice)
            : c.sale === "in_package"
              ? "In package"
              : `Cost ${formatMoney(c.costEstimate)}`}
        </span>
        {c.sale === "available" && <Actions c={c} canSell={canSell} sponsors={sponsors} />}
      </div>
    </li>
  );
}
