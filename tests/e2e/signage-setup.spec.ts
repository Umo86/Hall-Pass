import { expect, test, type Browser, type Page } from "@playwright/test";
import { signInAs } from "./helpers";

// A 1×1 PNG, used as a logo.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);
const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");
const stamp = () => String(Date.now()).slice(-7);

async function as(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext();
  await signInAs(ctx, email, baseURL);
  const page = await ctx.newPage();
  page.on("dialog", (d) => d.accept());
  return page;
}

/**
 * Decide the waiting step for `ref` from Approvals, with an optional comment.
 * Approve is on the row; Reject is in the row's "More decisions" menu.
 */
async function decide(
  page: Page,
  baseURL: string,
  ref: string,
  button: "Approve" | "Reject",
  comment?: string,
) {
  await page.goto(`${baseURL}/approvals`);
  const row = page.getByRole("main").locator("li", { hasText: ref });
  if (button === "Reject") {
    await row.getByRole("button", { name: `More decisions on ${ref}` }).click();
    await page.getByRole("menuitem", { name: "Reject…" }).click();
  } else {
    await row.getByRole("button", { name: button, exact: true }).click();
  }
  const dialog = page.getByRole("dialog");
  if (comment) await dialog.getByLabel(/Comment/).fill(comment);
  await dialog.getByRole("button", { name: button, exact: true }).click();
  await expect(dialog).toHaveCount(0);
}

/** The new-sign form with everything filled in, and who signs off opened up. */
async function newSignage(page: Page, baseURL: string, name: string) {
  await page.goto(`${baseURL}/BIRM27/signage/new`);
  await page.getByLabel("Name", { exact: true }).fill(name);
  await page.getByRole("button", { name: "Change who signs off" }).click();
  await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
  // Everything a sign needs before it can go for sign-off.
  await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
  await page.getByLabel("Location").selectOption({ label: "Registration" });
  await page.getByLabel("Width (mm)").fill("1000");
  await page.getByLabel("Height (mm)").fill("500");
  await page.getByLabel("Fixing method").selectOption("wall_mounted");
}

/** Create the sign, then upload its artwork, which sends it for sign-off. */
async function createAndSubmit(page: Page, baseURL: string): Promise<string> {
  await page.getByRole("button", { name: "Create item" }).click();
  await page.waitForURL("**/signage/SIG-BIRM27-*");
  const ref = new URL(page.url()).pathname.split("/").pop()!;
  await page.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
  // "Send for sign-off after upload" is ticked by default on a draft.
  await expect(page.getByLabel("Send for sign-off after upload")).toBeChecked();
  const upload = page.getByRole("button", { name: "Upload", exact: true });
  // A file chosen before React has hydrated is lost; choose again until the
  // Upload button wakes up.
  for (let attempt = 0; attempt < 4; attempt++) {
    await page.setInputFiles('input[type="file"]', {
      name: "art.pdf",
      mimeType: "application/pdf",
      buffer: PDF,
    });
    if (await upload.isEnabled({ timeout: 2_000 }).catch(() => false)) break;
    await page.waitForTimeout(1_000);
  }
  await upload.click();
  await expect(page.getByText(/^v1 uploaded and sent for sign-off — /).first()).toBeVisible();
  await expect(page.getByText("v1 — art.pdf")).toBeVisible();
  await page.goto(`${baseURL}/BIRM27/signage/${ref}`);
  await expect(page.getByText("In sign-off", { exact: true }).first()).toBeVisible();
  return ref;
}

test.describe("signage set-up and sign-off", () => {
  test("admin adds a digital signage type and a supplier service", async ({ browser, baseURL }) => {
    const page = await as(browser, "admin@media10.test", baseURL!);
    const typeName = `E2E Totem ${stamp()}`;
    await page.goto(`${baseURL}/settings/item-types`);
    const signage = page.getByRole("region", { name: "Signage" });
    await signage.getByRole("button", { name: "Add signage type" }).click();
    const dialog = page.getByRole("dialog", { name: "Add a signage type" });
    await dialog.getByLabel("Name").fill(typeName);
    await dialog.getByLabel("Digital").check();
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = signage.getByRole("listitem").filter({ hasText: typeName });
    await expect(row.getByText(/^Digital · 0 items$/)).toBeVisible();

    // It is offered under Digital on the new-item form.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await expect(
      page.locator('optgroup[label="Digital"] option', { hasText: typeName }),
    ).toHaveCount(1);

    // Archive it again so the list stays tidy.
    await page.goto(`${baseURL}/settings/item-types`);
    await signage.getByRole("button", { name: `Archive ${typeName}` }).click();
    await page
      .getByRole("dialog", { name: `Archive ${typeName}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(signage.getByRole("button", { name: `Archive ${typeName}` })).toHaveCount(0);
    await expect(signage.getByText(/^Archived \(\d+\)$/)).toBeVisible();

    // What suppliers do is managed from Suppliers.
    const service = `E2E Cleaning ${stamp()}`;
    await page.goto(`${baseURL}/suppliers?manage=services`);
    const manage = page.getByRole("dialog", { name: "What suppliers do" });
    await manage.getByLabel("New service").fill(service);
    await manage.getByRole("button", { name: "Add", exact: true }).click();
    await expect(manage.getByText(service, { exact: true })).toBeVisible();
    await manage.getByRole("button", { name: `Archive ${service}` }).click();
    await page
      .getByRole("dialog", { name: `Archive ${service}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    // Archived services can't be renamed until they're restored.
    await expect(manage.getByRole("button", { name: /^Rename / }).first()).toBeVisible();
    await expect(manage.getByRole("button", { name: `Rename ${service}` })).toHaveCount(0);
    await manage.getByText(/^Archived \(\d+\)$/).click();
    await expect(manage.getByRole("button", { name: `Restore ${service}` })).toBeVisible();
    await page.context().close();
  });

  test("ops adds a supplier and says what they do", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E Supplies ${stamp()}`;
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).first().click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Company name").fill(name);
    await dialog.getByLabel("Staffing", { exact: true }).check();
    await dialog.getByLabel("Signage print", { exact: true }).check();
    await dialog.getByLabel("Email").fill("hello@e2e-supplies.test");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = page.getByRole("main").getByRole("row", { name: new RegExp(name) });
    await expect(row.getByText("Staffing")).toBeVisible();
    await expect(row.getByText("Signage print")).toBeVisible();

    // Filter by what they do.
    const whatTheyDo = page.getByLabel("What they do");
    const staffing = await whatTheyDo
      .locator("option", { hasText: /^Staffing \(\d+\)$/ })
      .getAttribute("value");
    await whatTheyDo.selectOption(staffing!);
    await expect(row).toBeVisible();
    await expect(page.getByRole("main").getByRole("row", { name: /Big Print Co/ })).toHaveCount(0);

    // Offered on the item form with its services.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await expect(
      page.locator("option", { hasText: `${name} — Signage print, Staffing` }),
    ).toHaveCount(1);

    // Clean up: archive the unused supplier, then delete it from the archived list.
    await page.goto(`${baseURL}/suppliers`);
    await row.getByRole("button", { name: `Edit ${name}` }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Archive" }).click();
    await page
      .getByRole("dialog", { name: `Archive ${name}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(row).toHaveCount(0);
    await page.getByText(/^Archived \(\d+\)$/).click();
    await page.getByRole("button", { name: `Delete ${name}` }).click();
    await page
      .getByRole("dialog", { name: `Delete ${name} for good?` })
      .getByRole("button", { name: "Delete" })
      .click();
    await expect(page.getByRole("button", { name: `Restore ${name}` })).toHaveCount(0);
    await page.context().close();
  });

  test("ops creates an event with a new venue, then adds its address and logo", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const n = stamp();
    const code = `E2E${n}`;
    await page.goto(`${baseURL}/start?mode=fresh`, { waitUntil: "networkidle" });
    await expect(page.getByRole("heading", { name: "Create your event" })).toBeVisible();
    await page.getByLabel("Event name").fill(`E2E Expo ${n}`);
    await page.getByLabel("Opens to visitors").fill("2028-03-03");
    await page.getByLabel("Closes to visitors").fill("2028-03-05");
    await page.getByLabel("Venue", { exact: true }).selectOption("new");
    await page.getByLabel("Venue name").fill(`E2E Hall ${n}`);
    await page.getByLabel("Address (optional)").fill("1 Test Street, Testville TE5 7ST");
    await page.getByRole("button", { name: "Change" }).click();
    await page.getByLabel("Reference code").fill(code);
    await page.getByRole("button", { name: "Create event" }).click();
    await page.waitForURL(`**/${code}/setup`);
    await page.waitForLoadState("networkidle");

    // Step 1: the assumed dates are there to check; add the logo and save.
    await expect(page.getByLabel("Build-up starts")).toHaveValue("2028-03-01");
    await expect(page.getByLabel("Breakdown ends")).toHaveValue("2028-03-06");
    await expect(page.getByLabel("Venue address")).toHaveValue("1 Test Street, Testville TE5 7ST");
    await page
      .getByLabel("Logo (optional)")
      .setInputFiles({ name: "logo.png", mimeType: "image/png", buffer: PNG });
    await page.getByRole("button", { name: "Save and continue" }).click();
    await expect(page.getByText("Details saved")).toBeVisible();

    await page.goto(`${baseURL}/${code}/dashboard`);
    await expect(page.getByRole("heading", { name: `E2E Expo ${n}` })).toBeVisible();
    await expect(page.getByAltText(`E2E Expo ${n} logo`)).toBeVisible();
    await expect(
      page.getByText("1 Test Street, Testville TE5 7ST", { exact: false }),
    ).toBeVisible();
    // A new event has no signs yet: the dashboard says how to add them.
    await expect(page.getByText("No signs yet")).toBeVisible();
    await expect(page.getByRole("link", { name: "Add a sign" })).toHaveAttribute(
      "href",
      `/${code}/signage/new`,
    );
    await page.context().close();
  });

  test("organiser signage: Operations, Marketing and Senior management sign off, all logged", async ({
    browser,
    baseURL,
  }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await newSignage(ops, baseURL!, `E2E three sign-offs ${stamp()}`);
    await expect(ops.getByLabel("Needs Operations sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Marketing sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Senior management sign-off")).toBeChecked();
    await expect(ops.getByLabel("Needs Sales sign-off")).not.toBeChecked();
    // Name the marketing person.
    await ops
      .getByLabel("Who signs Marketing sign-off")
      .selectOption({ label: "Marcus Marketing — Marketing Manager" });
    const ref = await createAndSubmit(ops, baseURL!);

    // The named person — and the department — are asked.
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await decide(mkt, baseURL!, ref, "Approve", "Brand looks right");
    await decide(ops, baseURL!, ref, "Approve");

    // Senior management (Dana by default) is asked once both have approved,
    // and rejects with a reason.
    const director = await as(browser, "director@media10.test", baseURL!);
    await decide(director, baseURL!, ref, "Reject", "Wrong show dates on the artwork");
    await director.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await expect(director.getByText("Rejected", { exact: true }).first()).toBeVisible();

    // Every decision is in History, with the comments.
    await director.goto(`${baseURL}/BIRM27/signage/${ref}?tab=history`);
    await expect(
      director.getByText("Marketing sign-off: approved — “Brand looks right”"),
    ).toBeVisible();
    await expect(director.getByText("Operations sign-off: approved")).toBeVisible();
    await expect(
      director.getByText(
        "Senior management sign-off: rejected — “Wrong show dates on the artwork”",
      ),
    ).toBeVisible();

    // A comment can be left under the sign-off chain without deciding.
    await director.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
    await director.getByLabel("Leave a comment").fill("Dates fixed on v2 please");
    await director.getByRole("button", { name: "Post comment" }).click();
    await expect(director.getByText("Comment added")).toBeVisible();
    await director.goto(`${baseURL}/BIRM27/signage/${ref}?tab=comments`);
    await expect(director.getByText("Dates fixed on v2 please")).toBeVisible();
    for (const p of [ops, mkt, director]) await p.context().close();
  });

  test("a Marketing-only item is signed off by one approval", async ({ browser, baseURL }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await newSignage(ops, baseURL!, `E2E marketing only ${stamp()}`);
    await ops.getByLabel("Needs Operations sign-off").uncheck();
    await ops.getByLabel("Needs Senior management sign-off").uncheck();
    const ref = await createAndSubmit(ops, baseURL!);
    const mkt = await as(browser, "marketing@media10.test", baseURL!);
    await decide(mkt, baseURL!, ref, "Approve");
    await mkt.goto(`${baseURL}/BIRM27/signage/${ref}`);
    await expect(mkt.getByText("Approved", { exact: true }).first()).toBeVisible();
    for (const p of [ops, mkt]) await p.context().close();
  });

  test("sponsor signage asks for the sponsor and adds Sales", async ({ browser, baseURL }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E sponsor sign ${stamp()}`;
    await newSignage(ops, baseURL!, name);
    await ops.getByLabel(/Sponsor signage/).check();
    await expect(ops.getByLabel("Needs Sales sign-off")).toBeChecked();
    await ops.getByLabel("Sponsor", { exact: true }).selectOption({ label: "BuildCo" });
    await ops.getByRole("button", { name: "Create item" }).click();
    await ops.waitForURL("**/signage/SIG-BIRM27-*");
    const ref = new URL(ops.url()).pathname.split("/").pop()!;
    // Listed under Sponsorship with the sponsor, and in the schedule.
    await ops.goto(`${baseURL}/BIRM27/sponsorship`);
    const card = ops.getByRole("main").getByRole("listitem", { name });
    await expect(card.getByText("BuildCo", { exact: true })).toBeVisible();
    // Sponsor signage comes with the package rather than being sold on its own.
    await expect(card.getByText("In package", { exact: true })).toBeVisible();
    await ops.goto(`${baseURL}/BIRM27/signage?q=${ref}`);
    // The Sponsor column is one click away in Columns.
    await ops.getByRole("button", { name: "Columns" }).click();
    await ops.getByRole("menuitemcheckbox", { name: "Sponsor" }).click();
    await ops.keyboard.press("Escape");
    await expect(
      ops.getByRole("main").locator("tr", { hasText: ref }).getByText("BuildCo", { exact: true }),
    ).toBeVisible();
    await ops.context().close();
  });
});
