"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { createStandDesign } from "@/app/actions/stand-designs";
import { updateSignageItem } from "@/app/actions/signage";
import type { SignoffChoice, SignoffStepOption } from "@/components/signage/item-form";
import { SignoffPicker, updatePlan } from "@/components/signage/signoff-picker";

export type StandFormOptions = {
  halls: { id: string; name: string }[];
  locations: { id: string; name: string; hallId: string }[];
  sponsors: { id: string; name: string }[];
  signoffSteps: SignoffStepOption[];
};

export type StandFormValues = {
  id?: string;
  name?: string;
  standNumber?: string | null;
  hallId?: string | null;
  locationId?: string | null;
  widthMm?: number | null;
  depthMm?: number | null;
  heightMm?: number | null;
  category?: string | null;
  sponsorId?: string | null;
  description?: string | null;
  signoffs?: SignoffChoice[] | null;
};

/**
 * A stand the organiser designs: where it is, its size, and who approves
 * the design. Used to create a stand and to edit it.
 */
export function StandForm({
  mode,
  editionId,
  editionCode,
  values,
  options,
  status,
  readOnly = false,
}: {
  mode: "create" | "edit";
  editionId?: string;
  editionCode: string;
  values: StandFormValues;
  options: StandFormOptions;
  status?: string;
  readOnly?: boolean;
}) {
  const steps = options.signoffSteps;
  const [category, setCategory] = useState(values.category ?? "organiser");
  const [hallId, setHallId] = useState(values.hallId ?? "");
  const [plan, setPlan] = useState<SignoffChoice[]>(
    values.signoffs ??
      steps
        .filter((s) => s.defaultFor.includes(values.category ?? "organiser"))
        .map((s) => ({ stepId: s.id, userId: s.defaultUserId })),
  );
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [pending, start] = useTransition();
  const router = useRouter();
  const locations = options.locations.filter((l) => !hallId || l.hallId === hallId);

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (plan.length === 0) {
      setError("Choose at least one department to approve the design");
      return;
    }
    const fd = new FormData(e.currentTarget);
    const raw: Record<string, unknown> = {};
    for (const [k, v] of fd.entries()) raw[k] = v === "" ? null : v;
    raw.category = category;
    raw.signoffs = plan;
    if (category !== "sponsor") raw.sponsorId = null;
    setError(null);
    setMessage(null);
    setErrors({});
    start(async () => {
      if (mode === "create") {
        const res = await createStandDesign({ ...raw, editionId });
        if (!res.ok) {
          setError(res.error);
          setErrors(res.fieldErrors ?? {});
        } else {
          router.push(`/${editionCode}/stand-designs/${res.data?.ref}?tab=artwork`);
        }
      } else {
        const res = await updateSignageItem({ ...raw, id: values.id });
        if (!res.ok) {
          setError(res.error);
          setErrors(res.fieldErrors ?? {});
        } else {
          setTouched(false);
          setMessage(res.message ?? "Saved");
          router.refresh();
        }
      }
    });
  }

  const field = (id: string, label: string, control: React.ReactNode, className = "") => (
    <div className={`grid gap-1.5 ${className}`}>
      <Label htmlFor={id}>{label}</Label>
      {control}
      {errors[id] && <p className="text-destructive text-xs">{errors[id]}</p>}
    </div>
  );
  const mmInput = (id: "widthMm" | "depthMm" | "heightMm") => (
    <Input
      id={id}
      name={id}
      type="number"
      inputMode="numeric"
      min={1}
      defaultValue={values[id] ?? ""}
      disabled={readOnly}
    />
  );

  return (
    <form onSubmit={onSubmit} className="grid max-w-3xl gap-6">
      <fieldset disabled={readOnly || pending} className="grid gap-6">
        <section className="grid gap-3 sm:grid-cols-2">
          {field(
            "name",
            "Stand name",
            <Input
              id="name"
              name="name"
              required
              defaultValue={values.name ?? ""}
              placeholder="e.g. Feature stand — main entrance"
            />,
            "sm:col-span-2",
          )}
          {field(
            "standNumber",
            "Stand no.",
            <Input
              id="standNumber"
              name="standNumber"
              defaultValue={values.standNumber ?? ""}
              placeholder="e.g. A01"
              maxLength={50}
            />,
          )}
          <div className="grid gap-1.5">
            <Label>Whose stand</Label>
            <div className="flex gap-2" role="radiogroup" aria-label="Whose stand">
              {(["organiser", "sponsor"] as const).map((c) => (
                <label
                  key={c}
                  className={`flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-md border px-3 py-1.5 text-sm ${
                    category === c ? "border-primary bg-primary/5 font-medium" : ""
                  }`}
                >
                  <input
                    type="radio"
                    className="sr-only"
                    checked={category === c}
                    onChange={() => setCategory(c)}
                  />
                  {c === "organiser" ? "Organiser" : "Sponsor"}
                </label>
              ))}
            </div>
          </div>
          {category === "sponsor" &&
            field(
              "sponsorId",
              "Sponsor",
              <SelectNative id="sponsorId" name="sponsorId" defaultValue={values.sponsorId ?? ""}>
                <option value="">— Select —</option>
                {options.sponsors.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </SelectNative>,
              "sm:col-span-2",
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
            <SelectNative id="locationId" name="locationId" defaultValue={values.locationId ?? ""}>
              <option value="">— Select —</option>
              {locations.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name}
                </option>
              ))}
            </SelectNative>,
          )}
        </section>

        <section className="grid grid-cols-3 gap-3">
          <h3 className="col-span-3 text-sm font-semibold">Size (mm)</h3>
          {field("widthMm", "Width", mmInput("widthMm"))}
          {field("depthMm", "Depth", mmInput("depthMm"))}
          {field("heightMm", "Height", mmInput("heightMm"))}
        </section>

        {field(
          "description",
          "Notes",
          <Textarea
            id="description"
            name="description"
            rows={3}
            defaultValue={values.description ?? ""}
            placeholder="Brief, build notes, anything reviewers should know"
          />,
        )}

        <section className="grid gap-2">
          <div>
            <h3 className="text-sm font-semibold">Who approves the design</h3>
            <p className="text-muted-foreground text-xs">
              Tick each department that signs off, and pick a person or leave it to anyone in the
              department. The same people approve each panel&apos;s graphics once the design is
              approved.
            </p>
          </div>
          {steps.length === 0 ? (
            <p className="text-sm text-amber-800 dark:text-amber-300">
              No departments set up yet — add them under Approvals → Approvers.
            </p>
          ) : (
            <SignoffPicker
              steps={steps}
              plan={plan}
              label="Who approves the design"
              onChange={(stepId, on, userId) => {
                setTouched(true);
                setPlan((p) => updatePlan(steps, p, stepId, on, userId));
              }}
            />
          )}
          {(plan.length === 0 || errors.signoffs) && (
            <p className="text-destructive text-xs">
              {errors.signoffs ?? "Choose at least one department."}
            </p>
          )}
          {mode === "edit" && touched && status && status !== "draft" && (
            <p className="text-xs text-amber-800 dark:text-amber-300">
              Saving a change to who approves starts the design sign-off again.
            </p>
          )}
        </section>
      </fieldset>

      {!readOnly && (
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" disabled={pending}>
            {mode === "create" ? "Create stand" : "Save changes"}
          </Button>
          {pending && <span className="text-muted-foreground text-sm">Saving…</span>}
          {message && <span className="text-sm text-emerald-700">{message}</span>}
          {error && <span className="text-destructive text-sm">{error}</span>}
        </div>
      )}
    </form>
  );
}
