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
  DialogTrigger,
} from "@/components/ui/dialog";
import { PersonPicker } from "@/components/people/person-picker";
import { nameOf, type PersonOption } from "@/components/people/groups";
import { delegateApproval } from "@/app/actions/approvals";

/**
 * Hand a sign-off to someone else. Offers only people who can sign now
 * (peopleFor(…, { type: "signoff" }) in lib/people.ts), grouped by
 * department; not shown at all when there is nobody to hand it to.
 */
export function DelegateButton({
  instanceId,
  users,
  currentUserId,
}: {
  instanceId: string;
  users: PersonOption[];
  /** Who the step is with now: left out of the list. */
  currentUserId?: string | null;
}) {
  const [open, setOpen] = useState(false);
  const [toUserId, setToUserId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();
  const choices = users.filter((u) => u.id !== currentUserId && !u.unavailable);
  if (choices.length === 0) return null;

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="ghost">
          Delegate
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delegate this sign-off</DialogTitle>
          <DialogDescription>
            The delegate decides as themselves; you are both notified and the delegation is
            recorded.
          </DialogDescription>
        </DialogHeader>
        <PersonPicker
          aria-label="Delegate to"
          people={choices}
          value={toUserId}
          onChange={setToUserId}
          blankLabel="— Choose a person —"
        />
        {error && <p className="text-destructive text-sm">{error}</p>}
        <DialogFooter>
          <Button
            disabled={!toUserId || pending}
            onClick={() => {
              setError(null);
              start(async () => {
                const res = await delegateApproval({ instanceId, toUserId });
                if (!res.ok) setError(res.error);
                else {
                  setOpen(false);
                  toast.success(`Delegated to ${nameOf(choices, toUserId)}`, {
                    description: "You are both notified.",
                  });
                  router.refresh();
                }
              });
            }}
          >
            {pending ? "Delegating…" : "Delegate"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
