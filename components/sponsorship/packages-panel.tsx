"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import {
  Archive,
  ArrowDown,
  ArrowUp,
  MoreHorizontal,
  Package as PackageIcon,
  Pencil,
  Plus,
  RotateCcw,
  Trash2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { EmptyState } from "@/components/empty-state";
import { useConfirm } from "@/components/confirm-dialog";
import { deletePackage, movePackage, setPackageArchived } from "@/app/actions/sponsorship-packages";
import {
  availabilityLabel,
  toSellPackage,
  type PackageCard,
  type PlanEntitlement,
} from "@/lib/domain/sponsorship-packages";
import { formatMoney } from "@/lib/format";
import { cn } from "@/lib/utils";
import { PackageEditorDialog } from "./package-editor";
import { SellPackageButton, type SellSponsor } from "./sell-package-dialog";

/**
 * Sponsorship → Packages: one card per package (price, places, what's
 * included, who bought it at what price) with Sell and a ⋯ menu for
 * sellers; archived packages below. Money only reaches the browser for
 * people who see costs (packageCards on the server).
 */
export function PackagesPanel({
  editionId,
  editionCode,
  packages,
  canSell,
  canSeeCosts,
  currency,
  sponsors,
  entitlements,
}: {
  editionId: string;
  editionCode: string;
  packages: PackageCard[];
  canSell: boolean;
  canSeeCosts: boolean;
  currency: string;
  sponsors: SellSponsor[];
  entitlements: Record<string, PlanEntitlement[]>;
}) {
  const [editing, setEditing] = useState<PackageCard | "new" | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  // The page header's "Add package" links here with ?add=1.
  const addingFromLink = canSell && search.get("add") === "1";
  const editorOpen = editing !== null || addingFromLink;
  const current = editing === "new" || editing === null ? null : editing;
  const live = packages.filter((p) => !p.isArchived);
  const archived = packages.filter((p) => p.isArchived);
  const sellPackages = packages.map(toSellPackage);

  function closeEditor() {
    setEditing(null);
    if (search.get("add")) {
      const next = new URLSearchParams(search.toString());
      next.delete("add");
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    }
  }

  function archive(p: PackageCard, archivedNow: boolean) {
    start(async () => {
      const res = await setPackageArchived({ packageId: p.id, archived: archivedNow });
      if (!res.ok) toast.error(res.error);
      else if (archivedNow) {
        toast.success(res.message ?? `Archived ${p.name}`, {
          description: "It can't be sold; its sales stay in revenue.",
          action: { label: "Undo", onClick: () => archive(p, false) },
        });
      } else toast.success(res.message ?? `Restored ${p.name}`);
      router.refresh();
    });
  }

  function move(p: PackageCard, direction: "up" | "down") {
    start(async () => {
      const res = await movePackage({ packageId: p.id, direction });
      if (!res.ok) toast.error(res.error);
      router.refresh();
    });
  }

  async function onDelete(p: PackageCard) {
    const ok = await confirm({
      title: `Delete ${p.name}?`,
      description:
        "It has never been sold, so it is removed from this event's packages. History keeps a record.",
      confirmLabel: "Delete package",
      destructive: true,
    });
    if (!ok) return;
    start(async () => {
      const res = await deletePackage({ packageId: p.id });
      if (res.ok) toast.success(res.message ?? `Removed ${p.name}`);
      else toast.error(res.error);
      router.refresh();
    });
  }

  const card = (p: PackageCard, i: number) => {
    const soldOut = p.availability === "sold_out";
    const sellBlocked = p.isArchived
      ? "Archived — restore it to sell it"
      : soldOut
        ? "All places are sold — offer more under Edit package"
        : undefined;
    return (
      <li
        key={p.id}
        aria-label={p.name}
        data-archived={p.isArchived || undefined}
        className="data-[archived]:bg-muted/40 flex min-w-0 flex-col gap-3 rounded-lg border p-3 text-sm"
      >
        <div className="flex items-start gap-2">
          <div className="min-w-0 flex-1">
            <p className="font-medium break-words">{p.name}</p>
            {p.description && (
              <p className="text-muted-foreground text-xs break-words">{p.description}</p>
            )}
            <p className="text-muted-foreground mt-0.5 text-xs">{p.soldLine}</p>
          </div>
          <div className="flex shrink-0 flex-col items-end gap-1">
            {canSeeCosts && (
              <span className="font-semibold tabular-nums">
                {p.price != null ? formatMoney(p.price, currency) : "No price yet"}
              </span>
            )}
            <span
              className={cn(
                "rounded-md px-1.5 py-0.5 text-xs font-medium whitespace-nowrap",
                soldOut
                  ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
                  : "bg-muted text-foreground",
              )}
            >
              {p.isArchived ? "Archived" : availabilityLabel(p.places, p.sold)}
            </span>
          </div>
          {canSell && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  size="icon"
                  variant="ghost"
                  className="size-11 shrink-0 sm:size-9"
                  aria-label={`Change ${p.name}`}
                  disabled={pending}
                >
                  <MoreHorizontal aria-hidden />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-52">
                <DropdownMenuItem onSelect={() => setEditing(p)}>
                  <Pencil aria-hidden /> Edit package
                </DropdownMenuItem>
                {p.isArchived ? (
                  <DropdownMenuItem onSelect={() => archive(p, false)}>
                    <RotateCcw aria-hidden /> Restore
                  </DropdownMenuItem>
                ) : (
                  <>
                    <DropdownMenuItem disabled={i === 0} onSelect={() => move(p, "up")}>
                      <ArrowUp aria-hidden /> Move up
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      disabled={i === live.length - 1}
                      onSelect={() => move(p, "down")}
                    >
                      <ArrowDown aria-hidden /> Move down
                    </DropdownMenuItem>
                  </>
                )}
                <DropdownMenuSeparator />
                {!p.referenced ? (
                  <DropdownMenuItem
                    className="text-destructive focus:text-destructive"
                    onSelect={() => void onDelete(p)}
                  >
                    <Trash2 aria-hidden /> Delete package
                  </DropdownMenuItem>
                ) : (
                  !p.isArchived && (
                    <DropdownMenuItem onSelect={() => archive(p, true)}>
                      <Archive aria-hidden /> Archive
                    </DropdownMenuItem>
                  )
                )}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>

        <div className="min-w-0">
          <p className="text-muted-foreground text-xs font-medium">What&apos;s included</p>
          {p.lines.length === 0 ? (
            <p className="text-muted-foreground text-xs">
              Nothing listed as included yet{canSell ? " — add it under Edit package" : ""}
            </p>
          ) : (
            <ul className="mt-0.5 space-y-0.5 text-xs break-words">
              {p.lines.map((l) => (
                <li key={l.id}>
                  {l.quantity > 1 ? `${l.quantity} × ` : ""}
                  {l.description}
                </li>
              ))}
            </ul>
          )}
        </div>

        {p.sales.length > 0 && (
          <div className="min-w-0">
            <p className="text-muted-foreground text-xs font-medium">Sold to</p>
            <ul className="mt-0.5 space-y-0.5 text-xs break-words">
              {p.sales.map((s) => (
                <li key={s.sponsorId}>
                  <Link
                    href={`/${editionCode}/sponsorship?tab=sponsors#sponsor-${s.sponsorId}`}
                    className="link font-medium"
                  >
                    {s.companyName}
                  </Link>
                  {canSeeCosts && (
                    <span className="text-muted-foreground">
                      {" · "}
                      {s.agreedPrice != null
                        ? `${formatMoney(s.agreedPrice, currency)}${s.priceNote ? ` (${s.priceNote})` : ""}`
                        : "No price agreed yet"}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        )}

        {(canSeeCosts || canSell) && (
          <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t pt-2">
            {canSeeCosts ? (
              <p className="text-muted-foreground text-xs">
                Sold {formatMoney(p.soldValue ?? 0, currency)}
                {p.stillToSell != null &&
                  ` · ${formatMoney(p.stillToSell, currency)} still to sell`}
              </p>
            ) : (
              <span />
            )}
            {canSell && (
              <span className="flex flex-wrap gap-2">
                {p.isArchived && (
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    className="min-h-11 sm:min-h-9"
                    disabled={pending}
                    onClick={() => archive(p, false)}
                  >
                    <RotateCcw aria-hidden /> Restore
                  </Button>
                )}
                <SellPackageButton
                  fixed={{ packageId: p.id }}
                  packages={sellPackages}
                  sponsors={sponsors}
                  entitlements={entitlements}
                  currency={currency}
                  disabled={Boolean(sellBlocked)}
                  disabledReason={sellBlocked}
                />
              </span>
            )}
          </div>
        )}
      </li>
    );
  };

  return (
    <section className="space-y-3" aria-label="Packages">
      {live.length === 0 && archived.length === 0 ? (
        <EmptyState
          icon={PackageIcon}
          title="No packages yet"
          description={
            canSell
              ? "Set up what sponsors can buy as a package: its price, what's included and how many you can sell. Selling one adds what's included to the sponsor's entitlements."
              : "Packages appear here once Sales add them."
          }
          action={
            canSell && (
              <Button size="sm" className="min-h-11 sm:min-h-9" onClick={() => setEditing("new")}>
                <Plus className="size-4" /> Add the first package
              </Button>
            )
          }
        />
      ) : live.length === 0 ? (
        <p className="text-muted-foreground text-sm">
          Every package is archived{canSell ? " — restore one below, or add a new one." : "."}
        </p>
      ) : (
        <ul className="grid grid-cols-1 gap-3 lg:grid-cols-2" aria-label="Sponsorship packages">
          {live.map((p, i) => card(p, i))}
        </ul>
      )}

      {archived.length > 0 && (
        <details className="rounded-lg border">
          <summary className="flex min-h-11 cursor-pointer items-center px-3 text-sm font-medium sm:min-h-9">
            Archived packages ({archived.length})
          </summary>
          <ul
            className="grid grid-cols-1 gap-3 border-t p-3 lg:grid-cols-2"
            aria-label="Archived packages"
          >
            {archived.map((p, i) => card(p, i))}
          </ul>
        </details>
      )}
      {confirmDialog}

      <PackageEditorDialog
        editionId={editionId}
        current={current}
        currency={currency}
        open={editorOpen}
        onClose={closeEditor}
      />
    </section>
  );
}
