# Hall Pass

Internal signage schedule and design sign-off platform for exhibitions. One register for every piece of organiser signage and every exhibitor stand design, with configurable approval chains, automatic deadline chasing and an immutable audit trail.

See `PLAN.md` for the build plan and current status, `CLAUDE.md` for conventions and the non-negotiables, and `DECISIONS.md` for choices made where the brief was silent.

## What version 1 includes

- **Signage schedule** — items with refs, full lifecycle (draft → review → approval → production → delivery → install → close, plus hold/reject/reopen), artwork versions with SHA-256 hashes and never-silent invalidation, table and Kanban views with bulk actions, Excel import/export, approval certificate and A6 spec-label PDFs with QR codes.
- **Stand design approvals** — structure questionnaire with automatic complex-structure classification, required documents with expiry flags, venue-rules checklist, engineer/H&S/venue review chain, exhibitor portal with submit/resubmit.
- **Shared engine** — configurable workflows with conditions, parallel groups, SLAs, delegation and optimistic locking; My Sign-offs across editions; internal/external comments; notifications with transactional email; daily cron (reminders, escalation, chasers, expiry, digest) with idempotency; append-only audit trail enforced by the database; deny-by-default RLS; external portals scoped per grant.
- **Tests** — 448 unit tests (authz matrix, status machines, workflow engine, deadlines, DB-backed ref concurrency/RLS/audit-trigger/cron idempotency) and 9 Playwright end-to-end tests.

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

Without Supabase configured, the login page offers **development sign-in** as any seeded user (admin/ops/marketing/sales/director/viewer @media10.test, plus the external venue/engineer/H&S/supplier/exhibitor/sponsor users). This mode disables itself as soon as Supabase Auth is configured.

Checks:

```bash
pnpm typecheck && pnpm lint && pnpm test   # unit suite (DB tests need TEST_DATABASE_URL)
pnpm test:e2e                              # Playwright (needs the seeded DB; DEV_AUTH=1)
pnpm build
```

## Deploying to Vercel

1. Import `Umo86/Hall-Pass` at [vercel.com/new](https://vercel.com/new); name the project `hall-pass` for the `hall-pass.vercel.app` subdomain.
2. Create a **Supabase** project. In Vercel, set the environment variables from `.env.example`:
   - `DATABASE_URL` — Supabase **pooled** connection string (transaction mode)
   - `DIRECT_DATABASE_URL` — Supabase direct connection string
   - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
   - `NEXT_PUBLIC_APP_URL` — e.g. `https://hall-pass.vercel.app`
   - `CRON_SECRET` — any long random string (Vercel Cron sends it automatically)
   - `RESEND_API_KEY` + `EMAIL_FROM` — for transactional email (optional; sends are logged as failed until set)
   - Optional for a keyless demo: set only `DATABASE_URL`/`DIRECT_DATABASE_URL` and `DEV_AUTH=1` to use development sign-in.
3. Set up the database — either run `supabase-setup.sql` (checked into the repo root: full schema, RLS, triggers and demo seed, verified against a clean Postgres 16) in the Supabase **SQL Editor**, or run migrations and seed from your machine:
   ```bash
   DIRECT_DATABASE_URL=postgres://... pnpm db:migrate
   DIRECT_DATABASE_URL=postgres://... pnpm db:seed
   ```
4. In Supabase Storage, create private buckets: `artwork`, `documents`, `photos`, `floorplans`, `exports`.
5. Deploy. `vercel.json` schedules the daily cron at 06:00 UTC (07:00 BST); the handler computes "today" in Europe/London so clock changes don't break it.

## Imagery

Public and portal pages ship with built-in vector scenes of event crews at work. To use real
photography (e.g. AI-generated imagery), drop files into `public/images/` named `hero`,
`office`, `login` and `portal` (`.jpg`, `.png` or `.webp`) — they replace the corresponding
scene automatically, no code changes.

## Repository layout

Per the brief: `app/` (routes + `actions/` server actions, one intent per file), `components/`, `lib/` (`authz.ts`, `workflow/`, `status/`, `deadlines.ts`, `refs.ts`, `audit.ts`, `email/`, `exports/`, `storage.ts`, `db/` with schema, migrations and seed), `tests/unit` and `tests/e2e`.
