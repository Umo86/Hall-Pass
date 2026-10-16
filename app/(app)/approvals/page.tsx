import Link from "next/link";
import { and, eq, ne } from "drizzle-orm";
import { CheckCircle2, ImageOff, SearchX } from "lucide-react";
import { db } from "@/lib/db/client";
import { editions, events } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import {
  countPendingForUser,
  listOverdueArtwork,
  openSignoffsForTeam,
  parseWhoParam,
  pendingInstancesForUser,
} from "@/lib/queries/approvals";
import {
  ARTWORK_FILTERS,
  countItemsInSignoff,
  listArtworkApprovals,
  reviewArtworkForItems,
  type ArtworkFilter,
} from "@/lib/queries/artwork-approvals";
import { listDepartmentCards } from "@/lib/users/queries";
import { formatDate } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { WhoSignsOff } from "@/components/approvals/approvers-editor";
import { Page, PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { SegmentedLinks } from "@/components/ui/segmented";
import { Button } from "@/components/ui/button";
import { ListFilters } from "@/components/approvals/queue-filters";
import { ReviewQueue } from "@/components/approvals/review-queue";
import { TeamView } from "@/components/approvals/team-view";
import type { QueueRow } from "@/components/approvals/queue-types";
import { STEP_STATE_TONE, daysOverdue, stepStateLabel } from "@/components/approvals/step-words";
import { itemPath } from "@/lib/edition-path";
import { cn } from "@/lib/utils";

export const metadata = { title: "Approvals" };
export const dynamic = "force-dynamic";

type Tab = "mine" | "artwork" | "approvers";
type Params = {
  tab?: string;
  overdue?: string;
  all?: string;
  event?: string;
  /** Older links say show= for the event. */
  show?: string;
  filter?: string;
  q?: string;
  review?: string;
  /** Everyone's: only the sign-offs with these people or teams (group keys). */
  who?: string;
};
type Session = Awaited<ReturnType<typeof requireStaffSession>>;
type Show = { id: string; code: string; name: string };

/** Those who chase sign-offs (approval.chase: admins and Operations by default) see everyone's. */
const canSeeTeam = (session: Session) => can(session.actor, { type: "approval.chase" });

export default async function ApprovalsPage({ searchParams }: { searchParams: Promise<Params> }) {
  const session = await requireStaffSession();
  const params = await searchParams;
  const canManage = can(session.actor, { type: "departments.manage" });
  const mine = await countPendingForUser(session);
  // People who never sign anything off start on All artwork.
  const neverSigns =
    mine.total === 0 &&
    (session.actor.signoffDepartmentIds ?? []).length === 0 &&
    !canSeeTeam(session);
  const tab: Tab =
    params.tab === "artwork" || params.tab === "approvers"
      ? params.tab
      : params.tab === "mine" || params.all === "1" || params.overdue === "1" || params.review
        ? "mine"
        : neverSigns
          ? "artwork"
          : "mine";

  const tabs: { id: Tab; label: string; href: string; count?: number }[] = [
    { id: "mine", label: "Waiting on me", href: "/approvals?tab=mine", count: mine.total },
    { id: "artwork", label: "All artwork", href: "/approvals?tab=artwork" },
    { id: "approvers", label: "Who signs off", href: "/approvals?tab=approvers" },
  ];
  const shows: Show[] = await db
    .select({ id: editions.id, code: editions.code, name: editions.name })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(events.organisationId, session.organisation.id), ne(editions.status, "archived")))
    .orderBy(editions.openStart);
  const eventCode = (params.event ?? params.show)?.toUpperCase();
  const show = shows.find((s) => s.code === eventCode) ?? null;

  return (
    <Page>
      <PageHeader
        title="Approvals"
        description="Review and sign off artwork, and confirm print, delivery and installation. Every decision and comment is kept in the item's History."
      />
      <nav className="-mt-2 flex gap-1 overflow-x-auto border-b" aria-label="Approvals sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={t.href}
            className={cn(
              "inline-flex min-h-11 items-center gap-1.5 px-3 text-sm whitespace-nowrap sm:min-h-9",
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground",
            )}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
            {t.count !== undefined && t.count > 0 && (
              <span
                className={cn(
                  "rounded-full px-1.5 text-xs tabular-nums",
                  mine.overdue > 0 ? "bg-destructive text-white" : "bg-muted text-foreground",
                )}
              >
                {t.count}
              </span>
            )}
          </Link>
        ))}
      </nav>

      {tab === "mine" &&
        (params.all === "1" && canSeeTeam(session) ? (
          <Everyone session={session} params={params} shows={shows} show={show} />
        ) : (
          <WaitingOnMe session={session} params={params} shows={shows} show={show} />
        ))}
      {tab === "artwork" && (
        <AllArtwork
          organisationId={session.organisation.id}
          params={params}
          shows={shows}
          show={show}
        />
      )}
      {tab === "approvers" && (
        <ApproversTab organisationId={session.organisation.id} canManage={canManage} />
      )}
    </Page>
  );
}

/** /approvals?… with these parameters (empty ones dropped). */
function hrefWith(params: Record<string, string | undefined | null>) {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v) q.set(k, v);
  const s = q.toString();
  return s ? `/approvals?${s}` : "/approvals";
}

function ScopeBar({
  session,
  params,
  show,
  all,
  counts,
}: {
  session: Session;
  params: Params;
  show: Show | null;
  all: boolean;
  counts: { total: number; overdue: number };
}) {
  const keep = {
    tab: "mine",
    event: show?.code,
    q: params.q,
    all: all ? "1" : undefined,
    who: all ? params.who : undefined,
  };
  return (
    <div className="flex flex-wrap items-center gap-2">
      <SegmentedLinks
        label="Which sign-offs"
        items={[
          {
            label: "Everything",
            href: hrefWith({ ...keep, overdue: undefined }),
            active: params.overdue !== "1",
            count: counts.total,
          },
          {
            label: "Overdue",
            href: hrefWith({ ...keep, overdue: "1" }),
            active: params.overdue === "1",
            count: counts.overdue,
          },
        ]}
      />
      {canSeeTeam(session) && (
        <SegmentedLinks
          label="Whose sign-offs"
          items={[
            {
              label: "Waiting on me",
              href: hrefWith({ ...keep, all: undefined, who: undefined, overdue: params.overdue }),
              active: !all,
            },
            {
              label: "Everyone's",
              href: hrefWith({ ...keep, all: "1", overdue: params.overdue }),
              active: all,
            },
          ]}
        />
      )}
    </div>
  );
}

function matches(search: string | undefined, ...fields: string[]) {
  const q = search?.trim().toLowerCase();
  if (!q) return true;
  return fields.some((f) => f.toLowerCase().includes(q));
}

type PendingBundle = {
  item?: {
    id: string;
    ref: string;
    name: string;
    kind: string;
    currentArtworkVersionId: string | null;
  };
  sub?: { ref: string; submissionVersion: number };
  exhibitor?: { companyName: string; standNumber: string };
  edition: { id: string; code: string; name: string };
};

async function WaitingOnMe({
  session,
  params,
  shows,
  show,
}: {
  session: Session;
  params: Params;
  shows: Show[];
  show: Show | null;
}) {
  const all = await pendingInstancesForUser(session);
  const install = session.organisation.settings.install_photo_required;

  const base = all.map(({ raw, bundle, isSignage, isOverdue }) => {
    const b = bundle as never as PendingBundle;
    const ref = isSignage ? b.item!.ref : b.sub!.ref;
    const kindLabel =
      b.item?.kind === "stand_design"
        ? "Stand design: "
        : b.item?.kind === "stand_panel"
          ? "Stand panel: "
          : "";
    const row: QueueRow = {
      instanceId: raw.id,
      kind: raw.stepKindSnapshot,
      entity: isSignage ? "signage" : "stand",
      ref,
      title: isSignage
        ? `${kindLabel}${b.item!.name}`
        : `${b.exhibitor!.companyName} — stand ${b.exhibitor!.standNumber}`,
      href: isSignage
        ? `${itemPath(b.edition.code, b.item!)}?tab=artwork`
        : `/${b.edition.code}/stands/${ref}`,
      eventCode: b.edition.code,
      eventName: b.edition.name,
      stepName: raw.stepNameSnapshot,
      dueAt: raw.dueAt ? raw.dueAt.toISOString() : null,
      overdueDays: isOverdue && raw.dueAt ? daysOverdue(raw.dueAt) : null,
      expectedLockedVersionId: isSignage
        ? (b.item!.currentArtworkVersionId ?? null)
        : String(b.sub!.submissionVersion),
      requiresPhoto: Boolean(
        raw.stepNameSnapshot === "Installed" && isSignage && b.item!.kind === "signage" && install,
      ),
      artwork: null,
      others: [],
    };
    return { b, isSignage, row };
  });
  const scoped = base.filter(
    (r) => (!show || r.b.edition.id === show.id) && matches(params.q, r.row.ref, r.row.title),
  );
  const counts = {
    total: scoped.length,
    overdue: scoped.filter((r) => r.row.overdueDays !== null).length,
  };
  const shown = params.overdue === "1" ? scoped.filter((r) => r.row.overdueDays !== null) : scoped;

  // The artwork, the version before it and the other sign-offs, for artwork rows.
  const artwork = await reviewArtworkForItems(
    session.organisation.id,
    shown.filter((r) => r.isSignage && r.row.kind === "approval").map((r) => r.b.item!.id),
  );
  const rows: QueueRow[] = shown.map(({ row, b, isSignage }) => {
    const art = isSignage && row.kind === "approval" ? artwork.get(b.item!.id) : undefined;
    if (!art) return row;
    return {
      ...row,
      artwork: { current: art.current, previous: art.previous },
      others: art.signoffs
        .filter((s) => s.id !== row.instanceId && s.stepKind === "approval")
        .map((s) => ({ id: s.id, stepName: s.stepName, status: s.status, who: s.who })),
    };
  });

  const filtered = Boolean(show || params.q || params.overdue === "1");
  return (
    <section className="space-y-4" aria-label="Waiting on me">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <ScopeBar session={session} params={params} show={show} all={false} counts={counts} />
        <ListFilters
          events={shows}
          eventCode={show?.code ?? null}
          search={params.q ?? ""}
          keep={{ tab: "mine", overdue: params.overdue }}
        />
      </div>
      {rows.length === 0 ? (
        filtered && all.length > 0 ? (
          <EmptyState
            icon={SearchX}
            title="Nothing matches these filters"
            description="Try another event, or clear the search."
            action={
              <Button asChild variant="outline">
                <Link href="/approvals?tab=mine">Clear filters</Link>
              </Button>
            }
          />
        ) : (
          <NothingWaiting organisationId={session.organisation.id} />
        )
      ) : (
        <ReviewQueue
          approvals={rows.filter((r) => r.kind === "approval")}
          confirmations={rows.filter((r) => r.kind === "confirmation")}
          initialReviewId={params.review ?? null}
        />
      )}
    </section>
  );
}

async function NothingWaiting({ organisationId }: { organisationId: string }) {
  const others = await countItemsInSignoff(organisationId);
  return (
    <EmptyState
      icon={CheckCircle2}
      title="Nothing is waiting on you"
      description={
        others > 0
          ? `${others} item${others === 1 ? " is" : "s are"} in sign-off with other people.`
          : "When artwork needs your sign-off it appears here, and the bell tells you."
      }
      action={
        <Button asChild variant="outline">
          <Link href="/approvals?tab=artwork">See all artwork</Link>
        </Button>
      }
    />
  );
}

async function Everyone({
  session,
  params,
  shows,
  show,
}: {
  session: Session;
  params: Params;
  shows: Show[];
  show: Show | null;
}) {
  const who = parseWhoParam(params.who);
  const rows = await openSignoffsForTeam(session, {
    editionId: show?.id ?? null,
    search: params.q,
    who,
  });
  const counts = { total: rows.length, overdue: rows.filter((r) => r.isOverdue).length };
  const shown = params.overdue === "1" ? rows.filter((r) => r.isOverdue) : rows;
  const whoNames = [...new Set(rows.map((r) => r.waitingOn))];
  return (
    <section className="space-y-4" aria-label="Everyone's sign-offs">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <ScopeBar session={session} params={params} show={show} all counts={counts} />
        <ListFilters
          events={shows}
          eventCode={show?.code ?? null}
          search={params.q ?? ""}
          keep={{
            tab: "mine",
            all: "1",
            overdue: params.overdue,
            who: who.length ? who.join(",") : undefined,
          }}
        />
      </div>
      {who.length > 0 ? (
        <p className="text-muted-foreground text-sm">
          {whoNames.length > 0
            ? `Only the sign-offs waiting on ${whoNames.join(", ")}.`
            : "Only the sign-offs waiting on one person or team."}{" "}
          <Link
            href={hrefWith({
              tab: "mine",
              all: "1",
              event: show?.code,
              q: params.q,
              overdue: params.overdue,
            })}
            className="link"
          >
            Show everyone&apos;s
          </Link>
        </p>
      ) : (
        <p className="text-muted-foreground text-sm">
          Every open sign-off, by who it is waiting on. Remind tells them now (once a day per
          sign-off); the nightly reminders carry on as usual.
        </p>
      )}
      {shown.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title={params.overdue === "1" ? "Nothing is overdue" : "No sign-offs are open"}
          description={
            who.length > 0
              ? "Nothing is waiting on them here."
              : "Nobody is waiting to decide anything here."
          }
        />
      ) : (
        <TeamView
          rows={shown.map((r) => ({
            instanceId: r.instanceId,
            ref: r.ref,
            name: r.name,
            href: r.href,
            eventName: r.eventName,
            stepName: r.stepName,
            stepKind: r.stepKind,
            dueAt: r.dueAt ? r.dueAt.toISOString() : null,
            overdueDays: r.isOverdue && r.dueAt ? daysOverdue(r.dueAt) : null,
            waitingOn: r.waitingOn,
            groupKey: r.groupKey,
            people: r.people,
            expectedLockedVersionId: r.expectedLockedVersionId,
            canRemind: r.canRemind,
            remindedToday: r.remindedToday,
            isMine: r.isMine,
            canDecide: r.canDecide,
            requiresPhoto: r.requiresPhoto,
          }))}
        />
      )}
    </section>
  );
}

async function AllArtwork({
  organisationId,
  params,
  shows,
  show,
}: {
  organisationId: string;
  params: Params;
  shows: Show[];
  show: Show | null;
}) {
  const filter: ArtworkFilter =
    params.filter && (params.filter === "all" || params.filter in ARTWORK_FILTERS)
      ? (params.filter as ArtworkFilter)
      : "waiting";
  // ?overdue=1 (the dashboard's overdue link): only artwork whose sign-off is late.
  const overdue = params.overdue === "1";
  const { rows, counts, truncated } = overdue
    ? {
        ...(await listOverdueArtwork({
          organisationId,
          editionId: show?.id ?? null,
          filter,
          search: params.q,
        })),
        counts: {} as Record<string, number>,
      }
    : await listArtworkApprovals({
        organisationId,
        editionId: show?.id ?? null,
        filter,
        search: params.q,
      });
  const filters: [string, string][] = [
    ...Object.entries(ARTWORK_FILTERS).map(([k, v]) => [k, v.label] as [string, string]),
    ["all", "Everything"],
  ];

  return (
    <section className="space-y-4" aria-label="All artwork">
      <div className="flex flex-col gap-3">
        <ListFilters
          events={shows}
          eventCode={show?.code ?? null}
          search={params.q ?? ""}
          keep={{ tab: "artwork", filter, overdue: overdue ? "1" : undefined }}
        />
        {overdue ? (
          <p className="text-muted-foreground text-sm">
            Only artwork whose sign-off is overdue, most overdue first.{" "}
            <Link
              href={hrefWith({ tab: "artwork", filter, event: show?.code, q: params.q })}
              className="link"
            >
              Show all artwork
            </Link>
          </p>
        ) : (
          <SegmentedLinks
            label="Filter by sign-off"
            className="w-fit"
            items={filters.map(([key, label]) => ({
              label,
              href: hrefWith({ tab: "artwork", filter: key, event: show?.code, q: params.q }),
              active: filter === key,
              count: counts[key] ?? 0,
            }))}
          />
        )}
      </div>

      {rows.length === 0 ? (
        overdue ? (
          <EmptyState
            icon={CheckCircle2}
            title="No sign-offs are overdue"
            description="All artwork in sign-off is within its due dates."
            action={
              <Button asChild variant="outline">
                <Link href={hrefWith({ tab: "artwork", filter, event: show?.code })}>
                  See all artwork
                </Link>
              </Button>
            }
          />
        ) : (
          <EmptyState
            icon={ImageOff}
            title="No artwork here"
            description={
              show || params.q
                ? "Nothing matches — try another event, filter or search."
                : "Artwork appears once it's uploaded to a signage item."
            }
          />
        )
      ) : (
        <ul className="grid gap-3 md:grid-cols-2" aria-label="Artwork">
          {rows.map((r) => (
            <li key={r.id} className="flex gap-3 rounded-lg border p-3">
              <Link
                href={r.href}
                className="bg-muted flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-md border"
                aria-label={`Open ${r.ref}`}
              >
                {r.previewUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={r.previewUrl} alt="" className="size-full object-contain" />
                ) : (
                  <span className="text-muted-foreground text-xs">v{r.version}</span>
                )}
              </Link>
              <div className="min-w-0 flex-1 space-y-1.5">
                <div className="flex flex-wrap items-center gap-2">
                  <Link href={r.href} className="link font-medium">
                    {r.ref}
                  </Link>
                  <StatusBadge status={r.status} />
                </div>
                <p className="truncate text-sm">{r.name}</p>
                <p className="text-muted-foreground text-xs">
                  {r.showName} ·{" "}
                  {r.category === "sponsor"
                    ? `Sponsor${r.sponsorName ? ` — ${r.sponsorName}` : ""}`
                    : "Organiser"}{" "}
                  · artwork v{r.version}, {formatDate(r.uploadedAt)}
                </p>
                {r.signoffs.length > 0 && (
                  <ul className="space-y-0.5 text-xs" aria-label={`${r.ref} sign-off`}>
                    {r.signoffs.map((s) => (
                      <li key={s.id}>
                        <span className="font-medium">{s.stepName}:</span>{" "}
                        <span className={STEP_STATE_TONE[s.status] ?? "text-muted-foreground"}>
                          {stepStateLabel(s.status, s.who)}
                        </span>
                        {s.deciderName && s.decidedAt && (
                          <span className="text-muted-foreground">
                            {" "}
                            — {s.deciderName}, {formatDate(s.decidedAt)}
                          </span>
                        )}
                        {s.comment && <span className="text-muted-foreground"> “{s.comment}”</span>}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
      {truncated && (
        <p className="text-muted-foreground text-xs">
          {overdue
            ? "Showing the 150 most overdue — pick an event or search to narrow it down."
            : "Showing the newest 150 — pick an event or search to narrow it down."}
        </p>
      )}
    </section>
  );
}

async function ApproversTab({
  organisationId,
  canManage,
}: {
  organisationId: string;
  canManage: boolean;
}) {
  // Read-only here: departments and approvers are managed in Users → Departments.
  const depts = await listDepartmentCards(db, organisationId);
  return (
    <WhoSignsOff
      canManage={canManage}
      departments={depts
        .filter((d) => d.signsOff && !d.isArchived)
        .map((d) => ({
          id: d.id,
          name: d.name,
          defaultFor: d.defaultFor,
          signsLast: d.signsLast,
          approvers: d.approvers.map((a) => ({
            id: a.id,
            name: a.name,
            jobTitle: a.jobTitle,
            isMain: a.isMain,
            state: a.state,
          })),
        }))}
    />
  );
}
