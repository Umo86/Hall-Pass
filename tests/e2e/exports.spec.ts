import { expect, test } from "@playwright/test";
import ExcelJS from "exceljs";
import postgres from "postgres";
import { signInAs } from "./helpers";
import { IMPORT_COLUMNS } from "../../lib/exports/import-columns";

const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";

test.describe("exports and the external item page", () => {
  test("ops download the schedule, install sheet and spec labels", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/reports`);
    const main = page.getByRole("main");
    await expect(page).toHaveTitle(/Reports · BIRM27/);
    // Grouped by who receives them; stands are switched off here.
    for (const heading of [
      "For the venue",
      "For contractors",
      "For sponsors & sales",
      "Internal",
    ]) {
      await expect(main.getByRole("heading", { level: 2, name: heading })).toBeVisible();
    }
    await expect(main.getByText("Stand approval register")).toHaveCount(0);
    await expect(main.getByText(/\d+ items · \d+ halls?/).first()).toBeVisible();

    for (const [name, file] of [
      ["Download Excel: Signage schedule", "BIRM27-signage-schedule.xlsx"],
      ["Download Excel: Sponsor report", "BIRM27-sponsor-report.xlsx"],
      ["Download Excel: Contractor install schedule", "BIRM27-install-schedule.xlsx"],
      ["Download PDF: Spec labels", "BIRM27-spec-labels.pdf"],
    ] as const) {
      const button = main.getByRole("button", { name, exact: true });
      const [download] = await Promise.all([page.waitForEvent("download"), button.click()]);
      expect(download.suggestedFilename()).toBe(file);
      await expect(button).toBeEnabled();
    }
    // Each report says who took it last; the history keeps the last ten.
    const schedule = main.getByRole("listitem").filter({ hasText: "Signage schedule" });
    await expect(schedule.getByText(/^Last downloaded by Olivia Ops · /)).toBeVisible();
    await main.getByText("Download history").click();
    const history = main.locator("details").filter({ hasText: "Download history" });
    await expect(history.getByRole("listitem")).toHaveCount(10);
    await expect(history.getByRole("listitem").first()).toContainText("Olivia Ops");
    // Import now lives on the Signage page; the link opens it there.
    const importLink = main.getByRole("link", { name: "Import a schedule from the Signage page" });
    await expect(importLink).toHaveAttribute("href", "/BIRM27/signage?import=1");
    await importLink.click();
    await expect(page.getByRole("dialog", { name: "Import signs from Excel" })).toBeVisible();
    // The address loses ?import=1, so a reload doesn't open it again.
    await expect(page).toHaveURL(/\/BIRM27\/signage$/);
    await ctx.close();
  });

  test("sales get the sponsor report only", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/reports`);
    const main = page.getByRole("main");
    await expect(
      main.getByRole("button", { name: "Download Excel: Sponsor report" }),
    ).toBeVisible();
    await expect(
      main.getByRole("button", { name: "Download Excel: Signage schedule" }),
    ).toHaveCount(0);
    await expect(main.getByRole("heading", { name: "For the venue" })).toHaveCount(0);
    const res = await page.request.get(`${baseURL}/api/exports/schedule/BIRM27`);
    expect(res.status()).toBe(403);
    expect(await res.text()).toContain("Download not available");
    await ctx.close();
  });

  test("viewers are told downloads are for editors", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "viewer@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/reports`);
    const main = page.getByRole("main");
    await expect(main.getByText("Downloads are limited to editors")).toBeVisible();
    await expect(
      main.getByText(/Ask a super admin if you need the signage schedule/),
    ).toBeVisible();
    await expect(main.getByRole("button", { name: /^Download/ })).toHaveCount(0);
    // With nothing to download, Reports isn't in their menu.
    const nav = page.getByRole("navigation", { name: "Main navigation" });
    await expect(nav.getByRole("link", { name: "Dashboard" })).toBeVisible();
    await expect(nav.getByRole("link", { name: "Reports" })).toHaveCount(0);
    await ctx.close();
  });

  test("a schedule import is checked before anything is imported", async ({ browser, baseURL }) => {
    const name = `E2E import check ${Date.now()}`;
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet("Signs");
    ws.addRow([...IMPORT_COLUMNS]);
    ws.addRow(IMPORT_COLUMNS.map((c) => (c === "Name" ? name : "")));
    ws.addRow(IMPORT_COLUMNS.map((c) => (c === "Name" ? `${name} two` : "")));
    const buffer = Buffer.from(await wb.xlsx.writeBuffer());

    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage`);
    await page.getByRole("button", { name: "New sign" }).click();
    await page.getByRole("menuitem", { name: "Import from Excel" }).click();
    const sheet = page.getByRole("dialog");
    await expect(sheet.getByRole("heading", { name: "Import signs from Excel" })).toHaveCount(1);
    await sheet.locator('input[type="file"]').setInputFiles({
      name: "schedule.xlsx",
      mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      buffer,
    });
    await expect(sheet.getByText("2 new, 0 updated, 0 errors")).toBeVisible();
    await expect(sheet.getByRole("button", { name: "Import 2 rows" })).toBeEnabled();
    // Closing without importing leaves the schedule as it was.
    await page.keyboard.press("Escape");
    await expect(sheet).toHaveCount(0);
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    try {
      const rows = await sql`select id from signage_items where name like ${`${name}%`}`;
      expect(rows).toHaveLength(0);
    } finally {
      await sql.end();
      await ctx.close();
    }
  });

  test("a certificate is refused for an item that is not signed off", async ({
    browser,
    baseURL,
  }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    // SIG-BIRM27-002 is still in review.
    const res = await page.request.get(`${baseURL}/api/exports/certificate/SIG-BIRM27-002`);
    expect(res.status()).toBe(409);
    await ctx.close();
  });

  test("a venue user scanning a label lands on the item page", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "venue@nec.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/q/SIG-BIRM27-001`);
    await page.waitForURL("**/portal/items/SIG-BIRM27-001");
    await expect(page.getByRole("heading", { level: 2, name: "Artwork" })).toBeVisible();
    await expect(page.getByRole("link", { name: /spec label/i })).toBeVisible();
    // Items not shared with them are not found.
    const res = await page.request.get(`${baseURL}/portal/items/SIG-BIRM27-002`);
    expect(res.status()).toBe(404);
    await ctx.close();
  });
});
