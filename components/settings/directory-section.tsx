"use client";

import { useId, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { saveDirectoryEntry } from "@/app/actions/directory";

export type DirectoryField = {
  key: string;
  label: string;
  type?: "text" | "email" | "date" | "tel";
  required?: boolean;
  placeholder?: string;
  autoComplete?: string;
};

export type DirectoryRow = { id: string } & Record<string, string | null>;

/**
 * Add or edit one entry of a small list (venue, event series, install
 * contractor): a dialog of plain fields, a toast naming it when saved, and
 * the error read out when it isn't.
 */
export function DirectoryDialog({
  type,
  noun,
  fields,
  current,
  open,
  onClose,
  onArchive,
  extra,
  description = "Fields marked (optional) can be left blank.",
}: {
  type: "event" | "venue" | "contractor";
  /** "venue", "install contractor"… (lower case; used in the title). */
  noun: string;
  fields: DirectoryField[];
  /** The row being edited, or null to add one. */
  current: DirectoryRow | null;
  open: boolean;
  onClose: () => void;
  /** Offers "Archive" in the footer when editing (the caller confirms and archives). */
  onArchive?: (row: DirectoryRow) => void;
  /** Shown under the fields when editing (e.g. portal access for a venue). */
  extra?: React.ReactNode;
  description?: string;
}) {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const ids = useId();
  const errorId = `${ids}-error`;

  function close() {
    setError(null);
    onClose();
  }

  return (
    <Dialog open={open} onOpenChange={(o) => !o && close()}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {current
              ? `Edit ${current.name ?? noun}`
              : `Add ${/^[aeiou]/i.test(noun) ? "an" : "a"} ${noun}`}
          </DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <form
          key={current?.id ?? "new"}
          className="grid gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            const values = Object.fromEntries(fields.map((f) => [f.key, fd.get(f.key) ?? ""]));
            setError(null);
            start(async () => {
              const res = await saveDirectoryEntry({ type, id: current?.id, values });
              if (!res.ok) {
                setError(res.error);
                return;
              }
              toast.success(res.message ?? "Saved");
              close();
              router.refresh();
            });
          }}
        >
          {fields.map((f) => (
            <div key={f.key} className="space-y-1.5">
              <Label htmlFor={`${ids}-${f.key}`}>
                {f.label}
                {!f.required && (
                  <span className="text-muted-foreground font-normal"> (optional)</span>
                )}
              </Label>
              <Input
                id={`${ids}-${f.key}`}
                name={f.key}
                type={f.type ?? "text"}
                required={f.required}
                placeholder={f.placeholder}
                autoComplete={f.autoComplete ?? "off"}
                defaultValue={current?.[f.key] ?? ""}
                aria-describedby={error ? errorId : undefined}
                className="h-11 sm:h-9"
              />
            </div>
          ))}
          {current && extra}
          {error && (
            <p id={errorId} role="alert" className="text-destructive text-sm">
              {error}
            </p>
          )}
          <DialogFooter className="gap-2">
            {current && onArchive && (
              <Button
                type="button"
                variant="ghost"
                className="sm:mr-auto"
                disabled={pending}
                onClick={() => onArchive(current)}
              >
                Archive
              </Button>
            )}
            <Button type="button" variant="outline" onClick={close}>
              Cancel
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
