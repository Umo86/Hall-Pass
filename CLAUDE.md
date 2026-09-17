# CLAUDE.md — Hall Pass

Internal signage schedule and design sign-off platform for Media10 (first event: UK Construction Week). Two modules — Signage Schedule and Stand Design Approvals — on one shared engine (users/roles, workflows, comments, documents, deadlines, floorplans, notifications, exports, audit). See `PLAN.md` for the phased build plan and the build brief for full requirements.

## Non-negotiables

1. Every mutation goes through a server action or route handler that checks authorisation via one module (`lib/authz.ts`). No client-side database access, ever.
2. Every approval decision records who, when, the exact file version it was made against, and that file's SHA-256. Uploading a new version invalidates approvals according to workflow config — never silently.
3. The audit log is append-only, enforced at the database level (trigger raising on UPDATE/DELETE), not just in code.
4. External users (venue, engineer, H&S, supplier, exhibitor, sponsor) only ever see the records they are scoped to. Tested explicitly, including 403/404 by URL.
5. The workflow engine, status machines, authorisation rules and deadline calculations are pure TypeScript with unit tests. No business logic lives only in UI components.
6. Times are stored as `timestamptz` and displayed in Europe/London. UI copy uses British English.
7. The brand name is a config value (default "Hall Pass") — no hard-coded product name in UI or emails.

## Stack (fixed — do not substitute)

- Next.js (App Router) · React · TypeScript strict
- Tailwind CSS · shadcn/ui · Inter via `next/font` · lucide-react
- Supabase (Postgres, Auth, Storage) — RLS deny-by-default on every table; the app uses the service role from the server only
- Drizzle ORM + drizzle-kit migrations (`DATABASE_URL` pooled/transaction mode; `DIRECT_DATABASE_URL` for migrations)
- Zod schemas shared client/server for every form and import
- TanStack Table (schedule grid) · `nuqs` (URL-synced filters) · react-hook-form
- Resend + react-email · exceljs · `@react-pdf/renderer` · `qrcode` · `sharp` + `pdfjs-dist` (previews)
- Vercel hosting · Vercel Cron (daily scheduler, `CRON_SECRET`-protected)
- Vitest (unit) · Playwright (e2e) · ESLint + Prettier · pnpm · pino (structured logs)

## Commands

```bash
pnpm dev              # run locally
pnpm build            # production build
pnpm typecheck        # tsc --noEmit
pnpm lint             # eslint + prettier check
pnpm test             # vitest unit tests
pnpm test:e2e         # playwright
pnpm db:generate      # drizzle-kit generate migrations
pnpm db:migrate       # apply migrations (DIRECT_DATABASE_URL)
pnpm db:seed          # idempotent seed — safe to run twice
```

## Folder layout

```
app/
  (auth)/login, auth/callback, invite/[token]
  (app)/editions, [editionCode]/{dashboard,signage,stands,floorplan,onsite,reports}, approvals, settings/*
  (portal)/portal/{submission,items,approvals}
  q/[ref]
  api/cron/daily, api/ical/[token]
  actions/              # server actions, one intent per file
components/             # ui (shadcn), schedule grid, approval chain, artwork viewer, floorplan, forms
lib/
  authz.ts              # can(actor, action, resource) — the only authorisation module
  workflow/             # engine, conditions, activation, invalidation (pure functions)
  status/               # signage.ts, stand.ts (pure transition functions)
  deadlines.ts          # pure deadline calculations
  refs.ts               # ref generation with row lock
  audit.ts              # audit row writer, same transaction as the change
  email/                # react-email templates, send with retry
  exports/              # excel, pdf, ical
  storage.ts            # signed URLs, hash verification, previews
  db/                   # drizzle schema, client, migrations, seed
tests/
  unit/                 # vitest
  e2e/                  # playwright
```

## Conventions

### Server actions

One intent per file under `app/actions/`, named by intent (`submitForReview`, `decideApproval`, `uploadArtworkVersion`). Every action follows the same shape:

1. Parse input with zod
2. Load the actor (verify the Supabase session)
3. `authz.can(actor, action, resource)` — before every read of non-public data and every mutation
4. Transaction: the change **plus its audit row** in the same transaction
5. Revalidate
6. Return a typed result (never throw raw errors to the client; no stack traces reach the browser)

### Database

snake_case columns; `id uuid default gen_random_uuid()`; `created_at`/`updated_at` on everything; `deleted_at` where soft delete applies; statuses and kinds are Postgres enums; every FK indexed plus `(edition_id, status)` on `signage_items` and `stand_submissions`; refs are never reused.

### UI

shadcn/ui components; react-hook-form + zod; toasts for success, inline errors for validation; destructive or consequential actions behind a confirm dialog that states the consequence; every list has a real empty state with its primary action. Quiet, dense, professional; light theme default with dark mode; no gradients, no emoji; one colour token per status, always accompanied by the status text. British English throughout. Onsite section is mobile-first.

### Testing

Tests first for the workflow engine, status machines and authz; alongside the code everywhere else. Status machines get table-driven tests asserting every legal transition and that every other transition throws. Authz gets a test per permission-matrix row, including negatives. Cron jobs are pure functions taking `today`.

### Security

Secrets only in environment variables (`.env.example` kept complete, one comment per variable); the Supabase service role key never appears in client code; signed URLs only, no public buckets; magic-link and invite endpoints rate-limited; security headers (CSP, HSTS, nosniff, frame-ancestors none).

### Git

Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `refactor:`). One task, one commit where practical.

### Decisions

Where the brief is silent or ambiguous, choose the option that is simplest to test and easiest to change later, and log it with a one-line reason in `DECISIONS.md`. Ask before: adding a paid service, changing the stack, changing a status machine or workflow rule, or writing anything that deletes data.

## Definition of done (every task)

- [ ] `pnpm typecheck` green
- [ ] `pnpm lint` green
- [ ] `pnpm test` green (new code has tests; engine/status/authz code has tests written first)
- [ ] Every mutation writes its audit row inside the same transaction
- [ ] Every mutation and non-public read goes through `authz.can()`
- [ ] Committed with a Conventional Commits message
- [ ] Three-line report: what changed, what to click to see it

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
