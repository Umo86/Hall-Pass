import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("external scoping", () => {
  test("venue user is redirected away from staff routes", async ({ page, context, baseURL }) => {
    await signInAs(context, "venue@nec.test", baseURL!);
    await page.goto("/BIRM27/signage");
    await page.waitForURL("**/portal/**");
    await expect(page).toHaveURL(/portal/);
  });

  test("venue user sees only venue-approval items", async ({ page, context, baseURL }) => {
    await signInAs(context, "venue@nec.test", baseURL!);
    await page.goto("/portal/items");
    // Flagged item visible; a plain unflagged item is not.
    await expect(page.getByText("SIG-BIRM27-001")).toBeVisible();
    await expect(page.getByText("SIG-BIRM27-002")).toHaveCount(0);
  });

  test("venue sign-offs open the artwork; the decision sits under it", async ({
    page,
    context,
    baseURL,
  }) => {
    await signInAs(context, "venue@nec.test", baseURL!);
    await page.goto("/portal/approvals");
    await expect(page.getByRole("heading", { name: "My Sign-offs" })).toBeVisible();
    // No approving from the list: each row opens the item.
    await expect(page.getByRole("button", { name: "Approve", exact: true })).toHaveCount(0);
    const row = page.locator("li", { hasText: "SIG-BIRM27-007" });
    await expect(row.getByRole("link", { name: "SIG-BIRM27-007", exact: true })).toBeVisible();
    await row.getByRole("link", { name: "Review artwork" }).click();
    await page.waitForURL("**/portal/items/SIG-BIRM27-007");
    const artwork = page.getByRole("heading", { name: "Artwork", exact: true });
    const decision = page.getByRole("heading", { name: "Your sign-off" });
    await expect(decision).toBeVisible();
    await expect(page.getByRole("button", { name: "Approve", exact: true })).toBeVisible();
    const [a, d] = [await artwork.boundingBox(), await decision.boundingBox()];
    expect(d!.y).toBeGreaterThan(a!.y);
  });

  test("supplier sees PO but venue does not", async ({ browser, baseURL }) => {
    const supplierCtx = await browser.newContext();
    await signInAs(supplierCtx, "print@bigprint.test", baseURL!);
    const supplierPage = await supplierCtx.newPage();
    await supplierPage.goto(`${baseURL}/portal/items`);
    await expect(supplierPage.getByRole("columnheader", { name: "PO" })).toBeVisible();
    await supplierCtx.close();

    const venueCtx = await browser.newContext();
    await signInAs(venueCtx, "venue@nec.test", baseURL!);
    const venuePage = await venueCtx.newPage();
    await venuePage.goto(`${baseURL}/portal/items`);
    await expect(venuePage.getByRole("columnheader", { name: "PO" })).toHaveCount(0);
    await venueCtx.close();
  });

  test("exhibitor sees their submission with questionnaire and documents", async ({
    page,
    context,
    baseURL,
  }) => {
    await signInAs(context, "stand@exhibitorco.test", baseURL!);
    await page.goto("/portal/submission");
    await expect(page.getByText("Stand A10 — Exhibitor Co")).toBeVisible();
    await expect(page.getByText("Structure questionnaire")).toBeVisible();
    await expect(page.getByText("Complex structure — engineer review required")).toBeVisible();
  });

  test("signed-out users land on the sign-in page", async ({ page }) => {
    await page.goto("/BIRM27/dashboard");
    await page.waitForURL(/\/login/);
    await expect(page.getByRole("heading", { name: "Choose who to sign in as" })).toBeVisible();
    // …and signing in takes them back to the page they asked for.
    await page.getByRole("button", { name: /Olivia Ops/ }).click();
    await page.waitForURL("**/BIRM27/dashboard");
  });
});
