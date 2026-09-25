"use client";

import Link from "next/link";
import { useEffect, useState, useTransition } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { completeAccount } from "@/app/actions/auth";

type State =
  | { step: "checking" }
  | { step: "form"; email: string; name: string }
  | { step: "error"; message: string };

/**
 * Reads the session Supabase put in the invitation link (#access_token…),
 * stores it as cookies, then asks for name and password.
 */
export function AcceptAccount({
  supabaseUrl,
  supabaseKey,
}: {
  supabaseUrl: string;
  supabaseKey: string;
}) {
  const [state, setState] = useState<State>({ step: "checking" });
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  useEffect(() => {
    if (!supabaseUrl || !supabaseKey) {
      void Promise.resolve().then(() =>
        setState({ step: "error", message: "Sign-in isn't set up on this site." }),
      );
      return;
    }
    const supabase = createBrowserClient(supabaseUrl, supabaseKey);
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    const failure = hash.get("error_description");
    const accessToken = hash.get("access_token");
    const refreshToken = hash.get("refresh_token");
    // Keep tokens out of the address bar and history.
    if (window.location.hash) {
      window.history.replaceState(null, "", window.location.pathname);
    }
    (async () => {
      if (failure) {
        setState({
          step: "error",
          message: /expired|invalid/i.test(failure)
            ? "This link has expired or was already used. Ask your admin to send the invitation again."
            : failure,
        });
        return;
      }
      if (accessToken && refreshToken) {
        const { error: sessionError } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
        if (sessionError) {
          setState({
            step: "error",
            message: "This link has expired. Ask your admin to send the invitation again.",
          });
          return;
        }
      }
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user?.email) {
        setState({
          step: "error",
          message: "Open this page from the invitation email we sent you.",
        });
        return;
      }
      const meta = (user.user_metadata ?? {}) as { full_name?: string };
      setState({ step: "form", email: user.email, name: meta.full_name ?? "" });
    })();
  }, [supabaseUrl, supabaseKey]);

  if (state.step === "checking") {
    return <p className="text-muted-foreground text-center text-sm">Checking your invitation…</p>;
  }
  if (state.step === "error") {
    return (
      <div className="space-y-3 text-center">
        <p className="text-destructive text-sm">{state.message}</p>
        <Link href="/login" className="text-sm underline">
          Go to sign in
        </Link>
      </div>
    );
  }
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
        <span className="text-foreground font-medium">{state.email}</span>.
      </p>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Your name</span>
        <Input name="fullName" defaultValue={state.name} autoComplete="name" required />
      </label>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Choose a password</span>
        <Input name="password" type="password" autoComplete="new-password" minLength={8} required />
        <span className="text-muted-foreground block text-xs">At least 8 characters.</span>
      </label>
      <label className="block space-y-1.5">
        <span className="text-sm font-medium">Type it again</span>
        <Input name="confirm" type="password" autoComplete="new-password" required />
      </label>
      <Button type="submit" className="w-full" disabled={pending}>
        Create my account
      </Button>
      {error && <p className="text-destructive text-sm">{error}</p>}
    </form>
  );
}
