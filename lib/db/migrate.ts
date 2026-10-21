import "dotenv/config";
import { runMigrations } from "./migrate-core";
import {
  databaseHostPort,
  databaseNameOf,
  databaseProviderOf,
  migrationDatabaseMissingReason,
  migrationDatabaseUrl,
} from "./urls";

/**
 * `pnpm db:migrate`: applies the repo's migrations over the direct
 * connection (lib/db/urls.ts:migrationDatabaseUrl — DIRECT_DATABASE_URL
 * locally; with DATABASE_TARGET=neon, Neon's DATABASE_URL_UNPOOLED). Prints
 * the provider and host it is about to change, never the credentials.
 */
async function main() {
  const target = migrationDatabaseUrl(process.env);
  if (!target) throw new Error(migrationDatabaseMissingReason(process.env));
  console.log(
    `Migrating ${databaseProviderOf(target.url)} database ${databaseNameOf(target.url) ?? "?"} at ${databaseHostPort(target.url) ?? "?"} (from ${target.via})`,
  );
  const { applied, total } = await runMigrations(target.url, "lib/db/migrations");
  console.log(`Migrations applied: ${applied} new, ${total} in total`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
