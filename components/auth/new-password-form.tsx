"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { updatePassword } from "@/app/actions/auth";

export function NewPasswordForm() {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        setError(null);
        start(async () => {
          const res = await updatePassword({ password: f.get("password"), confirm: f.get("confirm") });
          if (res && !res.ok) setError(res.error);
        });
      }}
    >
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">New password</span>
        <Input name="password" type="password" autoComplete="new-password" minLength={8} required />
        <span className="text-muted-foreground block text-xs">At least 8 characters.</span>
      </label>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Type it again</span>
        <Input name="confirm" type="password" autoComplete="new-password" required />
      </label>
      <Button type="submit" className="w-full" disabled={pending}>
        Save password
      </Button>
      {error && <p className="text-destructive text-sm">{error}</p>}
    </form>
  );
}
