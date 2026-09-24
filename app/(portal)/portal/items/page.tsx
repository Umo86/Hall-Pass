import Link from "next/link";
import { requirePortalSession } from "@/lib/auth/actor";
import { visibleItemsForExternal } from "@/lib/queries/portal";
import { formatDate, statusLabel } from "@/lib/format";
import { StatusBadge } from "@/components/status-badge";

export const metadata = { title: "My Items" };
export const dynamic = "force-dynamic";

export default async function PortalItemsPage() {
  const session = await requirePortalSession();
  const roles = new Set(session.actor.grants.map((g) => g.role));
  const isSupplier = roles.has("supplier");
  const rows = await visibleItemsForExternal(session.actor);

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-4 p-4 sm:p-6">
      <h1 className="text-xl font-semibold tracking-tight">
        My items <span className="text-muted-foreground text-base font-normal">({rows.length})</span>
      </h1>

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 items-center justify-center rounded-lg border border-dashed text-sm">
          Nothing is currently shared with you.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-muted/50 text-muted-foreground border-b text-left">
                <th className="px-3 py-2 font-medium">Ref</th>
                <th className="px-3 py-2 font-medium">Name</th>
                <th className="px-3 py-2 font-medium">Status</th>
                <th className="px-3 py-2 font-medium">Size (mm)</th>
                <th className="px-3 py-2 font-medium">Qty</th>
                <th className="px-3 py-2 font-medium">Material / finish</th>
                <th className="px-3 py-2 font-medium">Fixing</th>
                <th className="px-3 py-2 font-medium">Location</th>
                {isSupplier && (
                  <>
                    <th className="px-3 py-2 font-medium">Delivery</th>
                    <th className="px-3 py-2 font-medium">Install</th>
                    <th className="px-3 py-2 font-medium">PO</th>
                  </>
                )}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.item.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">
                    <Link href={`/portal/items/${r.item.ref}`} className="text-primary hover:underline">
                      {r.item.ref}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{r.item.name}</td>
                  <td className="px-3 py-2">
                    <StatusBadge status={r.item.status} />
                  </td>
                  <td className="px-3 py-2">
                    {r.item.widthMm && r.item.heightMm
                      ? `${r.item.widthMm} × ${r.item.heightMm}`
                      : "—"}
                  </td>
                  <td className="px-3 py-2">{r.item.quantity}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {[r.item.material, r.item.finish].filter(Boolean).join(" / ") || "—"}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">
                    {r.item.fixingMethod ? statusLabel(r.item.fixingMethod) : "—"}
                  </td>
                  <td className="text-muted-foreground px-3 py-2">
                    {[r.hallName, r.locationName].filter(Boolean).join(" · ") || "—"}
                  </td>
                  {isSupplier && (
                    <>
                      <td className="px-3 py-2">{formatDate(r.item.deliveryDate)}</td>
                      <td className="px-3 py-2">
                        {r.item.installDate
                          ? `${formatDate(r.item.installDate)}${r.item.installSlot ? ` ${r.item.installSlot.toUpperCase()}` : ""}`
                          : "—"}
                      </td>
                      <td className="px-3 py-2">{r.item.poNumber ?? "—"}</td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <p className="text-muted-foreground text-xs">
        Open an item for its artwork, spec label and sign-off progress
        {isSupplier ? " — artwork is released to suppliers once it is signed off" : ""}.
      </p>
    </div>
  );
}
