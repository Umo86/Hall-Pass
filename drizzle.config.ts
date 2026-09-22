import { defineConfig } from "drizzle-kit";
import "dotenv/config";

export default defineConfig({
  schema: "./lib/db/schema/index.ts",
  out: "./lib/db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    // Migrations always use the direct (non-pooled) connection.
    url: process.env.DIRECT_DATABASE_URL ?? process.env.DATABASE_URL_UNPOOLED ?? process.env.POSTGRES_URL_NON_POOLING ?? process.env.DATABASE_URL ?? process.env.POSTGRES_URL ?? "",
  },
  verbose: true,
  strict: true,
});
