import { notFound } from "next/navigation";
import { Mail } from "lucide-react";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import {
  assignableAbilities,
  assignableRoles,
  can,
  FEATURE_LABELS,
  isSuperAdmin,
  type PersonCtx,
} from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { formatDate, roleLabel } from "@/lib/format";
import { departmentOptions, loadPerson } from "@/lib/users/queries";
import { getRemovalImpact } from "@/lib/users/manage";
import { invitesCanBeEmailed } from "@/lib/users/email";
import { abilityChoices, signoffPaused, visibleFeatures } from "@/lib/users/rules";
import { Page, PageHeader } from "@/components/page-header";
import { DepartmentChip } from "@/components/users/person-fields";
import { PersonEditor } from "@/components/users/person-editor";
import { RemoveUser } from "@/components/users/remove-user";
import { InviteStatus } from "@/components/users/invite-status";

export const metadata = { title: "User" };
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function PersonPage({ params }: { params: Promise<{ userId: string }> }) {
  const session = await requireStaffSession();
  const { userId } = await params;
  if (!UUID.test(userId)) notFound();
  const orgId = session.organisation.id;
  const found = await loadPerson(db, orgId, userId, session.user.id);
  if (!found) notFound();
  const { person } = found;
  const target: PersonCtx = {
    organisationId: orgId,
    userId: person.kind === "member" ? person.id : null,
    role: person.role,
    departmentId: person.departmentId,
    managerScope: person.managerScope,
  };
  // Super admins and managers in scope change people (person.edit); a super
  // admin also sees their own page as an editor (the self rules apply).
  const canEdit = can(session.actor, { type: "person.edit", person: target });
  // Invitations are for whoever may change them; everyone else only sees team members.
  if (person.kind === "invite" && !canEdit) notFound();
  const title = person.name || person.email;

  if (!canEdit) {
    return (
      <Page width="narrow">
        <PageHeader
          title={title}
          description={person.jobTitle ?? undefined}
          back={{ href: "/users", label: "All users" }}
        />
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

  const [departments, impact] = await Promise.all([
    departmentOptions(db, orgId, {
      userId: person.kind === "member" ? person.id : null,
      email: person.email,
    }),
    person.kind === "member" && !person.isSelf
      ? getRemovalImpact(db, orgId, person.id)
      : Promise.resolve(null),
  ]);
  const visible = visibleFeatures(standsEnabled);
  const sections =
    person.role === "admin" || person.features === null
      ? "every section"
      : person.features
          .filter((f) => visible.includes(f))
          .map((f) => FEATURE_LABELS[f])
          .join(", ") || "no sections";

  return (
    <Page width="narrow" className="pb-24 sm:pb-6">
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
        description={person.email}
        meta={
          person.kind === "member"
            ? `${person.departmentName ?? "No department"} · ${roleLabel(person.role)} · uses ${sections}`
            : `Invited · ${roleLabel(person.role)}`
        }
        back={{ href: "/users", label: "All users" }}
      />
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
        key={`${person.id}:${person.departmentId}:${person.role}:${JSON.stringify(person.features)}:${JSON.stringify(person.allSignoffs)}`}
        kind={person.kind}
        id={person.id}
        email={person.email}
        isSelf={person.isSelf}
        isOnlyAdmin={person.isOnlyAdmin}
        departments={departments}
        visible={visible}
        owned={person.owned}
        // Managers give only what they have themselves (checked again on the server).
        access={
          isSuperAdmin(session.actor)
            ? undefined
            : {
                roles: assignableRoles(session.actor),
                abilities: assignableAbilities(session.actor),
              }
        }
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
        }}
      />
      {impact && can(session.actor, { type: "person.remove", person: target }) && (
        <RemoveUser userId={person.id} impact={impact} currentUserId={session.user.id} />
      )}
      {person.isSelf && (
        <p className="text-muted-foreground text-sm">
          You can&apos;t remove yourself from the team — ask another super admin.
        </p>
      )}
    </Page>
  );
}
