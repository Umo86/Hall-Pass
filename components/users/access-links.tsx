"use client";

import { useState, useTransition } from "react";
import { KeyRound, LogIn } from "lucide-react";
import { toast } from "sonner";
import { createAccessLink } from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { CopyField } from "@/components/copy-field";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

type Kind = "sign_in" | "password_reset";

const LABEL: Record<Kind, string> = {
  sign_in: "Sign-in link",
  password_reset: "Password reset link",
};

/**
 * Super admins: a one-time sign-in or password reset link for someone, to
 * pass on when email isn't set up (or the email didn't arrive). Each click
 * makes a new link; it works once, for the next hour, and is audited.
 */
export function AccessLinks({
  userId,
  firstName,
  emailOn,
}: {
  userId: string;
  firstName: string;
  emailOn: boolean;
}) {
  const [pending, start] = useTransition();
  const [link, setLink] = useState<{ kind: Kind; url: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  function make(kind: Kind) {
    setError(null);
    start(async () => {
      const res = await createAccessLink({ userId, kind });
      if (!res.ok || !res.data) {
        const message = res.ok ? "Could not make a link — try again" : res.error;
        setLink(null);
        setError(message);
        toast.error(message);
        return;
      }
      setLink({ kind, url: res.data.url });
      toast.success(res.message ?? "Link ready");
    });
  }

  const kinds: Kind[] = ["sign_in", "password_reset"];

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-2">
        {kinds.map((kind) => (
          <Button
            key={kind}
            type="button"
            variant="outline"
            className="h-11 sm:h-9"
            disabled={pending}
            onClick={() => make(kind)}
          >
            {kind === "sign_in" ? <LogIn aria-hidden /> : <KeyRound aria-hidden />}
            {kind === "sign_in" ? "Copy a sign-in link" : "Copy a password reset link"}
          </Button>
        ))}
      </div>
      {link && (
        <div className="space-y-1.5 text-left">
          <CopyField value={link.url} label={LABEL[link.kind]} />
          <p className="text-muted-foreground text-xs">
            Works once, for the next hour. Anyone with this link can get in as {firstName} — send it
            only to them.
            {emailOn && " Email is set up, so they can also use “Forgot password?” themselves."}
          </p>
        </div>
      )}
      {error && (
        <p role="alert" className="text-destructive text-sm">
          {error}
        </p>
      )}
    </div>
  );
}

/**
 * Users → External, accepted partners (super admins): "Copy a sign-in link"
 * as one compact button; the link opens in a dialog to copy.
 */
export function PartnerSignInLink({
  userId,
  who,
  emailOn,
}: {
  userId: string;
  who: string;
  emailOn: boolean;
}) {
  const [pending, start] = useTransition();
  const [url, setUrl] = useState<string | null>(null);
  const first = who.trim().split(/\s+/)[0] || who;
  return (
    <>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className="h-11 sm:h-8"
        disabled={pending}
        aria-label={`Copy a sign-in link for ${who}`}
        onClick={() =>
          start(async () => {
            const res = await createAccessLink({ userId, kind: "sign_in" });
            if (!res.ok || !res.data) {
              toast.error(res.ok ? "Could not make a link — try again" : res.error);
              return;
            }
            setUrl(res.data.url);
          })
        }
      >
        Copy a sign-in link
      </Button>
      <Dialog open={url !== null} onOpenChange={(open) => !open && setUrl(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Sign-in link for {who}</DialogTitle>
            <DialogDescription>
              Works once, for the next hour. Anyone with this link can get in as {first} — send it
              only to them.
              {emailOn && " Email is set up, so they can also use “Forgot password?” themselves."}
            </DialogDescription>
          </DialogHeader>
          {url && <CopyField value={url} label="Sign-in link" />}
          <DialogFooter>
            <Button variant="outline" onClick={() => setUrl(null)}>
              Done
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
