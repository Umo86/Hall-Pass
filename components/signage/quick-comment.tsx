"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { addComment } from "@/app/actions/comments";

/**
 * A comment box right under the sign-off chain, so approvers can leave a
 * note without deciding. Posts to the item's comment thread.
 */
export function QuickComment({ itemId, count }: { itemId: string; count: number }) {
  const [body, setBody] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <form
      className="space-y-2"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setMessage(null);
        start(async () => {
          const res = await addComment({
            entityType: "signage_item",
            entityId: itemId,
            body,
            isInternal: true,
          });
          if (!res.ok) setError(res.error);
          else {
            setBody("");
            setMessage("Comment added");
            router.refresh();
          }
        });
      }}
    >
      <label htmlFor="quick-comment" className="text-sm font-semibold">
        Leave a comment
      </label>
      <Textarea
        id="quick-comment"
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder="A question or note about this artwork — the owner and earlier commenters are told"
        className="min-h-16"
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" size="sm" disabled={pending || !body.trim()}>
          Post comment
        </Button>
        <Link href="?tab=comments" className="text-muted-foreground text-xs hover:underline">
          {count > 0 ? `See all ${count} comment${count === 1 ? "" : "s"}` : "Comments tab"}
        </Link>
        {message && <span className="text-xs text-green-700 dark:text-green-400">{message}</span>}
        {error && <span className="text-destructive text-xs">{error}</span>}
      </div>
    </form>
  );
}
