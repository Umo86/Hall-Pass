import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("exports and the external item page", () => {
  test("ops download the schedule, install sheet and spec labels", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/reports`);
    await expect(page.getByText("Stand approval register")).toHaveCount(0); // stands hidden
    for (const [name, file] of [
      [/Signage schedule/, "BIRM27-signage-schedule.xlsx"],
      [/Sponsor report/, "BIRM27-sponsor-report.xlsx"],
      [/Contractor install schedule/, "BIRM27-install-schedule.xlsx"],
      [/^All items$/, "BIRM27-spec-labels.pdf"],
    ] as const) {
      const [download] = await Promise.all([
        page.waitForEvent("download"),
        page.getByRole("link", { name }).first().click(),
      ]);
      expect(download.suggestedFilename()).toBe(file);
    }
    await ctx.close();
  });

  test("sales get the sponsor report only", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "sales@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/reports`);
    await expect(page.getByRole("link", { name: /Sponsor report/ })).toBeVisible();
    await expect(page.getByRole("link", { name: /Signage schedule/ })).toHaveCount(0);
    const res = await page.request.get(`${baseURL}/api/exports/schedule/BIRM27`);
    expect(res.status()).toBe(403);
    expect(await res.text()).toContain("Download not available");
    await ctx.close();
  });

  test("a certificate is refused for an item that is not signed off", async ({ browser, baseURL }) => {
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
