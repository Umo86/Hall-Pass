import { describe, expect, it } from "vitest";
import {
  columnsToShow,
  moveToast,
  otherMoves,
  primaryMove,
  sortForColumn,
  visibleCards,
} from "@/components/tasks/board-logic";

type T = {
  id: string;
  status: "open" | "in_progress" | "done";
  dueDate: string | null;
  overdue: boolean;
  overdueSubtasks?: number;
  createdAt?: string;
  completedAt?: string | null;
};
const t = (id: string, rest: Partial<T>): T => ({
  id,
  status: "open",
  dueDate: null,
  overdue: false,
  ...rest,
});

describe("My Work board", () => {
  it("sorts To do as overdue first, then by due date, then undated", () => {
    const sorted = sortForColumn(
      [
        t("undated-new", { createdAt: "2026-10-02" }),
        t("later", { dueDate: "2026-10-30" }),
        t("late", { dueDate: "2026-10-01", overdue: true }),
        t("soon", { dueDate: "2026-10-18" }),
        t("late-subtask", { dueDate: "2026-11-30", overdueSubtasks: 1 }),
        t("undated-old", { createdAt: "2026-09-01" }),
      ],
      "open",
    ).map((x) => x.id);
    expect(sorted).toEqual(["late", "late-subtask", "soon", "later", "undated-old", "undated-new"]);
  });

  it("puts the most recently finished first in Done", () => {
    const sorted = sortForColumn(
      [
        t("a", { status: "done", completedAt: "2026-10-01T10:00:00Z" }),
        t("b", { status: "done", completedAt: "2026-10-15T10:00:00Z" }),
      ],
      "done",
    ).map((x) => x.id);
    expect(sorted).toEqual(["b", "a"]);
  });

  it("shows five Done cards and counts the rest", () => {
    const list = Array.from({ length: 8 }, (_, i) => i);
    expect(visibleCards(list, "done", false)).toEqual({ shown: [0, 1, 2, 3, 4], hidden: 3 });
    expect(visibleCards(list, "done", true)).toEqual({ shown: list, hidden: 0 });
    expect(visibleCards(list, "open", false)).toEqual({ shown: list, hidden: 0 });
  });

  it("offers one move per card and the rest in a menu", () => {
    expect(primaryMove("open")).toEqual({ label: "Start", to: "in_progress" });
    expect(primaryMove("in_progress")).toEqual({ label: "Mark done", to: "done" });
    expect(primaryMove("done")).toEqual({ label: "Reopen", to: "open" });
    for (const s of ["open", "in_progress", "done"] as const) {
      const targets = [primaryMove(s).to, ...otherMoves(s).map((m) => m.to)];
      // Every other column is reachable, and never the one it is in.
      expect(new Set(targets)).toEqual(
        new Set(["open", "in_progress", "done"].filter((x) => x !== s)),
      );
    }
    expect(moveToast("done")).toBe("Moved to Done");
  });

  it("shows only To do on an empty board", () => {
    expect(columnsToShow(0)).toEqual(["open"]);
    expect(columnsToShow(3)).toEqual(["open", "in_progress", "done"]);
  });
});
