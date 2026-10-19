/**
 * Reports page rules (pure; unit tested in tests/unit/dashboard-reports.test.ts):
 * which reports go to whom, what each covers, and reading a download's
 * response (its file name, or the reason it was refused).
 */
import { plural } from "@/lib/format";

/** The export permission kinds (can(…, { type: "export.run", kind })). */
export type ReportKind =
  | "venue_pack"
  | "contractor_schedule"
  | "spec_labels"
  | "sponsor_report"
  | "schedule"
  | "stand_register";

export type Audience = "venue" | "contractors" | "sponsors" | "internal";

/** Reports grouped by who receives them, in page order. */
export const REPORT_GROUPS: { id: Audience; title: string; kinds: ReportKind[] }[] = [
  { id: "venue", title: "For the venue", kinds: ["venue_pack"] },
  { id: "contractors", title: "For contractors", kinds: ["contractor_schedule", "spec_labels"] },
  { id: "sponsors", title: "For sponsors & sales", kinds: ["sponsor_report"] },
  { id: "internal", title: "Internal", kinds: ["schedule", "stand_register"] },
];

/** What the download log calls each report (exports.kind). */
export const EXPORT_LOG_KIND: Record<ReportKind, string> = {
  venue_pack: "venue_pack",
  contractor_schedule: "contractor_schedule",
  spec_labels: "spec_labels",
  sponsor_report: "sponsor_report",
  schedule: "signage_schedule",
  stand_register: "stand_register",
};

/** Groups with at least one report this person may download, keeping the order. */
export function visibleGroups(allowed: (kind: ReportKind) => boolean) {
  return REPORT_GROUPS.map((g) => ({ ...g, kinds: g.kinds.filter(allowed) })).filter(
    (g) => g.kinds.length > 0,
  );
}

export type ReportCounts = {
  items: number;
  halls: number;
  withInstallDate: number;
  sponsored: number;
  sponsors: number;
  venueItems: number;
  labels: number;
  exhibitors: number;
  /** Sponsors with a package (sponsor report); 0 or missing reads as before. */
  packagesSold?: number;
};

/** What a report covers, in a few words: "138 items · 2 halls". */
export function scopeLine(kind: ReportKind, c: ReportCounts): string {
  switch (kind) {
    case "schedule":
      return `${plural(c.items, "item")} · ${plural(c.halls, "hall")}`;
    case "contractor_schedule":
      return `${plural(c.items, "item")} · ${c.withInstallDate} with an install date`;
    case "venue_pack":
      return c.venueItems > 0
        ? `${plural(c.venueItems, "item")} needing venue approval`
        : "No items need venue approval yet";
    case "sponsor_report": {
      const items =
        c.sponsored > 0
          ? `${plural(c.sponsored, "item")} for ${plural(c.sponsors, "sponsor")}`
          : null;
      const packages = c.packagesSold ? `${plural(c.packagesSold, "package")} sold` : null;
      return [packages, items].filter(Boolean).join(" · ") || "Nothing sold to sponsors yet";
    }
    case "spec_labels":
      return c.labels > 0 ? `${plural(c.labels, "label")}, one per item` : "No items to label yet";
    case "stand_register":
      return plural(c.exhibitors, "exhibitor");
  }
}

/** The file name a download was sent with, or null. */
export function fileNameFromDisposition(header: string | null | undefined): string | null {
  if (!header) return null;
  const star = header.match(/filename\*=(?:UTF-8'')?([^;]+)/i);
  if (star) {
    try {
      return decodeURIComponent(star[1].trim().replace(/^"|"$/g, ""));
    } catch {
      // Fall through to the plain name.
    }
  }
  const plain = header.match(/filename="?([^";]+)"?/i);
  return plain ? plain[1].trim() : null;
}

/**
 * The reason on an export's "Download not available" page (the first
 * paragraph), with its HTML entities decoded; null when there is none.
 */
export function exportErrorText(html: string): string | null {
  const m = html.match(/<p>([\s\S]*?)<\/p>/i);
  if (!m) return null;
  return m[1]
    .replace(/<[^>]+>/g, "")
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCharCode(Number(code)))
    .replace(/&amp;/g, "&")
    .trim();
}
