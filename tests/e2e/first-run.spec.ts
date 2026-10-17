import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * A brand-new organisation: one admin and one marketing person, no events.
 * Made straight in the database (as a starter seed would) and removed again
 * afterwards; audit rows stay, as the audit log is append-only.
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const org = { id: randomUUID(), name: `First Run ${n}` };
const admin = { id: randomUUID(), email: `fran-${n}@firstrun.test`, name: "Fran First" };
const staff = { id: randomUUID(), email: `sam-${n}@firstrun.test`, name: "Sam Staff" };
const code = `FR${n}`;
const eventName = `First Run Expo ${n}`;

let sql: ReturnType<typeof postgres>;

/** Open a checklist step (it may already be open). */
async function openStep(page: Page, title: RegExp) {
  const step = page.getByRole("button", { name: title });
  if ((await step.getAttribute("aria-expanded")) !== "true") await step.click();
  await expect(step).toHaveAttribute("aria-expanded", "true");
}

async function as(browser: Browser, email: string, baseURL: string) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

test.describe.serial("first run: create an event, then get it ready", () => {
  test.beforeAll(async () => {
    sql = postgres(DB, { max: 1, onnotice: () => {} });
    await sql`insert into organisations (id, name, slug) values (${org.id}, ${org.name}, ${`first-run-${n}`})`;
    await sql`insert into users (id, email, full_name) values
      (${admin.id}, ${admin.email}, ${admin.name}),
      (${staff.id}, ${staff.email}, ${staff.name})`;
    await sql`insert into memberships (user_id, organisation_id, role) values
      (${admin.id}, ${org.id}, 'admin'),
      (${staff.id}, ${org.id}, 'marketing')`;
  });

  test.afterAll(async () => {
    const editions = sql`select e.id from editions e join events s on s.id = e.event_id where s.organisation_id = ${org.id}`;
    const steps = [
      sql`delete from edition_deadlines where edition_id in (${editions})`,
      sql`delete from edition_counters where edition_id in (${editions})`,
      sql`delete from locations where hall_id in (select id from halls where edition_id in (${editions}))`,
      sql`delete from halls where edition_id in (${editions})`,
      sql`delete from signage_items where edition_id in (${editions})`,
      sql`delete from external_grants where organisation_id = ${org.id}`,
      sql`delete from editions where id in (${editions})`,
      sql`delete from events where organisation_id = ${org.id}`,
      sql`delete from venues where organisation_id = ${org.id}`,
      sql`delete from workflow_steps where workflow_id in (select id from workflows where organisation_id = ${org.id})`,
      sql`delete from workflows where organisation_id = ${org.id}`,
      sql`delete from approvers where organisation_id = ${org.id}`,
      sql`delete from departments where organisation_id = ${org.id}`,
      sql`delete from item_types where organisation_id = ${org.id}`,
      sql`delete from staff_invites where organisation_id = ${org.id}`,
      sql`delete from notifications where user_id in (${admin.id}, ${staff.id})`,
      sql`delete from memberships where organisation_id = ${org.id}`,
      sql`delete from users where id in (${admin.id}, ${staff.id})`,
      sql`delete from organisations where id = ${org.id}`,
    ];
    // One at a time, in order; anything a constraint keeps is left in place.
    for (const step of steps) await step.catch(() => {});
    await sql.end();
  });

  test("before there's an event, other staff are told who to ask", async ({ browser, baseURL }) => {
    const page = await as(browser, staff.email, baseURL!);
    await page.goto(`${baseURL}/my-work`);
    await expect(page).toHaveURL(/\/my-work$/);
    await expect(page.getByRole("heading", { name: "Nothing set up yet" })).toBeVisible();
    await expect(page.getByRole("link", { name: admin.name })).toHaveAttribute(
      "href",
      `mailto:${admin.email}`,
    );
    // The Events list and /start say the same.
    await page.goto(`${baseURL}/events`);
    await expect(page.getByRole("heading", { name: "Nothing set up yet" })).toBeVisible();
    await page.goto(`${baseURL}/start`);
    await expect(page.getByRole("heading", { name: "Nothing set up yet" })).toBeVisible();
    await page.context().close();
  });

  test("the admin lands on Create your event and gets it ready step by step", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, admin.email, baseURL!);
    await page.goto(`${baseURL}/my-work`, { waitUntil: "networkidle" });
    await page.waitForURL(/\/start$/);
    await expect(page.getByRole("heading", { name: "Create your event" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Create your event" })).toBeVisible();
    // Nothing to copy yet, so no "Copy a previous event".
    await expect(page.getByRole("button", { name: "Copy a previous event" })).toHaveCount(0);

    // The four basics (plus the new venue's name).
    await page.getByLabel("Event name").fill(eventName);
    await page.getByLabel("Opens to visitors").fill("2027-05-04");
    await expect(page.getByLabel("Closes to visitors")).toHaveValue("2027-05-04");
    await page.getByLabel("Closes to visitors").fill("2027-05-06");
    await expect(
      page.getByText(/assumed build-up 2–3 May and breakdown ending 7 May/),
    ).toBeVisible();
    await page.getByLabel("Venue", { exact: true }).selectOption("new");
    await page.getByLabel("Venue name").fill(`First Run Arena ${n}`);
    await page.getByRole("button", { name: "Change" }).click();
    await page.getByLabel("Reference code").fill(code);
    await expect(page.getByText(`SIG-${code}-001`).first()).toBeVisible();
    await page.getByRole("button", { name: "Create event" }).click();

    // Straight to the checklist, with the first step open.
    await page.waitForURL(`**/${code}/setup`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { name: `Get ${eventName} ready` })).toBeVisible();
    await expect(page.getByText("0 of 6 essentials done")).toBeVisible();
    const details = page.getByRole("button", { name: /^1\. Dates, venue and budget\s*, To do/ });
    await expect(details).toHaveAttribute("aria-expanded", "true");
    const nav = page.getByRole("navigation", { name: "Main navigation" });
    await expect(nav.getByRole("link", { name: /Setup\s*0\/6/ })).toBeVisible();

    // Deadline dates follow build-up start as it's typed.
    await openStep(page, /^3\. Deadlines/);
    const artwork = page.getByRole("row", { name: /Artwork due/ });
    await expect(artwork).toContainText("11 Apr 2027");
    await page.getByLabel("Build-up starts").fill("2027-05-01");
    await expect(artwork).toContainText("10 Apr 2027");

    // Step 1 saved: one essential done, and the next step opens.
    await page.getByRole("button", { name: "Save and continue" }).click();
    await expect(page.getByText("Details saved")).toBeVisible();
    await expect(page.getByText("1 of 6 essentials done")).toBeVisible();
    await expect(
      page.getByRole("button", { name: /^1\. Dates, venue and budget\s*, Done/ }),
    ).toBeVisible();

    // Deadlines confirmed.
    await page.getByRole("button", { name: "These look right" }).click();
    await expect(page.getByText("2 of 6 essentials done")).toBeVisible();

    // Halls and locations, several at once.
    await openStep(page, /^2\. Halls and locations/);
    await page
      .getByLabel("Add several at once")
      .fill("Hall 1: Main entrance, Registration\nHall 2: Seminar theatre");
    await page.getByRole("button", { name: "Add 2 halls and 3 locations" }).click();
    await expect(page.getByText("3 of 6 essentials done")).toBeVisible();
    await expect(page.getByRole("heading", { name: "Hall 2" })).toBeVisible();

    // The side navigation keeps count.
    await expect(nav.getByRole("link", { name: /Setup\s*3\/6/ })).toBeVisible();

    // Who signs off is an admin's job in Users.
    await openStep(page, /^4\. Who signs off/);
    await expect(page.getByRole("link", { name: "Set up in Users → Departments" })).toHaveAttribute(
      "href",
      "/users?tab=departments",
    );

    // Nobody is sent back to /start once an event exists.
    await page.goto(`${baseURL}/my-work`);
    await expect(page).toHaveURL(/\/my-work$/);
    await page.context().close();
  });

  test("a second event at the same venue starts its halls from the first", async ({
    browser,
    baseURL,
  }) => {
    const page = await as(browser, admin.email, baseURL!);
    await page.goto(`${baseURL}/start`, { waitUntil: "networkidle" });
    // With an event to copy, copying is offered first.
    await expect(page.getByRole("button", { name: "Copy a previous event" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await page.getByRole("button", { name: "Start fresh" }).click();
    await page.getByLabel("Event name").fill(`${eventName} Winter`);
    await page.getByLabel("Opens to visitors").fill("2027-11-02");
    await expect(page.getByLabel("Venue", { exact: true })).toHaveValue(/.+/); // the only venue
    await page.getByRole("button", { name: "Change" }).click();
    await page.getByLabel("Reference code").fill(`${code}W`);
    await page.getByRole("button", { name: "Create event" }).click();
    await page.waitForURL(`**/${code}W/setup`);
    await page.waitForLoadState("networkidle");

    await openStep(page, /^2\. Halls and locations/);
    await expect(
      page.getByLabel(`Copy halls & locations from a previous event at First Run Arena ${n}`),
    ).toHaveValue(/.+/);
    await page.getByRole("button", { name: "Copy", exact: true }).click();
    await expect(page.getByText(/Copied 2 halls and 3 locations/)).toBeVisible();
    await expect(
      page.getByRole("button", { name: /^2\. Halls and locations\s*, Done/ }),
    ).toBeVisible();
    await page.context().close();
  });

  test("staff can follow setup but not change it", async ({ browser, baseURL }) => {
    const page = await as(browser, staff.email, baseURL!);
    await page.goto(`${baseURL}/${code}/setup`);
    await expect(page.getByRole("heading", { name: `Get ${eventName} ready` })).toBeVisible();
    await expect(page.getByText("People who set up events finish these steps")).toBeVisible();
    await expect(page.getByRole("button", { name: "Save and continue" })).toHaveCount(0);
    await page.goto(`${baseURL}/my-work`);
    await expect(page.getByRole("heading", { name: "Nothing set up yet" })).toHaveCount(0);
    await page.context().close();
  });
});
