"use client";

import { FilePlus2, Gift, HardHat, Megaphone, Settings2 } from "lucide-react";
import type { PersonTemplate, PersonTemplateId } from "@/lib/users/templates";
import { roleLabel } from "@/lib/format";
import { cn } from "@/lib/utils";

const ICONS: Record<PersonTemplateId, React.ComponentType<{ className?: string }>> = {
  blank: FilePlus2,
  marketing_executive: Megaphone,
  freelance_installer: HardHat,
  sales_manager: Gift,
  operations_coordinator: Settings2,
};

/** "Start from": template cards that fill the role, sections and abilities. */
export function TemplatePicker({
  name,
  templates,
  value,
  onChange,
}: {
  name: string;
  templates: readonly PersonTemplate[];
  value: PersonTemplateId;
  onChange: (template: PersonTemplate) => void;
}) {
  if (templates.length <= 1) return null;
  return (
    <fieldset className="space-y-2">
      <legend className="text-sm font-medium">Start from</legend>
      <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {templates.map((t) => {
          const Icon = ICONS[t.id];
          const checked = value === t.id;
          return (
            <label
              key={t.id}
              className={cn(
                "focus-within:ring-ring flex min-h-11 cursor-pointer items-start gap-3 rounded-md border p-3 text-sm transition-colors focus-within:ring-2",
                checked ? "border-primary bg-primary/5 ring-primary ring-1" : "hover:bg-muted/40",
              )}
            >
              <input
                type="radio"
                name={name}
                value={t.id}
                checked={checked}
                onChange={() => onChange(t)}
                className="sr-only"
              />
              <Icon className="text-muted-foreground mt-0.5 size-4 shrink-0" aria-hidden />
              <span className="min-w-0">
                <span className="block font-medium">{t.name}</span>
                <span className="text-muted-foreground block text-xs">
                  {t.role ? `${roleLabel(t.role)} · ` : ""}
                  {t.description}
                  {t.events === "current" ? " Usually for one event." : ""}
                </span>
              </span>
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}
