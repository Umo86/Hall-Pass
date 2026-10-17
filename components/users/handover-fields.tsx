"use client";

import Link from "next/link";
import { roleLabel } from "@/lib/format";
import { BACK_TO_DEPARTMENT, type HandoverChoice, type HandoverGroup } from "@/lib/users/handover";
import { Label } from "@/components/ui/label";
import { SelectNative } from "@/components/ui/select-native";

export type HandoverCandidateView = {
  userId: string;
  name: string;
  role: string;
  departmentId: string | null;
};

/** Each group's starting choice: its default, or nothing (someone must be picked). */
export function defaultHandover(groups: readonly HandoverGroup[]): HandoverChoice {
  return Object.fromEntries(groups.map((g) => [g.key, g.defaultTo ?? ""]));
}

/** The first group still needing a choice, as words to show; null when all are chosen. */
export function missingHandover(
  groups: readonly HandoverGroup[],
  choice: HandoverChoice,
  who: string,
): string | null {
  const g = groups.find((x) => !choice[x.key]);
  if (!g) return null;
  return g.departmentName
    ? `Choose who takes over ${who}'s ${g.departmentName} sign-offs`
    : `Choose who takes over ${who}'s other sign-offs`;
}

/**
 * Who takes over each department's sign-offs that name someone: the
 * department's approvers who can sign first (main approver as the
 * default), "everyone who signs off for it", or anyone else who can sign.
 * `signersOnly` (the viewer isn't a super admin): a department's sign-offs
 * go only to its own approvers or back to it, as the server allows.
 */
export function HandoverFields({
  idPrefix,
  groups,
  candidates,
  value,
  onChange,
  who,
  currentUserId,
  signersOnly = false,
}: {
  idPrefix: string;
  groups: readonly HandoverGroup[];
  candidates: readonly HandoverCandidateView[];
  value: HandoverChoice;
  onChange: (value: HandoverChoice) => void;
  /** Their first name, for the labels. */
  who: string;
  currentUserId: string;
  signersOnly?: boolean;
}) {
  if (groups.length === 0) return null;
  return (
    <div className="space-y-3">
      {groups.map((g) => {
        const signerIds = new Set(g.signers.map((s) => s.userId));
        const others =
          signersOnly && g.departmentId ? [] : candidates.filter((c) => !signerIds.has(c.userId));
        const later = g.steps.length - g.waitingNow;
        const id = `${idPrefix}-${g.key}`;
        const label = [
          g.waitingNow > 0
            ? `${g.waitingNow} ${g.waitingNow === 1 ? "is" : "are"} waiting on ${who} now`
            : null,
          later > 0 ? `${later} ${later === 1 ? "comes" : "come"} back to ${who} later` : null,
        ]
          .filter(Boolean)
          .join(", ");
        return (
          <div key={g.key} className="space-y-1.5">
            <Label htmlFor={id} className="block">
              {g.departmentName ? `${g.departmentName} sign-offs` : "Other sign-offs"}
              <span className="text-muted-foreground block text-xs font-normal">
                {g.steps.length === 1 ? "1 sign-off" : `${g.steps.length} sign-offs`} ({label}):{" "}
                {g.steps.slice(0, 5).map((s, i) => (
                  <span key={s.id}>
                    {i > 0 && ", "}
                    {s.href ? (
                      <Link href={s.href} className="link" target="_blank">
                        {s.ref}
                      </Link>
                    ) : (
                      s.ref
                    )}
                  </span>
                ))}
                {g.steps.length > 5 ? ` and ${g.steps.length - 5} more` : ""}
              </span>
            </Label>
            <SelectNative
              id={id}
              value={value[g.key] ?? ""}
              onChange={(e) => onChange({ ...value, [g.key]: e.target.value })}
              className="h-11 sm:h-9"
              aria-invalid={!value[g.key]}
            >
              {!g.defaultTo && <option value="">Choose a person…</option>}
              {g.signers.length > 0 && (
                <optgroup label={`${g.departmentName} approvers`}>
                  {g.signers.map((s) => (
                    <option key={s.userId} value={s.userId}>
                      {s.userId === currentUserId ? `${s.name} (you)` : s.name}
                      {s.isMain ? " — main approver" : ""}
                    </option>
                  ))}
                  <option value={BACK_TO_DEPARTMENT}>
                    Everyone who signs off for {g.departmentName}
                  </option>
                </optgroup>
              )}
              {others.length > 0 && (
                <optgroup label={g.signers.length > 0 ? "Someone else" : "People who can sign off"}>
                  {others.map((c) => (
                    <option key={c.userId} value={c.userId}>
                      {c.userId === currentUserId ? `${c.name} (you)` : c.name} —{" "}
                      {roleLabel(c.role)}
                    </option>
                  ))}
                </optgroup>
              )}
            </SelectNative>
            {g.departmentId && g.signers.length === 0 && (
              <p className="text-muted-foreground text-xs">
                {signersOnly
                  ? `Nobody else can sign off for ${g.departmentName} now — ask a super admin to choose who takes these over.`
                  : `Nobody else can sign off for ${g.departmentName} now, so pick someone to name on these.`}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}
