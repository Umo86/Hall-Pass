import { redirect } from "next/navigation";
import { db } from "@/lib/db/client";
import { getSession } from "@/lib/auth/actor";
import { can } from "@/lib/authz";
import { itemAuthzCtx, loadItemBundle } from "@/lib/domain/signage";
import { loadStandBundle, standAuthzCtx, stepActiveFlags } from "@/lib/domain/stand";
import { getItemByRef } from "@/lib/queries/signage";
import { getStandByRef } from "@/lib/queries/stands";
import { loadRun } from "@/lib/workflow/persist";

export const metadata = { title: "Scan" };
export const dynamic = "force-dynamic";

/** QR resolution: a scanned ref lands on the record, scoping enforced. */
export default async function QrResolvePage({ params }: { params: Promise<{ ref: string }> }) {
  const { ref: rawRef } = await params;
  const ref = decodeURIComponent(rawRef).toUpperCase();
  const session = await getSession();
  if (!session) redirect(`/login?next=/q/${encodeURIComponent(ref)}`);

  if (ref.startsWith("SIG-")) {
    const item = await getItemByRef(ref);
    if (item && !item.deletedAt) {
      const bundle = await loadItemBundle(db, item.id);
      if (bundle && can(session.actor, { type: "signage.view", item: itemAuthzCtx(bundle) })) {
        redirect(
          session.actor.kind === "staff"
            ? `/${bundle.edition.code}/signage/${item.ref}`
            : `/portal/items/${item.ref}`,
        );
      }
    }
  }
  if (ref.startsWith("STD-")) {
    const sub = await getStandByRef(ref);
    if (sub) {
      const bundle = await loadStandBundle(db, sub.id);
      if (bundle) {
        const run =
          sub.currentRunNumber > 0
            ? await loadRun(db, "stand_submission", sub.id, sub.currentRunNumber)
            : [];
        const ctx = standAuthzCtx(bundle, stepActiveFlags(run));
        if (can(session.actor, { type: "stand.view", sub: ctx })) {
          redirect(
            session.actor.kind === "staff"
              ? `/${bundle.edition.code}/stands/${sub.ref}`
              : "/portal/submission",
          );
        }
      }
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="max-w-sm space-y-2 text-center">
        <h1 className="text-xl font-semibold tracking-tight">{ref}</h1>
        <p className="text-muted-foreground text-sm">
          This reference does not exist or is not shared with you.
        </p>
      </div>
    </div>
  );
}
