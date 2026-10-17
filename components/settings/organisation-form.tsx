"use client";

import { useId, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { updateOrganisationSettings } from "@/app/actions/organisation";

export type OrganisationValues = {
  brandName: string;
  currency: string;
  escalateAfterDays: number;
  installPhotoRequired: boolean;
};

const CURRENCIES = [
  { value: "GBP", label: "Pounds sterling (£)" },
  { value: "EUR", label: "Euros (€)" },
  { value: "USD", label: "US dollars ($)" },
];

/** Settings → Organisation: name, currency (shown, not yet changeable) and the company-wide rules. */
export function OrganisationForm({ initial }: { initial: OrganisationValues }) {
  const [values, setValues] = useState<OrganisationValues>(initial);
  const [saved, setSaved] = useState<OrganisationValues>(initial);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const ids = useId();
  const errorId = `${ids}-error`;
  const dirty = JSON.stringify(values) !== JSON.stringify(saved);
  const set = <K extends keyof OrganisationValues>(key: K, v: OrganisationValues[K]) =>
    setValues((x) => ({ ...x, [key]: v }));

  return (
    <form
      className="max-w-xl space-y-6"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        start(async () => {
          const res = await updateOrganisationSettings({
            brandName: values.brandName,
            escalateAfterDays: values.escalateAfterDays,
            installPhotoRequired: values.installPhotoRequired,
          });
          if (!res.ok) {
            setError(res.error);
            return;
          }
          setSaved(values);
          toast.success(res.message ?? "Organisation settings saved");
          router.refresh();
        });
      }}
    >
      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-name`}>Organisation name</Label>
        <Input
          id={`${ids}-name`}
          value={values.brandName}
          onChange={(e) => set("brandName", e.target.value)}
          required
          maxLength={60}
          aria-describedby={`${ids}-name-hint${error ? ` ${errorId}` : ""}`}
          className="h-11 sm:h-9"
        />
        <p id={`${ids}-name-hint`} className="text-muted-foreground text-xs">
          Shown at the top of every page, in emails and on exports and labels.
        </p>
      </div>

      {/* Read-only until costs, labels and exports use it (they show pounds today). */}
      <div className="space-y-1.5">
        <p className="text-sm font-medium">Currency</p>
        <p className="text-sm">
          {CURRENCIES.find((c) => c.value === values.currency)?.label ?? values.currency}
        </p>
        <p className="text-muted-foreground text-xs">
          Costs, budgets and sponsorship prices are shown in pounds. Other currencies aren&apos;t
          available yet.
        </p>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-days`}>Chase overdue sign-offs after</Label>
        <div className="flex items-center gap-2">
          <Input
            id={`${ids}-days`}
            type="number"
            inputMode="numeric"
            min={1}
            max={14}
            step={1}
            required
            value={Number.isFinite(values.escalateAfterDays) ? values.escalateAfterDays : ""}
            onChange={(e) => set("escalateAfterDays", e.target.valueAsNumber)}
            aria-describedby={`${ids}-days-hint${error ? ` ${errorId}` : ""}`}
            className="h-11 w-24 sm:h-9"
          />
          <span className="text-sm">{values.escalateAfterDays === 1 ? "day" : "days"}</span>
        </div>
        <p id={`${ids}-days-hint`} className="text-muted-foreground text-xs">
          When a sign-off is this many days past its due date, super admins and the item&rsquo;s
          owner are told so they can chase it. Between 1 and 14 days.
        </p>
      </div>

      <div className="space-y-1.5">
        <label className="flex items-start gap-2.5 text-sm">
          <input
            type="checkbox"
            className="mt-0.5 size-4"
            checked={values.installPhotoRequired}
            onChange={(e) => set("installPhotoRequired", e.target.checked)}
            aria-describedby={`${ids}-photo-hint`}
          />
          <span>
            <span className="font-medium">
              Installers must add a photo before marking a sign installed
            </span>
            <span id={`${ids}-photo-hint`} className="text-muted-foreground block text-xs">
              Applies on every event — on the Onsite page, the item page and the supplier portal.
            </span>
          </span>
        </label>
      </div>

      {error && (
        <p id={errorId} role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={pending || !dirty}>
          {pending ? "Saving…" : "Save changes"}
        </Button>
        {dirty && !pending && (
          <Button type="button" variant="ghost" onClick={() => setValues(saved)}>
            Undo changes
          </Button>
        )}
      </div>
    </form>
  );
}
