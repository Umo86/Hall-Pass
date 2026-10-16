"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { KIND_LABELS, MUTABLE_KINDS, type MutableKind } from "@/lib/notification-kinds";
import { updateNotificationPrefs } from "@/app/actions/notifications";
import { NOTIFICATION_GROUPS } from "./notification-groups";

type Prefs = Record<MutableKind, boolean>;

/** My account → Notifications: what you hear about, in four groups. */
export function NotificationPrefsForm({ initial }: { initial: Record<string, boolean> }) {
  const start0 = () =>
    Object.fromEntries(MUTABLE_KINDS.map((k) => [k, initial[k] !== false])) as Prefs;
  const [prefs, setPrefs] = useState<Prefs>(start0);
  const [saved, setSaved] = useState<Prefs>(start0);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const dirty = MUTABLE_KINDS.some((k) => prefs[k] !== saved[k]);

  function save() {
    setError(null);
    start(async () => {
      const res = await updateNotificationPrefs(prefs);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setSaved(prefs);
      toast.success(res.message ?? "Notification preferences saved");
    });
  }

  return (
    <form
      className="space-y-5"
      onSubmit={(e) => {
        e.preventDefault();
        save();
      }}
    >
      {NOTIFICATION_GROUPS.map((g) => (
        <fieldset key={g.id} className="space-y-2">
          <legend className="mb-1 text-sm font-medium">{g.label}</legend>
          <ul className="divide-y rounded-md border">
            {g.kinds.map((kind) => (
              <li key={kind}>
                <label className="flex min-h-11 cursor-pointer items-center justify-between gap-3 px-3 py-2 text-sm">
                  <span>{KIND_LABELS[kind]}</span>
                  <input
                    type="checkbox"
                    checked={prefs[kind]}
                    onChange={(e) => setPrefs((p) => ({ ...p, [kind]: e.target.checked }))}
                    className="size-4 shrink-0 accent-indigo-600"
                  />
                </label>
              </li>
            ))}
          </ul>
        </fieldset>
      ))}
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={pending || !dirty}>
          {pending ? "Saving…" : "Save preferences"}
        </Button>
        {!dirty && !pending && (
          <span className="text-muted-foreground text-sm" aria-live="polite">
            No unsaved changes
          </span>
        )}
      </div>
    </form>
  );
}
