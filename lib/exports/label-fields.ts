import { formatDate, statusLabel } from "@/lib/format";

/** Everything a spec label can print about one item. */
export type LabelRow = {
  ref: string;
  name: string;
  kind: string;
  widthMm: number | null;
  heightMm: number | null;
  quantity: number;
  material: string | null;
  finish: string | null;
  fixingMethod: string | null;
  installDate: string | null;
  installSlot: string | null;
  deliveryDate: string | null;
  hallName: string | null;
  locationName: string | null;
  contractorName: string | null;
  sponsorName: string | null;
  supplierName: string | null;
};

/** "Hall 1 · Entrance A" — where the item goes, in large type on the label. */
export function labelWhere(row: LabelRow): string | null {
  const parts = [row.hallName, row.locationName].filter(Boolean);
  return parts.length ? parts.join(" · ") : null;
}

/** "Install 12 Mar 2027 AM · Acme Rigging" for signage; null otherwise. */
export function labelWhen(row: LabelRow): string | null {
  if (row.kind !== "signage") return null;
  const date = row.installDate
    ? `Install ${formatDate(row.installDate)}${row.installSlot ? ` ${row.installSlot.toUpperCase()}` : ""}`
    : null;
  const parts = [date, row.contractorName].filter(Boolean);
  return parts.length ? parts.join(" · ") : null;
}

/**
 * The key/value rows for a label, leaving out anything not filled in.
 * Sponsorship items (bags, lanyards) print sponsor, quantity, supplier and
 * delivery; signage prints its physical spec.
 */
export function specLabelFields(row: LabelRow): Array<[string, string]> {
  const size = row.widthMm && row.heightMm ? `${row.widthMm} × ${row.heightMm} mm` : null;
  const rows: Array<[string, string | null]> =
    row.kind === "signage"
      ? [
          ["Size", size],
          ["Quantity", String(row.quantity)],
          ["Material", row.material],
          ["Finish", row.finish],
          ["Fixing", row.fixingMethod ? statusLabel(row.fixingMethod) : null],
          ["Sponsor", row.sponsorName],
        ]
      : [
          ["Sponsor", row.sponsorName],
          ["Quantity", String(row.quantity)],
          ["Size", size],
          ["Supplier", row.supplierName],
          ["Delivery", row.deliveryDate ? formatDate(row.deliveryDate) : null],
        ];
  return rows.filter((r): r is [string, string] => Boolean(r[1]));
}
