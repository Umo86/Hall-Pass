/**
 * Events per person (Users → Events) in SQL: every list that spans events
 * filters by the viewer's scope (null = every event). No `server-only`, so
 * the cron and tests can use it too.
 */
import { inArray, isNull, or, sql, type AnyColumn, type SQL } from "drizzle-orm";
import { editionScope, type Actor, type EditionScope } from "@/lib/authz";

/**
 * SQL limiting `column` to the scope's events: undefined for every event
 * (drizzle drops it from `and()`), false for an empty list. `allowNull`
 * also keeps rows about no event (tasks and notifications without one).
 */
export function editionScopeSql(
  scope: EditionScope,
  column: AnyColumn | SQL,
  opts: { allowNull?: boolean } = {},
): SQL | undefined {
  if (scope === null) return undefined;
  const inScope = scope.length === 0 ? sql`false` : inArray(column as AnyColumn, [...scope]);
  return opts.allowNull ? or(isNull(column), inScope) : inScope;
}

/** The signed-in person's events (null = every event). */
export function sessionScope(session: { actor: Actor }): EditionScope {
  return editionScope(session.actor);
}

/**
 * What record loaders need to answer "not found" for anything outside the
 * signed-in person's organisation and events (loadItemBundle,
 * loadStandBundle). Here rather than in lib/auth/actor so tests that mock
 * the session keep it.
 */
export function actorScope(session: { organisation: { id: string }; actor: Actor }): {
  organisationId: string;
  actor: Actor;
} {
  return { organisationId: session.organisation.id, actor: session.actor };
}
