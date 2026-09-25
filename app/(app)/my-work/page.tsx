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
import { formatDate } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";
import { TaskForm } from "@/components/tasks/task-form";
import { TaskList } from "@/components/tasks/task-list";

export const metadata = { title: "My Work" };

export const dynamic = "force-dynamic";

export default async function MyWorkPage() {
  const session = await requireStaffSession();
  const [rows, openTasks, completedTasks, givenTasks, staff] = await Promise.all([
    pendingInstancesForUser(session),
    openTasksForUser(session.user.id),
    recentlyCompletedForUser(session.user.id),
    tasksAssignedByUser(session.user.id),
    db
      .select({ id: users.id, name: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organisationId, session.organisation.id)),
  ]);
  const overdueCount = rows.filter((r) => r.isOverdue).length;
  const canAssign = can(session.actor, { type: "task.assign" });

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">My Work</h1>
        <p className="text-muted-foreground text-sm">
          Your to-do list across all shows. Artwork sign-offs are under Approvals.
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

      <section className="space-y-2">
        <h2 className="text-sm font-semibold">Sign-offs</h2>
        {rows.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            No artwork is waiting on you.{" "}
            <Link href="/approvals?tab=artwork" className="underline">
              See all artwork
            </Link>
          </p>
        ) : (
          <Link
            href="/approvals"
            className="flex flex-wrap items-center gap-2 rounded-lg border border-sky-300 bg-sky-50 p-3 text-sm hover:bg-sky-100 dark:border-sky-800 dark:bg-sky-950 dark:hover:bg-sky-900"
          >
            <StatusBadge status="pending" />
            <span className="font-medium">
              {rows.length} sign-off{rows.length === 1 ? "" : "s"} waiting on you
            </span>
            {overdueCount > 0 && (
              <span className="text-destructive font-medium">({overdueCount} overdue)</span>
            )}
            <span className="ml-auto underline">Open Approvals</span>
          </Link>
        )}
      </section>
    </div>
  );
}
