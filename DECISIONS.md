# Decisions

A one-line log of choices made where the build brief is silent, with the reason. Newest first.

| Date       | Decision                                                       | Reason                                                                                                                                                                                                                                           |
| ---------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-09-17 | Development sign-in (`DEV_AUTH=1`) assumes seeded users by cookie | Lets the platform be demonstrated with only a database. Superseded 2026-09-24: see "Demo sign-in safeguards" below — `DEV_AUTH=1` keeps it on even with Supabase configured, so it is now fenced to demo accounts and flagged on every page. |
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

## v1.5 restructure (2026-09-24)
At the owner's request the platform was reshaped for ops, sales and
marketing teams together. The load-bearing choices:

- **Sponsorship items share the signage register** (`signage_items.kind`
  discriminator) but get their own navigation section. Everything they need
  — sign-off runs, artwork versions, comments, audit, portal scoping —
  already hangs off that table; a parallel table would have duplicated all
  of it for identically-behaving records.
- **`kind` and `category` are separate columns.** `category`
  (directional / venue / sponsorship) classifies signage for filtering and
  sales visibility; `kind` separates the registers. One merged enum would
  make the schedule filter and the separate section fight each other.
- **Permissions are role defaults + per-user overrides**
  (`memberships.permission_overrides`, whitelisted keys in `lib/authz.ts`).
  Admins are immune, an explicit false always blocks, and an
  `approval.decide: true` override never bypasses step assignment —
  it can only remove the ability. `users.manage` is not overridable, so
  there is no privilege-escalation path.
- **Staff invites get their own table** (`staff_invites`): a membership row
  needs the auth uid, which doesn't exist until first sign-in, so the invite
  carries the role and overrides to apply when the email arrives.
- **"My Work" reuses the `/approvals` route** rather than a new one, keeping
  bookmarks, the portal twin and existing tests valid.
- **The bell polls a count endpoint** (30 s, paused when hidden) and calls
  `router.refresh()` on change; the dropdown stays server-rendered. No web
  push or service worker — deliberate, to avoid permission prompts.
- **Task audit rows use the text `entity_type` column** of `audit_log`;
  the `entity_type` pg enum was left untouched (task notifications simply
  leave their nullable entity fields empty), avoiding an ALTER TYPE with
  transaction-ordering constraints.

## Platform review (2026-09-24)

A full process and code review (126 confirmed findings → 75 fixes, shipped in
stages A–G). Owner decisions and the choices made along the way:

- **Sign-off completes on the last approval.** The workflow engine treats a
  run as approved once every *approval* step is settled; the confirmation
  steps (Sent to print, Delivered, Installed) then follow in order. Before
  this, real items stayed "in review" for ever.
- **Approved items can still be edited; spec changes restart sign-off.**
  Changing size, material, fixing, type or sponsor on a signed-off item
  reopens the approvals it affects (never silently); dates, supplier and
  costs change freely. Installed/closed items must be reopened first.
- **Stands are hidden for now** (`STANDS_ENABLED=1` brings them back). Nav,
  dashboard widgets, reports, calendar chips, deadlines, stand invite roles
  and the stand chasers are all switched off; routes and data are kept.
- **Demo sign-in safeguards.** While `DEV_AUTH=1`, every page shows a red
  "Demo sign-in is on" bar. Once Supabase Auth is configured, demo sign-in
  only works for the seeded `…@….test` accounts and invitees always get an
  email link. Go-live: invite yourself as admin → sign in by the emailed
  link → remove `DEV_AUTH` → redeploy.
- **Staff land on My Work**; admins see their own sign-offs there with an
  "All open sign-offs" switch. Partners land on their sign-offs.
- **Only admins choose who signs off**; viewers and people whose sign-off
  right is switched off can't be named and aren't sent sign-off requests.
- **Signage comments are staff-only**; partners see the item page (artwork,
  spec, label, their sign-off buttons) instead.
- **Item page has five tabs** — Details, Artwork & sign-off, Change requests,
  Comments, History — and old tab links still resolve.
- **Change requests are only for signed-off items**; before sign-off the item
  is edited directly.
- **Exports are generated on demand, not stored**; the exports table is the
  history. PDFs embed Noto Sans (OFL, in `lib/exports/fonts/`) so every name
  prints.
- **Install confirmation takes a real photo** (downscaled on the phone,
  stored in the private `photos` bucket, path checked on the server).
- **Artwork chasers**: 7 and 2 days before the due date, on the day, then
  weekly; one morning reminder per person for tasks due.
- **Seeded sponsorship items use refs 031/032** and "Other signage" / "Other
  sponsorship item" types exist so nothing is forced into a wrong type.
- **Vercel functions run in Frankfurt (fra1)**, next to the database.


## Signage rework (2026-09-25)

Owner brief: operations add print or digital signage and mark it organiser or
sponsor signage; sponsorship items show in the signage schedule with the
sponsor; sign-off by department and a named person, with email; shows with
logo and address; suppliers with the services they offer; admins manage every
pick-list.

- **Two categories: Organiser or Sponsor.** Directional/Venue became
  Organiser; Sponsorship became Sponsor (migration 0004). Sponsor signage
  needs a sponsor. Sponsorship-section items are always Sponsor.
- **One schedule.** The signage schedule, dashboard counts and Excel schedule
  include everything, sponsorship items too (with Category, Sponsor, Type,
  Format and Supplier columns). The Sponsorship page lists everything sold to
  sponsors. Install sheets stay signage-only (bags aren't installed).
- **Print or digital is a property of the signage type**, which admins and
  Operations manage in Settings → Signage types (types are hidden, never
  deleted, so old items keep theirs).
- **Sign-off is by department.** Workflow steps with `default_for` are
  "department" steps (Operations, Marketing, Sales, Senior management by
  default). Operations, Marketing and Sales review together, then Senior
  management. Admins set, per step, the department, a default person, and
  whether it's on by default for organiser and/or sponsor signage, and can
  add or remove departments (Settings → Sign-off). Each item stores its own
  choices in `signage_items.signoffs` (null = the defaults), editable by
  whoever can edit the item. Changing them on an item in or past review
  restarts sign-off, like a spec change. The chosen person (or everyone in
  the department) gets an in-app notice and email. Venue approval and the
  production confirmations still follow their conditions.
- **Decisions and comments are logged** in History in plain words
  ("Marketing sign-off: changes requested — “…”"); a comment box sits under
  the sign-off chain.
- **Shows** replace "Editions" in the UI (routes unchanged). New show creates
  the series and venue (with address) inline if needed; logos are resized to
  512px WebP in the documents bucket.
- **Suppliers** have their own page; what they do is a list of services
  admins manage (`supplier_services`, many-to-many). The old `supplier_kind`
  stays in the table but is no longer shown.
- **Emails** need `RESEND_API_KEY` and `EMAIL_FROM` set on Vercel; without
  them notices appear in the app only.

## Approvals and approvers (2026-09-25)

Owner brief: an Approvals section showing every piece of signage with a
graphic, approved by the relevant department and person; an Approvers area to
add department names and people (name, job title, email). Everyone needs an
account: invitations are emailed and the person sets up a profile with a
password. Each department has a main approver.

- **Departments are data, not roles.** `departments` (name, order, default
  for organiser/sponsor, "signs last") and `approvers` (department, name, job
  title, email, main, `user_id` once they have an account). Staff roles still
  decide what someone can do in the app; departments only decide sign-off.
  Migration 0005 turned the four department steps into departments and added
  team members in the matching role as approvers (Dana stays Senior
  management's main approver).
- **One sign-off step per department**, kept in step by
  `syncDepartmentSteps` after every change: named "<Department> sign-off",
  going to the main approver when they have an account (otherwise anyone in
  the department), archived with its department. Order: departments that
  sign together, venue approval, departments that sign last, then the
  confirmations. Sign-offs already under way keep what they started with.
- **Routing by department.** Instances carry `assigned_department_id`;
  anyone in the department may decide unless a person is named. A person's
  departments load with their session. A removed department's waiting
  sign-offs can still be decided.
- **Approvers without an account get a view-only invitation** (an admin can
  give them more in Team). Adding someone already on the team links them at
  once. When an invitation is accepted, matching approver entries link to
  the new account.
- **Accounts use passwords.** Accepting an invitation creates the Supabase
  login with the chosen password (service key, email confirmed by the
  invitation link) and signs the person in. If they already have a login
  they sign in first. Without a service key the old emailed sign-in link is
  used. Sign-in defaults to email and password with "Forgot password"
  (Supabase reset email → `/reset-password`).
- **My Work** keeps tasks and links to Approvals; staff land on My Work.
  Settings → Sign-off moved to Approvals → Approvers.
