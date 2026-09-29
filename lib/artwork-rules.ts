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

const DESIGN_APPROVED = [
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
  "installed",
  "snagged",
  "closed",
];

export const PANEL_BLOCKED_MESSAGE =
  "The stand design must be approved before panel graphics can be added";

/**
 * Why new artwork can't be added, or null when it can. A stand panel also
 * waits for its stand's design to be approved (pass the stand's status).
 */
export function artworkBlockedReason(
  status: string,
  panel?: { parentStatus: string | null } | null,
): string | null {
  if (INSTALLED.includes(status)) {
    return "This item is installed — an admin or ops user must reopen it before new artwork";
  }
  if (panel && !(panel.parentStatus && DESIGN_APPROVED.includes(panel.parentStatus))) {
    return PANEL_BLOCKED_MESSAGE;
  }
  return null;
}
