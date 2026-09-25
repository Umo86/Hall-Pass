import { expect, test } from "@playwright/test";
import { signInAs } from "./helpers";

const STAFF_PAGES = [
  "/my-work",
  "/approvals",
  "/approvals?tab=artwork",
  "/approvals?tab=approvers",
  "/editions",
  "/suppliers",
  "/settings",
  "/settings?tab=team",
  "/settings?tab=types",
  "/settings?tab=services",
  "/settings?tab=venues",
  "/BIRM27/dashboard",
  "/BIRM27/signage",
  "/BIRM27/signage/SIG-BIRM27-001",
  "/BIRM27/signage/SIG-BIRM27-001?tab=artwork",
  "/BIRM27/signage/SIG-BIRM27-001?tab=history",
  "/BIRM27/sponsorship",
  "/BIRM27/sponsorship?tab=sponsors",
  "/BIRM27/sponsorship/SIG-BIRM27-031",
  "/BIRM27/calendar",
  "/BIRM27/reports",
  "/BIRM27/halls",
];

test.describe("every page, every role", () => {
  for (const email of [
    "admin@media10.test",
    "ops@media10.test",
    "marketing@media10.test",
    "sales@media10.test",
    "director@media10.test",
    "viewer@media10.test",
  ]) {
    test(`staff pages load for ${email}`, async ({ browser, baseURL }) => {
      const ctx = await browser.newContext();
      await signInAs(ctx, email, baseURL!);
      const page = await ctx.newPage();
      const errors: string[] = [];
      page.on("pageerror", (e) => errors.push(e.message));
      for (const path of STAFF_PAGES) {
        const res = await page.goto(`${baseURL}${path}`);
        expect(res?.status(), path).toBeLessThan(400);
        await expect(page.getByRole("heading", { name: "Something went wrong" }), path).toHaveCount(
          0,
        );
      }
      expect(errors).toEqual([]);
      await ctx.close();
    });
  }

  test("signed-out visitors only see the sign-in page", async ({ page, baseURL }) => {
    for (const path of ["/my-work", "/approvals", "/BIRM27/signage", "/settings", "/suppliers"]) {
      await page.goto(`${baseURL}${path}`);
      await expect(page).toHaveURL(/\/login/);
    }
    // Downloads send you to sign in rather than serving the file.
    const res = await page.request.get(`${baseURL}/api/exports/schedule/BIRM27`, {
      maxRedirects: 0,
    });
    expect(res.status()).toBe(307);
    expect(res.headers()["location"]).toContain("/login");
    const files = await page.request.get(
      `${baseURL}/api/task-files/00000000-0000-4000-8000-000000000000`,
    );
    expect(files.status()).toBe(401);
  });

  test("there is no sign-up: the invitation page needs a real invitation", async ({
    page,
    baseURL,
  }) => {
    await page.goto(`${baseURL}/invite/not-a-real-token-123456`);
    await expect(page.getByText("This invitation link is not valid.")).toBeVisible();
    await page.goto(`${baseURL}/auth/accept`);
    await expect(
      page.getByText(/Sign-in isn't set up on this site|Open this page from the invitation email/),
    ).toBeVisible();
  });

  test("hostile input is stored and shown as plain text", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    let alerted = false;
    page.on("dialog", async (d) => {
      alerted = true;
      await d.dismiss();
    });
    const nasty = `Robert'); DROP TABLE tasks;-- <img src=x onerror=alert(1)> ${Date.now()}`;
    await page.goto(`${baseURL}/my-work`);
    await page.getByLabel("Task title").fill(nasty);
    await page.getByRole("button", { name: "Add" }).click();
    await expect(page.getByRole("listitem", { name: nasty })).toBeVisible();
    await page.reload();
    await expect(page.getByRole("listitem", { name: nasty })).toBeVisible();
    // Search boxes take it too.
    await page.goto(`${baseURL}/BIRM27/signage?q=${encodeURIComponent("' OR 1=1 --")}`);
    await expect(page.getByRole("heading", { name: /Signage schedule/ })).toBeVisible();
    await page.goto(`${baseURL}/approvals?tab=artwork&q=${encodeURIComponent("%' OR '1'='1")}`);
    await expect(page.getByRole("heading", { name: "Approvals" })).toBeVisible();
    expect(alerted).toBe(false);
    await ctx.close();
  });
});

test.describe("calendar and suppliers", () => {
  test("the calendar shows deadlines in red and has a key", async ({ browser, baseURL }) => {
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    // The month of the seeded Water bottles order-by date (18 days ahead).
    const target = new Date(Date.now() + 18 * 86_400_000);
    const m = `${target.getUTCFullYear()}-${String(target.getUTCMonth() + 1).padStart(2, "0")}`;
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto(`${baseURL}/BIRM27/calendar?m=${m}`);
    const key = page.getByLabel("Key");
    for (const label of ["Deadline", "Deadline passed", "Show dates", "Delivery", "Install"]) {
      await expect(key.getByText(label, { exact: true })).toBeVisible();
    }
    const chip = page.getByRole("link", { name: "Sell & order by: Water bottles" }).first();
    await expect(chip).toBeVisible();
    await expect(chip).toHaveClass(/bg-red/);
    await ctx.close();
  });

  test("a new 'what they do' can be added from the supplier popup", async ({
    browser,
    baseURL,
  }) => {
    const n = String(Date.now()).slice(-6);
    const name = `E2E Crew ${n}`;
    const service = `Cloakroom staff ${n}`;
    const ctx = await browser.newContext();
    await signInAs(ctx, "ops@media10.test", baseURL!);
    const page = await ctx.newPage();
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Company name").fill(name);
    await dialog.getByLabel("Add something they do").fill(service);
    await dialog.getByRole("button", { name: "Add", exact: true }).click();
    await expect(dialog.getByLabel(`${service} (new)`)).toBeChecked();
    // Typing an existing one just ticks it.
    await dialog.getByLabel("Add something they do").fill("staffing");
    await dialog.getByLabel("Add something they do").press("Enter");
    await expect(dialog.getByLabel("Staffing", { exact: true })).toBeChecked();
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const card = page.locator("li", { hasText: name });
    await expect(card.getByText(service)).toBeVisible();
    await expect(card.getByText("Staffing")).toBeVisible();
    // It's now on the shared list for everyone.
    await page.goto(`${baseURL}/settings?tab=services`);
    await expect(page.getByText(service)).toBeVisible();
    await ctx.close();
  });
});
