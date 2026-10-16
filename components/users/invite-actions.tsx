"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
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
import { cancelInvitation, newInvitationLink, resendInvitation } from "@/app/actions/users";
import { firstName } from "@/lib/users/rules";

/**
 * Invitation links are built from the site address; when that isn't
 * configured (local development) they come back relative, so complete them
 * with the address the admin is using before anyone copies them.
 */
export function absoluteLink(link: string): string {
  if (!link.startsWith("/") || typeof window === "undefined") return link;
  return `${window.location.origin}${link}`;
}

/** Shows a fresh invitation link to pass on by hand. */
export function LinkDialog({
  link,
  name,
  onClose,
}: {
  link: string | null;
  name: string;
  onClose: () => void;
}) {
  return (
    <Dialog open={link !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Invitation link for {name}</DialogTitle>
          <DialogDescription>
            Only send it to {name} — it creates their account. Any earlier link no longer works.
          </DialogDescription>
        </DialogHeader>
        {link && <CopyField value={absoluteLink(link)} label="Invitation link" />}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Done
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/**
 * What can be done with an invitation nobody has accepted yet. With email
 * set up: send it again. Without: get a link to pass on. Either way it can
 * be cancelled.
 */
export function InviteActions({
  inviteId,
  name,
  email,
  emailOn,
  size = "sm",
  onCancelled,
}: {
  inviteId: string;
  name: string;
  email: string;
  emailOn: boolean;
  size?: "sm" | "default";
  /** Where to go once cancelled (the person page has nothing left to show). */
  onCancelled?: () => void;
}) {
  const [link, setLink] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [confirmDialog, confirm] = useConfirm();
  const router = useRouter();
  const who = name || email;
  const first = firstName(name, email);

  function resend() {
    start(async () => {
      const res = await resendInvitation({ inviteId });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? "Invitation sent again");
      if (res.data?.inviteUrl) setLink(res.data.inviteUrl);
      router.refresh();
    });
  }

  function copyLink() {
    start(async () => {
      const res = await newInvitationLink({ inviteId });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      setLink(res.data!.inviteUrl);
      router.refresh();
    });
  }

  async function cancel() {
    if (
      !(await confirm({
        title: `Cancel ${first}'s invitation?`,
        description: `The link stops working and any sign-off it was going to give ${first} goes back to the department. You can invite ${email} again later.`,
        confirmLabel: "Cancel invitation",
        cancelLabel: "Keep it",
        destructive: true,
      }))
    ) {
      return;
    }
    start(async () => {
      const res = await cancelInvitation({ inviteId });
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message ?? "Invitation cancelled");
      if (onCancelled) onCancelled();
      else router.refresh();
    });
  }

  const touch = size === "sm" ? "h-11 sm:h-8" : "h-11 sm:h-9";
  return (
    <span className="inline-flex flex-wrap gap-2">
      {emailOn ? (
        <Button
          type="button"
          size={size}
          variant="outline"
          className={touch}
          disabled={pending}
          onClick={resend}
          aria-label={`Resend the invitation to ${who}`}
        >
          Resend
        </Button>
      ) : (
        <Button
          type="button"
          size={size}
          variant="outline"
          className={touch}
          disabled={pending}
          onClick={copyLink}
          aria-label={`Copy an invitation link for ${who}`}
        >
          Copy link
        </Button>
      )}
      <Button
        type="button"
        size={size}
        variant="ghost"
        className={`${touch} text-destructive hover:text-destructive`}
        disabled={pending}
        onClick={cancel}
        aria-label={`Cancel the invitation for ${who}`}
      >
        Cancel invitation
      </Button>
      <LinkDialog link={link} name={first} onClose={() => setLink(null)} />
      {confirmDialog}
    </span>
  );
}
