import Link from "next/link";
import { Users as UsersIcon } from "lucide-react";
import {
  canManagePerson,
  canRenewInvite,
  editionScope,
  FEATURE_LABELS,
  managerScope,
  type Actor,
} from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { db } from "@/lib/db/client";
import { filterTeam, listTeam, needsDepartment, type TeamFilters } from "@/lib/users/queries";
import { eventsSummary, eventsTitle, featuresSummary, visibleFeatures } from "@/lib/users/rules";
import { listEditions } from "@/lib/queries/editions";
import {
  lastActiveText,
  managerBadgeText,
  parseStatusFilter,
  personStatus,
} from "@/lib/users/list";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { formatDateTime, plural, roleLabel } from "@/lib/format";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { TeamFilters as Filters } from "./team-filters";
import { TeamList, type TeamListRow } from "./team-list";
import { AddPeopleMenu } from "./add-menu";

const PAGE_SIZE = 50;

export type TeamParams = {
  q?: string;
  dept?: string;
  role?: string;
  status?: string;
  activity?: string;
  page?: string;
};

/**
 * Users → Team: everyone on the team. Super admins and managers also see
 * open invitations (the ones they may change), sections, status and last
 * active, and can select the people they manage for a bulk change; a
 * department manager starts on their own department. Everyone else sees a
 * directory.
 */
export async function TeamTab({
  organisationId,
  viewerId,
  isAdmin,
  actor,
  params,
}: {
  organisationId: string;
  viewerId: string;
  /** Adds and changes people (people.manage): sees invitations, sections and status. */
  isAdmin: boolean;
  actor: Actor;
  params: TeamParams;
}) {
  const now = new Date();
  const { rows: all, departments } = await listTeam(db, organisationId, viewerId, now);
  const manages = (r: (typeof all)[number]) =>
    !r.isSelf &&
    canManagePerson(actor, {
      organisationId,
      userId: r.kind === "member" ? r.id : null,
      role: r.role,
      departmentId: r.departmentId,
      managerScope: r.managerScope,
    });
  // Invitations, sections and status are for people who manage the team;
  // everyone else sees a directory. Managers see the invitations they may change.
  const everyone = isAdmin
    ? all.filter((r) => r.kind === "member" || manages(r))
    : all.filter((r) => r.kind === "member");
  // A department manager starts on their own department ("all" shows everyone).
  const ownDept =
    actor.kind === "staff" && managerScope(actor) === "department"
      ? (actor.departmentId ?? null)
      : null;
  const dept = params.dept === "all" ? undefined : (params.dept ?? ownDept ?? undefined);
  const filters: TeamFilters = {
    q: params.q,
    dept,
    role: params.role,
    status: isAdmin ? parseStatusFilter(params.status) : undefined,
    activity: isAdmin && params.activity === "stale" ? "stale" : undefined,
  };
  const filtered = filterTeam(everyone, filters, now);
  const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const page = Math.min(pages, Math.max(1, Number(params.page) || 1));
  const shown = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const invited = filtered.filter((r) => r.kind === "invite").length;
  const noDept = everyone.filter(needsDepartment).length;
  const filtering = Boolean(
    filters.q || filters.dept || filters.role || filters.status || filters.activity,
  );
  const visible = visibleFeatures(standsEnabled);

  // Users → Events: codes only for events the viewer can open.
  const codes = new Map(
    (await listEditions(organisationId, editionScope(actor))).map((e) => [
      e.edition.id,
      e.edition.code,
    ]),
  );
  const codeOf = (id: string) => codes.get(id) ?? null;
  const rows: TeamListRow[] = shown.map((r) => {
    const features = r.role === "admin" ? null : r.features;
    return {
      kind: r.kind,
      id: r.id,
      name: r.name,
      email: r.email,
      isSelf: r.isSelf,
      jobTitle: r.jobTitle,
      role: r.role,
      roleText: roleLabel(r.role),
      managerBadge: managerBadgeText(r, r.departmentName),
      departmentName: r.departmentName,
      departmentArchived: r.departmentArchived,
      sections: featuresSummary(features, visible),
      sectionsTitle:
        features === null
          ? "Every section"
          : features
              .filter((f) => visible.includes(f))
              .map((f) => FEATURE_LABELS[f])
              .join(", ") || "No sections",
      events: r.editionIds
        ? {
            text: eventsSummary(r.editionIds, codeOf),
            title: eventsTitle(r.editionIds, codeOf),
          }
        : null,
      signsOffFor: r.signsOffFor.map((s) => ({
        name: s.name,
        isMain: s.isMain,
        mainOnAccept: s.mainOnAccept,
      })),
      status: personStatus(r),
      statusText: r.statusText,
      lastActive: r.kind === "member" ? lastActiveText(r.lastSeenAt, now) : null,
      lastActiveTitle: r.lastSeenAt ? formatDateTime(r.lastSeenAt) : null,
      manageable: isAdmin && manages(r),
      // Resend / Copy link only for invitations the viewer could have made.
      canRenew:
        r.kind === "invite" &&
        canRenewInvite(actor, {
          role: r.role,
          departmentId: r.departmentId,
          features,
          overrides: r.overrides,
          managerScope: r.managerScope,
          // An ask ("main when they accept") counts as main approver here.
          signoffs: r.signsOffFor.map((s) => ({
            departmentId: s.departmentId,
            isMain: s.isMain || s.mainOnAccept,
          })),
          accessEndsAt: r.accessEndsAt,
          editionIds: r.editionIds,
        }),
    };
  });

  const pageHref = (p: number) => {
    const q = new URLSearchParams();
    const keep = { ...filters, dept: params.dept };
    for (const [k, v] of Object.entries(keep)) if (v) q.set(k, v);
    if (p > 1) q.set("page", String(p));
    const s = q.toString();
    return s ? `/users?${s}` : "/users";
  };

  if (everyone.length <= 1 && !filtering) {
    return (
      <EmptyState
        icon={UsersIcon}
        title="It's just you so far"
        description={
          isAdmin
            ? "Add the people you work with — they'll get an email to set up their account."
            : "A super admin adds the people you work with here."
        }
        action={isAdmin && <AddPeopleMenu />}
      />
    );
  }

  const ownDeptName = ownDept ? departments.find((d) => d.id === ownDept)?.name : null;

  return (
    <section className="space-y-4" aria-label="Team">
      {isAdmin && noDept > 0 && filters.dept !== "none" && !ownDept && (
        <p className="flex flex-wrap items-center gap-x-2 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          {noDept === 1 ? "1 person has" : `${noDept} people have`} no department yet.
          <Link href="/users?dept=none" className="font-medium underline underline-offset-2">
            Show them
          </Link>
        </p>
      )}
      <Filters
        departments={departments.map((d) => ({ id: d.id, name: d.name, isArchived: d.isArchived }))}
        showStatus={isAdmin}
        defaultDept={ownDept}
      />
      <p className="text-muted-foreground text-sm" aria-live="polite">
        {plural(filtered.length, "person", "people")}
        {isAdmin && invited > 0 ? ` · ${invited} invited` : ""}
        {ownDeptName && dept === ownDept ? (
          <>
            {" "}
            in {ownDeptName} ·{" "}
            <Link href="/users?dept=all" className="link">
              Show everyone
            </Link>
          </>
        ) : null}
      </p>
      {filtered.length === 0 ? (
        <EmptyState
          icon={UsersIcon}
          title="No one matches"
          description="Try another name, or clear the filters to see everyone."
          action={
            <Button asChild variant="outline">
              <Link href={ownDept ? "/users?dept=all" : "/users"}>Clear filters</Link>
            </Button>
          }
        />
      ) : (
        <TeamList rows={rows} isAdmin={isAdmin} emailOn={invitesCanBeEmailed()} />
      )}
      {pages > 1 && (
        <nav className="flex items-center justify-between gap-2 text-sm" aria-label="Pages">
          {page > 1 ? (
            <Button asChild variant="outline" className="h-11 sm:h-9">
              <Link href={pageHref(page - 1)}>Previous</Link>
            </Button>
          ) : (
            <span />
          )}
          <span className="text-muted-foreground">
            Page {page} of {pages}
          </span>
          {page < pages ? (
            <Button asChild variant="outline" className="h-11 sm:h-9">
              <Link href={pageHref(page + 1)}>Next</Link>
            </Button>
          ) : (
            <span />
          )}
        </nav>
      )}
    </section>
  );
}
