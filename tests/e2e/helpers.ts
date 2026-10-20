import type { BrowserContext } from "@playwright/test";
import postgres from "postgres";

/** Development sign-in: the harness assumes a seeded user via cookie. */
export async function signInAs(context: BrowserContext, email: string, baseURL: string) {
  const url = new URL(baseURL);
  await context.addCookies([
    {
      name: "hp-dev-user",
      value: email,
      domain: url.hostname,
      path: "/",
      httpOnly: true,
      sameSite: "Lax",
    },
  ]);
}

const DB = process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/hallpass";

/** The second event `ensureSecondEvent` makes; its name never mentions BIRM27. */
export const SECOND_EVENT = { code: "E2EALT", name: "E2E second event" } as const;

/**
 * A second, not archived event next to BIRM27 (same series and venue, a
 * year later), for specs that need more than one event: the event switcher,
 * My Work's "Show tasks for". The seed makes only BIRM27, so specs must not
 * rely on events other specs leave behind. Safe to call from any spec.
 */
export async function ensureSecondEvent() {
  const sql = postgres(DB, { max: 1 });
  try {
    await sql`
      INSERT INTO editions (event_id, venue_id, name, code, build_start, build_end,
                            open_start, open_end, breakdown_end, status)
      SELECT event_id, venue_id, ${SECOND_EVENT.name}, ${SECOND_EVENT.code},
             build_start + 364, build_end + 364, open_start + 364, open_end + 364,
             breakdown_end + 364, 'planning'
      FROM editions
      WHERE code = 'BIRM27'
        AND NOT EXISTS (SELECT 1 FROM editions WHERE code = ${SECOND_EVENT.code})`;
    await sql`UPDATE editions SET status = 'planning' WHERE code = ${SECOND_EVENT.code} AND status = 'archived'`;
  } finally {
    await sql.end();
  }
  return SECOND_EVENT;
}
