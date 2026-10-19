import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Events per person (Users → Events): someone added with "Only these
 * events: BIRM27" never sees another event — not in the switcher, Events,
 * Approvals, pages, exports, QR, the bell or My Work. The extra event
 * (EA{n}), its sign and the person are made here and removed afterwards.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const code = `EA${n}`;
const ref = `SIG-${code}-001`;
const limName = `Lim ${n}`;
const limEmail = `lim-${n}@ea.test`;

async function as(browser: Browser, email: string, baseURL: string, width = 1280): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width, height: width < 640 ? 844 : 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

const noSideScroll = (page: Page) =>
  page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth);

test.describe.configure({ mode: "serial" });

test.describe("Events per person", () => {
  const sql = postgres(DB, { max: 1, onnotice: () => {} });
  const editionId = randomUUID();
  const itemId = randomUUID();
  let limId = "";

  test.beforeAll(async ({ browser, baseURL }) => {
    const [birm] = await sql`
      select e.event_id, e.venue_id from editions e where e.code = 'BIRM27'`;
    const [olivia] = await sql`select id from users where email = 'ops@media10.test'`;
    await sql`insert into editions (id, event_id, venue_id, name, code, build_start, build_end,
        open_start, open_end, breakdown_end)
      values (${editionId}, ${birm.event_id}, ${birm.venue_id}, ${`Event access ${n}`}, ${code},
        '2031-03-01', '2031-03-03', '2031-03-04', '2031-03-05', '2031-03-06')`;
    await sql`insert into signage_items (id, edition_id, ref, seq, name, created_by, owner_user_id)
      values (${itemId}, ${editionId}, ${ref}, 1, ${`Hidden sign ${n}`}, ${olivia.id}, ${olivia.id})`;

    // Admin adds them through Add one person: Operations, only BIRM27.
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/new`);
    await admin.getByLabel("Full name").fill(limName);
    await admin.getByLabel("Email").fill(limEmail);
    await admin.getByRole("radio", { name: /^Operations Runs/ }).check();
    const events = admin.getByRole("region", { name: "Events" });
    await expect(events).toContainText("All events — including new ones");
    await events.getByRole("button", { name: "Change" }).click();
    await events.getByRole("radio", { name: /^Only these events/ }).check();
    const birm27 = events.getByRole("checkbox", { name: /BIRM27 ·/ });
    const other = events.getByRole("checkbox", { name: new RegExp(`${code} ·`) });
    if (!(await birm27.isChecked())) await birm27.check();
    if (await other.isChecked()) await other.uncheck();
    await admin.getByRole("button", { name: "Send invitation" }).click();
    const inviteUrl = await admin.getByLabel("Invitation link").inputValue();
    expect(inviteUrl).toContain("/invite/");
    await admin.context().close();

    // They accept in a fresh browser; the invitation names their event.
    const pctx = await browser.newContext();
    const p = await pctx.newPage();
    await p.goto(inviteUrl);
    await expect(p.getByText("You’ll work on UKCW Birmingham 2027.")).toBeVisible();
    await p.getByLabel("Choose a password").fill("s3cure-pass");
    await p.getByLabel("Type it again").fill("s3cure-pass");
    await p.getByRole("button", { name: "Create my account" }).click();
    await p.waitForURL("**/my-work");
    await pctx.close();

    const [u] = await sql`select id from users where email = ${limEmail}`;
    limId = u.id as string;
    // As notify() stores it: about the sign, with its event.
    await sql`insert into notifications (user_id, kind, title, link, entity_type, entity_id, edition_id)
      values (${limId}, 'comment', ${`Hidden news ${n}`}, ${`/${code}/signage/${ref}`},
        'signage_item', ${itemId}, ${editionId})`;
    await sql`insert into notifications (user_id, kind, title, link)
      values (${limId}, 'comment', ${`Plain news ${n}`}, '/my-work')`;
    const [org] = await sql`
      select s.organisation_id as id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    await sql`insert into tasks (organisation_id, edition_id, title, assigned_to_user_id, created_by_user_id)
      values (${org.id}, ${editionId}, ${`Hidden task ${n}`}, ${limId}, ${limId}),
             (${org.id}, null, ${`Plain task ${n}`}, ${limId}, ${limId})`;
  });

  test.afterAll(async () => {
    if (limId) {
      await sql`delete from notifications where user_id = ${limId}`;
      await sql`delete from tasks where assigned_to_user_id = ${limId}`;
      await sql`delete from memberships where user_id = ${limId}`;
    }
    await sql`update staff_invites set revoked_at = now()
      where invited_email = ${limEmail} and accepted_at is null and revoked_at is null`;
    await sql`delete from tasks where edition_id = ${editionId}`;
    await sql`delete from signage_items where edition_id = ${editionId}`;
    await sql`delete from edition_counters where edition_id = ${editionId}`;
    await sql`delete from edition_deadlines where edition_id = ${editionId}`;
    // The notifications.edition_id link clears rather than blocks.
    await sql`delete from editions where id = ${editionId}`;
    await sql.end();
  });

  test("1. the switcher, Events and Approvals' event filter list only BIRM27", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, limEmail, baseURL!);
    await page.goto(`${baseURL}/my-work`);
    await page.getByRole("button", { name: /^Event: |^Choose event$/ }).click();
    const menu = page.getByRole("menu");
    await expect(menu.locator("[data-code='BIRM27']")).toBeVisible();
    await expect(menu.locator(`[data-code='${code}']`)).toHaveCount(0);
    await page.keyboard.press("Escape");

    await page.goto(`${baseURL}/events`);
    await expect(page.getByRole("main")).toContainText("BIRM27");
    await expect(page.getByRole("main")).not.toContainText(code);

    // One event: Approvals has no event filter at all.
    await page.goto(`${baseURL}/approvals`);
    await expect(page.getByRole("combobox", { name: "Event" })).toHaveCount(0);
    await page.context().close();

    // A super admin still has both.
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/approvals`);
    await expect(
      admin.getByRole("combobox", { name: "Event" }).first().locator(`option[value='${code}']`),
    ).toHaveCount(1);
    await admin.context().close();
  });

  test("2. another event's pages, items, exports and QR answer as not found", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, limEmail, baseURL!);
    const notFound =
      "This page doesn't exist, belongs to a different event, or is in an event you haven't been given.";
    await page.goto(`${baseURL}/${code}/dashboard`);
    await expect(page.getByText(notFound)).toBeVisible();
    await page.goto(`${baseURL}/${code}/signage/${ref}`);
    await expect(page.getByText(notFound)).toBeVisible();
    await expect(page.getByText(`Hidden sign ${n}`)).toHaveCount(0);
    const res = await page.request.get(`${baseURL}/api/exports/schedule/${code}`);
    expect(res.status()).toBe(404);
    await page.goto(`${baseURL}/q/${ref}`);
    await expect(
      page.getByText("This reference does not exist or is not shared with you."),
    ).toBeVisible();
    // Their own event still opens.
    await page.goto(`${baseURL}/BIRM27/dashboard`);
    await expect(page.getByText(notFound)).toHaveCount(0);
    await page.context().close();
  });

  test("3. the bell, Notifications and My Work show nothing from the other event", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, limEmail, baseURL!);
    await page.goto(`${baseURL}/notifications`);
    await expect(page.getByText(`Plain news ${n}`)).toBeVisible();
    await expect(page.getByText(`Hidden news ${n}`)).toHaveCount(0);
    const unread = await page.request.get(`${baseURL}/api/notifications/unread`);
    expect(JSON.stringify(await unread.json())).not.toContain(`Hidden news ${n}`);
    await page.goto(`${baseURL}/my-work`);
    await expect(page.getByText(`Plain task ${n}`)).toBeVisible();
    await expect(page.getByText(`Hidden task ${n}`)).toHaveCount(0);
    await page.context().close();
  });

  test("4. the Users list shows 'BIRM27 only', the person page shows the choice, and My account lists their event", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users?q=${encodeURIComponent(limEmail)}`);
    await expect(admin.getByRole("row").filter({ hasText: limEmail })).toContainText("BIRM27 only");
    await admin.goto(`${baseURL}/users/${limId}`);
    const events = admin.getByRole("region", { name: "Events" });
    await expect(events.getByRole("radio", { name: /^Only these events/ })).toBeChecked();
    await expect(events.getByRole("checkbox", { name: /BIRM27 ·/ })).toBeChecked();
    await expect(events.getByRole("checkbox", { name: new RegExp(`${code} ·`) })).not.toBeChecked();
    await admin.context().close();

    const page = await as(browser, limEmail, baseURL!);
    await page.goto(`${baseURL}/account`);
    await expect(page.getByRole("link", { name: "UKCW Birmingham 2027 · BIRM27" })).toBeVisible();
    await expect(
      page.getByText("A super admin or your manager chooses which events you work on."),
    ).toBeVisible();
    await page.context().close();
  });

  test("5. narrowing with work there says what stays, confirms, and saves", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/users/${limId}`);
    const events = admin.getByRole("region", { name: "Events" });
    await events.getByRole("checkbox", { name: new RegExp(`${code} ·`) }).check();
    await admin.getByRole("button", { name: "Save changes" }).click();
    await expect(admin.getByText("Lim's events saved").first()).toBeVisible();

    await sql`update signage_items set owner_user_id = ${limId} where id = ${itemId}`;
    await admin.reload();
    await events.getByRole("checkbox", { name: new RegExp(`${code} ·`) }).uncheck();
    const note = admin.getByRole("note", { name: "What this change leaves behind" });
    await expect(note).toContainText(`Lim won't see ${code} any more.`);
    // The task in that event (made above) and the sign stay theirs.
    await expect(note).toContainText("1 task and 1 item Lim owns there stay with Lim");
    await expect(note).toContainText(ref);
    await admin.getByRole("button", { name: "Save changes" }).click();
    const dialog = admin.getByRole("dialog", { name: `Take ${code} away from Lim?` });
    await expect(dialog).toContainText("Their 1 task and 1 item there stay with them");
    await dialog.getByRole("button", { name: "Take it away" }).click();
    await expect(admin.getByText("Lim's events saved").first()).toBeVisible();
    const [m] = await sql`select edition_ids from memberships where user_id = ${limId}`;
    expect(m.edition_ids).toHaveLength(1);
    const [it] = await sql`select owner_user_id from signage_items where id = ${itemId}`;
    expect(it.owner_user_id).toBe(limId);
    await admin.context().close();
  });

  test("6. copying BIRM27 offers to give the copy to people who only see it", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!);
    await admin.goto(`${baseURL}/start?mode=copy`);
    const from = admin.getByLabel("Copy from");
    const birm = await from.evaluate(
      (el: HTMLSelectElement) =>
        [...el.options].find((o) => o.text.startsWith("UKCW Birmingham 2027 ·"))?.value ?? "",
    );
    await from.selectOption(birm);
    const box = admin.getByRole("checkbox", {
      name: /^People who only see BIRM27 — give them the new event too \(\d+\)$/,
    });
    await expect(box).toBeVisible();
    await expect(box).toBeChecked();
    // Not submitted: no event is left behind.
    await admin.context().close();
  });

  test("7. on a phone the person page and the Add form don't scroll sideways", async ({
    browser,
    baseURL,
  }) => {
    const admin = await as(browser, "admin@media10.test", baseURL!, 390);
    await admin.goto(`${baseURL}/users/${limId}`);
    await expect(admin.getByRole("region", { name: "Events" })).toBeVisible();
    expect(await noSideScroll(admin)).toBe(true);
    await admin.goto(`${baseURL}/users/new`);
    const events = admin.getByRole("region", { name: "Events" });
    await admin.getByRole("radio", { name: /^Operations Runs/ }).check();
    await expect(events).toContainText("All events — including new ones");
    expect(await noSideScroll(admin)).toBe(true);
    await events.getByRole("button", { name: "Change" }).click();
    await events.getByRole("radio", { name: /^Only these events/ }).check();
    await expect(events.getByRole("checkbox", { name: /BIRM27 ·/ })).toBeVisible();
    expect(await noSideScroll(admin)).toBe(true);
    await admin.context().close();
  });
});
