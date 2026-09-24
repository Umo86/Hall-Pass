import Link from "next/link";
import { redirect } from "next/navigation";
import { ArrowRight, ClipboardCheck, FileCheck2, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/status-badge";
import { AccentRule, Wordmark } from "@/components/wordmark";
import { Scene } from "@/components/scene";
import { brandImage } from "@/lib/brand-images";
import { brandName } from "@/lib/config";
import { getSession } from "@/lib/auth/actor";
import { PORTAL_HOME, STAFF_HOME } from "@/lib/edition-path";

export const dynamic = "force-dynamic";

const FEATURES = [
  {
    icon: ClipboardCheck,
    tile: "bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300",
    title: "One signage register",
    body: "Every sign, banner, graphic and screen — specs, artwork versions, costs and install dates in a single schedule that replaces the spreadsheet and the email chase.",
  },
  {
    icon: FileCheck2,
    tile: "bg-violet-100 text-violet-700 dark:bg-violet-950 dark:text-violet-300",
    title: "Sign-off that keeps moving",
    body: "Configurable approval chains across marketing, ops, sponsors, venues and engineers, with deadlines, automatic reminders and escalation when things stall.",
  },
  {
    icon: ShieldCheck,
    tile: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300",
    title: "Audit-ready by default",
    body: "Every decision records who, when and the exact file version it was made against. The audit trail is append-only — enforced by the database itself.",
  },
];

const PIPELINE = ["draft", "in_review", "approved", "in_production", "delivered", "installed"];

export default async function Home() {
  const session = await getSession().catch(() => null);
  if (session) redirect(session.actor.kind === "staff" ? STAFF_HOME : PORTAL_HOME);

  return (
    <div className="bg-background flex min-h-screen flex-col">
      <AccentRule className="rounded-none" />
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-5">
        <Wordmark name={brandName} />
        <Button asChild size="sm" variant="outline">
          <Link href="/login">Sign in</Link>
        </Button>
      </header>

      <main className="flex flex-1 flex-col">
        <section className="mx-auto grid w-full max-w-5xl items-center gap-10 px-6 pt-14 pb-16 sm:pt-20 lg:grid-cols-[7fr_5fr]">
          <div>
          <p className="text-xs font-semibold tracking-[0.2em] text-indigo-600 uppercase dark:text-indigo-400">
            Signage schedule &amp; design sign-off
          </p>
          <h1 className="mt-4 max-w-2xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
            Every sign. Every stand.{" "}
            <span className="text-indigo-600 dark:text-indigo-400">Signed off, on time.</span>
          </h1>
          <p className="text-muted-foreground mt-5 max-w-xl text-lg leading-relaxed">
            <Wordmark name={brandName} size="sm" className="align-baseline text-lg" /> is the
            single register for organiser signage and exhibitor stand designs — with approval
            chains, deadline chasing and an immutable audit trail built in.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <Button asChild size="lg" className="bg-indigo-600 text-white hover:bg-indigo-700">
              <Link href="/login">
                Staff sign in <ArrowRight className="size-4" aria-hidden />
              </Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link href="/login">Exhibitor &amp; partner portal</Link>
            </Button>
          </div>

          <div className="mt-12 flex flex-wrap items-center gap-2" aria-label="Item lifecycle">
            {PIPELINE.map((status, i) => (
              <span key={status} className="flex items-center gap-2">
                <StatusBadge status={status} />
                {i < PIPELINE.length - 1 && (
                  <ArrowRight className="text-muted-foreground/50 size-3.5" aria-hidden />
                )}
              </span>
            ))}
          </div>
          </div>
          <Scene
            kind="hall"
            photo={brandImage("hero")}
            alt="Crew installing event signage in an exhibition hall"
            className="shadow-sm"
          />
        </section>

        <section className="border-t bg-slate-50 dark:bg-slate-900/40">
          <div className="mx-auto grid w-full max-w-5xl gap-6 px-6 py-14 sm:grid-cols-3 sm:gap-10">
            {FEATURES.map((f) => (
              <div key={f.title}>
                <span
                  className={`flex size-10 items-center justify-center rounded-lg ${f.tile}`}
                >
                  <f.icon className="size-5" aria-hidden />
                </span>
                <h2 className="mt-4 text-sm font-semibold">{f.title}</h2>
                <p className="text-muted-foreground mt-1.5 text-sm leading-relaxed">{f.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="border-t">
          <div className="mx-auto grid w-full max-w-5xl items-center gap-10 px-6 py-14 lg:grid-cols-[5fr_7fr]">
            <Scene
              kind="office"
              photo={brandImage("office")}
              alt="Event operations team planning at a schedule wall"
              className="order-last lg:order-first"
            />
            <div>
              <h2 className="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
                From the office wall to the hall floor
              </h2>
              <p className="text-muted-foreground mt-4 max-w-xl leading-relaxed">
                Marketing checks the brand, ops checks the build, the venue checks the rigging and
                sponsors sign their own artwork — all on the same record, all against the same
                locked version. When the doors open, the audit trail already tells the whole story.
              </p>
              <ul className="text-muted-foreground mt-5 space-y-2 text-sm">
                <li className="flex gap-2"><span className="mt-1.5 size-2 shrink-0 rounded-full bg-indigo-500" />Automatic reminders and escalation keep every approval moving</li>
                <li className="flex gap-2"><span className="mt-1.5 size-2 shrink-0 rounded-full bg-amber-500" />Excel in, Excel out — plus certificates and spec labels as PDFs</li>
                <li className="flex gap-2"><span className="mt-1.5 size-2 shrink-0 rounded-full bg-emerald-500" />Exhibitors and contractors submit through their own portal</li>
              </ul>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t">
        <div className="text-muted-foreground mx-auto flex w-full max-w-5xl flex-wrap items-center justify-between gap-2 px-6 py-5 text-xs">
          <Wordmark name={brandName} size="sm" />
          <span>Access is by invitation — contact the operations team.</span>
        </div>
      </footer>
    </div>
  );
}
