"use client";

import { useId, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { KeyRound, UserPlus } from "lucide-react";
import { toast } from "sonner";
import { inviteExternal } from "@/app/actions/settings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { CopyField } from "@/components/copy-field";
import { GrantActions, londonToday, SameAccessNotice } from "@/components/users/external-access";
import type { SameAccess } from "@/app/actions/settings";
import { cn } from "@/lib/utils";
import { formatDate } from "@/lib/format";
import { GRANT_STATUS_LABELS, portalSummary } from "./summary";
import type { PortalGrant } from "./grants";

export type PortalEvent = { id: string; label: string; upcoming: boolean };

type Props = {
  scopeType: "supplier" | "venue";
  scopeId: string;
  scopeName: string;
  grants: PortalGrant[];
  /** The events an invitation can be for (for a venue: its own events). */
  events: PortalEvent[];
  defaultEventId: string | null;
  /** Whoever may invite partners invites and revokes; everyone else who sees this reads it. */
  canInvite: boolean;
  emailOn: boolean;
  /** The contact on the supplier's or venue's record, to fill the invitation in. */
  contact?: { name: string | null; email: string | null } | null;
};

const TONE: Record<PortalGrant["status"], string> = {
  active: "bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300",
  invited: "bg-sky-50 text-sky-800 dark:bg-sky-950 dark:text-sky-300",
  expired: "bg-amber-50 text-amber-900 dark:bg-amber-950 dark:text-amber-300",
};

/**
 * "2 people can sign in · Manage" next to a supplier or venue; opens the
 * portal access dialog for it.
 */
export function PortalAccessButton(props: Props & { className?: string }) {
  const [open, setOpen] = useState(false);
  const summary = portalSummary(props.grants);
  const none = props.grants.length === 0;
  if (none && !props.canInvite) return null;
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          "text-muted-foreground hover:text-foreground inline-flex min-h-8 items-center gap-1.5 text-left text-xs",
          props.className,
        )}
        aria-label={`Portal access for ${props.scopeName}: ${summary}. Manage`}
      >
        <KeyRound className="size-3.5 shrink-0" aria-hidden />
        <span>
          {none ? "No portal access" : summary}
          <span aria-hidden> · </span>
          <span className="link">{none ? "Invite" : "Manage"}</span>
        </span>
      </button>
      <PortalAccessDialog {...props} open={open} onOpenChange={setOpen} />
    </>
  );
}

/** The portal access dialog for one supplier or venue. */
export function PortalAccessDialog({
  open,
  onOpenChange,
  ...props
}: Props & { open: boolean; onOpenChange: (open: boolean) => void }) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Portal access · {props.scopeName}</DialogTitle>
          <DialogDescription>
            {props.scopeType === "supplier"
              ? `People from ${props.scopeName} sign in to a portal that shows only the items ${props.scopeName} supplies, for the event they are invited to.`
              : `People from ${props.scopeName} sign in to see and approve signage for the event they are invited to.`}
          </DialogDescription>
        </DialogHeader>
        <PortalAccessPanel {...props} />
      </DialogContent>
    </Dialog>
  );
}

function PortalAccessPanel({
  scopeType,
  scopeId,
  scopeName,
  grants,
  events,
  defaultEventId,
  canInvite,
  emailOn,
  contact,
}: Props) {
  const [inviting, setInviting] = useState(false);
  return (
    <div className="space-y-4">
      {grants.length === 0 ? (
        <p className="text-muted-foreground rounded-md border border-dashed px-3 py-4 text-center text-sm">
          Nobody from {scopeName} can sign in yet.
        </p>
      ) : (
        <ul className="divide-y rounded-lg border" aria-label={`Portal access for ${scopeName}`}>
          {grants.map((g) => (
            <li key={g.id} className="flex flex-wrap items-start justify-between gap-2 px-3 py-2.5">
              <div className="min-w-0 text-sm">
                <p className="font-medium break-words">{g.name || g.email}</p>
                {g.name && <p className="text-muted-foreground text-xs break-all">{g.email}</p>}
                <p className="text-muted-foreground text-xs">
                  {g.eventName} ({g.eventCode})
                  {g.endsOn
                    ? ` · ${g.status === "expired" ? "ended" : "ends"} ${formatDate(g.endsOn)}`
                    : ""}
                </p>
                <span
                  className={cn(
                    "mt-1 inline-flex rounded-md px-2 py-0.5 text-xs font-medium",
                    TONE[g.status],
                  )}
                >
                  {GRANT_STATUS_LABELS[g.status]}
                </span>
              </div>
              {canInvite && (
                <GrantActions
                  grantId={g.id}
                  who={g.name || g.email}
                  eventName={g.eventName}
                  status={g.status}
                  endsOn={g.endsOn}
                  emailOn={emailOn}
                />
              )}
            </li>
          ))}
        </ul>
      )}

      {canInvite ? (
        inviting ? (
          <InviteForm
            scopeType={scopeType}
            scopeId={scopeId}
            scopeName={scopeName}
            events={events}
            defaultEventId={defaultEventId}
            contact={grants.length === 0 ? contact : null}
            emailOn={emailOn}
            onDone={() => setInviting(false)}
          />
        ) : events.length === 0 ? (
          <p className="text-muted-foreground text-sm">
            {scopeType === "venue"
              ? `There are no events at ${scopeName} to invite people to (archived events take no invitations). Create one first; then you can invite people from the venue.`
              : "Create an event first; then you can invite people from this company."}
          </p>
        ) : (
          <Button type="button" variant="outline" onClick={() => setInviting(true)}>
            <UserPlus aria-hidden />
            Invite someone from {scopeName}
          </Button>
        )
      ) : (
        <p className="text-muted-foreground text-sm">
          Inviting people or taking access away needs &ldquo;Invite partners&rdquo; — ask a super
          admin.
        </p>
      )}
      {canInvite && (
        <p className="text-muted-foreground text-xs">
          Everyone from outside the team is listed in{" "}
          <Link href="/users?tab=external" className="link">
            Users → External
          </Link>
          .
        </p>
      )}
    </div>
  );
}

function InviteForm({
  scopeType,
  scopeId,
  scopeName,
  events,
  defaultEventId,
  contact,
  emailOn,
  onDone,
}: {
  scopeType: "supplier" | "venue";
  scopeId: string;
  scopeName: string;
  events: PortalEvent[];
  defaultEventId: string | null;
  /** Filled in from the record until typed over (only while nobody there has access). */
  contact?: { name: string | null; email: string | null } | null;
  emailOn: boolean;
  onDone: () => void;
}) {
  const ids = useId();
  const [email, setEmail] = useState(contact?.email ?? "");
  const [name, setName] = useState(contact?.name ?? "");
  const [editionId, setEditionId] = useState(
    events.find((e) => e.id === defaultEventId)?.id ?? events[0]?.id ?? "",
  );
  const [expires, setExpires] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [same, setSame] = useState<{ same: SameAccess; message: string } | null>(null);
  const [link, setLink] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const upcoming = events.filter((e) => e.upcoming);
  const past = events.filter((e) => !e.upcoming);
  const errorId = `${ids}-error`;
  const today = londonToday();
  const fromRecord = Boolean(contact?.email) && email === contact?.email;

  if (link) {
    return (
      <div className="space-y-3 rounded-lg border p-3" role="status">
        <p className="text-sm">
          Email isn&rsquo;t set up here, so send them this link yourself. Only send it to them.
        </p>
        <CopyField
          value={link.startsWith("/") ? `${window.location.origin}${link}` : link}
          label="Invitation link"
        />
        <div className="flex flex-wrap gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              setLink(null);
              setEmail("");
              setName("");
              setSame(null);
            }}
          >
            Invite someone else
          </Button>
          <Button type="button" onClick={onDone}>
            Done
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form
      className="space-y-3 rounded-lg border p-3"
      aria-label={`Invite someone from ${scopeName}`}
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setSame(null);
        start(async () => {
          const res = await inviteExternal({
            email,
            fullName: name || null,
            editionId,
            role: scopeType,
            scopeType,
            scopeId,
            expiresAt: expires || null,
          });
          if (!res.ok) {
            setError(res.error);
            return;
          }
          if (res.data?.same) {
            setSame({
              same: res.data.same,
              message: res.message ?? "They already have this access",
            });
            return;
          }
          toast.success(res.message ?? `Invitation sent to ${email}`);
          router.refresh();
          if (res.data?.inviteUrl) setLink(res.data.inviteUrl);
          else onDone();
        });
      }}
    >
      <p className="text-sm font-medium">Invite someone from {scopeName}</p>
      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-email`}>Their email</Label>
        <Input
          id={`${ids}-email`}
          type="email"
          required
          autoFocus
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            setSame(null);
          }}
          aria-invalid={error ? true : undefined}
          aria-describedby={
            [error ? errorId : null, fromRecord ? `${ids}-hint` : null].filter(Boolean).join(" ") ||
            undefined
          }
          className="h-11 sm:h-9"
        />
        {fromRecord && (
          <p id={`${ids}-hint`} className="text-muted-foreground text-xs">
            The contact on {scopeName}&rsquo;s record — change it if someone else should have
            access.
          </p>
        )}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-name`}>
          Their name <span className="text-muted-foreground font-normal">(optional)</span>
        </Label>
        <Input
          id={`${ids}-name`}
          value={name}
          autoComplete="off"
          onChange={(e) => setName(e.target.value)}
          className="h-11 sm:h-9"
        />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-event`}>Event</Label>
        <SelectNative
          id={`${ids}-event`}
          value={editionId}
          onChange={(e) => {
            setEditionId(e.target.value);
            setSame(null);
          }}
          className="h-11 sm:h-9"
        >
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
      </div>
      <div className="space-y-1.5">
        <Label htmlFor={`${ids}-expires`}>
          Access ends <span className="text-muted-foreground font-normal">(optional)</span>
        </Label>
        <Input
          id={`${ids}-expires`}
          type="date"
          min={today}
          value={expires}
          onChange={(e) => setExpires(e.target.value)}
          className="h-11 sm:h-9"
        />
        <p className="text-muted-foreground text-xs">They keep access until the end of that day.</p>
      </div>
      {same && (
        <SameAccessNotice
          same={same.same}
          message={same.message}
          who={name || email}
          emailOn={emailOn}
          suggestedEnd={expires || null}
          onLink={setLink}
          onDone={onDone}
        />
      )}
      {error && (
        <p id={errorId} role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
      <div className="flex flex-wrap justify-end gap-2">
        <Button type="button" variant="outline" onClick={onDone} disabled={pending}>
          Cancel
        </Button>
        <Button type="submit" disabled={pending || !editionId || Boolean(same)}>
          {pending ? "Sending…" : "Send invitation"}
        </Button>
      </div>
    </form>
  );
}
