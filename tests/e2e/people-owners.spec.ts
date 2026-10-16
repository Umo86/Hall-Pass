import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Handing work to people: give an item to someone else (on its page and in
 * bulk from the list), see an item owned by a suspended person labelled and
 * give it to someone who can work on it, see who raised and fixed snags on
 * the item and on Onsite, and find people to hand a stand's sign-off to.
 * Items and the suspended person are made in BIRM27 and removed afterwards
 * (audit rows stay: the audit log is append-only).
 */
const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";
const n = String(Date.now()).slice(-6);
const todayLondon = () =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());

let sql: ReturnType<typeof postgres>;
type Made = { id: string; ref: string; name: string };
const made: Made[] = [];
let orgId = "";
let editionId = "";
let hallId = "";
const ids: Record<string, string> = {};
const suspended = { id: randomUUID(), name: `Sid Suspended ${n}` };

async function as(browser: Browser, email: string, baseURL: string, phone = false): Promise<Page> {
  const ctx = await browser.newContext(phone ? { viewport: { width: 390, height: 844 } } : {});
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

async function makeItem(
  label: string,
  values: { owner: string; status?: string; installDate?: string | null },
): Promise<Made> {
  const id = randomUUID();
  const i = made.length;
  const ref = `SIG-BIRM27-P${n}${i}`;
  const name = `People ${label} ${n}`;
  await sql`insert into signage_items
    (id, edition_id, ref, seq, name, kind, category, status, created_by, owner_user_id,
     owner_role, hall_id, install_date, installed_at)
    values (${id}, ${editionId}, ${ref}, ${700000 + Number(n.slice(-4)) * 10 + i}, ${name},
      'signage', 'organiser', ${values.status ?? "draft"}, ${ids.ops}, ${values.owner}, 'ops',
      ${hallId}, ${values.installDate ?? null},
      ${["installed", "snagged"].includes(values.status ?? "") ? new Date() : null})`;
  const item = { id, ref, name };
  made.push(item);
  return item;
}

test.describe.serial("people: owners, snags and delegation", () => {
  test.beforeAll(async () => {
    sql = postgres(DB, { max: 1, onnotice: () => {} });
    const [ed] = await sql`
      select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    orgId = ed.organisation_id;
    editionId = ed.id;
    const [hall] = await sql`select id from halls where edition_id = ${ed.id} and name = 'Hall 1'`;
    hallId = hall.id;
    for (const key of ["ops", "marketing"]) {
      const [u] = await sql`select id from users where email = ${`${key}@media10.test`}`;
      ids[key] = u.id;
    }
    // Someone on the team whose access is paused.
    await sql`insert into users (id, email, full_name)
      values (${suspended.id}, ${`sid-${n}@people.test`}, ${suspended.name})`;
    await sql`insert into memberships (user_id, organisation_id, role, suspended_at)
      values (${suspended.id}, ${orgId}, 'marketing', now())`;
  });

  test.afterAll(async () => {
    const itemIds = made.map((m) => m.id);
    if (itemIds.length) {
      await sql`delete from snags where signage_item_id = any(${itemIds}::uuid[])`;
      await sql`update signage_items set deleted_at = now() where id = any(${itemIds}::uuid[])`;
    }
    await sql`delete from memberships where user_id = ${suspended.id}`;
    await sql.end();
  });

  test("give an item to someone else from its page", async ({ browser, baseURL }) => {
    const item = await makeItem("single", { owner: ids.ops });
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`/BIRM27/signage/${item.ref}?tab=details&edit=1#ownerUserId`);
    const owner = ops.getByLabel("Owner", { exact: true });
    await expect(owner).toHaveValue(ids.ops);
    // People are grouped by department, "Me" first; viewers and Sales aren't offered.
    await expect(owner.locator("option").first()).toHaveText("Me (Olivia Ops)");
    await expect(owner.locator("option", { hasText: "Vic Viewer" })).toHaveCount(0);
    await expect(owner.locator("option", { hasText: "Sara Sales" })).toHaveCount(0);
    await owner.selectOption({ label: "Marcus Marketing" });
    await ops.getByRole("button", { name: "Save changes" }).click();
    await expect(ops.getByText(`${item.ref} saved`)).toBeVisible();
    await expect
      .poll(
        async () =>
          (await sql`select owner_user_id from signage_items where id = ${item.id}`)[0]
            .owner_user_id,
      )
      .toBe(ids.marketing);
    await expect(ops.getByText("Marcus Marketing · Marketing")).toBeVisible();
    // Marcus is told it is his.
    const [note] = await sql`select title from notifications
      where user_id = ${ids.marketing} and entity_id = ${item.id} and kind = 'item_assigned'`;
    expect(note.title).toBe(`Olivia Ops gave you ${item.ref} — ${item.name}`);
    await ops.context().close();
  });

  test("give several items to someone at once from the list", async ({ browser, baseURL }) => {
    const a = await makeItem("bulk A", { owner: ids.ops });
    const b = await makeItem("bulk B", { owner: ids.ops });
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`/BIRM27/signage?q=${encodeURIComponent(`People bulk`)}`);
    await ops.getByLabel(`Select ${a.ref}`).check();
    await ops.getByLabel(`Select ${b.ref}`).check();
    const bar = ops.getByRole("region", { name: "Selected items" });
    await bar.getByRole("button", { name: "More" }).click();
    await ops.getByRole("menuitem", { name: "Change owner" }).click();
    const dialog = ops.getByRole("dialog");
    await dialog.getByLabel("New owner").selectOption({ label: "Marcus Marketing" });
    await dialog.getByRole("button", { name: "Give 2 items to Marcus Marketing" }).click();
    await expect(ops.getByText("2 items given to Marcus Marketing").first()).toBeVisible();
    const rows = await sql`select owner_user_id from signage_items where id in (${a.id}, ${b.id})`;
    expect(rows.map((r) => r.owner_user_id)).toEqual([ids.marketing, ids.marketing]);
    await ops.context().close();
  });

  test("an item owned by a suspended person says so and can be given to someone else", async ({
    browser,
    baseURL,
  }) => {
    const item = await makeItem("orphan", { owner: suspended.id });
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto(`/BIRM27/signage/${item.ref}`);
    const glance = ops.getByRole("region", { name: "At a glance" });
    await expect(glance.getByText(suspended.name)).toBeVisible();
    await expect(glance.getByText("(Suspended)")).toBeVisible();
    await glance.getByRole("link", { name: "Change" }).click();
    const owner = ops.getByLabel("Owner", { exact: true });
    // The current owner stays listed, labelled, so saving never swaps them silently.
    await expect(owner).toHaveValue(suspended.id);
    await expect(owner.locator("option:checked")).toHaveText(`${suspended.name} (Suspended)`);
    await expect(
      ops.getByText(`${suspended.name} can't own this item now (suspended)`),
    ).toBeVisible();
    await owner.selectOption({ label: "Me (Olivia Ops)" });
    await ops.getByRole("button", { name: "Save changes" }).click();
    await expect(ops.getByText(`${item.ref} saved`)).toBeVisible();
    await expect(glance.getByText("(Suspended)")).toHaveCount(0);
    await expect(glance.getByText("Olivia Ops · Operations")).toBeVisible();
    await ops.context().close();
  });

  test("who raised and who fixed a snag, on the item and on Onsite", async ({
    browser,
    baseURL,
  }) => {
    const item = await makeItem("snagged", {
      owner: ids.ops,
      status: "snagged",
      installDate: todayLondon(),
    });
    await sql`insert into snags (edition_id, signage_item_id, description, severity, raised_by_user_id)
      values (${editionId}, ${item.id}, ${`Torn corner ${n}`}, 'medium', ${ids.marketing})`;
    await sql`insert into snags (edition_id, signage_item_id, description, severity,
        raised_by_user_id, status, resolved_at, resolved_by)
      values (${editionId}, ${item.id}, ${`Wrong panel ${n}`}, 'low', ${ids.marketing},
        'resolved', now(), ${ids.ops})`;
    const phone = await as(browser, "ops@media10.test", baseURL!, true);
    await phone.goto(`/BIRM27/onsite?view=todo&q=${encodeURIComponent(item.name)}`);
    const card = phone.getByRole("article", { name: `${item.ref} ${item.name}` });
    await expect(card.getByText(`Torn corner ${n}`)).toBeVisible();
    await expect(card.getByText(/Raised by Marcus Marketing · /)).toBeVisible();
    await phone.goto(`/BIRM27/signage/${item.ref}`);
    const snags = phone.getByRole("region", { name: "Snags" });
    await expect(
      snags.getByText(/Raised by Marcus Marketing · .*Fixed by Olivia Ops · /),
    ).toBeVisible();
    await phone.context().close();
  });

  test("a stand's Delegate lists the people who can sign", async ({ browser, baseURL }) => {
    const ops = await as(browser, "ops@media10.test", baseURL!);
    await ops.goto("/BIRM27/stands/STD-BIRM27-A20?tab=signoff");
    await ops.getByRole("button", { name: "Delegate" }).first().click();
    const dialog = ops.getByRole("dialog");
    const pick = dialog.getByLabel("Delegate to");
    await expect(pick.locator("option", { hasText: "Marcus Marketing" })).toHaveCount(1);
    await expect(pick.locator("optgroup")).not.toHaveCount(0);
    // Nobody suspended, nobody who can't sign.
    await expect(pick.locator("option", { hasText: suspended.name })).toHaveCount(0);
    await expect(pick.locator("option", { hasText: "Vic Viewer" })).toHaveCount(0);
    await ops.keyboard.press("Escape");
    // And a task can be added about the stand.
    await expect(ops.getByRole("button", { name: "Add task" })).toBeVisible();
    await ops.context().close();
  });
});
