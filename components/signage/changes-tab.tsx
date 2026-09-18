"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { StatusBadge } from "@/components/status-badge";
import { formatDateTime } from "@/lib/format";
import { decideChangeRequest, raiseChangeRequest } from "@/app/actions/change-requests";

export type ChangeRequestRow = {
  id: string;
  reason: string;
  status: string;
  requesterName: string;
  deciderName: string | null;
  decidedAt: string | null;
  createdAt: string;
  reopenedCount: number;
  fieldChanges: Array<{ field: string; from: unknown; to: unknown }>;
};

const FIELD_LABELS: Record<string, string> = {
  name: "Name",
  widthMm: "Width (mm)",
  heightMm: "Height (mm)",
  depthMm: "Depth (mm)",
  quantity: "Quantity",
  material: "Material",
  finish: "Finish",
  installDate: "Install date",
  deliveryDate: "Delivery date",
};

function fmt(v: unknown): string {
  if (v === null || v === undefined || v === "") return "—";
  return String(v);
}

export function ChangesTab({
  itemId,
  requests,
  canRaise,
  canDecide,
}: {
  itemId: string;
  requests: ChangeRequestRow[];
  canRaise: boolean;
  canDecide: boolean;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [fields, setFields] = useState<Record<string, string>>({});

  function raise() {
    setError(null);
    const changes: Record<string, unknown> = {};
    const num = (k: string) => (fields[k]?.trim() ? Number(fields[k]) : undefined);
    if (fields.name?.trim()) changes.name = fields.name.trim();
    for (const k of ["widthMm", "heightMm", "quantity"]) {
      const v = num(k);
      if (v !== undefined && Number.isFinite(v)) changes[k] = v;
    }
    for (const k of ["material", "finish"]) {
      if (fields[k]?.trim()) changes[k] = fields[k].trim();
    }
    for (const k of ["installDate", "deliveryDate"]) {
      if (fields[k]) changes[k] = fields[k];
    }
    start(async () => {
      const res = await raiseChangeRequest({ itemId, reason, changes });
      if (!res.ok) setError(res.error);
      else {
        setReason("");
        setFields({});
        router.refresh();
      }
    });
  }

  function decide(id: string, decision: "approve" | "reject") {
    setError(null);
    start(async () => {
      const res = await decideChangeRequest({ id, decision });
      if (!res.ok) setError(res.error);
      else router.refresh();
    });
  }

  return (
    <div className="max-w-3xl space-y-4">
      {canRaise && (
        <div className="rounded-lg border p-4">
          <h3 className="mb-1 text-sm font-semibold">Request a change</h3>
          <p className="text-muted-foreground mb-3 text-sm">
            For items already through approval: describe what needs to change. When ops approve,
            the change is applied and any affected sign-offs reopen — never silently.
          </p>
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why does this need to change?"
            className="mb-3"
          />
          <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
            {(
              [
                ["name", "New name", "text"],
                ["widthMm", "Width (mm)", "number"],
                ["heightMm", "Height (mm)", "number"],
                ["quantity", "Quantity", "number"],
                ["material", "Material", "text"],
                ["finish", "Finish", "text"],
                ["installDate", "Install date", "date"],
                ["deliveryDate", "Delivery date", "date"],
              ] as const
            ).map(([key, label, type]) => (
              <label key={key} className="text-xs">
                <span className="text-muted-foreground mb-0.5 block">{label}</span>
                <input
                  type={type}
                  value={fields[key] ?? ""}
                  onChange={(e) => setFields((f) => ({ ...f, [key]: e.target.value }))}
                  className="w-full rounded-md border px-2 py-1.5 text-sm"
                />
              </label>
            ))}
          </div>
          <Button disabled={pending || reason.trim().length < 5} onClick={raise}>
            Raise change request
          </Button>
          {error && <p className="text-destructive mt-2 text-sm">{error}</p>}
        </div>
      )}

      {requests.length === 0 ? (
        <p className="text-muted-foreground text-sm">No change requests on this item.</p>
      ) : (
        <ol className="space-y-3">
          {requests.map((cr) => (
            <li key={cr.id} className="rounded-lg border p-4">
              <div className="mb-1 flex flex-wrap items-center gap-2">
                <StatusBadge status={cr.status} />
                <span className="text-muted-foreground text-xs">
                  {cr.requesterName} · {formatDateTime(cr.createdAt)}
                </span>
              </div>
              <p className="text-sm">{cr.reason}</p>
              {cr.fieldChanges.length > 0 && (
                <ul className="text-muted-foreground mt-2 space-y-0.5 text-xs">
                  {cr.fieldChanges.map((c) => (
                    <li key={c.field}>
                      {FIELD_LABELS[c.field] ?? c.field}: {fmt(c.from)} → <strong>{fmt(c.to)}</strong>
                    </li>
                  ))}
                </ul>
              )}
              {cr.status !== "open" && (
                <p className="text-muted-foreground mt-2 text-xs">
                  Decided by {cr.deciderName ?? "—"}
                  {cr.decidedAt ? ` · ${formatDateTime(cr.decidedAt)}` : ""}
                  {cr.reopenedCount > 0 ? ` · reopened ${cr.reopenedCount} approval(s)` : ""}
                </p>
              )}
              {cr.status === "open" && canDecide && (
                <div className="mt-3 flex gap-2">
                  <Button size="sm" disabled={pending} onClick={() => decide(cr.id, "approve")}>
                    Approve & apply
                  </Button>
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => decide(cr.id, "reject")}>
                    Reject
                  </Button>
                </div>
              )}
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
