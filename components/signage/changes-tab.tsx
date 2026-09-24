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

const NOT_YET_SIGNED_OFF = ["draft", "awaiting_artwork", "in_review", "changes_requested"];

type FieldDef = readonly [key: string, label: string, type: "text" | "number" | "date"];

export function ChangesTab({
  itemId,
  requests,
  canRaise,
  canDecide,
  status,
  kind,
  current,
}: {
  itemId: string;
  requests: ChangeRequestRow[];
  canRaise: boolean;
  canDecide: boolean;
  status: string;
  kind: "signage" | "sponsorship_item";
  /** Current values, shown as "Now: …" in each box. */
  current: Record<string, string | number | null>;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [fields, setFields] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});

  const defs: FieldDef[] = [
    ["name", "Name", "text"],
    ["widthMm", "Width (mm)", "number"],
    ["heightMm", "Height (mm)", "number"],
    ...(kind === "signage" ? ([["depthMm", "Depth (mm)", "number"]] as FieldDef[]) : []),
    ["quantity", "Quantity", "number"],
    ["material", "Material", "text"],
    ["finish", "Finish", "text"],
    ...(kind === "signage" ? ([["installDate", "Install date", "date"]] as FieldDef[]) : []),
    ["deliveryDate", "Delivery date", "date"],
  ];

  function raise() {
    setError(null);
    const changes: Record<string, unknown> = {};
    for (const [key, label, type] of defs) {
      const raw = fields[key]?.trim();
      if (!raw) continue;
      if (type === "number") {
        const n = Number(raw);
        if (!Number.isInteger(n) || n <= 0) {
          setError(`${label} must be a whole number above 0`);
          return;
        }
        changes[key] = n;
      } else {
        changes[key] = raw;
      }
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
      const res = await decideChangeRequest({ id, decision, comment: notes[id] || undefined });
      if (!res.ok) setError(res.error);
      else router.refresh();
    });
  }

  const showRaise = canRaise && !NOT_YET_SIGNED_OFF.includes(status);

  return (
    <div className="max-w-3xl space-y-4">
      {NOT_YET_SIGNED_OFF.includes(status) && (
        <p className="text-muted-foreground rounded-lg border p-4 text-sm">
          This item isn&apos;t signed off yet — change it directly on the Details tab. Change
          requests are for items that are already approved.
        </p>
      )}
      {showRaise && (
        <div className="rounded-lg border p-4">
          <h3 className="mb-1 text-sm font-semibold">Request a change</h3>
          <p className="text-muted-foreground mb-3 text-sm">
            Say what needs to change and fill in only the new values. When admin or ops accept it,
            the change is applied; if the size or material changes, the sign-offs it affects are
            asked again.
          </p>
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why does this need to change?"
            aria-label="Reason for the change"
            className="mb-3"
          />
          <div className="mb-3 grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-4">
            {defs.map(([key, label, type]) => (
              <label key={key} className="text-xs">
                <span className="text-muted-foreground mb-0.5 block">{label}</span>
                <input
                  type={type}
                  min={type === "number" ? 1 : undefined}
                  value={fields[key] ?? ""}
                  placeholder={type === "date" ? undefined : `Now: ${fmt(current[key])}`}
                  onChange={(e) => setFields((f) => ({ ...f, [key]: e.target.value }))}
                  className="w-full rounded-md border px-2 py-1.5 text-sm"
                />
                {type === "date" && (
                  <span className="text-muted-foreground mt-0.5 block">
                    Now: {fmt(current[key])}
                  </span>
                )}
              </label>
            ))}
          </div>
          <Button disabled={pending || reason.trim().length < 5} onClick={raise}>
            Raise change request
          </Button>
        </div>
      )}
      {error && <p className="text-destructive text-sm">{error}</p>}

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
                      {FIELD_LABELS[c.field] ?? c.field}: {fmt(c.from)} →{" "}
                      <strong>{fmt(c.to)}</strong>
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
                <div className="mt-3 space-y-2">
                  <Textarea
                    value={notes[cr.id] ?? ""}
                    onChange={(e) => setNotes((n) => ({ ...n, [cr.id]: e.target.value }))}
                    placeholder="Note to the requester (needed to reject)"
                    aria-label="Note to the requester"
                    className="min-h-16"
                  />
                  <div className="flex flex-wrap gap-2">
                    <Button size="sm" disabled={pending} onClick={() => decide(cr.id, "approve")}>
                      {cr.fieldChanges.length > 0 ? "Accept & apply" : "Accept"}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={pending || (notes[cr.id]?.trim().length ?? 0) < 5}
                      onClick={() => decide(cr.id, "reject")}
                    >
                      Reject
                    </Button>
                  </div>
                  {cr.fieldChanges.length === 0 && (
                    <p className="text-muted-foreground text-xs">
                      No field changes were given — accepting just records it; make the change on
                      the Details tab.
                    </p>
                  )}
                </div>
              )}
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
