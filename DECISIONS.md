# Decisions

A one-line log of choices made where the build brief is silent, with the reason. Newest first.

| Date       | Decision                                                       | Reason                                                                                                                                                                                                                                           |
| ---------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-09-17 | Development sign-in (`DEV_AUTH=1`) assumes seeded users by cookie | Lets the platform be demonstrated with only a database; hard-disabled the moment Supabase Auth is configured. |
| 2026-09-17 | Storage falls back to the local filesystem when Supabase is unconfigured | Keeps uploads working in development/demo; production uses Supabase Storage private buckets with signed URLs. Vercel's filesystem is ephemeral, so demo uploads there do not persist across deploys. |
| 2026-09-17 | Seeded artwork/documents are metadata-only (`seed/` paths, no real files) | Real files need object storage; hashes and versions still exercise the whole approval flow. |
| 2026-09-17 | Default-workflow confirmation names drive item status (Sent to print → in_production, etc.) | Simplest testable mapping; custom workflows that rename confirmations record decisions without moving item status. |
| 2026-09-17 | `locked_version_id` stored as text | It holds either an artwork version uuid or a stand submission version number. |
| 2026-09-17 | Excel import commits only when every row validates; the error list is the preview | One transaction, no partial imports; matches "commit in one transaction" with a simpler flow than a separate preview step. |
| 2026-09-17 | Grants are claimed by invited email on first Supabase sign-in | Avoids fragile uid pre-linking; the invite link flow still validates the hashed token. |
| 2026-09-17 | TanStack Table pinned to v8 | v9 shipped mid-build with a breaking typed API. |
| 2026-09-17 | Deferred from v1 (flagged, not silent): inline grid editing, saved views, floorplan and calendar views, artwork previews/compare/annotations, onsite mobile section and PWA, QR camera scanning, change-request UI, venue pack / contractor schedule / sponsor / cost / performance exports, iCal feed, workflow builder UI, email template editing, GDPR self-service | Section 14.10: scope not reduced silently — each is listed in PLAN.md as remaining work with the engine-level support already in place. |
| 2026-09-17 | App shell (tasks 0.1–0.4, 0.17-lite) pushed straight to `main` | The owner asked for a first Vercel deployment; production tracks `main` and the repository is not yet connected to Vercel, so a pull request had nothing to preview against. Later phase work goes through branches and pull requests.           |
| 2026-09-17 | shadcn/ui components vendored by hand (registry blocked)       | The build environment's egress proxy denies ui.shadcn.com, so `components.json`, the theme tokens and the base components were written manually from the standard shadcn sources; behaviourally identical, future components added the same way. |
| 2026-09-17 | Cron endpoint accepts GET and POST                             | Vercel Cron invokes with GET while the brief specifies POST; both are served by the same handler behind the same `CRON_SECRET` bearer check.                                                                                                     |
| 2026-09-17 | Initial planning docs pushed straight to `main`                | The repository was empty with no default branch yet.                                                                                                                                                                                             |

## Vercel-first infrastructure (2026-09-22)
The platform now targets Vercel end to end at the owner's request: Vercel
Postgres (Neon) for the database and Vercel Blob for files. The db client
accepts the integration's injected variables (POSTGRES_URL etc.) and probes
candidates in order, so attaching the store needs no manual env work.
Large artwork uploads go browser → Blob directly (2 GB cap, streaming
SHA-256 in the browser, token route scoped to the item's folder) because
serverless request bodies cap at ~4.5 MB. Blob URLs are public-but-
unguessable (uuid path segments, no store listing); the app never renders
them outside authenticated pages — accepted for an internal tool, revisit
if artwork becomes sensitive. Supabase remains a supported alternative;
supabase-setup.sql was renamed database-setup.sql and runs on any Postgres.
