"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { SelectNative } from "@/components/ui/select-native";
import { statusLabel } from "@/lib/format";
import { updateStepApprover } from "@/app/actions/workflows";

const ROLE_OPTIONS = [
  "admin",
  "ops",
  "marketing",
  "sales",
  "event_director",
  "venue",
  "structural_engineer",
  "hs",
  "supplier",
  "sponsor",
  "contractor",
];

export type ApproverStaff = { id: string; name: string };

/**
 * One select per step: "Role: …" options followed by "Person: …" for every
 * staff member. Saves on change; future runs pick it up.
 */
export function WorkflowApproverForm({
  stepId,
  approverType,
  approverRole,
  approverUserId,
  staff,
}: {
  stepId: string;
  approverType: string;
  approverRole: string | null;
  approverUserId: string | null;
  staff: ApproverStaff[];
}) {
  const current =
    approverType === "user" && approverUserId ? `user:${approverUserId}` : `role:${approverRole ?? ""}`;
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function onChange(value: string) {
    const [type, id] = value.split(":", 2);
    setError(null);
    start(async () => {
      const res = await updateStepApprover({
        stepId,
        approverType: type,
        approverRole: type === "role" ? id : null,
        approverUserId: type === "user" ? id : null,
      });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  return (
    <span className="inline-flex flex-wrap items-center gap-2">
      <SelectNative
        aria-label="Approver"
        value={current}
        disabled={pending}
        onChange={(e) => onChange(e.target.value)}
        className="h-7 w-auto py-0 text-xs"
      >
        {ROLE_OPTIONS.map((r) => (
          <option key={r} value={`role:${r}`}>
            Role: {statusLabel(r)}
          </option>
        ))}
        {staff.map((s) => (
          <option key={s.id} value={`user:${s.id}`}>
            Person: {s.name}
          </option>
        ))}
      </SelectNative>
      {error && <span className="text-destructive text-xs">{error}</span>}
    </span>
  );
}
