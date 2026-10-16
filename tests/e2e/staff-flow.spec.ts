import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

test.describe("staff flow", () => {
  test("login page lists development users and signs in", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("heading", { name: "Choose who to sign in as" })).toBeVisible();
    await page.getByRole("button", { name: /Olivia Ops/ }).click();
    // Staff land on their own work.
    await page.waitForURL("**/my-work");
    await expect(page.getByRole("heading", { name: "My Work" })).toBeVisible();
  });

  test("dashboard, schedule and item detail render seeded data", async ({
    page,
    context,
    baseURL,
  }) => {
    await signInAs(context, "ops@media10.test", baseURL!);
    await page.goto("/BIRM27/dashboard");
    await expect(page.getByRole("heading", { name: "UKCW Birmingham 2027" })).toBeVisible();
    await expect(page.getByText("Signage by status")).toBeVisible();

    await page.goto("/BIRM27/signage");
    await expect(page.getByRole("heading", { name: "Signage", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "SIG-BIRM27-001" })).toBeVisible();

    await page.goto("/BIRM27/signage/SIG-BIRM27-001?tab=approvals");
    // Decided steps keep the name they were decided under; open ones use the
    // department names.
    await expect(page.getByText(/Marketing (brand check|sign-off)/).first()).toBeVisible();
    await expect(page.getByText("Sales sign-off").first()).toBeVisible();
  });

  test("create → artwork → submit → marketing approves", async ({ browser, baseURL }) => {
    // Ops creates and submits a fresh item so the approval is guaranteed.
    const opsCtx = await browser.newContext();
    await signInAs(opsCtx, "ops@media10.test", baseURL!);
    const page = await opsCtx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    const name = `E2E test sign ${Date.now()}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    // Organiser signage is the default; this item needs Operations and
    // Marketing only (the full three-department flow is in signage-setup.spec).
    await page.getByRole("button", { name: "Change who signs off" }).click();
    await page.getByLabel("Needs Senior management sign-off").uncheck();
    await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await page.getByLabel("Location").selectOption({ label: "Registration" });
    await page.getByLabel("Width (mm)").fill("1200");
    await page.getByLabel("Height (mm)").fill("800");
    await page.getByLabel("Fixing method").selectOption("wall_mounted");
    // Nothing goes to print without a printer, so pick one now.
    await page.getByText("More details").click();
    await page.getByLabel("Supplier").selectOption({ index: 1 });
    await page.getByRole("button", { name: "Create item" }).click();
    // A new sign lands on its artwork, ready for the upload.
    await page.waitForURL("**/signage/SIG-BIRM27-*?tab=artwork&created=1");
    await expect(page.getByRole("heading", { name })).toBeVisible();
    await expect(page.getByText(/SIG-BIRM27-\d+ created\./)).toBeVisible();
    const ref = new URL(page.url()).pathname.split("/").pop()!;

    // Upload and send for sign-off in one step.
    await page.setInputFiles('input[type="file"]', {
      name: "artwork.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"),
    });
    await expect(page.getByLabel("Send for sign-off after upload")).toBeChecked();
    await page.getByRole("button", { name: "Upload", exact: true }).click();
    await expect(page.getByText("v1 — artwork.pdf")).toBeVisible();
    await expect(page.getByText("In sign-off", { exact: true }).first()).toBeVisible();
    await opsCtx.close();

    // Marketing sees the step in My Sign-offs and approves it.
    const mktCtx = await browser.newContext();
    await signInAs(mktCtx, "marketing@media10.test", baseURL!);
    const mkt = await mktCtx.newPage();
    await mkt.goto(`${baseURL}/approvals`);
    const row = mkt.getByRole("main").locator("li", { hasText: ref });
    await expect(row).toBeVisible();
    await row.getByRole("button", { name: "Approve", exact: true }).click();
    await expect(
      mkt.getByText("Your approval is recorded against the current artwork version"),
    ).toBeVisible();
    await mkt.getByRole("dialog").getByRole("button", { name: "Approve", exact: true }).click();
    await expect(row).toHaveCount(0);
    await mktCtx.close();

    // Ops signs off from the item itself (the decision sits under the
    // preview), then confirms print, delivery and install from the next step.
    const opsCtx2 = await browser.newContext();
    await signInAs(opsCtx2, "ops@media10.test", baseURL!);
    const ops = await opsCtx2.newPage();
    // A 1×1 PNG stands in for the installer's camera photo.
    const PNG = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
      "base64",
    );
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await expect(ops.getByText("Your sign-off: Operations sign-off")).toBeVisible();
    await ops.getByRole("link", { name: "Review artwork" }).click();
    const mine = ops.getByRole("region", { name: "Your decision: Operations sign-off" });
    await mine.getByRole("button", { name: "Approve", exact: true }).click();
    await ops.getByRole("dialog").getByRole("button", { name: "Approve", exact: true }).click();
    await expect(ops.getByRole("dialog")).toHaveCount(0);
    await expect(ops.getByText("Signed off. Next: confirm it has gone to print")).toBeVisible();
    const confirmStep = async (button: string, photo?: boolean) => {
      await ops.getByRole("button", { name: button }).click();
      const dialog = ops.getByRole("dialog");
      if (photo) {
        await dialog
          .getByLabel(/photo of the installed item/i)
          .setInputFiles({ name: "install.png", mimeType: "image/png", buffer: PNG });
        await expect(dialog.getByAltText("Install photo preview")).toBeVisible();
      }
      await dialog.getByRole("button", { name: "Confirm", exact: true }).click();
      await expect(dialog).toHaveCount(0);
    };
    await confirmStep("Confirm sent to print");
    await expect(ops.getByText("Sent to print. Next: confirm delivery")).toBeVisible();
    await confirmStep("Confirm delivered");
    await expect(ops.getByText("Delivered. Next: confirm it is installed")).toBeVisible();
    await confirmStep("Confirm installed", true);
    await expect(ops.getByText("Installed. Next: mark it complete")).toBeVisible();
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=install`);
    await expect(ops.getByRole("link", { name: "View photo" })).toBeVisible();
    // Signed off, so the approval certificate is offered and downloads.
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}?tab=production`);
    const [cert] = await Promise.all([
      ops.waitForEvent("download"),
      ops.getByRole("link", { name: /approval certificate/i }).click(),
    ]);
    expect(cert.suggestedFilename()).toBe(`${ref}-approval-certificate.pdf`);
    await opsCtx2.close();
  });

  test("deleting an item returns to the schedule", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    const name = `E2E delete me ${Date.now()}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*");
    await page.getByRole("button", { name: "More" }).click();
    await page.getByRole("menuitem", { name: "Delete" }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toContainText("Recently deleted on the Signage page");
    await dialog.getByRole("button", { name: "Delete" }).click();
    await page.waitForURL("**/BIRM27/signage");
    await expect(page.getByText(/Deleted SIG-BIRM27-\d+/)).toBeVisible();
    await expect(page.getByText(name)).toHaveCount(0);
    await ctx.close();
  });
});
