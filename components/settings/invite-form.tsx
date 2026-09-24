"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { inviteExternal, revokeGrant } from "@/app/actions/settings";

type ScopeOption = { id: string; label: string; editionId?: string };

export function InviteExternalForm({
  editions,
  venues,
  suppliers,
  exhibitors,
  sponsors,
  showStandRoles = false,
}: {
  editions: ScopeOption[];
  venues: ScopeOption[];
  suppliers: ScopeOption[];
  exhibitors: ScopeOption[];
  sponsors: ScopeOption[];
  /** Stand approvals are hidden, so their roles are too. */
  showStandRoles?: boolean;
}) {
  const [role, setRole] = useState("venue");
  const [editionId, setEditionId] = useState(editions[0]?.id ?? "");
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const scopeMap: Record<string, { type: string | null; options: ScopeOption[] }> = {
    venue: { type: "venue", options: venues },
    supplier: { type: "supplier", options: suppliers },
    exhibitor: { type: "exhibitor", options: exhibitors },
    contractor: { type: "exhibitor", options: exhibitors },
    sponsor: { type: "sponsor", options: sponsors },
    structural_engineer: { type: null, options: [] },
    hs: { type: null, options: [] },
  };
  const scope = scopeMap[role];
  // Sponsors and exhibitors belong to one show: offer only the chosen show's.
  const scopeOptions = scope.options.filter((o) => !o.editionId || o.editionId === editionId);

  return (
    <form
      className="grid gap-3 sm:grid-cols-2"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        setError(null);
        setInviteUrl(null);
        start(async () => {
          const res = await inviteExternal({
            email: fd.get("email"),
            editionId: fd.get("editionId"),
            role,
            scopeType: scope.type,
            scopeId: scope.type ? fd.get("scopeId") : null,
            expiresAt: fd.get("expiresAt") || null,
          });
          if (!res.ok) setError(res.error);
          else {
            setInviteUrl(res.data?.inviteUrl ?? null);
            router.refresh();
          }
        });
      }}
    >
      <div className="space-y-1.5">
        <Label htmlFor="inv-email">Email</Label>
        <Input id="inv-email" name="email" type="email" required />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="inv-edition">Edition</Label>
        <SelectNative
          id="inv-edition"
          name="editionId"
          required
          value={editionId}
          onChange={(e) => setEditionId(e.target.value)}
        >
          {editions.map((e) => (
            <option key={e.id} value={e.id}>
              {e.label}
            </option>
          ))}
        </SelectNative>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="inv-role">Role</Label>
        <SelectNative id="inv-role" value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="venue">Venue</option>
          <option value="supplier">Supplier</option>
          <option value="sponsor">Sponsor</option>
          {showStandRoles && (
            <>
              <option value="structural_engineer">Structural engineer</option>
              <option value="hs">Health &amp; safety</option>
              <option value="exhibitor">Exhibitor</option>
              <option value="contractor">Contractor</option>
            </>
          )}
        </SelectNative>
      </div>
      {scope.type && (
        <div className="space-y-1.5">
          <Label htmlFor="inv-scope">Scoped to</Label>
          {scopeOptions.length === 0 && (
            <p className="text-muted-foreground text-xs">
              Nothing to choose yet — add a {role === "sponsor" ? "sponsor on the Sponsorship page" : `${role} first`}.
            </p>
          )}
          <SelectNative id="inv-scope" name="scopeId" required>
            {scopeOptions.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </SelectNative>
        </div>
      )}
      <div className="space-y-1.5">
        <Label htmlFor="inv-expiry">Expires (optional)</Label>
        <Input id="inv-expiry" name="expiresAt" type="date" />
      </div>
      <div className="flex items-end">
        <Button type="submit" disabled={pending}>
          Create invitation
        </Button>
      </div>
      {inviteUrl && (
        <p className="text-sm sm:col-span-2">
          Share this link: <code className="bg-muted rounded px-1.5 py-0.5">{inviteUrl}</code>
        </p>
      )}
      {error && <p className="text-destructive text-sm sm:col-span-2">{error}</p>}
    </form>
  );
}

export function RevokeGrantButton({ grantId }: { grantId: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      size="sm"
      variant="outline"
      disabled={pending}
      onClick={() =>
        start(async () => {
          await revokeGrant({ grantId });
          router.refresh();
        })
      }
    >
      Revoke
    </Button>
  );
}
