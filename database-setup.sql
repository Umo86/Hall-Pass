-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites, public.supplier_services, public.supplier_service_links, public.departments, public.approvers, public.task_attachments, public.sponsorship_packages, public.sponsorship_package_lines CASCADE;
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

\restrict kzOxPQ5n0GnRuWRKwH4LoZxDxghEeCqdmtjRHXSBV4FVk2E8tE3ppxRTB86uQ72

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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('e9110a20-02ce-47f9-9413-8cd2eec90695', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('400aecf3-14bd-4344-a09f-6bc5f548e0d4', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('ea2bafc4-691f-490a-8a49-f4985a367ea4', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('1ba9236c-c729-436e-b4d5-353de3bf0e02', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('768962ba-7aa1-48a2-b33e-2d64da6b9fc1', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('0458784b-9e50-444b-afee-a7ea4771cd93', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('77726e02-f6a7-4677-83c2-f346395c75c7', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c3b9ac62-e5fa-45de-b8eb-b3f7e967a919', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.745989+00', '2026-10-19 12:16:16.745989+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0b503eaa-efda-47a8-9e1e-bb9843651459', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('043b599e-777b-448f-a2d2-676e1b962ddd', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('5b9f2af9-6a0c-4107-bdd5-c626dbc554a8', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('5ad2cec6-cf0b-42fc-ba35-ceb1b2b8f4fc', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('390db648-c07e-41bb-8f13-fb56c765b64d', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('22293337-a895-4b27-9a7f-26b08f853057', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c1a924cb-2dce-47d1-9f90-cdb059e91de9', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9300261b-e63d-4359-b5d1-f58413cf39b5', 'signage_item', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.780153+00', '2026-10-19 12:16:16.780153+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ef1a032-8e2b-464d-8ec6-58980ac34cb3', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-07 12:16:16.256+00', '2026-10-15 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('7dfba290-68c4-4e37-8914-4690f3aaf81c', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-09 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 12:16:16.256+00', '2026-10-10 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('1d6444fa-6207-4217-880c-bee11cca89cd', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-09 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 12:16:16.256+00', '2026-10-12 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('8beee454-ff82-4a8d-a237-dd107a215d77', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('488bc5c2-fa49-4f86-8430-acee142b03d3', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('2565029e-c070-4d3d-afc8-b4372438f4f4', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a6b445c4-31cf-4081-8078-4b437d20305b', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7865c6cd-bbee-488b-88f8-59d425e7ba8e', 'signage_item', '803ee864-e775-46c1-9795-324dd572e026', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.815408+00', '2026-10-19 12:16:16.815408+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f4713cd8-1209-4d7e-81b5-fc4e8cc9bc5a', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('ebbea0db-0e89-42c3-9cdb-3b4872a7ff7a', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('16901f4e-c308-4f4f-ad00-0fa996beee43', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('827feaed-7c7f-4363-84ba-a9890a36f29d', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e3801d6c-57d0-4fe5-bc76-565408894426', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('bf0df61a-8d77-425d-b9bc-84d3068bad4c', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('332765db-d4ba-4924-8e2c-a834b7eaf764', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9307489d-8cbf-4a6d-a9f3-b106321010e5', 'signage_item', '9943f023-a965-417c-ac73-89723c77b582', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.850754+00', '2026-10-19 12:16:16.850754+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9960ad45-dbf3-49e1-844d-81e16ba95bb1', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('25a79a85-88dd-4ba2-bbe3-d34cb4bfba16', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('fec27076-fc97-484e-9740-687369bec233', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('21bdb743-db61-4818-95c0-77a05ab227df', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4090aceb-51cd-40ed-b7ac-6de0369ba3f0', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('5b3f8bb1-d02b-4793-8d3e-58e1baf7ece1', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6f22f2e2-6220-41ea-87d1-f444a4239f98', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('329d28a0-085b-4979-a541-8e7e83d4392f', 'signage_item', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.873+00', '2026-10-19 12:16:16.873+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2f64abbf-e6d1-4d7c-96d7-7f5d514fe135', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-09 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 12:16:16.256+00', '2026-10-10 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('ef190412-66bd-419f-aa27-8100973b9c40', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-09 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 12:16:16.256+00', '2026-10-10 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('525b53a4-4e7d-431a-970f-3c8a60886780', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('0d2f2c03-945b-4a72-bd04-89e6d0716f20', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2bacf633-1c6a-49f8-8d11-fed5c0e09e76', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', '2026-10-15 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('59ec2568-61db-405f-844a-0f064489ebe3', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ec2bdefc-f218-4477-9a0c-982c43ee6def', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b0f9b07-a239-4704-b7cf-8deaab076d88', 'signage_item', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.901463+00', '2026-10-19 12:16:16.901463+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('906072fe-7c73-4be1-b363-7cc1d7f9cb26', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('0cb0b9d1-7483-4998-99fa-173294a9e6f3', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('4bce04d3-6795-43b1-a5e3-54eba94381f6', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('29106689-bbc3-4203-9efa-094a20d17ef5', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('36d762c5-3e09-4d2e-9696-951638c094cf', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('47c4be91-8e53-4d87-a22e-a39ba85e2451', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c204b2a0-48e7-4685-a67e-aff586c8a317', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b5bf092d-6d48-428d-b95d-8082a3012231', 'signage_item', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.926875+00', '2026-10-19 12:16:16.926875+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8afc9945-fcc3-4a64-95a1-c0081132fc18', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('c4ec667c-15b1-42e0-8926-2ad20097b0b6', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('98319f1a-338d-4363-884f-b16f7d2d7a25', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('bdb14f82-6790-4a6d-85a3-2ef2d739beec', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8cf08154-db5b-4b93-aaa7-d0acd3c0097b', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('e30ae7f1-8471-46b3-89b6-049b127ea209', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('10c85745-1fa5-4872-977b-0b0944a28579', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a328d015-1182-466c-a7f9-8709620f3648', 'signage_item', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.959197+00', '2026-10-19 12:16:16.959197+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9344ff60-890f-43a7-a885-bad165008aa6', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('2de53940-2ef2-49dd-b525-e7f2f5980df9', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('f3a8ec7f-a7fa-4e10-b7a2-57938045a270', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 12:16:16.256+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('a3d4a081-e515-4097-9c90-4f5e5dbb759e', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0bb64f0c-3d99-44a3-a4a3-b7bcc9cce041', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('eabe74e1-a61a-4c72-b664-8350916e8f11', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('553ad645-7122-49be-a778-5745e517b692', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('213eedfe-a4cf-4c3a-b1d9-a4deb0d44a76', 'signage_item', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:16.987112+00', '2026-10-19 12:16:16.987112+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('37d974c5-3c87-40b2-b558-6aa1c93a1df5', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('b168127a-1c15-4166-b27a-6985b3820d52', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('d3995fb8-8399-4d89-918b-7cf69d80cbef', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('15864c99-6026-4954-9f37-b00cfe49b468', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e80e634e-0d08-4652-a720-dab36295581c', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('30e84657-7f74-49f1-9536-4aa5feaea982', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('883b60c6-f23d-4605-aa6f-f7fa62567cd4', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aa3c16c0-6b23-4012-b96b-a5fa874f8b5b', 'signage_item', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.012594+00', '2026-10-19 12:16:17.012594+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3257a58a-e3c7-40d7-81bc-a47ccc9e271e', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('536a5e1e-1d37-4db0-92dd-237f1a7afae1', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('63213f8e-c646-4b31-8872-c46cc57e4b1e', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('b8965a90-4dfc-4da1-9eba-d30852a62480', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fc3520d2-9be6-46a4-90b1-c1592161ac81', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5e35fd45-d14d-4576-9243-809868443461', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('c9f52fda-c9b8-4c28-a6ed-6bbb3cd14d06', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('12088437-1efd-47ea-b3c1-9616bd1da9fb', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1db0f4dc-8101-4689-a025-d86270e8246c', 'signage_item', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.031445+00', '2026-10-19 12:16:17.031445+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d34fd259-9d9f-4beb-a85a-c1e51430bc28', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('7d7438e1-30d8-44a2-a5c6-2494eace6aa4', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('88ce1de0-4fef-4b48-bf36-31b423776ed8', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('b9023550-711a-4a85-8605-90f516055a0c', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2bfd1cf4-198f-4d5a-9884-47e1374ea842', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('3d727d2c-0059-455f-ac52-7e26569fa1f6', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('adb50a91-19fd-4d74-bba0-0f48ed57174a', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b5ca8009-e85a-4426-81c6-bb37b6fae963', 'signage_item', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.051471+00', '2026-10-19 12:16:17.051471+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('45ae0d64-bb72-407b-b4ae-805444261863', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('36d21013-dcff-49d6-af66-362391f6153f', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('7300e29d-6070-491e-8a63-44854db2c579', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('a7a03464-c371-427e-92f1-6f282e74cfcd', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('05fe0399-abf9-4877-a4d3-ce1cfd42fc06', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('c5e7554f-e3aa-47ac-8642-3ae8e167fb46', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f01d247b-a69d-48c8-ac54-8788dfdbebc9', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8fa956ed-a385-4333-896a-089dfabee2c5', 'signage_item', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.074028+00', '2026-10-19 12:16:17.074028+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b971852c-b8dd-4eac-aea0-7631d86e425d', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('c41383d2-70fd-40be-b33d-b62b9e9a85a0', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('35ab845f-83bb-4bb3-9018-6310012ed885', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('d0e7eaf4-a761-44d2-96ea-858fadee3619', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5552d515-faf7-45b0-be68-fa392475da90', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('6ad3e509-93f6-4aad-b9cc-d6a2370d46d9', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('be8ee7f5-7c2f-4f14-a283-e6337d29ac77', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('33d95e8a-bad4-4868-8b0f-a551b87f08a2', 'signage_item', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.092886+00', '2026-10-19 12:16:17.092886+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7dd34560-3583-4cca-937b-5e2a7d9ccc50', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('0a8ed567-2714-47c4-ba82-42350bdebf77', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('41ded4aa-8169-446e-bda8-a57d3f8f2f00', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('32be01f9-12b9-4e2a-af75-8c36b2ec5e98', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0ba34e21-c4ea-4a25-97f1-9c664f51e35c', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('156f4961-402b-4e3f-bd17-a50176bca6f1', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('392857b9-91d3-4b93-9ca1-f22b7600944a', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e863b812-7e9b-43d2-8124-cca0a6f747bc', 'signage_item', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.113887+00', '2026-10-19 12:16:17.113887+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5ff4e595-63bb-4b6c-b0d2-b60ec706b315', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('c6c4380a-a94e-4d05-9ba4-93cfe7818f10', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('22fb3c14-e800-436d-b832-b4bbf3733a87', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('be26dc8a-bb92-494d-aa6c-d9664c20cb07', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b2583ce6-15a8-4b01-8136-667424f3f413', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('b51229eb-5644-444c-b5c1-594bded7faf7', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3bea58c0-5293-4866-ae3f-6477caf9454b', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0bd3ac6e-56a2-4cf6-9422-3be03a37b023', 'signage_item', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.15144+00', '2026-10-19 12:16:17.15144+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d824cabd-5f94-4229-8c17-84a86088d453', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('afcf6d8d-a244-4268-85d3-7abf1e5ba152', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('c96fc4f6-10a9-4e57-a486-8b4132164dfb', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('7fa1a7fe-9f11-4048-ae4a-2833342e6ae0', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('14ef1f35-152a-4135-90ee-37f3850b1694', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('9ca25752-6091-49be-ab75-2295747933e6', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('27770387-7c01-4256-a777-8e6301b6b7e7', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('398267ee-b7cb-4867-a189-ae39ba2af762', 'signage_item', 'da099dc0-f415-428f-b575-6798f5d00001', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.173727+00', '2026-10-19 12:16:17.173727+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eb92b19c-68d4-4f1c-a541-61f5e5034a40', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('ae5b0ad5-8682-464d-8a13-0825564a2fd9', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('205c325c-cb6d-457d-9665-80182131c516', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('4b0b53b9-5034-41fe-ac00-810e475f24ab', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b10fe94e-2bf0-49c6-8f37-19210bf251f0', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('cce5d113-5588-404e-944e-b03202c82a82', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0c4b7ead-d602-4c4e-ac2c-ade4dffb1733', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8f94fa0f-53b5-4fe4-8b81-ab78683541c1', 'signage_item', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.195552+00', '2026-10-19 12:16:17.195552+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('950a3f70-e1f8-440d-a69e-d97446780182', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('7eabdbcd-179d-431b-bf21-b8b49b875b21', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 12:16:16.256+00', '2026-10-21 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('3b2abdde-5eaf-431f-96ef-7f24de550395', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('aee5fd76-9aee-4aa7-b0f6-0e7ce7ebbba6', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 12:16:16.256+00', '2026-10-21 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('25c22d80-3fd1-43a0-a72d-4f4a511940b3', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('aa863ef1-b1b0-41ba-8852-375d358980f3', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('8e67b0fa-4dd5-4305-bcb8-8a0a4642d504', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9d27efed-a9cf-49af-a6da-69d77f59409c', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('359f3237-544b-4575-82f6-a387976a3d8e', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c9fbbfa0-ac41-4f55-8af9-e911a4b7ca8c', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1f379168-b071-4ead-9338-baa434547898', 'signage_item', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.219497+00', '2026-10-19 12:16:17.219497+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('42c42098-418d-4322-abdd-66a4d1357b4e', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('3ce3196e-225d-485a-8859-dc37ef8bd8de', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('85977c61-293e-4f60-9cff-c7e16578b3a0', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('778efece-ea2f-4648-87b8-ecf74c2ad6cb', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('20ee5185-d97f-475c-ac48-abcfcb4e06cb', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('74f21385-6514-46b7-a3e4-b8f16d6313fb', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c6d838de-b585-4ea4-830e-89014f5127c5', 'signage_item', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.285408+00', '2026-10-19 12:16:17.285408+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e34f0542-ee56-44f1-9ae5-d7d425fb4aeb', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('c952d965-91c9-42c6-aa5a-02531dc5b6cb', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('46248f49-ac92-4f1b-b3f9-1565d4d9cc1d', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('1195d46c-32ef-4712-b615-8c4e990354aa', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 12:16:16.256+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-23 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6cc35c0e-dddb-417c-b111-a0bc7a829f0a', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('1fdab52f-1199-40cc-882d-df0b51d94f6d', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-18 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('607d931e-6d8d-40fc-b67c-5a2b08beef58', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cb3f70ac-17db-4707-a76c-cd6ab2e3e387', 'signage_item', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.305308+00', '2026-10-19 12:16:17.305308+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d349ca8f-17e8-4e60-b900-a3e8aa2bc477', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, '57076935-74d5-4951-9d5a-9a354c4acb9c', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 3, false, 'e668e4be-77dc-42f4-8980-3135844bd8aa', NULL);
INSERT INTO public.approval_instances VALUES ('46cca7f3-0afc-43cc-84eb-9da9de0efa69', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, '04a57237-d823-4192-b2f6-c7cefe2c4d50', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 3, false, '752531d9-7080-4a20-b3d6-361c10d37073', NULL);
INSERT INTO public.approval_instances VALUES ('d7d10a06-4e72-4500-8683-1f8cf8a71248', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'e85fb052-fb65-463d-b507-b0ceabffd651', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 12:16:16.256+00', '2026-10-19 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 5, false, '410119d7-fcc0-43ca-aa42-18e7c5303115', NULL);
INSERT INTO public.approval_instances VALUES ('ddc464ce-21ac-4520-afb4-66d0548748a4', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eb5e1d11-063f-4250-acf1-1a03de158253', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'b1a8dec7-3081-44e8-a198-21143a0b0b43', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 3, false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3', NULL);
INSERT INTO public.approval_instances VALUES ('7d67230c-961a-4609-910d-53f6b0fedc9a', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'dc258749-b93c-4cc6-94c5-2cd3a9743441', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8d420c2b-6f0e-4a63-a56f-98a7c02e6ce3', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bd6ea0df-697d-4e9d-af1f-4cffbc89fecb', 'signage_item', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, '9e3f8023-a403-419e-8707-f2c367b86cfb', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.32786+00', '2026-10-19 12:16:17.32786+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fa7285c4-d9ff-4500-b213-d6a3347b6319', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, '54a65ff7-3445-4b09-b7b8-459403a832d3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 12:16:16.256+00', '2026-10-16 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d1c80cc-908f-4c5d-9e2d-18aaf6f49e9b', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, 'c0efcb4a-c1fa-4d23-a628-89a95dd98474', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 12:16:16.256+00', '2026-10-22 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('38602ad3-72cc-4332-b03d-767cfb082437', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, 'f26fc6ef-7cb9-44bc-a658-822bd9a9683a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f8562ba0-315a-4535-bddc-1200039a6334', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, '5ec54ae2-ec70-4bbf-aa68-a2fff624a007', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('21513ec7-db40-4cb1-8049-2ea1c4054323', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, '461628b9-e1aa-44c5-9ea6-d78f470f290b', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5c99f4e2-a17e-4cd1-ba6a-c61233f8281d', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 1, 'e38be717-102c-40da-bb48-ff7c619fea87', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('566ae392-d648-4ba5-bbb7-a3a2684672a4', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, '54a65ff7-3445-4b09-b7b8-459403a832d3', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 12:16:16.256+00', '2026-10-16 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1f6210f3-16bf-44cc-b9b8-5bd20f566905', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, 'c0efcb4a-c1fa-4d23-a628-89a95dd98474', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4003f689-11b9-4ce9-b976-798244a9a48e', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, 'f26fc6ef-7cb9-44bc-a658-822bd9a9683a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('50553b9f-81f6-4284-a8ea-3cd7fcedee3b', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, '5ec54ae2-ec70-4bbf-aa68-a2fff624a007', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a401d152-2ff1-4aef-855f-54bc782f08c9', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, '461628b9-e1aa-44c5-9ea6-d78f470f290b', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cf4dcd71-4f6d-40de-af48-2853aa391779', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 1, 'e38be717-102c-40da-bb48-ff7c619fea87', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('233308bd-3913-4d76-892a-c03e7be9cb62', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, '54a65ff7-3445-4b09-b7b8-459403a832d3', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-13 12:16:16.256+00', '2026-10-16 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('097fde1e-ee20-455f-8eff-6b705c66c477', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, 'c0efcb4a-c1fa-4d23-a628-89a95dd98474', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2aecb6de-dfd4-4b65-aea3-4b3c9a9b6400', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, 'f26fc6ef-7cb9-44bc-a658-822bd9a9683a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('28fb0581-07cd-4681-b9cd-0495d9cf9c82', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, '5ec54ae2-ec70-4bbf-aa68-a2fff624a007', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('849fa361-ca3c-46fb-bc58-28e072f91719', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, '461628b9-e1aa-44c5-9ea6-d78f470f290b', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1bd18aee-b1d7-4a7e-8ed4-346325058f2b', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 1, 'e38be717-102c-40da-bb48-ff7c619fea87', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9b7ea923-555a-4c68-b259-d3df082c3e94', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, '54a65ff7-3445-4b09-b7b8-459403a832d3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 12:16:16.256+00', '2026-10-16 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('087e62a1-4dbc-4953-921a-8620ef5b89b8', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, 'c0efcb4a-c1fa-4d23-a628-89a95dd98474', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f073846c-0f9f-4ad4-b144-68041447cbd7', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, 'f26fc6ef-7cb9-44bc-a658-822bd9a9683a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-20 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ab6b657f-02d6-4538-a2dc-b2c376e95c50', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, '5ec54ae2-ec70-4bbf-aa68-a2fff624a007', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-22 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7ed8756c-a3c4-4f06-bb54-d64a3e2c34d8', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, '461628b9-e1aa-44c5-9ea6-d78f470f290b', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('93eae601-5141-430f-8d07-2244aa0fdce6', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 1, 'e38be717-102c-40da-bb48-ff7c619fea87', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f1d95edf-ea47-4790-ac28-1dbcea12ce5c', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, '54a65ff7-3445-4b09-b7b8-459403a832d3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 12:16:16.256+00', '2026-10-16 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a045dbf-5de8-42fe-8dea-7039724c63c2', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, 'c0efcb4a-c1fa-4d23-a628-89a95dd98474', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d99ea37-991e-48d2-9c30-e2b3d8b06dd3', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, 'f26fc6ef-7cb9-44bc-a658-822bd9a9683a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-20 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2d4eb655-f953-44b9-9bf4-0183b5ccc667', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, '5ec54ae2-ec70-4bbf-aa68-a2fff624a007', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-22 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('283fd72b-855c-443a-8de9-7c259e589e62', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, '461628b9-e1aa-44c5-9ea6-d78f470f290b', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 12:16:16.256+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 12:16:16.256+00', '2026-10-17 12:16:16.256+00', 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('75f8ffa8-6bab-43c9-9a33-66ddf516f6b1', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 1, 'e38be717-102c-40da-bb48-ff7c619fea87', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 12:16:16.256+00', NULL, 0, NULL, NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('4a74a510-f620-4948-a771-c3c2cb55558e', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e668e4be-77dc-42f4-8980-3135844bd8aa', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-19 12:16:16.560997+00', '2026-10-19 12:16:16.560997+00', false, NULL);
INSERT INTO public.approvers VALUES ('1fde3fc2-f448-46f9-b3e1-8d7c9c741379', 'c93eb335-72fd-4d7b-97d3-97530447fc73', '752531d9-7080-4a20-b3d6-361c10d37073', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-19 12:16:16.566983+00', '2026-10-19 12:16:16.566983+00', false, NULL);
INSERT INTO public.approvers VALUES ('e58295b5-0f91-442b-957e-28ca4e2827f6', 'c93eb335-72fd-4d7b-97d3-97530447fc73', '410119d7-fcc0-43ca-aa42-18e7c5303115', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-19 12:16:16.571507+00', '2026-10-19 12:16:16.571507+00', false, NULL);
INSERT INTO public.approvers VALUES ('29c47f3d-982f-4bb7-84bc-1c04ba3516e4', 'c93eb335-72fd-4d7b-97d3-97530447fc73', '5bb56667-a944-4815-91a6-1b0a62d4f7b3', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-19 12:16:16.576117+00', '2026-10-19 12:16:16.576117+00', false, NULL);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('689ad12d-8f93-448f-80c8-8ae3f26bf289', '638a2a14-7700-4527-9408-7e367a126aab', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:16.738635+00', '2026-10-19 12:16:16.738635+00');
INSERT INTO public.artwork_versions VALUES ('6cf8af16-ac57-45da-952f-6b03d73f7163', '84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:16.77399+00', '2026-10-19 12:16:16.77399+00');
INSERT INTO public.artwork_versions VALUES ('5aafeda4-4865-4ef9-8e47-f3c01eb8e6e4', '803ee864-e775-46c1-9795-324dd572e026', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-19 12:16:16.808045+00', '2026-10-19 12:16:16.808045+00');
INSERT INTO public.artwork_versions VALUES ('f77072ad-42ae-4f45-8e3c-03a1e0e9230c', '803ee864-e775-46c1-9795-324dd572e026', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:16.809834+00', '2026-10-19 12:16:16.809834+00');
INSERT INTO public.artwork_versions VALUES ('f3b983b8-b9f0-4c39-914f-be7a6fa6ed77', '9943f023-a965-417c-ac73-89723c77b582', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:16.844535+00', '2026-10-19 12:16:16.844535+00');
INSERT INTO public.artwork_versions VALUES ('3c75b8bc-2b72-4eee-bf26-5c478ac60209', '1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:16.869244+00', '2026-10-19 12:16:16.869244+00');
INSERT INTO public.artwork_versions VALUES ('041773e5-9d32-422c-9ee5-161fbc6de88d', '3048f056-39ff-4edd-9bdb-23c4743df460', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:16.896707+00', '2026-10-19 12:16:16.896707+00');
INSERT INTO public.artwork_versions VALUES ('026ad436-5f86-4747-91dc-3d8113def2c3', '88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:16.923408+00', '2026-10-19 12:16:16.923408+00');
INSERT INTO public.artwork_versions VALUES ('39bf15ea-3cca-4fc0-9da4-ee81c37afe98', '271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:16.954103+00', '2026-10-19 12:16:16.954103+00');
INSERT INTO public.artwork_versions VALUES ('22f048d6-5856-4055-8063-6265745e9ec9', 'add0fe03-67d0-4cb4-9647-1b404ba33fee', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:16.983853+00', '2026-10-19 12:16:16.983853+00');
INSERT INTO public.artwork_versions VALUES ('0de5879b-31b0-49a8-a16c-502a1c65d911', 'e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.009743+00', '2026-10-19 12:16:17.009743+00');
INSERT INTO public.artwork_versions VALUES ('c2a548b2-9e0f-47ec-a37d-4e00fd27096c', 'a2167814-515f-40da-a109-7a66f1f31bf5', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.028901+00', '2026-10-19 12:16:17.028901+00');
INSERT INTO public.artwork_versions VALUES ('c439c563-60ae-4216-bac3-4841546c8fcb', 'dd1fa477-621b-4d16-aaec-94bc5aff58be', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.048458+00', '2026-10-19 12:16:17.048458+00');
INSERT INTO public.artwork_versions VALUES ('1bb2f55f-eac8-4126-be9e-3ccddd92beb9', 'f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.071091+00', '2026-10-19 12:16:17.071091+00');
INSERT INTO public.artwork_versions VALUES ('ecfbf425-5287-4193-8347-ffabeeebd9cb', '1e9bd98f-acce-4092-86d2-e87e70266ab0', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.090253+00', '2026-10-19 12:16:17.090253+00');
INSERT INTO public.artwork_versions VALUES ('8ca5f967-fc27-4d24-9639-0b1ca6b8ce45', 'c52b6f0e-8756-4540-b2f6-991d564019e2', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.110349+00', '2026-10-19 12:16:17.110349+00');
INSERT INTO public.artwork_versions VALUES ('d9a4b45f-1237-4dec-b2bb-2671b2961424', 'b2c3930c-ac10-47e1-9389-246983f2de2b', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.148058+00', '2026-10-19 12:16:17.148058+00');
INSERT INTO public.artwork_versions VALUES ('b15b585f-b08a-42fd-b41f-411c665b0d4e', 'da099dc0-f415-428f-b575-6798f5d00001', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.170832+00', '2026-10-19 12:16:17.170832+00');
INSERT INTO public.artwork_versions VALUES ('2c1106c1-8eaa-456b-9b84-f73c63483771', 'a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.192843+00', '2026-10-19 12:16:17.192843+00');
INSERT INTO public.artwork_versions VALUES ('256ae897-8c1a-4b35-921b-3161e56371fc', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-19 12:16:17.214366+00', '2026-10-19 12:16:17.214366+00');
INSERT INTO public.artwork_versions VALUES ('31cab4fd-d01f-4806-9bc9-c5052620a33d', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-19 12:16:17.215858+00', '2026-10-19 12:16:17.215858+00');
INSERT INTO public.artwork_versions VALUES ('55481270-0158-45b0-b2c3-5294a1d75913', '36736688-63f2-46ed-a9a3-cbe38e0ef526', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.217+00', '2026-10-19 12:16:17.217+00');
INSERT INTO public.artwork_versions VALUES ('07de9519-3557-4d8b-bc1f-d2ec978b4c01', 'cac98160-0c80-47f3-b214-386562a75656', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 12:16:17.283038+00', '2026-10-19 12:16:17.283038+00');
INSERT INTO public.artwork_versions VALUES ('74a30f73-8e8f-446a-a2d6-87747153c40d', '93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.302582+00', '2026-10-19 12:16:17.302582+00');
INSERT INTO public.artwork_versions VALUES ('058247f4-2bc5-46a9-8dc4-8d95375ae712', 'ab9f3b35-26fb-43e9-9cbf-bdd723693561', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 12:16:17.324908+00', '2026-10-19 12:16:17.324908+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.audit_log VALUES ('d32d487e-fd7b-4965-9d1a-a82f0ee51c73', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', NULL, 'system', 'sponsorship_package', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68', 'create', NULL, '{"name": "Headline sponsor", "lines": [{"quantity": 6, "description": "Logo on 6 hanging banners"}, {"quantity": 1, "description": "Entrance feature branding"}], "price": "25000.00", "places": 1, "description": "Top billing across the venue"}', 'Added package Headline sponsor at £25,000', NULL, NULL, '2026-10-19 12:16:16.462114+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('ebe8832f-91cc-464d-b826-0508cb65a4c2', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', NULL, 'system', 'sponsor', '653744c6-13c4-423e-95c4-2c0703b43e44', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "a7fe5309-1f55-4c64-9f91-a6ca2e822f68", "packageName": "Headline sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["6 × Logo on 6 hanging banners", "Entrance feature branding"]}, "packagePrice": "22500.00", "packageSoldAt": "2026-10-09T12:16:16.256Z", "packagePriceNote": "Early-booking discount"}', 'BuildCo bought Headline sponsor for £22,500 (list £25,000: Early-booking discount)', NULL, NULL, '2026-10-19 12:16:16.462114+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('3068155e-eb3f-4740-9888-260801c07a2b', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', NULL, 'system', 'sponsorship_package', '19962cf8-a80c-473b-96f1-40182d04d590', 'create', NULL, '{"name": "Seminar theatre sponsor", "lines": [{"quantity": 1, "description": "Seminar theatre branding"}], "price": "8000.00", "places": 2, "description": "Branding in the seminar theatre"}', 'Added package Seminar theatre sponsor at £8,000', NULL, NULL, '2026-10-19 12:16:16.510111+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('ddb9d901-561a-4c80-8b28-86d2ea8436cd', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', NULL, 'system', 'sponsor', '04e77f6c-f598-4fed-a4fa-bd0b6c7309af', 'update', '{"packageId": null, "packageName": null, "packagePrice": null, "packageSoldAt": null, "packagePriceNote": null}', '{"packageId": "19962cf8-a80c-473b-96f1-40182d04d590", "packageName": "Seminar theatre sponsor", "entitlements": {"kept": [], "added": [], "removed": [], "alreadyThere": ["Seminar theatre branding"]}, "packagePrice": "8000.00", "packageSoldAt": "2026-10-09T12:16:16.256Z", "packagePriceNote": null}', 'ToolMart bought Seminar theatre sponsor for £8,000', NULL, NULL, '2026-10-19 12:16:16.510111+00', NULL, NULL);
INSERT INTO public.audit_log VALUES ('48a3df5f-a449-4cdc-91c3-386fab43652f', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', NULL, 'system', 'sponsorship_package', '9a8e5b5a-4d5d-4789-9b8a-9ae286086f45', 'create', NULL, '{"name": "Feature area sponsor", "lines": [{"quantity": 2, "description": "Feature area banners"}, {"quantity": 1, "description": "Logo in the event guide"}], "price": "12000.00", "places": 3, "description": "Branding around the feature area"}', 'Added package Feature area sponsor at £12,000', NULL, NULL, '2026-10-19 12:16:16.527832+00', NULL, NULL);


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

INSERT INTO public.contractors VALUES ('8c5a90d0-f5e3-466b-a447-8077b4902558', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-19 12:16:16.443732+00', '2026-10-19 12:16:16.443732+00');
INSERT INTO public.contractors VALUES ('10f18741-2f5b-453a-9455-94b733d5b327', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-19 12:16:16.446419+00', '2026-10-19 12:16:16.446419+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('e668e4be-77dc-42f4-8980-3135844bd8aa', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-19 12:16:16.557799+00', '2026-10-19 12:16:16.557799+00', true);
INSERT INTO public.departments VALUES ('752531d9-7080-4a20-b3d6-361c10d37073', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-19 12:16:16.564613+00', '2026-10-19 12:16:16.564613+00', true);
INSERT INTO public.departments VALUES ('410119d7-fcc0-43ca-aa42-18e7c5303115', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Sales', 3, false, '{sponsor}', false, '2026-10-19 12:16:16.569429+00', '2026-10-19 12:16:16.569429+00', true);
INSERT INTO public.departments VALUES ('5bb56667-a944-4815-91a6-1b0a62d4f7b3', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-19 12:16:16.574164+00', '2026-10-19 12:16:16.574164+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('0a235012-d80e-411e-82a1-73adcfda32ce', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00');
INSERT INTO public.documents VALUES ('4d070686-25e3-49e2-bf56-823989586106', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00');
INSERT INTO public.documents VALUES ('d72ff910-b9ed-46a3-83b0-8c2f956113a4', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00');
INSERT INTO public.documents VALUES ('2d5fc4a6-3ad2-478b-9c5f-48aa6a8b61f9', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'e272716d-5bec-440f-8675-15e57e2a33fd', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00');
INSERT INTO public.documents VALUES ('6499a736-f5ec-4a1c-a450-ef0d2477c3ac', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00');
INSERT INTO public.documents VALUES ('22018b4a-aabc-4a7b-b954-7190dfc669e6', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00');
INSERT INTO public.documents VALUES ('7573c045-a884-44fa-8c2b-9327aeac795b', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00');
INSERT INTO public.documents VALUES ('cb9730ce-997a-4ef8-9f3c-e3ed24055a65', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00');
INSERT INTO public.documents VALUES ('607d154b-3677-4291-a4b1-b41fe7b77144', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00');
INSERT INTO public.documents VALUES ('cda1eaaf-8775-49f8-a477-2ca576a6d774', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00');
INSERT INTO public.documents VALUES ('b5bacf14-5a00-42ac-8947-4d4923f9d3ff', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00');
INSERT INTO public.documents VALUES ('1ae6f3a7-bfb0-45d0-940a-d890c5ddd864', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', 'a759c61c-91fc-4205-9ab0-f475a75f9655', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00');
INSERT INTO public.documents VALUES ('d27114cf-3ca1-4525-8715-f4d5fcabce21', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00');
INSERT INTO public.documents VALUES ('d0055bf5-8ecc-4679-a77f-62ecd763f5c2', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00');
INSERT INTO public.documents VALUES ('cd368fd8-a899-444f-b40e-21cb7152b37c', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00');
INSERT INTO public.documents VALUES ('d8f4d182-f20a-4099-a021-23b4f713f136', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00');
INSERT INTO public.documents VALUES ('719f019e-365c-46cb-aa14-63c7eafab4cf', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00');
INSERT INTO public.documents VALUES ('22b72a85-57fd-48d0-901c-ae04163d3735', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00');
INSERT INTO public.documents VALUES ('a0a1603c-1a32-43cc-9141-8b4c276b3d0d', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00');
INSERT INTO public.documents VALUES ('7e88ec75-fda9-4f0e-acfb-ebde05cfb625', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_submission', '27d91f0b-0f0c-4847-b09c-627f8e98a779', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('8ba220b9-72a0-4d4a-959f-f6e612efeff5', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'signage', 34, '2026-10-19 12:16:17.358354+00', '2026-10-19 12:16:17.360126+00');
INSERT INTO public.edition_counters VALUES ('b2943a1a-e3a6-4c21-82f3-5fbc3f8f370b', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_design', 1, '2026-10-19 12:16:17.404669+00', '2026-10-19 12:16:17.404669+00');
INSERT INTO public.edition_counters VALUES ('5bdffaf2-f6a1-4429-8969-ce09bd5dc12e', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_item', 1, '2026-10-19 12:16:17.404669+00', '2026-10-19 12:16:17.404669+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('894e87b6-cfa1-4a6b-a5c9-ddbe79ac4f9b', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-19 12:16:16.364783+00', '2026-10-19 12:16:16.364783+00');
INSERT INTO public.edition_deadlines VALUES ('45f8e662-0485-4f12-91f6-b814a08b4d51', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-19 12:16:16.367265+00', '2026-10-19 12:16:16.367265+00');
INSERT INTO public.edition_deadlines VALUES ('839ec4e0-a68e-4669-b656-2e3b33d55ed7', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-19 12:16:16.368896+00', '2026-10-19 12:16:16.368896+00');
INSERT INTO public.edition_deadlines VALUES ('5df1d1b8-2401-4a84-bf51-76a2efa92737', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-19 12:16:16.37035+00', '2026-10-19 12:16:16.37035+00');
INSERT INTO public.edition_deadlines VALUES ('a3e3e37a-91f2-4060-8847-00a0f90ce98e', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-19 12:16:16.371504+00', '2026-10-19 12:16:16.371504+00');
INSERT INTO public.edition_deadlines VALUES ('72b9aee1-65ed-43ba-9a86-b2438a3ebe2a', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-19 12:16:16.372705+00', '2026-10-19 12:16:16.372705+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'd403ac77-b761-4601-9768-b63078ce9c18', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-19 12:16:16.36117+00', '2026-10-19 12:16:16.36117+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('d403ac77-b761-4601-9768-b63078ce9c18', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'UK Construction Week', 'UKCW', '2026-10-19 12:16:16.325813+00', '2026-10-19 12:16:16.325813+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('aa22859b-96a9-414d-abae-c94229b8e990', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Exhibitor Co', 'A10', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '8c5a90d0-f5e3-466b-a447-8077b4902558', '2026-10-19 12:16:16.682957+00', '2026-10-19 12:16:16.682957+00');
INSERT INTO public.exhibitors VALUES ('bff5c83e-2e82-45f3-bf25-7950925fd732', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SteelFrame Systems', 'A20', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '10f18741-2f5b-453a-9455-94b733d5b327', '2026-10-19 12:16:16.687516+00', '2026-10-19 12:16:16.687516+00');
INSERT INTO public.exhibitors VALUES ('20d4a7a1-6f0f-4d1c-b0ec-b7a76e21f046', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'BrickWorks UK', 'A30', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '8c5a90d0-f5e3-466b-a447-8077b4902558', '2026-10-19 12:16:16.691913+00', '2026-10-19 12:16:16.691913+00');
INSERT INTO public.exhibitors VALUES ('8239bd7b-752c-4f6a-b6b7-d0b9075147de', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Timber Trade Ltd', 'B10', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '10f18741-2f5b-453a-9455-94b733d5b327', '2026-10-19 12:16:16.695489+00', '2026-10-19 12:16:16.695489+00');
INSERT INTO public.exhibitors VALUES ('5b00e34c-6fa7-4f78-aebb-48a1e1ab1069', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'GlassTech', 'B20', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '8c5a90d0-f5e3-466b-a447-8077b4902558', '2026-10-19 12:16:16.698891+00', '2026-10-19 12:16:16.698891+00');
INSERT INTO public.exhibitors VALUES ('b84057cb-89db-4078-a043-f573080aa09c', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Insulate Pro', 'B30', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '10f18741-2f5b-453a-9455-94b733d5b327', '2026-10-19 12:16:16.70154+00', '2026-10-19 12:16:16.70154+00');
INSERT INTO public.exhibitors VALUES ('9bd50f7b-b8c8-44f9-be41-5b9a7825ab52', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'RoofRight', 'C10', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '8c5a90d0-f5e3-466b-a447-8077b4902558', '2026-10-19 12:16:16.703859+00', '2026-10-19 12:16:16.703859+00');
INSERT INTO public.exhibitors VALUES ('a6117d23-67b4-4f75-88d6-0aa6962b9309', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'PlantHire Direct', 'C20', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '10f18741-2f5b-453a-9455-94b733d5b327', '2026-10-19 12:16:16.706297+00', '2026-10-19 12:16:16.706297+00');
INSERT INTO public.exhibitors VALUES ('c8f5fa9f-5efc-4eec-86dc-4b04166c24d3', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SafetyFirst PPE', 'D10', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-19 12:16:16.710371+00', '2026-10-19 12:16:16.710371+00');
INSERT INTO public.exhibitors VALUES ('0871a16c-e792-4cc0-ad96-42e2191a00bc', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'ToolMart Retail', 'D20', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-19 12:16:16.714327+00', '2026-10-19 12:16:16.714327+00');
INSERT INTO public.exhibitors VALUES ('42fb247d-0552-43fe-b25e-96efd39bdc1d', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'EcoBuild Materials', 'D30', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-19 12:16:16.717972+00', '2026-10-19 12:16:16.717972+00');
INSERT INTO public.exhibitors VALUES ('28db7a12-236a-4e18-a218-cdb6e772481c', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SiteWise Software', 'D40', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-19 12:16:16.721553+00', '2026-10-19 12:16:16.721553+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('005449c2-c6f6-4348-aaaa-7b35da53e9cf', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'venue', 'venue', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.657921+00', '2026-10-19 12:16:16.657921+00');
INSERT INTO public.external_grants VALUES ('074591cb-6f4c-4875-9d4c-692c4fbc3b38', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.66248+00', '2026-10-19 12:16:16.66248+00');
INSERT INTO public.external_grants VALUES ('0383cd32-d28b-4c8d-af52-c73fde8d3c68', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.6676+00', '2026-10-19 12:16:16.6676+00');
INSERT INTO public.external_grants VALUES ('99db246c-974d-43e8-8de7-c31bd14ce84e', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'supplier', 'supplier', '0591712f-8671-4e29-bc58-a94099eb9526', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.671651+00', '2026-10-19 12:16:16.671651+00');
INSERT INTO public.external_grants VALUES ('28275403-716f-4d2a-8f6e-98ac6c2e50d2', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'sponsor', 'sponsor', '653744c6-13c4-423e-95c4-2c0703b43e44', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.67838+00', '2026-10-19 12:16:16.67838+00');
INSERT INTO public.external_grants VALUES ('17a4257d-82d6-4c5b-9c50-55838b1d394a', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'exhibitor', 'exhibitor', 'aa22859b-96a9-414d-abae-c94229b8e990', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-19 12:16:16.256+00', NULL, '2026-10-19 12:16:16.726103+00', '2026-10-19 12:16:16.726103+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('e62f8973-b9d0-40c3-b20c-38fd37843107', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-19 12:16:16.375702+00', '2026-10-19 12:16:16.375702+00');
INSERT INTO public.halls VALUES ('ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-19 12:16:16.378866+00', '2026-10-19 12:16:16.378866+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('06bdece1-0382-44ba-abd4-5369000016a9', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Hanging banner', 'hanging_banner', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'rigged', true, 0, '2026-10-19 12:16:16.621053+00', '2026-10-19 12:16:16.621053+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Foamex board', 'foamex_board', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'wall_mounted', false, 1, '2026-10-19 12:16:16.624102+00', '2026-10-19 12:16:16.624102+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('b439e5f7-bb12-44cc-8910-6579abb52b50', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Fabric graphic', 'fabric_graphic', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'shell_mounted', false, 2, '2026-10-19 12:16:16.626358+00', '2026-10-19 12:16:16.626358+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('babb359e-0865-4298-92d4-925bb422dfba', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Floor vinyl', 'floor_vinyl', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'floor', false, 3, '2026-10-19 12:16:16.628881+00', '2026-10-19 12:16:16.628881+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('6954afbf-a1b8-4fde-a784-3cd044c2b0c6', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Aisle sign', 'aisle_sign', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'rigged', true, 4, '2026-10-19 12:16:16.631049+00', '2026-10-19 12:16:16.631049+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('77f94146-c460-492f-a164-bf836afedff1', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Entrance feature', 'entrance_feature', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'freestanding', true, 5, '2026-10-19 12:16:16.632741+00', '2026-10-19 12:16:16.632741+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('88aada4e-35f3-4311-991f-de40b601a263', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Registration', 'registration', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'freestanding', false, 6, '2026-10-19 12:16:16.63447+00', '2026-10-19 12:16:16.63447+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('79ba2407-ad73-462d-889c-f7cfa57ff430', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Seminar theatre', 'seminar_theatre', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'freestanding', false, 7, '2026-10-19 12:16:16.636116+00', '2026-10-19 12:16:16.636116+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4f12d86a-7583-4945-bd82-eae30d62f1d2', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Feature area', 'feature_area', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'freestanding', false, 8, '2026-10-19 12:16:16.638249+00', '2026-10-19 12:16:16.638249+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('ea1a4152-f49e-47bb-a0eb-17e50ca6730e', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'External', 'external', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'freestanding', true, 9, '2026-10-19 12:16:16.642844+00', '2026-10-19 12:16:16.642844+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('7a656571-e83c-4dd9-9333-505724fd734e', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Digital screen', 'digital_screen', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'digital', false, 10, '2026-10-19 12:16:16.644506+00', '2026-10-19 12:16:16.644506+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('338ee328-d665-40bd-bd17-ec1af17b1bcd', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Branded lanyards', 'lanyard', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', NULL, false, 11, '2026-10-19 12:16:16.646287+00', '2026-10-19 12:16:16.646287+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('ba6d570b-b3cb-4600-998b-190c4dd2c2c5', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Show bags', 'show_bag', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', NULL, false, 12, '2026-10-19 12:16:16.647849+00', '2026-10-19 12:16:16.647849+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('d53ef471-c246-405f-a3d7-f6930f01f6c9', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Registration branding', 'reg_branding', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', NULL, false, 13, '2026-10-19 12:16:16.649396+00', '2026-10-19 12:16:16.649396+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('1031ff77-5b3c-4a95-95ba-d0a7178eec32', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Other signage', 'other_signage', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', NULL, false, 14, '2026-10-19 12:16:16.651044+00', '2026-10-19 12:16:16.651044+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('1089102f-ce30-4e62-b4aa-6dd056acd940', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Other sponsorship item', 'other_sponsorship', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', NULL, false, 15, '2026-10-19 12:16:16.652556+00', '2026-10-19 12:16:16.652556+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('7e237247-7d74-404a-b9d0-9852e7ffa5af', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-19 12:16:16.386788+00', '2026-10-19 12:16:16.386788+00');
INSERT INTO public.locations VALUES ('352951b4-d983-4006-a422-4d86f4f0197a', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-19 12:16:16.38984+00', '2026-10-19 12:16:16.38984+00');
INSERT INTO public.locations VALUES ('9a8581bb-e3ab-409d-9354-52c28b59357e', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-19 12:16:16.392482+00', '2026-10-19 12:16:16.392482+00');
INSERT INTO public.locations VALUES ('242bd712-6da9-4db7-b14f-007b61cf8f63', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-19 12:16:16.394497+00', '2026-10-19 12:16:16.394497+00');
INSERT INTO public.locations VALUES ('922e2966-54ba-4c56-930b-e1ae61b7370b', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-19 12:16:16.396813+00', '2026-10-19 12:16:16.396813+00');
INSERT INTO public.locations VALUES ('12b9d1f2-dcdc-483e-b1e8-f6a25dd8af3f', 'e62f8973-b9d0-40c3-b20c-38fd37843107', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-19 12:16:16.399103+00', '2026-10-19 12:16:16.399103+00');
INSERT INTO public.locations VALUES ('01079abc-92f0-4508-911b-99eeaac64d98', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-19 12:16:16.401248+00', '2026-10-19 12:16:16.401248+00');
INSERT INTO public.locations VALUES ('7f4ef8bf-c0a7-491b-b365-f78e51a140cd', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-19 12:16:16.404479+00', '2026-10-19 12:16:16.404479+00');
INSERT INTO public.locations VALUES ('acc6d0ac-add4-402b-8423-703383551fee', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-19 12:16:16.406469+00', '2026-10-19 12:16:16.406469+00');
INSERT INTO public.locations VALUES ('6d0f92b2-b77a-4282-baed-36ad25ae72a8', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-19 12:16:16.40888+00', '2026-10-19 12:16:16.40888+00');
INSERT INTO public.locations VALUES ('964519b7-88a0-4633-bac4-dfae76d29f1e', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-19 12:16:16.410976+00', '2026-10-19 12:16:16.410976+00');
INSERT INTO public.locations VALUES ('a3f9c2e8-6e2e-470f-8e39-b947cd9d01ef', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-19 12:16:16.413022+00', '2026-10-19 12:16:16.413022+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('5959359c-ac12-40e8-aa2d-504ca3894ed8', '00000000-0000-4000-8000-000000000001', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'admin', '2026-10-19 12:16:16.303218+00', '2026-10-19 12:16:16.303218+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('9f53aab1-9b47-4193-bd45-817d2affb279', '00000000-0000-4000-8000-000000000002', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'ops', '2026-10-19 12:16:16.308135+00', '2026-10-19 12:16:16.308135+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('c67d6fd9-401f-48fa-bd42-726c38b88649', '00000000-0000-4000-8000-000000000004', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'sales', '2026-10-19 12:16:16.316545+00', '2026-10-19 12:16:16.316545+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('4e7388d3-6ee8-4d99-a354-00b1343bc9ba', '00000000-0000-4000-8000-000000000005', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'event_director', '2026-10-19 12:16:16.320429+00', '2026-10-19 12:16:16.320429+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('6a6771ff-8a5b-4d88-aaad-3468812e2658', '00000000-0000-4000-8000-000000000006', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'viewer', '2026-10-19 12:16:16.323356+00', '2026-10-19 12:16:16.323356+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('c712a1db-904f-4813-ba64-30cf84a3321f', '00000000-0000-4000-8000-000000000003', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'marketing', '2026-10-19 12:16:16.311647+00', '2026-10-19 12:16:17.509714+00', '{"costs.edit": true}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('c93eb335-72fd-4d7b-97d3-97530447fc73', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-19 12:16:16.294526+00', '2026-10-19 12:16:16.294526+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('638a2a14-7700-4527-9408-7e367a126aab', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '77f94146-c460-492f-a164-bf836afedff1', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '7e237247-7d74-404a-b9d0-9852e7ffa5af', 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', '6197b001-4a92-4937-b394-f6c15a25cb87', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '689ad12d-8f93-448f-80c8-8ae3f26bf289', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.733283+00', '2026-10-19 12:16:16.741453+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('84684e66-cd1a-452e-aed7-2aad3fa8a9c1', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '88aada4e-35f3-4311-991f-de40b601a263', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '352951b4-d983-4006-a422-4d86f4f0197a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '6cf8af16-ac57-45da-952f-6b03d73f7163', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.770018+00', '2026-10-19 12:16:16.776838+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('803ee864-e775-46c1-9795-324dd572e026', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '06bdece1-0382-44ba-abd4-5369000016a9', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '9a8581bb-e3ab-409d-9354-52c28b59357e', 'ops', '00000000-0000-4000-8000-000000000002', '653744c6-13c4-423e-95c4-2c0703b43e44', 'c57d0625-7b51-4d51-87d4-d2f0703e8d51', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'f77072ad-42ae-4f45-8e3c-03a1e0e9230c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.804512+00', '2026-10-19 12:16:16.81272+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9943f023-a965-417c-ac73-89723c77b582', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '79ba2407-ad73-462d-889c-f7cfa57ff430', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '242bd712-6da9-4db7-b14f-007b61cf8f63', 'marketing', '00000000-0000-4000-8000-000000000003', '04e77f6c-f598-4fed-a4fa-bd0b6c7309af', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'f3b983b8-b9f0-4c39-914f-be7a6fa6ed77', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.839262+00', '2026-10-19 12:16:16.849183+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1e8ca4a1-fb34-4716-a1fa-1157577f7a3b', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', 'babb359e-0865-4298-92d4-925bb422dfba', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '922e2966-54ba-4c56-930b-e1ae61b7370b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '3c75b8bc-2b72-4eee-bf26-5c478ac60209', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.866313+00', '2026-10-19 12:16:16.871163+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3048f056-39ff-4edd-9bdb-23c4743df460', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '4f12d86a-7583-4945-bd82-eae30d62f1d2', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '12b9d1f2-dcdc-483e-b1e8-f6a25dd8af3f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '041773e5-9d32-422c-9ee5-161fbc6de88d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.893148+00', '2026-10-19 12:16:16.89919+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "b1a8dec7-3081-44e8-a198-21143a0b0b43", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('88bf8b2a-0f59-46d1-b77e-41c1067bfd68', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '06bdece1-0382-44ba-abd4-5369000016a9', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '01079abc-92f0-4508-911b-99eeaac64d98', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '026ad436-5f86-4747-91dc-3d8113def2c3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.920419+00', '2026-10-19 12:16:16.925138+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('271820ab-2cae-4a3b-93dd-30a6bb1b5a95', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '6954afbf-a1b8-4fde-a784-3cd044c2b0c6', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '7f4ef8bf-c0a7-491b-b365-f78e51a140cd', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '39bf15ea-3cca-4fc0-9da4-ee81c37afe98', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.949963+00', '2026-10-19 12:16:16.956279+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('add0fe03-67d0-4cb4-9647-1b404ba33fee', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '79ba2407-ad73-462d-889c-f7cfa57ff430', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'acc6d0ac-add4-402b-8423-703383551fee', 'marketing', '00000000-0000-4000-8000-000000000003', '04e77f6c-f598-4fed-a4fa-bd0b6c7309af', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '22f048d6-5856-4055-8063-6265745e9ec9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:16.981171+00', '2026-10-19 12:16:16.985343+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e472194b-eac2-48d0-9730-6a0dcfc9d9c0', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'b439e5f7-bb12-44cc-8910-6579abb52b50', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '6d0f92b2-b77a-4282-baed-36ad25ae72a8', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '0de5879b-31b0-49a8-a16c-502a1c65d911', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.007478+00', '2026-10-19 12:16:17.012594+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL);
INSERT INTO public.signage_items VALUES ('a2167814-515f-40da-a109-7a66f1f31bf5', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'ea1a4152-f49e-47bb-a0eb-17e50ca6730e', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '964519b7-88a0-4633-bac4-dfae76d29f1e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'c2a548b2-9e0f-47ec-a37d-4e00fd27096c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.026731+00', '2026-10-19 12:16:17.031445+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', NULL);
INSERT INTO public.signage_items VALUES ('dd1fa477-621b-4d16-aaec-94bc5aff58be', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'a3f9c2e8-6e2e-470f-8e39-b947cd9d01ef', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'c439c563-60ae-4216-bac3-4841546c8fcb', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.04583+00', '2026-10-19 12:16:17.051471+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-16 12:16:16.256+00');
INSERT INTO public.signage_items VALUES ('47d0cf93-75a1-4b45-8c0c-ca4880d2732f', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '1089102f-ce30-4e62-b4aa-6dd056acd940', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.355711+00', '2026-10-19 12:16:17.355711+00', 'sponsorship_item', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', '2026-11-06', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4ab381ae-c49f-4cb0-bec9-6d467413015e', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, 'e62f8973-b9d0-40c3-b20c-38fd37843107', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '69b07200-711e-40c6-8621-2d0a88bfe7f5', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.402842+00', '2026-10-19 12:16:17.402842+00', 'stand_design', 'organiser', '[{"stepId": "79f36c74-5308-4a1e-9e31-159686ee3943", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "3fc102a0-bc04-42a2-b11e-4e1d844297dc", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f8826c3b-6b06-42ab-bc1e-f4eaadb25330', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '7a656571-e83c-4dd9-9333-505724fd734e', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '352951b4-d983-4006-a422-4d86f4f0197a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '87b45188-59e0-4b75-ad57-3f9408319162', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '1bb2f55f-eac8-4126-be9e-3ccddd92beb9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.067042+00', '2026-10-19 12:16:17.074028+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "b1a8dec7-3081-44e8-a198-21143a0b0b43", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-16 12:16:16.256+00');
INSERT INTO public.signage_items VALUES ('1e9bd98f-acce-4092-86d2-e87e70266ab0', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '6954afbf-a1b8-4fde-a784-3cd044c2b0c6', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '9a8581bb-e3ab-409d-9354-52c28b59357e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'ecfbf425-5287-4193-8347-ffabeeebd9cb', '2026-10-16 12:16:16.256+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.088117+00', '2026-10-19 12:16:17.092886+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-16 12:16:16.256+00');
INSERT INTO public.signage_items VALUES ('c52b6f0e-8756-4540-b2f6-991d564019e2', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '922e2966-54ba-4c56-930b-e1ae61b7370b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '8ca5f967-fc27-4d24-9639-0b1ca6b8ce45', '2026-10-16 12:16:16.256+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.107592+00', '2026-10-19 12:16:17.113887+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-16 12:16:16.256+00');
INSERT INTO public.signage_items VALUES ('b2c3930c-ac10-47e1-9389-246983f2de2b', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '4f12d86a-7583-4945-bd82-eae30d62f1d2', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '12b9d1f2-dcdc-483e-b1e8-f6a25dd8af3f', 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'd9a4b45f-1237-4dec-b2bb-2671b2961424', '2026-10-16 12:16:16.256+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.144329+00', '2026-10-19 12:16:17.15144+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, '2026-10-16 12:16:16.256+00', '2026-10-16 12:16:16.256+00');
INSERT INTO public.signage_items VALUES ('da099dc0-f415-428f-b575-6798f5d00001', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '06bdece1-0382-44ba-abd4-5369000016a9', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '7f4ef8bf-c0a7-491b-b365-f78e51a140cd', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 'b15b585f-b08a-42fd-b41f-411c665b0d4e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.168134+00', '2026-10-19 12:16:17.172288+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a155ad23-7847-4d26-8b3a-fffb1b9d63ce', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'b439e5f7-bb12-44cc-8910-6579abb52b50', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '6d0f92b2-b77a-4282-baed-36ad25ae72a8', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '2c1106c1-8eaa-456b-9b84-f73c63483771', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.190207+00', '2026-10-19 12:16:17.194267+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('36736688-63f2-46ed-a9a3-cbe38e0ef526', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '06bdece1-0382-44ba-abd4-5369000016a9', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '9a8581bb-e3ab-409d-9354-52c28b59357e', 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', 'c57d0625-7b51-4d51-87d4-d2f0703e8d51', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '55481270-0158-45b0-b2c3-5294a1d75913', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.212221+00', '2026-10-19 12:16:17.217932+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b0ea7524-1f2f-4e67-a1a7-503fd437937a', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'a3f9c2e8-6e2e-470f-8e39-b947cd9d01ef', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.239471+00', '2026-10-19 12:16:17.239471+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a80a1607-88fe-429d-884a-2c73797d902c', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '352951b4-d983-4006-a422-4d86f4f0197a', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.247447+00', '2026-10-19 12:16:17.247447+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('807cd7f3-a246-43cb-9b65-20f8c2991b7e', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '88aada4e-35f3-4311-991f-de40b601a263', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '01079abc-92f0-4508-911b-99eeaac64d98', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.252156+00', '2026-10-19 12:16:17.252156+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e992e7b4-4560-4a30-9658-fffe2a51b517', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '7a656571-e83c-4dd9-9333-505724fd734e', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '12b9d1f2-dcdc-483e-b1e8-f6a25dd8af3f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '87b45188-59e0-4b75-ad57-3f9408319162', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.257848+00', '2026-10-19 12:16:17.257848+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "b1a8dec7-3081-44e8-a198-21143a0b0b43", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6e2979c1-d642-4867-80f4-28016d7856ac', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', 'babb359e-0865-4298-92d4-925bb422dfba', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'acc6d0ac-add4-402b-8423-703383551fee', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.263976+00', '2026-10-19 12:16:17.263976+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a96355ed-2ef5-4cbe-a2a7-85994b817b60', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '79ba2407-ad73-462d-889c-f7cfa57ff430', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'acc6d0ac-add4-402b-8423-703383551fee', 'marketing', '00000000-0000-4000-8000-000000000003', '04e77f6c-f598-4fed-a4fa-bd0b6c7309af', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.268459+00', '2026-10-19 12:16:17.268459+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('efd8ae8b-77eb-48d0-b8b6-18dba0669b14', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'ea1a4152-f49e-47bb-a0eb-17e50ca6730e', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '964519b7-88a0-4633-bac4-dfae76d29f1e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.272511+00', '2026-10-19 12:16:17.272511+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "b1a8dec7-3081-44e8-a198-21143a0b0b43", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d8cf43ca-a9f0-48a0-b761-bfa46ea8b245', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', '964519b7-88a0-4633-bac4-dfae76d29f1e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.276533+00', '2026-10-19 12:16:17.276533+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('cac98160-0c80-47f3-b214-386562a75656', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '922e2966-54ba-4c56-930b-e1ae61b7370b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '07de9519-3557-4d8b-bc1f-d2ec978b4c01', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.281169+00', '2026-10-19 12:16:17.284296+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('93e49b7e-12e7-4f9b-87f6-a73be3d01c55', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '77f94146-c460-492f-a164-bf836afedff1', 'e62f8973-b9d0-40c3-b20c-38fd37843107', '7e237247-7d74-404a-b9d0-9852e7ffa5af', 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', '6197b001-4a92-4937-b394-f6c15a25cb87', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '74a30f73-8e8f-446a-a2d6-87747153c40d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.299662+00', '2026-10-19 12:16:17.303945+00', 'signage', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', NULL, NULL, NULL, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('730d49d8-7a9b-4207-8bd5-b1e63ae3bc7f', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'e0977dfc-ef46-4959-93ef-f2864f1a39f7', 'ddbe9bce-9e74-4bf0-af97-a26d89e8c6a7', 'a3f9c2e8-6e2e-470f-8e39-b947cd9d01ef', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.31832+00', '2026-10-19 12:16:17.31832+00', 'signage', 'organiser', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ab9f3b35-26fb-43e9-9cbf-bdd723693561', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '338ee328-d665-40bd-bd17-ec1af17b1bcd', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, '058247f4-2bc5-46a9-8dc4-8d95375ae712', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.322596+00', '2026-10-19 12:16:17.326379+00', 'sponsorship_item', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', '2027-01-02', NULL, 9000.00, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8a7279e1-68c4-4c26-a913-6d9db5a1f209', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'ba6d570b-b3cb-4600-998b-190c4dd2c2c5', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '653744c6-13c4-423e-95c4-2c0703b43e44', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.342354+00', '2026-10-19 12:16:17.342354+00', 'sponsorship_item', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}, {"stepId": "e85fb052-fb65-463d-b507-b0ceabffd651", "userId": null}]', '2026-11-08', NULL, 12500.00, '2026-10-09 12:16:16.256+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1c666c39-cf5c-4911-8ae6-45ae1bce16ef', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'd53ef471-c246-405f-a3d7-f6930f01f6c9', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 12:16:17.348046+00', '2026-10-19 12:16:17.348046+00', 'sponsorship_item', 'sponsor', '[{"stepId": "57076935-74d5-4951-9d5a-9a354c4acb9c", "userId": null}, {"stepId": "04a57237-d823-4192-b2f6-c7cefe2c4d50", "userId": null}]', '2027-02-16', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('54bed48d-0573-4607-88eb-baa3b2b006ea', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'c52b6f0e-8756-4540-b2f6-991d564019e2', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '0591712f-8671-4e29-bc58-a94099eb9526', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-19 12:16:17.135078+00', '2026-10-19 12:16:17.135078+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('c57d0625-7b51-4d51-87d4-d2f0703e8d51', '653744c6-13c4-423e-95c4-2c0703b43e44', 'Logo on 6 hanging banners', 6, '2026-10-19 12:16:16.453941+00', '2026-10-19 12:16:16.462114+00', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68');
INSERT INTO public.sponsor_entitlements VALUES ('6197b001-4a92-4937-b394-f6c15a25cb87', '653744c6-13c4-423e-95c4-2c0703b43e44', 'Entrance feature branding', 1, '2026-10-19 12:16:16.456349+00', '2026-10-19 12:16:16.462114+00', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68');
INSERT INTO public.sponsor_entitlements VALUES ('1ad399b2-31a2-4ae2-a107-a0d98e386fa1', '04e77f6c-f598-4fed-a4fa-bd0b6c7309af', 'Seminar theatre branding', 1, '2026-10-19 12:16:16.460677+00', '2026-10-19 12:16:16.510111+00', '19962cf8-a80c-473b-96f1-40182d04d590');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('653744c6-13c4-423e-95c4-2c0703b43e44', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-19 12:16:16.450206+00', '2026-10-19 12:16:16.462114+00', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68', 22500.00, 'Early-booking discount', '2026-10-09 12:16:16.256+00');
INSERT INTO public.sponsors VALUES ('04e77f6c-f598-4fed-a4fa-bd0b6c7309af', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-19 12:16:16.458592+00', '2026-10-19 12:16:16.510111+00', '19962cf8-a80c-473b-96f1-40182d04d590', 8000.00, NULL, '2026-10-09 12:16:16.256+00');


--
-- Data for Name: sponsorship_package_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_package_lines VALUES ('984818d8-ff47-40ce-84eb-cbe1b00662ab', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68', 'Logo on 6 hanging banners', 6, 1, '2026-10-19 12:16:16.462114+00', '2026-10-19 12:16:16.462114+00');
INSERT INTO public.sponsorship_package_lines VALUES ('b76054c0-fc07-4c6c-8c0e-2f96e0c68568', 'a7fe5309-1f55-4c64-9f91-a6ca2e822f68', 'Entrance feature branding', 1, 2, '2026-10-19 12:16:16.462114+00', '2026-10-19 12:16:16.462114+00');
INSERT INTO public.sponsorship_package_lines VALUES ('566d151a-e0de-4458-9574-deba824e63af', '19962cf8-a80c-473b-96f1-40182d04d590', 'Seminar theatre branding', 1, 1, '2026-10-19 12:16:16.510111+00', '2026-10-19 12:16:16.510111+00');
INSERT INTO public.sponsorship_package_lines VALUES ('b2e3ab4a-f4cf-41a5-8be3-d1cbc0cb7726', '9a8e5b5a-4d5d-4789-9b8a-9ae286086f45', 'Feature area banners', 2, 1, '2026-10-19 12:16:16.527832+00', '2026-10-19 12:16:16.527832+00');
INSERT INTO public.sponsorship_package_lines VALUES ('1ce534d4-8172-4096-8117-f97bb87e7a6d', '9a8e5b5a-4d5d-4789-9b8a-9ae286086f45', 'Logo in the event guide', 1, 2, '2026-10-19 12:16:16.527832+00', '2026-10-19 12:16:16.527832+00');


--
-- Data for Name: sponsorship_packages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsorship_packages VALUES ('a7fe5309-1f55-4c64-9f91-a6ca2e822f68', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Headline sponsor', 'Top billing across the venue', 25000.00, 1, 1, false, '2026-10-19 12:16:16.462114+00', '2026-10-19 12:16:16.462114+00');
INSERT INTO public.sponsorship_packages VALUES ('19962cf8-a80c-473b-96f1-40182d04d590', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Seminar theatre sponsor', 'Branding in the seminar theatre', 8000.00, 2, 2, false, '2026-10-19 12:16:16.510111+00', '2026-10-19 12:16:16.510111+00');
INSERT INTO public.sponsorship_packages VALUES ('9a8e5b5a-4d5d-4789-9b8a-9ae286086f45', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Feature area sponsor', 'Branding around the feature area', 12000.00, 3, 3, false, '2026-10-19 12:16:16.527832+00', '2026-10-19 12:16:16.527832+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('e272716d-5bec-440f-8675-15e57e2a33fd', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'aa22859b-96a9-414d-abae-c94229b8e990', 'STD-BIRM27-A10', '8c5a90d0-f5e3-466b-a447-8077b4902558', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-13 12:16:16.256+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.407957+00', '2026-10-19 12:16:17.407957+00');
INSERT INTO public.stand_submissions VALUES ('22a4b0a9-64b6-4bf9-aa74-323b3e6655b3', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'bff5c83e-2e82-45f3-bf25-7950925fd732', 'STD-BIRM27-A20', '10f18741-2f5b-453a-9455-94b733d5b327', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-13 12:16:16.256+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.434242+00', '2026-10-19 12:16:17.434242+00');
INSERT INTO public.stand_submissions VALUES ('a759c61c-91fc-4205-9ab0-f475a75f9655', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', '20d4a7a1-6f0f-4d1c-b0ec-b7a76e21f046', 'STD-BIRM27-A30', '8c5a90d0-f5e3-466b-a447-8077b4902558', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-13 12:16:16.256+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.45069+00', '2026-10-19 12:16:17.45069+00');
INSERT INTO public.stand_submissions VALUES ('80e1ca87-3a67-4cc1-bd32-4958ea7d84c0', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', '8239bd7b-752c-4f6a-b6b7-d0b9075147de', 'STD-BIRM27-B10', '10f18741-2f5b-453a-9455-94b733d5b327', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-13 12:16:16.256+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.465065+00', '2026-10-19 12:16:17.465065+00');
INSERT INTO public.stand_submissions VALUES ('27d91f0b-0f0c-4847-b09c-627f8e98a779', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', '5b00e34c-6fa7-4f78-aebb-48a1e1ab1069', 'STD-BIRM27-B20', '8c5a90d0-f5e3-466b-a447-8077b4902558', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-13 12:16:16.256+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.479973+00', '2026-10-19 12:16:17.479973+00');
INSERT INTO public.stand_submissions VALUES ('761baa71-ca4d-4c8e-bbee-cf0125131d12', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'b84057cb-89db-4078-a043-f573080aa09c', 'STD-BIRM27-B30', '10f18741-2f5b-453a-9455-94b733d5b327', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.497977+00', '2026-10-19 12:16:17.497977+00');
INSERT INTO public.stand_submissions VALUES ('c81a77e1-79ab-4fed-b573-ddc6c1dba0aa', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', '9bd50f7b-b8c8-44f9-be41-5b9a7825ab52', 'STD-BIRM27-C10', '8c5a90d0-f5e3-466b-a447-8077b4902558', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.501917+00', '2026-10-19 12:16:17.501917+00');
INSERT INTO public.stand_submissions VALUES ('4a0acb56-0365-45fa-837a-5a921b3bbd96', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'a6117d23-67b4-4f75-88d6-0aa6962b9309', 'STD-BIRM27-C20', '10f18741-2f5b-453a-9455-94b733d5b327', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 12:16:17.505905+00', '2026-10-19 12:16:17.505905+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('0591712f-8671-4e29-bc58-a94099eb9526', '54d61a8d-51d0-4a70-ba81-cec14e87ec06');
INSERT INTO public.supplier_service_links VALUES ('0591712f-8671-4e29-bc58-a94099eb9526', 'ff396d3d-89c3-4498-8417-561e45b6441f');
INSERT INTO public.supplier_service_links VALUES ('018e2a08-c2c2-4c58-b42a-df6686d49786', 'a7646e05-077c-43b2-b947-996421a17d97');
INSERT INTO public.supplier_service_links VALUES ('018e2a08-c2c2-4c58-b42a-df6686d49786', 'ff396d3d-89c3-4498-8417-561e45b6441f');
INSERT INTO public.supplier_service_links VALUES ('018e2a08-c2c2-4c58-b42a-df6686d49786', 'c57f2249-2ffa-4ba7-a583-2a3dca2fd1e4');
INSERT INTO public.supplier_service_links VALUES ('87b45188-59e0-4b75-ad57-3f9408319162', '94f6a5ec-91f2-49a8-ade5-530652635df5');
INSERT INTO public.supplier_service_links VALUES ('87b45188-59e0-4b75-ad57-3f9408319162', 'c57f2249-2ffa-4ba7-a583-2a3dca2fd1e4');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('54d61a8d-51d0-4a70-ba81-cec14e87ec06', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Signage print', 1, false, '2026-10-19 12:16:16.424011+00', '2026-10-19 12:16:16.424011+00');
INSERT INTO public.supplier_services VALUES ('94f6a5ec-91f2-49a8-ade5-530652635df5', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Digital screens & AV', 2, false, '2026-10-19 12:16:16.425938+00', '2026-10-19 12:16:16.425938+00');
INSERT INTO public.supplier_services VALUES ('a7646e05-077c-43b2-b947-996421a17d97', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Rigging', 3, false, '2026-10-19 12:16:16.427818+00', '2026-10-19 12:16:16.427818+00');
INSERT INTO public.supplier_services VALUES ('ff396d3d-89c3-4498-8417-561e45b6441f', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Installation', 4, false, '2026-10-19 12:16:16.429117+00', '2026-10-19 12:16:16.429117+00');
INSERT INTO public.supplier_services VALUES ('c57f2249-2ffa-4ba7-a583-2a3dca2fd1e4', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Staffing', 5, false, '2026-10-19 12:16:16.430318+00', '2026-10-19 12:16:16.430318+00');
INSERT INTO public.supplier_services VALUES ('5e718b51-ba11-4871-851a-67311105fe57', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Furniture', 6, false, '2026-10-19 12:16:16.431496+00', '2026-10-19 12:16:16.431496+00');
INSERT INTO public.supplier_services VALUES ('e86f00e9-a57b-4267-a0a1-2d80ac3a6946', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Structural engineering', 7, false, '2026-10-19 12:16:16.432612+00', '2026-10-19 12:16:16.432612+00');
INSERT INTO public.supplier_services VALUES ('4369c290-bffd-4389-b4d0-4684c7819632', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Floor Manager', 8, false, '2026-10-19 12:16:16.433616+00', '2026-10-19 12:16:16.433616+00');
INSERT INTO public.supplier_services VALUES ('385e1974-22e9-4255-8fde-e7c373f19f17', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Security', 9, false, '2026-10-19 12:16:16.4346+00', '2026-10-19 12:16:16.4346+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('0591712f-8671-4e29-bc58-a94099eb9526', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-19 12:16:16.415966+00', '2026-10-19 12:16:16.415966+00', false);
INSERT INTO public.suppliers VALUES ('018e2a08-c2c2-4c58-b42a-df6686d49786', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-19 12:16:16.419089+00', '2026-10-19 12:16:16.419089+00', false);
INSERT INTO public.suppliers VALUES ('87b45188-59e0-4b75-ad57-3f9408319162', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-19 12:16:16.422263+00', '2026-10-19 12:16:16.422263+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('a668332f-320a-46fc-9e96-0697d71696ad', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-26', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '638a2a14-7700-4527-9408-7e367a126aab', NULL, '2026-10-19 12:16:17.51543+00', '2026-10-19 12:16:17.51543+00', NULL);
INSERT INTO public.tasks VALUES ('7a35d8c6-739e-4bf3-bd0d-a84eef0c22f1', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-29', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-19 12:16:17.517832+00', '2026-10-19 12:16:17.517832+00', NULL);
INSERT INTO public.tasks VALUES ('56a334b8-05cb-4960-8951-cc3037d1a7e8', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Walk the hall with the venue', NULL, 'done', '2026-10-14', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-19 12:16:16.256+00', '2026-10-19 12:16:17.519505+00', '2026-10-19 12:16:17.519505+00', '7a35d8c6-739e-4bf3-bd0d-a84eef0c22f1');
INSERT INTO public.tasks VALUES ('962a9b4b-511b-40e9-bbae-0024e218ced0', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'e5fca6d9-7c64-4a11-b1af-72ad1ea96b65', 'Send sign positions to the printer', NULL, 'open', '2026-10-18', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-19 12:16:17.519505+00', '2026-10-19 12:16:17.519505+00', '7a35d8c6-739e-4bf3-bd0d-a84eef0c22f1');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.299952+00', '2026-10-19 12:16:16.299952+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.306519+00', '2026-10-19 12:16:16.306519+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.309881+00', '2026-10-19 12:16:16.309881+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.314024+00', '2026-10-19 12:16:16.314024+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.318993+00', '2026-10-19 12:16:16.318993+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-19 12:16:16.322011+00', '2026-10-19 12:16:16.322011+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.654481+00', '2026-10-19 12:16:16.654481+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.660157+00', '2026-10-19 12:16:16.660157+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.664762+00', '2026-10-19 12:16:16.664762+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.669292+00', '2026-10-19 12:16:16.669292+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.673325+00', '2026-10-19 12:16:16.673325+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-19 12:16:16.72321+00', '2026-10-19 12:16:16.72321+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('ee501bde-e384-4dd4-8e48-016770b4f1ec', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-19 12:16:16.337102+00', '2026-10-19 12:16:16.337102+00');
INSERT INTO public.venue_rules VALUES ('3ef630e2-7446-4df4-84ae-4db344156f55', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-19 12:16:16.34028+00', '2026-10-19 12:16:16.34028+00');
INSERT INTO public.venue_rules VALUES ('27f95166-9b3b-42c2-b492-7e077098ba6c', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-19 12:16:16.343125+00', '2026-10-19 12:16:16.343125+00');
INSERT INTO public.venue_rules VALUES ('42ea7ebf-6a55-460e-b86a-5c85b9d38dc9', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-19 12:16:16.345898+00', '2026-10-19 12:16:16.345898+00');
INSERT INTO public.venue_rules VALUES ('9f2a251f-f9a4-415e-ae23-182ee36cc52f', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-19 12:16:16.349641+00', '2026-10-19 12:16:16.349641+00');
INSERT INTO public.venue_rules VALUES ('421723d9-5e18-4cd8-84e4-edc1e74d417d', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-19 12:16:16.352489+00', '2026-10-19 12:16:16.352489+00');
INSERT INTO public.venue_rules VALUES ('4d0cfa8b-8a80-4718-943d-dc3a50381fe8', 'dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-19 12:16:16.355344+00', '2026-10-19 12:16:16.355344+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('dcf5807a-f0dc-4ff1-b410-04253b7e5ed7', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-19 12:16:16.328547+00', '2026-10-19 12:16:16.328547+00', false);
INSERT INTO public.venues VALUES ('df086281-e605-4f26-aada-ce5a8831dbde', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-19 12:16:16.331273+00', '2026-10-19 12:16:16.331273+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('bcaab2a6-7233-4fcf-aad5-a5d19a62ddf6', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-19 12:16:16.547134+00', '2026-10-19 12:16:16.547134+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('dc258749-b93c-4cc6-94c5-2cd3a9743441', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-19 12:16:16.550117+00', '2026-10-19 12:16:16.550117+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('b0db56eb-e45e-46e7-95f3-faef80e3ed40', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-19 12:16:16.551273+00', '2026-10-19 12:16:16.551273+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('9e3f8023-a403-419e-8707-f2c367b86cfb', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-19 12:16:16.55248+00', '2026-10-19 12:16:16.55248+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('5c03c0c1-24dd-45fd-b141-42ddf5a44ea1', '69b07200-711e-40c6-8621-2d0a88bfe7f5', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-19 12:16:17.380054+00', '2026-10-19 12:16:17.385034+00', '{organiser,sponsor}', false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3');
INSERT INTO public.workflow_steps VALUES ('54a65ff7-3445-4b09-b7b8-459403a832d3', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-19 12:16:16.604061+00', '2026-10-19 12:16:16.604061+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('c0efcb4a-c1fa-4d23-a628-89a95dd98474', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-19 12:16:16.608876+00', '2026-10-19 12:16:16.608876+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('f26fc6ef-7cb9-44bc-a658-822bd9a9683a', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-19 12:16:16.610654+00', '2026-10-19 12:16:16.610654+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('5ec54ae2-ec70-4bbf-aa68-a2fff624a007', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-19 12:16:16.61225+00', '2026-10-19 12:16:16.61225+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('461628b9-e1aa-44c5-9ea6-d78f470f290b', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-19 12:16:16.614074+00', '2026-10-19 12:16:16.614074+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e38be717-102c-40da-bb48-ff7c619fea87', '9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-19 12:16:16.616446+00', '2026-10-19 12:16:16.616446+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('57076935-74d5-4951-9d5a-9a354c4acb9c', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 12:16:16.539475+00', '2026-10-19 12:16:17.369199+00', '{organiser,sponsor}', false, 'e668e4be-77dc-42f4-8980-3135844bd8aa');
INSERT INTO public.workflow_steps VALUES ('04a57237-d823-4192-b2f6-c7cefe2c4d50', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 12:16:16.541908+00', '2026-10-19 12:16:17.370472+00', '{organiser,sponsor}', false, '752531d9-7080-4a20-b3d6-361c10d37073');
INSERT INTO public.workflow_steps VALUES ('e85fb052-fb65-463d-b507-b0ceabffd651', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-19 12:16:16.543478+00', '2026-10-19 12:16:17.371446+00', '{sponsor}', false, '410119d7-fcc0-43ca-aa42-18e7c5303115');
INSERT INTO public.workflow_steps VALUES ('b1a8dec7-3081-44e8-a198-21143a0b0b43', 'a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-19 12:16:16.548745+00', '2026-10-19 12:16:17.372622+00', '{organiser,sponsor}', false, '5bb56667-a944-4815-91a6-1b0a62d4f7b3');
INSERT INTO public.workflow_steps VALUES ('79f36c74-5308-4a1e-9e31-159686ee3943', '69b07200-711e-40c6-8621-2d0a88bfe7f5', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 12:16:17.375227+00', '2026-10-19 12:16:17.381627+00', '{organiser,sponsor}', false, 'e668e4be-77dc-42f4-8980-3135844bd8aa');
INSERT INTO public.workflow_steps VALUES ('3fc102a0-bc04-42a2-b11e-4e1d844297dc', '69b07200-711e-40c6-8621-2d0a88bfe7f5', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 12:16:17.377085+00', '2026-10-19 12:16:17.382827+00', '{organiser,sponsor}', false, '752531d9-7080-4a20-b3d6-361c10d37073');
INSERT INTO public.workflow_steps VALUES ('894d140e-c588-4720-beba-dd89b2a93db7', '69b07200-711e-40c6-8621-2d0a88bfe7f5', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 12:16:17.378689+00', '2026-10-19 12:16:17.3838+00', '{sponsor}', false, '410119d7-fcc0-43ca-aa42-18e7c5303115');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('a8565192-b6e1-44bf-8e0b-03f2f5883e1d', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Signage default', 'signage', true, false, '2026-10-19 12:16:16.537443+00', '2026-10-19 12:16:16.537443+00', NULL);
INSERT INTO public.workflows VALUES ('9ecc6164-a9c9-4c4c-8465-dcd44fe91103', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Stand default', 'stand', true, false, '2026-10-19 12:16:16.601225+00', '2026-10-19 12:16:16.601225+00', NULL);
INSERT INTO public.workflows VALUES ('69b07200-711e-40c6-8621-2d0a88bfe7f5', 'c93eb335-72fd-4d7b-97d3-97530447fc73', 'Stand design sign-off', 'signage', false, false, '2026-10-19 12:16:17.363716+00', '2026-10-19 12:16:17.363716+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 14, true);


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

\unrestrict kzOxPQ5n0GnRuWRKwH4LoZxDxghEeCqdmtjRHXSBV4FVk2E8tE3ppxRTB86uQ72

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
