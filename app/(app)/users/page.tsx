import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Lock, UserPlus } from "lucide-react";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { listDepartmentCards, memberOptions } from "@/lib/users/queries";
import { setupContacts } from "@/lib/queries/setup";
import { AskContacts } from "@/components/setup/no-events-state";
import { Page, PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { TeamTab } from "@/components/users/team-tab";
import { ExternalTab } from "@/components/users/external-tab";
import { DepartmentsPanel } from "@/components/users/departments-panel";
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
  const isAdmin = can(session.actor, { type: "users.manage" });
  const params = await searchParams;
  const raw = one(params.tab);
  const tab: Tab =
    raw === "external" && isAdmin ? "external" : raw === "departments" ? "departments" : "team";
  const tabs: { id: Tab; label: string }[] = [
    { id: "team", label: "Team" },
    ...(isAdmin ? [{ id: "external" as const, label: "External" }] : []),
    { id: "departments", label: "Departments" },
  ];
  const orgId = session.organisation.id;
  // A link to External (e.g. "invite this supplier" from a notification)
  // opened by someone who isn't an admin: Team, saying why. Its ?role= and
  // ?invite= are dropped so they aren't read as Team filters.
  if (raw === "external" && !isAdmin) redirect("/users?from=external");
  const externalRefused = !isAdmin && one(params.from) === "external";
  const admins = externalRefused
    ? (await setupContacts(orgId)).filter((c) => c.role === "admin")
    : [];
  // Adding a team member is the main action, except on External (inviting outsiders).
  const showAdd = isAdmin && tab !== "external";

  return (
    <Page width="full" className={cn("max-w-7xl", showAdd && "pb-24 sm:pb-6")}>
      <PageHeader
        title="Users"
        description="Everyone on your team, their department and what they can use."
        actions={
          showAdd && (
            <Button asChild className="hidden sm:inline-flex">
              <Link href="/users/new">
                <UserPlus aria-hidden />
                Add user
              </Link>
            </Button>
          )
        }
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
            Only admins can invite partners. <AskContacts contacts={admins} />
          </span>
        </p>
      )}

      {tab === "team" && (
        <TeamTab
          organisationId={orgId}
          viewerId={session.user.id}
          isAdmin={isAdmin}
          params={{
            q: one(params.q),
            dept: one(params.dept),
            role: one(params.role),
            status:
              one(params.status) === "active" || one(params.status) === "invited"
                ? (one(params.status) as "active" | "invited")
                : undefined,
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
          members={isAdmin ? await memberOptions(db, orgId) : []}
          canEdit={isAdmin}
        />
      )}

      {showAdd && (
        <div className="bg-background fixed inset-x-0 bottom-0 z-30 border-t p-3 sm:hidden">
          <Button asChild className="h-11 w-full">
            <Link href="/users/new">
              <UserPlus aria-hidden />
              Add user
            </Link>
          </Button>
        </div>
      )}
    </Page>
  );
}
