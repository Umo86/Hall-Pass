import { notFound } from "next/navigation";
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
} from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { departmentOptions } from "@/lib/users/queries";
import { visibleFeatures } from "@/lib/users/rules";
import { templatesFor } from "@/lib/users/templates";
import { eventCardData } from "@/lib/users/event-options";
import { Page, PageHeader } from "@/components/page-header";
import { SegmentedLinks } from "@/components/ui/segmented";
import { AddUserForm, type AddAccess } from "@/components/users/add-user-form";
import { AddSeveral } from "@/components/users/add-several";

export const metadata = { title: "Add people" };
export const dynamic = "force-dynamic";

function one(v: string | string[] | undefined): string {
  return (Array.isArray(v) ? v[0] : v)?.slice(0, 200) ?? "";
}

export default async function AddUserPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireStaffSession();
  // Super admins and managers add people (each within their scope).
  if (!can(session.actor, { type: "people.manage" })) notFound();
  const params = await searchParams;
  const actor = session.actor;
  const superAdmin = isSuperAdmin(actor);
  const several = one(params.mode) === "several";
  const allDepartments = await departmentOptions(db, session.organisation.id);
  // A department manager adds people to their own department only.
  const deptManager = managerScope(actor) === "department";
  const own = deptManager ? allDepartments.find((d) => d.id === actor.departmentId) : undefined;
  const departments = deptManager ? (own ? [own] : []) : allDepartments;
  const giveable = assignableFeatures(actor);
  const visible = visibleFeatures(standsEnabled).filter(
    (f) => giveable === "all" || giveable.includes(f),
  );
  const liveSigning = allDepartments.filter((d) => d.signsOff && !d.isArchived).map((d) => d.id);
  const canDepartments = can(actor, { type: "departments.manage" });
  const access: AddAccess = {
    roles: superAdmin ? undefined : assignableRoles(actor),
    abilities: superAdmin ? undefined : assignableAbilities(actor),
    allSections: giveable === "all",
    canGrantManager: canGrantManager(actor),
    canNewDepartment: canDepartments,
    signoffDepartments: assignableSignoffDepartments(actor, liveSigning),
    canChooseMain: canDepartments,
    lockedDepartment: own ? { id: own.id, name: own.name } : null,
  };
  const templates = templatesFor(actor, { departmentId: actor.departmentId ?? null });
  // Users → Events: what they may give, and the event templates start from.
  const card = await eventCardData(session.organisation.id, actor);
  const events = {
    events: card.events,
    allowAll: card.allowAll,
    defaultEditionId: card.defaultEditionId,
  };
  const startDepartment = own?.id ?? one(params.department);
  const keep = startDepartment ? `&department=${startDepartment}` : "";

  return (
    <Page width="narrow">
      <PageHeader
        title={several ? "Add several people" : "Add one person"}
        description={
          several
            ? "Paste a list, choose what they all get, check it, then invite everyone who is ready."
            : "Who they are, which department they're in and what they can use. They get an invitation to set up their account."
        }
        back={{ href: "/users", label: "All users" }}
      />
      <SegmentedLinks
        className="w-fit"
        label="How many people"
        items={[
          {
            label: "One person",
            href: `/users/new${keep ? `?${keep.slice(1)}` : ""}`,
            active: !several,
          },
          { label: "Several people", href: `/users/new?mode=several${keep}`, active: several },
        ]}
      />
      {deptManager && !own ? (
        <p className="rounded-lg border p-4 text-sm">
          You manage your department&apos;s people, but you don&apos;t have a department yet — ask a
          super admin to give you one.
        </p>
      ) : several ? (
        <AddSeveral
          departments={departments}
          visible={visible}
          access={access}
          templates={templates}
          initialDepartmentId={startDepartment}
          events={events}
        />
      ) : (
        <AddUserForm
          departments={departments}
          visible={visible}
          access={access}
          templates={templates}
          events={events}
          initial={{
            departmentId: startDepartment,
            signsOff: one(params.signsOff) === "1",
            fullName: one(params.name),
            email: one(params.email),
          }}
        />
      )}
    </Page>
  );
}
