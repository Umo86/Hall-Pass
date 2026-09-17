"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
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
import { SelectNative } from "@/components/ui/select-native";
import { delegateApproval } from "@/app/actions/approvals";

export function DelegateButton({
  instanceId,
  users,
}: {
  instanceId: string;
  users: { id: string; name: string }[];
}) {
  const [open, setOpen] = useState(false);
  const [toUserId, setToUserId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="ghost">
          Delegate
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delegate this step</DialogTitle>
          <DialogDescription>
            The delegate decides as themselves; you are both notified and the delegation is
            recorded.
          </DialogDescription>
        </DialogHeader>
        <SelectNative value={toUserId} onChange={(e) => setToUserId(e.target.value)}>
          <option value="">— Choose a person —</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name}
            </option>
          ))}
        </SelectNative>
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
                  router.refresh();
                }
              });
            }}
          >
            Delegate
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
