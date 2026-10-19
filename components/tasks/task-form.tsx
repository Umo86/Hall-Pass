"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { PersonPicker } from "@/components/people/person-picker";
import { openingEvent, type PersonOption } from "@/components/people/groups";
import { createTask } from "@/app/actions/tasks";
import { cn } from "@/lib/utils";

/** Someone a task can be given to (peopleFor(…, { type: "task" }) in lib/people.ts). */
export type Assignee = PersonOption;
export type TaskEvent = { id: string; code: string; name: string };

/**
 * Add a task: title, then (optionally) a due date, who it is for and the
 * event it belongs to. Pass `entity` to tie it to an item (the item page's
 * "Add task"); its event is then fixed.
 */
export function TaskForm({
  currentUserId,
  currentDepartmentId = null,
  assignees,
  canAssign,
  events = [],
  defaultEventId = null,
  entity,
  placeholder = "Add a task…",
  onAdded,
  className,
}: {
  currentUserId: string;
  /** The viewer's department: offered first after "Me". */
  currentDepartmentId?: string | null;
  assignees: Assignee[];
  canAssign: boolean;
  /** Events to choose from; none hides the picker. */
  events?: TaskEvent[];
  /** The event picked to start with (the one last opened). */
  defaultEventId?: string | null;
  /** The record the task is about (fixes the event). */
  entity?: {
    type: "signage_item" | "stand_submission";
    id: string;
    editionId: string;
    label: string;
  };
  placeholder?: string;
  onAdded?: () => void;
  className?: string;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const titleRef = useRef<HTMLInputElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const showEvents = !entity && events.length > 0;
  // Users → Events: only people who can open the chosen event are offered
  // (the current pick stays, labelled). The server re-checks.
  const [eventId, setEventId] = useState(defaultEventId ?? "");
  const [assignee, setAssignee] = useState(currentUserId);
  const chosenEvent = entity ? entity.editionId : showEvents ? eventId : null;
  const offered = openingEvent(assignees, chosenEvent, assignee);
  // On a phone the fields sit two to a row under the title; Add takes a
  // whole row when it would otherwise be left on its own.
  const middle = 1 + (canAssign ? 1 : 0) + (showEvents ? 1 : 0);
  const addSpans = middle % 2 === 0;

  return (
    <form
      ref={formRef}
      aria-label="Add a task"
      className={cn("grid grid-cols-2 items-center gap-2 sm:flex sm:flex-wrap", className)}
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        const title = String(fd.get("title") ?? "").trim();
        const assignedTo = (fd.get("assignedToUserId") as string | null) || null;
        setError(null);
        start(async () => {
          const res = await createTask({
            title,
            dueDate: fd.get("dueDate") || null,
            assignedToUserId: assignedTo,
            editionId: entity ? entity.editionId : (fd.get("editionId") as string | null) || null,
            entityType: entity?.type ?? null,
            entityId: entity?.id ?? null,
          });
          if (!res.ok) {
            setError(res.error);
            return;
          }
          const forWhom =
            assignedTo && assignedTo !== currentUserId
              ? assignees.find((a) => a.id === assignedTo)?.name
              : null;
          toast.success(`Task added: ${title}`, {
            description: forWhom ? `For ${forWhom} — they are told.` : entity?.label,
          });
          formRef.current?.reset();
          setEventId(defaultEventId ?? "");
          setAssignee(currentUserId);
          titleRef.current?.focus();
          onAdded?.();
          router.refresh();
        });
      }}
    >
      <Input
        ref={titleRef}
        name="title"
        placeholder={placeholder}
        required
        maxLength={300}
        aria-label="Task title"
        className="col-span-2 h-9 sm:min-w-56 sm:flex-1"
      />
      <Input
        name="dueDate"
        type="date"
        aria-label="Due date"
        className="h-9 w-full min-w-0 sm:w-40"
      />
      {canAssign && (
        <PersonPicker
          name="assignedToUserId"
          aria-label="Assign to"
          people={offered}
          meId={currentUserId}
          meDepartmentId={currentDepartmentId}
          value={assignee}
          onChange={setAssignee}
          className="h-9 w-full min-w-0 sm:w-56"
        />
      )}
      {showEvents && (
        <SelectNative
          name="editionId"
          aria-label="Event"
          value={eventId}
          onChange={(e) => setEventId(e.target.value)}
          className="h-9 w-full min-w-0 sm:w-52"
        >
          <option value="">No event</option>
          {events.map((ev) => (
            <option key={ev.id} value={ev.id}>
              {ev.name}
            </option>
          ))}
        </SelectNative>
      )}
      <Button type="submit" className={cn("h-9", addSpans && "col-span-2")} disabled={pending}>
        <Plus className="size-4" aria-hidden /> {pending ? "Adding…" : "Add"}
      </Button>
      {error && (
        <p role="alert" className="text-destructive col-span-2 w-full text-sm">
          {error}
        </p>
      )}
    </form>
  );
}
