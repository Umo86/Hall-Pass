"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { parseAsString, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/status-badge";
import { DecideButtons } from "@/components/approvals/decide-buttons";
import { RaiseSnagButton } from "@/components/signage/snags-panel";
import { closeSignageItem } from "@/app/actions/signage";
import { formatDate, plural, slotLabel } from "@/lib/format";
import { itemPath } from "@/lib/edition-path";
import { cn } from "@/lib/utils";

export type OnsiteCard = {
  id: string;
  ref: string;
  name: string;
  kind: string;
  status: string;
  hallId: string | null;
  hallName: string | null;
  locationName: string | null;
  standNumber: string | null;
  installDate: string | null;
  installSlot: string | null;
  contractorName: string | null;
  installedAt: string | null;
  openSnags: number;
  /** Set when this person can tick Installed on the item. */
  confirm: {
    instanceId: string;
    expectedLockedVersionId: string | null;
    requiresPhoto: boolean;
  } | null;
};

const SLOT_ORDER: Record<string, number> = { am: 0, pm: 1, overnight: 2 };

function chipClass(active: boolean) {
  return cn(
    "rounded-full border px-3 py-1.5 text-sm whitespace-nowrap",
    active ? "bg-primary text-primary-foreground border-primary" : "bg-background hover:bg-muted",
  );
}

export function OnsiteChecklist({
  editionCode,
  cards,
  today,
  canSnag,
  canClose,
}: {
  editionCode: string;
  cards: OnsiteCard[];
  /** Today in the show's time zone (YYYY-MM-DD). */
  today: string;
  canSnag: boolean;
  canClose: boolean;
}) {
  const [hall, setHall] = useQueryState("hall", parseAsString.withDefault(""));
  const [when, setWhen] = useQueryState("when", parseAsString.withDefault("today"));
  const [show, setShow] = useQueryState("show", parseAsString.withDefault("todo"));
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const hallOptions = useMemo(() => {
    const seen = new Map<string, string>();
    for (const c of cards) if (c.hallId && c.hallName) seen.set(c.hallId, c.hallName);
    return [...seen.entries()].sort((a, b) => a[1].localeCompare(b[1]));
  }, [cards]);

  // A hall filter left over from a link that no longer matches anything would
  // show an empty list with no chip to clear it.
  useEffect(() => {
    if (hall && !hallOptions.some(([id]) => id === hall)) void setHall("");
  }, [hall, hallOptions, setHall]);

  const visible = cards.filter((c) => {
    if (hall && c.hallId !== hall) return false;
    // "Today" is everything due by today, including anything overdue and
    // anything with no date yet — nothing gets hidden by accident. Snagged
    // items stay in view whatever their date: they need someone today.
    const needsAttention = c.status === "snagged" || c.openSnags > 0;
    if (when === "today" && c.installDate && c.installDate > today && !needsAttention) return false;
    if (show === "todo" && (c.status === "closed" || c.status === "installed")) return false;
    return true;
  });

  // Group by hall, then location; within a group by slot then ref.
  const groups = useMemo(() => {
    const map = new Map<string, { title: string; items: OnsiteCard[] }>();
    for (const c of visible) {
      const key = `${c.hallName ?? "~"}|${c.locationName ?? "~"}`;
      const title = [c.hallName, c.locationName].filter(Boolean).join(" · ") || "No location";
      const g = map.get(key) ?? { title, items: [] };
      g.items.push(c);
      map.set(key, g);
    }
    for (const g of map.values()) {
      g.items.sort(
        (a, b) =>
          (a.installDate ?? "9999").localeCompare(b.installDate ?? "9999") ||
          (SLOT_ORDER[a.installSlot ?? ""] ?? 3) - (SLOT_ORDER[b.installSlot ?? ""] ?? 3) ||
          a.ref.localeCompare(b.ref),
      );
    }
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([, g]) => g);
  }, [visible]);

  const scoped = cards.filter((c) => !hall || c.hallId === hall);
  const installed = scoped.filter((c) =>
    ["installed", "snagged", "closed"].includes(c.status),
  ).length;
  const snagged = scoped.reduce((n, c) => n + c.openSnags, 0);
  const notDelivered = scoped.filter((c) => c.status === "in_production").length;

  function close(id: string) {
    setMessage(null);
    start(async () => {
      const res = await closeSignageItem({ id });
      setMessage(
        res.ok ? { text: res.message ?? "Closed", error: false } : { text: res.error, error: true },
      );
      if (res.ok) router.refresh();
    });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="bg-muted/60 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-lg border px-3 py-2 text-sm">
        <span className="font-medium">
          {installed} of {scoped.length} installed
        </span>
        <span className={snagged ? "text-destructive font-medium" : "text-muted-foreground"}>
          {plural(snagged, "open snag")}
        </span>
        {notDelivered > 0 && (
          <span className="text-muted-foreground">{notDelivered} still with the printer</span>
        )}
        {message && (
          <span className={message.error ? "text-destructive" : "text-muted-foreground"}>
            {message.text}
          </span>
        )}
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          className={chipClass(when === "today")}
          onClick={() => setWhen("today")}
        >
          Due today
        </button>
        <button type="button" className={chipClass(when === "all")} onClick={() => setWhen("all")}>
          All dates
        </button>
        <span className="border-l" aria-hidden />
        <button
          type="button"
          className={chipClass(show === "todo")}
          onClick={() => setShow("todo")}
        >
          To do
        </button>
        <button type="button" className={chipClass(show === "all")} onClick={() => setShow("all")}>
          Everything
        </button>
      </div>
      {hallOptions.length > 1 && (
        <div className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
          <button type="button" className={chipClass(hall === "")} onClick={() => setHall("")}>
            All halls
          </button>
          {hallOptions.map(([id, name]) => (
            <button
              key={id}
              type="button"
              className={chipClass(hall === id)}
              onClick={() => setHall(id)}
            >
              {name}
            </button>
          ))}
        </div>
      )}

      {groups.length === 0 && (
        <p className="text-muted-foreground py-8 text-center text-sm">
          {cards.length === 0
            ? "Nothing is printed yet. Items appear here once they have gone to print."
            : "Nothing to do here — try All dates or Everything."}
        </p>
      )}

      {groups.map((g) => (
        <section key={g.title} className="flex flex-col gap-2">
          <h2 className="text-muted-foreground sticky top-0 z-10 bg-background/95 py-1 text-xs font-semibold tracking-wide uppercase backdrop-blur">
            {g.title} · {g.items.length}
          </h2>
          {g.items.map((c) => {
            const overdue =
              c.installDate &&
              c.installDate < today &&
              !["installed", "snagged", "closed"].includes(c.status);
            return (
              <article
                key={c.id}
                className={cn(
                  "flex flex-col gap-2 rounded-lg border p-3",
                  c.status === "snagged" && "border-rose-300 dark:border-rose-800",
                  c.status === "closed" && "opacity-60",
                )}
              >
                <div className="flex flex-wrap items-start gap-x-2 gap-y-1">
                  <div className="min-w-0 flex-1">
                    <Link
                      href={itemPath(editionCode, { kind: c.kind, ref: c.ref })}
                      className="font-medium hover:underline"
                    >
                      {c.ref} · {c.name}
                    </Link>
                    <p className="text-muted-foreground text-sm">
                      {[
                        c.standNumber ? `Stand ${c.standNumber}` : null,
                        c.installDate
                          ? `${formatDate(c.installDate)}${c.installSlot ? ` ${slotLabel(c.installSlot)}` : ""}`
                          : "No install date",
                        c.contractorName,
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                      {overdue && <span className="text-destructive font-medium"> · overdue</span>}
                    </p>
                  </div>
                  <StatusBadge status={c.status} />
                  {c.openSnags > 0 && (
                    <span className="rounded-md bg-rose-50 px-2 py-0.5 text-xs font-medium text-rose-800 dark:bg-rose-950 dark:text-rose-300">
                      {plural(c.openSnags, "snag")}
                    </span>
                  )}
                </div>
                <div className="flex flex-wrap items-center gap-1.5">
                  {c.confirm && c.status === "delivered" && (
                    <DecideButtons
                      instanceId={c.confirm.instanceId}
                      stepKind="confirmation"
                      stepName="Installed"
                      expectedStatus="pending"
                      expectedLockedVersionId={c.confirm.expectedLockedVersionId}
                      requiresPhoto={c.confirm.requiresPhoto}
                      confirmLabel="Installed ✓"
                      compact
                    />
                  )}
                  {c.status === "in_production" && (
                    <span className="text-muted-foreground text-xs">
                      Confirm Delivered on the item first
                    </span>
                  )}
                  {!c.confirm && c.status === "delivered" && (
                    <span className="text-muted-foreground text-xs">
                      Waiting for Operations to confirm Installed
                    </span>
                  )}
                  {canSnag &&
                    c.kind !== "sponsorship_item" &&
                    ["installed", "snagged"].includes(c.status) && (
                      <RaiseSnagButton itemId={c.id} itemRef={c.ref} />
                    )}
                  {canClose && c.status === "installed" && (
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={pending}
                      onClick={() => close(c.id)}
                    >
                      Close
                    </Button>
                  )}
                </div>
              </article>
            );
          })}
        </section>
      ))}
    </div>
  );
}
