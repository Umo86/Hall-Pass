import { Handshake } from "lucide-react";
import { db } from "@/lib/db/client";
import { standsEnabled } from "@/lib/config";
import { formatDate, formatDayMonth, roleLabel } from "@/lib/format";
import { todayInLondon } from "@/lib/today";
import {
  defaultEventId,
  externalEvents,
  externalScopes,
  listGrants,
  type GrantRow,
} from "@/lib/users/external";
import { invitesCanBeEmailed } from "@/lib/users/email";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/empty-state";
import { cn } from "@/lib/utils";
import { EventFilter, ExternalInvite, GrantActions, type EventOption } from "./external-access";

function statusText(g: GrantRow): string {
  switch (g.status) {
    case "revoked":
      return `Revoked ${formatDayMonth(g.revokedAt)}`;
    case "expired":
      return g.endsOn ? `Access ended ${formatDate(g.endsOn)}` : "Access ended";
    case "active":
      return g.endsOn ? `Active · ends ${formatDate(g.endsOn)}` : "Active";
    default:
      return `Invited ${formatDayMonth(g.createdAt)}${g.endsOn ? ` · ends ${formatDate(g.endsOn)}` : ""}`;
  }
}

const TONE: Record<GrantRow["status"], string> = {
  active: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  invited: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  expired: "bg-amber-50 text-amber-900 dark:bg-amber-950 dark:text-amber-300",
  revoked: "bg-neutral-100 text-neutral-600 dark:bg-neutral-800 dark:text-neutral-400",
};

function Status({ g }: { g: GrantRow }) {
  return (
    <span className={cn("inline-flex rounded-md px-2 py-0.5 text-xs font-medium", TONE[g.status])}>
      {statusText(g)}
    </span>
  );
}

function GrantTable({ rows, emailOn }: { rows: GrantRow[]; emailOn: boolean }) {
  return (
    <>
      <div className="hidden rounded-lg border md:block">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Person</TableHead>
              <TableHead>Event</TableHead>
              <TableHead>For</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">
                <span className="sr-only">Actions</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((g) => (
              <TableRow key={g.id}>
                <TableCell>
                  <span className="block font-medium">{g.name || g.email}</span>
                  {g.name && <span className="text-muted-foreground text-xs">{g.email}</span>}
                </TableCell>
                <TableCell>{g.eventName}</TableCell>
                <TableCell>
                  {g.scopeName ?? <span className="text-muted-foreground">—</span>}
                </TableCell>
                <TableCell className="whitespace-nowrap">{roleLabel(g.role)}</TableCell>
                <TableCell>
                  <Status g={g} />
                </TableCell>
                <TableCell className="text-right">
                  {g.status !== "revoked" && (
                    <GrantActions
                      grantId={g.id}
                      who={g.name || g.email}
                      eventName={g.eventName}
                      status={g.status}
                      endsOn={g.endsOn}
                      emailOn={emailOn}
                    />
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      <ul className="space-y-2 md:hidden" aria-label="External people">
        {rows.map((g) => (
          <li key={g.id} className="space-y-1 rounded-lg border p-3">
            <p className="font-medium break-words">{g.name || g.email}</p>
            {g.name && <p className="text-muted-foreground text-xs break-all">{g.email}</p>}
            <p className="text-sm">
              {[roleLabel(g.role), g.scopeName, g.eventName].filter(Boolean).join(" · ")}
            </p>
            <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
              <Status g={g} />
              {g.status !== "revoked" && (
                <GrantActions
                  grantId={g.id}
                  who={g.name || g.email}
                  eventName={g.eventName}
                  status={g.status}
                  endsOn={g.endsOn}
                  emailOn={emailOn}
                />
              )}
            </div>
          </li>
        ))}
      </ul>
    </>
  );
}

/** Users → External: venues, suppliers and sponsors with access to an event. */
export async function ExternalTab({
  organisationId,
  params,
  lastEvent,
}: {
  organisationId: string;
  params: { event?: string; invite?: string; role?: string; scopeId?: string; edition?: string };
  lastEvent: string | null;
}) {
  const [eventList, grants, scopes] = await Promise.all([
    externalEvents(db, organisationId, todayInLondon()),
    listGrants(db, organisationId),
    externalScopes(db, organisationId),
  ]);
  const emailOn = invitesCanBeEmailed();
  const current = defaultEventId(eventList, lastEvent);
  const events: EventOption[] = eventList.map((e) => ({
    id: e.id,
    label: `${e.name} · ${formatDate(e.openStart)}`,
    upcoming: e.upcoming,
  }));
  // Archived events take no new invitations (the server refuses them too).
  const archived = new Set(eventList.filter((e) => e.archived).map((e) => e.id));
  const inviteEvents = events.filter((e) => !archived.has(e.id));
  const filter =
    params.event === "all"
      ? "all"
      : (eventList.find((e) => e.id === params.event || e.code === params.event)?.id ??
        current ??
        "all");
  const inEvent = filter === "all" ? grants : grants.filter((g) => g.editionId === filter);
  const live = inEvent.filter((g) => g.status !== "revoked");
  const revoked = inEvent.filter((g) => g.status === "revoked");
  const uuid = /^[0-9a-f-]{36}$/i;

  return (
    <section className="space-y-4" aria-label="External access">
      <p className="text-muted-foreground max-w-3xl text-sm">
        People outside the team — venues, suppliers and sponsors — sign in to a portal that shows
        only their own items for one event.
      </p>
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        {events.length > 0 ? <EventFilter events={events} value={filter} /> : <span />}
        {inviteEvents.length > 0 && (
          <ExternalInvite
            events={inviteEvents}
            defaultEventId={
              [filter, current].find((id) => id && id !== "all" && !archived.has(id)) ?? null
            }
            emailOn={emailOn}
            venues={scopes.venues}
            suppliers={scopes.suppliers}
            sponsors={scopes.sponsors}
            exhibitors={scopes.exhibitors}
            showStandRoles={standsEnabled}
            prefill={{
              open: params.invite === "1",
              role: params.role ?? null,
              scopeId: params.scopeId && uuid.test(params.scopeId) ? params.scopeId : null,
              editionId: params.edition && uuid.test(params.edition) ? params.edition : null,
            }}
          />
        )}
      </div>
      {events.length === 0 ? (
        <EmptyState
          icon={Handshake}
          title="No events yet"
          description="Create an event first; then you can invite its venue, suppliers and sponsors."
        />
      ) : live.length === 0 ? (
        <EmptyState
          icon={Handshake}
          title={
            filter === "all" ? "Nobody from outside yet" : "Nobody from outside for this event"
          }
          description="Invite the venue, suppliers or sponsors so they can see and approve their own items."
        />
      ) : (
        <GrantTable rows={live} emailOn={emailOn} />
      )}
      {revoked.length > 0 && (
        <details className="space-y-2">
          <summary className="text-muted-foreground min-h-11 cursor-pointer py-2 text-sm select-none">
            Revoked ({revoked.length})
          </summary>
          <GrantTable rows={revoked} emailOn={emailOn} />
        </details>
      )}
    </section>
  );
}
