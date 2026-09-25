import Link from "next/link";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import { boardTasks, type BoardScope } from "@/lib/queries/tasks";
import { StatusBadge } from "@/components/status-badge";
import { TaskForm } from "@/components/tasks/task-form";
import { TaskBoard } from "@/components/tasks/task-board";

export const metadata = { title: "My Work" };

export const dynamic = "force-dynamic";

const SCOPES: { id: BoardScope; label: string; adminOnly?: boolean }[] = [
  { id: "mine", label: "My tasks" },
  { id: "given", label: "Given to others" },
  { id: "everyone", label: "Everyone's", adminOnly: true },
];

export default async function MyWorkPage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string }>;
}) {
  const session = await requireStaffSession();
  const { view } = await searchParams;
  const isAdmin = session.actor.role === "admin";
  const scope: BoardScope =
    view === "given" || (view === "everyone" && isAdmin) ? (view as BoardScope) : "mine";
  const [rows, board, staff] = await Promise.all([
    pendingInstancesForUser(session),
    boardTasks({
      organisationId: session.organisation.id,
      userId: session.user.id,
      isAdmin,
      scope,
    }),
    db
      .select({ id: users.id, name: users.fullName, email: users.email })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organisationId, session.organisation.id))
      .orderBy(users.fullName),
  ]);
  const overdueCount = rows.filter((r) => r.isOverdue).length;
  const canAssign = can(session.actor, { type: "task.assign" });
  const overdueTasks = board.filter(
    (t) => t.status !== "done" && (t.overdue || t.overdueSubtasks > 0),
  ).length;
  const people = staff.map((s) => ({ id: s.id, name: s.name || s.email }));

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">My Work</h1>
        <p className="text-muted-foreground text-sm">
          Your jobs across all shows. Drag a card between columns (or use its menu); open it for
          subtasks, deadlines and files.
        </p>
      </div>

      <section className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          <nav className="flex gap-1" aria-label="Whose tasks">
            {SCOPES.filter((sc) => !sc.adminOnly || isAdmin).map((sc) => (
              <Link
                key={sc.id}
                href={sc.id === "mine" ? "/my-work" : `/my-work?view=${sc.id}`}
                aria-current={scope === sc.id ? "page" : undefined}
                className={`rounded-full border px-3 py-1 text-sm ${
                  scope === sc.id
                    ? "bg-foreground text-background border-foreground"
                    : "hover:bg-muted"
                }`}
              >
                {sc.label}
              </Link>
            ))}
          </nav>
          {overdueTasks > 0 && (
            <span className="rounded-full bg-red-600 px-3 py-1 text-sm font-semibold text-white">
              {overdueTasks} overdue — needs attention
            </span>
          )}
        </div>
        <TaskForm currentUserId={session.user.id} assignees={people} canAssign={canAssign} />
        <TaskBoard
          tasks={board}
          currentUserId={session.user.id}
          people={people}
          canAssign={canAssign}
        />
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
