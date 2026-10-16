/**
 * Archived editions are read-only: history stays queryable and exportable,
 * but nothing about them may change (brief §4). Pure so it is unit-testable
 * and safe to call anywhere.
 */

export type EditionStatusValue = "planning" | "live" | "closed" | "archived";

export function editionIsReadOnly(status: string): boolean {
  return status === "archived";
}

export const EDITION_LOCKED_MESSAGE =
  "This event is archived and read-only — nothing can be changed. An admin can bring it back from Events if follow-up work is needed.";
