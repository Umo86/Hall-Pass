"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { ArrowLeft, Building2, Check, UserRound, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { AccentRule, Wordmark } from "@/components/wordmark";
import { Input } from "@/components/ui/input";
import {
  devSignIn,
  sendPasswordReset,
  signInWithMagicLink,
  signInWithPassword,
  signOut,
} from "@/app/actions/auth";
import { Scene } from "@/components/scene";

export type DevUser = {
  email: string;
  name: string;
  role: string;
  isExternal: boolean;
};

export type ConfigStatus = {
  supabaseUrl: boolean;
  supabaseKey: boolean;
  databaseUrl: boolean;
  databaseReachable: boolean;
  databaseError: string | null;
  devAuth: boolean;
};

type Props = {
  brandName: string;
  supabaseEnabled: boolean;
  devEnabled: boolean;
  devUsers: DevUser[];
  configStatus: ConfigStatus;
  photo: string | null;
  /** Where to continue after signing in. */
  next?: string | null;
  /** A problem to explain, e.g. an expired sign-in link. */
  notice?: string | null;
  /** Signed in with Supabase, but this email has no account here yet. */
  unprovisionedEmail?: string | null;
};

export function LoginCard({
  brandName,
  supabaseEnabled,
  devEnabled,
  devUsers,
  configStatus,
  photo,
  next = null,
  notice = null,
  unprovisionedEmail = null,
}: Props) {
  const configured = supabaseEnabled || (devEnabled && devUsers.length > 0);

  return (
    <div className="bg-muted/40 flex min-h-screen flex-col">
      <div className="mx-auto flex w-full max-w-5xl items-center px-6 py-5">
        <Link
          href="/"
          className="text-muted-foreground hover:text-foreground flex items-center gap-2 text-sm"
        >
          <ArrowLeft className="size-4" aria-hidden /> <Wordmark name={brandName} size="sm" />
        </Link>
      </div>

      <div className="flex flex-1 items-start justify-center px-4 pt-6 pb-16 sm:items-center sm:pt-0">
        <div className="bg-background grid w-full max-w-4xl overflow-hidden rounded-xl border shadow-sm md:grid-cols-[2fr_3fr]">
          <aside className="bg-sidebar hidden flex-col justify-between border-r p-8 md:flex">
            <div>
              <Wordmark name={brandName} />
              <AccentRule className="mt-3 w-16" />
              <h1 className="mt-6 text-2xl font-semibold tracking-tight text-balance">
                Sign in to your schedule
              </h1>
              <ul className="text-muted-foreground mt-6 space-y-3 text-sm leading-relaxed">
                <li>Approvals waiting on you, across every edition</li>
                <li>Artwork locked by version and hash at every decision</li>
                <li>One portal for venues, suppliers, sponsors and exhibitors</li>
              </ul>
            </div>
            <div>
              <Scene
                kind="hall"
                photo={photo}
                alt="Crew installing event signage in an exhibition hall"
                className="mb-4"
              />
              <p className="text-muted-foreground text-xs">
                Access is by invitation from the operations team.
              </p>
            </div>
          </aside>

          <main className="p-6 sm:p-8">
            <div className="md:hidden">
              <Wordmark name={brandName} />
              <h1 className="mt-2 mb-6 text-xl font-semibold tracking-tight">Sign in</h1>
            </div>
            {notice && (
              <p className="mb-4 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
                {notice}
              </p>
            )}
            {unprovisionedEmail ? (
              <div className="mx-auto max-w-sm space-y-3 text-sm">
                <h2 className="text-lg font-semibold tracking-tight">
                  Your account isn&apos;t set up yet
                </h2>
                <p className="text-muted-foreground">
                  You&apos;re signed in as <strong>{unprovisionedEmail}</strong>, but nobody has
                  invited that address yet. Ask an admin to invite it, then sign in again.
                </p>
                <form action={signOut}>
                  <Button type="submit" variant="outline">
                    Sign out
                  </Button>
                </form>
              </div>
            ) : !configured ? (
              <SetupPanel status={configStatus} />
            ) : devEnabled && devUsers.length > 0 ? (
              <DevSignIn users={devUsers} supabaseEnabled={supabaseEnabled} next={next} />
            ) : (
              <EmailSignIn next={next} />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

function EmailSignIn({ next }: { next: string | null }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [mode, setMode] = useState<"password" | "magic" | "reset">("password");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  return (
    <div className="mx-auto max-w-sm">
      <h2 className="hidden text-lg font-semibold tracking-tight md:block">Welcome back</h2>
      <p className="text-muted-foreground mt-1 mb-6 hidden text-sm md:block">
        Use the email your invitation was sent to.
      </p>
      <form
        className="space-y-4"
        onSubmit={(e) => {
          e.preventDefault();
          setError(null);
          setMessage(null);
          start(async () => {
            const res =
              mode === "magic"
                ? await signInWithMagicLink({ email, next: next ?? undefined })
                : mode === "reset"
                  ? await sendPasswordReset({ email })
                  : await signInWithPassword({ email, password, next: next ?? undefined });
            if (res && !res.ok) setError(res.error);
            if (res && res.ok && res.message) setMessage(res.message);
          });
        }}
      >
        <div className="space-y-1.5">
          <label htmlFor="email" className="text-sm font-medium">
            Email address
          </label>
          <Input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            placeholder="you@company.com"
            required
          />
        </div>
        {mode === "password" && (
          <div className="space-y-1.5">
            <div className="flex items-baseline justify-between">
              <label htmlFor="password" className="text-sm font-medium">
                Password
              </label>
              <button
                type="button"
                className="text-muted-foreground hover:text-foreground text-xs underline-offset-2 hover:underline"
                onClick={() => {
                  setMode("reset");
                  setError(null);
                  setMessage(null);
                }}
              >
                Forgot password?
              </button>
            </div>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </div>
        )}
        <Button type="submit" className="w-full" disabled={pending}>
          {mode === "magic"
            ? "Email me a link"
            : mode === "reset"
              ? "Email me a link to reset it"
              : "Sign in"}
        </Button>
        {mode === "reset" && (
          <p className="text-muted-foreground text-xs">
            We&apos;ll email you a link to choose a new password.
          </p>
        )}
        <button
          type="button"
          className="text-muted-foreground hover:text-foreground w-full text-center text-xs underline-offset-2 hover:underline"
          onClick={() => {
            setMode(mode === "password" ? "magic" : "password");
            setError(null);
            setMessage(null);
          }}
        >
          {mode === "password"
            ? "First time here, or no password yet? Email me a link"
            : "Sign in with my password"}
        </button>
        {message && <p className="text-sm text-emerald-700 dark:text-emerald-400">{message}</p>}
        {error && <p className="text-destructive text-sm">{error}</p>}
      </form>
      <p className="text-muted-foreground mt-6 text-xs leading-relaxed">
        No account yet? Ask your admin to invite you — the invitation email has a link to set up
        your profile and password.
      </p>
    </div>
  );
}

function DevSignIn({
  users,
  supabaseEnabled,
  next,
}: {
  users: DevUser[];
  supabaseEnabled: boolean;
  next: string | null;
}) {
  const [error, setError] = useState<string | null>(null);
  const [pendingEmail, setPendingEmail] = useState<string | null>(null);
  const [showEmail, setShowEmail] = useState(false);
  const [pending, start] = useTransition();
  const staff = users.filter((u) => !u.isExternal);
  const externals = users.filter((u) => u.isExternal);

  if (showEmail) {
    return (
      <div>
        <button
          className="text-muted-foreground hover:text-foreground mb-4 text-xs underline-offset-2 hover:underline"
          onClick={() => setShowEmail(false)}
        >
          ← Back to demo sign-in
        </button>
        <EmailSignIn next={next} />
      </div>
    );
  }

  function go(email: string) {
    setError(null);
    setPendingEmail(email);
    start(async () => {
      const res = await devSignIn({ email, next: next ?? undefined });
      if (res && !res.ok) {
        setError(res.error);
        setPendingEmail(null);
      }
    });
  }

  return (
    <div>
      <div className="mb-5 flex items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold tracking-tight">Choose who to sign in as</h2>
          <p className="text-muted-foreground mt-0.5 text-sm">
            Demo mode — every seeded role, one click.
          </p>
        </div>
        <span className="rounded-full border border-amber-300 bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-300">
          Demo
        </span>
      </div>

      <p className="text-muted-foreground mb-2 flex items-center gap-1.5 text-xs font-semibold tracking-wide uppercase">
        <Building2 className="size-3.5" aria-hidden /> Media10 staff
      </p>
      <div className="grid gap-1.5 sm:grid-cols-2">
        {staff.map((u) => (
          <PersonButton
            key={u.email}
            user={u}
            busy={pendingEmail === u.email}
            disabled={pending}
            onClick={() => go(u.email)}
          />
        ))}
      </div>

      {externals.length > 0 && (
        <>
          <p className="text-muted-foreground mt-5 mb-2 flex items-center gap-1.5 text-xs font-semibold tracking-wide uppercase">
            <UserRound className="size-3.5" aria-hidden /> External partners
          </p>
          <div className="grid gap-1.5 sm:grid-cols-2">
            {externals.map((u) => (
              <PersonButton
                key={u.email}
                user={u}
                busy={pendingEmail === u.email}
                disabled={pending}
                onClick={() => go(u.email)}
              />
            ))}
          </div>
        </>
      )}

      {error && <p className="text-destructive mt-4 text-sm">{error}</p>}
      {supabaseEnabled && (
        <button
          className="text-muted-foreground hover:text-foreground mt-5 text-xs underline-offset-2 hover:underline"
          onClick={() => setShowEmail(true)}
        >
          Sign in with email instead
        </button>
      )}
    </div>
  );
}

function PersonButton({
  user,
  busy,
  disabled,
  onClick,
}: {
  user: DevUser;
  busy: boolean;
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="hover:bg-muted/60 focus-visible:ring-ring/50 flex items-center gap-3 rounded-lg border px-3 py-2.5 text-left transition-colors focus-visible:ring-[3px] focus-visible:outline-none disabled:opacity-60"
    >
      <span className="bg-muted text-muted-foreground flex size-8 shrink-0 items-center justify-center rounded-full text-xs font-semibold">
        {user.name
          .split(" ")
          .map((p) => p[0])
          .slice(0, 2)
          .join("")}
      </span>
      <span className="min-w-0">
        <span className="block truncate text-sm font-medium">
          {busy ? "Signing in…" : user.name}
        </span>
        <span className="text-muted-foreground block truncate text-xs">{user.role}</span>
      </span>
    </button>
  );
}

function SetupPanel({ status }: { status: ConfigStatus }) {
  const rows: Array<[string, boolean, string]> = [
    [
      "Database connected",
      status.databaseUrl && status.databaseReachable,
      status.databaseUrl
        ? (status.databaseError ??
          "DATABASE_URL is set but unreachable — check the pooler URI and password")
        : "Set DATABASE_URL (Supabase transaction pooler, port 6543)",
    ],
    [
      "Sign-in method",
      status.devAuth || (status.supabaseUrl && status.supabaseKey),
      "Set DEV_AUTH=1 for demo sign-in, or NEXT_PUBLIC_SUPABASE_URL + NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY for real auth",
    ],
  ];
  return (
    <div className="mx-auto max-w-sm">
      <h2 className="text-lg font-semibold tracking-tight">Almost there</h2>
      <p className="text-muted-foreground mt-1 mb-5 text-sm">
        This deployment needs its environment variables before anyone can sign in. Add them in your
        host&rsquo;s settings and redeploy — public variables only take effect on a fresh build.
      </p>
      <ul className="space-y-3">
        {rows.map(([label, ok, hint]) => (
          <li key={label} className="flex gap-3 rounded-lg border p-3">
            {ok ? (
              <Check className="mt-0.5 size-4 shrink-0 text-emerald-600" aria-hidden />
            ) : (
              <X className="text-destructive mt-0.5 size-4 shrink-0" aria-hidden />
            )}
            <div className="min-w-0 text-sm">
              <p className="font-medium">{label}</p>
              {!ok && <p className="text-muted-foreground mt-0.5 text-xs break-words">{hint}</p>}
            </div>
          </li>
        ))}
      </ul>
      <p className="text-muted-foreground mt-5 text-xs">
        Full instructions live in the repository&rsquo;s README under “Deploying to Vercel”.
      </p>
    </div>
  );
}
