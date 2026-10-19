"use client";

import { useId, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ChevronDown, ChevronRight } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import { cloneEdition, createEdition } from "@/app/actions/editions";
import {
  SAME_WEEKDAY_NEXT_YEAR,
  addDaysIso,
  assumedEventDates,
  datesLike,
  isIsoDate,
  type EventDates,
} from "@/lib/deadlines";
import { cn } from "@/lib/utils";
import { bumpYear, exampleSignRef, seriesNameFor, suggestCode } from "./naming";
import { dateRange, shortDate } from "./format";
import { copiedAccessCount, type CopyableGrant } from "@/lib/copy-access";

export type CopySource = {
  id: string;
  name: string;
  code: string;
  /** "UKCW Birmingham 2027 · NEC Birmingham · Oct 2027". */
  label: string;
  venueId: string;
  venueName: string;
  dates: EventDates;
  counts: {
    halls: number;
    locations: number;
    deadlines: number;
    sponsors: number;
    items: number;
    /** Partner grants a copy to the same venue could bring across (ended ones included). */
    access: number;
    /** Each of them, counted against the new dates and venue (copiedAccessCount). */
    accessGrants?: CopyableGrant[];
    accessLeftBehind: number;
    /** People who only see this event that the copier may give the copy too. */
    people?: number;
    /** People who only see this event outside the copier's scope (counted, never named). */
    peopleLeftOut?: number;
  };
};

type VenueOption = { id: string; name: string; address: string | null };
type SeriesOption = { id: string; name: string };
type Mode = "fresh" | "copy";
type Include = {
  halls: boolean;
  deadlines: boolean;
  sponsors: boolean;
  items: boolean;
  access: boolean;
  people: boolean;
};

function plural(n: number, one: string, many = `${one}s`) {
  return `${n} ${n === 1 ? one : many}`;
}

function FieldError({ id, error }: { id: string; error?: string }) {
  if (!error) return null;
  return (
    <p id={id} className="text-destructive text-sm">
      {error}
    </p>
  );
}

/** "Reference code LON27 · used in sign refs like SIG-LON27-001 · Change". */
function CodeLine({
  code,
  editing,
  onEdit,
  onChange,
  error,
}: {
  code: string;
  editing: boolean;
  onEdit: () => void;
  onChange: (code: string) => void;
  error?: string;
}) {
  const id = useId();
  if (!editing) {
    return (
      <div className="space-y-1">
        <p className="text-muted-foreground text-sm">
          Reference code{" "}
          <span className="text-foreground font-mono font-medium">{code || "—"}</span> · used in
          sign refs like <span className="font-mono">{exampleSignRef(code)}</span> ·{" "}
          <button type="button" className="link font-medium" onClick={onEdit}>
            Change
          </button>
        </p>
        <FieldError id={`${id}-error`} error={error} />
      </div>
    );
  }
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>Reference code</Label>
      <Input
        id={id}
        value={code}
        onChange={(e) => onChange(e.target.value.toUpperCase().replace(/[^A-Z0-9-]/g, ""))}
        maxLength={20}
        required
        autoFocus
        className="font-mono sm:max-w-48"
        aria-invalid={error ? true : undefined}
        aria-describedby={`${id}-help${error ? ` ${id}-error` : ""}`}
      />
      <p id={`${id}-help`} className="text-muted-foreground text-xs">
        Can&apos;t be changed once the event is created. Signs will be numbered{" "}
        <span className="font-mono">{exampleSignRef(code)}</span>, and so on.
      </p>
      <FieldError id={`${id}-error`} error={error} />
    </div>
  );
}

function DateFields({
  openStart,
  openEnd,
  onOpenStart,
  onOpenEnd,
  errors,
}: {
  openStart: string;
  openEnd: string;
  onOpenStart: (v: string) => void;
  onOpenEnd: (v: string) => void;
  errors: Record<string, string>;
}) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div className="space-y-1.5">
        <Label htmlFor="openStart">Opens to visitors</Label>
        <Input
          id="openStart"
          type="date"
          value={openStart}
          required
          onChange={(e) => onOpenStart(e.target.value)}
          aria-invalid={errors.openStart ? true : undefined}
        />
        <FieldError id="openStart-error" error={errors.openStart} />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="openEnd">Closes to visitors</Label>
        <Input
          id="openEnd"
          type="date"
          value={openEnd}
          min={openStart || undefined}
          required
          onChange={(e) => onOpenEnd(e.target.value)}
          aria-invalid={errors.openEnd ? true : undefined}
        />
        <FieldError id="openEnd-error" error={errors.openEnd ?? errors.breakdownEnd} />
      </div>
    </div>
  );
}

/**
 * "Create your event": the basics only (name, open dates, venue); the rest
 * is assumed and confirmed on the setup page. Or copy a previous event.
 */
export function CreateEventForm({
  initialMode,
  sources,
  venues,
  series,
  takenCodes,
  canCopyAccess,
  today,
}: {
  initialMode: Mode;
  sources: CopySource[];
  venues: VenueOption[];
  series: SeriesOption[];
  takenCodes: string[];
  canCopyAccess: boolean;
  /** Today in London, for which partners' access a copy brings across. */
  today: string;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [mode, setMode] = useState<Mode>(sources.length > 0 ? initialMode : "fresh");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  // Start fresh
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [codeTouched, setCodeTouched] = useState(false);
  const [editingCode, setEditingCode] = useState(false);
  const [openStart, setOpenStart] = useState("");
  const [openEnd, setOpenEnd] = useState("");
  const [venueChoice, setVenueChoice] = useState(venues.length === 1 ? venues[0].id : "");
  const [newVenueName, setNewVenueName] = useState("");
  const [newVenueAddress, setNewVenueAddress] = useState("");
  const [seriesOpen, setSeriesOpen] = useState(false);
  const [seriesChoice, setSeriesChoice] = useState("");
  const [newSeriesName, setNewSeriesName] = useState("");

  // Copy a previous event
  const first = sources[0];
  const [sourceId, setSourceId] = useState(first?.id ?? "");
  const [copyName, setCopyName] = useState(first ? bumpYear(first.name) : "");
  const [copyCode, setCopyCode] = useState("");
  const [copyCodeTouched, setCopyCodeTouched] = useState(false);
  const [editingCopyCode, setEditingCopyCode] = useState(false);
  const [copyOpenStart, setCopyOpenStart] = useState(
    first ? addDaysIso(first.dates.openStart, SAME_WEEKDAY_NEXT_YEAR) : "",
  );
  const [copyOpenEnd, setCopyOpenEnd] = useState(
    first ? addDaysIso(first.dates.openEnd, SAME_WEEKDAY_NEXT_YEAR) : "",
  );
  const [copyVenueId, setCopyVenueId] = useState(first?.venueId ?? "");
  const [include, setInclude] = useState<Include>({
    halls: true,
    deadlines: true,
    sponsors: true,
    items: true,
    access: true,
    people: true,
  });

  const source = sources.find((s) => s.id === sourceId) ?? first;
  const freshCode = codeTouched ? code : suggestCode(name, takenCodes);
  const copiedCode = copyCodeTouched ? copyCode : suggestCode(copyName, takenCodes);
  const chosenVenue = venues.find((v) => v.id === venueChoice);
  const seriesId = useId();

  function pickSource(id: string) {
    const s = sources.find((x) => x.id === id);
    setSourceId(id);
    if (!s) return;
    setCopyName(bumpYear(s.name));
    setCopyCodeTouched(false);
    setEditingCopyCode(false);
    setCopyOpenStart(addDaysIso(s.dates.openStart, SAME_WEEKDAY_NEXT_YEAR));
    setCopyOpenEnd(addDaysIso(s.dates.openEnd, SAME_WEEKDAY_NEXT_YEAR));
    setCopyVenueId(s.venueId);
    setInclude({
      halls: true,
      deadlines: true,
      sponsors: true,
      items: true,
      access: true,
      people: true,
    });
  }

  /** Closes follows Opens until it's set to something later. */
  function changeOpen(
    value: string,
    end: string,
    setStart: (v: string) => void,
    setEnd: (v: string) => void,
  ) {
    setStart(value);
    if (isIsoDate(value) && (!end || end < value)) setEnd(value);
  }

  function showErrors(res: { error: string; fieldErrors?: Record<string, string> }) {
    const fields = res.fieldErrors ?? {};
    setErrors(fields);
    if (fields.code) {
      if (mode === "fresh") setEditingCode(true);
      else setEditingCopyCode(true);
    }
    const shownInline = Object.keys(fields).some((k) =>
      ["name", "code", "openStart", "openEnd", "venueId", "breakdownEnd"].includes(k),
    );
    setFormError(shownInline ? null : res.error);
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setErrors({});
    setFormError(null);
    start(async () => {
      const res =
        mode === "fresh"
          ? await createEdition({
              name,
              code: freshCode,
              openStart,
              openEnd,
              venueId: venueChoice && venueChoice !== "new" ? venueChoice : null,
              newVenueName: venueChoice === "new" ? newVenueName : null,
              newVenueAddress: venueChoice === "new" ? newVenueAddress : null,
              eventId: seriesOpen && seriesChoice && seriesChoice !== "new" ? seriesChoice : null,
              newEventName: seriesOpen && seriesChoice === "new" ? newSeriesName : null,
            })
          : await cloneEdition({
              sourceEditionId: sourceId,
              name: copyName,
              code: copiedCode,
              openStart: copyOpenStart,
              openEnd: copyOpenEnd,
              venueId: copyVenueId || null,
              // A box that is disabled (nothing to bring) is never sent as ticked.
              include: {
                halls: include.halls && copyCounts.halls > 0,
                deadlines: include.deadlines && copyCounts.deadlines > 0,
                sponsors: include.sponsors && copyCounts.sponsors > 0,
                items: include.items && copyCounts.items > 0,
                access: canCopyAccess && include.access && copyCounts.access > 0,
                people: include.people && copyCounts.people > 0,
              },
            });
      if (!res.ok) {
        showErrors(res);
        return;
      }
      toast.success(res.message ?? "Event created");
      router.push(`/${res.data!.code}/setup`);
    });
  }

  const assumed =
    mode === "fresh"
      ? isIsoDate(openStart)
        ? assumedEventDates(openStart, isIsoDate(openEnd) ? openEnd : openStart)
        : null
      : source && isIsoDate(copyOpenStart)
        ? datesLike(
            source.dates,
            copyOpenStart,
            isIsoDate(copyOpenEnd) ? copyOpenEnd : copyOpenStart,
          )
        : null;

  const venueOptions =
    mode === "copy" && source && !venues.some((v) => v.id === source.venueId)
      ? [...venues, { id: source.venueId, name: source.venueName, address: null }]
      : venues;
  const differentVenue = mode === "copy" && source && copyVenueId !== source.venueId;
  // What each box would bring across with the dates and venue chosen now —
  // the same rule cloneEdition applies to partner access.
  const copyCounts: Record<keyof Include, number> = {
    halls: source?.counts.halls ?? 0,
    deadlines: source?.counts.deadlines ?? 0,
    sponsors: source?.counts.sponsors ?? 0,
    items: source?.counts.items ?? 0,
    access: source
      ? source.counts.accessGrants
        ? copiedAccessCount(source.counts.accessGrants, {
            breakdownEnd: mode === "copy" && assumed ? assumed.breakdownEnd : null,
            sameVenue: !differentVenue,
            today,
          })
        : source.counts.access
      : 0,
    people: source?.counts.people ?? 0,
  };

  return (
    <form onSubmit={submit} className="flex flex-col gap-6">
      {sources.length > 0 && (
        <SegmentGroup label="How to start" className="w-full sm:w-fit">
          {(
            [
              ["fresh", "Start fresh"],
              ["copy", "Copy a previous event"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              aria-pressed={mode === value}
              className={cn(segmentClass(mode === value), "flex-1 justify-center sm:flex-none")}
              onClick={() => {
                setMode(value);
                setErrors({});
                setFormError(null);
              }}
            >
              {label}
            </button>
          ))}
        </SegmentGroup>
      )}

      {mode === "fresh" ? (
        <div className="flex flex-col gap-5">
          <div className="space-y-1.5">
            <Label htmlFor="event-name">Event name</Label>
            <Input
              id="event-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. UKCW London 2027"
              required
              maxLength={200}
              autoFocus
              aria-invalid={errors.name ? true : undefined}
            />
            <FieldError id="name-error" error={errors.name} />
          </div>

          <div className="space-y-2">
            <DateFields
              openStart={openStart}
              openEnd={openEnd}
              onOpenStart={(v) => changeOpen(v, openEnd, setOpenStart, setOpenEnd)}
              onOpenEnd={setOpenEnd}
              errors={errors}
            />
            {assumed && (
              <p className="text-muted-foreground text-sm">
                We&apos;ve assumed build-up {dateRange(assumed.buildStart, assumed.buildEnd)} and
                breakdown ending {shortDate(assumed.breakdownEnd)} — change them in the next step.
              </p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="venue">Venue</Label>
            <SelectNative
              id="venue"
              value={venueChoice}
              required
              onChange={(e) => setVenueChoice(e.target.value)}
              aria-invalid={errors.venueId ? true : undefined}
            >
              <option value="" disabled>
                Choose…
              </option>
              {venues.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
              <option value="new">Add a new venue…</option>
            </SelectNative>
            {chosenVenue?.address && (
              <p className="text-muted-foreground text-xs">{chosenVenue.address}</p>
            )}
            <FieldError id="venue-error" error={errors.venueId} />
            {venueChoice === "new" && (
              <div className="grid gap-3 rounded-md border p-3">
                <div className="space-y-1.5">
                  <Label htmlFor="new-venue-name">Venue name</Label>
                  <Input
                    id="new-venue-name"
                    value={newVenueName}
                    onChange={(e) => setNewVenueName(e.target.value)}
                    placeholder="e.g. ExCeL London"
                    required
                    maxLength={200}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="new-venue-address">Address (optional)</Label>
                  <Textarea
                    id="new-venue-address"
                    value={newVenueAddress}
                    onChange={(e) => setNewVenueAddress(e.target.value)}
                    className="min-h-16"
                    maxLength={500}
                  />
                </div>
              </div>
            )}
          </div>

          <CodeLine
            code={freshCode}
            editing={editingCode}
            onEdit={() => {
              setCode(freshCode);
              setCodeTouched(true);
              setEditingCode(true);
            }}
            onChange={(v) => {
              setCodeTouched(true);
              setCode(v);
            }}
            error={errors.code}
          />

          <div className="rounded-md border">
            <button
              type="button"
              className="flex w-full items-center gap-2 px-3 py-2.5 text-left text-sm font-medium"
              aria-expanded={seriesOpen}
              aria-controls={seriesId}
              onClick={() => setSeriesOpen((o) => !o)}
            >
              {seriesOpen ? (
                <ChevronDown className="size-4" aria-hidden />
              ) : (
                <ChevronRight className="size-4" aria-hidden />
              )}
              Part of a recurring event series?
              <span className="text-muted-foreground ml-auto truncate text-xs font-normal">
                {seriesOpen ? "" : "Optional"}
              </span>
            </button>
            {seriesOpen && (
              <div id={seriesId} className="space-y-3 border-t p-3">
                <div className="space-y-1.5">
                  <Label htmlFor="series">Event series</Label>
                  <SelectNative
                    id="series"
                    value={seriesChoice}
                    onChange={(e) => setSeriesChoice(e.target.value)}
                  >
                    <option value="">
                      Automatic{name.trim() ? ` — “${seriesNameFor(name)}”` : ""}
                    </option>
                    {series.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name}
                      </option>
                    ))}
                    <option value="new">New series…</option>
                  </SelectNative>
                  <p className="text-muted-foreground text-xs">
                    Events in a series (the same event each year) are easy to copy from one to the
                    next.
                  </p>
                </div>
                {seriesChoice === "new" && (
                  <div className="space-y-1.5">
                    <Label htmlFor="new-series">New series name</Label>
                    <Input
                      id="new-series"
                      value={newSeriesName}
                      onChange={(e) => setNewSeriesName(e.target.value)}
                      placeholder="e.g. UK Construction Week"
                      required
                      maxLength={200}
                    />
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      ) : (
        source && (
          <div className="flex flex-col gap-5">
            <div className="space-y-1.5">
              <Label htmlFor="copy-from">Copy from</Label>
              <SelectNative
                id="copy-from"
                value={sourceId}
                onChange={(e) => pickSource(e.target.value)}
              >
                {sources.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.label}
                  </option>
                ))}
              </SelectNative>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="copy-name">Event name</Label>
              <Input
                id="copy-name"
                value={copyName}
                onChange={(e) => setCopyName(e.target.value)}
                required
                maxLength={200}
                aria-invalid={errors.name ? true : undefined}
              />
              <FieldError id="copy-name-error" error={errors.name} />
            </div>

            <div className="space-y-2">
              <DateFields
                openStart={copyOpenStart}
                openEnd={copyOpenEnd}
                onOpenStart={(v) => changeOpen(v, copyOpenEnd, setCopyOpenStart, setCopyOpenEnd)}
                onOpenEnd={setCopyOpenEnd}
                errors={errors}
              />
              {assumed && (
                <p className="text-muted-foreground text-sm">
                  Build-up {dateRange(assumed.buildStart, assumed.buildEnd)} and breakdown ending{" "}
                  {shortDate(assumed.breakdownEnd)}, timed as last time — change them in the next
                  step.
                </p>
              )}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="copy-venue">Venue</Label>
              <SelectNative
                id="copy-venue"
                value={copyVenueId}
                onChange={(e) => {
                  setCopyVenueId(e.target.value);
                  // Halls belong to a venue: don't bring them to a different one by default.
                  setInclude((i) => ({ ...i, halls: e.target.value === source.venueId }));
                }}
              >
                {venueOptions.map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.name}
                  </option>
                ))}
              </SelectNative>
              {differentVenue && (
                <p className="text-muted-foreground text-xs">
                  {source.name} was at {source.venueName}, so its halls aren&apos;t ticked.
                </p>
              )}
            </div>

            <CodeLine
              code={copiedCode}
              editing={editingCopyCode}
              onEdit={() => {
                setCopyCode(copiedCode);
                setCopyCodeTouched(true);
                setEditingCopyCode(true);
              }}
              onChange={(v) => {
                setCopyCodeTouched(true);
                setCopyCode(v);
              }}
              error={errors.code}
            />

            <fieldset className="space-y-2">
              <legend className="mb-1 text-sm font-medium">Bring across</legend>
              {(
                [
                  [
                    "halls",
                    `Halls & locations (${plural(source.counts.halls, "hall")}, ${plural(source.counts.locations, "location")})`,
                    source.counts.halls,
                  ],
                  ["deadlines", `Deadlines (${source.counts.deadlines})`, source.counts.deadlines],
                  [
                    "sponsors",
                    `Sponsors & packages (${source.counts.sponsors})`,
                    source.counts.sponsors,
                  ],
                  [
                    "items",
                    `Signs and sponsorship items as drafts (${source.counts.items})`,
                    source.counts.items,
                  ],
                  ...(canCopyAccess
                    ? ([
                        [
                          "access",
                          `Portal access for the venue and suppliers (${copyCounts.access})`,
                          copyCounts.access,
                        ],
                      ] as const)
                    : []),
                  // Hidden when nobody qualifies (it's about people, not records).
                  ...(copyCounts.people > 0
                    ? ([
                        [
                          "people",
                          `People who only see ${source.code} — give them the new event too (${copyCounts.people})`,
                          copyCounts.people,
                        ],
                      ] as const)
                    : []),
                ] as const
              ).map(([key, label, n]) => (
                <label
                  key={key}
                  className={cn(
                    "flex items-start gap-2.5 py-0.5 text-sm",
                    n === 0 && "text-muted-foreground",
                  )}
                >
                  <input
                    type="checkbox"
                    className="mt-0.5 size-4 shrink-0"
                    checked={include[key] && n > 0}
                    disabled={n === 0}
                    onChange={(e) => setInclude((i) => ({ ...i, [key]: e.target.checked }))}
                  />
                  <span>{label}</span>
                </label>
              ))}
              {canCopyAccess && source.counts.accessLeftBehind > 0 && (
                <p className="text-muted-foreground text-xs">
                  {plural(
                    source.counts.accessLeftBehind,
                    "sponsor or exhibitor login",
                    "sponsor and exhibitor logins",
                  )}{" "}
                  stay with {source.name}: their records are new for each event, so invite them
                  again once they&apos;re added.
                </p>
              )}
              {(source.counts.peopleLeftOut ?? 0) > 0 && (
                <p className="text-muted-foreground text-xs">
                  {source.counts.peopleLeftOut} more{" "}
                  {source.counts.peopleLeftOut === 1 ? "person" : "people"} who only see{" "}
                  {source.code} won&apos;t see the copy — a super admin can add it under Users.
                </p>
              )}
              <p className="text-muted-foreground text-xs">
                Artwork, sign-offs, actual costs and PO numbers always start fresh.
              </p>
            </fieldset>
          </div>
        )
      )}

      {formError && (
        <p className="text-destructive text-sm" role="alert">
          {formError}
        </p>
      )}

      <div className="bg-background fixed inset-x-0 bottom-0 z-30 border-t p-4 sm:static sm:z-auto sm:border-0 sm:bg-transparent sm:p-0">
        <Button type="submit" className="w-full sm:w-auto" size="lg" disabled={pending}>
          {pending ? "Creating…" : mode === "fresh" ? "Create event" : "Copy event"}
        </Button>
      </div>
    </form>
  );
}
