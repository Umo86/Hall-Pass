import Link from "next/link";
import { redirect } from "next/navigation";
import { ArrowRight, ClipboardCheck, FileCheck2, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { brandName } from "@/lib/config";
import { getSession } from "@/lib/auth/actor";

export const dynamic = "force-dynamic";

const FEATURES = [
  {
    icon: ClipboardCheck,
    title: "One signage register",
    body: "Every sign, banner, graphic and screen — specs, artwork versions, costs and install dates in a single schedule that replaces the spreadsheet and the email chase.",
  },
  {
    icon: FileCheck2,
    title: "Sign-off that keeps moving",
    body: "Configurable approval chains across marketing, ops, sponsors, venues and engineers, with deadlines, automatic reminders and escalation when things stall.",
  },
  {
    icon: ShieldCheck,
    title: "Audit-ready by default",
    body: "Every decision records who, when and the exact file version it was made against. The audit trail is append-only — enforced by the database itself.",
  },
];

export default async function Home() {
  const session = await getSession().catch(() => null);
  if (session) redirect(session.actor.kind === "staff" ? "/editions" : "/portal/approvals");

  return (
    <div className="bg-background flex min-h-screen flex-col">
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-5">
        <span className="text-sm font-semibold tracking-tight">{brandName}</span>
        <Button asChild size="sm" variant="outline">
          <Link href="/login">Sign in</Link>
        </Button>
      </header>

      <main className="flex flex-1 flex-col">
        <section className="mx-auto w-full max-w-5xl px-6 pt-16 pb-20 sm:pt-24">
          <p className="text-muted-foreground text-xs font-semibold tracking-[0.2em] uppercase">
            Signage schedule &amp; design sign-off
          </p>
          <h1 className="mt-4 max-w-2xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
            Every sign. Every stand.
            <br />
            Signed off, on time.
          </h1>
          <p className="text-muted-foreground mt-5 max-w-xl text-lg leading-relaxed">
            {brandName} is the single register for organiser signage and exhibitor stand designs —
            with approval chains, deadline chasing and an immutable audit trail built in.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Button asChild size="lg">
              <Link href="/login">
                Staff sign in <ArrowRight className="size-4" aria-hidden />
              </Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link href="/login">Exhibitor &amp; partner portal</Link>
            </Button>
          </div>
        </section>

        <section className="border-t">
          <div className="mx-auto grid w-full max-w-5xl gap-px px-6 py-14 sm:grid-cols-3 sm:gap-10">
            {FEATURES.map((f) => (
              <div key={f.title} className="py-4">
                <f.icon className="text-muted-foreground size-5" aria-hidden />
                <h2 className="mt-3 text-sm font-semibold">{f.title}</h2>
                <p className="text-muted-foreground mt-1.5 text-sm leading-relaxed">{f.body}</p>
              </div>
            ))}
          </div>
        </section>
      </main>

      <footer className="border-t">
        <div className="text-muted-foreground mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-5 text-xs">
          <span>{brandName}</span>
          <span>Access is by invitation — contact the operations team.</span>
        </div>
      </footer>
    </div>
  );
}
