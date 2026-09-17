"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { devSignIn, signInWithMagicLink, signInWithPassword } from "@/app/actions/auth";

type Props = {
  supabaseEnabled: boolean;
  devEnabled: boolean;
  devUsers: { email: string; label: string }[];
};

export function LoginForm({ supabaseEnabled, devEnabled, devUsers }: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [mode, setMode] = useState<"magic" | "password">("magic");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function submit(fn: () => Promise<{ ok: boolean; message?: string; error?: string } | void>) {
    setError(null);
    setMessage(null);
    startTransition(async () => {
      const res = await fn();
      if (res && !res.ok && res.error) setError(res.error);
      if (res && res.ok && res.message) setMessage(res.message);
    });
  }

  if (!supabaseEnabled && !devEnabled) {
    return (
      <p className="text-muted-foreground text-center text-sm">
        Sign-in is unavailable: authentication has not been configured for this deployment. Set the
        Supabase environment variables (or DEV_AUTH=1 with a seeded database) and redeploy.
      </p>
    );
  }

  return (
    <div className="space-y-4">
      {supabaseEnabled && (
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            submit(() =>
              mode === "magic"
                ? signInWithMagicLink({ email })
                : signInWithPassword({ email, password }),
            );
          }}
        >
          <label className="block space-y-1.5">
            <span className="text-sm font-medium">Email address</span>
            <Input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              placeholder="you@example.com"
              required
            />
          </label>
          {mode === "password" && (
            <label className="block space-y-1.5">
              <span className="text-sm font-medium">Password</span>
              <Input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
            </label>
          )}
          <Button type="submit" className="w-full" disabled={pending}>
            {mode === "magic" ? "Send magic link" : "Sign in"}
          </Button>
          <button
            type="button"
            className="text-muted-foreground w-full text-center text-xs underline-offset-2 hover:underline"
            onClick={() => setMode(mode === "magic" ? "password" : "magic")}
          >
            {mode === "magic" ? "Use a password instead" : "Use a magic link instead"}
          </button>
        </form>
      )}

      {devEnabled && (
        <div className="space-y-3">
          {supabaseEnabled && <Separator />}
          <p className="text-muted-foreground text-xs">
            Development sign-in — assume a seeded user:
          </p>
          <div className="grid grid-cols-2 gap-2">
            {devUsers.map((u) => (
              <Button
                key={u.email}
                variant="outline"
                size="sm"
                disabled={pending}
                onClick={() => submit(() => devSignIn({ email: u.email }))}
              >
                {u.label}
              </Button>
            ))}
          </div>
          <form
            className="flex gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              submit(() => devSignIn({ email }));
            }}
          >
            <Input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="email@media10.test"
            />
            <Button type="submit" variant="secondary" disabled={pending}>
              Sign in
            </Button>
          </form>
        </div>
      )}

      {message && <p className="text-sm text-green-700 dark:text-green-400">{message}</p>}
      {error && <p className="text-destructive text-sm">{error}</p>}
    </div>
  );
}
