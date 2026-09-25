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
  orderByDate?: string | null;
  salePrice?: string | null;
  deliveryDate?: string | null;
  installDate?: string | null;
  installSlot?: string | null;
  installContractorId?: string | null;
  workflowId?: string | null;
  signoffs?: SignoffChoice[] | null;
};

/** Fields kept under "More details" (sponsorship items add width and height). */
const MORE_FIELDS = [
  "description",
  "ownerRole",
  "depthMm",
  "sided",
  "weightKg",
  "material",
  "finish",
  "sponsorEntitlementId",
  "costActual",
  "poNumber",
  "budgetLine",
  "artworkDueOverride",
  "printDeadline",
  "deliveryDate",
  "installSlot",
  "installContractorId",
  "workflowId",
];

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

  const [moreOpen, setMoreOpen] = useState(false);
  // Errors on fields inside "More details" open it so they can be seen.
  function showErrors(errors: Record<string, string> | undefined) {
    setFieldErrors(errors ?? {});
    const more = new Set([...MORE_FIELDS, ...(isSponsorship ? ["widthMm", "heightMm"] : [])]);
    if (Object.keys(errors ?? {}).some((k) => more.has(k))) setMoreOpen(true);
  }

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
          showErrors(res.fieldErrors);
        } else
          router.push(
            `/${editionCode}/${isSponsorship ? "sponsorship" : "signage"}/${res.data?.ref}`,
          );
      } else {
        const res = await updateSignageItem({ ...clean, id: values.id });
        if (!res.ok) {
          setError(res.error);
          showErrors(res.fieldErrors);
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

  // Supplier and cost: whoever runs a sponsorship item also buys it.
  const costEditable = canEditCosts || isSponsorship;
  const moreFilled = [
    values.description,
    isSponsorship ? values.widthMm : values.depthMm,
    isSponsorship ? values.heightMm : values.weightKg,
    values.material,
    values.finish,
    values.sponsorEntitlementId,
    values.budgetLine,
    values.costActual,
    values.poNumber,
    values.artworkDueOverride,
    isSponsorship ? null : values.printDeadline,
    values.deliveryDate,
    isSponsorship ? null : values.installSlot,
    isSponsorship ? null : values.installContractorId,
  ].filter((v) => v !== null && v !== undefined && v !== "").length;

  const field = (
    id: string,
    label: string,
    control: React.ReactNode,
    opts: { span?: string; hint?: string } = {},
  ) => (
    <div className={`space-y-1.5 ${opts.span ?? ""}`}>
      <Label htmlFor={id}>{label}</Label>
      {control}
      {opts.hint && <p className="text-muted-foreground text-xs">{opts.hint}</p>}
      {err(id)}
    </div>
  );
  const dateInput = (id: keyof ItemFormValues) => (
    <Input id={id} name={id} type="date" defaultValue={(values[id] as string | null) ?? ""} />
  );
  const numberInput = (
    id: keyof ItemFormValues,
    opts: { step?: string; disabled?: boolean } = {},
  ) => (
    <Input
      id={id}
      name={id}
      type="number"
      min={opts.step ? "0" : "1"}
      step={opts.step}
      disabled={opts.disabled}
      defaultValue={
        (values[id] as string | number | null | undefined) ?? (id === "quantity" ? 1 : "")
      }
    />
  );
  const typeSelect = (
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
  );
  const sponsorSelect = (
    <SelectNative
      id="sponsorId"
      name="sponsorId"
      value={sponsorId}
      onChange={(e) => setSponsorId(e.target.value)}
      required={!isSponsorship}
    >
      <option value="">{isSponsorship ? "— Not sold yet —" : "— Select sponsor —"}</option>
      {options.sponsors.map((sp) => (
        <option key={sp.id} value={sp.id}>
          {sp.name}
        </option>
      ))}
    </SelectNative>
  );
  const supplierSelect = (
    <SelectNative
      id="supplierId"
      name="supplierId"
      defaultValue={values.supplierId ?? ""}
      disabled={!costEditable}
    >
      <option value="">— None yet —</option>
      {options.suppliers.map((sp) => (
        <option key={sp.id} value={sp.id}>
          {sp.name}
          {sp.services?.length ? ` — ${sp.services.join(", ")}` : ""}
        </option>
      ))}
    </SelectNative>
  );
  const sectionTitle = (text: string, span: string) => (
    <h3 className={`text-sm font-semibold ${span}`}>{text}</h3>
  );

  return (
    <form onSubmit={onSubmit} className="max-w-4xl">
      <fieldset disabled={readOnly} className="grid gap-5">
        {isSponsorship ? (
          <>
            <section className="grid gap-3 sm:grid-cols-2">
              {sectionTitle("The item", "sm:col-span-2")}
              {field(
                "name",
                "Name",
                <Input id="name" name="name" defaultValue={values.name ?? ""} required />,
                {
                  span: "sm:col-span-2",
                },
              )}
              {field("itemTypeId", "Item type", typeSelect)}
              {field("quantity", "Quantity", numberInput("quantity"))}
            </section>
            <section className="grid gap-3 sm:grid-cols-3">
              {sectionTitle("Buying", "sm:col-span-3")}
              {field("supplierId", "Supplier", supplierSelect)}
              {canSeeCosts &&
                field(
                  "costEstimate",
                  "Cost price (£)",
                  numberInput("costEstimate", { step: "0.01", disabled: !costEditable }),
                )}
              {field("orderByDate", "Order by", dateInput("orderByDate"), {
                hint: "Last day to order from the supplier — and so to sell it.",
              })}
            </section>
            <section className="grid gap-3 sm:grid-cols-2">
              {sectionTitle("Sale", "sm:col-span-2")}
              {field("sponsorId", "Sponsor", sponsorSelect, {
                hint:
                  options.sponsors.length === 0
                    ? "No sponsors yet — add them on the Sponsorship page, or use Mark as sold there."
                    : "Leave as not sold until a sponsor buys it.",
              })}
              {canSeeCosts &&
                field(
                  "salePrice",
                  "Sale price (£)",
                  <Input
                    id="salePrice"
                    name="salePrice"
                    type="number"
                    min="0"
                    step="0.01"
                    disabled={!sponsorId}
                    defaultValue={values.salePrice ?? ""}
                  />,
                )}
            </section>
          </>
        ) : (
          <>
            <section className="grid gap-3 sm:grid-cols-2">
              {sectionTitle("What and where", "sm:col-span-2")}
              {field(
                "name",
                "Name",
                <Input id="name" name="name" defaultValue={values.name ?? ""} required />,
                {
                  span: "sm:col-span-2",
                },
              )}
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
              {category === "sponsor" &&
                field("sponsorId", "Sponsor", sponsorSelect, {
                  hint:
                    options.sponsors.length === 0
                      ? "No sponsors yet — add them on the Sponsorship page first."
                      : undefined,
                })}
              {category === "sponsor" &&
                canSeeCosts &&
                field(
                  "salePrice",
                  "Sale price (£)",
                  <Input
                    id="salePrice"
                    name="salePrice"
                    type="number"
                    min="0"
                    step="0.01"
                    defaultValue={values.salePrice ?? ""}
                  />,
                )}
              {field("itemTypeId", "Item type", typeSelect)}
              {options.halls.length === 0 && (
                <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 sm:col-span-2 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
                  This show has no halls yet — add them in{" "}
                  <Link href={`/${editionCode}/halls`} className="underline">
                    Halls &amp; locations
                  </Link>{" "}
                  so signs can be placed.
                </p>
              )}
              {field(
                "hallId",
                "Hall",
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
                </SelectNative>,
              )}
              {field(
                "locationId",
                "Location",
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
                </SelectNative>,
              )}
            </section>
            <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {sectionTitle("Size and fixing", "col-span-2 sm:col-span-4")}
              {field("widthMm", "Width (mm)", numberInput("widthMm"))}
              {field("heightMm", "Height (mm)", numberInput("heightMm"))}
              {field("quantity", "Quantity", numberInput("quantity"))}
              {field(
                "fixingMethod",
                "Fixing method",
                <SelectNative
                  id="fixingMethod"
                  name="fixingMethod"
                  defaultValue={values.fixingMethod ?? ""}
                >
                  <option value="">— Select —</option>
                  {FIXINGS.map((f) => (
                    <option key={f} value={f}>
                      {f.charAt(0).toUpperCase() + f.slice(1).replace(/_/g, " ")}
                    </option>
                  ))}
                </SelectNative>,
              )}
              <label className="col-span-2 flex items-center gap-2 text-sm sm:col-span-4">
                <input
                  type="checkbox"
                  name="requiresVenueApproval"
                  className="size-4"
                  defaultChecked={values.requiresVenueApproval}
                />
                Needs venue approval (always for rigged items)
              </label>
            </section>
            <section className="grid gap-3 sm:grid-cols-3">
              {sectionTitle("Supplier, cost and install", "sm:col-span-3")}
              {field("supplierId", "Supplier", supplierSelect)}
              {canSeeCosts &&
                field(
                  "costEstimate",
                  "Cost price (£)",
                  numberInput("costEstimate", { step: "0.01", disabled: !costEditable }),
                )}
              {field("installDate", "Install date", dateInput("installDate"))}
            </section>
          </>
        )}

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

        <details
          className="rounded-lg border"
          open={moreOpen}
          onToggle={(e) => setMoreOpen(e.currentTarget.open)}
        >
          <summary className="cursor-pointer px-4 py-3 text-sm font-semibold select-none">
            More details
            <span className="text-muted-foreground ml-2 text-xs font-normal">
              {moreFilled > 0 ? `${moreFilled} filled in` : "notes, extra spec, purchasing, dates"}
            </span>
          </summary>
          <section className="grid gap-3 px-4 pb-4 sm:grid-cols-3">
            {field(
              "description",
              "Notes",
              <Textarea
                id="description"
                name="description"
                defaultValue={values.description ?? ""}
              />,
              { span: "sm:col-span-3" },
            )}
            {isSponsorship ? (
              <>
                {field("widthMm", "Width (mm)", numberInput("widthMm"))}
                {field("heightMm", "Height (mm)", numberInput("heightMm"))}
                <input type="hidden" name="ownerRole" value={values.ownerRole ?? "ops"} />
              </>
            ) : (
              <>
                {field(
                  "ownerRole",
                  "Owner",
                  <SelectNative
                    id="ownerRole"
                    name="ownerRole"
                    defaultValue={values.ownerRole ?? "ops"}
                  >
                    <option value="ops">Operations</option>
                    <option value="marketing">Marketing</option>
                  </SelectNative>,
                )}
                {field("depthMm", "Depth (mm)", numberInput("depthMm"))}
                {field(
                  "sided",
                  "Sided",
                  <SelectNative id="sided" name="sided" defaultValue={values.sided ?? "single"}>
                    <option value="single">Single</option>
                    <option value="double">Double</option>
                  </SelectNative>,
                )}
                {field("weightKg", "Weight (kg)", numberInput("weightKg", { step: "0.1" }))}
              </>
            )}
            {field(
              "material",
              "Material",
              <Input id="material" name="material" defaultValue={values.material ?? ""} />,
            )}
            {field(
              "finish",
              "Finish",
              <Input id="finish" name="finish" defaultValue={values.finish ?? ""} />,
            )}
            {(isSponsorship || category === "sponsor") &&
              field(
                "sponsorEntitlementId",
                "Sponsor entitlement",
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
                </SelectNative>,
              )}
            {canSeeCosts && (
              <>
                {field(
                  "costActual",
                  "Actual cost (£)",
                  numberInput("costActual", { step: "0.01", disabled: !costEditable }),
                )}
                {field(
                  "poNumber",
                  "PO number",
                  <Input
                    id="poNumber"
                    name="poNumber"
                    defaultValue={values.poNumber ?? ""}
                    disabled={!costEditable}
                  />,
                )}
                {field(
                  "budgetLine",
                  "Budget line",
                  <Input
                    id="budgetLine"
                    name="budgetLine"
                    defaultValue={values.budgetLine ?? ""}
                    disabled={!costEditable}
                  />,
                )}
              </>
            )}
            {field(
              "artworkDueOverride",
              "Artwork due (if different)",
              dateInput("artworkDueOverride"),
            )}
            {!isSponsorship && field("printDeadline", "Print deadline", dateInput("printDeadline"))}
            {field("deliveryDate", "Delivery date", dateInput("deliveryDate"))}
            {!isSponsorship && (
              <>
                {field(
                  "installSlot",
                  "Install slot",
                  <SelectNative
                    id="installSlot"
                    name="installSlot"
                    defaultValue={values.installSlot ?? ""}
                  >
                    <option value="">— None —</option>
                    <option value="am">AM</option>
                    <option value="pm">PM</option>
                    <option value="overnight">Overnight</option>
                  </SelectNative>,
                )}
                {field(
                  "installContractorId",
                  "Install contractor",
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
                  </SelectNative>,
                )}
              </>
            )}
            {mode === "create" &&
              options.workflows.length > 1 &&
              field(
                "workflowId",
                "Sign-off workflow",
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
                </SelectNative>,
              )}
          </section>
        </details>
        {mode === "create" && options.workflows.length === 1 && (
          <input type="hidden" name="workflowId" value={options.workflows[0].id} />
        )}
      </fieldset>
      {!readOnly &&
        mode === "edit" &&
        status &&
        ["approved", "approved_with_conditions", "in_production", "delivered"].includes(status) && (
          <p className="text-sm text-amber-800 dark:text-amber-300">
            This item is signed off. Changing its size, material, fixing, type, sponsor or who signs
            it off sends it back for sign-off; dates, supplier and costs can change freely.
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
