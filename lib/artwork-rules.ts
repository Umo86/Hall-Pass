/** Artwork upload rules shared by the direct and the browser → Blob paths. */

export const ARTWORK_TYPES = [
  "application/pdf",
  "application/postscript",
  "application/illustrator",
  "image/svg+xml",
  "image/png",
  "image/jpeg",
  "image/tiff",
  "application/zip",
];

export const ARTWORK_TYPE_MESSAGE = "Unsupported file type — use PDF, AI, EPS, SVG, PNG, JPG, TIFF or ZIP";

/** Illustrator and EPS files often arrive with no (or a generic) type. */
export function artworkTypeAllowed(mimeType: string | null | undefined, fileName: string): boolean {
  if (/\.(ai|eps)$/i.test(fileName)) return true;
  return !mimeType || ARTWORK_TYPES.includes(mimeType);
}

const INSTALLED = ["installed", "snagged", "closed"];

/** Why new artwork can't be added at this status, or null when it can. */
export function artworkBlockedReason(status: string): string | null {
  return INSTALLED.includes(status)
    ? "This item is installed — an admin or ops user must reopen it before new artwork"
    : null;
}
