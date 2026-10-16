import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

/** A sign with everything sign-off needs; Operations and Marketing sign it off. */
async function completeSign(page: Page, baseURL: string, name: string): Promise<string> {
  await page.goto(`${baseURL}/BIRM27/signage/new`);
  await page.getByLabel("Name", { exact: true }).fill(name);
  await page.getByRole("button", { name: "Change who signs off" }).click();
  await page.getByLabel("Needs Senior management sign-off").uncheck();
  await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
  await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
  await page.getByLabel("Location").selectOption({ label: "Registration" });
  await page.getByLabel("Width (mm)").fill("900");
  await page.getByLabel("Height (mm)").fill("600");
  await page.getByLabel("Fixing method").selectOption("wall_mounted");
  await page.getByRole("button", { name: "Create item" }).click();
  await page.waitForURL("**/signage/SIG-BIRM27-*?tab=artwork&created=1");
  return new URL(page.url()).pathname.split("/").pop()!;
}

async function upload(page: Page, fileName: string) {
  const button = page.getByRole("button", { name: "Upload", exact: true });
  // A file chosen before React has hydrated is lost; choose again until the
  // Upload button wakes up.
  for (let attempt = 0; attempt < 4; attempt++) {
    await page.setInputFiles('input[type="file"]', {
      name: fileName,
      mimeType: "application/pdf",
      buffer: PDF,
    });
    if (await button.isEnabled({ timeout: 2_000 }).catch(() => false)) break;
    await page.waitForTimeout(1_000);
  }
  await button.click();
}

test.describe("a sign's own page", () => {
  test("add another, then the checklist, the read-only details and the unsaved-changes guard", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(120_000);
    const page = await as(browser, "ops@media10.test", baseURL!);
    const stamp = Date.now();
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await expect(page.getByText("Needed for sign-off").first()).toBeVisible();
    await expect(page.getByText(/Signed off by: Operations, Marketing/)).toBeVisible();

    // "Create and add another" keeps the type and hall for the next one.
    await page.getByLabel("Name", { exact: true }).fill(`E2E first ${stamp}`);
    await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
    await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
    await page.getByRole("button", { name: "Create and add another" }).click();
    await expect(page.getByText(/SIG-BIRM27-\d+ created/).first()).toBeVisible();
    await expect(page.getByLabel("Name", { exact: true })).toHaveValue("");
    await expect(page.getByLabel("Name", { exact: true })).toBeFocused();
    await expect(page.getByLabel("Item type").locator("option:checked")).toHaveText("Foamex board");
    await expect(page.getByLabel("Hall", { exact: true }).locator("option:checked")).toHaveText(
      "Hall 1",
    );

    // The second lands on its artwork with a banner and what is missing.
    const name = `E2E second ${stamp}`;
    await page.getByLabel("Name", { exact: true }).fill(name);
    await page.getByRole("button", { name: "Create item" }).click();
    await page.waitForURL("**/signage/SIG-BIRM27-*?tab=artwork&created=1");
    const ref = new URL(page.url()).pathname.split("/").pop()!;
    await expect(page.getByText(`${ref} created.`)).toBeVisible();
    await expect(
      page.getByText(
        "Next: add hall and location, size and fixing method so it can go for sign-off",
      ),
    ).toBeVisible();
    const checklist = page.getByRole("list", { name: "Needed for sign-off" });
    await expect(checklist.getByText("Supplier (needed before print)")).toBeVisible();
    // Sending on upload waits for the fields.
    await expect(page.getByLabel("Send for sign-off after upload")).toBeDisabled();
    await expect(
      page.getByText(/Add hall and location, size and fixing method first; you can send it/),
    ).toBeVisible();
    // …and so does the next step's button, saying why.
    await expect(
      page.getByRole("button", { name: /^Send for sign-off — Add hall/ }),
    ).toBeDisabled();

    // A checklist line opens the form at that field.
    await checklist.getByRole("link", { name: /Size/ }).click();
    await expect(page.getByRole("heading", { name: "Edit details" })).toBeVisible();
    await expect(page.getByLabel("Width (mm)")).toBeFocused();
    await page.getByLabel("Location").selectOption({ label: "Registration" });
    await page.getByLabel("Width (mm)").fill("1000");
    await page.getByLabel("Height (mm)").fill("500");
    await page.getByLabel("Fixing method").selectOption("wall_mounted");
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByText(`${ref} saved`).first()).toBeVisible();
    // Back to the facts, read-only.
    await expect(page.getByRole("button", { name: "Edit details" })).toBeVisible();
    await expect(page.getByText("1000 × 500 mm")).toBeVisible();
    await expect(page.getByText("Next: upload the artwork")).toBeVisible();

    // Unsaved edits are not lost by a stray click.
    await page.getByRole("button", { name: "Edit details" }).click();
    await page.getByLabel("Name", { exact: true }).fill(`${name} (changed)`);
    await page.getByRole("link", { name: "History", exact: true }).click();
    const leave = page.getByRole("dialog");
    await expect(leave).toContainText("Leave without saving?");
    await leave.getByRole("button", { name: "Keep editing" }).click();
    await expect(page.getByRole("heading", { name: "Edit details" })).toBeVisible();
    await page.getByRole("button", { name: "Cancel", exact: true }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Discard changes" }).click();
    await expect(page.getByRole("button", { name: "Edit details" })).toBeVisible();
    await expect(page.getByRole("heading", { name, exact: true })).toBeVisible();

    // History always has a first line.
    await page.getByRole("link", { name: "History", exact: true }).click();
    await expect(page.getByRole("list", { name: "History" })).toContainText(`Created ${ref}`);
    await page.context().close();
  });

  test("changes requested: the corrected version goes straight back, and versions compare", async ({
    browser,
    baseURL,
  }) => {
    test.setTimeout(150_000);
    const ops = await as(browser, "ops@media10.test", baseURL!);
    const ref = await completeSign(ops, baseURL!, `E2E changes ${Date.now()}`);
    const itemUrl = `${baseURL}/BIRM27/signage/${ref}`;
    await upload(ops, "first.pdf");
    await expect(ops.getByText(`v1 uploaded and sent for sign-off`).first()).toBeVisible();
    await expect(ops.getByText("In sign-off", { exact: true }).first()).toBeVisible();

    // Marketing asks for changes from the item itself.
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await mkt.goto(itemUrl);
    await expect(mkt.getByText("Your sign-off: Marketing sign-off")).toBeVisible();
    await mkt.goto(`${itemUrl}?tab=artwork`);
    const mine = mkt.getByRole("region", { name: "Your decision: Marketing sign-off" });
    await mine.getByRole("button", { name: "Request changes" }).click();
    const dialog = mkt.getByRole("dialog");
    await dialog.getByLabel(/Comment/).fill("Make the logo bigger");
    await dialog.getByRole("button", { name: "Request changes" }).click();
    await expect(dialog).toHaveCount(0);
    await mkt.context().close();

    // Ops sees who asked and what, with the upload as the next step.
    await ops.goto(itemUrl);
    await expect(ops.getByText("Marcus Marketing asked for changes")).toBeVisible();
    await expect(ops.getByText("“Make the logo bigger”")).toBeVisible();
    // Sending back the same artwork asks first.
    await ops.getByRole("button", { name: "Resubmit without changes" }).click();
    const same = ops.getByRole("dialog");
    await expect(same).toContainText("No new artwork has been uploaded");
    await same.getByRole("button", { name: "Cancel" }).click();
    await expect(ops.getByText("Changes requested", { exact: true }).first()).toBeVisible();

    await ops.getByRole("link", { name: "Upload new version" }).click();
    await expect(ops.getByRole("heading", { name: "Upload the corrected version" })).toBeVisible();
    await expect(ops.getByLabel("Send back for sign-off after upload")).toBeChecked();
    await upload(ops, "second.pdf");
    await expect(ops.getByText("v2 uploaded and sent back for sign-off").first()).toBeVisible();
    await expect(ops.getByText("In sign-off", { exact: true }).first()).toBeVisible();

    // A "compare the versions" link opens the comparison.
    await ops.goto(`${itemUrl}?tab=artwork&compare=2`);
    await expect(ops.getByRole("heading", { name: "Compare versions" })).toBeVisible();
    await expect(ops.getByLabel("Left version").locator("option:checked")).toContainText("v1");
    await expect(ops.getByLabel("Right version").locator("option:checked")).toContainText("v2");
    await ops.context().close();
  });

  test("hold and resume live under More; the next step offers Resume", async ({
    browser,
    baseURL,
  }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    const ref = await completeSign(ops, baseURL!, `E2E hold ${Date.now()}`);
    await ops.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await ops.getByRole("button", { name: "More" }).click();
    await expect(ops.getByRole("menuitem", { name: "Delete" })).toBeVisible();
    await ops.getByRole("menuitem", { name: "Put on hold" }).click();
    const dialog = ops.getByRole("dialog");
    await dialog.getByLabel("Reason (required)").fill("Waiting for the sponsor");
    await dialog.getByRole("button", { name: "Put on hold" }).click();
    await expect(ops.getByText("On hold: Waiting for the sponsor")).toBeVisible();
    await ops.getByRole("button", { name: "Resume", exact: true }).click();
    await expect(ops.getByText(`${ref} resumed`).first()).toBeVisible();
    await expect(ops.getByText("Next: upload the artwork")).toBeVisible();
    await ops.context().close();
  });
});
