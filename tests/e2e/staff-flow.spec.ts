import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("staff flow", () => {
  test("login page lists development users and signs in", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("heading", { name: "Choose who to sign in as" })).toBeVisible();
    await page.getByRole("button", { name: /Olivia Ops/ }).click();
    await page.waitForURL("**/editions");
    await expect(page.getByRole("heading", { name: "Editions" })).toBeVisible();
    await expect(page.getByRole("link", { name: "BIRM27" })).toBeVisible();
  });

  test("dashboard, schedule and item detail render seeded data", async ({ page, context, baseURL }) => {
    await signInAs(context, "ops@media10.test", baseURL!);
    await page.goto("/BIRM27/dashboard");
    await expect(page.getByRole("heading", { name: "UKCW Birmingham 2027" })).toBeVisible();
    await expect(page.getByText("Signage by status")).toBeVisible();

    await page.goto("/BIRM27/signage");
    await expect(page.getByText("Signage schedule")).toBeVisible();
    await expect(page.getByRole("link", { name: "SIG-BIRM27-001" })).toBeVisible();

    await page.goto("/BIRM27/signage/SIG-BIRM27-001?tab=approvals");
    await expect(page.getByText("Marketing brand check")).toBeVisible();
    await expect(page.getByText("Sponsor approval")).toBeVisible();
  });

  test("create → artwork → submit → marketing approves", async ({ browser, baseURL }) => {
    // Ops creates and submits a fresh item so the approval is guaranteed.
    const opsCtx = await browser.newContext();
    await signInAs(opsCtx, "ops@media10.test", baseURL!);
    const page = await opsCtx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    const name = `E2E test sign ${Date.now()}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByLabel("Category").selectOption("venue");
    await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await page.getByLabel("Location").selectOption({ label: "Registration" });
    await page.getByLabel("Width (mm)").fill("1200");
    await page.getByLabel("Height (mm)").fill("800");
    await page.getByLabel("Fixing method").selectOption("wall_mounted");
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    await expect(page.getByRole("heading", { name })).toBeVisible();
    const ref = new URL(page.url()).pathname.split("/").pop()!;

    // Upload artwork so submission goes straight to review.
    await page.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
    await page.setInputFiles('input[type="file"]', {
      name: "artwork.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"),
    });
    await page.getByRole("button", { name: "Upload" }).click();
    await expect(page.getByText("v1 — artwork.pdf")).toBeVisible();

    await page.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await page.getByRole("button", { name: "Submit for review" }).click();
    await expect(page.getByText("In review", { exact: true })).toBeVisible();
    await opsCtx.close();

    // Marketing sees the step in My Sign-offs and approves it.
    const mktCtx = await browser.newContext();
    await signInAs(mktCtx, "marketing@media10.test", baseURL!);
    const mkt = await mktCtx.newPage();
    await mkt.goto(`${baseURL}/approvals`);
    const row = mkt.locator("li", { hasText: ref });
    await expect(row).toBeVisible();
    await row.getByRole("button", { name: "Approve", exact: true }).click();
    await expect(
      mkt.getByText("Your approval is recorded against the current version"),
    ).toBeVisible();
    await mkt.getByRole("dialog").getByRole("button", { name: "Approve", exact: true }).click();
    await expect(row).toHaveCount(0);
    await mktCtx.close();
  });

});
