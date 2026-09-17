import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

// Server-only Postgres client over the pooled connection (transaction mode).
// Never import from client components — the import of "postgres" would fail
// the build, which is the guard we want.
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error("DATABASE_URL is not set");
}

// Transaction-mode poolers do not support prepared statements.
const client = postgres(connectionString, { prepare: false });

export const db = drizzle(client, { schema });

export type Db = typeof db;
export type Tx = Parameters<Parameters<Db["transaction"]>[0]>[0];
