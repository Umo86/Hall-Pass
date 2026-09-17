# Hall Pass — Build Plan

Working plan for building Hall Pass per the build brief. One phase at a time; a phase only starts once the previous phase's acceptance list is met **and confirmed by the product owner**. Each task is sized at a few hours or less and ends with: typecheck, lint and tests green; a Conventional Commits commit; a three-line report.

Statuses: `[ ]` not started · `[~]` in progress · `[x]` done.

---

## V1 build status (September 2026)

Built and tested in v1: all of Phase 0 (schema, migrations, RLS, audit trigger, auth with dev sign-in, authz with full matrix tests, seed, CI); Phase 1 core — signage CRUD with refs, status machine, workflow engine (conditions, parallel groups, decisions with optimistic locking, delegation, restart both ways, invalidation, supplier fallback, hold shifting), artwork versions with invalidation warnings, My Sign-offs, comments, notifications with email, dashboard, table/Kanban schedule with bulk actions, Excel import/export, approval certificate and spec label PDFs, soft delete/restore, supplier/sponsor/venue portals; Phase 2 core — stand submissions with questionnaire/complexity, documents with expiry flags, rules checklist, stand workflow, exhibitor portal, deadlines, all six cron jobs with idempotency tests, stand register export, `/q/[ref]`. 448 unit tests + 9 Playwright e2e tests green.

Remaining (see DECISIONS.md, deferred not dropped): inline grid editing and saved views; artwork preview rendering, compare slider and annotations; floorplan and calendar views; onsite mobile + PWA + camera QR scanning; change-request flow UI; venue submission pack, contractor schedule, sponsor/cost/performance exports; iCal feed; workflow builder UI; email template editing; edition archive read-only enforcement; GDPR self-service; notification preference UI.

---

---

## Phase 0 — Foundations

**Goal:** a deployable skeleton with the full schema, security model, auth, seed data and CI — no product features yet.

### Milestone 0.A — Repo and tooling

- [ ] 0.1 Scaffold Next.js (latest stable, App Router) with TypeScript strict, Tailwind CSS, pnpm; add shadcn/ui, Inter via `next/font`, lucide-react
- [ ] 0.2 Tooling: ESLint + Prettier, Vitest, Playwright (config only), pino logger with request id; `pnpm typecheck | lint | test | test:e2e` scripts
- [ ] 0.3 Project docs: `.env.example` (every variable, one comment each), `README.md` (local setup, Supabase setup, migrations, seed, tests, deploy, cron), `DECISIONS.md`
- [ ] 0.4 App route skeleton per section 15 layout: `(auth)`, `(app)`, `(portal)`, `q/[ref]`, `api/cron/daily`, `api/ical/[token]` — empty pages only

### Milestone 0.B — Database

- [ ] 0.5 Drizzle + drizzle-kit set-up (`DATABASE_URL` pooled transaction mode, `DIRECT_DATABASE_URL` for migrations); Postgres enums for all statuses/kinds
- [ ] 0.6 Schema: tenancy and people (organisations, users, memberships, external_grants) + events and venues (events, venues, venue_rules, editions, edition_deadlines, edition_counters)
- [ ] 0.7 Schema: floorplans (halls, locations), third parties (suppliers, contractors, sponsors, sponsor_entitlements, exhibitors)
- [ ] 0.8 Schema: signage (item_types, signage_items, artwork_versions, artwork_annotations) and stands (stand_submissions)
- [ ] 0.9 Schema: documents, workflow engine (workflows, workflow_steps, approval_instances, reminder_log), collaboration (comments, comment_attachments, change_requests, snags, notifications, email_log, exports), audit_log
- [ ] 0.10 Constraints and indexes: every FK indexed, `(edition_id, status)` on signage_items and stand_submissions, unique refs, unique (exhibitor_id) submission, positive dimensions/quantities; first migration generated and applied
- [ ] 0.11 RLS enabled on every table, deny-by-default policies (service role only from the server); migration test that anon/authenticated roles are denied
- [ ] 0.12 Audit append-only trigger: raises on UPDATE or DELETE of `audit_log`; test proves it

### Milestone 0.C — Auth and authorisation

- [ ] 0.13 Supabase Auth wiring: staff password (dev) + magic link; external magic link only; `/auth/callback`; session verification helper for server actions
- [ ] 0.14 Invite flow: `/invite/[token]` — accept an external grant (token hash check, expiry, set name, land in portal); revocation and expiry cut access immediately
- [ ] 0.15 `lib/authz.ts`: `can(actor, action, resource)` covering the staff permission matrix (3.3) and external scoping rules (3.2) — **tests first**, one per matrix row including negatives
- [ ] 0.16 `lib/audit.ts`: audit row writer used inside the same transaction as every mutation; server action template established (zod → actor → authz → transaction+audit → revalidate → typed result)

### Milestone 0.D — Shell, seed, CI

- [ ] 0.17 App shell: left nav (staff), reduced nav (external), top bar with edition switcher, search and notifications bell placeholders; light theme, responsive
- [ ] 0.18 Seed script (`pnpm db:seed`, idempotent): organisation, staff users, external users + grants, event, venues, EXAMPLE venue rules, complex-structure triggers, edition BIRM27 with deadline offsets, halls + placeholder floorplans + 12 locations, item types, suppliers, contractors, sponsors + entitlements, default workflows (6.5)
- [ ] 0.19 Seed: 30 signage items across statuses (artwork PDFs generated, pending steps for every role, two overdue, one on hold, one rejected, one superseded approval) and 12 exhibitors with the specified submission spread
- [ ] 0.20 CI: GitHub Actions — typecheck, lint, unit tests, e2e against Supabase CLI local stack, dependency audit, on every PR

**Phase 0 acceptance** (section 13): `pnpm typecheck && pnpm lint && pnpm test` green; seed runs twice without error; all six staff users log in and see the correct navigation; external users get 403 on staff routes; the audit trigger rejects an UPDATE. **Stop and wait for confirmation.**

---

## Phase 1 — Signage schedule and sign-off

**Goal:** usable at the next show — the full signage lifecycle from creation to approval, with imports, exports and portals.

### Milestone 1.A — Editions and items

- [ ] 1.1 Editions: list, create; edition switcher wired to real data
- [ ] 1.2 Edition clone: halls, locations, deadline offsets, items as `draft` with artwork/approvals/actuals/PO cleared; exhibitors optional; new code and dates required
- [ ] 1.3 Settings: item types CRUD (defaults for workflow, fixing, venue approval)
- [ ] 1.4 `lib/refs.ts`: ref generation via `edition_counters` with `SELECT … FOR UPDATE`; concurrency unit test
- [ ] 1.5 Signage item CRUD server actions + Details tab form (sponsor and entitlement picker, flags; `requires_venue_approval` forced true when rigged); soft delete + restore in Settings
- [ ] 1.6 `lib/status/signage.ts`: pure transition function — **tests first**, table-driven, every legal transition passes and every other throws (incl. on_hold from any non-terminal, previous_status, reopen)

### Milestone 1.B — Artwork pipeline

- [ ] 1.7 `lib/storage.ts`: private buckets, path pattern, signed upload URLs issued by authorised server action, `finaliseUpload` with SHA-256 re-verification under 25 MB, 15-minute signed download URLs with audit
- [ ] 1.8 Artwork versions: upload UI with type/size limits, version numbering, browser-side SHA-256 (Web Crypto), upload retry on same signed URL
- [ ] 1.9 Previews: PNG of page 1 via `pdfjs-dist` + `sharp`; file-type icon fallback for AI/EPS/ZIP
- [ ] 1.10 Artwork tab: version list, proof status, invalidation warning dialog ("This will invalidate N approvals"), block upload after `installed` unless reopened
- [ ] 1.11 Version compare: side-by-side with slider overlay; annotation pins per version linked to comment threads

### Milestone 1.C — Workflow engine (`lib/workflow/`, tests first throughout)

- [ ] 1.12 Run creation: condition evaluation (all eight condition kinds), step snapshots, `skipped` instances, run_number increments
- [ ] 1.13 Activation: first non-skipped step/parallel group pending, `pending_since`/`due_at` (calendar days), group completion advances
- [ ] 1.14 Decisions: approve / approve_with_conditions / request_changes / reject / confirm; role and user assignment resolution incl. external scoping; admin override recorded; supplier-step fallback to ops with "No supplier set" flag
- [ ] 1.15 Optimistic locking: `expectedInstanceStatus` + `expectedLockedVersionId`, locked version + SHA-256 on every decision; concurrent-decision test (one success, one conflict)
- [ ] 1.16 Delegation: assignee or admin delegates to a named user, both notified, delegate decides as themselves
- [ ] 1.17 Changes-requested restart: `restart_from_here_on_changes` true (reset from that step) and false (new run); earlier approvals stand
- [ ] 1.18 Invalidation on new version: decided instances with `invalidate_on_new_version` → `invalidated`, fresh instances in position, notifications with compare link, greyed-out history display
- [ ] 1.19 Integration: submit-for-review action (required-field validation, `awaiting_artwork` vs `in_review`), resubmit, hold/resume with `due_at` shift, reopen rejected

### Milestone 1.D — Approvals UX and collaboration

- [ ] 1.20 Approvals tab: visual chain with status, assignee, due date, comments and conditions; decide buttons only for the current user's pending steps; delegate; previous-run history
- [ ] 1.21 `/approvals` My Sign-offs: cross-edition pending instances, sorted by due date, inline decisions, preview drawer with locked version, filters (edition, step, overdue)
- [ ] 1.22 Comments: markdown, threads, @mentions, attachments, internal/external flag, edit/delete; History tab from audit entries
- [ ] 1.23 Notifications: in-app bell + event-driven emails (react-email, brand name, one CTA deep link, plain-text fallback, batched mentions), retries with backoff into `email_log`, per-kind mute in profile

### Milestone 1.E — Views, dashboard, exports

- [ ] 1.24 Schedule table: TanStack grid, sticky header, column chooser, inline edit (per-field permission), multi-select bulk actions, grouping, saved views per user, search, `nuqs` URL-synced filters; virtualised, smooth at 1,500 rows
- [ ] 1.25 Kanban view: column per status; cards with ref, name, thumbnail, hall, next pending step + assignee, due date
- [ ] 1.26 Dashboard: status counts, sitting-with by department/external role, overdue click-through, next-7-days deadlines, budget vs estimate vs actual, most-overdue call-out (stand funnel arrives in Phase 2)
- [ ] 1.27 Excel import: template download, exceljs parse, shared zod validation, name resolution, preview with row errors, create-missing tick box, single-transaction commit, upsert by ref, one `import` audit row
- [ ] 1.28 Excel schedule export: current filters/grouping, styled header, frozen panes, status fills, sheet per hall + summary, approval status per step columns
- [ ] 1.29 Approval certificate PDF (`@react-pdf/renderer`): key fields, locked-version thumbnail, full chain with names/dates/versions/SHA-256 prefixes, conditions, QR to record
- [ ] 1.30 Spec labels: A6 PDF per item with QR to `/q/{ref}` (route resolves in Phase 2; label generation here)

### Milestone 1.F — Portals and e2e

- [ ] 1.31 Supplier portal (`/portal/items`): scoped items, spec fields, approved locked artwork only, delivery/install dates, PO; "Sent to print" and "Delivered" confirmations
- [ ] 1.32 Sponsor portal: scoped items, all artwork versions, sponsor approval step, external comments
- [ ] 1.33 Playwright: staff flow (create → upload → submit → marketing + ops approve → export); sponsored path with sales approval; invalidation and re-approval; supplier/sponsor scoping incl. 403/404 by URL

**Phase 1 acceptance** (section 13): staff e2e flow passes; every 5.1 and 6 rule unit-tested; invalidation exact and re-approval works; scoped externals get 403/404 by URL; 300-row import round-trips through export losslessly; concurrent decisions → one success, one conflict. **Stop and wait for confirmation.**

---

## Phase 2 — Stands, deadlines, venue, floorplan

### Milestone 2.A — Stand submissions

- [ ] 2.1 `lib/status/stand.ts` — **tests first**, table-driven as 1.6
- [ ] 2.2 Exhibitors admin table (`/[editionCode]/stands`): stand type, contractor, status, complexity flags, days to deadline, last chased, filters, bulk chase
- [ ] 2.3 Exhibitor portal (`/portal/submission`): structure questionnaire, `is_complex` computation (triggers + >4000 mm), document upload by type, submit (blocks on missing required docs / missing height), resubmit increments submission_version
- [ ] 2.4 Documents: required/received/accepted/rejected/expiry per type and submission_version; insurance expiry flag vs `build_end`
- [ ] 2.5 Rules checklist generated from venue_rules (stand/both, checklist items); tick with note, checked_by/at
- [ ] 2.6 Stand workflow wired to engine: engineer step only when complex, H&S, venue when `requires_stand_approval`; step 5 writes outcome + conditions; build check (notes mandatory when conditions exist)
- [ ] 2.7 Stand detail page: questionnaire, documents, checklist, chain, outcome, conditions, build check, comments

### Milestone 2.B — Deadlines and cron

- [ ] 2.8 `lib/deadlines.ts`: `effectiveDeadline`, `artworkDue`, `printDeadline`, `standDesignDue`, `insuranceDue` — pure, tested, overrides and hold shifting
- [ ] 2.9 Cron scaffold: `POST /api/cron/daily`, `CRON_SECRET` bearer check, Europe/London "today", each job a testable function taking `today`; `reminder_log` idempotency
- [ ] 2.10 Jobs 1–2: approval reminders (−7/−2/due/overdue, cap 10) and escalation (`escalate_after_days`, admins + owner, `escalated_at/to`)
- [ ] 2.11 Jobs 3–5: missing artwork, stand chasers (−14/−7/−2/due, weekly overdue, copy ops), document expiry
- [ ] 2.12 Job 6: daily digest to ops and admin; skipped when nothing changed and nothing overdue; Vercel Cron schedule config

### Milestone 2.C — Floorplans, views, exports

- [ ] 2.13 Floorplan admin: upload per hall (PDF → PNG render), place and drag locations (x/y as 0–1), assign items
- [ ] 2.14 Floorplan view: hall tabs, status-coloured pins with text, click popover; calendar view: install dates by day/slot grouped by contractor
- [ ] 2.15 `/q/[ref]`: resolve QR to item or submission after login, external scoping enforced
- [ ] 2.16 Exports: venue submission pack PDF (flagged items, floorplan crop, cover page); stand approval register (Excel + PDF); contractor and rigger schedule (Excel + PDF)
- [ ] 2.17 Playwright: cron idempotency via `email_log`; complex-vs-simple engineer step; venue scoping; blocked incomplete submission; insurance expiry flag

**Phase 2 acceptance** (section 13): cron sends exactly the expected emails once per day; complexity routing correct; venue user scoped; incomplete submissions blocked; expiry flag shows. **Stop and wait for confirmation.**

---

## Phase 3 — Onsite, reporting, admin

### Milestone 3.A — Onsite and PWA

- [ ] 3.1 Onsite mobile section: install checklist by hall/day, camera tick, installed confirmation with required photo (per org setting)
- [ ] 3.2 Snags: new snag (photo, item picker, severity, assign), list, resolve/won't-fix, status round-trip to `installed`
- [ ] 3.3 QR scanning: `@zxing/browser` camera scan + manual ref fallback; stand build checks onsite
- [ ] 3.4 PWA: manifest, service worker caching app shell only; browser photo downscale to 2000 px

### Milestone 3.B — Reports and admin

- [ ] 3.5 Reports page: sponsor deliverables, cost report, approval performance (Excel); generated-files list with expiry
- [ ] 3.6 iCal feed at tokenised URL, one event per item per install slot
- [ ] 3.7 Workflow builder UI: drag-to-order steps with kind, approver, conditions, SLA, invalidation; duplicate; archive
- [ ] 3.8 Email template editing (subject + intro editable, structure fixed); notification preferences UI
- [ ] 3.9 Edition archive (read-only), retention setting; GDPR export and deletion for externals from the portal

### Milestone 3.C — Polish

- [ ] 3.10 Dark mode polish; accessibility pass (keyboard grid/dialogs, focus, labels, colour-plus-text)
- [ ] 3.11 Error pages with reference ids; security headers, rate limiting on magic-link and invite endpoints
- [ ] 3.12 Full e2e suite on desktop and mobile viewports; Lighthouse a11y ≥ 90 on dashboard, schedule, item detail, onsite

**Phase 3 acceptance** (section 13): full e2e suite green on both viewports; Lighthouse accessibility ≥ 90 on the four named screens.

---

## Standing rules

- Tests first for the workflow engine, status machines and authz; tests alongside for everything else.
- Ask before: paid services, any change to the fixed stack, status machine or workflow rule changes, anything that deletes data.
- Everything else: decide the simplest testable option and log it in `DECISIONS.md`.
- No silent scope reduction — flag anything unachievable as written and propose the closest alternative.
