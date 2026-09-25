/**
 * Apply migrations once before any test file runs, so DB-backed test files
 * don't race each other migrating a fresh database.
 */
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";

export default async function setup() {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) return;
  const client = postgres(url, { max: 1, prepare: false, onnotice: () => {} });
  try {
    await migrate(drizzle(client), { migrationsFolder: "lib/db/migrations" });
  } finally {
    await client.end();
  }
}
