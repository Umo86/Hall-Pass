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
export type SignoffStepOption = {
  id: string;
  name: string;
  /** "Marketing" — for "Anyone in Marketing". */
  departmentName: string;
  defaultUserId: string | null;
  defaultFor: string[];
  /** The department's approvers who can sign off now. */
  people: { id: string; name: string; jobTitle: string | null }[];
};

export type SignoffChoice = { stepId: string; userId: string | null };

export type ItemFormOptions = {
  itemTypes: { id: string; name: string; format?: string | null }[];
  halls: { id: string; name: string }[];
  locations: { id: string; name: string; hallId: string }[];
  sponsors: { id: string; name: string }[];
  entitlements: { id: string; sponsorId: string; description: string }[];
  suppliers: { id: string; name: string; services?: string[] }[];
  contractors: { id: string; name: string }[];
  workflows: { id: string; name: string }[];
  /** Department sign-offs the item can ask for, and who can sign each. */
  signoffSteps?: SignoffStepOption[];
};

/** The defaults admins set for organiser or sponsor signage. */
function defaultPlan(steps: SignoffStepOption[], category: string): SignoffChoice[] {
  return steps
    .filter((s) => s.defaultFor.includes(category))
    .map((s) => ({ stepId: s.id, userId: s.defaultUserId }));
}

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
  signoffs?: SignoffChoice[] | null;
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
  const [category, setCategory] = useState(
    isSponsorship ? "sponsor" : (values.category ?? "organiser"),
  );
  const steps = options.signoffSteps ?? [];
  const [plan, setPlan] = useState<SignoffChoice[]>(
    values.signoffs ??
      defaultPlan(steps, isSponsorship ? "sponsor" : (values.category ?? "organiser")),
  );
  // Until someone changes the ticks, they follow the category's defaults.
  const [planTouched, setPlanTouched] = useState(false);

  function chooseCategory(next: string) {
    setCategory(next);
    if (!planTouched && !values.signoffs) setPlan(defaultPlan(steps, next));
  }

  function setStep(stepId: string, on: boolean, userId?: string | null) {
    setPlanTouched(true);
    setPlan((current) => {
      const rest = current.filter((p) => p.stepId !== stepId);
      if (!on) return rest;
      const step = steps.find((s) => s.id === stepId);
      const existing = current.find((p) => p.stepId === stepId);
      const chosen =
        userId !== undefined ? userId : (existing?.userId ?? step?.defaultUserId ?? null);
      // Keep the admin's order.
      return steps
        .filter((s) => s.id === stepId || rest.some((p) => p.stepId === s.id))
        .map((s) =>
          s.id === stepId ? { stepId, userId: chosen } : rest.find((p) => p.stepId === s.id)!,
        );
    });
  }
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
    if (category !== "sponsor" && !isSponsorship) clean.sponsorId = null;
    if (steps.length > 0 && plan.length === 0) {
      setError("Choose at least one department to sign this off");
      return;
    }
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
            <fieldset className="space-y-1.5 sm:col-span-2">
              <legend className="text-sm font-medium">Whose signage is it?</legend>
              <div className="flex flex-wrap gap-2">
                {(
                  [
                    [
                      "organiser",
                      "Organiser signage",
                      "Our own — directions, venue dressing, features",
                    ],
                    ["sponsor", "Sponsor signage", "Sold to a sponsor — shows their name"],
                  ] as const
                ).map(([value, label, hint]) => (
                  <label
                    key={value}
                    className={`flex min-w-52 flex-1 cursor-pointer items-start gap-2 rounded-md border p-2.5 text-sm ${
                      category === value ? "border-primary bg-primary/5" : ""
                    }`}
                  >
                    <input
                      type="radio"
                      name="category"
                      value={value}
                      checked={category === value}
                      onChange={() => chooseCategory(value)}
                      className="mt-0.5 size-4"
                    />
                    <span>
                      <span className="font-medium">{label}</span>
                      <span className="text-muted-foreground block text-xs">{hint}</span>
                    </span>
                  </label>
                ))}
              </div>
              {err("category")}
            </fieldset>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="itemTypeId">Item type</Label>
            <SelectNative id="itemTypeId" name="itemTypeId" defaultValue={values.itemTypeId ?? ""}>
              <option value="">— Select —</option>
              {isSponsorship
                ? options.itemTypes.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                    </option>
                  ))
                : (
                    [
                      ["print", "Print"],
                      ["digital", "Digital"],
                    ] as const
                  ).map(([format, label]) => {
                    const group = options.itemTypes.filter((t) => (t.format ?? "print") === format);
                    return group.length === 0 ? null : (
                      <optgroup key={format} label={label}>
                        {group.map((t) => (
                          <option key={t.id} value={t.id}>
                            {t.name}
                          </option>
                        ))}
                      </optgroup>
                    );
                  })}
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
          <h3 className="text-sm font-semibold sm:col-span-2">
            {category === "sponsor" ? "Sponsor" : "Approvals"}
          </h3>
          {category === "sponsor" && (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="sponsorId">Sponsor</Label>
                <SelectNative
                  id="sponsorId"
                  name="sponsorId"
                  value={sponsorId}
                  onChange={(e) => setSponsorId(e.target.value)}
                  required
                >
                  <option value="">— Select sponsor —</option>
                  {options.sponsors.map((sp) => (
                    <option key={sp.id} value={sp.id}>
                      {sp.name}
                    </option>
                  ))}
                </SelectNative>
                {err("sponsorId")}
                {options.sponsors.length === 0 && (
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
            </>
          )}
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
        </section>

        {steps.length > 0 && (
          <section className="grid gap-2">
            <div>
              <h3 className="text-sm font-semibold">Sign-off</h3>
              <p className="text-muted-foreground text-xs">
                Who approves the artwork. Pre-set for{" "}
                {category === "sponsor" ? "sponsor" : "organiser"} signage — untick a department or
                pick the person. They&apos;re emailed when it&apos;s their turn.
              </p>
            </div>
            {planTouched && <input type="hidden" name="signoffs" value={JSON.stringify(plan)} />}
            <ul className="divide-y rounded-lg border" aria-label="Sign-off">
              {steps.map((step) => {
                const choice = plan.find((p) => p.stepId === step.id);
                const people = step.people;
                return (
                  <li
                    key={step.id}
                    className="flex flex-wrap items-center gap-x-3 gap-y-1.5 px-3 py-2"
                  >
                    <label className="flex min-w-48 flex-1 items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        className="size-4"
                        checked={Boolean(choice)}
                        onChange={(e) => setStep(step.id, e.target.checked)}
                        aria-label={`Needs ${step.name}`}
                      />
                      <span className={choice ? "font-medium" : "text-muted-foreground"}>
                        {step.name}
                      </span>
                    </label>
                    {choice && (
                      <SelectNative
                        aria-label={`Who signs ${step.name}`}
                        value={choice.userId ?? ""}
                        onChange={(e) => setStep(step.id, true, e.target.value || null)}
                        className="h-8 w-full sm:w-60"
                      >
                        <option value="">Anyone in {step.departmentName}</option>
                        {people.map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.name}
                            {p.jobTitle ? ` — ${p.jobTitle}` : ""}
                            {p.id === step.defaultUserId ? " (main approver)" : ""}
                          </option>
                        ))}
                      </SelectNative>
                    )}
                    {choice && people.length === 0 && (
                      <p className="w-full text-xs text-amber-800 dark:text-amber-300">
                        No approvers with an account in {step.departmentName} yet — add them under
                        Approvals → Approvers.
                      </p>
                    )}
                  </li>
                );
              })}
            </ul>
            {plan.length === 0 && (
              <p className="text-destructive text-xs">Choose at least one department.</p>
            )}
            {mode === "edit" && status === "in_review" && planTouched && (
              <p className="text-xs text-amber-800 dark:text-amber-300">
                This item is in sign-off — saving a change here starts its sign-off again.
              </p>
            )}
          </section>
        )}

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
                      {sp.services?.length ? ` — ${sp.services.join(", ")}` : ""}
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
            This item is signed off. Changing its size, material, fixing, type, sponsor or who
            signs it off sends it back for sign-off; dates, supplier and costs can change freely.
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
