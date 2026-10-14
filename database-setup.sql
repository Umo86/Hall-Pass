-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites, public.supplier_services, public.supplier_service_links, public.departments, public.approvers, public.task_attachments CASCADE;
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

\restrict FkO7RNwEBOZ6lQq9g8Kyij3bVE9JMibxpcTvxPtE6lSPKHlKWnTB107QzHWNEqk

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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    job_title text
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    job_title text,
    department_id uuid,
    features text[],
    expires_at timestamp with time zone
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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('88018969-998c-42ee-a88c-bad02df9c754', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2c5cfaf1-54a6-491a-b2a6-c92eab7710ce', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('7c1bc3bf-f166-4266-98a9-fbd486546bc0', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('d008f545-748e-43b0-8793-91c79b013b2b', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('15064702-db58-4f06-be3c-33dde6b82005', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('e543c033-7d66-457c-9b62-8718faa39241', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6932ed31-e35d-4a85-8b14-ad1d906aaa7c', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('52e06a5f-beb6-4df4-beff-f30f95ed9471', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.600498+00', '2026-10-14 17:05:55.600498+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('98cdbb1c-4953-4ded-8a8e-5c0a110eb916', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('1ef1ffab-a954-43c2-b56e-811b93aa1f1c', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('a5066ddb-6686-42ac-b16f-c7424d70726b', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('2fa191c5-6694-4988-8f60-ce96e9f443db', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dda52b5c-5619-4adb-8f07-7fef6fbb220e', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('cf0e6228-dc6e-45b1-bcf7-5a81fb9a324f', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('545f6ac8-8e6b-4739-945e-bfcfb36e5d8d', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f3da09ca-bc2d-4b52-a09c-10d455543e3b', 'signage_item', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.624359+00', '2026-10-14 17:05:55.624359+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b840fc9c-ae13-4ca7-9492-a05627d54d02', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-02 17:05:55.198+00', '2026-10-10 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2b4842f1-886d-432e-a94b-7181417622ab', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-04 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-02 17:05:55.198+00', '2026-10-05 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('460dce5c-8fe7-4cef-b611-72d7b23a64ac', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-04 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-02 17:05:55.198+00', '2026-10-07 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('151bdc15-1c35-4b1c-9551-ddb2c8f5f490', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f1eae4e9-bb33-466d-b208-83370de21280', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('fa5cb82c-3de4-48e5-b0cb-9d261896751d', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('981f2297-0c27-4557-ac47-734c748e183b', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b31acf92-5d57-4cee-a032-142ff760cb11', 'signage_item', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.655763+00', '2026-10-14 17:05:55.655763+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('17da4914-1060-49f1-9522-249dc34ff560', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('3c49b5db-9251-407a-830d-b325b3e25a50', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('52ed0fa5-b1bc-40d5-b63b-5edef5cd2646', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('c62b199c-d9af-429f-81ee-8c4147cee9c8', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('724bf170-e55c-470e-a922-31c7b7a4c7fb', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('a597082e-b947-4435-a65e-6a1b01b8f660', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('839e1b8d-b9bf-47c1-9559-2373adce37ef', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('83092edb-2b70-46d1-b842-9ccfb1f717b0', 'signage_item', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.680993+00', '2026-10-14 17:05:55.680993+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ba1c8bca-f7f3-416b-a8f3-21e5f9b435d1', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('091c792b-a94b-4cc6-8b5f-72e15aa4c49b', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('aaee6e6b-2bbc-48b0-8e8b-819e02d586e0', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('58c03263-0da9-43ec-b490-17df540408ad', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('90ea9640-7650-4e3a-8916-39cdee211527', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('fd3f5763-828a-4a15-90b6-ba2451d4c3fd', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('84d31730-2974-4e5e-86ea-ef64d4959979', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d43a7fb0-c9d5-49af-9f4f-6dffed670f72', 'signage_item', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.710314+00', '2026-10-14 17:05:55.710314+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('72a8e1df-1ec6-4289-9b99-a05d99ce83c4', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-04 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-02 17:05:55.198+00', '2026-10-05 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2292fd12-89d6-40c2-9774-2fa8b96e1cd3', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-04 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-02 17:05:55.198+00', '2026-10-05 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('1eac2acd-f56d-40ed-b973-411e2a40b7b0', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('9b0de6d3-db5c-4e59-af83-303b1e6dc861', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c1ce8444-1421-48da-8bb7-ecf4d267d821', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', '2026-10-10 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('97edb165-758e-46a9-9832-7ad9cde28b92', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('110c55b3-003a-4f5f-9959-5fa9fc41f767', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('891f50c2-bdf0-45ee-b737-591292463594', 'signage_item', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.737538+00', '2026-10-14 17:05:55.737538+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ce7714b6-ad8d-4856-9090-5e849a88024e', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('01bb2048-7cd1-4afb-8869-783a8a901a15', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('004984f4-8ec5-4965-abf7-87591aad838d', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('41b60a69-645b-404b-b552-71d361dd5159', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d1f1a13-0e2a-4d25-987a-ac8f734dc48b', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('cabaa045-679c-43c1-9d3b-49a2080e72e2', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fcd28564-61ad-422a-bc35-12e82abbc477', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4329707f-5e58-480a-a7c1-c4293c138af7', 'signage_item', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.756845+00', '2026-10-14 17:05:55.756845+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('545e033f-c680-408e-afc6-18560530ff5e', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('d27c4da4-d048-44cf-bf15-e92adec52957', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('4a68a757-3232-41de-a34a-12e96beed83b', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('87d84fa6-914f-4486-99c9-b32a298dcb68', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8e0918d6-9b99-4331-a93e-44f045f4c513', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('05941a79-e79f-4257-8265-6037b4cfd18d', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef6992c9-8b4e-4ebb-a2de-f594b0710db1', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d88a682e-4045-4c92-8a35-87fa918fb1af', 'signage_item', '916641f0-6f23-419c-a20d-eee28797116a', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.784517+00', '2026-10-14 17:05:55.784517+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aa38df34-7a5e-43f9-ad01-9f198fc586eb', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('539cafb9-0549-4311-964c-877278c16074', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('2fea891e-fe16-450e-a0c5-4b10b60a9872', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-11 17:05:55.198+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('a2dde6d8-9a96-44d3-b870-05b7cec95c44', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fa4efaf2-3454-4752-b47a-69c1642f7f12', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('c5c3a863-30cd-400c-a628-139b09f30eb9', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4911a82a-50e0-43be-afaa-b373351e99cb', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8db6ea0e-0c56-4eef-ac5f-bcc3f5c8f333', 'signage_item', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.807959+00', '2026-10-14 17:05:55.807959+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6275310a-968a-46dc-aa54-e0af12698882', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('918cf49d-319c-4e20-b7a5-8246602f2d02', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('67d27d56-06b2-4ca7-9de0-52dc06043166', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('5b2e3e5e-6cde-4c52-bd11-29526e0981a0', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e06419a2-93c6-4d37-829d-3dd457aa2820', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('460369b6-e530-4ff5-8ca6-6febb8f585b1', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7e673856-c0d8-4bb0-a0d0-16842d65b2ab', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e5fa5160-3054-4c74-8787-54316fd7b8aa', 'signage_item', '2b523122-f192-4229-98af-b57204cef7a2', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.830957+00', '2026-10-14 17:05:55.830957+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9217df3b-13b8-40bd-a94f-6faf2b7ef8fb', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2ab53dc7-fefd-49a1-aa6e-786756020121', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('f2b419be-9d79-437d-89f0-5b4294e6f220', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('7d99c28c-2a7e-46ea-a733-43bca93244ba', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3ae7d77f-ae05-4df2-b056-1e8cfe531361', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('b2f6b3d3-47d4-4269-896e-2d3309442d8b', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('130afb6a-a470-4b49-986e-03d00f24d7ff', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d886ca81-5648-4f37-b595-eb96a7ec3acc', 'signage_item', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.855242+00', '2026-10-14 17:05:55.855242+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('67a3e857-5358-4c76-b4b2-754cc82e77eb', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('192f98a2-a073-47ea-8937-8876b7ed4022', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('a02e31b2-c4fa-4dab-a833-1b615439aeb1', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('571ea3da-24b7-4e20-a880-35839470edc4', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('06f2d5ca-30b6-434f-b05a-db20bdfe28e7', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('6d220f73-63b2-4331-849d-f8ad2660f3ec', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('486983ff-0f47-4bba-afcb-fb6228a17a03', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2ba169ef-18d4-41d4-9dbf-d21b84164aed', 'signage_item', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.875868+00', '2026-10-14 17:05:55.875868+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7872ca29-f114-4041-8da3-a38f4c5629ef', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2a2d83f9-febc-415a-adeb-32c188ebc92b', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('d50d0acb-c953-4522-b13d-99629d2ad0f5', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('54f5faba-d3c2-4e29-a6ea-8fb1096a5b72', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('704d7903-743a-4348-adc8-c7a8f08c3aa5', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('a4234bcb-1a96-44a6-b144-07500176de5e', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6e7368a0-b823-4723-921e-0dae4c5378ad', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1eb29546-64b2-420b-92f0-bb51480a2400', 'signage_item', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.893927+00', '2026-10-14 17:05:55.893927+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('76a6d8d4-7235-4f2e-a8e0-93fca0e67d5c', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('694b5219-c8ed-4a7c-ad9a-c68f1f709fb4', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('9c469390-bfd9-4d79-ba4f-492b0011ad2c', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('cf7e7ee6-3f1b-46eb-9c13-e2a4baed9253', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('79650e86-1599-40f2-8d3b-fcba067caff9', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('721d80d9-cbad-43e8-8d7d-e901c4dfebde', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0fa383dc-e1d8-4e5c-95d9-79f208ddc1a6', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6e2710ab-2371-4e65-afba-fa713a4723d3', 'signage_item', '3992d443-508c-41a2-9672-27de1a421042', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.91601+00', '2026-10-14 17:05:55.91601+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7fa4baa5-833e-45d2-a92d-147495026883', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('7a235a98-124b-40ef-a0ee-0ac88acbb994', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('5048d587-db0a-450c-9651-0974166c45dc', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('0079e334-4fd7-4526-9190-06865589efa8', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c82c52af-ca8a-42ec-8f80-a3f1e9bc23b4', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('dc573cc3-6867-49f6-8344-3a953553fd57', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('04633f2f-caec-45df-9100-73d464ce83cc', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b4f9ce5d-d697-46c0-8906-5f2f6da4365e', 'signage_item', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.94202+00', '2026-10-14 17:05:55.94202+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dc9e0a2e-0a39-4b83-af59-3913c26ee963', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('41984bea-c729-4e98-a428-5ba35bf3f663', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('4b674ea9-a267-491f-9ec7-e4f646e25def', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('e9f095fa-adce-4de1-855a-abd78a2fb616', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('91fccca4-5cfe-4f7a-a4be-c70611894121', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('d95cc361-7013-4303-aeba-c103b0730693', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9759fce6-63f7-4a3c-96d1-0e61b0a6d1a1', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1b8ef000-6920-4fed-be9c-002e0cdedd46', 'signage_item', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.963756+00', '2026-10-14 17:05:55.963756+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f5c8332e-60e3-4303-af70-87645711cc82', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('2581487c-7959-4abd-9904-6a253cb1d653', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('01cc41b3-4a19-4ac2-8bb2-1ef7a6aa5b9e', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('1089538f-009c-493b-a762-610902786ef3', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a32d33d7-84c8-484b-b9cb-0b2bd92dcf47', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('2863ae9d-dc06-4054-bead-64140014d101', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dbb684d0-ab33-4ee0-a0d6-426c3c869804', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ee4c5510-3001-44b4-8f00-a647f5cabccf', 'signage_item', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:55.986441+00', '2026-10-14 17:05:55.986441+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7659e10d-ef03-48bf-8232-a8b6aab06649', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('996b2d4a-0032-42b7-b3f0-cf0b90faed09', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('fbc342fa-ec0d-48a3-b230-c85c7410c02c', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('cbccb947-7be0-4d93-8274-cb5aabbd6c99', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('62d2ad8e-a101-421d-8571-c83ace0c2a55', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('3e998c77-d8ae-4965-8fcf-f4ca51720b66', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3e4c045e-cd41-49ce-a4e9-b66484b7cad3', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('60697b89-d959-4d05-8822-a2ba8bf95e9e', 'signage_item', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.009791+00', '2026-10-14 17:05:56.009791+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('66d0a7be-d0ff-4db0-aefd-15aa5d8672b6', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('37edfd07-b4da-4b40-99a3-c448691789f8', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 17:05:55.198+00', '2026-10-16 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('1422f7ec-1c07-4af3-8eef-a1cf55468360', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('10d74f0d-58c4-4517-adc0-e9dcd28f84f2', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 17:05:55.198+00', '2026-10-16 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('3d11b609-6cee-4638-92f2-9f7c13fdec80', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('57d4c33c-ea68-4536-8c00-2d20c56ebcbf', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('0aed1407-9337-4302-ac6e-243b966a2928', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('04b2c581-0b01-4b01-95da-1697ff41d74c', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('8aeb14f8-72f6-45af-a458-a055ce4c55fd', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9b3f17ce-2e8c-469d-b454-9ff1baa3cfa5', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d0e82040-83dc-41ee-9406-f35dfdc946c9', 'signage_item', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.040936+00', '2026-10-14 17:05:56.040936+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c9209acd-7703-418d-bc97-d01dc1de84b6', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('a46adfa2-8fcc-4d8d-b46e-5be0805d154a', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('5f2dcd57-1744-40a3-9de9-3b2192482bc8', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('f5374d38-5d46-48d4-b583-703a8d03d73d', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('679dd414-c8bb-463d-a447-f904a9bd3287', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('daf2bd84-482a-4cef-b953-c1f3904e442f', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1a80f266-ad25-4dfe-9f15-0c63989b386a', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c9719b79-9128-469d-919e-7a4f1caca697', 'signage_item', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.110177+00', '2026-10-14 17:05:56.110177+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('126af996-ff86-4fdc-b1e7-f44aae03e2f0', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('3eac0dd9-9ba2-4a1c-9567-2992ce1479b1', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('cc267de1-48e4-4381-987d-af5b31ca7b99', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('0a395f49-28b2-4867-bfb4-91fca6ca6373', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-11 17:05:55.198+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-18 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f920cc0b-576b-469e-9c62-9cafdc1fd20c', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('197a4b57-552c-457c-a8e3-f2600c6110c1', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 17:05:55.198+00', '2026-10-13 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('896e6dfa-de3b-46ac-a14b-0dca07fd5268', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f6d93247-793c-4641-853e-a2e3f8830faf', 'signage_item', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.129888+00', '2026-10-14 17:05:56.129888+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('238c8fb1-9c12-4dc9-bc04-17f0571ec597', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, '4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 3, false, '487d2141-0a83-4584-ba8f-060ce68ff60b', NULL);
INSERT INTO public.approval_instances VALUES ('3a91628d-fc58-4d09-965e-50d6f4158926', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, 'd3568630-40e4-49ed-a992-61bb47b8b5e5', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 3, false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', NULL);
INSERT INTO public.approval_instances VALUES ('896edb56-8108-4a0a-8e0b-f2b65e003225', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, '1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 17:05:55.198+00', '2026-10-14 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 5, false, '4970456a-b42d-440a-bbdb-295f4a9d1a97', NULL);
INSERT INTO public.approval_instances VALUES ('f05904ec-c6da-4b02-af69-b3bf1d8d70ac', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, 'c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('608cc318-c65f-4113-b545-90bc98d3e94f', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, 'fdae766c-4d89-4d88-9920-32d2d7106332', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 3, false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7', NULL);
INSERT INTO public.approval_instances VALUES ('805254e8-6d17-4782-81f6-b5796064c545', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, '00731f33-3de3-4fb2-ae74-6082a27b702d', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a6ef9236-17ca-432c-b3b3-19e0e4a5fa47', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, '63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('62902f71-252d-4ed5-afb1-567feac2e751', 'signage_item', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, '62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.151195+00', '2026-10-14 17:05:56.151195+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fc0e2f1a-e4dc-4002-83a1-ea8e6c171b08', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, '909a0d35-077d-4f26-b54c-681d91f1f71b', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-08 17:05:55.198+00', '2026-10-11 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5f1d14af-ca49-4666-bfdd-07bd824dd3a1', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, '16d0f82a-3863-4283-9aa9-e5b93bc14813', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 17:05:55.198+00', '2026-10-17 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5d705485-7ade-4b4b-8816-f14c505fcfe9', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, '15e89103-82f8-4933-ab42-db80135efc23', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1e8a0555-9682-4bff-9573-8545093df0b2', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, 'cc5579a7-e540-4f0d-a914-0ce5049d798d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f8980321-e7fe-4b31-80cb-4af0c8d561f4', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, 'e971109d-794c-4178-b4c7-018af2172445', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e364e8e7-b066-4835-816b-2c838336d3e3', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 1, '237f96af-3a03-4830-8bcd-1aa39daf15ae', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7e0cc2bb-4a0c-465c-b365-c151c12e169b', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, '909a0d35-077d-4f26-b54c-681d91f1f71b', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 17:05:55.198+00', '2026-10-11 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c6b0001f-4932-4121-8895-59797fcf3401', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, '16d0f82a-3863-4283-9aa9-e5b93bc14813', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c7081837-7a25-4889-81bb-888a58dd2c12', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, '15e89103-82f8-4933-ab42-db80135efc23', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d4cccfbd-4e1b-4d1e-8942-e12eb4cea782', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, 'cc5579a7-e540-4f0d-a914-0ce5049d798d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f87d5e86-b3e8-453c-b606-d3371b6271ea', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, 'e971109d-794c-4178-b4c7-018af2172445', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('59032f47-b3bc-41d0-949e-f54fa5180c90', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 1, '237f96af-3a03-4830-8bcd-1aa39daf15ae', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fd5e8a68-a4cd-46a0-9299-a765fde3ff32', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, '909a0d35-077d-4f26-b54c-681d91f1f71b', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-08 17:05:55.198+00', '2026-10-11 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('72ad1954-bfe9-4429-a683-db362edd219e', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, '16d0f82a-3863-4283-9aa9-e5b93bc14813', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b3ea7ff-8549-4bee-a25d-b3f4af722462', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, '15e89103-82f8-4933-ab42-db80135efc23', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0369fade-f158-4aa9-8295-d95e966a04a4', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, 'cc5579a7-e540-4f0d-a914-0ce5049d798d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('167d6a2d-a75a-4084-ab25-bec5d9455b9e', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, 'e971109d-794c-4178-b4c7-018af2172445', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d4454d26-5f4b-4a02-9865-0951b273a8e0', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 1, '237f96af-3a03-4830-8bcd-1aa39daf15ae', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('07ffeaf3-fee4-48ed-ad12-e345a0574412', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, '909a0d35-077d-4f26-b54c-681d91f1f71b', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-08 17:05:55.198+00', '2026-10-11 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e4836a56-7b5f-4913-86df-35ce1093d300', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, '16d0f82a-3863-4283-9aa9-e5b93bc14813', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bcad9834-8700-4abb-8080-87572f7820dc', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, '15e89103-82f8-4933-ab42-db80135efc23', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-15 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8fbf8e0e-bd16-4227-a681-e42edffae5b4', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, 'cc5579a7-e540-4f0d-a914-0ce5049d798d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-17 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('403f55bf-b1a1-45ee-ab5c-1e87f5ff5946', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, 'e971109d-794c-4178-b4c7-018af2172445', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('809ae075-0369-4535-9d77-88d1374a7d59', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 1, '237f96af-3a03-4830-8bcd-1aa39daf15ae', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 17:05:55.198+00', NULL, 0, NULL, NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('94bf2b2a-4d11-4da3-a0ca-1425e6e78279', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, '909a0d35-077d-4f26-b54c-681d91f1f71b', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-08 17:05:55.198+00', '2026-10-11 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5095d5ed-2453-42a0-8cf3-a863e4ef66e0', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, '16d0f82a-3863-4283-9aa9-e5b93bc14813', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('00770715-d423-4067-b10a-75c78f9927fd', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, '15e89103-82f8-4933-ab42-db80135efc23', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-15 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('66137bdd-22c4-4f31-8985-522e41b1238d', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, 'cc5579a7-e540-4f0d-a914-0ce5049d798d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-17 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3907d2ea-99f1-464c-b54e-ec016d71cb62', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, 'e971109d-794c-4178-b4c7-018af2172445', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-10 17:05:55.198+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 17:05:55.198+00', '2026-10-12 17:05:55.198+00', 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2e276ba0-e85f-411c-a26a-168894fb038e', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 1, '237f96af-3a03-4830-8bcd-1aa39daf15ae', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 17:05:55.198+00', NULL, 0, NULL, NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('b7c199c3-8555-4178-950f-88242baffc0d', '3c2810bc-2937-44fa-8d58-29896c2b1b67', '487d2141-0a83-4584-ba8f-060ce68ff60b', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-14 17:05:55.447014+00', '2026-10-14 17:05:55.447014+00');
INSERT INTO public.approvers VALUES ('439df6c7-abf7-4d2c-986a-f698d9bce44e', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'abdaac3c-a9d1-4ee9-9610-a472c328dc96', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-14 17:05:55.453685+00', '2026-10-14 17:05:55.453685+00');
INSERT INTO public.approvers VALUES ('0114b348-d31c-47d9-9c10-8b07299abb1a', '3c2810bc-2937-44fa-8d58-29896c2b1b67', '4970456a-b42d-440a-bbdb-295f4a9d1a97', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-14 17:05:55.458554+00', '2026-10-14 17:05:55.458554+00');
INSERT INTO public.approvers VALUES ('a79145aa-baf1-4f16-971b-9c9dba8b231b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', '43af81e3-3536-4415-8c70-0e06e0c9f8c7', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-14 17:05:55.463283+00', '2026-10-14 17:05:55.463283+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('5aab9c63-9bb0-426c-9eeb-06860e745952', 'd4125595-2e8c-4ede-a78d-fb95f90af256', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.5958+00', '2026-10-14 17:05:55.5958+00');
INSERT INTO public.artwork_versions VALUES ('7883b81a-09c6-42cd-a414-4f5c92a600f1', '37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.620243+00', '2026-10-14 17:05:55.620243+00');
INSERT INTO public.artwork_versions VALUES ('ef8b788b-9428-4c30-9142-acea74b13a12', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-14 17:05:55.646851+00', '2026-10-14 17:05:55.646851+00');
INSERT INTO public.artwork_versions VALUES ('25c87f5c-48e6-42db-835b-59d9444e90a9', 'a149db80-6c4a-4c46-9b02-d9b6b952915f', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.648535+00', '2026-10-14 17:05:55.648535+00');
INSERT INTO public.artwork_versions VALUES ('921ce11a-e03b-4c1e-a30d-e4cff328c243', '0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.678338+00', '2026-10-14 17:05:55.678338+00');
INSERT INTO public.artwork_versions VALUES ('cfcd02cb-c657-4d1d-a91e-0fcecf826067', '65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.706769+00', '2026-10-14 17:05:55.706769+00');
INSERT INTO public.artwork_versions VALUES ('a5b8c1bb-28ff-4639-8065-6849ae12e126', '7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.734225+00', '2026-10-14 17:05:55.734225+00');
INSERT INTO public.artwork_versions VALUES ('db0469a0-c9a4-4c6e-8c69-cb7d131e503d', '065556ac-e235-49d8-9d0a-1f4a975a961b', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.75407+00', '2026-10-14 17:05:55.75407+00');
INSERT INTO public.artwork_versions VALUES ('4be7b3a9-b28a-4b53-b6aa-b873f57d9daf', '916641f0-6f23-419c-a20d-eee28797116a', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.781003+00', '2026-10-14 17:05:55.781003+00');
INSERT INTO public.artwork_versions VALUES ('193affdb-02bd-4fbf-9647-f22fa9039d78', '9a6f539e-c74b-45fc-a90c-237007e951c1', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.803894+00', '2026-10-14 17:05:55.803894+00');
INSERT INTO public.artwork_versions VALUES ('2420f6f6-3c09-4b48-bdde-a21f00b5dffa', '2b523122-f192-4229-98af-b57204cef7a2', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.827536+00', '2026-10-14 17:05:55.827536+00');
INSERT INTO public.artwork_versions VALUES ('6d6d1904-a295-4590-8b38-e2859dbc8e5b', 'b60ba07c-31a4-4302-aedd-ed1ca6f46573', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.851701+00', '2026-10-14 17:05:55.851701+00');
INSERT INTO public.artwork_versions VALUES ('b1193bed-97a6-4794-96a8-130fbc9b8477', 'ae926bc8-f847-4bdf-9ef1-df21da2eab63', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.872638+00', '2026-10-14 17:05:55.872638+00');
INSERT INTO public.artwork_versions VALUES ('85151035-c753-45ca-b6bf-018c8450b6d2', '25b1f195-7e4c-4076-8ac1-373e816e4565', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.89132+00', '2026-10-14 17:05:55.89132+00');
INSERT INTO public.artwork_versions VALUES ('c062b691-a757-4ef1-bdc5-f5767ac4c578', '3992d443-508c-41a2-9672-27de1a421042', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.912139+00', '2026-10-14 17:05:55.912139+00');
INSERT INTO public.artwork_versions VALUES ('09ec3c02-3476-4242-881b-8b2d42cd05cf', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.939245+00', '2026-10-14 17:05:55.939245+00');
INSERT INTO public.artwork_versions VALUES ('c286892b-9429-45e2-9175-21fbc1fb92d8', '5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:55.961174+00', '2026-10-14 17:05:55.961174+00');
INSERT INTO public.artwork_versions VALUES ('8a0f6b2c-b2c6-4739-b0ab-1bcae5b0fb0f', 'cadf7910-5a99-4fcb-a36c-700262fe4562', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:55.983122+00', '2026-10-14 17:05:55.983122+00');
INSERT INTO public.artwork_versions VALUES ('5fab755f-a659-4227-ac8d-4f5a50896b4b', '8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:56.00583+00', '2026-10-14 17:05:56.00583+00');
INSERT INTO public.artwork_versions VALUES ('8c625fcf-51a4-43c7-9b1c-ab868da662e8', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-14 17:05:56.033298+00', '2026-10-14 17:05:56.033298+00');
INSERT INTO public.artwork_versions VALUES ('1d1a0225-e1e2-442a-82cf-366ba97c65e8', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-14 17:05:56.035085+00', '2026-10-14 17:05:56.035085+00');
INSERT INTO public.artwork_versions VALUES ('3e29735a-1104-4729-bf64-3d56939452e0', '5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:56.037127+00', '2026-10-14 17:05:56.037127+00');
INSERT INTO public.artwork_versions VALUES ('924e34da-5e6d-4aab-8c40-4c62a908624d', 'ebb7d725-e670-4dd6-b9dd-e5bab8103297', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-14 17:05:56.107369+00', '2026-10-14 17:05:56.107369+00');
INSERT INTO public.artwork_versions VALUES ('eef42d9a-ee4a-49f3-9aaf-e3096992d767', '2ae53606-0c9e-4278-bd1f-97e9c79029d6', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:56.126999+00', '2026-10-14 17:05:56.126999+00');
INSERT INTO public.artwork_versions VALUES ('5c8b4451-3a5d-4ea9-a404-401b6b7cc2b0', 'a46313b0-dad0-443a-b0da-36bebaefcc14', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-14 17:05:56.148418+00', '2026-10-14 17:05:56.148418+00');


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

INSERT INTO public.contractors VALUES ('8a959999-539e-4515-84e8-45a4841d6ba4', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-14 17:05:55.40476+00', '2026-10-14 17:05:55.40476+00');
INSERT INTO public.contractors VALUES ('263cc533-ac80-4be5-aac8-a1e035804f10', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-14 17:05:55.407727+00', '2026-10-14 17:05:55.407727+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('487d2141-0a83-4584-ba8f-060ce68ff60b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-14 17:05:55.443792+00', '2026-10-14 17:05:55.443792+00', true);
INSERT INTO public.departments VALUES ('abdaac3c-a9d1-4ee9-9610-a472c328dc96', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-14 17:05:55.450772+00', '2026-10-14 17:05:55.450772+00', true);
INSERT INTO public.departments VALUES ('4970456a-b42d-440a-bbdb-295f4a9d1a97', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Sales', 3, false, '{sponsor}', false, '2026-10-14 17:05:55.456351+00', '2026-10-14 17:05:55.456351+00', true);
INSERT INTO public.departments VALUES ('43af81e3-3536-4415-8c70-0e06e0c9f8c7', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-14 17:05:55.46137+00', '2026-10-14 17:05:55.46137+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('b5d48c70-079f-4522-85a0-2b2d3865a94a', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00');
INSERT INTO public.documents VALUES ('8209ed52-76ba-4800-838d-7fced028b39b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00');
INSERT INTO public.documents VALUES ('4ac92cf6-2193-4963-b630-d2e63f8903e0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00');
INSERT INTO public.documents VALUES ('a21fca39-e248-43fb-af3c-4d354ca28653', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00');
INSERT INTO public.documents VALUES ('ef9f03b2-06f0-4aaf-bb26-5bc5bd334671', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00');
INSERT INTO public.documents VALUES ('a573d8b5-a4e9-4e29-b616-47a85614d676', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00');
INSERT INTO public.documents VALUES ('072a9f31-70d1-48b1-8583-0c026dfd1b19', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00');
INSERT INTO public.documents VALUES ('0ad51d8d-3fed-4f09-9df3-23dcf8898758', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00');
INSERT INTO public.documents VALUES ('465907e6-7b00-4155-b55f-f5918dc94a3b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00');
INSERT INTO public.documents VALUES ('30dd97d9-40e7-424e-aae6-518673ee789b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00');
INSERT INTO public.documents VALUES ('142e664f-3de0-40e3-b832-e01ff385ef89', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00');
INSERT INTO public.documents VALUES ('cca52a8d-e708-4c4a-8290-565834c71fb0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '5e114857-8acb-4964-810e-94c89eb9fd98', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00');
INSERT INTO public.documents VALUES ('92be70df-0ecb-49a7-9489-d0601f553805', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00');
INSERT INTO public.documents VALUES ('ac73287e-cb31-4381-83c8-405bc2dcf1dc', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00');
INSERT INTO public.documents VALUES ('2f9691de-2335-4dee-b3c2-b006264f81f0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00');
INSERT INTO public.documents VALUES ('d9dbb812-534c-4eb2-8b50-16e86b7e6878', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', '223188e5-fd24-423d-8ed8-3903af528f8c', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00');
INSERT INTO public.documents VALUES ('00de773b-8be9-49a6-8e32-c1cf0a8fc043', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00');
INSERT INTO public.documents VALUES ('b07a0b7b-386c-41ea-aa3a-7a8ea5fdf684', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00');
INSERT INTO public.documents VALUES ('0a8b0d6f-b3a0-438f-bd41-c2ac80800b49', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00');
INSERT INTO public.documents VALUES ('3c4451c6-18cb-4cad-837f-f0c966d68ce0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_submission', 'f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('057baaab-b81b-403f-8a23-865238e465e2', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'signage', 34, '2026-10-14 17:05:56.179816+00', '2026-10-14 17:05:56.181676+00');
INSERT INTO public.edition_counters VALUES ('8fa41821-c48a-45c9-a4a4-9b3bf20428eb', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_design', 1, '2026-10-14 17:05:56.214543+00', '2026-10-14 17:05:56.214543+00');
INSERT INTO public.edition_counters VALUES ('a5684cec-1f4c-4a18-9711-27929ecc1fc7', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_item', 1, '2026-10-14 17:05:56.214543+00', '2026-10-14 17:05:56.214543+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('a0e6ceb9-0db8-4771-91bd-efab5450de79', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-14 17:05:55.309511+00', '2026-10-14 17:05:55.309511+00');
INSERT INTO public.edition_deadlines VALUES ('29793891-c40d-45ec-b99a-357a80b1aa64', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-14 17:05:55.311711+00', '2026-10-14 17:05:55.311711+00');
INSERT INTO public.edition_deadlines VALUES ('1c24dffc-1624-40d7-b10e-093da29a70f8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-14 17:05:55.313284+00', '2026-10-14 17:05:55.313284+00');
INSERT INTO public.edition_deadlines VALUES ('ada082b7-22d8-4fc2-b6a7-a360af3ae241', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-14 17:05:55.314833+00', '2026-10-14 17:05:55.314833+00');
INSERT INTO public.edition_deadlines VALUES ('bd445b16-ae44-400b-ae75-7748857dd6f8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-14 17:05:55.316396+00', '2026-10-14 17:05:55.316396+00');
INSERT INTO public.edition_deadlines VALUES ('b7bad798-ab8c-42fc-9565-5d5073d9f9c9', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-14 17:05:55.318021+00', '2026-10-14 17:05:55.318021+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'e4bf2a4d-319a-4d6f-980f-0548cd5d9379', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-14 17:05:55.30607+00', '2026-10-14 17:05:55.30607+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('e4bf2a4d-319a-4d6f-980f-0548cd5d9379', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'UK Construction Week', 'UKCW', '2026-10-14 17:05:55.269855+00', '2026-10-14 17:05:55.269855+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('91f17fa3-b5c1-4e7f-9cb2-3faf4e873b97', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Exhibitor Co', 'A10', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '8a959999-539e-4515-84e8-45a4841d6ba4', '2026-10-14 17:05:55.552686+00', '2026-10-14 17:05:55.552686+00');
INSERT INTO public.exhibitors VALUES ('a8efdbcd-9cba-4dde-97db-367cff72836a', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SteelFrame Systems', 'A20', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '263cc533-ac80-4be5-aac8-a1e035804f10', '2026-10-14 17:05:55.556295+00', '2026-10-14 17:05:55.556295+00');
INSERT INTO public.exhibitors VALUES ('49d1e298-f171-4200-a149-55fc098f74e9', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'BrickWorks UK', 'A30', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '8a959999-539e-4515-84e8-45a4841d6ba4', '2026-10-14 17:05:55.559722+00', '2026-10-14 17:05:55.559722+00');
INSERT INTO public.exhibitors VALUES ('6b6fedf7-5c24-4431-8be3-9affb6a13395', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Timber Trade Ltd', 'B10', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '263cc533-ac80-4be5-aac8-a1e035804f10', '2026-10-14 17:05:55.562656+00', '2026-10-14 17:05:55.562656+00');
INSERT INTO public.exhibitors VALUES ('c51ddfa6-f880-4a82-bb96-59b404b55203', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'GlassTech', 'B20', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '8a959999-539e-4515-84e8-45a4841d6ba4', '2026-10-14 17:05:55.565353+00', '2026-10-14 17:05:55.565353+00');
INSERT INTO public.exhibitors VALUES ('27f9347b-b01d-4586-aca3-2b1f3a6aa885', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Insulate Pro', 'B30', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '263cc533-ac80-4be5-aac8-a1e035804f10', '2026-10-14 17:05:55.56771+00', '2026-10-14 17:05:55.56771+00');
INSERT INTO public.exhibitors VALUES ('e6331947-728a-4067-82be-d2b6e3ebd0b5', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'RoofRight', 'C10', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '8a959999-539e-4515-84e8-45a4841d6ba4', '2026-10-14 17:05:55.570375+00', '2026-10-14 17:05:55.570375+00');
INSERT INTO public.exhibitors VALUES ('a0ef36af-4b02-4ff7-8e65-2354ef295f12', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'PlantHire Direct', 'C20', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '263cc533-ac80-4be5-aac8-a1e035804f10', '2026-10-14 17:05:55.572884+00', '2026-10-14 17:05:55.572884+00');
INSERT INTO public.exhibitors VALUES ('a885dc35-4a1a-4866-82cf-fb7e9836ce61', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SafetyFirst PPE', 'D10', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-14 17:05:55.574964+00', '2026-10-14 17:05:55.574964+00');
INSERT INTO public.exhibitors VALUES ('8d1d2e8e-1d27-4063-a5af-e8c525fb13a3', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'ToolMart Retail', 'D20', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-14 17:05:55.57768+00', '2026-10-14 17:05:55.57768+00');
INSERT INTO public.exhibitors VALUES ('e41b3ebe-d4e9-4401-a360-f6a68e241a69', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'EcoBuild Materials', 'D30', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-14 17:05:55.579817+00', '2026-10-14 17:05:55.579817+00');
INSERT INTO public.exhibitors VALUES ('e9dbf7a8-e2b4-442d-a914-2555af0359e7', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SiteWise Software', 'D40', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-14 17:05:55.58251+00', '2026-10-14 17:05:55.58251+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('ed217dd0-bf4a-4aa1-bd93-49190180f4cb', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'venue', 'venue', '926ffa9a-af16-4763-b157-d7c2b80fff9c', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.532637+00', '2026-10-14 17:05:55.532637+00');
INSERT INTO public.external_grants VALUES ('ff82bf25-a50a-4e23-a229-2f5f3db6a6d5', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.539884+00', '2026-10-14 17:05:55.539884+00');
INSERT INTO public.external_grants VALUES ('00bf1e71-47a5-4878-95f4-af1b30cbe750', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.543252+00', '2026-10-14 17:05:55.543252+00');
INSERT INTO public.external_grants VALUES ('2c4151cd-0123-4ca8-b4a1-803ecdf12779', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'supplier', 'supplier', 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.546478+00', '2026-10-14 17:05:55.546478+00');
INSERT INTO public.external_grants VALUES ('1c210326-bcc6-4bc9-8efd-9308bc4f85e9', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'sponsor', 'sponsor', '90aa07a6-7ede-45bb-978a-8f9ecf050424', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.549285+00', '2026-10-14 17:05:55.549285+00');
INSERT INTO public.external_grants VALUES ('3cf7f394-f600-4317-be0f-9b2e5d075f61', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'exhibitor', 'exhibitor', '91f17fa3-b5c1-4e7f-9cb2-3faf4e873b97', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-14 17:05:55.198+00', NULL, '2026-10-14 17:05:55.58583+00', '2026-10-14 17:05:55.58583+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-14 17:05:55.321497+00', '2026-10-14 17:05:55.321497+00');
INSERT INTO public.halls VALUES ('7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-14 17:05:55.325023+00', '2026-10-14 17:05:55.325023+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('38382239-e25d-4b88-810c-1040ee0371b0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Hanging banner', 'hanging_banner', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'rigged', true, 0, '2026-10-14 17:05:55.495593+00', '2026-10-14 17:05:55.495593+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a7aa482d-50fa-4df6-ae28-57023e736f6b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Foamex board', 'foamex_board', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'wall_mounted', false, 1, '2026-10-14 17:05:55.498916+00', '2026-10-14 17:05:55.498916+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4927648c-ea6d-4329-9963-2e467c424532', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Fabric graphic', 'fabric_graphic', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'shell_mounted', false, 2, '2026-10-14 17:05:55.502694+00', '2026-10-14 17:05:55.502694+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('57355874-dccd-49c0-bd7c-b10fbdf1ddc5', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Floor vinyl', 'floor_vinyl', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'floor', false, 3, '2026-10-14 17:05:55.504305+00', '2026-10-14 17:05:55.504305+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('39452851-cb20-4519-9a2a-accd5f87e54b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Aisle sign', 'aisle_sign', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'rigged', true, 4, '2026-10-14 17:05:55.506067+00', '2026-10-14 17:05:55.506067+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('8f5184a4-f55f-46f5-8882-3c2a69f8662a', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Entrance feature', 'entrance_feature', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'freestanding', true, 5, '2026-10-14 17:05:55.507839+00', '2026-10-14 17:05:55.507839+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('62e7c41f-f1f0-4ca8-8434-32e8987495c0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Registration', 'registration', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'freestanding', false, 6, '2026-10-14 17:05:55.509616+00', '2026-10-14 17:05:55.509616+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d1420fa0-2b03-4225-9f64-6adc4411b9a3', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Seminar theatre', 'seminar_theatre', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'freestanding', false, 7, '2026-10-14 17:05:55.511268+00', '2026-10-14 17:05:55.511268+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e2e9951f-dcbc-4728-ab16-48dd2b073614', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Feature area', 'feature_area', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'freestanding', false, 8, '2026-10-14 17:05:55.512774+00', '2026-10-14 17:05:55.512774+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4fff17ca-75de-4f87-855b-d24d2a47d07b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'External', 'external', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'freestanding', true, 9, '2026-10-14 17:05:55.514366+00', '2026-10-14 17:05:55.514366+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4985a904-e40e-48b5-8b36-eb1b5df5c121', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Digital screen', 'digital_screen', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 'digital', false, 10, '2026-10-14 17:05:55.515953+00', '2026-10-14 17:05:55.515953+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('d58172df-afda-48f6-8e94-7e3e762e1c6b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Branded lanyards', 'lanyard', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', NULL, false, 11, '2026-10-14 17:05:55.517428+00', '2026-10-14 17:05:55.517428+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('0004006c-fddc-482d-81d0-81f3ce0702ed', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Show bags', 'show_bag', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', NULL, false, 12, '2026-10-14 17:05:55.518783+00', '2026-10-14 17:05:55.518783+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('4f99116c-01c2-4044-af63-f4942d18e707', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Registration branding', 'reg_branding', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', NULL, false, 13, '2026-10-14 17:05:55.520535+00', '2026-10-14 17:05:55.520535+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('7c6d654f-97cc-41d7-af63-caf9b676f710', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Other signage', 'other_signage', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', NULL, false, 14, '2026-10-14 17:05:55.522115+00', '2026-10-14 17:05:55.522115+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('6145a1bd-a55b-4089-a3a3-ce476a75afed', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Other sponsorship item', 'other_sponsorship', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', NULL, false, 15, '2026-10-14 17:05:55.523551+00', '2026-10-14 17:05:55.523551+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('d91b1860-1d5a-4f47-92d4-80120285be1d', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-14 17:05:55.330984+00', '2026-10-14 17:05:55.330984+00');
INSERT INTO public.locations VALUES ('e752b229-5298-4805-91f9-83599054dc96', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-14 17:05:55.335516+00', '2026-10-14 17:05:55.335516+00');
INSERT INTO public.locations VALUES ('ed5e0907-864f-4ff8-b518-e7f395bd0749', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-14 17:05:55.338924+00', '2026-10-14 17:05:55.338924+00');
INSERT INTO public.locations VALUES ('a385eb07-c38b-4fb6-81ec-a9d14c85096f', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-14 17:05:55.341796+00', '2026-10-14 17:05:55.341796+00');
INSERT INTO public.locations VALUES ('1bddc5ea-1980-4bbe-ae21-1d7ab841b6c2', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-14 17:05:55.344249+00', '2026-10-14 17:05:55.344249+00');
INSERT INTO public.locations VALUES ('a5cfcccc-7668-4842-88c9-e35402506db3', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-14 17:05:55.346716+00', '2026-10-14 17:05:55.346716+00');
INSERT INTO public.locations VALUES ('5afe1bc5-25c9-4113-bd2b-e38510a52849', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-14 17:05:55.349065+00', '2026-10-14 17:05:55.349065+00');
INSERT INTO public.locations VALUES ('03612b8f-18aa-428f-8b8f-afde4cf460b8', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-14 17:05:55.351679+00', '2026-10-14 17:05:55.351679+00');
INSERT INTO public.locations VALUES ('a536da46-214f-4134-a3b7-d53df4fd90c7', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-14 17:05:55.354446+00', '2026-10-14 17:05:55.354446+00');
INSERT INTO public.locations VALUES ('b693f656-b86c-42db-a885-499431239644', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-14 17:05:55.35677+00', '2026-10-14 17:05:55.35677+00');
INSERT INTO public.locations VALUES ('4d5e65e0-8763-49b6-90fb-a49e0b633375', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-14 17:05:55.359468+00', '2026-10-14 17:05:55.359468+00');
INSERT INTO public.locations VALUES ('15ef4a51-b04f-4eaa-91ca-376f334795c2', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-14 17:05:55.362282+00', '2026-10-14 17:05:55.362282+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('8b446f06-05de-4efd-a642-b1a8f3804e9c', '00000000-0000-4000-8000-000000000001', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'admin', '2026-10-14 17:05:55.246276+00', '2026-10-14 17:05:55.246276+00', '{}', NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('c2d9f5cb-7c97-4dce-9832-3a6d48504a57', '00000000-0000-4000-8000-000000000002', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'ops', '2026-10-14 17:05:55.252026+00', '2026-10-14 17:05:55.252026+00', '{}', NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('2e02bcf2-5d13-4e9d-ad33-1665a6177549', '00000000-0000-4000-8000-000000000004', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'sales', '2026-10-14 17:05:55.260497+00', '2026-10-14 17:05:55.260497+00', '{}', NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('9a93f4a6-dc03-48b0-b74f-38df2614d293', '00000000-0000-4000-8000-000000000005', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'event_director', '2026-10-14 17:05:55.264427+00', '2026-10-14 17:05:55.264427+00', '{}', NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('07772106-80c9-41cd-bd48-0060eedd06d5', '00000000-0000-4000-8000-000000000006', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'viewer', '2026-10-14 17:05:55.267805+00', '2026-10-14 17:05:55.267805+00', '{}', NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('16b9bd50-3ab7-45bf-99bb-8a26a9aebe8d', '00000000-0000-4000-8000-000000000003', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'marketing', '2026-10-14 17:05:55.25607+00', '2026-10-14 17:05:56.325384+00', '{"costs.edit": true}', NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-14 17:05:55.238634+00', '2026-10-14 17:05:55.238634+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('d4125595-2e8c-4ede-a78d-fb95f90af256', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '8f5184a4-f55f-46f5-8882-3c2a69f8662a', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'd91b1860-1d5a-4f47-92d4-80120285be1d', 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', '00e311e1-548b-4cc4-9990-58e422db647e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '5aab9c63-9bb0-426c-9eeb-06860e745952', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.590953+00', '2026-10-14 17:05:55.597911+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('37fb0353-38f3-41e4-8a4c-3b470f7da2dd', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '62e7c41f-f1f0-4ca8-8434-32e8987495c0', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'e752b229-5298-4805-91f9-83599054dc96', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '7883b81a-09c6-42cd-a414-4f5c92a600f1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.617843+00', '2026-10-14 17:05:55.621999+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a149db80-6c4a-4c46-9b02-d9b6b952915f', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '38382239-e25d-4b88-810c-1040ee0371b0', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'ed5e0907-864f-4ff8-b518-e7f395bd0749', 'ops', '00000000-0000-4000-8000-000000000002', '90aa07a6-7ede-45bb-978a-8f9ecf050424', 'ecfb506c-e2bd-4cfa-8a40-5f0192f87b9e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '25c87f5c-48e6-42db-835b-59d9444e90a9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.64425+00', '2026-10-14 17:05:55.65284+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0253463a-3aaa-44a9-b3d1-7c2a846ddef8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'd1420fa0-2b03-4225-9f64-6adc4411b9a3', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'a385eb07-c38b-4fb6-81ec-a9d14c85096f', 'marketing', '00000000-0000-4000-8000-000000000003', '2f3c871a-5496-42a5-bdc1-442a011ceb75', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '921ce11a-e03b-4c1e-a30d-e4cff328c243', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.675842+00', '2026-10-14 17:05:55.679596+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('65cff1ac-b8eb-479c-8ef4-88f8edbf82c0', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '57355874-dccd-49c0-bd7c-b10fbdf1ddc5', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', '1bddc5ea-1980-4bbe-ae21-1d7ab841b6c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'cfcd02cb-c657-4d1d-a91e-0fcecf826067', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.703008+00', '2026-10-14 17:05:55.70858+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7d51e6b5-2d60-4fd8-85d2-8fae333dd557', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', 'e2e9951f-dcbc-4728-ab16-48dd2b073614', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'a5cfcccc-7668-4842-88c9-e35402506db3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'a5b8c1bb-28ff-4639-8065-6849ae12e126', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.731303+00', '2026-10-14 17:05:55.73579+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "fdae766c-4d89-4d88-9920-32d2d7106332", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('065556ac-e235-49d8-9d0a-1f4a975a961b', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '38382239-e25d-4b88-810c-1040ee0371b0', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '5afe1bc5-25c9-4113-bd2b-e38510a52849', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'db0469a0-c9a4-4c6e-8c69-cb7d131e503d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.751937+00', '2026-10-14 17:05:55.755502+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('916641f0-6f23-419c-a20d-eee28797116a', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '39452851-cb20-4519-9a2a-accd5f87e54b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '03612b8f-18aa-428f-8b8f-afde4cf460b8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '4be7b3a9-b28a-4b53-b6aa-b873f57d9daf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.778734+00', '2026-10-14 17:05:55.78259+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9a6f539e-c74b-45fc-a90c-237007e951c1', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'd1420fa0-2b03-4225-9f64-6adc4411b9a3', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'a536da46-214f-4134-a3b7-d53df4fd90c7', 'marketing', '00000000-0000-4000-8000-000000000003', '2f3c871a-5496-42a5-bdc1-442a011ceb75', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '193affdb-02bd-4fbf-9647-f22fa9039d78', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.801461+00', '2026-10-14 17:05:55.805818+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2b523122-f192-4229-98af-b57204cef7a2', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '4927648c-ea6d-4329-9963-2e467c424532', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'b693f656-b86c-42db-a885-499431239644', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '2420f6f6-3c09-4b48-bdde-a21f00b5dffa', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.824997+00', '2026-10-14 17:05:55.829164+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b60ba07c-31a4-4302-aedd-ed1ca6f46573', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '4fff17ca-75de-4f87-855b-d24d2a47d07b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '4d5e65e0-8763-49b6-90fb-a49e0b633375', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '6d6d1904-a295-4590-8b38-e2859dbc8e5b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.848961+00', '2026-10-14 17:05:55.853432+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ae926bc8-f847-4bdf-9ef1-df21da2eab63', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '15ef4a51-b04f-4eaa-91ca-376f334795c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'b1193bed-97a6-4794-96a8-130fbc9b8477', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.870336+00', '2026-10-14 17:05:55.874173+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('25b1f195-7e4c-4076-8ac1-373e816e4565', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '4985a904-e40e-48b5-8b36-eb1b5df5c121', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'e752b229-5298-4805-91f9-83599054dc96', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '633b8c09-14e5-4ef0-8278-7a362b6118ee', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '85151035-c753-45ca-b6bf-018c8450b6d2', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.889099+00', '2026-10-14 17:05:55.892429+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "fdae766c-4d89-4d88-9920-32d2d7106332", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3992d443-508c-41a2-9672-27de1a421042', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '39452851-cb20-4519-9a2a-accd5f87e54b', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'ed5e0907-864f-4ff8-b518-e7f395bd0749', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'c062b691-a757-4ef1-bdc5-f5767ac4c578', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.910049+00', '2026-10-14 17:05:55.913889+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8f48325a-4933-4e1a-a58b-1bba355ebcc6', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', '1bddc5ea-1980-4bbe-ae21-1d7ab841b6c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '09ec3c02-3476-4242-881b-8b2d42cd05cf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.937139+00', '2026-10-14 17:05:55.940533+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5d6607ac-f808-42ab-b5d3-e7bdedeb2119', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', 'e2e9951f-dcbc-4728-ab16-48dd2b073614', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'a5cfcccc-7668-4842-88c9-e35402506db3', 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'c286892b-9429-45e2-9175-21fbc1fb92d8', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.958792+00', '2026-10-14 17:05:55.962589+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('cadf7910-5a99-4fcb-a36c-700262fe4562', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '38382239-e25d-4b88-810c-1040ee0371b0', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '03612b8f-18aa-428f-8b8f-afde4cf460b8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '8a0f6b2c-b2c6-4739-b0ab-1bcae5b0fb0f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:55.980461+00', '2026-10-14 17:05:55.984583+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8a853cb1-06f6-495f-ac99-7b5f591d0bb5', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '4927648c-ea6d-4329-9963-2e467c424532', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'b693f656-b86c-42db-a885-499431239644', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '5fab755f-a659-4227-ac8d-4f5a50896b4b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.003317+00', '2026-10-14 17:05:56.007973+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5d76b1e8-9963-4c19-8919-dfd73ef5ffa4', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '38382239-e25d-4b88-810c-1040ee0371b0', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'ed5e0907-864f-4ff8-b518-e7f395bd0749', 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', 'ecfb506c-e2bd-4cfa-8a40-5f0192f87b9e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '3e29735a-1104-4729-bf64-3d56939452e0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.030608+00', '2026-10-14 17:05:56.03896+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2c2f35f6-725e-417d-98b7-5793e9f1b7d7', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '15ef4a51-b04f-4eaa-91ca-376f334795c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.065521+00', '2026-10-14 17:05:56.065521+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9035c063-79e7-4d35-a251-1f52b80812ef', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'e752b229-5298-4805-91f9-83599054dc96', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.073411+00', '2026-10-14 17:05:56.073411+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6ff2324d-5f64-41d2-9283-fb7049eb13a3', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '62e7c41f-f1f0-4ca8-8434-32e8987495c0', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '5afe1bc5-25c9-4113-bd2b-e38510a52849', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.078386+00', '2026-10-14 17:05:56.078386+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('78120e3d-cbec-470a-ba5b-6b982840d571', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '4985a904-e40e-48b5-8b36-eb1b5df5c121', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'a5cfcccc-7668-4842-88c9-e35402506db3', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '633b8c09-14e5-4ef0-8278-7a362b6118ee', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.083724+00', '2026-10-14 17:05:56.083724+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "fdae766c-4d89-4d88-9920-32d2d7106332", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('26e61868-f6df-4d55-85f8-8dba025643ee', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '57355874-dccd-49c0-bd7c-b10fbdf1ddc5', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'a536da46-214f-4134-a3b7-d53df4fd90c7', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.087984+00', '2026-10-14 17:05:56.087984+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ba8bbcc4-119e-4c98-9e74-af73f78cc874', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'd1420fa0-2b03-4225-9f64-6adc4411b9a3', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', 'a536da46-214f-4134-a3b7-d53df4fd90c7', 'marketing', '00000000-0000-4000-8000-000000000003', '2f3c871a-5496-42a5-bdc1-442a011ceb75', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.092179+00', '2026-10-14 17:05:56.092179+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6dccfc80-13a6-4d96-9b25-eca59934eca8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '4fff17ca-75de-4f87-855b-d24d2a47d07b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '4d5e65e0-8763-49b6-90fb-a49e0b633375', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.096515+00', '2026-10-14 17:05:56.096515+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "fdae766c-4d89-4d88-9920-32d2d7106332", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bcfc6f52-91b2-4598-a56f-6686d0d8f38c', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '4d5e65e0-8763-49b6-90fb-a49e0b633375', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.101815+00', '2026-10-14 17:05:56.101815+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ebb7d725-e670-4dd6-b9dd-e5bab8103297', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', '1bddc5ea-1980-4bbe-ae21-1d7ab841b6c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '924e34da-5e6d-4aab-8c40-4c62a908624d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.105523+00', '2026-10-14 17:05:56.108617+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2ae53606-0c9e-4278-bd1f-97e9c79029d6', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '8f5184a4-f55f-46f5-8882-3c2a69f8662a', '54eb48ba-7cea-41d0-9cbc-72a089a6e852', 'd91b1860-1d5a-4f47-92d4-80120285be1d', 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', '00e311e1-548b-4cc4-9990-58e422db647e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 'eef42d9a-ee4a-49f3-9aaf-e3096992d767', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.12488+00', '2026-10-14 17:05:56.128407+00', 'signage', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', NULL, NULL, NULL, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('fc9d28f4-5ea7-4168-a379-ebd40945c98a', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'a7aa482d-50fa-4df6-ae28-57023e736f6b', '7e2943e3-6a5b-4f8b-80b5-1b92278904dc', '15ef4a51-b04f-4eaa-91ca-376f334795c2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.142314+00', '2026-10-14 17:05:56.142314+00', 'signage', 'organiser', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a46313b0-dad0-443a-b0da-36bebaefcc14', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'd58172df-afda-48f6-8e94-7e3e762e1c6b', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, '5c8b4451-3a5d-4ea9-a404-401b6b7cc2b0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.146318+00', '2026-10-14 17:05:56.149861+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', '2026-12-28', NULL, 9000.00, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('272a4c4d-d92d-468a-b4f3-d69788226a36', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '0004006c-fddc-482d-81d0-81f3ce0702ed', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '90aa07a6-7ede-45bb-978a-8f9ecf050424', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.165771+00', '2026-10-14 17:05:56.165771+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}, {"stepId": "1795ed49-7aa8-4b59-a675-b3ff3c05dd81", "userId": null}]', '2026-11-03', NULL, 12500.00, '2026-10-04 17:05:55.198+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d4bd6865-b9b5-4631-8f4b-b2b64fa7a965', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '4f99116c-01c2-4044-af63-f4942d18e707', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.172648+00', '2026-10-14 17:05:56.172648+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', '2027-02-11', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1ad228ec-b3bd-48ed-a1cb-fd0ff43374bc', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '6145a1bd-a55b-4089-a3a3-ce476a75afed', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.177784+00', '2026-10-14 17:05:56.177784+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d8d0cbd-93a9-464a-be56-4c6e9a245113", "userId": null}, {"stepId": "d3568630-40e4-49ed-a992-61bb47b8b5e5", "userId": null}]', '2026-11-01', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c6c4050a-06ba-4086-a472-68093b90bab6', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '54eb48ba-7cea-41d0-9cbc-72a089a6e852', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, 'a6c15b1a-b768-416d-a342-0a1f829ae448', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-14 17:05:56.212384+00', '2026-10-14 17:05:56.212384+00', 'stand_design', 'organiser', '[{"stepId": "c21edb88-0c92-4365-b277-c875959a66c0", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "09529a68-eab8-4e87-b623-a8fe161ec08b", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('9071349f-4c7c-4009-b702-6bd61709baa8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', '8f48325a-4933-4e1a-a58b-1bba355ebcc6', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'a2082b36-b53c-4c97-8bb4-72d86ac4a707', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-14 17:05:55.953556+00', '2026-10-14 17:05:55.953556+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('ecfb506c-e2bd-4cfa-8a40-5f0192f87b9e', '90aa07a6-7ede-45bb-978a-8f9ecf050424', 'Logo on 6 hanging banners', 6, '2026-10-14 17:05:55.413419+00', '2026-10-14 17:05:55.413419+00');
INSERT INTO public.sponsor_entitlements VALUES ('00e311e1-548b-4cc4-9990-58e422db647e', '90aa07a6-7ede-45bb-978a-8f9ecf050424', 'Entrance feature branding', 1, '2026-10-14 17:05:55.416077+00', '2026-10-14 17:05:55.416077+00');
INSERT INTO public.sponsor_entitlements VALUES ('df4033b0-e7a2-4a22-9e4f-0c0bec57cf80', '2f3c871a-5496-42a5-bdc1-442a011ceb75', 'Seminar theatre branding', 1, '2026-10-14 17:05:55.420386+00', '2026-10-14 17:05:55.420386+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('90aa07a6-7ede-45bb-978a-8f9ecf050424', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-14 17:05:55.410337+00', '2026-10-14 17:05:55.410337+00');
INSERT INTO public.sponsors VALUES ('2f3c871a-5496-42a5-bdc1-442a011ceb75', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-14 17:05:55.418468+00', '2026-10-14 17:05:55.418468+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('e4ba3b07-13b2-4f1a-a75e-7f647a6ebde9', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', '91f17fa3-b5c1-4e7f-9cb2-3faf4e873b97', 'STD-BIRM27-A10', '8a959999-539e-4515-84e8-45a4841d6ba4', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-08 17:05:55.198+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.218187+00', '2026-10-14 17:05:56.218187+00');
INSERT INTO public.stand_submissions VALUES ('1db8476f-4f9b-4cc4-b4b4-fbd89c45aaf5', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'a8efdbcd-9cba-4dde-97db-367cff72836a', 'STD-BIRM27-A20', '263cc533-ac80-4be5-aac8-a1e035804f10', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-08 17:05:55.198+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.240409+00', '2026-10-14 17:05:56.240409+00');
INSERT INTO public.stand_submissions VALUES ('5e114857-8acb-4964-810e-94c89eb9fd98', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', '49d1e298-f171-4200-a149-55fc098f74e9', 'STD-BIRM27-A30', '8a959999-539e-4515-84e8-45a4841d6ba4', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-08 17:05:55.198+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.259838+00', '2026-10-14 17:05:56.259838+00');
INSERT INTO public.stand_submissions VALUES ('223188e5-fd24-423d-8ed8-3903af528f8c', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', '6b6fedf7-5c24-4431-8be3-9affb6a13395', 'STD-BIRM27-B10', '263cc533-ac80-4be5-aac8-a1e035804f10', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-08 17:05:55.198+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.276398+00', '2026-10-14 17:05:56.276398+00');
INSERT INTO public.stand_submissions VALUES ('f7c71ebd-d5db-425f-a790-a9afdc7c5daf', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'c51ddfa6-f880-4a82-bb96-59b404b55203', 'STD-BIRM27-B20', '8a959999-539e-4515-84e8-45a4841d6ba4', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-08 17:05:55.198+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.294316+00', '2026-10-14 17:05:56.294316+00');
INSERT INTO public.stand_submissions VALUES ('f100e2b4-acb9-45a8-92f8-f4044262dd00', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', '27f9347b-b01d-4586-aca3-2b1f3a6aa885', 'STD-BIRM27-B30', '263cc533-ac80-4be5-aac8-a1e035804f10', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 0, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.309422+00', '2026-10-14 17:05:56.309422+00');
INSERT INTO public.stand_submissions VALUES ('68e78d0a-4368-4f13-a549-524ecd9b17a8', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'e6331947-728a-4067-82be-d2b6e3ebd0b5', 'STD-BIRM27-C10', '8a959999-539e-4515-84e8-45a4841d6ba4', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 0, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.313916+00', '2026-10-14 17:05:56.313916+00');
INSERT INTO public.stand_submissions VALUES ('289ff3f1-7108-4427-a4d8-25a91d1632eb', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'a0ef36af-4b02-4ff7-8e65-2354ef295f12', 'STD-BIRM27-C20', '263cc533-ac80-4be5-aac8-a1e035804f10', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 0, '00000000-0000-4000-8000-000000000002', '2026-10-14 17:05:56.321942+00', '2026-10-14 17:05:56.321942+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('a2082b36-b53c-4c97-8bb4-72d86ac4a707', 'cae3719c-2a12-4290-bfe9-ca850ec590b1');
INSERT INTO public.supplier_service_links VALUES ('a2082b36-b53c-4c97-8bb4-72d86ac4a707', '527a6a0d-70fb-47a6-bb99-d7f808dec44e');
INSERT INTO public.supplier_service_links VALUES ('6affe5f6-feb7-4204-ba8d-2ac1db1eac6a', '31b48e7c-62f4-416f-9d96-5f088881b886');
INSERT INTO public.supplier_service_links VALUES ('6affe5f6-feb7-4204-ba8d-2ac1db1eac6a', '527a6a0d-70fb-47a6-bb99-d7f808dec44e');
INSERT INTO public.supplier_service_links VALUES ('6affe5f6-feb7-4204-ba8d-2ac1db1eac6a', '614eeee0-4a14-4836-bbbc-62bfb275d8ea');
INSERT INTO public.supplier_service_links VALUES ('633b8c09-14e5-4ef0-8278-7a362b6118ee', 'd193688e-4914-43fa-bc03-51472d510845');
INSERT INTO public.supplier_service_links VALUES ('633b8c09-14e5-4ef0-8278-7a362b6118ee', '614eeee0-4a14-4836-bbbc-62bfb275d8ea');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('cae3719c-2a12-4290-bfe9-ca850ec590b1', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Signage print', 1, false, '2026-10-14 17:05:55.376087+00', '2026-10-14 17:05:55.376087+00');
INSERT INTO public.supplier_services VALUES ('d193688e-4914-43fa-bc03-51472d510845', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Digital screens & AV', 2, false, '2026-10-14 17:05:55.378342+00', '2026-10-14 17:05:55.378342+00');
INSERT INTO public.supplier_services VALUES ('31b48e7c-62f4-416f-9d96-5f088881b886', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Rigging', 3, false, '2026-10-14 17:05:55.380435+00', '2026-10-14 17:05:55.380435+00');
INSERT INTO public.supplier_services VALUES ('527a6a0d-70fb-47a6-bb99-d7f808dec44e', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Installation', 4, false, '2026-10-14 17:05:55.382223+00', '2026-10-14 17:05:55.382223+00');
INSERT INTO public.supplier_services VALUES ('614eeee0-4a14-4836-bbbc-62bfb275d8ea', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Staffing', 5, false, '2026-10-14 17:05:55.384176+00', '2026-10-14 17:05:55.384176+00');
INSERT INTO public.supplier_services VALUES ('911bdb57-2be7-4c07-9e63-1899de28606d', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Furniture', 6, false, '2026-10-14 17:05:55.386075+00', '2026-10-14 17:05:55.386075+00');
INSERT INTO public.supplier_services VALUES ('1d75b8c6-17bc-4b8a-82c8-89a122407ceb', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Structural engineering', 7, false, '2026-10-14 17:05:55.387875+00', '2026-10-14 17:05:55.387875+00');
INSERT INTO public.supplier_services VALUES ('d4c8833b-1d69-49e1-986a-c1cf5789417b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Floor Manager', 8, false, '2026-10-14 17:05:55.389562+00', '2026-10-14 17:05:55.389562+00');
INSERT INTO public.supplier_services VALUES ('7148f6f9-0d0e-4466-9ea7-26cdf018f540', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Security', 9, false, '2026-10-14 17:05:55.391323+00', '2026-10-14 17:05:55.391323+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('a2082b36-b53c-4c97-8bb4-72d86ac4a707', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-14 17:05:55.365829+00', '2026-10-14 17:05:55.365829+00', false);
INSERT INTO public.suppliers VALUES ('6affe5f6-feb7-4204-ba8d-2ac1db1eac6a', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-14 17:05:55.369507+00', '2026-10-14 17:05:55.369507+00', false);
INSERT INTO public.suppliers VALUES ('633b8c09-14e5-4ef0-8278-7a362b6118ee', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-14 17:05:55.374239+00', '2026-10-14 17:05:55.374239+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('7cbfad47-8e6b-46bd-bc42-b1a7a5c35c7b', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-21', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'd4125595-2e8c-4ede-a78d-fb95f90af256', NULL, '2026-10-14 17:05:56.331235+00', '2026-10-14 17:05:56.331235+00', NULL);
INSERT INTO public.tasks VALUES ('d846b988-fb4b-4321-9b76-f7662f614e47', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-24', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-14 17:05:56.333162+00', '2026-10-14 17:05:56.333162+00', NULL);
INSERT INTO public.tasks VALUES ('b1ab1779-7881-4b06-af6e-6bb34983be39', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Walk the hall with the venue', NULL, 'done', '2026-10-09', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-14 17:05:55.198+00', '2026-10-14 17:05:56.334919+00', '2026-10-14 17:05:56.334919+00', 'd846b988-fb4b-4321-9b76-f7662f614e47');
INSERT INTO public.tasks VALUES ('d9ed3d39-8fb1-41a0-9a1a-d41a2cb1e7a4', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'c824d2d9-2639-4a6b-99a7-37e6b05e0d21', 'Send sign positions to the printer', NULL, 'open', '2026-10-13', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-14 17:05:56.334919+00', '2026-10-14 17:05:56.334919+00', 'd846b988-fb4b-4321-9b76-f7662f614e47');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.243404+00', '2026-10-14 17:05:55.243404+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.249927+00', '2026-10-14 17:05:55.249927+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.254461+00', '2026-10-14 17:05:55.254461+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.258231+00', '2026-10-14 17:05:55.258231+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.262727+00', '2026-10-14 17:05:55.262727+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-14 17:05:55.266289+00', '2026-10-14 17:05:55.266289+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.525086+00', '2026-10-14 17:05:55.525086+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.536237+00', '2026-10-14 17:05:55.536237+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.541271+00', '2026-10-14 17:05:55.541271+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.544431+00', '2026-10-14 17:05:55.544431+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.547546+00', '2026-10-14 17:05:55.547546+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-14 17:05:55.583727+00', '2026-10-14 17:05:55.583727+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('be3969c8-3a39-4328-99df-eac5b3363f8e', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-14 17:05:55.281662+00', '2026-10-14 17:05:55.281662+00');
INSERT INTO public.venue_rules VALUES ('df01041e-d5da-4ca9-b53d-620e0c77a9c1', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-14 17:05:55.285181+00', '2026-10-14 17:05:55.285181+00');
INSERT INTO public.venue_rules VALUES ('0fa6a478-7fb8-4f82-916b-b840965913ac', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-14 17:05:55.288973+00', '2026-10-14 17:05:55.288973+00');
INSERT INTO public.venue_rules VALUES ('5dafacaa-7800-4d38-9e96-d60470059989', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-14 17:05:55.291884+00', '2026-10-14 17:05:55.291884+00');
INSERT INTO public.venue_rules VALUES ('b0f48800-9c81-49a8-84db-56d1d8b1134c', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-14 17:05:55.29517+00', '2026-10-14 17:05:55.29517+00');
INSERT INTO public.venue_rules VALUES ('e3697332-d296-46d5-b44c-d0db5ea7c07a', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-14 17:05:55.29876+00', '2026-10-14 17:05:55.29876+00');
INSERT INTO public.venue_rules VALUES ('6e34fe11-8989-4ae8-82b5-977ddf2a0adb', '926ffa9a-af16-4763-b157-d7c2b80fff9c', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-14 17:05:55.301974+00', '2026-10-14 17:05:55.301974+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('926ffa9a-af16-4763-b157-d7c2b80fff9c', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-14 17:05:55.272744+00', '2026-10-14 17:05:55.272744+00', false);
INSERT INTO public.venues VALUES ('217c8000-f956-4018-a5b0-252b779471f0', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-14 17:05:55.275356+00', '2026-10-14 17:05:55.275356+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('c214b00b-7eb3-4cfc-8086-a74e7aea43f4', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-14 17:05:55.430124+00', '2026-10-14 17:05:55.430124+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('00731f33-3de3-4fb2-ae74-6082a27b702d', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-14 17:05:55.433346+00', '2026-10-14 17:05:55.433346+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('63d03bb9-43a6-4197-bbd9-44cb66c0f89e', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-14 17:05:55.434904+00', '2026-10-14 17:05:55.434904+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('62cad634-af1e-4ff5-ae63-cf4518aefdb7', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-14 17:05:55.436128+00', '2026-10-14 17:05:55.436128+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('146ea88d-dfe7-4d41-9933-5ea0137b8a2e', 'a6c15b1a-b768-416d-a342-0a1f829ae448', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-14 17:05:56.203077+00', '2026-10-14 17:05:56.208351+00', '{organiser,sponsor}', false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7');
INSERT INTO public.workflow_steps VALUES ('909a0d35-077d-4f26-b54c-681d91f1f71b', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-14 17:05:55.484759+00', '2026-10-14 17:05:55.484759+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('16d0f82a-3863-4283-9aa9-e5b93bc14813', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-14 17:05:55.486433+00', '2026-10-14 17:05:55.486433+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('15e89103-82f8-4933-ab42-db80135efc23', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-14 17:05:55.487703+00', '2026-10-14 17:05:55.487703+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('cc5579a7-e540-4f0d-a914-0ce5049d798d', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-14 17:05:55.488876+00', '2026-10-14 17:05:55.488876+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e971109d-794c-4178-b4c7-018af2172445', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-14 17:05:55.49056+00', '2026-10-14 17:05:55.49056+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('237f96af-3a03-4830-8bcd-1aa39daf15ae', 'c1f0a6dd-0e9c-4836-a885-c6f6dd373144', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-14 17:05:55.491889+00', '2026-10-14 17:05:55.491889+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('4d8d0cbd-93a9-464a-be56-4c6e9a245113', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-14 17:05:55.424502+00', '2026-10-14 17:05:56.190864+00', '{organiser,sponsor}', false, '487d2141-0a83-4584-ba8f-060ce68ff60b');
INSERT INTO public.workflow_steps VALUES ('d3568630-40e4-49ed-a992-61bb47b8b5e5', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-14 17:05:55.426522+00', '2026-10-14 17:05:56.192304+00', '{organiser,sponsor}', false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96');
INSERT INTO public.workflow_steps VALUES ('1795ed49-7aa8-4b59-a675-b3ff3c05dd81', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-14 17:05:55.428288+00', '2026-10-14 17:05:56.193689+00', '{sponsor}', false, '4970456a-b42d-440a-bbdb-295f4a9d1a97');
INSERT INTO public.workflow_steps VALUES ('fdae766c-4d89-4d88-9920-32d2d7106332', 'ff80f749-44b2-4ef8-b435-f6e1cc2aed40', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-14 17:05:55.431855+00', '2026-10-14 17:05:56.194986+00', '{organiser,sponsor}', false, '43af81e3-3536-4415-8c70-0e06e0c9f8c7');
INSERT INTO public.workflow_steps VALUES ('c21edb88-0c92-4365-b277-c875959a66c0', 'a6c15b1a-b768-416d-a342-0a1f829ae448', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-14 17:05:56.197469+00', '2026-10-14 17:05:56.204622+00', '{organiser,sponsor}', false, '487d2141-0a83-4584-ba8f-060ce68ff60b');
INSERT INTO public.workflow_steps VALUES ('09529a68-eab8-4e87-b623-a8fe161ec08b', 'a6c15b1a-b768-416d-a342-0a1f829ae448', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-14 17:05:56.199188+00', '2026-10-14 17:05:56.206081+00', '{organiser,sponsor}', false, 'abdaac3c-a9d1-4ee9-9610-a472c328dc96');
INSERT INTO public.workflow_steps VALUES ('62332f17-5d94-480c-8570-870eeb21ad57', 'a6c15b1a-b768-416d-a342-0a1f829ae448', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-14 17:05:56.201529+00', '2026-10-14 17:05:56.20723+00', '{sponsor}', false, '4970456a-b42d-440a-bbdb-295f4a9d1a97');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('ff80f749-44b2-4ef8-b435-f6e1cc2aed40', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Signage default', 'signage', true, false, '2026-10-14 17:05:55.422837+00', '2026-10-14 17:05:55.422837+00', NULL);
INSERT INTO public.workflows VALUES ('c1f0a6dd-0e9c-4836-a885-c6f6dd373144', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Stand default', 'stand', true, false, '2026-10-14 17:05:55.483059+00', '2026-10-14 17:05:55.483059+00', NULL);
INSERT INTO public.workflows VALUES ('a6c15b1a-b768-416d-a342-0a1f829ae448', '3c2810bc-2937-44fa-8d58-29896c2b1b67', 'Stand design sign-off', 'signage', false, false, '2026-10-14 17:05:56.184889+00', '2026-10-14 17:05:56.184889+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 12, true);


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

\unrestrict FkO7RNwEBOZ6lQq9g8Kyij3bVE9JMibxpcTvxPtE6lSPKHlKWnTB107QzHWNEqk

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
