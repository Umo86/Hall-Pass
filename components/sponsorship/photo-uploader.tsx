"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Camera, Gift } from "lucide-react";
import { Button } from "@/components/ui/button";
import { removeItemPhoto, uploadItemPhoto } from "@/app/actions/sponsorship";

/** The item's product photo, with add / replace / remove for editors. */
export function PhotoUploader({
  itemId,
  photoUrl,
  alt,
  canEdit,
}: {
  itemId: string;
  photoUrl: string | null;
  alt: string;
  canEdit: boolean;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  return (
    <div className="space-y-2">
      <div className="bg-muted flex aspect-[4/3] w-full items-center justify-center overflow-hidden rounded-md border">
        {photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={photoUrl} alt={alt} className="size-full object-cover" />
        ) : (
          <span className="text-muted-foreground flex flex-col items-center gap-1 text-xs">
            <Gift className="size-8 opacity-40" aria-hidden />
            No photo yet
          </span>
        )}
      </div>
      {canEdit && (
        <div className="flex flex-wrap items-center gap-2">
          <input
            ref={input}
            type="file"
            accept="image/*"
            className="sr-only"
            aria-label="Item photo"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              const fd = new FormData();
              fd.set("itemId", itemId);
              fd.set("file", file);
              setError(null);
              start(async () => {
                const res = await uploadItemPhoto(fd);
                if (!res.ok) setError(res.error);
                if (input.current) input.current.value = "";
                router.refresh();
              });
            }}
          />
          <Button
            type="button"
            size="sm"
            variant="outline"
            disabled={pending}
            onClick={() => input.current?.click()}
          >
            <Camera className="size-4" /> {photoUrl ? "Replace photo" : "Add photo"}
          </Button>
          {photoUrl && (
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={pending}
              onClick={() =>
                start(async () => {
                  const res = await removeItemPhoto({ itemId });
                  if (!res.ok) setError(res.error);
                  router.refresh();
                })
              }
            >
              Remove
            </Button>
          )}
          {pending && <span className="text-muted-foreground text-xs">Saving…</span>}
        </div>
      )}
      {error && <p className="text-destructive text-xs">{error}</p>}
    </div>
  );
}
