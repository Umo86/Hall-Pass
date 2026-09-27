import "server-only";
import ExcelJS from "exceljs";

import { IMPORT_COLUMNS } from "./import-columns";

export { IMPORT_COLUMNS };

export async function buildImportTemplate(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet("Schedule");
  ws.addRow([...IMPORT_COLUMNS]);
  ws.getRow(1).font = { bold: true };
  ws.addRow([
    "",
    "Main entrance banner",
    "Hanging banner",
    "Hall 1",
    "Main entrance",
    "B12",
    3000,
    1000,
    1,
    "single",
    "Tension fabric",
    "Matt",
    "rigged",
    "",
    "Big Print Co",
    "yes",
    2500,
    "2027-10-02",
    "am",
    "Example row — delete before importing",
    "organiser",
  ]);
  ws.views = [{ state: "frozen", ySplit: 1 }];
  ws.columns.forEach((c) => {
    c.width = 18;
  });
  return Buffer.from(await wb.xlsx.writeBuffer());
}
