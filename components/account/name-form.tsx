"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { updateMyName } from "@/app/actions/account";

export function NameForm({ initial }: { initial: string }) {
  const [name, setName] = useState(initial);
  const [pending, start] = useTransition();
  return (
    <form
      className="flex max-w-md flex-col gap-2 sm:flex-row sm:items-end"
      onSubmit={(e) => {
        e.preventDefault();
        start(async () => {
          const res = await updateMyName({ fullName: name });
          if (res.ok) toast.success(res.message ?? "Saved");
          else toast.error(res.error);
        });
      }}
    >
      <div className="flex-1 space-y-1.5">
        <Label htmlFor="account-name">Your name</Label>
        <Input
          id="account-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          maxLength={120}
          autoComplete="name"
        />
      </div>
      <Button type="submit" disabled={pending || name.trim() === initial.trim()}>
        {pending ? "Saving…" : "Save"}
      </Button>
    </form>
  );
}
