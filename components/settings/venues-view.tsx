"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Archive, KeyRound, MapPin, Pencil, Plus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/empty-state";
import { useConfirm } from "@/components/confirm-dialog";
import {
  PortalAccessButton,
  PortalAccessDialog,
  type PortalEvent,
} from "@/components/portal/portal-access";
import { portalSummary } from "@/components/portal/summary";
import type { PortalGrant } from "@/components/portal/grants";
import { setVenueArchived } from "@/app/actions/directory";
import { plural } from "@/lib/format";
import { DirectoryDialog, type DirectoryField, type DirectoryRow } from "./directory-section";

export type VenueRow = {
  id: string;
  name: string;
  address: string | null;
  riggingContactName: string | null;
  riggingContactEmail: string | null;
  isArchived: boolean;
  /** Event codes held here, newest first. */
  eventCodes: string[];
  grants: PortalGrant[];
  /** Events an invitation from this venue can be for. */
  inviteEvents: PortalEvent[];
  defaultEventId: string | null;
};

export type SeriesRow = { id: string; name: string; eventCount: number };

const VENUE_FIELDS: DirectoryField[] = [
  { key: "name", label: "Venue name", required: true, placeholder: "NEC Birmingham" },
  { key: "address", label: "Address", autoComplete: "street-address" },
  { key: "riggingContactName", label: "Rigging contact" },
  { key: "riggingContactEmail", label: "Rigging contact email", type: "email" },
];

const SERIES_FIELDS: DirectoryField[] = [
  { key: "name", label: "Series name", required: true, placeholder: "UK Construction Week" },
];

function toRow(v: VenueRow): DirectoryRow {
  return {
    id: v.id,
    name: v.name,
    address: v.address,
    riggingContactName: v.riggingContactName,
    riggingContactEmail: v.riggingContactEmail,
  };
}

function EventsText({ codes }: { codes: string[] }) {
  if (codes.length === 0) return <span className="text-muted-foreground">No events yet</span>;
  return (
    <span title={codes.join(", ")}>
      {plural(codes.length, "event")}
      <span className="text-muted-foreground"> · latest {codes[0]}</span>
    </span>
  );
}

/** Settings → Venues: where events are held, who to call, who can sign in. */
export function VenuesView({
  venues,
  series,
  canEdit,
  canInvite,
  emailOn,
}: {
  venues: VenueRow[];
  series: SeriesRow[];
  canEdit: boolean;
  canInvite: boolean;
  emailOn: boolean;
}) {
  const [editing, setEditing] = useState<DirectoryRow | "new" | null>(null);
  const [renaming, setRenaming] = useState<DirectoryRow | null>(null);
  const [portalFor, setPortalFor] = useState<VenueRow | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const live = venues.filter((v) => !v.isArchived);
  const archived = venues.filter((v) => v.isArchived);

  function setArchived(v: { id: string; name: string }, archived: boolean) {
    start(async () => {
      const res = await setVenueArchived({ id: v.id, archived });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? (archived ? `${v.name} archived` : `${v.name} restored`));
      setEditing(null);
      router.refresh();
    });
  }

  async function archive(row: DirectoryRow) {
    const venue = venues.find((v) => v.id === row.id);
    const n = venue?.eventCodes.length ?? 0;
    const ok = await confirm({
      title: `Archive ${row.name}?`,
      description: `It won't be offered when someone creates an event.${
        n > 0 ? ` Its ${plural(n, "event")} keep it.` : ""
      } You can restore it from Archived below.`,
      confirmLabel: "Archive",
    });
    if (ok) setArchived({ id: row.id, name: row.name ?? "The venue" }, true);
  }

  // Only venues that have access say so in the list; invite from Edit.
  const portal = (v: VenueRow) =>
    canEdit &&
    v.grants.length > 0 && (
      <PortalAccessButton
        scopeType="venue"
        scopeId={v.id}
        scopeName={v.name}
        grants={v.grants}
        events={v.inviteEvents}
        defaultEventId={v.defaultEventId}
        canInvite={canInvite}
        emailOn={emailOn}
      />
    );

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-muted-foreground text-sm">{plural(live.length, "venue")}</p>
        {canEdit && (
          <Button onClick={() => setEditing("new")} className="h-11 w-fit sm:h-9">
            <Plus aria-hidden /> Add venue
          </Button>
        )}
      </div>

      {live.length === 0 ? (
        <EmptyState
          icon={MapPin}
          title="No venues yet"
          description="Add the places you run events, with the rigging contact. You can also add one while creating an event."
          action={
            canEdit && (
              <Button onClick={() => setEditing("new")}>
                <Plus aria-hidden /> Add venue
              </Button>
            )
          }
        />
      ) : (
        <>
          <div className="hidden rounded-lg border md:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Venue</TableHead>
                  <TableHead>Address</TableHead>
                  <TableHead>Rigging contact</TableHead>
                  <TableHead>Events</TableHead>
                  {canEdit && (
                    <TableHead className="w-12">
                      <span className="sr-only">Edit</span>
                    </TableHead>
                  )}
                </TableRow>
              </TableHeader>
              <TableBody>
                {live.map((v) => (
                  <TableRow key={v.id}>
                    <TableCell className="max-w-56 align-top">
                      <span className="block font-medium break-words">{v.name}</span>
                      {portal(v)}
                    </TableCell>
                    <TableCell className="max-w-72 align-top break-words">
                      {v.address ?? <span className="text-muted-foreground">—</span>}
                    </TableCell>
                    <TableCell className="align-top">
                      {v.riggingContactName || v.riggingContactEmail ? (
                        <span className="flex flex-col">
                          {v.riggingContactName && <span>{v.riggingContactName}</span>}
                          {v.riggingContactEmail && (
                            <a
                              href={`mailto:${v.riggingContactEmail}`}
                              className="text-muted-foreground break-all hover:underline"
                            >
                              {v.riggingContactEmail}
                            </a>
                          )}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TableCell>
                    <TableCell className="align-top whitespace-nowrap">
                      <EventsText codes={v.eventCodes} />
                    </TableCell>
                    {canEdit && (
                      <TableCell className="align-top">
                        <Button
                          size="icon"
                          variant="ghost"
                          onClick={() => setEditing(toRow(v))}
                          aria-label={`Edit ${v.name}`}
                        >
                          <Pencil aria-hidden />
                        </Button>
                      </TableCell>
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          <ul className="space-y-2 md:hidden" aria-label="Venues">
            {live.map((v) => (
              <li
                key={v.id}
                className="flex items-start justify-between gap-2 rounded-lg border p-3"
              >
                <div className="min-w-0 space-y-1 text-sm">
                  <p className="font-semibold break-words">{v.name}</p>
                  {v.address && <p className="text-muted-foreground break-words">{v.address}</p>}
                  {(v.riggingContactName || v.riggingContactEmail) && (
                    <p className="break-words">
                      Rigging:{" "}
                      {[v.riggingContactName, v.riggingContactEmail].filter(Boolean).join(" · ")}
                    </p>
                  )}
                  <p className="text-xs">
                    <EventsText codes={v.eventCodes} />
                  </p>
                  {portal(v)}
                </div>
                {canEdit && (
                  <Button
                    size="touch"
                    variant="ghost"
                    onClick={() => setEditing(toRow(v))}
                    aria-label={`Edit ${v.name}`}
                  >
                    <Pencil aria-hidden />
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </>
      )}

      {archived.length > 0 && (
        <details>
          <summary className="text-muted-foreground hover:text-foreground inline-flex min-h-11 cursor-pointer items-center gap-1.5 text-sm select-none sm:min-h-9">
            <Archive className="size-4" aria-hidden />
            Archived ({archived.length})
          </summary>
          <p className="text-muted-foreground mt-1 text-sm">
            Archived venues aren&rsquo;t offered for new events. Their events keep them.
          </p>
          <ul className="mt-2 divide-y rounded-lg border" aria-label="Archived venues">
            {archived.map((v) => (
              <li key={v.id} className="flex items-center justify-between gap-2 px-3 py-2 text-sm">
                <span className="min-w-0">
                  <span className="block font-medium break-words">{v.name}</span>
                  <span className="text-muted-foreground text-xs">
                    <EventsText codes={v.eventCodes} />
                  </span>
                </span>
                {canEdit && (
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={pending}
                    onClick={() => setArchived(v, false)}
                    aria-label={`Restore ${v.name}`}
                  >
                    Restore
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </details>
      )}

      {series.length > 0 && (
        <details className="group">
          <summary className="hover:text-foreground inline-flex min-h-11 cursor-pointer items-center gap-1.5 text-sm font-medium select-none sm:min-h-9">
            Event series ({series.length})
          </summary>
          <p className="text-muted-foreground mt-1 text-sm">
            Each event belongs to a series — the same event run every year. New events join one
            automatically; rename a series here.
          </p>
          <ul className="mt-2 divide-y rounded-lg border" aria-label="Event series">
            {series.map((s) => (
              <li
                key={s.id}
                className="flex items-center justify-between gap-2 px-3 py-1.5 text-sm"
              >
                <span className="min-w-0">
                  <span className="font-medium break-words">{s.name}</span>
                  <span className="text-muted-foreground"> · {plural(s.eventCount, "event")}</span>
                </span>
                {canEdit && (
                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-11 md:h-8"
                    onClick={() => setRenaming({ id: s.id, name: s.name })}
                    aria-label={`Rename ${s.name}`}
                  >
                    Rename
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </details>
      )}

      {canEdit && (
        <>
          <DirectoryDialog
            type="venue"
            noun="venue"
            fields={VENUE_FIELDS}
            current={editing === "new" ? null : editing}
            open={editing !== null}
            onClose={() => setEditing(null)}
            onArchive={archive}
            extra={(() => {
              const v =
                editing && editing !== "new" ? venues.find((x) => x.id === editing.id) : null;
              if (!v || (v.grants.length === 0 && !canInvite)) return null;
              return (
                <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm">
                  <span className="inline-flex items-center gap-1.5">
                    <KeyRound className="text-muted-foreground size-4" aria-hidden />
                    Portal access: {portalSummary(v.grants)}
                  </span>
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    onClick={() => {
                      setEditing(null);
                      setPortalFor(v);
                    }}
                  >
                    {v.grants.length === 0 ? "Invite someone" : "Manage"}
                  </Button>
                </div>
              );
            })()}
          />
          <DirectoryDialog
            type="event"
            noun="event series"
            fields={SERIES_FIELDS}
            current={renaming}
            open={renaming !== null}
            onClose={() => setRenaming(null)}
            description="The new name shows wherever the series is listed. Its events keep their own names."
          />
        </>
      )}
      {portalFor && (
        <PortalAccessDialog
          open
          onOpenChange={(o) => !o && setPortalFor(null)}
          scopeType="venue"
          scopeId={portalFor.id}
          scopeName={portalFor.name}
          grants={venues.find((v) => v.id === portalFor.id)?.grants ?? portalFor.grants}
          events={portalFor.inviteEvents}
          defaultEventId={portalFor.defaultEventId}
          canInvite={canInvite}
          emailOn={emailOn}
        />
      )}
      {confirmDialog}
    </div>
  );
}
