/**
 * The Reports page rules (components/reports/report-rules.ts): reports by
 * audience, what each covers, and reading a download's response.
 */
import { describe, expect, it } from "vitest";
import {
  EXPORT_LOG_KIND,
  REPORT_GROUPS,
  exportErrorText,
  fileNameFromDisposition,
  scopeLine,
  visibleGroups,
  type ReportCounts,
} from "@/components/reports/report-rules";

describe("reports by audience", () => {
  it("covers every report once, venue first", () => {
    const kinds = REPORT_GROUPS.flatMap((g) => g.kinds);
    expect(new Set(kinds).size).toBe(kinds.length);
    expect(REPORT_GROUPS.map((g) => g.title)).toEqual([
      "For the venue",
      "For contractors",
      "For sponsors & sales",
      "Internal",
    ]);
    for (const k of kinds) expect(EXPORT_LOG_KIND[k]).toBeTruthy();
    expect(EXPORT_LOG_KIND.schedule).toBe("signage_schedule");
  });

  it("keeps only the groups someone can download from", () => {
    // Sales: the sponsor report only.
    expect(visibleGroups((k) => k === "sponsor_report")).toEqual([
      { id: "sponsors", title: "For sponsors & sales", kinds: ["sponsor_report"] },
    ]);
    // Viewers: nothing, so the page shows its empty state.
    expect(visibleGroups(() => false)).toEqual([]);
    expect(visibleGroups((k) => k !== "stand_register").at(-1)?.kinds).toEqual(["schedule"]);
  });
});

describe("scopeLine", () => {
  const c: ReportCounts = {
    items: 138,
    halls: 2,
    withInstallDate: 90,
    sponsored: 41,
    sponsors: 12,
    venueItems: 1,
    labels: 150,
    exhibitors: 0,
  };
  it("says what each report covers", () => {
    expect(scopeLine("schedule", c)).toBe("138 items · 2 halls");
    expect(scopeLine("contractor_schedule", c)).toBe("138 items · 90 with an install date");
    expect(scopeLine("venue_pack", c)).toBe("1 item needing venue approval");
    expect(scopeLine("venue_pack", { ...c, venueItems: 0 })).toBe(
      "No items need venue approval yet",
    );
    expect(scopeLine("sponsor_report", c)).toBe("41 items for 12 sponsors");
    expect(scopeLine("sponsor_report", { ...c, sponsored: 0 })).toBe(
      "Nothing sold to sponsors yet",
    );
    expect(scopeLine("spec_labels", c)).toBe("150 labels, one per item");
    expect(scopeLine("stand_register", c)).toBe("0 exhibitors");
  });
});

describe("reading a download", () => {
  it("takes the file name from Content-Disposition", () => {
    expect(fileNameFromDisposition('attachment; filename="BIRM27-signage-schedule.xlsx"')).toBe(
      "BIRM27-signage-schedule.xlsx",
    );
    expect(fileNameFromDisposition("attachment; filename=plain.pdf")).toBe("plain.pdf");
    expect(fileNameFromDisposition("attachment; filename*=UTF-8''Hall%201.pdf")).toBe("Hall 1.pdf");
    expect(fileNameFromDisposition(null)).toBeNull();
    expect(fileNameFromDisposition("inline")).toBeNull();
  });

  it("reads the reason from the Download not available page", () => {
    const html =
      '<!doctype html><html><body><h1>Download not available</h1><p>Your role can&#39;t download the signage schedule.</p><p><a href="javascript:history.back()">Go back</a></p></body></html>';
    expect(exportErrorText(html)).toBe("Your role can't download the signage schedule.");
    expect(exportErrorText("Not found")).toBeNull();
  });
});
