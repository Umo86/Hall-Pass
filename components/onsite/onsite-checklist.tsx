"use client";

import { useEffect, useMemo, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { parseAsString, useQueryState } from "nuqs";
import { toast } from "sonner";
import { Camera, CheckCircle2, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import { StatusBadge } from "@/components/status-badge";
import { EmptyState } from "@/components/empty-state";
import { useConfirm } from "@/components/confirm-dialog";
import { useDecisionDialog } from "@/components/approvals/decide-buttons";
import { RaiseSnagButton } from "@/components/signage/snags-panel";
import { ResolveSnagButton } from "@/components/signage/resolve-snag-dialog";
import { closeSignageItem } from "@/app/actions/signage";
import { undoMarkComplete } from "@/app/actions/snags";
import { formatDate, plural, slotLabel, statusLabel } from "@/lib/format";
import { itemPath } from "@/lib/edition-path";
import { cn } from "@/lib/utils";
import {
  ONSITE_VIEWS,
  inOnsiteView,
  matchesOnsiteSearch,
  onsiteSection,
  parseOnsiteView,
  snagLabel,
  type OnsiteAction,
} from "./rules";

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
  supplierName: string | null;
  installedAt: string | null;
  openSnags: number;
  snags: { id: string; description: string; severity: string; photoUrl: string | null }[];
  expectedLockedVersionId: string | null;
  /** What the card offers next (see onsiteAction). */
  action: OnsiteAction;
};

const SLOT_ORDER: Record<string, number> = { am: 0, pm: 1, overnight: 2 };

/** Phones: full-width 44px; from sm up the usual small buttons. */
const TOUCH = "h-11 w-full sm:h-8 sm:w-auto";

function chipClass(active: boolean) {
  return cn(
    "inline-flex min-h-11 items-center rounded-full border px-4 text-sm whitespace-nowrap sm:min-h-9 sm:px-3",
    active ? "bg-primary text-primary-foreground border-primary" : "bg-background hover:bg-muted",
  );
}

type Group = { key: string; title: string; items: OnsiteCard[] };

function sortCards(items: OnsiteCard[]) {
  return items.sort(
    (a, b) =>
      (a.installDate ?? "9999").localeCompare(b.installDate ?? "9999") ||
      (SLOT_ORDER[a.installSlot ?? ""] ?? 3) - (SLOT_ORDER[b.installSlot ?? ""] ?? 3) ||
      a.ref.localeCompare(b.ref),
  );
}

/**
 * The onsite checklist: one control for Today | All to do | Done (`?view=`),
 * find by ref or name (`?q=`), halls (`?hall=`). Deliveries first, then each
 * hall and location, then what's ready to close. Headings stay pinned under
 * the app header while scrolling.
 */
export function OnsiteChecklist({
  editionCode,
  cards,
  today,
  canSnag,
  canClose,
  canUndoClose,
}: {
  editionCode: string;
  cards: OnsiteCard[];
  /** Today in the show's time zone (YYYY-MM-DD). */
  today: string;
  canSnag: boolean;
  canClose: boolean;
  canUndoClose: boolean;
}) {
  const [hall, setHall] = useQueryState("hall", parseAsString.withDefault(""));
  const [rawView, setView] = useQueryState("view", parseAsString.withDefault(""));
  // Older links: ?when=all / ?show=all meant everything still to do.
  const [when, setWhen] = useQueryState("when", parseAsString.withDefault(""));
  const [show, setShow] = useQueryState("show", parseAsString.withDefault(""));
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const view = parseOnsiteView(rawView, { when, show });
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
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

  function chooseView(next: string) {
    void setView(next === "today" ? null : next);
    void setWhen(null);
    void setShow(null);
  }

  const searching = q.trim() !== "";
  // A search looks through everything, whatever the view.
  const visible = cards.filter(
    (c) =>
      (!hall || c.hallId === hall) &&
      (searching ? matchesOnsiteSearch(q, c) : inOnsiteView(c, view, today)),
  );

  const groups = useMemo(() => {
    const deliveries: OnsiteCard[] = [];
    const ready: OnsiteCard[] = [];
    const places = new Map<string, Group>();
    for (const c of visible) {
      const section = onsiteSection(c);
      if (section === "deliveries") deliveries.push(c);
      else if (section === "ready_to_close") ready.push(c);
      else {
        // Done: sponsorship items stay together, after the halls.
        const key =
          c.kind === "sponsorship_item"
            ? "~~deliveries"
            : `${c.hallName ?? "~"}|${c.locationName ?? "~"}`;
        const title =
          c.kind === "sponsorship_item"
            ? "Deliveries"
            : [c.hallName, c.locationName].filter(Boolean).join(" · ") || "No location";
        const g = places.get(key) ?? { key, title, items: [] };
        g.items.push(c);
        places.set(key, g);
      }
    }
    const out: Group[] = [];
    if (deliveries.length) out.push({ key: "deliveries", title: "Deliveries", items: deliveries });
    out.push(...[...places.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([, g]) => g));
    if (ready.length) out.push({ key: "ready", title: "Ready to close", items: ready });
    for (const g of out) sortCards(g.items);
    return out;
  }, [visible]);

  const scoped = cards.filter((c) => (!hall || c.hallId === hall) && c.kind !== "sponsorship_item");
  const installed = scoped.filter((c) =>
    ["installed", "snagged", "closed"].includes(c.status),
  ).length;
  const snagged = cards
    .filter((c) => !hall || c.hallId === hall)
    .reduce((n, c) => n + c.openSnags, 0);
  const notDelivered = cards.filter(
    (c) => (!hall || c.hallId === hall) && c.status === "in_production",
  ).length;

  async function close(card: OnsiteCard) {
    const ok = await confirm({
      title: `Mark ${card.ref} complete?`,
      description: `${card.name} is installed and snag-free; it moves to Done.`,
      confirmLabel: "Done – close",
    });
    if (!ok) return;
    start(async () => {
      const res = await closeSignageItem({ id: card.id });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? `${card.ref} marked complete`, {
        description: card.name,
        action: canUndoClose
          ? {
              label: "Undo",
              onClick: async () => {
                const undo = await undoMarkComplete({ id: card.id });
                if (undo.ok) toast.success(undo.message ?? `${card.ref} reopened`);
                else toast.error(undo.error);
                router.refresh();
              },
            }
          : undefined,
      });
      router.refresh();
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
          <span className="text-muted-foreground">{notDelivered} not delivered yet</span>
        )}
      </div>

      <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
        <SegmentGroup label="Show" className="w-full sm:w-auto">
          {ONSITE_VIEWS.map((v) => (
            <button
              key={v.id}
              type="button"
              aria-pressed={!searching && view === v.id}
              onClick={() => chooseView(v.id)}
              className={cn(
                segmentClass(!searching && view === v.id),
                "h-11 flex-1 justify-center sm:flex-none",
              )}
            >
              {v.label}
            </button>
          ))}
        </SegmentGroup>
        <div className="relative sm:ml-auto sm:w-64">
          <Search
            className="text-muted-foreground pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2"
            aria-hidden
          />
          <Input
            type="search"
            inputMode="search"
            value={q}
            onChange={(e) => void setQ(e.target.value || null)}
            placeholder="Find ref or name (e.g. 015)"
            aria-label="Find ref or name"
            className="h-11 pl-9"
          />
        </div>
      </div>
      {hallOptions.length > 1 && (
        <div
          className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0"
          role="group"
          aria-label="Halls"
        >
          <button
            type="button"
            className={chipClass(hall === "")}
            aria-pressed={hall === ""}
            onClick={() => void setHall("")}
          >
            All halls
          </button>
          {hallOptions.map(([id, name]) => (
            <button
              key={id}
              type="button"
              className={chipClass(hall === id)}
              aria-pressed={hall === id}
              onClick={() => void setHall(id)}
            >
              {name}
            </button>
          ))}
        </div>
      )}
      {searching && (
        <p className="text-muted-foreground text-sm">
          {plural(visible.length, "match", "matches")} for “{q.trim()}” across every day and status.
        </p>
      )}

      {groups.length === 0 &&
        (cards.length === 0 ? (
          <EmptyState
            icon={CheckCircle2}
            title="Nothing has gone to print yet"
            description="Signs, panels and sponsorship items appear here once they have gone to print."
          />
        ) : (
          <EmptyState
            icon={CheckCircle2}
            title={
              searching
                ? "Nothing matches"
                : view === "done"
                  ? "Nothing is complete yet"
                  : "Nothing to do here today"
            }
            description={
              searching
                ? "Try the ref printed on the spec label, or part of the name."
                : view === "today"
                  ? "Everything due by today is done. All to do shows what's coming."
                  : undefined
            }
            action={
              !searching &&
              view === "today" && (
                <Button size="sm" variant="outline" onClick={() => chooseView("todo")}>
                  Show all to do
                </Button>
              )
            }
          />
        ))}

      {groups.map((g) => (
        <section key={g.key} className="flex flex-col gap-2" aria-label={g.title}>
          <h2 className="bg-background text-muted-foreground sticky top-14 z-30 -mx-4 border-b px-4 py-2 text-xs font-semibold tracking-wide uppercase sm:-mx-6 sm:px-6">
            {g.title} · {g.items.length}
          </h2>
          {g.items.map((c) => (
            <OnsiteItem
              key={c.id}
              c={c}
              editionCode={editionCode}
              today={today}
              canSnag={canSnag}
              canClose={canClose}
              closing={pending}
              onClose={() => void close(c)}
            />
          ))}
        </section>
      ))}
      {confirmDialog}
    </div>
  );
}

function OnsiteItem({
  c,
  editionCode,
  today,
  canSnag,
  canClose,
  closing,
  onClose,
}: {
  c: OnsiteCard;
  editionCode: string;
  today: string;
  canSnag: boolean;
  canClose: boolean;
  closing: boolean;
  onClose: () => void;
}) {
  const href = itemPath(editionCode, { kind: c.kind as "signage", ref: c.ref });
  const overdue =
    c.installDate &&
    c.installDate < today &&
    !["installed", "snagged", "closed"].includes(c.status);
  const snagButton = canSnag ? snagLabel(c.kind, c.status) : null;
  const ready = onsiteSection(c) === "ready_to_close";
  const isSponsorship = c.kind === "sponsorship_item";
  const meta = [
    c.standNumber ? `Stand ${c.standNumber}` : null,
    isSponsorship
      ? c.supplierName
        ? `From ${c.supplierName}`
        : null
      : c.installDate
        ? `${formatDate(c.installDate)}${c.installSlot ? ` ${slotLabel(c.installSlot)}` : ""}`
        : "No install date",
    c.contractorName,
  ].filter(Boolean);

  const buttons = (
    <>
      {c.action?.type === "confirm" && <ConfirmStepButton action={c.action} card={c} href={href} />}
      {c.action?.type === "open_item" && (
        <Button asChild size="sm" variant="outline" className={TOUCH}>
          <Link href={`${href}?tab=artwork`}>{c.action.label}</Link>
        </Button>
      )}
      {snagButton && (
        <RaiseSnagButton
          itemId={c.id}
          itemRef={c.ref}
          label={snagButton}
          damage={c.status === "delivered"}
          className={TOUCH}
          onDone={(r) => {
            if (r.ok) toast.success(r.message ?? `Snag raised on ${c.ref}`);
          }}
        />
      )}
      {canClose && ready && (
        <Button size="sm" className={TOUCH} disabled={closing} onClick={onClose}>
          Done – close
        </Button>
      )}
    </>
  );
  const hasButtons =
    c.action?.type === "confirm" ||
    c.action?.type === "open_item" ||
    Boolean(snagButton) ||
    (canClose && ready);

  return (
    <article
      aria-label={`${c.ref} ${c.name}`}
      className={cn(
        "flex flex-col gap-2 rounded-lg border p-3",
        c.status === "snagged" && "border-rose-300 dark:border-rose-800",
        c.status === "closed" && "opacity-70",
      )}
    >
      <div className="flex flex-wrap items-start gap-x-2 gap-y-1">
        <div className="min-w-0 flex-1">
          <Link href={href} className="font-medium hover:underline">
            {c.ref} · {c.name}
          </Link>
          {meta.length > 0 && (
            <p className="text-muted-foreground text-sm">
              {meta.join(" · ")}
              {overdue && !isSponsorship && (
                <span className="text-destructive font-medium"> · overdue</span>
              )}
            </p>
          )}
        </div>
        <StatusBadge
          status={c.status}
          label={
            isSponsorship && c.status === "in_production"
              ? "On order"
              : isSponsorship && c.status === "installed"
                ? "In place"
                : undefined
          }
        />
        {c.openSnags > 0 && (
          <span className="rounded-md bg-rose-50 px-2 py-0.5 text-xs font-medium text-rose-800 dark:bg-rose-950 dark:text-rose-300">
            {plural(c.openSnags, "snag")}
          </span>
        )}
      </div>

      {c.snags.length > 0 && (
        <ul
          className="divide-y rounded-md border border-rose-200 dark:border-rose-900"
          aria-label="Open snags"
        >
          {c.snags.map((s) => (
            <li key={s.id} className="flex flex-col gap-2 p-2 text-sm sm:flex-row sm:items-center">
              <div className="min-w-0 flex-1">
                <p>{s.description}</p>
                <p className="text-muted-foreground text-xs">
                  {statusLabel(s.severity)}
                  {s.photoUrl && (
                    <>
                      {" · "}
                      <a
                        className="link inline-flex items-center gap-1"
                        href={s.photoUrl}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <Camera className="size-3" aria-hidden /> Photo
                      </a>
                    </>
                  )}
                </p>
              </div>
              {canSnag && (
                <ResolveSnagButton
                  snagId={s.id}
                  itemRef={c.ref}
                  description={s.description}
                  label="Fixed ✓"
                  confirmLabel="Fixed"
                  className={TOUCH}
                />
              )}
            </li>
          ))}
        </ul>
      )}

      {(c.action?.type === "waiting" || c.action?.type === "open_item") && (
        <p className="text-muted-foreground text-xs">{c.action.text}</p>
      )}
      {hasButtons && (
        <div className="grid grid-cols-2 gap-2 sm:flex sm:flex-wrap sm:items-center sm:gap-1.5 [&>*:only-child]:col-span-2">
          {buttons}
        </div>
      )}
    </article>
  );
}

/** Tick the waiting confirmation from the card: date, and the install photo where required. */
function ConfirmStepButton({
  action,
  card,
  href,
}: {
  action: Extract<OnsiteAction, { type: "confirm" }>;
  card: OnsiteCard;
  href: string;
}) {
  const { openDecision, dialog } = useDecisionDialog({
    instanceId: action.instanceId,
    stepKind: "confirmation",
    stepName: action.stepName,
    expectedStatus: "pending",
    expectedLockedVersionId: card.expectedLockedVersionId,
    requiresPhoto: action.photo,
    itemRef: card.ref,
    itemName: card.name,
    itemHref: href,
  });
  return (
    <>
      <Button size="sm" className={TOUCH} onClick={() => openDecision("confirm")}>
        {action.label}
      </Button>
      {dialog}
    </>
  );
}
