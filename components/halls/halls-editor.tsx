"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  createHall,
  createLocation,
  deleteHall,
  deleteLocation,
  renameHall,
  renameLocation,
} from "@/app/actions/halls";

export type HallRow = {
  id: string;
  name: string;
  locations: { id: string; name: string; zone: string | null; itemCount: number }[];
  itemCount: number;
};

type Result = { ok: boolean; error?: string };

function useAction() {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  function run(fn: () => Promise<Result>, onDone?: () => void) {
    setError(null);
    start(async () => {
      const res = await fn();
      if (!res.ok) setError(res.error ?? "Something went wrong");
      else {
        onDone?.();
        router.refresh();
      }
    });
  }
  return { error, pending, run };
}

function InlineAdd({
  placeholder,
  label,
  onAdd,
}: {
  placeholder: string;
  label: string;
  onAdd: (name: string) => Promise<Result>;
}) {
  const [value, setValue] = useState("");
  const { error, pending, run } = useAction();
  return (
    <form
      className="flex flex-wrap items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        if (!value.trim()) return;
        run(() => onAdd(value), () => setValue(""));
      }}
    >
      <Input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={placeholder}
        aria-label={label}
        className="h-9 min-w-0 flex-1 sm:max-w-xs"
      />
      <Button type="submit" size="sm" variant="outline" disabled={pending || !value.trim()}>
        <Plus className="size-4" /> {label}
      </Button>
      {error && <p className="text-destructive w-full text-sm">{error}</p>}
    </form>
  );
}

function RenameDelete({
  name,
  onRename,
  onDelete,
  deleteLabel,
}: {
  name: string;
  onRename: (name: string) => Promise<Result>;
  onDelete: () => Promise<Result>;
  deleteLabel: string;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(name);
  const { error, pending, run } = useAction();
  if (editing) {
    return (
      <form
        className="flex flex-wrap items-center gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          run(() => onRename(value), () => setEditing(false));
        }}
      >
        <Input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          aria-label={`New name for ${name}`}
          className="h-8 w-48"
          autoFocus
        />
        <Button type="submit" size="sm" disabled={pending}>
          Save
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>
          Cancel
        </Button>
        {error && <span className="text-destructive text-xs">{error}</span>}
      </form>
    );
  }
  return (
    <span className="inline-flex items-center gap-1">
      <Button
        size="sm"
        variant="ghost"
        aria-label={`Rename ${name}`}
        onClick={() => setEditing(true)}
      >
        <Pencil className="size-3.5" />
      </Button>
      <Button
        size="sm"
        variant="ghost"
        aria-label={`${deleteLabel} ${name}`}
        disabled={pending}
        onClick={() => {
          if (window.confirm(`${deleteLabel} "${name}"?`)) run(onDelete);
        }}
      >
        <Trash2 className="size-3.5" />
      </Button>
      {error && <span className="text-destructive text-xs">{error}</span>}
    </span>
  );
}

export function HallsEditor({
  editionId,
  halls,
  canEdit,
}: {
  editionId: string;
  halls: HallRow[];
  canEdit: boolean;
}) {
  return (
    <div className="space-y-4">
      {halls.length === 0 && (
        <p className="text-muted-foreground rounded-lg border border-dashed p-4 text-sm">
          No halls yet. Add the halls for this show, then the locations inside each one (e.g.
          &ldquo;Main entrance&rdquo;, &ldquo;Aisle A&rdquo;). Signs are placed at a location.
        </p>
      )}
      {halls.map((hall) => (
        <section key={hall.id} className="rounded-lg border p-4">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <h2 className="text-sm font-semibold">{hall.name}</h2>
            <span className="text-muted-foreground text-xs">
              {hall.locations.length} location{hall.locations.length === 1 ? "" : "s"} ·{" "}
              {hall.itemCount} item{hall.itemCount === 1 ? "" : "s"}
            </span>
            {canEdit && (
              <span className="ml-auto">
                <RenameDelete
                  name={hall.name}
                  deleteLabel="Remove hall"
                  onRename={(name) => renameHall({ id: hall.id, name })}
                  onDelete={() => deleteHall({ id: hall.id })}
                />
              </span>
            )}
          </div>
          <ul className="divide-y">
            {hall.locations.map((loc) => (
              <li key={loc.id} className="flex flex-wrap items-center gap-2 py-1.5 text-sm">
                <span>{loc.name}</span>
                {loc.zone && <span className="text-muted-foreground text-xs">· {loc.zone}</span>}
                <span className="text-muted-foreground text-xs">
                  · {loc.itemCount} item{loc.itemCount === 1 ? "" : "s"}
                </span>
                {canEdit && (
                  <span className="ml-auto">
                    <RenameDelete
                      name={loc.name}
                      deleteLabel="Remove location"
                      onRename={(name) => renameLocation({ id: loc.id, name })}
                      onDelete={() => deleteLocation({ id: loc.id })}
                    />
                  </span>
                )}
              </li>
            ))}
          </ul>
          {canEdit && (
            <div className="mt-2">
              <InlineAdd
                placeholder="e.g. Main entrance"
                label="Add location"
                onAdd={(name) => createLocation({ hallId: hall.id, name })}
              />
            </div>
          )}
        </section>
      ))}
      {canEdit && (
        <div className="rounded-lg border border-dashed p-4">
          <InlineAdd
            placeholder="e.g. Hall 3"
            label="Add hall"
            onAdd={(name) => createHall({ editionId, name })}
          />
        </div>
      )}
    </div>
  );
}
