"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { createSignageItem, updateSignageItem } from "@/app/actions/signage";

export type ItemFormOptions = {
  itemTypes: { id: string; name: string }[];
  halls: { id: string; name: string }[];
  locations: { id: string; name: string; hallId: string }[];
  sponsors: { id: string; name: string }[];
  entitlements: { id: string; sponsorId: string; description: string }[];
  suppliers: { id: string; name: string }[];
  contractors: { id: string; name: string }[];
  workflows: { id: string; name: string }[];
};

export type ItemFormValues = {
  id?: string;
  editionId?: string;
  name?: string;
  description?: string | null;
  category?: string | null;
  itemTypeId?: string | null;
  hallId?: string | null;
  locationId?: string | null;
  ownerRole?: string;
  sponsorId?: string | null;
  sponsorEntitlementId?: string | null;
  widthMm?: number | null;
  heightMm?: number | null;
  depthMm?: number | null;
  quantity?: number;
  sided?: string;
  material?: string | null;
  finish?: string | null;
  fixingMethod?: string | null;
  weightKg?: string | null;
  requiresVenueApproval?: boolean;
  requiresEventDirector?: boolean;
  budgetLine?: string | null;
  costEstimate?: string | null;
  costActual?: string | null;
  poNumber?: string | null;
  supplierId?: string | null;
  artworkDueOverride?: string | null;
  printDeadline?: string | null;
  deliveryDate?: string | null;
  installDate?: string | null;
  installSlot?: string | null;
  installContractorId?: string | null;
  workflowId?: string | null;
};

const FIXINGS = [
  "rigged",
  "freestanding",
  "wall_mounted",
  "shell_mounted",
  "floor",
  "digital",
  "other",
];

export function ItemForm({
  mode,
  values,
  options,
  canSeeCosts,
  canEditCosts,
  editionCode,
  kind = "signage",
  status,
  readOnly = false,
}: {
  mode: "create" | "edit";
  values: ItemFormValues;
  options: ItemFormOptions;
  canSeeCosts: boolean;
  canEditCosts: boolean;
  editionCode: string;
  /** Sponsorship items skip category, location and install fields. */
  kind?: "signage" | "sponsorship_item";
  /** Current status on edit, to warn that spec changes restart sign-off. */
  status?: string;
  /** View only: fields are shown but can't be changed and there is no Save. */
  readOnly?: boolean;
}) {
  const isSponsorship = kind === "sponsorship_item";
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [sponsorId, setSponsorId] = useState(values.sponsorId ?? "");
  const [hallId, setHallId] = useState(values.hallId ?? "");
  const [pending, start] = useTransition();
  const router = useRouter();

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const raw = Object.fromEntries(fd.entries());
    const clean: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(raw)) {
      clean[k] = v === "" ? null : v;
    }
    clean.requiresVenueApproval = fd.get("requiresVenueApproval") === "on";
    clean.requiresEventDirector = fd.get("requiresEventDirector") === "on";
    setError(null);
    setMessage(null);
    setFieldErrors({});
    start(async () => {
      if (mode === "create") {
        const res = await createSignageItem({ ...clean, editionId: values.editionId, kind });
        if (!res.ok) {
          setError(res.error);
          setFieldErrors(res.fieldErrors ?? {});
        } else
          router.push(
            `/${editionCode}/${isSponsorship ? "sponsorship" : "signage"}/${res.data?.ref}`,
          );
      } else {
        const res = await updateSignageItem({ ...clean, id: values.id });
        if (!res.ok) {
          setError(res.error);
          setFieldErrors(res.fieldErrors ?? {});
        } else {
          setMessage(res.message ?? "Saved");
          router.refresh();
        }
      }
    });
  }

  const err = (name: string) =>
    fieldErrors[name] ? (
      <p className="text-destructive text-xs" id={`${name}-error`}>
        {fieldErrors[name]}
      </p>
    ) : null;

  const locationChoices = options.locations.filter((l) => !hallId || l.hallId === hallId);
  const entitlementChoices = options.entitlements.filter((e) => e.sponsorId === sponsorId);

  const costsOpen = Boolean(
    values.budgetLine ??
    values.costEstimate ??
    values.costActual ??
    values.poNumber ??
    values.supplierId,
  );
  const datesOpen = Boolean(
    values.artworkDueOverride ??
    values.printDeadline ??
    values.deliveryDate ??
    values.installDate ??
    values.installSlot ??
    values.installContractorId,
  );

  return (
    <form onSubmit={onSubmit} className="max-w-4xl">
      <fieldset disabled={readOnly} className="grid gap-5">
        <section className="grid gap-3 sm:grid-cols-2">
          <h3 className="text-sm font-semibold sm:col-span-2">Basics</h3>
          <div className="space-y-1.5 sm:col-span-2">
            <Label htmlFor="name">Name</Label>
            <Input id="name" name="name" defaultValue={values.name ?? ""} required />
            {err("name")}
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label htmlFor="description">Description</Label>
            <Textarea id="description" name="description" defaultValue={values.description ?? ""} />
          </div>
          {!isSponsorship && (
            <div className="space-y-1.5">
              <Label htmlFor="category">Category</Label>
              <SelectNative
                id="category"
                name="category"
                defaultValue={values.category ?? ""}
                required
              >
                <option value="">— Select —</option>
                <option value="directional">Directional (wayfinding)</option>
                <option value="venue">Venue</option>
                <option value="sponsorship">Sponsorship (sold)</option>
              </SelectNative>
              {err("category")}
            </div>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="itemTypeId">Item type</Label>
            <SelectNative id="itemTypeId" name="itemTypeId" defaultValue={values.itemTypeId ?? ""}>
              <option value="">— Select —</option>
              {options.itemTypes.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </SelectNative>
          </div>
          {isSponsorship ? (
            <input type="hidden" name="ownerRole" value={values.ownerRole ?? "ops"} />
          ) : (
            <div className="space-y-1.5">
              <Label htmlFor="ownerRole">Owner</Label>
              <SelectNative
                id="ownerRole"
                name="ownerRole"
                defaultValue={values.ownerRole ?? "ops"}
              >
                <option value="ops">Operations</option>
                <option value="marketing">Marketing</option>
              </SelectNative>
            </div>
          )}
          {!isSponsorship && options.halls.length === 0 && (
            <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 sm:col-span-2 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
              This show has no halls yet — add them in{" "}
              <Link href={`/${editionCode}/halls`} className="underline">
                Halls &amp; locations
              </Link>{" "}
              so signs can be placed.
            </p>
          )}
          {!isSponsorship && (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="hallId">Hall</Label>
                <SelectNative
                  id="hallId"
                  name="hallId"
                  value={hallId}
                  onChange={(e) => setHallId(e.target.value)}
                >
                  <option value="">— Select —</option>
                  {options.halls.map((h) => (
                    <option key={h.id} value={h.id}>
                      {h.name}
                    </option>
                  ))}
                </SelectNative>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="locationId">Location</Label>
                <SelectNative
                  id="locationId"
                  name="locationId"
                  defaultValue={values.locationId ?? ""}
                >
                  <option value="">— Select —</option>
                  {locationChoices.map((l) => (
                    <option key={l.id} value={l.id}>
                      {l.name}
                    </option>
                  ))}
                </SelectNative>
              </div>
            </>
          )}
        </section>

        <section className="grid gap-3 sm:grid-cols-3">
          <h3 className="text-sm font-semibold sm:col-span-3">
            {isSponsorship ? "Spec" : "Physical spec"}
          </h3>
          <div className="space-y-1.5">
            <Label htmlFor="widthMm">Width (mm)</Label>
            <Input
              id="widthMm"
              name="widthMm"
              type="number"
              min="1"
              defaultValue={values.widthMm ?? ""}
            />
            {err("widthMm")}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="heightMm">Height (mm)</Label>
            <Input
              id="heightMm"
              name="heightMm"
              type="number"
              min="1"
              defaultValue={values.heightMm ?? ""}
            />
            {err("heightMm")}
          </div>
          {!isSponsorship && (
            <div className="space-y-1.5">
              <Label htmlFor="depthMm">Depth (mm)</Label>
              <Input
                id="depthMm"
                name="depthMm"
                type="number"
                min="1"
                defaultValue={values.depthMm ?? ""}
              />
              {err("depthMm")}
            </div>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="quantity">Quantity</Label>
            <Input
              id="quantity"
              name="quantity"
              type="number"
              min="1"
              defaultValue={values.quantity ?? 1}
            />
            {err("quantity")}
          </div>
          {!isSponsorship && (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="sided">Sided</Label>
                <SelectNative id="sided" name="sided" defaultValue={values.sided ?? "single"}>
                  <option value="single">Single</option>
                  <option value="double">Double</option>
                </SelectNative>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="fixingMethod">Fixing method</Label>
                <SelectNative
                  id="fixingMethod"
                  name="fixingMethod"
                  defaultValue={values.fixingMethod ?? ""}
                >
                  <option value="">— Select —</option>
                  {FIXINGS.map((f) => (
                    <option key={f} value={f}>
                      {f.replace(/_/g, " ")}
                    </option>
                  ))}
                </SelectNative>
              </div>
            </>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="material">Material</Label>
            <Input id="material" name="material" defaultValue={values.material ?? ""} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="finish">Finish</Label>
            <Input id="finish" name="finish" defaultValue={values.finish ?? ""} />
          </div>
          {!isSponsorship && (
            <div className="space-y-1.5">
              <Label htmlFor="weightKg">Weight (kg)</Label>
              <Input
                id="weightKg"
                name="weightKg"
                type="number"
                step="0.1"
                min="0"
                defaultValue={values.weightKg ?? ""}
              />
              {err("weightKg")}
            </div>
          )}
        </section>

        <section className="grid gap-3 sm:grid-cols-2">
          <h3 className="text-sm font-semibold sm:col-span-2">Sponsorship &amp; sign-off</h3>
          <div className="space-y-1.5">
            <Label htmlFor="sponsorId">Sponsor</Label>
            <SelectNative
              id="sponsorId"
              name="sponsorId"
              value={sponsorId}
              onChange={(e) => setSponsorId(e.target.value)}
              required={isSponsorship}
            >
              <option value="">{isSponsorship ? "— Select sponsor —" : "Not sponsored"}</option>
              {options.sponsors.map((sp) => (
                <option key={sp.id} value={sp.id}>
                  {sp.name}
                </option>
              ))}
            </SelectNative>
            {err("sponsorId")}
            {isSponsorship && options.sponsors.length === 0 && (
              <p className="text-xs text-amber-800 dark:text-amber-300">
                No sponsors yet — add them under Sponsors on the Sponsorship page first.
              </p>
            )}
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="sponsorEntitlementId">Entitlement</Label>
            <SelectNative
              id="sponsorEntitlementId"
              name="sponsorEntitlementId"
              defaultValue={values.sponsorEntitlementId ?? ""}
              disabled={!sponsorId}
            >
              <option value="">— None —</option>
              {entitlementChoices.map((en) => (
                <option key={en.id} value={en.id}>
                  {en.description}
                </option>
              ))}
            </SelectNative>
          </div>
          {mode === "create" &&
            (options.workflows.length > 1 ? (
              <div className="space-y-1.5">
                <Label htmlFor="workflowId">Sign-off workflow</Label>
                <SelectNative
                  id="workflowId"
                  name="workflowId"
                  defaultValue={options.workflows[0].id}
                >
                  {options.workflows.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name}
                    </option>
                  ))}
                </SelectNative>
              </div>
            ) : options.workflows[0] ? (
              <input type="hidden" name="workflowId" value={options.workflows[0].id} />
            ) : null)}
          {!isSponsorship && (
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                name="requiresVenueApproval"
                className="size-4"
                defaultChecked={values.requiresVenueApproval}
              />
              Requires venue approval (always on for rigged items)
            </label>
          )}
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              name="requiresEventDirector"
              className="size-4"
              defaultChecked={values.requiresEventDirector}
            />
            Requires Event Director sign-off
          </label>
        </section>

        {canSeeCosts && (
          <details open={costsOpen} className="rounded-lg border">
            <summary className="cursor-pointer px-4 py-3 text-sm font-semibold select-none">
              Costs &amp; purchasing
            </summary>
            <section className="grid gap-3 px-4 pb-4 sm:grid-cols-3">
              <div className="space-y-1.5">
                <Label htmlFor="budgetLine">Budget line</Label>
                <Input
                  id="budgetLine"
                  name="budgetLine"
                  defaultValue={values.budgetLine ?? ""}
                  disabled={!canEditCosts}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="costEstimate">Cost estimate (£)</Label>
                <Input
                  id="costEstimate"
                  name="costEstimate"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={values.costEstimate ?? ""}
                  disabled={!canEditCosts}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="costActual">Cost actual (£)</Label>
                <Input
                  id="costActual"
                  name="costActual"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={values.costActual ?? ""}
                  disabled={!canEditCosts}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="poNumber">PO number</Label>
                <Input
                  id="poNumber"
                  name="poNumber"
                  defaultValue={values.poNumber ?? ""}
                  disabled={!canEditCosts}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="supplierId">Supplier</Label>
                <SelectNative
                  id="supplierId"
                  name="supplierId"
                  defaultValue={values.supplierId ?? ""}
                  disabled={!canEditCosts}
                >
                  <option value="">— None —</option>
                  {options.suppliers.map((sp) => (
                    <option key={sp.id} value={sp.id}>
                      {sp.name}
                    </option>
                  ))}
                </SelectNative>
              </div>
            </section>
          </details>
        )}

        <details open={datesOpen} className="rounded-lg border">
          <summary className="cursor-pointer px-4 py-3 text-sm font-semibold select-none">
            Dates &amp; install
          </summary>
          <section className="grid gap-3 px-4 pb-4 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label htmlFor="artworkDueOverride">Artwork due (override)</Label>
              <Input
                id="artworkDueOverride"
                name="artworkDueOverride"
                type="date"
                defaultValue={values.artworkDueOverride ?? ""}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="printDeadline">Print deadline</Label>
              <Input
                id="printDeadline"
                name="printDeadline"
                type="date"
                defaultValue={values.printDeadline ?? ""}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="deliveryDate">Delivery date</Label>
              <Input
                id="deliveryDate"
                name="deliveryDate"
                type="date"
                defaultValue={values.deliveryDate ?? ""}
              />
            </div>
            {!isSponsorship && (
              <>
                <div className="space-y-1.5">
                  <Label htmlFor="installDate">Install date</Label>
                  <Input
                    id="installDate"
                    name="installDate"
                    type="date"
                    defaultValue={values.installDate ?? ""}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="installSlot">Install slot</Label>
                  <SelectNative
                    id="installSlot"
                    name="installSlot"
                    defaultValue={values.installSlot ?? ""}
                  >
                    <option value="">— None —</option>
                    <option value="am">AM</option>
                    <option value="pm">PM</option>
                    <option value="overnight">Overnight</option>
                  </SelectNative>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="installContractorId">Install contractor</Label>
                  <SelectNative
                    id="installContractorId"
                    name="installContractorId"
                    defaultValue={values.installContractorId ?? ""}
                  >
                    <option value="">— None —</option>
                    {options.contractors.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </SelectNative>
                </div>
              </>
            )}
          </section>
        </details>
      </fieldset>
      {!readOnly &&
        mode === "edit" &&
        status &&
        ["approved", "approved_with_conditions", "in_production", "delivered"].includes(status) && (
          <p className="text-sm text-amber-800 dark:text-amber-300">
            This item is signed off. Changing its size, material, fixing, type or sponsor sends it
            back for sign-off; dates, supplier and costs can change freely.
          </p>
        )}
      {!readOnly && (
        <div className="mt-5 flex flex-wrap items-center gap-3">
          <Button type="submit" disabled={pending}>
            {mode === "create" ? "Create item" : "Save changes"}
          </Button>
          {message && <span className="text-sm text-green-700 dark:text-green-400">{message}</span>}
          {error && <span className="text-destructive text-sm">{error}</span>}
        </div>
      )}
    </form>
  );
}
