import { randomUUID } from "node:crypto";
import { expect, test, type Browser } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Suppliers: a compact list with search, "What they do" and "Used on the
 * event"; archive, restore and delete-when-unused; install contractors with
 * insurance warnings; and portal access next to each supplier.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const stamp = () => String(Date.now()).slice(-7);
const iso = (offsetDays: number) =>
  new Date(Date.now() + offsetDays * 86_400_000).toISOString().slice(0, 10);

async function as(browser: Browser, email: string, baseURL: string, width = 1280) {
  const ctx = await browser.newContext({ viewport: { width, height: 900 } });
  await signInAs(ctx, email, baseURL);
  const url = new URL(baseURL);
  await ctx.addCookies([
    { name: "hp-last-event", value: "BIRM27", domain: url.hostname, path: "/", sameSite: "Lax" },
  ]);
  return ctx.newPage();
}

test.describe("suppliers", () => {
  test("search, What they do, Used on the event and the items link", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    await page.goto(`${baseURL}/suppliers`);
    const main = page.getByRole("main");
    await expect(main.getByRole("link", { name: /^Suppliers \d+$/ })).toHaveAttribute(
      "aria-current",
      "page",
    );
    await expect(main.getByRole("columnheader", { name: "Items on BIRM27" })).toBeVisible();

    const av = await page
      .getByLabel("What they do")
      .locator("option", { hasText: /^Digital screens & AV/ })
      .getAttribute("value");
    await page.getByLabel("What they do").selectOption(av!);
    await expect(main.getByRole("row", { name: /Screen Hire Ltd/ })).toBeVisible();
    await expect(main.getByRole("row", { name: /Big Print Co/ })).toHaveCount(0);
    await expect(page).toHaveURL(/service=/);
    await page.getByLabel("What they do").selectOption("");

    await page.getByLabel("Search suppliers").fill("big print");
    const big = main.getByRole("row", { name: /Big Print Co/ });
    await expect(big).toBeVisible();
    await expect(
      big.getByRole("link", { name: /items? from Big Print Co on BIRM27/ }),
    ).toHaveAttribute("href", /^\/BIRM27\/signage\?supplier=[0-9a-f-]{36}$/);
    await page.getByLabel("Search suppliers").fill("");

    const used = page.getByRole("button", { name: "Used on BIRM27" });
    await used.click();
    await expect(used).toHaveAttribute("aria-pressed", "true");
    await expect(main.getByRole("row", { name: /Big Print Co/ })).toBeVisible();
    // Suppliers with nothing on BIRM27 drop out.
    await expect(main.getByRole("row", { name: /E2E Crew/ })).toHaveCount(0);
    await page.getByRole("button", { name: "All", exact: true }).click();
    await page.context().close();
  });

  test("archive, restore, and delete only when nothing uses it", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E Supplies ${stamp()}`;
    await page.goto(`${baseURL}/suppliers`);
    await page.getByRole("button", { name: "Add supplier" }).first().click();
    const dialog = page.getByRole("dialog", { name: "Add a supplier" });
    await dialog.getByLabel("Company name").fill(name);
    await dialog.getByLabel("Staffing", { exact: true }).check();
    await dialog.getByLabel("Email (optional)").fill("hello@e2e-supplies.test");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText(`${name} saved`)).toBeVisible();
    const row = page.getByRole("main").getByRole("row", { name: new RegExp(name) });
    await expect(row.getByText("Staffing")).toBeVisible();
    await expect(row.getByRole("link", { name: "hello@e2e-supplies.test" })).toBeVisible();

    await row.getByRole("button", { name: `Edit ${name}` }).click();
    await page
      .getByRole("dialog", { name: `Edit ${name}` })
      .getByRole("button", { name: "Archive" })
      .click();
    await page
      .getByRole("dialog", { name: `Archive ${name}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(page.getByText(`${name} archived — hidden from lists and pickers`)).toBeVisible();
    await expect(row).toHaveCount(0);

    await page.getByText(/^Archived \(\d+\)$/).click();
    await page.getByRole("button", { name: `Restore ${name}` }).click();
    await expect(row).toBeVisible();

    // Archive again, then delete it for good (nothing uses it).
    await row.getByRole("button", { name: `Edit ${name}` }).click();
    await page
      .getByRole("dialog", { name: `Edit ${name}` })
      .getByRole("button", { name: "Archive" })
      .click();
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
    await expect(page.getByText(`${name} deleted`)).toBeVisible();
    await expect(page.getByRole("button", { name: `Restore ${name}` })).toHaveCount(0);
    await page.context().close();
  });

  test("an archived supplier used by a deleted item says why it stays", async ({
    browser,
    baseURL,
  }) => {
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const n = stamp();
    const supplierId = randomUUID();
    const itemId = randomUUID();
    const name = `E2E Kept Ltd ${n}`;
    const [ed] = await sql`
      select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
    await sql`insert into suppliers (id, organisation_id, name, is_archived)
      values (${supplierId}, ${ed.organisation_id}, ${name}, true)`;
    await sql`insert into signage_items (id, edition_id, ref, seq, name, created_by, supplier_id, deleted_at)
      values (${itemId}, ${ed.id}, ${`SIG-BIRM27-K${n}`}, ${700000 + Number(n.slice(-5))},
        ${`E2E kept sign ${n}`}, ${ops.id}, ${supplierId}, now())`;
    try {
      const page = await as(browser, "ops@media10.test", baseURL!);
      await page.goto(`${baseURL}/suppliers`);
      await page.getByText(/^Archived \(\d+\)$/).click();
      const item = page
        .getByRole("list", { name: "Archived suppliers" })
        .getByRole("listitem")
        .filter({ hasText: name });
      await expect(
        item.getByText(`1 deleted item still uses ${name}`, { exact: false }),
      ).toBeVisible();
      await expect(item.getByRole("link", { name: "Open the Recycle bin" })).toHaveAttribute(
        "href",
        "/settings/recycle-bin",
      );
      await expect(item.getByRole("button", { name: `Delete ${name}` })).toHaveCount(0);
      await expect(item.getByRole("button", { name: `Restore ${name}` })).toBeVisible();
      await page.context().close();
    } finally {
      await sql`delete from signage_items where id = ${itemId}`;
      await sql`delete from suppliers where id = ${supplierId}`;
      await sql.end();
    }
  });

  test("on a phone suppliers are cards with an edit button", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!, 390);
    await page.goto(`${baseURL}/suppliers?q=${encodeURIComponent("Big Print")}`);
    const card = page.getByRole("list", { name: "Suppliers" }).getByRole("listitem").first();
    await expect(card.getByText("Big Print Co")).toBeVisible();
    await expect(card.getByRole("button", { name: "Edit Big Print Co" })).toBeVisible();
    await expect(page.getByRole("main").getByRole("table")).toBeHidden();
    // Nothing in the page itself is wider than the phone (the app header is checked elsewhere).
    const widest = await page
      .getByRole("main")
      .evaluate((main) =>
        Math.max(...[...main.querySelectorAll("*")].map((e) => e.getBoundingClientRect().right)),
      );
    expect(widest).toBeLessThanOrEqual(390);
    await page.context().close();
  });

  test("install contractors have their own tab and insurance warnings", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E Riggers ${stamp()}`;
    try {
      await page.goto(`${baseURL}/suppliers`);
      await page
        .getByRole("main")
        .getByRole("link", { name: /^Install contractors \d+$/ })
        .click();
      await expect(page).toHaveURL(/tab=contractors/);
      const main = page.getByRole("main");
      await expect(main.getByRole("columnheader", { name: "Insurance expires" })).toBeVisible();

      await page.getByRole("button", { name: "Add install contractor" }).first().click();
      const dialog = page.getByRole("dialog", { name: "Add an install contractor" });
      await dialog.getByLabel("Company name").fill(name);
      await dialog.getByLabel("Insurance expires (optional)").fill(iso(-1));
      await dialog.getByRole("button", { name: "Save" }).click();
      await expect(dialog).toHaveCount(0);
      const row = main.getByRole("row", { name: new RegExp(name) });
      await expect(row.getByText("Insurance expired")).toBeVisible();
      // Shown as a British date, not ISO.
      await expect(row.getByText(/^\d{1,2} [A-Z][a-z]{2} \d{4}$/)).toBeVisible();

      await row.getByRole("button", { name: `Edit ${name}` }).click();
      const edit = page.getByRole("dialog", { name: `Edit ${name}` });
      await edit.getByLabel("Insurance expires (optional)").fill(iso(10));
      await edit.getByRole("button", { name: "Save" }).click();
      await expect(edit).toHaveCount(0);
      await expect(row.getByText(/Expires in (9|10) days/)).toBeVisible();
    } finally {
      const sql = postgres(DB, { max: 1, onnotice: () => {} });
      await sql`delete from contractors where name = ${name}`;
      await sql.end();
      await page.context().close();
    }
  });

  test("portal access is managed from the supplier", async ({ browser, baseURL }) => {
    const email = `e2e-portal-${stamp()}@bigprint.test`;
    const page = await as(browser, "admin@media10.test", baseURL!);
    try {
      await page.goto(`${baseURL}/suppliers?q=${encodeURIComponent("Big Print Co")}`);
      const row = page.getByRole("main").getByRole("row", { name: /Big Print Co/ });
      await row.getByRole("button", { name: /Portal access for Big Print Co/ }).click();
      const dialog = page.getByRole("dialog", { name: "Portal access · Big Print Co" });
      await expect(dialog.getByText("print@bigprint.test").first()).toBeVisible();
      await dialog.getByRole("button", { name: "Invite someone from Big Print Co" }).click();
      const form = dialog.getByRole("form", { name: "Invite someone from Big Print Co" });
      await expect(form.getByLabel("Event").locator("option:checked")).toHaveText(
        /UKCW Birmingham 2027/,
      );
      await form.getByLabel("Their email").fill(email);
      await form.getByRole("button", { name: "Send invitation" }).click();
      // With email off here, the link is shown to pass on.
      const done = dialog.getByRole("button", { name: "Done" });
      const person = dialog.getByRole("listitem").filter({ hasText: email });
      await expect(done.or(person)).toBeVisible();
      if (await done.isVisible()) await done.click();
      await expect(person.getByText("Invited")).toBeVisible();
      await person.getByRole("button", { name: `Revoke access for ${email}` }).click();
      await page
        .getByRole("dialog", { name: `Revoke ${email}'s access?` })
        .getByRole("button", { name: "Revoke access" })
        .click();
      await expect(dialog.getByText(email)).toHaveCount(0);
    } finally {
      const sql = postgres(DB, { max: 1, onnotice: () => {} });
      await sql`delete from external_grants where invited_email = ${email}`;
      await sql.end();
      await page.context().close();
    }

    // Operations see who has access but can't invite.
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/suppliers?q=${encodeURIComponent("Big Print Co")}`);
    await ops
      .getByRole("main")
      .getByRole("row", { name: /Big Print Co/ })
      .getByRole("button", { name: /Portal access for Big Print Co/ })
      .click();
    const opsDialog = ops.getByRole("dialog", { name: "Portal access · Big Print Co" });
    await expect(
      opsDialog.getByText("Only an admin can invite people or take access away."),
    ).toBeVisible();
    await expect(opsDialog.getByRole("button", { name: /Invite someone/ })).toHaveCount(0);
    await ops.context().close();
  });
});
