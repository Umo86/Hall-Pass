import Link from "next/link";
import { ArrowRight, ClipboardCheck, ListTodo, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatDate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { daysOverdue, isPast, overdueLabel } from "@/components/approvals/step-words";
import type { PendingSummaryRow } from "@/lib/queries/approvals";

const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

/**
 * The top of My Work: what is waiting on you right now — sign-offs (with the
 * three due soonest), your tasks, and for admins and Operations the team's
 * open sign-offs to chase.
 */
export function NeedsYou({
  signoffs,
  oldest,
  tasks,
  team,
}: {
  signoffs: { total: number; overdue: number };
  oldest: PendingSummaryRow[];
  tasks: { overdue: number; dueToday: number; dueThisWeek: number };
  team: { total: number; overdue: number } | null;
}) {
  const overdue = signoffs.overdue + tasks.overdue;
  return (
    <section aria-labelledby="needs-you" className="space-y-3">
      <div className="flex flex-wrap items-center gap-2">
        <h2 id="needs-you" className="text-sm font-semibold">
          Needs you
        </h2>
        {overdue > 0 && (
          <Link
            href={signoffs.overdue > 0 ? "/approvals?tab=mine&overdue=1" : "/my-work?due=overdue"}
            className="bg-destructive rounded-full px-3 py-0.5 text-xs font-semibold text-white hover:opacity-90"
          >
            {overdue} overdue:{" "}
            {[
              signoffs.overdue > 0 ? plural(signoffs.overdue, "sign-off") : null,
              tasks.overdue > 0 ? plural(tasks.overdue, "task") : null,
            ]
              .filter(Boolean)
              .join(", ")}
          </Link>
        )}
      </div>
      <div className={cn("grid gap-3 sm:grid-cols-2", team && "lg:grid-cols-3")}>
        <StatCard
          href={signoffs.total > 0 ? "/approvals?tab=mine" : "/approvals?tab=artwork"}
          icon={ClipboardCheck}
          title="Sign-offs"
          main={signoffs.total > 0 ? `${signoffs.total} waiting on you` : "Nothing waiting on you"}
          sub={
            signoffs.total === 0
              ? "See all artwork"
              : signoffs.overdue > 0
                ? `${signoffs.overdue} overdue`
                : "None overdue"
          }
          alert={signoffs.overdue > 0}
        />
        <StatCard
          href={tasks.overdue > 0 ? "/my-work?due=overdue" : "#tasks"}
          icon={ListTodo}
          title="Tasks"
          main={
            tasks.overdue > 0
              ? `${tasks.overdue} overdue`
              : tasks.dueToday > 0
                ? `${tasks.dueToday} due today`
                : "Nothing overdue"
          }
          sub={`${tasks.dueThisWeek} due in the next 7 days`}
          alert={tasks.overdue > 0}
        />
        {team && (
          <StatCard
            href={
              team.overdue > 0 ? "/approvals?tab=mine&all=1&overdue=1" : "/approvals?tab=mine&all=1"
            }
            icon={Users}
            title="Team"
            main={`${plural(team.total, "sign-off")} open`}
            sub={team.overdue > 0 ? `${team.overdue} overdue — chase them` : "None overdue"}
            alert={team.overdue > 0}
            action="Chase"
          />
        )}
      </div>
      {oldest.length > 0 && (
        <div className="space-y-1">
          <h3 className="text-muted-foreground text-xs font-medium">Due soonest</h3>
          <ol className="divide-y rounded-lg border">
            {oldest.map((r) => {
              const late = isPast(r.dueAt);
              const reviewable = r.stepKind === "approval" && r.entityType === "signage_item";
              return (
                <li key={r.instanceId} className="flex flex-wrap items-center gap-x-3 gap-y-2 p-3">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm">
                      <Link href={r.href} className="link font-medium">
                        {r.ref}
                      </Link>{" "}
                      — {r.name}
                    </p>
                    <p className="text-muted-foreground flex flex-wrap items-center gap-x-1.5 text-xs">
                      <span>{r.stepName}</span>
                      <span aria-hidden>·</span>
                      <span>{r.eventName}</span>
                      {r.dueAt && (
                        <>
                          <span aria-hidden>·</span>
                          <span className={cn(late && "text-destructive font-medium")}>
                            due {formatDate(r.dueAt)}
                          </span>
                        </>
                      )}
                      {late && r.dueAt && (
                        <span className="bg-destructive rounded-full px-2 text-[11px] font-semibold text-white">
                          {overdueLabel(daysOverdue(r.dueAt))}
                        </span>
                      )}
                    </p>
                  </div>
                  <Button asChild size="sm" variant={reviewable ? "default" : "outline"}>
                    <Link
                      href={reviewable ? `/approvals?tab=mine&review=${r.instanceId}` : r.href}
                      aria-label={`${reviewable ? "Review" : "Open"} ${r.ref}`}
                    >
                      {reviewable ? "Review" : "Open"}
                    </Link>
                  </Button>
                </li>
              );
            })}
          </ol>
          {signoffs.total > oldest.length && (
            <Link
              href="/approvals?tab=mine"
              className="link inline-flex items-center gap-1 text-sm"
            >
              See all {signoffs.total} sign-offs <ArrowRight className="size-3.5" aria-hidden />
            </Link>
          )}
        </div>
      )}
    </section>
  );
}

function StatCard({
  href,
  icon: Icon,
  title,
  main,
  sub,
  alert,
  action,
}: {
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  main: string;
  sub: string;
  alert?: boolean;
  action?: string;
}) {
  return (
    <Link
      href={href}
      className={cn(
        "hover:bg-muted/50 focus-visible:ring-ring flex items-start gap-3 rounded-lg border p-3 focus-visible:ring-2 focus-visible:outline-none",
        alert && "border-red-300 dark:border-red-900",
      )}
    >
      <span
        className={cn(
          "flex size-9 shrink-0 items-center justify-center rounded-full",
          alert
            ? "bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-300"
            : "bg-muted text-muted-foreground",
        )}
      >
        <Icon className="size-4" aria-hidden />
      </span>
      <span className="min-w-0 flex-1">
        <span className="text-muted-foreground block text-xs font-medium">{title}</span>
        <span className="block text-sm font-semibold">{main}</span>
        <span
          className={cn(
            "block text-xs",
            alert ? "text-destructive font-medium" : "text-muted-foreground",
          )}
        >
          {sub}
        </span>
      </span>
      {action && (
        <span className="text-muted-foreground inline-flex items-center gap-1 self-center text-sm">
          {action} <ArrowRight className="size-3.5" aria-hidden />
        </span>
      )}
    </Link>
  );
}
