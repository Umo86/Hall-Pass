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
   - `DEV_AUTH=1` — demo sign-in (one-click seeded users)
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
