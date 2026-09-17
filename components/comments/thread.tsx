"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { formatDateTime } from "@/lib/format";
import { addComment } from "@/app/actions/comments";

export type CommentRow = {
  id: string;
  body: string;
  isInternal: boolean;
  authorName: string;
  createdAt: string;
};

export function CommentThread({
  entityType,
  entityId,
  comments,
  canWriteInternal,
  canWriteExternal,
  isStaff,
}: {
  entityType: "signage_item" | "stand_submission";
  entityId: string;
  comments: CommentRow[];
  canWriteInternal: boolean;
  canWriteExternal: boolean;
  isStaff: boolean;
}) {
  const [body, setBody] = useState("");
  const [internal, setInternal] = useState(isStaff);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <div className="max-w-3xl space-y-4">
      {comments.length === 0 ? (
        <p className="text-muted-foreground text-sm">No comments yet.</p>
      ) : (
        <ol className="space-y-3">
          {comments.map((c) => (
            <li key={c.id} className="rounded-lg border p-3">
              <p className="text-muted-foreground text-xs">
                <span className="text-foreground font-medium">{c.authorName}</span> ·{" "}
                {formatDateTime(c.createdAt)} ·{" "}
                {c.isInternal ? (
                  <span className="text-amber-700 dark:text-amber-400">Internal</span>
                ) : (
                  <span>Visible to external parties</span>
                )}
              </p>
              <p className="mt-1 text-sm whitespace-pre-wrap">{c.body}</p>
            </li>
          ))}
        </ol>
      )}

      {(canWriteInternal || canWriteExternal) && (
        <form
          className="space-y-2"
          onSubmit={(e) => {
            e.preventDefault();
            setError(null);
            start(async () => {
              const res = await addComment({
                entityType,
                entityId,
                body,
                isInternal: canWriteInternal ? internal : false,
              });
              if (!res.ok) setError(res.error);
              else {
                setBody("");
                router.refresh();
              }
            });
          }}
        >
          <Textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="Write a comment… (@ mentions arrive with the notification centre)"
            required
          />
          <div className="flex items-center gap-3">
            {canWriteInternal && canWriteExternal && (
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  className="size-4"
                  checked={internal}
                  onChange={(e) => setInternal(e.target.checked)}
                />
                Internal (hidden from external parties)
              </label>
            )}
            <Button type="submit" size="sm" disabled={pending || !body.trim()}>
              Comment
            </Button>
            {error && <span className="text-destructive text-sm">{error}</span>}
          </div>
        </form>
      )}
    </div>
  );
}
