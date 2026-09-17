"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";
import { inviteExternal, revokeGrant } from "@/app/actions/settings";

type ScopeOption = { id: string; label: string };

export function InviteExternalForm({
  editions,
  venues,
  suppliers,
  exhibitors,
  sponsors,
}: {
  editions: ScopeOption[];
  venues: ScopeOption[];
  suppliers: ScopeOption[];
  exhibitors: ScopeOption[];
  sponsors: ScopeOption[];
}) {
  const [role, setRole] = useState("venue");
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
        <SelectNative id="inv-edition" name="editionId" required>
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
          <option value="structural_engineer">Structural engineer</option>
          <option value="hs">Health &amp; safety</option>
          <option value="supplier">Supplier</option>
          <option value="exhibitor">Exhibitor</option>
          <option value="contractor">Contractor</option>
          <option value="sponsor">Sponsor</option>
        </SelectNative>
      </div>
      {scope.type && (
        <div className="space-y-1.5">
          <Label htmlFor="inv-scope">Scoped to</Label>
          <SelectNative id="inv-scope" name="scopeId" required>
            {scope.options.map((o) => (
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
