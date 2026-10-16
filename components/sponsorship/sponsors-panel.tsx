"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import { Building2, Mail, MoreHorizontal, Pencil, Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { EmptyState } from "@/components/empty-state";
import { useConfirm } from "@/components/confirm-dialog";
import {
  removeEntitlement,
  removeSponsor,
  saveSponsor,
  updateEntitlement,
} from "@/app/actions/sponsors";
import { formatMoney, plural } from "@/lib/format";

export type SponsorEntitlement = {
  id: string;
  description: string;
  quantity: number;
  /** Items that count towards it (deleted ones too: they still point at it). */
  linkedItems: number;
};

export type SponsorRow = {
  id: string;
  companyName: string;
  contactName: string | null;
  contactEmail: string | null;
  packageName: string | null;
  entitlements: SponsorEntitlement[];
  /** Live items with this sponsor: bought, and signage in their package. */
  itemCount: number;
  soldCount: number;
  inPackageCount: number;
  /** What they've bought, from sale prices. */
  spend: number;
  /** Anything at all points at them (items, deleted ones too, or portal access). */
  linked: boolean;
  /** Someone at the sponsor can sign in to the portal, or has been invited to. */
  portal: "access" | "invited" | null;
};

/**
 * The event's sponsors: who they are, what they're entitled to (each line
 * editable, removable while nothing counts towards it), what they bought
 * (linking to those items), and an invitation for them to upload artwork.
 */
export function SponsorsPanel({
  editionId,
  editionCode,
  sponsors,
  canEdit,
  canInvite,
}: {
  editionId: string;
  editionCode: string;
  sponsors: SponsorRow[];
  canEdit: boolean;
  /** Admins invite partners (Users → External). */
  canInvite: boolean;
}) {
  const [editing, setEditing] = useState<SponsorRow | "new" | null>(null);
  const [editingEnt, setEditingEnt] = useState<{
    sponsor: SponsorRow;
    ent: SponsorEntitlement;
  } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  // The page header's "Add sponsor" links here with ?add=1.
  const addingFromLink = canEdit && search.get("add") === "1";
  const editorOpen = editing !== null || addingFromLink;
  const current = editing === "new" || editing === null ? null : editing;

  function closeEditor() {
    setEditing(null);
    if (search.get("add")) {
      const next = new URLSearchParams(search.toString());
      next.delete("add");
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    }
  }

  async function onRemoveSponsor(sp: SponsorRow) {
    const ok = await confirm({
      title: `Remove ${sp.companyName}?`,
      description:
        "They have nothing linked to them, so they and their entitlements are removed from this event. History keeps a record.",
      confirmLabel: "Remove sponsor",
      destructive: true,
    });
    if (!ok) return;
    start(async () => {
      const res = await removeSponsor({ sponsorId: sp.id });
      if (res.ok) toast.success(res.message ?? `Removed ${sp.companyName}`);
      else toast.error(res.error);
      router.refresh();
    });
  }

  async function onRemoveEntitlement(sp: SponsorRow, ent: SponsorEntitlement) {
    const ok = await confirm({
      title: `Remove “${ent.description}”?`,
      description: `It comes off ${sp.companyName}'s entitlements. Nothing counts towards it, so no item changes.`,
      confirmLabel: "Remove",
      destructive: true,
    });
    if (!ok) return;
    start(async () => {
      const res = await removeEntitlement({ entitlementId: ent.id });
      if (res.ok) toast.success(res.message ?? "Entitlement removed");
      else toast.error(res.error);
      router.refresh();
    });
  }

  const inviteHref = (sp: SponsorRow) =>
    `/users?tab=external&invite=1&role=sponsor&scopeId=${sp.id}&edition=${editionId}`;

  return (
    <section className="space-y-3" aria-label="Sponsors">
      {sponsors.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No sponsors for this event yet"
          description={
            canEdit
              ? "Add a sponsor to record what they're entitled to and link items to what they bought. Marking an item sold can add one too."
              : "Sponsors appear here once Sales add them."
          }
          action={
            canEdit && (
              <Button size="sm" onClick={() => setEditing("new")}>
                <Plus className="size-4" /> Add sponsor
              </Button>
            )
          }
        />
      ) : (
        <ul className="grid gap-3 lg:grid-cols-2">
          {sponsors.map((sp) => (
            <li key={sp.id} aria-label={sp.companyName} className="rounded-lg border p-3 text-sm">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="font-medium">{sp.companyName}</p>
                  <p className="text-muted-foreground text-xs">
                    {[sp.packageName, sp.contactName, sp.contactEmail]
                      .filter(Boolean)
                      .join(" · ") || "No contact yet"}
                  </p>
                </div>
                {canEdit && (
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        size="icon"
                        variant="ghost"
                        className="size-9"
                        aria-label={`Change ${sp.companyName}`}
                        disabled={pending}
                      >
                        <MoreHorizontal aria-hidden />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-52">
                      <DropdownMenuItem
                        onSelect={() => {
                          setError(null);
                          setEditing(sp);
                        }}
                      >
                        <Pencil aria-hidden /> Edit sponsor
                      </DropdownMenuItem>
                      {!sp.linked && (
                        <>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onSelect={() => void onRemoveSponsor(sp)}
                          >
                            <Trash2 aria-hidden /> Remove sponsor
                          </DropdownMenuItem>
                        </>
                      )}
                    </DropdownMenuContent>
                  </DropdownMenu>
                )}
              </div>

              {sp.entitlements.length > 0 && (
                <div className="mt-3">
                  <p className="text-muted-foreground text-xs font-medium">Entitled to</p>
                  <ul className="mt-1 divide-y rounded-md border">
                    {sp.entitlements.map((e) => (
                      <li
                        key={e.id}
                        className="flex items-center gap-2 px-2 py-1.5 text-xs"
                        aria-label={e.description}
                      >
                        <span className="min-w-0 flex-1">
                          {e.quantity > 1 ? `${e.quantity} × ` : ""}
                          {e.description}
                          {e.linkedItems > 0 && (
                            <span className="text-muted-foreground">
                              {" "}
                              ·{" "}
                              {e.linkedItems > e.quantity
                                ? `${e.linkedItems} linked, more than the ${e.quantity} included`
                                : `${e.linkedItems} of ${e.quantity} linked`}
                            </span>
                          )}
                        </span>
                        {canEdit && (
                          <>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="size-8"
                              aria-label={`Edit ${e.description}`}
                              onClick={() => {
                                setError(null);
                                setEditingEnt({ sponsor: sp, ent: e });
                              }}
                            >
                              <Pencil aria-hidden />
                            </Button>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="size-8"
                              aria-label={`Remove ${e.description}`}
                              disabled={pending || e.linkedItems > 0}
                              title={
                                e.linkedItems > 0
                                  ? `${plural(e.linkedItems, "item")} count towards it — it can't be removed`
                                  : undefined
                              }
                              onClick={() => void onRemoveEntitlement(sp, e)}
                            >
                              <Trash2 aria-hidden />
                            </Button>
                          </>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t pt-2">
                <p className="text-xs">
                  {sp.itemCount > 0 ? (
                    <Link
                      href={`/${editionCode}/sponsorship?sponsor=${sp.id}`}
                      className="link font-medium"
                    >
                      {[
                        sp.soldCount > 0 ? `${plural(sp.soldCount, "item")} bought` : null,
                        sp.inPackageCount > 0
                          ? `${plural(sp.inPackageCount, "sign")} in their package`
                          : null,
                      ]
                        .filter(Boolean)
                        .join(" · ") || plural(sp.itemCount, "item")}
                    </Link>
                  ) : (
                    <span className="text-muted-foreground">Nothing bought yet</span>
                  )}
                  {sp.spend > 0 && (
                    <span className="text-muted-foreground"> · {formatMoney(sp.spend)}</span>
                  )}
                </p>
                {canInvite && !sp.portal && sp.itemCount > 0 && (
                  <Button asChild size="sm" variant="outline">
                    <Link href={inviteHref(sp)}>
                      <Mail aria-hidden /> Invite to upload artwork
                    </Link>
                  </Button>
                )}
                {sp.portal && (
                  <span className="text-muted-foreground text-xs">
                    {sp.portal === "access" ? "Has portal access" : "Invited to the portal"}
                  </span>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
      {confirmDialog}

      <Dialog open={editorOpen} onOpenChange={(o) => !o && closeEditor()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{current ? `Edit ${current.companyName}` : "Add sponsor"}</DialogTitle>
            <DialogDescription>
              What they bought goes under entitlements, one per line (e.g. &ldquo;6 x Logo on
              hanging banners&rdquo;).
            </DialogDescription>
          </DialogHeader>
          <form
            key={current?.id ?? "new"}
            className="grid gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const fd = new FormData(e.currentTarget);
              setError(null);
              start(async () => {
                const res = await saveSponsor({
                  ...Object.fromEntries(fd.entries()),
                  editionId,
                  id: current?.id,
                });
                if (!res.ok) setError(res.error);
                else {
                  toast.success(res.message ?? "Sponsor saved");
                  closeEditor();
                  router.refresh();
                }
              });
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="sp-name">Company</Label>
              <Input id="sp-name" name="companyName" defaultValue={current?.companyName} required />
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="sp-package">Package (optional)</Label>
                <Input
                  id="sp-package"
                  name="packageName"
                  defaultValue={current?.packageName ?? ""}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sp-contact">Contact name (optional)</Label>
                <Input
                  id="sp-contact"
                  name="contactName"
                  defaultValue={current?.contactName ?? ""}
                />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sp-email">Contact email (optional)</Label>
              <Input
                id="sp-email"
                name="contactEmail"
                type="email"
                defaultValue={current?.contactEmail ?? ""}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sp-ent">
                {current ? "Add entitlements (optional)" : "Entitlements (optional)"}
              </Label>
              <Textarea
                id="sp-ent"
                name="entitlements"
                placeholder={"500 x Branded lanyards\nLogo on main entrance"}
              />
              {current && current.entitlements.length > 0 && (
                <p className="text-muted-foreground text-xs">
                  Change or remove existing ones from the sponsor&apos;s card.
                </p>
              )}
            </div>
            {error && (
              <p role="alert" className="text-destructive text-sm">
                {error}
              </p>
            )}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={closeEditor}>
                Cancel
              </Button>
              <Button type="submit" disabled={pending}>
                {pending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={editingEnt !== null} onOpenChange={(o) => !o && setEditingEnt(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit entitlement</DialogTitle>
            <DialogDescription>
              {editingEnt?.sponsor.companyName} —{" "}
              {editingEnt && editingEnt.ent.linkedItems > 0
                ? `${plural(editingEnt.ent.linkedItems, "item")} count towards it and stay linked.`
                : "what they get and how many."}
            </DialogDescription>
          </DialogHeader>
          <form
            key={editingEnt?.ent.id ?? "none"}
            className="grid grid-cols-[6rem_1fr] gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (!editingEnt) return;
              const fd = new FormData(e.currentTarget);
              setError(null);
              start(async () => {
                const res = await updateEntitlement({
                  entitlementId: editingEnt.ent.id,
                  quantity: fd.get("quantity"),
                  description: fd.get("description"),
                });
                if (!res.ok) setError(res.error);
                else {
                  toast.success(res.message ?? "Entitlement saved");
                  setEditingEnt(null);
                  router.refresh();
                }
              });
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="ent-qty">Quantity</Label>
              <Input
                id="ent-qty"
                name="quantity"
                type="number"
                inputMode="numeric"
                min={1}
                defaultValue={editingEnt?.ent.quantity ?? 1}
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="ent-desc">What they get</Label>
              <Input
                id="ent-desc"
                name="description"
                defaultValue={editingEnt?.ent.description ?? ""}
                required
              />
            </div>
            {error && (
              <p role="alert" className="text-destructive col-span-2 text-sm">
                {error}
              </p>
            )}
            <DialogFooter className="col-span-2">
              <Button type="button" variant="outline" onClick={() => setEditingEnt(null)}>
                Cancel
              </Button>
              <Button type="submit" disabled={pending}>
                {pending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </section>
  );
}
