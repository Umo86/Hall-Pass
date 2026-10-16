/**
 * Onsite's rules (pure; unit tested in tests/unit/onsite-rules.test.ts):
 * which section a card sits in, which view shows it, and the one thing it
 * offers next — confirm delivery or install, say which earlier step is
 * still open, or who it waits on. Never tells people to wait for themselves.
 */

/** The confirmation to tick on a card, as the item page's step names say it. */
const STEP_DUE_AT: Record<string, string[]> = {
  "Sent to print": ["approved", "approved_with_conditions"],
  Delivered: ["in_production"],
};

export type OnsiteView = "today" | "todo" | "done";

export const ONSITE_VIEWS: { id: OnsiteView; label: string }[] = [
  { id: "today", label: "Today" },
  { id: "todo", label: "All to do" },
  { id: "done", label: "Done" },
];

/** The view in the address, accepting the older `?when=all` / `?show=all` links. */
export function parseOnsiteView(
  view: string | null | undefined,
  legacy: { when?: string | null; show?: string | null } = {},
): OnsiteView {
  if (view === "today" || view === "todo" || view === "done") return view;
  if (legacy.when === "all" || legacy.show === "all") return "todo";
  return "today";
}

export type OnsiteSection = "deliveries" | "place" | "ready_to_close" | "done";

type SectionInput = { kind: string; status: string; openSnags: number };

/**
 * Sponsorship items arrive rather than go up: they sit under Deliveries.
 * Installed and snag-free means ready to close; closed means done.
 */
export function onsiteSection(card: SectionInput): OnsiteSection {
  if (card.status === "closed") return "done";
  if (card.status === "installed" && card.openSnags === 0) return "ready_to_close";
  if (card.kind === "sponsorship_item") return "deliveries";
  return "place";
}

/**
 * Today: everything due by today (overdue and undated included), anything
 * snagged whatever its date, and what is ready to close. All to do: every
 * open item. Done: closed items.
 */
export function inOnsiteView(
  card: SectionInput & { installDate: string | null },
  view: OnsiteView,
  today: string,
): boolean {
  const section = onsiteSection(card);
  if (view === "done") return section === "done";
  if (section === "done") return false;
  if (view === "todo") return true;
  if (section === "ready_to_close") return true;
  if (card.status === "snagged" || card.openSnags > 0) return true;
  return !card.installDate || card.installDate <= today;
}

/** Find by ref (or just its number: "015") or name. */
export function matchesOnsiteSearch(q: string, card: { ref: string; name: string }): boolean {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const hay = `${card.ref} ${card.name}`.toLowerCase();
  return words.every((w) => hay.includes(w));
}

export type OnsiteAction =
  | { type: "confirm"; instanceId: string; stepName: string; label: string; photo: boolean }
  | { type: "open_item"; text: string; label: string }
  | { type: "waiting"; text: string }
  | null;

/** "Delivered ✓"; sponsorship items are "Received ✓", then "In place ✓". */
export function confirmLabel(kind: string, stepName: string, isInstall: boolean): string {
  if (kind === "sponsorship_item") {
    if (stepName === "Delivered") return "Received ✓";
    if (isInstall) return "In place ✓";
  }
  return `${isInstall ? "Installed" : stepName} ✓`;
}

/**
 * What a card offers next. The waiting confirmation if it is due now and
 * the viewer may tick it; an earlier step left open (older data) sends them
 * to the item; someone else's step names who it waits on — but never the
 * viewer's own team.
 */
export function onsiteAction(card: {
  kind: string;
  status: string;
  pending: {
    id: string;
    stepName: string;
    isInstall: boolean;
    who: string;
    /** The viewer may tick it. */
    canDecide: boolean;
    /** It is the viewer's own step (their department, role or name). */
    viewerHolds: boolean;
  } | null;
  /** Signs need an install photo (organisation setting). */
  photoForSigns: boolean;
}): OnsiteAction {
  const { status, pending } = card;
  if (!["in_production", "delivered"].includes(status)) return null;
  if (!pending) {
    return status === "delivered"
      ? { type: "open_item", text: "Nothing is waiting to confirm.", label: "Open the item" }
      : null;
  }
  const dueNow = pending.isInstall
    ? status === "delivered"
    : (STEP_DUE_AT[pending.stepName] ?? []).includes(status);
  if (!dueNow) {
    return {
      type: "open_item",
      text: `${pending.stepName} isn't confirmed yet.`,
      label: "Confirm it on the item",
    };
  }
  if (pending.canDecide) {
    return {
      type: "confirm",
      instanceId: pending.id,
      stepName: pending.stepName,
      label: confirmLabel(card.kind, pending.stepName, pending.isInstall),
      photo: pending.isInstall && card.kind === "signage" && card.photoForSigns,
    };
  }
  if (pending.viewerHolds) return null;
  const what = pending.isInstall
    ? card.kind === "sponsorship_item"
      ? "it is in place"
      : "it is installed"
    : pending.stepName === "Delivered"
      ? "delivery"
      : pending.stepName.toLowerCase();
  return { type: "waiting", text: `Waiting on ${pending.who} to confirm ${what}` };
}

/** Snags can be raised from delivery on (damage on arrival) for signs and panels. */
export function snagLabel(kind: string, status: string): string | null {
  if (kind === "sponsorship_item") return null;
  if (status === "delivered") return "Report damage";
  if (status === "installed" || status === "snagged") return "Raise snag";
  return null;
}
