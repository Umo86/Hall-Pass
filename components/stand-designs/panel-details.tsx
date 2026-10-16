"use client";

import { useState } from "react";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { PanelForm, type PanelFormValues } from "./panel-form";

/**
 * A panel's Details tab: the facts, read-only, with "Edit details" swapping
 * in the slim panel form. The stand's line (where, who signs off) stays on
 * show above it.
 */
export function PanelDetails({
  canEdit,
  initialEditing,
  lockSpec,
  status,
  values,
  suppliers,
  fromStand,
  children,
}: {
  canEdit: boolean;
  initialEditing: boolean;
  lockSpec: boolean;
  status: string;
  values: PanelFormValues;
  suppliers: { id: string; name: string }[];
  /** "From the stand: Hall 1 · Stand Z99 · …" with its link. */
  fromStand: React.ReactNode;
  /** The read-only facts. */
  children: React.ReactNode;
}) {
  const [editing, setEditing] = useState(canEdit && initialEditing);

  if (editing) {
    return (
      <section aria-labelledby="edit-details-heading" className="grid gap-3">
        <h2 id="edit-details-heading" className="text-sm font-semibold">
          Edit details
        </h2>
        {fromStand}
        <PanelForm
          values={values}
          suppliers={suppliers}
          lockSpec={lockSpec}
          status={status}
          onCancel={() => setEditing(false)}
          onSaved={() => setEditing(false)}
        />
      </section>
    );
  }

  return (
    <section
      aria-labelledby="details-heading"
      className="grid max-w-4xl gap-3 rounded-lg border p-4 text-sm"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 id="details-heading" className="text-sm font-semibold">
          At a glance
        </h2>
        {canEdit && (
          <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
            <Pencil aria-hidden /> Edit details
          </Button>
        )}
      </div>
      {fromStand}
      {children}
    </section>
  );
}
