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
} from "@/components/ui/dialog";
import { submitStandSubmission } from "@/app/actions/stands";

export function SubmitStandButton({
  submissionId,
  isResubmit,
}: {
  submissionId: string;
  isResubmit: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <>
      <Button onClick={() => setOpen(true)}>
        {isResubmit ? "Resubmit design" : "Submit design for approval"}
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{isResubmit ? "Resubmit your design?" : "Submit your design?"}</DialogTitle>
            <DialogDescription>
              {isResubmit
                ? "Resubmitting increases the submission version and restarts the review from the step that requested changes. Earlier approvals stand."
                : "Submitting starts the approval review. Every required document must be uploaded and the maximum height set."}
            </DialogDescription>
          </DialogHeader>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={pending}
              onClick={() => {
                setError(null);
                start(async () => {
                  const res = await submitStandSubmission({ submissionId });
                  if (!res.ok) setError(res.error);
                  else {
                    setOpen(false);
                    router.refresh();
                  }
                });
              }}
            >
              {isResubmit ? "Resubmit" : "Submit"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
