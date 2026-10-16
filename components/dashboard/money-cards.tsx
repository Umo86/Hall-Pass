import Link from "next/link";
import { Button } from "@/components/ui/button";
import { formatMoney, plural } from "@/lib/format";
import { cn } from "@/lib/utils";
import { DashCard } from "./card";
import type { BudgetSummary } from "./rules";

function Bar({
  pct,
  tone,
  label,
}: {
  pct: number;
  tone: "good" | "bad" | "neutral";
  label: string;
}) {
  return (
    <div
      className="bg-muted h-1.5 w-full overflow-hidden rounded-full"
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={pct}
    >
      <div
        className={cn(
          "h-full rounded-full",
          tone === "bad" ? "bg-destructive" : tone === "good" ? "bg-emerald-600" : "bg-sky-600",
        )}
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

/** The signage budget: over in red, or what is left in green, with a thin bar. */
export function BudgetCard({
  code,
  summary,
  estimate,
  actual,
  canSetBudget,
}: {
  code: string;
  summary: BudgetSummary;
  estimate: number;
  actual: number;
  canSetBudget: boolean;
}) {
  return (
    <DashCard title="Signage budget" titleHref={`/${code}/signage`}>
      {summary.state === "none" ? (
        <div className="space-y-2">
          <p className="text-muted-foreground text-sm">
            No budget set yet, so nothing to measure the costs against.
          </p>
          {canSetBudget ? (
            <Button asChild size="sm" variant="outline">
              <Link href={`/${code}/setup#details`}>Set a budget</Link>
            </Button>
          ) : (
            <p className="text-muted-foreground text-xs">An admin or Operations can set one.</p>
          )}
        </div>
      ) : (
        <div className="space-y-2">
          <p
            className={cn(
              "text-base font-semibold",
              summary.state === "over"
                ? "text-destructive"
                : "text-emerald-700 dark:text-emerald-400",
            )}
          >
            {summary.state === "over"
              ? `Over budget by ${formatMoney(summary.difference)}`
              : summary.state === "on"
                ? "Exactly on budget"
                : `${formatMoney(summary.difference)} left`}
          </p>
          <Bar
            pct={summary.pct}
            tone={summary.state === "over" ? "bad" : "good"}
            label={`${summary.pct}% of the budget ${summary.basis === "actual" ? "spent" : "estimated"}`}
          />
          {summary.basis === "actual" && (
            <p className="text-muted-foreground text-xs">Based on actual costs so far.</p>
          )}
        </div>
      )}
      <dl className="space-y-1.5 text-sm">
        {summary.state !== "none" && (
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">Budget</dt>
            <dd className="font-medium tabular-nums">{formatMoney(summary.budget)}</dd>
          </div>
        )}
        <div className="flex justify-between gap-3">
          <dt className="text-muted-foreground">Estimated</dt>
          <dd className="font-medium tabular-nums">{formatMoney(estimate)}</dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-muted-foreground">Actual</dt>
          <dd className="font-medium tabular-nums">{formatMoney(actual)}</dd>
        </div>
      </dl>
    </DashCard>
  );
}

/**
 * Sponsorship at a glance: sold of what is for sale, sales, and what must
 * be ordered soon — each a link to the Sponsorship page filtered to it.
 */
export function SponsorshipCard({
  code,
  summary,
  canAdd,
}: {
  code: string;
  summary: {
    forSale: number;
    sold: number;
    available: number;
    inPackage: number;
    sales: number;
    urgent: number;
    urgentUnsold: number;
  };
  canAdd: boolean;
}) {
  const page = `/${code}/sponsorship`;
  if (summary.forSale === 0 && summary.inPackage === 0) {
    return (
      <DashCard title="Sponsorship" titleHref={page}>
        <p className="text-muted-foreground text-sm">Nothing is for sale to sponsors yet.</p>
        {canAdd && (
          <Button asChild size="sm" variant="outline" className="w-fit">
            <Link href={`${page}/new`}>Add a sponsorship item</Link>
          </Button>
        )}
      </DashCard>
    );
  }
  const pct = summary.forSale ? Math.round((summary.sold / summary.forSale) * 100) : 0;
  return (
    <DashCard title="Sponsorship" titleHref={page}>
      <div className="space-y-2">
        <p className="text-sm">
          <Link href={`${page}?filter=sold`} className="text-base font-semibold hover:underline">
            {summary.sold} of {summary.forSale} sold
          </Link>
          {summary.sales > 0 && (
            <span className="text-muted-foreground"> · {formatMoney(summary.sales)} sales</span>
          )}
        </p>
        <Bar pct={pct} tone="good" label={`${pct}% of sponsorship items sold`} />
      </div>
      <ul className="space-y-1.5 text-sm">
        {summary.available > 0 && (
          <li>
            <Link href={`${page}?filter=available`} className="hover:underline">
              {plural(summary.available, "item")} still for sale
            </Link>
          </li>
        )}
        {summary.urgent > 0 && (
          <li>
            <Link
              href={`${page}?filter=urgent`}
              className="text-destructive font-medium hover:underline"
            >
              {summary.urgent} to order within a month
              {summary.urgentUnsold > 0 && ` · ${summary.urgentUnsold} not sold yet`}
            </Link>
          </li>
        )}
        {summary.inPackage > 0 && (
          <li className="text-muted-foreground">
            <Link href={`${page}?filter=in_package`} className="hover:underline">
              {plural(summary.inPackage, "sponsor sign")} in packages
            </Link>
          </li>
        )}
      </ul>
    </DashCard>
  );
}
