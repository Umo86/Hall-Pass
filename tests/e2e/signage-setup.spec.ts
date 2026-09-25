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

/** Decide the waiting step for `ref` from My Work, with an optional comment. */
async function decide(page: Page, baseURL: string, ref: string, button: string, comment?: string) {
  await page.goto(`${baseURL}/approvals`);
  const row = page.locator("li", { hasText: ref });
  await row.getByRole("button", { name: button, exact: true }).click();
  const dialog = page.getByRole("dialog");
  if (comment) await dialog.getByLabel(/Comment/).fill(comment);
  await dialog.getByRole("button", { name: button, exact: true }).click();
  await expect(dialog).toHaveCount(0);
}

async function newSignage(page: Page, baseURL: string, name: string) {
  await page.goto(`${baseURL}/BIRM27/signage/new`);
  await page.getByLabel("Name", { exact: true }).fill(name);
  await page.getByLabel("Item type").selectOption({ label: "Foamex board" });
  // Everything a sign needs before it can go for sign-off.
  await page.getByLabel("Hall", { exact: true }).selectOption({ label: "Hall 1" });
  await page.getByLabel("Location").selectOption({ label: "Registration" });
  await page.getByLabel("Width (mm)").fill("1000");
  await page.getByLabel("Height (mm)").fill("500");
  await page.getByLabel("Fixing method").selectOption("wall_mounted");
}

async function createAndSubmit(page: Page, baseURL: string): Promise<string> {
  await page.getByRole("button", { name: "Create item" }).click();
  await page.waitForURL("**/signage/SIG-BIRM27-*");
  const ref = new URL(page.url()).pathname.split("/").pop()!;
  await page.goto(`${baseURL}/BIRM27/signage/${ref}?tab=artwork`);
  await page.setInputFiles('input[type="file"]', { name: "art.pdf", mimeType: "application/pdf", buffer: PDF });
  await page.getByRole("button", { name: "Upload" }).click();
  await expect(page.getByText("v1 — art.pdf")).toBeVisible();
  await page.goto(`${baseURL}/BIRM27/signage/${ref}`);
  await page.getByRole("button", { name: "Submit for review" }).click();
  await expect(page.getByText("In review", { exact: true })).toBeVisible();
  return ref;
}

test.describe("signage set-up and sign-off", () => {
  test("admin adds a digital signage type and a supplier service", async ({ browser, baseURL }) => {
    const page = await as(browser, "admin@media10.test", baseURL!);
    const typeName = `E2E Totem ${stamp()}`;
    await page.goto(`${baseURL}/settings?tab=types`);
    await page.getByRole("button", { name: "Add a type" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Name").fill(typeName);
    await dialog.getByLabel("Digital").check();
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = page.locator("li", { hasText: typeName });
    await expect(row.getByText("Digital signage")).toBeVisible();

    // It is offered under Digital on the new-item form.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await expect(page.locator('optgroup[label="Digital"] option', { hasText: typeName })).toHaveCount(1);

    // Hide it again so the list stays tidy.
    await page.goto(`${baseURL}/settings?tab=types`);
    await page.locator("li", { hasText: typeName }).getByRole("button", { name: "Hide" }).click();
    await expect(page.getByText(/Hidden types/)).toBeVisible();

    const service = `E2E Cleaning ${stamp()}`;
    await page.goto(`${baseURL}/settings?tab=services`);
    await page.getByLabel("New service").fill(service);
    await page.getByRole("button", { name: "Add service" }).click();
    await expect(page.locator("li", { hasText: service })).toBeVisible();
    await page.locator("li", { hasText: service }).getByRole("button", { name: "Remove" }).click();
    await expect(page.getByText(/Removed services/)).toBeVisible();
    await expect(page.getByRole("button", { name: "Rename" }).first()).toBeVisible();
    await expect(page.locator("li", { hasText: service }).getByRole("button", { name: "Rename" })).toHaveCount(0);
    await page.context().close();
  });

  test("ops adds a supplier and says what they do", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E Supplies ${stamp()}`;
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Company name").fill(name);
    await dialog.getByLabel("Staffing").check();
    await dialog.getByLabel("Signage print").check();
    await dialog.getByLabel("Email").fill("hello@e2e-supplies.test");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const card = page.locator("li", { hasText: name });
    await expect(card.getByText("Staffing")).toBeVisible();
    await expect(card.getByText("Signage print")).toBeVisible();

    // Filter by service.
    await page.getByRole("group", { name: "Filter by service" }).getByRole("button", { name: "Staffing" }).click();
    await expect(card).toBeVisible();
    await expect(page.locator("li", { hasText: "Big Print Co" })).toHaveCount(0);

    // Offered on the item form with its services.
    await page.goto(`${baseURL}/BIRM27/signage/new`);
    await expect(page.locator("option", { hasText: `${name} — Signage print, Staffing` })).toHaveCount(1);

    // Clean up.
    await page.goto(`${baseURL}/suppliers`);
    await page.locator("li", { hasText: name }).getByRole("button", { name: "Edit" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Remove" }).click();
    await expect(page.locator("li", { hasText: name })).toHaveCount(0);
    await page.context().close();
  });

  test("ops creates a show with a new venue, address and logo", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const n = stamp();
    const code = `E2E${n}`;
    await page.goto(`${baseURL}/editions`);
    await page.getByRole("button", { name: "New show" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Show name").fill(`E2E Expo ${n}`);
    await dialog.getByLabel("Short code").fill(code);
    await dialog.getByLabel("Show series").selectOption("new");
    await dialog.getByLabel("New series name").fill(`E2E Expo Series ${n}`);
    await dialog.getByLabel("Venue", { exact: true }).selectOption("new");
    await dialog.getByLabel("New venue name").fill(`E2E Hall ${n}`);
    await dialog.getByLabel("Venue address").fill("1 Test Street, Testville TE5 7ST");
    await dialog.getByLabel("Logo (optional)").setInputFiles({ name: "logo.png", mimeType: "image/png", buffer: PNG });
    await dialog.getByLabel("Build starts").fill("2028-03-01");
    await dialog.getByLabel("Build ends").fill("2028-03-02");
    await dialog.getByLabel("Show opens").fill("2028-03-03");
    await dialog.getByLabel("Show closes").fill("2028-03-05");
    await dialog.getByLabel("Breakdown ends").fill("2028-03-06");
    await dialog.getByRole("button", { name: "Create show" }).click();
    await page.waitForURL(`**/${code}/dashboard`);
    await expect(page.getByRole("heading", { name: `E2E Expo ${n}` })).toBeVisible();
    await expect(page.getByAltText(`E2E Expo ${n} logo`)).toBeVisible();
    await expect(page.getByText("1 Test Street, Testville TE5 7ST", { exact: false })).toBeVisible();
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
    await ops.getByLabel("Who signs Marketing sign-off").selectOption({ label: "Marcus Marketing" });
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
    await expect(director.getByText("Marketing sign-off: approved — “Brand looks right”")).toBeVisible();
    await expect(director.getByText("Operations sign-off: approved")).toBeVisible();
    await expect(
      director.getByText("Senior management sign-off: rejected — “Wrong show dates on the artwork”"),
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
    await expect(ops.locator("tr", { hasText: ref }).getByText("BuildCo")).toBeVisible();
    await ops.goto(`${baseURL}/BIRM27/signage?q=${ref}`);
    await expect(ops.locator("tr", { hasText: ref }).getByText("BuildCo")).toBeVisible();
    await ops.context().close();
  });
});
