"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { addStandPanel } from "@/app/actions/stand-designs";

/**
 * Add a graphic panel to an approved stand. Before the design is approved
 * the button stays off and says why.
 */
export function AddPanelButton({
  standId,
  editionCode,
  enabled,
  suppliers,
}: {
  standId: string;
  editionCode: string;
  enabled: boolean;
  suppliers: { id: string; name: string }[];
}) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [pending, start] = useTransition();
  const router = useRouter();

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const raw: Record<string, unknown> = { standId };
    for (const [k, v] of fd.entries()) raw[k] = v === "" ? null : v;
    setError(null);
    setErrors({});
    start(async () => {
      const res = await addStandPanel(raw);
      if (!res.ok) {
        setError(res.error);
        setErrors(res.fieldErrors ?? {});
        return;
      }
      setOpen(false);
      router.push(`/${editionCode}/stand-panels/${res.data?.ref}?tab=artwork`);
    });
  }

  const field = (
    id: string,
    label: string,
    control: React.ReactNode,
    className = "",
    name = id,
  ) => (
    <div className={`grid gap-1.5 ${className}`}>
      <Label htmlFor={id}>{label}</Label>
      {control}
      {errors[name] && <p className="text-destructive text-xs">{errors[name]}</p>}
    </div>
  );

  return (
    <>
      <Button size="sm" disabled={!enabled} onClick={() => setOpen(true)}>
        <Plus className="size-4" /> Add panel
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add a panel</DialogTitle>
            <DialogDescription>
              Name and size the panel, then upload its graphic. The stand&apos;s approvers sign it
              off.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={onSubmit} className="grid grid-cols-2 gap-3">
            {field(
              "panelName",
              "Panel name",
              <Input id="panelName" name="name" required placeholder="e.g. Back wall left" />,
              "col-span-2",
              "name",
            )}
            {field(
              "widthMm",
              "Width (mm)",
              <Input id="widthMm" name="widthMm" type="number" min={1} required />,
            )}
            {field(
              "heightMm",
              "Height (mm)",
              <Input id="heightMm" name="heightMm" type="number" min={1} required />,
            )}
            {field(
              "quantity",
              "Quantity",
              <Input id="quantity" name="quantity" type="number" min={1} defaultValue={1} />,
            )}
            {field(
              "supplierId",
              "Printer",
              <SelectNative id="supplierId" name="supplierId" defaultValue="">
                <option value="">— Not chosen yet —</option>
                {suppliers.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </SelectNative>,
            )}
            {field("material", "Material", <Input id="material" name="material" />)}
            {field("finish", "Finish", <Input id="finish" name="finish" />)}
            <div className="col-span-2 flex flex-wrap items-center gap-3">
              <Button type="submit" disabled={pending}>
                Add panel
              </Button>
              {error && <span className="text-destructive text-sm">{error}</span>}
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
