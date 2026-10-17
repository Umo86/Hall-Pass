"use client";

import { useId, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertTriangle, Copy, ListPlus, MapPin, Pencil, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { useConfirm } from "@/components/confirm-dialog";
import {
  copyHallsFrom,
  createHall,
  createHallsBulk,
  createLocation,
  deleteHall,
  deleteLocation,
  renameHall,
  renameLocation,
} from "@/app/actions/halls";
import { describeBulk, parseBulkHalls } from "./bulk";

export type LocationRow = { id: string; name: string; zone: string | null; itemCount: number };

export type HallRow = {
  id: string;
  name: string;
  locations: LocationRow[];
  itemCount: number;
  /** Signs in this hall that have no location yet. */
  unplacedCount: number;
};

export type HallCopySource = {
  id: string;
  name: string;
  code: string;
  halls: number;
  locations: number;
};

type Result = { ok: boolean; error?: string; message?: string };

/** Run a server action: toast on success and refresh, keep the error for inline display. */
function useAction() {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  function run(fn: () => Promise<Result>, onDone?: () => void) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) {
        setError(res.error ?? "Something went wrong");
        return;
      }
      toast.success(res.message ?? "Saved");
      onDone?.();
      router.refresh();
    });
  }
  return { error, setError, pending, run };
}

function plural(n: number, one: string, many = `${one}s`) {
  return `${n} ${n === 1 ? one : many}`;
}

function InlineError({ error }: { error: string | null }) {
  if (!error) return null;
  return (
    <p className="text-destructive w-full text-sm" role="alert">
      {error}
    </p>
  );
}

/** Location name + optional zone, used for adding and for editing. */
function LocationFields({
  hallName,
  name,
  zone,
  zonesListId,
  onName,
  onZone,
  autoFocus,
}: {
  hallName: string;
  name: string;
  zone: string;
  zonesListId: string;
  onName: (v: string) => void;
  onZone: (v: string) => void;
  autoFocus?: boolean;
}) {
  return (
    <>
      <Input
        value={name}
        onChange={(e) => onName(e.target.value)}
        placeholder="e.g. Main entrance"
        aria-label={`Location name in ${hallName}`}
        className="h-9 min-w-0 flex-1 sm:max-w-56"
        autoFocus={autoFocus}
        maxLength={120}
      />
      <Input
        value={zone}
        onChange={(e) => onZone(e.target.value)}
        placeholder="Zone (optional)"
        aria-label={`Zone in ${hallName} (optional)`}
        list={zonesListId}
        className="h-9 w-full sm:w-40"
        maxLength={120}
      />
    </>
  );
}

function AddLocation({ hall, zonesListId }: { hall: HallRow; zonesListId: string }) {
  const [name, setName] = useState("");
  const [zone, setZone] = useState("");
  const { error, pending, run } = useAction();
  return (
    <form
      className="flex flex-wrap items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        if (!name.trim()) return;
        run(
          () => createLocation({ hallId: hall.id, name, zone }),
          () => {
            setName("");
            setZone("");
          },
        );
      }}
    >
      <LocationFields
        hallName={hall.name}
        name={name}
        zone={zone}
        zonesListId={zonesListId}
        onName={setName}
        onZone={setZone}
      />
      <Button type="submit" size="sm" variant="outline" disabled={pending || !name.trim()}>
        <Plus aria-hidden /> {pending ? "Adding…" : "Add location"}
      </Button>
      <InlineError error={error} />
    </form>
  );
}

function LocationItem({
  loc,
  hallName,
  editionCode,
  canEdit,
  zonesListId,
  confirm,
}: {
  loc: LocationRow;
  hallName: string;
  editionCode: string;
  canEdit: boolean;
  zonesListId: string;
  confirm: ReturnType<typeof useConfirm>[1];
}) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(loc.name);
  const [zone, setZone] = useState(loc.zone ?? "");
  const { error, setError, pending, run } = useAction();

  if (editing) {
    return (
      <li className="py-2">
        <form
          className="flex flex-wrap items-center gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            run(
              () => renameLocation({ id: loc.id, name, zone }),
              () => setEditing(false),
            );
          }}
        >
          <LocationFields
            hallName={hallName}
            name={name}
            zone={zone}
            zonesListId={zonesListId}
            onName={setName}
            onZone={setZone}
            autoFocus
          />
          <Button type="submit" size="sm" disabled={pending || !name.trim()}>
            {pending ? "Saving…" : "Save"}
          </Button>
          <Button
            type="button"
            size="sm"
            variant="ghost"
            onClick={() => {
              setEditing(false);
              setName(loc.name);
              setZone(loc.zone ?? "");
              setError(null);
            }}
          >
            Cancel
          </Button>
          <InlineError error={error} />
        </form>
      </li>
    );
  }

  return (
    <li className="flex flex-wrap items-center gap-x-2 gap-y-1 py-2 text-sm">
      <span className="min-w-0 font-medium break-words">{loc.name}</span>
      {loc.zone && (
        <span className="bg-muted text-muted-foreground rounded px-1.5 py-0.5 text-xs">
          {loc.zone}
        </span>
      )}
      {loc.itemCount > 0 ? (
        <Link
          href={`/${editionCode}/signage?location=${loc.id}`}
          className="link text-xs"
          aria-label={`${plural(loc.itemCount, "sign")} at ${loc.name}`}
        >
          {plural(loc.itemCount, "sign")}
        </Link>
      ) : (
        <span className="text-muted-foreground text-xs">no signs</span>
      )}
      {canEdit && (
        <span className="ml-auto inline-flex items-center">
          <Button
            size="icon"
            variant="ghost"
            className="size-8"
            aria-label={`Edit location ${loc.name}`}
            onClick={() => setEditing(true)}
          >
            <Pencil className="size-3.5" aria-hidden />
          </Button>
          <Button
            size="icon"
            variant="ghost"
            className="size-8"
            aria-label={`Remove location ${loc.name}`}
            disabled={pending}
            onClick={async () => {
              const ok = await confirm({
                title: `Remove ${loc.name}?`,
                description: `It comes off ${hallName}. Signs can't be placed there afterwards.`,
                confirmLabel: "Remove location",
                destructive: true,
              });
              if (ok) run(() => deleteLocation({ id: loc.id }));
            }}
          >
            <Trash2 className="size-3.5" aria-hidden />
          </Button>
        </span>
      )}
      <InlineError error={error} />
    </li>
  );
}

function HallCard({
  hall,
  editionCode,
  canEdit,
  zonesListId,
  confirm,
}: {
  hall: HallRow;
  editionCode: string;
  canEdit: boolean;
  zonesListId: string;
  confirm: ReturnType<typeof useConfirm>[1];
}) {
  const [renaming, setRenaming] = useState(false);
  const [name, setName] = useState(hall.name);
  const { error, setError, pending, run } = useAction();
  const headingId = useId();

  return (
    <section aria-labelledby={headingId} className="rounded-lg border">
      <div className="flex flex-wrap items-center gap-2 border-b px-4 py-3">
        {renaming ? (
          <form
            className="flex w-full flex-wrap items-center gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              run(
                () => renameHall({ id: hall.id, name }),
                () => setRenaming(false),
              );
            }}
          >
            <h3 id={headingId} className="sr-only">
              {hall.name}
            </h3>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              aria-label={`New name for ${hall.name}`}
              className="h-9 min-w-0 flex-1 sm:max-w-64"
              autoFocus
              maxLength={120}
            />
            <Button type="submit" size="sm" disabled={pending || !name.trim()}>
              {pending ? "Saving…" : "Save"}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => {
                setRenaming(false);
                setName(hall.name);
                setError(null);
              }}
            >
              Cancel
            </Button>
          </form>
        ) : (
          <>
            <h3 id={headingId} className="text-sm font-semibold">
              {hall.name}
            </h3>
            <span className="text-muted-foreground text-xs">
              {plural(hall.locations.length, "location")} ·{" "}
              {hall.itemCount > 0 ? (
                <Link href={`/${editionCode}/signage?hall=${hall.id}`} className="link">
                  {plural(hall.itemCount, "sign")}
                </Link>
              ) : (
                "no signs yet"
              )}
            </span>
            {canEdit && (
              <span className="ml-auto inline-flex items-center">
                <Button
                  size="icon"
                  variant="ghost"
                  className="size-8"
                  aria-label={`Rename ${hall.name}`}
                  onClick={() => setRenaming(true)}
                >
                  <Pencil className="size-3.5" aria-hidden />
                </Button>
                <Button
                  size="icon"
                  variant="ghost"
                  className="size-8"
                  aria-label={`Remove hall ${hall.name}`}
                  disabled={pending}
                  onClick={async () => {
                    const ok = await confirm({
                      title: `Remove ${hall.name}?`,
                      description:
                        hall.locations.length > 0
                          ? `Its ${plural(hall.locations.length, "location")} go too. Signs can't be placed there afterwards.`
                          : "Signs can't be placed there afterwards.",
                      confirmLabel: "Remove hall",
                      destructive: true,
                    });
                    if (ok) run(() => deleteHall({ id: hall.id }));
                  }}
                >
                  <Trash2 className="size-3.5" aria-hidden />
                </Button>
              </span>
            )}
          </>
        )}
        <InlineError error={error} />
      </div>

      {hall.unplacedCount > 0 && (
        <div className="flex flex-wrap items-center gap-2 border-b border-amber-200 bg-amber-50 px-4 py-2 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <AlertTriangle className="size-4 shrink-0" aria-hidden />
          <span>
            {plural(hall.unplacedCount, "sign")} in {hall.name}{" "}
            {hall.unplacedCount === 1 ? "has" : "have"} no location yet
          </span>
          <Link
            href={`/${editionCode}/signage?hall=${hall.id}&location=none`}
            className="font-medium underline underline-offset-2"
          >
            Place them →
          </Link>
        </div>
      )}

      <div className="px-4 py-2">
        {hall.locations.length === 0 ? (
          <p className="text-muted-foreground py-2 text-sm">
            No locations yet.{" "}
            {canEdit ? "Add the places in this hall where signs go." : "None have been added."}
          </p>
        ) : (
          <ul className="divide-y">
            {hall.locations.map((loc) => (
              <LocationItem
                key={loc.id}
                loc={loc}
                hallName={hall.name}
                editionCode={editionCode}
                canEdit={canEdit}
                zonesListId={zonesListId}
                confirm={confirm}
              />
            ))}
          </ul>
        )}
        {canEdit && (
          <div className="border-t py-3">
            <AddLocation hall={hall} zonesListId={zonesListId} />
          </div>
        )}
      </div>
    </section>
  );
}

function AddHall({ editionId }: { editionId: string }) {
  const [name, setName] = useState("");
  const { error, pending, run } = useAction();
  return (
    <form
      className="flex flex-wrap items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        if (!name.trim()) return;
        run(
          () => createHall({ editionId, name }),
          () => setName(""),
        );
      }}
    >
      <Input
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="e.g. Hall 3"
        aria-label="New hall name"
        className="h-9 min-w-0 flex-1 sm:max-w-xs"
        maxLength={120}
      />
      <Button type="submit" size="sm" variant="outline" disabled={pending || !name.trim()}>
        <Plus aria-hidden /> {pending ? "Adding…" : "Add hall"}
      </Button>
      <InlineError error={error} />
    </form>
  );
}

function AddSeveral({ editionId, defaultOpen }: { editionId: string; defaultOpen: boolean }) {
  const [open, setOpen] = useState(defaultOpen);
  const [text, setText] = useState("");
  const { error, pending, run } = useAction();
  const id = useId();
  const preview = parseBulkHalls(text);
  if (!open) {
    return (
      <Button type="button" size="sm" variant="ghost" onClick={() => setOpen(true)}>
        <ListPlus aria-hidden /> Add several at once
      </Button>
    );
  }
  return (
    <form
      className="space-y-2"
      onSubmit={(e) => {
        e.preventDefault();
        if (preview.length === 0) return;
        run(
          () => createHallsBulk({ editionId, text }),
          () => setText(""),
        );
      }}
    >
      <Label htmlFor={id}>Add several at once</Label>
      <p className="text-muted-foreground text-xs" id={`${id}-help`}>
        One per line. Use &ldquo;Hall 1: Main entrance, Registration&rdquo; to add locations too.
      </p>
      <Textarea
        id={id}
        aria-describedby={`${id}-help`}
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder={"Hall 1: Main entrance, Registration\nHall 2: Seminar theatre\nHall 3"}
        className="min-h-28 font-mono text-sm"
      />
      <div className="flex flex-wrap items-center gap-2">
        <Button type="submit" size="sm" disabled={pending || preview.length === 0}>
          {pending ? "Adding…" : preview.length > 0 ? `Add ${describeBulk(preview)}` : "Add"}
        </Button>
        {!defaultOpen && (
          <Button type="button" size="sm" variant="ghost" onClick={() => setOpen(false)}>
            Cancel
          </Button>
        )}
      </div>
      <InlineError error={error} />
    </form>
  );
}

function CopyFromEvent({
  editionId,
  venueName,
  sources,
}: {
  editionId: string;
  venueName: string;
  sources: HallCopySource[];
}) {
  const [sourceId, setSourceId] = useState(sources[0]?.id ?? "");
  const { error, pending, run } = useAction();
  const id = useId();
  return (
    <form
      className="space-y-2"
      onSubmit={(e) => {
        e.preventDefault();
        if (!sourceId) return;
        run(() => copyHallsFrom({ sourceEditionId: sourceId, targetEditionId: editionId }));
      }}
    >
      <Label htmlFor={id}>Copy halls &amp; locations from a previous event at {venueName}</Label>
      <div className="flex flex-col gap-2 sm:flex-row">
        <SelectNative
          id={id}
          value={sourceId}
          onChange={(e) => setSourceId(e.target.value)}
          className="sm:max-w-sm"
        >
          {sources.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name} — {plural(s.halls, "hall")}, {plural(s.locations, "location")}
            </option>
          ))}
        </SelectNative>
        <Button type="submit" disabled={pending || !sourceId}>
          <Copy aria-hidden /> {pending ? "Copying…" : "Copy"}
        </Button>
      </div>
      <InlineError error={error} />
    </form>
  );
}

/**
 * Halls and the locations inside them, where every sign is placed. Used on
 * the Halls & locations page and inside the event setup checklist.
 */
export function HallsEditor({
  editionId,
  editionCode,
  halls,
  zones = [],
  canEdit,
  lockedReason,
  venueName,
  copySources = [],
}: {
  editionId: string;
  editionCode: string;
  halls: HallRow[];
  zones?: string[];
  canEdit: boolean;
  /** Why halls can't be added here (archived event, or no ability), when canEdit is false. */
  lockedReason?: string;
  venueName: string;
  copySources?: HallCopySource[];
}) {
  const [confirmDialog, confirm] = useConfirm();
  const zonesListId = `zones-${editionId}`;

  return (
    <div className="space-y-4">
      {confirmDialog}
      <datalist id={zonesListId}>
        {zones.map((z) => (
          <option key={z} value={z} />
        ))}
      </datalist>

      {halls.length === 0 && (
        <div className="space-y-4 rounded-lg border border-dashed p-4 sm:p-5">
          <div className="flex items-start gap-3">
            <span className="bg-muted text-muted-foreground flex size-9 shrink-0 items-center justify-center rounded-full">
              <MapPin className="size-4" aria-hidden />
            </span>
            <div className="space-y-1">
              <p className="text-sm font-medium">No halls yet</p>
              <p className="text-muted-foreground text-sm">
                {canEdit
                  ? `Add the halls at ${venueName}, then the places inside each one where signs go (“Main entrance”, “Aisle A”).`
                  : (lockedReason ?? "Halls can't be added here.")}
              </p>
            </div>
          </div>
          {canEdit && copySources.length > 0 && (
            <CopyFromEvent editionId={editionId} venueName={venueName} sources={copySources} />
          )}
          {canEdit && <AddSeveral editionId={editionId} defaultOpen />}
          {canEdit && (
            <div className="space-y-1">
              <p className="text-muted-foreground text-xs">Or add one hall:</p>
              <AddHall editionId={editionId} />
            </div>
          )}
        </div>
      )}

      {halls.map((hall) => (
        <HallCard
          key={hall.id}
          hall={hall}
          editionCode={editionCode}
          canEdit={canEdit}
          zonesListId={zonesListId}
          confirm={confirm}
        />
      ))}

      {canEdit && halls.length > 0 && (
        <div className="space-y-3 rounded-lg border border-dashed p-4">
          <AddHall editionId={editionId} />
          <AddSeveral editionId={editionId} defaultOpen={false} />
        </div>
      )}
    </div>
  );
}
