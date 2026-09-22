import Link from "next/link";
import { notFound } from "next/navigation";
import { and, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { approvalInstances, editionDeadlines, signageItems, standSubmissions, exhibitors } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { getEditionByCode } from "@/lib/queries/editions";
import { effectiveDeadline, type DeadlineKey } from "@/lib/deadlines";
import { addMonths, monthGrid, monthLabel, parseMonthParam } from "@/lib/calendar";
import { cn } from "@/lib/utils";

export const metadata = { title: "Calendar" };
export const dynamic = "force-dynamic";

type Chip = {
  label: string;
  href: string | null;
  tone: "deadline" | "install" | "delivery" | "signoff" | "overdue";
};

const TONE_CLASSES: Record<Chip["tone"], string> = {
  deadline: "bg-indigo-100 text-indigo-900 dark:bg-indigo-950 dark:text-indigo-200",
  install: "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200",
  delivery: "bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200",
  signoff: "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200",
  overdue: "bg-rose-100 text-rose-900 dark:bg-rose-950 dark:text-rose-200",
};

export default async function CalendarPage({
  params,
  searchParams,
}: {
  params: Promise<{ editionCode: string }>;
  searchParams: Promise<{ m?: string }>;
}) {
  await requireStaffSession();
  const { editionCode } = await params;
  const { m } = await searchParams;
  const ed = await getEditionByCode(editionCode.toUpperCase());
  if (!ed) notFound();
  const edition = ed.edition;

  const today = new Date();
  const todayIso = today.toISOString().slice(0, 10);
  const { year, month } = parseMonthParam(m, today);

  const [deadlineRows, items, stands] = await Promise.all([
    db.select().from(editionDeadlines).where(eq(editionDeadlines.editionId, edition.id)),
    db
      .select({
        ref: signageItems.ref,
        name: signageItems.name,
        id: signageItems.id,
        installDate: signageItems.installDate,
        deliveryDate: signageItems.deliveryDate,
      })
      .from(signageItems)
      .where(and(eq(signageItems.editionId, edition.id), isNull(signageItems.deletedAt))),
    db
      .select({ id: standSubmissions.id, company: exhibitors.companyName })
      .from(standSubmissions)
      .innerJoin(exhibitors, eq(standSubmissions.exhibitorId, exhibitors.id))
      .where(eq(standSubmissions.editionId, edition.id)),
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
      label: row.label,
      href: `/${editionCode}/dashboard`,
      tone: "deadline",
    });
  }
  add(edition.buildStart, { label: "Build-up starts", href: null, tone: "deadline" });

  for (const item of items) {
    add(item.installDate, {
      label: `Install ${item.ref}`,
      href: `/${editionCode}/signage/${item.ref}`,
      tone: "install",
    });
    add(item.deliveryDate, {
      label: `Deliver ${item.ref}`,
      href: `/${editionCode}/signage/${item.ref}`,
      tone: "delivery",
    });
  }

  for (const inst of pending) {
    if (!inst.dueAt) continue;
    const date = inst.dueAt.toISOString().slice(0, 10);
    const item = itemById.get(inst.entityId);
    const stand = standById.get(inst.entityId);
    const target = item ? item.ref : (stand?.company ?? "stand");
    add(date, {
      label: `${inst.stepNameSnapshot}: ${target}`,
      href: item ? `/${editionCode}/signage/${item.ref}?tab=approvals` : `/${editionCode}/stands`,
      tone: date < todayIso ? "overdue" : "signoff",
    });
  }

  const weeks = monthGrid(year, month);
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
            {edition.name} — deadlines, deliveries, installs and open sign-offs.
          </p>
        </div>
        <div className="flex items-center gap-2 text-sm">
          <Link href={`?m=${fmt(prev)}`} className="rounded-md border px-2.5 py-1.5 hover:bg-accent" aria-label="Previous month">
            ←
          </Link>
          <span className="min-w-36 text-center font-medium">{monthLabel(year, month)}</span>
          <Link href={`?m=${fmt(next)}`} className="rounded-md border px-2.5 py-1.5 hover:bg-accent" aria-label="Next month">
            →
          </Link>
          <Link href={`?m=${fmt(buildMonth)}`} className="text-muted-foreground ml-2 hover:underline">
            Jump to build-up
          </Link>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[760px] table-fixed border-collapse">
          <thead>
            <tr>
              {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((d) => (
                <th key={d} className="text-muted-foreground border p-1.5 text-left text-xs font-medium">
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
                      <p className={cn("mb-1 text-xs", cell.inMonth ? "font-medium" : "text-muted-foreground")}>
                        {Number(cell.iso.slice(8))}
                      </p>
                      <div className="flex flex-col gap-0.5">
                        {day.slice(0, 4).map((chip, i) =>
                          chip.href ? (
                            <Link
                              key={i}
                              href={chip.href}
                              className={cn("truncate rounded px-1 py-0.5 text-[11px] leading-4 hover:opacity-80", TONE_CLASSES[chip.tone])}
                              title={chip.label}
                            >
                              {chip.label}
                            </Link>
                          ) : (
                            <span key={i} className={cn("truncate rounded px-1 py-0.5 text-[11px] leading-4", TONE_CLASSES[chip.tone])} title={chip.label}>
                              {chip.label}
                            </span>
                          ),
                        )}
                        {day.length > 4 && (
                          <span className="text-muted-foreground text-[11px]">+{day.length - 4} more</span>
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

      <div className="text-muted-foreground flex flex-wrap gap-3 text-xs">
        {(
          [
            ["deadline", "Edition deadline"],
            ["delivery", "Delivery"],
            ["install", "Install"],
            ["signoff", "Sign-off due"],
            ["overdue", "Overdue sign-off"],
          ] as const
        ).map(([tone, label]) => (
          <span key={tone} className="flex items-center gap-1.5">
            <span className={cn("size-3 rounded", TONE_CLASSES[tone])} /> {label}
          </span>
        ))}
      </div>
    </div>
  );
}
