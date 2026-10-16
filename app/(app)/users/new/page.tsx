import { notFound } from "next/navigation";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import {
  assignableAbilities,
  assignableFeatures,
  assignableRoles,
  can,
  isSuperAdmin,
  managerScope,
} from "@/lib/authz";
import { standsEnabled } from "@/lib/config";
import { departmentOptions } from "@/lib/users/queries";
import { visibleFeatures } from "@/lib/users/rules";
import { Page, PageHeader } from "@/components/page-header";
import { AddUserForm } from "@/components/users/add-user-form";

export const metadata = { title: "Add user" };
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
  const allDepartments = await departmentOptions(db, session.organisation.id);
  // A department manager adds people to their own department only.
  const departments =
    managerScope(actor) === "department"
      ? allDepartments.filter((d) => d.id === actor.departmentId)
      : allDepartments;
  const giveable = assignableFeatures(actor);
  const visible = visibleFeatures(standsEnabled).filter(
    (f) => giveable === "all" || giveable.includes(f),
  );

  return (
    <Page width="narrow">
      <PageHeader
        title="Add user"
        description="Who they are, which department they're in and what they can use. They get an invitation to set up their account."
        back={{ href: "/users", label: "All users" }}
      />
      <AddUserForm
        departments={departments}
        visible={visible}
        access={
          superAdmin
            ? undefined
            : { roles: assignableRoles(actor), abilities: assignableAbilities(actor) }
        }
        initial={{
          departmentId:
            managerScope(actor) === "department"
              ? (actor.departmentId ?? "")
              : one(params.department),
          signsOff: one(params.signsOff) === "1",
          fullName: one(params.name),
          email: one(params.email),
        }}
      />
    </Page>
  );
}
