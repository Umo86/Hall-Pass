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

\restrict 6vH0CavMQTHRlukEVs6Bls7g2CrIeZ0TJKD6HW8gZyUxgIMkpt1daRws9SIIfQZ

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
    expires_at timestamp with time zone,
    manager_scope public.manager_scope,
    access_ends_at timestamp with time zone
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
INSERT INTO drizzle.__drizzle_migrations VALUES (13, '96d00148784489a135cd6ee6f8c4ec7ef2b66654eee26d3e5beceddca201c34e', 1792174730034);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('daedf232-e9e3-4962-967c-9bc3b095e3ee', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('8c26e2eb-9705-4b94-8e18-587e8bad119d', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('a7969079-cad8-462b-8c4e-d58104eecb4f', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('7e237c72-d220-4f06-a334-48af7507d622', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3bd16607-7885-4bdb-ab53-a11ebbfb5678', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('21b00b45-9320-4028-9409-abf2bf98d231', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5b9ff6f6-4522-4979-bec6-70411881eb5f', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('028fadb2-08e1-4e9d-bb6b-d5407c7803be', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.592793+00', '2026-10-16 18:55:55.592793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8d94b25-d319-45c7-bcc4-1c290a8974f1', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('cff592bd-d370-4446-9a88-c4ce1a36570c', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('22154c4f-cf66-4b50-8575-4a1907aeed92', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('866595ce-eefa-43f4-8db6-b5878aa03198', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('34f3d1a5-052e-4619-8fe5-d7e2896ee780', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('6d9cdb68-8f2c-461c-808d-50835f07579b', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0e1317f2-a1bb-4007-9193-5cdc6975a4fa', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('60acd985-5742-4fae-8535-577ce5f2d71b', 'signage_item', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.617601+00', '2026-10-16 18:55:55.617601+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('74b35c8d-c7a3-4b06-8636-7f2720abba39', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 18:55:55.19+00', '2026-10-12 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('e5a7e094-be71-49f6-9a8e-a62a7a2cd084', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 18:55:55.19+00', '2026-10-07 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('79da111b-9592-4bb9-835a-263ce9d780db', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-06 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 18:55:55.19+00', '2026-10-09 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('461eed5c-d8e2-4320-ad70-a4ff446eed4e', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eee17d9e-c133-42ff-8593-2aaecee99402', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('11a6ea3c-4856-4886-83d4-1dee1186aca9', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cd16d1df-5072-4f79-aad6-42f6bd92ddd5', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('36b9fc1b-26a1-4d17-a39e-b4243345d32e', 'signage_item', '65a918ac-a401-4def-a13b-ad913b200e30', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.645118+00', '2026-10-16 18:55:55.645118+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef902276-8fa8-4352-bce9-6f697a98930e', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('af155611-d5cf-401b-973e-d7b7fc8f1504', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('a7096153-f2a4-4b92-abde-15848689d184', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('5c73ef92-1458-4fdf-bad4-8f45a98d32a7', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4cfae4d6-8301-439f-abac-9b008a61ebdf', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('fe8c284d-b4dc-48de-a43b-63adba2c971c', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9a7a8978-cba5-4ccc-b825-6892c49a6cac', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('20834643-04ba-4c82-84c6-40c62d0ea82b', 'signage_item', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.668382+00', '2026-10-16 18:55:55.668382+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d811cc82-5dd1-4c34-914b-606a6102d51d', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('88237310-2263-4dbf-b02b-577683b26908', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('d071513a-caff-4099-8268-881405a77818', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('667f520b-a67c-47db-9513-1e509feb93c7', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4baa2915-77ee-49b1-9684-cee77ca1cb73', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('7b09c002-6c72-4786-b83c-b34d9786772f', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e6fb8055-f904-4550-a364-22640ee7f6e8', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef984251-520a-4a7c-8510-fdd412e1d59a', 'signage_item', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.688657+00', '2026-10-16 18:55:55.688657+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b098725c-fb13-47dd-a0a2-a37ec4cc53f1', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 18:55:55.19+00', '2026-10-07 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('30248269-7a01-4876-b158-77c1feb6f915', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 18:55:55.19+00', '2026-10-07 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('dc5dac54-e446-473d-b050-dd336f0abf42', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('a871d0f7-0fdf-4f20-a34e-4f54342d8752', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7910330c-4822-4e65-bab2-7d938ae7f8e3', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', '2026-10-12 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('b4017cf8-13f1-4545-9aa6-d73bd6b1052e', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8a031829-a476-4d2e-b924-af222be85cf4', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('134ed3a4-c695-46de-b394-27a35b1af9a4', 'signage_item', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.715573+00', '2026-10-16 18:55:55.715573+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1cff0128-35c3-4625-ac8e-c8b20ea16eba', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('d982a209-df5d-4499-87a7-f2461fc03769', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('e7d9b49f-0fb0-49e5-8d47-95b0120d938a', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('f9a8c948-b05e-4908-bf1c-cb3cfe3a7091', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c5449024-1328-46ec-8541-0c8abf324cd2', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('7a07ba86-c7b6-4820-855a-890de874e28a', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2ee2a6d4-1168-49a8-9bc7-56665595de83', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('05bbb1f1-9f48-4405-a935-77c6dc9538e3', 'signage_item', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.735598+00', '2026-10-16 18:55:55.735598+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8ac2b2bd-4c64-4a4d-9f02-a7bdbd52f3fc', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('ba76311d-432d-46f2-bd7d-fed691634c83', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('1d0efd3b-dd23-4e9d-bb10-dc01f30e018f', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('0f55ba9a-59e3-4b72-91e3-8b4c5276712b', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('45f966f2-fd68-493a-9eb7-a8b87a682d11', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('bc929808-82e7-4322-a8dc-13eb4f2bf0f2', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('94fa1186-7650-4457-8216-3abd9365c5ad', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4a9a485e-bf05-4de4-8a4c-5a5930720316', 'signage_item', '434511d7-4800-4e02-8117-a84de6317d1a', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.759481+00', '2026-10-16 18:55:55.759481+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2eaaa815-f315-4e1e-9203-4d084ef3c7b5', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('25a3cfa2-4452-4cbb-9d20-54267e941720', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('b29d3b13-39a3-466c-898e-eccabf1f1985', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-13 18:55:55.19+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('c858af05-5f3b-4e25-8f1a-76718668f5e6', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0202794a-fdd3-4784-bba6-478f6a481a6f', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('36dfd3e4-db4f-4bae-a0c8-1a1871e01545', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7a0af09d-68ba-406b-9e5b-ebbf736b26da', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f05b17a7-b19d-45c6-8f25-e07af621aed7', 'signage_item', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.779262+00', '2026-10-16 18:55:55.779262+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5c531c16-d91c-4324-a61a-b9cbc7aa07e7', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('e6e416fa-3406-4f4e-8f3b-f77d27f0b325', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('3bc1e224-f27a-4469-ab64-fba085123879', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('21a95a42-e1d4-44d5-9fee-1afa60388233', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('aaa7fe99-eef8-4127-b62c-2f7fd6c6ee96', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('c0ef5eed-814f-458d-9cda-1f66e9fc4e47', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('185f781b-910c-4b2b-af55-d8d48ece3f69', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('73d4ec0f-a498-4b01-97a8-00bc910fe1e1', 'signage_item', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.799852+00', '2026-10-16 18:55:55.799852+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e95a777d-89f0-4e48-bf54-717059bb997d', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('62d080d2-5c5f-47d7-b360-bd0c2b8625f3', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('aa260a96-d7b3-43bf-9311-abb338f78b55', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('2657a52f-7fd4-4c5d-86cf-f913058b4986', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a215fc0b-1e79-4c02-a62f-f7a42409ba96', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a8db9f76-df7d-4151-97dc-aab8c0c54ffe', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('43cbb305-c961-44eb-8bb6-a6a3adca51dc', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2f9f8607-9370-4673-b87a-c4b5d1fecd00', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c7b8451d-33f6-4151-89c6-2ae0749b0574', 'signage_item', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.820793+00', '2026-10-16 18:55:55.820793+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0dea33bb-90dd-47cc-826c-af8905fe4d5f', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('b9e40869-bf92-452a-9c3e-7b6f1f384ba2', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('96daa44f-eb78-4afd-a38b-4f3fd75a3ec3', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('e97ba6e8-6db8-4b63-996f-da3c8bb5100b', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8d9ca2ad-929c-4ec1-941e-a2eb4d6c5657', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('0868d99b-b3fe-4cbe-9303-1c6466817bd0', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6396da8c-19a3-47bc-8386-4baa250a632b', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fab1eb2e-2a36-4e3f-bbb8-465eac2be1cf', 'signage_item', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.850118+00', '2026-10-16 18:55:55.850118+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('96339972-3b22-42ed-9a9f-c309420ccccd', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('b2b2a6b5-fe1f-4ac6-b1eb-eb2f2affa232', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('3c4064dc-0bd9-4f60-8570-53bdd95500b4', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('d5974e84-e195-4d04-b8bd-1b00eb64b8a2', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('538a1647-bd47-4759-b32f-30e9e5f191ab', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('fc407f44-fc7e-4707-9ab6-9ef4b357210c', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ff9b609a-351a-4dd6-a126-5fe0c37ea1b0', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('85fbafb9-d161-4618-b263-998a262bdcff', 'signage_item', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.875589+00', '2026-10-16 18:55:55.875589+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('28330eea-aa46-43f9-9283-d6c8bffdd3a6', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('f543eb94-7b01-4211-9c50-1b0104ce0f84', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('f83c22d1-6563-4271-9cd2-2ca7805b41b4', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('87625027-5425-4802-bc43-007937a9cd00', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('432e2ba9-b35a-42e8-a90b-b051f6cdf0fe', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('47d301dd-1ba2-4db1-89cc-fc7d6b86899d', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d6f77550-ffb2-4abd-86d9-2760243a5def', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eff0c3df-e4cc-40d2-97f5-925505634a10', 'signage_item', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.900789+00', '2026-10-16 18:55:55.900789+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f5d02789-0728-4c3e-ba52-5b3f411a851f', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('ecb9ba11-ef7d-4620-a8b7-d4684e7e75c8', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('6e82dcd2-4ba1-4400-a3b2-acc10e779b27', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('3e7e558e-22eb-4630-852e-696f974f34f5', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('edf8378a-ebd0-459b-a3c5-b9f428ce3ca3', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('cb587595-9d64-4f56-9189-397f1d958791', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('63a2081d-5a00-4946-aab8-8b1883326d86', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('81d2d9e9-96ec-4f8f-ad20-6d377bacfc57', 'signage_item', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.921005+00', '2026-10-16 18:55:55.921005+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('093149cc-6537-46a6-a6d2-01530ec33e8c', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('88328a66-ae9e-4951-a442-86b54ca11324', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('6c481a4b-4193-49a5-9d17-e18fc8762a46', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('584b4904-f800-4b00-8b46-1b4802bda24d', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a0d671c-442c-4d70-bc1b-9b3c005bdd29', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('36e0e026-fa40-40fb-b7f3-a70655d32def', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ff426a11-5907-4ea8-87ac-e4c099daaeed', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('362f8f93-ebac-4812-95f7-9a30617028e6', 'signage_item', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:55.943174+00', '2026-10-16 18:55:55.943174+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1ac7220f-88c1-4d86-a6dc-23e287e5a8de', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('8dee044a-5509-4030-8815-d4bdcc4662f7', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('132f3fc4-3a9f-431c-8282-814889adb371', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('0be4d2e2-be44-429f-a94a-4f4dddfdb774', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f3f5fa6e-7311-4c7c-bbe9-7cdc74df992b', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('0a019965-df0c-41c7-a36b-105b4fdd458d', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a8136fae-5ca8-4ae9-8756-8f07956e660b', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8b6c23b1-e4e8-4297-a463-ec3830bc9eb3', 'signage_item', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:55.974481+00', '2026-10-16 18:55:55.974481+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a5e34249-6790-4ca9-90a4-1df7b3a58e8f', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('42e2268c-876f-4067-bddd-0580eb999352', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('155d78f7-7f8a-4810-a74b-6967ea3752a7', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('cb978430-52c7-40e2-bd42-4eaccb320293', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3dd1258e-173c-4b07-91bf-5c2a50f3861b', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('7bac00e7-6326-4f65-b4e0-ae2352718134', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('73771e18-b10c-41fb-bae1-7c87ef49d328', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0c2f1628-d0bd-46c0-b726-c2424da87d03', 'signage_item', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.003782+00', '2026-10-16 18:55:56.003782+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('90712e2e-2e43-493e-a640-6cfce63bb380', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('a5d90c11-1b08-4e28-825e-5d8d1ac9cdb3', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 18:55:55.19+00', '2026-10-18 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('bc41f949-dbae-4d1f-8426-57e53676dac8', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('519f139d-40e4-4bd6-a0b3-a6f11b67a2ed', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 18:55:55.19+00', '2026-10-18 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('554c2084-b84b-486c-8639-2b579206bbc4', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('f6bb1349-8b44-40ed-b1ce-ed54ca594df7', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('de7eb801-5709-4142-b8ba-bc47e30e2214', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6417e1d9-1ae2-437b-b0f6-3ce853b58786', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('19e41f77-f6f6-4c00-911c-e265fef3506e', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5e856463-6908-4097-b4ef-05e702e01123', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ffaf22a4-ccbf-4895-a901-11584c5fbe2e', 'signage_item', '83b17213-07f8-41b6-82d2-5684622606e3', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.035785+00', '2026-10-16 18:55:56.035785+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f49a7712-f3c4-41a9-b4fe-ff9cf10b10ac', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('66b0755e-bf91-4a87-82e5-914ae4d3b377', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('85ab1bfb-ee4a-46bb-aa5e-f41fc70cc702', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('3ee347bd-4327-4568-a459-7f6b7984a426', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('268d0405-2b53-4092-9bee-0e5d10bf61c3', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('c7369d2e-11b8-4f1c-8f2f-2bd2fcee7752', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4f4d5716-2bf6-49d9-a0dc-77445edb8ea2', 'signage_item', '98596709-ed55-4cab-820a-ad062794450a', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.12144+00', '2026-10-16 18:55:56.12144+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('45f6f23c-0e68-49a0-a2a2-d412f3d07368', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('da54e285-183f-4eb5-9886-2f679f0e15cc', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('04df7833-b615-455d-81a4-e8782e70f4e8', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('de821e4b-89da-472a-84e6-9a11dfde0da5', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-13 18:55:55.19+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-20 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2fbdfa99-085f-4446-8eb0-13da64fffc0c', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('bb4d0b97-1cbd-47fc-9ddc-72066b94567c', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-15 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('77c09583-28d6-4f4f-b633-29933db19771', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ddf2a432-1844-47c2-a33d-536d9dd76db8', 'signage_item', '80b5faf7-4251-4685-a150-436dc680381b', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.146809+00', '2026-10-16 18:55:56.146809+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('685e9bbf-6a45-4610-b272-43d6c1534fd5', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, '6a286d42-2c27-44c9-8494-95070c2f4c6b', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 3, false, '17506cfa-d41d-4093-a281-030c4833b4b5', NULL);
INSERT INTO public.approval_instances VALUES ('645e131a-1e8f-4fc7-89a1-77d08a4a69c0', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, 'acf1f495-95a7-41fa-8b8f-525731f918cd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 3, false, '7b6e0db5-1572-4292-b443-ca5927a4ac70', NULL);
INSERT INTO public.approval_instances VALUES ('c5a17e9d-a7ff-4d77-a836-99d594e0077d', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, 'e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-11 18:55:55.19+00', '2026-10-16 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 5, false, '2e756365-8406-4f56-91c7-3476aa802ecd', NULL);
INSERT INTO public.approval_instances VALUES ('41a754cf-ca4a-42e2-9c5d-495dc4bc4bbf', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, 'd2024f61-1afc-4a55-890f-6b264c8daad0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e8686c69-5fc3-4f60-b405-82ee3f26b775', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, '45640a65-e497-41ec-8082-4835e8c92cda', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 3, false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', NULL);
INSERT INTO public.approval_instances VALUES ('15a91823-1613-41a5-a178-98024b4321d3', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, '472d72bb-48aa-4f6e-976c-2252ea1453cf', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('af99f5d3-8dad-4afc-ba18-ab6eeed8eb51', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, '1577d64c-240a-4736-bb33-3d628738a20b', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b2258947-5f4a-4ea9-96a3-079f91978b09', 'signage_item', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, '669b7cd3-4839-4c6a-afe8-327a86e993b7', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.173649+00', '2026-10-16 18:55:56.173649+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('60759656-3369-462c-a0ed-95fd35965b25', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, 'd3cb4164-3445-433a-8447-1aa0a17167cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 18:55:55.19+00', '2026-10-13 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('534f4d2b-05b0-4369-afea-9c2d0b1e7eac', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, 'fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-12 18:55:55.19+00', '2026-10-19 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0748b601-29c7-4d2a-be54-194f7b8badcd', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, '3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5967cebb-a4e9-4e2e-bd68-9547b49bbc2e', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, 'b08ade09-b602-4e93-ac5d-9c979ef275a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('810d5b80-554d-42bf-b590-6876dc3a628f', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, '7d283807-c997-47da-a565-c1534a2e54e0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('db82d12d-cd7f-4b18-859b-855397a81de3', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 1, '9641c3a0-723a-4b5f-83b7-cc10313f555b', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('529ce652-f0b7-4920-a543-a75ef0d38d1e', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, 'd3cb4164-3445-433a-8447-1aa0a17167cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-10 18:55:55.19+00', '2026-10-13 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4940820f-332e-43d3-b7d9-f6d874f73a70', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, 'fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('718645f3-6bba-4ae6-a9d9-febb779b925e', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, '3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e0c66097-67d4-4ebb-a4b2-cfa8d22d93af', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, 'b08ade09-b602-4e93-ac5d-9c979ef275a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('05e79d37-4de5-460a-a8ac-bc5c4063c63f', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, '7d283807-c997-47da-a565-c1534a2e54e0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a461ea9-64bd-426f-8d50-326b2880a16d', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 1, '9641c3a0-723a-4b5f-83b7-cc10313f555b', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('707d8729-c052-4baa-8b88-5a22ce940d6d', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, 'd3cb4164-3445-433a-8447-1aa0a17167cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-10 18:55:55.19+00', '2026-10-13 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('77289b17-6d6e-4469-8497-efb45fb5fb69', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, 'fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('efc0347e-f9ea-46f7-aa45-5668e45e99cc', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, '3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d18338d4-ea67-4ebf-825c-6e3e1ceba2a4', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, 'b08ade09-b602-4e93-ac5d-9c979ef275a8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c92420d7-18ea-4740-987e-6de6e5502b5c', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, '7d283807-c997-47da-a565-c1534a2e54e0', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5be886b1-f83d-4aae-b66d-f56878735dd9', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 1, '9641c3a0-723a-4b5f-83b7-cc10313f555b', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('80d7c0dd-890d-40cf-83de-c843e072c261', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, 'd3cb4164-3445-433a-8447-1aa0a17167cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 18:55:55.19+00', '2026-10-13 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('26489295-c314-4a6f-8c62-310cbf319fab', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, 'fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ab2219f3-fe82-4aed-af66-03a6ea15966d', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, '3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-17 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a67298fd-20af-4754-ac54-5feb6f4b93ca', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, 'b08ade09-b602-4e93-ac5d-9c979ef275a8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-19 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cbe79d3d-c885-4987-8ea0-3bc553b7ff9f', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, '7d283807-c997-47da-a565-c1534a2e54e0', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a3a471f5-de1a-4e15-abb6-77a49277bbb6', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 1, '9641c3a0-723a-4b5f-83b7-cc10313f555b', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-12 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ce6ad503-7c34-4812-be49-3c6963d716be', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, 'd3cb4164-3445-433a-8447-1aa0a17167cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-10 18:55:55.19+00', '2026-10-13 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5f50f0ab-f711-4f3e-b463-4a98dacc4562', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, 'fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fa9bc6e1-b287-4219-8062-847ecc989eb2', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, '3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-17 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('38516b78-f3e1-46f8-bbbc-8718b4d5b116', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, 'b08ade09-b602-4e93-ac5d-9c979ef275a8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-19 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dfc6f878-fc65-440e-9710-dc996351f1ab', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, '7d283807-c997-47da-a565-c1534a2e54e0', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-12 18:55:55.19+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-12 18:55:55.19+00', '2026-10-14 18:55:55.19+00', 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('72b2aba0-ad5b-4f5c-8b5e-65ad932a1f1c', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 1, '9641c3a0-723a-4b5f-83b7-cc10313f555b', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-12 18:55:55.19+00', NULL, 0, NULL, NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('888c687b-3516-4121-a14d-9fa040103b4f', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '17506cfa-d41d-4093-a281-030c4833b4b5', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-16 18:55:55.436142+00', '2026-10-16 18:55:55.436142+00');
INSERT INTO public.approvers VALUES ('b97fde34-ee74-45ea-88b9-c2dec7e9d846', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '7b6e0db5-1572-4292-b443-ca5927a4ac70', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-16 18:55:55.443261+00', '2026-10-16 18:55:55.443261+00');
INSERT INTO public.approvers VALUES ('d5a5f543-8cca-476e-882d-33b0cd9ab197', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '2e756365-8406-4f56-91c7-3476aa802ecd', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-16 18:55:55.449143+00', '2026-10-16 18:55:55.449143+00');
INSERT INTO public.approvers VALUES ('9f29c40e-d002-44d6-a886-3479e4284706', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'e30799b6-7bb4-4dce-b3d3-3539d4beb947', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-16 18:55:55.456445+00', '2026-10-16 18:55:55.456445+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('5721fcfc-74e5-463a-9db1-998a949c2127', '7a50aa64-0348-4057-8029-d58f42cac2db', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.58738+00', '2026-10-16 18:55:55.58738+00');
INSERT INTO public.artwork_versions VALUES ('a3d75a57-3333-4501-bd6c-a64b526f409a', '72c0bafe-d155-4a4e-80cd-871a46e9bd32', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.614119+00', '2026-10-16 18:55:55.614119+00');
INSERT INTO public.artwork_versions VALUES ('829a68d4-d66d-46e6-971e-c293f84895ee', '65a918ac-a401-4def-a13b-ad913b200e30', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-16 18:55:55.639281+00', '2026-10-16 18:55:55.639281+00');
INSERT INTO public.artwork_versions VALUES ('1979faeb-0c6e-4911-9ab7-46f61be20f55', '65a918ac-a401-4def-a13b-ad913b200e30', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.641202+00', '2026-10-16 18:55:55.641202+00');
INSERT INTO public.artwork_versions VALUES ('afec93a1-a35e-415e-a9ec-ab2534ae0cb2', 'f74815b0-59f1-4678-bc52-b2b4681bd29e', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.665229+00', '2026-10-16 18:55:55.665229+00');
INSERT INTO public.artwork_versions VALUES ('1f9c64ee-ad9e-48e5-8944-a9c462bd5704', '7b12dee6-b6af-48f7-89cf-e81e4ab5359e', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.685437+00', '2026-10-16 18:55:55.685437+00');
INSERT INTO public.artwork_versions VALUES ('0e3ff711-dc84-442e-b978-31786487d523', '6962e9bf-07cc-4488-bb54-a6c507b0acf2', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.712603+00', '2026-10-16 18:55:55.712603+00');
INSERT INTO public.artwork_versions VALUES ('e8799dfb-7ae0-4bd3-ba13-1d1fd7e1d28b', 'e7199383-a9ae-4a07-83cc-366239c91e2c', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.73294+00', '2026-10-16 18:55:55.73294+00');
INSERT INTO public.artwork_versions VALUES ('044d6c19-c634-46c5-bb32-cffde07dd19d', '434511d7-4800-4e02-8117-a84de6317d1a', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.756404+00', '2026-10-16 18:55:55.756404+00');
INSERT INTO public.artwork_versions VALUES ('d641459b-9f53-4d5e-997e-4466200970f4', 'd4e250ed-bd16-4d11-bcaf-ba1a777711d3', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.776607+00', '2026-10-16 18:55:55.776607+00');
INSERT INTO public.artwork_versions VALUES ('0f1222cc-40f8-4c9d-8b99-1a912c475baf', '083a9c7d-a142-4426-8eab-1661a11131ae', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.796706+00', '2026-10-16 18:55:55.796706+00');
INSERT INTO public.artwork_versions VALUES ('2ef0f954-b239-4420-a792-7d5a436bb490', '7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.817996+00', '2026-10-16 18:55:55.817996+00');
INSERT INTO public.artwork_versions VALUES ('62daefe9-2ab9-4abb-986d-c92ead1e621d', 'c963180d-6cb8-48f1-96d3-1bce07328116', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.847585+00', '2026-10-16 18:55:55.847585+00');
INSERT INTO public.artwork_versions VALUES ('858c5621-cf23-4627-9af0-c518f0efa357', '8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.87212+00', '2026-10-16 18:55:55.87212+00');
INSERT INTO public.artwork_versions VALUES ('4a43cc4e-5432-46f6-ba91-c18c41ef1df8', 'c7bd02ad-db70-41d5-a1da-e0f67577f951', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.897556+00', '2026-10-16 18:55:55.897556+00');
INSERT INTO public.artwork_versions VALUES ('cb080396-195b-4271-a286-ef65aff363a3', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.918035+00', '2026-10-16 18:55:55.918035+00');
INSERT INTO public.artwork_versions VALUES ('f0720e01-5dec-4c3c-80c5-2942b2ad25a8', 'ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.940571+00', '2026-10-16 18:55:55.940571+00');
INSERT INTO public.artwork_versions VALUES ('3db0b495-b9ad-4317-9bf8-3b799ac29256', '3353f948-ee6f-4cfb-a02e-4150f4a129d6', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:55.970038+00', '2026-10-16 18:55:55.970038+00');
INSERT INTO public.artwork_versions VALUES ('caf46a89-4b25-46de-9946-730a62a4df1c', 'f78c6d41-892c-4eae-a7a9-6b615a1b3590', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:55.99812+00', '2026-10-16 18:55:55.99812+00');
INSERT INTO public.artwork_versions VALUES ('5758dc4b-c96a-4bef-a62f-37427d8eeca4', '83b17213-07f8-41b6-82d2-5684622606e3', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-16 18:55:56.027204+00', '2026-10-16 18:55:56.027204+00');
INSERT INTO public.artwork_versions VALUES ('d7219684-6afd-45a7-ad43-916611ae81c5', '83b17213-07f8-41b6-82d2-5684622606e3', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-16 18:55:56.029417+00', '2026-10-16 18:55:56.029417+00');
INSERT INTO public.artwork_versions VALUES ('75ab5ace-3ce0-48a0-80f5-78a52c6aefc5', '83b17213-07f8-41b6-82d2-5684622606e3', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:56.031485+00', '2026-10-16 18:55:56.031485+00');
INSERT INTO public.artwork_versions VALUES ('886f0c47-ca1b-43b2-affe-8ec795017636', '98596709-ed55-4cab-820a-ad062794450a', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-16 18:55:56.11813+00', '2026-10-16 18:55:56.11813+00');
INSERT INTO public.artwork_versions VALUES ('afb8ed4b-c608-40ad-b6b0-47d1711bd2a3', '80b5faf7-4251-4685-a150-436dc680381b', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:56.143617+00', '2026-10-16 18:55:56.143617+00');
INSERT INTO public.artwork_versions VALUES ('d6cdd2af-0dea-4d30-acc7-1f7e5b9640a1', '06cf4c88-cf42-45f7-a69d-c939906ba223', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-16 18:55:56.171319+00', '2026-10-16 18:55:56.171319+00');


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

INSERT INTO public.contractors VALUES ('c8c6d793-ce94-487b-bd61-6385f9c543d7', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-16 18:55:55.383822+00', '2026-10-16 18:55:55.383822+00');
INSERT INTO public.contractors VALUES ('054a3c0c-921a-404d-a063-1a52e2bfc9c3', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-16 18:55:55.387147+00', '2026-10-16 18:55:55.387147+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('17506cfa-d41d-4093-a281-030c4833b4b5', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-16 18:55:55.431993+00', '2026-10-16 18:55:55.431993+00', true);
INSERT INTO public.departments VALUES ('7b6e0db5-1572-4292-b443-ca5927a4ac70', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-16 18:55:55.440294+00', '2026-10-16 18:55:55.440294+00', true);
INSERT INTO public.departments VALUES ('2e756365-8406-4f56-91c7-3476aa802ecd', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Sales', 3, false, '{sponsor}', false, '2026-10-16 18:55:55.446594+00', '2026-10-16 18:55:55.446594+00', true);
INSERT INTO public.departments VALUES ('e30799b6-7bb4-4dce-b3d3-3539d4beb947', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-16 18:55:55.453975+00', '2026-10-16 18:55:55.453975+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('b6a5b34b-fed4-4f9b-b721-768ea650849d', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00');
INSERT INTO public.documents VALUES ('f5a92000-13f5-4620-b572-bd4558d77015', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00');
INSERT INTO public.documents VALUES ('fecc65f7-5516-4a34-8f48-bf41326c88d6', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00');
INSERT INTO public.documents VALUES ('73667812-7e63-400b-9574-c5edb9d2bf37', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', '0a915c34-82ae-446c-82b4-bc906daeff42', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00');
INSERT INTO public.documents VALUES ('a9c3f725-22e2-463e-98dc-f7bb74d91c12', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00');
INSERT INTO public.documents VALUES ('92862ec1-127b-4618-acbb-f227db366134', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00');
INSERT INTO public.documents VALUES ('4013ec38-a18a-4df9-9b8c-1d11a7dd0986', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00');
INSERT INTO public.documents VALUES ('7332b00c-2c87-435c-94e6-48e2559efdd0', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'f1ac822f-016d-4a57-b316-cbc2d82c7a4b', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00');
INSERT INTO public.documents VALUES ('2af9110a-ea32-4c46-9d45-913f7d6f8c51', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00');
INSERT INTO public.documents VALUES ('fcc7a71d-5fde-4e14-8c37-f3dcf9e6d011', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00');
INSERT INTO public.documents VALUES ('d7d3437b-1932-478e-8d42-a8e34ec6d94d', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00');
INSERT INTO public.documents VALUES ('2b3fcf54-5b6c-4242-92b5-64c542695cc4', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'eceafdb9-3e4d-49bd-98bc-538f746c083a', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00');
INSERT INTO public.documents VALUES ('8f1a612d-1e61-45aa-b973-ce536b42cc0d', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00');
INSERT INTO public.documents VALUES ('4e905c84-8f20-4002-a481-c51d1c700487', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00');
INSERT INTO public.documents VALUES ('f5a03e4e-07a4-4eb9-927a-7a301c94b29d', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00');
INSERT INTO public.documents VALUES ('3a26f25b-4d75-4534-9453-84258fafa2be', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00');
INSERT INTO public.documents VALUES ('60111b86-faad-4c9d-959b-5925ae50fd98', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00');
INSERT INTO public.documents VALUES ('c49dcfd9-8ec8-4e8c-8a0c-05f3535abdbb', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00');
INSERT INTO public.documents VALUES ('bcefab8f-4738-46d5-b660-cc16aa5ba01c', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00');
INSERT INTO public.documents VALUES ('0d7bf69f-5b40-4745-8074-aff09d8970db', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_submission', 'dd2d796a-bf96-4128-8ff2-d7beba08989c', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('b079f8ea-20b8-4d0f-8c8d-75a8e0456dd5', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'signage', 34, '2026-10-16 18:55:56.202268+00', '2026-10-16 18:55:56.204443+00');
INSERT INTO public.edition_counters VALUES ('f0ce4707-d2d2-410b-990c-f27507946142', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_design', 1, '2026-10-16 18:55:56.239272+00', '2026-10-16 18:55:56.239272+00');
INSERT INTO public.edition_counters VALUES ('f66f1419-51c3-49c2-a659-c46e5901b8d4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_item', 1, '2026-10-16 18:55:56.239272+00', '2026-10-16 18:55:56.239272+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('97883a10-9eec-4cfb-84fa-1910bf7f4751', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-16 18:55:55.291665+00', '2026-10-16 18:55:55.291665+00');
INSERT INTO public.edition_deadlines VALUES ('df23097c-86ff-4066-b202-9f26cf1c2ada', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-16 18:55:55.29405+00', '2026-10-16 18:55:55.29405+00');
INSERT INTO public.edition_deadlines VALUES ('572e9f91-f3a6-4f73-8902-98169f4f649e', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-16 18:55:55.295344+00', '2026-10-16 18:55:55.295344+00');
INSERT INTO public.edition_deadlines VALUES ('786c0723-a7cb-427a-b461-82656e3357ed', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-16 18:55:55.296615+00', '2026-10-16 18:55:55.296615+00');
INSERT INTO public.edition_deadlines VALUES ('cc60bab3-d340-4862-9b0d-a3fac36d0934', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-16 18:55:55.297643+00', '2026-10-16 18:55:55.297643+00');
INSERT INTO public.edition_deadlines VALUES ('7914717f-beaa-4b66-b238-28d3b26629fb', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-16 18:55:55.298769+00', '2026-10-16 18:55:55.298769+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '6c0fc405-8f4c-4c5c-9b87-0f7cdb90977f', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-16 18:55:55.288405+00', '2026-10-16 18:55:55.288405+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('6c0fc405-8f4c-4c5c-9b87-0f7cdb90977f', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'UK Construction Week', 'UKCW', '2026-10-16 18:55:55.261039+00', '2026-10-16 18:55:55.261039+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('c69070a1-c0c3-4fdb-9d1d-7a8ad2970d26', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Exhibitor Co', 'A10', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', '2026-10-16 18:55:55.539048+00', '2026-10-16 18:55:55.539048+00');
INSERT INTO public.exhibitors VALUES ('4fe60a30-135c-43e2-885c-f574999724f7', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SteelFrame Systems', 'A20', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', '2026-10-16 18:55:55.54282+00', '2026-10-16 18:55:55.54282+00');
INSERT INTO public.exhibitors VALUES ('6300e0eb-b1c9-4534-99db-bcea96f88a7d', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'BrickWorks UK', 'A30', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', '2026-10-16 18:55:55.545722+00', '2026-10-16 18:55:55.545722+00');
INSERT INTO public.exhibitors VALUES ('04806b7d-7fac-430f-a0fa-48e7a3c93965', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Timber Trade Ltd', 'B10', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', '2026-10-16 18:55:55.54835+00', '2026-10-16 18:55:55.54835+00');
INSERT INTO public.exhibitors VALUES ('b56c124a-251a-4e07-9bd3-16cd1b9c3d1e', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'GlassTech', 'B20', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', '2026-10-16 18:55:55.554514+00', '2026-10-16 18:55:55.554514+00');
INSERT INTO public.exhibitors VALUES ('1eee2062-351d-4fe3-9709-2a9d2c00b63f', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Insulate Pro', 'B30', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', '2026-10-16 18:55:55.557432+00', '2026-10-16 18:55:55.557432+00');
INSERT INTO public.exhibitors VALUES ('947799c6-e731-4f65-8669-38fcc142e13a', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'RoofRight', 'C10', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', '2026-10-16 18:55:55.559896+00', '2026-10-16 18:55:55.559896+00');
INSERT INTO public.exhibitors VALUES ('60215d1d-8bf3-41a4-b5d7-b59d123e44b3', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'PlantHire Direct', 'C20', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', '2026-10-16 18:55:55.562485+00', '2026-10-16 18:55:55.562485+00');
INSERT INTO public.exhibitors VALUES ('40a2a940-2cf6-419d-80f4-d1ac6b87f377', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SafetyFirst PPE', 'D10', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-16 18:55:55.564982+00', '2026-10-16 18:55:55.564982+00');
INSERT INTO public.exhibitors VALUES ('5b435aba-261c-41aa-97ed-10edbdc261a3', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'ToolMart Retail', 'D20', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-16 18:55:55.567421+00', '2026-10-16 18:55:55.567421+00');
INSERT INTO public.exhibitors VALUES ('25df71a1-89a0-43df-ab44-984f110f969d', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'EcoBuild Materials', 'D30', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-16 18:55:55.57041+00', '2026-10-16 18:55:55.57041+00');
INSERT INTO public.exhibitors VALUES ('ffee1b9f-09a1-432e-b7c1-67545f9bb688', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SiteWise Software', 'D40', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-16 18:55:55.572917+00', '2026-10-16 18:55:55.572917+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('6ca13fb1-31f5-4c7e-a19c-a3163db7996b', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'venue', 'venue', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.519903+00', '2026-10-16 18:55:55.519903+00');
INSERT INTO public.external_grants VALUES ('b49740b8-dd42-40da-833d-2b0ea0c114f2', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.524746+00', '2026-10-16 18:55:55.524746+00');
INSERT INTO public.external_grants VALUES ('7a95650f-1d13-4142-8f0e-390cf0b3a17e', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.528511+00', '2026-10-16 18:55:55.528511+00');
INSERT INTO public.external_grants VALUES ('49f3fce0-fb74-4b2e-b803-d295c606376c', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'supplier', 'supplier', 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.532014+00', '2026-10-16 18:55:55.532014+00');
INSERT INTO public.external_grants VALUES ('8a7c1514-dccf-45e9-be11-93a2e6d59e61', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'sponsor', 'sponsor', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.535657+00', '2026-10-16 18:55:55.535657+00');
INSERT INTO public.external_grants VALUES ('18f2162d-7546-4499-8bb9-4247cc766950', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'exhibitor', 'exhibitor', 'c69070a1-c0c3-4fdb-9d1d-7a8ad2970d26', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-16 18:55:55.19+00', NULL, '2026-10-16 18:55:55.576228+00', '2026-10-16 18:55:55.576228+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-16 18:55:55.301426+00', '2026-10-16 18:55:55.301426+00');
INSERT INTO public.halls VALUES ('670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-16 18:55:55.304678+00', '2026-10-16 18:55:55.304678+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('a7d37d47-c9cc-452a-9a7b-48bc99412eb0', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Hanging banner', 'hanging_banner', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'rigged', true, 0, '2026-10-16 18:55:55.490565+00', '2026-10-16 18:55:55.490565+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d63501be-154e-4122-b4e0-5123b808e1b3', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Foamex board', 'foamex_board', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'wall_mounted', false, 1, '2026-10-16 18:55:55.493294+00', '2026-10-16 18:55:55.493294+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('c6d6e0fd-672d-4b56-9371-f94d5af2c98e', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Fabric graphic', 'fabric_graphic', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'shell_mounted', false, 2, '2026-10-16 18:55:55.495123+00', '2026-10-16 18:55:55.495123+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('9b7ba848-6065-403d-9353-ca5562a57d81', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Floor vinyl', 'floor_vinyl', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'floor', false, 3, '2026-10-16 18:55:55.496591+00', '2026-10-16 18:55:55.496591+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('30ac8966-96a2-4dcd-8285-14fdf128de54', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Aisle sign', 'aisle_sign', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'rigged', true, 4, '2026-10-16 18:55:55.497858+00', '2026-10-16 18:55:55.497858+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('f338f617-c682-4226-8b13-de2da86565bd', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Entrance feature', 'entrance_feature', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'freestanding', true, 5, '2026-10-16 18:55:55.499264+00', '2026-10-16 18:55:55.499264+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d4edb812-169f-4435-a0cc-c1d762153fde', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Registration', 'registration', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'freestanding', false, 6, '2026-10-16 18:55:55.501011+00', '2026-10-16 18:55:55.501011+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('1ba2e4e2-90e7-40b5-a874-b1bf9222d2d5', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Seminar theatre', 'seminar_theatre', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'freestanding', false, 7, '2026-10-16 18:55:55.50234+00', '2026-10-16 18:55:55.50234+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('078c14f8-8812-4102-b2fb-aad3ce5bc7f9', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Feature area', 'feature_area', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'freestanding', false, 8, '2026-10-16 18:55:55.503774+00', '2026-10-16 18:55:55.503774+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('beda1902-5663-4aa7-9c55-ca0be7257231', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'External', 'external', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'freestanding', true, 9, '2026-10-16 18:55:55.505976+00', '2026-10-16 18:55:55.505976+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('25d27469-0ec6-4930-a8aa-11054f64c8da', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Digital screen', 'digital_screen', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 'digital', false, 10, '2026-10-16 18:55:55.507743+00', '2026-10-16 18:55:55.507743+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('60c01135-89b0-464b-9010-ef102e158e50', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Branded lanyards', 'lanyard', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', NULL, false, 11, '2026-10-16 18:55:55.50931+00', '2026-10-16 18:55:55.50931+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('154bee51-5c15-46b0-b5cb-70bcd897792c', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Show bags', 'show_bag', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', NULL, false, 12, '2026-10-16 18:55:55.510952+00', '2026-10-16 18:55:55.510952+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('e329b322-6002-4dd7-a156-805d662c2bee', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Registration branding', 'reg_branding', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', NULL, false, 13, '2026-10-16 18:55:55.512647+00', '2026-10-16 18:55:55.512647+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('df934a39-cad8-4f7a-b8c6-f72ab0c26bad', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Other signage', 'other_signage', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', NULL, false, 14, '2026-10-16 18:55:55.514062+00', '2026-10-16 18:55:55.514062+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('ab7da75f-1394-4ec9-b333-87ebda1ee104', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Other sponsorship item', 'other_sponsorship', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', NULL, false, 15, '2026-10-16 18:55:55.515602+00', '2026-10-16 18:55:55.515602+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('c8b57aab-90b8-4413-8b3c-17647949b524', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-16 18:55:55.307796+00', '2026-10-16 18:55:55.307796+00');
INSERT INTO public.locations VALUES ('5d741d8b-626c-4a32-844e-754675386692', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-16 18:55:55.310573+00', '2026-10-16 18:55:55.310573+00');
INSERT INTO public.locations VALUES ('c998c8da-704e-4a4c-8cf2-e627e923382e', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-16 18:55:55.314172+00', '2026-10-16 18:55:55.314172+00');
INSERT INTO public.locations VALUES ('05de4b21-e393-4bd8-a9db-0232fbd2ae35', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-16 18:55:55.319775+00', '2026-10-16 18:55:55.319775+00');
INSERT INTO public.locations VALUES ('d93102d2-3b59-41ee-9a44-dcb63ee9ce42', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-16 18:55:55.323045+00', '2026-10-16 18:55:55.323045+00');
INSERT INTO public.locations VALUES ('169b6457-65c3-4a8a-b060-a39219406965', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-16 18:55:55.326012+00', '2026-10-16 18:55:55.326012+00');
INSERT INTO public.locations VALUES ('d0d13a03-947a-4966-8a8b-41f352fff3a0', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-16 18:55:55.329324+00', '2026-10-16 18:55:55.329324+00');
INSERT INTO public.locations VALUES ('6269b455-5954-4778-a35c-9240aff96693', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-16 18:55:55.332696+00', '2026-10-16 18:55:55.332696+00');
INSERT INTO public.locations VALUES ('f024c5fe-a582-4673-a7c6-71d486f94583', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-16 18:55:55.3358+00', '2026-10-16 18:55:55.3358+00');
INSERT INTO public.locations VALUES ('fca3a6e7-47fc-47d3-98d2-36252b963aa0', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-16 18:55:55.339954+00', '2026-10-16 18:55:55.339954+00');
INSERT INTO public.locations VALUES ('4fba6bf3-237c-4728-b768-cf9e196b5fa1', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-16 18:55:55.34314+00', '2026-10-16 18:55:55.34314+00');
INSERT INTO public.locations VALUES ('9c4471bc-8503-4e16-ac24-1dc867a31658', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-16 18:55:55.345569+00', '2026-10-16 18:55:55.345569+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('b2291bc1-c4a7-4308-b682-2210236bf7a2', '00000000-0000-4000-8000-000000000001', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'admin', '2026-10-16 18:55:55.23837+00', '2026-10-16 18:55:55.23837+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('cbd45898-19b5-47b8-bfbd-2a8393a24158', '00000000-0000-4000-8000-000000000002', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'ops', '2026-10-16 18:55:55.243706+00', '2026-10-16 18:55:55.243706+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('c6266e50-42e4-47bb-9652-6b32d51b05e6', '00000000-0000-4000-8000-000000000004', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'sales', '2026-10-16 18:55:55.251876+00', '2026-10-16 18:55:55.251876+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('8a0d30cf-2de9-4160-ad51-a9798dc6ce8f', '00000000-0000-4000-8000-000000000005', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'event_director', '2026-10-16 18:55:55.255582+00', '2026-10-16 18:55:55.255582+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('4715dd98-7217-4cf8-a8c1-5475d8a62458', '00000000-0000-4000-8000-000000000006', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'viewer', '2026-10-16 18:55:55.258825+00', '2026-10-16 18:55:55.258825+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('2d826d77-5375-4b92-8201-67090273761f', '00000000-0000-4000-8000-000000000003', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'marketing', '2026-10-16 18:55:55.247539+00', '2026-10-16 18:55:56.360155+00', '{"costs.edit": true}', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-16 18:55:55.231102+00', '2026-10-16 18:55:55.231102+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('7a50aa64-0348-4057-8029-d58f42cac2db', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'f338f617-c682-4226-8b13-de2da86565bd', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'c8b57aab-90b8-4413-8b3c-17647949b524', 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', '06324119-1286-471d-a922-fbce257f4539', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '5721fcfc-74e5-463a-9db1-998a949c2127', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.582348+00', '2026-10-16 18:55:55.589746+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('72c0bafe-d155-4a4e-80cd-871a46e9bd32', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', 'd4edb812-169f-4435-a0cc-c1d762153fde', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '5d741d8b-626c-4a32-844e-754675386692', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'a3d75a57-3333-4501-bd6c-a64b526f409a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.611633+00', '2026-10-16 18:55:55.615582+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('65a918ac-a401-4def-a13b-ad913b200e30', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', 'a7d37d47-c9cc-452a-9a7b-48bc99412eb0', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'c998c8da-704e-4a4c-8cf2-e627e923382e', 'ops', '00000000-0000-4000-8000-000000000002', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', '6a9c16ca-1063-4627-b17b-cdbf31c0a2ab', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '1979faeb-0c6e-4911-9ab7-46f61be20f55', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.636121+00', '2026-10-16 18:55:55.642673+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f74815b0-59f1-4678-bc52-b2b4681bd29e', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '1ba2e4e2-90e7-40b5-a874-b1bf9222d2d5', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '05de4b21-e393-4bd8-a9db-0232fbd2ae35', 'marketing', '00000000-0000-4000-8000-000000000003', 'd9ca6161-54fc-4d0a-a030-3e843075962b', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'afec93a1-a35e-415e-a9ec-ab2534ae0cb2', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.662344+00', '2026-10-16 18:55:55.666948+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7b12dee6-b6af-48f7-89cf-e81e4ab5359e', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '9b7ba848-6065-403d-9353-ca5562a57d81', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'd93102d2-3b59-41ee-9a44-dcb63ee9ce42', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '1f9c64ee-ad9e-48e5-8944-a9c462bd5704', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.6829+00', '2026-10-16 18:55:55.687053+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6962e9bf-07cc-4488-bb54-a6c507b0acf2', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '078c14f8-8812-4102-b2fb-aad3ce5bc7f9', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '169b6457-65c3-4a8a-b060-a39219406965', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '0e3ff711-dc84-442e-b978-31786487d523', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.709426+00', '2026-10-16 18:55:55.713979+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "45640a65-e497-41ec-8082-4835e8c92cda", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e7199383-a9ae-4a07-83cc-366239c91e2c', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', 'a7d37d47-c9cc-452a-9a7b-48bc99412eb0', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'd0d13a03-947a-4966-8a8b-41f352fff3a0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'e8799dfb-7ae0-4bd3-ba13-1d1fd7e1d28b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.730748+00', '2026-10-16 18:55:55.734256+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('434511d7-4800-4e02-8117-a84de6317d1a', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '30ac8966-96a2-4dcd-8285-14fdf128de54', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '6269b455-5954-4778-a35c-9240aff96693', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '044d6c19-c634-46c5-bb32-cffde07dd19d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.753559+00', '2026-10-16 18:55:55.75786+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d4e250ed-bd16-4d11-bcaf-ba1a777711d3', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '1ba2e4e2-90e7-40b5-a874-b1bf9222d2d5', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'f024c5fe-a582-4673-a7c6-71d486f94583', 'marketing', '00000000-0000-4000-8000-000000000003', 'd9ca6161-54fc-4d0a-a030-3e843075962b', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'd641459b-9f53-4d5e-997e-4466200970f4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.774147+00', '2026-10-16 18:55:55.777772+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('083a9c7d-a142-4426-8eab-1661a11131ae', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'c6d6e0fd-672d-4b56-9371-f94d5af2c98e', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'fca3a6e7-47fc-47d3-98d2-36252b963aa0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '0f1222cc-40f8-4c9d-8b99-1a912c475baf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.794028+00', '2026-10-16 18:55:55.799852+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL);
INSERT INTO public.signage_items VALUES ('7fbeb0ad-2ba6-45e6-b094-85ff0ff36e33', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'beda1902-5663-4aa7-9c55-ca0be7257231', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '4fba6bf3-237c-4728-b768-cf9e196b5fa1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '2ef0f954-b239-4420-a792-7d5a436bb490', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.815904+00', '2026-10-16 18:55:55.820793+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', NULL);
INSERT INTO public.signage_items VALUES ('c963180d-6cb8-48f1-96d3-1bce07328116', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '9c4471bc-8503-4e16-ac24-1dc867a31658', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '62daefe9-2ab9-4abb-986d-c92ead1e621d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.845185+00', '2026-10-16 18:55:55.850118+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-13 18:55:55.19+00');
INSERT INTO public.signage_items VALUES ('27778036-acbd-40a3-bdd5-e3bd168cac12', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', 'ab7da75f-1394-4ec9-b333-87ebda1ee104', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.199565+00', '2026-10-16 18:55:56.199565+00', 'sponsorship_item', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', '2026-11-03', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bb6779a6-74ca-41e8-aca6-1a9b7f2425ad', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, 'c875af6c-0464-4549-b488-6ca1d16396fe', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.237198+00', '2026-10-16 18:55:56.237198+00', 'stand_design', 'organiser', '[{"stepId": "3ee28dcf-910f-4d06-b677-8f575f47c3f7", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "55648f93-0400-4268-b0ad-50a14dd93229", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8b1b5e9a-fdee-4c91-be0e-7fd2e34d377f', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '25d27469-0ec6-4930-a8aa-11054f64c8da', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '5d741d8b-626c-4a32-844e-754675386692', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '13040ce1-a030-4b3f-b420-a2882cd98647', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '858c5621-cf23-4627-9af0-c518f0efa357', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.869071+00', '2026-10-16 18:55:55.875589+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "45640a65-e497-41ec-8082-4835e8c92cda", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-13 18:55:55.19+00');
INSERT INTO public.signage_items VALUES ('c7bd02ad-db70-41d5-a1da-e0f67577f951', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '30ac8966-96a2-4dcd-8285-14fdf128de54', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'c998c8da-704e-4a4c-8cf2-e627e923382e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '4a43cc4e-5432-46f6-ba91-c18c41ef1df8', '2026-10-13 18:55:55.19+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.894879+00', '2026-10-16 18:55:55.900789+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-13 18:55:55.19+00');
INSERT INTO public.signage_items VALUES ('e2db12eb-7d91-4194-99b8-a1623ce45d87', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'd93102d2-3b59-41ee-9a44-dcb63ee9ce42', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'cb080396-195b-4271-a286-ef65aff363a3', '2026-10-13 18:55:55.19+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.915915+00', '2026-10-16 18:55:55.921005+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-13 18:55:55.19+00');
INSERT INTO public.signage_items VALUES ('ff643c6d-bcbf-46a2-a27d-6f0f6013d2ea', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '078c14f8-8812-4102-b2fb-aad3ce5bc7f9', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '169b6457-65c3-4a8a-b060-a39219406965', 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'f0720e01-5dec-4c3c-80c5-2942b2ad25a8', '2026-10-13 18:55:55.19+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.937821+00', '2026-10-16 18:55:55.943174+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, '2026-10-13 18:55:55.19+00', '2026-10-13 18:55:55.19+00');
INSERT INTO public.signage_items VALUES ('3353f948-ee6f-4cfb-a02e-4150f4a129d6', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', 'a7d37d47-c9cc-452a-9a7b-48bc99412eb0', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '6269b455-5954-4778-a35c-9240aff96693', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '3db0b495-b9ad-4317-9bf8-3b799ac29256', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.966859+00', '2026-10-16 18:55:55.972212+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f78c6d41-892c-4eae-a7a9-6b615a1b3590', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'c6d6e0fd-672d-4b56-9371-f94d5af2c98e', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'fca3a6e7-47fc-47d3-98d2-36252b963aa0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'caf46a89-4b25-46de-9946-730a62a4df1c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:55.993028+00', '2026-10-16 18:55:56.000654+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('83b17213-07f8-41b6-82d2-5684622606e3', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', 'a7d37d47-c9cc-452a-9a7b-48bc99412eb0', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'c998c8da-704e-4a4c-8cf2-e627e923382e', 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', '6a9c16ca-1063-4627-b17b-cdbf31c0a2ab', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '75ab5ace-3ce0-48a0-80f5-78a52c6aefc5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.02391+00', '2026-10-16 18:55:56.033615+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('70fa6fa2-fb81-4c61-8f4a-e9cf3539965a', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '9c4471bc-8503-4e16-ac24-1dc867a31658', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.058032+00', '2026-10-16 18:55:56.058032+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('73770198-65aa-4f20-a579-ccbd0ea96dc2', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '5d741d8b-626c-4a32-844e-754675386692', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.064787+00', '2026-10-16 18:55:56.064787+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('847e35af-912b-41b4-be2d-be9590d84b6c', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', 'd4edb812-169f-4435-a0cc-c1d762153fde', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'd0d13a03-947a-4966-8a8b-41f352fff3a0', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.071586+00', '2026-10-16 18:55:56.071586+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('16626540-a6ed-4413-bd82-b2cadb0c3c00', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '25d27469-0ec6-4930-a8aa-11054f64c8da', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', '169b6457-65c3-4a8a-b060-a39219406965', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '13040ce1-a030-4b3f-b420-a2882cd98647', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.078796+00', '2026-10-16 18:55:56.078796+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "45640a65-e497-41ec-8082-4835e8c92cda", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a3277dbc-d29b-4c0a-9f03-90580da32041', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '9b7ba848-6065-403d-9353-ca5562a57d81', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'f024c5fe-a582-4673-a7c6-71d486f94583', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.086231+00', '2026-10-16 18:55:56.086231+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5c18f54e-6a7f-4cd9-a4d7-81fdb3a2e6bd', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '1ba2e4e2-90e7-40b5-a874-b1bf9222d2d5', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', 'f024c5fe-a582-4673-a7c6-71d486f94583', 'marketing', '00000000-0000-4000-8000-000000000003', 'd9ca6161-54fc-4d0a-a030-3e843075962b', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.091814+00', '2026-10-16 18:55:56.091814+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9d15f1b4-2735-4b91-9f4b-4f05b2da9608', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'beda1902-5663-4aa7-9c55-ca0be7257231', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '4fba6bf3-237c-4728-b768-cf9e196b5fa1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.098199+00', '2026-10-16 18:55:56.098199+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "45640a65-e497-41ec-8082-4835e8c92cda", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f79cf69a-887f-4155-911c-849701deee1c', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '4fba6bf3-237c-4728-b768-cf9e196b5fa1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.108917+00', '2026-10-16 18:55:56.108917+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('98596709-ed55-4cab-820a-ad062794450a', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'd93102d2-3b59-41ee-9a44-dcb63ee9ce42', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, '886f0c47-ca1b-43b2-affe-8ec795017636', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.115066+00', '2026-10-16 18:55:56.119854+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('80b5faf7-4251-4685-a150-436dc680381b', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'f338f617-c682-4226-8b13-de2da86565bd', '50b51fd2-e0ba-48e5-b2ac-ca8d89566a35', 'c8b57aab-90b8-4413-8b3c-17647949b524', 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', '06324119-1286-471d-a922-fbce257f4539', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'afb8ed4b-c608-40ad-b6b0-47d1711bd2a3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.140721+00', '2026-10-16 18:55:56.145212+00', 'signage', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', NULL, NULL, NULL, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7047c828-f7ef-4148-9b68-a27a7b538167', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'd63501be-154e-4122-b4e0-5123b808e1b3', '670bdb45-0fe5-45a4-94dc-69c2a2484ba3', '9c4471bc-8503-4e16-ac24-1dc867a31658', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.163709+00', '2026-10-16 18:55:56.163709+00', 'signage', 'organiser', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('06cf4c88-cf42-45f7-a69d-c939906ba223', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '60c01135-89b0-464b-9010-ef102e158e50', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 'd6cdd2af-0dea-4d30-acc7-1f7e5b9640a1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.169117+00', '2026-10-16 18:55:56.17255+00', 'sponsorship_item', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', '2026-12-30', NULL, 9000.00, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3e7dd98c-8880-45c3-b13d-22f3daa89b05', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '154bee51-5c15-46b0-b5cb-70bcd897792c', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.187565+00', '2026-10-16 18:55:56.187565+00', 'sponsorship_item', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}, {"stepId": "e548e85c-8538-4618-aa13-0d0b60e6ec5c", "userId": null}]', '2026-11-05', NULL, 12500.00, '2026-10-06 18:55:55.19+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('379b7a9a-87fd-414b-b2ae-06ff8f601115', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'e329b322-6002-4dd7-a156-805d662c2bee', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-16 18:55:56.192448+00', '2026-10-16 18:55:56.192448+00', 'sponsorship_item', 'sponsor', '[{"stepId": "6a286d42-2c27-44c9-8494-95070c2f4c6b", "userId": null}, {"stepId": "acf1f495-95a7-41fa-8b8f-525731f918cd", "userId": null}]', '2027-02-13', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('bb3e9455-a615-4a17-a642-bd9a8210f999', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'e2db12eb-7d91-4194-99b8-a1623ce45d87', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'e3724183-3523-4e97-8857-948d2c20e38b', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-16 18:55:55.933396+00', '2026-10-16 18:55:55.933396+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('6a9c16ca-1063-4627-b17b-cdbf31c0a2ab', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', 'Logo on 6 hanging banners', 6, '2026-10-16 18:55:55.393913+00', '2026-10-16 18:55:55.393913+00');
INSERT INTO public.sponsor_entitlements VALUES ('06324119-1286-471d-a922-fbce257f4539', '8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', 'Entrance feature branding', 1, '2026-10-16 18:55:55.397062+00', '2026-10-16 18:55:55.397062+00');
INSERT INTO public.sponsor_entitlements VALUES ('fa5ad17c-bfbb-499e-b61c-4232683d98ca', 'd9ca6161-54fc-4d0a-a030-3e843075962b', 'Seminar theatre branding', 1, '2026-10-16 18:55:55.404261+00', '2026-10-16 18:55:55.404261+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('8f5dc4b0-0b4a-41a7-b7c3-0c50417a2907', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-16 18:55:55.390721+00', '2026-10-16 18:55:55.390721+00');
INSERT INTO public.sponsors VALUES ('d9ca6161-54fc-4d0a-a030-3e843075962b', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-16 18:55:55.399751+00', '2026-10-16 18:55:55.399751+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('0a915c34-82ae-446c-82b4-bc906daeff42', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'c69070a1-c0c3-4fdb-9d1d-7a8ad2970d26', 'STD-BIRM27-A10', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-10 18:55:55.19+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.245126+00', '2026-10-16 18:55:56.245126+00');
INSERT INTO public.stand_submissions VALUES ('f1ac822f-016d-4a57-b316-cbc2d82c7a4b', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '4fe60a30-135c-43e2-885c-f574999724f7', 'STD-BIRM27-A20', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-10 18:55:55.19+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.278368+00', '2026-10-16 18:55:56.278368+00');
INSERT INTO public.stand_submissions VALUES ('eceafdb9-3e4d-49bd-98bc-538f746c083a', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '6300e0eb-b1c9-4534-99db-bcea96f88a7d', 'STD-BIRM27-A30', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-10 18:55:55.19+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.299121+00', '2026-10-16 18:55:56.299121+00');
INSERT INTO public.stand_submissions VALUES ('b24ffa39-cd4d-4cfc-93be-5ff9dfc09ae7', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '04806b7d-7fac-430f-a0fa-48e7a3c93965', 'STD-BIRM27-B10', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-10 18:55:55.19+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.31777+00', '2026-10-16 18:55:56.31777+00');
INSERT INTO public.stand_submissions VALUES ('dd2d796a-bf96-4128-8ff2-d7beba08989c', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'b56c124a-251a-4e07-9bd3-16cd1b9c3d1e', 'STD-BIRM27-B20', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-10 18:55:55.19+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.336972+00', '2026-10-16 18:55:56.336972+00');
INSERT INTO public.stand_submissions VALUES ('97194a49-ca64-4795-a9f3-2ea4cc61c807', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '1eee2062-351d-4fe3-9709-2a9d2c00b63f', 'STD-BIRM27-B30', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 0, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.35097+00', '2026-10-16 18:55:56.35097+00');
INSERT INTO public.stand_submissions VALUES ('78e872df-0022-4391-b0e3-f1925b4fb8ea', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '947799c6-e731-4f65-8669-38fcc142e13a', 'STD-BIRM27-C10', 'c8c6d793-ce94-487b-bd61-6385f9c543d7', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 0, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.354249+00', '2026-10-16 18:55:56.354249+00');
INSERT INTO public.stand_submissions VALUES ('f606dff6-3d18-464f-a24f-1456ca6849d5', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', '60215d1d-8bf3-41a4-b5d7-b59d123e44b3', 'STD-BIRM27-C20', '054a3c0c-921a-404d-a063-1a52e2bfc9c3', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 0, '00000000-0000-4000-8000-000000000002', '2026-10-16 18:55:56.357327+00', '2026-10-16 18:55:56.357327+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('e3724183-3523-4e97-8857-948d2c20e38b', 'ee98555a-609b-4714-8718-d9254286d904');
INSERT INTO public.supplier_service_links VALUES ('e3724183-3523-4e97-8857-948d2c20e38b', 'dea5956c-4987-4421-803d-62ddee63824b');
INSERT INTO public.supplier_service_links VALUES ('32c900dd-0311-4041-8ca5-642711663d1d', '65993ad5-f72e-4090-99cb-6cc67ba956b4');
INSERT INTO public.supplier_service_links VALUES ('32c900dd-0311-4041-8ca5-642711663d1d', 'dea5956c-4987-4421-803d-62ddee63824b');
INSERT INTO public.supplier_service_links VALUES ('32c900dd-0311-4041-8ca5-642711663d1d', '828b3b74-1877-4feb-ad88-4a1114b071d0');
INSERT INTO public.supplier_service_links VALUES ('13040ce1-a030-4b3f-b420-a2882cd98647', 'f080a585-192c-47bd-a803-b6d259d6244a');
INSERT INTO public.supplier_service_links VALUES ('13040ce1-a030-4b3f-b420-a2882cd98647', '828b3b74-1877-4feb-ad88-4a1114b071d0');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('ee98555a-609b-4714-8718-d9254286d904', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Signage print', 1, false, '2026-10-16 18:55:55.354898+00', '2026-10-16 18:55:55.354898+00');
INSERT INTO public.supplier_services VALUES ('f080a585-192c-47bd-a803-b6d259d6244a', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Digital screens & AV', 2, false, '2026-10-16 18:55:55.356749+00', '2026-10-16 18:55:55.356749+00');
INSERT INTO public.supplier_services VALUES ('65993ad5-f72e-4090-99cb-6cc67ba956b4', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Rigging', 3, false, '2026-10-16 18:55:55.358306+00', '2026-10-16 18:55:55.358306+00');
INSERT INTO public.supplier_services VALUES ('dea5956c-4987-4421-803d-62ddee63824b', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Installation', 4, false, '2026-10-16 18:55:55.359854+00', '2026-10-16 18:55:55.359854+00');
INSERT INTO public.supplier_services VALUES ('828b3b74-1877-4feb-ad88-4a1114b071d0', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Staffing', 5, false, '2026-10-16 18:55:55.361583+00', '2026-10-16 18:55:55.361583+00');
INSERT INTO public.supplier_services VALUES ('e1cbe03f-ca46-42a7-bd6e-7c96f166326f', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Furniture', 6, false, '2026-10-16 18:55:55.363337+00', '2026-10-16 18:55:55.363337+00');
INSERT INTO public.supplier_services VALUES ('85ade72b-f02d-4d6f-97cd-652c7523b1cb', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Structural engineering', 7, false, '2026-10-16 18:55:55.36515+00', '2026-10-16 18:55:55.36515+00');
INSERT INTO public.supplier_services VALUES ('0528884c-b260-49ab-ab09-6a06e2c37fca', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Floor Manager', 8, false, '2026-10-16 18:55:55.366941+00', '2026-10-16 18:55:55.366941+00');
INSERT INTO public.supplier_services VALUES ('6383b213-f7f5-4c7c-9723-2496dd57d1b6', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Security', 9, false, '2026-10-16 18:55:55.368983+00', '2026-10-16 18:55:55.368983+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('e3724183-3523-4e97-8857-948d2c20e38b', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-16 18:55:55.348733+00', '2026-10-16 18:55:55.348733+00', false);
INSERT INTO public.suppliers VALUES ('32c900dd-0311-4041-8ca5-642711663d1d', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-16 18:55:55.351434+00', '2026-10-16 18:55:55.351434+00', false);
INSERT INTO public.suppliers VALUES ('13040ce1-a030-4b3f-b420-a2882cd98647', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-16 18:55:55.353588+00', '2026-10-16 18:55:55.353588+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('4b84fb69-6532-4ef9-afe6-b9d20ff852ce', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-23', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '7a50aa64-0348-4057-8029-d58f42cac2db', NULL, '2026-10-16 18:55:56.364113+00', '2026-10-16 18:55:56.364113+00', NULL);
INSERT INTO public.tasks VALUES ('bd869967-cfd5-4aa5-a3ac-10b3ff5255fd', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-26', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-16 18:55:56.366313+00', '2026-10-16 18:55:56.366313+00', NULL);
INSERT INTO public.tasks VALUES ('08f87372-5fe3-4259-9f57-4a961e189506', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Walk the hall with the venue', NULL, 'done', '2026-10-11', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-16 18:55:55.19+00', '2026-10-16 18:55:56.367855+00', '2026-10-16 18:55:56.367855+00', 'bd869967-cfd5-4aa5-a3ac-10b3ff5255fd');
INSERT INTO public.tasks VALUES ('b3e112d1-6e4d-401e-a2e1-3e5405b7473b', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', '9f9a2b08-9bfc-4f9b-9d4f-5cda8447d5f9', 'Send sign positions to the printer', NULL, 'open', '2026-10-15', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-16 18:55:56.367855+00', '2026-10-16 18:55:56.367855+00', 'bd869967-cfd5-4aa5-a3ac-10b3ff5255fd');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.235601+00', '2026-10-16 18:55:55.235601+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.241886+00', '2026-10-16 18:55:55.241886+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.245904+00', '2026-10-16 18:55:55.245904+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.249807+00', '2026-10-16 18:55:55.249807+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.25406+00', '2026-10-16 18:55:55.25406+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-16 18:55:55.257352+00', '2026-10-16 18:55:55.257352+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.51683+00', '2026-10-16 18:55:55.51683+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.521937+00', '2026-10-16 18:55:55.521937+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.526351+00', '2026-10-16 18:55:55.526351+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.529808+00', '2026-10-16 18:55:55.529808+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.533548+00', '2026-10-16 18:55:55.533548+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-16 18:55:55.57413+00', '2026-10-16 18:55:55.57413+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('9da7616d-3398-4a42-8c3d-3510f0357da6', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-16 18:55:55.270267+00', '2026-10-16 18:55:55.270267+00');
INSERT INTO public.venue_rules VALUES ('a0d21c8a-70db-4612-af1b-1e9d8eb2d6d3', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-16 18:55:55.272876+00', '2026-10-16 18:55:55.272876+00');
INSERT INTO public.venue_rules VALUES ('d1569a3c-df51-4e98-9116-a320afcee00e', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-16 18:55:55.275192+00', '2026-10-16 18:55:55.275192+00');
INSERT INTO public.venue_rules VALUES ('fa1dbb8c-cbe2-4a81-8d02-98643166b75f', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-16 18:55:55.277282+00', '2026-10-16 18:55:55.277282+00');
INSERT INTO public.venue_rules VALUES ('f53e0f08-451d-4c46-a193-92873da109ee', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-16 18:55:55.279728+00', '2026-10-16 18:55:55.279728+00');
INSERT INTO public.venue_rules VALUES ('5a2e1ca3-0636-42f6-b6dd-740d5e554f36', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-16 18:55:55.281786+00', '2026-10-16 18:55:55.281786+00');
INSERT INTO public.venue_rules VALUES ('df104d4b-f9c3-44a1-b281-67fa995d4e4c', '16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-16 18:55:55.283933+00', '2026-10-16 18:55:55.283933+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('16f2e9dc-fc28-43c5-8301-f4ab5ce2fff7', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-16 18:55:55.263698+00', '2026-10-16 18:55:55.263698+00', false);
INSERT INTO public.venues VALUES ('89ad8fff-f625-43d9-a147-f76c7fc6e6bf', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-16 18:55:55.265808+00', '2026-10-16 18:55:55.265808+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('d2024f61-1afc-4a55-890f-6b264c8daad0', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-16 18:55:55.41657+00', '2026-10-16 18:55:55.41657+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('472d72bb-48aa-4f6e-976c-2252ea1453cf', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-16 18:55:55.419583+00', '2026-10-16 18:55:55.419583+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('1577d64c-240a-4736-bb33-3d628738a20b', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-16 18:55:55.421336+00', '2026-10-16 18:55:55.421336+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('669b7cd3-4839-4c6a-afe8-327a86e993b7', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-16 18:55:55.422957+00', '2026-10-16 18:55:55.422957+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('4287212f-cd3b-4e62-b935-34e9bd1c2cbd', 'c875af6c-0464-4549-b488-6ca1d16396fe', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-16 18:55:56.227003+00', '2026-10-16 18:55:56.232999+00', '{organiser,sponsor}', false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947');
INSERT INTO public.workflow_steps VALUES ('d3cb4164-3445-433a-8447-1aa0a17167cb', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-16 18:55:55.481204+00', '2026-10-16 18:55:55.481204+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('fb9eec1a-aa93-4dfc-b869-4a56f8523b54', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-16 18:55:55.482737+00', '2026-10-16 18:55:55.482737+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('3f40a85c-cad1-4de4-9cbb-1694c22ff5ea', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-16 18:55:55.484256+00', '2026-10-16 18:55:55.484256+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('b08ade09-b602-4e93-ac5d-9c979ef275a8', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-16 18:55:55.485536+00', '2026-10-16 18:55:55.485536+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('7d283807-c997-47da-a565-c1534a2e54e0', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-16 18:55:55.486757+00', '2026-10-16 18:55:55.486757+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('9641c3a0-723a-4b5f-83b7-cc10313f555b', 'cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-16 18:55:55.487897+00', '2026-10-16 18:55:55.487897+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('6a286d42-2c27-44c9-8494-95070c2f4c6b', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-16 18:55:55.410778+00', '2026-10-16 18:55:56.21502+00', '{organiser,sponsor}', false, '17506cfa-d41d-4093-a281-030c4833b4b5');
INSERT INTO public.workflow_steps VALUES ('acf1f495-95a7-41fa-8b8f-525731f918cd', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-16 18:55:55.413479+00', '2026-10-16 18:55:56.216842+00', '{organiser,sponsor}', false, '7b6e0db5-1572-4292-b443-ca5927a4ac70');
INSERT INTO public.workflow_steps VALUES ('e548e85c-8538-4618-aa13-0d0b60e6ec5c', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-16 18:55:55.415159+00', '2026-10-16 18:55:56.218912+00', '{sponsor}', false, '2e756365-8406-4f56-91c7-3476aa802ecd');
INSERT INTO public.workflow_steps VALUES ('45640a65-e497-41ec-8082-4835e8c92cda', 'de3762c7-e6bc-4767-86aa-4df05eb812f9', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-16 18:55:55.417915+00', '2026-10-16 18:55:56.220681+00', '{organiser,sponsor}', false, 'e30799b6-7bb4-4dce-b3d3-3539d4beb947');
INSERT INTO public.workflow_steps VALUES ('3ee28dcf-910f-4d06-b677-8f575f47c3f7', 'c875af6c-0464-4549-b488-6ca1d16396fe', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-16 18:55:56.222846+00', '2026-10-16 18:55:56.229379+00', '{organiser,sponsor}', false, '17506cfa-d41d-4093-a281-030c4833b4b5');
INSERT INTO public.workflow_steps VALUES ('55648f93-0400-4268-b0ad-50a14dd93229', 'c875af6c-0464-4549-b488-6ca1d16396fe', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-16 18:55:56.224344+00', '2026-10-16 18:55:56.230409+00', '{organiser,sponsor}', false, '7b6e0db5-1572-4292-b443-ca5927a4ac70');
INSERT INTO public.workflow_steps VALUES ('210380f3-9ae9-473f-8f24-a97d54d60c97', 'c875af6c-0464-4549-b488-6ca1d16396fe', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-16 18:55:56.22567+00', '2026-10-16 18:55:56.232058+00', '{sponsor}', false, '2e756365-8406-4f56-91c7-3476aa802ecd');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('de3762c7-e6bc-4767-86aa-4df05eb812f9', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Signage default', 'signage', true, false, '2026-10-16 18:55:55.408249+00', '2026-10-16 18:55:55.408249+00', NULL);
INSERT INTO public.workflows VALUES ('cf8f6f07-3489-4cf9-bb88-1f02bcbd119b', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Stand default', 'stand', true, false, '2026-10-16 18:55:55.479406+00', '2026-10-16 18:55:55.479406+00', NULL);
INSERT INTO public.workflows VALUES ('c875af6c-0464-4549-b488-6ca1d16396fe', 'ee9d14e1-f375-49bd-b818-42a9c40d77e4', 'Stand design sign-off', 'signage', false, false, '2026-10-16 18:55:56.208899+00', '2026-10-16 18:55:56.208899+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 13, true);


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
-- Name: approvers_one_main; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approvers_one_main ON public.approvers USING btree (department_id) WHERE is_main;


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

\unrestrict 6vH0CavMQTHRlukEVs6Bls7g2CrIeZ0TJKD6HW8gZyUxgIMkpt1daRws9SIIfQZ

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
