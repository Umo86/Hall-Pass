"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, CalendarClock, CheckSquare, Paperclip, Trash2, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { Textarea } from "@/components/ui/textarea";
import {
  completeTask,
  createTask,
  deleteTask,
  deleteTaskAttachment,
  setTaskStatus,
  updateTask,
  uploadTaskAttachment,
} from "@/app/actions/tasks";
import { formatDate } from "@/lib/format";
import type { BoardAttachment, BoardTask } from "@/lib/queries/tasks";

type Status = BoardTask["status"];

const COLUMNS: { status: Status; label: string; head: string; body: string; dot: string }[] = [
  {
    status: "open",
    label: "To do",
    head: "bg-red-600 text-white",
    body: "border-red-200 bg-red-50/60 dark:border-red-900 dark:bg-red-950/30",
    dot: "bg-red-600",
  },
  {
    status: "in_progress",
    label: "In progress",
    head: "bg-orange-500 text-white",
    body: "border-orange-200 bg-orange-50/60 dark:border-orange-900 dark:bg-orange-950/30",
    dot: "bg-orange-500",
  },
  {
    status: "done",
    label: "Complete",
    head: "bg-green-600 text-white",
    body: "border-green-200 bg-green-50/60 dark:border-green-900 dark:bg-green-950/30",
    dot: "bg-green-600",
  },
];
const LABEL: Record<Status, string> = {
  open: "To do",
  in_progress: "In progress",
  done: "Complete",
};

export type Person = { id: string; name: string };

/** My Work as a board: To do (red), In progress (orange), Complete (green). */
export function TaskBoard({
  tasks,
  currentUserId,
  people,
  canAssign,
}: {
  tasks: BoardTask[];
  currentUserId: string;
  people: Person[];
  canAssign: boolean;
}) {
  const [moved, setMoved] = useState<Record<string, Status>>({});
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<Status | null>(null);
  const [openId, setOpenId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [, start] = useTransition();
  const router = useRouter();

  const statusOf = (t: BoardTask) => moved[t.id] ?? t.status;
  function move(id: string, status: Status) {
    const task = tasks.find((t) => t.id === id);
    if (!task || statusOf(task) === status) return;
    setMoved((m) => ({ ...m, [id]: status }));
    setError(null);
    start(async () => {
      const res = await setTaskStatus({ id, status });
      if (!res.ok) {
        setError(res.error);
        setMoved((m) => {
          const next = { ...m };
          delete next[id];
          return next;
        });
      }
      router.refresh();
    });
  }
  const open = tasks.find((t) => t.id === openId) ?? null;

  return (
    <div className="space-y-2">
      {error && <p className="text-destructive text-sm">{error}</p>}
      <div className="grid gap-3 lg:grid-cols-3" aria-label="Task board">
        {COLUMNS.map((col) => {
          const list = tasks.filter((t) => statusOf(t) === col.status);
          return (
            <section
              key={col.status}
              aria-label={col.label}
              className={`flex min-h-40 flex-col overflow-hidden rounded-lg border ${col.body} ${
                over === col.status ? "ring-primary ring-2" : ""
              }`}
              onDragOver={(e) => {
                e.preventDefault();
                setOver(col.status);
              }}
              onDragLeave={() => setOver((o) => (o === col.status ? null : o))}
              onDrop={(e) => {
                e.preventDefault();
                setOver(null);
                const id = e.dataTransfer.getData("text/plain") || dragging;
                if (id) move(id, col.status);
                setDragging(null);
              }}
            >
              <h3
                className={`flex items-center justify-between px-3 py-2 text-sm font-semibold ${col.head}`}
              >
                {col.label}
                <span className="rounded-full bg-white/25 px-2 text-xs">{list.length}</span>
              </h3>
              <ul className="flex flex-1 flex-col gap-2 p-2">
                {list.length === 0 && (
                  <li className="text-muted-foreground p-3 text-center text-xs">Drag tasks here</li>
                )}
                {list.map((t) => (
                  <TaskCard
                    key={t.id}
                    task={t}
                    status={statusOf(t)}
                    currentUserId={currentUserId}
                    onOpen={() => setOpenId(t.id)}
                    onMove={(s) => move(t.id, s)}
                    onDragStart={() => setDragging(t.id)}
                  />
                ))}
              </ul>
            </section>
          );
        })}
      </div>
      {open && (
        <TaskDetail
          task={open}
          people={people}
          canAssign={canAssign}
          currentUserId={currentUserId}
          onClose={() => setOpenId(null)}
          onMove={(s) => move(open.id, s)}
          status={statusOf(open)}
        />
      )}
    </div>
  );
}

function TaskCard({
  task,
  status,
  currentUserId,
  onOpen,
  onMove,
  onDragStart,
}: {
  task: BoardTask;
  status: Status;
  currentUserId: string;
  onOpen: () => void;
  onMove: (s: Status) => void;
  onDragStart: () => void;
}) {
  const doneSubs = task.subtasks.filter((s) => s.status === "done").length;
  const late = task.overdue && status !== "done";
  return (
    <li
      aria-label={task.title}
      draggable
      onDragStart={(e) => {
        e.dataTransfer.setData("text/plain", task.id);
        e.dataTransfer.effectAllowed = "move";
        onDragStart();
      }}
      className={`bg-background cursor-grab rounded-md border p-2.5 text-sm shadow-sm active:cursor-grabbing ${
        late ? "border-red-500 ring-1 ring-red-500" : ""
      }`}
    >
      <button
        type="button"
        onClick={onOpen}
        className="w-full text-left font-medium hover:underline"
      >
        {task.title}
      </button>
      <div className="text-muted-foreground mt-1 flex flex-wrap gap-x-3 gap-y-1 text-xs">
        <span>
          {task.assignedToUserId === currentUserId ? "You" : task.assignedToName}
          {task.createdByUserId !== task.assignedToUserId && task.createdByUserId !== currentUserId
            ? ` · from ${task.createdByName}`
            : ""}
        </span>
        {task.editionCode && <span>{task.editionCode}</span>}
        {task.subtasks.length > 0 && (
          <span className="inline-flex items-center gap-1">
            <CheckSquare className="size-3" aria-hidden /> {doneSubs}/{task.subtasks.length}
          </span>
        )}
        {task.attachments.length > 0 && (
          <span className="inline-flex items-center gap-1">
            <Paperclip className="size-3" aria-hidden /> {task.attachments.length}
          </span>
        )}
      </div>
      {task.dueDate && (
        <p
          className={`mt-1.5 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-xs ${
            late ? "bg-red-600 font-semibold text-white" : "text-muted-foreground bg-muted"
          }`}
        >
          {late ? (
            <AlertTriangle className="size-3" aria-hidden />
          ) : (
            <CalendarClock className="size-3" aria-hidden />
          )}
          {late ? "Overdue — was due " : "Due "}
          {formatDate(task.dueDate)}
        </p>
      )}
      {task.overdueSubtasks > 0 && status !== "done" && (
        <p className="mt-1 text-xs font-semibold text-red-600">
          {task.overdueSubtasks} subtask{task.overdueSubtasks === 1 ? "" : "s"} overdue
        </p>
      )}
      <SelectNative
        aria-label={`Move ${task.title}`}
        value={status}
        onChange={(e) => onMove(e.target.value as Status)}
        className="mt-2 h-7 text-xs"
      >
        {COLUMNS.map((c) => (
          <option key={c.status} value={c.status}>
            {c.label}
          </option>
        ))}
      </SelectNative>
    </li>
  );
}

function AttachmentList({
  files,
  taskId,
  label,
  onError,
}: {
  files: BoardAttachment[];
  taskId: string;
  label: string;
  onError: (e: string | null) => void;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <div className="space-y-1">
      {files.length > 0 && (
        <ul className="space-y-1 text-sm">
          {files.map((f) => (
            <li key={f.id} className="flex items-center gap-2">
              <Paperclip className="text-muted-foreground size-3.5 shrink-0" aria-hidden />
              <a href={`/api/task-files/${f.id}`} className="min-w-0 truncate underline">
                {f.fileName}
              </a>
              <span className="text-muted-foreground text-xs">
                {Math.max(1, Math.round(f.fileSize / 1024))} KB
              </span>
              <button
                type="button"
                aria-label={`Remove ${f.fileName}`}
                className="text-muted-foreground hover:text-destructive ml-auto"
                disabled={pending}
                onClick={() =>
                  start(async () => {
                    const res = await deleteTaskAttachment({ id: f.id });
                    onError(res.ok ? null : res.error);
                    router.refresh();
                  })
                }
              >
                <X className="size-4" />
              </button>
            </li>
          ))}
        </ul>
      )}
      <input
        ref={input}
        type="file"
        className="sr-only"
        aria-label={label}
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          const fd = new FormData();
          fd.set("taskId", taskId);
          fd.set("file", file);
          start(async () => {
            const res = await uploadTaskAttachment(fd);
            onError(res.ok ? null : res.error);
            if (input.current) input.current.value = "";
            router.refresh();
          });
        }}
      />
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className="h-7 px-2 text-xs"
        disabled={pending}
        onClick={() => input.current?.click()}
      >
        <Paperclip className="size-3.5" /> {pending ? "Uploading…" : "Attach a file"}
      </Button>
    </div>
  );
}

function TaskDetail({
  task,
  status,
  people,
  canAssign,
  currentUserId,
  onClose,
  onMove,
}: {
  task: BoardTask;
  status: Status;
  people: Person[];
  canAssign: boolean;
  currentUserId: string;
  onClose: () => void;
  onMove: (s: Status) => void;
}) {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const subForm = useRef<HTMLFormElement>(null);

  function run(
    fn: () => Promise<{ ok: boolean; error?: string; message?: string }>,
    after?: () => void,
  ) {
    setError(null);
    setNotice(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) setError(res.error ?? "Something went wrong");
      else {
        setNotice(res.message ?? null);
        after?.();
      }
      router.refresh();
    });
  }

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{task.title}</DialogTitle>
          <DialogDescription>
            {LABEL[status]} · for{" "}
            {task.assignedToUserId === currentUserId ? "you" : task.assignedToName}
            {task.createdByUserId !== task.assignedToUserId
              ? ` · set by ${task.createdByName}`
              : ""}
          </DialogDescription>
        </DialogHeader>

        {task.overdue && status !== "done" && (
          <p className="flex items-center gap-2 rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white">
            <AlertTriangle className="size-4" aria-hidden /> Overdue — this was due{" "}
            {formatDate(task.dueDate)}.
          </p>
        )}

        <form
          key={task.id + task.title + (task.dueDate ?? "")}
          className="grid gap-3 sm:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            const f = new FormData(e.currentTarget);
            run(() =>
              updateTask({
                id: task.id,
                title: f.get("title"),
                notes: f.get("notes") || null,
                dueDate: f.get("dueDate") || null,
                ...(canAssign ? { assignedToUserId: f.get("assignedToUserId") } : {}),
              }),
            );
          }}
        >
          <label className="grid gap-1 text-sm sm:col-span-2">
            <span className="font-medium">Task</span>
            <Input name="title" defaultValue={task.title} required />
          </label>
          <label className="grid gap-1 text-sm sm:col-span-2">
            <span className="font-medium">Notes</span>
            <Textarea name="notes" defaultValue={task.notes ?? ""} rows={2} />
          </label>
          <label className="grid gap-1 text-sm">
            <span className="font-medium">Deadline</span>
            <Input name="dueDate" type="date" defaultValue={task.dueDate ?? ""} />
          </label>
          {canAssign ? (
            <label className="grid gap-1 text-sm">
              <span className="font-medium">Assigned to</span>
              <SelectNative name="assignedToUserId" defaultValue={task.assignedToUserId}>
                {people.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.id === currentUserId ? "Me" : p.name}
                  </option>
                ))}
              </SelectNative>
            </label>
          ) : (
            <div />
          )}
          <label className="grid gap-1 text-sm">
            <span className="font-medium">Status</span>
            <SelectNative value={status} onChange={(e) => onMove(e.target.value as Status)}>
              {COLUMNS.map((c) => (
                <option key={c.status} value={c.status}>
                  {c.label}
                </option>
              ))}
            </SelectNative>
          </label>
          <div className="flex items-end gap-2">
            <Button type="submit" disabled={pending}>
              Save changes
            </Button>
            {task.canDelete && (
              <Button
                type="button"
                variant="ghost"
                disabled={pending}
                onClick={() => {
                  if (confirm(`Delete “${task.title}” and its subtasks?`)) {
                    run(() => deleteTask({ id: task.id }), onClose);
                  }
                }}
              >
                <Trash2 className="size-4" /> Delete
              </Button>
            )}
          </div>
        </form>

        <section className="space-y-2" aria-label="Attachments">
          <h4 className="text-sm font-semibold">Attachments</h4>
          <AttachmentList
            files={task.attachments}
            taskId={task.id}
            label={`Attach a file to ${task.title}`}
            onError={setError}
          />
        </section>

        <section className="space-y-2" aria-label="Subtasks">
          <h4 className="text-sm font-semibold">
            Subtasks{" "}
            <span className="text-muted-foreground font-normal">
              ({task.subtasks.filter((s) => s.status === "done").length}/{task.subtasks.length}{" "}
              done)
            </span>
          </h4>
          <ul className="divide-y rounded-md border">
            {task.subtasks.length === 0 && (
              <li className="text-muted-foreground px-3 py-2 text-sm">No subtasks yet.</li>
            )}
            {task.subtasks.map((s) => (
              <li
                key={s.id}
                aria-label={s.title}
                className={`space-y-1 px-3 py-2 text-sm ${s.overdue ? "bg-red-50 dark:bg-red-950/40" : ""}`}
              >
                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    className="size-4"
                    checked={s.status === "done"}
                    aria-label={`${s.title} done`}
                    disabled={pending}
                    onChange={(e) => run(() => completeTask({ id: s.id, done: e.target.checked }))}
                  />
                  <span
                    className={`flex-1 ${s.status === "done" ? "line-through opacity-60" : ""}`}
                  >
                    {s.title}
                  </span>
                  {s.dueDate && (
                    <span
                      className={`rounded px-1.5 py-0.5 text-xs ${
                        s.overdue ? "bg-red-600 font-semibold text-white" : "text-muted-foreground"
                      }`}
                    >
                      {s.overdue ? "Overdue — " : "Due "}
                      {formatDate(s.dueDate)}
                    </span>
                  )}
                  <button
                    type="button"
                    aria-label={`Delete subtask ${s.title}`}
                    className="text-muted-foreground hover:text-destructive"
                    disabled={pending}
                    onClick={() => run(() => deleteTask({ id: s.id }))}
                  >
                    <X className="size-4" />
                  </button>
                </div>
                <div className="pl-6">
                  <AttachmentList
                    files={s.attachments}
                    taskId={s.id}
                    label={`Attach a file to ${s.title}`}
                    onError={setError}
                  />
                </div>
              </li>
            ))}
          </ul>
          <form
            ref={subForm}
            className="flex flex-wrap gap-2"
            aria-label="Add a subtask"
            onSubmit={(e) => {
              e.preventDefault();
              const f = new FormData(e.currentTarget);
              run(
                () =>
                  createTask({
                    parentTaskId: task.id,
                    title: f.get("title"),
                    dueDate: f.get("dueDate") || null,
                  }),
                () => subForm.current?.reset(),
              );
            }}
          >
            <Input
              name="title"
              placeholder="Add a subtask…"
              aria-label="Subtask"
              className="h-9 min-w-40 flex-1"
              required
            />
            <Input name="dueDate" type="date" aria-label="Subtask deadline" className="h-9 w-40" />
            <Button type="submit" size="sm" className="h-9" disabled={pending}>
              Add
            </Button>
          </form>
        </section>
        {notice && <p className="text-sm text-green-700 dark:text-green-400">{notice}</p>}
        {error && <p className="text-destructive text-sm">{error}</p>}
      </DialogContent>
    </Dialog>
  );
}
