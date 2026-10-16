import { randomUUID } from "node:crypto";
import { expect, test, type Browser, type Page } from "@playwright/test";
import postgres from "postgres";
import { signInAs } from "./helpers";

/*
 * Onsite on a phone: confirm a delivery from the card, mark a snag fixed,
 * close what's done (with Undo), receive a sponsorship delivery, report
 * damage on arrival, and be told which earlier step is still open. The
 * items are made straight in the database in BIRM27 and removed afterwards;
 * audit rows stay, as the audit log is append-only.
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
const made: Record<string, Made> = {};

async function phone(browser: Browser, email: string, baseURL: string): Promise<Page> {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  await signInAs(ctx, email, baseURL);
  return ctx.newPage();
}

test.describe.serial("onsite", () => {
  test.beforeAll(async () => {
    sql = postgres(DB, { max: 1, onnotice: () => {} });
    const [ed] = await sql`
      select e.id, s.organisation_id from editions e join events s on s.id = e.event_id
      where e.code = 'BIRM27'`;
    const steps = await sql`
      select ws.id, ws.name, ws.sort_order from workflow_steps ws
      join workflows w on w.id = ws.workflow_id
      where w.organisation_id = ${ed.organisation_id} and w.applies_to = 'signage'
        and w.is_default = true and w.is_archived = false
        and ws.name in ('Sent to print', 'Delivered', 'Installed')`;
    const step = (name: string) => steps.find((s) => s.name === name)!;
    const [supplier] = await sql`
      select id from suppliers where organisation_id = ${ed.organisation_id} limit 1`;
    const [hall] = await sql`select id from halls where edition_id = ${ed.id} and name = 'Hall 1'`;
    const [ops] = await sql`select id from users where email = 'ops@media10.test'`;
    const today = todayLondon();

    const make = async (
      key: string,
      label: string,
      opts: {
        kind?: string;
        status: string;
        /** Confirmation steps in order, with their state. */
        confirmations: [string, "pending" | "waiting" | "confirmed"][];
      },
    ) => {
      const id = randomUUID();
      const i = Object.keys(made).length;
      const ref = `SIG-BIRM27-O${n}${i}`;
      const name = `Onsite ${label} ${n}`;
      await sql`insert into signage_items
        (id, edition_id, ref, seq, name, kind, status, current_run_number, created_by,
         supplier_id, hall_id, install_date, installed_at)
        values (${id}, ${ed.id}, ${ref}, ${800000 + Number(n.slice(-4)) * 10 + i}, ${name},
          ${opts.kind ?? "signage"}, ${opts.status}, 1, ${ops.id}, ${supplier?.id ?? null},
          ${opts.kind === "sponsorship_item" ? null : hall.id}, ${today},
          ${["installed", "snagged"].includes(opts.status) ? new Date() : null})`;
      for (const [stepName, status] of opts.confirmations) {
        const s = step(stepName);
        await sql`insert into approval_instances
          (entity_type, entity_id, run_number, workflow_step_id, step_name_snapshot,
           step_kind_snapshot, sort_order_snapshot, status, assigned_role, pending_since,
           decided_at, decided_by)
          values ('signage_item', ${id}, 1, ${s.id}, ${stepName}, 'confirmation', ${s.sort_order},
            ${status}, ${stepName === "Installed" ? "ops" : "supplier"},
            ${status === "pending" ? new Date() : null},
            ${status === "confirmed" ? new Date() : null},
            ${status === "confirmed" ? ops.id : null})`;
      }
      made[key] = { id, ref, name };
      return id;
    };
    await make("deliver", "banner", {
      status: "in_production",
      confirmations: [
        ["Sent to print", "confirmed"],
        ["Delivered", "pending"],
        ["Installed", "waiting"],
      ],
    });
    const snagged = await make("snagged", "totem", {
      status: "snagged",
      confirmations: [
        ["Sent to print", "confirmed"],
        ["Delivered", "confirmed"],
        ["Installed", "confirmed"],
      ],
    });
    await sql`insert into snags (edition_id, signage_item_id, description, severity)
      values (${ed.id}, ${snagged}, ${`Edge peeling ${n}`}, 'medium')`;
    await make("ready", "flag", {
      status: "installed",
      confirmations: [
        ["Sent to print", "confirmed"],
        ["Delivered", "confirmed"],
        ["Installed", "confirmed"],
      ],
    });
    await make("bags", "show bags", {
      kind: "sponsorship_item",
      status: "in_production",
      confirmations: [
        ["Sent to print", "confirmed"],
        ["Delivered", "pending"],
        ["Installed", "waiting"],
      ],
    });
    await make("damaged", "board", {
      status: "delivered",
      confirmations: [
        ["Sent to print", "confirmed"],
        ["Delivered", "confirmed"],
        ["Installed", "pending"],
      ],
    });
    await make("stale", "arch", {
      status: "delivered",
      confirmations: [
        ["Sent to print", "pending"],
        ["Delivered", "waiting"],
        ["Installed", "waiting"],
      ],
    });
  });

  test.afterAll(async () => {
    const ids = Object.values(made).map((m) => m.id);
    if (ids.length) {
      await sql`delete from snags where signage_item_id = any(${ids}::uuid[])`;
      await sql`delete from reminder_log where target_id in
        (select id from approval_instances where entity_id = any(${ids}::uuid[]))`;
      await sql`delete from approval_instances where entity_id = any(${ids}::uuid[])`;
      await sql`delete from notifications where entity_id = any(${ids}::uuid[])`;
      await sql`delete from signage_items where id = any(${ids}::uuid[])`;
    }
    await sql?.end();
  });

  test("ops works the floor from a phone", async ({ browser, baseURL }) => {
    test.setTimeout(150_000);
    const page = await phone(browser, "ops@media10.test", baseURL!);
    const main = page.getByRole("main");
    const card = (key: string) => main.locator("article", { hasText: made[key].ref });

    await page.goto(`${baseURL}/BIRM27/onsite`);
    await expect(page.getByRole("heading", { name: "Onsite", exact: true })).toBeVisible();
    // One control for the view, 44px tall, and its choice in the address.
    const todo = page.getByRole("button", { name: "All to do" });
    expect((await todo.boundingBox())!.height).toBeGreaterThanOrEqual(44);
    await todo.click();
    await expect(page).toHaveURL(/view=todo/);
    await expect(todo).toHaveAttribute("aria-pressed", "true");
    // Headings pin under the app header with a solid background.
    const heading = main.getByRole("heading", { name: /^Ready to close/ });
    await expect(heading).toBeVisible();
    expect(
      await heading.evaluate((h) => {
        const s = getComputedStyle(h);
        return [s.position, s.top];
      }),
    ).toEqual(["sticky", "56px"]);

    // Find by name or ref: just this run's items.
    await page.getByLabel("Find ref or name").fill(n);
    await expect(main.getByText(/6 matches for/)).toBeVisible();

    // Delivered ✓ from the card, then Installed ✓ is next.
    await card("deliver").getByRole("button", { name: "Delivered ✓" }).click();
    let dialog = page.getByRole("dialog");
    await dialog.getByRole("button", { name: "Confirm", exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(card("deliver").getByRole("button", { name: "Installed ✓" })).toBeVisible();

    // The snag is listed on its card and fixed from there.
    const snagged = card("snagged");
    await expect(snagged.getByText(`Edge peeling ${n}`)).toBeVisible();
    await snagged.getByRole("button", { name: "Fixed ✓" }).click();
    dialog = page.getByRole("dialog");
    await dialog.getByPlaceholder("What was done").fill("Re-stuck");
    await dialog.getByRole("button", { name: "Fixed", exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText("All snags cleared — item back to Installed")).toBeVisible();
    await expect(snagged.getByRole("button", { name: "Done – close" })).toBeVisible();

    // Close asks first, then offers Undo.
    const ready = card("ready");
    await ready.getByRole("button", { name: "Done – close" }).click();
    dialog = page.getByRole("dialog");
    await expect(dialog).toContainText(`Mark ${made.ready.ref} complete?`);
    await dialog.getByRole("button", { name: "Done – close" }).click();
    const toast = page
      .getByRole("listitem")
      .filter({ hasText: `${made.ready.ref} marked complete` });
    await expect(toast).toBeVisible();
    await toast.getByRole("button", { name: "Undo" }).click();
    await expect(page.getByText(`${made.ready.ref} is back under Ready to close`)).toBeVisible();
    await expect(ready.getByRole("button", { name: "Done – close" })).toBeVisible();

    // Sponsorship items arrive under Deliveries: Received ✓.
    const deliveries = main.getByRole("region", { name: "Deliveries" });
    await expect(deliveries.locator("article", { hasText: made.bags.ref })).toBeVisible();
    await expect(card("bags").getByRole("button", { name: "Received ✓" })).toBeVisible();

    // Damage on arrival is logged before anything goes up.
    await card("damaged").getByRole("button", { name: "Report damage" }).click();
    dialog = page.getByRole("dialog");
    await expect(dialog).toContainText(`Report damage on ${made.damaged.ref}`);
    await dialog.getByLabel("What's wrong?").fill(`Corner crushed ${n}`);
    await dialog.getByRole("button", { name: "Report damage" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(card("damaged").getByText("1 snag")).toBeVisible();
    await expect(card("damaged").getByRole("button", { name: "Fixed ✓" })).toBeVisible();
    await expect(card("damaged").getByRole("button", { name: "Installed ✓" })).toBeVisible();

    // An earlier step left open is named, with the way to it — never "wait for Operations".
    await expect(card("stale").getByText("Sent to print isn't confirmed yet.")).toBeVisible();
    await expect(card("stale").getByRole("link", { name: "Confirm it on the item" })).toBeVisible();
    await expect(main.getByText(/Waiting on Operations/)).toHaveCount(0);

    // Done shows what's closed.
    await page.getByLabel("Find ref or name").fill("");
    await page.getByRole("button", { name: "Done", exact: true }).click();
    await expect(page).toHaveURL(/view=done/);
    await expect(card("ready")).toHaveCount(0);
    await page.context().close();
  });
});
