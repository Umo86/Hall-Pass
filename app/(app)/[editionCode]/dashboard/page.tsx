import Link from "next/link";
import { notFound } from "next/navigation";
import { Pencil, Plus, Signpost } from "lucide-react";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature, type Feature } from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { getEditionByCode, showLogoUrl } from "@/lib/queries/editions";
import { dashboardData } from "@/lib/queries/dashboard";
import { plural } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { getSetupStatus, setupPermissionsFor } from "@/lib/queries/setup";
import { todayInLondon } from "@/lib/today";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import { Page, PageHeader } from "@/components/page-header";
import { SetupCard } from "@/components/setup/setup-card";
import { ImportSheet } from "@/components/setup/import-sheet";
import { DashCard } from "@/components/dashboard/card";
import { CountdownPill } from "@/components/dashboard/countdown-pill";
import { NextSteps } from "@/components/dashboard/next-steps";
import { SignageProgress } from "@/components/dashboard/signage-progress";
import { BudgetCard, SponsorshipCard } from "@/components/dashboard/money-cards";
import { OverdueCard, SittingWithCard } from "@/components/dashboard/signoff-cards";
import { UpcomingCard } from "@/components/dashboard/upcoming-card";
import {
  budgetSummary,
  dateRange,
  eventCountdown,
  nextStepRows,
  signageProgress,
} from "@/components/dashboard/rules";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ editionCode: string }> }) {
  const { editionCode } = await params;
  return { title: `Dashboard · ${editionCode.toUpperCase()}` };
}

const FUNNEL = [
  "not_submitted",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "rejected",
];

/**
 * The event at a glance: what is waiting on you first, then signage
 * progress, money, who sign-offs are sitting with, what is overdue and
 * what is due this week. Every number opens the list behind it.
 */
export default async function DashboardPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ notice?: string }>;
}) {
  const session = await requireStaffSession();
  const actor = session.actor;
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const { notice } = await searchParams;
  const edition = ed.edition;
  const code = edition.code;
  const today = todayInLondon();
  const archived = editionIsReadOnly(edition.status);
  // Setup progress for anyone who gets events ready; each step by its own ability.
  const canSetup = can(actor, { type: "event.setup" }) && !archived;
  const canEditEvent = can(actor, { type: "events.edit" }) && !archived;
  const canAddSigns = can(actor, { type: "signage.create" }) && !archived;
  const canSeeCosts = can(actor, { type: "costs.view" });
  const has = (f: Feature) => hasFeature(actor, f);
  const [data, logoUrl, setup] = await Promise.all([
    dashboardData({ edition, actor, today }),
    showLogoUrl(edition.logoPath),
    // Admins and Operations see how far setup has got until it's finished.
    canSetup && !(edition.setupChecked ?? []).includes("dismissed") && edition.breakdownEnd >= today
      ? getSetupStatus(
          edition,
          session.organisation.id,
          setupPermissionsFor(actor, { readOnly: archived }),
        )
      : Promise.resolve(null),
  ]);
  const progress = signageProgress(data.statusCounts);
  const noSigns = progress.total === 0 && progress.rejected === 0;
  const setupPending = Boolean(setup && !setup.summary.complete);

  // Your next steps: everyone but viewers, on events still running. Lines
  // for a section only for people who work in it.
  const showNextSteps = actor.role !== "viewer" && !archived;
  const nextRows = nextStepRows({
    code,
    signoffs: data.next.signoffs,
    tasks: data.next.tasks,
    sponsorship: can(actor, { type: "sponsorship.create" }) ? data.next.sponsorship : null,
    onsite: has("onsite") && can(actor, { type: "snag.manage" }) ? data.next.onsite : null,
  });

  // Those who chase sign-offs (approval.chase) work from the team view (each
  // line opens that person's or team's sign-offs); everyone else sees the artwork.
  const team = can(actor, { type: "approval.chase" });
  const sittingHref = team
    ? `/approvals?tab=mine&all=1&event=${code}`
    : `/approvals?tab=artwork&event=${code}&filter=waiting`;
  const sittingRows = data.sittingWith.map((row) => ({
    ...row,
    href: team
      ? `/approvals?${new URLSearchParams({ tab: "mine", all: "1", event: code, who: row.who.join(",") })}`
      : sittingHref,
  }));
  // The overdue card counts what its link lists: every overdue step for the
  // team view, else overdue artwork sign-offs (one per item).
  const overdueHref = team
    ? `/approvals?tab=mine&all=1&overdue=1&event=${code}`
    : `/approvals?tab=artwork&event=${code}&filter=waiting&overdue=1`;

  const venue = `${ed.venue.name}${ed.venue.address ? `, ${ed.venue.address}` : ""}`;
  const showSignage = has("signage");
  const showBudget = showSignage && canSeeCosts;
  const showSponsorship = has("sponsorship");

  return (
    <Page width="full" className="max-w-7xl">
      {notice && (
        <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          The event was created, but the logo wasn&apos;t saved: {notice}. Add it again from Event
          details.
        </p>
      )}

      <div className="flex items-start gap-4">
        {logoUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={logoUrl}
            alt={`${edition.name} logo`}
            className="h-10 w-auto max-w-28 shrink-0 rounded border object-contain p-1 sm:h-14 sm:max-w-40"
          />
        )}
        <PageHeader
          className="min-w-0 flex-1"
          title={edition.name}
          description={venue}
          meta={
            <span className="flex flex-wrap items-center gap-x-3 gap-y-1.5">
              <span>
                Build-up {dateRange(edition.buildStart, edition.buildEnd)} · Open{" "}
                {dateRange(edition.openStart, edition.openEnd)}
              </span>
              <CountdownPill countdown={eventCountdown(edition, today)} />
            </span>
          }
          actions={
            canEditEvent || canAddSigns ? (
              <>
                {canEditEvent && (
                  <Button asChild variant="outline" size="sm">
                    <Link href={`/${code}/setup#details`}>
                      <Pencil aria-hidden /> Edit event details
                    </Link>
                  </Button>
                )}
                {canAddSigns && (
                  <Button asChild size="sm">
                    <Link href={`/${code}/signage/new`}>
                      <Plus aria-hidden /> New sign
                    </Link>
                  </Button>
                )}
              </>
            ) : undefined
          }
        />
      </div>

      {setup && !setup.summary.complete && (
        <SetupCard
          editionId={edition.id}
          code={code}
          done={setup.summary.done}
          total={setup.summary.total}
          next={
            setup.summary.next
              ? { key: setup.summary.next.key, title: setup.summary.next.title }
              : null
          }
        />
      )}

      {showNextSteps && (
        <NextSteps rows={nextRows} eventName={edition.name} setupPending={setupPending} />
      )}

      {(showSignage || showBudget || showSponsorship) && (
        <div className="grid gap-4 lg:grid-cols-3">
          {showSignage && (
            <DashCard
              title="Signage progress"
              titleHref={`/${code}/signage`}
              count={
                noSigns ? undefined : (
                  <span className="text-muted-foreground font-normal">
                    {plural(progress.total, "item")}
                  </span>
                )
              }
              className="lg:col-span-2 lg:self-start"
            >
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
                          <Link href={`/${code}/signage/new`}>
                            <Plus aria-hidden /> Add a sign
                          </Link>
                        </Button>
                        <ImportSheet editionId={edition.id} />
                      </>
                    ) : undefined
                  }
                />
              ) : (
                <SignageProgress
                  code={code}
                  total={progress.total}
                  stages={progress.stages}
                  rejected={progress.rejected}
                />
              )}
            </DashCard>
          )}
          {(showBudget || showSponsorship) && (
            <div className="flex flex-col gap-4">
              {showBudget && (
                <BudgetCard
                  code={code}
                  summary={budgetSummary(data.budget)}
                  estimate={data.budget.estimate}
                  actual={data.budget.actual}
                  canSetBudget={canEditEvent}
                />
              )}
              {showSponsorship && (
                <SponsorshipCard
                  code={code}
                  // Sales figures only for people who see prices.
                  summary={canSeeCosts ? data.sponsorship : { ...data.sponsorship, sales: 0 }}
                  canAdd={can(actor, { type: "sponsorship.create" }) && !archived}
                />
              )}
            </div>
          )}
        </div>
      )}

      <div className="grid gap-4 lg:grid-cols-3">
        <SittingWithCard rows={sittingRows} total={data.pendingTotal} href={sittingHref} />
        <OverdueCard
          rows={team ? data.overdue : data.overdueArtwork}
          total={team ? data.overdueCount : data.overdueArtworkCount}
          seeAllHref={overdueHref}
        />
        <UpcomingCard
          rows={data.upcomingDeadlines}
          total={data.upcomingCount}
          today={today}
          calendarHref={has("calendar") ? `/${code}/calendar?view=upcoming` : null}
          canOpen={(feature) => !feature || has(feature)}
        />
      </div>

      {standsEnabled && has("stands") && (
        <DashCard title="Stand submissions — space-only exhibitors" titleHref={`/${code}/stands`}>
          <div className="flex flex-wrap gap-2">
            {FUNNEL.map((s) => (
              <Link
                key={s}
                href={`/${code}/stands?status=${s}`}
                className="hover:bg-muted/50 flex items-center gap-2 rounded-md border px-3 py-2"
              >
                <StatusBadge status={s} />
                <span className="text-sm font-semibold">{data.standCounts[s] ?? 0}</span>
              </Link>
            ))}
          </div>
        </DashCard>
      )}
    </Page>
  );
}
