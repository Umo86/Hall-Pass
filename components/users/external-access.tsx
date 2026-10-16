"use client";

import { useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { UserPlus } from "lucide-react";
import { toast } from "sonner";
import { inviteExternal, revokeGrant } from "@/app/actions/settings";
import { newExternalLink } from "@/app/actions/users";
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
import { absoluteLink, LinkDialog } from "./invite-actions";
import { FieldError } from "./person-fields";

type ScopeOption = { id: string; label: string; editionId?: string };
export type EventOption = { id: string; label: string; upcoming: boolean };

const ROLES: { value: string; label: string; stands?: boolean }[] = [
  { value: "venue", label: "Venue" },
  { value: "supplier", label: "Supplier" },
  { value: "sponsor", label: "Sponsor" },
  { value: "structural_engineer", label: "Structural engineer", stands: true },
  { value: "hs", label: "Health & safety", stands: true },
  { value: "exhibitor", label: "Exhibitor", stands: true },
  { value: "contractor", label: "Contractor", stands: true },
];

const SCOPE_FOR: Record<string, "venue" | "supplier" | "exhibitor" | "sponsor" | null> = {
  venue: "venue",
  supplier: "supplier",
  sponsor: "sponsor",
  exhibitor: "exhibitor",
  contractor: "exhibitor",
  structural_engineer: null,
  hs: null,
};

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

/** "Invite someone from outside": a dialog with the current event chosen. */
export function ExternalInvite({
  events,
  defaultEventId,
  venues,
  suppliers,
  sponsors,
  exhibitors,
  showStandRoles,
  prefill,
}: {
  events: EventOption[];
  defaultEventId: string | null;
  venues: ScopeOption[];
  suppliers: ScopeOption[];
  sponsors: ScopeOption[];
  exhibitors: ScopeOption[];
  showStandRoles: boolean;
  prefill: { open: boolean; role: string | null; scopeId: string | null; editionId: string | null };
}) {
  const roles = ROLES.filter((r) => showStandRoles || !r.stands);
  const startRole = roles.some((r) => r.value === prefill.role) ? prefill.role! : "venue";
  const startEvent =
    events.find((e) => e.id === prefill.editionId)?.id ?? defaultEventId ?? events[0]?.id ?? "";
  const [open, setOpen] = useState(prefill.open);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState(startRole);
  const [editionId, setEditionId] = useState(startEvent);
  const [scopeId, setScopeId] = useState(prefill.scopeId ?? "");
  const [expires, setExpires] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [link, setLink] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

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
  const scopeLabel = scopeType === "venue" ? "Which venue" : "Which company";

  function close() {
    setOpen(false);
    setError(null);
    setLink(null);
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
        email,
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
      toast.success(res.message ?? "Invitation sent");
      router.refresh();
      if (res.data?.inviteUrl) setLink(res.data.inviteUrl);
      else {
        setEmail("");
        close();
      }
    });
  }

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
                <Button
                  variant="outline"
                  onClick={() => {
                    setLink(null);
                    setEmail("");
                  }}
                >
                  Invite another
                </Button>
                <Button onClick={close}>Done</Button>
              </DialogFooter>
            </>
          ) : (
            <form className="space-y-4" onSubmit={submit} aria-label="Invite someone from outside">
              <div className="space-y-1.5">
                <Label htmlFor="ext-email">Email</Label>
                <Input
                  id="ext-email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="h-11 sm:h-9"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ext-event">Event</Label>
                <EventSelect
                  id="ext-event"
                  events={events}
                  value={editionId}
                  onChange={setEditionId}
                  className="h-11 sm:h-9"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ext-role">They are a</Label>
                <SelectNative
                  id="ext-role"
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
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
                    onChange={(e) => setScopeId(e.target.value)}
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
                <Label htmlFor="ext-expires">
                  Access ends <span className="text-muted-foreground font-normal">(optional)</span>
                </Label>
                <Input
                  id="ext-expires"
                  type="date"
                  value={expires}
                  onChange={(e) => setExpires(e.target.value)}
                  className="h-11 sm:h-9"
                />
              </div>
              <FieldError message={error} />
              <DialogFooter>
                <Button type="button" variant="outline" onClick={close}>
                  Cancel
                </Button>
                <Button type="submit" disabled={pending || !editionId}>
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

/** Copy link (when email is off) and Revoke, for one external grant. */
export function GrantActions({
  grantId,
  who,
  eventName,
  pendingInvite,
  emailOn,
}: {
  grantId: string;
  who: string;
  eventName: string;
  /** Not accepted yet: a fresh link can be made. */
  pendingInvite: boolean;
  emailOn: boolean;
}) {
  const [pending, start] = useTransition();
  const [link, setLink] = useState<string | null>(null);
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  return (
    <span className="inline-flex flex-wrap justify-end gap-1">
      {pendingInvite && !emailOn && (
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="h-11 sm:h-8"
          disabled={pending}
          aria-label={`Copy an invitation link for ${who}`}
          onClick={() =>
            start(async () => {
              const res = await newExternalLink({ grantId });
              if (!res.ok) toast.error(res.error);
              else setLink(res.data!.inviteUrl);
            })
          }
        >
          Copy link
        </Button>
      )}
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
      <LinkDialog link={link} name={who} onClose={() => setLink(null)} />
      {confirmDialog}
    </span>
  );
}
