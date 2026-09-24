"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { createTask } from "@/app/actions/tasks";

export type Assignee = { id: string; name: string };

/** Inline add-a-task row: title, optional due date, optional assignee. */
export function TaskForm({
  currentUserId,
  assignees,
  canAssign,
}: {
  currentUserId: string;
  assignees: Assignee[];
  canAssign: boolean;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <form
      ref={formRef}
      className="flex flex-wrap items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        setError(null);
        start(async () => {
          const res = await createTask({
            title: fd.get("title"),
            dueDate: fd.get("dueDate") || null,
            assignedToUserId: fd.get("assignedToUserId") || null,
          });
          if (!res.ok) setError(res.error);
          else {
            formRef.current?.reset();
            router.refresh();
          }
        });
      }}
    >
      <Input
        name="title"
        placeholder="Add a task…"
        required
        aria-label="Task title"
        className="h-9 min-w-40 flex-1"
      />
      <Input name="dueDate" type="date" aria-label="Due date" className="h-9 w-36" />
      {canAssign && (
        <SelectNative
          name="assignedToUserId"
          aria-label="Assign to"
          defaultValue={currentUserId}
          className="h-9 w-40"
        >
          {assignees.map((a) => (
            <option key={a.id} value={a.id}>
              {a.id === currentUserId ? "Me" : a.name}
            </option>
          ))}
        </SelectNative>
      )}
      <Button type="submit" size="sm" disabled={pending}>
        <Plus className="size-4" /> Add
      </Button>
      {error && <p className="text-destructive w-full text-sm">{error}</p>}
    </form>
  );
}
