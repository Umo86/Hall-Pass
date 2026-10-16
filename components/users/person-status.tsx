import { ShieldCheck } from "lucide-react";
import { PERSON_STATUS_CLASSES, type PersonStatus } from "@/lib/users/list";
import { cn } from "@/lib/utils";

/** A person's status: one colour each, always with its words ("Suspended 3 Oct"). */
export function PersonStatusChip({
  status,
  text,
  className,
}: {
  status: PersonStatus;
  text: string;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        PERSON_STATUS_CLASSES[status],
        className,
      )}
      data-status={status}
    >
      {text}
    </span>
  );
}

/** "Manager · Marketing" next to someone's role. */
export function ManagerBadge({ text, className }: { text: string; className?: string }) {
  return (
    <span
      className={cn(
        "bg-primary/10 text-primary inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-xs font-medium whitespace-nowrap",
        className,
      )}
    >
      <ShieldCheck className="size-3" aria-hidden />
      {text}
    </span>
  );
}
