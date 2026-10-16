import { notFound } from "next/navigation";
import { Mail } from "lucide-react";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import {
  assignableAbilities,
  assignableFeatures,
  assignableRoles,
  assignableSignoffDepartments,
  can,
  canGrantManager,
  isSuperAdmin,
  managerScope,
  type PersonCtx,
} from "@/lib/authz";
import { londonDateOfAccessEnd } from "@/lib/access";
import { standsEnabled } from "@/lib/config";
import { formatDate, roleLabel } from "@/lib/format";
import { departmentOptions, loadPerson } from "@/lib/users/queries";
import { getRemovalImpact, workableOwnedItems } from "@/lib/users/manage";
import { accessHistory } from "@/lib/users/history";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { abilityChoices, signoffPaused, visibleFeatures } from "@/lib/users/rules";
import { lastActiveText, managerBadgeText, personStatus } from "@/lib/users/list";
import { Page, PageHeader } from "@/components/page-header";
import { DepartmentChip } from "@/components/users/person-fields";
import { PersonEditor } from "@/components/users/person-editor";
import { RemoveUser } from "@/components/users/remove-user";
import { InviteStatus } from "@/components/users/invite-status";
import { AccountCard } from "@/components/users/account-card";
import { AccessHistory } from "@/components/users/access-history";
import { ManagerBadge, PersonStatusChip } from "@/components/users/person-status";

export const metadata = { title: "Person" };
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Why the viewer (who manages people) can't change this person, in their words. */
function outOfScopeReason(
  viewer: { departmentName: string | null; scope: "department" | "everyone" | null },
  person: { isSelf: boolean; role: string; managerScope: string | null },
): string {
  if (person.isSelf) return "You can't change your own access — ask a super admin.";
  if (person.role === "admin") return "Only super admins change a super admin's access.";
  if (person.managerScope) return "Only super admins change a manager's access.";
  if (viewer.scope === "department") {
    return viewer.departmentName
      ? `You manage the people in ${viewer.departmentName}, so you can't change this person's access.`
      : "You don't have a department yet, so there's nobody you can change — ask a super admin.";
  }
  return "You can't change this person's access.";
}

export default async function PersonPage({
  params,
  searchParams,
}: {
  params: Promise<{ userId: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireStaffSession();
  const { userId } = await params;
  const query = await searchParams;
  if (!UUID.test(userId)) notFound();
  const orgId = session.organisation.id;
  const actor = session.actor;
  const found = await loadPerson(db, orgId, userId, session.user.id);
  if (!found) notFound();
  const { person, departments: deptInfo } = found;
  const target: PersonCtx = {
    organisationId: orgId,
    userId: person.kind === "member" ? person.id : null,
    role: person.role,
    departmentId: person.departmentId,
    managerScope: person.managerScope,
  };
  // Super admins and managers in scope change people (person.edit); a super
  // admin also sees their own page as an editor (the self rules apply).
  const canEdit = can(actor, { type: "person.edit", person: target });
  const managesPeople = can(actor, { type: "people.manage" });
  // Invitations are for whoever may change them; everyone else only sees team members.
  if (person.kind === "invite" && !canEdit) notFound();
  const title = person.name || person.email;
  const now = new Date();
  const status = personStatus(person);
  const managerText = managerBadgeText(person, person.departmentName);
  const lastActive = person.kind === "member" ? lastActiveText(person.lastSeenAt, now) : null;
  const ownDeptName = actor.departmentId
    ? (deptInfo.find((d) => d.id === actor.departmentId)?.name ?? null)
    : null;

  const header = (
    <PageHeader
      title={
        <span className="inline-flex flex-wrap items-center gap-2">
          {title}
          {person.isSelf && (
            <span className="bg-primary/10 text-primary rounded px-1.5 py-0.5 text-xs font-medium">
              You
            </span>
          )}
        </span>
      }
      description={[person.jobTitle, person.email].filter(Boolean).join(" · ")}
      meta={
        <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <span>
            {person.departmentName ?? "No department"} · {roleLabel(person.role)}
          </span>
          {managerText && <ManagerBadge text={managerText} />}
          {(canEdit || managesPeople) && (
            <PersonStatusChip status={status} text={person.statusText} />
          )}
          {(canEdit || managesPeople) && lastActive && <span>Last active: {lastActive}</span>}
        </span>
      }
      back={{ href: "/users", label: "All users" }}
    />
  );

  if (!canEdit) {
    return (
      <Page width="narrow">
        {header}
        {managesPeople && (
          <p role="note" className="bg-muted/50 rounded-md px-3 py-2 text-sm">
            {outOfScopeReason({ departmentName: ownDeptName, scope: managerScope(actor) }, person)}
          </p>
        )}
        <section className="rounded-lg border p-4 sm:p-6">
          <dl className="grid gap-x-4 gap-y-3 text-sm sm:grid-cols-[10rem_1fr]">
            <dt className="text-muted-foreground">Email</dt>
            <dd>
              <a href={`mailto:${person.email}`} className="link inline-flex items-center gap-1.5">
                <Mail className="size-3.5" aria-hidden />
                {person.email}
              </a>
            </dd>
            <dt className="text-muted-foreground">Department</dt>
            <dd>
              {person.departmentName ? (
                <DepartmentChip name={person.departmentName} archived={person.departmentArchived} />
              ) : (
                "—"
              )}
            </dd>
            <dt className="text-muted-foreground">Role</dt>
            <dd>{roleLabel(person.role)}</dd>
            <dt className="text-muted-foreground">Signs off artwork for</dt>
            <dd className="flex flex-wrap gap-1">
              {person.signsOffFor.length === 0
                ? "—"
                : person.signsOffFor.map((s) => (
                    <DepartmentChip key={s.departmentId} name={s.name} main={s.isMain} />
                  ))}
            </dd>
          </dl>
        </section>
      </Page>
    );
  }

  const member = person.kind === "member";
  const showAll = query.history === "all";
  const [departments, impact, ownedItems, history] = await Promise.all([
    departmentOptions(db, orgId, {
      userId: member ? person.id : null,
      email: person.email,
    }),
    member && !person.isSelf ? getRemovalImpact(db, orgId, person.id) : Promise.resolve(null),
    member ? workableOwnedItems(db, orgId, person.id) : Promise.resolve([]),
    accessHistory(
      db,
      orgId,
      { userId: member ? person.id : null, email: person.email },
      { limit: showAll ? 200 : 21 },
    ),
  ]);
  const superAdmin = isSuperAdmin(actor);
  const giveable = assignableFeatures(actor);
  const visible = visibleFeatures(standsEnabled);
  const liveSigning = departments.filter((d) => d.signsOff && !d.isArchived).map((d) => d.id);
  const canDepartments = can(actor, { type: "departments.manage" });
  const canSuspend = can(actor, {
    type: "person.suspend",
    person: { ...target, lastActiveAdmin: person.isOnlyAdmin },
  });
  const canRemove = member && can(actor, { type: "person.remove", person: target });
  const accountLocked = person.isSelf
    ? "You can't change your own access — ask another super admin."
    : !canSuspend && person.isOnlyAdmin
      ? "There must always be at least one super admin with access, so their access can't be paused or ended."
      : !canSuspend
        ? "You can't change this person's access."
        : null;
  const handover = impact?.handover ?? { groups: [], candidates: [] };
  const suspendedLine =
    status === "suspended" && person.suspendedAt
      ? `Suspended since ${formatDate(person.suspendedAt)}${person.suspendedByName ? ` by ${person.suspendedByName}` : ""}`
      : status === "ended" && person.accessEndsAt
        ? `Access ended ${formatDate(person.accessEndsAt)}`
        : null;

  return (
    <Page width="narrow" className="pb-24 sm:pb-6">
      {header}
      {person.kind === "invite" && (
        <InviteStatus
          inviteId={person.id}
          name={person.name}
          email={person.email}
          statusText={person.statusText}
          expires={person.expiresAt ? formatDate(person.expiresAt) : null}
          expired={person.status === "expired"}
          emailOn={invitesCanBeEmailed()}
        />
      )}
      <PersonEditor
        // Fresh state whenever the saved person changes (e.g. after a save).
        key={`${person.id}:${person.departmentId}:${person.role}:${person.managerScope}:${JSON.stringify(person.features)}:${JSON.stringify(person.allSignoffs)}:${JSON.stringify(person.overrides)}`}
        kind={person.kind}
        id={person.id}
        email={person.email}
        isSelf={person.isSelf}
        isOnlyAdmin={person.isOnlyAdmin}
        departments={departments}
        visible={visible.filter(
          (f) =>
            giveable === "all" ||
            giveable.includes(f) ||
            person.features === null ||
            person.features.includes(f),
        )}
        owned={person.owned}
        // Managers give only what they have themselves (checked again on the server).
        access={{
          roles: superAdmin ? undefined : assignableRoles(actor),
          abilities: superAdmin ? undefined : assignableAbilities(actor),
          allSections: giveable === "all",
          canGrantManager: canGrantManager(actor),
          canNewDepartment: canDepartments,
          signoffDepartments: assignableSignoffDepartments(actor, liveSigning),
          canChooseMain: canDepartments,
          keepDepartment: managerScope(actor) === "department" && !superAdmin,
        }}
        work={{
          items: ownedItems.map((i) => ({ ref: i.ref, kind: i.kind, href: i.href })),
          signoffs: handover.groups.flatMap((g) =>
            g.steps.map((s) => ({ ref: s.ref, href: s.href, departmentId: s.departmentId })),
          ),
        }}
        initial={{
          fullName: person.name,
          jobTitle: person.jobTitle ?? "",
          department: person.departmentId ?? "",
          newDepartment: "",
          role: person.role,
          features: person.features,
          abilities: abilityChoices(person.overrides),
          signoffs: person.allSignoffs,
          paused: signoffPaused(person.overrides),
          managerScope: person.managerScope,
        }}
      />
      <AccountCard
        kind={person.kind}
        id={person.id}
        name={title}
        firstName={(person.name || person.email).trim().split(/\s+/)[0]}
        status={status}
        statusText={person.statusText}
        suspendedLine={suspendedLine}
        accessEndsOn={person.accessEndsAt ? londonDateOfAccessEnd(person.accessEndsAt) : null}
        lockedReason={accountLocked}
        handover={handover.groups}
        candidates={handover.candidates}
        currentUserId={session.user.id}
      >
        {impact && canRemove && (
          <RemoveUser
            userId={person.id}
            impact={impact}
            currentUserId={session.user.id}
            currentUserName={session.user.fullName || session.user.email}
          />
        )}
      </AccountCard>
      <AccessHistory
        entries={history.slice(0, showAll ? 200 : 20)}
        showAllHref={history.length > 20 ? `/users/${person.id}?history=all#history-h` : null}
        showingAll={showAll}
      />
    </Page>
  );
}
