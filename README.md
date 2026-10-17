# Hall Pass

Internal signage schedule and design sign-off platform for exhibitions. One register for every piece of organiser signage and every exhibitor stand design, with configurable approval chains, automatic deadline chasing and an immutable audit trail.

See `PLAN.md` for the build plan and current status, `CLAUDE.md` for conventions and the non-negotiables, and `DECISIONS.md` for choices made where the brief was silent.

## What the platform includes

- **Signage schedule** — every item for an event in one list: organiser or sponsor signage (with the sponsor's name), print or digital, the supplier, and everything from the Sponsorship section. Full lifecycle (draft → sign-off → production → delivery → install → close, plus hold/reject/reopen), artwork versions with never-silent invalidation, table/Kanban/phone views, Excel import/export, spec labels and approval certificates.
- **Approvals** — one place for artwork sign-off. _Waiting on me_ lists what each person needs to decide (with a review sheet that moves on to the next one); _All artwork_ shows every item with a graphic, filterable by event and sign-off state, with who approved, rejected or asked for changes and their comments; _Who signs off_ shows, read-only, which departments sign off what (they are set up in Users → Departments). On each item, whoever adds it can untick a department or pick a different person; the assignee is emailed. Every decision and comment is logged in History.
- **Invite-only sign-in (Supabase)** — there is no sign-up. Admins invite people (team, approvers, partners); Supabase emails them a link that only works from their inbox, where they set their name and password. Sign-in is by email and password (or an emailed link); "Forgot password" and sign-in links only go to invited people, and the reply never reveals who has an account. Demo sign-in is always off on a Vercel deployment with Supabase configured.
- **Events and the guided start** — with no events yet, admins and Operations land on **Create your event** (`/start`): name, open dates and venue (build-up and breakdown are assumed and shown), or copy a previous event and choose what comes across. The event's **setup checklist** (`/CODE/setup`) then works from real data: dates, venue and budget; halls and locations; deadlines; who signs off; people; sign types; suppliers; first signs (add or import); sponsorship. Progress shows as "Setup 3/6" in the side menu until it is done. All events are under General → Events.
- **Suppliers** — a directory of companies with what each does (signage print, screens, staffing…), filterable by "What they do"; new entries can be typed straight into the supplier popup, and the list itself is managed from the Suppliers page. Install contractors have their own tab. The supplier column in the schedule shows who's making what.
- **Settings** (admins and Operations; System is admins only) — **Organisation** (name, currency, chasing overdue sign-offs, install photo), **Item types** (signage and sponsorship types people pick from), **Venues**, **Recycle bin** (put deleted items back) and **System** (file storage, email and calendar feeds, in plain words — this is where Storage now lives).
- **Sponsorship** — what's for sale to sponsors as cards: product photo, cost price, supplier, sale price and profit once sold, and a countdown to the order-by date (months and days) with a "Less than 1 month to sell" warning on unsold items. "Mark as sold" records the sponsor (or adds a new one) and the sale price; a Sponsors tab lists each sponsor with what they've bought and spent. Same sign-off and artwork versioning as signage.
- **Fewer, clearer fields** — each form shows only what that kind of item needs (sponsorship: item, buying, sale; signage: what and where, size and fixing, supplier, cost and install); everything else sits in a closed "More details" section. Item pages open with an at-a-glance summary. Cost and sale prices are visible to the whole team.
- **My Work board** — To do (red), In progress (orange) and Complete (green). Drag cards between columns or use each card's menu; assign jobs to each other; each task has a deadline, subtasks with their own deadlines, and attachments on the task and each subtask. Anything past its deadline is highlighted in red on the card and counted at the top.
- **Calendar** — every deadline in red (event deadlines, print deadlines, artwork due, sponsorship order-by dates, sign-offs due, your task deadlines), solid dark red once passed; event dates, deliveries and installs colour-coded, with a key.
- **Users** (General → Users) — **Team**: add people with their name, email, job title, department, role, the sections they can use and which department's artwork they sign off; invited people show with Resend or Copy link; each person's page changes all of it in one save, and "Remove from team" hands their waiting sign-offs to someone else. **Departments**: which ones sign off artwork, their rules and order, and the approvers. **External**: portal access for partners (venue, suppliers, sponsors), per event. Super admins and managers change people, Departments needs “Manage departments and who signs off” and External needs “Invite partners” (see [Users and managers](#users-and-managers)); everyone else sees a read-only directory.
- **My account** (from the account menu) — your name, your personal calendar feed and which notifications you get.
- **Stand design approvals** — structure questionnaire with automatic complex-structure classification, required documents with expiry flags, venue-rules checklist, engineer/H&S/venue review chain, exhibitor portal with submit/resubmit.
- **Shared engine** — configurable workflows with conditions, parallel groups, SLAs, delegation and optimistic locking; creation and assignment notifications with a self-updating bell; internal/external comments; transactional email; daily cron (reminders, escalation, chasers, expiry, digest) with idempotency; append-only audit trail enforced by the database; deny-by-default RLS; every record checked against the caller's organisation (no cross-tenant access, admins included); parameterised queries only; external portals scoped per grant; mobile navigation throughout.
- **Tests** — 1,570 unit tests (authz with the abilities registry and the frozen v1 snapshot, managers and access state, status machines, workflow engine, department routing and re-routing, deadlines, exports and labels, DB-backed ref concurrency/RLS/audit-trigger/cron idempotency/staff and partner invitations/departments/suspension and end dates/hand-over/owners) and 122 Playwright end-to-end tests (Users v2: managers, suspension, end dates, templates, add several and partner access; every page for every role, hostile input, signed-out access, the task board with subtasks and files, full signage lifecycle to installed with a photo, three-department sign-off with a named approver, adding a department and approver who sets up an account and signs off, sponsor signage, selling a sponsorship item with a photo, suppliers and services, new event with logo, exports, partner item page, team, phone layouts).

## Users and managers

Everything is under General → Users, and every change shows in the person's access history.

- **Super admin** — everything, including people, managers and system settings. Only a super admin makes someone a super admin or a manager, removes people, archives events or changes System (storage, email, calendar feeds). There is always at least one super admin whose access doesn't end (not suspended, no end date), so a super admin can only be suspended, removed, demoted or given an end date while another one has lasting access.
- **Managers** — someone can manage their own department or everyone. A manager adds and changes people in that scope (never themselves, super admins or other managers) and can only give what they have themselves: roles, sections, abilities and sign-off for the departments they sign off for.
- **Abilities** — on top of the role, each person's page lists what they can be given or refused, one list for the whole app (`ABILITIES` in `lib/authz.ts`: Add signage, Edit costs and PO numbers, Confirm print, delivery and install, Invite partners…). Invite partners, Manage departments and who signs off, and Organisation settings can only be given by a super admin.
- **Suspend and end dates** — Suspend pauses access at once: sign-offs waiting on them by name are handed to whoever you pick (each department's main approver by default); their tasks and items stay, and Reactivate puts everything back. An access end date (a London date) stops access at the end of that day; super admins and their managers are warned a week before, and the daily job hands their named sign-offs back to the department. Anyone turned away at sign-in is told who to ask, with a link to email them.
- **Templates** — Add person starts from a template (Marketing executive, Freelance installer, Sales manager, Operations coordinator, or Blank) that fills in the role, sections, abilities and job title, and suggests an end date for freelancers.
- **Add several** — paste names and emails (from a spreadsheet or an email), see what will happen to each line (ready, already on the team, already invited, a portal account…), then invite them all with the same settings.

## Local development

Requires Node 22+, pnpm and Postgres 16.

```bash
pnpm install
createdb hallpass && createdb hallpass_test
cp .env.example .env          # or use the defaults below
pnpm db:migrate               # apply migrations
pnpm db:seed                  # idempotent — safe to run twice
pnpm dev                      # http://localhost:3000
```

Minimal local `.env`:

```
DATABASE_URL=postgres://postgres:postgres@localhost:5432/hallpass
DIRECT_DATABASE_URL=postgres://postgres:postgres@localhost:5432/hallpass
TEST_DATABASE_URL=postgres://postgres:postgres@localhost:5432/hallpass_test
CRON_SECRET=dev-cron-secret
```

Without Supabase configured, the login page offers **development sign-in** as any seeded user (admin/ops/marketing/sales/director/viewer @media10.test, plus the external venue/engineer/H&S/supplier/exhibitor/sponsor users). `DEV_AUTH=1` keeps it on even with Supabase configured — then it only accepts the seeded `…@….test` accounts, and every page shows a red "Demo sign-in is on" bar.

**Going live:** invite yourself as admin (Users), sign in with the emailed link, then remove `DEV_AUTH` and redeploy.

**Start a real organisation** (no demo data): on an empty, migrated database run

```bash
SEED_MODE=starter FIRST_ADMIN_EMAIL=you@company.com ORG_NAME="Your company" pnpm db:seed
```

It creates only the organisation, the first admin (an invitation they accept by signing in
with that email; a `…@….test` address gets a demo sign-in account instead), the departments
Operations, Marketing, Sales and Senior management (signs last), the signage sign-off
workflow, the standard sign types and supplier services. No series, venues, events or signs:
the admin signs in, is taken to **Create your event**, and the event's setup checklist walks
through dates, halls, deadlines, who signs off, people and the first signs. Optional:
`BRAND_NAME`, `ORG_SLUG`, `FIRST_ADMIN_NAME`. Safe to run twice.

Stand approvals are built but hidden; set `STANDS_ENABLED=1` to show them.

Checks:

```bash
pnpm typecheck && pnpm lint && pnpm test   # unit suite (DB tests need TEST_DATABASE_URL)
pnpm test:e2e                              # Playwright (needs the seeded DB; DEV_AUTH=1)
pnpm build
```

## Deploying to Vercel (all-Vercel setup)

1. Import `Umo86/Hall-Pass` at [vercel.com/new](https://vercel.com/new).
2. **Database** — in the project's **Storage** tab, create/connect a **Postgres (Neon)**
   database. The integration injects `DATABASE_URL` and friends automatically; the app
   accepts any of `DATABASE_URL`, `DIRECT_DATABASE_URL`, `POSTGRES_URL`,
   `DATABASE_URL_UNPOOLED`, `POSTGRES_URL_NON_POOLING` and uses the first reachable one.
3. **Schema + demo data** — open the database's SQL editor (Storage tab → Open in Neon →
   SQL Editor), paste the whole of `database-setup.sql` (repo root; re-runnable) and run it.
4. **Files** — an S3-compatible bucket (Cloudflare R2 recommended, see
   [Running on free plans](#running-on-free-plans-supabase-free--cloudflare-r2)) via
   `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`. Large artwork goes
   browser → bucket directly through a presigned upload (up to 2 GB per file). Vercel Blob
   (`BLOB_READ_WRITE_TOKEN`, from the Storage tab) still works as an alternative; without
   either, uploads fall back to the serverless filesystem, which does not persist.
5. Remaining env vars (Settings → Environment Variables):
   - `DEV_AUTH=1` — demo sign-in (one-click seeded users; remove before real use)
   - `STANDS_ENABLED=1` — optional; shows stand approvals (hidden by default)
   - `CRON_SECRET` — any long random string (Vercel Cron sends it automatically)
   - `RESEND_API_KEY` + `EMAIL_FROM` — transactional email (optional; sends are logged until set)
   - `NEXT_PUBLIC_APP_URL` — optional; auto-detected from the Vercel domain when unset
6. Redeploy. `vercel.json` schedules the daily cron at 06:00 UTC (07:00 BST); the handler
   computes "today" in Europe/London so clock changes don't break it. Verify at
   `/api/health` — it should return `"ok":true` and states which database variable and
   storage backend are active.

## Releasing a new version (upgrading the live database)

Every staff and partner page load reads the signed-in person's membership, which selects
every column the code knows about. If the code is deployed before its migrations have run,
every signed-in page fails with `column … does not exist` until they do. The build doesn't
migrate (`next build` only; `vercel.json` has no migration step), so, in this order:

1. **Migrate first.** From a checkout of the release, with the live database's _unpooled_
   URL (Neon: `DATABASE_URL_UNPOOLED` / `POSTGRES_URL_NON_POOLING`; Supabase: the direct or
   session-pooler URL) as `DIRECT_DATABASE_URL`:

   ```bash
   DIRECT_DATABASE_URL='postgres://…' pnpm db:migrate
   ```

   These migrations add and backfill (tables, columns with defaults, indexes) and drop or
   rename nothing, so the code that is live now keeps working on the migrated schema, with
   the one exception below.

2. **Then deploy**: push to `main` (or promote the preview deployment) straight after.
   Keep the gap between the two steps short.
3. **Check** `/api/health`: `"schema": "current"` and `"ok": true`. `"schema": "behind"`
   (status 503, with a `schemaNote`) means step 1 hasn't run against this database.

**Between migrating and deploying** (the release with migration 0012): the old code can't
make someone main approver of a department that already has one. 0012 adds a unique index
(one main approver per department) and the old code sets the new main before clearing the
old one, so it fails, saying "That email is already an approver in this department". Don't
change main approvers until the new deployment is live.

**Rolling back.** A Vercel rollback to a deployment from before 0012 is unsafe once anyone
has been suspended or given an access end date: that code ignores `suspended_at` and
`access_ends_at`, so suspended people and people whose access has ended could sign in
again, and the main-approver problem above comes back. Roll forward with a fix instead. If
a rollback can't be avoided, first remove from the team anyone suspended or past their end
date who must stay out (removal works the same in every version).

Supabase remains supported as an alternative (its pooler URIs in `DATABASE_URL`/
`DIRECT_DATABASE_URL`, Storage private buckets named `artwork`, `documents`, `photos`,
`floorplans`, `exports`, and `NEXT_PUBLIC_SUPABASE_URL` + publishable key for real email
sign-in). `database-setup.sql` runs unchanged in its SQL editor.

## Running on free plans (Supabase Free + Cloudflare R2)

The cheapest setup that still copes with large print-ready graphics:

| Part                                        | Service                  | Free allowance                                       | What to know                                                                                                                        |
| ------------------------------------------- | ------------------------ | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Database + sign-in                          | Supabase **Free**        | 500 MB database, 2 projects per organisation         | Pauses after a quiet week; the daily cron's queries keep it awake. No automatic backups — the weekly GitHub Action below takes one. |
| Database, alternative (see 3b)              | Neon **Free** via Vercel | 1 GB, 6-hour restore window                          | Scales to zero and wakes by itself; Supabase then only handles sign-in.                                                             |
| Files (artwork, photos, documents, exports) | Cloudflare **R2**        | 10 GB storage, no egress fees, up to 5 GB per upload | Needs a Cloudflare account; R2 may ask for a payment method on first use but charges nothing inside the allowance.                  |
| App                                         | Vercel **Hobby**         | Cron once a day, 1 GB Blob                           | Hobby is for non-commercial use; move to Pro when the tool runs a real show for a business.                                         |

Supabase Storage on the Free plan caps every file at 50 MB. Vercel Blob is the simplest
store (1a); R2 (1b) gives ten times the free space and no transfer fees.

Accepted artwork: PDF, AI, EPS, SVG, PNG, JPG, TIFF, WebP, ZIP, and MP4, MOV or WebM video
for screens and digital signage; videos play inline on the item page and in the partner
portal.

### 1a. Vercel Blob store (simplest: lives in the Vercel dashboard)

Artwork, panel graphics, photos, documents, exports and videos for screens all go to the
store; large files upload straight from the browser (up to 2 GB each).

1. Vercel → project → **Storage** → **Create Database** → **Blob** → name it
   (e.g. `hall-pass-files`), region Frankfurt, **Connect** it to the project for
   Production and Preview. Vercel adds `BLOB_READ_WRITE_TOKEN` itself.
2. Leave the `S3_*` variables unset (a bucket takes precedence when both are set).
3. **Redeploy**. `/api/health` shows `"storage":"blob"`. Upload a file on any item's
   Artwork tab to check.

Hobby plan allowance: 1 GB stored and 10 GB transferred a month, as hard caps (uploads
stop until the month rolls over). Pro includes 5 GB and 100 GB, then pay per GB. Video for
screens adds up quickly, so prefer the R2 bucket below past a few hundred megabytes.

### 1b. Or: Cloudflare R2 bucket (10 GB free)

1. Cloudflare dashboard → **R2 Object Storage** → **Create bucket** (name e.g. `hall-pass`,
   location hint Europe). Leave it private.
2. **Manage R2 API Tokens** → **Create API token** → permission _Object Read & Write_,
   scoped to that bucket. Copy the **Access Key ID**, **Secret Access Key** and the
   endpoint `https://<account id>.r2.cloudflarestorage.com`.
3. Bucket → **Settings** → **CORS policy** — so the browser can upload straight to it:
   ```json
   [
     {
       "AllowedOrigins": ["https://hall-pass-alpha.vercel.app"],
       "AllowedMethods": ["PUT", "GET"],
       "AllowedHeaders": ["content-type"],
       "ExposeHeaders": ["ETag"],
       "MaxAgeSeconds": 3600
     }
   ]
   ```
   Add your own domain to `AllowedOrigins` when you have one.
4. Vercel → project → **Settings → Environment Variables** (Production and Preview):
   `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`. Redeploy.
   `/api/health` now reports `"storage":"s3"`.

### 2. Move the existing files out of Vercel Blob

Keep `BLOB_READ_WRITE_TOKEN` set while copying — files not yet in the bucket are still
read from Blob. Sign in as an admin, open **Settings → System**: it shows whether the
bucket answers with your credentials, a **Test a browser upload** button that proves the
CORS policy lets the app upload directly (the step most often got wrong), and a
**Copy files now** button that copies every file across (safe to run more than once;
files already in the bucket are skipped). When it reports done, delete
`BLOB_READ_WRITE_TOKEN` from Vercel and the Blob store from the Storage tab, and redeploy.

The same copy is available for scripts, with the `CRON_SECRET` from Vercel:

```bash
curl -X POST -H "Authorization: Bearer $CRON_SECRET" \
  "https://hall-pass-alpha.vercel.app/api/admin/storage/migrate?limit=50"
```

Repeat with `&cursor=<nextCursor>` while the reply includes one, until `"done": true`; a
reply with `"incomplete": true` means run the same cursor again.

### 3. Supabase from Pro to Free (same project, same keys)

A project transfer keeps the URL, keys, data and sign-ins, so nothing in Vercel changes:

1. Sign in to the Supabase account that will own it and create an organisation on the
   **Free** plan (Dashboard → New organisation). If that is a different login, invite the
   current account's email into that organisation as a member.
2. From the current account: project → **Settings → General → Transfer project** → choose
   the Free organisation → confirm. Expect 1–2 minutes of downtime. Pre-requisites: no
   GitHub integration or log drains on the project, and the target organisation must have a
   free project slot.
3. **Billing** on the old organisation → downgrade to Free / cancel so the Pro charge stops.
4. Check `/api/health` and sign in once. The daily cron keeps the free project from pausing;
   if it is ever paused, open it in the dashboard and click **Resume**.

### 3b. Or: database on Neon via Vercel, Supabase for sign-in only

Neon's Free plan (1 GB, scales to zero between requests and wakes by itself, 6-hour
restore window) suits a tool that goes quiet between shows, and it lives in the Vercel
dashboard. Sign-in stays on Supabase (its Free plan is fine for that); the daily cron
makes one authenticated call a day so Supabase does not pause the idle project.

1. Vercel → project → **Storage** → **Create Database** → **Neon** (Free), region
   Frankfurt, connect it to the project. Vercel adds `DATABASE_URL`,
   `DATABASE_URL_UNPOOLED` and `POSTGRES_URL`. If it refuses because `DATABASE_URL` already
   exists, delete the old Supabase `DATABASE_URL` and `DIRECT_DATABASE_URL` variables
   (Settings → Environment Variables) and connect again. Keep every `NEXT_PUBLIC_SUPABASE_*`
   and `SUPABASE_*` variable.
2. Load the schema and data into the empty database with the import file generated from
   the live database (`neon-import.sql`, kept out of the repository because it holds real
   data): `psql "<DATABASE_URL_UNPOOLED from Vercel>" -v ON_ERROR_STOP=1 -f neon-import.sql`.
   It refuses to run on a database that already has data. `psql` comes with Postgres
   (macOS: `brew install libpq`). Make the file again if the old database was used after it
   was generated.
3. **Redeploy** so the functions pick up the new variables. `/api/health` should show
   `"databaseProvider":"neon"`, `"database":"ok"` and `"auth":"supabase"`. Sign in and open
   the dashboard, Signage and Onsite.
4. Then downgrade the Supabase organisation to Free (Billing). For the weekly backup, use
   the Neon `DATABASE_URL_UNPOOLED` as the `DIRECT_DATABASE_URL` secret.

### 4. Weekly backup to the bucket

The Free plan has no backups, so `.github/workflows/db-backup.yml` dumps the database
every Monday into `backups/` in the bucket. Add the repository secrets
`DIRECT_DATABASE_URL`, `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`,
`S3_SECRET_ACCESS_KEY` (GitHub → Settings → Secrets and variables → Actions) and run the
workflow once by hand to check it. For `DIRECT_DATABASE_URL` use the **Session pooler**
URI from Supabase's Connect dialog (port 5432, user `postgres.<ref>`), not the direct
`db.<ref>.supabase.co` address, which is IPv6-only on the Free plan and unreachable from
GitHub's runners. Restore with
`pg_restore --clean --if-exists --no-owner -d "<session pooler URI>" hallpass-<date>.dump`.

## Imagery

Public and portal pages ship with built-in vector scenes of event crews at work. To use real
photography (e.g. AI-generated imagery), drop files into `public/images/` named `hero`,
`office`, `login` and `portal` (`.jpg`, `.png` or `.webp`) — they replace the corresponding
scene automatically, no code changes.

## Repository layout

Per the brief: `app/` (routes + `actions/` server actions, one intent per file), `components/`, `lib/` (`authz.ts`, `workflow/`, `status/`, `deadlines.ts`, `refs.ts`, `audit.ts`, `email/`, `exports/`, `storage.ts`, `db/` with schema, migrations and seed), `tests/unit` and `tests/e2e`.
