"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { FileText, Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { SelectNative } from "@/components/ui/select-native";
import { StatusBadge } from "@/components/status-badge";
import { formatDate, formatDateTime, statusLabel } from "@/lib/format";
import { reviewStandDocument, uploadStandDocument } from "@/app/actions/stands";

export type DocRow = {
  id: string;
  docType: string;
  fileName: string;
  status: string;
  reviewNote: string | null;
  submissionVersion: number | null;
  expiresAt: string | null;
  expiryFlag: boolean;
  uploaderName: string | null;
  createdAt: string;
  downloadUrl: string | null;
};

const DOC_LABELS: Record<string, string> = {
  plan: "Stand plan",
  elevation: "Elevation",
  structural_calcs: "Structural calculations",
  rams: "RAMS",
  insurance_pl: "Public liability insurance",
  fire_cert: "Fire certificate",
  electrical_cert: "Electrical certificate",
  rigging_plan: "Rigging plan",
  other: "Other",
};

export function DocumentsPanel({
  submissionId,
  requiredTypes,
  documents,
  canUpload,
  canReview,
  currentVersion,
}: {
  submissionId: string;
  requiredTypes: string[];
  documents: DocRow[];
  canUpload: boolean;
  canReview: boolean;
  currentVersion: number;
}) {
  const [docType, setDocType] = useState(requiredTypes[0] ?? "plan");
  const [file, setFile] = useState<File | null>(null);
  const [expiresAt, setExpiresAt] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const presentTypes = new Set(
    documents.filter((d) => (d.submissionVersion ?? 1) >= currentVersion).map((d) => d.docType),
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {requiredTypes.map((t) => (
          <span
            key={t}
            className={`rounded-md border px-2 py-1 text-xs font-medium ${
              presentTypes.has(t)
                ? "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-300"
                : "border-red-200 bg-red-50 text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-300"
            }`}
          >
            {DOC_LABELS[t] ?? t}: {presentTypes.has(t) ? "received" : "required"}
          </span>
        ))}
      </div>

      {canUpload && (
        <div className="flex flex-wrap items-center gap-2 rounded-lg border p-3">
          <SelectNative
            className="w-56"
            value={docType}
            onChange={(e) => setDocType(e.target.value)}
            aria-label="Document type"
          >
            {Object.entries(DOC_LABELS).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </SelectNative>
          <input
            type="file"
            className="text-sm"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            accept=".pdf,.doc,.docx,.xls,.xlsx,.dwg,.png,.jpg,.jpeg"
          />
          {docType === "insurance_pl" && (
            <input
              type="date"
              className="border-input h-9 rounded-md border bg-transparent px-2 text-sm"
              value={expiresAt}
              onChange={(e) => setExpiresAt(e.target.value)}
              aria-label="Insurance expiry date"
            />
          )}
          <Button
            size="sm"
            disabled={!file || pending}
            onClick={() => {
              if (!file) return;
              const fd = new FormData();
              fd.set("submissionId", submissionId);
              fd.set("docType", docType);
              fd.set("file", file);
              if (expiresAt) fd.set("expiresAt", expiresAt);
              setError(null);
              start(async () => {
                const res = await uploadStandDocument(fd);
                if (!res.ok) setError(res.error);
                else {
                  setFile(null);
                  router.refresh();
                }
              });
            }}
          >
            <Upload className="size-4" /> Upload
          </Button>
          {error && <span className="text-destructive text-sm">{error}</span>}
        </div>
      )}

      <ul className="space-y-2">
        {documents.map((d) => (
          <li key={d.id} className="flex flex-wrap items-center gap-3 rounded-lg border p-3 text-sm">
            <FileText className="text-muted-foreground size-5" aria-hidden />
            <div className="min-w-0 flex-1">
              <p className="font-medium">
                {DOC_LABELS[d.docType] ?? statusLabel(d.docType)} — {d.fileName}
              </p>
              <p className="text-muted-foreground text-xs">
                v{d.submissionVersion ?? 1} · {d.uploaderName ?? "—"} · {formatDateTime(d.createdAt)}
                {d.expiresAt ? ` · expires ${formatDate(d.expiresAt)}` : ""}
                {d.reviewNote ? ` · “${d.reviewNote}”` : ""}
              </p>
            </div>
            {d.expiryFlag && (
              <span className="text-destructive text-xs font-medium">
                Expires before the show closes
              </span>
            )}
            <StatusBadge status={d.status} />
            {d.downloadUrl && (
              <Button size="sm" variant="outline" asChild>
                <a href={d.downloadUrl}>Download</a>
              </Button>
            )}
            {canReview && d.status === "received" && (
              <div className="flex gap-1">
                <Button
                  size="sm"
                  variant="outline"
                  disabled={pending}
                  onClick={() =>
                    start(async () => {
                      await reviewStandDocument({ documentId: d.id, status: "accepted" });
                      router.refresh();
                    })
                  }
                >
                  Accept
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={pending}
                  onClick={() =>
                    start(async () => {
                      await reviewStandDocument({
                        documentId: d.id,
                        status: "rejected",
                        reviewNote: "Not acceptable — see comments",
                      });
                      router.refresh();
                    })
                  }
                >
                  Reject
                </Button>
              </div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
