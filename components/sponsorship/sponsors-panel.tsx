"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
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
import { saveSponsor } from "@/app/actions/sponsors";

export type SponsorRow = {
  id: string;
  companyName: string;
  contactName: string | null;
  contactEmail: string | null;
  packageName: string | null;
  entitlements: { description: string; quantity: number }[];
  itemCount: number;
};

export function SponsorsPanel({
  editionId,
  sponsors,
  canEdit,
}: {
  editionId: string;
  sponsors: SponsorRow[];
  canEdit: boolean;
}) {
  const [editing, setEditing] = useState<SponsorRow | "new" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const current = editing === "new" ? null : editing;

  return (
    <section className="space-y-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold">Sponsors</h2>
        {canEdit && (
          <Button size="sm" variant="outline" onClick={() => setEditing("new")}>
            <Plus className="size-4" /> Add sponsor
          </Button>
        )}
      </div>
      {sponsors.length === 0 ? (
        <p className="text-muted-foreground text-sm">
          No sponsors for this show yet{canEdit ? " — add one to link items to what they bought." : "."}
        </p>
      ) : (
        <ul className="grid gap-2 sm:grid-cols-2">
          {sponsors.map((sp) => (
            <li key={sp.id} className="rounded-lg border p-3 text-sm">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="font-medium">{sp.companyName}</p>
                  <p className="text-muted-foreground text-xs">
                    {[sp.packageName, sp.contactName, sp.contactEmail].filter(Boolean).join(" · ") ||
                      "No contact yet"}
                  </p>
                </div>
                {canEdit && (
                  <Button size="sm" variant="ghost" onClick={() => setEditing(sp)}>
                    Edit
                  </Button>
                )}
              </div>
              {sp.entitlements.length > 0 && (
                <ul className="text-muted-foreground mt-2 list-disc pl-5 text-xs">
                  {sp.entitlements.map((e) => (
                    <li key={e.description}>
                      {e.quantity > 1 ? `${e.quantity} × ` : ""}
                      {e.description}
                    </li>
                  ))}
                </ul>
              )}
              <p className="text-muted-foreground mt-2 text-xs">
                {sp.itemCount} linked item{sp.itemCount === 1 ? "" : "s"}
              </p>
            </li>
          ))}
        </ul>
      )}

      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
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
                  setEditing(null);
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
                <Input id="sp-package" name="packageName" defaultValue={current?.packageName ?? ""} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sp-contact">Contact name (optional)</Label>
                <Input id="sp-contact" name="contactName" defaultValue={current?.contactName ?? ""} />
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
                {current ? "Add entitlements (existing ones are kept)" : "Entitlements (optional)"}
              </Label>
              <Textarea id="sp-ent" name="entitlements" placeholder={"500 x Branded lanyards\nLogo on main entrance"} />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setEditing(null)}>
                Cancel
              </Button>
              <Button type="submit" disabled={pending}>
                Save
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </section>
  );
}
