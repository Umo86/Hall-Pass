"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { acceptInvite } from "@/app/actions/invites";

export function InviteForm({ token, invitedEmail }: { token: string; invitedEmail: string }) {
  const [fullName, setFullName] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        startTransition(async () => {
          const res = await acceptInvite({ token, fullName });
          if (res && !res.ok) setError(res.error);
          if (res && res.ok && res.message) setMessage(res.message);
        });
      }}
    >
      <p className="text-muted-foreground text-sm">
        This invitation was sent to <span className="font-medium">{invitedEmail}</span>.
      </p>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Your name</span>
        <Input value={fullName} onChange={(e) => setFullName(e.target.value)} required />
      </label>
      <Button type="submit" className="w-full" disabled={pending}>
        Accept invitation
      </Button>
      {message && <p className="text-sm text-green-700 dark:text-green-400">{message}</p>}
      {error && <p className="text-destructive text-sm">{error}</p>}
    </form>
  );
}
