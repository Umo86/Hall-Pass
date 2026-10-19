import Link from "next/link";
import { notFound } from "next/navigation";
import { and, eq, inArray, isNotNull, isNull, ne } from "drizzle-orm";
import { AlertTriangle, ChevronLeft, ChevronRight } from "lucide-react";
import { db } from "@/lib/db/client";
import {
  approvalInstances,
  editionDeadlines,
  signageItems,
  standSubmissions,
  exhibitors,
  tasks,
} from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can, hasFeature } from "@/lib/authz";
import { getEditionByCode } from "@/lib/queries/editions";
import { effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import {
  CALENDAR_FILTERS,
  CALENDAR_FILTER_LABELS,
  addMonths,
  chipMatchesFilter,
  chipTone,
  defaultMonth,
  monthGrid,
  monthLabel,
  orderByKind,
  overdueChips,
  parseCalendarFilter,
  parseCalendarView,
  parseMonthParam,
  sortChips,
  upcomingGroups,
  type CalendarChip,
} from "@/lib/calendar";
import { cn } from "@/lib/utils";
import { standsEnabled } from "@/lib/config";
import { formatDate, formatDayMonth } from "@/lib/format";
import { deadlineHref, itemPath } from "@/lib/edition-path";
import { todayInLondon } from "@/lib/today";
import { calendarFeedUrl } from "@/lib/feed-url";
import { stepIsMine } from "@/lib/domain/signage";
import { DEADLINE_FEATURE } from "@/components/dashboard/rules";
import { Page, PageHeader } from "@/components/page-header";
import { SectionUnavailable } from "@/components/section-unavailable";
import { SegmentedLinks } from "@/components/ui/segmented";
import { ChipView, TONE_CLASSES, type ViewChip } from "@/components/calendar/chip";
import { UpcomingList } from "@/components/calendar/upcoming-list";
import { AddToCalendar } from "@/components/calendar/add-to-calendar";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ editionCode: string }> }) {
  const { editionCode } = await params;
  return { title: `Calendar · ${editionCode.toUpperCase()}` };
}

const LEGEND: [ViewChip["tone"], string][] = [
  ["deadline", "Deadline"],
  ["overdue", "Deadline passed"],
  ["show", "Event dates"],
  ["delivery", "Delivery"],
  ["install", "Install"],
];

/** Work still to do before each item deadline (anything later has met it). */
const BEFORE_PRINT = [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "on_hold",
];
const SETTLED = ["installed", "snagged", "closed", "rejected"];

type Params = { m?: string; f?: string; view?: string };

/**
 * The event's calendar: every deadline in red (solid once passed), event
 * dates, deliveries and installs. Anything overdue is listed above, whatever
 * month is showing. Phones open on the next 30 days; `?view=month` shows
 * the month. `?f=` filters, `?m=2027-09` picks the month.
 */
export default async function CalendarPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<Params>;
}) {
  const session = await requireStaffSession();
  const actor = session.actor;
  const { editionCode } = await params;
  if (!hasFeature(actor, "calendar")) {
    return <SectionUnavailable feature="calendar" backHref={`/${editionCode}/dashboard`} />;
  }
  const sp = await searchParams;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session);
  if (!ed) notFound();
  const edition = ed.edition;
  const code = edition.code;
  const today = todayInLondon();
  const filter = parseCalendarFilter(sp.f);
  const view = parseCalendarView(sp.view);

  const [deadlineRows, items, stands, myTasks] = await Promise.all([
    db.select().from(editionDeadlines).where(eq(editionDeadlines.editionId, edition.id)),
    db
      .select({
        id: signageItems.id,
        ref: signageItems.ref,
        name: signageItems.name,
        kind: signageItems.kind,
        status: signageItems.status,
        ownerUserId: signageItems.ownerUserId,
        installDate: signageItems.installDate,
        deliveryDate: signageItems.deliveryDate,
        printDeadline: signageItems.printDeadline,
        artworkDueOverride: signageItems.artworkDueOverride,
        orderByDate: signageItems.orderByDate,
        sponsorId: signageItems.sponsorId,
        currentArtworkVersionId: signageItems.currentArtworkVersionId,
      })
      .from(signageItems)
      .where(and(eq(signageItems.editionId, edition.id), isNull(signageItems.deletedAt))),
    standsEnabled
      ? db
          .select({
            id: standSubmissions.id,
            ref: standSubmissions.ref,
            company: exhibitors.companyName,
          })
          .from(standSubmissions)
          .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
          .where(eq(standSubmissions.editionId, edition.id))
      : [],
    // Your own open jobs for this event that have a deadline.
    db
      .select({ title: tasks.title, dueDate: tasks.dueDate })
      .from(tasks)
      .where(
        and(
          eq(tasks.editionId, edition.id),
          eq(tasks.assignedToUserId, session.user.id),
          isNotNull(tasks.dueDate),
          ne(tasks.status, "done"),
        ),
      ),
  ]);

  const entityIds = [...items.map((i) => i.id), ...stands.map((s) => s.id)];
  const pending = entityIds.length
    ? await db
        .select()
        .from(approvalInstances)
        .where(
          and(
            eq(approvalInstances.status, "pending"),
            inArray(approvalInstances.entityId, entityIds),
          ),
        )
    : [];

  const chips: CalendarChip[] = [];
  const add = (date: string | null | undefined, chip: Omit<CalendarChip, "date">) => {
    if (date) chips.push({ ...chip, date });
  };

  // The event's own deadlines open the work they are about.
  const deadlineCtx = {
    buildStart: edition.buildStart,
    deadlines: deadlineRows.map((r) => ({
      key: r.key as DeadlineKey,
      daysBeforeBuildStart: r.daysBeforeBuildStart,
      overrideDate: r.overrideDate,
    })),
  };
  for (const row of deadlineRows) {
    const feature = DEADLINE_FEATURE[row.key];
    add(effectiveDeadline(deadlineCtx, row.key as DeadlineKey), {
      kind: "deadline",
      label: `Deadline: ${row.label}`,
      name: row.label,
      href: !feature || hasFeature(actor, feature) ? deadlineHref(code, row.key) : null,
      mine: false,
    });
  }
  const event = (date: string, label: string) =>
    add(date, { kind: "event", label, name: label, href: null, mine: false });
  event(edition.buildStart, "Build-up starts");
  event(edition.openStart, "Event opens");
  if (edition.openEnd !== edition.openStart) event(edition.openEnd, "Event closes");
  event(edition.breakdownEnd, "Breakdown ends");

  const itemById = new Map(items.map((i) => [i.id, i]));
  const standById = new Map(stands.map((s) => [s.id, s]));
  for (const item of items) {
    const href = itemPath(code, item);
    const mine = item.ownerUserId === actor.userId;
    const base = { name: item.name, href, mine };
    // A deadline shows only while its work is still to do, so anything
    // before today really is overdue.
    if (BEFORE_PRINT.includes(item.status)) {
      add(item.printDeadline, { ...base, kind: "print", label: `Print deadline: ${item.name}` });
    }
    if (
      (item.status === "draft" || item.status === "awaiting_artwork") &&
      !item.currentArtworkVersionId
    ) {
      add(item.artworkDueOverride, {
        ...base,
        kind: "artwork",
        label: `Artwork due: ${item.name}`,
      });
    }
    const orderBy = orderByKind(item);
    if (orderBy) {
      add(item.orderByDate, {
        ...base,
        kind: orderBy,
        label: `${orderBy === "sell" ? "Sell by" : "Order by"}: ${item.name}`,
      });
    }
    if (item.status === "rejected") continue;
    if (item.kind === "signage") {
      add(item.installDate, { ...base, kind: "install", label: `Install: ${item.name}` });
    }
    add(item.deliveryDate, { ...base, kind: "delivery", label: `Delivery: ${item.name}` });
  }

  for (const inst of pending) {
    // Print, delivery and install dates are on the calendar already.
    if (!inst.dueAt || inst.stepKindSnapshot === "confirmation") continue;
    const item = itemById.get(inst.entityId);
    const stand = standById.get(inst.entityId);
    if (item && (item.status === "on_hold" || SETTLED.includes(item.status))) continue;
    if (!item && !stand) continue;
    const target = item ? item.name : `${stand!.company} — stand ${stand!.ref}`;
    add(todayInLondon(inst.dueAt), {
      kind: "signoff",
      label: `Sign-off due: ${inst.stepNameSnapshot} — ${target}`,
      name: target,
      href: item ? `${itemPath(code, item)}?tab=artwork` : `/${code}/stands/${stand!.ref}`,
      mine:
        actor.kind === "staff" &&
        stepIsMine(
          {
            stepKind: inst.stepKindSnapshot,
            assignedRole: inst.assignedRole,
            assignedUserId: inst.assignedUserId,
            assignedDepartmentId: inst.assignedDepartmentId,
          },
          actor,
        ),
    });
  }
  for (const t of myTasks) {
    add(t.dueDate, {
      kind: "task",
      label: `Task due: ${t.title}`,
      name: t.title,
      href: "/my-work",
      mine: true,
    });
  }

  const shown: ViewChip[] = sortChips(chips.filter((c) => chipMatchesFilter(c, filter))).map(
    (c) => ({ ...c, tone: chipTone(c, today) }),
  );
  const byDay = new Map<string, ViewChip[]>();
  for (const c of shown) byDay.set(c.date, [...(byDay.get(c.date) ?? []), c]);
  const overdue = overdueChips(shown, today);
  const upcoming = upcomingGroups(shown, today, 30);

  const todayDate = new Date(`${today}T12:00:00Z`);
  const { year, month } = sp.m
    ? parseMonthParam(sp.m, todayDate)
    : defaultMonth(
        shown.filter((c) => c.kind !== "event").map((c) => c.date),
        today,
      );
  const weeks = monthGrid(year, month);
  const monthPrefix = `${year}-${String(month).padStart(2, "0")}`;
  const agenda = [...byDay.entries()]
    .filter(([iso]) => iso.startsWith(monthPrefix))
    .sort((a, b) => a[0].localeCompare(b[0]));
  const fmt = (ym: { year: number; month: number }) =>
    `${ym.year}-${String(ym.month).padStart(2, "0")}`;
  const buildMonth = edition.buildStart.slice(0, 7);

  const href = (next: Partial<Params>) => {
    const q = new URLSearchParams();
    const merged = {
      m: sp.m,
      f: filter === "all" ? undefined : filter,
      view: view ?? undefined,
      ...next,
    };
    for (const [k, v] of Object.entries(merged)) if (v) q.set(k, v);
    const s = q.toString();
    return s ? `?${s}` : `/${code}/calendar`;
  };
  const monthNav = (
    <div className="flex flex-wrap items-center gap-2 text-sm">
      <Link
        href={href({ m: fmt(addMonths(year, month, -1)), view: view ?? undefined })}
        className="hover:bg-accent focus-visible:ring-ring inline-flex size-9 items-center justify-center rounded-md border focus-visible:ring-2 focus-visible:outline-none"
        aria-label="Previous month"
      >
        <ChevronLeft className="size-4" aria-hidden />
      </Link>
      <span className="min-w-36 text-center font-medium" aria-live="polite">
        {monthLabel(year, month)}
      </span>
      <Link
        href={href({ m: fmt(addMonths(year, month, 1)), view: view ?? undefined })}
        className="hover:bg-accent focus-visible:ring-ring inline-flex size-9 items-center justify-center rounded-md border focus-visible:ring-2 focus-visible:outline-none"
        aria-label="Next month"
      >
        <ChevronRight className="size-4" aria-hidden />
      </Link>
      {monthPrefix !== today.slice(0, 7) && (
        <Link href={href({ m: today.slice(0, 7) })} className="link ml-1">
          This month
        </Link>
      )}
      {monthPrefix !== buildMonth && (
        <Link href={href({ m: buildMonth })} className="link ml-1">
          Jump to build-up
        </Link>
      )}
    </div>
  );
  // Phones open on Upcoming, wider screens on the month, unless ?view= says.
  const viewToggle = (active: "upcoming" | "month", className: string) => (
    <SegmentedLinks
      label="View"
      className={className}
      items={[
        { label: "Upcoming", href: href({ view: "upcoming" }), active: active === "upcoming" },
        { label: "Month", href: href({ view: "month" }), active: active === "month" },
      ]}
    />
  );
  const monthHref = href({ view: "month" });

  const grid = (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[760px] table-fixed border-collapse">
        <caption className="sr-only">{monthLabel(year, month)}</caption>
        <thead>
          <tr>
            {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((d) => (
              <th
                key={d}
                scope="col"
                className="text-muted-foreground border p-1.5 text-left text-xs font-medium"
              >
                {d}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {weeks.map((week, wi) => (
            <tr key={wi}>
              {week.map((cell) => {
                const day = byDay.get(cell.iso) ?? [];
                return (
                  <td
                    key={cell.iso}
                    className={cn(
                      "h-24 border p-1 align-top",
                      !cell.inMonth && "bg-muted/30",
                      cell.iso === today && "ring-primary ring-2 ring-inset",
                    )}
                  >
                    <p
                      className={cn(
                        "mb-1 text-xs",
                        cell.inMonth ? "font-medium" : "text-muted-foreground",
                      )}
                    >
                      {Number(cell.iso.slice(8))}
                    </p>
                    <div className="flex flex-col gap-0.5">
                      {day.slice(0, 4).map((chip, i) => (
                        <ChipView key={i} chip={chip} />
                      ))}
                      {day.length > 4 && (
                        <details className="text-[11px]">
                          <summary className="text-muted-foreground cursor-pointer select-none">
                            +{day.length - 4} more
                          </summary>
                          <div className="mt-0.5 flex flex-col gap-0.5">
                            {day.slice(4).map((chip, i) => (
                              <ChipView key={i} chip={chip} />
                            ))}
                          </div>
                        </details>
                      )}
                    </div>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );

  const monthAgenda = (
    <ol className="space-y-3">
      {agenda.length === 0 ? (
        <li className="text-muted-foreground rounded-lg border border-dashed p-4 text-sm">
          Nothing on in {monthLabel(year, month)}.
        </li>
      ) : (
        agenda.map(([iso, day]) => (
          <li
            key={iso}
            className={cn("rounded-lg border p-3", iso === today && "ring-primary ring-2")}
          >
            <h3 className="mb-1.5 text-sm font-medium">{formatDate(iso)}</h3>
            <div className="flex flex-col gap-1">
              {day.map((chip, i) => (
                <ChipView key={i} chip={chip} large />
              ))}
            </div>
          </li>
        ))
      )}
    </ol>
  );

  return (
    <Page width="full">
      <PageHeader
        title="Calendar"
        description={`${edition.name}: every deadline in red, with event dates, deliveries and installs.`}
        actions={
          <AddToCalendar
            feedUrl={calendarFeedUrl(session.user.id)}
            canSetUp={can(actor, { type: "system.manage" })}
          />
        }
      />

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <SegmentedLinks
          label="Show on the calendar"
          items={CALENDAR_FILTERS.map((f) => ({
            label: CALENDAR_FILTER_LABELS[f],
            href: href({ f: f === "all" ? undefined : f }),
            active: filter === f,
          }))}
        />
        {view === null ? (
          <>
            {viewToggle("upcoming", "sm:hidden")}
            {viewToggle("month", "hidden sm:inline-flex")}
          </>
        ) : (
          viewToggle(view, "")
        )}
      </div>

      {overdue.length > 0 && (
        <details
          open
          className="border-destructive/40 bg-destructive/5 group rounded-lg border"
          aria-label={`Overdue (${overdue.length})`}
        >
          <summary className="text-destructive flex cursor-pointer list-none items-center gap-2 px-3 py-2 text-sm font-semibold select-none [&::-webkit-details-marker]:hidden">
            <AlertTriangle className="size-4" aria-hidden />
            Overdue ({overdue.length})
            <span className="text-muted-foreground hidden font-normal sm:inline">
              — passed and still to do, from any month
            </span>
            <ChevronRight
              className="ml-auto size-4 transition-transform group-open:rotate-90"
              aria-hidden
            />
          </summary>
          <ul className="grid max-h-72 gap-1 overflow-y-auto px-3 pb-3 sm:grid-cols-2 xl:grid-cols-3">
            {overdue.map((chip, i) => (
              <li key={`${chip.label}-${i}`} className="flex min-w-0 items-center gap-2">
                <span className="text-muted-foreground w-14 shrink-0 text-xs tabular-nums">
                  {formatDayMonth(`${chip.date}T12:00:00Z`)}
                </span>
                <span className="min-w-0 flex-1">
                  <ChipView chip={chip} />
                </span>
              </li>
            ))}
          </ul>
        </details>
      )}

      {view !== "upcoming" && (
        <div
          className={cn(
            "flex flex-wrap items-center justify-between gap-3",
            view === null && "hidden sm:flex",
          )}
        >
          {monthNav}
          <Legend />
        </div>
      )}
      {view === "upcoming" && <Legend />}

      {/* Phones: the next 30 days, or the month as a list. */}
      <div className="sm:hidden">
        {view === "month" ? monthAgenda : <UpcomingList groups={upcoming} monthHref={monthHref} />}
      </div>
      {/* Wider screens: the month grid, or the next 30 days. */}
      <div className="hidden sm:block">
        {view === "upcoming" ? <UpcomingList groups={upcoming} monthHref={monthHref} /> : grid}
      </div>
    </Page>
  );
}

function Legend() {
  return (
    <div className="text-muted-foreground flex flex-wrap gap-3 text-xs" aria-label="Key">
      {LEGEND.map(([tone, label]) => (
        <span key={tone} className="flex items-center gap-1.5">
          <span className={cn("size-3 rounded", TONE_CLASSES[tone])} /> {label}
        </span>
      ))}
    </div>
  );
}
