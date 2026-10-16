"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { toast } from "sonner";
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
 * Add a graphic panel to a stand — at any point before it is complete, so
 * printers can quote early. Its graphic goes for sign-off once the design
 * is approved.
 */
export function AddPanelButton({
  standId,
  editionCode,
  enabled,
  suppliers,
  designApproved = true,
}: {
  standId: string;
  editionCode: string;
  enabled: boolean;
  suppliers: { id: string; name: string }[];
  /** Approved: the new panel opens on its graphic; before that, on its details. */
  designApproved?: boolean;
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
      toast.success(res.message ?? "Panel added");
      router.push(
        `/${editionCode}/stand-panels/${res.data?.ref}?${designApproved ? "tab=artwork&" : ""}created=1`,
      );
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
              Name and size the panel. Its graphic goes to the stand&apos;s approvers once the
              design is approved.
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
                {pending ? "Adding…" : "Add panel"}
              </Button>
              {error && <span className="text-destructive text-sm">{error}</span>}
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
