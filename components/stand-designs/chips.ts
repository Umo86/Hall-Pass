/**
 * The status chips above the Feature stands cards. Pure and client-safe:
 * the stand list (a client component) reads them without pulling in the
 * stand-design domain module and its database code.
 */
export const STAND_CHIPS = [
  "needs_design",
  "not_sent",
  "in_signoff",
  "changes_requested",
  "approved",
  "on_hold",
] as const;

export type StandChip = (typeof STAND_CHIPS)[number];

export const STAND_CHIP_LABELS: Record<StandChip, string> = {
  needs_design: "Needs design",
  not_sent: "Not sent yet",
  in_signoff: "In sign-off",
  changes_requested: "Changes requested",
  approved: "Approved",
  on_hold: "On hold",
};
