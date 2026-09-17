# Hall Pass

Internal signage schedule and design sign-off platform for exhibitions. One register for every piece of organiser signage and every exhibitor stand design, with configurable approval chains, automatic deadline chasing and an immutable audit trail.

See `PLAN.md` for the phased build plan and `CLAUDE.md` for conventions and the non-negotiables. Decisions made where the brief is silent are logged in `DECISIONS.md`.

## Status

**Phase 0 in progress.** The app currently deploys as a navigable shell: every route from the brief exists with the shared layout (left navigation, edition switcher, portal navigation), and screens are placeholders labelled with the phase in which they arrive. Database, auth and business logic land next.

## Stack

Next.js (App Router) · TypeScript strict · Tailwind CSS + shadcn/ui · Supabase (Postgres, Auth, Storage) · Drizzle ORM · Resend · Vercel. See `CLAUDE.md` for the full list.

## Local setup

```bash
pnpm install
cp .env.example .env.local   # fill in values (see comments per variable)
pnpm dev                     # http://localhost:3000
```

Checks:

```bash
pnpm typecheck
pnpm lint
pnpm format        # prettier --check
pnpm build
```

Unit tests (Vitest) and end-to-end tests (Playwright) are added in Phase 0 as the first business logic lands.

## Supabase setup

Not yet wired in (Phase 0, milestone 0.B/0.C). When it is:

1. Create a Supabase project; note the URL, anon key and service role key.
2. Set `DATABASE_URL` to the pooled connection string (transaction mode) and `DIRECT_DATABASE_URL` to the direct connection string.
3. `pnpm db:migrate` to apply migrations, `pnpm db:seed` to load the idempotent seed.

## Deploying to Vercel

1. Go to [vercel.com/new](https://vercel.com/new) and import the `Umo86/Hall-Pass` GitHub repository.
2. Name the project **`hall-pass`** — the production URL becomes `hall-pass.vercel.app` (if that subdomain is taken globally, Vercel appends a suffix; you can adjust the domain under Project → Settings → Domains).
3. Framework preset: Next.js (auto-detected). Build command and output: defaults. Install command: `pnpm install` (auto-detected from the lockfile).
4. Add the environment variables from `.env.example`. For the current shell deployment only `NEXT_PUBLIC_BRAND_NAME` (optional) and `NEXT_PUBLIC_APP_URL` matter; the rest are needed from Phase 0 onwards.
5. Deploy. Production deploys track `main`; every pull request gets a preview deployment.

### Cron

The daily scheduler endpoint is `GET/POST /api/cron/daily`, protected by `Authorization: Bearer <CRON_SECRET>`. The Vercel Cron entry is added in Phase 2 when the jobs exist; schedule it in UTC (the handler computes "today" in Europe/London so BST/GMT changes don't break it).
