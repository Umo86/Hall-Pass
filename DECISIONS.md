# Decisions

A one-line log of choices made where the build brief is silent, with the reason. Newest first.

| Date       | Decision                                                                                                                                                                                                                                                                                                                                                               | Reason                                                                                                                                                                                                                                           |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-09-17 | Development sign-in (`DEV_AUTH=1`) assumes seeded users by cookie                                                                                                                                                                                                                                                                                                      | Lets the platform be demonstrated with only a database. Superseded 2026-09-24: see "Demo sign-in safeguards" below — `DEV_AUTH=1` keeps it on even with Supabase configured, so it is now fenced to demo accounts and flagged on every page.     |
| 2026-09-17 | Storage falls back to the local filesystem when Supabase is unconfigured                                                                                                                                                                                                                                                                                               | Keeps uploads working in development/demo; production uses Supabase Storage private buckets with signed URLs. Vercel's filesystem is ephemeral, so demo uploads there do not persist across deploys.                                             |
| 2026-09-17 | Seeded artwork/documents are metadata-only (`seed/` paths, no real files)                                                                                                                                                                                                                                                                                              | Real files need object storage; hashes and versions still exercise the whole approval flow.                                                                                                                                                      |
| 2026-09-17 | Default-workflow confirmation names drive item status (Sent to print → in_production, etc.)                                                                                                                                                                                                                                                                            | Simplest testable mapping; custom workflows that rename confirmations record decisions without moving item status.                                                                                                                               |
| 2026-09-17 | `locked_version_id` stored as text                                                                                                                                                                                                                                                                                                                                     | It holds either an artwork version uuid or a stand submission version number.                                                                                                                                                                    |
| 2026-09-17 | Excel import commits only when every row validates; the error list is the preview                                                                                                                                                                                                                                                                                      | One transaction, no partial imports; matches "commit in one transaction" with a simpler flow than a separate preview step.                                                                                                                       |
| 2026-09-17 | Grants are claimed by invited email on first Supabase sign-in                                                                                                                                                                                                                                                                                                          | Avoids fragile uid pre-linking; the invite link flow still validates the hashed token.                                                                                                                                                           |
| 2026-09-17 | TanStack Table pinned to v8                                                                                                                                                                                                                                                                                                                                            | v9 shipped mid-build with a breaking typed API.                                                                                                                                                                                                  |
| 2026-09-17 | Deferred from v1 (flagged, not silent): inline grid editing, saved views, floorplan and calendar views, artwork previews/compare/annotations, onsite mobile section and PWA, QR camera scanning, change-request UI, venue pack / contractor schedule / sponsor / cost / performance exports, iCal feed, workflow builder UI, email template editing, GDPR self-service | Section 14.10: scope not reduced silently — each is listed in PLAN.md as remaining work with the engine-level support already in place.                                                                                                          |
| 2026-09-17 | App shell (tasks 0.1–0.4, 0.17-lite) pushed straight to `main`                                                                                                                                                                                                                                                                                                         | The owner asked for a first Vercel deployment; production tracks `main` and the repository is not yet connected to Vercel, so a pull request had nothing to preview against. Later phase work goes through branches and pull requests.           |
| 2026-09-17 | shadcn/ui components vendored by hand (registry blocked)                                                                                                                                                                                                                                                                                                               | The build environment's egress proxy denies ui.shadcn.com, so `components.json`, the theme tokens and the base components were written manually from the standard shadcn sources; behaviourally identical, future components added the same way. |
| 2026-09-17 | Cron endpoint accepts GET and POST                                                                                                                                                                                                                                                                                                                                     | Vercel Cron invokes with GET while the brief specifies POST; both are served by the same handler behind the same `CRON_SECRET` bearer check.                                                                                                     |
| 2026-09-17 | Initial planning docs pushed straight to `main`                                                                                                                                                                                                                                                                                                                        | The repository was empty with no default branch yet.                                                                                                                                                                                             |

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
  run as approved once every _approval_ step is settled; the confirmation
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
- **Item page has four tabs** — Details, Artwork & sign-off, Comments, History
  (stand designs add Panels) — and old tab links still resolve.
- **There is no separate change-request flow**: editing a signed-off item is
  the one way to change it, and saving a change to its spec or approvers
  restarts sign-off (never silently). Installed items stay locked until an
  admin or operations user reopens them.
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

## Sponsorship cards and field review (2026-09-25)

Owner brief: sponsorship items as cards with photo, cost price, order-by
deadline and supplier; a day-and-month countdown with a warning under a month
to sell; sale price once sold; sponsors managed in a sub-section; fewer, more
useful fields for every item.

- **One date: order by** (`signage_items.order_by_date`) — the last day to
  order from the supplier, and so to sell it. `lib/countdown.ts` gives
  "2 months 5 days left"; unsold items under a calendar month away (or past)
  get "Less than 1 month to sell" / "Order date has passed". Sold items near
  the date turn amber (ops still need to order).
- **Sold = has a sponsor.** Sponsorship items can exist unsold. "Mark as
  sold" sets the sponsor (optionally creating one), `sale_price` and
  `sold_at`; "Undo sale" clears them. Sponsor signage is always sold. A first
  sale after sign-off doesn't restart sign-off; changing sponsor does.
  Migration 0006 marked everything that already had a sponsor as sold.
- **Product photo** (`photo_path`, photos bucket, 1000px WebP) on the card and
  item page; cards fall back to the artwork preview.
- **Prices are visible to everyone on the team** (owner's choice). Editing
  cost stays with admins/Operations for signage; whoever runs a sponsorship
  item can set its supplier and cost; Sales, Operations and admins record
  sales.
- **Fields:** forms show the essentials per kind; the rest (notes, depth,
  sided, weight, material, finish, entitlement, actual cost, PO, budget line,
  artwork-due override, print deadline, delivery, install slot/contractor,
  owner, workflow) moved into a closed "More details" section that opens
  itself when one of its fields has an error. Nothing was removed from the
  database or exports. The schedule hides Format by default and calls the
  estimate "Cost price". The sponsor report adds Order by, Cost, Sale, Profit
  and a "Still to sell" sheet.

## Invite-only access, task board, calendar, security review (2026-09-25)

- **No sign-up.** Only people with a team membership, an open staff
  invitation or a live partner invitation can get in. Invitations go out
  through Supabase (`auth.admin.inviteUserByEmail`, redirect `/auth/accept`):
  the link works only from the invitee's inbox; there they choose their name
  and password (`completeAccount`) and the invitation is applied. Existing
  accounts get a sign-in link instead. If Supabase can't send, our own email
  with the invitation link; failing that the admin sees the link to pass on.
  "Email me a link" and "Forgot password" only email invited people and give
  the same reply either way. Password sign-in also checks the person still
  has access. Supabase's own sign-up is never called (`shouldCreateUser`
  only when no service key exists, and only for invited emails).
- **Demo sign-in is off on any Vercel deployment with Supabase configured**,
  whatever `DEV_AUTH` says; it remains for local development and tests.
- **Tenancy.** A security review found that records were looked up by id,
  ref or show code without checking the organisation, and `can()` never
  compared organisations. Now: records carry their organisation (from the
  show's event); `can()` refuses any record from another organisation
  (admins included); `getEditionByCode`, `loadItemBundle` and
  `loadStandBundle` take the caller's organisation; item pages also check
  the show in the address; every id linked to an item (type, hall, location,
  sponsor, entitlement, supplier, contractor, workflow) is checked against
  the organisation/show (`assertItemLinks`); import and clone check the show;
  replies must belong to the same record; revoked or expired partner
  invitations show nothing. No raw SQL, `dangerouslySetInnerHTML` or `eval`
  anywhere; local file paths can't escape the store; CSP adds
  `object-src 'none'`, `base-uri` and `form-action`, plus a Permissions-Policy.
- **Task board.** `task_status` gains `in_progress`; subtasks are tasks with
  `parent_task_id`; `task_attachments` (documents bucket, 20 MB, documents,
  images, Office, ZIP — nothing that runs in a browser) served through
  `/api/task-files/[id]` only to people working on the task. Anyone working
  on a task can manage its subtasks; only the creator or an admin deletes a
  whole task. Completed tasks leave the board after 30 days.
- **Calendar.** Deadlines of every kind are red (dark red with ⚠ once
  passed); show dates violet, deliveries blue, installs green.
- **Suppliers.** New "what they do" entries typed in the supplier popup join
  the shared list (or tick an existing match).

## Users, sections and the guided start (Oct 2026)

- **Words.** The dated occurrence (`editions`) is an **Event** everywhere in
  the UI; the recurring brand (`events`) is an **Event series**. Code and
  table names stay. The list moved from `/editions` to `/events` (old link
  redirects). Stand designs are shown as **Feature stands** and exhibitor
  stand approvals as **Exhibitor stands**.
- **One department per person.** `memberships.department_id` uses the
  existing `departments` table. A department now has `signs_off`: off means
  it is a team for grouping people only and has no sign-off step (handled in
  `syncDepartmentSteps`, like an archived department). Which departments a
  person signs off for is still the `approvers` table (`signoffDepartmentIds`
  on the actor, renamed from `departmentIds` so the two can't be confused).
  The migration gives existing approvers of exactly one live department that
  department; everyone else starts with none. Nobody's access changes.
- **Sections (features).** `memberships.features` lists the app sections a
  person can use (`FEATURES` in `lib/authz.ts`); null means every section,
  which is what everyone had before. `can()` refuses actions in a switched-off
  section before overrides are looked at, so a granted ability can't reopen a
  section; admins are never limited; viewing one record, deciding a sign-off
  assigned to you, tasks and comments are never gated, so emailed links and
  sign-offs keep working; anyone who signs off for a department always has
  Approvals. Section pages show "isn't switched on for you" rather than 404.
- **Invitations** carry name, job title, department and sections and expire
  after 14 days (`STAFF_INVITE_DAYS`); older invitations without a date never
  expire. Accepting copies department, sections and job title onto the
  membership.
- **New organisations** get the signage workflow (venue approval and the
  print/delivery/install confirmations; department sign-offs come from the
  departments) through `ensureSignageWorkflow`; before this, an organisation
  set up without the demo seed could never send a sign for sign-off.
- **Personal settings** moved to My account (`/account`, from the account
  menu); `?tab=general` redirects there.
- **Feedback** uses toasts (sonner) and `useConfirm()` instead of
  `window.confirm`; pages share `PageHeader`, `EmptyState` and
  `SegmentedLinks`.
- **Users list.** With email set up, invited rows offer Resend; without, Copy
  link. Both make a new link (links are stored only as hashes). An open
  invitation is edited on the same /users/[id] page, by invitation id.
- **Sections in forms.** "All sections" is stored as null, and so is ticking
  every visible section. Abilities in a switched-off section are hidden but
  keep their stored value. `approval.decide` is no longer a checkbox; a
  stored false shows as "Sign-off paused" with Resume.
- **New departments** start without sign-off (from Add user or from
  Departments), so a new team never silently joins every sign-off.
- **Removing people.** Removing the main approver promotes nobody: the
  department step goes to everyone left in the department. Sign-offs waiting
  on the person must be handed to someone (not a viewer); their tasks and
  items move to the admin removing them.
- **Who can be invited.** Staff invitations refuse emails with live portal
  access or a membership elsewhere; partner invitations refuse team members'
  emails. Joining links approver entries by email within that organisation
  only. Expired staff invitations can't be accepted or claimed.
- **Event setup.** Six essentials count towards progress: dates, halls,
  deadlines, who signs off, sign types and first signs. People is
  recommended; suppliers and sponsorship are optional. "Who signs off" is
  done when the signage workflow exists, at least one department signs off,
  and every department that signs organiser signage has someone with an
  account who can sign; it is "waiting" while they are only invited.
  Progress shows only for events still to come. Events that existed before
  this change show dates and deadlines as to do once, until confirmed.
- **Default event** (pages without one in the address): the hp-last-event
  cookie, else the earliest event that hasn't closed, else the most recent
  past one, never an archived one while a live one exists.
- **Event phase** is worked out from the dates (Planning, Build-up, Open,
  Breakdown, Finished; Archived stays). The stored status is no longer
  edited in the UI; an event restored from archive becomes Planning, or
  Closed if finished.
- **Copying an event** copies portal access only when an admin copies it:
  venue access only at the same venue, supplier access for non-archived
  suppliers, engineer and H&S access always, sponsor and exhibitor access
  never. Choosing another venue unticks Halls & locations.
- **New event series.** Left on Automatic, a new event joins the series whose
  name equals the event name without its year, or a new one is created.
- **Halls.** Removing a hall also removes its unused locations after a
  confirm; it is refused while any sign, live or deleted, uses them.
- **Signage rules live on the server.** Stages, chips, Mine, overdue, the
  readiness checklist, next step, stepper, bulk skip reasons, spec lock and the
  stale-confirmation filter are in `lib/domain/signage.ts` (it imports the
  schema, so it can't be bundled for the browser) and reach pages as data.
- **Signage chips.** "Needs artwork" is a draft or needs-artwork item with no
  artwork; "Not sent yet" catches drafts that have artwork, so every row is in
  a chip. Empty chips are hidden except All, Mine and the active one.
- **Mine** is: I own it, or a waiting step names me, my sign-off department or
  my role (Operations also count supplier confirmations). An admin's power to
  decide anything doesn't make every row theirs. `stepIsMine` also chooses
  "Your decision" and the dashboard's "Sign-offs waiting on you"; a paused
  sign-off counts as none.
- **Stale confirmations.** A confirmation left pending after its item moved
  past it (older data) isn't shown as what the item waits on (`stepStillDue`);
  the status machine and the instances are unchanged.
- **Upload and send.** "Send for sign-off after upload" is ticked by default
  for ready drafts and changes requested, needs signage.submit as well as
  artwork.upload, and runs in a savepoint so a refusal keeps the upload.
- **Sending back.** Sending back without new artwork asks first, checked on the
  server (`resubmitItem`). `resubmitItemInTx` does the work for the item page,
  upload-and-send and now `resubmitSignageItem` too, so there is one copy.
- **Item page.** The header holds only More; the stage's main action is only in
  the next-step card. Read-only "At a glance" details for every kind (stand
  designs keep their form); a sticky Save bar only while editing. Recently
  deleted lists every kind for the event, for people who can restore.
  List dates show day and month (full date on hover); Stand no. is optional.
- **Bulk confirmations** call `decideApproval` per item or step, so authz, audit
  and status effects stay in one place; skip reasons (e.g. needs a photo) are
  checked first and named.
- **Remind** is its own permission, `approval.remind`: admins and Operations
  always; otherwise whoever could send that item for sign-off (signage.submit)
  or review that stand (stand.review); never portal users; in the item's
  section like signage.submit. Deciding a step doesn't make you its chaser.
  Once a day per step (reminder log), audited as `escalate`.
- **Settling requests.** `settleApprovalNotifications` marks "Please sign off",
  reminders and delegations read for everyone except holders of a step that
  was already running, before the people whose turn starts are told; the daily
  job settles against every open step. The bell shows a request as Done
  (muted, under Earlier) when the viewer holds no pending step on that record.
- **Overdue digest.** One message a day per person, only when one of their
  steps was logged that day (no per-step cap; mutable). Due dates are read as
  London dates. The daily digest loads open sign-offs once.
- **Everyone's sign-offs** is for admins and Operations; your own steps show
  Decide; groups are by the waiting-on name, so a department's sign-offs and
  its role's confirmations share a group. `?who=` takes one or more group keys
  (`user:<id>`, `dept:<id>`, `role:<role>`, comma-separated); the dashboard's
  "Sitting with" lines carry the keys behind each name.
- **Overdue artwork.** `?tab=artwork&overdue=1` lists artwork whose sign-off in
  the current round is past due (print, delivery and install confirmations are
  not sign-offs), most overdue first; the status filter and search still
  apply. The dashboard's overdue link uses it for people without the team view.
- **Words.** Toasts name the item, not its ref (toasts are list items and specs
  find rows by ref). "Notifications" stays the noun for the bell and page.
  Step states have one set of words, `stepStatusLabel` in `lib/format.ts`;
  `stepStateLabel` re-exports it. "Show" left messages ("Event not found").
- **Sponsorship stages** are a reading of the status machine plus sponsor and
  artwork; no transitions changed. On hold reads as the stage it was held at;
  unsold drafts are For sale; an unsold item further along keeps its next step
  with Mark as sold beside it. "Overdue to order" is past order-by and not
  ordered, sold or not; "Under a month" is not ordered with under a month to
  go; `?filter=urgent` is both. Sold leaves out "In package" sponsor signage.
  The dashboard card uses the same functions, so its numbers match.
- **Phones.** Sponsorship opens as a list on phones unless `?view=` is set;
  both layouts render and CSS picks, so nothing flashes.
- **Undo Mark complete** (`undoMarkComplete`) chains the existing reopen
  (closed → delivered) and installed steps in one transaction, keeps the
  install date and photo, and needs signage.close and signage.reopen.
- **Damage at delivery** doesn't change the item's status; installing with an
  open snag still makes it Snagged. Snags can be open at Delivered.
- **Panels follow their stand.** Hall, location and stand no. go to every panel
  not yet installed; category, sponsor and sign-off plan only to panels still
  in draft, so nothing in sign-off restarts. If the panel update fails the
  stand is still saved and the message says so. The slim panel form has an
  install date (Onsite's Today needs one).
- **Removing a sponsor or entitlement** is a hard delete, offered only when
  nothing points at it (items, deleted items, live portal access), after a
  confirm; the audit row keeps the full record.
- **Onsite** uses its own full-width 44px confirm button on the shared
  decision dialog; the stand's "Your decision" uses DecideButtons against the
  submission version; snag dialogs keep "Resolved" on the item page and say
  "Fixed" on Onsite.
- **Dashboard links.** Artwork-due and print-deadline links use the Signage
  chips (`?show=needs_artwork`, `?show=ready_to_print`), which count the work
  left. Onsite counts only what Onsite lists. A link to a section the person
  doesn't have is plain text. The budget forecast is the larger of estimate
  and actual (noted when it is actuals). Pure rules sit in
  `components/dashboard/rules.ts`, `components/reports/report-rules.ts` and
  `lib/calendar.ts`.
- **Calendar.** Item deadlines show only while their work is open, so the
  Overdue strip is the real backlog; the event's own passed deadlines stay on
  their day but out of the strip.
- **Reports and import.** Download buttons' accessible names start with their
  visible text. Import from the dashboard and Setup opens the Signage import
  sheet; the dry run is a flag on the same action (same authz and lock).
- **Settings** has five sections, each its own route (Organisation, Item types,
  Venues, Recycle bin, System); old `?tab=` links redirect.
- **Codes.** Venue and event series codes are made from the name on the server.
- **Suppliers.** A supplier can be deleted only when nothing live or deleted
  refers to it; otherwise it is archived. Archived suppliers are left out of
  the item form, new-item and bulk "Set supplier" pickers, and choosing one
  anew is refused in plain words; an item keeps the archived supplier it
  already has (shown "(archived)"). An edit form that doesn't name the item's
  supplier keeps archived suppliers still used on that event.
- **Portal access on suppliers and venues** is read-only for Operations; only
  admins invite or revoke.
- **Archived suppliers are refused in one place.** `assertItemLinks` refuses
  an archived supplier unless it is the item's current one
  (`currentSupplierId`), so new panels and every later caller get the rule;
  the import refuses one for a new row or a row whose item doesn't already
  have it, and a live supplier wins over an archived one of the same name.
  A `?supplier=` link to an archived supplier is named from its rows.
- **Venues.** Archived venues are left out of the create-event and event
  details pickers; the event's own venue stays in its details. Creating an
  event at one, or moving an event (or a copy) to one, is refused on the
  server too; a copy may keep its source's venue.
- **Reports** is left out of the navigation when the person can download no
  report.
- **Partner invitations** are for admins (`users.manage`). Someone else who
  follows a link to Users → External lands on Team (`/users?from=external`)
  with a note naming the admins to ask. Operations told that a supplier has
  no portal access are pointed at the item to confirm it themselves, or to
  ask an admin to invite the supplier.
- **Overdue on the dashboard** counts what its link lists: every overdue step
  in the team view, else overdue artwork sign-offs, one per item
  (`overdueArtworkSignoffs`).
- **Demo sign-in** lists accounts oldest first, so the seeded ones stay on the
  list however many people test runs add.
- **Demo seed.** An approved round carries on into its confirmations, so signs
  the demo puts at Sent to print or later have those steps confirmed. Re-seeding
  confirms them on demo items still as seeded (same status, first round) and
  leaves anything that has moved since alone.

## Users v2 core: abilities, managers, account access (Oct 2026)

- **One abilities registry.** `ABILITIES` in `lib/authz.ts` lists every ability a
  person can be given or refused (23 keys, grouped as the person form shows
  them) with its role defaults; `OVERRIDE_KEYS`/`OVERRIDE_ROLE_DEFAULTS` and the
  second table in `lib/users/rules.ts` are gone (a deprecated `OVERRIDE_KEYS`
  alias stays for the v1 tests). can() runs tenancy → partners → sections →
  abilities → the role, item or step rule. A stored false always blocks; a
  stored true grants a "grant" ability and only switches on a "gate" one
  (sign-off, delegation, bulk), so the step or item rule still applies.
- **Frozen behaviour.** `tests/unit/fixtures/authz-v1-snapshot.json` records
  can() before the registry (91 actors × 153 actions plus cost-on-item cases);
  the new can() must give the same answers. The one deliberate change: a stored
  `costs.edit: false` now also stops costs, PO and supplier on sponsorship items
  the person can edit (before, the item action let them through).
- **No data rewrite.** The six setup abilities (events.create, events.edit,
  halls.manage, suppliers.manage, lists.manage, organisation.manage) read a
  stored `settings.manage` when nothing newer is stored; `sponsorship.sell`
  reads `sponsorship.create`; `signage.bulk` follows `signage.create`
  (granted ones included). Saving a person writes only the new keys and drops
  `settings.manage`. `{type: "settings.manage"}` is now "any of the six" and
  `{type: "event.setup"}` is dates, halls, lists or suppliers (nav, Setup,
  dashboard).
- **Super admin only, never stored:** `users.manage` (grant super admin or
  manager, remove people), `system.manage` (storage, email, calendar feeds) and
  `events.archive`. Partner invitations (`partners.invite`) and departments
  (`departments.manage`) are abilities that default to super admins, and only
  a super admin can give them (also `organisation.manage`).
- **Settings sections** open by their ability: Organisation →
  organisation.manage, Item types and Venues → lists.manage, Recycle bin →
  signage.delete (restore needs it anyway), System → system.manage. Each setup
  step uses its own ability (`setupPermissionsFor`); on an archived event only
  People and Who signs off stay open.
- **Confirm print, delivery and install** (`signage.confirm`, Operations by
  default) is decided in one place: steps with no named person assigned to the
  supplier or to Operations. `confirmsForSuppliers()` feeds Approvals, Mine and
  notifications, so whoever holds the ability is asked and nobody else; a
  paused sign-off counts as none. Admins can confirm anything but aren't asked.
- **Chase overdue sign-offs** (`approval.chase`) is the team view on Approvals,
  My Work and the dashboard and the Remind button (approval.remind reads it:
  Operations and admins any, others where they could send it for sign-off).
  My Work's Everyone's tasks are for super admins.
- **Import and bulk.** Import needs "Add signage" and "Import from Excel and bulk
  actions"; creating halls and locations needs halls.manage, suppliers
  suppliers.manage (otherwise the row says Unknown hall/supplier); an update by
  ref needs signage.edit on that item, and its supplier and cost columns are
  ignored without costs.edit on it. Bulk checks signage.bulk on the server and
  "Set supplier" checks costs per item.
- **Copying an event** copies each part only for someone who could make it:
  items by kind, sponsors with sponsorship.sell, partner access with
  partners.invite. Directory entries check their own ability (event series →
  events.create, venues → lists.manage, suppliers and contractors →
  suppliers.manage); "Manage what they do" on Suppliers is lists.manage.
- **Prices.** Sponsorship prices, profit tiles, sponsor spend and the
  dashboard's sales figure need costs.view; selling requires it too.
- **Managers** are `memberships.manager_scope` ('department' | 'everyone',
  null otherwise; a database check keeps it null for super admins), carried on
  invitations and copied when one is accepted — not an override, so nothing a
  manager submits can write it. Managers add and change people in their scope
  (never themselves, super admins or other managers; a department manager with
  no department manages nobody), give only roles, sections and abilities they
  fully have themselves (role powers that aren't abilities — editing, artwork,
  stand reviews — count too), sign-off only for departments they sign off for
  and never the main approver without departments.manage, and can't remove
  anyone. The rules are pure (`personChangeRefusal` and friends in
  lib/authz.ts) and checked in the transaction after the person is loaded, with
  the actor's own access read fresh there.
- **Suspension and access end dates.** `suspended_at`/`suspended_by` and
  `access_ends_at` on memberships (end dates entered as a London date mean the
  end of that day). Only active people sign in (a blocked person is turned away
  before any partner invitation is claimed, and /login says "Your access is
  paused / has ended — ask {name}"), get the iCal feed, pass emailIsInvited,
  are told anything (notify() and email dispatch drop everyone without an
  active membership or a live partner grant), are offered in pickers or count
  as signers. Suspending hands sign-offs waiting on them by name to someone who
  can sign and keeps approver rows, tasks and items; reactivating restores it
  all. The daily job records "Access ended" once, re-routes department steps,
  tells super admins and the person's managers about sign-offs still waiting on
  them, and warns them a week ahead.
- **Who can be handed a sign-off** (`canReceiveSignoff`): active, not a viewer
  (as before), sign-off not paused. Used for delegation, hand-over on removal
  or suspension, and adding an approver from Departments. Main approver routing
  skips anyone who can't sign now, so the step goes to the whole department.
- **One main approver per department** is a unique index; saves clear the
  other main first (the migration kept the oldest where there were two).
- **Last super admin.** Demoting, suspending, ending or removing counts only
  super admins with access, under a row lock. (Tightened by the release
  review: the other super admin must have no end date — see "Release review
  fixes" below.)
- **Access history.** `audit_log.subject_user_id`/`subject_email` name the
  person a people change is about (also sign-ins, written on password sign-in
  and the email-link callback); `accessHistory()` finds those and older rows by
  membership, invitation, approver and user. Saves that change nothing no
  longer log "overrides changed". `users.last_seen_at` is written at most every
  15 minutes after a signed-in page load (not from the iCal feed).
- **Snags** record who raised them (`snags.raised_by_user_id`, backfilled from
  the audit log where it says).
- **Words.** The admin role is shown as "Super admin" ("Everything, including
  people, managers and system settings"). Refusals for a missing ability name
  it: "You need “Manage suppliers” for that — ask a super admin".

## Users v2: abilities and managers (Oct 2026)

Only what the core section above doesn't already say.

- **Roles a manager can give** (`assignableRoles`) ignore abilities only a
  super admin gives and hidden keys; those are switched off for the new
  person instead of refusing the role.
- **End dates** must be today or later (a London date, stored as the end of
  that day, worked out on the wall clock so BST and GMT are both right).
- **A paused person can still delegate** a step to someone else, exactly as
  before the registry.
- **The daily job** runs `endExpiredAccess` first; the reminder log gained
  the `membership` target for the week-before warning.
- **Import refusal** stays "You cannot import items" (tests rely on it);
  other missing abilities use `missingAbilityMessage`.
- **Viewers never sign off** now (see the next section), which replaces the
  core note that invitations still allowed viewer approver rows.
- **`snag.manage` is not gated by the Onsite section.** Mapping it to
  "onsite" in `featureForAction` changes seven answers in the frozen v1
  snapshot (Operations and Marketing with only other sections), so it stays
  as it was; the Onsite page itself is behind the section.

## Users v2: pages and hand-over (Oct 2026)

- **Viewers can't sign off** (`canReceiveSignoff`): inviting, changing a
  person or an invitation refuses sign-off rows for a viewer ("Viewers can't
  sign off artwork — choose another role or untick sign-off"); the person
  page clears them on save and says so; Departments shows older ones as
  "Viewer — can't sign off".
- **An invitation never takes "main approver"** from a main who can sign:
  `setSignoffs` keeps the current main and says "{X} stays main approver
  until {name} has accepted"; `setMainApprover` refuses invitee rows the same
  way. **Known limitation:** nothing promotes the invitee when they accept —
  make them main under Departments then (the Add form says so). Doing it
  automatically needs a column (e.g. `approvers.main_on_accept`) plus claim
  code; not added in this release.
- **Hand-over is per department.** Each department's default is its main
  approver, else another approver who can sign; "Everyone who signs off for
  X" is offered only when someone else can sign. Steps outside a department,
  or in one with nobody else, need a person picked. An older single
  `handToUserId` still works as the fallback for every group. These selects
  keep their own department-first layout; the removal "hand their work to"
  picker is the one person picker (PersonPicker: you first, then your
  department).
- **What moves (P2.0):** in each item's current round, pending, waiting and
  changes-requested steps naming the person (pending ones by delegation), and
  approved or confirmed steps that redo on new artwork (who decided stays).
  Item plans naming them are cleared on suspend, remove and stop-signing and
  are not restored on reactivation.
- **Stopping signing** (taken off a department, moved, made a viewer, paused
  — `stopSigningTx`) sends named sign-offs back to the department only where
  someone else can sign; otherwise they stay named and the toast and audit
  say so. The daily job does the same when an access end date passes
  (audited as the cron, no actor), then tells super admins and managers only
  about what still waits on the person.
- **Removal:** the person picked must have access and not be a viewer; only
  items not deleted or complete in planning or live events move (finished
  items and archived events keep the leaver); kinds the picked person can't
  work on go to the remover; one audit row per task and item. Removal and the
  person page count the same items. Its notice stays its own ("Fred left the
  team; Alex gave you the items they owned", to My Work) rather than
  `notifyOwnerChange`, because a leaver's items can span events. "Can work
  on" here is still `canWorkOwnItem` (edit or upload, by kind), not the
  owner rule in `lib/people.ts` (edit, upload and send, sponsored or not);
  moving removal onto `peopleFor({ type: "owner" })` is left for later.
- **Suspension keeps tasks and items**; only sign-offs are handed over. Bulk
  Suspend uses each department's default and leaves out anyone without one,
  with the reason.
- **Sign-off on Add and the person page** offers all departments with
  departments.manage, else the manager's own sign-off departments; main
  approver needs departments.manage.
- **Templates and role changes** by anyone who isn't a super admin switch off
  abilities only a super admin gives that the role has by default
  (`startingChoices`), instead of refusing the role.
- **Order of refusals:** suspend, reactivate and end date check scope before
  "last super admin", so someone out of scope only hears "You can't change
  this person's access".
- **Open invitations aren't replaced:** inviting an email with one open is
  refused with a link to their page.
- **Status filter:** Active includes people whose end date is still ahead;
  "Access ends" is its own filter and colour. "Last active" counts London
  days (year shown when not this year). Stale = 30 days or more, or never
  signed in (members only).
- **Add several:** tabs, else commas with quotes; an optional header sets the
  column order; otherwise the field with an @ is the email and a line with
  none reads Name, Email, Job title. Repeats are matched by lower-cased email;
  a missing name is made from the email. `bulkPeople` lives in
  `lib/users/manage.ts` so its checks are DB-tested.
- **Turned away at sign-in** (suspended or ended): /login names who to ask
  with their email as a mailto link (`AccessBlock.askEmail`); "a super admin"
  when there is nobody. With no contacts to name, setup and Users notes say
  "Ask a super admin".

## Users v2: who work goes to (Oct 2026)

- **Giving an item to someone** needs only the right to edit it, and the new
  owner must be able to own that kind of item: an active member who could
  edit it, upload its artwork and send it for sign-off as its owner (checked
  through can(), sections included — "No longer has Signage"). No separate
  item.assign ability.
- **Sign-off routing follows departments.** Plans can't tell "chosen" from
  "pre-filled", so they are never rewritten. Items with no stored plan follow
  the department's current main approver (or anyone in it); items with a plan
  keep the named person until they can no longer sign for the department.
  Delegated or handed-over steps stay with the delegate while they can sign
  at all, and steps handed back to the whole department stay there. A step
  never moves to a department nobody can sign for: it stays named so it can
  be handed on. `syncDepartmentSteps` now ends with
  `rerouteDepartmentSignoffs`, so every approver, department, suspension,
  pause or end-date change applies the rule; a round that starts or restarts
  applies it too. Hand-overs (`stopSigningTx`, suspension, removal) run
  before the re-sync, so their own messages and audit rows are the ones
  people get. (Not done: an engine-level check when a later step turns
  pending; the daily job and round start cover the gap.)
- **A routing move** is audited as "delegate", actor system, about the person
  it moved from; the new holder is asked to sign off and the old request is
  settled.
- **Snags** are always with the item's owner, read live
  (`snags.assigned_user_id` is no longer written or read). A closed snag
  tells whoever raised it and the owner, never the person who closed it.
- **Panels** are owned by their stand's owner whatever their status; bulk
  Change owner refuses panels ("a panel goes with its stand").
- **New-item notices** go to active people in the owner's department who use
  the item's section, never the creator or the owner (who gets
  `item_assigned`); the old Operations/Marketing (+ Sales for sponsor items)
  rule is the fallback when the owner has no department.
- **`item_assigned`** ("An item is given to me") can be switched off under
  Items on My account and is emailed. It goes to the new owner unless they
  made the change, and to the previous owner unless they did; one message
  per change.
- **Import "Owner email"** (or "Owner") is a template column with the hint
  "Email of an active team member; blank = you"; older sheets without it
  read no fallback column. A new row is owned by the person named when they
  can own it, otherwise by the importer; an update changes the owner only to
  someone who can. The check lists how many rows went each way and why.
- **Deciding on someone's behalf** names the step's person (or its only
  holder) as the subject; with several possible holders it lists them all.
- **"Approved but no supplier"** goes to people who can set the supplier
  (costs.edit with Signage, active, not super admins).
- **Nobody can sign in for a step:** a supplier confirmation tells the
  production confirmers; a venue or sponsor sign-off tells active Operations
  and the item owner. Partner inviters get the invite link, others are told
  who can invite, and an unaccepted invitation is named.
- **The task reminder** counts what My Work counts (`dueTaskCounts`).
- **Pickers list people in a stable order** (`loadTeam` sorts by name), so
  "ask A or B" reads the same every time.

## Partners (Users v2) (Oct 2026)

- **Staff means an active team membership**, never `users.is_external`:
  staff-only comment recipients, email links (portal links for anyone
  without a membership) and the overdue digest decide by membership. Claiming
  a partner invitation marks the account external (audited) and it
  self-heals at each sign-in; migration 0012 also brings the flag into line
  once (idempotent UPDATEs). Accounts with any membership never claim; a
  staff session can't accept a partner link.
- **Grants are claimed on every sign-in**, each audited in its own
  organisation, after a cheap SELECT. A partner's session organisation is
  that of their newest live grant; an organisation switcher is left for
  later. A partner whose grants are all over is told at /login that their
  access has ended, naming whoever invited them.
- **Who can invite partners** is "Invite partners" (partners.invite), not
  only admins — this replaces the earlier "partner invitations are for
  admins" and "only admins invite or revoke". The portal says "Inviting
  people or taking access away needs “Invite partners” — ask a super admin."
- **Sponsors upload artwork** for their own items while draft, awaiting
  artwork or changes requested (later it is the team's call, as it would
  supersede decisions); never stands or panels. The upload sends the item for
  sign-off when its details are complete, otherwise the team is told; the
  owner (else creator) gets `artwork_uploaded`. The rule needs the item's
  status, which `itemAuthzCtx` always supplies, so the frozen snapshot is
  unchanged.
- **Duplicates:** same email, event, role and company, not revoked. Waiting →
  Resend; active → said so; ended → Extend. No second row.
- **Team and partner invitations don't collide.** An open team invitation
  blocks a partner one (named here; "use a different email" elsewhere).
  A staff invitation is blocked only by live partner access here ("This email
  has portal access here (…) — revoke it in Users → External first, then
  invite them to the team") or a neutral refusal for live access in another
  organisation; ended and revoked access never blocks (Add several too).
- **Venue grants** must be for the event's own venue. Changing an event's
  venue revokes nothing but says how many people at the old venue no longer
  see it (P4.4).
- **Prefill:** suppliers use their contact name and email, sponsors and
  exhibitors their contact, venues their rigging contact.
- **Invite lists leave out archived events** (Suppliers, Venues, External);
  the server refuses them anyway.
- **One answer for "does this sponsor have portal access"**
  (`sponsorPortalAccess`, live grants only) on the Sponsors tab and the item
  page.
- **Existing accounts** get our own "new access" email with the reason,
  falling back to a Supabase sign-in link, then a link to pass on.
- **Event copy:** partner end dates move with the event's breakdown end (end
  of the London day); ended grants come across moved unless still past;
  revoked never. An owner who can't own the copy is replaced by the copier.
- **Supplier embargo** (`externalSeesArtwork`) lives in
  `lib/users/external.ts` and reuses can(signage.view) without supplier
  grants.
- **Defence in depth:** the portal item list joins the event and filters by
  the partner's organisation, and can() gets the organisation for its
  tenancy check.
- **Dates:** External shows end dates with the year ("ends 8 Oct 2027");
  invitation dates day and month only.

## Release review fixes (Oct 2026)

- **Always a super admin whose access lasts.** Suspending, removing or
  demoting a super admin, or giving one a new or moved end date, needs
  another super admin who is not suspended and has no end date (the rows are
  locked FOR UPDATE). "Has access right now" let two super admins give each
  other end dates; "outlasts the new end date" still empties the
  organisation once the later date passes, so the rule is no end date at
  all. Clearing an end date is never refused, so an organisation already in
  that state can recover. The person page's "only super admin" lock follows
  the same rule.
- **A new invitation link is a way in as that person.** A manager who isn't
  a super admin may Resend or get a New link (singly or from the bulk bar)
  only for an invitation they could have made themselves —
  personChangeRefusal as if adding the person now, sign-off rows included.
  Where invitations can be emailed, only super admins get a raw link by
  hand; managers use Resend. The invitation page and the Team list hide both
  buttons when the viewer can't renew (`canRenewInvite` in lib/authz.ts, the
  same rule the server applies). Renewing also re-checks that the email hasn't since
  got other access (portal access here, a team or portal account
  elsewhere), as inviting does.
- **Managers hand over within the departments' own approvers.** When a
  manager who isn't a super admin suspends someone, each department's
  sign-offs go only to that department's approvers (or back to the
  department), and sign-offs outside a department never to the manager —
  the same limit as rule 8 of personChangeRefusal. With nobody else in the
  department, they are told to ask a super admin. The Suspend dialog offers
  only those choices.
- **A department's last signer takes its open department-wide sign-offs
  with them.** Suspending or removing the only person who can sign for a
  department hands over its pending, waiting and sent-back steps that name
  nobody, with the person's own (a person must be picked; the audit row
  records that the step was the department's). When such a person's access
  ends, the daily job can't pick anyone, so the notice to super admins and
  managers names those sign-offs too.
- **Clearing an item's sign-off plan is recorded on the item**: one audit
  row per item (before and after plan, the person as subject), when someone
  is suspended, removed or stops signing for a department.
- **Team members hold no live partner access in the same organisation.**
  Removing someone from the team revokes their live grants here (one audit
  row each; the Remove dialog lists them), so a leaver isn't signed in to
  the portal. Partner access of a team member can be ended but not extended,
  and copying an event leaves their grants behind (counted).
- **People changes run one after another per organisation**
  (pg_advisory_xact_lock on the organisation, taken first in suspend,
  remove, end dates, person edits, stop-signing and taking someone off a
  department's approvers), so two suspensions at once can't each hand
  sign-offs to the other.
- **Losing "main approver" to someone else is in the person's history**: an
  approver audit row naming the demoted person, from the person page,
  invitations and Users → Departments alike (`clearOtherMainsTx`).
- **Comment and "approval superseded" notifications reach a partner only
  while their live grants in this organisation still show them the record**
  (can() on the item or stand), never for a staff-only comment. notify()
  also takes the record's organisation and event, keeping a partner only
  with a live grant there; the email dispatcher drops (and settles) a
  partner's item or stand email once they have no live grant on that event.
- **Event copy counts what it copies.** The "Portal access" count includes
  ended grants that come across with their end date moved, leaves out
  archived suppliers, other venues' grants (when the venue changes) and team
  members, and is recounted in the form from the new dates and venue
  (`copiedAccessCount`). A box with nothing to bring is never sent ticked.
  The result says how many partners can sign in to the new event. Items
  whose supplier has been archived are copied with no supplier (counted).
- **Confirming several steps is one request** (`confirmApprovals`): each
  step in its own transaction with the usual checks and audit row, the pages
  revalidated once. Actions that revalidate aren't followed by a client
  refresh (revalidatePath in a Server Function already updates the page).
  Waiting on me loads every record in two joined queries instead of two per
  step.
- **Setup progress is loaded once per request** (React cache) and shared by
  the layout and the Dashboard or Setup page; the side navigation leaves
  Setup out once its card is dismissed ("still under Event details").
- **Currency is shown, not chosen**, until costs, labels and exports use it
  (they all show pounds); a currency sent to the settings action is ignored.
- **Words:** copy never says "admins" or "an admin" on its own — "a super
  admin", or missingAbilityMessage for a missing ability; partners and
  sign-in pages say "the person who invited you" / "your contact there".
  tests/unit/terminology.test.ts guards it. Halls says an archived event is
  read-only before anything about permissions.
- **Who to ask** about creating or setting up events is whoever has access
  and holds the ability (events.create, or any event setup ability), super
  admins first, falling back to super admins with access.
- **My Work between seasons:** only an organisation with no events at all
  sends people who create events to /start; when every event is archived,
  My Work stays open with a "Create your next event" card.
- **Releases migrate first, then deploy** (README → Releasing). /api/health
  reports `"schema": "behind"` (and fails) when the database lacks this
  code's newest migration. A rollback past 0012 is unsafe once anyone is
  suspended or has an end date.
- **drizzle-kit's migration metadata is left to drizzle-kit**
  (`lib/db/migrations/meta` in .prettierignore): it rewrites the journal and
  snapshots in its own format on every generate, so formatting them would
  only churn.
