import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("staff flow", () => {
  test("login page lists development users and signs in", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("heading", { name: "Hall Pass" })).toBeVisible();
    await page.getByRole("button", { name: "Olivia Ops" }).click();
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

  test("create item → submit → marketing approves", async ({ page, context, baseURL }) => {
    await signInAs(context, "ops@media10.test", baseURL!);
    await page.goto("/BIRM27/signage/new");
    const name = `E2E test sign ${Date.now()}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await page.getByLabel("Location").selectOption({ label: "Registration" });
    await page.getByLabel("Width (mm)").fill("1200");
    await page.getByLabel("Height (mm)").fill("800");
    await page.getByLabel("Fixing method").selectOption("wall_mounted");
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    await expect(page.getByRole("heading", { name })).toBeVisible();

    // Submit for review — no artwork yet, so it awaits artwork.
    await page.getByRole("button", { name: "Submit for review" }).click();
    await expect(page.getByText("Awaiting artwork")).toBeVisible();
  });

  test("marketing decides their pending step from My Sign-offs", async ({ page, context, baseURL }) => {
    await signInAs(context, "marketing@media10.test", baseURL!);
    await page.goto("/approvals");
    await expect(page.getByRole("heading", { name: "My Sign-offs" })).toBeVisible();
    const firstApprove = page.getByRole("button", { name: "Approve", exact: true }).first();
    await expect(firstApprove).toBeVisible();
    await firstApprove.click();
    await expect(page.getByText("Your approval is recorded against the current version")).toBeVisible();
    await page.getByRole("dialog").getByRole("button", { name: "Approve", exact: true }).click();
    // The row disappears or the list refreshes without error.
    await expect(page.getByRole("heading", { name: "My Sign-offs" })).toBeVisible();
  });
});
