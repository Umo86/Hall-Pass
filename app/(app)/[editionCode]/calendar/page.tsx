import Link from "next/link";
import { notFound } from "next/navigation";
import { and, eq, inArray, isNotNull, isNull } from "drizzle-orm";
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
import { getEditionByCode } from "@/lib/queries/editions";
import { effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import { addMonths, monthGrid, monthLabel, parseMonthParam } from "@/lib/calendar";
import { cn } from "@/lib/utils";
import { standsEnabled } from "@/lib/config";
import { formatDate } from "@/lib/format";

export const metadata = { title: "Calendar" };
export const dynamic = "force-dynamic";

type Tone = "deadline" | "overdue" | "show" | "delivery" | "install";

type Chip = { label: string; href: string | null; tone: Tone };

/** Every deadline is red (solid once it has passed); the rest by type. */
const TONE_CLASSES: Record<Tone, string> = {
  deadline: "bg-red-600 text-white font-medium",
  overdue: "bg-red-900 text-white font-semibold",
  show: "bg-violet-100 text-violet-900 dark:bg-violet-950 dark:text-violet-200",
  delivery: "bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200",
  install: "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200",
};

const LEGEND: [Tone, string][] = [
  ["deadline", "Deadline"],
  ["overdue", "Deadline passed"],
  ["show", "Show dates"],
  ["delivery", "Delivery"],
  ["install", "Install"],
];

export default async function CalendarPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ m?: string }>;
}) {
  const session = await requireStaffSession();
  const { editionCode } = await params;
  const { m } = await searchParams;
  const ed = await getEditionByCode(editionCode.toUpperCase(), session.organisation.id);
  if (!ed) notFound();
  const edition = ed.edition;

  const today = new Date();
  const todayIso = today.toISOString().slice(0, 10);
  const { year, month } = parseMonthParam(m, today);

  const [deadlineRows, items, stands, myTasks] = await Promise.all([
    db.select().from(editionDeadlines).where(eq(editionDeadlines.editionId, edition.id)),
    db
      .select({
        ref: signageItems.ref,
        name: signageItems.name,
        id: signageItems.id,
        kind: signageItems.kind,
        installDate: signageItems.installDate,
        deliveryDate: signageItems.deliveryDate,
        printDeadline: signageItems.printDeadline,
        artworkDueOverride: signageItems.artworkDueOverride,
        orderByDate: signageItems.orderByDate,
        sponsorId: signageItems.sponsorId,
        status: signageItems.status,
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
    // Your own jobs for this show that have a deadline.
    db
      .select({ title: tasks.title, dueDate: tasks.dueDate, status: tasks.status })
      .from(tasks)
      .where(
        and(
          eq(tasks.editionId, edition.id),
          eq(tasks.assignedToUserId, session.user.id),
          isNotNull(tasks.dueDate),
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

  const itemById = new Map(items.map((i) => [i.id, i]));
  const standById = new Map(stands.map((s) => [s.id, s]));
  const chips = new Map<string, Chip[]>();
  const add = (date: string | null | undefined, chip: Chip) => {
    if (!date) return;
    // A deadline that has passed turns solid red.
    if (chip.tone === "deadline" && date < todayIso) {
      chip = { ...chip, tone: "overdue", label: `⚠ ${chip.label}` };
    }
    const list = chips.get(date) ?? [];
    list.push(chip);
    chips.set(date, list);
  };

  const deadlineCtx = {
    buildStart: edition.buildStart,
    deadlines: deadlineRows.map((r) => ({
      key: r.key as DeadlineKey,
      daysBeforeBuildStart: r.daysBeforeBuildStart,
      overrideDate: r.overrideDate,
    })),
  };
  for (const row of deadlineRows) {
    add(effectiveDeadline(deadlineCtx, row.key as DeadlineKey), {
      label: `Deadline: ${row.label}`,
      href: `/${editionCode}/dashboard`,
      tone: "deadline",
    });
  }
  add(edition.buildStart, { label: "Build-up starts", href: null, tone: "show" });
  add(edition.openStart, { label: "Show opens", href: null, tone: "show" });
  if (edition.openEnd !== edition.openStart) {
    add(edition.openEnd, { label: "Show closes", href: null, tone: "show" });
  }
  add(edition.breakdownEnd, { label: "Breakdown ends", href: null, tone: "show" });

  const itemHref = (item: { ref: string; kind: string }) =>
    `/${editionCode}/${item.kind === "sponsorship_item" ? "sponsorship" : "signage"}/${item.ref}`;
  const settled = ["installed", "snagged", "closed"];
  for (const item of items) {
    const open = !settled.includes(item.status);
    if (open) {
      add(item.printDeadline, {
        label: `Print deadline: ${item.name}`,
        href: itemHref(item),
        tone: "deadline",
      });
      add(item.artworkDueOverride, {
        label: `Artwork due: ${item.name}`,
        href: itemHref(item),
        tone: "deadline",
      });
      add(item.orderByDate, {
        label: `${item.sponsorId ? "Order by" : "Sell & order by"}: ${item.name}`,
        href: itemHref(item),
        tone: "deadline",
      });
    }
    if (item.kind === "signage") {
      add(item.installDate, {
        label: `Install: ${item.name}`,
        href: itemHref(item),
        tone: "install",
      });
    }
    add(item.deliveryDate, {
      label: `Delivery: ${item.name}`,
      href: itemHref(item),
      tone: "delivery",
    });
  }

  for (const inst of pending) {
    if (!inst.dueAt) continue;
    const date = inst.dueAt.toISOString().slice(0, 10);
    const item = itemById.get(inst.entityId);
    const stand = standById.get(inst.entityId);
    if (!item && !stand) continue;
    const target = item ? item.name : stand!.company;
    add(date, {
      label: `Sign-off due: ${inst.stepNameSnapshot} — ${target}`,
      href: item ? `${itemHref(item)}?tab=artwork` : `/${editionCode}/stands/${stand!.ref}`,
      tone: "deadline",
    });
  }
  for (const t of myTasks) {
    if (t.status === "done") continue;
    add(t.dueDate, { label: `Task due: ${t.title}`, href: "/my-work", tone: "deadline" });
  }
  // Deadlines first on each day.
  const rank: Record<Tone, number> = { overdue: 0, deadline: 1, show: 2, delivery: 3, install: 4 };
  for (const list of chips.values()) list.sort((a, b) => rank[a.tone] - rank[b.tone]);

  const weeks = monthGrid(year, month);
  const monthPrefix = `${year}-${String(month).padStart(2, "0")}`;
  const agenda = [...chips.entries()]
    .filter(([iso]) => iso.startsWith(monthPrefix))
    .sort((a, b) => a[0].localeCompare(b[0]));
  const prev = addMonths(year, month, -1);
  const next = addMonths(year, month, 1);
  const fmt = (ym: { year: number; month: number }) =>
    `${ym.year}-${String(ym.month).padStart(2, "0")}`;
  const buildMonth = parseMonthParam(edition.buildStart.slice(0, 7), today);

  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Calendar</h1>
          <p className="text-muted-foreground text-sm">
            {edition.name} — every deadline in red, plus show dates, deliveries and installs.
          </p>
        </div>
        <div className="flex items-center gap-2 text-sm">
          <Link
            href={`?m=${fmt(prev)}`}
            className="rounded-md border px-2.5 py-1.5 hover:bg-accent"
            aria-label="Previous month"
          >
            ←
          </Link>
          <span className="min-w-36 text-center font-medium">{monthLabel(year, month)}</span>
          <Link
            href={`?m=${fmt(next)}`}
            className="rounded-md border px-2.5 py-1.5 hover:bg-accent"
            aria-label="Next month"
          >
            →
          </Link>
          <Link
            href={`?m=${fmt(buildMonth)}`}
            className="text-muted-foreground ml-2 hover:underline"
          >
            Jump to build-up
          </Link>
        </div>
      </div>

      <div className="text-muted-foreground flex flex-wrap gap-3 text-xs" aria-label="Key">
        {LEGEND.map(([tone, label]) => (
          <span key={tone} className="flex items-center gap-1.5">
            <span className={cn("size-3 rounded", TONE_CLASSES[tone])} /> {label}
          </span>
        ))}
      </div>

      {/* Phones: a simple list of the month's days that have something on. */}
      <ol className="space-y-3 sm:hidden">
        {agenda.length === 0 ? (
          <li className="text-muted-foreground rounded-lg border border-dashed p-4 text-sm">
            Nothing on this month.
          </li>
        ) : (
          agenda.map(([iso, day]) => (
            <li
              key={iso}
              className={cn("rounded-lg border p-3", iso === todayIso && "ring-primary ring-2")}
            >
              <p className="mb-1.5 text-sm font-medium">{formatDate(iso)}</p>
              <div className="flex flex-col gap-1">
                {day.map((chip, i) => (
                  <ChipView key={i} chip={chip} large />
                ))}
              </div>
            </li>
          ))
        )}
      </ol>

      <div className="hidden overflow-x-auto sm:block">
        <table className="w-full min-w-[760px] table-fixed border-collapse">
          <thead>
            <tr>
              {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((d) => (
                <th
                  key={d}
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
                  const day = chips.get(cell.iso) ?? [];
                  return (
                    <td
                      key={cell.iso}
                      className={cn(
                        "h-24 border p-1 align-top",
                        !cell.inMonth && "bg-muted/30",
                        cell.iso === todayIso && "ring-primary ring-2 ring-inset",
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
    </div>
  );
}

function ChipView({ chip, large = false }: { chip: Chip; large?: boolean }) {
  const cls = cn(
    "truncate rounded px-1 py-0.5",
    large ? "text-sm leading-5" : "text-[11px] leading-4",
    TONE_CLASSES[chip.tone],
  );
  return chip.href ? (
    <Link href={chip.href} className={cn(cls, "hover:opacity-80")} title={chip.label}>
      {chip.label}
    </Link>
  ) : (
    <span className={cls} title={chip.label}>
      {chip.label}
    </span>
  );
}
