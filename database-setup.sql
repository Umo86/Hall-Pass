-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites CASCADE;
DROP TYPE IF EXISTS public.actor_type CASCADE;
DROP TYPE IF EXISTS public.approval_entity_type CASCADE;
DROP TYPE IF EXISTS public.approver_type CASCADE;
DROP TYPE IF EXISTS public.audit_action CASCADE;
DROP TYPE IF EXISTS public.change_request_status CASCADE;
DROP TYPE IF EXISTS public.deadline_key CASCADE;
DROP TYPE IF EXISTS public.doc_type CASCADE;
DROP TYPE IF EXISTS public.document_status CASCADE;
DROP TYPE IF EXISTS public.edition_status CASCADE;
DROP TYPE IF EXISTS public.email_status CASCADE;
DROP TYPE IF EXISTS public.entity_type CASCADE;
DROP TYPE IF EXISTS public.external_role CASCADE;
DROP TYPE IF EXISTS public.fixing_method CASCADE;
DROP TYPE IF EXISTS public.install_slot CASCADE;
DROP TYPE IF EXISTS public.instance_status CASCADE;
DROP TYPE IF EXISTS public.item_kind CASCADE;
DROP TYPE IF EXISTS public.owner_role CASCADE;
DROP TYPE IF EXISTS public.proof_status CASCADE;
DROP TYPE IF EXISTS public.reminder_kind CASCADE;
DROP TYPE IF EXISTS public.reminder_target_type CASCADE;
DROP TYPE IF EXISTS public.scope_type CASCADE;
DROP TYPE IF EXISTS public.sided CASCADE;
DROP TYPE IF EXISTS public.signage_category CASCADE;
DROP TYPE IF EXISTS public.signage_status CASCADE;
DROP TYPE IF EXISTS public.snag_severity CASCADE;
DROP TYPE IF EXISTS public.snag_status CASCADE;
DROP TYPE IF EXISTS public.staff_role CASCADE;
DROP TYPE IF EXISTS public.stand_outcome CASCADE;
DROP TYPE IF EXISTS public.stand_status CASCADE;
DROP TYPE IF EXISTS public.stand_type CASCADE;
DROP TYPE IF EXISTS public.step_kind CASCADE;
DROP TYPE IF EXISTS public.supplier_kind CASCADE;
DROP TYPE IF EXISTS public.task_status CASCADE;
DROP TYPE IF EXISTS public.workflow_applies_to CASCADE;
DROP FUNCTION IF EXISTS public.forbid_audit_mutation() CASCADE;
DROP FUNCTION IF EXISTS public.set_updated_at() CASCADE;
-- ---------------------------------------------------------------------------

--
-- PostgreSQL database dump
--

\restrict 7ppc9qbsNrdr0K17loavXoELeK82OA6mxdMisEKKwracOIlftMUHHzGuCZncIFw

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: drizzle; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA drizzle;


--
-- Name: actor_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.actor_type AS ENUM (
    'user',
    'system',
    'cron'
);


--
-- Name: approval_entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_entity_type AS ENUM (
    'signage_item',
    'stand_submission'
);


--
-- Name: approver_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approver_type AS ENUM (
    'role',
    'user'
);


--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_action AS ENUM (
    'create',
    'update',
    'soft_delete',
    'restore',
    'status_change',
    'submit',
    'decide',
    'delegate',
    'escalate',
    'upload',
    'download',
    'export',
    'import',
    'login',
    'invite',
    'grant_revoke',
    'settings_change'
);


--
-- Name: change_request_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.change_request_status AS ENUM (
    'open',
    'approved',
    'rejected',
    'applied'
);


--
-- Name: deadline_key; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.deadline_key AS ENUM (
    'artwork_due',
    'venue_rigging_submission',
    'print_deadline',
    'delivery',
    'stand_design_due',
    'insurance_due'
);


--
-- Name: doc_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.doc_type AS ENUM (
    'plan',
    'elevation',
    'structural_calcs',
    'rams',
    'insurance_pl',
    'fire_cert',
    'electrical_cert',
    'rigging_plan',
    'spec_sheet',
    'quote',
    'po',
    'other'
);


--
-- Name: document_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.document_status AS ENUM (
    'received',
    'accepted',
    'rejected'
);


--
-- Name: edition_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.edition_status AS ENUM (
    'planning',
    'live',
    'closed',
    'archived'
);


--
-- Name: email_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.email_status AS ENUM (
    'sent',
    'failed'
);


--
-- Name: entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_type AS ENUM (
    'signage_item',
    'stand_submission',
    'exhibitor',
    'contractor',
    'supplier',
    'edition'
);


--
-- Name: external_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.external_role AS ENUM (
    'venue',
    'structural_engineer',
    'hs',
    'supplier',
    'exhibitor',
    'contractor',
    'sponsor'
);


--
-- Name: fixing_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fixing_method AS ENUM (
    'rigged',
    'freestanding',
    'wall_mounted',
    'shell_mounted',
    'floor',
    'digital',
    'other'
);


--
-- Name: install_slot; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.install_slot AS ENUM (
    'am',
    'pm',
    'overnight'
);


--
-- Name: instance_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.instance_status AS ENUM (
    'waiting',
    'pending',
    'approved',
    'approved_with_conditions',
    'changes_requested',
    'rejected',
    'confirmed',
    'skipped',
    'invalidated'
);


--
-- Name: item_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.item_kind AS ENUM (
    'signage',
    'sponsorship_item'
);


--
-- Name: owner_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.owner_role AS ENUM (
    'ops',
    'marketing'
);


--
-- Name: proof_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.proof_status AS ENUM (
    'draft',
    'proof',
    'final'
);


--
-- Name: reminder_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reminder_kind AS ENUM (
    'minus7',
    'minus2',
    'due',
    'overdue',
    'escalation',
    'chaser',
    'expiry'
);


--
-- Name: reminder_target_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reminder_target_type AS ENUM (
    'approval_instance',
    'signage_item',
    'exhibitor',
    'document'
);


--
-- Name: scope_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.scope_type AS ENUM (
    'venue',
    'supplier',
    'exhibitor',
    'sponsor'
);


--
-- Name: sided; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sided AS ENUM (
    'single',
    'double'
);


--
-- Name: signage_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.signage_category AS ENUM (
    'directional',
    'venue',
    'sponsorship'
);


--
-- Name: signage_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.signage_status AS ENUM (
    'draft',
    'awaiting_artwork',
    'in_review',
    'changes_requested',
    'approved',
    'approved_with_conditions',
    'in_production',
    'delivered',
    'installed',
    'snagged',
    'closed',
    'rejected',
    'on_hold'
);


--
-- Name: snag_severity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.snag_severity AS ENUM (
    'low',
    'medium',
    'high'
);


--
-- Name: snag_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.snag_status AS ENUM (
    'open',
    'in_progress',
    'resolved',
    'wont_fix'
);


--
-- Name: staff_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.staff_role AS ENUM (
    'admin',
    'ops',
    'marketing',
    'sales',
    'event_director',
    'viewer'
);


--
-- Name: stand_outcome; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stand_outcome AS ENUM (
    'approved',
    'approved_with_conditions',
    'rejected'
);


--
-- Name: stand_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stand_status AS ENUM (
    'not_submitted',
    'submitted',
    'in_review',
    'changes_requested',
    'approved',
    'approved_with_conditions',
    'rejected',
    'build_checked',
    'closed',
    'on_hold'
);


--
-- Name: stand_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stand_type AS ENUM (
    'space_only',
    'shell',
    'custom_shell'
);


--
-- Name: step_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.step_kind AS ENUM (
    'approval',
    'confirmation'
);


--
-- Name: supplier_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.supplier_kind AS ENUM (
    'print',
    'rigging',
    'av',
    'contractor',
    'structural_engineer',
    'other'
);


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_status AS ENUM (
    'open',
    'done'
);


--
-- Name: workflow_applies_to; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.workflow_applies_to AS ENUM (
    'signage',
    'stand'
);


--
-- Name: forbid_audit_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.forbid_audit_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is append-only: % is not permitted', TG_OP;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: __drizzle_migrations; Type: TABLE; Schema: drizzle; Owner: -
--

CREATE TABLE drizzle.__drizzle_migrations (
    id integer NOT NULL,
    hash text NOT NULL,
    created_at bigint
);


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE; Schema: drizzle; Owner: -
--

CREATE SEQUENCE drizzle.__drizzle_migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: drizzle; Owner: -
--

ALTER SEQUENCE drizzle.__drizzle_migrations_id_seq OWNED BY drizzle.__drizzle_migrations.id;


--
-- Name: approval_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_instances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type public.approval_entity_type NOT NULL,
    entity_id uuid NOT NULL,
    run_number integer NOT NULL,
    workflow_step_id uuid NOT NULL,
    step_name_snapshot text NOT NULL,
    step_kind_snapshot public.step_kind NOT NULL,
    sort_order_snapshot integer NOT NULL,
    parallel_group_snapshot integer,
    status public.instance_status DEFAULT 'waiting'::public.instance_status NOT NULL,
    assigned_role text,
    assigned_user_id uuid,
    delegated_from_user_id uuid,
    decided_by uuid,
    decided_at timestamp with time zone,
    decision_comment text,
    conditions_text text,
    locked_version_type text,
    locked_version_id text,
    locked_sha256 text,
    pending_since timestamp with time zone,
    due_at timestamp with time zone,
    hold_shift_days integer DEFAULT 0 NOT NULL,
    escalated_at timestamp with time zone,
    escalated_to uuid[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    invalidate_on_new_version_snapshot boolean DEFAULT true NOT NULL,
    restart_from_here_snapshot boolean DEFAULT true NOT NULL,
    sla_days_snapshot integer DEFAULT 0 NOT NULL,
    no_supplier_fallback boolean DEFAULT false NOT NULL
);


--
-- Name: artwork_annotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artwork_annotations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    artwork_version_id uuid NOT NULL,
    page integer DEFAULT 1 NOT NULL,
    x_pct numeric(6,5) NOT NULL,
    y_pct numeric(6,5) NOT NULL,
    comment_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: artwork_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artwork_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    signage_item_id uuid NOT NULL,
    version_number integer NOT NULL,
    file_path text NOT NULL,
    file_name text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    sha256 text NOT NULL,
    page_count integer,
    preview_path text,
    uploaded_by uuid,
    proof_status public.proof_status DEFAULT 'draft'::public.proof_status NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT artwork_versions_size_positive CHECK ((file_size >= 0)),
    CONSTRAINT artwork_versions_version_positive CHECK ((version_number > 0))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid,
    edition_id uuid,
    actor_user_id uuid,
    actor_type public.actor_type DEFAULT 'user'::public.actor_type NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    action public.audit_action NOT NULL,
    before jsonb,
    after jsonb,
    summary text NOT NULL,
    ip text,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: change_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.change_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type public.entity_type NOT NULL,
    entity_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    reason text NOT NULL,
    field_changes jsonb DEFAULT '[]'::jsonb NOT NULL,
    status public.change_request_status DEFAULT 'open'::public.change_request_status NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone,
    reopened_instance_ids uuid[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: comment_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    comment_id uuid NOT NULL,
    document_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type public.entity_type NOT NULL,
    entity_id uuid NOT NULL,
    parent_id uuid,
    author_id uuid NOT NULL,
    body text NOT NULL,
    mention_user_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    is_internal boolean DEFAULT true NOT NULL,
    edited_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contractors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contractors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    contact_name text,
    email text,
    phone text,
    insurance_expiry date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    edition_id uuid,
    entity_type public.entity_type NOT NULL,
    entity_id uuid NOT NULL,
    doc_type public.doc_type NOT NULL,
    file_path text NOT NULL,
    file_name text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    sha256 text NOT NULL,
    submission_version integer,
    expires_at date,
    uploaded_by uuid,
    is_external_upload boolean DEFAULT false NOT NULL,
    status public.document_status DEFAULT 'received'::public.document_status NOT NULL,
    review_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: edition_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edition_counters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    key text NOT NULL,
    value integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: edition_deadlines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edition_deadlines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    key public.deadline_key NOT NULL,
    label text NOT NULL,
    days_before_build_start integer NOT NULL,
    override_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: editions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.editions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    venue_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    build_start date NOT NULL,
    build_end date NOT NULL,
    open_start date NOT NULL,
    open_end date NOT NULL,
    breakdown_end date NOT NULL,
    status public.edition_status DEFAULT 'planning'::public.edition_status NOT NULL,
    cloned_from_edition_id uuid,
    signage_budget numeric(12,2),
    stand_required_doc_types text[] DEFAULT '{plan,elevation,rams,insurance_pl}'::text[] NOT NULL,
    complex_structure_triggers jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: email_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    to_email text NOT NULL,
    template text NOT NULL,
    entity_type text,
    entity_id uuid,
    provider_message_id text,
    status public.email_status NOT NULL,
    error text,
    attempts integer DEFAULT 1 NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: exhibitors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exhibitors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    company_name text NOT NULL,
    stand_number text NOT NULL,
    hall_id uuid,
    stand_size_sqm numeric(8,2),
    stand_type public.stand_type DEFAULT 'space_only'::public.stand_type NOT NULL,
    contact_name text,
    contact_email text,
    contractor_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    kind text NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    file_path text NOT NULL,
    generated_by uuid,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: external_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    invited_email text NOT NULL,
    organisation_id uuid NOT NULL,
    edition_id uuid NOT NULL,
    role public.external_role NOT NULL,
    scope_type public.scope_type,
    scope_id uuid,
    expires_at timestamp with time zone,
    invited_by uuid,
    invite_token_hash text NOT NULL,
    accepted_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: halls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.halls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    name text NOT NULL,
    floorplan_path text,
    floorplan_width_px integer,
    floorplan_height_px integer,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: item_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    default_workflow_id uuid,
    default_fixing_method public.fixing_method,
    requires_venue_approval_default boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    kind public.item_kind DEFAULT 'signage'::public.item_kind NOT NULL
);


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    hall_id uuid NOT NULL,
    name text NOT NULL,
    zone text,
    x_pct numeric(6,5),
    y_pct numeric(6,5),
    near_stand_number text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    organisation_id uuid NOT NULL,
    role public.staff_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    permission_overrides jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    kind text NOT NULL,
    entity_type public.entity_type,
    entity_id uuid,
    title text NOT NULL,
    body text,
    link text,
    read_at timestamp with time zone,
    emailed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organisations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    brand_name text DEFAULT 'Hall Pass'::text NOT NULL,
    logo_path text,
    settings jsonb DEFAULT '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reminder_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reminder_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    target_type public.reminder_target_type NOT NULL,
    target_id uuid NOT NULL,
    kind public.reminder_kind NOT NULL,
    sent_on date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: signage_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signage_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    ref text NOT NULL,
    seq integer NOT NULL,
    name text NOT NULL,
    description text,
    item_type_id uuid,
    hall_id uuid,
    location_id uuid,
    owner_role public.owner_role DEFAULT 'ops'::public.owner_role NOT NULL,
    owner_user_id uuid,
    sponsor_id uuid,
    sponsor_entitlement_id uuid,
    is_sponsor_deliverable boolean DEFAULT false NOT NULL,
    width_mm integer,
    height_mm integer,
    depth_mm integer,
    quantity integer DEFAULT 1 NOT NULL,
    sided public.sided DEFAULT 'single'::public.sided NOT NULL,
    material text,
    finish text,
    fixing_method public.fixing_method,
    weight_kg numeric(8,2),
    requires_venue_approval boolean DEFAULT false NOT NULL,
    requires_event_director boolean DEFAULT false NOT NULL,
    budget_line text,
    cost_estimate numeric(12,2),
    cost_actual numeric(12,2),
    po_number text,
    supplier_id uuid,
    artwork_due_override date,
    print_deadline date,
    delivery_date date,
    install_date date,
    install_slot public.install_slot,
    install_contractor_id uuid,
    status public.signage_status DEFAULT 'draft'::public.signage_status NOT NULL,
    previous_status public.signage_status,
    on_hold_reason text,
    workflow_id uuid,
    current_run_number integer DEFAULT 0 NOT NULL,
    current_artwork_version_id uuid,
    installed_at timestamp with time zone,
    installed_by uuid,
    install_photo_path text,
    created_by uuid,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    kind public.item_kind DEFAULT 'signage'::public.item_kind NOT NULL,
    category public.signage_category,
    CONSTRAINT signage_items_depth_positive CHECK (((depth_mm IS NULL) OR (depth_mm > 0))),
    CONSTRAINT signage_items_height_positive CHECK (((height_mm IS NULL) OR (height_mm > 0))),
    CONSTRAINT signage_items_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT signage_items_width_positive CHECK (((width_mm IS NULL) OR (width_mm > 0)))
);


--
-- Name: snags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    signage_item_id uuid,
    stand_submission_id uuid,
    description text NOT NULL,
    photo_path text,
    severity public.snag_severity DEFAULT 'medium'::public.snag_severity NOT NULL,
    assigned_user_id uuid,
    assigned_supplier_id uuid,
    assigned_contractor_id uuid,
    status public.snag_status DEFAULT 'open'::public.snag_status NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by uuid,
    resolution_note text,
    resolution_photo_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sponsor_entitlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsor_entitlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sponsor_id uuid NOT NULL,
    description text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sponsor_entitlements_quantity_positive CHECK ((quantity > 0))
);


--
-- Name: sponsors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    company_name text NOT NULL,
    contact_name text,
    contact_email text,
    package_name text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: staff_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_invites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    invited_email text NOT NULL,
    role public.staff_role NOT NULL,
    permission_overrides jsonb DEFAULT '{}'::jsonb NOT NULL,
    invited_by uuid,
    invite_token_hash text NOT NULL,
    accepted_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stand_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stand_submissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    exhibitor_id uuid NOT NULL,
    ref text NOT NULL,
    contractor_id uuid,
    submission_version integer DEFAULT 1 NOT NULL,
    max_height_mm integer,
    is_double_deck boolean DEFAULT false NOT NULL,
    has_platform_over_600mm boolean DEFAULT false NOT NULL,
    has_ramped_raised_floor boolean DEFAULT false NOT NULL,
    has_rigging boolean DEFAULT false NOT NULL,
    has_ceiling_or_roof boolean DEFAULT false NOT NULL,
    has_tiered_seating boolean DEFAULT false NOT NULL,
    other_complex_notes text,
    is_complex boolean DEFAULT false NOT NULL,
    status public.stand_status DEFAULT 'not_submitted'::public.stand_status NOT NULL,
    previous_status public.stand_status,
    on_hold_reason text,
    outcome public.stand_outcome,
    conditions_text text,
    submitted_at timestamp with time zone,
    submitted_by uuid,
    rules_checklist jsonb DEFAULT '[]'::jsonb NOT NULL,
    build_check_done_at timestamp with time zone,
    build_check_by uuid,
    build_check_notes text,
    build_check_photo_path text,
    workflow_id uuid,
    current_run_number integer DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stand_submissions_height_positive CHECK (((max_height_mm IS NULL) OR (max_height_mm > 0)))
);


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    kind public.supplier_kind NOT NULL,
    contact_name text,
    email text,
    phone text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    edition_id uuid,
    title text NOT NULL,
    notes text,
    status public.task_status DEFAULT 'open'::public.task_status NOT NULL,
    due_date date,
    assigned_to_user_id uuid NOT NULL,
    created_by_user_id uuid NOT NULL,
    entity_type public.entity_type,
    entity_id uuid,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tasks_title_not_empty CHECK ((title <> ''::text))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    phone text,
    avatar_path text,
    is_external boolean DEFAULT false NOT NULL,
    notification_prefs jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: venue_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    rule_text text NOT NULL,
    applies_to text NOT NULL,
    is_checklist_item boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    address text,
    rigging_contact_name text,
    rigging_contact_email text,
    requires_stand_approval boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: workflow_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_steps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workflow_id uuid NOT NULL,
    sort_order integer NOT NULL,
    parallel_group integer,
    name text NOT NULL,
    kind public.step_kind NOT NULL,
    approver_type public.approver_type NOT NULL,
    approver_role text,
    approver_user_id uuid,
    conditions text[] DEFAULT '{always}'::text[] NOT NULL,
    sla_days integer DEFAULT 0 NOT NULL,
    invalidate_on_new_version boolean DEFAULT true NOT NULL,
    restart_from_here_on_changes boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: workflows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    applies_to public.workflow_applies_to NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: __drizzle_migrations id; Type: DEFAULT; Schema: drizzle; Owner: -
--

ALTER TABLE ONLY drizzle.__drizzle_migrations ALTER COLUMN id SET DEFAULT nextval('drizzle.__drizzle_migrations_id_seq'::regclass);


--
-- Data for Name: __drizzle_migrations; Type: TABLE DATA; Schema: drizzle; Owner: -
--

INSERT INTO drizzle.__drizzle_migrations VALUES (1, '16f092f05555074d4ce1fb58f25b34b3398c11d6af7041e18e1d111d0e1bcc74', 1789661173257);
INSERT INTO drizzle.__drizzle_migrations VALUES (2, 'adb93016f2f148c5c1e2943bf50156436f711bfcaa38360e70bedea43da71ead', 1789661180190);
INSERT INTO drizzle.__drizzle_migrations VALUES (3, '2c304a6f92295679243acc99ee45b1e3e742ca3d099a3b216b8045b356703cad', 1789661989851);
INSERT INTO drizzle.__drizzle_migrations VALUES (4, 'b95dbf219f96a657f1e90edf990d6bcc4161512dcd3a6a5dd9fc7752c36d5e9f', 1790114031781);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('5ad64248-18e8-4332-a042-acf09988fde5', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c0dc6f18-b2de-442d-9015-670574c12623', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('e1730310-dd3e-4484-9f77-40d03d020399', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c3a5266b-5284-4766-b920-1259bbc6e8bd', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e009ff35-6be4-497b-a9ed-af3b501bfd50', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'waiting', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('99d185a7-a6c7-4d43-8652-5426f326e2cc', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('fe978d4c-7eb3-44c8-a0c6-685fc3eb8a02', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1043727b-4d16-44a7-b3f5-3d096df30a4a', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.198719+00', '2026-09-22 22:04:08.198719+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a5d2d5de-9f43-4cee-b3f7-fe2b0dab2936', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1168c07d-891f-4214-9ac9-16d3911e27fa', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('25bbd4bd-7f80-4598-8e63-0fb4a2722552', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('666d288f-38f4-4341-9081-9d93ac73415b', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('097af242-8671-4aa7-ae3f-4f46b2e4f25f', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('220c1fd8-6f1b-40a0-ac83-4f14a48d9af8', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('4f4a655c-ecfe-4544-b035-71f0091c467d', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1a100977-456e-4851-ac87-e17e2121e213', 'signage_item', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.228873+00', '2026-09-22 22:04:08.228873+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('4f8e612b-5dfb-4928-b4ee-d48b53809c84', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-12 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-10 22:04:07.797+00', '2026-09-13 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('083b576a-b7b8-4522-99a3-d457483bece1', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-12 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-10 22:04:07.797+00', '2026-09-15 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('95b7becd-fc97-4e88-9323-32bfbaed87c2', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-12 22:04:07.797+00', '2026-09-18 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0ff098e9-e024-4018-87cc-36c9ed3a54e7', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('a798aa83-293a-408d-ad16-2b6ed8d92c8b', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('84e3315a-d2ef-40c7-a94c-013dd24f95ce', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f0d311c2-2073-4387-b6a6-12edd8ff3ee8', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a2a1753b-13dc-4d9c-875d-9ce9c0e2fcdb', 'signage_item', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.262051+00', '2026-09-22 22:04:08.262051+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('eeed0d8d-bbe2-4612-9e95-e01cced988ca', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c1241899-7a75-447b-bb84-7294be1cc4fd', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('ffb20e9d-c428-4ba0-b3b1-40750ccaf87c', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c41d4bf5-b66d-4f4d-90b6-056d21ae00d3', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('d666641a-3a15-4b65-aca3-7a375f13ef47', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('63bb843a-fd48-43a3-9b61-2469a050b422', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('60c1de0a-bec4-4143-987f-835b9a91cfb7', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('cd78ee61-7229-4b61-be82-e7c7141a9f9e', 'signage_item', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.295588+00', '2026-09-22 22:04:08.295588+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('d0ed7d66-49db-458d-9299-9a8e740984f5', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('923b6c4f-ef46-4982-acdb-1391fa839e67', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('87369a78-81e3-4ee0-8435-8ed8ddb7bdda', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('090de4c7-c358-45ca-b83a-2a63cfe925b7', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b2877be0-b993-4f71-b117-30afd1d06f5e', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1202f864-8f94-4ea2-b7e1-43cc5f4c35a0', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('d25b8dc1-1bcc-4f49-aa62-941e3a21a02f', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('26d648c5-6822-485f-b63b-55487b9113bd', 'signage_item', '1964c166-1947-46ce-a173-ea4384ba5693', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.324562+00', '2026-09-22 22:04:08.324562+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('300760d2-1a90-4293-be00-662b2ee7d531', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-12 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-10 22:04:07.797+00', '2026-09-13 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('744de9b4-4651-440e-b29e-fb4ecfce1c19', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('c6220d8a-49dc-4c2a-8a34-defe3035c638', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-12 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-12 22:04:07.797+00', '2026-09-15 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f42ce8a0-09c4-47fc-b0d4-19ae17249585', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('d1e41486-130b-4bfa-b781-aba6769d7e54', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-12 22:04:07.797+00', '2026-09-18 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('fbcc2399-3ab5-4e5a-8aac-ae918289c404', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('00095b65-f2b4-4ea9-864f-c3a2e8089819', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('10704c66-3843-4b74-9607-54483135a529', 'signage_item', '929c3864-1d75-473a-8d72-8891713c5661', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.357248+00', '2026-09-22 22:04:08.357248+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('80237d33-6a76-4b17-b13d-24131480e9e9', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('bad06bd3-a365-47f6-bc38-eee5b00fbe6a', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('22e8da84-3e98-430d-bacd-2432c5dbe411', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1f20c3e0-dc89-4ac3-9045-5f124ee60b4b', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('65a20a81-7ffa-46e1-84df-28c6e18777a4', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a7d3b3e4-e694-43e2-8714-359d9ebd9c3f', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('9d299f78-6ea4-4b95-8565-d649ffeb48ef', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b489ba54-fc2f-4b2e-b627-a06bc5420c75', 'signage_item', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.385263+00', '2026-09-22 22:04:08.385263+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('8516002d-b345-4fbe-b859-8e944df8d54b', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('036a78b4-f6e5-4c43-8f22-95729f79136d', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('9a735f16-8aed-41cf-ac14-d37ee9eec6b6', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('af3d7ff5-ae69-4321-8202-35f15b5c15bf', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8d6fc022-6958-4586-aa11-a3d43d1a0baa', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('83cc7b56-ec72-45e5-a01e-dce95d4ccf0b', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('4fc04679-609d-4cd9-8e24-70fd0e4686e3', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5bcfa188-4af9-4a48-a80a-08f29cdda88f', 'signage_item', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.416468+00', '2026-09-22 22:04:08.416468+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1170a0af-e687-43aa-ae6f-cbef66571047', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e442e2b4-1db2-4997-9cfb-0e8748d66a9c', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'approved_with_conditions', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-19 22:04:07.797+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('01729ebb-db22-4098-858c-baa8c5b70edd', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('115618f0-3241-4deb-b83e-9fbc9ad96b80', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('722554f1-1047-44d1-806c-1a3608d53698', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('160a437b-4dd9-424b-a559-192de64f6ba0', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('1f7b69ed-66e1-4b5a-a70e-bc8d6d3bd1ee', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c15c7933-3b09-4325-be7e-6c8ab4654e86', 'signage_item', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.453019+00', '2026-09-22 22:04:08.453019+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('dac7134e-58b3-4d7d-9d94-cc468bda50a5', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('db54317c-7599-4f58-8129-5624543b6ed7', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('2c282ae5-84a0-4ba8-812f-330767e5bda9', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5f3a4fee-a37a-4912-be4c-91f3854c4a8f', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('2e5d69be-6b82-4e0f-8ea3-cc91ca1e03ed', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('98ea8798-f375-4f90-85a4-f770bcf36941', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('2fa55ca3-9d65-4477-a7a9-1e7d5015e1de', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f5a85104-ec62-4880-86af-15dc9668252f', 'signage_item', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.475018+00', '2026-09-22 22:04:08.475018+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('30db8947-03ad-4fb6-b257-34f297f46742', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('afedbf50-b58d-46d2-a83e-6caa6d7f2332', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('01db6aea-af14-4706-9479-3b27f4671e19', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('84fa3910-2402-4902-b7b7-688326c398d5', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('636d67e7-57fe-4fff-9d8b-756731a6fabe', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0a2cb323-66e7-4796-9efb-0f9ef448b833', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f1b0a6a7-4a5e-4156-aff6-057e59372014', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('05f744ee-992e-43ee-9fb5-ae08a735eaf5', 'signage_item', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.50183+00', '2026-09-22 22:04:08.50183+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('8742425e-7377-404c-b458-eac442049c05', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7def39f2-7231-441c-9ca1-a7d8421d5031', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('ba8cf2f5-786f-493e-aac9-d90e0b9e1669', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('cc8e8af2-4e12-4be1-a068-4742f96abbf6', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b4c490e7-12d1-4a4c-8f80-21a3e09fae40', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1bf7b2b9-b9c4-43d8-9ba6-a531d3cd2540', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('2eee49b7-0804-4707-baad-552e004db38c', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('9ea7a087-0929-4014-b0cc-1f554598170f', 'signage_item', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.522154+00', '2026-09-22 22:04:08.522154+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('51b400fd-1bdb-4481-ac46-4c5783ec1b8a', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0197561c-42da-4135-8fef-2fa196156a73', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('322cffce-421b-4ba4-b3dc-3487b0cff445', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a9ab422d-51d5-4cb4-bd57-ca08564435b7', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('7de7369e-e05b-4ef4-b6f3-7ecf84969790', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('63f434b0-8cca-4941-b6b3-763ded371d09', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('bc99de6b-77a6-40b3-ac02-f638a20a7a05', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('815a96bf-c4fa-4240-b8b0-3c998a1cf742', 'signage_item', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.543588+00', '2026-09-22 22:04:08.543588+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('7a53f580-3afc-4389-8069-678291f042db', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('df86723f-c6cc-47ac-88de-e1eab42b9c3d', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('72b5b4bb-c89c-4af0-b7b0-606523fb9a5a', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('dd17a5e8-929d-405f-b5eb-c717e5edad9f', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('c2f9570a-80b1-455b-8e16-7f8bec6c3504', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1879c478-4fc8-4f9e-a544-7a2f0f231cab', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ee5ec5a8-89e7-42fb-8be0-cc80e30c3071', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('05d803bd-51dc-41e6-a7f9-1c7e59537923', 'signage_item', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.572938+00', '2026-09-22 22:04:08.572938+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a5fa5a13-4741-4d35-88d6-2b0392a62365', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0226ccb8-f0d0-4de5-9ab5-1b9c46bb95e6', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b9f30f45-009b-406e-9899-f2527d7ae346', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b7458bcc-a229-46f2-8770-f616b78b09e7', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('547634c2-c582-4675-bdf1-16fd65941da6', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('016a2b22-9c16-4304-95aa-84df801b2295', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('d2e1241a-66e6-4ccb-8eac-a9d536da2b53', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('63c8399e-d065-4dae-9478-dd7869b04248', 'signage_item', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.595557+00', '2026-09-22 22:04:08.595557+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0d19705f-1c93-4a20-9636-8aae831e092d', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ce394c09-4ed1-419b-8fe5-a85b08b12f3f', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('d7615754-9f25-49f1-98c9-7a38b282daeb', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2554f2d3-b126-4358-9ac4-1d1ce07a9828', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('32233f94-10dd-4b83-961b-daf20b9ff8a4', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0aa37cb4-47d0-4212-8edc-18cdfb59ac83', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-21 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('3c39cba4-d937-4730-8ef9-9b72b043f7a3', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('61103eea-6cda-4d0a-965b-cf45700dd173', 'signage_item', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.617015+00', '2026-09-22 22:04:08.617015+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3c29e291-892a-40c3-a619-29f3bb81bd84', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'rejected', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('dde8af49-6f0e-40bd-91b5-875f4656d63c', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('607a5a6b-5ab2-4175-9a16-6f1fd1fd7d2a', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('00c63c81-7d3a-4526-bb2b-ad0bdc195f44', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('d80b9b39-0ef8-4180-9c89-a15f72f8eaa8', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f7ba8821-2b36-48f0-ace6-033af770fd26', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('67cc9c13-4294-46f0-9d15-379a37e339aa', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0fddb74a-5548-4f9e-b75f-b9973aadd4f5', 'signage_item', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.638614+00', '2026-09-22 22:04:08.638614+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('517f73a0-a166-4128-8022-1094cfd7ef83', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e4563aaf-5af8-4c79-9ef0-b65d370971aa', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('63871f3e-31d1-4b55-a195-22303e9d30fc', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('03278c6a-f95e-48b5-aec1-fae1442e49f1', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('622adfea-2d8b-4696-9b4e-7f07ec9ca67d', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('56beee9e-b04f-4fa1-8318-af83c398bfb6', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('2f49c59b-70d1-457a-a71c-765bd611009c', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c43e7037-3cc8-444f-ac8d-d84919989602', 'signage_item', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.662267+00', '2026-09-22 22:04:08.662267+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6d89b636-0244-4d9d-9d3c-25cd52dd9958', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'invalidated', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5e8e8638-921d-475f-8a98-e003d7f358c2', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 22:04:07.797+00', '2026-09-24 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2525d170-11d9-4f88-a23a-6780be67daec', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'invalidated', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('8ef17640-28a3-46ce-b62d-463760db2e22', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('5c97d0c1-76ec-49fb-8385-dea12ce37064', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'invalidated', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3716596c-de99-41bc-845e-4f53ff6b08b5', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('4ff147e7-820a-47dc-8008-5037da2cb9e8', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e4423409-abdd-4f94-88d3-4034aa051fed', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2bb50bfe-b6e0-4d3a-8af3-319530be6ab8', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('a1a41b7c-2988-4c03-8c0a-9838eb7c13bf', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e378722c-cfe7-4c07-8249-1f3062dca3aa', 'signage_item', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.692401+00', '2026-09-22 22:04:08.692401+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f09fa249-4c98-4eab-abee-740612f3984e', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c76ba0c6-3870-4919-bf33-67591422d49e', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('7c9fc949-c4e9-4e9d-bfff-25cc4d39f129', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('6e968275-ec2a-4e89-b06b-a2d97924ff62', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('53f6832f-664d-4c45-ab84-f3ab7487bf60', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c8a0c42d-a4c4-4a0e-a07e-412e4dbaee16', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('96c81bbc-4543-4be5-b3b9-9720fc7a8a26', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3187baef-df5b-4767-81ea-07191e97d5e7', 'signage_item', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.758694+00', '2026-09-22 22:04:08.758694+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('44824ab9-2397-4fa4-b2c1-b1ed1f55268a', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2e8aeb80-ec75-42ed-8b58-6266220b0b5e', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('3f77cf51-d04f-427e-a740-b6550e139a09', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a2a7cdf3-1971-4ee5-996a-b30c6a1decd4', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-19 22:04:07.797+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-26 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('0fa6e076-6cdb-499b-a3bf-274894084c36', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9ed9c8ea-e2fe-4e17-bcd0-fe9539bfbd04', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('19f83c09-4d4b-4dd9-ac9f-65be1bcdddb4', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e60667ec-63d0-440c-ae73-8e3a8e005fce', 'signage_item', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.780956+00', '2026-09-22 22:04:08.780956+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('514e489f-6215-48d1-939b-396b5d1dd3bd', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, 'd9a649d4-4c47-4845-8ab5-d85503c30285', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('850febf7-1bea-486b-9885-4185704dc4c2', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, '941badea-b72c-406e-8964-ee26f65879bf', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 22:04:07.797+00', '2026-09-22 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('4888b76d-6727-40c3-893a-7ab8356ed106', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, '6c5cd0f3-72e2-4183-bc18-397ed3fc626e', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c075b9e1-5ecd-401a-b405-a3415b28c5cc', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, 'b2d98ce3-cec8-45f7-9a95-7c119b8a122f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b522cde7-06eb-4353-9340-0a84d06df2eb', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, 'fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('dfd5935f-374c-49d1-8ef8-7673a1d7619e', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, 'f8af35dc-e202-4528-8fc3-4abe2c320914', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('be2131bc-aee9-4d10-a816-9864586e7d23', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, '76930ae9-e543-4890-95b1-33b06f8bca22', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('38251c8e-64ac-4506-9e88-c58594d712c6', 'signage_item', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, '6f8b4a5b-dfbe-44f1-a95b-0448b5812656', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.806968+00', '2026-09-22 22:04:08.806968+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0844b8d3-b3f0-4a53-b4f0-6e4b023d3603', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, '90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-16 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('4f471943-0649-4954-96da-65831ba51012', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, 'cea38c40-70af-424f-98b0-3fb854c21966', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-18 22:04:07.797+00', '2026-09-25 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6c32e7a6-4840-434d-b50a-fd2648ffc01c', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, '12bb7737-67d3-46c9-b85f-b85908305782', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('634c5de0-6fd1-4c7d-8635-4c5841834dd2', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, '55b1e82f-daaf-42e4-86fb-048f32257cda', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('89ccac93-ee4e-440d-ba96-d96cde75cef4', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, '3d5d60d1-7f54-4c3d-898d-153581cc0090', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('39640f85-a79b-46a1-af80-17b1d54b209b', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 1, '371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('89bbb99e-1295-4dad-a480-84b8d094456f', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, '90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-16 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('421bebfc-ee95-4a67-9451-ed5df3070c6a', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, 'cea38c40-70af-424f-98b0-3fb854c21966', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8c02e476-6b79-41e8-bf46-64887bbadf28', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, '12bb7737-67d3-46c9-b85f-b85908305782', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('884d8c82-cc36-470a-93eb-4e0cd8d090e9', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, '55b1e82f-daaf-42e4-86fb-048f32257cda', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('23d80464-a05a-439b-97e6-6d5baa247b50', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, '3d5d60d1-7f54-4c3d-898d-153581cc0090', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('c9245cad-dda6-48c2-9e73-5116a3e93aac', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 1, '371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('927e45c8-f136-4643-9b38-f26280b9e6ef', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, '90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-16 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('27a38cfb-edd9-4c28-8d69-db79ce7c88bc', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, 'cea38c40-70af-424f-98b0-3fb854c21966', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('c9b9684f-d855-4fb3-97c7-4798365e9d72', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, '12bb7737-67d3-46c9-b85f-b85908305782', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('3e3af084-21a6-4801-8970-ecb17cb86732', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, '55b1e82f-daaf-42e4-86fb-048f32257cda', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('be115154-1f9d-455a-99f2-53bb7e4c4a3f', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, '3d5d60d1-7f54-4c3d-898d-153581cc0090', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('344db5fa-b008-45ce-b061-e1a13ad10902', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 1, '371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b6fe37c3-ce07-480a-ba8e-dd24e8ef07e6', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, '90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-16 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9be77688-cb17-46b0-baaf-06e9b51bec48', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, 'cea38c40-70af-424f-98b0-3fb854c21966', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('48624f2f-2509-4647-8490-58c67b5e59f8', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, '12bb7737-67d3-46c9-b85f-b85908305782', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-23 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('0533b4a3-e0fc-4f30-80eb-ef124ea57de6', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, '55b1e82f-daaf-42e4-86fb-048f32257cda', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-25 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('7c8f7f9b-ecd4-467c-bf8c-c8c296dc9739', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, '3d5d60d1-7f54-4c3d-898d-153581cc0090', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('8b81b9b2-7294-48ce-9dd8-e4f8f7ab816b', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 1, '371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-18 22:04:07.797+00', '2026-09-18 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f8e9a73a-5b84-4417-890b-8387d432a60c', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, '90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-16 22:04:07.797+00', '2026-09-19 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('827abac7-aa06-4acf-beed-5c375c4c010d', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, 'cea38c40-70af-424f-98b0-3fb854c21966', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('550d01a8-0b58-424c-858f-28a654957354', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, '12bb7737-67d3-46c9-b85f-b85908305782', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-23 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('20575eb7-e334-4143-931b-bc1b1a6bb450', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, '55b1e82f-daaf-42e4-86fb-048f32257cda', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-25 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('fc0fe707-2ea9-4665-b591-b51f6bc8ec55', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, '3d5d60d1-7f54-4c3d-898d-153581cc0090', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-18 22:04:07.797+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 22:04:07.797+00', '2026-09-20 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('946b8061-7e58-4f8d-b663-34d40bdd99d3', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 1, '371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-18 22:04:07.797+00', '2026-09-18 22:04:07.797+00', 0, NULL, NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00', false, true, 0, false);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('24f3759f-70b8-41aa-b2ec-0dd108561616', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.193761+00', '2026-09-22 22:04:08.193761+00');
INSERT INTO public.artwork_versions VALUES ('7824adb6-4075-41ed-8d8b-0f2b3593a82d', '2977a429-c9c3-451d-b3f1-045d3e53bb34', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.22238+00', '2026-09-22 22:04:08.22238+00');
INSERT INTO public.artwork_versions VALUES ('19b88e73-e35e-497e-be93-419486729087', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-22 22:04:08.253184+00', '2026-09-22 22:04:08.253184+00');
INSERT INTO public.artwork_versions VALUES ('1e1a6582-c68c-4789-a297-21eb9e95cce7', '009c5b2b-1d10-4267-ba32-b77eafe06abe', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.256138+00', '2026-09-22 22:04:08.256138+00');
INSERT INTO public.artwork_versions VALUES ('f1850ee5-a46f-4349-91cd-e076175594e6', '7d61fec3-f1f3-4885-959d-3523b0ddde4c', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.287449+00', '2026-09-22 22:04:08.287449+00');
INSERT INTO public.artwork_versions VALUES ('58e4be37-f74d-412b-bcd8-eb3fbe39fb68', '1964c166-1947-46ce-a173-ea4384ba5693', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.319812+00', '2026-09-22 22:04:08.319812+00');
INSERT INTO public.artwork_versions VALUES ('9bcd76d0-cdf9-4985-86df-2ab6a2aa9a73', '929c3864-1d75-473a-8d72-8891713c5661', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.352618+00', '2026-09-22 22:04:08.352618+00');
INSERT INTO public.artwork_versions VALUES ('c7210b66-281b-4071-a032-97c87a8bd655', '6980c6fe-7a8b-4e15-846e-b86fc517a677', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.382193+00', '2026-09-22 22:04:08.382193+00');
INSERT INTO public.artwork_versions VALUES ('732f11d4-a68e-4ed1-94fa-b038b8daa3ee', 'a0b3b007-3c7d-465f-b25a-ea223f2aff98', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.409737+00', '2026-09-22 22:04:08.409737+00');
INSERT INTO public.artwork_versions VALUES ('8a463714-262e-4fe7-a929-d1ff46072a96', '2c865569-6050-4d10-bee8-5bed03eb643f', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.448792+00', '2026-09-22 22:04:08.448792+00');
INSERT INTO public.artwork_versions VALUES ('3e563949-d95d-448e-881c-5d017c76ce13', 'b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.472003+00', '2026-09-22 22:04:08.472003+00');
INSERT INTO public.artwork_versions VALUES ('dc68932b-1a37-4341-8812-0891d7009afe', '1ca24aa8-39d2-4463-b7fc-b50010476a9e', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.496151+00', '2026-09-22 22:04:08.496151+00');
INSERT INTO public.artwork_versions VALUES ('5e3f27e8-5049-453a-9131-6ff9c0326129', '71d03ae2-ebeb-41b6-b530-ab121fc4578d', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.518902+00', '2026-09-22 22:04:08.518902+00');
INSERT INTO public.artwork_versions VALUES ('40754e2d-3759-4cc8-91cd-f8b609b46c16', 'f90da0b1-c989-4475-bc09-01cf253493dc', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.53929+00', '2026-09-22 22:04:08.53929+00');
INSERT INTO public.artwork_versions VALUES ('41bce6e0-7a8d-46b6-8fc0-f7c0879675a6', '94c917e7-d75c-4579-90bc-2f40126602e9', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.565372+00', '2026-09-22 22:04:08.565372+00');
INSERT INTO public.artwork_versions VALUES ('a34fc688-34a5-487d-ac01-02436270184f', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.59264+00', '2026-09-22 22:04:08.59264+00');
INSERT INTO public.artwork_versions VALUES ('eb275c22-dd6c-49b9-8c25-6fc989d2e67a', '9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.613448+00', '2026-09-22 22:04:08.613448+00');
INSERT INTO public.artwork_versions VALUES ('d35bceb3-cf9e-4a03-9bff-28b4e3dc160e', 'f90dcaf1-0e17-405f-b62b-da9e78a17292', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.634855+00', '2026-09-22 22:04:08.634855+00');
INSERT INTO public.artwork_versions VALUES ('b159909c-3ea0-4f32-a18d-932c9356756f', 'ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.658996+00', '2026-09-22 22:04:08.658996+00');
INSERT INTO public.artwork_versions VALUES ('f573d405-0efe-46d7-bf16-751d55c5e612', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-22 22:04:08.683057+00', '2026-09-22 22:04:08.683057+00');
INSERT INTO public.artwork_versions VALUES ('e1a6c980-18f2-42b5-a308-798d9f8430c8', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-22 22:04:08.685987+00', '2026-09-22 22:04:08.685987+00');
INSERT INTO public.artwork_versions VALUES ('7218b7ed-af6e-4840-b822-1ce45a79d091', '15b2cfe4-a7cc-404a-8404-cfd193390a89', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.688352+00', '2026-09-22 22:04:08.688352+00');
INSERT INTO public.artwork_versions VALUES ('c1e3f801-384c-46c0-990a-c6af32de7367', '56eaa73d-a7b5-4751-ad2c-d94063065499', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-22 22:04:08.755961+00', '2026-09-22 22:04:08.755961+00');
INSERT INTO public.artwork_versions VALUES ('ca0aad0a-9c49-4166-a257-bd77fb7b414b', '5314baa3-4f26-433e-9dae-bc62ef959ea7', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.77773+00', '2026-09-22 22:04:08.77773+00');
INSERT INTO public.artwork_versions VALUES ('66ef2c0d-2fab-432a-a271-86dac7588693', 'b6da625a-0336-46a7-9847-c63d0e45c2a9', 1, 'seed/SIG-BIRM27-900-v1.pdf', 'SIG-BIRM27-900-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-22 22:04:08.802631+00', '2026-09-22 22:04:08.802631+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: change_requests; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: comment_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: contractors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.contractors VALUES ('237e9d0f-8083-4c50-b07c-201bd607c633', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-22 22:04:07.983712+00', '2026-09-22 22:04:07.983712+00');
INSERT INTO public.contractors VALUES ('bea315c3-17ea-413d-9035-ac2efab588e4', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-22 22:04:07.987696+00', '2026-09-22 22:04:07.987696+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('ef016473-be5b-4a44-b8a4-49aa9d972b29', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00');
INSERT INTO public.documents VALUES ('bff90195-ea98-4b67-b10a-792aaa2a0179', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00');
INSERT INTO public.documents VALUES ('babd0a80-cc96-4a41-96e0-32ab0098e323', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00');
INSERT INTO public.documents VALUES ('e762a41e-d614-48e3-95cb-5108b0c1db25', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '48b28d64-2b9f-4442-bc34-057f6b86e4e4', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00');
INSERT INTO public.documents VALUES ('7b7d8ed8-7a11-4dee-a7e7-e93943f4a336', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00');
INSERT INTO public.documents VALUES ('6f369814-29bd-48ad-81a7-d2eb74f13d44', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00');
INSERT INTO public.documents VALUES ('b5e0eccb-a407-4668-b047-46b1c6e2467e', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00');
INSERT INTO public.documents VALUES ('b016f295-e824-4c8e-b2e0-eb9cb5194202', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'ffa464be-7a41-447e-915b-885df907d272', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00');
INSERT INTO public.documents VALUES ('a41e72ba-ec26-4880-9499-7331f3e3f28b', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00');
INSERT INTO public.documents VALUES ('54e3a9ac-2125-4961-a58b-787544aef3c9', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00');
INSERT INTO public.documents VALUES ('5a468e32-8c62-431a-bd80-d36a4e3fc5d9', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00');
INSERT INTO public.documents VALUES ('afe4ab59-5a69-4f1e-8072-e9bbb29c468a', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '57e42457-5460-4365-9e51-1e3810db7b09', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00');
INSERT INTO public.documents VALUES ('c29d84a4-fb2d-4acb-b308-d9c5252e12c2', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00');
INSERT INTO public.documents VALUES ('e4c570c2-84e4-4442-a1e5-043ecca67161', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00');
INSERT INTO public.documents VALUES ('45c07686-0de6-4195-8815-78bfb9e08561', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00');
INSERT INTO public.documents VALUES ('28a816c2-a225-4ab4-9b09-085a60d54b21', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', 'f34686c3-d177-49b8-97b0-2b009d72b168', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00');
INSERT INTO public.documents VALUES ('6d72d34d-748d-476f-9de3-3cd65f1e781f', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00');
INSERT INTO public.documents VALUES ('251f3663-589e-4ff3-b1b6-c6fc5e9c293e', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00');
INSERT INTO public.documents VALUES ('611d6e3c-17e1-4123-af3f-1861701b939a', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00');
INSERT INTO public.documents VALUES ('4014f6c3-cc09-43f8-aea9-3f1e3bb84d0c', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_submission', '414696cc-e406-4f0f-9ed1-3d2f0baead31', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('64f1a858-b949-41d2-a127-bd4ac55d42ca', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'signage', 30, '2026-09-22 22:04:08.826696+00', '2026-09-22 22:04:08.826696+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('62ceb230-187b-4186-a152-7261845e5d06', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-22 22:04:07.898484+00', '2026-09-22 22:04:07.898484+00');
INSERT INTO public.edition_deadlines VALUES ('083d1a12-9b19-4b4a-8484-22e2de649b42', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-22 22:04:07.901187+00', '2026-09-22 22:04:07.901187+00');
INSERT INTO public.edition_deadlines VALUES ('94a6128b-3744-42dc-9794-b8facba8b660', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-22 22:04:07.903517+00', '2026-09-22 22:04:07.903517+00');
INSERT INTO public.edition_deadlines VALUES ('ba4db93a-2cda-4411-9504-0d977877ff55', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-22 22:04:07.905427+00', '2026-09-22 22:04:07.905427+00');
INSERT INTO public.edition_deadlines VALUES ('0263b29c-e68b-4423-823e-d3a8b62b18b2', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-22 22:04:07.907414+00', '2026-09-22 22:04:07.907414+00');
INSERT INTO public.edition_deadlines VALUES ('dbd22068-649d-4324-9e7c-bf1e564d7a29', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-22 22:04:07.909026+00', '2026-09-22 22:04:07.909026+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('f2a78acb-1259-4cfe-bf19-8403581e9090', '9d0a9e2d-fd17-4ef9-9884-d2e7caebd83c', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-22 22:04:07.894969+00', '2026-09-22 22:04:07.894969+00');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('9d0a9e2d-fd17-4ef9-9884-d2e7caebd83c', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'UK Construction Week', 'UKCW', '2026-09-22 22:04:07.859195+00', '2026-09-22 22:04:07.859195+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('ed49a91f-ed15-4151-a50f-d2ce128689df', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Exhibitor Co', 'A10', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '237e9d0f-8083-4c50-b07c-201bd607c633', '2026-09-22 22:04:08.118762+00', '2026-09-22 22:04:08.118762+00');
INSERT INTO public.exhibitors VALUES ('07bd6559-0326-43e5-b788-acdb815eb91e', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SteelFrame Systems', 'A20', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'bea315c3-17ea-413d-9035-ac2efab588e4', '2026-09-22 22:04:08.129229+00', '2026-09-22 22:04:08.129229+00');
INSERT INTO public.exhibitors VALUES ('06816d23-34ef-47b6-9a85-53b9f1ec3102', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'BrickWorks UK', 'A30', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '237e9d0f-8083-4c50-b07c-201bd607c633', '2026-09-22 22:04:08.136533+00', '2026-09-22 22:04:08.136533+00');
INSERT INTO public.exhibitors VALUES ('7f52516d-8c99-4edc-a48f-0c70f8797952', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Timber Trade Ltd', 'B10', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'bea315c3-17ea-413d-9035-ac2efab588e4', '2026-09-22 22:04:08.141845+00', '2026-09-22 22:04:08.141845+00');
INSERT INTO public.exhibitors VALUES ('832dfe3b-4263-450f-bf46-aea81fa04ad3', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'GlassTech', 'B20', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '237e9d0f-8083-4c50-b07c-201bd607c633', '2026-09-22 22:04:08.14484+00', '2026-09-22 22:04:08.14484+00');
INSERT INTO public.exhibitors VALUES ('4311a92e-e625-4592-b174-c964dd5a8e13', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Insulate Pro', 'B30', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'bea315c3-17ea-413d-9035-ac2efab588e4', '2026-09-22 22:04:08.149613+00', '2026-09-22 22:04:08.149613+00');
INSERT INTO public.exhibitors VALUES ('b387299f-d79e-42c0-b262-4aa9b6164bee', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'RoofRight', 'C10', '979fdc93-f8c7-4356-a368-a38767444ec7', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '237e9d0f-8083-4c50-b07c-201bd607c633', '2026-09-22 22:04:08.152984+00', '2026-09-22 22:04:08.152984+00');
INSERT INTO public.exhibitors VALUES ('29ba277c-45e9-4ed9-9db7-2d46f07e2541', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'PlantHire Direct', 'C20', '979fdc93-f8c7-4356-a368-a38767444ec7', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'bea315c3-17ea-413d-9035-ac2efab588e4', '2026-09-22 22:04:08.156172+00', '2026-09-22 22:04:08.156172+00');
INSERT INTO public.exhibitors VALUES ('7b30c9bf-5fff-4ee5-9f75-016cafbbf12b', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SafetyFirst PPE', 'D10', '979fdc93-f8c7-4356-a368-a38767444ec7', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-22 22:04:08.162555+00', '2026-09-22 22:04:08.162555+00');
INSERT INTO public.exhibitors VALUES ('45f3b802-0191-4e0f-9954-27de0f84b07e', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'ToolMart Retail', 'D20', '979fdc93-f8c7-4356-a368-a38767444ec7', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-22 22:04:08.167157+00', '2026-09-22 22:04:08.167157+00');
INSERT INTO public.exhibitors VALUES ('e0efe2d5-91c4-46a0-ab9c-7bbe7bd70b12', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'EcoBuild Materials', 'D30', '979fdc93-f8c7-4356-a368-a38767444ec7', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-22 22:04:08.170843+00', '2026-09-22 22:04:08.170843+00');
INSERT INTO public.exhibitors VALUES ('43a6358a-a656-43f4-b78e-968e3ae33ef3', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SiteWise Software', 'D40', '979fdc93-f8c7-4356-a368-a38767444ec7', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-22 22:04:08.174309+00', '2026-09-22 22:04:08.174309+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('90e937e1-6d9f-4a00-ab6e-f24957f477c4', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'venue', 'venue', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.083561+00', '2026-09-22 22:04:08.083561+00');
INSERT INTO public.external_grants VALUES ('122a3ff1-5c74-4ee2-8f9c-9bbb35589f56', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.094437+00', '2026-09-22 22:04:08.094437+00');
INSERT INTO public.external_grants VALUES ('707d04bf-6f3a-44a4-82d9-0bf5a77c0468', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.099741+00', '2026-09-22 22:04:08.099741+00');
INSERT INTO public.external_grants VALUES ('06a882b4-6c86-41c8-bafa-937e5c296e5e', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'supplier', 'supplier', '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.10923+00', '2026-09-22 22:04:08.10923+00');
INSERT INTO public.external_grants VALUES ('334c2113-712c-4fa4-a3b2-7ddac6ee12f9', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'sponsor', 'sponsor', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.114328+00', '2026-09-22 22:04:08.114328+00');
INSERT INTO public.external_grants VALUES ('ef60c26f-dc66-47ab-a79a-b568a33546e7', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'exhibitor', 'exhibitor', 'ed49a91f-ed15-4151-a50f-d2ce128689df', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-22 22:04:07.797+00', NULL, '2026-09-22 22:04:08.178412+00', '2026-09-22 22:04:08.178412+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('ef33167d-e615-4e8d-a10a-0a1b8379230f', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-22 22:04:07.912687+00', '2026-09-22 22:04:07.912687+00');
INSERT INTO public.halls VALUES ('979fdc93-f8c7-4356-a368-a38767444ec7', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-22 22:04:07.916396+00', '2026-09-22 22:04:07.916396+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('489fc7fe-29f7-4c9c-ae9c-e4960d17154a', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Hanging banner', 'hanging_banner', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'rigged', true, 0, '2026-09-22 22:04:08.051884+00', '2026-09-22 22:04:08.051884+00', 'signage');
INSERT INTO public.item_types VALUES ('e216b05e-d2e1-4b5c-a928-a088a2784390', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Foamex board', 'foamex_board', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'wall_mounted', false, 1, '2026-09-22 22:04:08.055132+00', '2026-09-22 22:04:08.055132+00', 'signage');
INSERT INTO public.item_types VALUES ('4c61d3df-80e5-4e61-9b4a-e9521fe35ad9', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Fabric graphic', 'fabric_graphic', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'shell_mounted', false, 2, '2026-09-22 22:04:08.057591+00', '2026-09-22 22:04:08.057591+00', 'signage');
INSERT INTO public.item_types VALUES ('b0fcb2ca-96c7-49ae-834b-c07ce5ef44c3', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Floor vinyl', 'floor_vinyl', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'floor', false, 3, '2026-09-22 22:04:08.059789+00', '2026-09-22 22:04:08.059789+00', 'signage');
INSERT INTO public.item_types VALUES ('e63d5918-899a-4b43-8267-8dbca376133e', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Aisle sign', 'aisle_sign', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'rigged', true, 4, '2026-09-22 22:04:08.061626+00', '2026-09-22 22:04:08.061626+00', 'signage');
INSERT INTO public.item_types VALUES ('f8c5fd78-41fe-4354-9d87-385761c61a17', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Entrance feature', 'entrance_feature', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'freestanding', true, 5, '2026-09-22 22:04:08.063449+00', '2026-09-22 22:04:08.063449+00', 'signage');
INSERT INTO public.item_types VALUES ('3780ba30-aee0-4543-bd74-2a53df5fa639', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Registration', 'registration', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'freestanding', false, 6, '2026-09-22 22:04:08.065389+00', '2026-09-22 22:04:08.065389+00', 'signage');
INSERT INTO public.item_types VALUES ('11bedcd0-81f2-43f6-bdbd-df6d1e10ff55', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Seminar theatre', 'seminar_theatre', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'freestanding', false, 7, '2026-09-22 22:04:08.067486+00', '2026-09-22 22:04:08.067486+00', 'signage');
INSERT INTO public.item_types VALUES ('903306bf-fc57-4dad-a6c1-3408c498a2b9', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Feature area', 'feature_area', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'freestanding', false, 8, '2026-09-22 22:04:08.069043+00', '2026-09-22 22:04:08.069043+00', 'signage');
INSERT INTO public.item_types VALUES ('eb204dd6-abcb-400f-bb3e-64c9e5a593e2', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'External', 'external', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'freestanding', true, 9, '2026-09-22 22:04:08.071277+00', '2026-09-22 22:04:08.071277+00', 'signage');
INSERT INTO public.item_types VALUES ('ef4f13e9-4598-4f19-8399-069702f6ed02', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Digital screen', 'digital_screen', '80e169af-df8b-4b50-98bd-3570454ad1d6', 'digital', false, 10, '2026-09-22 22:04:08.073173+00', '2026-09-22 22:04:08.073173+00', 'signage');
INSERT INTO public.item_types VALUES ('13622f3e-d04e-40aa-afce-40a3d6a47c0d', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Branded lanyards', 'lanyard', '80e169af-df8b-4b50-98bd-3570454ad1d6', NULL, false, 11, '2026-09-22 22:04:08.075029+00', '2026-09-22 22:04:08.075029+00', 'sponsorship_item');
INSERT INTO public.item_types VALUES ('e06f625a-c9ab-475a-97a4-6e37f488daed', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Show bags', 'show_bag', '80e169af-df8b-4b50-98bd-3570454ad1d6', NULL, false, 12, '2026-09-22 22:04:08.076784+00', '2026-09-22 22:04:08.076784+00', 'sponsorship_item');
INSERT INTO public.item_types VALUES ('175c05fb-5217-432f-b912-fc6b2a80d974', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Registration branding', 'reg_branding', '80e169af-df8b-4b50-98bd-3570454ad1d6', NULL, false, 13, '2026-09-22 22:04:08.07849+00', '2026-09-22 22:04:08.07849+00', 'sponsorship_item');


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('3952c483-2f8e-4687-8eb5-b38f0af41eaf', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-22 22:04:07.920252+00', '2026-09-22 22:04:07.920252+00');
INSERT INTO public.locations VALUES ('897c608c-6617-4ab7-aeba-dcbdeeffda10', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-22 22:04:07.924921+00', '2026-09-22 22:04:07.924921+00');
INSERT INTO public.locations VALUES ('c8c4cf7f-4d87-4859-bcf7-13bc4f12c748', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-22 22:04:07.92777+00', '2026-09-22 22:04:07.92777+00');
INSERT INTO public.locations VALUES ('61349fe1-ae87-41fb-8bae-df6da3e797b7', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-22 22:04:07.932216+00', '2026-09-22 22:04:07.932216+00');
INSERT INTO public.locations VALUES ('24b389b9-6f34-4af9-8262-a1c72a34491e', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-22 22:04:07.935333+00', '2026-09-22 22:04:07.935333+00');
INSERT INTO public.locations VALUES ('a4d54987-fcc0-4e34-9db8-12149c0720a3', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-22 22:04:07.940328+00', '2026-09-22 22:04:07.940328+00');
INSERT INTO public.locations VALUES ('8a5716b2-dd46-47f0-b650-4f72e28d0a1f', '979fdc93-f8c7-4356-a368-a38767444ec7', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-22 22:04:07.944312+00', '2026-09-22 22:04:07.944312+00');
INSERT INTO public.locations VALUES ('2479295d-6ff1-4963-94df-81944bf8b341', '979fdc93-f8c7-4356-a368-a38767444ec7', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-22 22:04:07.948888+00', '2026-09-22 22:04:07.948888+00');
INSERT INTO public.locations VALUES ('c62d987a-27f4-4965-8b14-b7312032e414', '979fdc93-f8c7-4356-a368-a38767444ec7', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-22 22:04:07.951847+00', '2026-09-22 22:04:07.951847+00');
INSERT INTO public.locations VALUES ('afe55480-6e21-4cd8-92c8-76cc3d53ee36', '979fdc93-f8c7-4356-a368-a38767444ec7', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-22 22:04:07.954797+00', '2026-09-22 22:04:07.954797+00');
INSERT INTO public.locations VALUES ('ac44e718-b16b-414a-8e7c-0abc44265236', '979fdc93-f8c7-4356-a368-a38767444ec7', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-22 22:04:07.958459+00', '2026-09-22 22:04:07.958459+00');
INSERT INTO public.locations VALUES ('5f0c31cc-718b-49eb-a0ce-7c822c9ecd9d', '979fdc93-f8c7-4356-a368-a38767444ec7', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-22 22:04:07.962404+00', '2026-09-22 22:04:07.962404+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('71a780ed-2f38-4067-a046-996b1c9cddc6', '00000000-0000-4000-8000-000000000001', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'admin', '2026-09-22 22:04:07.834316+00', '2026-09-22 22:04:07.834316+00', '{}');
INSERT INTO public.memberships VALUES ('68f6ca84-9859-4ce6-922d-15cce51f7e7d', '00000000-0000-4000-8000-000000000002', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'ops', '2026-09-22 22:04:07.839686+00', '2026-09-22 22:04:07.839686+00', '{}');
INSERT INTO public.memberships VALUES ('ee348aa2-24f1-424e-b08d-7b96e0666314', '00000000-0000-4000-8000-000000000004', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'sales', '2026-09-22 22:04:07.849617+00', '2026-09-22 22:04:07.849617+00', '{}');
INSERT INTO public.memberships VALUES ('1430d946-4c10-4bbb-a581-067718350667', '00000000-0000-4000-8000-000000000005', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'event_director', '2026-09-22 22:04:07.853975+00', '2026-09-22 22:04:07.853975+00', '{}');
INSERT INTO public.memberships VALUES ('2300a8ce-23fa-424c-a5f2-6f94af9d6678', '00000000-0000-4000-8000-000000000006', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'viewer', '2026-09-22 22:04:07.857042+00', '2026-09-22 22:04:07.857042+00', '{}');
INSERT INTO public.memberships VALUES ('e231057b-b59a-4988-b3ce-8858924f0c3c', '00000000-0000-4000-8000-000000000003', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'marketing', '2026-09-22 22:04:07.843699+00', '2026-09-22 22:04:08.942886+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('ebe00c58-c215-4883-9ff8-71222f85a87d', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-22 22:04:07.8255+00', '2026-09-22 22:04:07.8255+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'f8c5fd78-41fe-4354-9d87-385761c61a17', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '3952c483-2f8e-4687-8eb5-b38f0af41eaf', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', '8d040533-d4d4-454d-b856-cc9d89519dd3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '24f3759f-70b8-41aa-b2ec-0dd108561616', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.186135+00', '2026-09-22 22:04:08.195806+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('2977a429-c9c3-451d-b3f1-045d3e53bb34', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '3780ba30-aee0-4543-bd74-2a53df5fa639', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '897c608c-6617-4ab7-aeba-dcbdeeffda10', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '7824adb6-4075-41ed-8d8b-0f2b3593a82d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.219237+00', '2026-09-22 22:04:08.225023+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('009c5b2b-1d10-4267-ba32-b77eafe06abe', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '489fc7fe-29f7-4c9c-ae9c-e4960d17154a', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'c8c4cf7f-4d87-4859-bcf7-13bc4f12c748', 'ops', '00000000-0000-4000-8000-000000000002', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', 'aaa805ab-359d-4f6b-b706-8c428bedbd59', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '1e1a6582-c68c-4789-a297-21eb9e95cce7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.25042+00', '2026-09-22 22:04:08.259957+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('7d61fec3-f1f3-4885-959d-3523b0ddde4c', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '11bedcd0-81f2-43f6-bdbd-df6d1e10ff55', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '61349fe1-ae87-41fb-8bae-df6da3e797b7', 'marketing', '00000000-0000-4000-8000-000000000003', 'baf9b4ce-d6f2-4ec3-9f26-935e49f49052', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'f1850ee5-a46f-4349-91cd-e076175594e6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.284597+00', '2026-09-22 22:04:08.292772+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('1964c166-1947-46ce-a173-ea4384ba5693', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', 'b0fcb2ca-96c7-49ae-834b-c07ce5ef44c3', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '24b389b9-6f34-4af9-8262-a1c72a34491e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '58e4be37-f74d-412b-bcd8-eb3fbe39fb68', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.316422+00', '2026-09-22 22:04:08.32215+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('929c3864-1d75-473a-8d72-8891713c5661', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '903306bf-fc57-4dad-a6c1-3408c498a2b9', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'a4d54987-fcc0-4e34-9db8-12149c0720a3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '9bcd76d0-cdf9-4985-86df-2ab6a2aa9a73', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.348246+00', '2026-09-22 22:04:08.354858+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('6980c6fe-7a8b-4e15-846e-b86fc517a677', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '489fc7fe-29f7-4c9c-ae9c-e4960d17154a', '979fdc93-f8c7-4356-a368-a38767444ec7', '8a5716b2-dd46-47f0-b650-4f72e28d0a1f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'c7210b66-281b-4071-a032-97c87a8bd655', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.379259+00', '2026-09-22 22:04:08.383641+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('a0b3b007-3c7d-465f-b25a-ea223f2aff98', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', 'e63d5918-899a-4b43-8267-8dbca376133e', '979fdc93-f8c7-4356-a368-a38767444ec7', '2479295d-6ff1-4963-94df-81944bf8b341', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '732f11d4-a68e-4ed1-94fa-b038b8daa3ee', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.406912+00', '2026-09-22 22:04:08.411784+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('2c865569-6050-4d10-bee8-5bed03eb643f', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '11bedcd0-81f2-43f6-bdbd-df6d1e10ff55', '979fdc93-f8c7-4356-a368-a38767444ec7', 'c62d987a-27f4-4965-8b14-b7312032e414', 'marketing', '00000000-0000-4000-8000-000000000003', 'baf9b4ce-d6f2-4ec3-9f26-935e49f49052', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '8a463714-262e-4fe7-a929-d1ff46072a96', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.443828+00', '2026-09-22 22:04:08.451023+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('b6fb03ea-79ad-49ac-b9d2-512dd74c1cb0', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '4c61d3df-80e5-4e61-9b4a-e9521fe35ad9', '979fdc93-f8c7-4356-a368-a38767444ec7', 'afe55480-6e21-4cd8-92c8-76cc3d53ee36', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '3e563949-d95d-448e-881c-5d017c76ce13', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.470252+00', '2026-09-22 22:04:08.473609+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('1ca24aa8-39d2-4463-b7fc-b50010476a9e', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'eb204dd6-abcb-400f-bb3e-64c9e5a593e2', '979fdc93-f8c7-4356-a368-a38767444ec7', 'ac44e718-b16b-414a-8e7c-0abc44265236', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'dc68932b-1a37-4341-8812-0891d7009afe', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.493976+00', '2026-09-22 22:04:08.497828+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('71d03ae2-ebeb-41b6-b530-ab121fc4578d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', '979fdc93-f8c7-4356-a368-a38767444ec7', '5f0c31cc-718b-49eb-a0ce-7c822c9ecd9d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '5e3f27e8-5049-453a-9131-6ff9c0326129', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.517161+00', '2026-09-22 22:04:08.520554+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('f90da0b1-c989-4475-bc09-01cf253493dc', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'ef4f13e9-4598-4f19-8399-069702f6ed02', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '897c608c-6617-4ab7-aeba-dcbdeeffda10', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '125638d9-f7cb-4a90-94d7-fa1b24a01edd', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '40754e2d-3759-4cc8-91cd-f8b609b46c16', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.536586+00', '2026-09-22 22:04:08.541666+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('94c917e7-d75c-4579-90bc-2f40126602e9', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', 'e63d5918-899a-4b43-8267-8dbca376133e', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'c8c4cf7f-4d87-4859-bcf7-13bc4f12c748', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '41bce6e0-7a8d-46b6-8fc0-f7c0879675a6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.56047+00', '2026-09-22 22:04:08.571001+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('05aecd12-1536-49ec-bfc7-d6aba25c6a45', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '24b389b9-6f34-4af9-8262-a1c72a34491e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'a34fc688-34a5-487d-ac01-02436270184f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.590194+00', '2026-09-22 22:04:08.593967+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('9d75524f-66ba-4bf0-8957-e6cd7b9f141b', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '903306bf-fc57-4dad-a6c1-3408c498a2b9', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'a4d54987-fcc0-4e34-9db8-12149c0720a3', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'eb275c22-dd6c-49b9-8c25-6fc989d2e67a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.611266+00', '2026-09-22 22:04:08.615045+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('f90dcaf1-0e17-405f-b62b-da9e78a17292', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '489fc7fe-29f7-4c9c-ae9c-e4960d17154a', '979fdc93-f8c7-4356-a368-a38767444ec7', '2479295d-6ff1-4963-94df-81944bf8b341', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'd35bceb3-cf9e-4a03-9bff-28b4e3dc160e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.6323+00', '2026-09-22 22:04:08.636752+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('ff5873ea-bf7c-4eb4-be5c-7c297cfa477e', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '4c61d3df-80e5-4e61-9b4a-e9521fe35ad9', '979fdc93-f8c7-4356-a368-a38767444ec7', 'afe55480-6e21-4cd8-92c8-76cc3d53ee36', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'b159909c-3ea0-4f32-a18d-932c9356756f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.656327+00', '2026-09-22 22:04:08.660818+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('15b2cfe4-a7cc-404a-8404-cfd193390a89', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '489fc7fe-29f7-4c9c-ae9c-e4960d17154a', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'c8c4cf7f-4d87-4859-bcf7-13bc4f12c748', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', 'aaa805ab-359d-4f6b-b706-8c428bedbd59', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '7218b7ed-af6e-4840-b822-1ce45a79d091', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.681032+00', '2026-09-22 22:04:08.690263+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('99c8a590-875b-4587-a3ba-cf72a62f0f32', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', '979fdc93-f8c7-4356-a368-a38767444ec7', '5f0c31cc-718b-49eb-a0ce-7c822c9ecd9d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.717023+00', '2026-09-22 22:04:08.717023+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('0abe29a5-8ab0-4584-9771-9e11f879ede5', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '897c608c-6617-4ab7-aeba-dcbdeeffda10', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.720588+00', '2026-09-22 22:04:08.720588+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('ea522008-74fd-4246-a2f3-9683b03580ac', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '3780ba30-aee0-4543-bd74-2a53df5fa639', '979fdc93-f8c7-4356-a368-a38767444ec7', '8a5716b2-dd46-47f0-b650-4f72e28d0a1f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.724462+00', '2026-09-22 22:04:08.724462+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('a8ccb301-d396-48ed-94be-afb9e613f756', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'ef4f13e9-4598-4f19-8399-069702f6ed02', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', 'a4d54987-fcc0-4e34-9db8-12149c0720a3', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '125638d9-f7cb-4a90-94d7-fa1b24a01edd', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.734587+00', '2026-09-22 22:04:08.734587+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('742d6593-9e38-4233-adf2-607ac1bdf00e', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', 'b0fcb2ca-96c7-49ae-834b-c07ce5ef44c3', '979fdc93-f8c7-4356-a368-a38767444ec7', 'c62d987a-27f4-4965-8b14-b7312032e414', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.738334+00', '2026-09-22 22:04:08.738334+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('1a76adfa-51c1-4547-952f-82a32c54a46f', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '11bedcd0-81f2-43f6-bdbd-df6d1e10ff55', '979fdc93-f8c7-4356-a368-a38767444ec7', 'c62d987a-27f4-4965-8b14-b7312032e414', 'marketing', '00000000-0000-4000-8000-000000000003', 'baf9b4ce-d6f2-4ec3-9f26-935e49f49052', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.742014+00', '2026-09-22 22:04:08.742014+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('e34eebbf-11b5-4ede-8186-c27bf31afcda', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'eb204dd6-abcb-400f-bb3e-64c9e5a593e2', '979fdc93-f8c7-4356-a368-a38767444ec7', 'ac44e718-b16b-414a-8e7c-0abc44265236', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.745779+00', '2026-09-22 22:04:08.745779+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('afc06feb-b36d-4cd4-80ee-b1d914a68389', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', '979fdc93-f8c7-4356-a368-a38767444ec7', 'ac44e718-b16b-414a-8e7c-0abc44265236', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.74969+00', '2026-09-22 22:04:08.74969+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('56eaa73d-a7b5-4751-ad2c-d94063065499', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '24b389b9-6f34-4af9-8262-a1c72a34491e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'c1e3f801-384c-46c0-990a-c6af32de7367', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.753271+00', '2026-09-22 22:04:08.757343+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('5314baa3-4f26-433e-9dae-bc62ef959ea7', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'f8c5fd78-41fe-4354-9d87-385761c61a17', 'ef33167d-e615-4e8d-a10a-0a1b8379230f', '3952c483-2f8e-4687-8eb5-b38f0af41eaf', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', '8d040533-d4d4-454d-b856-cc9d89519dd3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 'ca0aad0a-9c49-4166-a257-bd77fb7b414b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.775469+00', '2026-09-22 22:04:08.779493+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('581111c5-6ab2-4d53-8728-ce2d8a7c9052', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'e216b05e-d2e1-4b5c-a928-a088a2784390', '979fdc93-f8c7-4356-a368-a38767444ec7', '5f0c31cc-718b-49eb-a0ce-7c822c9ecd9d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.79608+00', '2026-09-22 22:04:08.79608+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('b6da625a-0336-46a7-9847-c63d0e45c2a9', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-900', 900, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '13622f3e-d04e-40aa-afce-40a3d6a47c0d', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, '66ef2c0d-2fab-432a-a271-86dac7588693', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.800449+00', '2026-09-22 22:04:08.804458+00', 'sponsorship_item', NULL);
INSERT INTO public.signage_items VALUES ('2c215acb-bdaa-46b1-9174-cc40d37de5c6', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'SIG-BIRM27-901', 901, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'e06f625a-c9ab-475a-97a4-6e37f488daed', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '80e169af-df8b-4b50-98bd-3570454ad1d6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-22 22:04:08.824126+00', '2026-09-22 22:04:08.824126+00', 'sponsorship_item', NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('98590bd7-ca1b-4b0a-8f9b-0ef54e4f33b5', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '05aecd12-1536-49ec-bfc7-d6aba25c6a45', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '61302fcd-dcac-4166-8edf-c0b5a8a62cb7', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-22 22:04:08.606763+00', '2026-09-22 22:04:08.606763+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('aaa805ab-359d-4f6b-b706-8c428bedbd59', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', 'Logo on 6 hanging banners', 6, '2026-09-22 22:04:07.995927+00', '2026-09-22 22:04:07.995927+00');
INSERT INTO public.sponsor_entitlements VALUES ('8d040533-d4d4-454d-b856-cc9d89519dd3', 'ad3c5445-68ea-43d4-8036-86a6146a92c3', 'Entrance feature branding', 1, '2026-09-22 22:04:07.999376+00', '2026-09-22 22:04:07.999376+00');
INSERT INTO public.sponsor_entitlements VALUES ('bd03cd12-c185-40e7-8272-93e9e27815bd', 'baf9b4ce-d6f2-4ec3-9f26-935e49f49052', 'Seminar theatre branding', 1, '2026-09-22 22:04:08.00643+00', '2026-09-22 22:04:08.00643+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('ad3c5445-68ea-43d4-8036-86a6146a92c3', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-22 22:04:07.992495+00', '2026-09-22 22:04:07.992495+00');
INSERT INTO public.sponsors VALUES ('baf9b4ce-d6f2-4ec3-9f26-935e49f49052', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-22 22:04:08.002751+00', '2026-09-22 22:04:08.002751+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('48b28d64-2b9f-4442-bc34-057f6b86e4e4', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'ed49a91f-ed15-4151-a50f-d2ce128689df', 'STD-BIRM27-A10', '237e9d0f-8083-4c50-b07c-201bd607c633', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-16 22:04:07.797+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.830732+00', '2026-09-22 22:04:08.830732+00');
INSERT INTO public.stand_submissions VALUES ('ffa464be-7a41-447e-915b-885df907d272', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '07bd6559-0326-43e5-b788-acdb815eb91e', 'STD-BIRM27-A20', 'bea315c3-17ea-413d-9035-ac2efab588e4', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-16 22:04:07.797+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.851677+00', '2026-09-22 22:04:08.851677+00');
INSERT INTO public.stand_submissions VALUES ('57e42457-5460-4365-9e51-1e3810db7b09', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '06816d23-34ef-47b6-9a85-53b9f1ec3102', 'STD-BIRM27-A30', '237e9d0f-8083-4c50-b07c-201bd607c633', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-16 22:04:07.797+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.871002+00', '2026-09-22 22:04:08.871002+00');
INSERT INTO public.stand_submissions VALUES ('f34686c3-d177-49b8-97b0-2b009d72b168', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '7f52516d-8c99-4edc-a48f-0c70f8797952', 'STD-BIRM27-B10', 'bea315c3-17ea-413d-9035-ac2efab588e4', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-16 22:04:07.797+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.892133+00', '2026-09-22 22:04:08.892133+00');
INSERT INTO public.stand_submissions VALUES ('414696cc-e406-4f0f-9ed1-3d2f0baead31', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '832dfe3b-4263-450f-bf46-aea81fa04ad3', 'STD-BIRM27-B20', '237e9d0f-8083-4c50-b07c-201bd607c633', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-16 22:04:07.797+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.909255+00', '2026-09-22 22:04:08.909255+00');
INSERT INTO public.stand_submissions VALUES ('0c9651a8-2a73-4ff5-8cc3-f8d755dc7870', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '4311a92e-e625-4592-b174-c964dd5a8e13', 'STD-BIRM27-B30', 'bea315c3-17ea-413d-9035-ac2efab588e4', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 0, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.929872+00', '2026-09-22 22:04:08.929872+00');
INSERT INTO public.stand_submissions VALUES ('6da83bc5-d2bc-48c5-bcaa-75e0df91a114', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'b387299f-d79e-42c0-b262-4aa9b6164bee', 'STD-BIRM27-C10', '237e9d0f-8083-4c50-b07c-201bd607c633', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 0, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.934247+00', '2026-09-22 22:04:08.934247+00');
INSERT INTO public.stand_submissions VALUES ('4517030b-92bd-4fbd-804f-4a45d57d05d2', 'f2a78acb-1259-4cfe-bf19-8403581e9090', '29ba277c-45e9-4ed9-9db7-2d46f07e2541', 'STD-BIRM27-C20', 'bea315c3-17ea-413d-9035-ac2efab588e4', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 0, '00000000-0000-4000-8000-000000000002', '2026-09-22 22:04:08.938958+00', '2026-09-22 22:04:08.938958+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('61302fcd-dcac-4166-8edf-c0b5a8a62cb7', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-22 22:04:07.969053+00', '2026-09-22 22:04:07.969053+00');
INSERT INTO public.suppliers VALUES ('8946246b-3bcc-440e-bda9-bfd85dd68d84', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-22 22:04:07.973605+00', '2026-09-22 22:04:07.973605+00');
INSERT INTO public.suppliers VALUES ('125638d9-f7cb-4a90-94d7-fa1b24a01edd', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-22 22:04:07.978537+00', '2026-09-22 22:04:07.978537+00');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('24622f37-0b86-4adb-8457-35483212f88c', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'f2a78acb-1259-4cfe-bf19-8403581e9090', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-09-29', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'a58ab8b4-cf13-45d7-89db-ef1c8ef549f4', NULL, '2026-09-22 22:04:08.94786+00', '2026-09-22 22:04:08.94786+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.830965+00', '2026-09-22 22:04:07.830965+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.837278+00', '2026-09-22 22:04:07.837278+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.841613+00', '2026-09-22 22:04:07.841613+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.845907+00', '2026-09-22 22:04:07.845907+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.851922+00', '2026-09-22 22:04:07.851922+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-22 22:04:07.855693+00', '2026-09-22 22:04:07.855693+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.080188+00', '2026-09-22 22:04:08.080188+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.088642+00', '2026-09-22 22:04:08.088642+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.096724+00', '2026-09-22 22:04:08.096724+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.102747+00', '2026-09-22 22:04:08.102747+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.111112+00', '2026-09-22 22:04:08.111112+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-22 22:04:08.176172+00', '2026-09-22 22:04:08.176172+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('51172d48-a3c3-4589-8a6a-b3dbe5227d9d', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-22 22:04:07.87062+00', '2026-09-22 22:04:07.87062+00');
INSERT INTO public.venue_rules VALUES ('bbada296-638b-4168-aeca-da3ec18d065a', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-22 22:04:07.874166+00', '2026-09-22 22:04:07.874166+00');
INSERT INTO public.venue_rules VALUES ('56bdb300-b70e-492b-ab23-188846514c75', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-22 22:04:07.877497+00', '2026-09-22 22:04:07.877497+00');
INSERT INTO public.venue_rules VALUES ('a82005d5-8d3a-4732-b2e2-c4c196e1f6b3', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-22 22:04:07.880697+00', '2026-09-22 22:04:07.880697+00');
INSERT INTO public.venue_rules VALUES ('f7e71a14-d36c-4099-a60f-13e27ebc57f4', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-22 22:04:07.884267+00', '2026-09-22 22:04:07.884267+00');
INSERT INTO public.venue_rules VALUES ('3243996c-6663-40c2-aad3-d843a626e640', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-22 22:04:07.887901+00', '2026-09-22 22:04:07.887901+00');
INSERT INTO public.venue_rules VALUES ('d3dbe2c5-ae69-4c8c-8f85-a695203dc39b', '9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-22 22:04:07.890952+00', '2026-09-22 22:04:07.890952+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('9cefa37e-dcce-4547-847b-8fc4ccc67ef0', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-22 22:04:07.861659+00', '2026-09-22 22:04:07.861659+00');
INSERT INTO public.venues VALUES ('ca618363-31a7-427e-bf1d-7fd43b84d419', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-22 22:04:07.864669+00', '2026-09-22 22:04:07.864669+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('d9a649d4-4c47-4845-8ab5-d85503c30285', '80e169af-df8b-4b50-98bd-3570454ad1d6', 1, 1, 'Marketing brand check', 'approval', 'role', 'marketing', NULL, '{always}', 3, true, true, '2026-09-22 22:04:08.011446+00', '2026-09-22 22:04:08.011446+00');
INSERT INTO public.workflow_steps VALUES ('941badea-b72c-406e-8964-ee26f65879bf', '80e169af-df8b-4b50-98bd-3570454ad1d6', 2, 1, 'Sponsor approval', 'approval', 'role', 'sales', NULL, '{if_sponsored}', 5, true, true, '2026-09-22 22:04:08.013445+00', '2026-09-22 22:04:08.013445+00');
INSERT INTO public.workflow_steps VALUES ('6c5cd0f3-72e2-4183-bc18-397ed3fc626e', '80e169af-df8b-4b50-98bd-3570454ad1d6', 3, NULL, 'Ops technical check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-22 22:04:08.014876+00', '2026-09-22 22:04:08.014876+00');
INSERT INTO public.workflow_steps VALUES ('b2d98ce3-cec8-45f7-9a95-7c119b8a122f', '80e169af-df8b-4b50-98bd-3570454ad1d6', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-22 22:04:08.016644+00', '2026-09-22 22:04:08.016644+00');
INSERT INTO public.workflow_steps VALUES ('f8af35dc-e202-4528-8fc3-4abe2c320914', '80e169af-df8b-4b50-98bd-3570454ad1d6', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-22 22:04:08.019602+00', '2026-09-22 22:04:08.019602+00');
INSERT INTO public.workflow_steps VALUES ('76930ae9-e543-4890-95b1-33b06f8bca22', '80e169af-df8b-4b50-98bd-3570454ad1d6', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-22 22:04:08.021053+00', '2026-09-22 22:04:08.021053+00');
INSERT INTO public.workflow_steps VALUES ('6f8b4a5b-dfbe-44f1-a95b-0448b5812656', '80e169af-df8b-4b50-98bd-3570454ad1d6', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-22 22:04:08.022253+00', '2026-09-22 22:04:08.022253+00');
INSERT INTO public.workflow_steps VALUES ('fcbc4b49-d91a-4d92-9aa2-4f6b8422c65a', '80e169af-df8b-4b50-98bd-3570454ad1d6', 5, NULL, 'Event Director sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{if_requires_event_director,if_cost_over_threshold}', 3, true, true, '2026-09-22 22:04:08.017868+00', '2026-09-22 22:04:08.026387+00');
INSERT INTO public.workflow_steps VALUES ('90c0f107-3c8a-4960-9a11-ee58dd03a7d2', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-22 22:04:08.037908+00', '2026-09-22 22:04:08.037908+00');
INSERT INTO public.workflow_steps VALUES ('cea38c40-70af-424f-98b0-3fb854c21966', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-22 22:04:08.040366+00', '2026-09-22 22:04:08.040366+00');
INSERT INTO public.workflow_steps VALUES ('12bb7737-67d3-46c9-b85f-b85908305782', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-22 22:04:08.041898+00', '2026-09-22 22:04:08.041898+00');
INSERT INTO public.workflow_steps VALUES ('55b1e82f-daaf-42e4-86fb-048f32257cda', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-22 22:04:08.043381+00', '2026-09-22 22:04:08.043381+00');
INSERT INTO public.workflow_steps VALUES ('3d5d60d1-7f54-4c3d-898d-153581cc0090', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-22 22:04:08.045855+00', '2026-09-22 22:04:08.045855+00');
INSERT INTO public.workflow_steps VALUES ('371a1076-1567-4a8c-a04c-8c6ba7ffc141', 'cba6a488-80c7-495c-bf0e-0ea38827a51d', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-22 22:04:08.047862+00', '2026-09-22 22:04:08.047862+00');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('80e169af-df8b-4b50-98bd-3570454ad1d6', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Signage default', 'signage', true, false, '2026-09-22 22:04:08.009232+00', '2026-09-22 22:04:08.009232+00');
INSERT INTO public.workflows VALUES ('cba6a488-80c7-495c-bf0e-0ea38827a51d', 'ebe00c58-c215-4883-9ff8-71222f85a87d', 'Stand default', 'stand', true, false, '2026-09-22 22:04:08.03571+00', '2026-09-22 22:04:08.03571+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 4, true);


--
-- Name: __drizzle_migrations __drizzle_migrations_pkey; Type: CONSTRAINT; Schema: drizzle; Owner: -
--

ALTER TABLE ONLY drizzle.__drizzle_migrations
    ADD CONSTRAINT __drizzle_migrations_pkey PRIMARY KEY (id);


--
-- Name: approval_instances approval_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_pkey PRIMARY KEY (id);


--
-- Name: artwork_annotations artwork_annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_annotations
    ADD CONSTRAINT artwork_annotations_pkey PRIMARY KEY (id);


--
-- Name: artwork_versions artwork_versions_item_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_versions
    ADD CONSTRAINT artwork_versions_item_version_unique UNIQUE (signage_item_id, version_number);


--
-- Name: artwork_versions artwork_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_versions
    ADD CONSTRAINT artwork_versions_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: change_requests change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_pkey PRIMARY KEY (id);


--
-- Name: comment_attachments comment_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_attachments
    ADD CONSTRAINT comment_attachments_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: contractors contractors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractors
    ADD CONSTRAINT contractors_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: edition_counters edition_counters_edition_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_counters
    ADD CONSTRAINT edition_counters_edition_key_unique UNIQUE (edition_id, key);


--
-- Name: edition_counters edition_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_counters
    ADD CONSTRAINT edition_counters_pkey PRIMARY KEY (id);


--
-- Name: edition_deadlines edition_deadlines_edition_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_deadlines
    ADD CONSTRAINT edition_deadlines_edition_key_unique UNIQUE (edition_id, key);


--
-- Name: edition_deadlines edition_deadlines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_deadlines
    ADD CONSTRAINT edition_deadlines_pkey PRIMARY KEY (id);


--
-- Name: editions editions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editions
    ADD CONSTRAINT editions_pkey PRIMARY KEY (id);


--
-- Name: email_log email_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_log
    ADD CONSTRAINT email_log_pkey PRIMARY KEY (id);


--
-- Name: events events_org_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_org_code_unique UNIQUE (organisation_id, code);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: exhibitors exhibitors_edition_stand_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exhibitors
    ADD CONSTRAINT exhibitors_edition_stand_unique UNIQUE (edition_id, stand_number);


--
-- Name: exhibitors exhibitors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exhibitors
    ADD CONSTRAINT exhibitors_pkey PRIMARY KEY (id);


--
-- Name: exports exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports
    ADD CONSTRAINT exports_pkey PRIMARY KEY (id);


--
-- Name: external_grants external_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_grants
    ADD CONSTRAINT external_grants_pkey PRIMARY KEY (id);


--
-- Name: halls halls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.halls
    ADD CONSTRAINT halls_pkey PRIMARY KEY (id);


--
-- Name: item_types item_types_org_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_types
    ADD CONSTRAINT item_types_org_code_unique UNIQUE (organisation_id, code);


--
-- Name: item_types item_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_types
    ADD CONSTRAINT item_types_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_user_org_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_user_org_unique UNIQUE (user_id, organisation_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: organisations organisations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisations
    ADD CONSTRAINT organisations_pkey PRIMARY KEY (id);


--
-- Name: organisations organisations_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisations
    ADD CONSTRAINT organisations_slug_unique UNIQUE (slug);


--
-- Name: reminder_log reminder_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT reminder_log_pkey PRIMARY KEY (id);


--
-- Name: reminder_log reminder_log_unique_send; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT reminder_log_unique_send UNIQUE (target_type, target_id, kind, sent_on);


--
-- Name: signage_items signage_items_edition_seq_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_edition_seq_unique UNIQUE (edition_id, seq);


--
-- Name: signage_items signage_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_pkey PRIMARY KEY (id);


--
-- Name: signage_items signage_items_ref_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_ref_unique UNIQUE (ref);


--
-- Name: snags snags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_pkey PRIMARY KEY (id);


--
-- Name: sponsor_entitlements sponsor_entitlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsor_entitlements
    ADD CONSTRAINT sponsor_entitlements_pkey PRIMARY KEY (id);


--
-- Name: sponsors sponsors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors
    ADD CONSTRAINT sponsors_pkey PRIMARY KEY (id);


--
-- Name: staff_invites staff_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_invites
    ADD CONSTRAINT staff_invites_pkey PRIMARY KEY (id);


--
-- Name: stand_submissions stand_submissions_exhibitor_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_exhibitor_unique UNIQUE (exhibitor_id);


--
-- Name: stand_submissions stand_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_pkey PRIMARY KEY (id);


--
-- Name: stand_submissions stand_submissions_ref_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_ref_unique UNIQUE (ref);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: venue_rules venue_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_rules
    ADD CONSTRAINT venue_rules_pkey PRIMARY KEY (id);


--
-- Name: venues venues_org_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_org_code_unique UNIQUE (organisation_id, code);


--
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (id);


--
-- Name: workflow_steps workflow_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_pkey PRIMARY KEY (id);


--
-- Name: workflows workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (id);


--
-- Name: approval_instances_assigned_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_assigned_user_idx ON public.approval_instances USING btree (assigned_user_id);


--
-- Name: approval_instances_decided_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_decided_by_idx ON public.approval_instances USING btree (decided_by);


--
-- Name: approval_instances_delegated_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_delegated_from_idx ON public.approval_instances USING btree (delegated_from_user_id);


--
-- Name: approval_instances_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_entity_idx ON public.approval_instances USING btree (entity_type, entity_id, run_number);


--
-- Name: approval_instances_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_status_idx ON public.approval_instances USING btree (status);


--
-- Name: approval_instances_step_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_step_idx ON public.approval_instances USING btree (workflow_step_id);


--
-- Name: artwork_annotations_comment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artwork_annotations_comment_idx ON public.artwork_annotations USING btree (comment_id);


--
-- Name: artwork_annotations_version_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artwork_annotations_version_idx ON public.artwork_annotations USING btree (artwork_version_id);


--
-- Name: artwork_versions_item_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artwork_versions_item_idx ON public.artwork_versions USING btree (signage_item_id);


--
-- Name: artwork_versions_uploaded_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX artwork_versions_uploaded_by_idx ON public.artwork_versions USING btree (uploaded_by);


--
-- Name: audit_log_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_actor_idx ON public.audit_log USING btree (actor_user_id);


--
-- Name: audit_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_created_at_idx ON public.audit_log USING btree (created_at);


--
-- Name: audit_log_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_edition_idx ON public.audit_log USING btree (edition_id);


--
-- Name: audit_log_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_entity_idx ON public.audit_log USING btree (entity_type, entity_id);


--
-- Name: audit_log_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_org_idx ON public.audit_log USING btree (organisation_id);


--
-- Name: change_requests_decided_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX change_requests_decided_by_idx ON public.change_requests USING btree (decided_by);


--
-- Name: change_requests_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX change_requests_entity_idx ON public.change_requests USING btree (entity_type, entity_id);


--
-- Name: change_requests_requested_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX change_requests_requested_by_idx ON public.change_requests USING btree (requested_by);


--
-- Name: comment_attachments_comment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comment_attachments_comment_idx ON public.comment_attachments USING btree (comment_id);


--
-- Name: comment_attachments_document_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comment_attachments_document_idx ON public.comment_attachments USING btree (document_id);


--
-- Name: comments_author_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_author_idx ON public.comments USING btree (author_id);


--
-- Name: comments_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_entity_idx ON public.comments USING btree (entity_type, entity_id);


--
-- Name: comments_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_parent_idx ON public.comments USING btree (parent_id);


--
-- Name: contractors_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contractors_org_idx ON public.contractors USING btree (organisation_id);


--
-- Name: documents_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_edition_idx ON public.documents USING btree (edition_id);


--
-- Name: documents_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_entity_idx ON public.documents USING btree (entity_type, entity_id);


--
-- Name: documents_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_org_idx ON public.documents USING btree (organisation_id);


--
-- Name: documents_uploaded_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_uploaded_by_idx ON public.documents USING btree (uploaded_by);


--
-- Name: edition_counters_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX edition_counters_edition_idx ON public.edition_counters USING btree (edition_id);


--
-- Name: edition_deadlines_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX edition_deadlines_edition_idx ON public.edition_deadlines USING btree (edition_id);


--
-- Name: editions_cloned_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX editions_cloned_from_idx ON public.editions USING btree (cloned_from_edition_id);


--
-- Name: editions_event_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX editions_event_idx ON public.editions USING btree (event_id);


--
-- Name: editions_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX editions_venue_idx ON public.editions USING btree (venue_id);


--
-- Name: email_log_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_log_entity_idx ON public.email_log USING btree (entity_type, entity_id);


--
-- Name: events_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_org_idx ON public.events USING btree (organisation_id);


--
-- Name: exhibitors_contractor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exhibitors_contractor_idx ON public.exhibitors USING btree (contractor_id);


--
-- Name: exhibitors_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exhibitors_edition_idx ON public.exhibitors USING btree (edition_id);


--
-- Name: exhibitors_hall_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exhibitors_hall_idx ON public.exhibitors USING btree (hall_id);


--
-- Name: exports_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exports_edition_idx ON public.exports USING btree (edition_id);


--
-- Name: exports_generated_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exports_generated_by_idx ON public.exports USING btree (generated_by);


--
-- Name: external_grants_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX external_grants_edition_idx ON public.external_grants USING btree (edition_id);


--
-- Name: external_grants_invited_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX external_grants_invited_by_idx ON public.external_grants USING btree (invited_by);


--
-- Name: external_grants_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX external_grants_org_idx ON public.external_grants USING btree (organisation_id);


--
-- Name: external_grants_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX external_grants_token_idx ON public.external_grants USING btree (invite_token_hash);


--
-- Name: external_grants_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX external_grants_user_idx ON public.external_grants USING btree (user_id);


--
-- Name: halls_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX halls_edition_idx ON public.halls USING btree (edition_id);


--
-- Name: item_types_default_workflow_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_types_default_workflow_idx ON public.item_types USING btree (default_workflow_id);


--
-- Name: item_types_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_types_org_idx ON public.item_types USING btree (organisation_id);


--
-- Name: locations_hall_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_hall_idx ON public.locations USING btree (hall_id);


--
-- Name: memberships_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_org_idx ON public.memberships USING btree (organisation_id);


--
-- Name: memberships_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_user_idx ON public.memberships USING btree (user_id);


--
-- Name: notifications_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user_idx ON public.notifications USING btree (user_id);


--
-- Name: notifications_user_unread_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user_unread_idx ON public.notifications USING btree (user_id, read_at);


--
-- Name: reminder_log_target_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reminder_log_target_idx ON public.reminder_log USING btree (target_type, target_id);


--
-- Name: signage_items_created_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_created_by_idx ON public.signage_items USING btree (created_by);


--
-- Name: signage_items_current_artwork_version_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_current_artwork_version_idx ON public.signage_items USING btree (current_artwork_version_id);


--
-- Name: signage_items_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_edition_idx ON public.signage_items USING btree (edition_id);


--
-- Name: signage_items_edition_kind_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_edition_kind_idx ON public.signage_items USING btree (edition_id, kind);


--
-- Name: signage_items_edition_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_edition_status_idx ON public.signage_items USING btree (edition_id, status);


--
-- Name: signage_items_hall_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_hall_idx ON public.signage_items USING btree (hall_id);


--
-- Name: signage_items_install_contractor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_install_contractor_idx ON public.signage_items USING btree (install_contractor_id);


--
-- Name: signage_items_installed_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_installed_by_idx ON public.signage_items USING btree (installed_by);


--
-- Name: signage_items_item_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_item_type_idx ON public.signage_items USING btree (item_type_id);


--
-- Name: signage_items_location_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_location_idx ON public.signage_items USING btree (location_id);


--
-- Name: signage_items_owner_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_owner_user_idx ON public.signage_items USING btree (owner_user_id);


--
-- Name: signage_items_sponsor_entitlement_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_sponsor_entitlement_idx ON public.signage_items USING btree (sponsor_entitlement_id);


--
-- Name: signage_items_sponsor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_sponsor_idx ON public.signage_items USING btree (sponsor_id);


--
-- Name: signage_items_supplier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_supplier_idx ON public.signage_items USING btree (supplier_id);


--
-- Name: signage_items_workflow_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_workflow_idx ON public.signage_items USING btree (workflow_id);


--
-- Name: snags_assigned_contractor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_assigned_contractor_idx ON public.snags USING btree (assigned_contractor_id);


--
-- Name: snags_assigned_supplier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_assigned_supplier_idx ON public.snags USING btree (assigned_supplier_id);


--
-- Name: snags_assigned_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_assigned_user_idx ON public.snags USING btree (assigned_user_id);


--
-- Name: snags_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_edition_idx ON public.snags USING btree (edition_id);


--
-- Name: snags_resolved_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_resolved_by_idx ON public.snags USING btree (resolved_by);


--
-- Name: snags_signage_item_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_signage_item_idx ON public.snags USING btree (signage_item_id);


--
-- Name: snags_stand_submission_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_stand_submission_idx ON public.snags USING btree (stand_submission_id);


--
-- Name: sponsor_entitlements_sponsor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsor_entitlements_sponsor_idx ON public.sponsor_entitlements USING btree (sponsor_id);


--
-- Name: sponsors_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsors_edition_idx ON public.sponsors USING btree (edition_id);


--
-- Name: staff_invites_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX staff_invites_email_idx ON public.staff_invites USING btree (invited_email);


--
-- Name: staff_invites_invited_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX staff_invites_invited_by_idx ON public.staff_invites USING btree (invited_by);


--
-- Name: staff_invites_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX staff_invites_org_idx ON public.staff_invites USING btree (organisation_id);


--
-- Name: staff_invites_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX staff_invites_token_idx ON public.staff_invites USING btree (invite_token_hash);


--
-- Name: stand_submissions_build_check_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_build_check_by_idx ON public.stand_submissions USING btree (build_check_by);


--
-- Name: stand_submissions_contractor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_contractor_idx ON public.stand_submissions USING btree (contractor_id);


--
-- Name: stand_submissions_created_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_created_by_idx ON public.stand_submissions USING btree (created_by);


--
-- Name: stand_submissions_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_edition_idx ON public.stand_submissions USING btree (edition_id);


--
-- Name: stand_submissions_edition_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_edition_status_idx ON public.stand_submissions USING btree (edition_id, status);


--
-- Name: stand_submissions_submitted_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_submitted_by_idx ON public.stand_submissions USING btree (submitted_by);


--
-- Name: stand_submissions_workflow_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stand_submissions_workflow_idx ON public.stand_submissions USING btree (workflow_id);


--
-- Name: suppliers_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suppliers_org_idx ON public.suppliers USING btree (organisation_id);


--
-- Name: tasks_assignee_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_assignee_status_idx ON public.tasks USING btree (assigned_to_user_id, status);


--
-- Name: tasks_created_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_created_by_idx ON public.tasks USING btree (created_by_user_id);


--
-- Name: tasks_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_edition_idx ON public.tasks USING btree (edition_id);


--
-- Name: tasks_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_org_idx ON public.tasks USING btree (organisation_id);


--
-- Name: venue_rules_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_rules_venue_idx ON public.venue_rules USING btree (venue_id);


--
-- Name: venues_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_org_idx ON public.venues USING btree (organisation_id);


--
-- Name: workflow_steps_approver_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workflow_steps_approver_user_idx ON public.workflow_steps USING btree (approver_user_id);


--
-- Name: workflow_steps_workflow_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workflow_steps_workflow_idx ON public.workflow_steps USING btree (workflow_id);


--
-- Name: workflows_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workflows_org_idx ON public.workflows USING btree (organisation_id);


--
-- Name: approval_instances approval_instances_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER approval_instances_set_updated_at BEFORE UPDATE ON public.approval_instances FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: artwork_annotations artwork_annotations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artwork_annotations_set_updated_at BEFORE UPDATE ON public.artwork_annotations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: artwork_versions artwork_versions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artwork_versions_set_updated_at BEFORE UPDATE ON public.artwork_versions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: audit_log audit_log_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_log_append_only BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.forbid_audit_mutation();


--
-- Name: change_requests change_requests_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER change_requests_set_updated_at BEFORE UPDATE ON public.change_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: comment_attachments comment_attachments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_attachments_set_updated_at BEFORE UPDATE ON public.comment_attachments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: comments comments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comments_set_updated_at BEFORE UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contractors contractors_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contractors_set_updated_at BEFORE UPDATE ON public.contractors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: documents documents_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER documents_set_updated_at BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: edition_counters edition_counters_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER edition_counters_set_updated_at BEFORE UPDATE ON public.edition_counters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: edition_deadlines edition_deadlines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER edition_deadlines_set_updated_at BEFORE UPDATE ON public.edition_deadlines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: editions editions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER editions_set_updated_at BEFORE UPDATE ON public.editions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: email_log email_log_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER email_log_set_updated_at BEFORE UPDATE ON public.email_log FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: events events_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER events_set_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: exhibitors exhibitors_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER exhibitors_set_updated_at BEFORE UPDATE ON public.exhibitors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: exports exports_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER exports_set_updated_at BEFORE UPDATE ON public.exports FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: external_grants external_grants_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER external_grants_set_updated_at BEFORE UPDATE ON public.external_grants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: halls halls_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER halls_set_updated_at BEFORE UPDATE ON public.halls FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: item_types item_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER item_types_set_updated_at BEFORE UPDATE ON public.item_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: locations locations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER locations_set_updated_at BEFORE UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: memberships memberships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER memberships_set_updated_at BEFORE UPDATE ON public.memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: notifications notifications_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notifications_set_updated_at BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: organisations organisations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER organisations_set_updated_at BEFORE UPDATE ON public.organisations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: reminder_log reminder_log_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reminder_log_set_updated_at BEFORE UPDATE ON public.reminder_log FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: signage_items signage_items_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER signage_items_set_updated_at BEFORE UPDATE ON public.signage_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: snags snags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER snags_set_updated_at BEFORE UPDATE ON public.snags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sponsor_entitlements sponsor_entitlements_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsor_entitlements_set_updated_at BEFORE UPDATE ON public.sponsor_entitlements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sponsors sponsors_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsors_set_updated_at BEFORE UPDATE ON public.sponsors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: staff_invites staff_invites_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER staff_invites_set_updated_at BEFORE UPDATE ON public.staff_invites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: stand_submissions stand_submissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stand_submissions_set_updated_at BEFORE UPDATE ON public.stand_submissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: suppliers suppliers_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suppliers_set_updated_at BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tasks tasks_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_set_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users users_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: venue_rules venue_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER venue_rules_set_updated_at BEFORE UPDATE ON public.venue_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: venues venues_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER venues_set_updated_at BEFORE UPDATE ON public.venues FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: workflow_steps workflow_steps_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER workflow_steps_set_updated_at BEFORE UPDATE ON public.workflow_steps FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: workflows workflows_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER workflows_set_updated_at BEFORE UPDATE ON public.workflows FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: approval_instances approval_instances_assigned_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_assigned_user_id_users_id_fk FOREIGN KEY (assigned_user_id) REFERENCES public.users(id);


--
-- Name: approval_instances approval_instances_decided_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_decided_by_users_id_fk FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: approval_instances approval_instances_delegated_from_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_delegated_from_user_id_users_id_fk FOREIGN KEY (delegated_from_user_id) REFERENCES public.users(id);


--
-- Name: approval_instances approval_instances_workflow_step_id_workflow_steps_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_workflow_step_id_workflow_steps_id_fk FOREIGN KEY (workflow_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: artwork_annotations artwork_annotations_artwork_version_id_artwork_versions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_annotations
    ADD CONSTRAINT artwork_annotations_artwork_version_id_artwork_versions_id_fk FOREIGN KEY (artwork_version_id) REFERENCES public.artwork_versions(id);


--
-- Name: artwork_annotations artwork_annotations_comment_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_annotations
    ADD CONSTRAINT artwork_annotations_comment_fk FOREIGN KEY (comment_id) REFERENCES public.comments(id);


--
-- Name: artwork_versions artwork_versions_signage_item_id_signage_items_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_versions
    ADD CONSTRAINT artwork_versions_signage_item_id_signage_items_id_fk FOREIGN KEY (signage_item_id) REFERENCES public.signage_items(id);


--
-- Name: artwork_versions artwork_versions_uploaded_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artwork_versions
    ADD CONSTRAINT artwork_versions_uploaded_by_users_id_fk FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


--
-- Name: change_requests change_requests_decided_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_decided_by_users_id_fk FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: change_requests change_requests_requested_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_requested_by_users_id_fk FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- Name: comment_attachments comment_attachments_comment_id_comments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_attachments
    ADD CONSTRAINT comment_attachments_comment_id_comments_id_fk FOREIGN KEY (comment_id) REFERENCES public.comments(id);


--
-- Name: comment_attachments comment_attachments_document_id_documents_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_attachments
    ADD CONSTRAINT comment_attachments_document_id_documents_id_fk FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: comments comments_author_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_author_id_users_id_fk FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: comments comments_parent_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_fk FOREIGN KEY (parent_id) REFERENCES public.comments(id);


--
-- Name: contractors contractors_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractors
    ADD CONSTRAINT contractors_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: documents documents_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: documents documents_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: documents documents_uploaded_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_uploaded_by_users_id_fk FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


--
-- Name: edition_counters edition_counters_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_counters
    ADD CONSTRAINT edition_counters_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: edition_deadlines edition_deadlines_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edition_deadlines
    ADD CONSTRAINT edition_deadlines_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: editions editions_cloned_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editions
    ADD CONSTRAINT editions_cloned_from_fk FOREIGN KEY (cloned_from_edition_id) REFERENCES public.editions(id);


--
-- Name: editions editions_event_id_events_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editions
    ADD CONSTRAINT editions_event_id_events_id_fk FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: editions editions_venue_id_venues_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editions
    ADD CONSTRAINT editions_venue_id_venues_id_fk FOREIGN KEY (venue_id) REFERENCES public.venues(id);


--
-- Name: events events_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: exhibitors exhibitors_contractor_id_contractors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exhibitors
    ADD CONSTRAINT exhibitors_contractor_id_contractors_id_fk FOREIGN KEY (contractor_id) REFERENCES public.contractors(id);


--
-- Name: exhibitors exhibitors_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exhibitors
    ADD CONSTRAINT exhibitors_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: exhibitors exhibitors_hall_id_halls_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exhibitors
    ADD CONSTRAINT exhibitors_hall_id_halls_id_fk FOREIGN KEY (hall_id) REFERENCES public.halls(id);


--
-- Name: exports exports_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports
    ADD CONSTRAINT exports_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: exports exports_generated_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports
    ADD CONSTRAINT exports_generated_by_users_id_fk FOREIGN KEY (generated_by) REFERENCES public.users(id);


--
-- Name: external_grants external_grants_edition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_grants
    ADD CONSTRAINT external_grants_edition_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: external_grants external_grants_invited_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_grants
    ADD CONSTRAINT external_grants_invited_by_users_id_fk FOREIGN KEY (invited_by) REFERENCES public.users(id);


--
-- Name: external_grants external_grants_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_grants
    ADD CONSTRAINT external_grants_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: external_grants external_grants_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_grants
    ADD CONSTRAINT external_grants_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: halls halls_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.halls
    ADD CONSTRAINT halls_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: item_types item_types_default_workflow_id_workflows_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_types
    ADD CONSTRAINT item_types_default_workflow_id_workflows_id_fk FOREIGN KEY (default_workflow_id) REFERENCES public.workflows(id);


--
-- Name: item_types item_types_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_types
    ADD CONSTRAINT item_types_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: locations locations_hall_id_halls_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_hall_id_halls_id_fk FOREIGN KEY (hall_id) REFERENCES public.halls(id);


--
-- Name: memberships memberships_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: memberships memberships_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications notifications_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: signage_items signage_items_created_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_created_by_users_id_fk FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: signage_items signage_items_current_artwork_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_current_artwork_version_fk FOREIGN KEY (current_artwork_version_id) REFERENCES public.artwork_versions(id);


--
-- Name: signage_items signage_items_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: signage_items signage_items_hall_id_halls_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_hall_id_halls_id_fk FOREIGN KEY (hall_id) REFERENCES public.halls(id);


--
-- Name: signage_items signage_items_install_contractor_id_contractors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_install_contractor_id_contractors_id_fk FOREIGN KEY (install_contractor_id) REFERENCES public.contractors(id);


--
-- Name: signage_items signage_items_installed_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_installed_by_users_id_fk FOREIGN KEY (installed_by) REFERENCES public.users(id);


--
-- Name: signage_items signage_items_item_type_id_item_types_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_item_type_id_item_types_id_fk FOREIGN KEY (item_type_id) REFERENCES public.item_types(id);


--
-- Name: signage_items signage_items_location_id_locations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_location_id_locations_id_fk FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: signage_items signage_items_owner_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_owner_user_id_users_id_fk FOREIGN KEY (owner_user_id) REFERENCES public.users(id);


--
-- Name: signage_items signage_items_sponsor_entitlement_id_sponsor_entitlements_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_sponsor_entitlement_id_sponsor_entitlements_id_fk FOREIGN KEY (sponsor_entitlement_id) REFERENCES public.sponsor_entitlements(id);


--
-- Name: signage_items signage_items_sponsor_id_sponsors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_sponsor_id_sponsors_id_fk FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id);


--
-- Name: signage_items signage_items_supplier_id_suppliers_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_supplier_id_suppliers_id_fk FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: signage_items signage_items_workflow_id_workflows_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_workflow_id_workflows_id_fk FOREIGN KEY (workflow_id) REFERENCES public.workflows(id);


--
-- Name: snags snags_assigned_contractor_id_contractors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_assigned_contractor_id_contractors_id_fk FOREIGN KEY (assigned_contractor_id) REFERENCES public.contractors(id);


--
-- Name: snags snags_assigned_supplier_id_suppliers_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_assigned_supplier_id_suppliers_id_fk FOREIGN KEY (assigned_supplier_id) REFERENCES public.suppliers(id);


--
-- Name: snags snags_assigned_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_assigned_user_id_users_id_fk FOREIGN KEY (assigned_user_id) REFERENCES public.users(id);


--
-- Name: snags snags_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: snags snags_resolved_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_resolved_by_users_id_fk FOREIGN KEY (resolved_by) REFERENCES public.users(id);


--
-- Name: snags snags_signage_item_id_signage_items_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_signage_item_id_signage_items_id_fk FOREIGN KEY (signage_item_id) REFERENCES public.signage_items(id);


--
-- Name: snags snags_stand_submission_id_stand_submissions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_stand_submission_id_stand_submissions_id_fk FOREIGN KEY (stand_submission_id) REFERENCES public.stand_submissions(id);


--
-- Name: sponsor_entitlements sponsor_entitlements_sponsor_id_sponsors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsor_entitlements
    ADD CONSTRAINT sponsor_entitlements_sponsor_id_sponsors_id_fk FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id);


--
-- Name: sponsors sponsors_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors
    ADD CONSTRAINT sponsors_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: staff_invites staff_invites_invited_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_invites
    ADD CONSTRAINT staff_invites_invited_by_users_id_fk FOREIGN KEY (invited_by) REFERENCES public.users(id);


--
-- Name: staff_invites staff_invites_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_invites
    ADD CONSTRAINT staff_invites_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: stand_submissions stand_submissions_build_check_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_build_check_by_users_id_fk FOREIGN KEY (build_check_by) REFERENCES public.users(id);


--
-- Name: stand_submissions stand_submissions_contractor_id_contractors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_contractor_id_contractors_id_fk FOREIGN KEY (contractor_id) REFERENCES public.contractors(id);


--
-- Name: stand_submissions stand_submissions_created_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_created_by_users_id_fk FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: stand_submissions stand_submissions_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: stand_submissions stand_submissions_exhibitor_id_exhibitors_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_exhibitor_id_exhibitors_id_fk FOREIGN KEY (exhibitor_id) REFERENCES public.exhibitors(id);


--
-- Name: stand_submissions stand_submissions_submitted_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_submitted_by_users_id_fk FOREIGN KEY (submitted_by) REFERENCES public.users(id);


--
-- Name: stand_submissions stand_submissions_workflow_id_workflows_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stand_submissions
    ADD CONSTRAINT stand_submissions_workflow_id_workflows_id_fk FOREIGN KEY (workflow_id) REFERENCES public.workflows(id);


--
-- Name: suppliers suppliers_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: tasks tasks_assigned_to_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assigned_to_user_id_users_id_fk FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id);


--
-- Name: tasks tasks_created_by_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_user_id_users_id_fk FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: tasks tasks_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: tasks tasks_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: venue_rules venue_rules_venue_id_venues_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_rules
    ADD CONSTRAINT venue_rules_venue_id_venues_id_fk FOREIGN KEY (venue_id) REFERENCES public.venues(id);


--
-- Name: venues venues_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: workflow_steps workflow_steps_approver_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_approver_user_id_users_id_fk FOREIGN KEY (approver_user_id) REFERENCES public.users(id);


--
-- Name: workflow_steps workflow_steps_workflow_id_workflows_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_workflow_id_workflows_id_fk FOREIGN KEY (workflow_id) REFERENCES public.workflows(id);


--
-- Name: workflows workflows_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: approval_instances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approval_instances ENABLE ROW LEVEL SECURITY;

--
-- Name: artwork_annotations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.artwork_annotations ENABLE ROW LEVEL SECURITY;

--
-- Name: artwork_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.artwork_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: change_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.change_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: comment_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

--
-- Name: contractors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contractors ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: edition_counters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.edition_counters ENABLE ROW LEVEL SECURITY;

--
-- Name: edition_deadlines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.edition_deadlines ENABLE ROW LEVEL SECURITY;

--
-- Name: editions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.editions ENABLE ROW LEVEL SECURITY;

--
-- Name: email_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_log ENABLE ROW LEVEL SECURITY;

--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

--
-- Name: exhibitors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exhibitors ENABLE ROW LEVEL SECURITY;

--
-- Name: exports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exports ENABLE ROW LEVEL SECURITY;

--
-- Name: external_grants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.external_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: halls; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.halls ENABLE ROW LEVEL SECURITY;

--
-- Name: item_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.item_types ENABLE ROW LEVEL SECURITY;

--
-- Name: locations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

--
-- Name: memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: organisations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organisations ENABLE ROW LEVEL SECURITY;

--
-- Name: reminder_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reminder_log ENABLE ROW LEVEL SECURITY;

--
-- Name: signage_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.signage_items ENABLE ROW LEVEL SECURITY;

--
-- Name: snags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.snags ENABLE ROW LEVEL SECURITY;

--
-- Name: sponsor_entitlements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsor_entitlements ENABLE ROW LEVEL SECURITY;

--
-- Name: sponsors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsors ENABLE ROW LEVEL SECURITY;

--
-- Name: staff_invites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff_invites ENABLE ROW LEVEL SECURITY;

--
-- Name: stand_submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stand_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: suppliers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: venue_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venue_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: venues; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

--
-- Name: workflow_steps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.workflow_steps ENABLE ROW LEVEL SECURITY;

--
-- Name: workflows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.workflows ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict 7ppc9qbsNrdr0K17loavXoELeK82OA6mxdMisEKKwracOIlftMUHHzGuCZncIFw

-- ---------------------------------------------------------------------------
-- Hall Pass epilogue: deny-by-default for Supabase client roles.
-- RLS is already enabled on every table above; these revokes make sure the
-- anon/authenticated roles hold no direct table privileges either.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM authenticated;
  END IF;
END $$;
