"use client";

import { useId, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { parseAsString, useQueryState } from "nuqs";
import { Archive, KeyRound, Mail, Pencil, Phone, Plus, Search, Truck } from "lucide-react";
import { toast } from "sonner";
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
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { useConfirm } from "@/components/confirm-dialog";
import { ServicesEditor, type ServiceRow } from "@/components/settings/services-editor";
import { PortalAccessDialog, type PortalEvent } from "@/components/portal/portal-access";
import type { PortalGrant } from "@/components/portal/grants";
import { portalSummary } from "@/components/portal/summary";
import { deleteSupplier, saveSupplier, setSupplierArchived } from "@/app/actions/suppliers";
import { plural } from "@/lib/format";
import { matchesSupplier, servicesPreview } from "./rules";

export type SupplierRow = {
  id: string;
  name: string;
  serviceIds: string[];
  contactName: string | null;
  email: string | null;
  phone: string | null;
  notes: string | null;
  /** Live signs and sponsorship items on the current event. */
  itemsOnEvent: number;
  /** Live items on any event. */
  itemsTotal: number;
  isArchived: boolean;
  /** Whether it can be deleted outright (archived list only). */
  removal: { canDelete: boolean; reason: string | null; deletedItems: number };
  grants: PortalGrant[];
};

export type ServiceOption = { id: string; name: string; supplierCount: number };

const PAGE = 50;

/** Suppliers: who they are, what they do, how to reach them and who can sign in. */
export function SuppliersView({
  suppliers,
  services,
  serviceRows,
  canEdit,
  canEditServices = canEdit,
  canInvite,
  emailOn,
  currentEvent,
  inviteEvents,
  defaultEventId,
  tabs,
  openManage,
}: {
  suppliers: SupplierRow[];
  services: ServiceOption[];
  /** Every service including archived ones, for "Manage what they do". */
  serviceRows: ServiceRow[];
  canEdit: boolean;
  /** "Manage what they do" (lists.manage); defaults to canEdit. */
  canEditServices?: boolean;
  canInvite: boolean;
  emailOn: boolean;
  currentEvent: { code: string; name: string } | null;
  inviteEvents: PortalEvent[];
  defaultEventId: string | null;
  tabs: React.ReactNode;
  openManage: boolean;
}) {
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [service, setService] = useQueryState("service", parseAsString.withDefault(""));
  const [used, setUsed] = useQueryState("used", parseAsString.withDefault(""));
  const [limit, setLimit] = useState(PAGE);
  const [editing, setEditing] = useState<SupplierRow | "new" | null>(null);
  const [portalFor, setPortalFor] = useState<SupplierRow | null>(null);
  const [manageOpen, setManageOpen] = useState(openManage && canEditServices);
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  const live = suppliers.filter((s) => !s.isArchived);
  const archived = suppliers.filter((s) => s.isArchived);
  const onEvent = Boolean(currentEvent) && used === "event";
  const serviceName = new Map(services.map((s) => [s.id, s.name]));
  const serviceValue = services.some((s) => s.id === service) ? service : "";

  const shown = useMemo(
    () =>
      live.filter(
        (s) =>
          matchesSupplier(s, { q, serviceId: serviceValue }) && (!onEvent || s.itemsOnEvent > 0),
      ),
    [live, q, serviceValue, onEvent],
  );
  const filtered = Boolean(q.trim() || serviceValue || onEvent);
  const page = shown.slice(0, limit);

  function closeManage() {
    setManageOpen(false);
    if (params.get("manage")) {
      const next = new URLSearchParams(params.toString());
      next.delete("manage");
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    }
  }

  function clearFilters() {
    void setQ(null);
    void setService(null);
    void setUsed(null);
  }

  const itemsLink = (s: SupplierRow) =>
    currentEvent ? `/${currentEvent.code}/signage?supplier=${s.id}` : null;

  return (
    <>
      <PageHeader
        title="Suppliers"
        description="The companies you work with, what each one does and how to reach them."
        actions={
          (canEdit || canEditServices) && (
            <>
              {canEditServices && (
                <Button variant="outline" onClick={() => setManageOpen(true)}>
                  Manage what they do
                </Button>
              )}
              {canEdit && (
                <Button onClick={() => setEditing("new")}>
                  <Plus aria-hidden /> Add supplier
                </Button>
              )}
            </>
          )
        }
      />
      {tabs}

      <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
        <div className="relative w-full sm:w-64">
          <Search
            className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2"
            aria-hidden
          />
          <Input
            type="search"
            value={q}
            onChange={(e) => {
              setLimit(PAGE);
              void setQ(e.target.value || null);
            }}
            placeholder="Search name, contact, email…"
            className="h-11 pl-8 sm:h-9"
            aria-label="Search suppliers"
          />
        </div>
        <SelectNative
          value={serviceValue}
          onChange={(e) => {
            setLimit(PAGE);
            void setService(e.target.value || null);
          }}
          aria-label="What they do"
          className="h-11 w-full sm:h-9 sm:w-60"
        >
          <option value="">Everything they do</option>
          {services.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name} ({s.supplierCount})
            </option>
          ))}
        </SelectNative>
        {currentEvent && (
          <SegmentGroup label="Which suppliers" className="w-fit">
            <button
              type="button"
              aria-pressed={onEvent}
              className={segmentClass(onEvent)}
              onClick={() => {
                setLimit(PAGE);
                void setUsed("event");
              }}
            >
              Used on {currentEvent.code}
            </button>
            <button
              type="button"
              aria-pressed={!onEvent}
              className={segmentClass(!onEvent)}
              onClick={() => {
                setLimit(PAGE);
                void setUsed(null);
              }}
            >
              All
            </button>
          </SegmentGroup>
        )}
      </div>
      <p className="text-muted-foreground -mt-3 text-sm" aria-live="polite">
        {filtered
          ? `${plural(shown.length, "supplier")} of ${live.length}`
          : plural(live.length, "supplier")}
      </p>

      {live.length === 0 ? (
        <EmptyState
          icon={Truck}
          title="No suppliers yet"
          description="Add the companies you work with — printers, AV, staffing — and what each one does, so the right one is easy to pick on an item."
          action={
            canEdit && (
              <Button onClick={() => setEditing("new")}>
                <Plus aria-hidden /> Add supplier
              </Button>
            )
          }
        />
      ) : shown.length === 0 ? (
        <EmptyState
          icon={Search}
          title="No suppliers match"
          description={
            onEvent
              ? `None of these suppliers is on an item for ${currentEvent?.code} yet.`
              : "Try another name or clear the filters."
          }
          action={
            <Button variant="outline" onClick={clearFilters}>
              Clear filters
            </Button>
          }
        />
      ) : (
        <>
          <div className="hidden rounded-lg border sm:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Company</TableHead>
                  <TableHead>What they do</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Email / phone</TableHead>
                  <TableHead className="text-right">
                    {currentEvent ? `Items on ${currentEvent.code}` : "Items"}
                  </TableHead>
                  {canEdit && (
                    <TableHead className="w-12">
                      <span className="sr-only">Edit</span>
                    </TableHead>
                  )}
                </TableRow>
              </TableHeader>
              <TableBody>
                {page.map((s) => (
                  <TableRow key={s.id}>
                    <TableCell className="max-w-56 align-top">
                      <span className="block font-medium break-words">{s.name}</span>
                      {canEdit && <PortalLine supplier={s} onOpen={() => setPortalFor(s)} />}
                    </TableCell>
                    <TableCell className="align-top">
                      <ServiceTags ids={s.serviceIds} names={serviceName} />
                    </TableCell>
                    <TableCell className="align-top">
                      {s.contactName ?? <span className="text-muted-foreground">—</span>}
                    </TableCell>
                    <TableCell className="align-top">
                      <ContactLinks email={s.email} phone={s.phone} />
                    </TableCell>
                    <TableCell className="text-right align-top tabular-nums">
                      <ItemsCount supplier={s} href={itemsLink(s)} eventCode={currentEvent?.code} />
                    </TableCell>
                    {canEdit && (
                      <TableCell className="align-top">
                        <Button
                          size="icon"
                          variant="ghost"
                          onClick={() => setEditing(s)}
                          aria-label={`Edit ${s.name}`}
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

          <ul className="space-y-2 sm:hidden" aria-label="Suppliers">
            {page.map((s) => (
              <li key={s.id} className="space-y-2 rounded-lg border p-3">
                <div className="flex items-start justify-between gap-2">
                  <p className="pt-2 font-semibold break-words">{s.name}</p>
                  {canEdit && (
                    <Button
                      size="touch"
                      variant="ghost"
                      onClick={() => setEditing(s)}
                      aria-label={`Edit ${s.name}`}
                    >
                      <Pencil aria-hidden />
                    </Button>
                  )}
                </div>
                <ServiceTags ids={s.serviceIds} names={serviceName} max={6} />
                {s.contactName && <p className="text-sm">{s.contactName}</p>}
                {(s.email || s.phone) && <ContactLinks email={s.email} phone={s.phone} touch />}
                <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
                  <ItemsCount
                    supplier={s}
                    href={itemsLink(s)}
                    long
                    eventCode={currentEvent?.code}
                  />
                  {canEdit && <PortalLine supplier={s} onOpen={() => setPortalFor(s)} />}
                </div>
              </li>
            ))}
          </ul>
          {shown.length > limit && (
            <div className="flex justify-center">
              <Button variant="outline" onClick={() => setLimit((n) => n + PAGE)}>
                Show {Math.min(PAGE, shown.length - limit)} more ({shown.length - limit} not shown)
              </Button>
            </div>
          )}
        </>
      )}

      {canEdit && archived.length > 0 && <ArchivedSuppliers rows={archived} />}

      {canEdit && (
        <SupplierDialog
          key={editing === "new" ? "new" : (editing?.id ?? "closed")}
          current={editing}
          services={services}
          canInvite={canInvite}
          onClose={() => setEditing(null)}
          onPortal={(s) => {
            setEditing(null);
            setPortalFor(s);
          }}
        />
      )}
      {portalFor && (
        <PortalAccessDialog
          open
          onOpenChange={(o) => !o && setPortalFor(null)}
          scopeType="supplier"
          scopeId={portalFor.id}
          scopeName={portalFor.name}
          grants={suppliers.find((s) => s.id === portalFor.id)?.grants ?? portalFor.grants}
          events={inviteEvents}
          defaultEventId={defaultEventId}
          canInvite={canInvite}
          emailOn={emailOn}
        />
      )}
      <Dialog open={manageOpen} onOpenChange={(o) => !o && closeManage()}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>What suppliers do</DialogTitle>
            <DialogDescription>
              The kinds of work you tick on each supplier. Renaming one changes it on every
              supplier; archiving hides it until you restore it.
            </DialogDescription>
          </DialogHeader>
          <ServicesEditor rows={serviceRows} canEdit={canEditServices} />
        </DialogContent>
      </Dialog>
    </>
  );
}

function ServiceTags({
  ids,
  names,
  max = 3,
}: {
  ids: string[];
  names: Map<string, string>;
  max?: number;
}) {
  if (ids.length === 0) return <span className="text-muted-foreground text-xs">Not set</span>;
  const all = ids.map((id) => names.get(id) ?? "—");
  const { shown, more } = servicesPreview(all, max);
  return (
    <span className="flex flex-wrap gap-1" title={all.join(", ")}>
      {shown.map((n) => (
        <span key={n} className="bg-muted rounded-full px-2 py-0.5 text-xs">
          {n}
        </span>
      ))}
      {more > 0 && (
        <span className="text-muted-foreground px-1 py-0.5 text-xs" aria-label={`and ${more} more`}>
          +{more}
        </span>
      )}
    </span>
  );
}

function ContactLinks({
  email,
  phone,
  touch,
}: {
  email: string | null;
  phone: string | null;
  touch?: boolean;
}) {
  if (!email && !phone) return <span className="text-muted-foreground">—</span>;
  const cls = touch
    ? "inline-flex min-h-11 items-center gap-1.5 break-all hover:underline"
    : "inline-flex items-center gap-1.5 break-all hover:underline";
  return (
    <span className="flex flex-col text-sm">
      {email && (
        <a href={`mailto:${email}`} className={cls}>
          <Mail className="text-muted-foreground size-3.5 shrink-0" aria-hidden />
          {email}
        </a>
      )}
      {phone && (
        <a href={`tel:${phone.replace(/\s+/g, "")}`} className={cls}>
          <Phone className="text-muted-foreground size-3.5 shrink-0" aria-hidden />
          {phone}
        </a>
      )}
    </span>
  );
}

function ItemsCount({
  supplier,
  href,
  long,
  eventCode,
}: {
  supplier: SupplierRow;
  href: string | null;
  long?: boolean;
  eventCode?: string;
}) {
  const n = href ? supplier.itemsOnEvent : supplier.itemsTotal;
  const text = long ? `${plural(n, "item")}${eventCode ? ` on ${eventCode}` : ""}` : String(n);
  if (!href || n === 0) {
    return <span className={n === 0 ? "text-muted-foreground" : undefined}>{text}</span>;
  }
  return (
    <Link
      href={href}
      className="link"
      aria-label={`${plural(n, "item")} from ${supplier.name}${eventCode ? ` on ${eventCode}` : ""}`}
    >
      {text}
    </Link>
  );
}

/** "2 people can sign in · Manage" under a supplier that has portal access. */
function PortalLine({ supplier, onOpen }: { supplier: SupplierRow; onOpen: () => void }) {
  // Without access the row stays quiet; invite from the supplier's Edit dialog.
  if (supplier.grants.length === 0) return null;
  const summary = portalSummary(supplier.grants);
  return (
    <button
      type="button"
      onClick={onOpen}
      className="text-muted-foreground hover:text-foreground mt-0.5 inline-flex min-h-8 items-center gap-1.5 text-left text-xs"
      aria-label={`Portal access for ${supplier.name}: ${summary}. Manage`}
    >
      <KeyRound className="size-3.5 shrink-0" aria-hidden />
      <span>
        {summary}
        <span aria-hidden> · </span>
        <span className="link">Manage</span>
      </span>
    </button>
  );
}

/** Archived suppliers: restore, or delete when nothing ever used them. */
function ArchivedSuppliers({ rows }: { rows: SupplierRow[] }) {
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();

  function restore(s: SupplierRow) {
    start(async () => {
      const res = await setSupplierArchived({ id: s.id, archived: false });
      if (!res.ok) toast.error(res.error);
      else {
        toast.success(res.message ?? `${s.name} restored`);
        router.refresh();
      }
    });
  }

  async function remove(s: SupplierRow) {
    const ok = await confirm({
      title: `Delete ${s.name} for good?`,
      description:
        "Nothing uses this supplier, so it can be deleted. This can't be undone — archive keeps it out of the way instead.",
      confirmLabel: "Delete",
      destructive: true,
    });
    if (!ok) return;
    start(async () => {
      const res = await deleteSupplier({ id: s.id });
      if (!res.ok) toast.error(res.error);
      else {
        toast.success(res.message ?? `${s.name} deleted`);
        router.refresh();
      }
    });
  }

  return (
    <details className="group">
      <summary className="text-muted-foreground hover:text-foreground inline-flex min-h-11 cursor-pointer items-center gap-1.5 text-sm select-none sm:min-h-9">
        <Archive className="size-4" aria-hidden />
        Archived ({rows.length})
      </summary>
      <p className="text-muted-foreground mt-1 text-sm">
        Archived suppliers aren&rsquo;t offered on items. Items that already use them keep them.
      </p>
      <ul className="mt-2 divide-y rounded-lg border" aria-label="Archived suppliers">
        {rows.map((s) => (
          <li key={s.id} className="flex flex-wrap items-start justify-between gap-2 px-3 py-2">
            <div className="min-w-0 text-sm">
              <p className="font-medium break-words">{s.name}</p>
              {!s.removal.canDelete && s.removal.reason && (
                <p className="text-muted-foreground text-xs">
                  Can&rsquo;t be deleted: {s.removal.reason}
                  {s.removal.deletedItems > 0 && (
                    <>
                      {" "}
                      <Link href="/settings/recycle-bin" className="link">
                        Open the Recycle bin
                      </Link>
                    </>
                  )}
                </p>
              )}
            </div>
            <span className="flex gap-1">
              <Button
                size="sm"
                variant="outline"
                disabled={pending}
                onClick={() => restore(s)}
                aria-label={`Restore ${s.name}`}
              >
                Restore
              </Button>
              {s.removal.canDelete && (
                <Button
                  size="sm"
                  variant="ghost"
                  className="text-destructive hover:text-destructive"
                  disabled={pending}
                  onClick={() => remove(s)}
                  aria-label={`Delete ${s.name}`}
                >
                  Delete
                </Button>
              )}
            </span>
          </li>
        ))}
      </ul>
      {confirmDialog}
    </details>
  );
}

/** Add or edit a supplier: what they do, how to reach them; archive from here. */
function SupplierDialog({
  current: editing,
  services,
  canInvite,
  onClose,
  onPortal,
}: {
  current: SupplierRow | "new" | null;
  services: ServiceOption[];
  canInvite: boolean;
  onClose: () => void;
  onPortal: (s: SupplierRow) => void;
}) {
  const current = editing === "new" ? null : editing;
  const [checked, setChecked] = useState<Set<string>>(() => new Set(current?.serviceIds ?? []));
  const [extraServices, setExtraServices] = useState<string[]>([]);
  const [newService, setNewService] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const ids = useId();
  const errorId = `${ids}-error`;

  function addService() {
    const name = newService.trim().replace(/\s+/g, " ");
    if (!name) return;
    const known = services.find((sv) => sv.name.toLowerCase() === name.toLowerCase());
    if (known) {
      // Already on the list: just tick it.
      setChecked((c) => new Set(c).add(known.id));
    } else if (!extraServices.some((n) => n.toLowerCase() === name.toLowerCase())) {
      setExtraServices((x) => [...x, name]);
    }
    setNewService("");
  }

  async function archive(s: SupplierRow) {
    const ok = await confirm({
      title: `Archive ${s.name}?`,
      description: `It leaves the supplier list and the supplier choice on items.${
        s.itemsTotal > 0 ? ` The ${plural(s.itemsTotal, "item")} that use it keep it.` : ""
      } You can restore it from Archived at the bottom of the list.`,
      confirmLabel: "Archive",
    });
    if (!ok) return;
    setError(null);
    start(async () => {
      const res = await setSupplierArchived({ id: s.id, archived: true });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toast.success(res.message ?? `${s.name} archived`);
      onClose();
      router.refresh();
    });
  }

  return (
    <Dialog open={editing !== null} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto">
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
                serviceIds: [...checked],
                newServices: extraServices,
                contactName: fd.get("contactName"),
                email: fd.get("email"),
                phone: fd.get("phone"),
                notes: fd.get("notes"),
              });
              if (!res.ok) {
                setError(res.error);
                return;
              }
              toast.success(res.message ?? "Supplier saved");
              onClose();
              router.refresh();
            });
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor={`${ids}-name`}>Company name</Label>
            <Input
              id={`${ids}-name`}
              name="name"
              required
              maxLength={200}
              defaultValue={current?.name ?? ""}
              aria-describedby={error ? errorId : undefined}
              className="h-11 sm:h-9"
            />
          </div>
          <fieldset className="space-y-1.5">
            <legend className="text-sm font-medium">What they do</legend>
            <div className="grid gap-1.5 sm:grid-cols-2">
              {services.map((s) => (
                <label key={s.id} className="flex min-h-9 items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    name="serviceIds"
                    value={s.id}
                    className="size-4"
                    checked={checked.has(s.id)}
                    onChange={(e) =>
                      setChecked((c) => {
                        const next = new Set(c);
                        if (e.target.checked) next.add(s.id);
                        else next.delete(s.id);
                        return next;
                      })
                    }
                  />
                  {s.name}
                </label>
              ))}
              {extraServices.map((name) => (
                <label key={name} className="flex min-h-9 items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    className="size-4"
                    checked
                    onChange={() => setExtraServices((x) => x.filter((n) => n !== name))}
                    aria-label={`${name} (new)`}
                  />
                  {name} <span className="text-muted-foreground text-xs">new</span>
                </label>
              ))}
            </div>
            <div className="flex gap-2 pt-1">
              <Input
                value={newService}
                onChange={(e) => setNewService(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    addService();
                  }
                }}
                placeholder="Something else they do…"
                aria-label="Add something they do"
                maxLength={100}
                className="h-11 sm:h-9"
              />
              <Button type="button" variant="outline" onClick={addService} className="h-11 sm:h-9">
                Add
              </Button>
            </div>
          </fieldset>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${ids}-contact`}>
                Contact name <span className="text-muted-foreground font-normal">(optional)</span>
              </Label>
              <Input
                id={`${ids}-contact`}
                name="contactName"
                defaultValue={current?.contactName ?? ""}
                className="h-11 sm:h-9"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${ids}-phone`}>
                Phone <span className="text-muted-foreground font-normal">(optional)</span>
              </Label>
              <Input
                id={`${ids}-phone`}
                name="phone"
                type="tel"
                defaultValue={current?.phone ?? ""}
                className="h-11 sm:h-9"
              />
            </div>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor={`${ids}-email`}>
              Email <span className="text-muted-foreground font-normal">(optional)</span>
            </Label>
            <Input
              id={`${ids}-email`}
              name="email"
              type="email"
              defaultValue={current?.email ?? ""}
              aria-describedby={error ? errorId : undefined}
              className="h-11 sm:h-9"
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor={`${ids}-notes`}>
              Notes <span className="text-muted-foreground font-normal">(optional)</span>
            </Label>
            <Textarea id={`${ids}-notes`} name="notes" defaultValue={current?.notes ?? ""} />
          </div>
          {current && (current.grants.length > 0 || canInvite) && (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm">
              <span className="inline-flex items-center gap-1.5">
                <KeyRound className="text-muted-foreground size-4" aria-hidden />
                Portal access: {portalSummary(current.grants)}
              </span>
              <Button type="button" size="sm" variant="outline" onClick={() => onPortal(current)}>
                {current.grants.length === 0 ? "Invite someone" : "Manage"}
              </Button>
            </div>
          )}
          {error && (
            <p id={errorId} role="alert" className="text-destructive text-sm">
              {error}
            </p>
          )}
        </form>
        <DialogFooter className="gap-2">
          {current && (
            <Button
              type="button"
              variant="ghost"
              className="sm:mr-auto"
              disabled={pending}
              onClick={() => archive(current)}
            >
              <Archive aria-hidden /> Archive
            </Button>
          )}
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="supplier-form" disabled={pending}>
            {pending ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
        {confirmDialog}
      </DialogContent>
    </Dialog>
  );
}
