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

\restrict wk5aTvcAh8CXhjGNyGREffdEeVM2lpcLnHcd7mwBSg1Vp7ytXCGhrr1rWO8SVCU

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

INSERT INTO public.approval_instances VALUES ('c6297675-bd62-4ae4-bbae-d6c9e4133070', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('852cec90-a8f1-4234-8653-b28d3e1ec1f1', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('91388b5d-3af5-4de8-a1c9-312549f069fa', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('4948f06e-7972-4372-83bc-d36f9631ace3', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c11308a4-a464-4002-b82d-08f1533362b4', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('af20518b-dc6e-4054-8679-36e17d63b727', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4f6510c6-94ff-427d-adc4-459612908e3b', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f0407cd1-2d6b-4d5c-a974-16f116c902d1', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.105399+00', '2026-10-20 14:29:58.105399+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('64ec979e-7835-4728-9fdb-5f5ccc1b5f46', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('256054f6-5980-4455-8eb7-1ce9468ceee7', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('584b58c7-cced-481d-bc94-e51d6da54d73', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('c5392987-5cdd-46c0-b271-1c62272723e9', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fe0c32ba-2d30-425a-9e1a-c769f0ad1850', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('891880b4-db64-416c-8394-143f3ebd5880', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('84a50c7e-a970-44d5-b4b8-846ffbeb5df9', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7e48015f-0437-4a6c-9130-218583841626', 'signage_item', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.130622+00', '2026-10-20 14:29:58.130622+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d6421155-ea98-44a3-aec4-b514d42ed81f', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 14:29:57.634+00', '2026-10-16 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('42115c9e-8777-4399-ba28-bd5b7ab81ab6', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 14:29:57.634+00', '2026-10-11 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('bfae3232-0017-4bc0-9745-41feaf5aca8a', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-10 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 14:29:57.634+00', '2026-10-13 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('c8c819c6-0d9c-444a-8786-80bcc3bcdfe9', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('028f2a7a-c1a7-4b6f-9c44-e080fa31392e', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('ad6fbe87-fa95-46dd-b6fc-82bc5a9b25b5', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('08226d15-d741-43e6-86ad-ba352fec3d2b', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8bb699fe-dc52-4556-82c1-0c114f1399e1', 'signage_item', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.14965+00', '2026-10-20 14:29:58.14965+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dc395e20-7512-466b-bcab-c4c91684c075', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('48f0a17a-a01c-4826-b58e-e5ef032e90e6', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('c5e86827-c2d5-428c-bd65-0b2acc908f18', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('9aff5939-d939-4f0f-af35-40b9ba453fb6', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('02b0436b-0277-4a02-bf65-8b3a57354a73', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('ffa87c00-31f0-488c-a6cd-21036f82ad4b', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c448a112-6cbf-48db-a0da-faf24cc4a41b', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aef24808-fd16-4052-8e36-bcf60fad39f5', 'signage_item', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.1664+00', '2026-10-20 14:29:58.1664+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3b0a4301-6c89-4ce6-be56-e28c22f08795', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('9991dabc-7cca-459d-ae2c-61be7ff511c3', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('215a002e-601b-4d4b-b609-616e62a7cbde', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('8d69fb0a-14c5-4fa6-95f2-f4f9f8e48d52', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a5b3a730-b09e-4078-8cc4-b0bb0c6a31d3', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('ff0443bc-e445-44fc-be8f-f0ad17b3adba', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c097f95e-a4eb-4073-bbf7-1464716de5da', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('58d5b828-f272-4ce7-8a1f-900f97096bb4', 'signage_item', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.185059+00', '2026-10-20 14:29:58.185059+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7d0de8b7-e78c-4d44-ad72-4a7fa9c387db', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 14:29:57.634+00', '2026-10-11 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('ded47cf7-204c-455e-9662-5d24054662e6', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 14:29:57.634+00', '2026-10-11 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('58c8fcd6-2be5-40a0-86d3-14efd7177f1a', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('ae6c3cdd-f4ef-48dc-9482-fa2f32eccbcd', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a076f071-da44-4500-a1e8-8432d11d4aaf', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', '2026-10-16 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('2bca37f9-0730-4815-8e80-b2a77bd15cba', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9d9b4f50-db57-4350-9a81-476878696cca', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('605426a9-2bd1-44b7-b458-a89061d6c43f', 'signage_item', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.204902+00', '2026-10-20 14:29:58.204902+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0a0d8dec-de15-4d83-b348-b4b990e18dbc', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('d8da895e-7917-45c4-add2-20c40e8bd1de', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('caeea970-9f03-4dcd-8d80-f15cad385b3c', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('cd1d2ce6-c30d-4921-abbf-04f0a2e6d69e', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1f1cc3e4-b053-4555-91ac-b38d3a057a8a', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('7b22e102-aae3-433f-a04a-7f9829602a73', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9e53883f-78a2-458e-9ae5-cf74984dfdd8', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('045476a0-1077-424f-ad89-c9fa94f76c94', 'signage_item', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.222782+00', '2026-10-20 14:29:58.222782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('883b585a-9a86-4cac-aca4-0f7931bb40ba', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('d15583ff-e2c1-44ed-89b3-17147b16e868', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('80f09237-bbb3-430e-a799-53778269eb34', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('57b81e8e-cc01-431a-a859-ab3444733052', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('79848ade-e9eb-47ca-aa29-6fc3abb495f1', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('6b6ff8e5-3057-4303-a8c3-6e7087cc3685', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d417124-cfae-4968-b33f-2a872471c8ac', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f611f62a-933a-4364-b755-d188ae3403bc', 'signage_item', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.241698+00', '2026-10-20 14:29:58.241698+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c68e0103-156d-443b-852e-0f733401b546', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('ea096741-ef98-452d-b656-d24cf7adf3f7', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('403a1cad-72c7-4cf8-b8b9-be1b5e741816', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 14:29:57.634+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('dd113f5e-f27f-4628-89e6-db4009583387', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a3c69565-0066-4aa1-a49d-fcf7ac271bf8', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('f1a67a3c-e7ab-4ec4-b907-cbe51641dda4', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('605f80cf-0fa9-4ddd-9d38-4c355a994ef6', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('abb62ce7-1ede-4937-aec3-8b4ed1e4e905', 'signage_item', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.261838+00', '2026-10-20 14:29:58.261838+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c1943310-ad85-453b-81db-d5164900aa7a', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('12261c95-b32d-45b1-99b3-527e398ae94b', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('e37afc63-7701-4dea-84a8-ab29cb594963', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('6b190abc-0efd-41ef-868c-33e2db348dcf', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ca5d6433-f748-42c7-b643-e280fb51da9b', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('e2e4008e-66c6-4768-bdd9-eb66395921b3', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bda7f68d-0c11-4dab-9e17-2aae5c39ce0b', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('72faba58-ead6-4a79-a86b-9024e349dd04', 'signage_item', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.285466+00', '2026-10-20 14:29:58.285466+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b0b2be8-b90a-4558-82b9-4b4b687f0347', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('d39a7be3-6897-4548-aef9-195ca8d8d1b4', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('7cda4924-ce45-4933-81c6-0400f60c06fd', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('063380f2-332a-4748-94f6-b1ebf3d86fcb', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d04c41ef-280a-4583-9722-dc2fb949871b', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7bece196-cc53-47c3-8ab9-391e3a3c4079', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('e54c6b58-b32c-4c0b-ab74-cc250b91037a', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3cce6db2-f57d-4f8e-8285-da79486abb89', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1d334bbb-e4cf-483d-b5ae-0bbcbdc94375', 'signage_item', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.309492+00', '2026-10-20 14:29:58.309492+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('abfc39e3-a379-42e1-8456-1a862bfd95b9', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('e035ed0e-09c1-4f7d-be8e-aff716836019', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('d6f0ec45-0dc5-4ea2-89fd-12a86eead7dd', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('ae7e1d2e-bfbf-422e-8c2d-e0de04b9b91d', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('92558882-2ea2-48a6-92bc-2a417a64c2a3', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('5f5e5541-d604-43de-9bb8-9e3d6f9eaf91', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef21a07e-af39-4754-9e70-d31885d57ece', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7d4cd229-19a9-4201-9beb-b1e362422c95', 'signage_item', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.336454+00', '2026-10-20 14:29:58.336454+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('39b8f0e4-f984-4772-a465-e6d80ee434d9', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('17bdaf1c-5786-429b-b4d3-a76b8431bb1e', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('296506c6-c27e-4cc2-a893-63bc680d9034', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('31cec53c-14af-4455-98ce-827a7321d0d4', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('db295603-16db-4118-922c-0099bb0523d2', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('f6403d5b-37ab-4c23-ae84-e5bd3d75bc32', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a1461034-512b-4520-ab22-3dbef825b4d0', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ce6ed133-f86d-4939-b9c8-40b79b70474b', 'signage_item', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.360363+00', '2026-10-20 14:29:58.360363+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6f5987a9-dc2d-4cb7-8d4f-171182943ece', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('2395fe09-1eea-4e24-90b8-6a73137171b0', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('419a88a6-076b-48e6-8c6c-e1f121c58375', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('0eabd9bd-1528-4ab5-ae64-1702d1bf0d6a', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d068003a-4550-4db6-8f41-f795a4461eed', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('70916bca-c1ed-42d0-a815-1eb441ec6714', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cc9118ce-5be7-4ef8-a4f2-9dd95fced1db', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('408b2d0f-bb58-4af4-a15f-3bcd2c33246c', 'signage_item', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.381525+00', '2026-10-20 14:29:58.381525+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('417cf1c3-02ea-4fc9-9925-12d72a8e1aba', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('a379de97-8161-478e-83a3-b21a0c8c3e78', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('3d50ed94-ca3b-4d34-8c11-6c76f04cf5f0', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('f23b5a8a-4e38-4ce3-ac72-8f6ab9d245a3', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('60ee2524-eb43-4510-97f2-5a9a88e10bec', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('2267b969-b1fe-4ca0-954d-125b9d0b6b49', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('78992bfa-ffb8-4530-98e7-ca7fb5c846f8', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('84ec5fa1-4c2c-42be-a1e8-633f719adff6', 'signage_item', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.400973+00', '2026-10-20 14:29:58.400973+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('50556264-c13d-456d-b4a1-34b3912d3bbc', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('6454f897-b386-4990-a422-d449a5e9973a', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('9e3f3bc5-923a-442f-844c-6e91ab9a7fae', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('c7e165a4-2e12-43d6-9b27-76e94edcb483', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0d22e3b3-eca1-4105-8750-07963736b67f', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('b5d922c6-b27d-4031-a811-d254114a5c5e', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0ffe991a-0b06-409a-a19b-962c6532e1da', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('581ca349-6d57-4dc6-a3e1-8ac993463fd1', 'signage_item', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.421855+00', '2026-10-20 14:29:58.421855+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('984c3a6e-88b1-45a8-9bbc-e380b94ae4d4', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('66f1eb7d-3081-4d49-9f51-513367085cc7', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('9be6412e-7f6c-42ab-b57e-803cef3125cc', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('1aa77fc1-1b4c-44d5-a1d7-31fcfc299e75', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2b6c3f4e-8286-42c6-86e3-9a2328bace29', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('8cfc4a83-6a24-45b2-956c-c94e89b9b0f1', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3a24ccfd-0401-41a7-afd0-4fc27071222c', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('028a8bf7-9fcb-49d9-9dba-b514ae116de2', 'signage_item', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.444562+00', '2026-10-20 14:29:58.444562+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('913f3b4f-f6bd-43eb-822d-92eab826740f', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('6ba979a4-228a-4f75-a3ea-273ef5c32e27', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('030bb4c4-d820-487b-8dcf-83df2d264f6e', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('15fccc70-abff-46fb-abe1-6bb917f8380f', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a159757c-afdf-42bf-9b58-22183b28f5a8', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('d6fb9478-f083-4b53-a460-95dc8b756b44', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a1f326c1-f267-4777-a11c-e6d1bd383f94', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('913322d9-c457-457f-bc6d-0794c679ef52', 'signage_item', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.465624+00', '2026-10-20 14:29:58.465624+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eb2e5037-cd77-4b81-8600-a1f01ffaad41', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('7d1ee335-f101-4df1-abd5-5ad8d634d0a8', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 14:29:57.634+00', '2026-10-22 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('149e7008-4f39-421a-8179-622bf870cb77', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('b6ac5f4c-b951-42b5-9bdf-578dceb97116', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 14:29:57.634+00', '2026-10-22 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('c88e91e4-4870-4c56-a764-51f5ba90edaf', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('a9509812-57d2-49bd-952d-e877c78870d7', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('603d9770-8316-4b22-b027-e2abcef0c0cf', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('75e3792c-3605-4a4e-9f9e-4fc7350fec6c', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('fa67657b-04b0-4ccc-9458-35ace296d99d', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d0404219-515d-4f8e-88d7-04f8fd81d20e', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eeffe397-779f-472d-b4d3-09202f887b6b', 'signage_item', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.493152+00', '2026-10-20 14:29:58.493152+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b003f4f6-07fe-4246-addf-a36a176a4986', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('13481480-1363-4ba0-802d-0afc045a6fa5', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('889d54d2-a2dd-4016-b023-54cff419ad13', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('d704f55d-1e11-4f40-bf02-3820ce2a9824', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d45535f6-a628-4635-a686-556ab9643109', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('29f9128c-f2fa-489f-849a-86254cfe5bd8', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('61438774-55fa-4dc9-aad7-45485a0dfd73', 'signage_item', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.557691+00', '2026-10-20 14:29:58.557691+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fe6d7b14-ca27-492a-9e0a-8fe3597c50c8', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('263b21db-3b37-4a4c-8a66-c8d779f1709c', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('b9781ad8-f15c-4ef6-8307-2754df0bbe66', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('b4b925e0-6f64-4f5a-aaf9-79ba711480e8', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 14:29:57.634+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-24 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4c5b01b0-4dca-415a-b696-a4fd81ad877e', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('1bbd597e-c543-486d-bf83-b5de5a499892', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-19 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8fca0908-c194-46bb-8d5b-d54ee561be92', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dbb4df4c-0bba-464d-b60c-8a50d36a59ec', 'signage_item', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.576312+00', '2026-10-20 14:29:58.576312+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e9bf021f-9a43-4b6c-ade0-4b46e17f02f9', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, '374a392f-fe98-44b1-89dd-df85e374c19f', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 3, false, '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL);
INSERT INTO public.approval_instances VALUES ('46523210-dd58-4520-b28d-9018a618541f', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'ebdb8492-091d-41bd-9f67-e58fa8d062ce', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 3, false, '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL);
INSERT INTO public.approval_instances VALUES ('a1d365f2-3d45-4f0b-9970-ec8cd9d90413', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'aaf6b08e-b076-4a98-b3dd-76f89962644e', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 14:29:57.634+00', '2026-10-20 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 5, false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL);
INSERT INTO public.approval_instances VALUES ('bb2e7ff0-980f-471b-a24a-724ac660eedb', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'a68f25aa-5d71-47f5-b96a-208f8464a6cd', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cea10398-b84c-4641-bb53-1f8bd616ef96', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'fb7aa3f8-537b-4bcf-a433-1227442cabb4', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 3, false, '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL);
INSERT INTO public.approval_instances VALUES ('2826257f-7cba-44f4-a8c1-4d07635b60c8', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, '5eb28843-4804-43ec-b377-15cc9adf2f16', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('33e1cad3-6cea-4181-8827-2459d2e9804d', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'd77d8db9-d3a3-4dca-8098-1188e8098956', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e77a4921-b832-4711-95df-f96835a23f39', 'signage_item', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.605525+00', '2026-10-20 14:29:58.605525+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('37322c07-d624-4274-a652-88826cfcf063', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '8889addf-46d9-4f98-8713-57f916569ab8', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 14:29:57.634+00', '2026-10-17 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('90d3270a-7ea3-41d3-8327-7d93d1de842a', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '3a692444-6e4a-44c5-8d58-f7b343c64030', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 14:29:57.634+00', '2026-10-23 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d23b80bb-7146-46f5-804f-ed2747237e20', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('55abfc6c-35a1-4784-9b5e-30091d58a82f', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '1357e33a-565d-45d5-9d66-fe9b53e95495', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3e9f5a93-539d-41dc-b243-1338de63f009', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '50bd0d89-0840-4910-8f45-a44e8edec8f0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cfbbe761-656b-4543-b4d3-a7ee9ec40b97', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 1, '3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('59730bf7-4d21-4caa-9720-1a1663d72cb0', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '8889addf-46d9-4f98-8713-57f916569ab8', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 14:29:57.634+00', '2026-10-17 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5039df89-1298-4b69-ba8d-a0db466746e8', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '3a692444-6e4a-44c5-8d58-f7b343c64030', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('88e8454e-16c0-47b5-9bcb-f8a7c8410498', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e2c65e5b-d9c8-4c3e-a709-c49229d87092', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '1357e33a-565d-45d5-9d66-fe9b53e95495', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6db0ac7c-1734-4efd-a5f0-9cdb0567e92d', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '50bd0d89-0840-4910-8f45-a44e8edec8f0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8e48abb-5cac-4aec-b9e9-9aa489c293e5', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 1, '3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('66d51930-f2ed-4d4c-a6a6-940b674de584', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '8889addf-46d9-4f98-8713-57f916569ab8', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-14 14:29:57.634+00', '2026-10-17 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8c3a9429-ca09-4765-a734-802f41d6e7a5', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '3a692444-6e4a-44c5-8d58-f7b343c64030', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5dd54a34-621e-4172-b313-b3a9f39166ac', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('14f3ac1d-ea26-4468-9748-cbc148ae9d8c', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '1357e33a-565d-45d5-9d66-fe9b53e95495', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eeb889bd-7946-4621-96cb-876773cbcd05', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '50bd0d89-0840-4910-8f45-a44e8edec8f0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('facb2601-5afd-46db-ab0a-8907eec7580d', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 1, '3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b83946c3-838f-496c-acc6-6baf6cda4e50', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '8889addf-46d9-4f98-8713-57f916569ab8', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 14:29:57.634+00', '2026-10-17 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('20e8d692-db1e-4818-be5c-306bda4fb5cc', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '3a692444-6e4a-44c5-8d58-f7b343c64030', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c66bdf22-38c3-4622-93ed-2ad5cdf6e118', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-21 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('28d50da7-28f4-493c-8b99-7eaf15415ca3', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '1357e33a-565d-45d5-9d66-fe9b53e95495', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-23 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('754289ca-e70c-4985-8b5b-1661f10e84f5', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '50bd0d89-0840-4910-8f45-a44e8edec8f0', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9b073ece-5c19-4678-897e-db8fb2e6e995', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 1, '3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('36e3ce68-9251-40e1-b3cc-6a5db296838e', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '8889addf-46d9-4f98-8713-57f916569ab8', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 14:29:57.634+00', '2026-10-17 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8bc76562-fa57-4301-ae15-90b1d836ea4d', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '3a692444-6e4a-44c5-8d58-f7b343c64030', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ec94cbb8-620a-49e4-a99c-36af99da24ee', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-21 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0f8e7f47-438f-4ceb-beac-01dc9a32f93f', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '1357e33a-565d-45d5-9d66-fe9b53e95495', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-23 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('009007d6-3e91-4a03-9e51-aded50e97712', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '50bd0d89-0840-4910-8f45-a44e8edec8f0', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 14:29:57.634+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 14:29:57.634+00', '2026-10-18 14:29:57.634+00', 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('430e04fc-51a9-42cb-a2b6-5cc745964fd0', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 1, '3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 14:29:57.634+00', NULL, 0, NULL, NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('ff4f6827-4a79-4808-b201-647fc9f63569', 'cdefdce7-e027-4686-815d-e686802f0d6b', '7ff3cb3d-b720-4426-b140-89c37f6edb31', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-20 14:29:57.940906+00', '2026-10-20 14:29:57.940906+00', false, NULL);
INSERT INTO public.approvers VALUES ('27f85243-2735-4ce6-a21c-16f8c5ea5365', 'cdefdce7-e027-4686-815d-e686802f0d6b', '88465857-25b1-4dd8-b581-6e56f5dd9de2', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-20 14:29:57.948469+00', '2026-10-20 14:29:57.948469+00', false, NULL);
INSERT INTO public.approvers VALUES ('b498e39c-77f0-488b-b2e2-f078c1851754', 'cdefdce7-e027-4686-815d-e686802f0d6b', '19ebabd4-6c3b-4d72-9ec7-77849a710c49', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-20 14:29:57.95481+00', '2026-10-20 14:29:57.95481+00', false, NULL);
INSERT INTO public.approvers VALUES ('c76f6577-bef1-455f-aede-7b793f901ebb', 'cdefdce7-e027-4686-815d-e686802f0d6b', '340ee6f8-6497-45e3-ac89-6268b9504dd4', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-20 14:29:57.961107+00', '2026-10-20 14:29:57.961107+00', false, NULL);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('ee2edfa0-2d86-4a3a-bfc7-4f0978514efc', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.101071+00', '2026-10-20 14:29:58.101071+00');
INSERT INTO public.artwork_versions VALUES ('58371fb3-840f-4873-8450-94c2c4dbe54f', '4fcfafa2-dc7c-4110-97b0-993df925b275', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.127357+00', '2026-10-20 14:29:58.127357+00');
INSERT INTO public.artwork_versions VALUES ('037ad330-cd89-48cf-b1ee-2093bfd9a45d', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-20 14:29:58.145795+00', '2026-10-20 14:29:58.145795+00');
INSERT INTO public.artwork_versions VALUES ('46f58d19-7c10-443f-9877-079a3d766978', 'b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.147073+00', '2026-10-20 14:29:58.147073+00');
INSERT INTO public.artwork_versions VALUES ('256deea6-f776-48e4-81cd-d7dbb44e9687', '56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.16368+00', '2026-10-20 14:29:58.16368+00');
INSERT INTO public.artwork_versions VALUES ('35937b45-e761-4281-b879-fbc95dd8efa5', 'b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.182592+00', '2026-10-20 14:29:58.182592+00');
INSERT INTO public.artwork_versions VALUES ('5d56b294-12fa-48be-91f3-74e5014c3e9e', 'ff9292be-873b-4162-863e-e1ccf3beed3d', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.20235+00', '2026-10-20 14:29:58.20235+00');
INSERT INTO public.artwork_versions VALUES ('30b3b3bc-65e4-45a9-aad6-a8784046ba75', 'a7f31649-13d3-456b-8657-9c790962400f', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.219505+00', '2026-10-20 14:29:58.219505+00');
INSERT INTO public.artwork_versions VALUES ('aa3312ec-8e9a-4334-be7b-32095cc41ac6', '714435b6-a93f-483c-9ef4-385eacdd4b77', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.238438+00', '2026-10-20 14:29:58.238438+00');
INSERT INTO public.artwork_versions VALUES ('869d4b98-dd8a-49ac-bcec-2168b4422780', '26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.258366+00', '2026-10-20 14:29:58.258366+00');
INSERT INTO public.artwork_versions VALUES ('c15d236e-40a4-486a-9c9f-8ee1629a7a45', '45fc60ae-d656-43bb-a591-39f9485ef628', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.281995+00', '2026-10-20 14:29:58.281995+00');
INSERT INTO public.artwork_versions VALUES ('0af40746-506f-418c-8d68-a4a35df293c6', 'b606a761-8514-4b22-b08c-bf18760356c3', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.306063+00', '2026-10-20 14:29:58.306063+00');
INSERT INTO public.artwork_versions VALUES ('1a81a051-d570-4c3c-ac0a-14568e108c65', 'b27c08c6-2ffe-4dea-8f17-a88e7f945c17', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.333528+00', '2026-10-20 14:29:58.333528+00');
INSERT INTO public.artwork_versions VALUES ('b2b9e91c-4a09-4ac0-8194-d1299e207f4e', 'ef58e8b1-7152-4d8b-886f-5f087e549170', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.357309+00', '2026-10-20 14:29:58.357309+00');
INSERT INTO public.artwork_versions VALUES ('821f150b-3c8b-4369-8168-fe8512fa59c0', 'b3a446ee-db7d-4f34-9e94-5bc9a6832b72', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.378104+00', '2026-10-20 14:29:58.378104+00');
INSERT INTO public.artwork_versions VALUES ('d380e3f6-7f0b-4d3a-a7c2-39c07d9dac67', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.398597+00', '2026-10-20 14:29:58.398597+00');
INSERT INTO public.artwork_versions VALUES ('c7998659-b45f-4631-9aac-a9dfbf7f764e', 'c6f7bd8e-45df-477d-9257-203109469727', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.419364+00', '2026-10-20 14:29:58.419364+00');
INSERT INTO public.artwork_versions VALUES ('501f40eb-79e7-4346-9d06-184b11453154', 'f0492761-b9a4-4c0c-a48a-c974fcd85720', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.441305+00', '2026-10-20 14:29:58.441305+00');
INSERT INTO public.artwork_versions VALUES ('53ce1a73-6b01-400f-b426-2b6d937266a5', '97de8752-29e8-4f1d-a8af-f8826efd28d6', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.462477+00', '2026-10-20 14:29:58.462477+00');
INSERT INTO public.artwork_versions VALUES ('01f9e308-d8d0-4fba-8077-9de05587c7be', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 14:29:58.485803+00', '2026-10-20 14:29:58.485803+00');
INSERT INTO public.artwork_versions VALUES ('b86a2fa3-5ef9-43e0-8be4-487b45b888ef', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 14:29:58.487642+00', '2026-10-20 14:29:58.487642+00');
INSERT INTO public.artwork_versions VALUES ('ef592121-19ba-4b81-b400-efcf64c5aa50', '2b9520b4-ef78-488e-99dd-ddb7906e9e6f', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.489459+00', '2026-10-20 14:29:58.489459+00');
INSERT INTO public.artwork_versions VALUES ('8f84337e-dfb1-4a71-8a42-2c8fd67338c5', '382556c8-0adb-43ed-b0f0-9d56ca11a537', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 14:29:58.554769+00', '2026-10-20 14:29:58.554769+00');
INSERT INTO public.artwork_versions VALUES ('7b94428e-8edc-4581-9151-3264ace113de', 'e1f4832a-4085-4380-aa24-7ae827451062', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.573009+00', '2026-10-20 14:29:58.573009+00');
INSERT INTO public.artwork_versions VALUES ('debf7828-8a10-40df-896d-5ef69e4a7a71', 'b223ee70-3aec-4775-b3c1-2330712f0e6b', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 14:29:58.602983+00', '2026-10-20 14:29:58.602983+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.audit_log VALUES ('4139f41f-fef2-4cd9-b9c6-4580e53f821a', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', NULL, 'system', 'sponsorship_package', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc', 'create', NULL, '{"name": "Headline sponsor", "lines": [{"quantity": 6, "description": "Logo on 6 hanging banners"}, {"quantity": 1, "description": "Entrance feature branding"}], "price": "25000.00", "places": 1, "description": "Top billing across the venue"}', 'Added package Headline sponsor at £25,000', NULL, NULL, '2026-10-20 14:29:57.829043+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('8e0120b8-aea6-4a27-acbb-16eb0fc287bc', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', NULL, 'system', 'sponsor', 'e652944b-a5c0-4598-8287-939590f2952e', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc", "packageName": "Headline sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["6 × Logo on 6 hanging banners", "Entrance feature branding"]}, "packagePrice": "22500.00", "packageSoldAt": "2026-10-10T14:29:57.634Z", "packagePriceNote": "Early-booking discount"}', 'BuildCo bought Headline sponsor for £22,500 (list £25,000: Early-booking discount)', NULL, NULL, '2026-10-20 14:29:57.829043+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('de638e60-86e3-437f-be01-be24c738d1cb', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', NULL, 'system', 'sponsorship_package', '73f4a2b8-cb6f-4d1d-965e-45e899e63d17', 'create', NULL, '{"name": "Seminar theatre sponsor", "lines": [{"quantity": 1, "description": "Seminar theatre branding"}], "price": "8000.00", "places": 2, "description": "Branding in the seminar theatre"}', 'Added package Seminar theatre sponsor at £8,000', NULL, NULL, '2026-10-20 14:29:57.885908+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('dcdeb6fe-5343-4c4c-95b9-87826d521730', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', NULL, 'system', 'sponsor', '82e54d80-9ce1-4de7-9862-6410ab47e0f0', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "73f4a2b8-cb6f-4d1d-965e-45e899e63d17", "packageName": "Seminar theatre sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["Seminar theatre branding"]}, "packagePrice": "8000.00", "packageSoldAt": "2026-10-10T14:29:57.634Z", "packagePriceNote": null}', 'ToolMart bought Seminar theatre sponsor for £8,000', NULL, NULL, '2026-10-20 14:29:57.885908+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('a34ab513-a2c0-48de-9808-ee62cc055ddf', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', NULL, 'system', 'sponsorship_package', '3daf33f8-f21b-48de-b1d7-37b35e65ddf4', 'create', NULL, '{"name": "Feature area sponsor", "lines": [{"quantity": 2, "description": "Feature area banners"}, {"quantity": 1, "description": "Logo in the event guide"}], "price": "12000.00", "places": 3, "description": "Branding around the feature area"}', 'Added package Feature area sponsor at £12,000', NULL, NULL, '2026-10-20 14:29:57.909716+00', NULL, NULL);


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

INSERT INTO public.contractors VALUES ('25832db2-93c1-476d-8553-27e698d4b3ad', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-20 14:29:57.803938+00', '2026-10-20 14:29:57.803938+00');
INSERT INTO public.contractors VALUES ('916f4741-ae4f-492d-9306-8eea591faf72', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-20 14:29:57.807796+00', '2026-10-20 14:29:57.807796+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('7ff3cb3d-b720-4426-b140-89c37f6edb31', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-20 14:29:57.937815+00', '2026-10-20 14:29:57.937815+00', true);
INSERT INTO public.departments VALUES ('88465857-25b1-4dd8-b581-6e56f5dd9de2', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-20 14:29:57.946309+00', '2026-10-20 14:29:57.946309+00', true);
INSERT INTO public.departments VALUES ('19ebabd4-6c3b-4d72-9ec7-77849a710c49', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Sales', 3, false, '{sponsor}', false, '2026-10-20 14:29:57.952788+00', '2026-10-20 14:29:57.952788+00', true);
INSERT INTO public.departments VALUES ('340ee6f8-6497-45e3-ac89-6268b9504dd4', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-20 14:29:57.959071+00', '2026-10-20 14:29:57.959071+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('6e57dc36-5b37-4a1a-a291-ab639cd3e7a7', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00');
INSERT INTO public.documents VALUES ('51194c3e-e3a9-472c-83d0-eab56646c5cc', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00');
INSERT INTO public.documents VALUES ('f2f6baf5-44c0-4db3-939b-74be615efc1a', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00');
INSERT INTO public.documents VALUES ('8e2a92bd-c085-4a8e-b4d7-e5aa48a02df5', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '9a5a276b-c3de-4279-8de8-fa1c8a059684', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00');
INSERT INTO public.documents VALUES ('58b1b8c2-94a5-4594-aeb5-4c70a2f679a4', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00');
INSERT INTO public.documents VALUES ('88d1982f-6fd4-4454-9327-b96d1cc5f0c8', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00');
INSERT INTO public.documents VALUES ('854c2628-23ef-47f2-b773-a8a06f681d4a', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00');
INSERT INTO public.documents VALUES ('35844280-2bd3-40f6-87d2-6edd25791f76', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00');
INSERT INTO public.documents VALUES ('cfe539f1-3483-450d-a35b-755ef9494829', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00');
INSERT INTO public.documents VALUES ('2bd95578-ca83-47ee-8795-2e38d044721e', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00');
INSERT INTO public.documents VALUES ('29ab0c0f-9a06-41a3-a04d-c30f9d983fdd', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00');
INSERT INTO public.documents VALUES ('3c44eeeb-2e61-457e-a518-6e47436f13ae', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '8ea45c70-5cc6-47d7-901d-c795f8130595', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00');
INSERT INTO public.documents VALUES ('25c21761-ce01-420a-88cb-d2be66d619cf', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00');
INSERT INTO public.documents VALUES ('7c063705-bb62-4026-b857-54bbc79bf95d', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00');
INSERT INTO public.documents VALUES ('0ed92058-6348-420c-b197-d4b493ce6b3a', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00');
INSERT INTO public.documents VALUES ('b76cb7fc-ebca-400b-8c5f-a0a1988af17f', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', 'e0df4b02-0901-4a4a-a80a-a5411b63ee8d', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00');
INSERT INTO public.documents VALUES ('2552aae9-40f8-4a2d-8126-c1dcb6be4269', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00');
INSERT INTO public.documents VALUES ('6c08e8f6-5f89-4c18-92d4-6ec67e588ec4', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00');
INSERT INTO public.documents VALUES ('fcb5023e-1c25-43d2-a113-d7a4ff20fd90', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00');
INSERT INTO public.documents VALUES ('12081061-76c9-4226-857c-74a0310abe8c', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_submission', '2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('5a08cadb-0d63-4405-950e-ca690fb7863c', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'signage', 34, '2026-10-20 14:29:58.629663+00', '2026-10-20 14:29:58.631234+00');
INSERT INTO public.edition_counters VALUES ('7fe3cd84-a756-4756-b7d9-0a429570d69f', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_design', 1, '2026-10-20 14:29:58.671302+00', '2026-10-20 14:29:58.671302+00');
INSERT INTO public.edition_counters VALUES ('34898834-d8a6-47e3-99e3-0a7bd34b4ef5', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_item', 1, '2026-10-20 14:29:58.671302+00', '2026-10-20 14:29:58.671302+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('503a9ace-7d9e-4a2b-baa1-3a8487bb4058', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-20 14:29:57.719952+00', '2026-10-20 14:29:57.719952+00');
INSERT INTO public.edition_deadlines VALUES ('0c223093-4366-42d3-870f-269b4c183e95', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-20 14:29:57.722028+00', '2026-10-20 14:29:57.722028+00');
INSERT INTO public.edition_deadlines VALUES ('91227a2a-b246-4352-b819-42cac2f2f33c', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-20 14:29:57.723366+00', '2026-10-20 14:29:57.723366+00');
INSERT INTO public.edition_deadlines VALUES ('baf65f0a-db00-47c0-a02d-ebe19aa2a538', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-20 14:29:57.724678+00', '2026-10-20 14:29:57.724678+00');
INSERT INTO public.edition_deadlines VALUES ('f94d4fc2-4742-4d90-8f03-7fcd8541ac61', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-20 14:29:57.726105+00', '2026-10-20 14:29:57.726105+00');
INSERT INTO public.edition_deadlines VALUES ('4d8973b3-7e8c-452b-ad3f-736601d069b8', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-20 14:29:57.727739+00', '2026-10-20 14:29:57.727739+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('9ca41a0e-5976-45c1-9478-b741ec5a8538', '732056c3-bc24-404e-8055-8464fafe8873', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-20 14:29:57.717358+00', '2026-10-20 14:29:57.717358+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('732056c3-bc24-404e-8055-8464fafe8873', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'UK Construction Week', 'UKCW', '2026-10-20 14:29:57.689775+00', '2026-10-20 14:29:57.689775+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('6f2cb15f-0495-4387-a8aa-3a30cd656222', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Exhibitor Co', 'A10', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '25832db2-93c1-476d-8553-27e698d4b3ad', '2026-10-20 14:29:58.051289+00', '2026-10-20 14:29:58.051289+00');
INSERT INTO public.exhibitors VALUES ('8a442ae2-7791-4d9c-a426-009b4770e057', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SteelFrame Systems', 'A20', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '916f4741-ae4f-492d-9306-8eea591faf72', '2026-10-20 14:29:58.055043+00', '2026-10-20 14:29:58.055043+00');
INSERT INTO public.exhibitors VALUES ('ba89836b-443a-4a57-9381-ad64fb285493', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'BrickWorks UK', 'A30', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '25832db2-93c1-476d-8553-27e698d4b3ad', '2026-10-20 14:29:58.058321+00', '2026-10-20 14:29:58.058321+00');
INSERT INTO public.exhibitors VALUES ('9c804c09-b9e1-45b5-bcd8-daf35b1191b8', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Timber Trade Ltd', 'B10', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '916f4741-ae4f-492d-9306-8eea591faf72', '2026-10-20 14:29:58.061237+00', '2026-10-20 14:29:58.061237+00');
INSERT INTO public.exhibitors VALUES ('6fe6fb91-0f21-425e-aca6-a0681c1f0380', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'GlassTech', 'B20', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '25832db2-93c1-476d-8553-27e698d4b3ad', '2026-10-20 14:29:58.066526+00', '2026-10-20 14:29:58.066526+00');
INSERT INTO public.exhibitors VALUES ('2113d1ba-f700-48f9-b05c-9c4a8a033b80', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Insulate Pro', 'B30', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '916f4741-ae4f-492d-9306-8eea591faf72', '2026-10-20 14:29:58.069278+00', '2026-10-20 14:29:58.069278+00');
INSERT INTO public.exhibitors VALUES ('bdfbc104-5e19-4315-89e3-fc1deb0839da', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'RoofRight', 'C10', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '25832db2-93c1-476d-8553-27e698d4b3ad', '2026-10-20 14:29:58.073193+00', '2026-10-20 14:29:58.073193+00');
INSERT INTO public.exhibitors VALUES ('a09a38e2-42e8-4600-aa95-9e8c79045935', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'PlantHire Direct', 'C20', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '916f4741-ae4f-492d-9306-8eea591faf72', '2026-10-20 14:29:58.076672+00', '2026-10-20 14:29:58.076672+00');
INSERT INTO public.exhibitors VALUES ('a5496055-94b7-4987-95ab-825c1a166974', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SafetyFirst PPE', 'D10', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-20 14:29:58.080107+00', '2026-10-20 14:29:58.080107+00');
INSERT INTO public.exhibitors VALUES ('19d0b234-3ef6-4e4a-8978-8d0c8c9267d5', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'ToolMart Retail', 'D20', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-20 14:29:58.084362+00', '2026-10-20 14:29:58.084362+00');
INSERT INTO public.exhibitors VALUES ('a682627f-1d60-499f-8699-ec70e1795713', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'EcoBuild Materials', 'D30', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-20 14:29:58.086416+00', '2026-10-20 14:29:58.086416+00');
INSERT INTO public.exhibitors VALUES ('05417bdb-aeb2-438b-9a30-78334943e32a', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SiteWise Software', 'D40', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-20 14:29:58.088642+00', '2026-10-20 14:29:58.088642+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('c9d3428e-2b07-4687-8dc9-66ec5009ebcb', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'venue', 'venue', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.028517+00', '2026-10-20 14:29:58.028517+00');
INSERT INTO public.external_grants VALUES ('d4b70cdd-489e-4500-bf80-a86e87149a71', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.034007+00', '2026-10-20 14:29:58.034007+00');
INSERT INTO public.external_grants VALUES ('5c9274bb-7137-44b4-b72e-c2774d9b4cb5', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.038965+00', '2026-10-20 14:29:58.038965+00');
INSERT INTO public.external_grants VALUES ('0b233751-82b1-4ef0-b248-4e9947f04a84', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'supplier', 'supplier', '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.043463+00', '2026-10-20 14:29:58.043463+00');
INSERT INTO public.external_grants VALUES ('3c0c5c75-4902-455f-911e-9774c4b2b054', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'sponsor', 'sponsor', 'e652944b-a5c0-4598-8287-939590f2952e', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.047835+00', '2026-10-20 14:29:58.047835+00');
INSERT INTO public.external_grants VALUES ('286ee64c-5083-4f91-a30f-50d22e1c12bc', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'exhibitor', 'exhibitor', '6f2cb15f-0495-4387-a8aa-3a30cd656222', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-20 14:29:57.634+00', NULL, '2026-10-20 14:29:58.091109+00', '2026-10-20 14:29:58.091109+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('caae2974-1c0f-4a29-9a16-2cf1fdb77209', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-20 14:29:57.730849+00', '2026-10-20 14:29:57.730849+00');
INSERT INTO public.halls VALUES ('b81dca66-1c3f-469a-8da9-e045a974a3fb', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-20 14:29:57.733527+00', '2026-10-20 14:29:57.733527+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('21a4368a-4c78-4c5e-bee9-3cc74461a06e', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Hanging banner', 'hanging_banner', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'rigged', true, 0, '2026-10-20 14:29:57.994029+00', '2026-10-20 14:29:57.994029+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('2f306921-05e8-4b67-9972-d1d77e9d175f', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Foamex board', 'foamex_board', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'wall_mounted', false, 1, '2026-10-20 14:29:57.996308+00', '2026-10-20 14:29:57.996308+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('00c31065-18f3-4bd1-a1e1-9e770003cc8e', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Fabric graphic', 'fabric_graphic', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'shell_mounted', false, 2, '2026-10-20 14:29:57.998518+00', '2026-10-20 14:29:57.998518+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('f011c291-315d-43b2-9b75-e8175cace8ca', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Floor vinyl', 'floor_vinyl', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'floor', false, 3, '2026-10-20 14:29:58.000348+00', '2026-10-20 14:29:58.000348+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('2228d91b-1959-4679-85b8-13fc95488f45', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Aisle sign', 'aisle_sign', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'rigged', true, 4, '2026-10-20 14:29:58.002046+00', '2026-10-20 14:29:58.002046+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('f00f890c-29b6-4efc-9080-4762524855b9', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Entrance feature', 'entrance_feature', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'freestanding', true, 5, '2026-10-20 14:29:58.003928+00', '2026-10-20 14:29:58.003928+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('84d95d43-0efb-49a2-a858-6b57e6c91b97', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Registration', 'registration', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'freestanding', false, 6, '2026-10-20 14:29:58.006301+00', '2026-10-20 14:29:58.006301+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a7c8e868-ca55-4bdf-96ef-ff48bb418c32', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Seminar theatre', 'seminar_theatre', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'freestanding', false, 7, '2026-10-20 14:29:58.008197+00', '2026-10-20 14:29:58.008197+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3ee292a1-abf1-478b-b746-4126b555c25a', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Feature area', 'feature_area', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'freestanding', false, 8, '2026-10-20 14:29:58.009653+00', '2026-10-20 14:29:58.009653+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('ff63d963-df29-4ccb-a3f3-9d0f381ace7c', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'External', 'external', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'freestanding', true, 9, '2026-10-20 14:29:58.011112+00', '2026-10-20 14:29:58.011112+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d0663d97-7eb1-413e-a323-cfc42dc36e81', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Digital screen', 'digital_screen', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 'digital', false, 10, '2026-10-20 14:29:58.012548+00', '2026-10-20 14:29:58.012548+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('775565bc-6397-4447-a31b-805ab993bc2f', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Branded lanyards', 'lanyard', '759de502-ea98-4b34-a4d6-291ca2dabd9b', NULL, false, 11, '2026-10-20 14:29:58.014396+00', '2026-10-20 14:29:58.014396+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('f17b0a17-81bf-46fd-b31d-423d2004a52f', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Show bags', 'show_bag', '759de502-ea98-4b34-a4d6-291ca2dabd9b', NULL, false, 12, '2026-10-20 14:29:58.016069+00', '2026-10-20 14:29:58.016069+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('efa79d66-d232-4bf6-875a-0ccdca59ec61', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Registration branding', 'reg_branding', '759de502-ea98-4b34-a4d6-291ca2dabd9b', NULL, false, 13, '2026-10-20 14:29:58.017514+00', '2026-10-20 14:29:58.017514+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('290875f7-b474-4fba-ae1f-fe7efdce1554', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Other signage', 'other_signage', '759de502-ea98-4b34-a4d6-291ca2dabd9b', NULL, false, 14, '2026-10-20 14:29:58.020098+00', '2026-10-20 14:29:58.020098+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('188d99bf-a6f2-430f-8151-9f10a7c24265', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Other sponsorship item', 'other_sponsorship', '759de502-ea98-4b34-a4d6-291ca2dabd9b', NULL, false, 15, '2026-10-20 14:29:58.022511+00', '2026-10-20 14:29:58.022511+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('48b277f3-2fd7-4276-90f3-53cdce7a447c', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-20 14:29:57.736528+00', '2026-10-20 14:29:57.736528+00');
INSERT INTO public.locations VALUES ('3d8c2df2-7af8-4ba5-ac26-d50d5f2c6c86', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-20 14:29:57.739239+00', '2026-10-20 14:29:57.739239+00');
INSERT INTO public.locations VALUES ('bfa4e666-432f-4ee7-bc2f-959788fa57b3', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-20 14:29:57.742438+00', '2026-10-20 14:29:57.742438+00');
INSERT INTO public.locations VALUES ('79018fd5-59fe-4723-974c-f1d56479c335', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-20 14:29:57.744587+00', '2026-10-20 14:29:57.744587+00');
INSERT INTO public.locations VALUES ('552d29b8-02f8-4565-9e4e-8b79caa51e3f', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-20 14:29:57.748306+00', '2026-10-20 14:29:57.748306+00');
INSERT INTO public.locations VALUES ('f79e9e53-ddcc-40d7-b138-9efbccc7a4d9', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-20 14:29:57.751099+00', '2026-10-20 14:29:57.751099+00');
INSERT INTO public.locations VALUES ('1a3777da-4d93-4465-85c9-7b418689fa8b', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-20 14:29:57.753874+00', '2026-10-20 14:29:57.753874+00');
INSERT INTO public.locations VALUES ('7310ff6e-2efa-4a6a-8225-bb0f9aee0d4c', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-20 14:29:57.756428+00', '2026-10-20 14:29:57.756428+00');
INSERT INTO public.locations VALUES ('ef873d9e-d139-422a-b765-5c063f0a884e', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-20 14:29:57.75865+00', '2026-10-20 14:29:57.75865+00');
INSERT INTO public.locations VALUES ('b8f731e9-4fc2-45f7-ac5a-aa7ab30455a0', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-20 14:29:57.761172+00', '2026-10-20 14:29:57.761172+00');
INSERT INTO public.locations VALUES ('7b111424-2c8b-4591-9871-2e2a49d530f6', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-20 14:29:57.764021+00', '2026-10-20 14:29:57.764021+00');
INSERT INTO public.locations VALUES ('94ca0b00-498c-413a-ae7d-0dbadb621eb9', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-20 14:29:57.766154+00', '2026-10-20 14:29:57.766154+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('dec8dc65-d71d-449c-994e-cd136cfc262d', '00000000-0000-4000-8000-000000000001', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'admin', '2026-10-20 14:29:57.670225+00', '2026-10-20 14:29:57.670225+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('630a07cd-5d04-4975-9112-b83f1615ed19', '00000000-0000-4000-8000-000000000006', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'viewer', '2026-10-20 14:29:57.688189+00', '2026-10-20 14:29:57.688189+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('84f91970-ea42-4934-8b39-7f15fb8feee7', '00000000-0000-4000-8000-000000000002', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'ops', '2026-10-20 14:29:57.674927+00', '2026-10-20 14:29:57.943417+00', '{}', '7ff3cb3d-b720-4426-b140-89c37f6edb31', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('19f6700e-d2c8-4cf5-9a07-05cc68dd385a', '00000000-0000-4000-8000-000000000004', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'sales', '2026-10-20 14:29:57.681909+00', '2026-10-20 14:29:57.956055+00', '{}', '19ebabd4-6c3b-4d72-9ec7-77849a710c49', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('8af9aa3c-4c52-4a12-8583-b63322c80d78', '00000000-0000-4000-8000-000000000005', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'event_director', '2026-10-20 14:29:57.685433+00', '2026-10-20 14:29:57.962601+00', '{}', '340ee6f8-6497-45e3-ac89-6268b9504dd4', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('e95a4783-9cca-4fea-9864-293538d5234c', '00000000-0000-4000-8000-000000000003', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'marketing', '2026-10-20 14:29:57.678227+00', '2026-10-20 14:29:58.751757+00', '{"costs.edit": true}', '88465857-25b1-4dd8-b581-6e56f5dd9de2', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('cdefdce7-e027-4686-815d-e686802f0d6b', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-20 14:29:57.662353+00', '2026-10-20 14:29:57.662353+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'f00f890c-29b6-4efc-9080-4762524855b9', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '48b277f3-2fd7-4276-90f3-53cdce7a447c', 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', '933ad509-64d5-411f-af30-a20b47d9643b', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'ee2edfa0-2d86-4a3a-bfc7-4f0978514efc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.097156+00', '2026-10-20 14:29:58.102975+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4fcfafa2-dc7c-4110-97b0-993df925b275', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '84d95d43-0efb-49a2-a858-6b57e6c91b97', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '3d8c2df2-7af8-4ba5-ac26-d50d5f2c6c86', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '58371fb3-840f-4873-8450-94c2c4dbe54f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.124734+00', '2026-10-20 14:29:58.128807+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b3bf4ad3-e9bb-4e2b-9a93-2d4acdaa68be', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '21a4368a-4c78-4c5e-bee9-3cc74461a06e', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'bfa4e666-432f-4ee7-bc2f-959788fa57b3', 'ops', '00000000-0000-4000-8000-000000000002', 'e652944b-a5c0-4598-8287-939590f2952e', '1d7c1521-ed0b-4097-8bd7-83ba5785eb0c', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '46f58d19-7c10-443f-9877-079a3d766978', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.143797+00', '2026-10-20 14:29:58.148405+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('56c7f9a3-f7f2-4ab6-9892-bd7e772f1a6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'a7c8e868-ca55-4bdf-96ef-ff48bb418c32', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '79018fd5-59fe-4723-974c-f1d56479c335', 'marketing', '00000000-0000-4000-8000-000000000003', '82e54d80-9ce1-4de7-9862-6410ab47e0f0', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '256deea6-f776-48e4-81cd-d7dbb44e9687', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.161449+00', '2026-10-20 14:29:58.165068+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b7ec437f-76ff-4a70-808f-e5d8b5fd51cb', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', 'f011c291-315d-43b2-9b75-e8175cace8ca', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '552d29b8-02f8-4565-9e4e-8b79caa51e3f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '35937b45-e761-4281-b879-fbc95dd8efa5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.180205+00', '2026-10-20 14:29:58.184023+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ff9292be-873b-4162-863e-e1ccf3beed3d', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '3ee292a1-abf1-478b-b746-4126b555c25a', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'f79e9e53-ddcc-40d7-b138-9efbccc7a4d9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '5d56b294-12fa-48be-91f3-74e5014c3e9e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.200452+00', '2026-10-20 14:29:58.203579+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "fb7aa3f8-537b-4bcf-a433-1227442cabb4", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a7f31649-13d3-456b-8657-9c790962400f', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '21a4368a-4c78-4c5e-bee9-3cc74461a06e', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '1a3777da-4d93-4465-85c9-7b418689fa8b', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '30b3b3bc-65e4-45a9-aad6-a8784046ba75', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.21746+00', '2026-10-20 14:29:58.220956+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('714435b6-a93f-483c-9ef4-385eacdd4b77', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '2228d91b-1959-4679-85b8-13fc95488f45', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '7310ff6e-2efa-4a6a-8225-bb0f9aee0d4c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'aa3312ec-8e9a-4334-be7b-32095cc41ac6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.236566+00', '2026-10-20 14:29:58.240146+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('26fadbea-c3a3-437d-a027-f2b8f3d9bfb4', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'a7c8e868-ca55-4bdf-96ef-ff48bb418c32', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'ef873d9e-d139-422a-b765-5c063f0a884e', 'marketing', '00000000-0000-4000-8000-000000000003', '82e54d80-9ce1-4de7-9862-6410ab47e0f0', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '869d4b98-dd8a-49ac-bcec-2168b4422780', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.255728+00', '2026-10-20 14:29:58.260079+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('45fc60ae-d656-43bb-a591-39f9485ef628', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '00c31065-18f3-4bd1-a1e1-9e770003cc8e', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'b8f731e9-4fc2-45f7-ac5a-aa7ab30455a0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'c15d236e-40a4-486a-9c9f-8ee1629a7a45', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.279452+00', '2026-10-20 14:29:58.285466+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL);
INSERT INTO public.signage_items VALUES ('b606a761-8514-4b22-b08c-bf18760356c3', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'ff63d963-df29-4ccb-a3f3-9d0f381ace7c', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '7b111424-2c8b-4591-9871-2e2a49d530f6', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '0af40746-506f-418c-8d68-a4a35df293c6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.30392+00', '2026-10-20 14:29:58.309492+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', NULL);
INSERT INTO public.signage_items VALUES ('b27c08c6-2ffe-4dea-8f17-a88e7f945c17', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '94ca0b00-498c-413a-ae7d-0dbadb621eb9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '1a81a051-d570-4c3c-ac0a-14568e108c65', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.331104+00', '2026-10-20 14:29:58.336454+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-17 14:29:57.634+00');
INSERT INTO public.signage_items VALUES ('3cd57b9a-c6fc-4043-b819-cc833c280607', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '188d99bf-a6f2-430f-8151-9f10a7c24265', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.627845+00', '2026-10-20 14:29:58.627845+00', 'sponsorship_item', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', '2026-11-07', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7404bca9-651f-45f2-a35d-3a8f06e7fdda', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '7abace82-91c9-44bb-b9b2-51b9b0e25af9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.667255+00', '2026-10-20 14:29:58.667255+00', 'stand_design', 'organiser', '[{"stepId": "96ff00f0-99bc-4858-a580-839e43ce3df2", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "feee577f-9e49-4d2e-890c-fde83d076fb4", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ef58e8b1-7152-4d8b-886f-5f087e549170', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'd0663d97-7eb1-413e-a323-cfc42dc36e81', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '3d8c2df2-7af8-4ba5-ac26-d50d5f2c6c86', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '3cb3adae-9697-42be-8df9-1131690ce0f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'b2b9e91c-4a09-4ac0-8194-d1299e207f4e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.35471+00', '2026-10-20 14:29:58.360363+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "fb7aa3f8-537b-4bcf-a433-1227442cabb4", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-17 14:29:57.634+00');
INSERT INTO public.signage_items VALUES ('b3a446ee-db7d-4f34-9e94-5bc9a6832b72', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '2228d91b-1959-4679-85b8-13fc95488f45', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'bfa4e666-432f-4ee7-bc2f-959788fa57b3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '821f150b-3c8b-4369-8168-fe8512fa59c0', '2026-10-17 14:29:57.634+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.375705+00', '2026-10-20 14:29:58.381525+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-17 14:29:57.634+00');
INSERT INTO public.signage_items VALUES ('d80c9d87-c727-48b4-bdb0-070fbf9bd60a', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '552d29b8-02f8-4565-9e4e-8b79caa51e3f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'd380e3f6-7f0b-4d3a-a7c2-39c07d9dac67', '2026-10-17 14:29:57.634+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.396302+00', '2026-10-20 14:29:58.400973+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-17 14:29:57.634+00');
INSERT INTO public.signage_items VALUES ('c6f7bd8e-45df-477d-9257-203109469727', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '3ee292a1-abf1-478b-b746-4126b555c25a', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'f79e9e53-ddcc-40d7-b138-9efbccc7a4d9', 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'c7998659-b45f-4631-9aac-a9dfbf7f764e', '2026-10-17 14:29:57.634+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.417373+00', '2026-10-20 14:29:58.421855+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, '2026-10-17 14:29:57.634+00', '2026-10-17 14:29:57.634+00');
INSERT INTO public.signage_items VALUES ('f0492761-b9a4-4c0c-a48a-c974fcd85720', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '21a4368a-4c78-4c5e-bee9-3cc74461a06e', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '7310ff6e-2efa-4a6a-8225-bb0f9aee0d4c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '501f40eb-79e7-4346-9d06-184b11453154', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.439234+00', '2026-10-20 14:29:58.442873+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('97de8752-29e8-4f1d-a8af-f8826efd28d6', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '00c31065-18f3-4bd1-a1e1-9e770003cc8e', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'b8f731e9-4fc2-45f7-ac5a-aa7ab30455a0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '53ce1a73-6b01-400f-b426-2b6d937266a5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.459475+00', '2026-10-20 14:29:58.464108+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2b9520b4-ef78-488e-99dd-ddb7906e9e6f', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '21a4368a-4c78-4c5e-bee9-3cc74461a06e', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'bfa4e666-432f-4ee7-bc2f-959788fa57b3', 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', '1d7c1521-ed0b-4097-8bd7-83ba5785eb0c', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'ef592121-19ba-4b81-b400-efcf64c5aa50', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.483503+00', '2026-10-20 14:29:58.491175+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('63d443a2-139a-4d3c-9142-65f1bcba92e8', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '94ca0b00-498c-413a-ae7d-0dbadb621eb9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.517169+00', '2026-10-20 14:29:58.517169+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('adcae9f1-3248-4ce4-8147-6c59fe35dc15', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '3d8c2df2-7af8-4ba5-ac26-d50d5f2c6c86', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.521676+00', '2026-10-20 14:29:58.521676+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1a766d96-d3c7-4170-ab36-41ce8140aa1c', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '84d95d43-0efb-49a2-a858-6b57e6c91b97', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '1a3777da-4d93-4465-85c9-7b418689fa8b', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.525787+00', '2026-10-20 14:29:58.525787+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bbfd617c-fc1a-4115-aee9-902b6a41f2e0', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'd0663d97-7eb1-413e-a323-cfc42dc36e81', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', 'f79e9e53-ddcc-40d7-b138-9efbccc7a4d9', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '3cb3adae-9697-42be-8df9-1131690ce0f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.529917+00', '2026-10-20 14:29:58.529917+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "fb7aa3f8-537b-4bcf-a433-1227442cabb4", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c92e1aa5-9c17-4ad1-81fe-39ae4af21eab', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', 'f011c291-315d-43b2-9b75-e8175cace8ca', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'ef873d9e-d139-422a-b765-5c063f0a884e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.535027+00', '2026-10-20 14:29:58.535027+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('df6cdce8-5d38-4d76-ae68-690692e88d2c', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'a7c8e868-ca55-4bdf-96ef-ff48bb418c32', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', 'ef873d9e-d139-422a-b765-5c063f0a884e', 'marketing', '00000000-0000-4000-8000-000000000003', '82e54d80-9ce1-4de7-9862-6410ab47e0f0', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.538784+00', '2026-10-20 14:29:58.538784+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3a3213cb-2e3a-4879-95ff-05db34e7d271', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'ff63d963-df29-4ccb-a3f3-9d0f381ace7c', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '7b111424-2c8b-4591-9871-2e2a49d530f6', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.543458+00', '2026-10-20 14:29:58.543458+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "fb7aa3f8-537b-4bcf-a433-1227442cabb4", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('df4433df-d5e0-479d-ac5f-f5dd72e9a548', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '7b111424-2c8b-4591-9871-2e2a49d530f6', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.547093+00', '2026-10-20 14:29:58.547093+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('382556c8-0adb-43ed-b0f0-9d56ca11a537', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '552d29b8-02f8-4565-9e4e-8b79caa51e3f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '8f84337e-dfb1-4a71-8a42-2c8fd67338c5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.552796+00', '2026-10-20 14:29:58.555987+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e1f4832a-4085-4380-aa24-7ae827451062', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'f00f890c-29b6-4efc-9080-4762524855b9', 'caae2974-1c0f-4a29-9a16-2cf1fdb77209', '48b277f3-2fd7-4276-90f3-53cdce7a447c', 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', '933ad509-64d5-411f-af30-a20b47d9643b', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, '7b94428e-8edc-4581-9151-3264ace113de', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.57045+00', '2026-10-20 14:29:58.574701+00', 'signage', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', NULL, NULL, NULL, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('575c37b1-84bb-4523-96f7-1031399296b1', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '2f306921-05e8-4b67-9972-d1d77e9d175f', 'b81dca66-1c3f-469a-8da9-e045a974a3fb', '94ca0b00-498c-413a-ae7d-0dbadb621eb9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.596949+00', '2026-10-20 14:29:58.596949+00', 'signage', 'organiser', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b223ee70-3aec-4775-b3c1-2330712f0e6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '775565bc-6397-4447-a31b-805ab993bc2f', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 'debf7828-8a10-40df-896d-5ef69e4a7a71', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.60087+00', '2026-10-20 14:29:58.604236+00', 'sponsorship_item', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', '2027-01-03', NULL, 9000.00, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b544c727-89ed-491e-9e25-f70ea6392d01', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'f17b0a17-81bf-46fd-b31d-423d2004a52f', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'e652944b-a5c0-4598-8287-939590f2952e', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.618028+00', '2026-10-20 14:29:58.618028+00', 'sponsorship_item', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}, {"stepId": "aaf6b08e-b076-4a98-b3dd-76f89962644e", "userId": null}]', '2026-11-09', NULL, 12500.00, '2026-10-10 14:29:57.634+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('499c6b7c-7d5e-45c2-a734-cb4f1135d2ab', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'efa79d66-d232-4bf6-875a-0ccdca59ec61', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '759de502-ea98-4b34-a4d6-291ca2dabd9b', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 14:29:58.624154+00', '2026-10-20 14:29:58.624154+00', 'sponsorship_item', 'sponsor', '[{"stepId": "374a392f-fe98-44b1-89dd-df85e374c19f", "userId": null}, {"stepId": "ebdb8492-091d-41bd-9f67-e58fa8d062ce", "userId": null}]', '2027-02-17', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('88d54a6b-4f5d-4619-a4bd-447be6caae66', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'd80c9d87-c727-48b4-bdb0-070fbf9bd60a', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '597d129b-0fb9-44f7-9767-16b4738f36be', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-20 14:29:58.41237+00', '2026-10-20 14:29:58.41237+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('1d7c1521-ed0b-4097-8bd7-83ba5785eb0c', 'e652944b-a5c0-4598-8287-939590f2952e', 'Logo on 6 hanging banners', 6, '2026-10-20 14:29:57.815484+00', '2026-10-20 14:29:57.829043+00', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc');
INSERT INTO public.sponsor_entitlements VALUES ('933ad509-64d5-411f-af30-a20b47d9643b', 'e652944b-a5c0-4598-8287-939590f2952e', 'Entrance feature branding', 1, '2026-10-20 14:29:57.821166+00', '2026-10-20 14:29:57.829043+00', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc');
INSERT INTO public.sponsor_entitlements VALUES ('78a56323-8116-450f-a107-38e9858526c3', '82e54d80-9ce1-4de7-9862-6410ab47e0f0', 'Seminar theatre branding', 1, '2026-10-20 14:29:57.827317+00', '2026-10-20 14:29:57.885908+00', '73f4a2b8-cb6f-4d1d-965e-45e899e63d17');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('e652944b-a5c0-4598-8287-939590f2952e', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-20 14:29:57.811653+00', '2026-10-20 14:29:57.829043+00', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc', 22500.00, 'Early-booking discount', '2026-10-10 14:29:57.634+00');
INSERT INTO public.sponsors VALUES ('82e54d80-9ce1-4de7-9862-6410ab47e0f0', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-20 14:29:57.823928+00', '2026-10-20 14:29:57.885908+00', '73f4a2b8-cb6f-4d1d-965e-45e899e63d17', 8000.00, NULL, '2026-10-10 14:29:57.634+00');


--
-- Data for Name: sponsorship_package_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_package_lines VALUES ('b9887868-42d7-45b4-8aa5-01bebae6edba', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc', 'Logo on 6 hanging banners', 6, 1, '2026-10-20 14:29:57.829043+00', '2026-10-20 14:29:57.829043+00');
INSERT INTO public.sponsorship_package_lines VALUES ('ce3b668e-8b4c-4242-961c-bb2a34e633e2', 'f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc', 'Entrance feature branding', 1, 2, '2026-10-20 14:29:57.829043+00', '2026-10-20 14:29:57.829043+00');
INSERT INTO public.sponsorship_package_lines VALUES ('f5ac5348-4c64-4ae8-840e-4f329c4ed1d7', '73f4a2b8-cb6f-4d1d-965e-45e899e63d17', 'Seminar theatre branding', 1, 1, '2026-10-20 14:29:57.885908+00', '2026-10-20 14:29:57.885908+00');
INSERT INTO public.sponsorship_package_lines VALUES ('db16e3ba-560e-44d6-af48-2a4950dd6bc9', '3daf33f8-f21b-48de-b1d7-37b35e65ddf4', 'Feature area banners', 2, 1, '2026-10-20 14:29:57.909716+00', '2026-10-20 14:29:57.909716+00');
INSERT INTO public.sponsorship_package_lines VALUES ('09bea5fd-2136-417b-b0dc-76a6dabba0d6', '3daf33f8-f21b-48de-b1d7-37b35e65ddf4', 'Logo in the event guide', 1, 2, '2026-10-20 14:29:57.909716+00', '2026-10-20 14:29:57.909716+00');


--
-- Data for Name: sponsorship_packages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_packages VALUES ('f8e7e848-dd26-4dd1-b5b0-42549d7eb1dc', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Headline sponsor', 'Top billing across the venue', 25000.00, 1, 1, false, '2026-10-20 14:29:57.829043+00', '2026-10-20 14:29:57.829043+00');
INSERT INTO public.sponsorship_packages VALUES ('73f4a2b8-cb6f-4d1d-965e-45e899e63d17', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Seminar theatre sponsor', 'Branding in the seminar theatre', 8000.00, 2, 2, false, '2026-10-20 14:29:57.885908+00', '2026-10-20 14:29:57.885908+00');
INSERT INTO public.sponsorship_packages VALUES ('3daf33f8-f21b-48de-b1d7-37b35e65ddf4', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Feature area sponsor', 'Branding around the feature area', 12000.00, 3, 3, false, '2026-10-20 14:29:57.909716+00', '2026-10-20 14:29:57.909716+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('9a5a276b-c3de-4279-8de8-fa1c8a059684', '9ca41a0e-5976-45c1-9478-b741ec5a8538', '6f2cb15f-0495-4387-a8aa-3a30cd656222', 'STD-BIRM27-A10', '25832db2-93c1-476d-8553-27e698d4b3ad', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 14:29:57.634+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.674102+00', '2026-10-20 14:29:58.674102+00');
INSERT INTO public.stand_submissions VALUES ('00ba9fbf-e2bc-4d70-95cb-f7c7df201e7f', '9ca41a0e-5976-45c1-9478-b741ec5a8538', '8a442ae2-7791-4d9c-a426-009b4770e057', 'STD-BIRM27-A20', '916f4741-ae4f-492d-9306-8eea591faf72', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 14:29:57.634+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.689967+00', '2026-10-20 14:29:58.689967+00');
INSERT INTO public.stand_submissions VALUES ('8ea45c70-5cc6-47d7-901d-c795f8130595', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'ba89836b-443a-4a57-9381-ad64fb285493', 'STD-BIRM27-A30', '25832db2-93c1-476d-8553-27e698d4b3ad', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-14 14:29:57.634+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.703049+00', '2026-10-20 14:29:58.703049+00');
INSERT INTO public.stand_submissions VALUES ('e0df4b02-0901-4a4a-a80a-a5411b63ee8d', '9ca41a0e-5976-45c1-9478-b741ec5a8538', '9c804c09-b9e1-45b5-bcd8-daf35b1191b8', 'STD-BIRM27-B10', '916f4741-ae4f-492d-9306-8eea591faf72', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-14 14:29:57.634+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.716678+00', '2026-10-20 14:29:58.716678+00');
INSERT INTO public.stand_submissions VALUES ('2117e73e-4aa7-40e3-8f4f-cdfcc51e5bf0', '9ca41a0e-5976-45c1-9478-b741ec5a8538', '6fe6fb91-0f21-425e-aca6-a0681c1f0380', 'STD-BIRM27-B20', '25832db2-93c1-476d-8553-27e698d4b3ad', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-14 14:29:57.634+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.729117+00', '2026-10-20 14:29:58.729117+00');
INSERT INTO public.stand_submissions VALUES ('96228486-71d6-4a35-b13b-a81210dae82d', '9ca41a0e-5976-45c1-9478-b741ec5a8538', '2113d1ba-f700-48f9-b05c-9c4a8a033b80', 'STD-BIRM27-B30', '916f4741-ae4f-492d-9306-8eea591faf72', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.743221+00', '2026-10-20 14:29:58.743221+00');
INSERT INTO public.stand_submissions VALUES ('ef51f82f-80a7-4677-897e-054bef788393', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'bdfbc104-5e19-4315-89e3-fc1deb0839da', 'STD-BIRM27-C10', '25832db2-93c1-476d-8553-27e698d4b3ad', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.74645+00', '2026-10-20 14:29:58.74645+00');
INSERT INTO public.stand_submissions VALUES ('5d567ef6-7ce6-4ccd-af7e-543bc758d74c', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'a09a38e2-42e8-4600-aa95-9e8c79045935', 'STD-BIRM27-C20', '916f4741-ae4f-492d-9306-8eea591faf72', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 14:29:58.749115+00', '2026-10-20 14:29:58.749115+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('597d129b-0fb9-44f7-9767-16b4738f36be', '44ab18dd-203e-4c7b-9189-998b4627a715');
INSERT INTO public.supplier_service_links VALUES ('597d129b-0fb9-44f7-9767-16b4738f36be', 'd7ea799b-febc-44e4-801b-76fa3d2422a9');
INSERT INTO public.supplier_service_links VALUES ('1d193856-613f-499e-8ebc-25d619be705e', '1841950b-f9f8-4dce-bb03-b9664054d8c4');
INSERT INTO public.supplier_service_links VALUES ('1d193856-613f-499e-8ebc-25d619be705e', 'd7ea799b-febc-44e4-801b-76fa3d2422a9');
INSERT INTO public.supplier_service_links VALUES ('1d193856-613f-499e-8ebc-25d619be705e', '7c7176e4-03d0-463b-a09e-8cac5a187e53');
INSERT INTO public.supplier_service_links VALUES ('3cb3adae-9697-42be-8df9-1131690ce0f8', '50dbf877-cb7e-4e0e-a467-bb6bb4d71794');
INSERT INTO public.supplier_service_links VALUES ('3cb3adae-9697-42be-8df9-1131690ce0f8', '7c7176e4-03d0-463b-a09e-8cac5a187e53');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('44ab18dd-203e-4c7b-9189-998b4627a715', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Signage print', 1, false, '2026-10-20 14:29:57.776738+00', '2026-10-20 14:29:57.776738+00');
INSERT INTO public.supplier_services VALUES ('50dbf877-cb7e-4e0e-a467-bb6bb4d71794', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Digital screens & AV', 2, false, '2026-10-20 14:29:57.778796+00', '2026-10-20 14:29:57.778796+00');
INSERT INTO public.supplier_services VALUES ('1841950b-f9f8-4dce-bb03-b9664054d8c4', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Rigging', 3, false, '2026-10-20 14:29:57.780596+00', '2026-10-20 14:29:57.780596+00');
INSERT INTO public.supplier_services VALUES ('d7ea799b-febc-44e4-801b-76fa3d2422a9', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Installation', 4, false, '2026-10-20 14:29:57.782278+00', '2026-10-20 14:29:57.782278+00');
INSERT INTO public.supplier_services VALUES ('7c7176e4-03d0-463b-a09e-8cac5a187e53', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Staffing', 5, false, '2026-10-20 14:29:57.783861+00', '2026-10-20 14:29:57.783861+00');
INSERT INTO public.supplier_services VALUES ('82c0d40a-8c75-4990-84db-5fcff40d98fc', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Furniture', 6, false, '2026-10-20 14:29:57.785896+00', '2026-10-20 14:29:57.785896+00');
INSERT INTO public.supplier_services VALUES ('c0046725-42e4-4874-8d6f-5d7eb0ab4c18', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Structural engineering', 7, false, '2026-10-20 14:29:57.787764+00', '2026-10-20 14:29:57.787764+00');
INSERT INTO public.supplier_services VALUES ('0e4139a7-1a8b-49c8-8570-623abc5010e3', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Floor Manager', 8, false, '2026-10-20 14:29:57.789473+00', '2026-10-20 14:29:57.789473+00');
INSERT INTO public.supplier_services VALUES ('7661ce4e-ff81-4c84-be28-0dba8904f677', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Security', 9, false, '2026-10-20 14:29:57.790962+00', '2026-10-20 14:29:57.790962+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('597d129b-0fb9-44f7-9767-16b4738f36be', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-20 14:29:57.769031+00', '2026-10-20 14:29:57.769031+00', false);
INSERT INTO public.suppliers VALUES ('1d193856-613f-499e-8ebc-25d619be705e', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-20 14:29:57.772257+00', '2026-10-20 14:29:57.772257+00', false);
INSERT INTO public.suppliers VALUES ('3cb3adae-9697-42be-8df9-1131690ce0f8', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-20 14:29:57.775142+00', '2026-10-20 14:29:57.775142+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('9075a720-cbc4-4309-8bc3-3e83d34c71fd', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-27', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '110fcf29-4f69-4ea3-9cc9-ae1c4a1a847a', NULL, '2026-10-20 14:29:58.756784+00', '2026-10-20 14:29:58.756784+00', NULL);
INSERT INTO public.tasks VALUES ('838e89c5-3883-4447-9ae6-ec57a014d4f8', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-30', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 14:29:58.75902+00', '2026-10-20 14:29:58.75902+00', NULL);
INSERT INTO public.tasks VALUES ('72c77e7c-c698-4987-b30f-cf678e5b1d0d', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Walk the hall with the venue', NULL, 'done', '2026-10-15', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-20 14:29:57.634+00', '2026-10-20 14:29:58.760642+00', '2026-10-20 14:29:58.760642+00', '838e89c5-3883-4447-9ae6-ec57a014d4f8');
INSERT INTO public.tasks VALUES ('87b34a6f-4304-4708-a810-ea84ce609ac8', 'cdefdce7-e027-4686-815d-e686802f0d6b', '9ca41a0e-5976-45c1-9478-b741ec5a8538', 'Send sign positions to the printer', NULL, 'open', '2026-10-19', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 14:29:58.760642+00', '2026-10-20 14:29:58.760642+00', '838e89c5-3883-4447-9ae6-ec57a014d4f8');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.666758+00', '2026-10-20 14:29:57.666758+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.673222+00', '2026-10-20 14:29:57.673222+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.676836+00', '2026-10-20 14:29:57.676836+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.679977+00', '2026-10-20 14:29:57.679977+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.683845+00', '2026-10-20 14:29:57.683845+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-20 14:29:57.687005+00', '2026-10-20 14:29:57.687005+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.024682+00', '2026-10-20 14:29:58.024682+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.030759+00', '2026-10-20 14:29:58.030759+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.035909+00', '2026-10-20 14:29:58.035909+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.040612+00', '2026-10-20 14:29:58.040612+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.045173+00', '2026-10-20 14:29:58.045173+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-20 14:29:58.089648+00', '2026-10-20 14:29:58.089648+00', true);


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('64b16f70-ac1b-4cb6-a1a9-52f85b642c25', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-20 14:29:57.699332+00', '2026-10-20 14:29:57.699332+00');
INSERT INTO public.venue_rules VALUES ('c7800b0b-76bd-471a-9549-4a765b8d8cb3', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-20 14:29:57.701803+00', '2026-10-20 14:29:57.701803+00');
INSERT INTO public.venue_rules VALUES ('32ee39d9-757c-4de6-b508-20bdeed21c41', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-20 14:29:57.704042+00', '2026-10-20 14:29:57.704042+00');
INSERT INTO public.venue_rules VALUES ('f2b496aa-7ffb-4aa0-a386-8736018359ef', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-20 14:29:57.706116+00', '2026-10-20 14:29:57.706116+00');
INSERT INTO public.venue_rules VALUES ('86a1038b-32a3-4090-ae35-1bbaf60c54e7', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-20 14:29:57.708684+00', '2026-10-20 14:29:57.708684+00');
INSERT INTO public.venue_rules VALUES ('7dc7d9a0-6af5-4341-9dbd-dca39a936934', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-20 14:29:57.711291+00', '2026-10-20 14:29:57.711291+00');
INSERT INTO public.venue_rules VALUES ('1dd11419-5591-4983-ae2f-a22d25c831ae', '0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-20 14:29:57.714166+00', '2026-10-20 14:29:57.714166+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('0b949755-4f2f-4d5e-8de5-f758be0ffb49', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-20 14:29:57.692196+00', '2026-10-20 14:29:57.692196+00', false);
INSERT INTO public.venues VALUES ('9282f21c-19d3-4844-9b42-0d7ce5ee3a36', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-20 14:29:57.694583+00', '2026-10-20 14:29:57.694583+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('a68f25aa-5d71-47f5-b96a-208f8464a6cd', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-20 14:29:57.92699+00', '2026-10-20 14:29:57.92699+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('5eb28843-4804-43ec-b377-15cc9adf2f16', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-20 14:29:57.929814+00', '2026-10-20 14:29:57.929814+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('d77d8db9-d3a3-4dca-8098-1188e8098956', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-20 14:29:57.931301+00', '2026-10-20 14:29:57.931301+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('f83edce0-8cc6-48fd-b08a-9fd5a9fe0e1c', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 14:29:57.93255+00', '2026-10-20 14:29:57.93255+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('bc6f39ff-943f-4fef-a34b-deb0d36dff90', '7abace82-91c9-44bb-b9b2-51b9b0e25af9', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 14:29:58.64789+00', '2026-10-20 14:29:58.652432+00', '{organiser,sponsor}', false, '340ee6f8-6497-45e3-ac89-6268b9504dd4');
INSERT INTO public.workflow_steps VALUES ('8889addf-46d9-4f98-8713-57f916569ab8', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-20 14:29:57.98543+00', '2026-10-20 14:29:57.98543+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('3a692444-6e4a-44c5-8d58-f7b343c64030', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-20 14:29:57.986945+00', '2026-10-20 14:29:57.986945+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('4ac5498a-c41c-4bd8-a7d1-29e9df616963', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-20 14:29:57.988484+00', '2026-10-20 14:29:57.988484+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('1357e33a-565d-45d5-9d66-fe9b53e95495', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-20 14:29:57.989804+00', '2026-10-20 14:29:57.989804+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('50bd0d89-0840-4910-8f45-a44e8edec8f0', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-20 14:29:57.990796+00', '2026-10-20 14:29:57.990796+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('3d8e095e-1aad-4c31-9a60-5b1f959703f3', 'c28e8d5d-27db-4b43-9117-f9cac182b5e8', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 14:29:57.991675+00', '2026-10-20 14:29:57.991675+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('374a392f-fe98-44b1-89dd-df85e374c19f', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 14:29:57.920401+00', '2026-10-20 14:29:58.638563+00', '{organiser,sponsor}', false, '7ff3cb3d-b720-4426-b140-89c37f6edb31');
INSERT INTO public.workflow_steps VALUES ('ebdb8492-091d-41bd-9f67-e58fa8d062ce', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 14:29:57.922925+00', '2026-10-20 14:29:58.639685+00', '{organiser,sponsor}', false, '88465857-25b1-4dd8-b581-6e56f5dd9de2');
INSERT INTO public.workflow_steps VALUES ('aaf6b08e-b076-4a98-b3dd-76f89962644e', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-20 14:29:57.924664+00', '2026-10-20 14:29:58.640772+00', '{sponsor}', false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49');
INSERT INTO public.workflow_steps VALUES ('fb7aa3f8-537b-4bcf-a433-1227442cabb4', '759de502-ea98-4b34-a4d6-291ca2dabd9b', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 14:29:57.928394+00', '2026-10-20 14:29:58.641868+00', '{organiser,sponsor}', false, '340ee6f8-6497-45e3-ac89-6268b9504dd4');
INSERT INTO public.workflow_steps VALUES ('96ff00f0-99bc-4858-a580-839e43ce3df2', '7abace82-91c9-44bb-b9b2-51b9b0e25af9', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 14:29:58.643908+00', '2026-10-20 14:29:58.649296+00', '{organiser,sponsor}', false, '7ff3cb3d-b720-4426-b140-89c37f6edb31');
INSERT INTO public.workflow_steps VALUES ('feee577f-9e49-4d2e-890c-fde83d076fb4', '7abace82-91c9-44bb-b9b2-51b9b0e25af9', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 14:29:58.645107+00', '2026-10-20 14:29:58.650388+00', '{organiser,sponsor}', false, '88465857-25b1-4dd8-b581-6e56f5dd9de2');
INSERT INTO public.workflow_steps VALUES ('efffdd04-aaff-4e9a-bc81-9ffd61075df8', '7abace82-91c9-44bb-b9b2-51b9b0e25af9', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 14:29:58.646469+00', '2026-10-20 14:29:58.651212+00', '{sponsor}', false, '19ebabd4-6c3b-4d72-9ec7-77849a710c49');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('759de502-ea98-4b34-a4d6-291ca2dabd9b', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Signage default', 'signage', true, false, '2026-10-20 14:29:57.918172+00', '2026-10-20 14:29:57.918172+00', NULL);
INSERT INTO public.workflows VALUES ('c28e8d5d-27db-4b43-9117-f9cac182b5e8', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Stand default', 'stand', true, false, '2026-10-20 14:29:57.983903+00', '2026-10-20 14:29:57.983903+00', NULL);
INSERT INTO public.workflows VALUES ('7abace82-91c9-44bb-b9b2-51b9b0e25af9', 'cdefdce7-e027-4686-815d-e686802f0d6b', 'Stand design sign-off', 'signage', false, false, '2026-10-20 14:29:58.633725+00', '2026-10-20 14:29:58.633725+00', 'stand_design');


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

\unrestrict wk5aTvcAh8CXhjGNyGREffdEeVM2lpcLnHcd7mwBSg1Vp7ytXCGhrr1rWO8SVCU

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
