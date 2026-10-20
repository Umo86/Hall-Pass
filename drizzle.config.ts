import { defineConfig } from "drizzle-kit";
import "dotenv/config";
import { migrationDatabaseUrl } from "./lib/db/urls";

export default defineConfig({
  schema: "./lib/db/schema/index.ts",
  out: "./lib/db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    // Migrations always use the direct (non-pooled) connection: DIRECT_DATABASE_URL
    // locally; with DATABASE_TARGET=neon, Neon's DATABASE_URL_UNPOOLED.
    url: migrationDatabaseUrl(process.env)?.url ?? "",
  },
  verbose: true,
  strict: true,
});
