import "server-only";

/**
 * The platform's own public address, used for links in emails, QR codes,
 * certificates and the iCal feed. NEXT_PUBLIC_APP_URL wins when set;
 * otherwise Vercel's own domain variables configure it automatically, so a
 * renamed project (e.g. hall-pass-alpha) keeps working without env edits.
 */
export function appUrl(): string {
  const explicit = process.env.NEXT_PUBLIC_APP_URL;
  if (explicit) return explicit.replace(/\/$/, "");
  const vercel =
    process.env.VERCEL_PROJECT_PRODUCTION_URL ??
    process.env.VERCEL_BRANCH_URL ??
    process.env.VERCEL_URL;
  if (vercel) return `https://${vercel.replace(/\/$/, "")}`;
  return "";
}
