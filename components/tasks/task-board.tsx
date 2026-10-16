"use client";

import { useRef, useState, useSyncExternalStore, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  AlertTriangle,
  ArrowUpRight,
  CalendarClock,
  CheckSquare,
  MoreHorizontal,
  Paperclip,
  Trash2,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { SelectNative } from "@/components/ui/select-native";
import { PersonPicker, UnavailableNote } from "@/components/people/person-picker";
import type { PersonOption } from "@/components/people/groups";
import { Textarea } from "@/components/ui/textarea";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import { useConfirm } from "@/components/confirm-dialog";
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
import { cn } from "@/lib/utils";
import type { BoardAttachment, BoardTask } from "@/lib/queries/tasks";
import {
  STATUS_WORDS,
  columnsToShow,
  moveToast,
  otherMoves,
  primaryMove,
  sortForColumn,
  visibleCards,
  type TaskStatus,
} from "./board-logic";

type Status = TaskStatus;

/** One colour per column; red is kept for overdue only. */
const COLUMNS: { status: Status; label: string; head: string; body: string }[] = [
  {
    status: "open",
    label: STATUS_WORDS.open,
    head: "bg-slate-700 text-white dark:bg-slate-600",
    body: "border-border bg-muted/30",
  },
  {
    status: "in_progress",
    label: STATUS_WORDS.in_progress,
    head: "bg-blue-600 text-white",
    body: "border-blue-200 bg-blue-50/50 dark:border-blue-900 dark:bg-blue-950/30",
  },
  {
    status: "done",
    label: STATUS_WORDS.done,
    head: "bg-green-700 text-white",
    body: "border-green-200 bg-green-50/50 dark:border-green-900 dark:bg-green-950/30",
  },
];

const PHONE_COLUMN_KEY = "hp-board-column";

/** Someone a task can go to; the current assignee stays listed, labelled, if they can't any more. */
export type Person = PersonOption;

/** True on devices with a mouse or trackpad (drag and drop works there). */
function useFinePointer() {
  return useSyncExternalStore(
    (onChange) => {
      const mq = window.matchMedia("(pointer: fine)");
      mq.addEventListener("change", onChange);
      return () => mq.removeEventListener("change", onChange);
    },
    () => window.matchMedia("(pointer: fine)").matches,
    () => false,
  );
}

// Which column a phone shows, remembered in this browser (in memory when
// storage is blocked).
const columnListeners = new Set<() => void>();
let columnInMemory: Status | null = null;
function readColumn(): Status {
  try {
    const saved = window.localStorage.getItem(PHONE_COLUMN_KEY);
    if (saved === "open" || saved === "in_progress" || saved === "done") return saved;
  } catch {
    // Storage blocked (private mode).
  }
  return columnInMemory ?? "open";
}
function usePhoneColumn(): [Status, (s: Status) => void] {
  const value = useSyncExternalStore(
    (onChange) => {
      columnListeners.add(onChange);
      window.addEventListener("storage", onChange);
      return () => {
        columnListeners.delete(onChange);
        window.removeEventListener("storage", onChange);
      };
    },
    readColumn,
    () => "open" as Status,
  );
  const set = (s: Status) => {
    columnInMemory = s;
    try {
      window.localStorage.setItem(PHONE_COLUMN_KEY, s);
    } catch {
      // Not remembered beyond this page; fine.
    }
    columnListeners.forEach((l) => l());
  };
  return [value, set];
}

/** My Work as a board: To do, In progress, Done. Phones show one column at a time. */
export function TaskBoard({
  tasks,
  currentUserId,
  people,
  canAssign,
  emptyMessage,
}: {
  tasks: BoardTask[];
  currentUserId: string;
  people: Person[];
  canAssign: boolean;
  /** What an empty board says when filters hide everything. */
  emptyMessage?: string;
}) {
  const [moved, setMoved] = useState<Record<string, Status>>({});
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<Status | null>(null);
  const [openId, setOpenId] = useState<string | null>(null);
  const [showAllDone, setShowAllDone] = useState(false);
  const [phoneColumn, choosePhoneColumn] = usePhoneColumn();
  const [error, setError] = useState<string | null>(null);
  const [, start] = useTransition();
  const router = useRouter();
  const fine = useFinePointer();

  const statusOf = (t: BoardTask) => moved[t.id] ?? t.status;
  function move(id: string, status: Status, opts: { undo?: boolean } = {}) {
    const task = tasks.find((t) => t.id === id);
    if (!task) return;
    const from = statusOf(task);
    // Undo comes from a toast made earlier, so it skips the "already there" check.
    if (from === status && !opts.undo) return;
    setMoved((m) => ({ ...m, [id]: status }));
    setError(null);
    start(async () => {
      const res = await setTaskStatus({ id, status });
      if (!res.ok) {
        setError(res.error);
        toast.error(res.error);
        setMoved((m) => {
          const next = { ...m };
          delete next[id];
          return next;
        });
      } else if (!opts.undo) {
        toast.success(moveToast(status), {
          description: task.title,
          action:
            status === "done"
              ? { label: "Undo", onClick: () => move(id, from, { undo: true }) }
              : undefined,
        });
      } else {
        toast.success(`Moved back to ${STATUS_WORDS[status]}`, { description: task.title });
      }
      router.refresh();
    });
  }
  const open = tasks.find((t) => t.id === openId) ?? null;
  const shownColumns = COLUMNS.filter((c) => columnsToShow(tasks.length).includes(c.status));
  const byStatus = (s: Status) =>
    sortForColumn(
      tasks.filter((t) => statusOf(t) === s),
      s,
    );

  return (
    <div className="space-y-2">
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      {tasks.length > 0 && (
        <SegmentGroup label="Board column" className="flex w-full lg:hidden">
          {COLUMNS.map((col) => (
            <button
              key={col.status}
              type="button"
              aria-pressed={phoneColumn === col.status}
              onClick={() => choosePhoneColumn(col.status)}
              className={cn(segmentClass(phoneColumn === col.status), "flex-1 justify-center")}
            >
              {col.label}
              <span className="rounded-full px-1.5 text-xs tabular-nums opacity-80">
                {byStatus(col.status).length}
              </span>
            </button>
          ))}
        </SegmentGroup>
      )}
      <div className="grid gap-3 lg:grid-cols-3" aria-label="Task board">
        {shownColumns.map((col) => {
          const list = byStatus(col.status);
          const { shown, hidden } = visibleCards(list, col.status, showAllDone);
          return (
            <section
              key={col.status}
              aria-label={col.label}
              className={cn(
                "min-h-40 flex-col overflow-hidden rounded-lg border",
                col.body,
                tasks.length > 0 && phoneColumn !== col.status ? "hidden lg:flex" : "flex",
                over === col.status && "ring-primary ring-2",
              )}
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
                className={cn(
                  "flex items-center justify-between px-3 py-2 text-sm font-semibold",
                  col.head,
                )}
              >
                {col.label}
                <span className="rounded-full bg-white/25 px-2 text-xs tabular-nums">
                  {list.length}
                </span>
              </h3>
              <ul className="flex flex-1 flex-col gap-2 p-2">
                {tasks.length === 0 && (
                  <li className="bg-background text-muted-foreground rounded-md border border-dashed p-3 text-sm">
                    {emptyMessage ??
                      "Add your first task above, e.g. “Send the hall plan to the NEC by Friday”. Open a task to add subtasks, a deadline and files."}
                  </li>
                )}
                {tasks.length > 0 && list.length === 0 && (
                  <li className="text-muted-foreground p-3 text-center text-xs">
                    {fine ? "Nothing here — drag a task here to move it." : "Nothing here."}
                  </li>
                )}
                {shown.map((t) => (
                  <TaskCard
                    key={t.id}
                    task={t}
                    status={statusOf(t)}
                    currentUserId={currentUserId}
                    draggable={fine}
                    onOpen={() => setOpenId(t.id)}
                    onMove={(s) => move(t.id, s)}
                    onDragStart={() => setDragging(t.id)}
                  />
                ))}
                {hidden > 0 && (
                  <li>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full"
                      onClick={() => setShowAllDone(true)}
                    >
                      Show {hidden} more done
                    </Button>
                  </li>
                )}
                {col.status === "done" && showAllDone && list.length > 5 && (
                  <li>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full"
                      onClick={() => setShowAllDone(false)}
                    >
                      Show fewer
                    </Button>
                  </li>
                )}
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
  draggable,
  onOpen,
  onMove,
  onDragStart,
}: {
  task: BoardTask;
  status: Status;
  currentUserId: string;
  draggable: boolean;
  onOpen: () => void;
  onMove: (s: Status) => void;
  onDragStart: () => void;
}) {
  const doneSubs = task.subtasks.filter((s) => s.status === "done").length;
  const late = task.overdue && status !== "done";
  const lateSubs = task.overdueSubtasks > 0 && status !== "done";
  const primary = primaryMove(status);
  return (
    <li
      aria-label={task.title}
      draggable={draggable}
      onDragStart={(e) => {
        e.dataTransfer.setData("text/plain", task.id);
        e.dataTransfer.effectAllowed = "move";
        onDragStart();
      }}
      className={cn(
        "bg-background rounded-md border p-2.5 text-sm shadow-sm",
        draggable && "cursor-grab active:cursor-grabbing",
        (late || lateSubs) && "border-red-500 ring-1 ring-red-500",
        status === "done" && "opacity-80",
      )}
    >
      <button
        type="button"
        onClick={onOpen}
        className={cn(
          "w-full text-left font-medium hover:underline",
          status === "done" && "text-muted-foreground line-through decoration-1",
        )}
      >
        {task.title}
      </button>
      <div className="text-muted-foreground mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
        <span>
          {task.assignedToUserId === currentUserId ? "You" : task.assignedToName}
          {task.createdByUserId !== task.assignedToUserId && task.createdByUserId !== currentUserId
            ? ` · from ${task.createdByName}`
            : ""}
        </span>
        {task.entity ? (
          <Link
            href={task.entity.href}
            className="link inline-flex items-center gap-0.5"
            aria-label={`Open ${task.entity.ref}`}
          >
            {task.entity.ref}
            <ArrowUpRight className="size-3" aria-hidden />
          </Link>
        ) : (
          task.editionCode && <span title={task.editionName ?? undefined}>{task.editionCode}</span>
        )}
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
          className={cn(
            "mt-1.5 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-xs",
            late ? "bg-red-600 font-semibold text-white" : "text-muted-foreground bg-muted",
          )}
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
      {lateSubs && (
        <p className="mt-1 text-xs font-semibold text-red-600 dark:text-red-400">
          {task.overdueSubtasks} subtask{task.overdueSubtasks === 1 ? "" : "s"} overdue
        </p>
      )}
      <div className="mt-2 flex items-center gap-1">
        <Button
          size="sm"
          variant="outline"
          className="h-8 min-w-0 flex-1 sm:h-7 sm:flex-none"
          onClick={() => onMove(primary.to)}
          aria-label={`${primary.label}: ${task.title}`}
        >
          {primary.label}
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              size="icon"
              variant="ghost"
              className="size-8 sm:size-7"
              aria-label={`More for ${task.title}`}
            >
              <MoreHorizontal aria-hidden />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {otherMoves(status).map((m) => (
              <DropdownMenuItem key={m.to} onSelect={() => onMove(m.to)}>
                {m.label}
              </DropdownMenuItem>
            ))}
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={onOpen}>Open details…</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
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
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  return (
    <div className="space-y-1">
      {confirmDialog}
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
                onClick={async () => {
                  const ok = await confirm({
                    title: `Remove ${f.fileName}?`,
                    description: "The file is deleted from this task.",
                    confirmLabel: "Remove",
                    destructive: true,
                  });
                  if (!ok) return;
                  start(async () => {
                    const res = await deleteTaskAttachment({ id: f.id });
                    onError(res.ok ? null : res.error);
                    if (res.ok) toast.success(`Removed ${f.fileName}`);
                    router.refresh();
                  });
                }}
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
            if (res.ok) toast.success(`Attached ${file.name}`);
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
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const subForm = useRef<HTMLFormElement>(null);

  function run(
    fn: () => Promise<{ ok: boolean; error?: string; message?: string }>,
    after?: () => void,
  ) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) setError(res.error ?? "Something went wrong");
      else {
        if (res.message) toast.success(res.message, { description: task.title });
        after?.();
      }
      router.refresh();
    });
  }

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        {confirmDialog}
        <DialogHeader>
          <DialogTitle>{task.title}</DialogTitle>
          <DialogDescription>
            {STATUS_WORDS[status]} · for{" "}
            {task.assignedToUserId === currentUserId ? "you" : task.assignedToName}
            {task.createdByUserId !== task.assignedToUserId
              ? ` · set by ${task.createdByName}`
              : ""}
            {task.editionName ? ` · ${task.editionName}` : ""}
          </DialogDescription>
        </DialogHeader>

        {task.entity && (
          <p className="text-sm">
            About{" "}
            <Link href={task.entity.href} className="link">
              {task.entity.ref}
            </Link>
          </p>
        )}

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
            <div className="grid gap-1 text-sm">
              <label htmlFor={`assignee-${task.id}`} className="font-medium">
                Assigned to
              </label>
              <PersonPicker
                id={`assignee-${task.id}`}
                name="assignedToUserId"
                people={people}
                meId={currentUserId}
                defaultValue={task.assignedToUserId}
              />
              <UnavailableNote
                people={people}
                userId={task.assignedToUserId}
                what="work on this task"
              />
            </div>
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
              {pending ? "Saving…" : "Save changes"}
            </Button>
            {task.canDelete && (
              <Button
                type="button"
                variant="ghost"
                disabled={pending}
                onClick={async () => {
                  const ok = await confirm({
                    title: `Delete “${task.title}”?`,
                    description:
                      task.subtasks.length > 0
                        ? `Its ${task.subtasks.length} subtask${task.subtasks.length === 1 ? "" : "s"} and files are deleted too.`
                        : "The task and its files are deleted.",
                    confirmLabel: "Delete",
                    destructive: true,
                  });
                  if (ok) run(() => deleteTask({ id: task.id }), onClose);
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
                className={cn(
                  "space-y-1 px-3 py-2 text-sm",
                  s.overdue && "bg-red-50 dark:bg-red-950/40",
                )}
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
                  <span className={cn("flex-1", s.status === "done" && "line-through opacity-60")}>
                    {s.title}
                  </span>
                  {s.dueDate && (
                    <span
                      className={cn(
                        "rounded px-1.5 py-0.5 text-xs",
                        s.overdue ? "bg-red-600 font-semibold text-white" : "text-muted-foreground",
                      )}
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
                    onClick={async () => {
                      const ok = await confirm({
                        title: `Delete the subtask “${s.title}”?`,
                        description:
                          s.attachments.length > 0 ? "Its files are deleted too." : undefined,
                        confirmLabel: "Delete",
                        destructive: true,
                      });
                      if (ok) run(() => deleteTask({ id: s.id }));
                    }}
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
            className="grid grid-cols-[1fr_auto] gap-2 sm:flex sm:flex-wrap"
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
              className="col-span-2 h-9 min-w-40 flex-1"
              required
            />
            <Input
              name="dueDate"
              type="date"
              aria-label="Subtask deadline"
              className="h-9 w-full sm:w-40"
            />
            <Button type="submit" size="sm" className="h-9" disabled={pending}>
              Add
            </Button>
          </form>
        </section>
        {error && (
          <p role="alert" className="text-destructive text-sm">
            {error}
          </p>
        )}
      </DialogContent>
    </Dialog>
  );
}
