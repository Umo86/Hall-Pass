"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { tickRulesChecklist } from "@/app/actions/stands";

export type ChecklistItem = {
  ruleId: string;
  title: string;
  ruleText: string;
  checked: boolean;
  checkedByName: string | null;
  note: string | null;
};

export function RulesChecklist({
  submissionId,
  items,
  canTick,
}: {
  submissionId: string;
  items: ChecklistItem[];
  canTick: boolean;
}) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  if (items.length === 0) {
    return (
      <p className="text-muted-foreground text-sm">
        The checklist is generated from the venue rules when the design is submitted.
      </p>
    );
  }

  return (
    <>
      <ul className="max-w-3xl space-y-2">
        {items.map((item) => (
          <li key={item.ruleId} className="flex items-start gap-3 rounded-lg border p-3 text-sm">
            <input
              type="checkbox"
              className="mt-0.5 size-4"
              checked={item.checked}
              disabled={!canTick || pending}
              aria-label={item.title}
              onChange={(e) =>
                start(async () => {
                  const res = await tickRulesChecklist({
                    submissionId,
                    ruleId: item.ruleId,
                    checked: e.target.checked,
                  });
                  setError(res.ok ? null : res.error);
                  router.refresh();
                })
              }
            />
            <div>
              <p className="font-medium">{item.title}</p>
              <p className="text-muted-foreground text-xs">{item.ruleText}</p>
              {item.checkedByName && item.checked && (
                <p className="text-muted-foreground mt-0.5 text-xs">
                  Checked by {item.checkedByName}
                </p>
              )}
              {item.note && <p className="text-muted-foreground mt-0.5 text-xs">“{item.note}”</p>}
            </div>
          </li>
        ))}
      </ul>
      {error && <p className="text-destructive mt-2 text-sm">{error}</p>}
    </>
  );
}
