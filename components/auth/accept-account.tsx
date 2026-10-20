"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { completeAccount } from "@/app/actions/auth";

/**
 * Name and password for someone an email link has just signed in for the
 * first time (app/auth/accept/page.tsx checks the session first).
 */
export function AcceptAccount({ email, name }: { email: string; name: string }) {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        setError(null);
        if (f.get("password") !== f.get("confirm")) {
          setError("The two passwords don't match");
          return;
        }
        start(async () => {
          const res = await completeAccount({
            fullName: f.get("fullName"),
            password: f.get("password"),
            confirm: f.get("confirm"),
          });
          if (res && !res.ok) setError(res.error);
        });
      }}
    >
      <p className="text-muted-foreground text-sm">
        You&apos;re setting up the account for{" "}
        <span className="text-foreground font-medium">{email}</span>.
      </p>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Your name</span>
        <Input name="fullName" defaultValue={name} autoComplete="name" required />
      </label>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Choose a password</span>
        <PasswordInput name="password" autoComplete="new-password" minLength={8} required />
        <span className="text-muted-foreground block text-xs">At least 8 characters.</span>
      </label>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Type it again</span>
        <PasswordInput name="confirm" autoComplete="new-password" required />
      </label>
      <Button type="submit" className="w-full" disabled={pending}>
        Create my account
      </Button>
      {error && <p className="text-destructive text-sm">{error}</p>}
    </form>
  );
}
