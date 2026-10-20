-- Rows for tests/unit/db-move.db.test.ts, loaded into the copy's source
-- database (after migrations and the demo seed). They cover every foreign-key
-- cycle the copy has to break (a cloned edition, a sign with a parent and a
-- current artwork version, a comment reply, a subtask), the composite
-- sponsor → package key, audit rows, an open staff invitation, a partner
-- grant, Better Auth's four tables, and values that only survive a copy that
-- never passes through JavaScript: numeric scale, big numbers inside jsonb,
-- text[] with NULL/quotes/braces/commas/empty strings, microsecond
-- timestamps, control characters, non-ASCII, and a bigint above 2^53.
BEGIN;

INSERT INTO organisations (id, name, slug, settings, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000001', 'Move Fixture Org', 'move-fixture',
   '{"big": 123456789012345678901234567890.000, "tiny": 0.000000000000000000000000000001, "nested": [1.10, null, true, "x"]}',
   '2026-10-20 01:30:00.000001+00', '2026-10-20 01:30:00.999999+00');

INSERT INTO users (id, email, full_name, email_verified, notification_prefs, last_seen_at, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000011', 'zoe@move-fixture.test', 'Zoë Çelik — 東京 🚀', true,
   '{"digest": "weekly", "mute": ["comment"]}', '2026-10-19 23:59:59.123456+00',
   '2026-01-01 00:00:00.000001+00', '2026-01-01 00:00:00.000002+00'),
  ('f1000000-0000-4000-8000-000000000012', 'ops@move-fixture.test', E'O''Brien "Ops"\ttabbed', true,
   '{}', NULL, '2026-01-02 00:00:00+00', '2026-01-02 00:00:00+00'),
  ('f1000000-0000-4000-8000-000000000013', 'partner@move-fixture.test', 'Partner', true,
   '{}', NULL, '2026-01-03 00:00:00+00', '2026-01-03 00:00:00+00');

INSERT INTO departments (id, organisation_id, name, sort_order, default_for, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000021', 'f1000000-0000-4000-8000-000000000001', 'Operations', 1,
   ARRAY[NULL, 'quote"d', 'brace{x}', 'comma,here', '', 'back\slash', 'Zoë']::text[],
   '2026-01-04 00:00:00.5+00', '2026-01-04 00:00:00.5+00');

INSERT INTO memberships (id, user_id, organisation_id, role, department_id, features, edition_ids, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000015', 'f1000000-0000-4000-8000-000000000011',
   'f1000000-0000-4000-8000-000000000001', 'admin', NULL, NULL, NULL, '2026-01-05 00:00:00+00', '2026-01-05 00:00:00+00'),
  ('f1000000-0000-4000-8000-000000000016', 'f1000000-0000-4000-8000-000000000012',
   'f1000000-0000-4000-8000-000000000001', 'ops', 'f1000000-0000-4000-8000-000000000021',
   ARRAY['sponsorship', '']::text[],
   ARRAY['f1000000-0000-4000-8000-000000000051', 'f1000000-0000-4000-8000-000000000052']::uuid[],
   '2026-01-05 00:00:00+00', '2026-01-05 00:00:00+00');

INSERT INTO events (id, organisation_id, name, code, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000031', 'f1000000-0000-4000-8000-000000000001', 'Move Fixture Week', 'MVFX',
   '2026-01-06 00:00:00+00', '2026-01-06 00:00:00+00');

INSERT INTO venues (id, organisation_id, name, code, notes, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000041', 'f1000000-0000-4000-8000-000000000001', 'Hall Ünïcode', 'MVFXV',
   E'Line one\nLine two\ttabbed \\ backslash \x01 \x1f end', '2026-01-07 00:00:00+00', '2026-01-07 00:00:00+00');

-- An edition and a copy of it (editions_cloned_from_fk: a self-reference).
INSERT INTO editions (id, event_id, venue_id, name, code, build_start, build_end, open_start, open_end, breakdown_end,
                      status, cloned_from_edition_id, signage_budget, stand_required_doc_types,
                      complex_structure_triggers, setup_checked, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000051', 'f1000000-0000-4000-8000-000000000031', 'f1000000-0000-4000-8000-000000000041',
   'Move Fixture 2027', 'MVFX27', '2027-09-20', '2027-09-22', '2027-09-23', '2027-09-25', '2027-09-26',
   'live', NULL, 10.50, ARRAY['rams', 'insurance']::text[], '{"height_mm": 4000, "ratio": 0.10}',
   ARRAY['venue']::text[], '2026-02-01 08:00:00.000001+00', '2026-02-01 08:00:00.000001+00'),
  ('f1000000-0000-4000-8000-000000000052', 'f1000000-0000-4000-8000-000000000031', 'f1000000-0000-4000-8000-000000000041',
   'Move Fixture 2028', 'MVFX28', '2028-09-18', '2028-09-20', '2028-09-21', '2028-09-23', '2028-09-24',
   'planning', 'f1000000-0000-4000-8000-000000000051', 1234567890.00, '{}', '{}',
   '{}', '2025-12-31 23:59:59.999999+00', '2025-12-31 23:59:59.999999+00');

-- A sign, and a child sign whose current artwork version is set below
-- (signage_items ↔ artwork_versions is a cycle; parent_item_id a self-reference).
INSERT INTO signage_items (id, edition_id, ref, seq, name, description, weight_kg, cost_estimate, sale_price,
                           signoffs, created_by, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000061', 'f1000000-0000-4000-8000-000000000051', 'SIG-MVFX27-001', 1,
   'Entrance totem', 'Façade — “curly quotes”', 12.50, 10.50, 0.10, '{"marketing": {"by": "zoe", "at": "2026-03-01T10:00:00.000001Z"}}',
   'f1000000-0000-4000-8000-000000000011', '2026-03-01 10:00:00.000001+00', '2026-03-01 10:00:00.000001+00'),
  ('f1000000-0000-4000-8000-000000000062', 'f1000000-0000-4000-8000-000000000051', 'SIG-MVFX27-002', 2,
   'Totem side panel', NULL, NULL, 99999999.99, NULL, NULL,
   'f1000000-0000-4000-8000-000000000011', '2026-03-02 10:00:00+00', '2026-03-02 10:00:00+00');
UPDATE signage_items SET parent_item_id = 'f1000000-0000-4000-8000-000000000061'
  WHERE id = 'f1000000-0000-4000-8000-000000000062';

INSERT INTO artwork_versions (id, signage_item_id, version_number, file_path, file_name, mime_type, file_size, sha256,
                              page_count, preview_path, uploaded_by, proof_status, notes, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000071', 'f1000000-0000-4000-8000-000000000062', 1,
   'f1000000-0000-4000-8000-000000000062/v1.pdf', 'Panel v1.pdf', 'application/pdf', 2048,
   'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 1,
   'f1000000-0000-4000-8000-000000000062/v1.png', 'f1000000-0000-4000-8000-000000000011', 'proof',
   E'Notes with a newline\nand a tab\t', '2026-03-03 10:00:00.000001+00', '2026-03-03 10:00:00.000001+00'),
  ('f1000000-0000-4000-8000-000000000072', 'f1000000-0000-4000-8000-000000000062', 2,
   'seed/sample-panel.pdf', 'Panel v2.pdf', 'application/pdf', 0,
   '0000000000000000000000000000000000000000000000000000000000000000', NULL, NULL,
   'f1000000-0000-4000-8000-000000000011', 'final', NULL, '2026-03-04 10:00:00+00', '2026-03-04 10:00:00+00');
UPDATE signage_items SET current_artwork_version_id = 'f1000000-0000-4000-8000-000000000072'
  WHERE id = 'f1000000-0000-4000-8000-000000000062';

-- A comment and a reply to it (comments_parent_fk: a self-reference).
INSERT INTO comments (id, entity_type, entity_id, parent_id, author_id, body, mention_user_ids, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000081', 'signage_item', 'f1000000-0000-4000-8000-000000000062', NULL,
   'f1000000-0000-4000-8000-000000000011', E'Is the bleed right?\n\t— Zoë', '{}', '2026-03-05 10:00:00+00', '2026-03-05 10:00:00+00'),
  ('f1000000-0000-4000-8000-000000000082', 'signage_item', 'f1000000-0000-4000-8000-000000000062',
   'f1000000-0000-4000-8000-000000000081', 'f1000000-0000-4000-8000-000000000012', 'Yes: 3 mm, all round {ok}',
   ARRAY['f1000000-0000-4000-8000-000000000011']::uuid[], '2026-03-05 10:00:00.000007+00', '2026-03-05 10:00:00.000007+00');

-- A task and a subtask (parent_task_id: a self-reference).
INSERT INTO tasks (id, organisation_id, edition_id, title, notes, status, due_date, assigned_to_user_id,
                   created_by_user_id, parent_task_id, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-000000000091', 'f1000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000051',
   'Book the riggers', NULL, 'open', '2027-09-01', 'f1000000-0000-4000-8000-000000000012',
   'f1000000-0000-4000-8000-000000000011', NULL, '2026-03-06 10:00:00+00', '2026-03-06 10:00:00+00'),
  ('f1000000-0000-4000-8000-000000000092', 'f1000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000051',
   'Send the RAMS', 'Ask for the "final" version', 'in_progress', NULL, 'f1000000-0000-4000-8000-000000000012',
   'f1000000-0000-4000-8000-000000000011', 'f1000000-0000-4000-8000-000000000091', '2026-03-06 10:00:01+00', '2026-03-06 10:00:01+00');

-- A package and a sponsor that bought it (composite key edition_id + package_id).
INSERT INTO sponsorship_packages (id, edition_id, name, description, price, places, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000a1', 'f1000000-0000-4000-8000-000000000051', 'Gold', 'Ünïcode — gold', 1500.50, 3,
   '2026-03-07 10:00:00+00', '2026-03-07 10:00:00+00');
INSERT INTO sponsors (id, edition_id, company_name, contact_email, package_id, package_price, package_price_note,
                      package_sold_at, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000b1', 'f1000000-0000-4000-8000-000000000051', 'Acme & Söhne', 'acme@move-fixture.test',
   'f1000000-0000-4000-8000-0000000000a1', 10.50, 'Early-bird, 10% off', '2026-03-08 10:00:00.000001+00',
   '2026-03-08 10:00:00+00', '2026-03-08 10:00:00+00');

-- Audit rows (append-only on every database).
INSERT INTO audit_log (id, organisation_id, edition_id, actor_user_id, actor_type, entity_type, entity_id, action,
                       before, after, summary, ip, user_agent, created_at) VALUES
  ('f1000000-0000-4000-8000-0000000000c1', 'f1000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000051',
   'f1000000-0000-4000-8000-000000000011', 'user', 'signage_item', 'f1000000-0000-4000-8000-000000000062', 'update',
   '{"cost": 10.50}', '{"cost": 123456789012345678901234567890.000, "text": "quote \" and \\ backslash", "unicode": "Zoë 東京 🚀"}',
   E'Changed the cost\twith a tab and a bell \x07', '203.0.113.7', 'Mozilla/5.0 (Fixture)', '2026-03-09 10:00:00.000001+00'),
  ('f1000000-0000-4000-8000-0000000000c2', 'f1000000-0000-4000-8000-000000000001', NULL, NULL, 'system', 'database', NULL,
   'settings_change', NULL, NULL, 'System row', NULL, NULL, '2026-03-09 10:00:00.000002+00');

-- An open staff invitation and a partner grant.
INSERT INTO staff_invites (id, organisation_id, invited_email, role, invited_by, invite_token_hash, full_name,
                           job_title, department_id, edition_ids, expires_at, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000d1', 'f1000000-0000-4000-8000-000000000001', 'new.starter@move-fixture.test', 'ops',
   'f1000000-0000-4000-8000-000000000011', 'sha256-fixture-invite-hash', 'New Starter', 'Coördinator',
   'f1000000-0000-4000-8000-000000000021', ARRAY['f1000000-0000-4000-8000-000000000051']::uuid[],
   '2026-11-01 00:00:00+00', '2026-10-18 09:00:00+00', '2026-10-18 09:00:00+00');
INSERT INTO external_grants (id, user_id, invited_email, organisation_id, edition_id, role, scope_type, scope_id,
                             invited_by, invite_token_hash, accepted_at, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000e1', 'f1000000-0000-4000-8000-000000000013', 'partner@move-fixture.test',
   'f1000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000051', 'sponsor', 'sponsor',
   'f1000000-0000-4000-8000-0000000000b1', 'f1000000-0000-4000-8000-000000000011', 'sha256-fixture-grant-hash',
   '2026-10-18 10:00:00.000001+00', '2026-10-18 09:30:00+00', '2026-10-18 10:00:00.000001+00');

-- Better Auth: a password (scrypt-shaped), two sessions, a hashed link, a rate-limit counter.
INSERT INTO auth_account (id, user_id, account_id, provider_id, password, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000f1', 'f1000000-0000-4000-8000-000000000011', 'f1000000-0000-4000-8000-000000000011',
   'credential', '9f86d081884c7d659a2feaa0c55ad015:a3bf4f1b2b0b822cd15d6c15b0f00a089f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
   '2026-10-01 00:00:00+00', '2026-10-02 00:00:00.000001+00');
INSERT INTO auth_session (id, user_id, token, expires_at, ip_address, user_agent, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000f2', 'f1000000-0000-4000-8000-000000000011', 'Hk3q9VbN0aFixtureTokenOne_-x',
   '2026-11-19 00:00:00.000001+00', '198.51.100.4', 'Mozilla/5.0 (Fixture one)', '2026-10-20 00:00:00+00', '2026-10-20 00:00:00+00'),
  ('f1000000-0000-4000-8000-0000000000f3', 'f1000000-0000-4000-8000-000000000012', 'Zz9-FixtureTokenTwo.with/odd+chars=',
   '2026-11-19 00:00:00+00', NULL, NULL, '2026-10-20 00:00:01+00', '2026-10-20 00:00:01+00');
INSERT INTO auth_verification (id, identifier, value, expires_at, created_at, updated_at) VALUES
  ('f1000000-0000-4000-8000-0000000000f4', 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
   '{"email":"zoe@move-fixture.test","name":"Zoë"}', '2026-10-20 01:00:00+00', '2026-10-20 00:00:00+00', '2026-10-20 00:00:00+00');
INSERT INTO auth_rate_limit (id, key, count, last_request) VALUES
  ('f1000000-0000-4000-8000-0000000000f5', '203.0.113.7|/sign-in/email', 3, 9007199254740993);

COMMIT;
