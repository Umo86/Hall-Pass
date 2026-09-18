"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { KIND_LABELS, MUTABLE_KINDS, type MutableKind } from "@/lib/notification-kinds";
import { updateNotificationPrefs } from "@/app/actions/notifications";

export function NotificationPrefsForm({ initial }: { initial: Record<string, boolean> }) {
  const [prefs, setPrefs] = useState<Record<MutableKind, boolean>>(() =>
    Object.fromEntries(MUTABLE_KINDS.map((k) => [k, initial[k] !== false])) as Record<
      MutableKind,
      boolean
    >,
  );
  const [pending, start] = useTransition();
  const [message, setMessage] = useState<string | null>(null);

  function save() {
    setMessage(null);
    start(async () => {
      const res = await updateNotificationPrefs(prefs);
      setMessage(res.ok ? "Saved" : res.error);
    });
  }

  return (
    <div className="max-w-md">
      <ul className="space-y-2">
        {MUTABLE_KINDS.map((kind) => (
          <li key={kind}>
            <label className="flex items-center justify-between gap-3 rounded-md border px-3 py-2 text-sm">
              <span>{KIND_LABELS[kind]}</span>
              <input
                type="checkbox"
                checked={prefs[kind]}
                onChange={(e) => setPrefs((p) => ({ ...p, [kind]: e.target.checked }))}
                className="size-4 accent-indigo-600"
              />
            </label>
          </li>
        ))}
      </ul>
      <div className="mt-3 flex items-center gap-3">
        <Button size="sm" disabled={pending} onClick={save}>
          Save preferences
        </Button>
        {message && <span className="text-muted-foreground text-sm">{message}</span>}
      </div>
    </div>
  );
}
