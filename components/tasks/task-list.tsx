"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatDate } from "@/lib/format";
import { completeTask, deleteTask } from "@/app/actions/tasks";
import type { TaskRow } from "@/lib/queries/tasks";

function TaskItem({ task, currentUserId }: { task: TaskRow; currentUserId: string }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const done = task.status === "done";
  const canDelete = task.createdByUserId === currentUserId;

  return (
    <li className="flex flex-wrap items-center gap-3 rounded-lg border p-3">
      <input
        type="checkbox"
        className="size-4"
        checked={done}
        disabled={pending}
        aria-label={`Mark "${task.title}" ${done ? "open" : "done"}`}
        onChange={(e) =>
          start(async () => {
            const res = await completeTask({ id: task.id, done: e.target.checked });
            setError(res.ok ? null : res.error);
            router.refresh();
          })
        }
      />
      <div className="min-w-0 flex-1">
        <p className={`text-sm font-medium ${done ? "text-muted-foreground line-through" : ""}`}>
          {task.title}
        </p>
        <p className="text-muted-foreground text-xs">
          {task.dueDate && (
            <span className={task.overdue ? "text-destructive font-medium" : ""}>
              Due {formatDate(task.dueDate)}
              {task.overdue ? " — overdue" : ""}
            </span>
          )}
          {task.dueDate && (task.editionCode || task.createdByUserId !== currentUserId) && " · "}
          {task.editionCode && <span>{task.editionCode}</span>}
          {task.editionCode && task.createdByUserId !== currentUserId && " · "}
          {task.createdByUserId !== currentUserId && (
            <span>from {task.createdByName || "a colleague"}</span>
          )}
        </p>
        {task.notes && <p className="text-muted-foreground mt-1 text-xs">{task.notes}</p>}
        {error && <p className="text-destructive mt-1 text-xs">{error}</p>}
      </div>
      {canDelete && (
        <Button
          size="sm"
          variant="ghost"
          disabled={pending}
          aria-label={`Delete "${task.title}"`}
          onClick={() =>
            start(async () => {
              const res = await deleteTask({ id: task.id });
              setError(res.ok ? null : res.error);
              router.refresh();
            })
          }
        >
          <Trash2 className="size-4" />
        </Button>
      )}
    </li>
  );
}

export function TaskList({
  open,
  completed,
  currentUserId,
}: {
  open: TaskRow[];
  completed: TaskRow[];
  currentUserId: string;
}) {
  if (open.length === 0 && completed.length === 0) {
    return (
      <p className="text-muted-foreground rounded-lg border border-dashed p-4 text-sm">
        No tasks yet — add your own above, or a colleague can assign you one.
      </p>
    );
  }
  return (
    <div className="space-y-2">
      <ol className="space-y-2">
        {open.map((t) => (
          <TaskItem key={t.id} task={t} currentUserId={currentUserId} />
        ))}
      </ol>
      {completed.length > 0 && (
        <details>
          <summary className="text-muted-foreground cursor-pointer text-xs select-none">
            Recently completed ({completed.length})
          </summary>
          <ol className="mt-2 space-y-2">
            {completed.map((t) => (
              <TaskItem key={t.id} task={t} currentUserId={currentUserId} />
            ))}
          </ol>
        </details>
      )}
    </div>
  );
}
