import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Lock } from "lucide-react";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, managerScope } from "@/lib/authz";
import { abilityHolders, listDepartmentCards, memberOptions } from "@/lib/users/queries";
import { AskContacts } from "@/components/setup/no-events-state";
import { Page, PageHeader } from "@/components/page-header";
import { TeamTab } from "@/components/users/team-tab";
import { ExternalTab } from "@/components/users/external-tab";
import { DepartmentsPanel } from "@/components/users/departments-panel";
import { AddPeopleMenu } from "@/components/users/add-menu";
import { cn } from "@/lib/utils";

export const metadata = { title: "Users" };
export const dynamic = "force-dynamic";

type Tab = "team" | "external" | "departments";
/** The event last opened, if the app remembers it (code or id). */
const LAST_EVENT_COOKIE = "hp-last-event";

function one(v: string | string[] | undefined): string | undefined {
  const s = Array.isArray(v) ? v[0] : v;
  return s ? s.slice(0, 200) : undefined;
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireStaffSession();
  const actor = session.actor;
  // Super admins and managers add and change people; partners and
  // departments are their own abilities (super admins by default).
  const canPeople = can(actor, { type: "people.manage" });
  const canPartners = can(actor, { type: "partners.invite" });
  const canDepartments = can(actor, { type: "departments.manage" });
  const params = await searchParams;
  const raw = one(params.tab);
  const tab: Tab =
    raw === "external" && canPartners ? "external" : raw === "departments" ? "departments" : "team";
  const tabs: { id: Tab; label: string }[] = [
    { id: "team", label: "Team" },
    ...(canPartners ? [{ id: "external" as const, label: "External" }] : []),
    { id: "departments", label: "Departments" },
  ];
  const orgId = session.organisation.id;
  // A link to External (e.g. "invite this supplier" from a notification)
  // opened by someone who can't invite partners: Team, saying who can. Its
  // ?role= and ?invite= are dropped so they aren't read as Team filters.
  if (raw === "external" && !canPartners) redirect("/users?from=external");
  const externalRefused = !canPartners && one(params.from) === "external";
  const partnerInviters = externalRefused ? await abilityHolders(db, orgId, "partners.invite") : [];
  // Adding a team member is the main action, except on External (inviting outsiders).
  const showAdd = canPeople && tab !== "external";
  // Department managers add people to their own department from its card.
  const scope = managerScope(actor);
  const addTo: "all" | string[] =
    scope === "everyone"
      ? "all"
      : scope === "department" && actor.departmentId
        ? [actor.departmentId]
        : [];

  return (
    <Page width="full" className={cn("max-w-7xl", showAdd && "pb-24 sm:pb-6")}>
      <PageHeader
        title="Users"
        description="Everyone on your team, their department and what they can use."
        actions={showAdd && <AddPeopleMenu className="hidden sm:inline-flex" />}
      />
      <nav className="-mt-2 flex gap-1 overflow-x-auto border-b" aria-label="Users sections">
        {tabs.map((t) => (
          <Link
            key={t.id}
            href={t.id === "team" ? "/users" : `/users?tab=${t.id}`}
            className={cn(
              "inline-flex min-h-11 items-center px-3 text-sm whitespace-nowrap sm:min-h-9",
              tab === t.id
                ? "border-primary text-foreground border-b-2 font-medium"
                : "text-muted-foreground hover:text-foreground",
            )}
            aria-current={tab === t.id ? "page" : undefined}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      {externalRefused && (
        <p
          role="note"
          className="flex gap-2 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
        >
          <Lock className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span>
            Inviting partners needs “Invite partners”. <AskContacts contacts={partnerInviters} />
          </span>
        </p>
      )}

      {tab === "team" && (
        <TeamTab
          organisationId={orgId}
          viewerId={session.user.id}
          isAdmin={canPeople}
          actor={actor}
          params={{
            q: one(params.q),
            dept: one(params.dept),
            role: one(params.role),
            status: one(params.status),
            activity: one(params.activity),
            page: one(params.page),
          }}
        />
      )}
      {tab === "external" && (
        <ExternalTab
          organisationId={orgId}
          lastEvent={(await cookies()).get(LAST_EVENT_COOKIE)?.value ?? null}
          params={{
            event: one(params.event),
            invite: one(params.invite),
            role: one(params.role),
            scopeId: one(params.scopeId),
            edition: one(params.edition),
          }}
        />
      )}
      {tab === "departments" && (
        <DepartmentsPanel
          departments={await listDepartmentCards(db, orgId)}
          members={canDepartments ? await memberOptions(db, orgId) : []}
          canEdit={canDepartments}
          addTo={canPeople ? addTo : []}
        />
      )}

      {showAdd && (
        <div className="bg-background fixed inset-x-0 bottom-0 z-30 border-t p-3 sm:hidden">
          <AddPeopleMenu className="w-full" />
        </div>
      )}
    </Page>
  );
}
