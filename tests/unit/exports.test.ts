import { describe, expect, it } from "vitest";
import { safeSheetName } from "@/lib/exports/sheet-name";
import {
  labelWhen,
  labelWhere,
  specLabelFields,
  type LabelRow,
} from "@/lib/exports/label-fields";
import { renderApprovalCertificate, renderSpecLabels } from "@/lib/exports/pdf";

describe("safeSheetName", () => {
  it("strips characters Excel refuses and trims to 31", () => {
    const used = new Set<string>();
    expect(safeSheetName("A/V Solutions: Hall [1]?*", used)).toBe("A-V Solutions- Hall -1---");
    const long = safeSheetName("x".repeat(40), used);
    expect(long).toHaveLength(31);
  });

  it("de-duplicates ignoring case and avoids reserved names", () => {
    const used = new Set<string>(["deliveries"]);
    expect(safeSheetName("Deliveries", used)).toBe("Deliveries (2)");
    expect(safeSheetName("Hall 1", used)).toBe("Hall 1");
    expect(safeSheetName("HALL 1", used)).toBe("HALL 1 (2)");
    expect(safeSheetName("History", used)).toBe("History (1)");
    expect(safeSheetName("   ", used)).toBe("Sheet");
    const dupLong = safeSheetName("y".repeat(40), new Set(["y".repeat(31)]));
    expect(dupLong).toHaveLength(31);
    expect(dupLong.endsWith(" (2)")).toBe(true);
  });
});

const base: LabelRow = {
  ref: "SIG-X-001",
  name: "Entrance banner",
  kind: "signage",
  widthMm: 1000,
  heightMm: 2000,
  quantity: 2,
  material: "Foamex",
  finish: null,
  fixingMethod: "cable_tie",
  installDate: "2027-03-12",
  installSlot: "am",
  deliveryDate: "2027-03-10",
  hallName: "Hall 1",
  locationName: "Entrance A",
  contractorName: "Acme Rigging",
  sponsorName: null,
  supplierName: "PrintCo",
};

describe("spec label fields", () => {
  it("says where and when for signage and leaves out empty rows", () => {
    expect(labelWhere(base)).toBe("Hall 1 · Entrance A");
    expect(labelWhen(base)).toMatch(/^Install .*2027 AM · Acme Rigging$/);
    const keys = specLabelFields(base).map(([k]) => k);
    expect(keys).toEqual(["Size", "Quantity", "Material", "Fixing"]);
  });

  it("prints sponsor, supplier and delivery for sponsorship items", () => {
    const bag: LabelRow = {
      ...base,
      kind: "sponsorship_item",
      widthMm: null,
      heightMm: null,
      hallName: null,
      locationName: null,
      sponsorName: "Acme Ltd",
    };
    expect(labelWhere(bag)).toBeNull();
    expect(labelWhen(bag)).toBeNull();
    expect(specLabelFields(bag).map(([k]) => k)).toEqual([
      "Sponsor",
      "Quantity",
      "Supplier",
      "Delivery",
    ]);
  });
});

describe("PDF rendering", () => {
  it("renders labels and certificates with non-Western-European names", async () => {
    const labels = await renderSpecLabels({
      brandName: "Hall Pass",
      labels: [
        { ref: "SIG-X-001", name: "Giriş / Çıkış", where: "Hall 1 · Łódź", when: null, fields: [], qrUrl: "https://example.test/q/SIG-X-001" },
        { ref: "SIG-X-002", name: "Second", where: null, when: null, fields: [["Size", "1 × 2 mm"]], qrUrl: "https://example.test/q/SIG-X-002" },
      ],
    });
    expect(labels.subarray(0, 4).toString()).toBe("%PDF");
    const cert = await renderApprovalCertificate({
      brandName: "Hall Pass",
      ref: "SIG-X-001",
      title: "Giriş / Çıkış",
      editionName: "Show 2027",
      fields: [["Status", "Approved"]],
      steps: [
        {
          name: "Ops technical check",
          status: "approved",
          deciderName: "Şule Łukasz",
          decidedAt: new Date("2027-01-02T10:00:00Z"),
          versionLabel: null,
          shaPrefix: null,
          conditions: null,
        },
      ],
      recordUrl: "https://example.test/q/SIG-X-001",
    });
    expect(cert.subarray(0, 4).toString()).toBe("%PDF");
  });
});
