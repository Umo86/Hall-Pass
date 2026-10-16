"use client";

import { useState } from "react";
import Link from "next/link";
import { ListPlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { TaskForm, type Assignee } from "./task-form";

/**
 * "Add task" for an item's page: a task about this item (and its event),
 * for you or someone on the team. It shows on My Work with a link back here.
 *
 *   <AddTaskDialog currentUserId={…} assignees={…} canAssign={…}
 *     entity={{ type: "signage_item", id: item.id, editionId: edition.id, label: item.ref }} />
 */
export function AddTaskDialog({
  currentUserId,
  assignees,
  canAssign,
  entity,
  triggerLabel = "Add task",
}: {
  currentUserId: string;
  assignees: Assignee[];
  canAssign: boolean;
  entity: {
    type: "signage_item" | "stand_submission";
    id: string;
    editionId: string;
    /** The item's ref, e.g. "SIG-BIRM27-001". */
    label: string;
  };
  triggerLabel?: string;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <ListPlus aria-hidden /> {triggerLabel}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add a task about {entity.label}</DialogTitle>
          <DialogDescription>
            It goes on{" "}
            <Link href="/my-work" className="link">
              My Work
            </Link>{" "}
            with a link back to this item.
          </DialogDescription>
        </DialogHeader>
        <TaskForm
          currentUserId={currentUserId}
          assignees={assignees}
          canAssign={canAssign}
          entity={entity}
          placeholder="e.g. Check the proof with the sponsor"
          onAdded={() => setOpen(false)}
        />
      </DialogContent>
    </Dialog>
  );
}
