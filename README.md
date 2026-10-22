# Hall Pass

Internal signage schedule and design sign-off platform for exhibitions. One register for every piece of organiser signage and every exhibitor stand design, with configurable approval chains, automatic deadline chasing and an immutable audit trail.

See `PLAN.md` for the build plan and current status, `CLAUDE.md` for conventions and the non-negotiables, and `DECISIONS.md` for choices made where the brief was silent.

## What the platform includes

- **Signage schedule** — every item for an event in one list: organiser or sponsor signage (with the sponsor's name), print or digital, the supplier, and everything from the Sponsorship section. Full lifecycle (draft → sign-off → production → delivery → install → close, plus hold/reject/reopen), artwork versions with never-silent invalidation, table/Kanban/phone views, Excel import/export, spec labels and approval certificates.
- **Approvals** — one place for artwork sign-off. _Waiting on me_ lists what each person needs to decide (with a review sheet that moves on to the next one); _All artwork_ shows every item with a graphic, filterable by event and sign-off state, with who approved, rejected or asked for changes and their comments; _Who signs off_ shows, read-only, which departments sign off what (they are set up in Users → Departments). On each item, whoever adds it can untick a department or pick a different person; the assignee is emailed. Every decision and comment is logged in History.
- **Invite-only sign-in (Better Auth, in our own database)** — there is no sign-up. Admins invite people (team, approvers, partners); our invitation email has a link where they set their name and password, and while email isn't set up the invitation link is shown to pass on ("Copy link"). Sign-in is by email and password (or an emailed link); "Forgot password" and sign-in links only go to invited people, and the reply never reveals who has an account. Super admins can also make a one-time sign-in or password reset link for someone to pass on. Demo sign-in is never on for Vercel production.
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
- **Events** — everyone works on All events (including ones created later) unless their page says _Only these events_. A limited person sees only those events everywhere — the switcher, lists, counts, the bell, emails, exports, the calendar feed — and anything in another event answers as not found; nobody offers them work there. Narrowing someone hands their sign-offs in the events taken away back to the department (or to someone picked when nobody else there can open them); their tasks and items stay, listed on their page. A manager limited to some events gives and takes only those; super admins always see every event. Creating an event adds it to the creator's list, and copying one offers it to the people who only see the original.
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

Without `BETTER_AUTH_SECRET`, the login page offers **development sign-in** as any seeded user (admin/ops/marketing/sales/director/viewer @media10.test, plus the external venue/engineer/H&S/supplier/exhibitor/sponsor users). `DEV_AUTH=1` keeps it on next to real sign-in — then it only accepts the seeded `…@….test` accounts, and every page shows a red "Demo sign-in is on" bar. It is never on for Vercel production, whatever `DEV_AUTH` says.

**Going live:** invite yourself as admin (Users), open the invitation link and choose a password, then remove `DEV_AUTH` and redeploy. See [Sign-in](#sign-in).

**Real sign-in locally:** add `BETTER_AUTH_SECRET=` with any 32 or more characters (keep `DEV_AUTH=1` for the one-click demo accounts; with the secret set they're limited to `…@….test`). Email isn't set up locally, so "Forgot password?" and "Email me a link" show the link that would have been emailed right on the sign-in page (local development only). My account has Password; a super admin's person page has "Copy a sign-in link" and "Copy a password reset link".

**Start a real organisation** (no demo data): on an empty, migrated database run

```bash
SEED_MODE=starter FIRST_ADMIN_EMAIL=you@company.com ORG_NAME="Your company" pnpm db:seed
```

It creates only the organisation, the first admin (an invitation whose link the command
prints; a `…@….test` address gets a demo sign-in account instead), the departments
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
BETTER_AUTH_SECRET=<32+ chars> pnpm test:e2e # as CI runs it: real sign-in on, auth.spec.ts too
pnpm build
```

## Deploying to Vercel (all-Vercel setup)

1. Import `Umo86/Hall-Pass` at [vercel.com/new](https://vercel.com/new).
2. **Database** — in the project's **Storage** tab, create/connect a **Postgres (Neon)**
   database. The integration injects `POSTGRES_URL` (pooled) and `DATABASE_URL_UNPOOLED`
   (direct) among others. Set `DATABASE_TARGET=neon` on Production: the app then runs on
   `POSTGRES_URL` only and migrations use `DATABASE_URL_UNPOOLED` (then
   `POSTGRES_URL_NON_POOLING`), with no probing and no fallback. Without `DATABASE_TARGET`
   (local development, CI) the app accepts any of `DATABASE_URL`, `DIRECT_DATABASE_URL`,
   `POSTGRES_URL`, `DATABASE_URL_UNPOOLED`, `POSTGRES_URL_NON_POOLING` and uses the first
   reachable one. Preview deployments get no database unless `DATABASE_TARGET` is set for
   Preview too (the integration hands Preview the production database's URLs).
3. **Schema + demo data** — open the database's SQL editor (Storage tab → Open in Neon →
   SQL Editor), paste the whole of `database-setup.sql` (repo root; re-runnable) and run it.
4. **Files** — an S3-compatible bucket (Cloudflare R2 recommended, see
   [Running on free plans](#running-on-free-plans-supabase-free--cloudflare-r2)) via
   `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`. Large artwork goes
   browser → bucket directly through a presigned upload (up to 2 GB per file). Vercel Blob
   (`BLOB_READ_WRITE_TOKEN`, from the Storage tab) still works as an alternative; without
   either, uploads fall back to the serverless filesystem, which does not persist.
5. Remaining env vars (Settings → Environment Variables):
   - `BETTER_AUTH_SECRET` — signs sessions and sign-in links (`openssl rand -base64 32`,
     Sensitive). Optional on Production only: without it the secret is derived from
     `CRON_SECRET` (see [Sign-in](#sign-in)). Previews need it set for real sign-in.
   - `DEV_AUTH=1` — demo sign-in on previews and locally (one-click seeded users; never on
     Production; remove before real use)
   - `STANDS_ENABLED=1` — optional; shows stand approvals (hidden by default)
   - `CRON_SECRET` — any long random string (Vercel Cron sends it automatically)
   - `RESEND_API_KEY` + `EMAIL_FROM` — transactional email (optional; sends are logged until
     BOTH are set, and sign-in links, resets and invitations are then handed over instead)
   - `NEXT_PUBLIC_APP_URL` — recommended (the address in sign-in and reset links);
     auto-detected from the Vercel domain when unset
6. Redeploy. `vercel.json` schedules the daily cron at 06:00 UTC (07:00 BST); the handler
   computes "today" in Europe/London so clock changes don't break it. Verify at
   `/api/health` — it should return `"ok":true`, `"auth":"better-auth"` (with
   `"demoSignIn":false` on Production) and `"authBaseUrl"` naming your domain, and states
   which database is in use (`databaseTarget`, `databaseProvider`, `databaseProject`,
   `databaseRegion`, `databaseVia`), the functions' region (`functionRegion`) and the
   storage backend.

## Releasing a new version (upgrading the live database)

Every staff and partner page load reads the signed-in person's membership, which selects
every column the code knows about. If the code is deployed before its migrations have run,
every signed-in page fails with `column … does not exist` until they do. The build doesn't
migrate (`next build` only; `vercel.json` has no migration step), so, in this order:

1. **Migrate first.** Run the **Database migrate** workflow on the release's branch (GitHub
   → Actions → Database migrate → Run workflow). It runs `pnpm db:migrate` with the
   repository secret `DIRECT_DATABASE_URL`, the live database's _unpooled_ URL (Neon:
   `DATABASE_URL_UNPOOLED`; it refuses pooled hosts), and its log names the provider and host
   it changed. By hand, from a checkout of the release, the same is:

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

### Release 0013 (`0013_users_events_packages`)

Main approver when they accept, events per person and sponsorship packages ship on one
migration. It adds and backfills only (no enum value), so the live code keeps working on it.

1. **Migrate first, by hand** (from a checkout of the release, with the live direct/session
   URL):

   ```bash
   HASH=$(sha256sum lib/db/migrations/0013_users_events_packages.sql | cut -d' ' -f1)
   WHEN=$(node -p "require('./lib/db/migrations/meta/_journal.json').entries.at(-1).when")
   psql "$DIRECT_DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
   BEGIN;
   \i lib/db/migrations/0013_users_events_packages.sql
   INSERT INTO drizzle.__drizzle_migrations (hash, created_at)
   SELECT '$HASH', $WHEN
   WHERE NOT EXISTS (SELECT 1 FROM drizzle.__drizzle_migrations WHERE created_at = $WHEN);
   COMMIT;
   SQL
   ```

   (`DIRECT_DATABASE_URL=… pnpm db:migrate` does the same and records the row itself.)

2. **Deploy straight after.** In the gap the old code is running on the new schema: don't
   change main approvers, edit sponsors, or copy events until the new deployment is live (an
   old sponsor edit can rewrite `package_name` away from its package; an old copy brings
   package names across as free text).
3. **Run the file once more** after the deploy (without the bookkeeping insert): it is
   idempotent and picks up notifications and sponsors the old code wrote in the gap.
4. **Check** `/api/health`: `"schema": "current"`, `"ok": true`.

**Rolling back past 0013** is unsafe once anyone is limited to events (older code ignores
`edition_ids`, so they would see every event) or an ask is pending (older code links approver
rows without clearing `main_on_accept`, the CHECK refuses, and that person can't finish
signing in). Roll forward instead. If a rollback can't be avoided, first:

```sql
UPDATE approvers SET main_on_accept = false, main_on_accept_by = NULL WHERE main_on_accept;
```

and suspend (Users → Suspend) everyone limited to events who must not see the others. Package
prices entered after the release stay in the database but aren't shown until the roll-forward;
`package_name` is mirrored, so names still show.

### Release 0014 (`0014_better_auth`)

Sign-in moves from Supabase Auth to Better Auth, in this database. 0014 only adds (four
`auth_*` tables and `users.email_verified`) and copies each Supabase password (bcrypt) to
the account with the same id, so people keep their passwords; the first password sign-in
rehashes it. Migrate, deploy, then run `scripts/auth-carry-over.sql` once against the same
database (`psql "$DIRECT_DATABASE_URL" -f scripts/auth-carry-over.sql`): it picks up any
Supabase account created between migrating and deploying and changes nothing else.
Passwords are matched by account id only, never by email, so a seeded demo account can't
take a password from a Supabase sign-up. Stop and find out why before going on if, before
migrating, the number of Supabase accounts
(`SELECT count(*) FROM auth.users WHERE deleted_at IS NULL`) isn't the number of people who
sign in with a password today, or if, after migrating or after the catch-up script, the
number of passwords (`SELECT count(*) FROM auth_account WHERE provider_id = 'credential'`)
isn't that number either (one on the live site, the owner). A
rollback to the previous deployment is safe (it ignores the new tables and still finds the
passwords in Supabase Auth); anyone who accepted an invitation in between needs a new one.
After deploying, `/api/health` reports `"auth":"better-auth"` and `"demoSignIn":false`;
`DEV_AUTH` no longer does anything on Production (set it to `0`, delete it when convenient).

Supabase Postgres remains supported as the database (its pooler URIs in `DATABASE_URL`/
`DIRECT_DATABASE_URL`). `database-setup.sql` runs unchanged in its SQL editor.

## Moving the database to Neon

A one-off copy of everything in `public` and `drizzle` (sign-in tables included, so people
stay signed in) from Supabase to Neon in London, then a switch. Nothing happens until it is
switched on: Release A ships the tool and the switch; Release B (`vercel.json` →
`"regions": ["lhr1"]`) moves the functions next to the database at the switch.

- **The switch:** `DATABASE_TARGET=neon` (Production, plain). Unset or `auto` is the
  behaviour before the move (the rollback value, as a variable can't be deleted with the
  tools at hand); anything else means no database. On Vercel, `auto` never falls back onto
  a Neon URL: an instance that couldn't reach Supabase at start-up would otherwise write to
  Neon while the tool treats Supabase as live.
- **The database on Neon:** `NEON_DATABASE=hallpass` (Production, plain). The integration's
  own database (`neondb`) sorts text as C.UTF-8 ("Bob" before "alice"); Supabase's sorts
  as ICU en-US, and a database's collation can't change once it exists. So `step=prepare`
  makes `hallpass` on the same Neon server with Supabase's collation, and every Neon URL
  (the app's, migrations', backups', the tool's) names it instead of `neondb`.
- **The tool:** `GET /api/admin/move-database?step=<step>&token=<MOVE_DATABASE_TOKEN>` (or
  `Authorization: Bearer <token>`). It is a 404 unless `MOVE_DATABASE_TOKEN` (Production,
  Sensitive, `openssl rand -hex 32`) is set and isn't `off`. Steps that change something also
  need `confirm=<step>`. It reads Supabase from `DIRECT_DATABASE_URL` and Neon from
  `DATABASE_URL_UNPOOLED`, never copies into the database the app runs on, copies from it
  only once it is frozen (`unfrozen=1` overrides that, for when freezing is refused), and
  replies with hosts only. While the token is set the daily orphan-artwork sweep is paused.
  Each copy also keeps its snapshot's per-table digests on the target, in schema `db_move`
  (outside `public` and `drizzle`, so nothing else sees it), for `finish`.

  | Step        | What it does                                                                                                                                                                                                                             |
  | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | `check`     | Read-only preflight: versions, collation, owners, frozen or not, rows, migrations against this release                                                                                                                                   |
  | `prepare`   | Makes `NEON_DATABASE` on the Neon server with Supabase's collation; keeps one that is already right, refuses (never drops) one that isn't                                                                                                |
  | `files`     | Read-only: every file the database (`db=`, default the live one) refers to exists in the bucket                                                                                                                                          |
  | `freeze`    | `db=supabase\|neon`: read-only. A: write privileges revoked from the owner, roles it inherits (Supabase's `service_role`) and PUBLIC, recorded first in `db_move.frozen_grants`; B (if A can't): read-only sessions, every session ended |
  | `unfreeze`  | `db=…`: writable again, exactly the privileges A recorded; after strategy B it also ends the sessions opened during the freeze, so they reconnect writable                                                                               |
  | `copy`      | Migrates the target, then copies in one snapshot and one transaction, checked before commit (`replace=1` to overwrite a previous copy, `batch=50–2000`)                                                                                  |
  | `verify`    | Live comparison: every table, the schema, sequences, both fingerprints (`detail=1` for full lists)                                                                                                                                       |
  | `finish`    | `expect=<copy's fingerprint>`, once the app is on Neon: Supabase unchanged since the copy (else `differingTables` names what changed), then one audit row                                                                                |
  | `back-copy` | Neon → Supabase, replacing Supabase's data (the lossless rollback)                                                                                                                                                                       |

**Runbook** (a weekday, 10:00–10:45 London; Hall Pass, sign-in included, is unavailable
during the window). Save every reply.

1. **Before:** run "Database backup" (until its `DIRECT_DATABASE_URL` secret exists, the frozen
   Supabase project, whose data the move never changes, is the fallback; a scheduled run without
   the secret warns instead of failing). Create `MOVE_DATABASE_TOKEN` and `NEON_DATABASE=hallpass`,
   then merge Release A. `/api/health`: `ok:true`, `databaseTarget:"auto"`,
   `databaseProvider:"supabase"`, `databaseVia:"DIRECT_DATABASE_URL"`, `schema:"current"`.
   Deploy nothing else until step 7. `step=prepare&confirm=prepare` → `created:true`,
   `target:"ICU en-US, UTF8"`, `collationMatch:true` (run again: `created:false`).
2. `step=check`: `readyToCopy:true` (otherwise `blockers` says why), `migrations` `{ bundled:
15, latest: "0014_better_auth", source: 15, match: true }`, source `tables: 48`, target
   `database:"hallpass"`, `state:"empty"`, `collationMatch:true`, `ownsAllTables:true` on
   both sides.
3. `step=files&db=supabase`: note `missing` (reported, not a blocker).
   **Rehearsal** (optional, a day ahead, the app still live): `step=copy&confirm=copy&unfrozen=1`
   → `ok:true`, `migrationsApplied:15` (its own in-snapshot check proves every row); straight
   after, `step=verify` → schema and sequences match. Tables the app writes in normal use
   (`users`, `auth_session`, `auth_rate_limit`, `audit_log`, `notifications`, `email_log`,
   `reminder_log`) may differ by then: that is live traffic, not the copy. Don't keep its
   fingerprint. From then on `check` says target `state:"previousCopy"` (with every table
   non-empty and `db_move` among `otherSchemas`), and step 5 needs `replace=1`.
4. **Window starts.** `step=freeze&db=supabase&confirm=freeze` → `frozen:true`; `check`
   again shows `source.frozen:true`.
5. `step=copy&confirm=copy` (`&replace=1` after a rehearsal) → `migrationsApplied:15`, the
   five deferred cycle columns, `totalRows`, and `fingerprint` (F: keep only this one). A
   failed copy leaves Neon as it was (after a rehearsal, the rehearsal's copy, which nothing
   reads until the switch).
6. `step=verify` → `ok:true`; schema functions 2, triggers 46, constraints
   `{c:20,f:106,p:48,u:21}`; `sourceFingerprint` = `targetFingerprint` = F.
7. **Switch:** create `DATABASE_TARGET=neon` (Production), push Release B, wait for READY.
8. `/api/health`: `databaseTarget:"neon"`, `databaseProvider:"neon"`, `databaseProject`
   (the Neon project), `databaseName:"hallpass"`, `databaseRegion:"aws-eu-west-2"`,
   `functionRegion:"lhr1"` (the authority; an `x-vercel-id` header reads
   `<edge>::lhr1::<request id>`), `schema:"current"`, `seeded:true`, no `databaseError`.
   Settings → System says London.
9. `step=files` again (now Neon): the same as step 3. Sign in, open the dashboard, an item
   with artwork and Users.
10. `step=finish&expect=F&confirm=finish` → `sourceUnchanged:true` and the audit row
    "Database moved from Supabase to Neon (London): N rows verified". The window ends.
11. **After:** set the GitHub secret `DIRECT_DATABASE_URL` to Neon's `DATABASE_URL_UNPOOLED`
    with `/neondb` at the end changed to `/hallpass`, and run "Database backup": its log says "Backing up the database at ep-….neon.tech
    (Neon)" (a Supabase host there means the secret wasn't changed). Keep Supabase frozen and
    the token set until Phase 3.

**Rolling back.** Before step 7: `step=unfreeze&db=supabase&confirm=unfreeze`. After it, with
nothing written to Neon yet: Instant Rollback to Release A, `DATABASE_TARGET=auto`, unfreeze
Supabase, revert Release B. Either way, once a copy reached Neon also
`step=freeze&db=neon&confirm=freeze`, so the copy can't take writes (`unfreeze` it before the
next attempt). After people have used Neon (nothing lost): if Supabase is
paused, restore it first; `step=freeze&db=neon&confirm=freeze`;
`step=unfreeze&db=supabase&confirm=unfreeze`; `step=back-copy&confirm=back-copy`;
`step=verify&from=neon&to=supabase` → `ok:true`; Instant Rollback to Release A;
`DATABASE_TARGET=auto`.

**If `check` isn't ready:** a different collation needs `step=prepare` (and `NEON_DATABASE`);
a schema difference wanted on Neon (`verify&detail=1`) ships as migration 0015, applied to
Supabase before the window; a migration hash mismatch means a file changed after it ran, or
(0010 on Supabase, fixed 2026-10-21) the row records a draft's hash while the schema is the
file's: correct the row's `hash`, never the comparison.

## Sign-in

Better Auth runs inside the app and keeps everything in this database (`users` plus
`auth_session`, `auth_account`, `auth_verification`, `auth_rate_limit`). There is no
sign-up and no client SDK: every sign-in step is a server action, and over HTTP only the
email-link landing (`GET /api/auth/magic-link/verify`) answers.

- **The secret.** `BETTER_AUTH_SECRET` when it is set. Otherwise, on Vercel Production only
  (`VERCEL_ENV=production`) and when `CRON_SECRET` is set, it is
  `HMAC-SHA256(CRON_SECRET, "hall-pass:better-auth:v1")` in hex, so no new secret has to be
  typed or shown anywhere. Real sign-in is on when either gives a secret; changing either
  value signs everyone out (sessions and links stop validating). Locally and in CI's unit
  step nothing changes; CI's end-to-end step sets `BETTER_AUTH_SECRET`.
- **Sessions** last 30 days and roll while people use the app: once a day at most, the
  session and its cookie are extended together. Pages can't rewrite cookies, so they read
  the session without rolling it; the staff and partner layouts ping `/api/session` on each
  full page load and hourly (as do the bell and server actions), and that rolls it.
  Suspending someone, removing them, their access end date passing, a password reset and a
  password change (other devices) end their sessions at once.
- **Links** (sign-in and reset) work once, for an hour, and are stored hashed. Sign-in, link
  and reset requests are rate-limited in production (`AUTH_RATE_LIMIT=1` elsewhere).
- **Email.** With `RESEND_API_KEY` and `EMAIL_FROM` set, invitations, sign-in links and
  resets are emailed. Without them invitations show the link to pass on, "Email me a link"
  and "Forgot password?" say email isn't set up, and super admins can make one-time sign-in
  and reset links on a person's page, on Users → External for partners, and on the
  invitation page of someone invited again who already has an account (a removed team
  member, a partner whose access ended). In local development (no email) the login page shows
  the link that would have been sent. To switch email on: verify a sending domain at
  resend.com, create an API key, add `RESEND_API_KEY` (Sensitive) and `EMAIL_FROM`
  (e.g. `Hall Pass <noreply@mail.example.com>`) on Vercel and redeploy.
- **Changing a password.** Staff: My account → Password (it asks for the current one and
  signs out every other device). Partners use "Forgot password?". There is no email change.
- **Demo sign-in** (`DEV_AUTH=1`, or local development without a secret) is never possible
  on Vercel Production, whatever `DEV_AUTH` says; elsewhere, next to real sign-in, it only
  takes the seeded `…@….test` accounts.
- **Demo logins (testing only, temporary).** `DEMO_LOGIN_PASSWORD` (8+ characters,
  Production) lists every seeded `…@….test` account under the sign-in form — role, name,
  email — with that shared password; picking one fills in the form. Signing in with it sets
  it as that account's password (audited); only that password is taken, and it can't be
  changed from My account. Demo accounts keep their role but can't add, change or remove
  people, invite partners, make sign-in links, or change departments or system settings,
  so nobody who reads the page can reach a real person's access. Delete the variable and
  redeploy to turn it off: on any Vercel deployment with real sign-in the demo accounts then
  can't sign in at all, and any session or calendar feed they have stops working.
- **Checking it.** Settings → System → Sign-in says, in plain words, whether real sign-in
  and demo sign-in are on and where the secret comes from; `/api/health` reports `auth`
  (`better-auth`, `demo` or `none`), `demoSignIn` and `authBaseUrl`.
- **Locked out** (the last super admin forgot their password and email is off):
  `DATABASE_URL='<live database URL>' pnpm auth:set-password you@company.com` prints a new
  20-character password once, signs them out everywhere and writes an audit row. On Neon,
  use `DATABASE_URL_UNPOOLED` from Vercel → Storage → the Neon database → `.env.local` →
  Show secret, pasted as it is.

## Running on free plans (Supabase Free + Cloudflare R2)

The cheapest setup that still copes with large print-ready graphics:

| Part                                        | Service                  | Free allowance                                       | What to know                                                                                                                       |
| ------------------------------------------- | ------------------------ | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Database (sign-in data lives here too)      | Supabase **Free**        | 500 MB database, 2 projects per organisation         | Pauses after a quiet week; the daily cron's queries keep it awake. No automatic backups — the daily GitHub Action below takes one. |
| Database, alternative (see 3b)              | Neon **Free** via Vercel | 1 GB, 6-hour restore window                          | Scales to zero and wakes by itself.                                                                                                |
| Files (artwork, photos, documents, exports) | Cloudflare **R2**        | 10 GB storage, no egress fees, up to 5 GB per upload | Needs a Cloudflare account; R2 may ask for a payment method on first use but charges nothing inside the allowance.                 |
| App                                         | Vercel **Hobby**         | Cron once a day, 1 GB Blob                           | Hobby is for non-commercial use; move to Pro when the tool runs a real show for a business.                                        |

Vercel Blob is the simplest file store (1a); R2 (1b) gives ten times the free space and no
transfer fees.

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

### 3b. Or: database on Neon via Vercel

Neon's Free plan (1 GB, scales to zero between requests and wakes by itself, 6-hour
restore window) suits a tool that goes quiet between shows, and it lives in the Vercel
dashboard. Sign-in runs in the app (Better Auth) and keeps its sessions and passwords in
the `auth_*` tables, so they move with the data and nobody has to set a new password.

1. Vercel → project → **Storage** → **Create Database** → **Neon** (Free), region
   Frankfurt, connect it to the project. Vercel adds `DATABASE_URL`,
   `DATABASE_URL_UNPOOLED` and `POSTGRES_URL`. If it refuses because `DATABASE_URL` already
   exists, delete the old Supabase `DATABASE_URL` and `DIRECT_DATABASE_URL` variables
   (Settings → Environment Variables) and connect again.
2. Load the schema and data into the empty database with the import file generated from
   the live database (`neon-import.sql`, kept out of the repository because it holds real
   data): `psql "<DATABASE_URL_UNPOOLED from Vercel>" -v ON_ERROR_STOP=1 -f neon-import.sql`.
   It refuses to run on a database that already has data. `psql` comes with Postgres
   (macOS: `brew install libpq`). Make the file again if the old database was used after it
   was generated.
3. **Redeploy** so the functions pick up the new variables. `/api/health` should show
   `"databaseProvider":"neon"`, `"database":"ok"` and `"auth":"better-auth"`. Sign in and open
   the dashboard, Signage and Onsite.
4. Then downgrade the Supabase organisation to Free (Billing). For the daily backup, use
   the Neon `DATABASE_URL_UNPOOLED` as the `DIRECT_DATABASE_URL` secret.

For the live site, [Moving the database to Neon](#moving-the-database-to-neon) replaces
steps 1–3: the move tool copies and checks every row instead of an import file.

### 4. Daily backup to the bucket

Neon's Free plan keeps a 6-hour restore window only, so `.github/workflows/db-backup.yml`
dumps the database every day into `backups/` in the bucket, with the `pg_dump` client that
matches the server's version, and uploads only a dump that reads back with at least 48
tables. Add the repository secrets `DIRECT_DATABASE_URL`, `S3_BUCKET`, `S3_ENDPOINT`,
`S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (GitHub → Settings → Secrets and variables →
Actions) and run the workflow once by hand to check it. For `DIRECT_DATABASE_URL` use Neon's
`DATABASE_URL_UNPOOLED` (Vercel → project → Storage → the Neon database → `.env.local` tab →
Show secret), never the pooled `-pooler` host; until the move it is Supabase's **Session
pooler** URI (port 5432, user `postgres.<ref>`), not the IPv6-only `db.<ref>.supabase.co`.
The same secret drives the **Database migrate** workflow. Restore with
`pg_restore --clean --if-exists --no-owner --no-privileges -d "<Neon direct URL>" hallpass-<date>.dump`.

## Imagery

Public and portal pages ship with built-in vector scenes of event crews at work. To use real
photography (e.g. AI-generated imagery), drop files into `public/images/` named `hero`,
`office`, `login` and `portal` (`.jpg`, `.png` or `.webp`) — they replace the corresponding
scene automatically, no code changes.

## Repository layout

Per the brief: `app/` (routes + `actions/` server actions, one intent per file), `components/`, `lib/` (`authz.ts`, `workflow/`, `status/`, `deadlines.ts`, `refs.ts`, `audit.ts`, `email/`, `exports/`, `storage.ts`, `db/` with schema, migrations and seed), `tests/unit` and `tests/e2e`.
