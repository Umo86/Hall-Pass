/**
 * Pure rules for the My Work board: the order of cards in each column, how
 * many Done cards show, and the one-tap move on each card. Unit tested.
 */

export type TaskStatus = "open" | "in_progress" | "done";

export const STATUS_WORDS: Record<TaskStatus, string> = {
  open: "To do",
  in_progress: "In progress",
  done: "Done",
};

type Sortable = {
  status: TaskStatus;
  dueDate: string | null;
  overdue: boolean;
  overdueSubtasks?: number;
  createdAt?: string;
  completedAt?: string | null;
};

const late = (t: Sortable) => t.overdue || (t.overdueSubtasks ?? 0) > 0;

/**
 * To do and In progress: overdue first, then by due date, then undated (oldest
 * first). Done: most recently finished first.
 */
export function sortForColumn<T extends Sortable>(tasks: T[], status: TaskStatus): T[] {
  const list = [...tasks];
  if (status === "done") {
    return list.sort((a, b) => (b.completedAt ?? "").localeCompare(a.completedAt ?? ""));
  }
  return list.sort((a, b) => {
    if (late(a) !== late(b)) return late(a) ? -1 : 1;
    if (a.dueDate && b.dueDate && a.dueDate !== b.dueDate) {
      return a.dueDate.localeCompare(b.dueDate);
    }
    if (a.dueDate && !b.dueDate) return -1;
    if (!a.dueDate && b.dueDate) return 1;
    return (a.createdAt ?? "").localeCompare(b.createdAt ?? "");
  });
}

/** Done shows the five most recent; the rest are behind "Show n more". */
export const DONE_VISIBLE = 5;

export function visibleCards<T>(
  list: T[],
  status: TaskStatus,
  expanded: boolean,
): { shown: T[]; hidden: number } {
  if (status !== "done" || expanded || list.length <= DONE_VISIBLE) {
    return { shown: list, hidden: 0 };
  }
  return { shown: list.slice(0, DONE_VISIBLE), hidden: list.length - DONE_VISIBLE };
}

export type Move = { label: string; to: TaskStatus };

/** The one button on each card: Start, Mark done, or Reopen. */
export function primaryMove(status: TaskStatus): Move {
  switch (status) {
    case "open":
      return { label: "Start", to: "in_progress" };
    case "in_progress":
      return { label: "Mark done", to: "done" };
    case "done":
      return { label: "Reopen", to: "open" };
  }
}

/** The other moves, in the card's "…" menu. */
export function otherMoves(status: TaskStatus): Move[] {
  switch (status) {
    case "open":
      return [{ label: "Mark done", to: "done" }];
    case "in_progress":
      return [{ label: "Back to To do", to: "open" }];
    case "done":
      return [{ label: "Back to In progress", to: "in_progress" }];
  }
}

/** The toast after a move: "Moved to Done". */
export function moveToast(to: TaskStatus): string {
  return `Moved to ${STATUS_WORDS[to]}`;
}

/** Which board columns to draw: an empty board shows only To do with a hint. */
export function columnsToShow(total: number): TaskStatus[] {
  return total === 0 ? ["open"] : ["open", "in_progress", "done"];
}
