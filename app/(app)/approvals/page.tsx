import Link from "next/link";
import { and, eq, inArray, isNull, ne } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { editions, events, staffInvites } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import {
  ARTWORK_FILTERS,
  listArtworkApprovals,
  type ArtworkFilter,
} from "@/lib/queries/artwork-approvals";
import { listDepartments } from "@/lib/domain/departments";
import { formatDate, formatDateTime, statusLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { ApproversEditor, type DepartmentRow } from "@/components/approvals/approvers-editor";
import { Scene } from "@/components/scene";
import { brandImage } from "@/lib/brand-images";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { Button } from "@/components/ui/button";

export const metadata = { title: "Approvals" };
export const dynamic = "force-dynamic";

type Tab = "mine" | "artwork" | "approvers";

export default async function ApprovalsPage({
  searchParams,
}: {
  searchParams: Promise<{
    tab?: string;
    overdue?: string;
    all?: string;
    show?: string;
    filter?: string;
    q?: string;
  }>;
}) {
  const session = await requireStaffSession();
  const params = await searchParams;
  const tab: Tab =
    params.tab === "artwork" || params.tab === "approvers" ? params.tab : "mine";
  const canManage = can(session.actor, { type: "users.manage" });

  const tabs: { id: Tab; label: string }[] = [
    { id: "mine", label: "Waiting on me" },
    { id: "artwork", label: "All artwork" },
    { id: "approvers", label: "Approvers" },
  ];

  return (
    <div className="flex max-w-6xl flex-col gap-6 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Approvals</h1>
        <p className="text-muted-foreground text-sm">
          Signage artwork and who needs to sign it off. Every decision and comment is kept in the
          item&apos;s History.
        </p>
      </div>
      <nav className="flex gap-1 overflow-x-auto border-b" aria-label="Approvals sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={t.id === "mine" ? "/approvals" : `/approvals?tab=${t.id}`}
            className={`px-3 py-2 text-sm whitespace-nowrap ${
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground"
            }`}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      {tab === "mine" && <WaitingOnMe session={session} params={params} />}
      {tab === "artwork" && <AllArtwork organisationId={session.organisation.id} params={params} />}
      {tab === "approvers" && (
        <ApproversTab organisationId={session.organisation.id} canEdit={canManage} />
      )}
    </div>
  );
}

type Session = Awaited<ReturnType<typeof requireStaffSession>>;

async function WaitingOnMe({
  session,
  params,
}: {
  session: Session;
  params: { overdue?: string; all?: string };
}) {
  const isAdmin = session.actor.role === "admin";
  const showAll = isAdmin && params.all === "1";
  const rows = await pendingInstancesForUser(session, { all: showAll });
  const filtered = params.overdue === "1" ? rows.filter((r) => r.isOverdue) : rows;
  const base = showAll ? "/approvals?all=1" : "/approvals";
  const join = showAll ? "&" : "?";

  return (
    <section className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-sm font-semibold">
          {showAll ? "Every open sign-off" : "Sign-offs waiting on you"}
        </h2>
        <span className="text-muted-foreground text-sm">{filtered.length}</span>
        <div className="ml-auto flex flex-wrap gap-3 text-sm">
          <Link
            href={base}
            className={
              params.overdue !== "1"
                ? "font-medium underline"
                : "text-muted-foreground hover:underline"
            }
          >
            Everything
          </Link>
          <Link
            href={`${base}${join}overdue=1`}
            className={
              params.overdue === "1"
                ? "font-medium underline"
                : "text-muted-foreground hover:underline"
            }
          >
            Overdue only
          </Link>
          {isAdmin && (
            <Link
              href={showAll ? "/approvals" : "/approvals?all=1"}
              className="text-muted-foreground hover:underline"
            >
              {showAll ? "Just mine" : "Everyone's (admin)"}
            </Link>
          )}
        </div>
      </div>

      {filtered.length === 0 ? (
        <div className="border-border flex flex-col items-center gap-4 rounded-lg border border-dashed p-8">
          <Scene
            kind="office"
            photo={brandImage("office")}
            alt="Event operations team planning at a schedule wall"
            className="w-full max-w-md"
          />
          <p className="text-muted-foreground text-sm">
            Nothing is waiting on you.{" "}
            <Link href="/approvals?tab=artwork" className="underline">
              See all artwork
            </Link>
          </p>
        </div>
      ) : (
        <ol className="space-y-2">
          {filtered.map(({ raw, bundle, isSignage, isOverdue }) => {
            const b = bundle as never as {
              item?: {
                ref: string;
                name: string;
                kind: string;
                currentArtworkVersionId: string | null;
              };
              sub?: { ref: string; submissionVersion: number };
              exhibitor?: { companyName: string; standNumber: string };
              edition: { code: string; name: string };
            };
            const ref = isSignage ? b.item!.ref : b.sub!.ref;
            const title = isSignage
              ? b.item!.name
              : `${b.exhibitor!.companyName} — stand ${b.exhibitor!.standNumber}`;
            const section = b.item?.kind === "sponsorship_item" ? "sponsorship" : "signage";
            const href = isSignage
              ? `/${b.edition.code}/${section}/${ref}?tab=artwork`
              : `/${b.edition.code}/stands/${ref}`;
            return (
              <li key={raw.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
                <StatusBadge status="pending" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm">
                    <Link href={href} className="font-medium hover:underline">
                      {ref}
                    </Link>{" "}
                    — {title}
                  </p>
                  <p
                    className={`text-xs ${isOverdue ? "text-destructive font-medium" : "text-muted-foreground"}`}
                  >
                    {raw.stepNameSnapshot} · {b.edition.name}
                    {raw.dueAt ? ` · due ${formatDateTime(raw.dueAt)}` : ""}
                    {isOverdue ? " — overdue" : ""}
                  </p>
                </div>
                <Link href={href} className="text-sm underline">
                  View artwork
                </Link>
                <DecideButtons
                  instanceId={raw.id}
                  stepKind={raw.stepKindSnapshot}
                  stepName={raw.stepNameSnapshot}
                  expectedStatus="pending"
                  expectedLockedVersionId={
                    isSignage
                      ? (b.item!.currentArtworkVersionId ?? null)
                      : String(b.sub!.submissionVersion)
                  }
                  requiresPhoto={
                    raw.stepNameSnapshot === "Installed" &&
                    isSignage &&
                    b.item!.kind === "signage" &&
                    session.organisation.settings.install_photo_required
                  }
                  compact
                />
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

const SIGNOFF_TONE: Record<string, string> = {
  approved: "text-emerald-700 dark:text-emerald-400",
  approved_with_conditions: "text-teal-700 dark:text-teal-400",
  changes_requested: "text-orange-700 dark:text-orange-400",
  rejected: "text-destructive",
  pending: "text-sky-700 dark:text-sky-400",
};

async function AllArtwork({
  organisationId,
  params,
}: {
  organisationId: string;
  params: { show?: string; filter?: string; q?: string };
}) {
  const shows = await db
    .select({ id: editions.id, code: editions.code, name: editions.name })
    .from(editions)
    .innerJoin(events, eq(editions.eventId, events.id))
    .where(and(eq(events.organisationId, organisationId), ne(editions.status, "archived")))
    .orderBy(editions.openStart);
  const show = shows.find((s) => s.code === params.show) ?? null;
  const filter: ArtworkFilter =
    params.filter && (params.filter === "all" || params.filter in ARTWORK_FILTERS)
      ? (params.filter as ArtworkFilter)
      : "waiting";
  const { rows, counts, truncated } = await listArtworkApprovals({
    organisationId,
    editionId: show?.id ?? null,
    filter,
    search: params.q,
  });

  const hrefFor = (f: string) => {
    const q = new URLSearchParams({ tab: "artwork", filter: f });
    if (show) q.set("show", show.code);
    if (params.q) q.set("q", params.q);
    return `/approvals?${q.toString()}`;
  };
  const filters: [string, string][] = [
    ...Object.entries(ARTWORK_FILTERS).map(([k, v]) => [k, v.label] as [string, string]),
    ["all", "Everything"],
  ];

  return (
    <section className="space-y-4">
      <form className="flex flex-wrap items-end gap-2" action="/approvals">
        <input type="hidden" name="tab" value="artwork" />
        <input type="hidden" name="filter" value={filter} />
        <label className="grid gap-1 text-xs">
          Show
          <SelectNative name="show" defaultValue={show?.code ?? ""} className="h-9 w-56">
            <option value="">All shows</option>
            {shows.map((s) => (
              <option key={s.id} value={s.code}>
                {s.name}
              </option>
            ))}
          </SelectNative>
        </label>
        <label className="grid gap-1 text-xs">
          Search
          <Input
            name="q"
            defaultValue={params.q ?? ""}
            placeholder="Name or ref"
            className="h-9 w-56"
          />
        </label>
        <Button type="submit" variant="outline" className="h-9">
          Apply
        </Button>
      </form>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Filter by sign-off">
        {filters.map(([key, label]) => (
          <Link
            key={key}
            href={hrefFor(key)}
            className={`rounded-full border px-3 py-1 text-sm ${
              filter === key
                ? "bg-foreground text-background border-foreground"
                : "hover:bg-muted"
            }`}
            aria-current={filter === key ? "true" : undefined}
          >
            {label} <span className="opacity-70">({counts[key] ?? 0})</span>
          </Link>
        ))}
      </div>

      {rows.length === 0 ? (
        <p className="text-muted-foreground rounded-lg border border-dashed p-8 text-center text-sm">
          No artwork here. Artwork appears once it&apos;s uploaded to a signage item.
        </p>
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
                  <Link href={r.href} className="font-medium hover:underline">
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
                        <span className={SIGNOFF_TONE[s.status] ?? "text-muted-foreground"}>
                          {s.status === "pending"
                            ? `waiting on ${s.who ?? "someone"}`
                            : s.status === "waiting"
                              ? "not yet (after the others)"
                              : statusLabel(s.status)}
                        </span>
                        {s.deciderName && s.decidedAt && (
                          <span className="text-muted-foreground">
                            {" "}
                            — {s.deciderName}, {formatDate(s.decidedAt)}
                          </span>
                        )}
                        {s.comment && (
                          <span className="text-muted-foreground"> “{s.comment}”</span>
                        )}
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
          Showing the newest 150 — pick a show or search to narrow it down.
        </p>
      )}
    </section>
  );
}

async function ApproversTab({
  organisationId,
  canEdit,
}: {
  organisationId: string;
  canEdit: boolean;
}) {
  const depts = await listDepartments(db, organisationId);
  const emails = [...new Set(depts.flatMap((d) => d.approvers.map((a) => a.email)))];
  const invites = emails.length
    ? await db
        .select({ email: staffInvites.invitedEmail })
        .from(staffInvites)
        .where(
          and(
            eq(staffInvites.organisationId, organisationId),
            inArray(staffInvites.invitedEmail, emails),
            isNull(staffInvites.acceptedAt),
            isNull(staffInvites.revokedAt),
          ),
        )
    : [];
  const invited = new Set(invites.map((i) => i.email));
  const rows: DepartmentRow[] = depts.map((d) => ({
    id: d.id,
    name: d.name,
    defaultFor: d.defaultFor,
    signsLast: d.signsLast,
    isArchived: d.isArchived,
    approvers: d.approvers.map((a) => ({
      id: a.id,
      fullName: a.fullName,
      jobTitle: a.jobTitle,
      email: a.email,
      isMain: a.isMain,
      state: a.active ? "active" : invited.has(a.email) ? "invited" : "none",
    })),
  }));

  return (
    <section className="space-y-3">
      <div className="text-muted-foreground max-w-3xl space-y-1 text-sm">
        <p>
          Each department signs off the artwork for the signage it&apos;s set up for. The{" "}
          <span className="text-foreground font-medium">main approver</span> gets every item unless
          someone else in the department is picked when the signage is added. Departments that
          sign off after the others wait until everyone before them has approved.
        </p>
        <p>
          New approvers get an email to set up their account with a password. They&apos;re
          emailed again whenever artwork needs their sign-off.
          {canEdit ? "" : " Only admins can change approvers."}
        </p>
      </div>
      <ApproversEditor departments={rows} canEdit={canEdit} />
    </section>
  );
}
