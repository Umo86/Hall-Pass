"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { PasswordInput } from "@/components/ui/password-input";
import { changeMyPassword } from "@/app/actions/account";

/**
 * My account → Password: change it (the current one is asked for) or, for
 * someone who only ever signed in by email link, set one. Every other
 * device is signed out; this one stays signed in.
 */
export function PasswordForm({ hasPassword }: { hasPassword: boolean }) {
  const [current, setCurrent] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <form
      className="max-w-md space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        if (password !== confirm) {
          setError("The two passwords don't match");
          return;
        }
        start(async () => {
          const res = await changeMyPassword({
            ...(hasPassword ? { currentPassword: current } : {}),
            password,
            confirm,
          });
          if (!res.ok) {
            setError(res.error);
            return;
          }
          toast.success(res.message ?? "Password changed");
          setCurrent("");
          setPassword("");
          setConfirm("");
          router.refresh();
        });
      }}
    >
      {hasPassword && (
        <div className="space-y-1.5">
          <Label htmlFor="account-current-password">Current password</Label>
          <PasswordInput
            id="account-current-password"
            value={current}
            onChange={(e) => setCurrent(e.target.value)}
            autoComplete="current-password"
            maxLength={200}
            required
          />
        </div>
      )}
      <div className="space-y-1.5">
        <Label htmlFor="account-new-password">
          {hasPassword ? "New password" : "Choose a password"}
        </Label>
        <PasswordInput
          id="account-new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
          minLength={8}
          maxLength={200}
          required
        />
        <p className="text-muted-foreground text-xs">At least 8 characters.</p>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="account-confirm-password">Type it again</Label>
        <PasswordInput
          id="account-confirm-password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          autoComplete="new-password"
          maxLength={200}
          required
        />
      </div>
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? "Saving…" : hasPassword ? "Change password" : "Set password"}
      </Button>
    </form>
  );
}
