"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import {
  cloneEdition,
  createEdition,
  removeShowLogo,
  updateEdition,
  uploadShowLogo,
} from "@/app/actions/editions";
import { Textarea } from "@/components/ui/textarea";

type EventOption = { id: string; name: string };
type VenueOption = { id: string; name: string; address?: string | null };
type EditionOption = { id: string; code: string; name: string };

function DateField({
  label,
  name,
  defaultValue,
}: {
  label: string;
  name: string;
  defaultValue?: string;
}) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={name}>{label}</Label>
      <Input id={name} name={name} type="date" defaultValue={defaultValue} required />
    </div>
  );
}

/** Suggest a short code from a show name: "UKCW London 2027" → "UKCWLON27". */
export function suggestCode(name: string): string {
  const words = name.toUpperCase().match(/[A-Z0-9]+/g) ?? [];
  const year = words.find((w) => /^\d{4}$/.test(w));
  const letters = words
    .filter((w) => w !== year)
    .map((w) => (w.length <= 4 ? w : w.slice(0, 3)))
    .join("");
  return `${letters.slice(0, 12)}${year ? year.slice(2) : ""}`;
}

async function sendLogo(editionId: string, file: File | null): Promise<string | null> {
  if (!file || file.size === 0) return null;
  const fd = new FormData();
  fd.set("editionId", editionId);
  fd.set("file", file);
  const res = await uploadShowLogo(fd);
  return res.ok ? null : res.error;
}

export function CreateEditionDialog({
  events,
  venues,
}: {
  events: EventOption[];
  venues: VenueOption[];
}) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [eventChoice, setEventChoice] = useState(events[0]?.id ?? "new");
  const [venueChoice, setVenueChoice] = useState(venues[0]?.id ?? "new");
  const [code, setCode] = useState("");
  const [codeTouched, setCodeTouched] = useState(false);
  const router = useRouter();
  const chosenVenue = venues.find((v) => v.id === venueChoice);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>New show</Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>New show</DialogTitle>
          <DialogDescription>
            One show at one venue, with its own signage, sign-offs and deadlines.
          </DialogDescription>
        </DialogHeader>
        <form
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            const logo = fd.get("logo");
            fd.delete("logo");
            if (fd.get("eventId") === "new") fd.delete("eventId");
            if (fd.get("venueId") === "new") fd.delete("venueId");
            setError(null);
            start(async () => {
              const res = await createEdition(Object.fromEntries(fd.entries()));
              if (!res.ok) {
                setError(res.error);
                return;
              }
              const logoError = await sendLogo(res.data!.id, logo instanceof File ? logo : null);
              setOpen(false);
              router.push(
                `/${res.data?.code}/dashboard${logoError ? `?notice=${encodeURIComponent(logoError)}` : ""}`,
              );
            });
          }}
        >
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-[1fr_9rem]">
            <div className="space-y-1.5">
              <Label htmlFor="name">Show name</Label>
              <Input
                id="name"
                name="name"
                placeholder="UKCW London 2027"
                required
                onChange={(e) => {
                  if (!codeTouched) setCode(suggestCode(e.target.value));
                }}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="code">Short code</Label>
              <Input
                id="code"
                name="code"
                placeholder="LON27"
                required
                value={code}
                onChange={(e) => {
                  setCodeTouched(true);
                  setCode(e.target.value.toUpperCase());
                }}
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="eventId">Show series</Label>
            <SelectNative
              id="eventId"
              name="eventId"
              value={eventChoice}
              onChange={(e) => setEventChoice(e.target.value)}
            >
              {events.map((ev) => (
                <option key={ev.id} value={ev.id}>
                  {ev.name}
                </option>
              ))}
              <option value="new">+ New series…</option>
            </SelectNative>
            {eventChoice === "new" && (
              <Input
                name="newEventName"
                placeholder="e.g. UK Construction Week"
                aria-label="New series name"
                required
              />
            )}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="venueId">Venue</Label>
            <SelectNative
              id="venueId"
              name="venueId"
              value={venueChoice}
              onChange={(e) => setVenueChoice(e.target.value)}
            >
              {venues.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
              <option value="new">+ New venue…</option>
            </SelectNative>
            {venueChoice === "new" ? (
              <div className="grid gap-2">
                <Input
                  name="newVenueName"
                  placeholder="Venue name"
                  aria-label="New venue name"
                  required
                />
                <Textarea
                  name="newVenueAddress"
                  placeholder="Address"
                  aria-label="Venue address"
                  className="min-h-16"
                />
              </div>
            ) : (
              chosenVenue?.address && (
                <p className="text-muted-foreground text-xs">{chosenVenue.address}</p>
              )
            )}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="logo">Logo (optional)</Label>
            <input
              id="logo"
              name="logo"
              type="file"
              accept="image/png,image/jpeg,image/webp,image/svg+xml,image/gif"
              className="block w-full text-sm file:mr-3 file:rounded-md file:border file:bg-transparent file:px-3 file:py-1.5 file:text-sm"
            />
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <DateField label="Build starts" name="buildStart" />
            <DateField label="Build ends" name="buildEnd" />
            <DateField label="Show opens" name="openStart" />
            <DateField label="Show closes" name="openEnd" />
            <DateField label="Breakdown ends" name="breakdownEnd" />
            <div className="space-y-1.5">
              <Label htmlFor="signageBudget">Signage budget (£)</Label>
              <Input id="signageBudget" name="signageBudget" type="number" min="0" />
            </div>
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending}>
              {pending ? "Creating…" : "Create show"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

export function CloneEditionDialog({ editions }: { editions: EditionOption[] }) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline">Copy a show</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Copy a show</DialogTitle>
          <DialogDescription>
            Starts next year&apos;s show from this one: halls, locations, deadlines, logo and
            signage come across as drafts. Artwork, sign-offs, actual costs and PO numbers are
            cleared.
          </DialogDescription>
        </DialogHeader>
        <form
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            setError(null);
            start(async () => {
              const res = await cloneEdition(Object.fromEntries(fd.entries()));
              if (!res.ok) setError(res.error);
              else {
                setOpen(false);
                router.push(`/${res.data?.code}/dashboard`);
              }
            });
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor="sourceEditionId">Copy from</Label>
            <select
              id="sourceEditionId"
              name="sourceEditionId"
              className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
              required
            >
              {editions.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.code} — {e.name}
                </option>
              ))}
            </select>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="clone-name">New name</Label>
              <Input id="clone-name" name="name" required />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="clone-code">New code</Label>
              <Input id="clone-code" name="code" required />
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <DateField label="Build starts" name="buildStart" />
            <DateField label="Build ends" name="buildEnd" />
            <DateField label="Show opens" name="openStart" />
            <DateField label="Show closes" name="openEnd" />
            <DateField label="Breakdown ends" name="breakdownEnd" />
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending}>
              Copy show
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

export type EditableEdition = {
  id: string;
  code: string;
  name: string;
  status: string;
  buildStart: string;
  buildEnd: string;
  openStart: string;
  openEnd: string;
  breakdownEnd: string;
  signageBudget: string | null;
  venueId: string;
  logoUrl: string | null;
};

export function EditEditionDialog({
  edition,
  canArchive,
  venues = [],
}: {
  edition: EditableEdition;
  canArchive: boolean;
  venues?: VenueOption[];
}) {
  const [venueId, setVenueId] = useState(edition.venueId);
  const venueAddress = venues.find((v) => v.id === venueId)?.address ?? "";
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const archived = edition.status === "archived";

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit {edition.code}</DialogTitle>
          <DialogDescription>
            {archived
              ? "This show is archived and read-only. An admin can un-archive it."
              : "Deadlines move automatically with the build start date."}
          </DialogDescription>
        </DialogHeader>
        <form
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            const status = String(fd.get("status"));
            if (
              status === "archived" &&
              !archived &&
              !window.confirm(`Archive ${edition.code}? It becomes read-only for everyone.`)
            ) {
              return;
            }
            const logo = fd.get("logo");
            fd.delete("logo");
            setError(null);
            start(async () => {
              const res = await updateEdition({
                ...Object.fromEntries(fd.entries()),
                id: edition.id,
              });
              if (!res.ok) {
                setError(res.error);
                return;
              }
              const logoError = await sendLogo(edition.id, logo instanceof File ? logo : null);
              if (logoError) {
                setError(logoError);
                router.refresh();
                return;
              }
              setOpen(false);
              router.refresh();
            });
          }}
        >
          <fieldset disabled={archived} className="grid gap-3">
            <div className="space-y-1.5">
              <Label htmlFor={`name-${edition.id}`}>Show name</Label>
              <Input id={`name-${edition.id}`} name="name" defaultValue={edition.name} required />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`logo-${edition.id}`}>Logo</Label>
              <div className="flex flex-wrap items-center gap-3">
                {edition.logoUrl && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={edition.logoUrl}
                    alt={`${edition.name} logo`}
                    className="h-12 w-auto max-w-32 rounded border object-contain"
                  />
                )}
                <input
                  id={`logo-${edition.id}`}
                  name="logo"
                  type="file"
                  accept="image/png,image/jpeg,image/webp,image/svg+xml,image/gif"
                  className="block min-w-0 flex-1 text-sm file:mr-3 file:rounded-md file:border file:bg-transparent file:px-3 file:py-1.5 file:text-sm"
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
                        if (!res.ok) setError(res.error);
                        router.refresh();
                      })
                    }
                  >
                    Remove logo
                  </Button>
                )}
              </div>
            </div>
            {venues.length > 0 && (
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label htmlFor={`venue-${edition.id}`}>Venue</Label>
                  <SelectNative
                    id={`venue-${edition.id}`}
                    name="venueId"
                    value={venueId}
                    onChange={(e) => setVenueId(e.target.value)}
                  >
                    {venues.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.name}
                      </option>
                    ))}
                  </SelectNative>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor={`address-${edition.id}`}>Venue address</Label>
                  <Textarea
                    key={venueId}
                    id={`address-${edition.id}`}
                    name="venueAddress"
                    defaultValue={venueAddress}
                    className="min-h-16"
                  />
                </div>
              </div>
            )}
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <DateField label="Build starts" name="buildStart" defaultValue={edition.buildStart} />
              <DateField label="Build ends" name="buildEnd" defaultValue={edition.buildEnd} />
              <DateField label="Show opens" name="openStart" defaultValue={edition.openStart} />
              <DateField label="Show closes" name="openEnd" defaultValue={edition.openEnd} />
              <DateField
                label="Breakdown ends"
                name="breakdownEnd"
                defaultValue={edition.breakdownEnd}
              />
              <div className="space-y-1.5">
                <Label htmlFor={`budget-${edition.id}`}>Signage budget (£)</Label>
                <Input
                  id={`budget-${edition.id}`}
                  name="signageBudget"
                  type="number"
                  min="0"
                  defaultValue={edition.signageBudget ?? ""}
                />
              </div>
            </div>
          </fieldset>
          {/* Hidden copies so an archived show can still be un-archived. */}
          {archived && (
            <>
              <input type="hidden" name="name" value={edition.name} />
              <input type="hidden" name="buildStart" value={edition.buildStart} />
              <input type="hidden" name="buildEnd" value={edition.buildEnd} />
              <input type="hidden" name="openStart" value={edition.openStart} />
              <input type="hidden" name="openEnd" value={edition.openEnd} />
              <input type="hidden" name="breakdownEnd" value={edition.breakdownEnd} />
            </>
          )}
          <div className="space-y-1.5">
            <Label htmlFor={`status-${edition.id}`}>Status</Label>
            <SelectNative
              id={`status-${edition.id}`}
              name="status"
              defaultValue={edition.status}
              disabled={archived && !canArchive}
            >
              <option value="planning">Planning</option>
              <option value="live">Live</option>
              <option value="closed">Closed</option>
              {(canArchive || archived) && <option value="archived">Archived (read-only)</option>}
            </SelectNative>
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending || (archived && !canArchive)}>
              Save
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
