/**
 * Is the database's schema as new as this deployment's code? Compared by
 * the newest migration each knows: drizzle records each applied migration's
 * journal timestamp in drizzle.__drizzle_migrations.created_at. Pure; used
 * by /api/health so a deploy that ran before `pnpm db:migrate` says so
 * (every signed-in page would otherwise fail on a missing column).
 */
import journal from "@/lib/db/migrations/meta/_journal.json";

export type SchemaState = "current" | "behind" | "unknown";

/** The newest migration this code ships with (its journal timestamp and tag). */
export function latestMigration(): { when: number; tag: string } {
  const last = journal.entries[journal.entries.length - 1];
  return { when: last.when, tag: last.tag };
}

/** `appliedWhen`: the newest created_at in drizzle.__drizzle_migrations, or null when unknown. */
export function schemaState(
  appliedWhen: number | null,
  codeWhen = latestMigration().when,
): SchemaState {
  if (appliedWhen == null || !Number.isFinite(appliedWhen)) return "unknown";
  return appliedWhen >= codeWhen ? "current" : "behind";
}
