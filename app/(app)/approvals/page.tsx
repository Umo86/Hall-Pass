import Link from "next/link";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { memberships, users } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { pendingInstancesForUser } from "@/lib/queries/approvals";
import { openTasksForUser, recentlyCompletedForUser } from "@/lib/queries/tasks";
import { formatDateTime, statusLabel } from "@/lib/format";
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
  searchParams: Promise<{ overdue?: string }>;
}) {
  const session = await requireStaffSession();
  const { overdue } = await searchParams;
  const [rows, openTasks, completedTasks, staff] = await Promise.all([
    pendingInstancesForUser(),
    openTasksForUser(session.user.id),
    recentlyCompletedForUser(session.user.id),
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
      </section>

      <section className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-sm font-semibold">My sign-offs</h2>
        <span className="text-muted-foreground text-sm">
          {filtered.length} waiting on you
        </span>
        <div className="ml-auto flex gap-2 text-sm">
          <Link
            href="/approvals"
            className={!overdue ? "font-medium underline" : "text-muted-foreground hover:underline"}
          >
            All
          </Link>
          <Link
            href="/approvals?overdue=1"
            className={overdue ? "font-medium underline" : "text-muted-foreground hover:underline"}
          >
            Overdue only
          </Link>
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
              item?: { ref: string; name: string; currentArtworkVersionId: string | null };
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
              <li key={raw.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
                <StatusBadge status="pending" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm">
                    <Link href={href} className="font-medium hover:underline">
                      {ref}
                    </Link>{" "}
                    — {title}
                  </p>
                  <p className={`text-xs ${isOverdue ? "text-destructive font-medium" : "text-muted-foreground"}`}>
                    {raw.stepNameSnapshot}
                    {raw.assignedRole ? ` · ${statusLabel(raw.assignedRole)}` : ""}
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
