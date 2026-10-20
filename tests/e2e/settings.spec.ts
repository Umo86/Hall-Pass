import { randomUUID } from "node:crypto";
import { expect, test, type Browser } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Settings: a list of sections (a rail on wider screens), old ?tab= links
 * sent on, organisation rules, item types in two groups, venues with
 * archive, the org-wide recycle bin and the plain-language System page.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const stamp = () => String(Date.now()).slice(-7);

async function as(browser: Browser, email: string, baseURL: string, width = 1280) {
  const ctx = await browser.newContext({ viewport: { width, height: 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

test.describe("settings", () => {
  test("sections by permission, the rail, and old links sent on", async ({ browser, baseURL }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/settings`);
    const main = admin.getByRole("main");
    for (const label of ["Organisation", "Item types", "Venues", "Recycle bin", "System"]) {
      await expect(main.getByRole("link", { name: new RegExp(`^${label}`) })).toBeVisible();
    }
    // Inside a section the others are a rail, with the current one marked.
    await main.getByRole("link", { name: /^Item types/ }).click();
    await expect(admin).toHaveURL(/\/settings\/item-types$/);
    const rail = admin.getByRole("navigation", { name: "Settings sections" });
    await expect(rail.getByRole("link", { name: /^Item types/ })).toHaveAttribute(
      "aria-current",
      "page",
    );
    await rail.getByRole("link", { name: /^System/ }).click();
    await expect(admin.getByRole("heading", { name: "System", exact: true })).toBeVisible();

    for (const [tab, to] of [
      ["general", /\/account$/],
      ["team", /\/users$/],
      ["signoff", /\/users\?tab=departments$/],
      ["types", /\/settings\/item-types$/],
      ["services", /\/suppliers\?manage=services$/],
      ["venues", /\/settings\/venues$/],
      ["deleted", /\/settings\/recycle-bin$/],
      ["storage", /\/settings\/system$/],
    ] as const) {
      await admin.goto(`${baseURL}/settings?tab=${tab}`);
      await expect(admin, tab).toHaveURL(to);
    }
    await admin.context().close();

    // Operations: everything but System, which says who can open it.
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`${baseURL}/settings`);
    await expect(ops.getByRole("main").getByRole("link", { name: /^Venues/ })).toBeVisible();
    await expect(ops.getByRole("main").getByRole("link", { name: /^System/ })).toHaveCount(0);
    await ops.goto(`${baseURL}/settings/system`);
    await expect(ops.getByText("Only super admins can open System")).toBeVisible();
    await ops.context().close();

    // Everyone else is pointed at My account and Users.
    const viewer = await as(browser, "viewer@media10.test", baseURL!);
    await viewer.goto(`${baseURL}/settings`);
    await expect(
      viewer.getByText(/Settings are looked after by super admins and the people they choose/),
    ).toBeVisible();
    await viewer.goto(`${baseURL}/settings/venues`);
    await expect(
      viewer.getByText("You need “Manage lists” for that — ask a super admin"),
    ).toBeVisible();
    await viewer.context().close();
  });

  test("on a phone Settings is a list of rows with a way back", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!, 390);
    await page.goto(`${baseURL}/settings`);
    await page
      .getByRole("main")
      .getByRole("link", { name: /^Recycle bin/ })
      .click();
    await expect(page.getByRole("heading", { name: "Recycle bin" })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "Settings sections" })).toBeHidden();
    await page.getByRole("main").getByRole("link", { name: "Settings", exact: true }).click();
    await expect(page).toHaveURL(/\/settings$/);
    // Nothing in the page itself is wider than the phone (the app header is checked elsewhere).
    const widest = await page
      .getByRole("main")
      .evaluate((main) =>
        Math.max(...[...main.querySelectorAll("*")].map((e) => e.getBoundingClientRect().right)),
      );
    expect(widest).toBeLessThanOrEqual(390);
    await page.context().close();
  });

  test("Operations change when overdue sign-offs are chased", async ({ browser, baseURL }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    await page.goto(`${baseURL}/settings/organisation`);
    const days = page.getByLabel("Chase overdue sign-offs after");
    const before = await days.inputValue();
    const next = before === "3" ? "4" : "3";
    const save = page.getByRole("button", { name: "Save changes" });
    await expect(save).toBeDisabled();
    await days.fill(next);
    await save.click();
    await expect(page.getByText(/Settings for .+ saved/)).toBeVisible();
    await page.reload();
    await expect(page.getByLabel("Chase overdue sign-offs after")).toHaveValue(next);
    // Put it back.
    await page.getByLabel("Chase overdue sign-offs after").fill(before);
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByRole("button", { name: "Save changes" })).toBeDisabled();
    await page.context().close();
  });

  test("item types come in two groups, each with its own Add, and archive", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "admin@media10.test", baseURL!);
    const n = stamp();
    await page.goto(`${baseURL}/settings/item-types`);
    const signage = page.getByRole("region", { name: "Signage" });
    const sponsorship = page.getByRole("region", { name: "Sponsorship items" });

    await signage.getByRole("button", { name: "Add signage type" }).click();
    let dialog = page.getByRole("dialog", { name: "Add a signage type" });
    await expect(dialog.getByLabel("Used for")).toHaveCount(0);
    await dialog.getByLabel("Name").fill(`E2E Totem ${n}`);
    await dialog.getByLabel("Digital").check();
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = signage.getByRole("listitem").filter({ hasText: `E2E Totem ${n}` });
    await expect(row.getByText(/^Digital · 0 items$/)).toBeVisible();

    await sponsorship.getByRole("button", { name: "Add sponsorship item type" }).click();
    dialog = page.getByRole("dialog", { name: "Add a sponsorship item type" });
    await dialog.getByLabel("Name").fill(`E2E Lanyard ${n}`);
    await expect(dialog.getByText("Print or digital")).toHaveCount(0);
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(sponsorship.getByText(`E2E Lanyard ${n}`)).toBeVisible();

    // Archive asks first, then moves it under Archived; Restore brings it back.
    await row.getByRole("button", { name: `Archive E2E Totem ${n}` }).click();
    await page
      .getByRole("dialog", { name: `Archive E2E Totem ${n}?` })
      .getByRole("button", { name: "Archive" })
      .click();
    await expect(signage.getByRole("button", { name: `Archive E2E Totem ${n}` })).toHaveCount(0);
    await signage.getByText(/^Archived \(\d+\)$/).click();
    await signage.getByRole("button", { name: `Restore E2E Totem ${n}` }).click();
    await expect(signage.getByRole("button", { name: `Archive E2E Totem ${n}` })).toBeVisible();

    // Tidy up.
    for (const name of [`E2E Totem ${n}`, `E2E Lanyard ${n}`]) {
      await page.getByRole("button", { name: `Archive ${name}` }).click();
      await page
        .getByRole("dialog", { name: `Archive ${name}?` })
        .getByRole("button", { name: "Archive" })
        .click();
      await expect(page.getByRole("button", { name: `Archive ${name}` })).toHaveCount(0);
    }
    await page.context().close();
  });

  test("venues need no code, can be archived and drop out of New event", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "ops@media10.test", baseURL!);
    const name = `E2E Arena ${stamp()}`;
    await page.goto(`${baseURL}/settings/venues`);
    await page.getByRole("button", { name: "Add venue" }).first().click();
    const dialog = page.getByRole("dialog", { name: "Add a venue" });
    await expect(dialog.getByLabel(/code/i)).toHaveCount(0);
    await dialog.getByLabel("Venue name").fill(name);
    await dialog.getByLabel("Address (optional)").fill("1 Arena Way, Testville");
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(dialog).toHaveCount(0);
    const row = page.getByRole("main").getByRole("row", { name: new RegExp(name) });
    await expect(row.getByText("1 Arena Way, Testville")).toBeVisible();
    await expect(row.getByText("No events yet")).toBeVisible();

    await page.goto(`${baseURL}/start?mode=fresh`);
    await expect(
      page.getByLabel("Venue", { exact: true }).locator("option", { hasText: name }),
    ).toHaveCount(1);

    await page.goto(`${baseURL}/settings/venues`);
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
    await expect(page.getByRole("button", { name: `Restore ${name}` })).toBeVisible();

    await page.goto(`${baseURL}/start?mode=fresh`);
    await expect(
      page.getByLabel("Venue", { exact: true }).locator("option", { hasText: name }),
    ).toHaveCount(0);
    await page.context().close();
  });

  test("a venue shows who from it can sign in", async ({ browser, baseURL }) => {
    const page = await as(browser, "admin@media10.test", baseURL!);
    await page.goto(`${baseURL}/settings/venues`);
    const row = page.getByRole("main").getByRole("row", { name: /NEC Birmingham/ });
    await row.getByRole("button", { name: /Portal access for NEC Birmingham/ }).click();
    const dialog = page.getByRole("dialog", { name: "Portal access · NEC Birmingham" });
    await expect(dialog.getByText("venue@nec.test").first()).toBeVisible();
    await dialog.getByRole("button", { name: "Invite someone from NEC Birmingham" }).click();
    // Only events at this venue, the current one first.
    const event = dialog.getByLabel("Event");
    await expect(event.locator("option:checked")).toHaveText(/UKCW Birmingham 2027/);
    await page.context().close();
  });

  test("the recycle bin lists every event's deleted items and restores them", async ({
    browser,
    baseURL,
  }) => {
    const sql = postgres(DB, { max: 1, onnotice: () => {} });
    const n = stamp();
    const id = randomUUID();
    const ref = `SIG-BIRM27-R${n}`;
    const [ed] = await sql`select id from editions where code = 'BIRM27'`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
    await sql`insert into signage_items (id, edition_id, ref, seq, name, created_by, deleted_at)
      values (${id}, ${ed.id}, ${ref}, ${800000 + Number(n.slice(-5))}, ${`E2E binned ${n}`},
        ${ops.id}, now())`;
    try {
      const page = await as(browser, "ops@media10.test", baseURL!);
      await page.goto(`${baseURL}/settings/recycle-bin`);
      await page.getByLabel("Show deleted items from").selectOption("BIRM27");
      await expect(page).toHaveURL(/event=BIRM27/);
      await expect(
        page.getByRole("link", { name: "Open BIRM27’s Recently deleted" }),
      ).toHaveAttribute("href", "/BIRM27/signage/deleted");
      const row = page.getByRole("main").getByRole("row", { name: new RegExp(ref) });
      await expect(row.getByRole("link", { name: "BIRM27" })).toHaveAttribute(
        "href",
        "/BIRM27/signage/deleted",
      );
      await row.getByRole("button", { name: `Restore ${ref}` }).click();
      await expect(row).toHaveCount(0);
      await page.context().close();
    } finally {
      await sql`delete from approval_instances where entity_id = ${id}`;
      await sql`delete from notifications where entity_id = ${id}`;
      await sql`delete from signage_items where id = ${id}`;
      await sql.end();
    }
  });

  test("System says in plain words whether files and email are safe", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, "admin@media10.test", baseURL!);
    await page.goto(`${baseURL}/settings/system`);
    const storage = page.getByRole("region", { name: "File storage" });
    await expect(
      storage.getByText(
        /Files are stored safely|File storage isn't working|Uploaded files will be lost|Files are saved on this computer/,
      ),
    ).toBeVisible();
    await expect(
      page.getByRole("region", { name: "Email" }).getByText(/Email is working|Email is off/),
    ).toBeVisible();
    // Where the data is: here, the local database the app connected to.
    const database = page.getByRole("region", { name: "Database" });
    await expect(database.getByText("Your data is stored safely")).toBeVisible();
    await expect(database.getByText("In a database on this computer.")).toBeVisible();
    // The detail is there but folded away unless something is wrong.
    await page.getByText("Technical details").click();
    await expect(page.getByText("New files go to")).toBeVisible();
    await expect(page.getByText("DATABASE_URL (the first variable that answers)")).toBeVisible();
    await expect(page.getByText(/^Up to date \(0014_better_auth\)$/)).toBeVisible();
    await page.context().close();
  });
});
