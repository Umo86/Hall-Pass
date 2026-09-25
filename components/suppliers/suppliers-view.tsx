"use client";

import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Mail, Phone, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { deleteSupplier, saveSupplier } from "@/app/actions/suppliers";

export type SupplierCard = {
  id: string;
  name: string;
  serviceIds: string[];
  contactName: string | null;
  email: string | null;
  phone: string | null;
  notes: string | null;
  itemCount: number;
};

export type ServiceOption = { id: string; name: string };

/** Suppliers: who they are, what they do, and how to reach them. */
export function SuppliersView({
  suppliers,
  services,
  canEdit,
}: {
  suppliers: SupplierCard[];
  services: ServiceOption[];
  canEdit: boolean;
}) {
  const [q, setQ] = useState("");
  const [service, setService] = useState("");
  const [editing, setEditing] = useState<SupplierCard | "new" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const serviceName = new Map(services.map((s) => [s.id, s.name]));
  const current = editing === "new" ? null : editing;

  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return suppliers.filter(
      (s) =>
        (!service || s.serviceIds.includes(service)) &&
        (!needle ||
          [s.name, s.contactName ?? "", s.email ?? ""].join(" ").toLowerCase().includes(needle)),
    );
  }, [suppliers, q, service]);

  function open(row: SupplierCard | "new") {
    setError(null);
    setEditing(row);
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <Input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search by name or contact…"
          className="h-9 w-full sm:w-64"
          aria-label="Search suppliers"
        />
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Filter by service">
          <button
            type="button"
            onClick={() => setService("")}
            className={`rounded-full border px-3 py-1 text-xs ${!service ? "bg-foreground text-background" : "hover:bg-muted"}`}
          >
            All
          </button>
          {services.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => setService(service === s.id ? "" : s.id)}
              className={`rounded-full border px-3 py-1 text-xs ${service === s.id ? "bg-foreground text-background" : "hover:bg-muted"}`}
            >
              {s.name}
            </button>
          ))}
        </div>
        {canEdit && (
          <Button size="sm" className="ml-auto" onClick={() => open("new")}>
            <Plus className="size-4" /> Add supplier
          </Button>
        )}
      </div>

      {shown.length === 0 ? (
        <div className="text-muted-foreground flex h-32 items-center justify-center rounded-lg border border-dashed text-sm">
          {suppliers.length === 0 ? "No suppliers yet." : "No suppliers match."}
        </div>
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {shown.map((s) => (
            <li key={s.id} className="flex flex-col gap-2 rounded-lg border p-4">
              <div className="flex items-start justify-between gap-2">
                <p className="font-semibold">{s.name}</p>
                {canEdit && (
                  <Button size="sm" variant="outline" onClick={() => open(s)}>
                    Edit
                  </Button>
                )}
              </div>
              <div className="flex flex-wrap gap-1">
                {s.serviceIds.length === 0 ? (
                  <span className="text-muted-foreground text-xs">No services ticked yet</span>
                ) : (
                  s.serviceIds.map((id) => (
                    <span key={id} className="bg-muted rounded-full px-2 py-0.5 text-xs">
                      {serviceName.get(id) ?? "—"}
                    </span>
                  ))
                )}
              </div>
              <div className="text-muted-foreground space-y-0.5 text-sm">
                {s.contactName && <p>{s.contactName}</p>}
                {s.email && (
                  <p className="flex items-center gap-1.5">
                    <Mail className="size-3.5" aria-hidden />
                    <a href={`mailto:${s.email}`} className="hover:underline">
                      {s.email}
                    </a>
                  </p>
                )}
                {s.phone && (
                  <p className="flex items-center gap-1.5">
                    <Phone className="size-3.5" aria-hidden />
                    <a href={`tel:${s.phone}`} className="hover:underline">
                      {s.phone}
                    </a>
                  </p>
                )}
              </div>
              {s.notes && <p className="text-muted-foreground text-xs">{s.notes}</p>}
              <p className="text-muted-foreground mt-auto text-xs">
                Supplier on {s.itemCount} item{s.itemCount === 1 ? "" : "s"}
              </p>
            </li>
          ))}
        </ul>
      )}
      {canEdit && (
        <p className="text-muted-foreground text-xs">
          The list of services is managed under{" "}
          <Link href="/settings?tab=services" className="underline">
            Settings → Supplier services
          </Link>
          .
        </p>
      )}

      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{current ? `Edit ${current.name}` : "Add a supplier"}</DialogTitle>
            <DialogDescription>Tick everything this company can do for you.</DialogDescription>
          </DialogHeader>
          <form
            id="supplier-form"
            className="grid gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const fd = new FormData(e.currentTarget);
              setError(null);
              start(async () => {
                const res = await saveSupplier({
                  id: current?.id,
                  name: fd.get("name"),
                  serviceIds: fd.getAll("serviceIds"),
                  contactName: fd.get("contactName"),
                  email: fd.get("email"),
                  phone: fd.get("phone"),
                  notes: fd.get("notes"),
                });
                if (!res.ok) setError(res.error);
                else {
                  setEditing(null);
                  router.refresh();
                }
              });
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="sup-name">Company name</Label>
              <Input id="sup-name" name="name" required defaultValue={current?.name ?? ""} />
            </div>
            <fieldset className="space-y-1.5">
              <legend className="text-sm font-medium">What they do</legend>
              <div className="grid gap-1.5 sm:grid-cols-2">
                {services.map((s) => (
                  <label key={s.id} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      name="serviceIds"
                      value={s.id}
                      className="size-4"
                      defaultChecked={current?.serviceIds.includes(s.id) ?? false}
                    />
                    {s.name}
                  </label>
                ))}
              </div>
            </fieldset>
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="sup-contact">Contact name</Label>
                <Input
                  id="sup-contact"
                  name="contactName"
                  defaultValue={current?.contactName ?? ""}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sup-phone">Phone</Label>
                <Input id="sup-phone" name="phone" defaultValue={current?.phone ?? ""} />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sup-email">Email</Label>
              <Input id="sup-email" name="email" type="email" defaultValue={current?.email ?? ""} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sup-notes">Notes</Label>
              <Textarea id="sup-notes" name="notes" defaultValue={current?.notes ?? ""} />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
          </form>
          <DialogFooter className="gap-2">
            {current && (
              <Button
                variant="ghost"
                className="sm:mr-auto"
                disabled={pending}
                onClick={() => {
                  if (!window.confirm(`Remove ${current.name}?`)) return;
                  setError(null);
                  start(async () => {
                    const res = await deleteSupplier({ id: current.id });
                    if (!res.ok) setError(res.error);
                    else {
                      setEditing(null);
                      router.refresh();
                    }
                  });
                }}
              >
                Remove
              </Button>
            )}
            <Button variant="outline" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button type="submit" form="supplier-form" disabled={pending}>
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
