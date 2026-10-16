import { cn } from "@/lib/utils";
import type { ReviewVersion } from "@/lib/queries/artwork-approvals";

type Version = Pick<
  ReviewVersion,
  "versionNumber" | "fileName" | "previewUrl" | "previewKind" | "downloadUrl" | "sample"
>;

/**
 * A large preview of one artwork version: an image (or its generated
 * preview), a PDF in a frame, or a video. Used by the review sheet; the same
 * rules as the item's Artwork tab.
 */
export function ArtworkPreview({
  version,
  className,
  frameClassName = "max-h-[60vh] min-h-48",
}: {
  version: Version;
  className?: string;
  /** Size of the picture, PDF frame or video. */
  frameClassName?: string;
}) {
  const label = `Artwork v${version.versionNumber} — ${version.fileName}`;
  if (!version.previewUrl || !version.previewKind) {
    return (
      <div
        className={cn(
          "text-muted-foreground bg-muted/30 flex min-h-48 flex-col items-center justify-center gap-2 rounded-lg border border-dashed p-6 text-center text-sm",
          className,
        )}
      >
        <span>
          {version.sample
            ? "Sample record — no file attached."
            : "No preview for this type of file."}
        </span>
        {version.downloadUrl && (
          <a href={version.downloadUrl} className="link" target="_blank" rel="noopener noreferrer">
            Download {version.fileName}
          </a>
        )}
      </div>
    );
  }
  return (
    <div className={cn("space-y-1", className)}>
      {version.previewKind === "pdf" ? (
        <iframe
          src={version.previewUrl}
          title={label}
          className={cn("h-[60vh] w-full rounded-lg border", frameClassName)}
        />
      ) : version.previewKind === "video" ? (
        <video
          src={version.previewUrl}
          controls
          preload="metadata"
          playsInline
          aria-label={label}
          className={cn("bg-muted/30 w-full rounded-lg border", frameClassName)}
        />
      ) : (
        // eslint-disable-next-line @next/next/no-img-element -- artwork has unknown dimensions
        <img
          src={version.previewUrl}
          alt={label}
          className={cn("bg-muted/30 w-full rounded-lg border object-contain", frameClassName)}
        />
      )}
      {/* Phone browsers often won't show a PDF inside a frame. */}
      <a
        href={version.previewUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="text-muted-foreground text-xs underline"
      >
        Open full size
      </a>
    </div>
  );
}
