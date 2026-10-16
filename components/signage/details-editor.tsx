"use client";

import { useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ItemForm, type ItemFormProps } from "./item-form";

/**
 * The Details tab: the facts, read-only, with "Edit details" swapping in the
 * form (sticky Save and Cancel). Opens straight in edit mode from a
 * checklist link (`?edit=1#widthMm`).
 */
export function DetailsEditor({
  canEdit,
  initialEditing,
  formProps,
  children,
}: {
  canEdit: boolean;
  initialEditing: boolean;
  formProps: Omit<ItemFormProps, "mode" | "onCancel" | "onSaved">;
  /** The read-only facts. */
  children: React.ReactNode;
}) {
  const [editing, setEditing] = useState(canEdit && initialEditing);
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  // A "Change" link on this page (`?edit=1#ownerUserId`) opens the form too.
  const editParam = search.get("edit") === "1";
  const [seenEditParam, setSeenEditParam] = useState(editParam);
  if (editParam !== seenEditParam) {
    setSeenEditParam(editParam);
    if (editParam && canEdit) setEditing(true);
  }

  function leave() {
    setEditing(false);
    // A refresh afterwards shows the facts again, not the form.
    if (search.get("edit")) {
      const next = new URLSearchParams(search.toString());
      next.delete("edit");
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    }
  }

  if (editing) {
    return (
      <section aria-labelledby="edit-details-heading" className="grid gap-4">
        <h2 id="edit-details-heading" className="text-sm font-semibold">
          Edit details
        </h2>
        <ItemForm mode="edit" {...formProps} onCancel={leave} onSaved={leave} />
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
      {children}
    </section>
  );
}
