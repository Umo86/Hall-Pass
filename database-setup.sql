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

\restrict 4Y8qMPkd9Ni5oiuiiPwWVnZfYi1xJRZpS3gZAoRg42J0Hl83vgd99it7vjRZ7h1

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
    assigned_department_id uuid
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    logo_path text
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
    signoffs jsonb,
    order_by_date date,
    photo_path text,
    sale_price numeric(12,2),
    sold_at timestamp with time zone,
    stand_number text,
    parent_item_id uuid,
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('233ba800-a228-4e79-8839-455cd58cebf3', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('4ab2b1a4-c4e7-4a5f-bbeb-d6f3524fae97', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('ae4d37e7-3e86-4d44-bf36-518640fec107', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('d2418a7d-8fc9-40be-9430-492d21682d33', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('6deaa360-79dc-42ee-a30b-df2ba6b0a159', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('4e481060-06bb-4ee0-8a3e-66b9617a5748', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('23355f4c-cd50-4d3c-aa58-1e75fe850069', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3d9f9add-3912-42bb-98b8-5419505bb097', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:26.98702+00', '2026-09-29 13:50:26.98702+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a725ef27-f6bb-4125-8cfc-641a47bb5928', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('a177cfc0-6464-4b01-8835-1917e4389474', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('cee57c7a-e033-4a7f-8ca3-3d8b12b8d8a1', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('878f47db-0ee5-498f-8bcc-df07fef5c822', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('77184972-c717-428d-8227-88b654205d20', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('6421f58d-3921-48e4-a028-a72ec0d34cb2', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cc1cb91e-c02c-402c-aa22-7f2bc735c89b', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('57b1f980-cb40-4294-922f-b9dd5abe425c', 'signage_item', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.017822+00', '2026-09-29 13:50:27.017822+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ff1bdb5c-fd79-4ca6-8576-963b2f62e37d', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 13:50:26.566+00', '2026-09-25 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('9db2b9e2-995a-4c84-be88-d82daf7fa8ff', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 13:50:26.566+00', '2026-09-20 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('637b0ded-dec9-4514-93e2-ad5adc9d2808', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-19 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 13:50:26.566+00', '2026-09-22 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('ef21c759-d3bd-4f82-ad65-b18f9f83e732', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('015ce694-6bcb-4c7a-8d39-16566835202b', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('365d5438-43a4-4652-b74e-bbfb7c18ced9', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('ae050777-3e86-4bb1-baee-2b7c40d71928', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('33eb46d6-9b19-4eec-9365-ef9e39d918c6', 'signage_item', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.047358+00', '2026-09-29 13:50:27.047358+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('dbb4e83b-9a74-426e-b125-3c304de39a02', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('12721891-2b4a-41fa-8fc1-fb27f63dc9aa', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('50ffb9c5-d800-4378-b20f-c7f5ac1c5507', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('c29b2ccf-45bf-47a8-8af7-3106e92760ac', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0a77cefc-1c0a-4b7c-a6cc-592208f15835', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('5b398acc-f97f-4e94-9228-dd491c29f51d', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('2052e73f-cd17-441a-b293-2bc6da97a3c2', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c0f27106-5f37-4426-a9bd-237084408248', 'signage_item', '5d965425-2291-419b-b6fa-237efb649a08', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.078266+00', '2026-09-29 13:50:27.078266+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('888b801f-3932-456d-b6dd-556e3188898f', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('0e19a7d4-3c04-4a9e-837c-df5f3f8cb80f', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('0707f496-eeeb-498e-8d48-09291494fb6a', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('0ab6b88b-3b13-4316-93c2-86052075239c', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f9c56987-acf5-491b-b334-7cec51de2f49', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('ab52329f-ac17-4926-be27-797e4171cd32', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('b3e955ba-6f97-4d9f-9850-b51b556e8307', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('74bff5ea-191a-44d0-bab1-0b4d8e36fe4f', 'signage_item', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.106307+00', '2026-09-29 13:50:27.106307+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('13a1e3d1-8a1f-4e44-9bf7-ea50e7cb5768', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-19 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 13:50:26.566+00', '2026-09-20 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('30b47a22-04d3-4713-963d-252806f5bca2', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-19 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-17 13:50:26.566+00', '2026-09-20 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('07f4ad8a-0ab4-49cc-86a3-cff397045cd7', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('19039876-ace0-4b55-9688-f38ad29c9a71', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0fc845c3-b9b3-43fc-a11f-d7bf11306840', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', '2026-09-25 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('7082db6b-8d07-4ef0-af54-daed11fa9115', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('bf4026b1-5bd0-45b3-884f-0d54943dad94', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('62b76e03-203d-4807-9b52-a98829f340fa', 'signage_item', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.128947+00', '2026-09-29 13:50:27.128947+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ba0e35f1-ae93-412e-aa80-3bf40e752210', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('4cc84b83-e720-407b-849c-69fd3f9f9349', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('9c8965c2-5b00-4a86-9efd-c132dff7cc99', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('f43b9820-aca6-44be-a8c2-30a1221d1044', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('b967e7d7-c5f4-40f3-95a4-5f503b3ff5cf', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('1d103b89-7922-4501-8230-f06050d818c1', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('356d799d-f0f3-41b4-9d15-ebb9cde09c28', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e3bcc336-b66c-427b-af37-87fa4b2e7449', 'signage_item', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.153801+00', '2026-09-29 13:50:27.153801+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ef60fd99-a5f1-4a76-b039-d6fd8896435f', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('ced4bc84-2d9d-4736-b844-35c6a04facd5', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('98b5f0b6-3a57-4e60-a5e1-a96b1158f376', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('cf2640b3-ccab-4734-ae2f-b6776b063b02', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('8b351f39-d22b-4ca4-96f0-9fa67ff986b0', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('842dad02-a349-4ae0-9309-8f4abfc314a9', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('39237e83-d931-45db-9b37-5ed86e5eba77', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1f47e9fc-b21a-4673-ad12-4727e10a678c', 'signage_item', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.183432+00', '2026-09-29 13:50:27.183432+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('5216e8a2-ae20-4a44-b42f-16d4a1192358', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('b08b9b7f-0ffc-4d7b-959e-5f08c9f45f8d', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('d14252ed-9c6b-42b5-b5a4-a16b8f222ce1', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-26 13:50:26.566+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('37514554-3572-4752-9e8e-feb4735f73fc', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('923d4463-76dc-4865-9269-5fdb155bc6fc', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('926a50a6-1e9e-429f-8a5e-67195d4a9371', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9f1517be-30e5-4b4d-b9b1-3bea880f1f3d', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a7196b49-095d-4873-93bd-e43b308992b1', 'signage_item', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.210322+00', '2026-09-29 13:50:27.210322+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('16a6461a-2147-4d0c-a52f-0053042ee876', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('0cb613c0-798b-4111-877d-fada892ff3bd', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('70f27c17-eaea-4a2f-9d4e-e8a8bb722c67', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('3d0cb8d0-a4e5-449b-a0d5-df8add56ad73', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('11a0ca3d-bf43-435c-8ada-da632847aac3', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('c767ef48-6d6c-479b-b67d-e0a6e165ac22', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('be2a12ce-3555-4d7a-9b54-62d39f5ec735', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d8cc3f50-a816-4d86-b294-38a8f7603158', 'signage_item', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.233975+00', '2026-09-29 13:50:27.233975+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('61a4e458-2e8c-46ba-ab21-735a0f6d8955', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('8ae0baa4-baf6-4458-af3a-90203c8f9ef8', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('bc73fa7e-1110-434b-a5d9-de98bdcc27dc', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('1fe8bf31-5385-4be0-9464-9e2c677c7570', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('1f4afe8a-d951-4daf-b73f-b032214a4135', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('0576d581-7a27-4964-9423-6147c3a4138e', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('7581fcd4-f037-454b-985a-ed0c522a006b', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('991d1885-2b2f-49f8-883f-17bc74d11667', 'signage_item', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.251886+00', '2026-09-29 13:50:27.251886+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0ba8955c-f4c8-4830-8386-538e1e070aa6', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('e886a12f-cb79-4f72-9498-86b90357ca8e', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('03d4e999-7541-442b-abb3-94173fe7241b', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('c825cca8-7149-46e4-9e92-d4f8b0c75a1c', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9cc46662-94bf-4eb8-be9b-467ed0bf2568', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('6fea15c5-7bb6-435b-9173-a3802083e6af', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('7b768573-7fc8-432e-933d-dd15a3913588', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('02d08de8-075f-491c-8422-6134e181685c', 'signage_item', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.27904+00', '2026-09-29 13:50:27.27904+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a99fe6c4-152b-444d-8074-eb8f779ae7e6', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('39b601cd-ef87-435d-bf23-18e37b2efd76', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('16c74277-be19-44ab-8a8a-d3ad109f2e51', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('072f0634-0133-4a71-96f1-e710f2d05c1c', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d4de3f0c-9f23-4de9-9824-5e922f78d284', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('f34ac541-3b8f-4393-a923-9b9a637b1cd9', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e35fee93-038e-4607-89b3-9f7786d789d5', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8f343675-7691-4af7-8762-2a748c3361d2', 'signage_item', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.303419+00', '2026-09-29 13:50:27.303419+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cba6bf83-322b-4608-8714-6bf291cb6e24', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('8a821ff4-325d-4bc1-814d-9138cfe50214', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('d0f1a847-47f4-4d82-8a67-1f7c69d124ee', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('431d4e78-feec-4256-872d-d6ee3f39009a', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('4534e3a0-9ab3-4dac-a754-c17264a6c157', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('a220bf99-211d-4e98-b631-98c53c13d308', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('bcd3a9c4-df67-4d43-8082-66984401e699', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0a05d641-869f-43c1-b735-2a88d95e00a5', 'signage_item', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.324209+00', '2026-09-29 13:50:27.324209+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('fbdaaecf-f277-4276-baf2-4d0056ad4c5a', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('7bb8359c-2423-4810-be17-4ca1c9101d0f', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('ca52fbbc-0a9d-4c22-ab1b-af1c4c9398cc', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('a736c170-7f77-4a86-9c3c-4d728743a90c', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('379b0dd0-82b8-4d5a-8353-9751c4804d26', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('d14f7157-e7b0-42e0-9cb8-6e2d664bc4e8', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a845f4f9-4c7b-4c66-937e-eb0b0ebeb726', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('bf442cf8-418f-436a-a4ac-dc67bce69567', 'signage_item', '9947f2de-2e68-430d-8722-b0a696b24241', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.34483+00', '2026-09-29 13:50:27.34483+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f6904bbc-57ff-4a3b-9fdb-554e3ee9aa91', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('1bc1fc71-69ec-4486-b176-374fe4a6eb84', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('06c24b2b-cf7b-4e2a-b794-79b3601457e5', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('7d617cb0-c333-4f38-b0ac-912c923047bc', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('cceb798c-ae65-4aff-b92b-e12f43497ee6', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('f56898ed-6149-4db6-b49e-36ae2fbc0ae9', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('09f00904-c8a9-4fd0-8b82-b8e7cb932cb1', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a0c39c20-3b94-4d0a-a8ed-1fba8ec459cf', 'signage_item', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.372199+00', '2026-09-29 13:50:27.372199+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d314afe3-acf1-4990-81b9-cda8b77f88e5', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('5dece04f-db9a-4f72-85cc-c339c4c5f09b', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('5f6cb42d-f61f-4713-a9a9-d1775e8b9d24', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('8eda65c9-2afe-4c4a-8729-6ba6aa7ceaac', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('1f6eb807-9827-4910-9e71-371fa2a301bd', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('ba8a2471-b7f2-4f6e-a793-4d28e8f7cc81', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1b3ec17c-247e-421b-9f46-1aa8a91b01c7', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2398ff28-0071-4a95-93d9-5cb79468c76b', 'signage_item', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.399311+00', '2026-09-29 13:50:27.399311+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('820ae6e1-44be-462f-bce5-15db4faeea46', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('6d82fa5e-84bf-4914-b557-0ecff421b656', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('4cbac6cb-bb72-4f6f-b909-80db3119eb96', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('4b590d09-be17-47fa-86ea-3adb40521248', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('741f4a16-27e2-4cef-b5e6-d33a62d89607', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('68f44a7b-fd16-4f46-b992-020afbb60696', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a27f2b44-92ed-4d86-9f60-7973c850f670', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('021a6dfa-9b88-43ed-a2b5-20b4488d40a9', 'signage_item', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.423579+00', '2026-09-29 13:50:27.423579+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e1e290c4-c76a-4365-8d7e-22c9339c3f84', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('7015568f-a25f-4bbe-8e6f-fb53daa05d52', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-28 13:50:26.566+00', '2026-10-01 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('3458cfe4-68fb-4967-b109-6daced97f78c', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('7a83dc98-1f0b-4e95-bc65-4f3543532449', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-28 13:50:26.566+00', '2026-10-01 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('d68a1796-0130-4136-b1e8-543dbaf88d22', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('28d99e61-028e-44eb-8064-896fbfee4428', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-28 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('08cf581a-ba70-4ed5-8e6f-f085c232dcfa', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ad71e8dd-a528-4d7b-9107-f9b66117be19', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('242576d8-4e75-4a10-8458-16dde25ad290', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('2273d905-1d06-4601-8688-e24837514553', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('5f2e8e93-3ccc-456f-bcaa-4d89dda1d9d1', 'signage_item', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.451299+00', '2026-09-29 13:50:27.451299+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a36d6515-b803-40c2-8c04-f8f30d7e6c0e', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('f1e5e5d8-c808-41ba-9828-93587e698f13', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('89588b10-b76c-48dc-ab81-94938ffaa03d', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('b54c1678-b97d-4df5-a2b9-f9e3c955fda3', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('bc478ad4-5692-4cbe-9d99-b23c6dfa612c', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('d132b56b-06a6-410c-9b86-340d729b59d2', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('012706b0-c951-47ea-a338-052d9f0c8699', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f0189348-4038-4633-bc2d-1ffd6fcb4c6e', 'signage_item', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.515149+00', '2026-09-29 13:50:27.515149+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('dadd175b-088a-45b1-bf07-98eaf6bf4b5a', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('45b7ea11-9376-41e8-82a9-c2e2961f8d16', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('4f6242cf-cbf6-40e8-ab8c-16db796316f5', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('d5d5ba73-666c-494c-852c-4b94c653c5aa', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-26 13:50:26.566+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-10-03 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('6ef676c5-b527-4299-82ad-312965d8f7b9', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('4596f8ea-ab1e-4130-a153-3e3171eb101e', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 13:50:26.566+00', '2026-09-28 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('61a786a0-1885-41ce-b2b5-a6c9caa706ba', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6770742c-ab9d-48db-be23-f7a1106f1d4f', 'signage_item', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.539162+00', '2026-09-29 13:50:27.539162+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c988f1a6-c6b6-41ca-8ae9-993bc0813d1d', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, 'a278f705-0c91-4d12-9d17-f0a57f1458a2', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 3, false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.approval_instances VALUES ('7b986244-fd53-4da1-bb35-5207cd6c4d2e', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, '32a2efba-9b00-4fcf-badc-55a63405d2c7', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 3, false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.approval_instances VALUES ('03c1f76f-44c1-4335-a894-8d861c53526c', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, 'c840d56a-3c2f-417c-a94a-7cd65f8b2abc', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 13:50:26.566+00', '2026-09-29 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 5, false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.approval_instances VALUES ('f9e688e1-5a50-46ee-b911-6589cc0ac46e', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, '1085444c-dd0c-403e-8757-5cfa36f67860', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('28e344fd-3ef8-4fde-b272-2c622f878b98', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, 'fc1393f4-3f78-4631-ada7-42f690841933', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 3, false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.approval_instances VALUES ('dbfc1f4c-587f-4cdc-b872-ff34e67f09b6', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, 'fd337e62-0ddf-4aad-91d9-3921159267b6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4bafc0f0-8544-4565-bb43-7df3245d517a', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, '70934458-6128-4d5f-8f06-d1e801c2b555', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('dbe2dcc7-beff-468b-b925-5157a283fe9c', 'signage_item', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, '6892931a-b3d1-4c85-8723-a88d66298141', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.563606+00', '2026-09-29 13:50:27.563606+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c85f610d-0bab-4598-a5fc-ae96a069aaca', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, 'a319834a-7e1c-499c-a437-69a8e48880c3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 13:50:26.566+00', '2026-09-26 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('b3373a14-4548-42d5-82de-8bbc615f651b', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, 'fa27f3db-31a2-461b-955e-e41dfa90c5ff', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-25 13:50:26.566+00', '2026-10-02 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('df7c1f3d-ec66-4a9d-b7c0-a3fd2cf18e34', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, 'e1dc0748-23a0-49b4-be10-c1bfd90f293b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('3a88ee27-6dfa-40ba-806c-11c5c308b8a7', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, '8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('71ffcf43-2310-426b-b4b6-60b1da870ff7', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, 'e21bfb89-d82f-4bdb-8495-9f998a8b194a', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c7bb2e0d-5467-4f88-aa86-4ab7bc278d7e', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 1, '66ce8c3d-8df5-4d66-a263-b125f47a2249', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a41acc31-46bf-434a-9a4a-e661f9409106', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, 'a319834a-7e1c-499c-a437-69a8e48880c3', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 13:50:26.566+00', '2026-09-26 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('e54984fb-ff74-4e47-9872-80b8cd1b4b16', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, 'fa27f3db-31a2-461b-955e-e41dfa90c5ff', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0c46969a-6da5-4b59-9a82-fdf3cb93c70e', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, 'e1dc0748-23a0-49b4-be10-c1bfd90f293b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('4d9ab8b1-9d88-4a5a-b9d6-db47c5dbea39', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, '8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('237b269e-bde6-43ec-959d-77b9620e24cc', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, 'e21bfb89-d82f-4bdb-8495-9f998a8b194a', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f92ef189-afac-479c-ab77-f8f4409f6a45', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 1, '66ce8c3d-8df5-4d66-a263-b125f47a2249', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3c016cbd-20ef-49f7-b4e8-63ec1a92dde7', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, 'a319834a-7e1c-499c-a437-69a8e48880c3', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-23 13:50:26.566+00', '2026-09-26 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('4a6c70e7-42c5-418d-9a28-22fe0c8e85cd', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, 'fa27f3db-31a2-461b-955e-e41dfa90c5ff', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('cdf4bd3c-43c5-4948-b940-7aafce1a2627', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, 'e1dc0748-23a0-49b4-be10-c1bfd90f293b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('c592a592-eeab-4b86-98b6-1ab8ddfde42d', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, '8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('5a657826-ce90-4b83-8529-d11275539ff7', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, 'e21bfb89-d82f-4bdb-8495-9f998a8b194a', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('54aa036a-110a-4d8b-8b73-66a82a6e513c', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 1, '66ce8c3d-8df5-4d66-a263-b125f47a2249', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('202def74-20ba-4948-9893-738017bf8800', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, 'a319834a-7e1c-499c-a437-69a8e48880c3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 13:50:26.566+00', '2026-09-26 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('a5c3fe36-71cd-4486-b9d1-743931b9fadd', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, 'fa27f3db-31a2-461b-955e-e41dfa90c5ff', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0eb8f7be-1e03-4cbc-811d-f640737434df', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, 'e1dc0748-23a0-49b4-be10-c1bfd90f293b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-09-30 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('9df484ac-00ec-4acf-b5ed-df36fa349bf7', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, '8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-10-02 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('e31094f5-7cbe-4676-9d82-a52ad09f05df', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, 'e21bfb89-d82f-4bdb-8495-9f998a8b194a', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e29df850-bd66-443f-8a60-3c2b438c695f', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 1, '66ce8c3d-8df5-4d66-a263-b125f47a2249', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-25 13:50:26.566+00', '2026-09-25 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e7fe1635-a41e-4f62-8413-6551f3dd9db3', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, 'a319834a-7e1c-499c-a437-69a8e48880c3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 13:50:26.566+00', '2026-09-26 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('2505c963-a613-41f3-ad5f-24ee1b9805f0', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, 'fa27f3db-31a2-461b-955e-e41dfa90c5ff', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('b46eccc6-73f4-4678-a35f-abe86df15a53', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, 'e1dc0748-23a0-49b4-be10-c1bfd90f293b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-09-30 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('87fcf089-02ac-495f-8063-83bda0df85f9', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, '8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-10-02 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d58a0d7f-f6c2-460e-84af-9b94360b2707', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, 'e21bfb89-d82f-4bdb-8495-9f998a8b194a', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-25 13:50:26.566+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-25 13:50:26.566+00', '2026-09-27 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('ff464ac2-9462-4f11-9948-6688ea62d460', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 1, '66ce8c3d-8df5-4d66-a263-b125f47a2249', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-25 13:50:26.566+00', '2026-09-25 13:50:26.566+00', 0, NULL, NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00', false, true, 0, false, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('0e294714-96d8-4318-88ac-6fd40166bdde', '63444b23-4629-4f13-9723-4e24f9998b24', '5b76f15f-8f07-409d-a508-36698184a938', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-09-29 13:50:26.825667+00', '2026-09-29 13:50:26.825667+00');
INSERT INTO public.approvers VALUES ('cb8e264a-214d-4aaa-beea-7d1b6ca6cfd8', '63444b23-4629-4f13-9723-4e24f9998b24', '96bb0847-3e6b-4385-a227-54770da1b023', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-09-29 13:50:26.833218+00', '2026-09-29 13:50:26.833218+00');
INSERT INTO public.approvers VALUES ('577c74f4-44b2-4af7-8b95-528ba775ab8a', '63444b23-4629-4f13-9723-4e24f9998b24', 'ab270b47-199b-4326-b84e-9d2aa042b6be', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-09-29 13:50:26.838879+00', '2026-09-29 13:50:26.838879+00');
INSERT INTO public.approvers VALUES ('8a869a38-f8df-4601-9f82-1cd5faa4be68', '63444b23-4629-4f13-9723-4e24f9998b24', 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-09-29 13:50:26.844474+00', '2026-09-29 13:50:26.844474+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('aedb28d6-1e3f-4a26-93e5-137fa5b38a14', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:26.979358+00', '2026-09-29 13:50:26.979358+00');
INSERT INTO public.artwork_versions VALUES ('bb077508-c257-4c31-8cd8-4cd8a6f78c0f', '4e1c8307-d5fb-422f-83e9-6675a1612cd7', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.013071+00', '2026-09-29 13:50:27.013071+00');
INSERT INTO public.artwork_versions VALUES ('16eb585b-f7e0-41d2-a5a4-886c82766c41', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-29 13:50:27.041384+00', '2026-09-29 13:50:27.041384+00');
INSERT INTO public.artwork_versions VALUES ('8b7ab618-1533-4a80-b6f5-14efaa8671e3', 'cb170bef-84bb-41e5-ae15-165a5652af1f', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.043729+00', '2026-09-29 13:50:27.043729+00');
INSERT INTO public.artwork_versions VALUES ('8bd5cb97-0e46-4755-8b6c-5f61479f3b59', '5d965425-2291-419b-b6fa-237efb649a08', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.073604+00', '2026-09-29 13:50:27.073604+00');
INSERT INTO public.artwork_versions VALUES ('a5843bef-00b3-40ed-bd99-9f007cca5814', 'c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.101614+00', '2026-09-29 13:50:27.101614+00');
INSERT INTO public.artwork_versions VALUES ('91a221f1-0509-4933-b01d-a10ce8e0e817', 'dd98cde6-1e98-4b9c-93ca-be19c030d426', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.125563+00', '2026-09-29 13:50:27.125563+00');
INSERT INTO public.artwork_versions VALUES ('99e7eb5a-1460-4cc8-a151-107776beb4ea', '86ca805f-a8fc-43ac-85a1-3820e8060146', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.149775+00', '2026-09-29 13:50:27.149775+00');
INSERT INTO public.artwork_versions VALUES ('e7a4bb62-fa31-4178-bd1c-2453cbafdf95', 'd13c5d0f-f49c-429d-af3b-377d67c8bd73', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.179526+00', '2026-09-29 13:50:27.179526+00');
INSERT INTO public.artwork_versions VALUES ('50ec5f64-ca66-4774-ab98-4c6a6ca852d3', '712b2221-a138-44bf-b38f-bedbc3c594a3', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.206246+00', '2026-09-29 13:50:27.206246+00');
INSERT INTO public.artwork_versions VALUES ('24beeb57-7a42-4b73-ab50-5df0289357ae', '9665bc68-f9da-4ec6-b219-4c1812cb5db4', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.230626+00', '2026-09-29 13:50:27.230626+00');
INSERT INTO public.artwork_versions VALUES ('2cf661b6-9420-4547-9771-d45ab7ca0336', '96eee195-28b5-4570-b003-2849e5e50bf6', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.248847+00', '2026-09-29 13:50:27.248847+00');
INSERT INTO public.artwork_versions VALUES ('b8e90d12-ea8c-4336-9ee5-0521b7315b4d', '58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.275162+00', '2026-09-29 13:50:27.275162+00');
INSERT INTO public.artwork_versions VALUES ('1cbe755c-85e3-4dfa-b636-500b7416ad9a', '4e430c0a-6f7d-411d-b651-3b89932293a2', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.299806+00', '2026-09-29 13:50:27.299806+00');
INSERT INTO public.artwork_versions VALUES ('91b8dcc7-e143-4f87-972d-3c890d826793', 'fd52f021-d9bc-452c-88dc-42e1df1eaeaf', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.321109+00', '2026-09-29 13:50:27.321109+00');
INSERT INTO public.artwork_versions VALUES ('80d99452-0c5e-4492-8b24-cf655be24624', '9947f2de-2e68-430d-8722-b0a696b24241', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.341536+00', '2026-09-29 13:50:27.341536+00');
INSERT INTO public.artwork_versions VALUES ('03681425-92f0-4700-b314-709deb085c8b', '6589098f-92d2-496d-8ae7-0ec2e593e27b', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.367612+00', '2026-09-29 13:50:27.367612+00');
INSERT INTO public.artwork_versions VALUES ('7de001d4-5537-4607-8a5f-484b248122a1', '26b23435-f98c-4a9f-ad65-924e1b0220ad', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.39543+00', '2026-09-29 13:50:27.39543+00');
INSERT INTO public.artwork_versions VALUES ('13c9d203-7b72-47e3-85cf-f0ddc71e4d6f', '307ed765-8683-4f4d-a282-aa59c3dbab13', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.419955+00', '2026-09-29 13:50:27.419955+00');
INSERT INTO public.artwork_versions VALUES ('975dd600-164e-4692-ac50-4f08927d9551', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-29 13:50:27.444092+00', '2026-09-29 13:50:27.444092+00');
INSERT INTO public.artwork_versions VALUES ('0befe983-4b59-4746-8fa2-fb5045eb845a', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-29 13:50:27.445995+00', '2026-09-29 13:50:27.445995+00');
INSERT INTO public.artwork_versions VALUES ('eda07a0b-fe00-4fba-aded-d5ccf6dfee17', 'a27ce0b5-1900-4c6d-80d2-d7436790aeca', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.448103+00', '2026-09-29 13:50:27.448103+00');
INSERT INTO public.artwork_versions VALUES ('f4fa473b-78fb-44ef-b51f-fe2c095f9f90', '0a6b18fa-741d-4d5e-a27b-923c916a8f98', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-29 13:50:27.512371+00', '2026-09-29 13:50:27.512371+00');
INSERT INTO public.artwork_versions VALUES ('1ce9112d-3e9f-4af4-b617-bd188b22aadf', '7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.533222+00', '2026-09-29 13:50:27.533222+00');
INSERT INTO public.artwork_versions VALUES ('6bd5e13d-25db-4ac0-abf7-5e00545844ad', '8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-29 13:50:27.560282+00', '2026-09-29 13:50:27.560282+00');


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

INSERT INTO public.contractors VALUES ('331c642e-6836-44fd-a5b7-f2ade3cffef2', '63444b23-4629-4f13-9723-4e24f9998b24', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-29 13:50:26.777878+00', '2026-09-29 13:50:26.777878+00');
INSERT INTO public.contractors VALUES ('6be56e7a-f1e1-4dc5-9816-3fb83916b681', '63444b23-4629-4f13-9723-4e24f9998b24', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-29 13:50:26.781335+00', '2026-09-29 13:50:26.781335+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('5b76f15f-8f07-409d-a508-36698184a938', '63444b23-4629-4f13-9723-4e24f9998b24', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-09-29 13:50:26.822706+00', '2026-09-29 13:50:26.822706+00');
INSERT INTO public.departments VALUES ('96bb0847-3e6b-4385-a227-54770da1b023', '63444b23-4629-4f13-9723-4e24f9998b24', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-09-29 13:50:26.830433+00', '2026-09-29 13:50:26.830433+00');
INSERT INTO public.departments VALUES ('ab270b47-199b-4326-b84e-9d2aa042b6be', '63444b23-4629-4f13-9723-4e24f9998b24', 'Sales', 3, false, '{sponsor}', false, '2026-09-29 13:50:26.836569+00', '2026-09-29 13:50:26.836569+00');
INSERT INTO public.departments VALUES ('dd42350c-8dd8-4b16-90b9-dc1cfebbee2b', '63444b23-4629-4f13-9723-4e24f9998b24', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-09-29 13:50:26.841631+00', '2026-09-29 13:50:26.841631+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('516c1b65-ddd9-4356-b26f-9660a6962cae', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00');
INSERT INTO public.documents VALUES ('94409f28-80e5-4435-b7d2-979ac53f752f', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00');
INSERT INTO public.documents VALUES ('c93c96f8-c409-4d52-a9dc-7d8cf3257a8d', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00');
INSERT INTO public.documents VALUES ('6a11f4f6-4df0-4ae9-a2b2-38106f435810', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00');
INSERT INTO public.documents VALUES ('10b0a7fb-5e54-4c20-8cd9-bfa018616a13', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00');
INSERT INTO public.documents VALUES ('f1a6901d-8cb8-4e1d-9fcf-44919707f55f', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00');
INSERT INTO public.documents VALUES ('ca97ee75-17d1-480d-a1a2-b93302676fe1', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00');
INSERT INTO public.documents VALUES ('7f4fc062-3a64-47e2-ad30-5dda6d2190e5', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00');
INSERT INTO public.documents VALUES ('e14e3bc1-1c2c-4f95-ab37-b5d0bd502bb2', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00');
INSERT INTO public.documents VALUES ('229f9440-176e-4de0-858c-7e6eb2f7251b', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00');
INSERT INTO public.documents VALUES ('a227222b-2a52-4a38-9b88-c9c7412decc2', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00');
INSERT INTO public.documents VALUES ('3ceaba73-73ea-49c7-a3bf-4fc534cd0175', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '5a580172-ce6b-44ef-a128-30a4bfa7d742', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00');
INSERT INTO public.documents VALUES ('4b32dda9-13ad-4343-b8c3-80fe540c6ec8', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00');
INSERT INTO public.documents VALUES ('dc678e55-e61e-42f7-a673-4c747a4b832b', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00');
INSERT INTO public.documents VALUES ('97c9a2e2-7e1b-423b-a359-f99a6e9a8beb', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00');
INSERT INTO public.documents VALUES ('1b118fe7-4809-483b-ab36-2fd4e48c9b53', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', 'f55a86e5-d457-4c02-a078-f44e637fd6b3', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00');
INSERT INTO public.documents VALUES ('34dad368-8490-47b2-bd72-27382061a07b', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00');
INSERT INTO public.documents VALUES ('b2e933ac-fb26-4435-a33a-d8a4e3e410d6', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00');
INSERT INTO public.documents VALUES ('9ce3bdf0-9db8-4180-98ba-aac39e969157', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00');
INSERT INTO public.documents VALUES ('21b6cf3b-4aa3-4bcf-805d-8ff2760411e2', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_submission', '6837fa68-d256-472c-a5ee-07629cc38d64', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('7b7e83bf-876b-4149-8d58-242e4a88a7bc', '49ceff12-276a-4250-b082-92fe2510745a', 'signage', 34, '2026-09-29 13:50:27.591033+00', '2026-09-29 13:50:27.59312+00');
INSERT INTO public.edition_counters VALUES ('4e00bff7-fe15-4172-aded-9b90f6d9352f', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_design', 1, '2026-09-29 13:50:27.629441+00', '2026-09-29 13:50:27.629441+00');
INSERT INTO public.edition_counters VALUES ('39e93eed-d424-42f9-8014-720f2e0202b1', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_item', 1, '2026-09-29 13:50:27.629441+00', '2026-09-29 13:50:27.629441+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('4c8114f9-c881-4134-88b3-12944a33c99b', '49ceff12-276a-4250-b082-92fe2510745a', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-29 13:50:26.673831+00', '2026-09-29 13:50:26.673831+00');
INSERT INTO public.edition_deadlines VALUES ('d3a093f9-fc1b-4fa5-a76a-abd9555db148', '49ceff12-276a-4250-b082-92fe2510745a', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-29 13:50:26.676668+00', '2026-09-29 13:50:26.676668+00');
INSERT INTO public.edition_deadlines VALUES ('a8433c6e-a05f-4a73-be38-78f4e260cac3', '49ceff12-276a-4250-b082-92fe2510745a', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-29 13:50:26.67833+00', '2026-09-29 13:50:26.67833+00');
INSERT INTO public.edition_deadlines VALUES ('71d271bf-aab1-40ce-8617-6ed82af896ba', '49ceff12-276a-4250-b082-92fe2510745a', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-29 13:50:26.680104+00', '2026-09-29 13:50:26.680104+00');
INSERT INTO public.edition_deadlines VALUES ('a87914f6-1563-44a3-a352-37949de35613', '49ceff12-276a-4250-b082-92fe2510745a', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-29 13:50:26.681785+00', '2026-09-29 13:50:26.681785+00');
INSERT INTO public.edition_deadlines VALUES ('cd837d87-b3d2-44b5-9fbf-e67008c1e4cb', '49ceff12-276a-4250-b082-92fe2510745a', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-29 13:50:26.683481+00', '2026-09-29 13:50:26.683481+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('49ceff12-276a-4250-b082-92fe2510745a', '06a6234c-baa4-44f0-97fd-378755835c20', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-29 13:50:26.669869+00', '2026-09-29 13:50:26.669869+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('06a6234c-baa4-44f0-97fd-378755835c20', '63444b23-4629-4f13-9723-4e24f9998b24', 'UK Construction Week', 'UKCW', '2026-09-29 13:50:26.62667+00', '2026-09-29 13:50:26.62667+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('051badeb-0635-4dd2-a796-95ea5a8667cf', '49ceff12-276a-4250-b082-92fe2510745a', 'Exhibitor Co', 'A10', '355bbc1f-3fd8-4322-8a99-557b019b8513', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '331c642e-6836-44fd-a5b7-f2ade3cffef2', '2026-09-29 13:50:26.933414+00', '2026-09-29 13:50:26.933414+00');
INSERT INTO public.exhibitors VALUES ('adbaadda-50c7-4087-b7ed-fb73539fc8c9', '49ceff12-276a-4250-b082-92fe2510745a', 'SteelFrame Systems', 'A20', '355bbc1f-3fd8-4322-8a99-557b019b8513', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', '2026-09-29 13:50:26.937004+00', '2026-09-29 13:50:26.937004+00');
INSERT INTO public.exhibitors VALUES ('785a77e1-86dc-4bb2-8e08-9ec741d82910', '49ceff12-276a-4250-b082-92fe2510745a', 'BrickWorks UK', 'A30', '355bbc1f-3fd8-4322-8a99-557b019b8513', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '331c642e-6836-44fd-a5b7-f2ade3cffef2', '2026-09-29 13:50:26.939631+00', '2026-09-29 13:50:26.939631+00');
INSERT INTO public.exhibitors VALUES ('4c4e5d8b-576f-4698-92df-73229c6d5150', '49ceff12-276a-4250-b082-92fe2510745a', 'Timber Trade Ltd', 'B10', '355bbc1f-3fd8-4322-8a99-557b019b8513', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', '2026-09-29 13:50:26.942814+00', '2026-09-29 13:50:26.942814+00');
INSERT INTO public.exhibitors VALUES ('f27a2fa2-aa02-4770-9fca-1fc1df85b9c6', '49ceff12-276a-4250-b082-92fe2510745a', 'GlassTech', 'B20', '355bbc1f-3fd8-4322-8a99-557b019b8513', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '331c642e-6836-44fd-a5b7-f2ade3cffef2', '2026-09-29 13:50:26.945373+00', '2026-09-29 13:50:26.945373+00');
INSERT INTO public.exhibitors VALUES ('fbca0339-60cf-4c06-8b06-fd74ec41c043', '49ceff12-276a-4250-b082-92fe2510745a', 'Insulate Pro', 'B30', '355bbc1f-3fd8-4322-8a99-557b019b8513', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', '2026-09-29 13:50:26.947886+00', '2026-09-29 13:50:26.947886+00');
INSERT INTO public.exhibitors VALUES ('3604eaba-53ca-457f-888f-496d0d09e494', '49ceff12-276a-4250-b082-92fe2510745a', 'RoofRight', 'C10', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '331c642e-6836-44fd-a5b7-f2ade3cffef2', '2026-09-29 13:50:26.950262+00', '2026-09-29 13:50:26.950262+00');
INSERT INTO public.exhibitors VALUES ('2f8cba79-a9c7-470a-b19d-55c8e3570ee6', '49ceff12-276a-4250-b082-92fe2510745a', 'PlantHire Direct', 'C20', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', '2026-09-29 13:50:26.952879+00', '2026-09-29 13:50:26.952879+00');
INSERT INTO public.exhibitors VALUES ('1b855196-75b1-4738-9f9c-573dc8ddf0fa', '49ceff12-276a-4250-b082-92fe2510745a', 'SafetyFirst PPE', 'D10', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-29 13:50:26.955172+00', '2026-09-29 13:50:26.955172+00');
INSERT INTO public.exhibitors VALUES ('8aa815d1-5eb4-4b67-923e-059b67e9d271', '49ceff12-276a-4250-b082-92fe2510745a', 'ToolMart Retail', 'D20', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-29 13:50:26.958474+00', '2026-09-29 13:50:26.958474+00');
INSERT INTO public.exhibitors VALUES ('f73fed5b-f0dd-4882-84c2-3a79c95caf37', '49ceff12-276a-4250-b082-92fe2510745a', 'EcoBuild Materials', 'D30', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-29 13:50:26.961429+00', '2026-09-29 13:50:26.961429+00');
INSERT INTO public.exhibitors VALUES ('9d7b1e93-a947-4520-bd6d-5713dae1fa7a', '49ceff12-276a-4250-b082-92fe2510745a', 'SiteWise Software', 'D40', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-29 13:50:26.964764+00', '2026-09-29 13:50:26.964764+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('a14cb03e-4f2c-418b-8fc9-521e38f16a5a', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'venue', 'venue', '13b754dd-5d21-49bd-aa73-2113259c8bf2', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.912542+00', '2026-09-29 13:50:26.912542+00');
INSERT INTO public.external_grants VALUES ('bd844fa2-84c9-4a74-87e3-be6920e0f18f', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.917086+00', '2026-09-29 13:50:26.917086+00');
INSERT INTO public.external_grants VALUES ('70ca6853-852a-40e9-966b-749dd8a84ff0', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.922203+00', '2026-09-29 13:50:26.922203+00');
INSERT INTO public.external_grants VALUES ('d6f8d3f4-de88-4e16-977f-6a6fadee7299', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'supplier', 'supplier', '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.926098+00', '2026-09-29 13:50:26.926098+00');
INSERT INTO public.external_grants VALUES ('b58de774-31e4-4eca-b53e-1b9b8537da16', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'sponsor', 'sponsor', '231158fc-fecf-4074-bea3-65dadef79206', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.930128+00', '2026-09-29 13:50:26.930128+00');
INSERT INTO public.external_grants VALUES ('a080665f-7f01-4169-a8e5-a20cda883188', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'exhibitor', 'exhibitor', '051badeb-0635-4dd2-a796-95ea5a8667cf', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-29 13:50:26.566+00', NULL, '2026-09-29 13:50:26.969419+00', '2026-09-29 13:50:26.969419+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('355bbc1f-3fd8-4322-8a99-557b019b8513', '49ceff12-276a-4250-b082-92fe2510745a', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-29 13:50:26.687215+00', '2026-09-29 13:50:26.687215+00');
INSERT INTO public.halls VALUES ('ba33cedc-3a02-4f47-80a0-5a91911a9356', '49ceff12-276a-4250-b082-92fe2510745a', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-29 13:50:26.691211+00', '2026-09-29 13:50:26.691211+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('847bfd47-4b0e-4e48-b779-b35c16f7564c', '63444b23-4629-4f13-9723-4e24f9998b24', 'Hanging banner', 'hanging_banner', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'rigged', true, 0, '2026-09-29 13:50:26.874966+00', '2026-09-29 13:50:26.874966+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('21a4e2b9-5cf6-4f2e-9199-e12367354467', '63444b23-4629-4f13-9723-4e24f9998b24', 'Foamex board', 'foamex_board', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'wall_mounted', false, 1, '2026-09-29 13:50:26.877715+00', '2026-09-29 13:50:26.877715+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('aaa3130e-cff3-4557-8a53-66736a24ef15', '63444b23-4629-4f13-9723-4e24f9998b24', 'Fabric graphic', 'fabric_graphic', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'shell_mounted', false, 2, '2026-09-29 13:50:26.880142+00', '2026-09-29 13:50:26.880142+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('53b78244-16e1-4aa3-831d-616c9b7930cf', '63444b23-4629-4f13-9723-4e24f9998b24', 'Floor vinyl', 'floor_vinyl', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'floor', false, 3, '2026-09-29 13:50:26.883285+00', '2026-09-29 13:50:26.883285+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('90af1e87-9660-4843-81af-bd279ea21523', '63444b23-4629-4f13-9723-4e24f9998b24', 'Aisle sign', 'aisle_sign', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'rigged', true, 4, '2026-09-29 13:50:26.885316+00', '2026-09-29 13:50:26.885316+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('ba881181-b8e8-4393-b3cf-2bc2c29b4870', '63444b23-4629-4f13-9723-4e24f9998b24', 'Entrance feature', 'entrance_feature', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'freestanding', true, 5, '2026-09-29 13:50:26.887277+00', '2026-09-29 13:50:26.887277+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('bb7a09da-e2fc-491b-a70e-bdf5abc04b9e', '63444b23-4629-4f13-9723-4e24f9998b24', 'Registration', 'registration', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'freestanding', false, 6, '2026-09-29 13:50:26.889974+00', '2026-09-29 13:50:26.889974+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('c869e794-a76a-4352-8048-44f64a2bc74b', '63444b23-4629-4f13-9723-4e24f9998b24', 'Seminar theatre', 'seminar_theatre', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'freestanding', false, 7, '2026-09-29 13:50:26.892452+00', '2026-09-29 13:50:26.892452+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('15f4669c-e1b0-4f16-84a5-d71d3fbc62cc', '63444b23-4629-4f13-9723-4e24f9998b24', 'Feature area', 'feature_area', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'freestanding', false, 8, '2026-09-29 13:50:26.89423+00', '2026-09-29 13:50:26.89423+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('14bcf290-abbe-44eb-9c5d-10e0fa7575b4', '63444b23-4629-4f13-9723-4e24f9998b24', 'External', 'external', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'freestanding', true, 9, '2026-09-29 13:50:26.895894+00', '2026-09-29 13:50:26.895894+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('93c23850-f66c-4e49-8149-123082670375', '63444b23-4629-4f13-9723-4e24f9998b24', 'Digital screen', 'digital_screen', '6e545017-c54f-4d97-9f4b-780664c1d10f', 'digital', false, 10, '2026-09-29 13:50:26.897973+00', '2026-09-29 13:50:26.897973+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('81382986-7167-4d36-a863-9b92f0b2dfdf', '63444b23-4629-4f13-9723-4e24f9998b24', 'Branded lanyards', 'lanyard', '6e545017-c54f-4d97-9f4b-780664c1d10f', NULL, false, 11, '2026-09-29 13:50:26.900424+00', '2026-09-29 13:50:26.900424+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('fd0ddd6d-1585-4288-afae-0a261d2ab164', '63444b23-4629-4f13-9723-4e24f9998b24', 'Show bags', 'show_bag', '6e545017-c54f-4d97-9f4b-780664c1d10f', NULL, false, 12, '2026-09-29 13:50:26.902207+00', '2026-09-29 13:50:26.902207+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('87b7ae5b-1edb-432a-8e77-01da6462613d', '63444b23-4629-4f13-9723-4e24f9998b24', 'Registration branding', 'reg_branding', '6e545017-c54f-4d97-9f4b-780664c1d10f', NULL, false, 13, '2026-09-29 13:50:26.904232+00', '2026-09-29 13:50:26.904232+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('92b5e69c-5570-4c84-8125-afd526440e9b', '63444b23-4629-4f13-9723-4e24f9998b24', 'Other signage', 'other_signage', '6e545017-c54f-4d97-9f4b-780664c1d10f', NULL, false, 14, '2026-09-29 13:50:26.90596+00', '2026-09-29 13:50:26.90596+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('f04d2205-c8a1-4afe-8c66-6bc3ff79537a', '63444b23-4629-4f13-9723-4e24f9998b24', 'Other sponsorship item', 'other_sponsorship', '6e545017-c54f-4d97-9f4b-780664c1d10f', NULL, false, 15, '2026-09-29 13:50:26.907678+00', '2026-09-29 13:50:26.907678+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('1370d254-5006-4b31-80b2-b97a11ee487e', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-29 13:50:26.695315+00', '2026-09-29 13:50:26.695315+00');
INSERT INTO public.locations VALUES ('f4991cc9-b07f-4c9c-b846-264a4795e108', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-29 13:50:26.699984+00', '2026-09-29 13:50:26.699984+00');
INSERT INTO public.locations VALUES ('b24abe17-624a-40c7-8fa7-daf75aaa3ed2', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-29 13:50:26.704812+00', '2026-09-29 13:50:26.704812+00');
INSERT INTO public.locations VALUES ('c0ad4a11-0cd2-4c9e-8907-40c70a612531', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-29 13:50:26.708292+00', '2026-09-29 13:50:26.708292+00');
INSERT INTO public.locations VALUES ('e26f0e64-0042-4dd1-aac6-f88112f59ae3', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-29 13:50:26.711804+00', '2026-09-29 13:50:26.711804+00');
INSERT INTO public.locations VALUES ('5d5d9502-1809-4de9-b0ad-93aac1eebcbd', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-29 13:50:26.715016+00', '2026-09-29 13:50:26.715016+00');
INSERT INTO public.locations VALUES ('21eb1a39-0fbb-4ea4-a581-f38d7d465ee0', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-29 13:50:26.718465+00', '2026-09-29 13:50:26.718465+00');
INSERT INTO public.locations VALUES ('f091ec84-a5eb-484c-a008-1c98d167e1b7', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-29 13:50:26.721461+00', '2026-09-29 13:50:26.721461+00');
INSERT INTO public.locations VALUES ('c0875444-89ef-4030-9e81-93f363564e57', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-29 13:50:26.724439+00', '2026-09-29 13:50:26.724439+00');
INSERT INTO public.locations VALUES ('163ddf8e-00e0-4531-ae97-973b492ca82d', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-29 13:50:26.727295+00', '2026-09-29 13:50:26.727295+00');
INSERT INTO public.locations VALUES ('e409acdc-9347-4164-9029-e2b8011b4d05', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-29 13:50:26.730448+00', '2026-09-29 13:50:26.730448+00');
INSERT INTO public.locations VALUES ('40a99430-357f-483c-b2ad-c62930f3007d', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-29 13:50:26.733066+00', '2026-09-29 13:50:26.733066+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('78386060-eb8e-4357-8d70-ea427240ec28', '00000000-0000-4000-8000-000000000001', '63444b23-4629-4f13-9723-4e24f9998b24', 'admin', '2026-09-29 13:50:26.60277+00', '2026-09-29 13:50:26.60277+00', '{}');
INSERT INTO public.memberships VALUES ('264f476a-01e9-4611-8b7c-3c92444455f5', '00000000-0000-4000-8000-000000000002', '63444b23-4629-4f13-9723-4e24f9998b24', 'ops', '2026-09-29 13:50:26.607907+00', '2026-09-29 13:50:26.607907+00', '{}');
INSERT INTO public.memberships VALUES ('fb4e6217-8d8a-41c3-920e-dd40527bec8a', '00000000-0000-4000-8000-000000000004', '63444b23-4629-4f13-9723-4e24f9998b24', 'sales', '2026-09-29 13:50:26.615282+00', '2026-09-29 13:50:26.615282+00', '{}');
INSERT INTO public.memberships VALUES ('1f86ece1-0d4a-4187-b17c-66c69c594135', '00000000-0000-4000-8000-000000000005', '63444b23-4629-4f13-9723-4e24f9998b24', 'event_director', '2026-09-29 13:50:26.619002+00', '2026-09-29 13:50:26.619002+00', '{}');
INSERT INTO public.memberships VALUES ('05301320-096b-43cc-a52b-0b8a15616fd6', '00000000-0000-4000-8000-000000000006', '63444b23-4629-4f13-9723-4e24f9998b24', 'viewer', '2026-09-29 13:50:26.623308+00', '2026-09-29 13:50:26.623308+00', '{}');
INSERT INTO public.memberships VALUES ('f49560c8-6226-4c62-94cd-1276c121187e', '00000000-0000-4000-8000-000000000003', '63444b23-4629-4f13-9723-4e24f9998b24', 'marketing', '2026-09-29 13:50:26.611451+00', '2026-09-29 13:50:27.737038+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('63444b23-4629-4f13-9723-4e24f9998b24', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-29 13:50:26.595092+00', '2026-09-29 13:50:26.595092+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'ba881181-b8e8-4393-b3cf-2bc2c29b4870', '355bbc1f-3fd8-4322-8a99-557b019b8513', '1370d254-5006-4b31-80b2-b97a11ee487e', 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', 'bddabcfa-4682-464c-a959-41496a8fd0d7', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'aedb28d6-1e3f-4a26-93e5-137fa5b38a14', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:26.974572+00', '2026-09-29 13:50:26.984159+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('4e1c8307-d5fb-422f-83e9-6675a1612cd7', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', 'bb7a09da-e2fc-491b-a70e-bdf5abc04b9e', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'f4991cc9-b07f-4c9c-b846-264a4795e108', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'bb077508-c257-4c31-8cd8-4cd8a6f78c0f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.010067+00', '2026-09-29 13:50:27.014847+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('cb170bef-84bb-41e5-ae15-165a5652af1f', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '847bfd47-4b0e-4e48-b779-b35c16f7564c', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'b24abe17-624a-40c7-8fa7-daf75aaa3ed2', 'ops', '00000000-0000-4000-8000-000000000002', '231158fc-fecf-4074-bea3-65dadef79206', 'b98f4113-2eed-4686-9e74-d5feeab5cf3b', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '8b7ab618-1533-4a80-b6f5-14efaa8671e3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.038298+00', '2026-09-29 13:50:27.04529+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('5d965425-2291-419b-b6fa-237efb649a08', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'c869e794-a76a-4352-8048-44f64a2bc74b', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'c0ad4a11-0cd2-4c9e-8907-40c70a612531', 'marketing', '00000000-0000-4000-8000-000000000003', '002ee837-3b82-4348-94ef-bb854ac3f1a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '8bd5cb97-0e46-4755-8b6c-5f61479f3b59', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.070215+00', '2026-09-29 13:50:27.07614+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('c20777a0-29a6-4a70-bce3-9ee0bb4ef80c', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '53b78244-16e1-4aa3-831d-616c9b7930cf', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'e26f0e64-0042-4dd1-aac6-f88112f59ae3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'a5843bef-00b3-40ed-bd99-9f007cca5814', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.098725+00', '2026-09-29 13:50:27.103391+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dd98cde6-1e98-4b9c-93ca-be19c030d426', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '15f4669c-e1b0-4f16-84a5-d71d3fbc62cc', '355bbc1f-3fd8-4322-8a99-557b019b8513', '5d5d9502-1809-4de9-b0ad-93aac1eebcbd', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '91a221f1-0509-4933-b01d-a10ce8e0e817', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.122446+00', '2026-09-29 13:50:27.127054+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "fc1393f4-3f78-4631-ada7-42f690841933", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('86ca805f-a8fc-43ac-85a1-3820e8060146', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '847bfd47-4b0e-4e48-b779-b35c16f7564c', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '21eb1a39-0fbb-4ea4-a581-f38d7d465ee0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '99e7eb5a-1460-4cc8-a151-107776beb4ea', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.146994+00', '2026-09-29 13:50:27.151658+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d13c5d0f-f49c-429d-af3b-377d67c8bd73', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '90af1e87-9660-4843-81af-bd279ea21523', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'f091ec84-a5eb-484c-a008-1c98d167e1b7', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'e7a4bb62-fa31-4178-bd1c-2453cbafdf95', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.176676+00', '2026-09-29 13:50:27.18123+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('712b2221-a138-44bf-b38f-bedbc3c594a3', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'c869e794-a76a-4352-8048-44f64a2bc74b', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'c0875444-89ef-4030-9e81-93f363564e57', 'marketing', '00000000-0000-4000-8000-000000000003', '002ee837-3b82-4348-94ef-bb854ac3f1a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '50ec5f64-ca66-4774-ab98-4c6a6ca852d3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.203087+00', '2026-09-29 13:50:27.208313+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('9665bc68-f9da-4ec6-b219-4c1812cb5db4', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'aaa3130e-cff3-4557-8a53-66736a24ef15', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '163ddf8e-00e0-4531-ae97-973b492ca82d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '24beeb57-7a42-4b73-ab50-5df0289357ae', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.227232+00', '2026-09-29 13:50:27.232499+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('96eee195-28b5-4570-b003-2849e5e50bf6', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '14bcf290-abbe-44eb-9c5d-10e0fa7575b4', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'e409acdc-9347-4164-9029-e2b8011b4d05', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '2cf661b6-9420-4547-9771-d45ab7ca0336', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.246485+00', '2026-09-29 13:50:27.250172+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('58df91d3-9a40-4c6e-8c79-75fbfe79e2cb', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '40a99430-357f-483c-b2ad-c62930f3007d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'b8e90d12-ea8c-4336-9ee5-0521b7315b4d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.272367+00', '2026-09-29 13:50:27.277209+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4e430c0a-6f7d-411d-b651-3b89932293a2', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '93c23850-f66c-4e49-8149-123082670375', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'f4991cc9-b07f-4c9c-b846-264a4795e108', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '67af8422-370b-45e8-9824-7a06a04166d3', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '1cbe755c-85e3-4dfa-b636-500b7416ad9a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.297189+00', '2026-09-29 13:50:27.30147+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "fc1393f4-3f78-4631-ada7-42f690841933", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('fd52f021-d9bc-452c-88dc-42e1df1eaeaf', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '90af1e87-9660-4843-81af-bd279ea21523', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'b24abe17-624a-40c7-8fa7-daf75aaa3ed2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '91b8dcc7-e143-4f87-972d-3c890d826793', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.318636+00', '2026-09-29 13:50:27.322663+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9947f2de-2e68-430d-8722-b0a696b24241', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'e26f0e64-0042-4dd1-aac6-f88112f59ae3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '80d99452-0c5e-4492-8b24-cf655be24624', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.339226+00', '2026-09-29 13:50:27.343212+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6589098f-92d2-496d-8ae7-0ec2e593e27b', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '15f4669c-e1b0-4f16-84a5-d71d3fbc62cc', '355bbc1f-3fd8-4322-8a99-557b019b8513', '5d5d9502-1809-4de9-b0ad-93aac1eebcbd', 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '03681425-92f0-4700-b314-709deb085c8b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.364475+00', '2026-09-29 13:50:27.369981+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('26b23435-f98c-4a9f-ad65-924e1b0220ad', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '847bfd47-4b0e-4e48-b779-b35c16f7564c', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'f091ec84-a5eb-484c-a008-1c98d167e1b7', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '7de001d4-5537-4607-8a5f-484b248122a1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.39289+00', '2026-09-29 13:50:27.397495+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('307ed765-8683-4f4d-a282-aa59c3dbab13', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'aaa3130e-cff3-4557-8a53-66736a24ef15', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '163ddf8e-00e0-4531-ae97-973b492ca82d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '13c9d203-7b72-47e3-85cf-f0ddc71e4d6f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.415481+00', '2026-09-29 13:50:27.421757+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a27ce0b5-1900-4c6d-80d2-d7436790aeca', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '847bfd47-4b0e-4e48-b779-b35c16f7564c', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'b24abe17-624a-40c7-8fa7-daf75aaa3ed2', 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', 'b98f4113-2eed-4686-9e74-d5feeab5cf3b', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'eda07a0b-fe00-4fba-aded-d5ccf6dfee17', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.441044+00', '2026-09-29 13:50:27.449465+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('bf165f7a-c6a3-4f1b-8275-f70e77087b91', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '40a99430-357f-483c-b2ad-c62930f3007d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.471743+00', '2026-09-29 13:50:27.471743+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('50ba9f49-c169-41f7-b14c-a91bc29ef6dd', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'f4991cc9-b07f-4c9c-b846-264a4795e108', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.476453+00', '2026-09-29 13:50:27.476453+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('49de7c09-f6e9-4310-b69f-e5f9d94dce88', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', 'bb7a09da-e2fc-491b-a70e-bdf5abc04b9e', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '21eb1a39-0fbb-4ea4-a581-f38d7d465ee0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.481231+00', '2026-09-29 13:50:27.481231+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('89ca57bc-c0ed-4a88-a895-85242b5a82f0', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '93c23850-f66c-4e49-8149-123082670375', '355bbc1f-3fd8-4322-8a99-557b019b8513', '5d5d9502-1809-4de9-b0ad-93aac1eebcbd', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '67af8422-370b-45e8-9824-7a06a04166d3', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.485595+00', '2026-09-29 13:50:27.485595+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "fc1393f4-3f78-4631-ada7-42f690841933", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2842ed7d-1167-4730-afc9-071ac8d4fb32', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '53b78244-16e1-4aa3-831d-616c9b7930cf', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'c0875444-89ef-4030-9e81-93f363564e57', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.49018+00', '2026-09-29 13:50:27.49018+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7e02ce35-0a4a-4e3e-8aae-0c9affa157f8', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'c869e794-a76a-4352-8048-44f64a2bc74b', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'c0875444-89ef-4030-9e81-93f363564e57', 'marketing', '00000000-0000-4000-8000-000000000003', '002ee837-3b82-4348-94ef-bb854ac3f1a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.495285+00', '2026-09-29 13:50:27.495285+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('8f5d86fc-7acc-4fe4-9f0a-30f3627fe772', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '14bcf290-abbe-44eb-9c5d-10e0fa7575b4', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'e409acdc-9347-4164-9029-e2b8011b4d05', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.500271+00', '2026-09-29 13:50:27.500271+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "fc1393f4-3f78-4631-ada7-42f690841933", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('00c3e77a-5fac-4233-a7aa-52c339291a0f', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', 'e409acdc-9347-4164-9029-e2b8011b4d05', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.505933+00', '2026-09-29 13:50:27.505933+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0a6b18fa-741d-4d5e-a27b-923c916a8f98', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', '355bbc1f-3fd8-4322-8a99-557b019b8513', 'e26f0e64-0042-4dd1-aac6-f88112f59ae3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 'f4fa473b-78fb-44ef-b51f-fe2c095f9f90', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.510134+00', '2026-09-29 13:50:27.51373+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7a10444d-880d-4d2c-8b7e-fd3cbab0c7cc', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'ba881181-b8e8-4393-b3cf-2bc2c29b4870', '355bbc1f-3fd8-4322-8a99-557b019b8513', '1370d254-5006-4b31-80b2-b97a11ee487e', 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', 'bddabcfa-4682-464c-a959-41496a8fd0d7', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '1ce9112d-3e9f-4af4-b617-bd188b22aadf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.530541+00', '2026-09-29 13:50:27.537611+00', 'signage', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', NULL, NULL, NULL, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('0f737299-3901-4c21-9802-b535111d27e4', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '21a4e2b9-5cf6-4f2e-9199-e12367354467', 'ba33cedc-3a02-4f47-80a0-5a91911a9356', '40a99430-357f-483c-b2ad-c62930f3007d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.552566+00', '2026-09-29 13:50:27.552566+00', 'signage', 'organiser', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8f1ff7d4-b924-4b95-b0e5-84e99c77cffd', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '81382986-7167-4d36-a863-9b92f0b2dfdf', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, '6bd5e13d-25db-4ac0-abf7-5e00545844ad', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.557537+00', '2026-09-29 13:50:27.562119+00', 'sponsorship_item', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', '2026-12-13', NULL, 9000.00, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('f81daeac-0288-434a-8c58-2d0cb1db8303', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'fd0ddd6d-1585-4288-afae-0a261d2ab164', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '231158fc-fecf-4074-bea3-65dadef79206', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.577553+00', '2026-09-29 13:50:27.577553+00', 'sponsorship_item', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}, {"stepId": "c840d56a-3c2f-417c-a94a-7cd65f8b2abc", "userId": null}]', '2026-10-19', NULL, 12500.00, '2026-09-19 13:50:26.566+00', NULL, NULL);
INSERT INTO public.signage_items VALUES ('a858160c-810f-4725-aaa1-ab436c31929d', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '87b7ae5b-1edb-432a-8e77-01da6462613d', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.581885+00', '2026-09-29 13:50:27.581885+00', 'sponsorship_item', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', '2027-01-27', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2af56236-fcfb-4ef5-b822-1260aee45c71', '49ceff12-276a-4250-b082-92fe2510745a', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', 'f04d2205-c8a1-4afe-8c66-6bc3ff79537a', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '6e545017-c54f-4d97-9f4b-780664c1d10f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.586835+00', '2026-09-29 13:50:27.586835+00', 'sponsorship_item', 'sponsor', '[{"stepId": "a278f705-0c91-4d12-9d17-f0a57f1458a2", "userId": null}, {"stepId": "32a2efba-9b00-4fcf-badc-55a63405d2c7", "userId": null}]', '2026-10-17', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('68a1df1e-d5b1-4be2-a203-2219952198ed', '49ceff12-276a-4250-b082-92fe2510745a', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '355bbc1f-3fd8-4322-8a99-557b019b8513', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '1eea99c2-a894-4a61-bf39-a9773c8ddcea', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-29 13:50:27.62734+00', '2026-09-29 13:50:27.62734+00', 'stand_design', 'organiser', '[{"stepId": "c550ab40-0786-406d-8320-3a8b2a00bccb", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "6eb9663d-aa29-4402-a102-cc4ec384e31b", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('0ab125e8-a8e4-48ec-9b73-e4f265fc0790', '49ceff12-276a-4250-b082-92fe2510745a', '9947f2de-2e68-430d-8722-b0a696b24241', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '3769ac9b-3bac-4f38-9cb6-9a1902713a9f', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-29 13:50:27.35829+00', '2026-09-29 13:50:27.35829+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('b98f4113-2eed-4686-9e74-d5feeab5cf3b', '231158fc-fecf-4074-bea3-65dadef79206', 'Logo on 6 hanging banners', 6, '2026-09-29 13:50:26.78925+00', '2026-09-29 13:50:26.78925+00');
INSERT INTO public.sponsor_entitlements VALUES ('bddabcfa-4682-464c-a959-41496a8fd0d7', '231158fc-fecf-4074-bea3-65dadef79206', 'Entrance feature branding', 1, '2026-09-29 13:50:26.792735+00', '2026-09-29 13:50:26.792735+00');
INSERT INTO public.sponsor_entitlements VALUES ('32c8fc73-02ef-4c44-91e9-fd21fc9a9095', '002ee837-3b82-4348-94ef-bb854ac3f1a7', 'Seminar theatre branding', 1, '2026-09-29 13:50:26.799121+00', '2026-09-29 13:50:26.799121+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('231158fc-fecf-4074-bea3-65dadef79206', '49ceff12-276a-4250-b082-92fe2510745a', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-29 13:50:26.785322+00', '2026-09-29 13:50:26.785322+00');
INSERT INTO public.sponsors VALUES ('002ee837-3b82-4348-94ef-bb854ac3f1a7', '49ceff12-276a-4250-b082-92fe2510745a', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-29 13:50:26.79606+00', '2026-09-29 13:50:26.79606+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('52d75dbb-51fc-4b7a-b6d1-e384f94fdc7c', '49ceff12-276a-4250-b082-92fe2510745a', '051badeb-0635-4dd2-a796-95ea5a8667cf', 'STD-BIRM27-A10', '331c642e-6836-44fd-a5b7-f2ade3cffef2', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-23 13:50:26.566+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.633231+00', '2026-09-29 13:50:27.633231+00');
INSERT INTO public.stand_submissions VALUES ('6bf9e4d3-f5b4-4230-8ceb-f5fed1ae9463', '49ceff12-276a-4250-b082-92fe2510745a', 'adbaadda-50c7-4087-b7ed-fb73539fc8c9', 'STD-BIRM27-A20', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-23 13:50:26.566+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.655785+00', '2026-09-29 13:50:27.655785+00');
INSERT INTO public.stand_submissions VALUES ('5a580172-ce6b-44ef-a128-30a4bfa7d742', '49ceff12-276a-4250-b082-92fe2510745a', '785a77e1-86dc-4bb2-8e08-9ec741d82910', 'STD-BIRM27-A30', '331c642e-6836-44fd-a5b7-f2ade3cffef2', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-23 13:50:26.566+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.669911+00', '2026-09-29 13:50:27.669911+00');
INSERT INTO public.stand_submissions VALUES ('f55a86e5-d457-4c02-a078-f44e637fd6b3', '49ceff12-276a-4250-b082-92fe2510745a', '4c4e5d8b-576f-4698-92df-73229c6d5150', 'STD-BIRM27-B10', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-23 13:50:26.566+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.68684+00', '2026-09-29 13:50:27.68684+00');
INSERT INTO public.stand_submissions VALUES ('6837fa68-d256-472c-a5ee-07629cc38d64', '49ceff12-276a-4250-b082-92fe2510745a', 'f27a2fa2-aa02-4770-9fca-1fc1df85b9c6', 'STD-BIRM27-B20', '331c642e-6836-44fd-a5b7-f2ade3cffef2', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-23 13:50:26.566+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.704032+00', '2026-09-29 13:50:27.704032+00');
INSERT INTO public.stand_submissions VALUES ('237f57e9-e52a-4d0c-ab89-67dd9b1d9403', '49ceff12-276a-4250-b082-92fe2510745a', 'fbca0339-60cf-4c06-8b06-fd74ec41c043', 'STD-BIRM27-B30', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 0, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.723124+00', '2026-09-29 13:50:27.723124+00');
INSERT INTO public.stand_submissions VALUES ('2a46a604-7bff-4f04-b681-044fe35722ef', '49ceff12-276a-4250-b082-92fe2510745a', '3604eaba-53ca-457f-888f-496d0d09e494', 'STD-BIRM27-C10', '331c642e-6836-44fd-a5b7-f2ade3cffef2', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 0, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.727525+00', '2026-09-29 13:50:27.727525+00');
INSERT INTO public.stand_submissions VALUES ('1e5d03f8-acf4-4481-b41c-9a69ec70f64a', '49ceff12-276a-4250-b082-92fe2510745a', '2f8cba79-a9c7-470a-b19d-55c8e3570ee6', 'STD-BIRM27-C20', '6be56e7a-f1e1-4dc5-9816-3fb83916b681', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '26af3260-b8e1-4d57-b1c7-03cba896c51b', 0, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:50:27.732729+00', '2026-09-29 13:50:27.732729+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('3769ac9b-3bac-4f38-9cb6-9a1902713a9f', '27c85bec-359b-45fb-87ff-edc23d590499');
INSERT INTO public.supplier_service_links VALUES ('3769ac9b-3bac-4f38-9cb6-9a1902713a9f', 'cf241e69-c4fb-4713-9c63-f985f287707a');
INSERT INTO public.supplier_service_links VALUES ('10cd3009-4450-47d8-9fa2-da35b63b6401', '96e44c7f-3b43-4c9b-b4f1-fb87a1f75376');
INSERT INTO public.supplier_service_links VALUES ('10cd3009-4450-47d8-9fa2-da35b63b6401', 'cf241e69-c4fb-4713-9c63-f985f287707a');
INSERT INTO public.supplier_service_links VALUES ('10cd3009-4450-47d8-9fa2-da35b63b6401', 'd1ee061c-7a48-4f1d-b670-7bc571a26f67');
INSERT INTO public.supplier_service_links VALUES ('67af8422-370b-45e8-9824-7a06a04166d3', '0a99c123-e91e-43bf-afdb-735d0bab8ab7');
INSERT INTO public.supplier_service_links VALUES ('67af8422-370b-45e8-9824-7a06a04166d3', 'd1ee061c-7a48-4f1d-b670-7bc571a26f67');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('27c85bec-359b-45fb-87ff-edc23d590499', '63444b23-4629-4f13-9723-4e24f9998b24', 'Signage print', 1, false, '2026-09-29 13:50:26.748278+00', '2026-09-29 13:50:26.748278+00');
INSERT INTO public.supplier_services VALUES ('0a99c123-e91e-43bf-afdb-735d0bab8ab7', '63444b23-4629-4f13-9723-4e24f9998b24', 'Digital screens & AV', 2, false, '2026-09-29 13:50:26.750909+00', '2026-09-29 13:50:26.750909+00');
INSERT INTO public.supplier_services VALUES ('96e44c7f-3b43-4c9b-b4f1-fb87a1f75376', '63444b23-4629-4f13-9723-4e24f9998b24', 'Rigging', 3, false, '2026-09-29 13:50:26.753169+00', '2026-09-29 13:50:26.753169+00');
INSERT INTO public.supplier_services VALUES ('cf241e69-c4fb-4713-9c63-f985f287707a', '63444b23-4629-4f13-9723-4e24f9998b24', 'Installation', 4, false, '2026-09-29 13:50:26.755407+00', '2026-09-29 13:50:26.755407+00');
INSERT INTO public.supplier_services VALUES ('d1ee061c-7a48-4f1d-b670-7bc571a26f67', '63444b23-4629-4f13-9723-4e24f9998b24', 'Staffing', 5, false, '2026-09-29 13:50:26.757546+00', '2026-09-29 13:50:26.757546+00');
INSERT INTO public.supplier_services VALUES ('b8b22ef9-feea-439f-990a-eb17aa8a44b2', '63444b23-4629-4f13-9723-4e24f9998b24', 'Furniture', 6, false, '2026-09-29 13:50:26.75949+00', '2026-09-29 13:50:26.75949+00');
INSERT INTO public.supplier_services VALUES ('002f0a13-b286-40cc-9914-5c509a232501', '63444b23-4629-4f13-9723-4e24f9998b24', 'Structural engineering', 7, false, '2026-09-29 13:50:26.761237+00', '2026-09-29 13:50:26.761237+00');
INSERT INTO public.supplier_services VALUES ('b0e618a2-c330-4229-aee3-f5798ecd8e13', '63444b23-4629-4f13-9723-4e24f9998b24', 'Floor Manager', 8, false, '2026-09-29 13:50:26.762862+00', '2026-09-29 13:50:26.762862+00');
INSERT INTO public.supplier_services VALUES ('3a38a374-fc66-4565-99a3-d711dc4210bb', '63444b23-4629-4f13-9723-4e24f9998b24', 'Security', 9, false, '2026-09-29 13:50:26.764767+00', '2026-09-29 13:50:26.764767+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('3769ac9b-3bac-4f38-9cb6-9a1902713a9f', '63444b23-4629-4f13-9723-4e24f9998b24', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-29 13:50:26.736593+00', '2026-09-29 13:50:26.736593+00');
INSERT INTO public.suppliers VALUES ('10cd3009-4450-47d8-9fa2-da35b63b6401', '63444b23-4629-4f13-9723-4e24f9998b24', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-29 13:50:26.740761+00', '2026-09-29 13:50:26.740761+00');
INSERT INTO public.suppliers VALUES ('67af8422-370b-45e8-9824-7a06a04166d3', '63444b23-4629-4f13-9723-4e24f9998b24', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-29 13:50:26.744573+00', '2026-09-29 13:50:26.744573+00');


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('3ba39038-7580-49c1-b0da-ac3f2b77a089', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-06', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'e92c8d5a-c8ea-44e4-b9ad-5dfd648992d8', NULL, '2026-09-29 13:50:27.742496+00', '2026-09-29 13:50:27.742496+00', NULL);
INSERT INTO public.tasks VALUES ('98783c1a-a2f8-409f-a734-0b1a924fced7', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-09', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-29 13:50:27.744716+00', '2026-09-29 13:50:27.744716+00', NULL);
INSERT INTO public.tasks VALUES ('aba122c9-1dc0-41ea-811e-a0fed61ca7a7', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'Walk the hall with the venue', NULL, 'done', '2026-09-24', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-09-29 13:50:26.566+00', '2026-09-29 13:50:27.746264+00', '2026-09-29 13:50:27.746264+00', '98783c1a-a2f8-409f-a734-0b1a924fced7');
INSERT INTO public.tasks VALUES ('0473fa2e-acfd-48ad-874a-13425d098fd1', '63444b23-4629-4f13-9723-4e24f9998b24', '49ceff12-276a-4250-b082-92fe2510745a', 'Send sign positions to the printer', NULL, 'open', '2026-09-28', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-29 13:50:27.746264+00', '2026-09-29 13:50:27.746264+00', '98783c1a-a2f8-409f-a734-0b1a924fced7');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.600161+00', '2026-09-29 13:50:26.600161+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.606072+00', '2026-09-29 13:50:26.606072+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.609912+00', '2026-09-29 13:50:26.609912+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.613308+00', '2026-09-29 13:50:26.613308+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.617281+00', '2026-09-29 13:50:26.617281+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-29 13:50:26.621212+00', '2026-09-29 13:50:26.621212+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.90934+00', '2026-09-29 13:50:26.90934+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.914665+00', '2026-09-29 13:50:26.914665+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.919038+00', '2026-09-29 13:50:26.919038+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.923622+00', '2026-09-29 13:50:26.923622+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.927803+00', '2026-09-29 13:50:26.927803+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-29 13:50:26.966146+00', '2026-09-29 13:50:26.966146+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('a9135d6a-a5d7-4f97-b5a3-20fa684fcc16', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-29 13:50:26.640207+00', '2026-09-29 13:50:26.640207+00');
INSERT INTO public.venue_rules VALUES ('15e76faa-7245-4e11-921c-1b4bc93dd0fa', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-29 13:50:26.644265+00', '2026-09-29 13:50:26.644265+00');
INSERT INTO public.venue_rules VALUES ('4d4a3669-84b2-4a30-a4a7-15aa3e69caa7', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-29 13:50:26.648403+00', '2026-09-29 13:50:26.648403+00');
INSERT INTO public.venue_rules VALUES ('670c853d-a3e9-4b24-b493-50cf001edda4', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-29 13:50:26.652835+00', '2026-09-29 13:50:26.652835+00');
INSERT INTO public.venue_rules VALUES ('4eb1e27c-8bb0-4cd2-b607-4c423b39e467', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-29 13:50:26.656343+00', '2026-09-29 13:50:26.656343+00');
INSERT INTO public.venue_rules VALUES ('c07be26e-7883-4e34-8f47-789ef7a697a9', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-29 13:50:26.661823+00', '2026-09-29 13:50:26.661823+00');
INSERT INTO public.venue_rules VALUES ('d1d4924c-da2e-4980-b4a2-edb956543609', '13b754dd-5d21-49bd-aa73-2113259c8bf2', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-29 13:50:26.665605+00', '2026-09-29 13:50:26.665605+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('13b754dd-5d21-49bd-aa73-2113259c8bf2', '63444b23-4629-4f13-9723-4e24f9998b24', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-29 13:50:26.630137+00', '2026-09-29 13:50:26.630137+00');
INSERT INTO public.venues VALUES ('b0a998bf-c8a6-425a-b370-b909ab19ad48', '63444b23-4629-4f13-9723-4e24f9998b24', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-29 13:50:26.633187+00', '2026-09-29 13:50:26.633187+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('1085444c-dd0c-403e-8757-5cfa36f67860', '6e545017-c54f-4d97-9f4b-780664c1d10f', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-29 13:50:26.811+00', '2026-09-29 13:50:26.811+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('fd337e62-0ddf-4aad-91d9-3921159267b6', '6e545017-c54f-4d97-9f4b-780664c1d10f', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-29 13:50:26.813789+00', '2026-09-29 13:50:26.813789+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('70934458-6128-4d5f-8f06-d1e801c2b555', '6e545017-c54f-4d97-9f4b-780664c1d10f', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-29 13:50:26.815329+00', '2026-09-29 13:50:26.815329+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('6892931a-b3d1-4c85-8723-a88d66298141', '6e545017-c54f-4d97-9f4b-780664c1d10f', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-29 13:50:26.816362+00', '2026-09-29 13:50:26.816362+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('ca8a25d0-25a0-423e-b835-def8a6a558f8', '1eea99c2-a894-4a61-bf39-a9773c8ddcea', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-29 13:50:27.615094+00', '2026-09-29 13:50:27.622265+00', '{organiser,sponsor}', false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.workflow_steps VALUES ('a319834a-7e1c-499c-a437-69a8e48880c3', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-29 13:50:26.863998+00', '2026-09-29 13:50:26.863998+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('fa27f3db-31a2-461b-955e-e41dfa90c5ff', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-29 13:50:26.865976+00', '2026-09-29 13:50:26.865976+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e1dc0748-23a0-49b4-be10-c1bfd90f293b', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-29 13:50:26.867809+00', '2026-09-29 13:50:26.867809+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('8d9e775d-41e4-4ab7-b0bc-8cb760e218a8', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-29 13:50:26.868924+00', '2026-09-29 13:50:26.868924+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e21bfb89-d82f-4bdb-8495-9f998a8b194a', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-29 13:50:26.870197+00', '2026-09-29 13:50:26.870197+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('66ce8c3d-8df5-4d66-a263-b125f47a2249', '26af3260-b8e1-4d57-b1c7-03cba896c51b', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-29 13:50:26.871371+00', '2026-09-29 13:50:26.871371+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a278f705-0c91-4d12-9d17-f0a57f1458a2', '6e545017-c54f-4d97-9f4b-780664c1d10f', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-29 13:50:26.805198+00', '2026-09-29 13:50:27.603787+00', '{organiser,sponsor}', false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.workflow_steps VALUES ('32a2efba-9b00-4fcf-badc-55a63405d2c7', '6e545017-c54f-4d97-9f4b-780664c1d10f', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-29 13:50:26.807524+00', '2026-09-29 13:50:27.605107+00', '{organiser,sponsor}', false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.workflow_steps VALUES ('c840d56a-3c2f-417c-a94a-7cd65f8b2abc', '6e545017-c54f-4d97-9f4b-780664c1d10f', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-09-29 13:50:26.809479+00', '2026-09-29 13:50:27.60619+00', '{sponsor}', false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');
INSERT INTO public.workflow_steps VALUES ('fc1393f4-3f78-4631-ada7-42f690841933', '6e545017-c54f-4d97-9f4b-780664c1d10f', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-29 13:50:26.812503+00', '2026-09-29 13:50:27.607812+00', '{organiser,sponsor}', false, 'dd42350c-8dd8-4b16-90b9-dc1cfebbee2b');
INSERT INTO public.workflow_steps VALUES ('c550ab40-0786-406d-8320-3a8b2a00bccb', '1eea99c2-a894-4a61-bf39-a9773c8ddcea', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-29 13:50:27.609977+00', '2026-09-29 13:50:27.61708+00', '{organiser,sponsor}', false, '5b76f15f-8f07-409d-a508-36698184a938');
INSERT INTO public.workflow_steps VALUES ('6eb9663d-aa29-4402-a102-cc4ec384e31b', '1eea99c2-a894-4a61-bf39-a9773c8ddcea', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-29 13:50:27.611549+00', '2026-09-29 13:50:27.618572+00', '{organiser,sponsor}', false, '96bb0847-3e6b-4385-a227-54770da1b023');
INSERT INTO public.workflow_steps VALUES ('b50dec53-5de5-4261-a815-a374443b46ee', '1eea99c2-a894-4a61-bf39-a9773c8ddcea', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-29 13:50:27.613125+00', '2026-09-29 13:50:27.620249+00', '{sponsor}', false, 'ab270b47-199b-4326-b84e-9d2aa042b6be');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('6e545017-c54f-4d97-9f4b-780664c1d10f', '63444b23-4629-4f13-9723-4e24f9998b24', 'Signage default', 'signage', true, false, '2026-09-29 13:50:26.802858+00', '2026-09-29 13:50:26.802858+00', NULL);
INSERT INTO public.workflows VALUES ('26af3260-b8e1-4d57-b1c7-03cba896c51b', '63444b23-4629-4f13-9723-4e24f9998b24', 'Stand default', 'stand', true, false, '2026-09-29 13:50:26.862026+00', '2026-09-29 13:50:26.862026+00', NULL);
INSERT INTO public.workflows VALUES ('1eea99c2-a894-4a61-bf39-a9773c8ddcea', '63444b23-4629-4f13-9723-4e24f9998b24', 'Stand design sign-off', 'signage', false, false, '2026-09-29 13:50:27.596598+00', '2026-09-29 13:50:27.596598+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 10, true);


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

\unrestrict 4Y8qMPkd9Ni5oiuiiPwWVnZfYi1xJRZpS3gZAoRg42J0Hl83vgd99it7vjRZ7h1

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
