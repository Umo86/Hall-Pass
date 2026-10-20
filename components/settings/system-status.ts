/**
 * Plain-language status lines for Settings → System. Pure — unit tested in
 * tests/unit/settings-sections.test.ts.
 */

export type StatusTone = "ok" | "warn" | "error";
export type StatusLine = { tone: StatusTone; title: string; detail: string };

export function storageStatus(p: {
  backend: "s3" | "blob" | "local" | string;
  /** Live bucket check, when a bucket is configured. */
  check: { ok: boolean } | null;
  /** Running on hosting where the server's own disk is wiped on deploy. */
  hosted: boolean;
}): StatusLine {
  switch (p.backend) {
    case "s3":
      return p.check && !p.check.ok
        ? {
            tone: "error",
            title: "File storage isn't working",
            detail:
              "New uploads will fail until the storage settings are fixed. Ask your developer to look at the technical details below.",
          }
        : {
            tone: "ok",
            title: "Files are stored safely",
            detail: "Artwork, photos, documents and exports are kept in your file storage bucket.",
          };
    case "blob":
      return {
        tone: "ok",
        title: "Files are stored safely",
        detail: "Artwork, photos, documents and exports are kept in Vercel Blob.",
      };
    default:
      return p.hosted
        ? {
            tone: "error",
            title: "Uploaded files will be lost",
            detail:
              "Files are being saved to temporary disk and will be lost on the next deploy. Ask your developer to connect file storage.",
          }
        : {
            tone: "warn",
            title: "Files are saved on this computer",
            detail: "Fine for trying things out. Connect file storage before you use it for real.",
          };
  }
}

export function emailStatus(configured: boolean): StatusLine {
  return configured
    ? {
        tone: "ok",
        title: "Email is working",
        detail:
          "Notifications are emailed as well as shown in the bell, and invitations arrive by email.",
      }
    : {
        tone: "warn",
        title: "Email is off",
        detail:
          "Notifications only appear in the bell, and inviting someone gives you a link to send them yourself. Ask your developer to switch email on.",
      };
}
