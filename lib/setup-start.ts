/**
 * What My Work does when no event is running. Pure; tested in
 * tests/unit/setup-start.test.ts.
 *
 * Only a brand-new organisation (no events at all) sends whoever can
 * create events straight to "Create your event". Between seasons — every
 * event archived, the next not created yet — My Work stays open (it is
 * where people land after signing in, with their open tasks) and shows a
 * card to create the next event; people who can't create events are told
 * who to ask.
 */
export type NoEventsStart = "redirect" | "create_next" | "ask" | null;

export function noEventsStart(opts: {
  /** Events in the organisation, archived ones included. */
  totalEvents: number;
  /** Events not archived. */
  activeEvents: number;
  canCreate: boolean;
}): NoEventsStart {
  if (opts.activeEvents > 0) return null;
  if (opts.canCreate) return opts.totalEvents === 0 ? "redirect" : "create_next";
  return "ask";
}
