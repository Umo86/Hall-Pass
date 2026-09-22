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
import { createEdition, cloneEdition } from "@/app/actions/editions";

type EventOption = { id: string; name: string };
type VenueOption = { id: string; name: string };
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
  const router = useRouter();

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>New edition</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New edition</DialogTitle>
          <DialogDescription>
            An edition is one show at one venue, with its own schedule and deadlines.
          </DialogDescription>
        </DialogHeader>
        <form
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            setError(null);
            start(async () => {
              const res = await createEdition(Object.fromEntries(fd.entries()));
              if (!res.ok) setError(res.error);
              else {
                setOpen(false);
                router.push(`/${res.data?.code}/dashboard`);
              }
            });
          }}
        >
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="eventId">Event</Label>
              <select
                id="eventId"
                name="eventId"
                className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                required
              >
                {events.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="venueId">Venue</Label>
              <select
                id="venueId"
                name="venueId"
                className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                required
              >
                {venues.map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="name">Name</Label>
              <Input id="name" name="name" placeholder="UKCW London 2027" required />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="code">Code</Label>
              <Input id="code" name="code" placeholder="LON27" required />
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <DateField label="Build start" name="buildStart" />
            <DateField label="Build end" name="buildEnd" />
            <DateField label="Open start" name="openStart" />
            <DateField label="Open end" name="openEnd" />
            <DateField label="Breakdown ends" name="breakdownEnd" />
            <div className="space-y-1.5">
              <Label htmlFor="signageBudget">Signage budget (£)</Label>
              <Input id="signageBudget" name="signageBudget" type="number" min="0" />
            </div>
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending}>
              Create edition
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
        <Button variant="outline">Clone edition</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Clone an edition</DialogTitle>
          <DialogDescription>
            Copies halls, locations, deadline offsets and signage items as drafts. Artwork,
            approvals, actual costs and PO numbers are cleared. New code and dates are required.
          </DialogDescription>
        </DialogHeader>
        <form
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            setError(null);
            start(async () => {
              const res = await cloneEdition({
                ...Object.fromEntries(fd.entries()),
                includeExhibitors: fd.get("includeExhibitors") === "on",
              });
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
            <DateField label="Build start" name="buildStart" />
            <DateField label="Build end" name="buildEnd" />
            <DateField label="Open start" name="openStart" />
            <DateField label="Open end" name="openEnd" />
            <DateField label="Breakdown ends" name="breakdownEnd" />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="includeExhibitors" className="size-4" />
            Also copy exhibitors
          </label>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending}>
              Clone
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
