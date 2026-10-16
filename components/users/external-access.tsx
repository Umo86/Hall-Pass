"use client";

import { useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { UserPlus } from "lucide-react";
import { toast } from "sonner";
import {
  inviteExternal,
  resendPartnerInvite,
  revokeGrant,
  setPartnerAccessEnd,
  type SameAccess,
} from "@/app/actions/settings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { CopyField } from "@/components/copy-field";
import { useConfirm } from "@/components/confirm-dialog";
import { appTimezone } from "@/lib/config";
import { formatDate } from "@/lib/format";
import { absoluteLink, LinkDialog } from "./invite-actions";
import { FieldError } from "./person-fields";

/** A venue or company an invitation can be for, with the contact on its record. */
export type ScopeOption = {
  id: string;
  label: string;
  editionId?: string;
  contactName?: string | null;
  contactEmail?: string | null;
};
export type EventOption = { id: string; label: string; upcoming: boolean };
export type GrantState = "invited" | "active" | "expired";

const ROLES: { value: string; label: string; stands?: boolean }[] = [
  { value: "venue", label: "Venue" },
  { value: "supplier", label: "Supplier" },
  { value: "sponsor", label: "Sponsor" },
  { value: "structural_engineer", label: "Structural engineer", stands: true },
  { value: "hs", label: "Health & safety", stands: true },
  { value: "exhibitor", label: "Exhibitor", stands: true },
  { value: "contractor", label: "Contractor", stands: true },
];

// The server checks the same pairing (PARTNER_SCOPE_FOR in lib/users/external.ts).
const SCOPE_FOR: Record<string, "venue" | "supplier" | "exhibitor" | "sponsor" | null> = {
  venue: "venue",
  supplier: "supplier",
  sponsor: "sponsor",
  exhibitor: "exhibitor",
  contractor: "exhibitor",
  structural_engineer: null,
  hs: null,
};

/** Today in London (YYYY-MM-DD): the earliest end date the server accepts. */
export function londonToday(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: appTimezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function EventSelect({
  id,
  events,
  value,
  onChange,
  allOption,
  label,
  className,
}: {
  id?: string;
  events: EventOption[];
  value: string;
  onChange: (value: string) => void;
  allOption?: string;
  label?: string;
  className?: string;
}) {
  const upcoming = events.filter((e) => e.upcoming);
  const past = events.filter((e) => !e.upcoming);
  return (
    <SelectNative
      id={id}
      aria-label={label}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={className}
    >
      {allOption && <option value="all">{allOption}</option>}
      {upcoming.length > 0 && (
        <optgroup label="Upcoming">
          {upcoming.map((e) => (
            <option key={e.id} value={e.id}>
              {e.label}
            </option>
          ))}
        </optgroup>
      )}
      {past.length > 0 && (
        <optgroup label="Past">
          {past.map((e) => (
            <option key={e.id} value={e.id}>
              {e.label}
            </option>
          ))}
        </optgroup>
      )}
    </SelectNative>
  );
}

/**
 * The same access was given before: what to do instead of inviting again —
 * send the invitation again, give ended access a new end date, or nothing.
 */
export function SameAccessNotice({
  same,
  message,
  who,
  emailOn,
  suggestedEnd,
  onLink,
  onDone,
}: {
  same: SameAccess;
  message: string;
  who: string;
  emailOn: boolean;
  /** The end date typed into the invitation, offered for extending. */
  suggestedEnd?: string | null;
  onLink: (link: string) => void;
  onDone: () => void;
}) {
  const today = londonToday();
  const [date, setDate] = useState(suggestedEnd && suggestedEnd >= today ? suggestedEnd : "");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <div
      role="status"
      className="space-y-3 rounded-md border border-sky-200 bg-sky-50 p-3 text-sm text-sky-950 dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-100"
    >
      <p>{message}</p>
      {same.status === "invited" && (
        <Button
          type="button"
          size="sm"
          className="h-11 sm:h-8"
          disabled={pending}
          onClick={() =>
            start(async () => {
              const res = await resendPartnerInvite({ grantId: same.grantId, linkOnly: !emailOn });
              if (!res.ok) {
                setError(res.error);
                return;
              }
              toast.success(res.message ?? "Invitation sent again");
              router.refresh();
              if (res.data?.inviteUrl) onLink(res.data.inviteUrl);
              else onDone();
            })
          }
        >
          {emailOn ? "Send the invitation again" : "Get a new link"}
        </Button>
      )}
      {same.status === "expired" && (
        <div className="flex flex-wrap items-end gap-2">
          <div className="space-y-1">
            <Label htmlFor="same-end">New end date</Label>
            <Input
              id="same-end"
              type="date"
              min={today}
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="h-11 w-44 sm:h-9"
            />
          </div>
          <Button
            type="button"
            size="sm"
            className="h-11 sm:h-9"
            disabled={pending}
            aria-label={`Extend ${who}'s access`}
            onClick={() => {
              setError(null);
              start(async () => {
                const res = await setPartnerAccessEnd({
                  grantId: same.grantId,
                  date: date || null,
                });
                if (!res.ok) {
                  setError(res.error);
                  return;
                }
                toast.success(res.message ?? "Access extended");
                router.refresh();
                onDone();
              });
            }}
          >
            {date ? "Extend access" : "Extend with no end date"}
          </Button>
        </div>
      )}
      {same.status === "active" && (
        <p className="text-xs">
          Nothing to send: they sign in with this email.
          {same.endsOn ? ` Access ends ${formatDate(same.endsOn)}.` : ""}
        </p>
      )}
      <FieldError message={error} />
    </div>
  );
}

/** "Invite someone from outside": a dialog with the current event chosen. */
export function ExternalInvite({
  events,
  defaultEventId,
  venues,
  suppliers,
  sponsors,
  exhibitors,
  showStandRoles,
  emailOn,
  prefill,
}: {
  events: EventOption[];
  defaultEventId: string | null;
  venues: ScopeOption[];
  suppliers: ScopeOption[];
  sponsors: ScopeOption[];
  exhibitors: ScopeOption[];
  showStandRoles: boolean;
  emailOn: boolean;
  prefill: { open: boolean; role: string | null; scopeId: string | null; editionId: string | null };
}) {
  const roles = ROLES.filter((r) => showStandRoles || !r.stands);
  const startRole = roles.some((r) => r.value === prefill.role) ? prefill.role! : "venue";
  const startEvent =
    events.find((e) => e.id === prefill.editionId)?.id ?? defaultEventId ?? events[0]?.id ?? "";
  const [open, setOpen] = useState(prefill.open);
  // Until typed over, email and name follow the contact on the chosen company's record.
  const [email, setEmail] = useState<string | null>(null);
  const [name, setName] = useState<string | null>(null);
  const [role, setRole] = useState(startRole);
  const [editionId, setEditionId] = useState(startEvent);
  const [scopeId, setScopeId] = useState(prefill.scopeId ?? "");
  const [expires, setExpires] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [same, setSame] = useState<{ same: SameAccess; message: string } | null>(null);
  const [link, setLink] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const today = londonToday();

  const scopeType = SCOPE_FOR[role];
  const options = (
    scopeType === "venue"
      ? venues
      : scopeType === "supplier"
        ? suppliers
        : scopeType === "sponsor"
          ? sponsors
          : scopeType === "exhibitor"
            ? exhibitors
            : []
  ).filter((o) => !o.editionId || o.editionId === editionId);
  const scopeValue = options.some((o) => o.id === scopeId) ? scopeId : (options[0]?.id ?? "");
  const scope = options.find((o) => o.id === scopeValue);
  const scopeLabel = scopeType === "venue" ? "Which venue" : "Which company";
  const shownEmail = email ?? scope?.contactEmail ?? "";
  const shownName = name ?? scope?.contactName ?? "";
  const fromRecord = email === null && Boolean(scope?.contactEmail);

  function reset() {
    setEmail(null);
    setName(null);
    setExpires("");
    setError(null);
    setSame(null);
    setLink(null);
  }

  function close() {
    setOpen(false);
    reset();
    // Drop the prefill from the address so a refresh doesn't reopen it.
    if (params.get("invite")) {
      const next = new URLSearchParams(params.toString());
      for (const k of ["invite", "role", "scopeId", "edition"]) next.delete(k);
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    }
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSame(null);
    if (scopeType && !scopeValue) {
      setError(
        role === "sponsor"
          ? "This event has no sponsors yet — add one on its Sponsorship page first."
          : `There's nothing to choose yet — add a ${role} first.`,
      );
      return;
    }
    start(async () => {
      const res = await inviteExternal({
        email: shownEmail,
        fullName: shownName || null,
        editionId,
        role,
        scopeType,
        scopeId: scopeType ? scopeValue : null,
        expiresAt: expires || null,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      if (res.data?.same) {
        setSame({ same: res.data.same, message: res.message ?? "They already have this access" });
        return;
      }
      toast.success(res.message ?? "Invitation sent");
      router.refresh();
      if (res.data?.inviteUrl) setLink(res.data.inviteUrl);
      else close();
    });
  }

  const changed = () => setSame(null);

  return (
    <>
      <Button type="button" onClick={() => setOpen(true)} className="h-11 sm:h-9">
        <UserPlus aria-hidden />
        Invite someone from outside
      </Button>
      <Dialog open={open} onOpenChange={(o) => (o ? setOpen(true) : close())}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{link ? "Invitation ready" : "Invite someone from outside"}</DialogTitle>
            <DialogDescription>
              {link
                ? "Email isn't set up here, so send them this link yourself. Only send it to them — it creates their account."
                : "Venues, suppliers and sponsors see only their own items for the event you choose."}
            </DialogDescription>
          </DialogHeader>
          {link ? (
            <>
              <CopyField value={absoluteLink(link)} label="Invitation link" />
              <DialogFooter>
                <Button variant="outline" onClick={reset}>
                  Invite another
                </Button>
                <Button onClick={close}>Done</Button>
              </DialogFooter>
            </>
          ) : (
            <form className="space-y-4" onSubmit={submit} aria-label="Invite someone from outside">
              <div className="space-y-1.5">
                <Label htmlFor="ext-event">Event</Label>
                <EventSelect
                  id="ext-event"
                  events={events}
                  value={editionId}
                  onChange={(v) => {
                    setEditionId(v);
                    changed();
                  }}
                  className="h-11 sm:h-9"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ext-role">They are a</Label>
                <SelectNative
                  id="ext-role"
                  value={role}
                  onChange={(e) => {
                    setRole(e.target.value);
                    changed();
                  }}
                  className="h-11 sm:h-9"
                >
                  {roles.map((r) => (
                    <option key={r.value} value={r.value}>
                      {r.label}
                    </option>
                  ))}
                </SelectNative>
              </div>
              {scopeType && (
                <div className="space-y-1.5">
                  <Label htmlFor="ext-scope">{scopeLabel}</Label>
                  <SelectNative
                    id="ext-scope"
                    value={scopeValue}
                    onChange={(e) => {
                      setScopeId(e.target.value);
                      changed();
                    }}
                    className="h-11 sm:h-9"
                    disabled={options.length === 0}
                  >
                    {options.length === 0 && <option value="">Nothing to choose yet</option>}
                    {options.map((o) => (
                      <option key={o.id} value={o.id}>
                        {o.label}
                      </option>
                    ))}
                  </SelectNative>
                </div>
              )}
              <div className="space-y-1.5">
                <Label htmlFor="ext-email">Email</Label>
                <Input
                  id="ext-email"
                  type="email"
                  required
                  value={shownEmail}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    changed();
                  }}
                  aria-describedby={fromRecord ? "ext-email-hint" : undefined}
                  className="h-11 sm:h-9"
                />
                {fromRecord && (
                  <p id="ext-email-hint" className="text-muted-foreground text-xs">
                    The contact on {scope?.label}&rsquo;s record — change it if someone else should
                    have access.
                  </p>
                )}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ext-name">
                  Their name <span className="text-muted-foreground font-normal">(optional)</span>
                </Label>
                <Input
                  id="ext-name"
                  value={shownName}
                  autoComplete="off"
                  onChange={(e) => setName(e.target.value)}
                  className="h-11 sm:h-9"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ext-expires">
                  Access ends <span className="text-muted-foreground font-normal">(optional)</span>
                </Label>
                <Input
                  id="ext-expires"
                  type="date"
                  min={today}
                  value={expires}
                  onChange={(e) => setExpires(e.target.value)}
                  aria-describedby="ext-expires-hint"
                  className="h-11 sm:h-9"
                />
                <p id="ext-expires-hint" className="text-muted-foreground text-xs">
                  They keep access until the end of that day.
                </p>
              </div>
              {same && (
                <SameAccessNotice
                  same={same.same}
                  message={same.message}
                  who={shownName || shownEmail}
                  emailOn={emailOn}
                  suggestedEnd={expires || null}
                  onLink={setLink}
                  onDone={close}
                />
              )}
              <FieldError message={error} />
              <DialogFooter>
                <Button type="button" variant="outline" onClick={close}>
                  Cancel
                </Button>
                <Button type="submit" disabled={pending || !editionId || Boolean(same)}>
                  {pending ? "Sending…" : "Send invitation"}
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Filter the access list by event (in the address, so it survives a reload). */
export function EventFilter({ events, value }: { events: EventOption[]; value: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  return (
    <EventSelect
      events={events}
      value={value}
      label="Event"
      allOption="All events"
      className="h-11 w-full sm:h-9 sm:w-auto sm:max-w-md"
      onChange={(v) => {
        const next = new URLSearchParams(params.toString());
        next.set("event", v);
        router.push(`${pathname}?${next.toString()}`, { scroll: false });
      }}
    />
  );
}

/** When one grant ends: a London date (the end of that day), or no end date. */
function EndDateDialog({
  open,
  onOpenChange,
  grantId,
  who,
  eventName,
  status,
  endsOn,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  grantId: string;
  who: string;
  eventName: string;
  status: GrantState;
  endsOn: string | null;
}) {
  const today = londonToday();
  const [date, setDate] = useState(endsOn && endsOn >= today ? endsOn : "");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const save = (value: string | null) =>
    start(async () => {
      setError(null);
      const res = await setPartnerAccessEnd({ grantId, date: value });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      toast.success(res.message ?? "End date saved");
      onOpenChange(false);
      router.refresh();
    });
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {status === "expired" ? `Extend ${who}'s access` : `When ${who}'s access ends`}
          </DialogTitle>
          <DialogDescription>
            {status === "expired"
              ? `Their access to ${eventName} ended${endsOn ? ` on ${formatDate(endsOn)}` : ""}. Give it a new end date, or none, and they can sign in again.`
              : `They can see ${eventName} until the end of the day you choose.`}
          </DialogDescription>
        </DialogHeader>
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            save(date || null);
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor={`end-${grantId}`}>Access ends</Label>
            <Input
              id={`end-${grantId}`}
              type="date"
              min={today}
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="h-11 sm:h-9"
            />
          </div>
          <FieldError message={error} />
          <DialogFooter>
            <Button type="button" variant="outline" disabled={pending} onClick={() => save(null)}>
              No end date
            </Button>
            <Button type="submit" disabled={pending || !date}>
              {pending ? "Saving…" : status === "expired" ? "Extend access" : "Save end date"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** Resend or Copy link (waiting invitations), the end date, and Revoke, for one grant. */
export function GrantActions({
  grantId,
  who,
  eventName,
  status,
  endsOn,
  emailOn,
}: {
  grantId: string;
  who: string;
  eventName: string;
  status: GrantState;
  /** The London date access ends (or ended) on. */
  endsOn: string | null;
  emailOn: boolean;
}) {
  const [pending, start] = useTransition();
  const [link, setLink] = useState<string | null>(null);
  const [ending, setEnding] = useState(false);
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const pendingInvite = status === "invited";
  return (
    <span className="inline-flex flex-wrap justify-end gap-1">
      {pendingInvite && (
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="h-11 sm:h-8"
          disabled={pending}
          aria-label={
            emailOn ? `Send the invitation to ${who} again` : `Copy an invitation link for ${who}`
          }
          onClick={() =>
            start(async () => {
              const res = await resendPartnerInvite({ grantId, linkOnly: !emailOn });
              if (!res.ok) {
                toast.error(res.error);
                return;
              }
              if (res.data?.inviteUrl) setLink(res.data.inviteUrl);
              else toast.success(res.message ?? "Invitation sent again");
              router.refresh();
            })
          }
        >
          {emailOn ? "Resend" : "Copy link"}
        </Button>
      )}
      <Button
        type="button"
        size="sm"
        variant={status === "expired" ? "outline" : "ghost"}
        className="h-11 sm:h-8"
        disabled={pending}
        aria-label={
          status === "expired" ? `Extend ${who}'s access` : `Change when ${who}'s access ends`
        }
        onClick={() => setEnding(true)}
      >
        {status === "expired" ? "Extend" : "End date"}
      </Button>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className="text-destructive hover:text-destructive h-11 sm:h-8"
        disabled={pending}
        aria-label={`Revoke access for ${who}`}
        onClick={async () => {
          const ok = await confirm({
            title: `Revoke ${who}'s access?`,
            description: `They lose access to ${eventName} straight away${pendingInvite ? " and the invitation link stops working" : ""}. You can invite them again later.`,
            confirmLabel: "Revoke access",
            destructive: true,
          });
          if (!ok) return;
          start(async () => {
            const res = await revokeGrant({ grantId });
            if (!res.ok) toast.error(res.error);
            else toast.success(res.message ?? "Access revoked");
            router.refresh();
          });
        }}
      >
        Revoke
      </Button>
      {ending && (
        <EndDateDialog
          open={ending}
          onOpenChange={setEnding}
          grantId={grantId}
          who={who}
          eventName={eventName}
          status={status}
          endsOn={endsOn}
        />
      )}
      <LinkDialog link={link} name={who} onClose={() => setLink(null)} />
      {confirmDialog}
    </span>
  );
}
