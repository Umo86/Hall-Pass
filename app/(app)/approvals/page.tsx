import Link from "next/link";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import {
  openTasksForUser,
  recentlyCompletedForUser,
  tasksAssignedByUser,
} from "@/lib/queries/tasks";
import { formatDate, formatDateTime, roleLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { TaskForm } from "@/components/tasks/task-form";
import { TaskList } from "@/components/tasks/task-list";
import { Scene } from "@/components/scene";
import { brandImage } from "@/lib/brand-images";

export const metadata = { title: "My Work" };
export const dynamic = "force-dynamic";

export default async function ApprovalsPage({
  searchParams,
}: {
  searchParams: Promise<{ overdue?: string; all?: string }>;
}) {
  const session = await requireStaffSession();
  const { overdue, all } = await searchParams;
  const isAdmin = session.actor.role === "admin";
  const showAll = isAdmin && all === "1";
  const [rows, openTasks, completedTasks, givenTasks, staff] = await Promise.all([
    pendingInstancesForUser(session, { all: showAll }),
    openTasksForUser(session.user.id),
    recentlyCompletedForUser(session.user.id),
    tasksAssignedByUser(session.user.id),
    db
      .select({ id: users.id, name: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organisationId, session.organisation.id)),
  ]);
  const filtered = overdue === "1" ? rows.filter((r) => r.isOverdue) : rows;
  const canAssign = can(session.actor, { type: "task.assign" });

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">My Work</h1>
        <p className="text-muted-foreground text-sm">
          Your to-do list and the sign-offs waiting on you, across all editions.
        </p>
      </div>

      <section className="space-y-3">
        <h2 className="text-sm font-semibold">
          My tasks{" "}
          <span className="text-muted-foreground font-normal">({openTasks.length} open)</span>
        </h2>
        <TaskForm
          currentUserId={session.user.id}
          assignees={staff.map((s) => ({ id: s.id, name: s.name || s.email }))}
          canAssign={canAssign}
        />
        <TaskList open={openTasks} completed={completedTasks} currentUserId={session.user.id} />
        {givenTasks.length > 0 && (
          <details className="rounded-lg border">
            <summary className="cursor-pointer px-3 py-2 text-sm font-medium select-none">
              Assigned by me ({givenTasks.length} open)
            </summary>
            <ul className="divide-y border-t text-sm">
              {givenTasks.map((t) => (
                <li key={t.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2">
                  <span className="min-w-0 flex-1">{t.title}</span>
                  <span className="text-muted-foreground text-xs">
                    to {t.assignedToName || "a colleague"}
                    {t.dueDate && (
                      <span className={t.overdue ? "text-destructive font-medium" : ""}>
                        {" "}
                        · due {formatDate(t.dueDate)}
                        {t.overdue ? " — overdue" : ""}
                      </span>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </details>
        )}
      </section>

      <section className="space-y-3">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-sm font-semibold">
            {showAll ? "All open sign-offs" : "My sign-offs"}
          </h2>
          <span className="text-muted-foreground text-sm">
            {filtered.length} {showAll ? "open" : "waiting on you"}
          </span>
          <div className="ml-auto flex flex-wrap gap-3 text-sm">
            <Link
              href={showAll ? "/approvals?all=1" : "/approvals"}
              className={
                !overdue ? "font-medium underline" : "text-muted-foreground hover:underline"
              }
            >
              Everything
            </Link>
            <Link
              href={showAll ? "/approvals?all=1&overdue=1" : "/approvals?overdue=1"}
              className={
                overdue ? "font-medium underline" : "text-muted-foreground hover:underline"
              }
            >
              Overdue only
            </Link>
            {isAdmin && (
              <Link
                href={showAll ? "/approvals" : "/approvals?all=1"}
                className="text-muted-foreground hover:underline"
              >
                {showAll ? "Just mine" : "All open sign-offs (admin)"}
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
              Nothing is waiting on you. Enjoy it while it lasts.
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
                edition: { code: string };
              };
              const ref = isSignage ? b.item!.ref : b.sub!.ref;
              const title = isSignage
                ? b.item!.name
                : `${b.exhibitor!.companyName} — stand ${b.exhibitor!.standNumber}`;
              const href = isSignage
                ? `/${b.edition.code}/signage/${ref}?tab=approvals`
                : `/${b.edition.code}/stands/${ref}`;
              return (
                <li
                  key={raw.id}
                  className="flex flex-wrap items-center gap-3 rounded-lg border p-3"
                >
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
                      {raw.stepNameSnapshot}
                      {raw.assignedRole ? ` · ${roleLabel(raw.assignedRole)}` : ""}
                      {raw.dueAt ? ` · due ${formatDateTime(raw.dueAt)}` : ""}
                      {isOverdue ? " — overdue" : ""}
                    </p>
                  </div>
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
    </div>
  );
}
