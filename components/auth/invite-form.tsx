"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { acceptInvite } from "@/app/actions/invites";

export function InviteForm({
  token,
  invitedEmail,
  initialName = "",
  needsPassword = true,
}: {
  token: string;
  invitedEmail: string;
  /** Carried back through the sign-in link so nobody types it twice. */
  initialName?: string;
  /** False when already signed in as the invited email. */
  needsPassword?: boolean;
}) {
  const [fullName, setFullName] = useState(initialName);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        if (needsPassword && password !== confirm) {
          setError("The two passwords don't match");
          return;
        }
        startTransition(async () => {
          const res = await acceptInvite({
            token,
            fullName,
            ...(needsPassword ? { password, confirm } : {}),
          });
          if (res && !res.ok) setError(res.error);
          if (res && res.ok && res.message) setMessage(res.message);
        });
      }}
    >
      <p className="text-muted-foreground text-sm">
        This invitation was sent to <span className="font-medium">{invitedEmail}</span>.
        {needsPassword ? " Set up your profile to get started." : ""}
      </p>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Your name</span>
        <Input
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          autoComplete="name"
          required
        />
      </label>
      {needsPassword && (
        <>
          <label className="block space-y-1.5">
            <span className="text-sm font-medium">Choose a password</span>
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="new-password"
              minLength={8}
              required
            />
            <span className="text-muted-foreground block text-xs">At least 8 characters.</span>
          </label>
          <label className="block space-y-1.5">
            <span className="text-sm font-medium">Type it again</span>
            <Input
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              autoComplete="new-password"
              required
            />
          </label>
        </>
      )}
      <Button type="submit" className="w-full" disabled={pending}>
        {needsPassword ? "Create my account" : "Accept invitation"}
      </Button>
      {message && <p className="text-sm text-green-700 dark:text-green-400">{message}</p>}
      {error && <p className="text-destructive text-sm">{error}</p>}
      {needsPassword && (
        <p className="text-muted-foreground text-center text-xs">
          Already have an account?{" "}
          <Link
            href={`/login?next=${encodeURIComponent(`/invite/${token}`)}`}
            className="underline"
          >
            Sign in first
          </Link>
        </p>
      )}
    </form>
  );
}
