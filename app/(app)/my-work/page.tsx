import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { X } from "lucide-react";
import { db } from "@/lib/db/client";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, isSuperAdmin } from "@/lib/authz";
import { loadTeam, peopleFor, personOptions } from "@/lib/people";
import {
  countPendingForUser,
  oldestPendingForUser,
  teamPendingSummary,
} from "@/lib/queries/approvals";
import { boardTasks, myTaskSummary, type BoardScope } from "@/lib/queries/tasks";
import { LAST_EVENT_COOKIE, listEditions, pickDefaultEdition } from "@/lib/queries/editions";
import { todayInLondon } from "@/lib/today";
import { TaskForm } from "@/components/tasks/task-form";
import { TaskBoard } from "@/components/tasks/task-board";
import { EventFilter } from "@/components/tasks/event-filter";
import { Page, PageHeader } from "@/components/page-header";
import { SegmentedLinks } from "@/components/ui/segmented";
import { countActiveEvents, setupContacts } from "@/lib/queries/setup";
import { NoEventsYet } from "@/components/setup/no-events-state";
import { NeedsYou } from "./needs-you";

export const metadata = { title: "My Work" };

export const dynamic = "force-dynamic";

const SCOPES: { id: BoardScope; label: string; adminOnly?: boolean; assignersOnly?: boolean }[] = [
  { id: "mine", label: "My tasks" },
  { id: "given", label: "Given to others", assignersOnly: true },
  { id: "everyone", label: "Everyone's", adminOnly: true },
];

export default async function MyWorkPage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string; event?: string; due?: string }>;
}) {
  const session = await requireStaffSession();
  // A brand-new organisation starts by creating its first event.
  const activeEvents = await countActiveEvents(session.organisation.id);
  if (activeEvents === 0 && can(session.actor, { type: "events.create" })) redirect("/start");
  const contacts = activeEvents === 0 ? await setupContacts(session.organisation.id) : [];
  const { view, event, due } = await searchParams;
  // Everyone's tasks are for super admins.
  const isAdmin = isSuperAdmin(session.actor);
  const canAssign = can(session.actor, { type: "task.assign" });
  const scope: BoardScope =
    (view === "given" && canAssign) || (view === "everyone" && isAdmin)
      ? (view as BoardScope)
      : "mine";
  const orgId = session.organisation.id;
  const today = todayInLondon();

  // Events for the task form and the filter; the form starts on the event
  // last opened (or the next one coming up).
  const editions = await listEditions(orgId);
  const live = editions.filter((e) => e.edition.status !== "archived");
  const filterEvent = live.find((e) => e.edition.code === event?.toUpperCase()) ?? null;
  const cookieStore = await cookies();
  const defaultCode = pickDefaultEdition(
    live.map((e) => ({
      code: e.edition.code,
      status: e.edition.status,
      openStart: e.edition.openStart,
      openEnd: e.edition.openEnd,
    })),
    { lastCode: cookieStore.get(LAST_EVENT_COOKIE)?.value ?? null, today },
  );
  const defaultEvent = filterEvent ?? live.find((e) => e.edition.code === defaultCode) ?? null;
  const canChase = can(session.actor, { type: "approval.chase" });

  const [signoffs, oldest, teamSignoffs, taskSummary, board, team] = await Promise.all([
    countPendingForUser(session),
    oldestPendingForUser(session, 3),
    canChase ? teamPendingSummary(orgId) : Promise.resolve(null),
    myTaskSummary({ organisationId: orgId, userId: session.user.id, today }),
    boardTasks({
      organisationId: orgId,
      userId: session.user.id,
      isAdmin,
      scope,
      editionId: filterEvent?.edition.id ?? null,
    }),
    loadTeam(db, orgId),
  ]);
  // Tasks go to people with access (lib/people.ts); someone suspended still
  // shows, labelled, on the tasks they already have, so opening one never
  // reassigns it by accident.
  const assignees = personOptions(team, { type: "task" }, { organisationId: orgId });
  const people = await peopleFor(
    db,
    orgId,
    { type: "task" },
    {
      include: board.map((t) => t.assignedToUserId),
      team,
    },
  );
  const myDepartmentId =
    session.actor.kind === "staff" ? (session.actor.departmentId ?? null) : null;
  const overdueOnly = due === "overdue";
  const tasks = overdueOnly
    ? board.filter((t) => t.status !== "done" && (t.overdue || t.overdueSubtasks > 0))
    : board;
  const keep = { view: scope === "mine" ? undefined : scope, due: overdueOnly ? due : undefined };
  const scopes = SCOPES.filter(
    (sc) => (!sc.adminOnly || isAdmin) && (!sc.assignersOnly || canAssign),
  );
  const hrefFor = (params: Record<string, string | undefined>) => {
    const q = new URLSearchParams();
    for (const [k, v] of Object.entries(params)) if (v) q.set(k, v);
    const s = q.toString();
    return s ? `/my-work?${s}` : "/my-work";
  };

  return (
    <Page width="full">
      <PageHeader
        title="My Work"
        description="Everything you need to do across your events: sign-offs first, then your tasks. Tap a task to add subtasks, a deadline and files."
      />

      {activeEvents === 0 && (
        <NoEventsYet brandName={session.organisation.brandName} contacts={contacts} />
      )}

      <NeedsYou
        signoffs={signoffs}
        oldest={oldest}
        tasks={taskSummary}
        team={teamSignoffs && teamSignoffs.total > 0 ? teamSignoffs : null}
      />

      <section id="tasks" className="scroll-mt-20 space-y-3" aria-labelledby="tasks-heading">
        <h2 id="tasks-heading" className="text-sm font-semibold">
          Tasks
        </h2>
        <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
          {scopes.length > 1 && (
            <SegmentedLinks
              label="Whose tasks"
              items={scopes.map((sc) => ({
                label: sc.label,
                href: hrefFor({
                  view: sc.id === "mine" ? undefined : sc.id,
                  event: filterEvent?.edition.code,
                }),
                active: scope === sc.id,
              }))}
            />
          )}
          <EventFilter
            events={live.map((e) => ({ code: e.edition.code, name: e.edition.name }))}
            value={filterEvent?.edition.code ?? null}
            keep={keep}
          />
          {overdueOnly && (
            <Link
              href={hrefFor({ ...keep, due: undefined, event: filterEvent?.edition.code })}
              className="bg-muted inline-flex w-fit items-center gap-1 rounded-full px-3 py-1 text-sm"
            >
              Overdue only <X className="size-3.5" aria-label="Show all tasks" />
            </Link>
          )}
        </div>
        <TaskForm
          currentUserId={session.user.id}
          currentDepartmentId={myDepartmentId}
          assignees={assignees}
          canAssign={canAssign}
          events={live.map((e) => ({
            id: e.edition.id,
            code: e.edition.code,
            name: e.edition.name,
          }))}
          defaultEventId={defaultEvent?.edition.id ?? null}
        />
        <TaskBoard
          tasks={tasks}
          currentUserId={session.user.id}
          people={people}
          canAssign={canAssign}
          emptyMessage={
            overdueOnly
              ? "Nothing is overdue. Well done."
              : filterEvent
                ? `No tasks for ${filterEvent.edition.name} yet — add one above.`
                : scope === "given"
                  ? "You haven't given anyone a task yet. Choose someone under Assign to when you add one."
                  : undefined
          }
        />
      </section>
    </Page>
  );
}
