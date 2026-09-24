"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { roleLabel } from "@/lib/format";
import { OVERRIDE_KEYS, type OverrideKey, type PermissionOverrides, type StaffRole } from "@/lib/authz";
import {
  inviteStaff,
  removeStaffMember,
  revokeStaffInvite,
  updateStaffOverrides,
  updateStaffRole,
} from "@/app/actions/team";

const ROLES: StaffRole[] = ["admin", "ops", "marketing", "sales", "event_director", "viewer"];

const KEY_LABELS: Record<OverrideKey, string> = {
  "signage.create": "Add signage",
  "sponsorship.create": "Add sponsorship items",
  "costs.edit": "Edit costs",
  "approval.decide": "Approve / sign off (when assigned)",
  "settings.manage": "Manage settings",
};

/** Mirrors the role defaults in lib/authz.ts so the checkboxes show the
 * effective ability; only differences from the default are stored. */
const ROLE_DEFAULTS: Record<OverrideKey, StaffRole[]> = {
  "signage.create": ["admin", "ops", "marketing"],
  "sponsorship.create": ["admin", "ops", "sales"],
  "costs.edit": ["admin", "ops"],
  "approval.decide": ["admin", "ops", "marketing", "sales", "event_director", "viewer"],
  "settings.manage": ["admin", "ops"],
};

export type TeamMember = {
  membershipId: string;
  userId: string;
  name: string;
  email: string;
  role: StaffRole;
  overrides: PermissionOverrides;
};

export type PendingInvite = { id: string; email: string; role: StaffRole };

function effective(key: OverrideKey, role: StaffRole, overrides: PermissionOverrides): boolean {
  return overrides[key] ?? ROLE_DEFAULTS[key].includes(role);
}

function MemberRow({ member, isSelf }: { member: TeamMember; isSelf: boolean }) {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function changeRole(role: string) {
    const label = roleLabel(role);
    if (
      !window.confirm(
        `Make ${member.name || member.email} ${label}? Any custom permissions go back to that role's defaults.`,
      )
    ) {
      router.refresh();
      return;
    }
    setError(null);
    start(async () => {
      const res = await updateStaffRole({ membershipId: member.membershipId, role });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  function remove() {
    if (
      !window.confirm(
        `Remove ${member.name || member.email} from the team? They lose access straight away.`,
      )
    ) {
      return;
    }
    setError(null);
    start(async () => {
      const res = await removeStaffMember({ membershipId: member.membershipId });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  function toggle(key: OverrideKey, checked: boolean) {
    // Store only what differs from the role default; approval true is
    // meaningless (assignment still rules), so it is treated as default.
    const next: PermissionOverrides = {};
    for (const k of OVERRIDE_KEYS) {
      const value = k === key ? checked : effective(k, member.role, member.overrides);
      if (value !== ROLE_DEFAULTS[k].includes(member.role)) next[k] = value;
    }
    setError(null);
    start(async () => {
      const res = await updateStaffOverrides({ membershipId: member.membershipId, overrides: next });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  function reset() {
    setError(null);
    start(async () => {
      const res = await updateStaffOverrides({ membershipId: member.membershipId, overrides: {} });
      if (!res.ok) setError(res.error);
      router.refresh();
    });
  }

  const hasOverrides = Object.keys(member.overrides).length > 0;

  return (
    <li className="p-3">
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium">
            {member.name || member.email}
            {isSelf && <span className="text-muted-foreground ml-1 text-xs">(you)</span>}
          </p>
          <p className="text-muted-foreground truncate text-xs">{member.email}</p>
        </div>
        <SelectNative
          aria-label={`Role for ${member.email}`}
          value={member.role}
          disabled={isSelf || pending}
          onChange={(e) => changeRole(e.target.value)}
          className="w-40"
        >
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {roleLabel(r)}
            </option>
          ))}
        </SelectNative>
        {!isSelf && (
          <Button size="sm" variant="ghost" disabled={pending} onClick={remove}>
            Remove
          </Button>
        )}
      </div>
      {member.role === "admin" ? (
        <p className="text-muted-foreground mt-1 text-xs">Full access</p>
      ) : (
        <details className="mt-1">
          <summary className="text-muted-foreground cursor-pointer text-xs select-none">
            Permissions{hasOverrides ? " (customised)" : ""}
          </summary>
          <div className="mt-2 grid gap-1.5 sm:grid-cols-2">
            {OVERRIDE_KEYS.map((key) => (
              <label key={key} className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  className="size-4"
                  disabled={pending}
                  checked={effective(key, member.role, member.overrides)}
                  onChange={(e) => toggle(key, e.target.checked)}
                />
                {KEY_LABELS[key]}
              </label>
            ))}
          </div>
          {hasOverrides && (
            <button
              type="button"
              className="text-muted-foreground mt-2 text-xs underline"
              onClick={reset}
              disabled={pending}
            >
              Reset to role defaults
            </button>
          )}
        </details>
      )}
      {error && <p className="text-destructive mt-1 text-xs">{error}</p>}
    </li>
  );
}

export function TeamTable({
  members,
  invites,
  currentUserId,
  canManage,
}: {
  members: TeamMember[];
  invites: PendingInvite[];
  currentUserId: string;
  canManage: boolean;
}) {
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  if (!canManage) {
    return (
      <div className="overflow-x-auto rounded-lg border">
        <table className="w-full text-sm">
          <tbody>
            {members.map((m) => (
              <tr key={m.membershipId} className="border-b last:border-0">
                <td className="px-3 py-2 font-medium">{m.name || m.email}</td>
                <td className="text-muted-foreground px-3 py-2">{m.email}</td>
                <td className="px-3 py-2">{roleLabel(m.role)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <ul className="divide-y rounded-lg border">
        {members.map((m) => (
          <MemberRow key={m.membershipId} member={m} isSelf={m.userId === currentUserId} />
        ))}
      </ul>

      <div className="rounded-lg border p-4">
        <h3 className="mb-3 text-sm font-medium">Invite a staff member</h3>
        <form
          className="flex flex-wrap items-end gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            const fd = new FormData(e.currentTarget);
            setError(null);
            setInviteUrl(null);
            start(async () => {
              setCopied(false);
              const res = await inviteStaff({ email: fd.get("email"), role: fd.get("role") });
              if (!res.ok) setError(res.error);
              else {
                setInviteUrl(res.data?.inviteUrl ?? null);
                router.refresh();
              }
            });
          }}
        >
          <div className="min-w-52 flex-1 space-y-1.5">
            <Label htmlFor="staff-email">Email</Label>
            <Input id="staff-email" name="email" type="email" required />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="staff-role">Role</Label>
            <SelectNative id="staff-role" name="role" defaultValue="ops">
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {roleLabel(r)}
                </option>
              ))}
            </SelectNative>
          </div>
          <Button type="submit" disabled={pending}>
            Create invitation
          </Button>
        </form>
        {inviteUrl && (
          <div className="mt-2 space-y-1 text-sm">
            <div className="flex flex-wrap items-center gap-2">
              <code className="bg-muted min-w-0 flex-1 rounded px-1.5 py-0.5 break-all">
                {inviteUrl}
              </code>
              <Button
                type="button"
                size="sm"
                variant="outline"
                onClick={() => {
                  void navigator.clipboard?.writeText(inviteUrl);
                  setCopied(true);
                }}
              >
                {copied ? "Copied" : "Copy link"}
              </Button>
            </div>
            <p className="text-muted-foreground text-xs">
              Send them this link — or just ask them to sign in with that email address; the
              invitation is applied automatically.
            </p>
          </div>
        )}
        {error && <p className="text-destructive mt-2 text-sm">{error}</p>}
        {invites.length > 0 && (
          <ul className="mt-3 space-y-1">
            {invites.map((inv) => (
              <li key={inv.id} className="flex items-center gap-2 text-sm">
                <span className="min-w-0 flex-1 truncate">
                  {inv.email} <span className="text-muted-foreground">· {roleLabel(inv.role)} · invited</span>
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={pending}
                  onClick={() =>
                    start(async () => {
                      await revokeStaffInvite({ inviteId: inv.id });
                      router.refresh();
                    })
                  }
                >
                  Revoke
                </Button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
