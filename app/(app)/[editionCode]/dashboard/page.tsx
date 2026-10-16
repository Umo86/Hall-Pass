import Link from "next/link";
import { notFound } from "next/navigation";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { getEditionByCode, showLogoUrl } from "@/lib/queries/editions";
import { dashboardData, refsForInstanceEntities } from "@/lib/queries/dashboard";
import { formatDate, formatDateTime, formatMoney, roleLabel } from "@/lib/format";
import { itemPath } from "@/lib/edition-path";
import { StatusBadge } from "@/components/status-badge";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getSetupStatus } from "@/lib/queries/setup";
import { todayInLondon } from "@/lib/today";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import { SetupCard } from "@/components/setup/setup-card";
import { ImportSheet } from "@/components/setup/import-sheet";
import { Pencil, Plus, Signpost } from "lucide-react";

export const metadata = { title: "Dashboard" };
export const dynamic = "force-dynamic";

const SIGNAGE_ORDER = [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
  "installed",
  "snagged",
  "closed",
  "rejected",
  "on_hold",
];

const FUNNEL = [
  "not_submitted",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "rejected",
];

export default async function DashboardPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ notice?: string }>;
}) {
  const session = await requireStaffSession();
  const canSeeCosts = can(session.actor, { type: "costs.view" });
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const { notice } = await searchParams;
  const archived = editionIsReadOnly(ed.edition.status);
  const canSetup = can(session.actor, { type: "settings.manage" }) && !archived;
  const canAddSigns = can(session.actor, { type: "signage.create" }) && !archived;
  const [data, logoUrl, setup] = await Promise.all([
    dashboardData(ed.edition.id),
    showLogoUrl(ed.edition.logoPath),
    // Admins and Operations see how far setup has got until it's finished.
    canSetup &&
    !(ed.edition.setupChecked ?? []).includes("dismissed") &&
    ed.edition.breakdownEnd >= todayInLondon()
      ? getSetupStatus(ed.edition, session.organisation.id, {
          canSetup,
          canUsers: can(session.actor, { type: "users.manage" }),
          canAddSigns,
        })
      : Promise.resolve(null),
  ]);
  const noSigns = Object.values(data.statusCounts).every((n) => !n);
  const refMap = await refsForInstanceEntities(data.overdue);
  const mostOverdueRef = data.mostOverdue ? refsForLink(refMap, data.mostOverdue) : null;

  function refsForLink(
    map: Awaited<ReturnType<typeof refsForInstanceEntities>>,
    inst: (typeof data.overdue)[number],
  ) {
    const entry = map.get(inst.entityId);
    if (!entry) return null;
    const href =
      inst.entityType === "signage_item"
        ? itemPath(editionCode, { kind: entry.kind ?? "signage", ref: entry.ref })
        : `/${editionCode}/stands/${entry.ref}`;
    return { ...entry, href };
  }

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      {notice && (
        <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          The event was created, but the logo wasn&apos;t saved: {notice}. Add it again from Event
          details.
        </p>
      )}
      <div className="flex flex-wrap items-end justify-between gap-3">
        {logoUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={logoUrl}
            alt={`${ed.edition.name} logo`}
            className="h-14 w-auto max-w-40 rounded border object-contain p-1"
          />
        )}
        <div className="mr-auto">
          <h1 className="text-xl font-semibold tracking-tight">{ed.edition.name}</h1>
          <p className="text-muted-foreground text-sm">
            {ed.venue.name}
            {ed.venue.address ? `, ${ed.venue.address}` : ""} · build{" "}
            {formatDate(ed.edition.buildStart)} – {formatDate(ed.edition.buildEnd)} · open{" "}
            {formatDate(ed.edition.openStart)} – {formatDate(ed.edition.openEnd)}
          </p>
        </div>
        <StatusBadge status={ed.edition.status} />
        {canSetup && (
          <Button asChild variant="outline" size="sm">
            <Link href={`/${ed.edition.code}/setup#details`}>
              <Pencil aria-hidden /> Edit details
            </Link>
          </Button>
        )}
      </div>

      {setup && !setup.summary.complete && (
        <SetupCard
          editionId={ed.edition.id}
          code={ed.edition.code}
          done={setup.summary.done}
          total={setup.summary.total}
          next={
            setup.summary.next
              ? { key: setup.summary.next.key, title: setup.summary.next.title }
              : null
          }
        />
      )}

      {data.mostOverdue && mostOverdueRef && (
        <Link
          href={mostOverdueRef.href}
          className="border-destructive/40 bg-destructive/5 hover:bg-destructive/10 block rounded-lg border p-4 text-sm"
        >
          <span className="text-destructive font-semibold">Most overdue: </span>
          <span className="font-medium">{mostOverdueRef.ref}</span> —{" "}
          {data.mostOverdue.stepNameSnapshot} sitting with{" "}
          <span className="font-medium">
            {data.mostOverdue.assignedRole
              ? roleLabel(data.mostOverdue.assignedRole)
              : "a named person"}
          </span>
          , due {formatDateTime(data.mostOverdue.dueAt)}
        </Link>
      )}

      <section className="grid gap-4 lg:grid-cols-3">
        <div className="rounded-lg border p-4 lg:col-span-2">
          <h2 className="mb-3 text-sm font-semibold">Signage by status</h2>
          {noSigns ? (
            <EmptyState
              icon={Signpost}
              title="No signs yet"
              description="Add them one by one, or import the schedule you already have in a spreadsheet."
              className="py-6"
              action={
                canAddSigns ? (
                  <>
                    <Button asChild>
                      <Link href={`/${editionCode}/signage/new`}>
                        <Plus aria-hidden /> Add a sign
                      </Link>
                    </Button>
                    <ImportSheet editionId={ed.edition.id} />
                  </>
                ) : undefined
              }
            />
          ) : (
            <div className="flex flex-wrap gap-2">
              {SIGNAGE_ORDER.filter((s) => data.statusCounts[s]).map((s) => (
                <Link
                  key={s}
                  href={`/${editionCode}/signage?status=${s}`}
                  className="hover:bg-muted/50 flex items-center gap-2 rounded-md border px-3 py-2"
                >
                  <StatusBadge status={s} />
                  <span className="text-sm font-semibold">{data.statusCounts[s]}</span>
                </Link>
              ))}
            </div>
          )}
          <Link
            href={`/${editionCode}/sponsorship`}
            className="text-muted-foreground mt-3 inline-block text-sm hover:underline"
          >
            Sold to sponsors: {data.sponsorshipCount} →
          </Link>
        </div>

        {canSeeCosts && (
          <div className="rounded-lg border p-4">
            <h2 className="mb-3 text-sm font-semibold">Signage budget</h2>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Budget</dt>
                <dd className="font-medium">{formatMoney(data.budget.budget)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Estimated</dt>
                <dd className="font-medium">{formatMoney(data.budget.estimate)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Actual</dt>
                <dd className="font-medium">{formatMoney(data.budget.actual)}</dd>
              </div>
            </dl>
          </div>
        )}
      </section>

      <section className="grid gap-4 lg:grid-cols-3">
        <div className="rounded-lg border p-4">
          <h2 className="mb-3 text-sm font-semibold">
            Sitting with{" "}
            <span className="text-muted-foreground font-normal">
              ({data.pendingTotal} open sign-offs)
            </span>
          </h2>
          {data.sittingWith.length === 0 ? (
            <p className="text-muted-foreground text-sm">Nothing is waiting on anyone.</p>
          ) : (
            <ul className="space-y-1.5 text-sm">
              {data.sittingWith.map(([role, n]) => (
                <li key={role} className="flex justify-between">
                  <span>{role}</span>
                  <span className="font-semibold">{n}</span>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="rounded-lg border p-4">
          <h2 className="mb-3 text-sm font-semibold">
            Overdue sign-offs{" "}
            <span className="text-destructive font-semibold">{data.overdueCount}</span>
          </h2>
          {data.overdue.length === 0 ? (
            <p className="text-muted-foreground text-sm">Nothing is overdue.</p>
          ) : (
            <ul className="space-y-1.5 text-sm">
              {data.overdue.map((inst) => {
                const target = refsForLink(refMap, inst);
                return (
                  <li key={inst.id}>
                    {target ? (
                      <Link href={target.href} className="hover:underline">
                        <span className="font-medium">{target.ref}</span> — {inst.stepNameSnapshot}{" "}
                        <span className="text-muted-foreground">due {formatDate(inst.dueAt)}</span>
                      </Link>
                    ) : (
                      inst.stepNameSnapshot
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <div className="rounded-lg border p-4">
          <h2 className="mb-3 text-sm font-semibold">Deadlines in the next 7 days</h2>
          {data.upcomingDeadlines.length === 0 ? (
            <p className="text-muted-foreground text-sm">No deadlines this week.</p>
          ) : (
            <ul className="space-y-1.5 text-sm">
              {data.upcomingDeadlines.map((d) => (
                <li key={d.id} className="flex justify-between gap-3">
                  <Link href={d.href} className="min-w-0 truncate hover:underline">
                    {d.label}
                  </Link>
                  <span className="shrink-0 font-medium">{formatDate(d.date)}</span>
                </li>
              ))}
              {data.upcomingCount > data.upcomingDeadlines.length && (
                <li>
                  <Link
                    href={`/${editionCode}/calendar`}
                    className="text-muted-foreground text-xs hover:underline"
                  >
                    and {data.upcomingCount - data.upcomingDeadlines.length} more on the calendar
                  </Link>
                </li>
              )}
            </ul>
          )}
        </div>
      </section>

      {standsEnabled && (
        <section className="rounded-lg border p-4">
          <h2 className="mb-3 text-sm font-semibold">Stand submissions — space-only exhibitors</h2>
          <div className="flex flex-wrap gap-2">
            {FUNNEL.map((s) => (
              <Link
                key={s}
                href={`/${editionCode}/stands?status=${s}`}
                className="hover:bg-muted/50 flex items-center gap-2 rounded-md border px-3 py-2"
              >
                <StatusBadge status={s} />
                <span className="text-sm font-semibold">{data.standCounts[s] ?? 0}</span>
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
