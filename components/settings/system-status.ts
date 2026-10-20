/**
 * Plain-language status lines for Settings → System. Pure — unit tested in
 * tests/unit/settings-sections.test.ts.
 */
import { providerName, regionCity } from "@/lib/db/urls";

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

/** Where the data is, and whether the database works, in plain words. */
export function databaseStatus(p: {
  /** lib/db/urls.ts provider of the connection in use ("neon", "supabase", "local", …); null when none. */
  provider: string | null;
  /** Cloud region, e.g. "aws-eu-west-2". */
  region: string | null;
  schema: "current" | "behind" | "unknown";
  reachable: boolean;
}): StatusLine {
  if (!p.provider || !p.reachable) {
    return {
      tone: "error",
      title: "The database isn't connected",
      detail:
        "Nothing can be saved or shown until it is. Ask your developer to look at the technical details below.",
    };
  }
  if (p.schema === "behind") {
    return {
      tone: "warn",
      title: "The database needs updating",
      detail:
        "This release expects changes to the database that haven't been made yet, so some pages may fail. Ask your developer to run the database migration.",
    };
  }
  const city = regionCity(p.region);
  const where =
    p.provider === "neon" || p.provider === "supabase"
      ? city
        ? `In ${providerName(p.provider)}'s ${city} data centre.`
        : `With ${providerName(p.provider)}.`
      : p.provider === "local"
        ? "In a database on this computer."
        : "In your Postgres database.";
  return { tone: "ok", title: "Your data is stored safely", detail: where };
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

/** Sign-in in plain words: real sign-in (Better Auth), demo sign-in, and links without email. */
export function signInStatus(p: {
  /** Real sign-in is set up (a secret is available). */
  configured: boolean;
  /** Demo sign-in (one click as a seeded account) is on. */
  demo: boolean;
  emailOn: boolean;
}): StatusLine {
  if (p.configured && p.demo) {
    return {
      tone: "warn",
      title: "Demo sign-in is on",
      detail:
        "People sign in with their email and password, and the demo accounts can be used with one click too. Ask your developer to switch demo sign-in off before real use.",
    };
  }
  if (p.configured) {
    return {
      tone: "ok",
      title: "Sign-in is working",
      detail: p.emailOn
        ? "People sign in with their email and password. Sign-in links and password resets are emailed."
        : "People sign in with their email and password. Email is off, so a super admin gives out sign-in and password reset links from the person's page in Users.",
    };
  }
  if (p.demo) {
    return {
      tone: "warn",
      title: "Only demo sign-in is on",
      detail:
        "Only the demo accounts can sign in. Ask your developer to set up real sign-in before anyone uses this for real.",
    };
  }
  return {
    tone: "error",
    title: "Nobody can sign in",
    detail: "Sign-in isn't set up on this site. Ask your developer to set it up.",
  };
}
