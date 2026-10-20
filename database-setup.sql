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

\restrict HIymCzSANI0X6x8wvuRi7lkk6d6aLNZ8yIRuokhFgqEl9Lr9bpxiDE9s5sVbPpg

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
INSERT INTO drizzle.__drizzle_migrations VALUES (15, '7f513652309cdd9f7b029d2857c901c379135583f36893eb6d0b878010a050dc', 1792502669707);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('512b7f63-73db-4859-ba13-fb8ffe426e0a', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('f39c55d0-48e8-4681-ba17-c613e3c27824', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('7bfc3e48-2203-4100-b35e-9e0c00990100', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('da3824e8-4e3e-41b0-b046-e4a370a5e5ad', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c5ec1225-3f90-4c46-97bd-27f02c565142', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('dcdfb24a-b765-4571-b40c-e85f9e93c085', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('24724e35-def0-48e7-b925-9b1c51039ec8', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b28a08c2-5539-495b-b4d3-f0fc6bfdb2ca', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.453588+00', '2026-10-20 16:32:32.453588+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7f220f37-d7d0-42b9-87ee-90df53a517ce', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('735e3962-b4c4-49ff-a922-936ea5943015', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('5056fb9d-bb00-4470-b056-14feacd30698', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('071e3235-ffed-47af-a42b-adf191976086', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1a78b32d-7ae9-4ae4-a977-92de167d4f10', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('a1872538-1cbe-4b84-b4b2-7bdd9716637c', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fcfbcb6f-2b8a-4aa6-8c16-19f8086748b9', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4304b40f-a73d-413c-9f8d-7ae1f843f70a', 'signage_item', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.47633+00', '2026-10-20 16:32:32.47633+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3269826b-3122-4bd2-997a-11d55ab7acff', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 16:32:32.003+00', '2026-10-16 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('f808610a-d34e-4a2d-8ae1-e49516b7aa4b', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 16:32:32.003+00', '2026-10-11 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('35c92f07-a5d4-471f-8ea7-8df7edfd7cad', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-10 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 16:32:32.003+00', '2026-10-13 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('35e9fed3-cb7f-43a3-ad99-75b5b6d83973', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('182df79e-23a5-4e14-b509-728b564f090d', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('9c3837eb-e819-449f-bb77-af23ea620d3e', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('04545cc9-8f4e-4e1a-ba4b-f88c7188a2ce', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('94763e2a-3b88-4791-aa86-cb5d8935cd12', 'signage_item', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.498468+00', '2026-10-20 16:32:32.498468+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('71d6db8f-e4d1-4bde-9328-74c369f32f25', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('418c7613-ab3c-4c8b-945f-5cb11be96e72', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('96ee5338-00ff-48d1-b97b-feae963b6925', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('98526d8b-ef29-49ec-b048-4e1f38185eff', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0d3147ae-51cf-47e0-81c5-fc51feb975bf', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('619f6662-0e5b-4a04-a4f2-cdaf756cdb66', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9589f73a-e7fb-4dee-99cb-4ff1591c0f46', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3b44b6de-206e-4e4e-9d41-b05117afbbbb', 'signage_item', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.538223+00', '2026-10-20 16:32:32.538223+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e3ea29d4-925b-4de0-a3f5-423447827cd7', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('479fd5d9-b908-4300-87d1-0d7c6f1ec776', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('8b774a21-9a71-4858-a808-e2656f1a710c', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('d8461815-31cb-4fd5-be45-3fceb432c460', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('94d127b4-23d9-47a7-8084-f75c5df0274c', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('4b632d80-a828-4b39-8042-62fd81e5aab0', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('00a22305-9702-4285-8e7a-a374a5d77db2', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9ee9ba58-d43e-4105-a354-1e6f085cf82e', 'signage_item', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.566527+00', '2026-10-20 16:32:32.566527+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5fb42884-c526-4812-bb94-8846f7cd861b', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 16:32:32.003+00', '2026-10-11 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('19226e88-949f-4c62-b5c3-34bd0f0d7eb2', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-10 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-08 16:32:32.003+00', '2026-10-11 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('74102b6a-93c3-420e-958f-1e8bbb8fa77c', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('d88be276-2e5a-463a-bc65-7ec85105cb03', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cf05c9a7-ede1-4680-8ea2-632760082b5e', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', '2026-10-16 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('8c079acb-97b3-4669-8295-c27b1da43525', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d50317d3-d13f-4c34-a546-d01c0f241ad9', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('000acc9b-bf38-4d4d-8dcd-f834f3c3d3b3', 'signage_item', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.592016+00', '2026-10-20 16:32:32.592016+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1af0917b-1d5f-47aa-aa92-81c50c7bc1a0', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('0cc407c2-9ee8-4037-ba9c-e6d0e48d7eeb', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('be8565ed-e880-4eca-bc9f-45bdacbf655d', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('4529eb1c-1f19-4b93-ae38-e30173a4dc66', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a5c017e-c2c0-418d-9ee1-9aa8e85ef5a6', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('f435a366-59c9-443c-adb4-3acb85aaf04d', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8a906bf3-389f-431c-a339-c15151851d6e', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a180a20-c6c3-4543-99e0-4c97710aa33b', 'signage_item', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.613515+00', '2026-10-20 16:32:32.613515+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d7d5abf4-f371-4be7-b197-5793de480a2f', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('e9f5b40c-3960-4cf2-84cd-846230411639', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('6fd715e1-f908-4b65-9c8e-cdd83f8a3742', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('b3dec785-8bff-44a3-9903-0b8da9f52bcc', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a4a419c7-62bd-4d04-b392-81f12e2b6bdd', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('13fd23c9-3d16-4654-9d5f-4312ae7720e2', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8459d63b-8291-4c3e-8778-6affcf4d42ca', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ec2296c-00d4-4b50-8cb2-ede45c85f1fd', 'signage_item', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.63513+00', '2026-10-20 16:32:32.63513+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9cdf72b5-f234-4123-83e5-a802d56fe8bd', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('56e15c20-d22f-465e-87a9-089377c88f97', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('15fbfa70-2c93-4521-82ac-d0b735ba7664', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 16:32:32.003+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('9b2bdeea-fea9-442d-b226-4ed1b3708624', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1416b0ab-6654-4843-996b-13ccaeab0c3c', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('2119a2dc-d54b-4fe1-bca9-232a9ba479c0', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f0a4d112-d5ce-4ee4-89ca-b0457edb0f5a', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('71bc3b01-c88d-482f-aef9-299dec104109', 'signage_item', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.652793+00', '2026-10-20 16:32:32.652793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4e7779f9-2903-41f5-845a-6aa093d39fe7', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('d51716a1-02b1-489a-9ad3-0e8dbc2ba06d', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('f276d57f-17cd-4a6a-9f1e-c70031a42cdb', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('0384536b-0fa4-40d5-9a4a-bbe33f557fc7', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f8b5c88a-0ac0-40fc-8550-e978f7352a61', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('092a4fe8-2f13-4ebb-b420-4971855a6a2b', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d21447ab-8e1a-45db-97bf-9b1d87cc462c', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('88cbd6c3-6f99-43e1-9492-f2a4fc977130', 'signage_item', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.67367+00', '2026-10-20 16:32:32.67367+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a7cc213-69df-4ada-9876-a62f02137a43', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('a2408a24-3f8f-4df1-a457-46eae11fdada', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('d8a076bc-71f2-4770-9389-1ed6035fceb0', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('82ba8c7d-efa1-4abe-a26d-1fbd7fa713cb', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a21c2dbe-5b79-496d-bf1b-2bf98caf3480', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d26b6258-d13f-48e3-91b5-56a8d7b7bde6', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('2b067fbd-8a85-487f-a8b3-7257928de3ef', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a36aebb1-34c9-431e-8ff4-6ac87162f458', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('21834314-4fa2-4ecc-ac9d-82e17d494f02', 'signage_item', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.69346+00', '2026-10-20 16:32:32.69346+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3531ac3b-4f0f-4463-9deb-b08705d2bd53', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('bd4f43a9-7e31-4a18-96d1-ef399eb771a8', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('811cba59-563b-44cc-87d9-cd73398f7880', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('a21f41c6-16a1-4f0a-b531-3e186c18625c', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bf1d326e-87a7-42c2-bd77-591af8b9e760', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('6d3ca46d-417a-41bb-b649-c160d545c53f', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c90cedfd-ea13-4b87-b002-d26bcd4fbfb7', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('989f5ae5-6310-45b5-90e7-fc57db9ebe89', 'signage_item', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.714101+00', '2026-10-20 16:32:32.714101+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('faa40355-3cbe-426a-8593-6047ab772982', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('5bbb1d8c-567a-4770-ae70-0e4316820ca7', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('a763dc25-d92f-4f40-aaf7-fe35d2235f87', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('019970c5-c60a-4910-b0bd-5c99861186ac', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a6635e43-7b15-4739-868b-37a02b963129', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('f273090e-8f1b-4068-8748-722e6fa98c51', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5fa2d514-b592-4987-8f51-7b5fd0caab9e', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f6799d72-61b1-40e4-9498-ee289b46d38e', 'signage_item', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.733845+00', '2026-10-20 16:32:32.733845+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5384df97-877f-4fdc-9e0d-3063eb80ccb5', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('90c9d09b-6ca5-4d87-a05a-4a8e940ef505', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('f1c0c2d8-a524-4c33-8085-2571e0b14975', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('3a62d09f-8889-43d6-95a2-d78842fad529', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b25cbfd1-da3a-4688-8778-692bf787e044', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('10231ba9-5779-4ed9-986b-1f423ebdb19e', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('95c0ed59-31b8-49e4-bc3f-6246ee28bc47', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1fd69531-f208-40e3-b212-3b852a1cb618', 'signage_item', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.754378+00', '2026-10-20 16:32:32.754378+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ac879e0a-1776-4521-bf28-282dd6b16870', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('c4661890-379b-49c7-86fd-a34b2f87b491', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('0a822dd0-f840-42b8-9eb2-cd4a2c0e3a59', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('066eaa73-a6c1-4e98-847d-5cbdd755805c', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('246b30ff-1cc5-423d-b94d-998b44fb0ce4', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('8ed41bbb-92cc-43f5-93c5-463014a88106', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aed4689e-e8de-4404-bcea-d75e4465c70a', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a7d5d57-806f-4f89-92ed-3ca8b9736f70', 'signage_item', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.781498+00', '2026-10-20 16:32:32.781498+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a6445e29-4ba9-490f-a828-76c290ba5b8d', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('18087c4a-e7f3-4365-b073-9d2d39aff520', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('8aba19c4-cc07-4710-853d-967efed70369', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('0f044f1d-51fa-47ed-9d4e-72fd6f1b1d4e', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7bbc08b0-6b8a-409a-bdc8-0a02b78452ae', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('0b445b33-1d8a-4e52-8a2c-77a4180bb347', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1ab3bf2b-ba59-47a7-aa9b-8ebe26310d8f', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('14253117-9018-4424-9294-5af83ecb9cfe', 'signage_item', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:32.812459+00', '2026-10-20 16:32:32.812459+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ec6f7600-5797-4058-a1eb-4f370fcd8eaf', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('3bdcdf24-b6fd-49d5-9f9a-e420973098b0', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('3827cf49-3a25-40d7-9041-e78d37859ae3', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('a38aadb9-77d4-4077-8077-b9a0b3241bdf', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e081be9c-65ca-4152-94c4-7fc553730f64', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('c808755f-5a4b-4ebe-9df4-a603082d03e0', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8d9d85a2-e953-4d78-ad98-7b6c5717417e', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('af178b97-435d-4ed8-ae21-ab75b55fc9c0', 'signage_item', '2b2117a0-715b-418f-8439-906703a149d4', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.837148+00', '2026-10-20 16:32:32.837148+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fe59ab41-db3b-4573-b083-4ac4832c8342', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('5aef5444-8cc6-4f0f-8998-70e987c7236a', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('9692f8cf-8330-4846-9314-f579db578e48', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('f851e59a-dfe9-4262-8c77-19cb17a76ebe', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a24eb5bb-da4d-4323-8085-9dc0f9fe47e2', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('35d527e1-0c7f-40a4-a851-288b3f93b80a', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8d043541-7031-45fc-a410-ec978b85cf77', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4573ae06-4821-4301-ae30-49f932e37bfe', 'signage_item', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.859484+00', '2026-10-20 16:32:32.859484+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9edce201-97f6-4231-9aad-3ebef8a4a583', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('f345e591-93e5-41e3-94b6-dd1fe366bf3b', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 16:32:32.003+00', '2026-10-22 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('511a8f0d-ce74-476b-ad08-95f0e57fb232', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('a41ecd5f-c9ec-4063-9ddf-788cd3db260d', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 16:32:32.003+00', '2026-10-22 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('eab50d17-e642-4dd5-9c44-f13278460c96', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('617eae65-9ce8-4c1d-b21e-eccbee0db0da', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-19 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('61b67012-627f-4ae1-966d-51f59d4d3a5b', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e3b313c2-6110-47f3-aa71-8f3c828324cb', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('4b11da7b-336d-474f-bfbe-2a6d46ac9f70', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ad8ba2f7-5aef-4201-bcd0-32354b30f029', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d34fba24-44f4-4373-8068-ee46c215c035', 'signage_item', 'feb6de4e-7590-4753-9d46-54346952020f', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.883476+00', '2026-10-20 16:32:32.883476+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ca5deac4-1c90-4fc3-b315-15e20a8d0793', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('cc1043f4-42c9-4b3b-9a68-d6cbdea01322', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('c69a9945-1572-4da7-bc8b-79fb93440794', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('0d867002-4b80-4e6f-b0ed-e3b496d38c09', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('96be74dc-4c5c-42cb-b41b-8e8ed421236f', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('3eb5ef0f-cf40-4238-b64d-8cc0ef35b200', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5ae1cb03-cf80-4b30-985f-f118f8d6c8d6', 'signage_item', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.94266+00', '2026-10-20 16:32:32.94266+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3c23d7b4-8b38-4fe2-9817-42420149af9f', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('fb2dc64a-e4f5-41e2-9106-9b29bc905440', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('14c7e1db-1e1d-4633-94dc-7565c5bc4059', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('c981d4e3-07f9-4dc2-b6a9-46c1575901e5', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-17 16:32:32.003+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-24 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4f88463b-830f-439f-963a-6ea78b2c4bfd', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('35bba428-b7d5-43ab-a7b4-4bdf8cc9135e', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-19 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('442b5368-cf70-41bc-906b-14bee52263a0', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f07a4712-bd07-4b18-b60e-67118ab82592', 'signage_item', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.961891+00', '2026-10-20 16:32:32.961891+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('72cbd41b-7bcf-4ea2-a293-0549105f3f6d', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, '129dce63-a304-4c6a-831a-7e8bf8882d75', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 3, false, '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL);
INSERT INTO public.approval_instances VALUES ('245ab7a9-5506-42b8-bcb7-81b8aad18ea0', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, '5797db91-099d-4f89-8808-31d79ec689c9', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 3, false, '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL);
INSERT INTO public.approval_instances VALUES ('e8237b2a-1db5-418c-9157-445491b02fd0', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, '223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 16:32:32.003+00', '2026-10-20 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 5, false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL);
INSERT INTO public.approval_instances VALUES ('041c2240-43a7-450b-8dbf-53264384ec70', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, 'a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5277abb6-45df-4cc7-9b03-fe58b12d8ea9', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, 'c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 3, false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL);
INSERT INTO public.approval_instances VALUES ('b4e67cfb-3e1d-40d9-8053-7e789ce6f4a6', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, 'b22eb044-d17a-48d6-8318-c466dde82b55', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('adfc5461-ef72-4847-8765-dd79cfece48c', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, '0abf5528-c585-4e59-8e1f-f36326534d82', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('06ead43d-d53e-47ae-9e2b-771fdf57689e', 'signage_item', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, '8e5c47c0-14fa-4986-8419-93ab49b2e095', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:32.985033+00', '2026-10-20 16:32:32.985033+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fb857885-241f-4952-b0f4-ee791f5e6d0d', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, 'c96c031b-c13a-4c9a-ace4-7c9936dfd805', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 16:32:32.003+00', '2026-10-17 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dd37cf2d-3e7e-41fd-9fe7-78142284c8d2', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, '1b060e92-997e-4e7b-a059-98d09865c0a4', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 16:32:32.003+00', '2026-10-23 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('75b747cc-4436-48bf-9708-5267a1e2ad0f', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, '5aa18475-a317-465b-ae01-f4aee48c96ed', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b77658f-6aa0-484e-95ed-a6f3ab51be4d', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, 'fc571e6e-7833-4a1d-b5bf-1794bb5f7079', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c1879423-cbf3-4bee-bcd8-c124f183cdeb', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, '16a9ec03-5063-40cd-8ed9-93a93b0471e8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d5488b54-b582-493b-8ad1-a322205e9de2', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 1, '451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('db692b57-cd85-44c4-a57a-d4b0701bbb16', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, 'c96c031b-c13a-4c9a-ace4-7c9936dfd805', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 16:32:32.003+00', '2026-10-17 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7f291e50-3ae9-4801-b03d-bbf981a8d521', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, '1b060e92-997e-4e7b-a059-98d09865c0a4', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('af73b8ff-b506-4fae-ab6e-c94240709d4f', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, '5aa18475-a317-465b-ae01-f4aee48c96ed', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('63a2dd7e-1ee3-4740-9edd-51d57ca1a591', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, 'fc571e6e-7833-4a1d-b5bf-1794bb5f7079', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e62728b5-25e2-46df-bf37-70bc40cd57d1', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, '16a9ec03-5063-40cd-8ed9-93a93b0471e8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('af215538-643d-4757-b09b-39960c26b2eb', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 1, '451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a36a4994-0759-4cdd-bd5f-857027a86273', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, 'c96c031b-c13a-4c9a-ace4-7c9936dfd805', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-14 16:32:32.003+00', '2026-10-17 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cb0b42a1-4c91-43c2-999b-bf9143c8f6c6', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, '1b060e92-997e-4e7b-a059-98d09865c0a4', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d9e8d9f9-9a0e-47b2-96ba-4774f922a869', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, '5aa18475-a317-465b-ae01-f4aee48c96ed', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('50b4e3dc-1317-42a5-8fa4-d85a2a422650', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, 'fc571e6e-7833-4a1d-b5bf-1794bb5f7079', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('69d5257b-7b06-4c73-a1c6-b2c7b6fb5d2c', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, '16a9ec03-5063-40cd-8ed9-93a93b0471e8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('22a1f93d-cdb4-4228-b71f-eb3a84e76390', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 1, '451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a5c1193-ae41-4ee7-b676-4a1c36c616c9', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, 'c96c031b-c13a-4c9a-ace4-7c9936dfd805', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 16:32:32.003+00', '2026-10-17 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d21de732-49cf-44d1-a3f0-01506404aff4', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, '1b060e92-997e-4e7b-a059-98d09865c0a4', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ff41788-9286-4f64-83aa-68cc94daabda', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, '5aa18475-a317-465b-ae01-f4aee48c96ed', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-21 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('33066afc-c0a2-4f91-a779-f399af5f34a7', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, 'fc571e6e-7833-4a1d-b5bf-1794bb5f7079', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-23 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('00e1e101-7e73-4f19-ba39-43e864f08965', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, '16a9ec03-5063-40cd-8ed9-93a93b0471e8', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d342e10a-184d-4ffb-bd3d-5c750fabf031', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 1, '451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e7c77c3a-2e6d-494e-b145-1594dc367faa', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, 'c96c031b-c13a-4c9a-ace4-7c9936dfd805', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-14 16:32:32.003+00', '2026-10-17 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e4d85614-e8a9-46da-994d-7fb1d6be4c04', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, '1b060e92-997e-4e7b-a059-98d09865c0a4', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c55b0f3b-6e89-4965-b34b-d0a98cef3dea', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, '5aa18475-a317-465b-ae01-f4aee48c96ed', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-21 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('896c815b-9f79-4f78-b0d4-cc8eb6e4a966', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, 'fc571e6e-7833-4a1d-b5bf-1794bb5f7079', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-23 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2891c7a6-54e2-4a70-a686-ddb97504ead1', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, '16a9ec03-5063-40cd-8ed9-93a93b0471e8', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 16:32:32.003+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-16 16:32:32.003+00', '2026-10-18 16:32:32.003+00', 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('586a6819-6e21-44aa-b724-cb6958e1162b', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 1, '451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 16:32:32.003+00', NULL, 0, NULL, NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('2d72f919-cc78-47b6-8dcc-f89514ff9350', '617224a2-546d-4403-8443-4750f2372e7c', '8944f948-1b60-46a1-a2b8-991731ba53ca', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-20 16:32:32.29479+00', '2026-10-20 16:32:32.29479+00', false, NULL);
INSERT INTO public.approvers VALUES ('37ed6336-ae9f-4164-9e8a-1dddb7d49252', '617224a2-546d-4403-8443-4750f2372e7c', '9d8434b4-4283-44d0-8919-2bc44356f2af', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-20 16:32:32.302438+00', '2026-10-20 16:32:32.302438+00', false, NULL);
INSERT INTO public.approvers VALUES ('0bd1ea5e-7889-49db-b5df-ce4fa4354d44', '617224a2-546d-4403-8443-4750f2372e7c', 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-20 16:32:32.309495+00', '2026-10-20 16:32:32.309495+00', false, NULL);
INSERT INTO public.approvers VALUES ('0c9e4f6f-6d97-4ee7-9d3f-1a70b465f784', '617224a2-546d-4403-8443-4750f2372e7c', '84196ff9-50de-43c9-bd8c-f0ed23741ba8', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-20 16:32:32.315987+00', '2026-10-20 16:32:32.315987+00', false, NULL);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('a61b80d8-3d37-4b2d-b7df-754c635b3493', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.44851+00', '2026-10-20 16:32:32.44851+00');
INSERT INTO public.artwork_versions VALUES ('d01f27af-3883-4dfc-9e68-247d10a6be36', 'e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.473154+00', '2026-10-20 16:32:32.473154+00');
INSERT INTO public.artwork_versions VALUES ('a3dc4d27-ae71-4892-8cff-7916c5bca765', '5610639c-0f53-4f84-991c-6a84f29d6e80', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-20 16:32:32.493951+00', '2026-10-20 16:32:32.493951+00');
INSERT INTO public.artwork_versions VALUES ('c3df84d8-067a-4f4a-adcf-44d192dc09e8', '5610639c-0f53-4f84-991c-6a84f29d6e80', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.495563+00', '2026-10-20 16:32:32.495563+00');
INSERT INTO public.artwork_versions VALUES ('03adadf9-791c-4c2a-bb5e-c7441cd13b1f', '8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.534565+00', '2026-10-20 16:32:32.534565+00');
INSERT INTO public.artwork_versions VALUES ('1cae02d9-ebfc-4597-9025-294b51ad66bc', '0b1c405d-1415-4a95-9c53-6077ab65bfa6', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.563172+00', '2026-10-20 16:32:32.563172+00');
INSERT INTO public.artwork_versions VALUES ('47686cd3-6739-417c-b9d0-1984c3d77cce', '4586623c-8f9e-43da-ad1a-2c738aaecc18', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.588799+00', '2026-10-20 16:32:32.588799+00');
INSERT INTO public.artwork_versions VALUES ('e3fb22ff-db2e-4c95-ba7e-6abd17c206bc', 'c4798d9f-e4da-4038-b3cd-369787efe22d', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.610862+00', '2026-10-20 16:32:32.610862+00');
INSERT INTO public.artwork_versions VALUES ('36dc3098-7f06-4c06-bd4d-31e101e89089', '2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.631554+00', '2026-10-20 16:32:32.631554+00');
INSERT INTO public.artwork_versions VALUES ('d880df72-632f-4d94-a1a3-9abc0be451f1', '5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.650174+00', '2026-10-20 16:32:32.650174+00');
INSERT INTO public.artwork_versions VALUES ('b8e2164a-be35-443e-bbd6-0164ff81330b', 'a283b442-d33c-4f7f-b330-67aed9301be7', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.67151+00', '2026-10-20 16:32:32.67151+00');
INSERT INTO public.artwork_versions VALUES ('c080d71d-c679-475e-9eaf-e510f86878d6', 'b0120a19-312b-4173-b7d9-2655c29c74f2', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.689613+00', '2026-10-20 16:32:32.689613+00');
INSERT INTO public.artwork_versions VALUES ('11ee6e4d-8b31-45e5-9c8b-cdd42fe37781', '16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.711052+00', '2026-10-20 16:32:32.711052+00');
INSERT INTO public.artwork_versions VALUES ('e3c9a2a6-547a-4010-84b8-f194ddb3bcff', '1641dc19-aba1-47b4-a778-e35af4c8b68f', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.731139+00', '2026-10-20 16:32:32.731139+00');
INSERT INTO public.artwork_versions VALUES ('f6ca2f9c-7950-4af8-b29e-f8b9645f0e77', 'a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.751057+00', '2026-10-20 16:32:32.751057+00');
INSERT INTO public.artwork_versions VALUES ('e98c86f6-04cb-4369-8c37-ae0484abafeb', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.77816+00', '2026-10-20 16:32:32.77816+00');
INSERT INTO public.artwork_versions VALUES ('8166ecd6-0b0d-4791-8c67-6fcefe4ac3d2', 'ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.809127+00', '2026-10-20 16:32:32.809127+00');
INSERT INTO public.artwork_versions VALUES ('eeaa310c-a099-4812-8a93-7ad395b3a789', '2b2117a0-715b-418f-8439-906703a149d4', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.833865+00', '2026-10-20 16:32:32.833865+00');
INSERT INTO public.artwork_versions VALUES ('693f73de-444b-418b-8dd1-9303ba563bbe', '593641fa-83a7-49b5-9f28-e0e12c29aef7', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.85665+00', '2026-10-20 16:32:32.85665+00');
INSERT INTO public.artwork_versions VALUES ('345a0ecc-aec1-4f29-8803-d1fe12c6693d', 'feb6de4e-7590-4753-9d46-54346952020f', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 16:32:32.87718+00', '2026-10-20 16:32:32.87718+00');
INSERT INTO public.artwork_versions VALUES ('10f7ebd1-fe2c-4506-8a2f-d334dc7b6e03', 'feb6de4e-7590-4753-9d46-54346952020f', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-20 16:32:32.878919+00', '2026-10-20 16:32:32.878919+00');
INSERT INTO public.artwork_versions VALUES ('17929d3f-b4b9-4f77-8ec0-a0597d542dad', 'feb6de4e-7590-4753-9d46-54346952020f', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.88031+00', '2026-10-20 16:32:32.88031+00');
INSERT INTO public.artwork_versions VALUES ('b80596ad-6186-4bbc-b182-df9db5b8c760', 'da05cd6a-c162-433f-b8f0-e33a05e9cae4', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-20 16:32:32.939404+00', '2026-10-20 16:32:32.939404+00');
INSERT INTO public.artwork_versions VALUES ('7f41c837-7a12-4e93-beb6-46666b769fcb', 'bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.959296+00', '2026-10-20 16:32:32.959296+00');
INSERT INTO public.artwork_versions VALUES ('55240299-e02c-402c-a705-14491b42cabe', 'f6dec329-eda3-4f9b-945c-991e2294fa98', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-20 16:32:32.982867+00', '2026-10-20 16:32:32.982867+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.audit_log VALUES ('eb3e4859-2dce-44cf-98ff-446d28ca7863', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', NULL, 'system', 'sponsorship_package', '60d312e8-1686-41cc-9951-8fc39a8fffdb', 'create', NULL, '{"name": "Headline sponsor", "lines": [{"quantity": 6, "description": "Logo on 6 hanging banners"}, {"quantity": 1, "description": "Entrance feature branding"}], "price": "25000.00", "places": 1, "description": "Top billing across the venue"}', 'Added package Headline sponsor at £25,000', NULL, NULL, '2026-10-20 16:32:32.190515+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('48d5f1cd-fe79-424c-b123-a41264c1ce5c', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', NULL, 'system', 'sponsor', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "60d312e8-1686-41cc-9951-8fc39a8fffdb", "packageName": "Headline sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["6 × Logo on 6 hanging banners", "Entrance feature branding"]}, "packagePrice": "22500.00", "packageSoldAt": "2026-10-10T16:32:32.003Z", "packagePriceNote": "Early-booking discount"}', 'BuildCo bought Headline sponsor for £22,500 (list £25,000: Early-booking discount)', NULL, NULL, '2026-10-20 16:32:32.190515+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('d208fae3-9d75-4ab6-98c8-46b4d8b20adb', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', NULL, 'system', 'sponsorship_package', '04439ea3-50e4-49eb-872a-2fa896cecb64', 'create', NULL, '{"name": "Seminar theatre sponsor", "lines": [{"quantity": 1, "description": "Seminar theatre branding"}], "price": "8000.00", "places": 2, "description": "Branding in the seminar theatre"}', 'Added package Seminar theatre sponsor at £8,000', NULL, NULL, '2026-10-20 16:32:32.240236+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('6cd7346d-f1d4-4894-a860-2c17612edac6', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', NULL, 'system', 'sponsor', '22bc90f5-619b-4205-b329-9221aeee466d', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "04439ea3-50e4-49eb-872a-2fa896cecb64", "packageName": "Seminar theatre sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["Seminar theatre branding"]}, "packagePrice": "8000.00", "packageSoldAt": "2026-10-10T16:32:32.003Z", "packagePriceNote": null}', 'ToolMart bought Seminar theatre sponsor for £8,000', NULL, NULL, '2026-10-20 16:32:32.240236+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('17b9de90-0c4c-4b2f-8fbb-ad576d9b7b78', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', NULL, 'system', 'sponsorship_package', '35967320-c6c3-4e7e-8064-589db67fe688', 'create', NULL, '{"name": "Feature area sponsor", "lines": [{"quantity": 2, "description": "Feature area banners"}, {"quantity": 1, "description": "Logo in the event guide"}], "price": "12000.00", "places": 3, "description": "Branding around the feature area"}', 'Added package Feature area sponsor at £12,000', NULL, NULL, '2026-10-20 16:32:32.257906+00', NULL, NULL);


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

INSERT INTO public.contractors VALUES ('3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', '617224a2-546d-4403-8443-4750f2372e7c', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-20 16:32:32.170747+00', '2026-10-20 16:32:32.170747+00');
INSERT INTO public.contractors VALUES ('ed87df9d-8261-4091-b411-b195e264c72c', '617224a2-546d-4403-8443-4750f2372e7c', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-20 16:32:32.1739+00', '2026-10-20 16:32:32.1739+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('8944f948-1b60-46a1-a2b8-991731ba53ca', '617224a2-546d-4403-8443-4750f2372e7c', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-20 16:32:32.290825+00', '2026-10-20 16:32:32.290825+00', true);
INSERT INTO public.departments VALUES ('9d8434b4-4283-44d0-8919-2bc44356f2af', '617224a2-546d-4403-8443-4750f2372e7c', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-20 16:32:32.29992+00', '2026-10-20 16:32:32.29992+00', true);
INSERT INTO public.departments VALUES ('f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', '617224a2-546d-4403-8443-4750f2372e7c', 'Sales', 3, false, '{sponsor}', false, '2026-10-20 16:32:32.306801+00', '2026-10-20 16:32:32.306801+00', true);
INSERT INTO public.departments VALUES ('84196ff9-50de-43c9-bd8c-f0ed23741ba8', '617224a2-546d-4403-8443-4750f2372e7c', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-20 16:32:32.31339+00', '2026-10-20 16:32:32.31339+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('ece89087-0b1c-46f3-8917-ba67302cb73b', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00');
INSERT INTO public.documents VALUES ('caa87e4b-1631-4ed8-aa67-9a18b340ea65', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00');
INSERT INTO public.documents VALUES ('e9ee216d-461b-4899-9640-183317856d1d', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00');
INSERT INTO public.documents VALUES ('8c1b8b09-32da-4269-b89a-8ffd7336db85', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'cb7b6bd9-a211-4d18-89ff-170c70633ccc', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00');
INSERT INTO public.documents VALUES ('0e1aafed-a8bf-4419-ae26-029be8bd8b78', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00');
INSERT INTO public.documents VALUES ('39a7ed62-1c34-4513-ab20-18a44a1f4ba4', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00');
INSERT INTO public.documents VALUES ('3f8fa433-7de4-4379-ae1f-97e511eadb3d', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00');
INSERT INTO public.documents VALUES ('96612ba8-745d-4a0a-a4ef-16da1d50593d', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '4f50009d-cf62-4c11-9b40-8536adc2dfcf', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00');
INSERT INTO public.documents VALUES ('a6798dfb-0b29-45cf-9670-2035f3e888e2', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00');
INSERT INTO public.documents VALUES ('b2e6091f-e915-49b3-9593-c72581d37ac7', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00');
INSERT INTO public.documents VALUES ('fdaeb83f-8d1c-4243-91f0-6f784d76cca9', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00');
INSERT INTO public.documents VALUES ('b422ca88-9374-46a8-8376-c4d5a1e84b6e', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', '27330cd6-8c39-4031-b784-34007054cffb', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00');
INSERT INTO public.documents VALUES ('152dea4d-b8a2-4cef-89c8-fc5207e6be54', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00');
INSERT INTO public.documents VALUES ('52495049-176b-4ca3-861b-9df989926c84', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00');
INSERT INTO public.documents VALUES ('cd21f12f-b4a1-4e36-8317-65bba61844a9', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00');
INSERT INTO public.documents VALUES ('106208dd-4c95-42d5-847f-aa3667a80f2e', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'e90f86cf-52be-4bd7-aacf-6e4aba73a134', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00');
INSERT INTO public.documents VALUES ('b4031f3b-0871-466c-b475-68f9dfd487d8', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00');
INSERT INTO public.documents VALUES ('8fdcbfa7-7b47-48dd-a5c4-7395c9c3cea8', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00');
INSERT INTO public.documents VALUES ('64b8d603-b23b-497b-b9f2-efcb2a0c8f6c', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00');
INSERT INTO public.documents VALUES ('d944a3d3-d619-428a-ad06-6779a6be247e', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_submission', 'b540165e-12a6-4f3b-89cf-4f6f454c24b3', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('5acd14c0-1f1f-4516-b995-20db70917488', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'signage', 34, '2026-10-20 16:32:33.007494+00', '2026-10-20 16:32:33.009125+00');
INSERT INTO public.edition_counters VALUES ('99b15ec5-b489-4ed1-afa0-950c2ff5d618', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_design', 1, '2026-10-20 16:32:33.052007+00', '2026-10-20 16:32:33.052007+00');
INSERT INTO public.edition_counters VALUES ('1efde5e0-5f65-4d2a-9802-ffcb28cf12e6', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_item', 1, '2026-10-20 16:32:33.052007+00', '2026-10-20 16:32:33.052007+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('70d6d8d8-f5ee-437f-8e68-eef51b51b910', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-20 16:32:32.08953+00', '2026-10-20 16:32:32.08953+00');
INSERT INTO public.edition_deadlines VALUES ('b7fefcbe-661b-4224-8426-4be929f3bf31', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-20 16:32:32.091911+00', '2026-10-20 16:32:32.091911+00');
INSERT INTO public.edition_deadlines VALUES ('2db0ab33-a64f-4795-8dcb-e794d4b21655', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-20 16:32:32.093626+00', '2026-10-20 16:32:32.093626+00');
INSERT INTO public.edition_deadlines VALUES ('6ab38df5-6a6c-4552-83e0-686ebdfc8ff3', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-20 16:32:32.095305+00', '2026-10-20 16:32:32.095305+00');
INSERT INTO public.edition_deadlines VALUES ('a2592ad7-471e-49d1-ab0e-5042247b252e', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-20 16:32:32.096871+00', '2026-10-20 16:32:32.096871+00');
INSERT INTO public.edition_deadlines VALUES ('e268631c-38d2-4256-8d43-995e18a5dc33', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-20 16:32:32.098602+00', '2026-10-20 16:32:32.098602+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '0cb77c5c-739b-4a75-9b6a-66e31501a766', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-20 16:32:32.086423+00', '2026-10-20 16:32:32.086423+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('0cb77c5c-739b-4a75-9b6a-66e31501a766', '617224a2-546d-4403-8443-4750f2372e7c', 'UK Construction Week', 'UKCW', '2026-10-20 16:32:32.060429+00', '2026-10-20 16:32:32.060429+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('d62bd66d-c700-4d20-8a60-404d92d4e84d', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Exhibitor Co', 'A10', '793c79b2-47aa-48c7-bd26-99ebafb48053', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', '2026-10-20 16:32:32.409761+00', '2026-10-20 16:32:32.409761+00');
INSERT INTO public.exhibitors VALUES ('c4862222-12b8-4a5f-839a-f26d3d44c9ae', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SteelFrame Systems', 'A20', '793c79b2-47aa-48c7-bd26-99ebafb48053', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'ed87df9d-8261-4091-b411-b195e264c72c', '2026-10-20 16:32:32.41327+00', '2026-10-20 16:32:32.41327+00');
INSERT INTO public.exhibitors VALUES ('29859da7-1719-4ab0-b58f-0fbd42164c37', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'BrickWorks UK', 'A30', '793c79b2-47aa-48c7-bd26-99ebafb48053', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', '2026-10-20 16:32:32.415796+00', '2026-10-20 16:32:32.415796+00');
INSERT INTO public.exhibitors VALUES ('7d04072e-8bcd-452f-863c-38f4c1be8e70', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Timber Trade Ltd', 'B10', '793c79b2-47aa-48c7-bd26-99ebafb48053', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'ed87df9d-8261-4091-b411-b195e264c72c', '2026-10-20 16:32:32.41806+00', '2026-10-20 16:32:32.41806+00');
INSERT INTO public.exhibitors VALUES ('6b9a23f5-da92-4b0b-9dfd-cf929df1bb04', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'GlassTech', 'B20', '793c79b2-47aa-48c7-bd26-99ebafb48053', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', '2026-10-20 16:32:32.420626+00', '2026-10-20 16:32:32.420626+00');
INSERT INTO public.exhibitors VALUES ('537e91f7-8862-40f8-af51-2daf7f9360e0', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Insulate Pro', 'B30', '793c79b2-47aa-48c7-bd26-99ebafb48053', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'ed87df9d-8261-4091-b411-b195e264c72c', '2026-10-20 16:32:32.422634+00', '2026-10-20 16:32:32.422634+00');
INSERT INTO public.exhibitors VALUES ('a540b227-c04f-4e0c-b04b-37247bb4f170', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'RoofRight', 'C10', '82811d22-9d92-49a4-ab00-d29b72a4f380', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', '2026-10-20 16:32:32.42473+00', '2026-10-20 16:32:32.42473+00');
INSERT INTO public.exhibitors VALUES ('1692a635-0f59-45a8-a277-6d10d283db96', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'PlantHire Direct', 'C20', '82811d22-9d92-49a4-ab00-d29b72a4f380', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'ed87df9d-8261-4091-b411-b195e264c72c', '2026-10-20 16:32:32.42681+00', '2026-10-20 16:32:32.42681+00');
INSERT INTO public.exhibitors VALUES ('1d8689e2-928c-4e41-85c6-c257c0a93b23', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SafetyFirst PPE', 'D10', '82811d22-9d92-49a4-ab00-d29b72a4f380', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-20 16:32:32.428917+00', '2026-10-20 16:32:32.428917+00');
INSERT INTO public.exhibitors VALUES ('086e57f9-3ec5-4c68-bae8-4865157a5cff', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'ToolMart Retail', 'D20', '82811d22-9d92-49a4-ab00-d29b72a4f380', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-20 16:32:32.431014+00', '2026-10-20 16:32:32.431014+00');
INSERT INTO public.exhibitors VALUES ('8c8cf43f-7ada-4ab8-9279-fa45d34621c3', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'EcoBuild Materials', 'D30', '82811d22-9d92-49a4-ab00-d29b72a4f380', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-20 16:32:32.433391+00', '2026-10-20 16:32:32.433391+00');
INSERT INTO public.exhibitors VALUES ('2af645cf-c7a7-4c57-82d0-2a3eb83f5e04', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SiteWise Software', 'D40', '82811d22-9d92-49a4-ab00-d29b72a4f380', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-20 16:32:32.43614+00', '2026-10-20 16:32:32.43614+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('6348034e-2287-4ec3-8d51-f5c1e919e506', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'venue', 'venue', '84f219e1-682e-4bb2-82fb-78e7f34d082a', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.391085+00', '2026-10-20 16:32:32.391085+00');
INSERT INTO public.external_grants VALUES ('3c13e379-52ad-45a0-8596-2637fd38a5c3', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.395553+00', '2026-10-20 16:32:32.395553+00');
INSERT INTO public.external_grants VALUES ('71282251-5fd7-46dc-8b75-c8cdb9dfa944', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.399297+00', '2026-10-20 16:32:32.399297+00');
INSERT INTO public.external_grants VALUES ('c2d216eb-a77e-4181-a927-eb6db365fa94', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'supplier', 'supplier', 'ec1ee301-104e-489f-85bb-278da6111413', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.403183+00', '2026-10-20 16:32:32.403183+00');
INSERT INTO public.external_grants VALUES ('e689d983-a221-4170-b7c9-d839aa02db15', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'sponsor', 'sponsor', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.40683+00', '2026-10-20 16:32:32.40683+00');
INSERT INTO public.external_grants VALUES ('befe5a7b-8917-4ac8-b357-9d2a6d89e1fd', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'exhibitor', 'exhibitor', 'd62bd66d-c700-4d20-8a60-404d92d4e84d', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-20 16:32:32.003+00', NULL, '2026-10-20 16:32:32.439681+00', '2026-10-20 16:32:32.439681+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('793c79b2-47aa-48c7-bd26-99ebafb48053', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-20 16:32:32.101748+00', '2026-10-20 16:32:32.101748+00');
INSERT INTO public.halls VALUES ('82811d22-9d92-49a4-ab00-d29b72a4f380', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-20 16:32:32.105036+00', '2026-10-20 16:32:32.105036+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('7fadf965-533b-4621-834c-cf4a69e27388', '617224a2-546d-4403-8443-4750f2372e7c', 'Hanging banner', 'hanging_banner', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'rigged', true, 0, '2026-10-20 16:32:32.357218+00', '2026-10-20 16:32:32.357218+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a0fb328d-902b-4eed-a4a0-443aca9cd223', '617224a2-546d-4403-8443-4750f2372e7c', 'Foamex board', 'foamex_board', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'wall_mounted', false, 1, '2026-10-20 16:32:32.359963+00', '2026-10-20 16:32:32.359963+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3945b6ca-f4b4-4d28-bc7e-641728fea434', '617224a2-546d-4403-8443-4750f2372e7c', 'Fabric graphic', 'fabric_graphic', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'shell_mounted', false, 2, '2026-10-20 16:32:32.36172+00', '2026-10-20 16:32:32.36172+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('2a81893b-46c7-47a4-bbbb-e6cc5ba22219', '617224a2-546d-4403-8443-4750f2372e7c', 'Floor vinyl', 'floor_vinyl', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'floor', false, 3, '2026-10-20 16:32:32.363746+00', '2026-10-20 16:32:32.363746+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('863f3fa4-4e43-4356-9c23-bdd69b5a738d', '617224a2-546d-4403-8443-4750f2372e7c', 'Aisle sign', 'aisle_sign', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'rigged', true, 4, '2026-10-20 16:32:32.365733+00', '2026-10-20 16:32:32.365733+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('098c8d2c-656c-40a8-90b9-ceae9968d266', '617224a2-546d-4403-8443-4750f2372e7c', 'Entrance feature', 'entrance_feature', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'freestanding', true, 5, '2026-10-20 16:32:32.367895+00', '2026-10-20 16:32:32.367895+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('20d13238-4534-461b-bdfa-077476b0f4ab', '617224a2-546d-4403-8443-4750f2372e7c', 'Registration', 'registration', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'freestanding', false, 6, '2026-10-20 16:32:32.369569+00', '2026-10-20 16:32:32.369569+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('aa9ebd98-c6a6-4c99-b0f0-47204f3c113d', '617224a2-546d-4403-8443-4750f2372e7c', 'Seminar theatre', 'seminar_theatre', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'freestanding', false, 7, '2026-10-20 16:32:32.371422+00', '2026-10-20 16:32:32.371422+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('fc0ed635-5c80-4227-b701-fdd304184d11', '617224a2-546d-4403-8443-4750f2372e7c', 'Feature area', 'feature_area', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'freestanding', false, 8, '2026-10-20 16:32:32.373047+00', '2026-10-20 16:32:32.373047+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('32dc9484-1705-4d6a-a0cb-f8293f4982bc', '617224a2-546d-4403-8443-4750f2372e7c', 'External', 'external', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'freestanding', true, 9, '2026-10-20 16:32:32.374653+00', '2026-10-20 16:32:32.374653+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('1ab89940-9084-4c52-b603-28c3ef139ad9', '617224a2-546d-4403-8443-4750f2372e7c', 'Digital screen', 'digital_screen', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 'digital', false, 10, '2026-10-20 16:32:32.37646+00', '2026-10-20 16:32:32.37646+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('02984291-b700-461a-8abb-4c8b23818ddd', '617224a2-546d-4403-8443-4750f2372e7c', 'Branded lanyards', 'lanyard', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', NULL, false, 11, '2026-10-20 16:32:32.378181+00', '2026-10-20 16:32:32.378181+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('b4a48479-92e9-48cc-aaed-e95ceb309a33', '617224a2-546d-4403-8443-4750f2372e7c', 'Show bags', 'show_bag', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', NULL, false, 12, '2026-10-20 16:32:32.381666+00', '2026-10-20 16:32:32.381666+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('457b0350-fc19-493a-989c-75ff3c88353e', '617224a2-546d-4403-8443-4750f2372e7c', 'Registration branding', 'reg_branding', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', NULL, false, 13, '2026-10-20 16:32:32.383201+00', '2026-10-20 16:32:32.383201+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('59e0f052-5c3d-470b-b812-24d78b734bed', '617224a2-546d-4403-8443-4750f2372e7c', 'Other signage', 'other_signage', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', NULL, false, 14, '2026-10-20 16:32:32.384512+00', '2026-10-20 16:32:32.384512+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('630e614d-3360-44d9-99da-565976dca8c9', '617224a2-546d-4403-8443-4750f2372e7c', 'Other sponsorship item', 'other_sponsorship', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', NULL, false, 15, '2026-10-20 16:32:32.386216+00', '2026-10-20 16:32:32.386216+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('d4520d02-db29-4260-a0f3-ebd51930b5ed', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-20 16:32:32.107884+00', '2026-10-20 16:32:32.107884+00');
INSERT INTO public.locations VALUES ('0a8bf507-9725-4b24-845f-01e887a42139', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-20 16:32:32.110565+00', '2026-10-20 16:32:32.110565+00');
INSERT INTO public.locations VALUES ('9068bec0-f7a0-4a64-ad93-dd6157b40030', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-20 16:32:32.11631+00', '2026-10-20 16:32:32.11631+00');
INSERT INTO public.locations VALUES ('70cac651-ca61-4645-81ce-b8b01c66f927', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-20 16:32:32.119017+00', '2026-10-20 16:32:32.119017+00');
INSERT INTO public.locations VALUES ('b18a0225-a4d0-44a4-ab51-9412d01a3381', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-20 16:32:32.12135+00', '2026-10-20 16:32:32.12135+00');
INSERT INTO public.locations VALUES ('079d1875-bae5-4c94-943d-f8168db4b7e5', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-20 16:32:32.123724+00', '2026-10-20 16:32:32.123724+00');
INSERT INTO public.locations VALUES ('ef1dc401-2abf-40d6-b49a-1d09a5dd1a0f', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-20 16:32:32.126183+00', '2026-10-20 16:32:32.126183+00');
INSERT INTO public.locations VALUES ('4ff1e547-0c92-4ca9-94f4-cfd42b8e42aa', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-20 16:32:32.128144+00', '2026-10-20 16:32:32.128144+00');
INSERT INTO public.locations VALUES ('2af63bb4-ed4c-4f63-8cce-0d18f9d1b5e0', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-20 16:32:32.130119+00', '2026-10-20 16:32:32.130119+00');
INSERT INTO public.locations VALUES ('77ee8dff-27f3-4340-858a-f347fd351c17', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-20 16:32:32.132362+00', '2026-10-20 16:32:32.132362+00');
INSERT INTO public.locations VALUES ('a2ee5b73-513a-46c6-b785-ccc35b29d208', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-20 16:32:32.134449+00', '2026-10-20 16:32:32.134449+00');
INSERT INTO public.locations VALUES ('37f1021b-b652-4526-800b-0299a824b42d', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-20 16:32:32.137218+00', '2026-10-20 16:32:32.137218+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('dc6d7259-f577-46d5-8e34-137e8afe0348', '00000000-0000-4000-8000-000000000001', '617224a2-546d-4403-8443-4750f2372e7c', 'admin', '2026-10-20 16:32:32.041582+00', '2026-10-20 16:32:32.041582+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('cf2175ed-0eff-40f8-ba48-78d35903564d', '00000000-0000-4000-8000-000000000006', '617224a2-546d-4403-8443-4750f2372e7c', 'viewer', '2026-10-20 16:32:32.058915+00', '2026-10-20 16:32:32.058915+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('496ae6eb-43f1-437f-a60c-9ddfeed4a45a', '00000000-0000-4000-8000-000000000002', '617224a2-546d-4403-8443-4750f2372e7c', 'ops', '2026-10-20 16:32:32.046085+00', '2026-10-20 16:32:32.297023+00', '{}', '8944f948-1b60-46a1-a2b8-991731ba53ca', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('14091d51-7dc8-445c-8e3e-18678483f064', '00000000-0000-4000-8000-000000000004', '617224a2-546d-4403-8443-4750f2372e7c', 'sales', '2026-10-20 16:32:32.052297+00', '2026-10-20 16:32:32.31084+00', '{}', 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('cbf04c0e-31e0-4b44-93ad-3b576a3bf207', '00000000-0000-4000-8000-000000000005', '617224a2-546d-4403-8443-4750f2372e7c', 'event_director', '2026-10-20 16:32:32.055465+00', '2026-10-20 16:32:32.317558+00', '{}', '84196ff9-50de-43c9-bd8c-f0ed23741ba8', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('cf56f75a-c3fa-48c2-a37b-9421c7f1413e', '00000000-0000-4000-8000-000000000003', '617224a2-546d-4403-8443-4750f2372e7c', 'marketing', '2026-10-20 16:32:32.048716+00', '2026-10-20 16:32:33.131479+00', '{"costs.edit": true}', '9d8434b4-4283-44d0-8919-2bc44356f2af', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('617224a2-546d-4403-8443-4750f2372e7c', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-20 16:32:32.035716+00', '2026-10-20 16:32:32.035716+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('638eaf42-56f6-4c95-ae6b-661ae29a5d56', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '098c8d2c-656c-40a8-90b9-ceae9968d266', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'd4520d02-db29-4260-a0f3-ebd51930b5ed', 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', '9c5dd1d6-df0d-4465-a1d4-be3d8bbe7eb9', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'a61b80d8-3d37-4b2d-b7df-754c635b3493', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.44439+00', '2026-10-20 16:32:32.450827+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e9ca8e31-b3b7-45e7-8897-4f1d3df8b20e', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '20d13238-4534-461b-bdfa-077476b0f4ab', '793c79b2-47aa-48c7-bd26-99ebafb48053', '0a8bf507-9725-4b24-845f-01e887a42139', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'd01f27af-3883-4dfc-9e68-247d10a6be36', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.470756+00', '2026-10-20 16:32:32.474556+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5610639c-0f53-4f84-991c-6a84f29d6e80', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '7fadf965-533b-4621-834c-cf4a69e27388', '793c79b2-47aa-48c7-bd26-99ebafb48053', '9068bec0-f7a0-4a64-ad93-dd6157b40030', 'ops', '00000000-0000-4000-8000-000000000002', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', '272f0680-c383-4946-83ef-50f93c7ad7f4', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'c3df84d8-067a-4f4a-adcf-44d192dc09e8', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.491271+00', '2026-10-20 16:32:32.496881+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8a5f7fde-1794-4e67-a86c-daa98fa2e4d5', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'aa9ebd98-c6a6-4c99-b0f0-47204f3c113d', '793c79b2-47aa-48c7-bd26-99ebafb48053', '70cac651-ca61-4645-81ce-b8b01c66f927', 'marketing', '00000000-0000-4000-8000-000000000003', '22bc90f5-619b-4205-b329-9221aeee466d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '03adadf9-791c-4c2a-bb5e-c7441cd13b1f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.531609+00', '2026-10-20 16:32:32.536328+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0b1c405d-1415-4a95-9c53-6077ab65bfa6', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '2a81893b-46c7-47a4-bbbb-e6cc5ba22219', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'b18a0225-a4d0-44a4-ab51-9412d01a3381', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '1cae02d9-ebfc-4597-9025-294b51ad66bc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.55966+00', '2026-10-20 16:32:32.564973+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4586623c-8f9e-43da-ad1a-2c738aaecc18', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', 'fc0ed635-5c80-4227-b701-fdd304184d11', '793c79b2-47aa-48c7-bd26-99ebafb48053', '079d1875-bae5-4c94-943d-f8168db4b7e5', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '47686cd3-6739-417c-b9d0-1984c3d77cce', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.585785+00', '2026-10-20 16:32:32.590245+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "c86733fc-bbd4-49cd-bfa2-652e152d55e0", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c4798d9f-e4da-4038-b3cd-369787efe22d', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '7fadf965-533b-4621-834c-cf4a69e27388', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'ef1dc401-2abf-40d6-b49a-1d09a5dd1a0f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'e3fb22ff-db2e-4c95-ba7e-6abd17c206bc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.608977+00', '2026-10-20 16:32:32.612241+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2bcecfdf-6e36-4ef1-a3fa-2263bef1eee1', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '863f3fa4-4e43-4356-9c23-bdd69b5a738d', '82811d22-9d92-49a4-ab00-d29b72a4f380', '4ff1e547-0c92-4ca9-94f4-cfd42b8e42aa', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '36dc3098-7f06-4c06-bd4d-31e101e89089', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.628529+00', '2026-10-20 16:32:32.633257+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5a4f0769-e0fc-42e0-94a1-4e0cf39f2c62', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'aa9ebd98-c6a6-4c99-b0f0-47204f3c113d', '82811d22-9d92-49a4-ab00-d29b72a4f380', '2af63bb4-ed4c-4f63-8cce-0d18f9d1b5e0', 'marketing', '00000000-0000-4000-8000-000000000003', '22bc90f5-619b-4205-b329-9221aeee466d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'd880df72-632f-4d94-a1a3-9abc0be451f1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.64828+00', '2026-10-20 16:32:32.651385+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a283b442-d33c-4f7f-b330-67aed9301be7', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '3945b6ca-f4b4-4d28-bc7e-641728fea434', '82811d22-9d92-49a4-ab00-d29b72a4f380', '77ee8dff-27f3-4340-858a-f347fd351c17', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'b8e2164a-be35-443e-bbd6-0164ff81330b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.667792+00', '2026-10-20 16:32:32.67367+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL);
INSERT INTO public.signage_items VALUES ('b0120a19-312b-4173-b7d9-2655c29c74f2', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '32dc9484-1705-4d6a-a0cb-f8293f4982bc', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'a2ee5b73-513a-46c6-b785-ccc35b29d208', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'c080d71d-c679-475e-9eaf-e510f86878d6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.687302+00', '2026-10-20 16:32:32.69346+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', NULL);
INSERT INTO public.signage_items VALUES ('16b466b4-e59c-4e5c-b3b7-eb7c11edebbb', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '82811d22-9d92-49a4-ab00-d29b72a4f380', '37f1021b-b652-4526-800b-0299a824b42d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '11ee6e4d-8b31-45e5-9c8b-cdd42fe37781', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.708783+00', '2026-10-20 16:32:32.714101+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-17 16:32:32.003+00');
INSERT INTO public.signage_items VALUES ('c17f9899-b12d-47ac-8e1b-722fef1e3f98', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '630e614d-3360-44d9-99da-565976dca8c9', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:33.00321+00', '2026-10-20 16:32:33.00321+00', 'sponsorship_item', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', '2026-11-07', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b13f5e9c-8ab2-4f2a-b74d-92d3b9800c34', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '793c79b2-47aa-48c7-bd26-99ebafb48053', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, 'beffbbfc-45cb-4878-aae7-33787be01fc9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:33.050533+00', '2026-10-20 16:32:33.050533+00', 'stand_design', 'organiser', '[{"stepId": "33301c70-9195-411a-b2dc-449716be5e83", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "65fe0910-9bbb-483b-abff-949c36ca15f3", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1641dc19-aba1-47b4-a778-e35af4c8b68f', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '1ab89940-9084-4c52-b603-28c3ef139ad9', '793c79b2-47aa-48c7-bd26-99ebafb48053', '0a8bf507-9725-4b24-845f-01e887a42139', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '8819f0dd-5863-41c9-a599-5ae06b51f78c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'e3c9a2a6-547a-4010-84b8-f194ddb3bcff', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.728837+00', '2026-10-20 16:32:32.733845+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "c86733fc-bbd4-49cd-bfa2-652e152d55e0", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-17 16:32:32.003+00');
INSERT INTO public.signage_items VALUES ('a0e51c28-f4a9-41e6-bc4a-227a560f49c6', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '863f3fa4-4e43-4356-9c23-bdd69b5a738d', '793c79b2-47aa-48c7-bd26-99ebafb48053', '9068bec0-f7a0-4a64-ad93-dd6157b40030', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'f6ca2f9c-7950-4af8-b29e-f8b9645f0e77', '2026-10-17 16:32:32.003+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.748516+00', '2026-10-20 16:32:32.754378+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-17 16:32:32.003+00');
INSERT INTO public.signage_items VALUES ('eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'b18a0225-a4d0-44a4-ab51-9412d01a3381', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'e98c86f6-04cb-4369-8c37-ae0484abafeb', '2026-10-17 16:32:32.003+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.776489+00', '2026-10-20 16:32:32.781498+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-17 16:32:32.003+00');
INSERT INTO public.signage_items VALUES ('ce0ab44a-18f5-4429-b5f0-5f478788f7ee', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', 'fc0ed635-5c80-4227-b701-fdd304184d11', '793c79b2-47aa-48c7-bd26-99ebafb48053', '079d1875-bae5-4c94-943d-f8168db4b7e5', 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '8166ecd6-0b0d-4791-8c67-6fcefe4ac3d2', '2026-10-17 16:32:32.003+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.806633+00', '2026-10-20 16:32:32.812459+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, '2026-10-17 16:32:32.003+00', '2026-10-17 16:32:32.003+00');
INSERT INTO public.signage_items VALUES ('2b2117a0-715b-418f-8439-906703a149d4', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '7fadf965-533b-4621-834c-cf4a69e27388', '82811d22-9d92-49a4-ab00-d29b72a4f380', '4ff1e547-0c92-4ca9-94f4-cfd42b8e42aa', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'eeaa310c-a099-4812-8a93-7ad395b3a789', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.831234+00', '2026-10-20 16:32:32.835657+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('593641fa-83a7-49b5-9f28-e0e12c29aef7', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '3945b6ca-f4b4-4d28-bc7e-641728fea434', '82811d22-9d92-49a4-ab00-d29b72a4f380', '77ee8dff-27f3-4340-858a-f347fd351c17', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '693f73de-444b-418b-8dd1-9303ba563bbe', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.854244+00', '2026-10-20 16:32:32.858086+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('feb6de4e-7590-4753-9d46-54346952020f', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '7fadf965-533b-4621-834c-cf4a69e27388', '793c79b2-47aa-48c7-bd26-99ebafb48053', '9068bec0-f7a0-4a64-ad93-dd6157b40030', 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', '272f0680-c383-4946-83ef-50f93c7ad7f4', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '17929d3f-b4b9-4f77-8ec0-a0597d542dad', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.874836+00', '2026-10-20 16:32:32.881644+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('39fcb6f6-9187-45c2-aafe-d854da7cc1b3', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '82811d22-9d92-49a4-ab00-d29b72a4f380', '37f1021b-b652-4526-800b-0299a824b42d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.902519+00', '2026-10-20 16:32:32.902519+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d1d1b24a-20cf-44ee-8a2f-54e78157dec6', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '793c79b2-47aa-48c7-bd26-99ebafb48053', '0a8bf507-9725-4b24-845f-01e887a42139', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.906581+00', '2026-10-20 16:32:32.906581+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8df5f502-0d3c-45f7-8bd4-88e74cd467f9', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '20d13238-4534-461b-bdfa-077476b0f4ab', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'ef1dc401-2abf-40d6-b49a-1d09a5dd1a0f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.912596+00', '2026-10-20 16:32:32.912596+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e7e71c84-464c-47b6-b818-46684c2da7a2', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '1ab89940-9084-4c52-b603-28c3ef139ad9', '793c79b2-47aa-48c7-bd26-99ebafb48053', '079d1875-bae5-4c94-943d-f8168db4b7e5', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '8819f0dd-5863-41c9-a599-5ae06b51f78c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.915967+00', '2026-10-20 16:32:32.915967+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "c86733fc-bbd4-49cd-bfa2-652e152d55e0", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4fdb45fa-8450-4689-93ef-d855436c0895', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '2a81893b-46c7-47a4-bbbb-e6cc5ba22219', '82811d22-9d92-49a4-ab00-d29b72a4f380', '2af63bb4-ed4c-4f63-8cce-0d18f9d1b5e0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.920908+00', '2026-10-20 16:32:32.920908+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2a9fdec6-3659-4c30-a875-4e0d3e65550c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'aa9ebd98-c6a6-4c99-b0f0-47204f3c113d', '82811d22-9d92-49a4-ab00-d29b72a4f380', '2af63bb4-ed4c-4f63-8cce-0d18f9d1b5e0', 'marketing', '00000000-0000-4000-8000-000000000003', '22bc90f5-619b-4205-b329-9221aeee466d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.92504+00', '2026-10-20 16:32:32.92504+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e85ac8cd-be78-43c7-aa9a-4137deb3a31a', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '32dc9484-1705-4d6a-a0cb-f8293f4982bc', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'a2ee5b73-513a-46c6-b785-ccc35b29d208', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.929318+00', '2026-10-20 16:32:32.929318+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "c86733fc-bbd4-49cd-bfa2-652e152d55e0", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('39507726-f7bc-4dc0-9649-b24355df3d8c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '82811d22-9d92-49a4-ab00-d29b72a4f380', 'a2ee5b73-513a-46c6-b785-ccc35b29d208', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.933221+00', '2026-10-20 16:32:32.933221+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('da05cd6a-c162-433f-b8f0-e33a05e9cae4', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'b18a0225-a4d0-44a4-ab51-9412d01a3381', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 'b80596ad-6186-4bbc-b182-df9db5b8c760', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.937267+00', '2026-10-20 16:32:32.941108+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bf7c0415-aacb-4363-81e0-3d382c1ea7bd', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '098c8d2c-656c-40a8-90b9-ceae9968d266', '793c79b2-47aa-48c7-bd26-99ebafb48053', 'd4520d02-db29-4260-a0f3-ebd51930b5ed', 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', '9c5dd1d6-df0d-4465-a1d4-be3d8bbe7eb9', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '7f41c837-7a12-4e93-beb6-46666b769fcb', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.957269+00', '2026-10-20 16:32:32.960517+00', 'signage', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', NULL, NULL, NULL, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('fbf38964-0817-4a0a-a774-bfbb316322da', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'a0fb328d-902b-4eed-a4a0-443aca9cd223', '82811d22-9d92-49a4-ab00-d29b72a4f380', '37f1021b-b652-4526-800b-0299a824b42d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.975638+00', '2026-10-20 16:32:32.975638+00', 'signage', 'organiser', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f6dec329-eda3-4f9b-945c-991e2294fa98', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '02984291-b700-461a-8abb-4c8b23818ddd', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, '55240299-e02c-402c-a705-14491b42cabe', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.980199+00', '2026-10-20 16:32:32.983951+00', 'sponsorship_item', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', '2027-01-03', NULL, 9000.00, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('536a2246-f4e5-41fb-882c-f6cf3bd2b97a', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'b4a48479-92e9-48cc-aaed-e95ceb309a33', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.995861+00', '2026-10-20 16:32:32.995861+00', 'sponsorship_item', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}, {"stepId": "223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2", "userId": null}]', '2026-11-09', NULL, 12500.00, '2026-10-10 16:32:32.003+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9cba1d41-3df1-4964-b814-46887159dbc4', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '457b0350-fc19-493a-989c-75ff3c88353e', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-20 16:32:32.999426+00', '2026-10-20 16:32:32.999426+00', 'sponsorship_item', 'sponsor', '[{"stepId": "129dce63-a304-4c6a-831a-7e8bf8882d75", "userId": null}, {"stepId": "5797db91-099d-4f89-8808-31d79ec689c9", "userId": null}]', '2027-02-17', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('a9128a38-b947-4a00-983a-bb7c76abe6a0', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'eeb14496-2a2a-4c2f-8218-7f27c6e0a8fc', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'ec1ee301-104e-489f-85bb-278da6111413', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-20 16:32:32.800971+00', '2026-10-20 16:32:32.800971+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('272f0680-c383-4946-83ef-50f93c7ad7f4', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', 'Logo on 6 hanging banners', 6, '2026-10-20 16:32:32.180642+00', '2026-10-20 16:32:32.190515+00', '60d312e8-1686-41cc-9951-8fc39a8fffdb');
INSERT INTO public.sponsor_entitlements VALUES ('9c5dd1d6-df0d-4465-a1d4-be3d8bbe7eb9', 'b7f9884b-8f6a-4d1c-9fc0-22243145c692', 'Entrance feature branding', 1, '2026-10-20 16:32:32.183162+00', '2026-10-20 16:32:32.190515+00', '60d312e8-1686-41cc-9951-8fc39a8fffdb');
INSERT INTO public.sponsor_entitlements VALUES ('285672b0-35bb-4e12-ac98-32332ab77977', '22bc90f5-619b-4205-b329-9221aeee466d', 'Seminar theatre branding', 1, '2026-10-20 16:32:32.188935+00', '2026-10-20 16:32:32.240236+00', '04439ea3-50e4-49eb-872a-2fa896cecb64');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('b7f9884b-8f6a-4d1c-9fc0-22243145c692', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-20 16:32:32.177031+00', '2026-10-20 16:32:32.190515+00', '60d312e8-1686-41cc-9951-8fc39a8fffdb', 22500.00, 'Early-booking discount', '2026-10-10 16:32:32.003+00');
INSERT INTO public.sponsors VALUES ('22bc90f5-619b-4205-b329-9221aeee466d', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-20 16:32:32.186099+00', '2026-10-20 16:32:32.240236+00', '04439ea3-50e4-49eb-872a-2fa896cecb64', 8000.00, NULL, '2026-10-10 16:32:32.003+00');


--
-- Data for Name: sponsorship_package_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_package_lines VALUES ('89fff799-554a-467f-94f8-496aea63b1fa', '60d312e8-1686-41cc-9951-8fc39a8fffdb', 'Logo on 6 hanging banners', 6, 1, '2026-10-20 16:32:32.190515+00', '2026-10-20 16:32:32.190515+00');
INSERT INTO public.sponsorship_package_lines VALUES ('0bb0399b-6c17-4985-b38f-594639841122', '60d312e8-1686-41cc-9951-8fc39a8fffdb', 'Entrance feature branding', 1, 2, '2026-10-20 16:32:32.190515+00', '2026-10-20 16:32:32.190515+00');
INSERT INTO public.sponsorship_package_lines VALUES ('a04657b7-10af-4f7f-ac99-a72f5aca952d', '04439ea3-50e4-49eb-872a-2fa896cecb64', 'Seminar theatre branding', 1, 1, '2026-10-20 16:32:32.240236+00', '2026-10-20 16:32:32.240236+00');
INSERT INTO public.sponsorship_package_lines VALUES ('a925dc27-8a0e-484f-8ce9-1219ce625cf1', '35967320-c6c3-4e7e-8064-589db67fe688', 'Feature area banners', 2, 1, '2026-10-20 16:32:32.257906+00', '2026-10-20 16:32:32.257906+00');
INSERT INTO public.sponsorship_package_lines VALUES ('dd1614b2-bf86-417f-a890-45f96ff66560', '35967320-c6c3-4e7e-8064-589db67fe688', 'Logo in the event guide', 1, 2, '2026-10-20 16:32:32.257906+00', '2026-10-20 16:32:32.257906+00');


--
-- Data for Name: sponsorship_packages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_packages VALUES ('60d312e8-1686-41cc-9951-8fc39a8fffdb', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Headline sponsor', 'Top billing across the venue', 25000.00, 1, 1, false, '2026-10-20 16:32:32.190515+00', '2026-10-20 16:32:32.190515+00');
INSERT INTO public.sponsorship_packages VALUES ('04439ea3-50e4-49eb-872a-2fa896cecb64', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Seminar theatre sponsor', 'Branding in the seminar theatre', 8000.00, 2, 2, false, '2026-10-20 16:32:32.240236+00', '2026-10-20 16:32:32.240236+00');
INSERT INTO public.sponsorship_packages VALUES ('35967320-c6c3-4e7e-8064-589db67fe688', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Feature area sponsor', 'Branding around the feature area', 12000.00, 3, 3, false, '2026-10-20 16:32:32.257906+00', '2026-10-20 16:32:32.257906+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('cb7b6bd9-a211-4d18-89ff-170c70633ccc', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'd62bd66d-c700-4d20-8a60-404d92d4e84d', 'STD-BIRM27-A10', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 16:32:32.003+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.054393+00', '2026-10-20 16:32:33.054393+00');
INSERT INTO public.stand_submissions VALUES ('4f50009d-cf62-4c11-9b40-8536adc2dfcf', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'c4862222-12b8-4a5f-839a-f26d3d44c9ae', 'STD-BIRM27-A20', 'ed87df9d-8261-4091-b411-b195e264c72c', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-14 16:32:32.003+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.071902+00', '2026-10-20 16:32:33.071902+00');
INSERT INTO public.stand_submissions VALUES ('27330cd6-8c39-4031-b784-34007054cffb', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '29859da7-1719-4ab0-b58f-0fbd42164c37', 'STD-BIRM27-A30', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-14 16:32:32.003+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.082805+00', '2026-10-20 16:32:33.082805+00');
INSERT INTO public.stand_submissions VALUES ('e90f86cf-52be-4bd7-aacf-6e4aba73a134', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '7d04072e-8bcd-452f-863c-38f4c1be8e70', 'STD-BIRM27-B10', 'ed87df9d-8261-4091-b411-b195e264c72c', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-14 16:32:32.003+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.094722+00', '2026-10-20 16:32:33.094722+00');
INSERT INTO public.stand_submissions VALUES ('b540165e-12a6-4f3b-89cf-4f6f454c24b3', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '6b9a23f5-da92-4b0b-9dfd-cf929df1bb04', 'STD-BIRM27-B20', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-14 16:32:32.003+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.107243+00', '2026-10-20 16:32:33.107243+00');
INSERT INTO public.stand_submissions VALUES ('c564654b-4536-486e-84b5-b1da484e7cac', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '537e91f7-8862-40f8-af51-2daf7f9360e0', 'STD-BIRM27-B30', 'ed87df9d-8261-4091-b411-b195e264c72c', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.121333+00', '2026-10-20 16:32:33.121333+00');
INSERT INTO public.stand_submissions VALUES ('fc29265b-10a0-4611-9f6f-da1b4686266a', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'a540b227-c04f-4e0c-b04b-37247bb4f170', 'STD-BIRM27-C10', '3bc432c6-4ea3-4dcb-aed0-a421a89b2f67', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.124958+00', '2026-10-20 16:32:33.124958+00');
INSERT INTO public.stand_submissions VALUES ('5fd2b7ac-371b-4314-b627-9940266bd185', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', '1692a635-0f59-45a8-a277-6d10d283db96', 'STD-BIRM27-C20', 'ed87df9d-8261-4091-b411-b195e264c72c', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '681e0493-3492-48b4-8850-eea31e531ea7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-20 16:32:33.128543+00', '2026-10-20 16:32:33.128543+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('ec1ee301-104e-489f-85bb-278da6111413', '81c2fd2f-69a3-44a8-9de1-d0f18586c239');
INSERT INTO public.supplier_service_links VALUES ('ec1ee301-104e-489f-85bb-278da6111413', '99862c04-17d8-46a0-a4ad-a753cf2332af');
INSERT INTO public.supplier_service_links VALUES ('587d9268-f43b-4b20-b5bc-b031e72db30c', '0790ba6d-a924-44c6-a34a-127557926110');
INSERT INTO public.supplier_service_links VALUES ('587d9268-f43b-4b20-b5bc-b031e72db30c', '99862c04-17d8-46a0-a4ad-a753cf2332af');
INSERT INTO public.supplier_service_links VALUES ('587d9268-f43b-4b20-b5bc-b031e72db30c', '79e82f2f-2db9-4c64-93ad-666be6a100cc');
INSERT INTO public.supplier_service_links VALUES ('8819f0dd-5863-41c9-a599-5ae06b51f78c', 'f75081fa-adbd-4283-b4c2-60316f8a5d09');
INSERT INTO public.supplier_service_links VALUES ('8819f0dd-5863-41c9-a599-5ae06b51f78c', '79e82f2f-2db9-4c64-93ad-666be6a100cc');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('81c2fd2f-69a3-44a8-9de1-d0f18586c239', '617224a2-546d-4403-8443-4750f2372e7c', 'Signage print', 1, false, '2026-10-20 16:32:32.14717+00', '2026-10-20 16:32:32.14717+00');
INSERT INTO public.supplier_services VALUES ('f75081fa-adbd-4283-b4c2-60316f8a5d09', '617224a2-546d-4403-8443-4750f2372e7c', 'Digital screens & AV', 2, false, '2026-10-20 16:32:32.149193+00', '2026-10-20 16:32:32.149193+00');
INSERT INTO public.supplier_services VALUES ('0790ba6d-a924-44c6-a34a-127557926110', '617224a2-546d-4403-8443-4750f2372e7c', 'Rigging', 3, false, '2026-10-20 16:32:32.150792+00', '2026-10-20 16:32:32.150792+00');
INSERT INTO public.supplier_services VALUES ('99862c04-17d8-46a0-a4ad-a753cf2332af', '617224a2-546d-4403-8443-4750f2372e7c', 'Installation', 4, false, '2026-10-20 16:32:32.152274+00', '2026-10-20 16:32:32.152274+00');
INSERT INTO public.supplier_services VALUES ('79e82f2f-2db9-4c64-93ad-666be6a100cc', '617224a2-546d-4403-8443-4750f2372e7c', 'Staffing', 5, false, '2026-10-20 16:32:32.153753+00', '2026-10-20 16:32:32.153753+00');
INSERT INTO public.supplier_services VALUES ('f9455461-9575-42f0-b3e9-a1ca25a154f2', '617224a2-546d-4403-8443-4750f2372e7c', 'Furniture', 6, false, '2026-10-20 16:32:32.154931+00', '2026-10-20 16:32:32.154931+00');
INSERT INTO public.supplier_services VALUES ('c9602130-9cf5-4d03-a0d2-bf3204ff1b7a', '617224a2-546d-4403-8443-4750f2372e7c', 'Structural engineering', 7, false, '2026-10-20 16:32:32.156112+00', '2026-10-20 16:32:32.156112+00');
INSERT INTO public.supplier_services VALUES ('8f9f149f-7329-45a9-9830-f41dce6fcd1e', '617224a2-546d-4403-8443-4750f2372e7c', 'Floor Manager', 8, false, '2026-10-20 16:32:32.15721+00', '2026-10-20 16:32:32.15721+00');
INSERT INTO public.supplier_services VALUES ('26c30bf2-422b-4426-b4e2-b0ec5f155618', '617224a2-546d-4403-8443-4750f2372e7c', 'Security', 9, false, '2026-10-20 16:32:32.159218+00', '2026-10-20 16:32:32.159218+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('ec1ee301-104e-489f-85bb-278da6111413', '617224a2-546d-4403-8443-4750f2372e7c', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-20 16:32:32.139549+00', '2026-10-20 16:32:32.139549+00', false);
INSERT INTO public.suppliers VALUES ('587d9268-f43b-4b20-b5bc-b031e72db30c', '617224a2-546d-4403-8443-4750f2372e7c', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-20 16:32:32.142574+00', '2026-10-20 16:32:32.142574+00', false);
INSERT INTO public.suppliers VALUES ('8819f0dd-5863-41c9-a599-5ae06b51f78c', '617224a2-546d-4403-8443-4750f2372e7c', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-20 16:32:32.145583+00', '2026-10-20 16:32:32.145583+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('9efa8278-666f-45f9-b2c6-4b708037932a', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-27', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '638eaf42-56f6-4c95-ae6b-661ae29a5d56', NULL, '2026-10-20 16:32:33.136363+00', '2026-10-20 16:32:33.136363+00', NULL);
INSERT INTO public.tasks VALUES ('1d8c0cbe-a1c4-480a-990b-7816bb9eaa80', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-30', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 16:32:33.138687+00', '2026-10-20 16:32:33.138687+00', NULL);
INSERT INTO public.tasks VALUES ('1e77ccc8-0ad5-4619-9d15-f65d680710b2', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Walk the hall with the venue', NULL, 'done', '2026-10-15', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-20 16:32:32.003+00', '2026-10-20 16:32:33.14021+00', '2026-10-20 16:32:33.14021+00', '1d8c0cbe-a1c4-480a-990b-7816bb9eaa80');
INSERT INTO public.tasks VALUES ('31ee45dc-f752-418b-972e-6029a2b0958a', '617224a2-546d-4403-8443-4750f2372e7c', 'ddebd9a3-26a9-429f-8bcb-94aeb9c2abab', 'Send sign positions to the printer', NULL, 'open', '2026-10-19', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-20 16:32:33.14021+00', '2026-10-20 16:32:33.14021+00', '1d8c0cbe-a1c4-480a-990b-7816bb9eaa80');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.039381+00', '2026-10-20 16:32:32.039381+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.044693+00', '2026-10-20 16:32:32.044693+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.047528+00', '2026-10-20 16:32:32.047528+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.050408+00', '2026-10-20 16:32:32.050408+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.053932+00', '2026-10-20 16:32:32.053932+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-20 16:32:32.057477+00', '2026-10-20 16:32:32.057477+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.388057+00', '2026-10-20 16:32:32.388057+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.393356+00', '2026-10-20 16:32:32.393356+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.396799+00', '2026-10-20 16:32:32.396799+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.401011+00', '2026-10-20 16:32:32.401011+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.404823+00', '2026-10-20 16:32:32.404823+00', true);
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-20 16:32:32.437569+00', '2026-10-20 16:32:32.437569+00', true);


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('1c784873-add4-4088-a458-fba66c73748b', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-20 16:32:32.069593+00', '2026-10-20 16:32:32.069593+00');
INSERT INTO public.venue_rules VALUES ('21bf4bd1-c731-4887-b45e-1594d2e5cab5', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-20 16:32:32.072119+00', '2026-10-20 16:32:32.072119+00');
INSERT INTO public.venue_rules VALUES ('1072fd48-e38d-4cde-85be-53225e387622', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-20 16:32:32.074455+00', '2026-10-20 16:32:32.074455+00');
INSERT INTO public.venue_rules VALUES ('1b0e0797-cba2-4c74-ab5d-99d51b889d74', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-20 16:32:32.07661+00', '2026-10-20 16:32:32.07661+00');
INSERT INTO public.venue_rules VALUES ('fabe5e3b-24e8-4f46-906a-6f62159c9570', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-20 16:32:32.078993+00', '2026-10-20 16:32:32.078993+00');
INSERT INTO public.venue_rules VALUES ('19220d44-f995-4368-8ec3-8bc3de0b66a9', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-20 16:32:32.081443+00', '2026-10-20 16:32:32.081443+00');
INSERT INTO public.venue_rules VALUES ('e708bf7e-aa47-4885-b280-97818bc216f0', '84f219e1-682e-4bb2-82fb-78e7f34d082a', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-20 16:32:32.083603+00', '2026-10-20 16:32:32.083603+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('84f219e1-682e-4bb2-82fb-78e7f34d082a', '617224a2-546d-4403-8443-4750f2372e7c', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-20 16:32:32.062935+00', '2026-10-20 16:32:32.062935+00', false);
INSERT INTO public.venues VALUES ('2a1f2ab0-37a8-4ba4-983a-3a822a60912f', '617224a2-546d-4403-8443-4750f2372e7c', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-20 16:32:32.064796+00', '2026-10-20 16:32:32.064796+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('a164e640-2ab2-495a-a3c8-47c2ca8fd7eb', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-20 16:32:32.279058+00', '2026-10-20 16:32:32.279058+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('b22eb044-d17a-48d6-8318-c466dde82b55', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-20 16:32:32.282409+00', '2026-10-20 16:32:32.282409+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('0abf5528-c585-4e59-8e1f-f36326534d82', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-20 16:32:32.283976+00', '2026-10-20 16:32:32.283976+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('8e5c47c0-14fa-4986-8419-93ab49b2e095', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 16:32:32.285241+00', '2026-10-20 16:32:32.285241+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('eca99f45-0c5c-410b-90d7-f4d3fc57175a', 'beffbbfc-45cb-4878-aae7-33787be01fc9', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 16:32:33.031709+00', '2026-10-20 16:32:33.036438+00', '{organiser,sponsor}', false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8');
INSERT INTO public.workflow_steps VALUES ('c96c031b-c13a-4c9a-ace4-7c9936dfd805', '681e0493-3492-48b4-8850-eea31e531ea7', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-20 16:32:32.346607+00', '2026-10-20 16:32:32.346607+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('1b060e92-997e-4e7b-a059-98d09865c0a4', '681e0493-3492-48b4-8850-eea31e531ea7', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-20 16:32:32.348173+00', '2026-10-20 16:32:32.348173+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('5aa18475-a317-465b-ae01-f4aee48c96ed', '681e0493-3492-48b4-8850-eea31e531ea7', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-20 16:32:32.349702+00', '2026-10-20 16:32:32.349702+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('fc571e6e-7833-4a1d-b5bf-1794bb5f7079', '681e0493-3492-48b4-8850-eea31e531ea7', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-20 16:32:32.351145+00', '2026-10-20 16:32:32.351145+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('16a9ec03-5063-40cd-8ed9-93a93b0471e8', '681e0493-3492-48b4-8850-eea31e531ea7', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-20 16:32:32.35246+00', '2026-10-20 16:32:32.35246+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('451348c2-39c7-45f0-bf0d-1e7e0b3f0a85', '681e0493-3492-48b4-8850-eea31e531ea7', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-20 16:32:32.353819+00', '2026-10-20 16:32:32.353819+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('129dce63-a304-4c6a-831a-7e8bf8882d75', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 16:32:32.271205+00', '2026-10-20 16:32:33.019356+00', '{organiser,sponsor}', false, '8944f948-1b60-46a1-a2b8-991731ba53ca');
INSERT INTO public.workflow_steps VALUES ('5797db91-099d-4f89-8808-31d79ec689c9', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 16:32:32.274053+00', '2026-10-20 16:32:33.021036+00', '{organiser,sponsor}', false, '9d8434b4-4283-44d0-8919-2bc44356f2af');
INSERT INTO public.workflow_steps VALUES ('223e6b8c-5fbf-4c98-b792-fbda4c8ac3e2', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-20 16:32:32.27622+00', '2026-10-20 16:32:33.022395+00', '{sponsor}', false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3');
INSERT INTO public.workflow_steps VALUES ('c86733fc-bbd4-49cd-bfa2-652e152d55e0', 'e187091f-8014-4e81-8fd5-6a6f255bc39e', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-20 16:32:32.280718+00', '2026-10-20 16:32:33.023819+00', '{organiser,sponsor}', false, '84196ff9-50de-43c9-bd8c-f0ed23741ba8');
INSERT INTO public.workflow_steps VALUES ('33301c70-9195-411a-b2dc-449716be5e83', 'beffbbfc-45cb-4878-aae7-33787be01fc9', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 16:32:33.026432+00', '2026-10-20 16:32:33.032904+00', '{organiser,sponsor}', false, '8944f948-1b60-46a1-a2b8-991731ba53ca');
INSERT INTO public.workflow_steps VALUES ('65fe0910-9bbb-483b-abff-949c36ca15f3', 'beffbbfc-45cb-4878-aae7-33787be01fc9', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 16:32:33.028352+00', '2026-10-20 16:32:33.034489+00', '{organiser,sponsor}', false, '9d8434b4-4283-44d0-8919-2bc44356f2af');
INSERT INTO public.workflow_steps VALUES ('3941a643-6ed2-4301-9de3-0886bfbaa313', 'beffbbfc-45cb-4878-aae7-33787be01fc9', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-20 16:32:33.030124+00', '2026-10-20 16:32:33.035341+00', '{sponsor}', false, 'f9a4e8c5-146f-4e34-ba06-db46ffcfbab3');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('e187091f-8014-4e81-8fd5-6a6f255bc39e', '617224a2-546d-4403-8443-4750f2372e7c', 'Signage default', 'signage', true, false, '2026-10-20 16:32:32.268725+00', '2026-10-20 16:32:32.268725+00', NULL);
INSERT INTO public.workflows VALUES ('681e0493-3492-48b4-8850-eea31e531ea7', '617224a2-546d-4403-8443-4750f2372e7c', 'Stand default', 'stand', true, false, '2026-10-20 16:32:32.344613+00', '2026-10-20 16:32:32.344613+00', NULL);
INSERT INTO public.workflows VALUES ('beffbbfc-45cb-4878-aae7-33787be01fc9', '617224a2-546d-4403-8443-4750f2372e7c', 'Stand design sign-off', 'signage', false, false, '2026-10-20 16:32:33.012633+00', '2026-10-20 16:32:33.012633+00', 'stand_design');


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

\unrestrict HIymCzSANI0X6x8wvuRi7lkk6d6aLNZ8yIRuokhFgqEl9Lr9bpxiDE9s5sVbPpg

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
