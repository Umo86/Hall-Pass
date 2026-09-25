"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { roleLabel } from "@/lib/format";
import { archiveSignoffStep, saveSignoffStep } from "@/app/actions/workflows";

export type SignoffStepRow = {
  id: string;
  name: string;
  department: string | null;
  defaultUserId: string | null;
  defaultFor: string[];
  slaDays: number;
  together: boolean;
};

export type SignoffPerson = { id: string; name: string; role: string };

const DEPARTMENTS = ["ops", "marketing", "sales", "event_director", "admin"];

/**
 * Settings → Sign-off: the departments that can sign items off, who in each
 * signs by default, and which kinds of signage get them without asking.
 */
export function SignoffEditor({
  steps,
  alwaysSteps,
  people,
  canEdit,
}: {
  steps: SignoffStepRow[];
  /** Steps every item still goes through when they apply (venue, print…). */
  alwaysSteps: string[];
  people: SignoffPerson[];
  canEdit: boolean;
}) {
  const [editing, setEditing] = useState<SignoffStepRow | "new" | null>(null);
  const [department, setDepartment] = useState("ops");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const current = editing === "new" ? null : editing;
  const nameOf = new Map(people.map((p) => [p.id, p.name]));

  function open(row: SignoffStepRow | "new") {
    setError(null);
    setDepartment(row === "new" ? "ops" : (row.department ?? "ops"));
    setEditing(row);
  }

  const choices = people.filter((p) => p.role === department || p.role === "admin");

  return (
    <div className="space-y-3">
      <ul className="divide-y rounded-lg border">
        {steps.map((s) => (
          <li key={s.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2.5 text-sm">
            <div className="min-w-0 flex-1">
              <p className="font-medium">{s.name}</p>
              <p className="text-muted-foreground text-xs">
                {s.defaultUserId
                  ? `${nameOf.get(s.defaultUserId) ?? "A named person"} (${roleLabel(s.department)})`
                  : `Anyone in ${roleLabel(s.department)}`}
                {" · "}
                {s.defaultFor.length === 2
                  ? "on by default for organiser and sponsor signage"
                  : s.defaultFor.includes("sponsor")
                    ? "on by default for sponsor signage"
                    : s.defaultFor.includes("organiser")
                      ? "on by default for organiser signage"
                      : "off unless chosen on the item"}
                {" · "}
                {s.slaDays} days to decide
                {s.together ? "" : " · after the others"}
              </p>
            </div>
            {canEdit && (
              <span className="flex gap-1">
                <Button size="sm" variant="outline" onClick={() => open(s)}>
                  Edit
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pending}
                  onClick={() => {
                    if (!window.confirm(`Remove “${s.name}”? Items already in sign-off keep it.`)) return;
                    setError(null);
                    start(async () => {
                      const res = await archiveSignoffStep({ id: s.id });
                      if (!res.ok) setError(res.error);
                      router.refresh();
                    });
                  }}
                >
                  Remove
                </Button>
              </span>
            )}
          </li>
        ))}
      </ul>
      {canEdit && (
        <Button size="sm" variant="outline" onClick={() => open("new")}>
          <Plus className="size-4" /> Add a department sign-off
        </Button>
      )}
      <p className="text-muted-foreground text-xs">
        Each item shows these as ticks, pre-set from the defaults above; whoever adds or edits the
        item can change them and pick the person in each department. The chosen person is
        notified by email. {alwaysSteps.length > 0 && <>Also, when they apply: {alwaysSteps.join(", ")}.</>}{" "}
        Changes apply to sign-offs started from now on.
      </p>
      {error && !editing && <p className="text-destructive text-sm">{error}</p>}

      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{current ? `Edit ${current.name}` : "Add a department sign-off"}</DialogTitle>
            <DialogDescription>Who signs off, and when it&apos;s needed by default.</DialogDescription>
          </DialogHeader>
          <form
            id="signoff-step-form"
            className="grid gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              const fd = new FormData(e.currentTarget);
              setError(null);
              start(async () => {
                const res = await saveSignoffStep({
                  id: current?.id,
                  name: fd.get("name"),
                  department: fd.get("department"),
                  defaultUserId: (fd.get("defaultUserId") as string) || null,
                  defaultFor: fd.getAll("defaultFor"),
                  slaDays: fd.get("slaDays"),
                });
                if (!res.ok) setError(res.error);
                else {
                  setEditing(null);
                  router.refresh();
                }
              });
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="step-name">Name</Label>
              <Input
                id="step-name"
                name="name"
                required
                defaultValue={current?.name ?? ""}
                placeholder="e.g. Legal sign-off"
              />
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="step-department">Department</Label>
                <SelectNative
                  id="step-department"
                  name="department"
                  value={department}
                  onChange={(e) => setDepartment(e.target.value)}
                >
                  {DEPARTMENTS.map((d) => (
                    <option key={d} value={d}>
                      {roleLabel(d)}
                    </option>
                  ))}
                </SelectNative>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="step-person">Signed off by</Label>
                <SelectNative
                  key={department}
                  id="step-person"
                  name="defaultUserId"
                  defaultValue={
                    current?.defaultUserId && choices.some((c) => c.id === current.defaultUserId)
                      ? current.defaultUserId
                      : ""
                  }
                >
                  <option value="">Anyone in {roleLabel(department)}</option>
                  {choices.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </SelectNative>
              </div>
            </div>
            <fieldset className="space-y-1.5">
              <legend className="text-sm font-medium">On by default for</legend>
              <div className="flex flex-wrap gap-4 text-sm">
                {(["organiser", "sponsor"] as const).map((c) => (
                  <label key={c} className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      name="defaultFor"
                      value={c}
                      className="size-4"
                      defaultChecked={current ? current.defaultFor.includes(c) : true}
                    />
                    {c === "organiser" ? "Organiser signage" : "Sponsor signage"}
                  </label>
                ))}
              </div>
            </fieldset>
            <div className="space-y-1.5">
              <Label htmlFor="step-sla">Days to decide</Label>
              <Input
                id="step-sla"
                name="slaDays"
                type="number"
                min={0}
                max={60}
                defaultValue={current?.slaDays ?? 3}
                className="w-24"
              />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
          </form>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button type="submit" form="signoff-step-form" disabled={pending}>
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
