"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { FileInput } from "@/components/ui/file-input";
import { removeShowLogo, saveEventDetails, uploadShowLogo } from "@/app/actions/editions";
import { EVENT_DATE_LABELS, type EventDates } from "@/lib/deadlines";
import { useSetup } from "./setup-checklist";

type VenueOption = { id: string; name: string; address: string | null };
type SeriesOption = { id: string; name: string };

export type DetailsFormEdition = EventDates & {
  id: string;
  name: string;
  signageBudget: string | null;
  venueId: string;
  eventId: string;
  logoUrl: string | null;
};

const DATE_KEYS: Array<keyof EventDates> = [
  "buildStart",
  "buildEnd",
  "openStart",
  "openEnd",
  "breakdownEnd",
];

const LOGO_ACCEPT = "image/png,image/jpeg,image/webp,image/svg+xml,image/gif";

/**
 * Setup step 1: name, the five dates, venue (address shared by every event
 * there), logo, signage budget and series. "Save and continue" marks it done.
 */
export function EventDetailsForm({
  edition,
  venues,
  series,
  confirmed,
}: {
  edition: DetailsFormEdition;
  venues: VenueOption[];
  series: SeriesOption[];
  /** Already saved once: the button just says Save. */
  confirmed: boolean;
}) {
  const router = useRouter();
  const { setBuildStart, advance } = useSetup();
  const [pending, start] = useTransition();
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [name, setName] = useState(edition.name);
  const [dates, setDates] = useState<EventDates>({
    buildStart: edition.buildStart,
    buildEnd: edition.buildEnd,
    openStart: edition.openStart,
    openEnd: edition.openEnd,
    breakdownEnd: edition.breakdownEnd,
  });
  const [venueId, setVenueId] = useState(edition.venueId);
  const [newVenueName, setNewVenueName] = useState("");
  const [addresses, setAddresses] = useState<Record<string, string>>(() =>
    Object.fromEntries(venues.map((v) => [v.id, v.address ?? ""])),
  );
  const [budget, setBudget] = useState(edition.signageBudget ?? "");
  const [seriesId, setSeriesId] = useState(edition.eventId);
  const [newSeriesName, setNewSeriesName] = useState("");
  const [logo, setLogo] = useState<File | null>(null);
  const venue = venues.find((v) => v.id === venueId);
  const addressKey = venueId === "new" ? "new" : venueId;

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setErrors({});
    setFormError(null);
    start(async () => {
      const res = await saveEventDetails({
        id: edition.id,
        name,
        ...dates,
        signageBudget: budget,
        venueId: venueId === "new" ? null : venueId,
        newVenueName: venueId === "new" ? newVenueName : null,
        venueAddress: addresses[addressKey] ?? "",
        eventId: seriesId === "new" ? null : seriesId,
        newEventName: seriesId === "new" ? newSeriesName : null,
      });
      if (!res.ok) {
        setErrors(res.fieldErrors ?? {});
        if (!res.fieldErrors || Object.keys(res.fieldErrors).every((k) => k === "form")) {
          setFormError(res.error);
        }
        return;
      }
      if (logo) {
        const fd = new FormData();
        fd.set("editionId", edition.id);
        fd.set("file", logo);
        const up = await uploadShowLogo(fd);
        if (!up.ok) {
          toast.error(`Details saved, but the logo wasn't: ${up.error}`);
          router.refresh();
          return;
        }
      }
      toast.success(res.message ?? "Saved");
      advance("details");
      router.refresh();
    });
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-5">
      <div className="space-y-1.5">
        <Label htmlFor="details-name">Event name</Label>
        <Input
          id="details-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          maxLength={200}
          aria-invalid={errors.name ? true : undefined}
        />
        {errors.name && <p className="text-destructive text-sm">{errors.name}</p>}
      </div>

      <fieldset className="space-y-2">
        <legend className="mb-1 text-sm font-medium">Dates</legend>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {DATE_KEYS.map((key) => (
            <div key={key} className="space-y-1.5">
              <Label htmlFor={`details-${key}`} className="font-normal">
                {EVENT_DATE_LABELS[key]}
              </Label>
              <Input
                id={`details-${key}`}
                type="date"
                required
                value={dates[key]}
                onChange={(e) => {
                  const value = e.target.value;
                  setDates((d) => ({ ...d, [key]: value }));
                  if (key === "buildStart") setBuildStart(value);
                }}
                aria-invalid={errors[key] ? true : undefined}
              />
              {errors[key] && <p className="text-destructive text-sm">{errors[key]}</p>}
            </div>
          ))}
        </div>
        <p className="text-muted-foreground text-xs">
          Deadlines are counted back from build-up starts, so they move with it.
        </p>
      </fieldset>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label htmlFor="details-venue">Venue</Label>
          <SelectNative
            id="details-venue"
            value={venueId}
            onChange={(e) => setVenueId(e.target.value)}
          >
            {venues.map((v) => (
              <option key={v.id} value={v.id}>
                {v.name}
              </option>
            ))}
            <option value="new">Add a new venue…</option>
          </SelectNative>
          {venueId === "new" && (
            <Input
              value={newVenueName}
              onChange={(e) => setNewVenueName(e.target.value)}
              placeholder="Venue name"
              aria-label="New venue name"
              required
              maxLength={200}
            />
          )}
          {errors.venueId && <p className="text-destructive text-sm">{errors.venueId}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="details-address">Venue address</Label>
          <Textarea
            id="details-address"
            value={addresses[addressKey] ?? ""}
            onChange={(e) => setAddresses((a) => ({ ...a, [addressKey]: e.target.value }))}
            className="min-h-16"
            maxLength={500}
            aria-describedby="details-address-help"
          />
          <p id="details-address-help" className="text-muted-foreground text-xs">
            {venueId === "new" || !venue
              ? "Saved with the new venue."
              : `Shared by every event at ${venue.name}.`}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label htmlFor="details-budget">Signage budget (£)</Label>
          <Input
            id="details-budget"
            type="number"
            inputMode="decimal"
            min="0"
            step="any"
            value={budget}
            onChange={(e) => setBudget(e.target.value)}
            placeholder="Optional"
            aria-invalid={errors.signageBudget ? true : undefined}
          />
          {errors.signageBudget && (
            <p className="text-destructive text-sm">{errors.signageBudget}</p>
          )}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="details-series">Event series</Label>
          <SelectNative
            id="details-series"
            value={seriesId}
            onChange={(e) => setSeriesId(e.target.value)}
          >
            {series.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
            <option value="new">New series…</option>
          </SelectNative>
          {seriesId === "new" && (
            <Input
              value={newSeriesName}
              onChange={(e) => setNewSeriesName(e.target.value)}
              placeholder="e.g. UK Construction Week"
              aria-label="New series name"
              required
              maxLength={200}
            />
          )}
        </div>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="details-logo">Logo (optional)</Label>
        <div className="flex flex-wrap items-center gap-3">
          {edition.logoUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={edition.logoUrl}
              alt={`${edition.name} logo`}
              className="h-12 w-auto max-w-32 rounded border object-contain p-1"
            />
          )}
          <FileInput
            id="details-logo"
            accept={LOGO_ACCEPT}
            buttonLabel={edition.logoUrl ? "Replace logo…" : "Choose logo…"}
            onFileChange={(files) => setLogo(files?.[0] ?? null)}
          />
          {edition.logoUrl && (
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={pending}
              onClick={() =>
                start(async () => {
                  const res = await removeShowLogo({ editionId: edition.id });
                  if (res.ok) toast.success(res.message ?? "Logo removed");
                  else toast.error(res.error);
                  router.refresh();
                })
              }
            >
              Remove logo
            </Button>
          )}
        </div>
        <p className="text-muted-foreground text-xs">
          Shown on the dashboard and exports. PNG, JPG, WebP, GIF or SVG up to 5 MB.
        </p>
      </div>

      {formError && (
        <p className="text-destructive text-sm" role="alert">
          {formError}
        </p>
      )}
      <div>
        <Button type="submit" disabled={pending} className="w-full sm:w-auto">
          {pending ? "Saving…" : confirmed ? "Save" : "Save and continue"}
        </Button>
      </div>
    </form>
  );
}
