"use client";

import { useRouter } from "next/navigation";
import { MailCheck } from "lucide-react";
import { cn } from "@/lib/utils";
import { InviteActions } from "./invite-actions";

/** The box at the top of an invited person's page: when, until when, and what to do. */
export function InviteStatus({
  inviteId,
  name,
  email,
  statusText,
  expires,
  expired,
  emailOn,
  canRenew = true,
}: {
  inviteId: string;
  name: string;
  email: string;
  statusText: string;
  expires: string | null;
  expired: boolean;
  emailOn: boolean;
  /** False when only a super admin may send it again (it gives more than the viewer can). */
  canRenew?: boolean;
}) {
  const router = useRouter();
  return (
    <section
      className={cn(
        "flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:items-center",
        expired
          ? "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200"
          : "bg-muted/30",
      )}
      aria-label="Invitation"
    >
      <MailCheck className="hidden size-5 shrink-0 sm:block" aria-hidden />
      <div className="min-w-0 flex-1 text-sm">
        <p className="font-medium">
          {statusText}
          {!expired && expires ? ` · link expires ${expires}` : ""}
        </p>
        <p className={expired ? "" : "text-muted-foreground"}>
          {expired
            ? canRenew
              ? "The link no longer works. Send a new one — what's below still applies."
              : "The link no longer works. Only a super admin can send a new one: it gives access you can't give."
            : "Changes you save here apply when they accept."}
        </p>
      </div>
      <InviteActions
        inviteId={inviteId}
        name={name}
        email={email}
        emailOn={emailOn}
        canRenew={canRenew}
        size="default"
        onCancelled={() => {
          router.push("/users");
          router.refresh();
        }}
      />
    </section>
  );
}
