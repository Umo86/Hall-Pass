"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import { updateSignageItem } from "@/app/actions/signage";

export type PanelFormValues = {
  id: string;
  ref: string;
  name: string;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number;
  supplierId: string | null;
  material: string | null;
  finish: string | null;
  description: string | null;
  /** When it goes up (Onsite lists it on that day). */
  installDate: string | null;
};

/**
 * A stand panel's own details: name, size, quantity, printer, material,
 * finish, install date and notes. Where it is and who signs it off come
 * from its stand.
 */
export function PanelForm({
  values,
  suppliers,
  lockSpec,
  status,
  onCancel,
  onSaved,
}: {
  values: PanelFormValues;
  suppliers: { id: string; name: string }[];
  /** Installed: what was approved can't change. */
  lockSpec: boolean;
  status: string;
  onCancel: () => void;
  onSaved: () => void;
}) {
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const signedOff = !["draft", "awaiting_artwork"].includes(status);

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const raw: Record<string, unknown> = { id: values.id };
    for (const [k, v] of fd.entries()) raw[k] = v === "" ? null : v;
    setError(null);
    setErrors({});
    start(async () => {
      const res = await updateSignageItem(raw);
      if (!res.ok) {
        setError(res.error);
        setErrors(res.fieldErrors ?? {});
        return;
      }
      toast.success(res.message ?? `${values.ref} saved`);
      onSaved();
      router.refresh();
    });
  }

  const field = (id: string, label: string, control: React.ReactNode, className = "") => (
    <div className={`grid gap-1.5 ${className}`}>
      <Label htmlFor={id}>{label}</Label>
      {control}
      {errors[id] && <p className="text-destructive text-xs">{errors[id]}</p>}
    </div>
  );

  return (
    <form onSubmit={onSubmit} className="grid max-w-3xl gap-4" aria-label="Edit panel">
      {lockSpec && (
        <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          Installed — only the printer, install date and notes can change. To change the spec, use
          More → Undo install first.
        </p>
      )}
      <fieldset disabled={pending} className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {field(
          "name",
          "Panel name",
          <Input id="name" name="name" required defaultValue={values.name} disabled={lockSpec} />,
          "col-span-2 sm:col-span-3",
        )}
        {field(
          "widthMm",
          "Width (mm)",
          <Input
            id="widthMm"
            name="widthMm"
            type="number"
            inputMode="numeric"
            min={1}
            required
            defaultValue={values.widthMm ?? ""}
            disabled={lockSpec}
          />,
        )}
        {field(
          "heightMm",
          "Height (mm)",
          <Input
            id="heightMm"
            name="heightMm"
            type="number"
            inputMode="numeric"
            min={1}
            required
            defaultValue={values.heightMm ?? ""}
            disabled={lockSpec}
          />,
        )}
        {field(
          "quantity",
          "Quantity",
          <Input
            id="quantity"
            name="quantity"
            type="number"
            inputMode="numeric"
            min={1}
            defaultValue={values.quantity}
            disabled={lockSpec}
          />,
        )}
        {field(
          "supplierId",
          "Printer",
          <SelectNative id="supplierId" name="supplierId" defaultValue={values.supplierId ?? ""}>
            <option value="">— Not chosen yet —</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </SelectNative>,
          "col-span-2 sm:col-span-1",
        )}
        {field(
          "material",
          "Material",
          <Input
            id="material"
            name="material"
            defaultValue={values.material ?? ""}
            disabled={lockSpec}
          />,
        )}
        {field(
          "finish",
          "Finish",
          <Input
            id="finish"
            name="finish"
            defaultValue={values.finish ?? ""}
            disabled={lockSpec}
          />,
        )}
        {field(
          "installDate",
          "Install date",
          <Input
            id="installDate"
            name="installDate"
            type="date"
            defaultValue={values.installDate ?? ""}
          />,
        )}
        {field(
          "description",
          "Notes",
          <Textarea id="description" name="description" defaultValue={values.description ?? ""} />,
          "col-span-2 sm:col-span-3",
        )}
      </fieldset>
      {signedOff && !lockSpec && (
        <p className="text-xs text-amber-800 dark:text-amber-300">
          Changing the name, size, quantity, material or finish sends its graphic back for sign-off.
        </p>
      )}
      <div className="bg-background/95 sticky bottom-0 z-10 flex flex-wrap items-center gap-3 border-t py-3 backdrop-blur">
        <Button type="submit" disabled={pending}>
          {pending ? "Saving…" : "Save changes"}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel} disabled={pending}>
          Cancel
        </Button>
        {error && (
          <span role="alert" className="text-destructive text-sm">
            {error}
          </span>
        )}
      </div>
    </form>
  );
}
