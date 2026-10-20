-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites, public.supplier_services, public.supplier_service_links, public.departments, public.approvers, public.task_attachments, public.sponsorship_packages, public.sponsorship_package_lines, public.auth_session, public.auth_account, public.auth_verification, public.auth_rate_limit CASCADE;
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
DROP TYPE IF EXISTS public.item_format CASCADE;
DROP TYPE IF EXISTS public.item_kind CASCADE;
DROP TYPE IF EXISTS public.manager_scope CASCADE;
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

\restrict sPJrzDYEdyUx276FtNjro3Wof9uL6P9Yaya0Jou69hIJxWgawHhy9GYkS70vjuZ

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

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
-- Name: item_format; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.item_format AS ENUM (
    'print',
    'digital'
);


--
-- Name: item_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.item_kind AS ENUM (
    'signage',
    'sponsorship_item',
    'stand_design',
    'stand_panel'
);


--
-- Name: manager_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.manager_scope AS ENUM (
    'department',
    'everyone'
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
    'expiry',
    'print_due',
    'delivery_due',
    'install_due',
    'order_by_due'
);


--
-- Name: reminder_target_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reminder_target_type AS ENUM (
    'approval_instance',
    'signage_item',
    'exhibitor',
    'document',
    'membership'
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
    'organiser',
    'sponsor'
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
    'in_progress',
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
    no_supplier_fallback boolean DEFAULT false NOT NULL,
    assigned_department_id uuid,
    confirmed_on date
);


--
-- Name: approvers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approvers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    department_id uuid NOT NULL,
    full_name text NOT NULL,
    job_title text,
    email text NOT NULL,
    user_id uuid,
    is_main boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    main_on_accept boolean DEFAULT false NOT NULL,
    main_on_accept_by uuid,
    CONSTRAINT approvers_main_on_accept_invite_only CHECK (((NOT main_on_accept) OR ((user_id IS NULL) AND (NOT is_main))))
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    subject_user_id uuid,
    subject_email text
);


--
-- Name: auth_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    account_id text NOT NULL,
    provider_id text NOT NULL,
    access_token text,
    refresh_token text,
    id_token text,
    access_token_expires_at timestamp with time zone,
    refresh_token_expires_at timestamp with time zone,
    scope text,
    password text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_rate_limit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_rate_limit (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    count integer NOT NULL,
    last_request bigint NOT NULL
);


--
-- Name: auth_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_session (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    ip_address text,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_verification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_verification (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    identifier text NOT NULL,
    value text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    signs_last boolean DEFAULT false NOT NULL,
    default_for text[] DEFAULT '{}'::text[] NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    signs_off boolean DEFAULT true NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    logo_path text,
    setup_checked text[] DEFAULT '{}'::text[] NOT NULL
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
    kind public.item_kind DEFAULT 'signage'::public.item_kind NOT NULL,
    format public.item_format,
    is_archived boolean DEFAULT false NOT NULL
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
    permission_overrides jsonb DEFAULT '{}'::jsonb NOT NULL,
    department_id uuid,
    features text[],
    job_title text,
    manager_scope public.manager_scope,
    suspended_at timestamp with time zone,
    suspended_by uuid,
    access_ends_at timestamp with time zone,
    edition_ids uuid[],
    CONSTRAINT memberships_edition_ids_not_admin CHECK (((role <> 'admin'::public.staff_role) OR (edition_ids IS NULL))),
    CONSTRAINT memberships_edition_ids_not_empty CHECK (((edition_ids IS NULL) OR (cardinality(edition_ids) > 0))),
    CONSTRAINT memberships_manager_scope_not_admin CHECK (((role <> 'admin'::public.staff_role) OR (manager_scope IS NULL)))
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    edition_id uuid
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
    signoffs jsonb,
    order_by_date date,
    photo_path text,
    sale_price numeric(12,2),
    sold_at timestamp with time zone,
    stand_number text,
    parent_item_id uuid,
    sent_to_print_at timestamp with time zone,
    delivered_at timestamp with time zone,
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    raised_by_user_id uuid
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
    from_package_id uuid,
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    package_id uuid,
    package_price numeric(12,2),
    package_price_note text,
    package_sold_at timestamp with time zone,
    CONSTRAINT sponsors_package_price_not_negative CHECK (((package_price IS NULL) OR (package_price >= (0)::numeric))),
    CONSTRAINT sponsors_package_sale_fields CHECK (((package_id IS NOT NULL) OR ((package_price IS NULL) AND (package_price_note IS NULL) AND (package_sold_at IS NULL))))
);


--
-- Name: sponsorship_package_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsorship_package_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    package_id uuid NOT NULL,
    description text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sponsorship_package_lines_quantity_positive CHECK ((quantity >= 1))
);


--
-- Name: sponsorship_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsorship_packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    price numeric(12,2),
    places integer,
    sort_order integer DEFAULT 0 NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sponsorship_packages_places_positive CHECK (((places IS NULL) OR (places >= 1))),
    CONSTRAINT sponsorship_packages_price_not_negative CHECK (((price IS NULL) OR (price >= (0)::numeric)))
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    job_title text,
    department_id uuid,
    features text[],
    expires_at timestamp with time zone,
    manager_scope public.manager_scope,
    access_ends_at timestamp with time zone,
    edition_ids uuid[],
    CONSTRAINT staff_invites_edition_ids_not_admin CHECK (((role <> 'admin'::public.staff_role) OR (edition_ids IS NULL))),
    CONSTRAINT staff_invites_edition_ids_not_empty CHECK (((edition_ids IS NULL) OR (cardinality(edition_ids) > 0)))
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
-- Name: supplier_service_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_service_links (
    supplier_id uuid NOT NULL,
    service_id uuid NOT NULL
);


--
-- Name: supplier_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    kind public.supplier_kind DEFAULT 'other'::public.supplier_kind NOT NULL,
    contact_name text,
    email text,
    phone text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_archived boolean DEFAULT false NOT NULL
);


--
-- Name: task_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    file_path text NOT NULL,
    file_name text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    uploaded_by uuid NOT NULL,
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
    parent_task_id uuid,
    CONSTRAINT tasks_title_not_empty CHECK ((title <> ''::text))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    phone text,
    avatar_path text,
    is_external boolean DEFAULT false NOT NULL,
    notification_prefs jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    email_verified boolean DEFAULT false NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_archived boolean DEFAULT false NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    default_for text[] DEFAULT '{}'::text[] NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    department_id uuid
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    for_kind text
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
INSERT INTO drizzle.__drizzle_migrations VALUES (5, '65bf2a8698b59f070aad294fbb21d5089fe629b06b79c58d85ad12106e01abf8', 1790325422848);
INSERT INTO drizzle.__drizzle_migrations VALUES (6, '6757321e3e804ab6e7fde119333e65f225ffeb77f65735613b025773f8145358', 1790330588710);
INSERT INTO drizzle.__drizzle_migrations VALUES (7, 'be6f48bbde7615c5827770d0ff3ec083541d89b777281ef5046a2c622d0e382b', 1790337619744);
INSERT INTO drizzle.__drizzle_migrations VALUES (8, '78873a6d3c286cefc0d8ab94a074b6bad018471f9e0cfa617715f3977a630b92', 1790344364546);
INSERT INTO drizzle.__drizzle_migrations VALUES (9, '275eeed9383b78ea18fd0efcaaea9625a2947b25fc25c28cb2efa8d846ba83e3', 1790525113552);
INSERT INTO drizzle.__drizzle_migrations VALUES (10, '009e4b5d9fe9c323d68fd6fca017d9b598686927bc50c80576a97459183d541b', 1790688915685);
INSERT INTO drizzle.__drizzle_migrations VALUES (11, '25f41827c7ab1b63530a494f6bb6b6e05f89c092c59c006d46c8a47d2d009851', 1790765456233);
INSERT INTO drizzle.__drizzle_migrations VALUES (12, '6d94adacc90d35eb4deffd57f74eaca35b448d8e39e66237dd1a15f86552c64d', 1791996931045);
INSERT INTO drizzle.__drizzle_migrations VALUES (13, '119f9a08459f5a2d69f20cb46982997d50602c0914fed930a8b83e691c9a33b6', 1792174730034);
INSERT INTO drizzle.__drizzle_migrations VALUES (14, 'c95d7f3af4f4cddf20ec23d476b5f981c82ce7173070e8aa8de595f4cc7bd6fa', 1792400722931);
INSERT INTO drizzle.__drizzle_migrations VALUES (15, 'f1add84f821c8102c5d95a70a3257031a1f121b25a2ab66b4128ebd80172d8f5', 1792502669707);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('68e8249e-93e5-4d9e-b27b-07b0151591f9', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('329fa549-5e1e-4077-9a97-b931c3b9ba59', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('72d85afa-95f6-4abf-9e4a-cdac867ef4ab', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('e73a520c-204d-40f3-a837-6755761777bb', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d3bf735f-9274-4c71-9b67-d5b966da1761', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('08df93a9-2972-4f6a-8f51-a7cd840042c9', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c7ce5c92-258e-4520-8354-a86d1aa34bac', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6521ca0c-5352-4a46-9d2a-d10c16ec0775', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.457788+00', '2026-10-20 13:55:02.457788+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5ac7a25f-01fe-4f94-8dc5-3c1dd81fbcb0', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('60b34b8d-8cb0-4e60-a58b-5cc9c9de1c1c', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('d5be007a-144e-4bfb-9b3b-b76e26350949', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('d941f482-bf2d-479a-9309-b5f0b01c9bac', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('33d2ee21-cf96-4bde-b8b7-d3f496008eba', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('69cc7dac-8969-430d-a742-49640903d2c3', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e8e9062d-c638-4454-a7d2-0df45cdae5c8', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a3adf0ac-1445-4fc9-8e63-1a5adaaf1013', 'signage_item', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.48447+00', '2026-10-20 13:55:02.48447+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f49d03ec-9670-4f4a-b6e5-3d70b49add25', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 13:55:01.964+00', '2026-10-16 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('1f49b357-739c-4a0e-b275-ae376129e5cf', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 13:55:01.964+00', '2026-10-11 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('d3ab8bc4-33e4-4a86-8550-32f40c7d7505', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-10 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 13:55:01.964+00', '2026-10-13 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('e873cff8-16e9-4adf-8c1e-fc1eb4a453d1', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5c9fe756-0435-42ab-9ca8-acec95af5c72', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('c87d518b-d06e-4ff3-b9f2-a15f38ebe781', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f43cd504-3a15-49de-ac8e-1a5b1f8be15e', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a72f534c-0a1a-4e66-a55f-44f7cc51d46a', 'signage_item', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.515062+00', '2026-10-20 13:55:02.515062+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d4c9eb7-90eb-4830-8df6-afc1a171bd2c', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('5a2bd5d3-bdbf-4cfa-b020-61b1af171b80', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('92d381ce-18dd-4d3d-8af4-c906868ea457', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('5735b896-5567-43ca-82db-3aab7ece05de', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('350b9f1c-0a1d-4e9c-acab-ffbb436a1850', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('120c57b6-f77f-43ec-8c2e-7f90d74912e1', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8c9cb9fe-8d5c-4856-9f8d-9e1bcee4765a', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('14fc7370-015e-4177-a404-5861787470d1', 'signage_item', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.543689+00', '2026-10-20 13:55:02.543689+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b08df51-0009-4de4-a998-ff3a955ead18', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('90eb08b3-ef06-4bd6-9a8f-75d6643243b9', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('869927e7-566e-4f66-91c5-9fd47012ad31', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('9b5be24e-797f-433b-a181-35de7560a7d7', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3632f2b2-708f-422f-8810-975e0ed4e323', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('8fee565a-74f8-41c4-82d9-d057b266c4dd', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8b7242b7-3f7f-449b-ac14-bc6ebaea5c32', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6d0dbead-b4b4-4274-aa79-3991f295480a', 'signage_item', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.565905+00', '2026-10-20 13:55:02.565905+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('81358717-a85d-4706-a78e-db32a12302bf', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 13:55:01.964+00', '2026-10-11 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('fc50accf-01dd-4ea1-b402-429e24ab1c1b', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 13:55:01.964+00', '2026-10-11 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('123deecb-19ac-474a-9296-9ddc9162c927', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('63cd25d9-48b9-4f91-9b4c-721aaaed74fb', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1554488e-e526-4275-b8b9-0a22da79e70e', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', '2026-10-16 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('ce19f42d-57cc-4dd8-b684-c2cba8c93d50', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8154ea0f-1e38-48c2-8f34-311d1395db19', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('db9d206c-da68-4e2e-a75b-42022e137408', 'signage_item', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.588397+00', '2026-10-20 13:55:02.588397+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2825186c-01a5-48ba-a78b-110b94ed5052', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('1149319c-053e-46d1-baac-4d6c896d3e8c', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('5208613c-0dd8-4870-b154-dd74632c8c8e', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('1d9a0022-ad86-4b0f-bdf9-87fb66142708', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f496cf56-eb56-4519-90bf-5ed1ca13a6b4', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('1abda8a2-6dc9-4bc2-8ce4-a07135f20552', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('93a3c676-f5de-4e1e-9b1b-601dc8312b46', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3b242079-6e7f-4273-8f29-115622ef59ad', 'signage_item', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.612297+00', '2026-10-20 13:55:02.612297+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('37313553-da1f-448d-92fe-9a1595f2ad55', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('e60c6459-2fa6-48d3-9ca7-2d7e06192b8c', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('3431f15e-1cad-4223-8e47-015897b2ed54', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('f57c5390-903c-4c5e-af53-77ef322fcebc', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2f2c784e-a3ea-4c92-be41-16e04be4d672', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('efa86a42-dc37-42a9-9c2b-ba952b9675b2', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f302fa18-9ac2-4f83-b150-78d916f50c1a', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0ad0a1ee-a835-4d56-8340-4c2397276f2e', 'signage_item', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.633195+00', '2026-10-20 13:55:02.633195+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bbb17564-20df-4063-9ba4-6ba8e356200f', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('7356863f-3203-44e2-990a-90cde7337173', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('d1d18ce2-42b0-4413-b514-13174f4ec18a', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 13:55:01.964+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('056e1318-9352-4459-966b-d2feef218973', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b7aec44c-8c92-4a0e-8c81-65d508598bcf', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('1d78d466-d905-4969-8f24-200c4b6f695f', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5604d266-a315-484c-b680-da0b696f4f88', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f92ea24f-afd4-4b57-9d3f-7a4a1193cab5', 'signage_item', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.649126+00', '2026-10-20 13:55:02.649126+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('66c4a8f2-04e1-4235-805c-15ae11603a9d', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('4123f65a-58c0-455e-a709-a40cc84e2ab8', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('589b5e3a-5245-44aa-ae56-5bd8a7a37180', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('c0e01080-adb1-497e-923f-bb8804e3aa31', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9a46b6a8-e776-4dbc-93dd-fa5030ef9da8', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('a0c1a1b7-4c25-432e-acff-5a98d90ba45f', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('98fbd211-3084-44f9-be7e-993b952d7a13', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1b650b48-24bd-4d40-801e-de8b21cf48f1', 'signage_item', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.668289+00', '2026-10-20 13:55:02.668289+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b9f80a7e-e5f0-4a7f-8e1e-27db7c0be689', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('dcc26716-1a35-481f-829a-07ba06706191', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('0b7f55db-c7d1-4bbe-91e0-d068097f0e58', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('f67bb1e9-a80f-4c54-98b4-a888a161e130', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1edaad65-d9e4-4d5b-a536-ca5868860103', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e89a5a98-fc0a-4980-8d79-fb05b7317211', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('7fb9c073-51a1-4111-9c88-7d21c8ca1b35', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4844f022-64a7-4cd9-83ca-24e1df1f19d4', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ab230607-63a7-4fda-bbd0-916c8a32d020', 'signage_item', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.686802+00', '2026-10-20 13:55:02.686802+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4d3bfa5f-0ca0-496d-babc-259474b586a6', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('8b6ac939-225b-4aaa-86b0-da2e8eb1489a', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('9b825c99-9f80-4954-aa6a-3f1a9c272593', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('b72ef4f7-606e-410c-b778-7afd15ad95d5', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('881a0e7f-a700-4952-81a5-baec731fa0e0', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('afa90c50-a6ee-44b6-b414-f5feefb7565e', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ab529976-1830-4679-8475-da9d17a5ef9c', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('877e4e54-2aa6-4ea7-a128-b5a75d046b4c', 'signage_item', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.709942+00', '2026-10-20 13:55:02.709942+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('065d2356-b7c1-46e8-932c-1966542112aa', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('ca1f8bcd-7db5-4445-964a-01e0964795c4', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('a508425b-4235-4168-8372-7c4a11e9d2b2', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('e8c1266c-d74a-4482-ae59-c35f53296151', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('851e65ce-51a9-4046-9537-6010c501a78c', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('abc3107d-987e-464e-9e20-0da24373f330', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('71f3ddea-0614-4ae8-a498-ecbcf80baf88', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4ea910f3-c0ca-4497-bc57-44fb009e9d1a', 'signage_item', 'ffb78223-3b09-4549-8963-05d934195a67', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.732799+00', '2026-10-20 13:55:02.732799+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5db9ddd3-1969-43a6-a258-417a0e22e48b', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('6098ca8f-6556-4453-ad45-484325a02865', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('7724d253-24bc-468f-afd4-3442052fde70', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('14566f01-6336-4525-8127-3afaacea2205', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d96aef41-7f9f-405b-af2a-1c3ccfdc7914', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('44bdba92-31b1-4cfa-80fb-7ee81e8a4135', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('06dbb6ca-9cb1-4df9-b9b5-139d8c7456a2', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2c78a78d-91b6-4f7e-bfe6-6f4c12f89072', 'signage_item', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.756458+00', '2026-10-20 13:55:02.756458+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1578679d-2c70-42fb-8479-2742969afb20', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('21112772-a0b3-48fa-8404-8e2625ab552c', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('fb57e214-7d47-47bf-bc0e-b89c70321846', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('75dff8ca-90a7-4f3b-bf43-e8264227685d', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f2b5b605-97de-4e49-be20-395b05702a44', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('e52dc3e2-72d1-4086-a990-88963d199702', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9a9fc251-4cc2-4ef6-875f-b391d2578161', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('433bfd92-7e5e-44a7-8887-a9ee50d7b7ec', 'signage_item', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.77582+00', '2026-10-20 13:55:02.77582+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bc6ba2c3-3363-4112-b968-833648874f86', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('300f3962-d280-41b1-8ff9-55f767108e02', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('2305b931-72f0-497e-a585-72ac89e49a72', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('a274fcb9-2457-4c83-a1b2-dd3b48e1ed50', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aa30b710-d2ae-47f9-87fa-9be4169c338d', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('6a5dbf2b-145f-4716-b9cc-dc897f14fa13', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a6d1c5b-a26e-4e08-9b8f-dec18fda6690', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d4cb462f-59ff-47c2-8750-13c7e60f5999', 'signage_item', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:02.79642+00', '2026-10-20 13:55:02.79642+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('be5648c5-265e-4d2f-9328-585b87cfad1e', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('273c8884-6de6-41f6-bbcc-9a71cf3326fc', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('f8739872-04f6-4d2a-8955-aafd111cbf3c', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('80b8f37c-9cc7-40c1-b8bf-b163563a5375', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('92798e06-a884-423b-b577-9f25843b5e6f', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('688f3d75-8d68-4dde-83f3-0c22ba8d9b63', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c95d0ad7-416b-49fb-a95d-699dcabf5a7d', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('19156f61-0d64-457d-a307-9b2b0a992276', 'signage_item', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.819614+00', '2026-10-20 13:55:02.819614+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0d047040-b87f-45e6-bf38-cc5b9aa1f1d0', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('03b91261-138e-4444-82f2-c71943ed7a38', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('ac8c4dc6-d74b-49a2-aa3c-6ba724408e57', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('85131364-29f8-4c3a-98ed-2f025c754172', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f98e7851-7684-4edf-b3e9-9a24222222d4', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('8a62b4e3-b0b0-4aad-9fa4-4ee71fd7e2db', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5482f23d-234a-47d2-bc13-30a9b3cf3eef', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('983fe8fc-89df-4860-9d77-3df0126a5b83', 'signage_item', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.841335+00', '2026-10-20 13:55:02.841335+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('334e49e5-4f4b-48a0-abb1-b5bf17105e15', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('a3a2a5a7-839d-4142-82ba-2d75d05ee25b', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 13:55:01.964+00', '2026-10-22 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('bde47177-b1e8-4a41-995b-457304fb5e4d', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('97bca98f-3d86-4da4-9096-605b69419919', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 13:55:01.964+00', '2026-10-22 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('1f645c96-c80b-4bb0-a340-5d8d02d696c3', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('1208ca6d-a486-43bb-861f-67ae60f010b6', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('361cbeaa-87e9-45fd-827b-e709acbc2d2e', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a6436c06-a685-4eab-8db2-083aef04c95b', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('7dfaeca3-101f-4def-9ff6-cb3d8bb121f0', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1e78833b-e058-4801-9dbc-39b4bea09c97', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('362891ac-0a75-4f00-818b-6392c9f4d7d0', 'signage_item', '37eceb72-034e-4cca-b007-f57016530050', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.868419+00', '2026-10-20 13:55:02.868419+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ca483052-82f6-43b1-82f3-83d3a522c4e8', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('e1413b12-c8fa-4f87-9877-58c1136f28b3', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('20ae3bb1-a0c0-4655-b9a7-f1ba769a8f7f', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('226949fe-0067-4d9a-b7ee-8dbf80dd9c4f', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d1a3db00-c44f-4eb2-a058-c5d962ce5adc', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('6cfbfcdd-d094-4e04-bb14-dc94db6ce55a', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ccc2d163-0e7e-4671-9069-05469426a23f', 'signage_item', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.933798+00', '2026-10-20 13:55:02.933798+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5c37ae5e-a0ad-44a3-b4c1-42342706a416', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('312ecedc-85fa-43fb-b552-db63050c6717', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('19cff5cf-7851-4dd4-8ed4-b8f396d09fd7', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('e852eec3-5035-490c-bbf0-cbc4c51af442', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 13:55:01.964+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-24 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7ffe7932-a7b7-42d0-aa0d-bdbee59b0630', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('b1aa5507-cc4a-4de6-ac3c-78f98d1995a8', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-19 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef21f8e2-1998-47db-b57a-b5a2225f646f', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8da07845-a207-4284-9707-68b378ebedf0', 'signage_item', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.953782+00', '2026-10-20 13:55:02.953782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8536619-1c69-4402-8bb9-4fc4b19af932', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, '67b8642a-fe4f-42b5-85c6-15321c9c376c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 3, false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL);
INSERT INTO public.approval_instances VALUES ('3246efe2-8a22-4fcc-a56d-762dd478d1b1', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, '603241d4-a67b-4e10-93d6-535336b119e2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 3, false, '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL);
INSERT INTO public.approval_instances VALUES ('b276414e-6b3a-41a3-8190-cfbee2bf949f', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, 'c9a167f7-1953-47a6-acd9-deb4ca47978c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 13:55:01.964+00', '2026-10-20 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 5, false, '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL);
INSERT INTO public.approval_instances VALUES ('8f31f578-8b52-4130-9090-b6c3061f03e6', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, '1dcc830e-b53c-460a-895d-74a728ddceff', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6845b9c4-72bb-4cbf-93a7-d99e34f5d701', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, 'c7691ad9-a181-4ad5-8452-ee490fee874f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 3, false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL);
INSERT INTO public.approval_instances VALUES ('18ecdf3e-cfab-4183-968c-3c20f2592914', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, 'cafa3da5-55b3-4ee3-9c74-ee548400871b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bda7e9e3-05ab-42ba-ac51-c2bb45b6b0a7', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, '6c5ba552-76e9-4b2e-afec-d6da816ed8df', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('75824a79-6b47-476d-b3ac-8e32a8038d32', 'signage_item', 'a75374f3-df11-486e-a475-0152fce6d602', 1, '964566a4-0cce-4591-802e-7aa14fc778ab', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:02.979464+00', '2026-10-20 13:55:02.979464+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f90b0eed-db2e-4911-9482-608f7196a0d4', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, 'b962c2e9-1c25-469d-84f3-ebd9bea4a302', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 13:55:01.964+00', '2026-10-17 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a7603996-4d67-494d-b6bf-8dfe8078debe', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, 'c5d8b4ef-9862-474b-89fd-a1e3a65a1930', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 13:55:01.964+00', '2026-10-23 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('de16cb58-708d-4bb1-89bd-a722200d40fb', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, '62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9535f178-225c-4306-a7a9-52f66717a765', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, '03966daa-c49a-45ed-9e6a-b7edfa2c71f3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('34035d17-b2af-48ad-b0b7-e5c3caa69b60', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, 'd1c1afbd-8821-43c2-a1fb-16ea88cd5e19', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ca765b69-d1c1-408f-bf5a-d2fe015ddf2f', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 1, 'c313293f-58e5-4563-8ac0-b4a2640e99b4', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('73bec492-2e37-46d0-bfdc-474138ed5393', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, 'b962c2e9-1c25-469d-84f3-ebd9bea4a302', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 13:55:01.964+00', '2026-10-17 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c92f48f5-94bb-4c27-8a7d-a8c1c64839dc', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, 'c5d8b4ef-9862-474b-89fd-a1e3a65a1930', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3ff5bf91-055a-472c-bcd3-f488549d0183', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, '62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b498fdd4-6c22-46ac-a07b-627c6c89393e', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, '03966daa-c49a-45ed-9e6a-b7edfa2c71f3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('55c1a366-661b-4745-a495-102d4bfe47cb', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, 'd1c1afbd-8821-43c2-a1fb-16ea88cd5e19', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('46623c59-3a23-41a5-bf66-024884631468', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 1, 'c313293f-58e5-4563-8ac0-b4a2640e99b4', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3770356f-5369-485d-843a-7891cdab6489', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, 'b962c2e9-1c25-469d-84f3-ebd9bea4a302', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-14 13:55:01.964+00', '2026-10-17 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7511548d-02d6-4e01-a8cb-7bd16de6fc5e', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, 'c5d8b4ef-9862-474b-89fd-a1e3a65a1930', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2ca30464-f79d-47ac-b246-398064188e85', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, '62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ac54448c-7b8f-4ed6-896d-5e2d884e257c', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, '03966daa-c49a-45ed-9e6a-b7edfa2c71f3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a9dfd672-485f-439f-b439-af6adb66bcfd', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, 'd1c1afbd-8821-43c2-a1fb-16ea88cd5e19', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c8f2cfc8-b9a0-4018-85c8-2f0b30843643', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 1, 'c313293f-58e5-4563-8ac0-b4a2640e99b4', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ab5b85d-f3ee-4a87-adcb-aa95840afa51', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, 'b962c2e9-1c25-469d-84f3-ebd9bea4a302', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 13:55:01.964+00', '2026-10-17 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b7bd4b67-64f8-4678-b466-904f20f05fb6', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, 'c5d8b4ef-9862-474b-89fd-a1e3a65a1930', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5485a5fc-897f-4b30-8634-2cd5b7cc0d41', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, '62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-21 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cfe51858-aa12-4c52-ab1b-5b784b66bd2d', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, '03966daa-c49a-45ed-9e6a-b7edfa2c71f3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-23 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8a77802-809f-4c99-8d51-5da21724139a', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, 'd1c1afbd-8821-43c2-a1fb-16ea88cd5e19', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f5858d46-e975-41e3-81dd-ba8427aef268', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 1, 'c313293f-58e5-4563-8ac0-b4a2640e99b4', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('522a7886-159e-4c36-842f-22bdf0db45d5', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, 'b962c2e9-1c25-469d-84f3-ebd9bea4a302', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 13:55:01.964+00', '2026-10-17 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5b204ec4-cb83-429d-add2-ba6b83fb53c9', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, 'c5d8b4ef-9862-474b-89fd-a1e3a65a1930', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f5d08dce-f3eb-4cbb-a4bd-2ed324c2c133', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, '62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-21 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dfba709a-9164-4b15-8e9e-95f96e6c983e', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, '03966daa-c49a-45ed-9e6a-b7edfa2c71f3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-23 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('256e2ff7-de73-449e-a273-4468be1532e5', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, 'd1c1afbd-8821-43c2-a1fb-16ea88cd5e19', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 13:55:01.964+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 13:55:01.964+00', '2026-10-18 13:55:01.964+00', 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('02ff5af3-433d-4b71-a2da-eac860be9784', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 1, 'c313293f-58e5-4563-8ac0-b4a2640e99b4', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 13:55:01.964+00', NULL, 0, NULL, NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('021165f3-de19-4943-8133-a12e3ae842fe', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-20 13:55:02.294539+00', '2026-10-20 13:55:02.294539+00', false, NULL);
INSERT INTO public.approvers VALUES ('fc1a2841-e05d-4a60-a283-2b799c9b5087', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '8c70a9ee-40a9-406f-9141-61229fc7802c', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-20 13:55:02.303061+00', '2026-10-20 13:55:02.303061+00', false, NULL);
INSERT INTO public.approvers VALUES ('1f57c204-46df-4ca4-9079-dcd6a80ff6d4', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '8de66405-e14e-42be-bb1e-0fb99a8f2096', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-20 13:55:02.310625+00', '2026-10-20 13:55:02.310625+00', false, NULL);
INSERT INTO public.approvers VALUES ('fe88047d-422f-44d0-b0c0-a9aff2fb6dc4', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-20 13:55:02.317554+00', '2026-10-20 13:55:02.317554+00', false, NULL);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('15797a0c-67c2-418d-b4ab-fc6d7d7324d2', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.452898+00', '2026-10-20 13:55:02.452898+00');
INSERT INTO public.artwork_versions VALUES ('5c9af79e-8ce9-45ab-8f76-726aec50441b', 'f90708a1-2157-4261-ad1d-cb7635283df7', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.479972+00', '2026-10-20 13:55:02.479972+00');
INSERT INTO public.artwork_versions VALUES ('0c3d4469-bde7-4b1a-97ab-36afb69ede3b', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-20 13:55:02.50955+00', '2026-10-20 13:55:02.50955+00');
INSERT INTO public.artwork_versions VALUES ('820da2a4-aec1-472c-9906-c49995610eed', 'dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.512048+00', '2026-10-20 13:55:02.512048+00');
INSERT INTO public.artwork_versions VALUES ('30681070-b791-4061-a45c-1ddfcfa4e894', '66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.539725+00', '2026-10-20 13:55:02.539725+00');
INSERT INTO public.artwork_versions VALUES ('88b44ea7-3a81-4a0e-a9b5-fcc1060b892d', '6a927a8e-2296-4a3b-ac5f-476cd5098dc4', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.563512+00', '2026-10-20 13:55:02.563512+00');
INSERT INTO public.artwork_versions VALUES ('1adf6db1-04bb-4757-bd25-dcb61936007a', 'ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.585401+00', '2026-10-20 13:55:02.585401+00');
INSERT INTO public.artwork_versions VALUES ('7e9809c7-78f2-4dd2-a732-ae74a83deba1', '6c14d34e-3c19-4f48-a98c-ce665cdf3809', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.607225+00', '2026-10-20 13:55:02.607225+00');
INSERT INTO public.artwork_versions VALUES ('438cf599-bad9-48de-84f7-ebcd8f1665a0', 'd259edce-308b-4ccb-a9f9-babca5188475', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.630569+00', '2026-10-20 13:55:02.630569+00');
INSERT INTO public.artwork_versions VALUES ('89743202-17bf-49e1-a7d7-2c159a925a22', 'c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.647009+00', '2026-10-20 13:55:02.647009+00');
INSERT INTO public.artwork_versions VALUES ('0ffc2e29-5a7f-470b-b2d8-0df1df9442e4', 'b27fa1a1-2573-4820-ae71-5aaba9689103', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.666081+00', '2026-10-20 13:55:02.666081+00');
INSERT INTO public.artwork_versions VALUES ('a2547dad-0afb-4209-ac29-faf873324c4a', '622d9203-6e0b-4e37-9145-7869805c6cb3', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.684245+00', '2026-10-20 13:55:02.684245+00');
INSERT INTO public.artwork_versions VALUES ('340bc477-bfb7-4f9f-bdf9-0c790db6f05f', 'e1866883-2c14-4be6-a560-ab4de4ca9ea0', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.707145+00', '2026-10-20 13:55:02.707145+00');
INSERT INTO public.artwork_versions VALUES ('1adf755a-8754-48d2-a5ae-8996a5eba779', 'ffb78223-3b09-4549-8963-05d934195a67', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.730104+00', '2026-10-20 13:55:02.730104+00');
INSERT INTO public.artwork_versions VALUES ('37b1bf5b-1d67-4de3-8684-b8c389b6cf96', '0ecfb702-61bb-47dd-b920-4794d33bffe8', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.753638+00', '2026-10-20 13:55:02.753638+00');
INSERT INTO public.artwork_versions VALUES ('dece8b5e-f08c-46f0-9b38-2c34046570ac', '146575e8-4dc9-4ddb-bba5-d19e71e38599', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.773208+00', '2026-10-20 13:55:02.773208+00');
INSERT INTO public.artwork_versions VALUES ('96ed1809-d1a3-47c3-b4c8-7abc12c978e2', '95ac976c-9272-406b-a2d7-1bee9e710dda', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.794006+00', '2026-10-20 13:55:02.794006+00');
INSERT INTO public.artwork_versions VALUES ('f26ea9b9-4972-48c7-baae-e8db946b4e01', 'ae52aad7-6d7e-4830-a0bd-08ca9823ed27', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.81712+00', '2026-10-20 13:55:02.81712+00');
INSERT INTO public.artwork_versions VALUES ('fe92880b-ed39-4c6c-a3f4-79139bc491cd', 'ad1cb3ba-be38-44f0-aa66-429a8d279015', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.838469+00', '2026-10-20 13:55:02.838469+00');
INSERT INTO public.artwork_versions VALUES ('6d6201cd-4cbb-4490-b7d9-eed1b8738d72', '37eceb72-034e-4cca-b007-f57016530050', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 13:55:02.859808+00', '2026-10-20 13:55:02.859808+00');
INSERT INTO public.artwork_versions VALUES ('fa971f09-6794-447e-b1eb-21828a0a5ee3', '37eceb72-034e-4cca-b007-f57016530050', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 13:55:02.863778+00', '2026-10-20 13:55:02.863778+00');
INSERT INTO public.artwork_versions VALUES ('375b18b8-a63c-42b0-b09e-ee3516184123', '37eceb72-034e-4cca-b007-f57016530050', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.865399+00', '2026-10-20 13:55:02.865399+00');
INSERT INTO public.artwork_versions VALUES ('8944fc8c-a55e-4541-9571-f29df88a5f19', '81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 13:55:02.931079+00', '2026-10-20 13:55:02.931079+00');
INSERT INTO public.artwork_versions VALUES ('f87109c4-2f46-48ac-8845-facc4c65e045', 'f4308466-c635-44e8-9c3f-3a5fb478f530', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.951781+00', '2026-10-20 13:55:02.951781+00');
INSERT INTO public.artwork_versions VALUES ('ecd6164c-f66a-4e7b-807e-f8b571e2aeb5', 'a75374f3-df11-486e-a475-0152fce6d602', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 13:55:02.977009+00', '2026-10-20 13:55:02.977009+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.audit_log VALUES ('2ffaadfd-1d38-43f7-89c1-136512faa2d7', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', NULL, 'system', 'sponsorship_package', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285', 'create', NULL, '{"name": "Headline sponsor", "lines": [{"quantity": 6, "description": "Logo on 6 hanging banners"}, {"quantity": 1, "description": "Entrance feature branding"}], "price": "25000.00", "places": 1, "description": "Top billing across the venue"}', 'Added package Headline sponsor at £25,000', NULL, NULL, '2026-10-20 13:55:02.183803+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('b77620da-8d28-4ac2-bbce-3ff9f532b75b', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', NULL, 'system', 'sponsor', '954d3f91-aed4-4add-a48e-46d076c6f0c6', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "c7d2dcf3-14c0-4170-9fba-bb3b917f4285", "packageName": "Headline sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["6 × Logo on 6 hanging banners", "Entrance feature branding"]}, "packagePrice": "22500.00", "packageSoldAt": "2026-10-10T13:55:01.964Z", "packagePriceNote": "Early-booking discount"}', 'BuildCo bought Headline sponsor for £22,500 (list £25,000: Early-booking discount)', NULL, NULL, '2026-10-20 13:55:02.183803+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('6b67591f-d0d5-4838-829a-d8ac5cee38b0', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', NULL, 'system', 'sponsorship_package', 'a720163f-f09d-45f4-baec-d3b8ff3db326', 'create', NULL, '{"name": "Seminar theatre sponsor", "lines": [{"quantity": 1, "description": "Seminar theatre branding"}], "price": "8000.00", "places": 2, "description": "Branding in the seminar theatre"}', 'Added package Seminar theatre sponsor at £8,000', NULL, NULL, '2026-10-20 13:55:02.24077+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('ebfd80d3-8eae-4c9e-99bb-820a9fd006b9', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', NULL, 'system', 'sponsor', 'e3225ff5-b193-460e-9748-c978511eb9ae', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "a720163f-f09d-45f4-baec-d3b8ff3db326", "packageName": "Seminar theatre sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["Seminar theatre branding"]}, "packagePrice": "8000.00", "packageSoldAt": "2026-10-10T13:55:01.964Z", "packagePriceNote": null}', 'ToolMart bought Seminar theatre sponsor for £8,000', NULL, NULL, '2026-10-20 13:55:02.24077+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('442ca1ef-0e51-4497-8d39-e70a2ce0444e', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', NULL, 'system', 'sponsorship_package', '26e005a0-baf7-417a-9868-55934ef10d3a', 'create', NULL, '{"name": "Feature area sponsor", "lines": [{"quantity": 2, "description": "Feature area banners"}, {"quantity": 1, "description": "Logo in the event guide"}], "price": "12000.00", "places": 3, "description": "Branding around the feature area"}', 'Added package Feature area sponsor at £12,000', NULL, NULL, '2026-10-20 13:55:02.260761+00', NULL, NULL);


--
-- Data for Name: auth_account; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: auth_rate_limit; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: auth_session; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: auth_verification; Type: TABLE DATA; Schema: public; Owner: -
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

INSERT INTO public.contractors VALUES ('d4c469ef-47b9-4f8d-89dc-7a076f8e94e2', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-20 13:55:02.163159+00', '2026-10-20 13:55:02.163159+00');
INSERT INTO public.contractors VALUES ('a0e6b780-c186-4d37-9ff9-7618ff2afa80', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-20 13:55:02.166008+00', '2026-10-20 13:55:02.166008+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-20 13:55:02.290643+00', '2026-10-20 13:55:02.290643+00', true);
INSERT INTO public.departments VALUES ('8c70a9ee-40a9-406f-9141-61229fc7802c', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-20 13:55:02.300468+00', '2026-10-20 13:55:02.300468+00', true);
INSERT INTO public.departments VALUES ('8de66405-e14e-42be-bb1e-0fb99a8f2096', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Sales', 3, false, '{sponsor}', false, '2026-10-20 13:55:02.308142+00', '2026-10-20 13:55:02.308142+00', true);
INSERT INTO public.departments VALUES ('e39fed2a-3763-4f6b-9f65-b85cd89faa3a', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-20 13:55:02.315034+00', '2026-10-20 13:55:02.315034+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('cf9ca081-cbf4-4950-b075-80db9789af4f', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00');
INSERT INTO public.documents VALUES ('a23e475b-281b-452b-8311-4501c4cf7248', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00');
INSERT INTO public.documents VALUES ('bea4c7ff-adc9-4a09-9dae-b0599f8afa6d', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00');
INSERT INTO public.documents VALUES ('15a7c093-7628-417d-978a-fb75735c57d2', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'b503cd8d-5750-463b-bde3-d7922e16951e', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00');
INSERT INTO public.documents VALUES ('eae5f6fa-a091-4dd4-9cd4-bff74493abcb', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00');
INSERT INTO public.documents VALUES ('53c70b03-3321-465f-842d-33974ce3ae8f', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00');
INSERT INTO public.documents VALUES ('a77d2abc-552d-46a3-a009-74f0dc39cb3d', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00');
INSERT INTO public.documents VALUES ('f737af36-bfce-4e89-840f-8587b92cfdae', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'a3ba06b2-7fb4-499a-b79a-349b9018ad7d', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00');
INSERT INTO public.documents VALUES ('19be1566-3ad1-4845-9b64-845668046322', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00');
INSERT INTO public.documents VALUES ('8c08253d-96b5-4f17-a65f-1d98fe27aecc', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00');
INSERT INTO public.documents VALUES ('acc9f1db-936d-4708-8894-cd595bb328b5', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00');
INSERT INTO public.documents VALUES ('467798db-3136-44c1-a902-a1ca8641e694', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', 'f0ed0327-e1c3-436c-9498-a153e869fb85', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00');
INSERT INTO public.documents VALUES ('0f1bc34f-1ade-41da-b377-6dfed5a6ab6e', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00');
INSERT INTO public.documents VALUES ('e307b5b2-7197-4d23-92b1-1ef738ab6967', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00');
INSERT INTO public.documents VALUES ('8d35e8c3-05d0-42c9-819b-444fa49d0ae2', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00');
INSERT INTO public.documents VALUES ('9ed4038b-7118-4105-a794-ec1b10d7d524', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '9e7ca5d6-4270-4586-8979-df289f75a615', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00');
INSERT INTO public.documents VALUES ('85b0ab2e-2bd5-4e44-83eb-920e3c616181', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00');
INSERT INTO public.documents VALUES ('e2e67a7f-1718-4330-937a-5b7476ccb0b8', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00');
INSERT INTO public.documents VALUES ('a6c7432e-c619-4fed-88ab-6292fff96546', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00');
INSERT INTO public.documents VALUES ('d34cd87e-3e81-4a76-85c5-c56f2418b8cb', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_submission', '6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('5be46a2d-6341-433c-9c7c-01c93454a5d3', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'signage', 34, '2026-10-20 13:55:03.009333+00', '2026-10-20 13:55:03.011339+00');
INSERT INTO public.edition_counters VALUES ('e6691e7a-87f1-4206-a921-b80e2210b67e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_design', 1, '2026-10-20 13:55:03.054263+00', '2026-10-20 13:55:03.054263+00');
INSERT INTO public.edition_counters VALUES ('c5e1b9bd-4b34-4f28-8077-7a3e6cea4d71', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_item', 1, '2026-10-20 13:55:03.054263+00', '2026-10-20 13:55:03.054263+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('d0ebbf30-47a0-4e0b-80f5-0b308b1651be', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-20 13:55:02.070969+00', '2026-10-20 13:55:02.070969+00');
INSERT INTO public.edition_deadlines VALUES ('e67cf361-c3a3-4e9e-8df9-83e98b053528', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-20 13:55:02.072949+00', '2026-10-20 13:55:02.072949+00');
INSERT INTO public.edition_deadlines VALUES ('79e30a22-7915-4dfe-908a-b9daeb846949', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-20 13:55:02.074414+00', '2026-10-20 13:55:02.074414+00');
INSERT INTO public.edition_deadlines VALUES ('aaca83ae-307d-4d4b-8fb3-f4163d466463', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-20 13:55:02.076011+00', '2026-10-20 13:55:02.076011+00');
INSERT INTO public.edition_deadlines VALUES ('5cd13a3b-b5e9-4b77-8bc0-c09d47c4b940', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-20 13:55:02.077291+00', '2026-10-20 13:55:02.077291+00');
INSERT INTO public.edition_deadlines VALUES ('84beb42d-0336-40f6-98ff-457138f28c17', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-20 13:55:02.078851+00', '2026-10-20 13:55:02.078851+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'fa3ca90f-a55b-4bd9-9d37-3f5cd0cb9bc3', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-20 13:55:02.067466+00', '2026-10-20 13:55:02.067466+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('fa3ca90f-a55b-4bd9-9d37-3f5cd0cb9bc3', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'UK Construction Week', 'UKCW', '2026-10-20 13:55:02.031829+00', '2026-10-20 13:55:02.031829+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('a45ac2ad-a9fe-4e93-8766-9bccbde34aba', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Exhibitor Co', 'A10', '5a773592-ce98-4962-a355-9f8edfa43845', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', '2026-10-20 13:55:02.407281+00', '2026-10-20 13:55:02.407281+00');
INSERT INTO public.exhibitors VALUES ('f27ad077-a775-4b94-bcbc-12b88ad357bc', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SteelFrame Systems', 'A20', '5a773592-ce98-4962-a355-9f8edfa43845', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', '2026-10-20 13:55:02.410252+00', '2026-10-20 13:55:02.410252+00');
INSERT INTO public.exhibitors VALUES ('736282a9-d56c-48b7-8a7b-7623584c68fb', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'BrickWorks UK', 'A30', '5a773592-ce98-4962-a355-9f8edfa43845', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', '2026-10-20 13:55:02.414758+00', '2026-10-20 13:55:02.414758+00');
INSERT INTO public.exhibitors VALUES ('a82d8416-2dd7-4e3c-804f-e2611f044804', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Timber Trade Ltd', 'B10', '5a773592-ce98-4962-a355-9f8edfa43845', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', '2026-10-20 13:55:02.418565+00', '2026-10-20 13:55:02.418565+00');
INSERT INTO public.exhibitors VALUES ('51bb9463-b8e9-4c10-9bff-8d0cc87dc8ba', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'GlassTech', 'B20', '5a773592-ce98-4962-a355-9f8edfa43845', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', '2026-10-20 13:55:02.421094+00', '2026-10-20 13:55:02.421094+00');
INSERT INTO public.exhibitors VALUES ('10fcc298-59d6-43b3-8741-53c7b7f1a764', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Insulate Pro', 'B30', '5a773592-ce98-4962-a355-9f8edfa43845', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', '2026-10-20 13:55:02.423757+00', '2026-10-20 13:55:02.423757+00');
INSERT INTO public.exhibitors VALUES ('20fc9b05-dc1f-413a-8ae7-c3b06c7c1628', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'RoofRight', 'C10', '50969d12-f23a-4849-94bd-26998592477b', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', '2026-10-20 13:55:02.42699+00', '2026-10-20 13:55:02.42699+00');
INSERT INTO public.exhibitors VALUES ('9a862529-f71e-4c90-80e9-92351c8e47e1', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'PlantHire Direct', 'C20', '50969d12-f23a-4849-94bd-26998592477b', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', '2026-10-20 13:55:02.430289+00', '2026-10-20 13:55:02.430289+00');
INSERT INTO public.exhibitors VALUES ('d18cdc97-a6e2-4c6f-bfcd-dfc4850b5fc0', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SafetyFirst PPE', 'D10', '50969d12-f23a-4849-94bd-26998592477b', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-20 13:55:02.433518+00', '2026-10-20 13:55:02.433518+00');
INSERT INTO public.exhibitors VALUES ('b74c44a2-5194-4e64-b1ba-3739ebf844ba', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'ToolMart Retail', 'D20', '50969d12-f23a-4849-94bd-26998592477b', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-20 13:55:02.436176+00', '2026-10-20 13:55:02.436176+00');
INSERT INTO public.exhibitors VALUES ('e52c848f-ccff-47ec-8e23-c1b27f84c53e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'EcoBuild Materials', 'D30', '50969d12-f23a-4849-94bd-26998592477b', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-20 13:55:02.438724+00', '2026-10-20 13:55:02.438724+00');
INSERT INTO public.exhibitors VALUES ('1cff6958-d592-4e65-9d02-466bbaf8141b', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SiteWise Software', 'D40', '50969d12-f23a-4849-94bd-26998592477b', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-20 13:55:02.441085+00', '2026-10-20 13:55:02.441085+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('cebaea7c-89b8-42ba-a93f-b544ed8fe3db', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'venue', 'venue', '22aec32d-8b06-44d2-86d1-e89aaa607710', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.386301+00', '2026-10-20 13:55:02.386301+00');
INSERT INTO public.external_grants VALUES ('a433f623-c902-4e25-b8cd-1a94f121abe8', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.393878+00', '2026-10-20 13:55:02.393878+00');
INSERT INTO public.external_grants VALUES ('fc8148ac-a08e-4ed2-aa22-0802ef6946e0', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.397739+00', '2026-10-20 13:55:02.397739+00');
INSERT INTO public.external_grants VALUES ('09f798dd-0e71-495f-b35c-fceffc405e7b', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'supplier', 'supplier', 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.400977+00', '2026-10-20 13:55:02.400977+00');
INSERT INTO public.external_grants VALUES ('09305e3b-a0f1-4649-9fd1-f065735c897a', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'sponsor', 'sponsor', '954d3f91-aed4-4add-a48e-46d076c6f0c6', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.404649+00', '2026-10-20 13:55:02.404649+00');
INSERT INTO public.external_grants VALUES ('6640fe68-377b-4fa7-b6f6-20fa2f57ce7f', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'exhibitor', 'exhibitor', 'a45ac2ad-a9fe-4e93-8766-9bccbde34aba', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-20 13:55:01.964+00', NULL, '2026-10-20 13:55:02.444696+00', '2026-10-20 13:55:02.444696+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('5a773592-ce98-4962-a355-9f8edfa43845', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-20 13:55:02.082093+00', '2026-10-20 13:55:02.082093+00');
INSERT INTO public.halls VALUES ('50969d12-f23a-4849-94bd-26998592477b', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-20 13:55:02.085912+00', '2026-10-20 13:55:02.085912+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('2d82f862-4f51-4798-bd25-b4fbf0c7bf10', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Hanging banner', 'hanging_banner', '23b32713-7062-4516-9bbf-c10e5645df8a', 'rigged', true, 0, '2026-10-20 13:55:02.355244+00', '2026-10-20 13:55:02.355244+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e372e519-b34c-49cb-9983-2265a28d8939', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Foamex board', 'foamex_board', '23b32713-7062-4516-9bbf-c10e5645df8a', 'wall_mounted', false, 1, '2026-10-20 13:55:02.3578+00', '2026-10-20 13:55:02.3578+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e2be17db-14f4-4ef7-bd3e-e8c409d657fa', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Fabric graphic', 'fabric_graphic', '23b32713-7062-4516-9bbf-c10e5645df8a', 'shell_mounted', false, 2, '2026-10-20 13:55:02.359916+00', '2026-10-20 13:55:02.359916+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('62a02c4b-80d8-43ec-808f-b5e17e781b42', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Floor vinyl', 'floor_vinyl', '23b32713-7062-4516-9bbf-c10e5645df8a', 'floor', false, 3, '2026-10-20 13:55:02.361636+00', '2026-10-20 13:55:02.361636+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4fe1d113-e4e4-423b-86e1-0671568c2ad7', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Aisle sign', 'aisle_sign', '23b32713-7062-4516-9bbf-c10e5645df8a', 'rigged', true, 4, '2026-10-20 13:55:02.363367+00', '2026-10-20 13:55:02.363367+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('c4939fcd-c60b-4b7b-94e2-6a5a15c39eba', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Entrance feature', 'entrance_feature', '23b32713-7062-4516-9bbf-c10e5645df8a', 'freestanding', true, 5, '2026-10-20 13:55:02.365008+00', '2026-10-20 13:55:02.365008+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('5e5030f7-f0a4-4647-ba71-d4d51d10bfb5', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Registration', 'registration', '23b32713-7062-4516-9bbf-c10e5645df8a', 'freestanding', false, 6, '2026-10-20 13:55:02.367511+00', '2026-10-20 13:55:02.367511+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('b356665a-43ad-468d-a163-0461051fa045', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Seminar theatre', 'seminar_theatre', '23b32713-7062-4516-9bbf-c10e5645df8a', 'freestanding', false, 7, '2026-10-20 13:55:02.369646+00', '2026-10-20 13:55:02.369646+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('45ee0e3a-dc59-462d-a291-0e2d75d9928c', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Feature area', 'feature_area', '23b32713-7062-4516-9bbf-c10e5645df8a', 'freestanding', false, 8, '2026-10-20 13:55:02.371033+00', '2026-10-20 13:55:02.371033+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('daad1330-6084-47af-a03a-b4544188734a', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'External', 'external', '23b32713-7062-4516-9bbf-c10e5645df8a', 'freestanding', true, 9, '2026-10-20 13:55:02.372668+00', '2026-10-20 13:55:02.372668+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('b9ee75d0-4725-4dee-b015-71803dd65a75', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Digital screen', 'digital_screen', '23b32713-7062-4516-9bbf-c10e5645df8a', 'digital', false, 10, '2026-10-20 13:55:02.374032+00', '2026-10-20 13:55:02.374032+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('de2f7d04-4c92-45e0-b6cc-e759bc81e8f4', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Branded lanyards', 'lanyard', '23b32713-7062-4516-9bbf-c10e5645df8a', NULL, false, 11, '2026-10-20 13:55:02.375337+00', '2026-10-20 13:55:02.375337+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('e7001649-5c96-45df-92bb-0d9a32de9307', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Show bags', 'show_bag', '23b32713-7062-4516-9bbf-c10e5645df8a', NULL, false, 12, '2026-10-20 13:55:02.376953+00', '2026-10-20 13:55:02.376953+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('aa59f119-f530-44ac-ac6b-0d6ccf203b98', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Registration branding', 'reg_branding', '23b32713-7062-4516-9bbf-c10e5645df8a', NULL, false, 13, '2026-10-20 13:55:02.37843+00', '2026-10-20 13:55:02.37843+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('2de2aebc-fbee-4cbd-a08e-98f6d9753e60', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Other signage', 'other_signage', '23b32713-7062-4516-9bbf-c10e5645df8a', NULL, false, 14, '2026-10-20 13:55:02.379987+00', '2026-10-20 13:55:02.379987+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('43180325-8514-4f82-8914-437cc757f7bd', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Other sponsorship item', 'other_sponsorship', '23b32713-7062-4516-9bbf-c10e5645df8a', NULL, false, 15, '2026-10-20 13:55:02.381645+00', '2026-10-20 13:55:02.381645+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('65107efc-7669-4e48-a431-d2fcc414b603', '5a773592-ce98-4962-a355-9f8edfa43845', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-20 13:55:02.089613+00', '2026-10-20 13:55:02.089613+00');
INSERT INTO public.locations VALUES ('35efa569-e2c2-4f0f-aada-03dddee2f6ba', '5a773592-ce98-4962-a355-9f8edfa43845', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-20 13:55:02.0927+00', '2026-10-20 13:55:02.0927+00');
INSERT INTO public.locations VALUES ('1161efb0-1909-47a7-ab2d-f8866ae000ae', '5a773592-ce98-4962-a355-9f8edfa43845', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-20 13:55:02.095592+00', '2026-10-20 13:55:02.095592+00');
INSERT INTO public.locations VALUES ('c551cda1-7ae6-4e03-91e0-b2b700565d95', '5a773592-ce98-4962-a355-9f8edfa43845', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-20 13:55:02.098754+00', '2026-10-20 13:55:02.098754+00');
INSERT INTO public.locations VALUES ('fe3882f4-14b1-445b-9f92-cca8f75d2504', '5a773592-ce98-4962-a355-9f8edfa43845', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-20 13:55:02.101822+00', '2026-10-20 13:55:02.101822+00');
INSERT INTO public.locations VALUES ('9e9394c3-2ef0-4096-9c17-fbde58088caf', '5a773592-ce98-4962-a355-9f8edfa43845', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-20 13:55:02.104589+00', '2026-10-20 13:55:02.104589+00');
INSERT INTO public.locations VALUES ('c8205d8b-ef52-4bfb-b51f-0daedad37f93', '50969d12-f23a-4849-94bd-26998592477b', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-20 13:55:02.107599+00', '2026-10-20 13:55:02.107599+00');
INSERT INTO public.locations VALUES ('ef508195-2c60-421b-9e26-01dbd2c5c77c', '50969d12-f23a-4849-94bd-26998592477b', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-20 13:55:02.1112+00', '2026-10-20 13:55:02.1112+00');
INSERT INTO public.locations VALUES ('b5461018-006c-4d49-b815-86b8e65ee521', '50969d12-f23a-4849-94bd-26998592477b', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-20 13:55:02.114491+00', '2026-10-20 13:55:02.114491+00');
INSERT INTO public.locations VALUES ('00529c5c-80c8-40a0-bf78-de062e65e699', '50969d12-f23a-4849-94bd-26998592477b', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-20 13:55:02.117108+00', '2026-10-20 13:55:02.117108+00');
INSERT INTO public.locations VALUES ('2d2a5be9-bf7c-47e7-9499-61ce7e7dc5bb', '50969d12-f23a-4849-94bd-26998592477b', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-20 13:55:02.120177+00', '2026-10-20 13:55:02.120177+00');
INSERT INTO public.locations VALUES ('4736da14-3a51-4a53-b5a7-6eb2b9e6d540', '50969d12-f23a-4849-94bd-26998592477b', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-20 13:55:02.126409+00', '2026-10-20 13:55:02.126409+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('00b50a5c-48ad-4dac-8e4b-c66723f8703c', '00000000-0000-4000-8000-000000000001', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'admin', '2026-10-20 13:55:02.007808+00', '2026-10-20 13:55:02.007808+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('5c8361bd-b6eb-4079-a184-799fa2d7a809', '00000000-0000-4000-8000-000000000006', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'viewer', '2026-10-20 13:55:02.029683+00', '2026-10-20 13:55:02.029683+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('8eff6832-62f4-4470-950d-95f57c430826', '00000000-0000-4000-8000-000000000002', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'ops', '2026-10-20 13:55:02.012613+00', '2026-10-20 13:55:02.297171+00', '{}', '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('a7c37344-be78-462a-b966-91807d9122b7', '00000000-0000-4000-8000-000000000004', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'sales', '2026-10-20 13:55:02.02257+00', '2026-10-20 13:55:02.312148+00', '{}', '8de66405-e14e-42be-bb1e-0fb99a8f2096', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('38c93874-2b43-49e7-859e-dd363f470af7', '00000000-0000-4000-8000-000000000005', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'event_director', '2026-10-20 13:55:02.026166+00', '2026-10-20 13:55:02.319447+00', '{}', 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('2b17b61c-abd5-4eaa-bd46-c85bd8697ee7', '00000000-0000-4000-8000-000000000003', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'marketing', '2026-10-20 13:55:02.016722+00', '2026-10-20 13:55:03.155621+00', '{"costs.edit": true}', '8c70a9ee-40a9-406f-9141-61229fc7802c', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-20 13:55:01.998977+00', '2026-10-20 13:55:01.998977+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'c4939fcd-c60b-4b7b-94e2-6a5a15c39eba', '5a773592-ce98-4962-a355-9f8edfa43845', '65107efc-7669-4e48-a431-d2fcc414b603', 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', 'c173cf85-22f3-4d9f-9442-86675d1dd1c3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '15797a0c-67c2-418d-b4ab-fc6d7d7324d2', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.449189+00', '2026-10-20 13:55:02.455133+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f90708a1-2157-4261-ad1d-cb7635283df7', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '5e5030f7-f0a4-4647-ba71-d4d51d10bfb5', '5a773592-ce98-4962-a355-9f8edfa43845', '35efa569-e2c2-4f0f-aada-03dddee2f6ba', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '5c9af79e-8ce9-45ab-8f76-726aec50441b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.477255+00', '2026-10-20 13:55:02.481849+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dd190be6-b1c8-4b15-9c27-fa4f2ab9313f', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '2d82f862-4f51-4798-bd25-b4fbf0c7bf10', '5a773592-ce98-4962-a355-9f8edfa43845', '1161efb0-1909-47a7-ab2d-f8866ae000ae', 'ops', '00000000-0000-4000-8000-000000000002', '954d3f91-aed4-4add-a48e-46d076c6f0c6', '7608fc00-d050-4669-a256-678e8179f18e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '820da2a4-aec1-472c-9906-c49995610eed', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.506803+00', '2026-10-20 13:55:02.513543+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('66d2e9f9-c2f6-4fb9-9314-fb18feee1d61', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'b356665a-43ad-468d-a163-0461051fa045', '5a773592-ce98-4962-a355-9f8edfa43845', 'c551cda1-7ae6-4e03-91e0-b2b700565d95', 'marketing', '00000000-0000-4000-8000-000000000003', 'e3225ff5-b193-460e-9748-c978511eb9ae', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '30681070-b791-4061-a45c-1ddfcfa4e894', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.536638+00', '2026-10-20 13:55:02.541796+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6a927a8e-2296-4a3b-ac5f-476cd5098dc4', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '62a02c4b-80d8-43ec-808f-b5e17e781b42', '5a773592-ce98-4962-a355-9f8edfa43845', 'fe3882f4-14b1-445b-9f92-cca8f75d2504', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '88b44ea7-3a81-4a0e-a9b5-fcc1060b892d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.560904+00', '2026-10-20 13:55:02.5648+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ec2750d6-aaca-42ae-b2a8-e5eb7a78b093', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '45ee0e3a-dc59-462d-a291-0e2d75d9928c', '5a773592-ce98-4962-a355-9f8edfa43845', '9e9394c3-2ef0-4096-9c17-fbde58088caf', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '1adf6db1-04bb-4757-bd25-dcb61936007a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.582935+00', '2026-10-20 13:55:02.586767+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c7691ad9-a181-4ad5-8452-ee490fee874f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6c14d34e-3c19-4f48-a98c-ce665cdf3809', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '2d82f862-4f51-4798-bd25-b4fbf0c7bf10', '50969d12-f23a-4849-94bd-26998592477b', 'c8205d8b-ef52-4bfb-b51f-0daedad37f93', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '7e9809c7-78f2-4dd2-a732-ae74a83deba1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.605158+00', '2026-10-20 13:55:02.609463+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d259edce-308b-4ccb-a9f9-babca5188475', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '4fe1d113-e4e4-423b-86e1-0671568c2ad7', '50969d12-f23a-4849-94bd-26998592477b', 'ef508195-2c60-421b-9e26-01dbd2c5c77c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '438cf599-bad9-48de-84f7-ebcd8f1665a0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.628669+00', '2026-10-20 13:55:02.631904+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c2a1c1e1-7ae0-438a-8c88-7e39f99c572c', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'b356665a-43ad-468d-a163-0461051fa045', '50969d12-f23a-4849-94bd-26998592477b', 'b5461018-006c-4d49-b815-86b8e65ee521', 'marketing', '00000000-0000-4000-8000-000000000003', 'e3225ff5-b193-460e-9748-c978511eb9ae', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '89743202-17bf-49e1-a7d7-2c159a925a22', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.645122+00', '2026-10-20 13:55:02.648131+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b27fa1a1-2573-4820-ae71-5aaba9689103', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'e2be17db-14f4-4ef7-bd3e-e8c409d657fa', '50969d12-f23a-4849-94bd-26998592477b', '00529c5c-80c8-40a0-bf78-de062e65e699', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '0ffc2e29-5a7f-470b-b2d8-0df1df9442e4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.664184+00', '2026-10-20 13:55:02.668289+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL);
INSERT INTO public.signage_items VALUES ('622d9203-6e0b-4e37-9145-7869805c6cb3', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'daad1330-6084-47af-a03a-b4544188734a', '50969d12-f23a-4849-94bd-26998592477b', '2d2a5be9-bf7c-47e7-9499-61ce7e7dc5bb', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'a2547dad-0afb-4209-ac29-faf873324c4a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.681775+00', '2026-10-20 13:55:02.686802+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', NULL);
INSERT INTO public.signage_items VALUES ('e1866883-2c14-4be6-a560-ab4de4ca9ea0', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '50969d12-f23a-4849-94bd-26998592477b', '4736da14-3a51-4a53-b5a7-6eb2b9e6d540', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '340bc477-bfb7-4f9f-bdf9-0c790db6f05f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.704817+00', '2026-10-20 13:55:02.709942+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-17 13:55:01.964+00');
INSERT INTO public.signage_items VALUES ('8bf745ce-27aa-4139-9598-fc21ae7a95d1', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '43180325-8514-4f82-8914-437cc757f7bd', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:03.007473+00', '2026-10-20 13:55:03.007473+00', 'sponsorship_item', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', '2026-11-07', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('18f0dd5a-b1bb-41f5-856b-48cb4454405a', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '5a773592-ce98-4962-a355-9f8edfa43845', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:03.052575+00', '2026-10-20 13:55:03.052575+00', 'stand_design', 'organiser', '[{"stepId": "6f9e73d6-d160-4014-9716-c7265e9c1313", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "96e895b9-9afe-4c0e-8048-fc6b331d1534", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ffb78223-3b09-4549-8963-05d934195a67', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'b9ee75d0-4725-4dee-b015-71803dd65a75', '5a773592-ce98-4962-a355-9f8edfa43845', '35efa569-e2c2-4f0f-aada-03dddee2f6ba', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, 'd0f3c618-fef9-4d18-983a-18d6c1a8170e', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '1adf755a-8754-48d2-a5ae-8996a5eba779', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.727646+00', '2026-10-20 13:55:02.732799+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c7691ad9-a181-4ad5-8452-ee490fee874f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-17 13:55:01.964+00');
INSERT INTO public.signage_items VALUES ('0ecfb702-61bb-47dd-b920-4794d33bffe8', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '4fe1d113-e4e4-423b-86e1-0671568c2ad7', '5a773592-ce98-4962-a355-9f8edfa43845', '1161efb0-1909-47a7-ab2d-f8866ae000ae', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '37b1bf5b-1d67-4de3-8684-b8c389b6cf96', '2026-10-17 13:55:01.964+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.751399+00', '2026-10-20 13:55:02.756458+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-17 13:55:01.964+00');
INSERT INTO public.signage_items VALUES ('146575e8-4dc9-4ddb-bba5-d19e71e38599', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '5a773592-ce98-4962-a355-9f8edfa43845', 'fe3882f4-14b1-445b-9f92-cca8f75d2504', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'dece8b5e-f08c-46f0-9b38-2c34046570ac', '2026-10-17 13:55:01.964+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.771157+00', '2026-10-20 13:55:02.77582+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-17 13:55:01.964+00');
INSERT INTO public.signage_items VALUES ('95ac976c-9272-406b-a2d7-1bee9e710dda', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '45ee0e3a-dc59-462d-a291-0e2d75d9928c', '5a773592-ce98-4962-a355-9f8edfa43845', '9e9394c3-2ef0-4096-9c17-fbde58088caf', 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '96ed1809-d1a3-47c3-b4c8-7abc12c978e2', '2026-10-17 13:55:01.964+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.792265+00', '2026-10-20 13:55:02.79642+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, '2026-10-17 13:55:01.964+00', '2026-10-17 13:55:01.964+00');
INSERT INTO public.signage_items VALUES ('ae52aad7-6d7e-4830-a0bd-08ca9823ed27', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '2d82f862-4f51-4798-bd25-b4fbf0c7bf10', '50969d12-f23a-4849-94bd-26998592477b', 'ef508195-2c60-421b-9e26-01dbd2c5c77c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'f26ea9b9-4972-48c7-baae-e8db946b4e01', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.815222+00', '2026-10-20 13:55:02.818197+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ad1cb3ba-be38-44f0-aa66-429a8d279015', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'e2be17db-14f4-4ef7-bd3e-e8c409d657fa', '50969d12-f23a-4849-94bd-26998592477b', '00529c5c-80c8-40a0-bf78-de062e65e699', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'fe92880b-ed39-4c6c-a3f4-79139bc491cd', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.835851+00', '2026-10-20 13:55:02.840063+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('37eceb72-034e-4cca-b007-f57016530050', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '2d82f862-4f51-4798-bd25-b4fbf0c7bf10', '5a773592-ce98-4962-a355-9f8edfa43845', '1161efb0-1909-47a7-ab2d-f8866ae000ae', 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', '7608fc00-d050-4669-a256-678e8179f18e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '375b18b8-a63c-42b0-b09e-ee3516184123', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.857725+00', '2026-10-20 13:55:02.86679+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1bc35d14-b42a-405f-b768-86678268d084', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '50969d12-f23a-4849-94bd-26998592477b', '4736da14-3a51-4a53-b5a7-6eb2b9e6d540', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.890818+00', '2026-10-20 13:55:02.890818+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d7399dd7-4922-486f-a8da-60cfe931ee72', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '5a773592-ce98-4962-a355-9f8edfa43845', '35efa569-e2c2-4f0f-aada-03dddee2f6ba', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.895733+00', '2026-10-20 13:55:02.895733+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('803cca3c-2c0f-4324-94ce-910ade867693', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '5e5030f7-f0a4-4647-ba71-d4d51d10bfb5', '50969d12-f23a-4849-94bd-26998592477b', 'c8205d8b-ef52-4bfb-b51f-0daedad37f93', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.900568+00', '2026-10-20 13:55:02.900568+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f811160a-6f51-405e-af4c-a34b6d9a17e7', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'b9ee75d0-4725-4dee-b015-71803dd65a75', '5a773592-ce98-4962-a355-9f8edfa43845', '9e9394c3-2ef0-4096-9c17-fbde58088caf', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, 'd0f3c618-fef9-4d18-983a-18d6c1a8170e', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.905305+00', '2026-10-20 13:55:02.905305+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c7691ad9-a181-4ad5-8452-ee490fee874f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dfa3c96c-5c9a-47db-b761-2e7354317b9c', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '62a02c4b-80d8-43ec-808f-b5e17e781b42', '50969d12-f23a-4849-94bd-26998592477b', 'b5461018-006c-4d49-b815-86b8e65ee521', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.911518+00', '2026-10-20 13:55:02.911518+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3be45581-5cdc-4d26-aee9-e2eb2988b13b', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'b356665a-43ad-468d-a163-0461051fa045', '50969d12-f23a-4849-94bd-26998592477b', 'b5461018-006c-4d49-b815-86b8e65ee521', 'marketing', '00000000-0000-4000-8000-000000000003', 'e3225ff5-b193-460e-9748-c978511eb9ae', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.916393+00', '2026-10-20 13:55:02.916393+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c824eeca-94e6-413c-b5ac-96ae27d30ff8', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'daad1330-6084-47af-a03a-b4544188734a', '50969d12-f23a-4849-94bd-26998592477b', '2d2a5be9-bf7c-47e7-9499-61ce7e7dc5bb', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.921193+00', '2026-10-20 13:55:02.921193+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c7691ad9-a181-4ad5-8452-ee490fee874f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('764fdc01-a165-473f-a293-9b74e41c34be', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '50969d12-f23a-4849-94bd-26998592477b', '2d2a5be9-bf7c-47e7-9499-61ce7e7dc5bb', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.925479+00', '2026-10-20 13:55:02.925479+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('81c9a0c3-e952-4c11-bbac-06f2d51dbd4e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '5a773592-ce98-4962-a355-9f8edfa43845', 'fe3882f4-14b1-445b-9f92-cca8f75d2504', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, '8944fc8c-a55e-4541-9571-f29df88a5f19', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.928973+00', '2026-10-20 13:55:02.93237+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f4308466-c635-44e8-9c3f-3a5fb478f530', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'c4939fcd-c60b-4b7b-94e2-6a5a15c39eba', '5a773592-ce98-4962-a355-9f8edfa43845', '65107efc-7669-4e48-a431-d2fcc414b603', 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', 'c173cf85-22f3-4d9f-9442-86675d1dd1c3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'f87109c4-2f46-48ac-8845-facc4c65e045', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.949973+00', '2026-10-20 13:55:02.952737+00', 'signage', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', NULL, NULL, NULL, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8e50b272-ed1a-4ad3-87c2-ff8fe448ef73', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'e372e519-b34c-49cb-9983-2265a28d8939', '50969d12-f23a-4849-94bd-26998592477b', '4736da14-3a51-4a53-b5a7-6eb2b9e6d540', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.969913+00', '2026-10-20 13:55:02.969913+00', 'signage', 'organiser', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a75374f3-df11-486e-a475-0152fce6d602', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'de2f7d04-4c92-45e0-b6cc-e759bc81e8f4', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 'ecd6164c-f66a-4e7b-807e-f8b571e2aeb5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.974432+00', '2026-10-20 13:55:02.978314+00', 'sponsorship_item', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', '2027-01-03', NULL, 9000.00, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5b5bc505-418a-4d90-92ac-b17ec0697e57', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'e7001649-5c96-45df-92bb-0d9a32de9307', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '954d3f91-aed4-4add-a48e-46d076c6f0c6', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:02.995735+00', '2026-10-20 13:55:02.995735+00', 'sponsorship_item', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}, {"stepId": "c9a167f7-1953-47a6-acd9-deb4ca47978c", "userId": null}]', '2026-11-09', NULL, 12500.00, '2026-10-10 13:55:01.964+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8f53963f-c2f4-4481-b4ca-4afc8bc62e93', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'aa59f119-f530-44ac-ac6b-0d6ccf203b98', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '23b32713-7062-4516-9bbf-c10e5645df8a', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 13:55:03.001208+00', '2026-10-20 13:55:03.001208+00', 'sponsorship_item', 'sponsor', '[{"stepId": "67b8642a-fe4f-42b5-85c6-15321c9c376c", "userId": null}, {"stepId": "603241d4-a67b-4e10-93d6-535336b119e2", "userId": null}]', '2027-02-17', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('01460ae9-f3a9-4a8c-8c26-0d8c0029bedd', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '146575e8-4dc9-4ddb-bba5-d19e71e38599', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'e632dd1d-5ee4-45ff-a306-9530f398b80a', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-20 13:55:02.787486+00', '2026-10-20 13:55:02.787486+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('7608fc00-d050-4669-a256-678e8179f18e', '954d3f91-aed4-4add-a48e-46d076c6f0c6', 'Logo on 6 hanging banners', 6, '2026-10-20 13:55:02.172712+00', '2026-10-20 13:55:02.183803+00', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285');
INSERT INTO public.sponsor_entitlements VALUES ('c173cf85-22f3-4d9f-9442-86675d1dd1c3', '954d3f91-aed4-4add-a48e-46d076c6f0c6', 'Entrance feature branding', 1, '2026-10-20 13:55:02.176611+00', '2026-10-20 13:55:02.183803+00', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285');
INSERT INTO public.sponsor_entitlements VALUES ('667c1857-d127-4fce-a3d9-19d75b3fd2b9', 'e3225ff5-b193-460e-9748-c978511eb9ae', 'Seminar theatre branding', 1, '2026-10-20 13:55:02.182132+00', '2026-10-20 13:55:02.24077+00', 'a720163f-f09d-45f4-baec-d3b8ff3db326');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('954d3f91-aed4-4add-a48e-46d076c6f0c6', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-20 13:55:02.169215+00', '2026-10-20 13:55:02.183803+00', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285', 22500.00, 'Early-booking discount', '2026-10-10 13:55:01.964+00');
INSERT INTO public.sponsors VALUES ('e3225ff5-b193-460e-9748-c978511eb9ae', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-20 13:55:02.179266+00', '2026-10-20 13:55:02.24077+00', 'a720163f-f09d-45f4-baec-d3b8ff3db326', 8000.00, NULL, '2026-10-10 13:55:01.964+00');


--
-- Data for Name: sponsorship_package_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_package_lines VALUES ('cb94c2c8-596c-4559-9642-534617ccc684', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285', 'Logo on 6 hanging banners', 6, 1, '2026-10-20 13:55:02.183803+00', '2026-10-20 13:55:02.183803+00');
INSERT INTO public.sponsorship_package_lines VALUES ('0dd942e1-4ce0-49da-939e-39cbea12c410', 'c7d2dcf3-14c0-4170-9fba-bb3b917f4285', 'Entrance feature branding', 1, 2, '2026-10-20 13:55:02.183803+00', '2026-10-20 13:55:02.183803+00');
INSERT INTO public.sponsorship_package_lines VALUES ('d1a1289d-1edf-4a6a-be77-ea1ab546d247', 'a720163f-f09d-45f4-baec-d3b8ff3db326', 'Seminar theatre branding', 1, 1, '2026-10-20 13:55:02.24077+00', '2026-10-20 13:55:02.24077+00');
INSERT INTO public.sponsorship_package_lines VALUES ('c74392e8-34ba-4c67-a077-e6405f2bcf79', '26e005a0-baf7-417a-9868-55934ef10d3a', 'Feature area banners', 2, 1, '2026-10-20 13:55:02.260761+00', '2026-10-20 13:55:02.260761+00');
INSERT INTO public.sponsorship_package_lines VALUES ('934d6ed6-a9a6-46ce-8c72-bb2478a3b480', '26e005a0-baf7-417a-9868-55934ef10d3a', 'Logo in the event guide', 1, 2, '2026-10-20 13:55:02.260761+00', '2026-10-20 13:55:02.260761+00');


--
-- Data for Name: sponsorship_packages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_packages VALUES ('c7d2dcf3-14c0-4170-9fba-bb3b917f4285', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Headline sponsor', 'Top billing across the venue', 25000.00, 1, 1, false, '2026-10-20 13:55:02.183803+00', '2026-10-20 13:55:02.183803+00');
INSERT INTO public.sponsorship_packages VALUES ('a720163f-f09d-45f4-baec-d3b8ff3db326', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Seminar theatre sponsor', 'Branding in the seminar theatre', 8000.00, 2, 2, false, '2026-10-20 13:55:02.24077+00', '2026-10-20 13:55:02.24077+00');
INSERT INTO public.sponsorship_packages VALUES ('26e005a0-baf7-417a-9868-55934ef10d3a', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Feature area sponsor', 'Branding around the feature area', 12000.00, 3, 3, false, '2026-10-20 13:55:02.260761+00', '2026-10-20 13:55:02.260761+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('b503cd8d-5750-463b-bde3-d7922e16951e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'a45ac2ad-a9fe-4e93-8766-9bccbde34aba', 'STD-BIRM27-A10', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 13:55:01.964+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.057763+00', '2026-10-20 13:55:03.057763+00');
INSERT INTO public.stand_submissions VALUES ('a3ba06b2-7fb4-499a-b79a-349b9018ad7d', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'f27ad077-a775-4b94-bcbc-12b88ad357bc', 'STD-BIRM27-A20', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 13:55:01.964+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.073297+00', '2026-10-20 13:55:03.073297+00');
INSERT INTO public.stand_submissions VALUES ('f0ed0327-e1c3-436c-9498-a153e869fb85', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '736282a9-d56c-48b7-8a7b-7623584c68fb', 'STD-BIRM27-A30', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-14 13:55:01.964+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.086636+00', '2026-10-20 13:55:03.086636+00');
INSERT INTO public.stand_submissions VALUES ('9e7ca5d6-4270-4586-8979-df289f75a615', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'a82d8416-2dd7-4e3c-804f-e2611f044804', 'STD-BIRM27-B10', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-14 13:55:01.964+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.103687+00', '2026-10-20 13:55:03.103687+00');
INSERT INTO public.stand_submissions VALUES ('6fb801b3-9ccd-4073-b7c1-c8a3667ecba2', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '51bb9463-b8e9-4c10-9bff-8d0cc87dc8ba', 'STD-BIRM27-B20', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-14 13:55:01.964+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.122161+00', '2026-10-20 13:55:03.122161+00');
INSERT INTO public.stand_submissions VALUES ('f7236e50-d2dd-4e9c-ad8d-41e26ededa04', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '10fcc298-59d6-43b3-8741-53c7b7f1a764', 'STD-BIRM27-B30', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.142753+00', '2026-10-20 13:55:03.142753+00');
INSERT INTO public.stand_submissions VALUES ('e412ac40-73c3-443a-b64b-292ccc1c1cb9', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '20fc9b05-dc1f-413a-8ae7-c3b06c7c1628', 'STD-BIRM27-C10', 'd4c469ef-47b9-4f8d-89dc-7a076f8e94e2', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.146236+00', '2026-10-20 13:55:03.146236+00');
INSERT INTO public.stand_submissions VALUES ('1a4c6bb0-9810-43fb-ad16-f2600d36aeca', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', '9a862529-f71e-4c90-80e9-92351c8e47e1', 'STD-BIRM27-C20', 'a0e6b780-c186-4d37-9ff9-7618ff2afa80', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 13:55:03.152487+00', '2026-10-20 13:55:03.152487+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('e632dd1d-5ee4-45ff-a306-9530f398b80a', 'f3949d21-dfe0-45a8-b4cd-e6822a74d5f2');
INSERT INTO public.supplier_service_links VALUES ('e632dd1d-5ee4-45ff-a306-9530f398b80a', 'adeca7cc-5630-4f7c-9e05-dabfa74e6151');
INSERT INTO public.supplier_service_links VALUES ('87e86510-cb56-4b78-b170-32204c4fb6bd', '9e26b05d-de53-46b2-a8fb-8f885bb851c3');
INSERT INTO public.supplier_service_links VALUES ('87e86510-cb56-4b78-b170-32204c4fb6bd', 'adeca7cc-5630-4f7c-9e05-dabfa74e6151');
INSERT INTO public.supplier_service_links VALUES ('87e86510-cb56-4b78-b170-32204c4fb6bd', 'abdea2a9-5a53-4b93-9a20-dc757eb63f81');
INSERT INTO public.supplier_service_links VALUES ('d0f3c618-fef9-4d18-983a-18d6c1a8170e', '91cc40d1-06e3-4709-94f8-08129934a1c0');
INSERT INTO public.supplier_service_links VALUES ('d0f3c618-fef9-4d18-983a-18d6c1a8170e', 'abdea2a9-5a53-4b93-9a20-dc757eb63f81');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('f3949d21-dfe0-45a8-b4cd-e6822a74d5f2', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Signage print', 1, false, '2026-10-20 13:55:02.138803+00', '2026-10-20 13:55:02.138803+00');
INSERT INTO public.supplier_services VALUES ('91cc40d1-06e3-4709-94f8-08129934a1c0', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Digital screens & AV', 2, false, '2026-10-20 13:55:02.141289+00', '2026-10-20 13:55:02.141289+00');
INSERT INTO public.supplier_services VALUES ('9e26b05d-de53-46b2-a8fb-8f885bb851c3', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Rigging', 3, false, '2026-10-20 13:55:02.143314+00', '2026-10-20 13:55:02.143314+00');
INSERT INTO public.supplier_services VALUES ('adeca7cc-5630-4f7c-9e05-dabfa74e6151', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Installation', 4, false, '2026-10-20 13:55:02.145134+00', '2026-10-20 13:55:02.145134+00');
INSERT INTO public.supplier_services VALUES ('abdea2a9-5a53-4b93-9a20-dc757eb63f81', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Staffing', 5, false, '2026-10-20 13:55:02.146794+00', '2026-10-20 13:55:02.146794+00');
INSERT INTO public.supplier_services VALUES ('cb4b9fff-b618-41d5-b40e-e1cc392c460c', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Furniture', 6, false, '2026-10-20 13:55:02.148197+00', '2026-10-20 13:55:02.148197+00');
INSERT INTO public.supplier_services VALUES ('5d354895-4d22-42c4-8de3-bfe8cf07ac6f', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Structural engineering', 7, false, '2026-10-20 13:55:02.149243+00', '2026-10-20 13:55:02.149243+00');
INSERT INTO public.supplier_services VALUES ('30bdfc23-00da-4fef-a0c4-d9e1fddd52a7', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Floor Manager', 8, false, '2026-10-20 13:55:02.150431+00', '2026-10-20 13:55:02.150431+00');
INSERT INTO public.supplier_services VALUES ('96f20356-5098-4a48-b4e5-13eaf94e40fa', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Security', 9, false, '2026-10-20 13:55:02.151752+00', '2026-10-20 13:55:02.151752+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('e632dd1d-5ee4-45ff-a306-9530f398b80a', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-20 13:55:02.130073+00', '2026-10-20 13:55:02.130073+00', false);
INSERT INTO public.suppliers VALUES ('87e86510-cb56-4b78-b170-32204c4fb6bd', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-20 13:55:02.133787+00', '2026-10-20 13:55:02.133787+00', false);
INSERT INTO public.suppliers VALUES ('d0f3c618-fef9-4d18-983a-18d6c1a8170e', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-20 13:55:02.137001+00', '2026-10-20 13:55:02.137001+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('e5edecec-24eb-4749-9a92-0800fda80375', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-27', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '767a4f6e-8b5c-4286-a8b6-a4bcd4c874e6', NULL, '2026-10-20 13:55:03.161552+00', '2026-10-20 13:55:03.161552+00', NULL);
INSERT INTO public.tasks VALUES ('63768dec-92c9-4d03-bcfa-f83e157b14d5', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-30', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 13:55:03.165691+00', '2026-10-20 13:55:03.165691+00', NULL);
INSERT INTO public.tasks VALUES ('e29c9a53-2c8c-4c2e-94bb-10afdef90853', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Walk the hall with the venue', NULL, 'done', '2026-10-15', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-20 13:55:01.964+00', '2026-10-20 13:55:03.167204+00', '2026-10-20 13:55:03.167204+00', '63768dec-92c9-4d03-bcfa-f83e157b14d5');
INSERT INTO public.tasks VALUES ('be2bcc8e-9249-40e7-9c33-84f4fb588b45', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', '53b3303d-976b-45ef-a7d0-693ed1dd36b7', 'Send sign positions to the printer', NULL, 'open', '2026-10-19', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 13:55:03.167204+00', '2026-10-20 13:55:03.167204+00', '63768dec-92c9-4d03-bcfa-f83e157b14d5');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.004817+00', '2026-10-20 13:55:02.004817+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.011039+00', '2026-10-20 13:55:02.011039+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.014757+00', '2026-10-20 13:55:02.014757+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.020156+00', '2026-10-20 13:55:02.020156+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.024585+00', '2026-10-20 13:55:02.024585+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-20 13:55:02.028054+00', '2026-10-20 13:55:02.028054+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.383389+00', '2026-10-20 13:55:02.383389+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.389874+00', '2026-10-20 13:55:02.389874+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.395585+00', '2026-10-20 13:55:02.395585+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.399001+00', '2026-10-20 13:55:02.399001+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.402603+00', '2026-10-20 13:55:02.402603+00', false);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-20 13:55:02.442647+00', '2026-10-20 13:55:02.442647+00', false);


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('2efd3025-e2b8-478a-bf15-1513c8ce1962', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-20 13:55:02.044385+00', '2026-10-20 13:55:02.044385+00');
INSERT INTO public.venue_rules VALUES ('5075e068-e8eb-4beb-952a-13d459b0576b', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-20 13:55:02.048027+00', '2026-10-20 13:55:02.048027+00');
INSERT INTO public.venue_rules VALUES ('5dd031fb-8124-4104-addd-6203d50451c3', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-20 13:55:02.051254+00', '2026-10-20 13:55:02.051254+00');
INSERT INTO public.venue_rules VALUES ('dfa66ded-9712-4ce6-a3a1-d387f9a83e49', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-20 13:55:02.054367+00', '2026-10-20 13:55:02.054367+00');
INSERT INTO public.venue_rules VALUES ('30ece034-e95b-4a03-85f8-8ab8753e4466', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-20 13:55:02.057551+00', '2026-10-20 13:55:02.057551+00');
INSERT INTO public.venue_rules VALUES ('c2c5921b-8593-4c8a-9bfc-4d6677ec50ff', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-20 13:55:02.060586+00', '2026-10-20 13:55:02.060586+00');
INSERT INTO public.venue_rules VALUES ('f4697fad-e711-4812-96f7-0d21624850cc', '22aec32d-8b06-44d2-86d1-e89aaa607710', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-20 13:55:02.063431+00', '2026-10-20 13:55:02.063431+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('22aec32d-8b06-44d2-86d1-e89aaa607710', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-20 13:55:02.034431+00', '2026-10-20 13:55:02.034431+00', false);
INSERT INTO public.venues VALUES ('3e7c3bf0-c8c2-4a11-bcd6-913411126a6c', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-20 13:55:02.037768+00', '2026-10-20 13:55:02.037768+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('1dcc830e-b53c-460a-895d-74a728ddceff', '23b32713-7062-4516-9bbf-c10e5645df8a', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-20 13:55:02.27849+00', '2026-10-20 13:55:02.27849+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('cafa3da5-55b3-4ee3-9c74-ee548400871b', '23b32713-7062-4516-9bbf-c10e5645df8a', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-20 13:55:02.28127+00', '2026-10-20 13:55:02.28127+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('6c5ba552-76e9-4b2e-afec-d6da816ed8df', '23b32713-7062-4516-9bbf-c10e5645df8a', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-20 13:55:02.282432+00', '2026-10-20 13:55:02.282432+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('964566a4-0cce-4591-802e-7aa14fc778ab', '23b32713-7062-4516-9bbf-c10e5645df8a', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 13:55:02.283457+00', '2026-10-20 13:55:02.283457+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('736b90e5-ff06-4a28-82dd-997f50548511', '3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 13:55:03.031103+00', '2026-10-20 13:55:03.035238+00', '{organiser,sponsor}', false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a');
INSERT INTO public.workflow_steps VALUES ('b962c2e9-1c25-469d-84f3-ebd9bea4a302', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-20 13:55:02.345643+00', '2026-10-20 13:55:02.345643+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('c5d8b4ef-9862-474b-89fd-a1e3a65a1930', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-20 13:55:02.347287+00', '2026-10-20 13:55:02.347287+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('62da8cfa-ec42-46b7-b6fb-60807d1dc7f8', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-20 13:55:02.348735+00', '2026-10-20 13:55:02.348735+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('03966daa-c49a-45ed-9e6a-b7edfa2c71f3', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-20 13:55:02.350093+00', '2026-10-20 13:55:02.350093+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('d1c1afbd-8821-43c2-a1fb-16ea88cd5e19', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-20 13:55:02.351222+00', '2026-10-20 13:55:02.351222+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('c313293f-58e5-4563-8ac0-b4a2640e99b4', '60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 13:55:02.352525+00', '2026-10-20 13:55:02.352525+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('67b8642a-fe4f-42b5-85c6-15321c9c376c', '23b32713-7062-4516-9bbf-c10e5645df8a', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 13:55:02.272465+00', '2026-10-20 13:55:03.019778+00', '{organiser,sponsor}', false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9');
INSERT INTO public.workflow_steps VALUES ('603241d4-a67b-4e10-93d6-535336b119e2', '23b32713-7062-4516-9bbf-c10e5645df8a', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 13:55:02.274528+00', '2026-10-20 13:55:03.021165+00', '{organiser,sponsor}', false, '8c70a9ee-40a9-406f-9141-61229fc7802c');
INSERT INTO public.workflow_steps VALUES ('c9a167f7-1953-47a6-acd9-deb4ca47978c', '23b32713-7062-4516-9bbf-c10e5645df8a', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-20 13:55:02.275869+00', '2026-10-20 13:55:03.022313+00', '{sponsor}', false, '8de66405-e14e-42be-bb1e-0fb99a8f2096');
INSERT INTO public.workflow_steps VALUES ('c7691ad9-a181-4ad5-8452-ee490fee874f', '23b32713-7062-4516-9bbf-c10e5645df8a', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 13:55:02.280096+00', '2026-10-20 13:55:03.02404+00', '{organiser,sponsor}', false, 'e39fed2a-3763-4f6b-9f65-b85cd89faa3a');
INSERT INTO public.workflow_steps VALUES ('6f9e73d6-d160-4014-9716-c7265e9c1313', '3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 13:55:03.026371+00', '2026-10-20 13:55:03.032301+00', '{organiser,sponsor}', false, '6bd4a91a-64e7-4c83-8ba6-0adc09dd27a9');
INSERT INTO public.workflow_steps VALUES ('96e895b9-9afe-4c0e-8048-fc6b331d1534', '3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 13:55:03.028213+00', '2026-10-20 13:55:03.033164+00', '{organiser,sponsor}', false, '8c70a9ee-40a9-406f-9141-61229fc7802c');
INSERT INTO public.workflow_steps VALUES ('7f87e50c-096b-46ed-a6fb-c7e7ec2d89a1', '3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 13:55:03.029656+00', '2026-10-20 13:55:03.033853+00', '{sponsor}', false, '8de66405-e14e-42be-bb1e-0fb99a8f2096');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('23b32713-7062-4516-9bbf-c10e5645df8a', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Signage default', 'signage', true, false, '2026-10-20 13:55:02.270522+00', '2026-10-20 13:55:02.270522+00', NULL);
INSERT INTO public.workflows VALUES ('60e2433f-6ccb-4ccc-aaaf-6bdd88f1318d', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Stand default', 'stand', true, false, '2026-10-20 13:55:02.343609+00', '2026-10-20 13:55:02.343609+00', NULL);
INSERT INTO public.workflows VALUES ('3ca6bf0c-1a7e-4187-90c9-c5ad6e7838e6', '8ef1e237-b6e9-4443-8f4d-3b33cefa3b6e', 'Stand design sign-off', 'signage', false, false, '2026-10-20 13:55:03.014317+00', '2026-10-20 13:55:03.014317+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 15, true);


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
-- Name: approvers approvers_department_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_department_email_unique UNIQUE (department_id, email);


--
-- Name: approvers approvers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_pkey PRIMARY KEY (id);


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
-- Name: auth_account auth_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_account
    ADD CONSTRAINT auth_account_pkey PRIMARY KEY (id);


--
-- Name: auth_rate_limit auth_rate_limit_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_rate_limit
    ADD CONSTRAINT auth_rate_limit_key_unique UNIQUE (key);


--
-- Name: auth_rate_limit auth_rate_limit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_rate_limit
    ADD CONSTRAINT auth_rate_limit_pkey PRIMARY KEY (id);


--
-- Name: auth_session auth_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_session
    ADD CONSTRAINT auth_session_pkey PRIMARY KEY (id);


--
-- Name: auth_session auth_session_token_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_session
    ADD CONSTRAINT auth_session_token_unique UNIQUE (token);


--
-- Name: auth_verification auth_verification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_verification
    ADD CONSTRAINT auth_verification_pkey PRIMARY KEY (id);


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
-- Name: departments departments_org_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_org_name_unique UNIQUE (organisation_id, name);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


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
-- Name: sponsorship_package_lines sponsorship_package_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_package_lines
    ADD CONSTRAINT sponsorship_package_lines_pkey PRIMARY KEY (id);


--
-- Name: sponsorship_packages sponsorship_packages_id_edition_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_id_edition_unique UNIQUE (id, edition_id);


--
-- Name: sponsorship_packages sponsorship_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_pkey PRIMARY KEY (id);


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
-- Name: supplier_service_links supplier_service_links_supplier_id_service_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_links
    ADD CONSTRAINT supplier_service_links_supplier_id_service_id_pk PRIMARY KEY (supplier_id, service_id);


--
-- Name: supplier_services supplier_services_org_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_services
    ADD CONSTRAINT supplier_services_org_name_unique UNIQUE (organisation_id, name);


--
-- Name: supplier_services supplier_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_services
    ADD CONSTRAINT supplier_services_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: task_attachments task_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_attachments
    ADD CONSTRAINT task_attachments_pkey PRIMARY KEY (id);


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
-- Name: approval_instances_department_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_instances_department_idx ON public.approval_instances USING btree (assigned_department_id);


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
-- Name: approvers_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approvers_email_idx ON public.approvers USING btree (email);


--
-- Name: approvers_main_on_accept_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approvers_main_on_accept_by_idx ON public.approvers USING btree (main_on_accept_by);


--
-- Name: approvers_one_main; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approvers_one_main ON public.approvers USING btree (department_id) WHERE is_main;


--
-- Name: approvers_one_main_on_accept; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approvers_one_main_on_accept ON public.approvers USING btree (department_id) WHERE main_on_accept;


--
-- Name: approvers_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approvers_org_idx ON public.approvers USING btree (organisation_id);


--
-- Name: approvers_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approvers_user_idx ON public.approvers USING btree (user_id);


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
-- Name: audit_log_subject_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_subject_email_idx ON public.audit_log USING btree (organisation_id, subject_email);


--
-- Name: audit_log_subject_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_subject_user_idx ON public.audit_log USING btree (organisation_id, subject_user_id);


--
-- Name: auth_account_provider_account_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX auth_account_provider_account_unique ON public.auth_account USING btree (provider_id, account_id);


--
-- Name: auth_account_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_account_user_idx ON public.auth_account USING btree (user_id);


--
-- Name: auth_session_expires_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_session_expires_idx ON public.auth_session USING btree (expires_at);


--
-- Name: auth_session_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_session_user_idx ON public.auth_session USING btree (user_id);


--
-- Name: auth_verification_expires_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_verification_expires_idx ON public.auth_verification USING btree (expires_at);


--
-- Name: auth_verification_identifier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_verification_identifier_idx ON public.auth_verification USING btree (identifier);


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
-- Name: memberships_department_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_department_idx ON public.memberships USING btree (department_id);


--
-- Name: memberships_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_org_idx ON public.memberships USING btree (organisation_id);


--
-- Name: memberships_suspended_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_suspended_by_idx ON public.memberships USING btree (suspended_by);


--
-- Name: memberships_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_user_idx ON public.memberships USING btree (user_id);


--
-- Name: notifications_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_edition_idx ON public.notifications USING btree (edition_id);


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
-- Name: signage_items_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signage_items_parent_idx ON public.signage_items USING btree (parent_item_id);


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
-- Name: snags_raised_by_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX snags_raised_by_user_idx ON public.snags USING btree (raised_by_user_id);


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
-- Name: sponsor_entitlements_from_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsor_entitlements_from_package_idx ON public.sponsor_entitlements USING btree (from_package_id);


--
-- Name: sponsor_entitlements_sponsor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsor_entitlements_sponsor_idx ON public.sponsor_entitlements USING btree (sponsor_id);


--
-- Name: sponsors_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsors_edition_idx ON public.sponsors USING btree (edition_id);


--
-- Name: sponsors_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsors_package_idx ON public.sponsors USING btree (package_id);


--
-- Name: sponsorship_package_lines_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsorship_package_lines_package_idx ON public.sponsorship_package_lines USING btree (package_id, sort_order);


--
-- Name: sponsorship_packages_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsorship_packages_edition_idx ON public.sponsorship_packages USING btree (edition_id, sort_order);


--
-- Name: sponsorship_packages_edition_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sponsorship_packages_edition_name_unique ON public.sponsorship_packages USING btree (edition_id, lower(name));


--
-- Name: staff_invites_department_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX staff_invites_department_idx ON public.staff_invites USING btree (department_id);


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
-- Name: supplier_service_links_service_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_service_links_service_idx ON public.supplier_service_links USING btree (service_id);


--
-- Name: suppliers_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX suppliers_org_idx ON public.suppliers USING btree (organisation_id);


--
-- Name: task_attachments_task_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_attachments_task_idx ON public.task_attachments USING btree (task_id);


--
-- Name: task_attachments_uploaded_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_attachments_uploaded_by_idx ON public.task_attachments USING btree (uploaded_by);


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
-- Name: tasks_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_parent_idx ON public.tasks USING btree (parent_task_id);


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
-- Name: workflow_steps_department_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX workflow_steps_department_idx ON public.workflow_steps USING btree (department_id);


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
-- Name: approvers approvers_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER approvers_set_updated_at BEFORE UPDATE ON public.approvers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: auth_account auth_account_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auth_account_set_updated_at BEFORE UPDATE ON public.auth_account FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: auth_session auth_session_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auth_session_set_updated_at BEFORE UPDATE ON public.auth_session FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: auth_verification auth_verification_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auth_verification_set_updated_at BEFORE UPDATE ON public.auth_verification FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: departments departments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER departments_set_updated_at BEFORE UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: sponsorship_package_lines sponsorship_package_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsorship_package_lines_set_updated_at BEFORE UPDATE ON public.sponsorship_package_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sponsorship_packages sponsorship_packages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsorship_packages_set_updated_at BEFORE UPDATE ON public.sponsorship_packages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: staff_invites staff_invites_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER staff_invites_set_updated_at BEFORE UPDATE ON public.staff_invites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: stand_submissions stand_submissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stand_submissions_set_updated_at BEFORE UPDATE ON public.stand_submissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: supplier_services supplier_services_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_services_set_updated_at BEFORE UPDATE ON public.supplier_services FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: suppliers suppliers_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suppliers_set_updated_at BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: task_attachments task_attachments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_attachments_set_updated_at BEFORE UPDATE ON public.task_attachments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: approval_instances approval_instances_assigned_department_id_departments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_instances
    ADD CONSTRAINT approval_instances_assigned_department_id_departments_id_fk FOREIGN KEY (assigned_department_id) REFERENCES public.departments(id);


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
-- Name: approvers approvers_department_id_departments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_department_id_departments_id_fk FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: approvers approvers_main_on_accept_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_main_on_accept_by_users_id_fk FOREIGN KEY (main_on_accept_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approvers approvers_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: approvers approvers_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: auth_account auth_account_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_account
    ADD CONSTRAINT auth_account_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: auth_session auth_session_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_session
    ADD CONSTRAINT auth_session_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: departments departments_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


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
-- Name: memberships memberships_department_id_departments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_department_id_departments_id_fk FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: memberships memberships_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: memberships memberships_suspended_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_suspended_by_users_id_fk FOREIGN KEY (suspended_by) REFERENCES public.users(id);


--
-- Name: memberships memberships_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications notifications_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id) ON DELETE SET NULL;


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
-- Name: signage_items signage_items_parent_item_id_signage_items_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signage_items
    ADD CONSTRAINT signage_items_parent_item_id_signage_items_id_fk FOREIGN KEY (parent_item_id) REFERENCES public.signage_items(id);


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
-- Name: snags snags_raised_by_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snags
    ADD CONSTRAINT snags_raised_by_user_id_users_id_fk FOREIGN KEY (raised_by_user_id) REFERENCES public.users(id);


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
-- Name: sponsor_entitlements sponsor_entitlements_from_package_id_sponsorship_packages_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsor_entitlements
    ADD CONSTRAINT sponsor_entitlements_from_package_id_sponsorship_packages_id_fk FOREIGN KEY (from_package_id) REFERENCES public.sponsorship_packages(id);


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
-- Name: sponsors sponsors_package_same_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors
    ADD CONSTRAINT sponsors_package_same_event_fk FOREIGN KEY (package_id, edition_id) REFERENCES public.sponsorship_packages(id, edition_id);


--
-- Name: sponsorship_package_lines sponsorship_package_lines_package_id_sponsorship_packages_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_package_lines
    ADD CONSTRAINT sponsorship_package_lines_package_id_sponsorship_packages_id_fk FOREIGN KEY (package_id) REFERENCES public.sponsorship_packages(id) ON DELETE CASCADE;


--
-- Name: sponsorship_packages sponsorship_packages_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


--
-- Name: staff_invites staff_invites_department_id_departments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_invites
    ADD CONSTRAINT staff_invites_department_id_departments_id_fk FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


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
-- Name: supplier_service_links supplier_service_links_service_id_supplier_services_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_links
    ADD CONSTRAINT supplier_service_links_service_id_supplier_services_id_fk FOREIGN KEY (service_id) REFERENCES public.supplier_services(id) ON DELETE CASCADE;


--
-- Name: supplier_service_links supplier_service_links_supplier_id_suppliers_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_links
    ADD CONSTRAINT supplier_service_links_supplier_id_suppliers_id_fk FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE CASCADE;


--
-- Name: supplier_services supplier_services_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_services
    ADD CONSTRAINT supplier_services_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: suppliers suppliers_organisation_id_organisations_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_organisation_id_organisations_id_fk FOREIGN KEY (organisation_id) REFERENCES public.organisations(id);


--
-- Name: task_attachments task_attachments_task_id_tasks_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_attachments
    ADD CONSTRAINT task_attachments_task_id_tasks_id_fk FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_attachments task_attachments_uploaded_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_attachments
    ADD CONSTRAINT task_attachments_uploaded_by_users_id_fk FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


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
-- Name: tasks tasks_parent_task_id_tasks_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_parent_task_id_tasks_id_fk FOREIGN KEY (parent_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


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
-- Name: workflow_steps workflow_steps_department_id_departments_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_department_id_departments_id_fk FOREIGN KEY (department_id) REFERENCES public.departments(id);


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
-- Name: approvers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approvers ENABLE ROW LEVEL SECURITY;

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
-- Name: auth_account; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_account ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_rate_limit; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_rate_limit ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_session; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_session ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_verification; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_verification ENABLE ROW LEVEL SECURITY;

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
-- Name: departments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

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
-- Name: sponsorship_package_lines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsorship_package_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: sponsorship_packages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsorship_packages ENABLE ROW LEVEL SECURITY;

--
-- Name: staff_invites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff_invites ENABLE ROW LEVEL SECURITY;

--
-- Name: stand_submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stand_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: supplier_service_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.supplier_service_links ENABLE ROW LEVEL SECURITY;

--
-- Name: supplier_services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.supplier_services ENABLE ROW LEVEL SECURITY;

--
-- Name: suppliers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

--
-- Name: task_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_attachments ENABLE ROW LEVEL SECURITY;

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

\unrestrict sPJrzDYEdyUx276FtNjro3Wof9uL6P9Yaya0Jou69hIJxWgawHhy9GYkS70vjuZ

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
