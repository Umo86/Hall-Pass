import Link from "next/link";
import { UserPlus, Users as UsersIcon } from "lucide-react";
import { canManagePerson, FEATURE_LABELS, isSuperAdmin, type Actor } from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { db } from "@/lib/db/client";
import { filterTeam, listTeam, needsDepartment, type TeamFilters } from "@/lib/users/queries";
import { featuresSummary, visibleFeatures } from "@/lib/users/rules";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { plural } from "@/lib/format";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { TeamFilters as Filters } from "./team-filters";
import { TeamList, type TeamListRow } from "./team-list";

const PAGE_SIZE = 50;

/** Users → Team: everyone on the team (and, for admins, open invitations). */
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
  /** The viewer: a manager sees only the invitations they may change. */
  actor?: Actor;
  params: TeamFilters & { page?: string };
}) {
  const { rows: all, departments } = await listTeam(db, organisationId, viewerId);
  // Invitations, sections and status are for people who manage the team;
  // everyone else sees a directory.
  const everyone = isAdmin
    ? all.filter(
        (r) =>
          r.kind === "member" ||
          !actor ||
          isSuperAdmin(actor) ||
          canManagePerson(actor, {
            organisationId,
            userId: null,
            role: r.role,
            departmentId: r.departmentId,
            managerScope: r.managerScope,
          }),
      )
    : all.filter((r) => r.kind === "member");
  const filters: TeamFilters = {
    q: params.q,
    dept: params.dept,
    role: params.role,
    status: isAdmin ? params.status : undefined,
  };
  const filtered = filterTeam(everyone, filters);
  const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const page = Math.min(pages, Math.max(1, Number(params.page) || 1));
  const shown = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const invited = filtered.filter((r) => r.kind === "invite").length;
  const noDept = everyone.filter(needsDepartment).length;
  const filtering = Boolean(filters.q || filters.dept || filters.role || filters.status);
  const visible = visibleFeatures(standsEnabled);

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
      signsOffFor: r.signsOffFor.map((s) => ({ name: s.name, isMain: s.isMain })),
      status: r.status,
      statusText: r.statusText,
    };
  });

  const pageHref = (p: number) => {
    const q = new URLSearchParams();
    for (const [k, v] of Object.entries(filters)) if (v) q.set(k, v);
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
            : "An admin adds the people you work with here."
        }
        action={
          isAdmin && (
            <Button asChild>
              <Link href="/users/new">
                <UserPlus aria-hidden />
                Add user
              </Link>
            </Button>
          )
        }
      />
    );
  }

  return (
    <section className="space-y-4" aria-label="Team">
      {isAdmin && noDept > 0 && filters.dept !== "none" && (
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
      />
      <p className="text-muted-foreground text-sm" aria-live="polite">
        {plural(filtered.length, "person", "people")}
        {isAdmin && invited > 0 ? ` · ${invited} invited` : ""}
      </p>
      {filtered.length === 0 ? (
        <EmptyState
          icon={UsersIcon}
          title="No one matches"
          description="Try another name, or clear the filters to see everyone."
          action={
            <Button asChild variant="outline">
              <Link href="/users">Clear filters</Link>
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
