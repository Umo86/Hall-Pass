import Link from "next/link";
import { notFound } from "next/navigation";
import { eq } from "drizzle-orm";
import { CheckCircle2, Copy, Download, Plus } from "lucide-react";
import { db } from "@/lib/db/client";
import { editions, events } from "@/lib/db/schema";
import { requireStaffSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { editionIsReadOnly } from "@/lib/edition-lock";
import { diffDaysIso } from "@/lib/deadlines";
import { plural } from "@/lib/format";
import { todayInLondon } from "@/lib/today";
import { getEditionByCode, showLogoUrl } from "@/lib/queries/editions";
import {
  deadlinesForSetup,
  getSetupStatus,
  hallCopySources,
  hallsEditorData,
  setupContacts,
  setupPermissionsFor,
  venuesForPicker,
  type OrgSetupFacts,
  type SetupStep,
} from "@/lib/queries/setup";
import { Page, PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { HallsEditor } from "@/components/halls/halls-editor";
import { SetupChecklist } from "@/components/setup/setup-checklist";
import { EventDetailsForm } from "@/components/setup/details-form";
import { DeadlinesForm } from "@/components/setup/deadlines-form";
import { ImportSheet } from "@/components/setup/import-sheet";
import { AskContacts, type SetupContact } from "@/components/setup/no-events-state";
import { dateRangeWithYear, longDate } from "@/components/setup/format";

export const metadata = { title: "Event setup" };
export const dynamic = "force-dynamic";

function Actions({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap [&>*]:w-full sm:[&>*]:w-auto">
      {children}
    </div>
  );
}

function Ask({ contacts }: { contacts: SetupContact[] }) {
  return (
    <p className="text-sm">
      <AskContacts contacts={contacts} suffix="to finish this" />
    </p>
  );
}

function SignoffPanel({
  org,
  step,
  admins,
}: {
  org: OrgSetupFacts;
  step: SetupStep;
  admins: SetupContact[];
}) {
  return (
    <div className="space-y-3">
      {org.signoffDepartments.length > 0 ? (
        <ul className="divide-y rounded-md border text-sm">
          {org.signoffDepartments.map((d) => {
            const main = d.approvers.find((a) => a.isMain);
            const active = d.approvers.filter((a) => a.active);
            const who = main
              ? `${main.name} (main approver)${main.active ? "" : " — hasn't accepted their invitation yet"}`
              : active.length > 0
                ? `Anyone of ${active.map((a) => a.name).join(", ")}`
                : d.approvers.length > 0
                  ? `Waiting for ${d.approvers[0].email} to accept`
                  : "Nobody yet";
            const ready = main ? main.active || active.length > 0 : active.length > 0;
            return (
              <li
                key={d.name}
                className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 px-3 py-2"
              >
                <span className="font-medium">{d.name}</span>
                {d.forOrganiser && (
                  <span className="text-muted-foreground text-xs">organiser signage</span>
                )}
                <span
                  className={
                    ready
                      ? "text-muted-foreground w-full sm:ml-auto sm:w-auto"
                      : "w-full text-amber-700 sm:ml-auto sm:w-auto dark:text-amber-400"
                  }
                >
                  {who}
                </span>
              </li>
            );
          })}
        </ul>
      ) : (
        <p className="text-sm">No department signs off artwork yet.</p>
      )}
      {step.canAct ? (
        <Actions>
          <Button asChild variant={step.state === "done" ? "outline" : "default"}>
            <Link href="/users?tab=departments">Set up in Users → Departments</Link>
          </Button>
        </Actions>
      ) : step.state !== "done" ? (
        <Ask contacts={admins} />
      ) : null}
    </div>
  );
}

export default async function SetupPage({ params }: { params: Promise<{ editionCode: string }> }) {
  const session = await requireStaffSession();
  const orgId = session.organisation.id;
  const { editionCode } = await params;
  const ed = await getEditionByCode(editionCode.toUpperCase(), orgId);
  if (!ed) notFound();
  const edition = ed.edition;
  const archived = editionIsReadOnly(edition.status);
  // Each step by its own ability (dates, halls, lists, suppliers…).
  const perms = setupPermissionsFor(session.actor, { readOnly: archived });
  const canSetup = can(session.actor, { type: "event.setup" }) && !archived;

  const [status, contacts, deadlines, halls, copySources, venueRows, seriesRows, logoUrl, source] =
    await Promise.all([
      getSetupStatus(edition, orgId, perms),
      setupContacts(orgId),
      deadlinesForSetup(edition.id),
      hallsEditorData(edition.id),
      perms.halls ? hallCopySources(orgId, edition) : Promise.resolve([]),
      perms.details ? venuesForPicker(orgId) : Promise.resolve([]),
      perms.details
        ? db.select().from(events).where(eq(events.organisationId, orgId)).orderBy(events.name)
        : Promise.resolve([]),
      perms.details ? showLogoUrl(edition.logoPath) : Promise.resolve(null),
      edition.clonedFromEditionId
        ? db
            .select({ name: editions.name })
            .from(editions)
            .where(eq(editions.id, edition.clonedFromEditionId))
            .limit(1)
            .then((r) => r[0] ?? null)
        : Promise.resolve(null),
    ]);
  const { steps, summary, org, facts } = status;
  const admins = contacts.filter((c) => c.role === "admin");
  const stepByKey = Object.fromEntries(steps.map((s) => [s.key, s])) as Record<
    SetupStep["key"],
    SetupStep
  >;
  // An archived venue still shows for the event that uses it.
  const venues = venueRows.some((v) => v.id === ed.venue.id)
    ? venueRows
    : [{ id: ed.venue.id, name: ed.venue.name, address: ed.venue.address }, ...venueRows];

  const today = todayInLondon();
  const daysToGo = diffDaysIso(edition.openStart, today);
  const when =
    daysToGo > 1
      ? `Opens ${longDate(edition.openStart)} · ${daysToGo} days to go`
      : daysToGo === 1
        ? `Opens tomorrow, ${longDate(edition.openStart)}`
        : daysToGo === 0
          ? "Opens today"
          : `Open ${dateRangeWithYear(edition.openStart, edition.openEnd)}`;
  const pct = summary.total > 0 ? Math.round((summary.done / summary.total) * 100) : 0;
  const copiedParts = [
    facts.halls.length > 0 ? plural(facts.halls.length, "hall") : null,
    facts.deadlines.length > 0 ? plural(facts.deadlines.length, "deadline") : null,
    facts.sponsorCount > 0 ? plural(facts.sponsorCount, "sponsor") : null,
    facts.signCount + facts.sponsorshipItemCount > 0
      ? `${plural(facts.signCount + facts.sponsorshipItemCount, "draft item")}`
      : null,
  ].filter(Boolean);
  const checked = (k: string) => (edition.setupChecked ?? []).includes(k);
  const ask = (step: SetupStep, who: SetupContact[] = contacts) =>
    step.canAct || step.state === "done" ? null : <Ask contacts={who} />;

  const panels: Record<string, React.ReactNode> = {
    details: perms.details ? (
      <EventDetailsForm
        edition={{
          id: edition.id,
          name: edition.name,
          buildStart: edition.buildStart,
          buildEnd: edition.buildEnd,
          openStart: edition.openStart,
          openEnd: edition.openEnd,
          breakdownEnd: edition.breakdownEnd,
          signageBudget: edition.signageBudget,
          venueId: edition.venueId,
          eventId: edition.eventId,
          logoUrl,
        }}
        venues={venues}
        series={seriesRows.map((s) => ({ id: s.id, name: s.name }))}
        confirmed={checked("details")}
      />
    ) : (
      <div className="space-y-3">
        <dl className="grid grid-cols-[9rem_1fr] gap-x-3 gap-y-1 text-sm">
          <dt className="text-muted-foreground">Build-up</dt>
          <dd>{dateRangeWithYear(edition.buildStart, edition.buildEnd)}</dd>
          <dt className="text-muted-foreground">Open to visitors</dt>
          <dd>{dateRangeWithYear(edition.openStart, edition.openEnd)}</dd>
          <dt className="text-muted-foreground">Breakdown ends</dt>
          <dd>{longDate(edition.breakdownEnd)}</dd>
          <dt className="text-muted-foreground">Venue</dt>
          <dd>
            {ed.venue.name}
            {ed.venue.address ? `, ${ed.venue.address}` : ""}
          </dd>
          <dt className="text-muted-foreground">Event series</dt>
          <dd>{ed.event.name}</dd>
        </dl>
        {ask(stepByKey.details)}
      </div>
    ),
    halls: (
      <div className="space-y-3">
        <HallsEditor
          editionId={edition.id}
          editionCode={edition.code}
          canEdit={perms.halls}
          venueName={ed.venue.name}
          halls={halls.halls}
          zones={halls.zones}
          copySources={copySources}
        />
        <Link href={`/${edition.code}/halls`} className="link inline-block text-sm">
          Open Halls &amp; locations →
        </Link>
      </div>
    ),
    deadlines: (
      <div className="space-y-3">
        <DeadlinesForm
          editionId={edition.id}
          deadlines={deadlines}
          confirmed={checked("deadlines")}
          canEdit={perms.deadlines}
        />
        {ask(stepByKey.deadlines)}
      </div>
    ),
    signoff: <SignoffPanel org={org} step={stepByKey.signoff} admins={admins} />,
    people: stepByKey.people.canAct ? (
      <Actions>
        <Button asChild variant={stepByKey.people.state === "done" ? "outline" : "default"}>
          <Link href="/users/new">
            <Plus aria-hidden /> Add people
          </Link>
        </Button>
        <Button asChild variant="outline">
          <Link href="/users">Manage users</Link>
        </Button>
      </Actions>
    ) : (
      (ask(stepByKey.people, admins) ?? (
        <Link href="/users" className="link text-sm">
          See who&apos;s here →
        </Link>
      ))
    ),
    types: stepByKey.types.canAct ? (
      <Actions>
        <Button asChild variant="outline">
          <Link href="/settings/item-types">Edit sign types</Link>
        </Button>
      </Actions>
    ) : (
      ask(stepByKey.types)
    ),
    suppliers: stepByKey.suppliers.canAct ? (
      <Actions>
        <Button asChild variant="outline">
          <Link href="/suppliers">
            {org.supplierCount > 0 ? "Open Suppliers" : "Add suppliers"}
          </Link>
        </Button>
      </Actions>
    ) : (
      <p className="text-muted-foreground text-sm">
        Optional — add them whenever you&apos;re ready.
      </p>
    ),
    signs: stepByKey.signs.canAct ? (
      <Actions>
        <Button asChild variant={stepByKey.signs.state === "done" ? "outline" : "default"}>
          <Link href={`/${edition.code}/signage/new`}>
            <Plus aria-hidden /> Add a sign
          </Link>
        </Button>
        <ImportSheet editionId={edition.id} />
        <Button asChild variant="ghost">
          <a href="/api/exports/import-template" download>
            <Download aria-hidden /> Download template
          </a>
        </Button>
        {facts.copied && facts.draftSignCount > 0 && (
          <Button asChild variant="ghost">
            <Link href={`/${edition.code}/signage?status=draft`}>Review the drafts</Link>
          </Button>
        )}
      </Actions>
    ) : (
      (ask(stepByKey.signs) ?? (
        <Link href={`/${edition.code}/signage`} className="link text-sm">
          Open Signage →
        </Link>
      ))
    ),
    sponsorship: (
      <Actions>
        <Button asChild variant="outline">
          <Link href={`/${edition.code}/sponsorship`}>Open Sponsorship</Link>
        </Button>
      </Actions>
    ),
  };

  return (
    <Page width="narrow">
      <PageHeader
        title={`Get ${edition.name} ready`}
        description={`${ed.venue.name} · ${when}`}
        actions={
          <Button asChild variant="outline" size="sm">
            <Link href={`/${edition.code}/dashboard`}>Go to dashboard</Link>
          </Button>
        }
      />

      {archived && (
        <p className="rounded-md border bg-neutral-50 px-3 py-2 text-sm dark:bg-neutral-900">
          This event is archived, so nothing here can be changed.
        </p>
      )}

      {summary.complete ? (
        <section
          aria-label="Ready"
          className="flex flex-col gap-3 rounded-lg border border-emerald-300 bg-emerald-50 p-4 text-emerald-950 sm:flex-row sm:items-center dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-100"
        >
          <CheckCircle2 className="hidden size-5 shrink-0 sm:block" aria-hidden />
          <p className="flex-1 text-sm">
            <span className="font-semibold">{edition.name} is ready.</span> People can add signs and
            send them for sign-off.
          </p>
          <Button asChild>
            <Link href={`/${edition.code}/dashboard`}>Go to dashboard</Link>
          </Button>
        </section>
      ) : (
        <div className="space-y-1.5">
          <p className="text-sm font-medium">
            {summary.done} of {summary.total} essentials done
          </p>
          <div
            className="bg-muted h-2 w-full overflow-hidden rounded-full"
            role="progressbar"
            aria-label="Essentials done"
            aria-valuemin={0}
            aria-valuemax={summary.total}
            aria-valuenow={summary.done}
          >
            <div className="bg-primary h-full rounded-full" style={{ width: `${pct}%` }} />
          </div>
          {!canSetup && !archived && (
            <p className="text-muted-foreground text-sm">
              Admins and Operations finish these steps; you can follow along here.
            </p>
          )}
        </div>
      )}

      {source && !summary.complete && copiedParts.length > 0 && (
        <p className="text-muted-foreground flex items-start gap-2 text-sm">
          <Copy className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span>
            Copied from {source.name} — {copiedParts.join(", ").replace(/, ([^,]*)$/, " and $1")}{" "}
            came across. Check the dates and deadlines: they were worked out from last time.
          </span>
        </p>
      )}

      <SetupChecklist
        steps={steps.map((s) => ({
          key: s.key,
          title: s.title,
          reason: s.reason,
          level: s.level,
          state: s.state,
          detail: s.detail,
          shared: s.shared,
        }))}
        panels={panels}
        initialBuildStart={edition.buildStart}
        readOnly={!perms.details}
      />
    </Page>
  );
}
