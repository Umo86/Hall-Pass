"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { saveStandQuestionnaire } from "@/app/actions/stands";

export type QuestionnaireValues = {
  submissionId: string;
  maxHeightMm: number | null;
  isDoubleDeck: boolean;
  hasPlatformOver600mm: boolean;
  hasRampedRaisedFloor: boolean;
  hasRigging: boolean;
  hasCeilingOrRoof: boolean;
  hasTieredSeating: boolean;
  otherComplexNotes: string | null;
  isComplex: boolean;
};

const TRIGGERS: Array<[keyof QuestionnaireValues, string]> = [
  ["isDoubleDeck", "Double deck"],
  ["hasPlatformOver600mm", "Platform or stage over 600 mm"],
  ["hasRampedRaisedFloor", "Ramped raised floor"],
  ["hasRigging", "Rigging or suspended items"],
  ["hasCeilingOrRoof", "Ceiling or roof"],
  ["hasTieredSeating", "Tiered seating"],
];

export function QuestionnaireForm({
  values,
  readOnly,
}: {
  values: QuestionnaireValues;
  readOnly: boolean;
}) {
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  if (readOnly) {
    return (
      <dl className="grid max-w-xl grid-cols-1 gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
        <dt className="text-muted-foreground">Maximum height</dt>
        <dd>{values.maxHeightMm ? `${values.maxHeightMm} mm` : "Not set"}</dd>
        {TRIGGERS.map(([key, label]) => (
          <FragmentRow key={key} label={label} value={Boolean(values[key])} />
        ))}
        <dt className="text-muted-foreground">Other notes</dt>
        <dd>{values.otherComplexNotes || "—"}</dd>
        <dt className="text-muted-foreground">Classification</dt>
        <dd className={values.isComplex ? "font-medium text-orange-700 dark:text-orange-400" : ""}>
          {values.isComplex ? "Complex structure — engineer review required" : "Standard"}
        </dd>
      </dl>
    );
  }

  return (
    <form
      className="max-w-xl space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        setError(null);
        setMessage(null);
        start(async () => {
          const res = await saveStandQuestionnaire({
            submissionId: values.submissionId,
            maxHeightMm: fd.get("maxHeightMm") || null,
            isDoubleDeck: fd.get("isDoubleDeck") === "on",
            hasPlatformOver600mm: fd.get("hasPlatformOver600mm") === "on",
            hasRampedRaisedFloor: fd.get("hasRampedRaisedFloor") === "on",
            hasRigging: fd.get("hasRigging") === "on",
            hasCeilingOrRoof: fd.get("hasCeilingOrRoof") === "on",
            hasTieredSeating: fd.get("hasTieredSeating") === "on",
            otherComplexNotes: fd.get("otherComplexNotes") || null,
          });
          if (!res.ok) setError(res.error);
          else {
            setMessage(res.message ?? "Saved");
            router.refresh();
          }
        });
      }}
    >
      <div className="space-y-1.5">
        <Label htmlFor="maxHeightMm">Maximum height (mm)</Label>
        <Input
          id="maxHeightMm"
          name="maxHeightMm"
          type="number"
          min="1"
          defaultValue={values.maxHeightMm ?? ""}
          required
        />
        <p className="text-muted-foreground text-xs">
          Anything over 4,000 mm counts as a complex structure.
        </p>
      </div>
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium">Does the design include any of these?</legend>
        {TRIGGERS.map(([key, label]) => (
          <label key={key} className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              name={key}
              className="size-4"
              defaultChecked={Boolean(values[key])}
            />
            {label}
          </label>
        ))}
      </fieldset>
      <div className="space-y-1.5">
        <Label htmlFor="otherComplexNotes">Anything else structural we should know?</Label>
        <Textarea
          id="otherComplexNotes"
          name="otherComplexNotes"
          defaultValue={values.otherComplexNotes ?? ""}
        />
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={pending}>
          Save questionnaire
        </Button>
        {message && <span className="text-sm text-green-700 dark:text-green-400">{message}</span>}
        {error && <span className="text-destructive text-sm">{error}</span>}
      </div>
    </form>
  );
}

function FragmentRow({ label, value }: { label: string; value: boolean }) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd>{value ? "Yes" : "No"}</dd>
    </>
  );
}
