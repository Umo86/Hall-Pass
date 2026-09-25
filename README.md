# Hall Pass

Internal signage schedule and design sign-off platform for exhibitions. One register for every piece of organiser signage and every exhibitor stand design, with configurable approval chains, automatic deadline chasing and an immutable audit trail.

See `PLAN.md` for the build plan and current status, `CLAUDE.md` for conventions and the non-negotiables, and `DECISIONS.md` for choices made where the brief was silent.

## What the platform includes

- **Signage schedule** — every item for a show in one list: organiser or sponsor signage (with the sponsor's name), print or digital, the supplier, and everything from the Sponsorship section. Full lifecycle (draft → sign-off → production → delivery → install → close, plus hold/reject/reopen), artwork versions with never-silent invalidation, table/Kanban/phone views, Excel import/export, spec labels and approval certificates.
- **Approvals** — one place for artwork sign-off. *Waiting on me* lists what each person needs to decide; *All artwork* shows every item with a graphic, filterable by show and sign-off state, with who approved, rejected or asked for changes and their comments; *Approvers* is where admins add departments (any name) and the people in them (name, job title, email), star a main approver, and choose which departments sign off organiser and sponsor signage by default and which sign off last. On each item, whoever adds it can untick a department or pick a different person; the assignee is emailed. Every decision and comment is logged in History.
- **Invite-only sign-in (Supabase)** — there is no sign-up. Admins invite people (team, approvers, partners); Supabase emails them a link that only works from their inbox, where they set their name and password. Sign-in is by email and password (or an emailed link); "Forgot password" and sign-in links only go to invited people, and the reply never reveals who has an account. Demo sign-in is always off on a Vercel deployment with Supabase configured.
- **Shows** — one form for a new show: name, logo, series, venue and address, dates.
- **Suppliers** — a directory of companies with what each does (signage print, screens, staffing…), filterable; new "what they do" entries can be typed straight into the supplier popup. The supplier column in the schedule shows who's making what.
- **Admin pick-lists** — signage types (print/digital), supplier services and venues in Settings, sign-off departments and approvers in Approvals; everyone else chooses from them.
- **Sponsorship** — what's for sale to sponsors as cards: product photo, cost price, supplier, sale price and profit once sold, and a countdown to the order-by date (months and days) with a "Less than 1 month to sell" warning on unsold items. "Mark as sold" records the sponsor (or adds a new one) and the sale price; a Sponsors tab lists each sponsor with what they've bought and spent. Same sign-off and artwork versioning as signage.
- **Fewer, clearer fields** — each form shows only what that kind of item needs (sponsorship: item, buying, sale; signage: what and where, size and fixing, supplier, cost and install); everything else sits in a closed "More details" section. Item pages open with an at-a-glance summary. Cost and sale prices are visible to the whole team.
- **My Work board** — To do (red), In progress (orange) and Complete (green). Drag cards between columns or use each card's menu; assign jobs to each other; each task has a deadline, subtasks with their own deadlines, and attachments on the task and each subtask. Anything past its deadline is highlighted in red on the card and counted at the top.
- **Calendar** — every deadline in red (show deadlines, print deadlines, artwork due, sponsorship order-by dates, sign-offs due, your task deadlines), solid dark red once passed; show dates, deliveries and installs colour-coded, with a key.
- **Team management** — admins set each member's role, fine-tune per-user abilities (add signage, add sponsorship items, edit costs, approve, manage settings) and invite staff by email.
- **Stand design approvals** — structure questionnaire with automatic complex-structure classification, required documents with expiry flags, venue-rules checklist, engineer/H&S/venue review chain, exhibitor portal with submit/resubmit.
- **Shared engine** — configurable workflows with conditions, parallel groups, SLAs, delegation and optimistic locking; creation and assignment notifications with a self-updating bell; internal/external comments; transactional email; daily cron (reminders, escalation, chasers, expiry, digest) with idempotency; append-only audit trail enforced by the database; deny-by-default RLS; every record checked against the caller's organisation (no cross-tenant access, admins included); parameterised queries only; external portals scoped per grant; mobile navigation throughout.
- **Tests** — 580 unit tests (authz + override matrix, status machines, workflow engine, department routing and ordering, deadlines, exports and labels, DB-backed ref concurrency/RLS/audit-trigger/cron idempotency/staff invitations/departments) and 42 Playwright end-to-end tests (every page for every role, hostile input, signed-out access, the task board with subtasks and files, full signage lifecycle to installed with a photo, three-department sign-off with a named approver, adding a department and approver who sets up an account and signs off, sponsor signage, selling a sponsorship item with a photo, suppliers and services, new show with logo, exports, partner item page, team, phone layouts).

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

**Going live:** invite yourself as admin (Settings → Team), sign in with the emailed link, then remove `DEV_AUTH` and redeploy.

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
4. **Files** — in the Storage tab, also create a **Blob** store. Its
   `BLOB_READ_WRITE_TOKEN` is injected automatically; uploads then persist in Vercel Blob,
   with large artwork going browser → Blob directly (up to 2 GB per file). Without it,
   uploads fall back to the serverless filesystem, which does not persist.
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

Supabase remains supported as an alternative (its pooler URIs in `DATABASE_URL`/
`DIRECT_DATABASE_URL`, Storage private buckets named `artwork`, `documents`, `photos`,
`floorplans`, `exports`, and `NEXT_PUBLIC_SUPABASE_URL` + publishable key for real email
sign-in). `database-setup.sql` runs unchanged in its SQL editor.

## Imagery

Public and portal pages ship with built-in vector scenes of event crews at work. To use real
photography (e.g. AI-generated imagery), drop files into `public/images/` named `hero`,
`office`, `login` and `portal` (`.jpg`, `.png` or `.webp`) — they replace the corresponding
scene automatically, no code changes.

## Repository layout

Per the brief: `app/` (routes + `actions/` server actions, one intent per file), `components/`, `lib/` (`authz.ts`, `workflow/`, `status/`, `deadlines.ts`, `refs.ts`, `audit.ts`, `email/`, `exports/`, `storage.ts`, `db/` with schema, migrations and seed), `tests/unit` and `tests/e2e`.
