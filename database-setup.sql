-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites, public.supplier_services, public.supplier_service_links, public.departments, public.approvers CASCADE;
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

\restrict LH9ae1e0mC1ql98Gb7jbywd8IZFXhlyDfR5piLtDDmslljSQ8t5SbKvBmH0BPWf

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
INSERT INTO drizzle.__drizzle_migrations VALUES (5, '65bf2a8698b59f070aad294fbb21d5089fe629b06b79c58d85ad12106e01abf8', 1790325422848);
INSERT INTO drizzle.__drizzle_migrations VALUES (6, '6757321e3e804ab6e7fde119333e65f225ffeb77f65735613b025773f8145358', 1790330588710);
INSERT INTO drizzle.__drizzle_migrations VALUES (7, 'be6f48bbde7615c5827770d0ff3ec083541d89b777281ef5046a2c622d0e382b', 1790337619744);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('ffc87dc6-a2f1-4abd-9585-21ef0fcb14bf', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('061c44e7-36e0-4dae-a485-4b0d24e00019', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('bc691769-85f2-47ad-9ade-a397c6977586', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('5094c479-1784-40d9-9aed-4db8d229502a', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('db06037e-252e-4610-842d-5a63c9b0f297', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('a4e4b189-1d6b-422c-95e3-d1ac291b6d86', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('afa3847e-14ee-4d12-88ca-dd3955366dc0', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3647542d-d8fe-4f99-b76b-9655528bd3c8', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.792138+00', '2026-09-25 12:20:11.792138+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a0fe5484-3421-4b3f-a6ab-022c1cdb265f', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('31b9c1ac-2c7b-4538-88fd-e1c408e3ffbe', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('f3e22893-a65d-4525-9950-cf4542b2276f', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('ea25f6cb-0b56-4474-b117-b204167bc0ca', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('00e3f67e-3f01-4f49-b0cb-aa678f47f67e', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('eddef788-5768-422d-8b7e-9f04e5e46c95', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('3323ccb7-3f60-4cd8-ba9b-f6f010bbc2df', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6b5821fb-8eb2-4b23-a735-f9ca0a5224a5', 'signage_item', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.814475+00', '2026-09-25 12:20:11.814475+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('336c3a52-b113-4714-83a6-0f830214c30c', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 12:20:11.467+00', '2026-09-21 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('b009d0e3-8b09-4452-a8c3-318a1957a59e', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 12:20:11.467+00', '2026-09-16 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('d4aee624-c6d7-424a-a6aa-8e958f7f7f4d', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 12:20:11.467+00', '2026-09-18 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('0788675c-e00f-4b5b-b934-0d174b79baac', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('57394881-f7b5-47ff-86ba-5be3ae7ddf63', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('edae28f7-b76c-4d72-8483-67b3b7d5db92', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d86f8f63-cbd9-450c-86e8-2fd6f192c1cd', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('fca0045a-f8a5-47ec-a5be-3f73a4983320', 'signage_item', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.836641+00', '2026-09-25 12:20:11.836641+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('4d300fc5-07d8-4931-9518-570a78d86438', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('92e0b07c-8632-40c6-b6a0-c7c74113d6e8', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('b732ed32-d0ea-4f53-8033-5083e03c1a16', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('3a14d67d-d3fe-4398-91d0-571dc05fd57c', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('466c2639-814a-46a3-a347-f1f7e0942a5b', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('15580399-b3c4-455f-bc74-c5c6fa556218', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f230b077-265a-4fea-ac5e-4d21a2a0ea77', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('de31d40b-6833-4086-8520-d69964ddc560', 'signage_item', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.856992+00', '2026-09-25 12:20:11.856992+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('85fa5641-d67f-4c3e-bd47-b0a525e2ecfd', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('6517389a-1d56-4ae0-941f-a7ffdaf94431', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('d8cb5bc8-1727-45b6-a3bf-2dbb2a3eef94', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('e7f7a6f2-0921-409e-95f4-808511287669', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('22bb32c5-dcdd-4c2d-a8ad-6dabb372215a', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('8708cdd3-f0e8-4db4-a396-5a86cb65f3bd', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('2fe0e376-6568-40fd-9079-85280484e4ea', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('17ed08de-934d-4b48-b8f0-cc5aa8a035a2', 'signage_item', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.873725+00', '2026-09-25 12:20:11.873725+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7650110b-95bc-44b4-8376-17fec4b73d5a', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 12:20:11.467+00', '2026-09-16 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('2b643e1e-a210-4ba3-9f1d-24e8a9c84357', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 12:20:11.467+00', '2026-09-16 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('be8602bb-9afc-4392-8f5f-1c390f22e07a', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('a16c4167-8da7-4c71-87a1-291c9d533aaa', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0b37c761-a0c1-46c2-8220-26cd3f4d841d', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 12:20:11.467+00', '2026-09-21 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('cd3d6ff2-160a-4fb3-b928-d325977b7091', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c8ee751f-90ee-4cc0-95db-020c0ddc631a', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('45ddda71-21e8-4181-96d2-e1fdbc9c49fb', 'signage_item', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.896717+00', '2026-09-25 12:20:11.896717+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('da6c22d6-5860-4427-aa56-f7285ad43954', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('27c4ec0c-0195-4b13-8e39-e99debf574ae', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('dfd629d2-1d43-47b9-9e13-d0645c9f9e5d', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('169112f7-d1c1-4e9d-a2b5-a9aa5033a64b', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('00c308b6-4856-4599-bad8-ec388a789f7d', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('167c4e75-4cd0-4fe0-bc6f-a6f71d3b09b8', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('ddbffdd9-cadd-4d47-8299-d697abbb0978', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('63bd49e0-8524-41c9-a839-7c7ce13d9527', 'signage_item', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.917246+00', '2026-09-25 12:20:11.917246+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0d3cbeb3-8740-496d-86c5-8a543f89470d', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('db9be404-48c2-4811-81a7-0622b692e263', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('de6c3f0c-45ea-4e16-9cca-f31d4deb0e98', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('35117213-642c-4351-84ae-2600445addfb', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('be506b04-2d4e-4593-a3ee-bf091ff845fa', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('b3c48b0e-148f-4365-bd17-5078200540e3', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cb37c81e-4d4c-4f7f-827e-17f8dac503f1', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('db29f30b-42b9-4e3a-abb2-02b340411f1b', 'signage_item', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.937473+00', '2026-09-25 12:20:11.937473+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e1d4b9aa-c173-4562-970b-402c56417119', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('47231d39-8449-4d22-ab77-9cac7141948a', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('6740facc-7238-4142-9710-97a4f35b6f31', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 12:20:11.467+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('727a22a1-14ad-40c3-a7c0-3f4052f5e09b', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9f4daf72-db46-40fb-9ec4-96e0598420ae', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('eae8c89a-c2e9-4456-aeda-58f989efb566', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('5e1b553f-0081-409c-8fd3-3c589045c37d', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7cfc64b0-e52d-41bf-83c0-e6dbca64a747', 'signage_item', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.954241+00', '2026-09-25 12:20:11.954241+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('eaa1ac83-27dc-48ce-ae20-76e66b650e4e', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('c8fd7c5b-e6b4-4238-ab8f-3172d126a72c', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('556b9fbe-12ad-4806-9ff7-ee69227419da', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('f8e50ba9-827f-4260-850d-6ff4bd0ef9d8', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('709ae578-12ce-4a88-8038-3beef0f52e0e', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('17f995ed-b9b2-407c-93d9-7825d11aaa78', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('aa098222-23a8-4e9c-8ce6-1874146d5704', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('9fc13e72-9fe3-4a70-ab64-357e14417f0f', 'signage_item', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.97226+00', '2026-09-25 12:20:11.97226+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3cc1709c-b7a7-4633-b5d8-fa680a0ae717', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('d6e75c01-d99e-4910-8281-7d06630ca5b6', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('ff99841f-f3f6-4249-8a32-4c4ebd62bca2', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('65a0af6d-0dad-4293-a15b-797aca56c02b', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d4ec0300-dfab-4492-b5ad-fedc2e611df5', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('4dd32826-2491-4970-be60-9f1e3c140394', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('286b99e9-bd7a-4850-afb0-bbe5eebf2433', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2d014254-2a03-4141-827c-b2dd0ee4bf7d', 'signage_item', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:11.987493+00', '2026-09-25 12:20:11.987493+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('46616af7-96f1-4e2a-a670-72cfe62312cf', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('a7cf4b90-9c23-4fdc-a184-d0f9f4a9e66b', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('1a80afff-3223-4bc4-8c16-05018615735f', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('24c81725-eb0b-4c32-bb83-f5b17a198683', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('b3b5db2c-9101-45fe-ac28-33f2682d7954', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('6dae9556-5ec7-4e64-aea3-0f3b9993667b', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('01c16209-92c1-4cbb-bf01-135260d3cc42', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f394d28a-0408-4f16-b2cc-39174ad2003d', 'signage_item', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.002646+00', '2026-09-25 12:20:12.002646+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('88c4cbd1-d473-4eef-b8c3-8dc83dae492e', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('009f1e79-cd78-4ec8-b758-6a1a9e5d2db8', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('0f71ad83-89d7-4aa1-8a23-4a177090d9dc', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('e63b1955-2655-48de-a184-3c839b1aff68', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('930b880e-0bde-43cc-80e5-863213158066', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('0fc8fc8d-cb2d-40ab-8ba9-a8a55fda5130', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c8368d06-2846-469d-858b-4291740b7294', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e558ad5e-8391-4a65-ae7f-5f02de283891', 'signage_item', '60e12914-f69e-4561-864b-30c2ae587498', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.020252+00', '2026-09-25 12:20:12.020252+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('eeaa9a44-70ab-4e9d-b00e-86ca7f1f4c7f', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('194a0780-3873-4d16-830e-6dca4c440046', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('cf85d919-83df-4388-a421-4646b2dfbca9', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('c20d1215-a3bd-4cf6-ac97-b645cc1efd78', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('56919927-e1d5-4e4d-9c35-e865b0cadeee', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('33035dec-6fed-46e2-8d20-eb54edfdc5aa', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('17095ac7-c375-4923-ab7b-3b0a4efc974a', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('306f38cd-756f-4b63-be7a-19ff0f189bbc', 'signage_item', '30906015-95e2-4822-aaa7-86e299b4e037', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.037891+00', '2026-09-25 12:20:12.037891+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('28317190-d4a3-4f4a-aa82-baba308ab895', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('76e89e68-8be2-4fe2-91eb-1940222c01a2', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('f9f14c40-0cf1-41e2-bc04-4e1e2d280d4b', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('9bbfd3c5-32f4-43da-bba1-8a517d98d099', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('7f8a7a0f-da75-47d1-b2de-86504cd5b57f', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('1dbf3e9c-5f20-46a9-8574-34c298da7c6c', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('16172708-b5c5-4ace-a8e9-e24469a52e94', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8997988f-c1b3-482c-8998-b6c9c4ba365c', 'signage_item', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.05361+00', '2026-09-25 12:20:12.05361+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8e7adbeb-1908-42bd-934f-9005dcf19650', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('fd67dfa5-d64b-41a4-bda3-11b4f31a57aa', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('0fec501a-05a7-4087-ace5-23b06c44843e', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('904231d4-2d49-45e2-9805-17608c3686b9', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('709f4972-16b6-4dac-871f-cbcc2893f7d9', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('1cb854a5-5afb-4af6-98d8-907357fb77dc', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('7e4802a0-6c78-471d-b03b-9c62296f1beb', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6dad11b4-6567-4b58-ab26-8a4bc189e61d', 'signage_item', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.072676+00', '2026-09-25 12:20:12.072676+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1a045e89-12cc-4dfc-849b-b09370bceda1', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('9ce6b176-8f39-4bb8-a3fb-9df7188f3cc4', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('bcfa369c-0fb2-4f0b-a277-12f4d9f98421', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('7ce17a42-9d62-45a7-a950-4dff1bf02d29', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('e0e30fce-e092-4f94-9dad-ff5b32dea118', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('a6f8dda7-1125-4ac4-9f54-309e2f7e79f0', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a57c214b-56c2-4363-a4f8-76713c2e8b03', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('bb37ab81-05b6-4787-a289-3054c8a9a5e6', 'signage_item', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.093681+00', '2026-09-25 12:20:12.093681+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a155602d-82df-430a-82bf-b7d2cb6d339e', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('1beac797-caff-49fa-b651-f8234f5749c8', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('69f34b9e-7497-4bd5-a5a0-c3a1500d5c8d', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('b34695f6-5909-4426-b68d-3c59fdd39c01', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('292bae58-1ae6-4fd7-bff5-cd61232764ab', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('ec15ac7f-1876-4740-98be-b2b16010b548', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('df2e9efc-94cb-4ac3-a62e-d7a45f0fd5fc', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7849819b-f03f-42c0-8b5f-a70b719c2fd8', 'signage_item', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.11244+00', '2026-09-25 12:20:12.11244+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7f27db33-36e4-4158-9edf-13149cd76421', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('09574114-2875-4522-8e29-289666cf342e', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 12:20:11.467+00', '2026-09-27 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('64ae17e1-5d2d-448d-9151-fa27c691533b', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('0a20ce92-4110-4fa2-98c3-1e30d9a652d3', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 12:20:11.467+00', '2026-09-27 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('3bd5f06b-24bc-46ca-9d4c-751eb0424982', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('be9bc46b-1d06-432d-a44a-982e33632782', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('41e60093-4fa5-4c03-93c8-0aea39f06b59', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('bd2cb2c4-95cb-44e0-bed5-70605f6b728f', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('6849620a-a7af-4380-ab0f-f1c04cb62a46', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e25432b3-d057-4f6a-9239-41658bab6f88', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c41200f1-ef73-4260-b71d-5121d5e8a144', 'signage_item', '7374d653-4d84-4872-b455-b3df9dc15876', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.134459+00', '2026-09-25 12:20:12.134459+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ff846a0e-7f70-4dce-a78c-6384d27b632c', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('e88fc314-5056-41b7-8aff-8a8b1aa2a53a', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('255fc3b5-bbe8-414d-8122-b87c06c2fc73', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('c1a36e00-6403-4e26-8a58-c0756b107d61', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('e69d4838-4b7a-4829-b71e-b1f0b84c969b', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('ee62779c-2c5f-4a1a-b5e9-586f56f9293f', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('7bf743d1-ebea-41ce-9fa4-d2b315554828', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('54194f92-3e6e-4f53-876d-327f41159506', 'signage_item', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.188551+00', '2026-09-25 12:20:12.188551+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3f35fd70-46ab-4f0a-a642-8ff4eb80ca39', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('34671939-9f7a-4ec4-97e9-dca9730d419c', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('9b4a69d0-bb94-417e-9df9-348b36304c7c', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('a8aa1700-990c-40c4-af7d-fd0b5c5365f5', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 12:20:11.467+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-29 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('787696ac-60b8-46ba-8610-6e9aa5dfdfb8', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('d9c4f01c-8560-4eca-84ce-7a0ec6b05fbd', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 12:20:11.467+00', '2026-09-24 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e483ee8b-8887-4468-a50b-19170191bc60', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c72f12ca-871c-4303-b2cd-ae69c550e4ea', 'signage_item', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.208699+00', '2026-09-25 12:20:12.208699+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cdea927c-2190-466e-b4ff-afde82043a01', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, 'f826a881-f10d-48fc-a069-d7d88582e5f9', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 3, false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.approval_instances VALUES ('c78ad773-0b89-4b7d-ad35-b85b9529dd3e', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, 'c4d8153b-a943-4cc0-8317-a568dcebab00', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 3, false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.approval_instances VALUES ('6e9781a6-4520-4f61-bd43-bb0efb86da5d', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, '97ca0927-9de4-4c00-a611-6d70b5cdae62', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 12:20:11.467+00', '2026-09-25 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 5, false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.approval_instances VALUES ('b43c205b-02ef-483a-98f6-a3f447e74966', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, '22aa3822-2d16-4052-b821-29e15a27fac0', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('c7bc32e0-7bb3-453c-9470-8fa9c7a28871', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, 'cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 3, false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.approval_instances VALUES ('1370744f-ee21-4843-999e-f8ec1625aa32', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, '06ec9fc0-3129-44b2-8035-ae374e3277e6', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('3daae35b-ff25-4cc6-821f-8a8c17597930', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, '709ba005-3606-4a66-a380-7f223fee7d5a', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('32bf16f2-9660-4189-8d81-88c21c7c6852', 'signage_item', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, '90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.232949+00', '2026-09-25 12:20:12.232949+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d32583a4-2732-4d70-ae3d-fdf3f7204e6e', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, '590712a9-3448-49b6-b1d1-e70b6b352bf0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 12:20:11.467+00', '2026-09-22 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('daeb9e0f-682e-4a89-b029-9c72a2f8b20d', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, '75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 12:20:11.467+00', '2026-09-28 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d5624e9c-4d75-4e62-82e8-4f6463dd99fe', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, 'a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('5a551628-0e2d-4606-98e4-204db9f49318', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, '97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9407aebf-b4ff-4f73-ab24-6497e4a7d257', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, '1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4b8676be-6bb7-454d-898f-00d749f0c46a', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 1, '9571e5d9-ca38-450d-bc82-d54f0eac5467', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1a014851-ffa9-4f95-8d91-a90a5a9ee82f', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, '590712a9-3448-49b6-b1d1-e70b6b352bf0', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 12:20:11.467+00', '2026-09-22 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('57fdf0df-123e-446b-bd9b-3770d31194c1', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, '75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('83663a66-25bb-45a0-af36-b2214413ed50', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, 'a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('b94fecff-de75-462c-a407-a4293faba8f7', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, '97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('596f77f1-ad80-42ab-9031-de4b59d02bfe', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, '1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('6ce1b050-f966-4311-a439-ab67dabce44a', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 1, '9571e5d9-ca38-450d-bc82-d54f0eac5467', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f3a7d661-61cc-4450-996b-6acaabf190ae', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, '590712a9-3448-49b6-b1d1-e70b6b352bf0', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-19 12:20:11.467+00', '2026-09-22 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('af35bf03-0dce-419c-8c52-36c3897df70a', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, '75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('cfa08c04-cf49-4b35-a61e-997f26c648a4', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, 'a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('0de238a0-d0d5-4555-a72f-e350ecc12d76', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, '97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('cbdb1f37-6667-4272-8f6a-a3892db5c22f', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, '1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cbfc513e-ca36-47cd-8f35-cd8d4ce97dcf', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 1, '9571e5d9-ca38-450d-bc82-d54f0eac5467', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('45702793-1595-445c-99d0-187d464403fc', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, '590712a9-3448-49b6-b1d1-e70b6b352bf0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 12:20:11.467+00', '2026-09-22 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('823d8af3-31b1-4cf1-becf-45d24e2d6b37', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, '75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d2537871-c196-459b-9c58-c4db892a663c', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, 'a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-26 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('68632542-6826-4a32-ba3b-29907a413229', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, '97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-28 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('7279f083-3e52-46a2-b705-af49bc03cab4', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, '1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1421555f-c0dd-44d3-999d-b8bd4f93ee75', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 1, '9571e5d9-ca38-450d-bc82-d54f0eac5467', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 12:20:11.467+00', '2026-09-21 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('37146b7f-d9d3-4a65-9914-9ece87756849', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, '590712a9-3448-49b6-b1d1-e70b6b352bf0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 12:20:11.467+00', '2026-09-22 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('9e2ed22b-7874-400a-9541-1346d8182282', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, '75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('280be98d-1a70-4fc6-8678-6755af3c73b6', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, 'a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-26 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('26eae911-29f8-4d6e-83e1-01e1ff792860', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, '97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-28 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9d706993-75b9-4cae-8d0e-82513d23db99', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, '1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 12:20:11.467+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 12:20:11.467+00', '2026-09-23 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1a4eb36c-695a-43a0-8747-83b134a9360b', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 1, '9571e5d9-ca38-450d-bc82-d54f0eac5467', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 12:20:11.467+00', '2026-09-21 12:20:11.467+00', 0, NULL, NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00', false, true, 0, false, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('9461f51c-1517-4426-b86d-9a42831e82b9', '2989a917-5bd2-416a-b279-1c3a4471e729', 'd93df5e4-7e59-4889-8877-d7ca47c296ce', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-09-25 12:20:11.652719+00', '2026-09-25 12:20:11.652719+00');
INSERT INTO public.approvers VALUES ('b082ebbd-400d-4ef1-8e1c-c55aff46ce61', '2989a917-5bd2-416a-b279-1c3a4471e729', 'dfb16230-b1a1-49df-88e6-605f63075d96', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-09-25 12:20:11.658396+00', '2026-09-25 12:20:11.658396+00');
INSERT INTO public.approvers VALUES ('80967352-eb7f-4995-973d-d1e3df5f469f', '2989a917-5bd2-416a-b279-1c3a4471e729', '929b40b3-88c3-45bf-906a-ba6c9b316c12', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-09-25 12:20:11.663421+00', '2026-09-25 12:20:11.663421+00');
INSERT INTO public.approvers VALUES ('bdf2fece-068c-4b2c-814e-694f98122999', '2989a917-5bd2-416a-b279-1c3a4471e729', 'b40757a1-2176-4375-a69d-98a98908129b', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-09-25 12:20:11.667428+00', '2026-09-25 12:20:11.667428+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('af7ae260-b05f-4b83-88ca-59b3e254d7f2', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.786224+00', '2026-09-25 12:20:11.786224+00');
INSERT INTO public.artwork_versions VALUES ('5d24bbc2-c94d-4679-b61e-4a331fa8c35a', 'ae214d99-20f2-4409-a13f-74d784a6abd2', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.811432+00', '2026-09-25 12:20:11.811432+00');
INSERT INTO public.artwork_versions VALUES ('eafc760f-1e8a-4267-be55-215c5eb91a18', 'af596ea8-d767-4256-921c-4b0f945d75d3', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-25 12:20:11.832818+00', '2026-09-25 12:20:11.832818+00');
INSERT INTO public.artwork_versions VALUES ('6b9bd1f2-13d8-4161-8349-bb886a48e43c', 'af596ea8-d767-4256-921c-4b0f945d75d3', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:11.834279+00', '2026-09-25 12:20:11.834279+00');
INSERT INTO public.artwork_versions VALUES ('14c9f236-44a4-4505-ab9e-5c41de2c2ec9', '721c8d0f-4884-43d8-a833-a537678af7ad', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.854617+00', '2026-09-25 12:20:11.854617+00');
INSERT INTO public.artwork_versions VALUES ('ab8b7227-3d6a-4730-8a30-663e2f46bbf6', 'bdd669de-eb4d-4547-bab5-97425f7914f4', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:11.871546+00', '2026-09-25 12:20:11.871546+00');
INSERT INTO public.artwork_versions VALUES ('22a80e68-4a3a-419c-aacb-ab316a547467', '56707fec-8ef5-434e-9b29-3ec50add7fd3', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:11.893028+00', '2026-09-25 12:20:11.893028+00');
INSERT INTO public.artwork_versions VALUES ('08c7297f-395b-4124-8562-b82e224ce75e', '06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.914655+00', '2026-09-25 12:20:11.914655+00');
INSERT INTO public.artwork_versions VALUES ('798077b6-b711-430e-b4e6-80c2a4e2a3de', '1843d938-cde2-4f89-a557-bb75efe4a9d3', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:11.93407+00', '2026-09-25 12:20:11.93407+00');
INSERT INTO public.artwork_versions VALUES ('b0d79a63-f9f1-4176-8c7b-743e57d5595b', '066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.951895+00', '2026-09-25 12:20:11.951895+00');
INSERT INTO public.artwork_versions VALUES ('508b3ce0-7d7d-4b6c-b43a-cc00190c5d70', '5617cbc4-b194-45e7-a6c1-f6fbda750b22', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:11.970002+00', '2026-09-25 12:20:11.970002+00');
INSERT INTO public.artwork_versions VALUES ('b6fb716d-4b5c-4d2e-878a-4d20f9b5eb66', '8b13aa35-0b0b-4559-9499-3ccddb3c89f3', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:11.984921+00', '2026-09-25 12:20:11.984921+00');
INSERT INTO public.artwork_versions VALUES ('243def60-cdf9-49a7-a2ce-849a4806e711', 'fbea6d23-3392-43fd-a8e9-19838ac214e8', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:12.00035+00', '2026-09-25 12:20:12.00035+00');
INSERT INTO public.artwork_versions VALUES ('9cfbb8f4-2daf-4c5e-988f-c650b4622196', '60e12914-f69e-4561-864b-30c2ae587498', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.018152+00', '2026-09-25 12:20:12.018152+00');
INSERT INTO public.artwork_versions VALUES ('2925c9f1-bc60-4e84-8ac2-705fa979bd39', '30906015-95e2-4822-aaa7-86e299b4e037', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:12.03548+00', '2026-09-25 12:20:12.03548+00');
INSERT INTO public.artwork_versions VALUES ('ab222808-cb1f-4f57-a0af-408aa2bbcd45', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:12.051734+00', '2026-09-25 12:20:12.051734+00');
INSERT INTO public.artwork_versions VALUES ('9183c59c-de04-4410-9005-774094d70a4f', '680553fc-f05b-4cfd-ae91-46ca48d15cc5', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.06916+00', '2026-09-25 12:20:12.06916+00');
INSERT INTO public.artwork_versions VALUES ('293a2691-d2b3-469f-a094-bf9f61a92f0e', '2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:12.091055+00', '2026-09-25 12:20:12.091055+00');
INSERT INTO public.artwork_versions VALUES ('24c61e0a-6d9a-480c-8f41-bc9423dfff35', 'd1b2f343-f99b-4640-859b-976fd23860b2', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.108074+00', '2026-09-25 12:20:12.108074+00');
INSERT INTO public.artwork_versions VALUES ('c2651314-127d-4bbf-a8a0-bbbd3d66e6a8', '7374d653-4d84-4872-b455-b3df9dc15876', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 12:20:12.128238+00', '2026-09-25 12:20:12.128238+00');
INSERT INTO public.artwork_versions VALUES ('ffa1c545-f618-431f-8edb-75f8747d5257', '7374d653-4d84-4872-b455-b3df9dc15876', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 12:20:12.12984+00', '2026-09-25 12:20:12.12984+00');
INSERT INTO public.artwork_versions VALUES ('38ba4e47-1df7-4a4e-935d-a9e055524ce1', '7374d653-4d84-4872-b455-b3df9dc15876', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.131522+00', '2026-09-25 12:20:12.131522+00');
INSERT INTO public.artwork_versions VALUES ('06c09c4b-7fc4-4bf8-86ef-1595afd80869', 'e7c728df-8db0-4e4e-9976-bd87d6c69aa6', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 12:20:12.185988+00', '2026-09-25 12:20:12.185988+00');
INSERT INTO public.artwork_versions VALUES ('d409a719-4caa-4503-850c-b3e38f270aaf', '288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.206227+00', '2026-09-25 12:20:12.206227+00');
INSERT INTO public.artwork_versions VALUES ('efc3406d-1ec0-4d48-a6a1-614db72d20a0', 'd37e7b21-8fb9-40f6-9179-fc13ebe2aa96', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 12:20:12.230342+00', '2026-09-25 12:20:12.230342+00');


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

INSERT INTO public.contractors VALUES ('c319f4f6-3d48-49e0-b730-111355536d15', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-25 12:20:11.614844+00', '2026-09-25 12:20:11.614844+00');
INSERT INTO public.contractors VALUES ('3e8ddaf0-4c72-4773-b44d-5726e6278b97', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-25 12:20:11.616806+00', '2026-09-25 12:20:11.616806+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('d93df5e4-7e59-4889-8877-d7ca47c296ce', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-09-25 12:20:11.649404+00', '2026-09-25 12:20:11.649404+00');
INSERT INTO public.departments VALUES ('dfb16230-b1a1-49df-88e6-605f63075d96', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-09-25 12:20:11.656001+00', '2026-09-25 12:20:11.656001+00');
INSERT INTO public.departments VALUES ('929b40b3-88c3-45bf-906a-ba6c9b316c12', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Sales', 3, false, '{sponsor}', false, '2026-09-25 12:20:11.661324+00', '2026-09-25 12:20:11.661324+00');
INSERT INTO public.departments VALUES ('b40757a1-2176-4375-a69d-98a98908129b', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-09-25 12:20:11.665395+00', '2026-09-25 12:20:11.665395+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('7e304138-d194-4523-aa3a-e7cbaf92b76d', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00');
INSERT INTO public.documents VALUES ('54973ae6-7e3b-4508-9605-54accb7f3dbd', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00');
INSERT INTO public.documents VALUES ('1576fa96-f3ac-49d2-8189-510df2a08918', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00');
INSERT INTO public.documents VALUES ('3289439e-8aa4-4ab1-9cb1-c8308b101df5', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '7d314169-ecf0-4ce6-b5c7-e8e36596dc82', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00');
INSERT INTO public.documents VALUES ('1ad9738c-93c7-44f0-9643-1abb8ab2d7a1', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00');
INSERT INTO public.documents VALUES ('3f0905cb-9755-4409-a5e5-47860d440635', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00');
INSERT INTO public.documents VALUES ('244ae4cc-63d1-4551-9515-65e4b6518659', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00');
INSERT INTO public.documents VALUES ('0ecf5197-8632-4c26-b867-8303ba4dca89', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', '906effc9-8148-47f6-8fc0-ef88075cd461', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00');
INSERT INTO public.documents VALUES ('63121936-9553-4ea2-af93-98c51ae3e90e', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00');
INSERT INTO public.documents VALUES ('3ecf891c-7a09-4926-8b79-02f3bc82c8aa', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00');
INSERT INTO public.documents VALUES ('ad8c54ad-e6c5-45ee-803e-e9d8b3bc596c', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00');
INSERT INTO public.documents VALUES ('9ca4c25c-a31f-49b0-9357-c08eafa1d435', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'b79b4e80-958c-418a-a2f4-adaf3ed821b7', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00');
INSERT INTO public.documents VALUES ('d0a5adc4-82a3-4c8e-b8c4-bef42573c754', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00');
INSERT INTO public.documents VALUES ('8f8da22f-1b58-4b5d-a2b7-63c972a2413c', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00');
INSERT INTO public.documents VALUES ('96edb058-e3a2-4493-84fe-2a174e0b8f7c', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00');
INSERT INTO public.documents VALUES ('8ec80843-0b57-419d-90a4-223137101465', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'abb94472-b15d-4d77-a53b-db8abfa4d396', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00');
INSERT INTO public.documents VALUES ('6d256ba6-63ff-42af-8e0b-995ee26be8ae', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00');
INSERT INTO public.documents VALUES ('7443025f-c057-4901-be55-cf6ae7ccc988', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00');
INSERT INTO public.documents VALUES ('e05bf11a-b743-43b6-ab4c-18bded1405a0', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00');
INSERT INTO public.documents VALUES ('b8b36031-9f89-4590-ae25-65f1ca592f85', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_submission', 'ae00ba2b-8e21-43e9-9f15-d54546e529ca', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('d712347e-a941-4918-978c-01e64611f458', '7d266665-566a-4fdb-906e-7d52244d5a77', 'signage', 34, '2026-09-25 12:20:12.258154+00', '2026-09-25 12:20:12.259917+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('5b53582d-0e84-4698-bb73-8e34878f9e52', '7d266665-566a-4fdb-906e-7d52244d5a77', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-25 12:20:11.547469+00', '2026-09-25 12:20:11.547469+00');
INSERT INTO public.edition_deadlines VALUES ('354e416d-3673-4f04-93ed-1b09a8d3c560', '7d266665-566a-4fdb-906e-7d52244d5a77', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-25 12:20:11.549643+00', '2026-09-25 12:20:11.549643+00');
INSERT INTO public.edition_deadlines VALUES ('a9897566-4e38-4686-b273-1def4e0baabe', '7d266665-566a-4fdb-906e-7d52244d5a77', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-25 12:20:11.551067+00', '2026-09-25 12:20:11.551067+00');
INSERT INTO public.edition_deadlines VALUES ('e38ddeaf-b764-4678-bf2e-005590a4ddae', '7d266665-566a-4fdb-906e-7d52244d5a77', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-25 12:20:11.552151+00', '2026-09-25 12:20:11.552151+00');
INSERT INTO public.edition_deadlines VALUES ('5188c21d-4e54-4266-aa31-896595ca6107', '7d266665-566a-4fdb-906e-7d52244d5a77', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-25 12:20:11.553249+00', '2026-09-25 12:20:11.553249+00');
INSERT INTO public.edition_deadlines VALUES ('ac36d693-17ff-4994-aa29-2486692b5248', '7d266665-566a-4fdb-906e-7d52244d5a77', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-25 12:20:11.554451+00', '2026-09-25 12:20:11.554451+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('7d266665-566a-4fdb-906e-7d52244d5a77', '9ba55e0c-6f33-4232-9cf1-edac3b3e401e', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-25 12:20:11.54488+00', '2026-09-25 12:20:11.54488+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('9ba55e0c-6f33-4232-9cf1-edac3b3e401e', '2989a917-5bd2-416a-b279-1c3a4471e729', 'UK Construction Week', 'UKCW', '2026-09-25 12:20:11.518273+00', '2026-09-25 12:20:11.518273+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('c889d357-44cf-4a9e-8467-f520b3865556', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Exhibitor Co', 'A10', '2565af3b-6561-4711-9fee-628ed831b44c', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'c319f4f6-3d48-49e0-b730-111355536d15', '2026-09-25 12:20:11.745278+00', '2026-09-25 12:20:11.745278+00');
INSERT INTO public.exhibitors VALUES ('1f5fb2c8-aecc-4044-8431-57f16f2691b7', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SteelFrame Systems', 'A20', '2565af3b-6561-4711-9fee-628ed831b44c', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', '2026-09-25 12:20:11.748476+00', '2026-09-25 12:20:11.748476+00');
INSERT INTO public.exhibitors VALUES ('c65cab59-0264-4bc8-a4ca-24875d62032f', '7d266665-566a-4fdb-906e-7d52244d5a77', 'BrickWorks UK', 'A30', '2565af3b-6561-4711-9fee-628ed831b44c', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'c319f4f6-3d48-49e0-b730-111355536d15', '2026-09-25 12:20:11.751317+00', '2026-09-25 12:20:11.751317+00');
INSERT INTO public.exhibitors VALUES ('8e3c863c-604c-4560-af31-54b6ce60134c', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Timber Trade Ltd', 'B10', '2565af3b-6561-4711-9fee-628ed831b44c', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', '2026-09-25 12:20:11.754186+00', '2026-09-25 12:20:11.754186+00');
INSERT INTO public.exhibitors VALUES ('8f33b28f-f618-47d5-a9b0-0c683fe7145d', '7d266665-566a-4fdb-906e-7d52244d5a77', 'GlassTech', 'B20', '2565af3b-6561-4711-9fee-628ed831b44c', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'c319f4f6-3d48-49e0-b730-111355536d15', '2026-09-25 12:20:11.756436+00', '2026-09-25 12:20:11.756436+00');
INSERT INTO public.exhibitors VALUES ('2e8187b4-1074-4e08-b9c2-1771a59faad5', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Insulate Pro', 'B30', '2565af3b-6561-4711-9fee-628ed831b44c', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', '2026-09-25 12:20:11.758649+00', '2026-09-25 12:20:11.758649+00');
INSERT INTO public.exhibitors VALUES ('e4fba57d-3857-4e2f-848d-36e7306eee13', '7d266665-566a-4fdb-906e-7d52244d5a77', 'RoofRight', 'C10', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'c319f4f6-3d48-49e0-b730-111355536d15', '2026-09-25 12:20:11.761072+00', '2026-09-25 12:20:11.761072+00');
INSERT INTO public.exhibitors VALUES ('3a5940c1-f686-41d9-b449-2b366dc85876', '7d266665-566a-4fdb-906e-7d52244d5a77', 'PlantHire Direct', 'C20', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', '2026-09-25 12:20:11.763725+00', '2026-09-25 12:20:11.763725+00');
INSERT INTO public.exhibitors VALUES ('f0333c5b-cc22-44f3-b35b-88afb7f0e2f4', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SafetyFirst PPE', 'D10', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-25 12:20:11.766077+00', '2026-09-25 12:20:11.766077+00');
INSERT INTO public.exhibitors VALUES ('22378f26-c0e1-461c-bb12-70b54664f1f7', '7d266665-566a-4fdb-906e-7d52244d5a77', 'ToolMart Retail', 'D20', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-25 12:20:11.768654+00', '2026-09-25 12:20:11.768654+00');
INSERT INTO public.exhibitors VALUES ('2fb55a7f-8ffc-4832-8dd7-d79481535aab', '7d266665-566a-4fdb-906e-7d52244d5a77', 'EcoBuild Materials', 'D30', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-25 12:20:11.770926+00', '2026-09-25 12:20:11.770926+00');
INSERT INTO public.exhibitors VALUES ('f7ba88dc-bf00-491d-b31d-7a455bbf7f8e', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SiteWise Software', 'D40', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-25 12:20:11.772992+00', '2026-09-25 12:20:11.772992+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('8d63c559-c5ba-4234-a4ff-2fc5525c814f', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'venue', 'venue', '8e791b9c-1520-4e0b-8289-a3da7556e582', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.726649+00', '2026-09-25 12:20:11.726649+00');
INSERT INTO public.external_grants VALUES ('d2448051-ceee-4b28-9a09-f7b1b0028d4d', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.73112+00', '2026-09-25 12:20:11.73112+00');
INSERT INTO public.external_grants VALUES ('04a100d5-7e2c-4193-af77-98437d40862a', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.734901+00', '2026-09-25 12:20:11.734901+00');
INSERT INTO public.external_grants VALUES ('730d51a2-d1e3-404b-b0e1-fb8db34cb87b', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'supplier', 'supplier', 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.738997+00', '2026-09-25 12:20:11.738997+00');
INSERT INTO public.external_grants VALUES ('daaed05e-3610-4ab8-8153-f4f87d5aa40a', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'sponsor', 'sponsor', 'b02e6069-6caf-4993-bdb8-ece427078dd2', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.742603+00', '2026-09-25 12:20:11.742603+00');
INSERT INTO public.external_grants VALUES ('da064d90-ca70-4572-a304-cc4c41f3ee86', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'exhibitor', 'exhibitor', 'c889d357-44cf-4a9e-8467-f520b3865556', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-25 12:20:11.467+00', NULL, '2026-09-25 12:20:11.776447+00', '2026-09-25 12:20:11.776447+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('2565af3b-6561-4711-9fee-628ed831b44c', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-25 12:20:11.557079+00', '2026-09-25 12:20:11.557079+00');
INSERT INTO public.halls VALUES ('5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-25 12:20:11.560077+00', '2026-09-25 12:20:11.560077+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('b33e1c0c-0154-426c-8323-1a1d9e8723a8', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Hanging banner', 'hanging_banner', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'rigged', true, 0, '2026-09-25 12:20:11.696269+00', '2026-09-25 12:20:11.696269+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('f733b6ba-edd4-4895-b29f-348ae35f8017', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Foamex board', 'foamex_board', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'wall_mounted', false, 1, '2026-09-25 12:20:11.698583+00', '2026-09-25 12:20:11.698583+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('110448dd-9565-43fe-9c2f-2ee2ad903bdb', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Fabric graphic', 'fabric_graphic', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'shell_mounted', false, 2, '2026-09-25 12:20:11.700277+00', '2026-09-25 12:20:11.700277+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('6c11fdc4-148e-483e-b70d-d2355a68e146', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Floor vinyl', 'floor_vinyl', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'floor', false, 3, '2026-09-25 12:20:11.702197+00', '2026-09-25 12:20:11.702197+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3b0a85b8-baf2-4e9d-8c93-7397f9b34b5c', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Aisle sign', 'aisle_sign', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'rigged', true, 4, '2026-09-25 12:20:11.705623+00', '2026-09-25 12:20:11.705623+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3d220df1-c77e-42cf-8b5c-91d3f74b31c3', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Entrance feature', 'entrance_feature', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'freestanding', true, 5, '2026-09-25 12:20:11.70734+00', '2026-09-25 12:20:11.70734+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('9bcefee2-b050-4c7f-bef1-808f3b13be23', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Registration', 'registration', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'freestanding', false, 6, '2026-09-25 12:20:11.708788+00', '2026-09-25 12:20:11.708788+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('59774fc8-00d2-416e-ab8a-cff029767c0e', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Seminar theatre', 'seminar_theatre', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'freestanding', false, 7, '2026-09-25 12:20:11.710156+00', '2026-09-25 12:20:11.710156+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('939c2e40-40d0-4f05-952f-36c0f58aa295', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Feature area', 'feature_area', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'freestanding', false, 8, '2026-09-25 12:20:11.712003+00', '2026-09-25 12:20:11.712003+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('1f8179f6-82c2-47c6-a134-ccbb2a1b1b4a', '2989a917-5bd2-416a-b279-1c3a4471e729', 'External', 'external', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'freestanding', true, 9, '2026-09-25 12:20:11.713554+00', '2026-09-25 12:20:11.713554+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('980c1ee8-a169-4906-999e-463c86a864fc', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Digital screen', 'digital_screen', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 'digital', false, 10, '2026-09-25 12:20:11.715009+00', '2026-09-25 12:20:11.715009+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('ba3fbb5a-df6c-4aec-b523-f272b837aa27', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Branded lanyards', 'lanyard', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', NULL, false, 11, '2026-09-25 12:20:11.716368+00', '2026-09-25 12:20:11.716368+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('a25c9da9-608b-498d-bccf-8c167a363ed9', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Show bags', 'show_bag', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', NULL, false, 12, '2026-09-25 12:20:11.71788+00', '2026-09-25 12:20:11.71788+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('8ed5a9ed-180e-4cc9-9b27-e8db7c8481ca', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Registration branding', 'reg_branding', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', NULL, false, 13, '2026-09-25 12:20:11.719549+00', '2026-09-25 12:20:11.719549+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('f0149186-b999-4a10-893b-63c59e7910bd', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Other signage', 'other_signage', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', NULL, false, 14, '2026-09-25 12:20:11.721083+00', '2026-09-25 12:20:11.721083+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('b25c7647-4999-4ce9-8a95-74fd6173f9bb', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Other sponsorship item', 'other_sponsorship', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', NULL, false, 15, '2026-09-25 12:20:11.722548+00', '2026-09-25 12:20:11.722548+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('6462761e-6241-49de-912f-40fac5c16aa1', '2565af3b-6561-4711-9fee-628ed831b44c', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-25 12:20:11.56273+00', '2026-09-25 12:20:11.56273+00');
INSERT INTO public.locations VALUES ('b7099557-f8b8-4514-bbea-657518e3d585', '2565af3b-6561-4711-9fee-628ed831b44c', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-25 12:20:11.565289+00', '2026-09-25 12:20:11.565289+00');
INSERT INTO public.locations VALUES ('a1b18e92-fbce-4697-9d90-89da330890a1', '2565af3b-6561-4711-9fee-628ed831b44c', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-25 12:20:11.568927+00', '2026-09-25 12:20:11.568927+00');
INSERT INTO public.locations VALUES ('2079757f-3bf8-4162-9cd7-33d942c60d3e', '2565af3b-6561-4711-9fee-628ed831b44c', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-25 12:20:11.571723+00', '2026-09-25 12:20:11.571723+00');
INSERT INTO public.locations VALUES ('1122b874-6870-4530-90c6-dcb6eb62e669', '2565af3b-6561-4711-9fee-628ed831b44c', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-25 12:20:11.57401+00', '2026-09-25 12:20:11.57401+00');
INSERT INTO public.locations VALUES ('428bbbde-a5d7-4cc3-9da7-9a287e31fc2f', '2565af3b-6561-4711-9fee-628ed831b44c', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-25 12:20:11.575995+00', '2026-09-25 12:20:11.575995+00');
INSERT INTO public.locations VALUES ('579fb2a2-5298-44df-a3f6-82988d81fefa', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-25 12:20:11.57823+00', '2026-09-25 12:20:11.57823+00');
INSERT INTO public.locations VALUES ('8b7cada6-f73b-45fb-bd94-88e31dd3d741', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-25 12:20:11.580587+00', '2026-09-25 12:20:11.580587+00');
INSERT INTO public.locations VALUES ('be379542-424f-4877-adb2-78b3b4d2141a', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-25 12:20:11.583121+00', '2026-09-25 12:20:11.583121+00');
INSERT INTO public.locations VALUES ('5af0f7c6-ab15-4519-85f7-5083221f0505', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-25 12:20:11.585036+00', '2026-09-25 12:20:11.585036+00');
INSERT INTO public.locations VALUES ('2cde25af-11c5-483d-a7ef-31e2ac489d59', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-25 12:20:11.587251+00', '2026-09-25 12:20:11.587251+00');
INSERT INTO public.locations VALUES ('a5651999-4f2b-45bd-94db-88aab617c258', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-25 12:20:11.589182+00', '2026-09-25 12:20:11.589182+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('9664df17-d670-431b-8dc9-eb7687a25699', '00000000-0000-4000-8000-000000000001', '2989a917-5bd2-416a-b279-1c3a4471e729', 'admin', '2026-09-25 12:20:11.501788+00', '2026-09-25 12:20:11.501788+00', '{}');
INSERT INTO public.memberships VALUES ('5f281117-2f2d-43bd-9f61-af2453506c5d', '00000000-0000-4000-8000-000000000002', '2989a917-5bd2-416a-b279-1c3a4471e729', 'ops', '2026-09-25 12:20:11.505463+00', '2026-09-25 12:20:11.505463+00', '{}');
INSERT INTO public.memberships VALUES ('bb378ce1-ac72-4172-8728-83def96c35c8', '00000000-0000-4000-8000-000000000004', '2989a917-5bd2-416a-b279-1c3a4471e729', 'sales', '2026-09-25 12:20:11.510813+00', '2026-09-25 12:20:11.510813+00', '{}');
INSERT INTO public.memberships VALUES ('dca5e6f5-d100-4cdb-83b2-9124bfec4ecf', '00000000-0000-4000-8000-000000000005', '2989a917-5bd2-416a-b279-1c3a4471e729', 'event_director', '2026-09-25 12:20:11.514214+00', '2026-09-25 12:20:11.514214+00', '{}');
INSERT INTO public.memberships VALUES ('e7f0af47-92a4-46fc-b46b-c63c84343a51', '00000000-0000-4000-8000-000000000006', '2989a917-5bd2-416a-b279-1c3a4471e729', 'viewer', '2026-09-25 12:20:11.516656+00', '2026-09-25 12:20:11.516656+00', '{}');
INSERT INTO public.memberships VALUES ('c4442a8d-85cd-4d43-a7fd-7cdaf1ec97f0', '00000000-0000-4000-8000-000000000003', '2989a917-5bd2-416a-b279-1c3a4471e729', 'marketing', '2026-09-25 12:20:11.507419+00', '2026-09-25 12:20:12.378031+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('2989a917-5bd2-416a-b279-1c3a4471e729', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-25 12:20:11.496123+00', '2026-09-25 12:20:11.496123+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('aa515a37-6899-46d3-83aa-abcfe8cebe66', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '3d220df1-c77e-42cf-8b5c-91d3f74b31c3', '2565af3b-6561-4711-9fee-628ed831b44c', '6462761e-6241-49de-912f-40fac5c16aa1', 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', 'e25d33fd-a24a-46dd-be3d-ad6e0724ce73', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'af7ae260-b05f-4b83-88ca-59b3e254d7f2', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.782042+00', '2026-09-25 12:20:11.789443+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('ae214d99-20f2-4409-a13f-74d784a6abd2', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '9bcefee2-b050-4c7f-bef1-808f3b13be23', '2565af3b-6561-4711-9fee-628ed831b44c', 'b7099557-f8b8-4514-bbea-657518e3d585', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '5d24bbc2-c94d-4679-b61e-4a331fa8c35a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.808994+00', '2026-09-25 12:20:11.812682+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('af596ea8-d767-4256-921c-4b0f945d75d3', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', 'b33e1c0c-0154-426c-8323-1a1d9e8723a8', '2565af3b-6561-4711-9fee-628ed831b44c', 'a1b18e92-fbce-4697-9d90-89da330890a1', 'ops', '00000000-0000-4000-8000-000000000002', 'b02e6069-6caf-4993-bdb8-ece427078dd2', '5b608a73-c583-4054-9e4e-9d101160a104', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '6b9bd1f2-13d8-4161-8349-bb886a48e43c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.829615+00', '2026-09-25 12:20:11.835393+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('721c8d0f-4884-43d8-a833-a537678af7ad', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '59774fc8-00d2-416e-ab8a-cff029767c0e', '2565af3b-6561-4711-9fee-628ed831b44c', '2079757f-3bf8-4162-9cd7-33d942c60d3e', 'marketing', '00000000-0000-4000-8000-000000000003', '170efde9-43ec-4dd7-a75f-7d2d68f9ff35', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '14c9f236-44a4-4505-ab9e-5c41de2c2ec9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.852366+00', '2026-09-25 12:20:11.855881+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('bdd669de-eb4d-4547-bab5-97425f7914f4', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '6c11fdc4-148e-483e-b70d-d2355a68e146', '2565af3b-6561-4711-9fee-628ed831b44c', '1122b874-6870-4530-90c6-dcb6eb62e669', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'ab8b7227-3d6a-4730-8a30-663e2f46bbf6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.869306+00', '2026-09-25 12:20:11.872731+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('56707fec-8ef5-434e-9b29-3ec50add7fd3', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '939c2e40-40d0-4f05-952f-36c0f58aa295', '2565af3b-6561-4711-9fee-628ed831b44c', '428bbbde-a5d7-4cc3-9da7-9a287e31fc2f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '22a80e68-4a3a-419c-aacb-ab316a547467', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.88931+00', '2026-09-25 12:20:11.894895+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "cab7cad1-8dcb-4d88-83d1-8cd40ce46e68", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('06ccbb50-78c5-416b-a3e6-ba4a4a833ffb', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', 'b33e1c0c-0154-426c-8323-1a1d9e8723a8', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '579fb2a2-5298-44df-a3f6-82988d81fefa', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '08c7297f-395b-4124-8562-b82e224ce75e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.912697+00', '2026-09-25 12:20:11.916072+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1843d938-cde2-4f89-a557-bb75efe4a9d3', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '3b0a85b8-baf2-4e9d-8c93-7397f9b34b5c', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '8b7cada6-f73b-45fb-bd94-88e31dd3d741', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '798077b6-b711-430e-b4e6-80c2a4e2a3de', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.931824+00', '2026-09-25 12:20:11.935734+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('066d4e9c-ff9b-434f-b33d-3ee2512d0f6d', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '59774fc8-00d2-416e-ab8a-cff029767c0e', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'be379542-424f-4877-adb2-78b3b4d2141a', 'marketing', '00000000-0000-4000-8000-000000000003', '170efde9-43ec-4dd7-a75f-7d2d68f9ff35', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'b0d79a63-f9f1-4176-8c7b-743e57d5595b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.949791+00', '2026-09-25 12:20:11.953051+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('5617cbc4-b194-45e7-a6c1-f6fbda750b22', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '110448dd-9565-43fe-9c2f-2ee2ad903bdb', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '5af0f7c6-ab15-4519-85f7-5083221f0505', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '508b3ce0-7d7d-4b6c-b43a-cc00190c5d70', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.968075+00', '2026-09-25 12:20:11.97134+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8b13aa35-0b0b-4559-9499-3ccddb3c89f3', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '1f8179f6-82c2-47c6-a134-ccbb2a1b1b4a', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '2cde25af-11c5-483d-a7ef-31e2ac489d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'b6fb716d-4b5c-4d2e-878a-4d20f9b5eb66', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.983061+00', '2026-09-25 12:20:11.986146+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('fbea6d23-3392-43fd-a8e9-19838ac214e8', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'a5651999-4f2b-45bd-94db-88aab617c258', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '243def60-cdf9-49a7-a2ce-849a4806e711', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:11.998826+00', '2026-09-25 12:20:12.001302+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('60e12914-f69e-4561-864b-30c2ae587498', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '980c1ee8-a169-4906-999e-463c86a864fc', '2565af3b-6561-4711-9fee-628ed831b44c', 'b7099557-f8b8-4514-bbea-657518e3d585', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, 'c8060758-600f-4f50-bb12-fbf26a4e831c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '9cfbb8f4-2daf-4c5e-988f-c650b4622196', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.016103+00', '2026-09-25 12:20:12.01924+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "cab7cad1-8dcb-4d88-83d1-8cd40ce46e68", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('30906015-95e2-4822-aaa7-86e299b4e037', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '3b0a85b8-baf2-4e9d-8c93-7397f9b34b5c', '2565af3b-6561-4711-9fee-628ed831b44c', 'a1b18e92-fbce-4697-9d90-89da330890a1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '2925c9f1-bc60-4e84-8ac2-705fa979bd39', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.033722+00', '2026-09-25 12:20:12.036695+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '2565af3b-6561-4711-9fee-628ed831b44c', '1122b874-6870-4530-90c6-dcb6eb62e669', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'ab222808-cb1f-4f57-a0af-408aa2bbcd45', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.050082+00', '2026-09-25 12:20:12.052624+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('680553fc-f05b-4cfd-ae91-46ca48d15cc5', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '939c2e40-40d0-4f05-952f-36c0f58aa295', '2565af3b-6561-4711-9fee-628ed831b44c', '428bbbde-a5d7-4cc3-9da7-9a287e31fc2f', 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '9183c59c-de04-4410-9005-774094d70a4f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.067097+00', '2026-09-25 12:20:12.071209+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('2dca03ea-f648-47b8-b5e8-a61fd4a2c4cc', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', 'b33e1c0c-0154-426c-8323-1a1d9e8723a8', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '8b7cada6-f73b-45fb-bd94-88e31dd3d741', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '293a2691-d2b3-469f-a094-bf9f61a92f0e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.088767+00', '2026-09-25 12:20:12.092433+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d1b2f343-f99b-4640-859b-976fd23860b2', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '110448dd-9565-43fe-9c2f-2ee2ad903bdb', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '5af0f7c6-ab15-4519-85f7-5083221f0505', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '24c61e0a-6d9a-480c-8f41-bc9423dfff35', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.106487+00', '2026-09-25 12:20:12.111501+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7374d653-4d84-4872-b455-b3df9dc15876', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', 'b33e1c0c-0154-426c-8323-1a1d9e8723a8', '2565af3b-6561-4711-9fee-628ed831b44c', 'a1b18e92-fbce-4697-9d90-89da330890a1', 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', '5b608a73-c583-4054-9e4e-9d101160a104', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '38ba4e47-1df7-4a4e-935d-a9e055524ce1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.125796+00', '2026-09-25 12:20:12.132837+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('f840f390-852a-49ce-828d-613da271b95a', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'a5651999-4f2b-45bd-94db-88aab617c258', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.151745+00', '2026-09-25 12:20:12.151745+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('15e13ac5-5bd4-4fa5-aa97-018919836edf', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '2565af3b-6561-4711-9fee-628ed831b44c', 'b7099557-f8b8-4514-bbea-657518e3d585', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.155441+00', '2026-09-25 12:20:12.155441+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('eae5448b-fc77-4cba-bdd2-dec582a807b5', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '9bcefee2-b050-4c7f-bef1-808f3b13be23', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '579fb2a2-5298-44df-a3f6-82988d81fefa', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.160075+00', '2026-09-25 12:20:12.160075+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8ccc4ade-2169-412e-96c4-4920e0ab4eed', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '980c1ee8-a169-4906-999e-463c86a864fc', '2565af3b-6561-4711-9fee-628ed831b44c', '428bbbde-a5d7-4cc3-9da7-9a287e31fc2f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, 'c8060758-600f-4f50-bb12-fbf26a4e831c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.164941+00', '2026-09-25 12:20:12.164941+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "cab7cad1-8dcb-4d88-83d1-8cd40ce46e68", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('403fba66-a0d2-4966-bf24-954c79942a25', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '6c11fdc4-148e-483e-b70d-d2355a68e146', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'be379542-424f-4877-adb2-78b3b4d2141a', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.16991+00', '2026-09-25 12:20:12.16991+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0da680d1-27fa-4c64-86a7-1c02ddc123e6', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '59774fc8-00d2-416e-ab8a-cff029767c0e', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'be379542-424f-4877-adb2-78b3b4d2141a', 'marketing', '00000000-0000-4000-8000-000000000003', '170efde9-43ec-4dd7-a75f-7d2d68f9ff35', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.173616+00', '2026-09-25 12:20:12.173616+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('6db7eaee-be57-4020-aad1-b5a931a7aae2', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '1f8179f6-82c2-47c6-a134-ccbb2a1b1b4a', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '2cde25af-11c5-483d-a7ef-31e2ac489d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.176982+00', '2026-09-25 12:20:12.176982+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "cab7cad1-8dcb-4d88-83d1-8cd40ce46e68", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2217bb0f-e196-4318-9943-c37cf63212b9', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', '2cde25af-11c5-483d-a7ef-31e2ac489d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.180699+00', '2026-09-25 12:20:12.180699+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e7c728df-8db0-4e4e-9976-bd87d6c69aa6', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '2565af3b-6561-4711-9fee-628ed831b44c', '1122b874-6870-4530-90c6-dcb6eb62e669', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, '06c09c4b-7fc4-4bf8-86ef-1595afd80869', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.184341+00', '2026-09-25 12:20:12.187409+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('288ddd34-37f7-4e9b-a0f1-7f25e9a5334d', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '3d220df1-c77e-42cf-8b5c-91d3f74b31c3', '2565af3b-6561-4711-9fee-628ed831b44c', '6462761e-6241-49de-912f-40fac5c16aa1', 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', 'e25d33fd-a24a-46dd-be3d-ad6e0724ce73', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'd409a719-4caa-4503-850c-b3e38f270aaf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.203918+00', '2026-09-25 12:20:12.2076+00', 'signage', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', NULL, NULL, NULL, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('644dcab4-4736-46a8-9fc3-1dd9518defd1', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'f733b6ba-edd4-4895-b29f-348ae35f8017', '5d915b19-7c36-45bf-b9d2-74b8fffc3bde', 'a5651999-4f2b-45bd-94db-88aab617c258', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.224508+00', '2026-09-25 12:20:12.224508+00', 'signage', 'organiser', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d37e7b21-8fb9-40f6-9179-fc13ebe2aa96', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'ba3fbb5a-df6c-4aec-b523-f272b837aa27', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 'efc3406d-1ec0-4d48-a6a1-614db72d20a0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.227874+00', '2026-09-25 12:20:12.231667+00', 'sponsorship_item', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', '2026-12-09', NULL, 9000.00, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('1cf928f3-0a24-4297-856a-a7b9831e9129', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'a25c9da9-608b-498d-bccf-8c167a363ed9', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'b02e6069-6caf-4993-bdb8-ece427078dd2', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.248255+00', '2026-09-25 12:20:12.248255+00', 'sponsorship_item', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}, {"stepId": "97ca0927-9de4-4c00-a611-6d70b5cdae62", "userId": null}]', '2026-10-15', NULL, 12500.00, '2026-09-15 12:20:11.467+00');
INSERT INTO public.signage_items VALUES ('d198740f-7b5d-4a9b-96a0-d31abcf0c187', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '8ed5a9ed-180e-4cc9-9b27-e8db7c8481ca', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.252883+00', '2026-09-25 12:20:12.252883+00', 'sponsorship_item', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', '2027-01-23', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('27da3621-0ffe-4ab7-b58f-427fd64b6f7d', '7d266665-566a-4fdb-906e-7d52244d5a77', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', 'b25c7647-4999-4ce9-8a95-74fd6173f9bb', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 12:20:12.256476+00', '2026-09-25 12:20:12.256476+00', 'sponsorship_item', 'sponsor', '[{"stepId": "f826a881-f10d-48fc-a069-d7d88582e5f9", "userId": null}, {"stepId": "c4d8153b-a943-4cc0-8317-a568dcebab00", "userId": null}]', '2026-10-13', NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('c85fe5a9-e71d-463d-8450-cae70e6b2c16', '7d266665-566a-4fdb-906e-7d52244d5a77', 'fa81bdcf-d3bf-4ee2-8a1e-87a269bde396', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'b4d07d42-62a6-4196-b341-790a3d73ab4f', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-25 12:20:12.063156+00', '2026-09-25 12:20:12.063156+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('5b608a73-c583-4054-9e4e-9d101160a104', 'b02e6069-6caf-4993-bdb8-ece427078dd2', 'Logo on 6 hanging banners', 6, '2026-09-25 12:20:11.62157+00', '2026-09-25 12:20:11.62157+00');
INSERT INTO public.sponsor_entitlements VALUES ('e25d33fd-a24a-46dd-be3d-ad6e0724ce73', 'b02e6069-6caf-4993-bdb8-ece427078dd2', 'Entrance feature branding', 1, '2026-09-25 12:20:11.623759+00', '2026-09-25 12:20:11.623759+00');
INSERT INTO public.sponsor_entitlements VALUES ('07b478a2-6211-42bb-baf0-ff32124e9f76', '170efde9-43ec-4dd7-a75f-7d2d68f9ff35', 'Seminar theatre branding', 1, '2026-09-25 12:20:11.626816+00', '2026-09-25 12:20:11.626816+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('b02e6069-6caf-4993-bdb8-ece427078dd2', '7d266665-566a-4fdb-906e-7d52244d5a77', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-25 12:20:11.619067+00', '2026-09-25 12:20:11.619067+00');
INSERT INTO public.sponsors VALUES ('170efde9-43ec-4dd7-a75f-7d2d68f9ff35', '7d266665-566a-4fdb-906e-7d52244d5a77', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-25 12:20:11.625353+00', '2026-09-25 12:20:11.625353+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('7d314169-ecf0-4ce6-b5c7-e8e36596dc82', '7d266665-566a-4fdb-906e-7d52244d5a77', 'c889d357-44cf-4a9e-8467-f520b3865556', 'STD-BIRM27-A10', 'c319f4f6-3d48-49e0-b730-111355536d15', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 12:20:11.467+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.263648+00', '2026-09-25 12:20:12.263648+00');
INSERT INTO public.stand_submissions VALUES ('906effc9-8148-47f6-8fc0-ef88075cd461', '7d266665-566a-4fdb-906e-7d52244d5a77', '1f5fb2c8-aecc-4044-8431-57f16f2691b7', 'STD-BIRM27-A20', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 12:20:11.467+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.282435+00', '2026-09-25 12:20:12.282435+00');
INSERT INTO public.stand_submissions VALUES ('b79b4e80-958c-418a-a2f4-adaf3ed821b7', '7d266665-566a-4fdb-906e-7d52244d5a77', 'c65cab59-0264-4bc8-a4ca-24875d62032f', 'STD-BIRM27-A30', 'c319f4f6-3d48-49e0-b730-111355536d15', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-19 12:20:11.467+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.297472+00', '2026-09-25 12:20:12.297472+00');
INSERT INTO public.stand_submissions VALUES ('abb94472-b15d-4d77-a53b-db8abfa4d396', '7d266665-566a-4fdb-906e-7d52244d5a77', '8e3c863c-604c-4560-af31-54b6ce60134c', 'STD-BIRM27-B10', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-19 12:20:11.467+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.315723+00', '2026-09-25 12:20:12.315723+00');
INSERT INTO public.stand_submissions VALUES ('ae00ba2b-8e21-43e9-9f15-d54546e529ca', '7d266665-566a-4fdb-906e-7d52244d5a77', '8f33b28f-f618-47d5-a9b0-0c683fe7145d', 'STD-BIRM27-B20', 'c319f4f6-3d48-49e0-b730-111355536d15', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-19 12:20:11.467+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.345329+00', '2026-09-25 12:20:12.345329+00');
INSERT INTO public.stand_submissions VALUES ('dd218c3f-35e1-4495-a373-177f6afc500e', '7d266665-566a-4fdb-906e-7d52244d5a77', '2e8187b4-1074-4e08-b9c2-1771a59faad5', 'STD-BIRM27-B30', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.368648+00', '2026-09-25 12:20:12.368648+00');
INSERT INTO public.stand_submissions VALUES ('88102d4d-5b49-44ba-9f78-4655ee7fa06e', '7d266665-566a-4fdb-906e-7d52244d5a77', 'e4fba57d-3857-4e2f-848d-36e7306eee13', 'STD-BIRM27-C10', 'c319f4f6-3d48-49e0-b730-111355536d15', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.372246+00', '2026-09-25 12:20:12.372246+00');
INSERT INTO public.stand_submissions VALUES ('af48664a-26dc-4cb1-a017-077bfaa3928b', '7d266665-566a-4fdb-906e-7d52244d5a77', '3a5940c1-f686-41d9-b449-2b366dc85876', 'STD-BIRM27-C20', '3e8ddaf0-4c72-4773-b44d-5726e6278b97', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 12:20:12.375132+00', '2026-09-25 12:20:12.375132+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('b4d07d42-62a6-4196-b341-790a3d73ab4f', '5ca1007d-9f20-4515-ab8a-23b9ebc137a2');
INSERT INTO public.supplier_service_links VALUES ('b4d07d42-62a6-4196-b341-790a3d73ab4f', 'd27c3a2f-592b-4f6e-8970-b934a11c6f70');
INSERT INTO public.supplier_service_links VALUES ('8848f44f-6970-4681-8c5e-46b1bff7330a', '9ce0dfc3-2ee6-4a60-b036-0ff3671f1f37');
INSERT INTO public.supplier_service_links VALUES ('8848f44f-6970-4681-8c5e-46b1bff7330a', 'd27c3a2f-592b-4f6e-8970-b934a11c6f70');
INSERT INTO public.supplier_service_links VALUES ('8848f44f-6970-4681-8c5e-46b1bff7330a', '41bc5033-972d-4ff7-9d73-d7d3b701e300');
INSERT INTO public.supplier_service_links VALUES ('c8060758-600f-4f50-bb12-fbf26a4e831c', '469ea4e9-6acc-4594-8cc8-0025c5d3f242');
INSERT INTO public.supplier_service_links VALUES ('c8060758-600f-4f50-bb12-fbf26a4e831c', '41bc5033-972d-4ff7-9d73-d7d3b701e300');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('5ca1007d-9f20-4515-ab8a-23b9ebc137a2', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Signage print', 1, false, '2026-09-25 12:20:11.598632+00', '2026-09-25 12:20:11.598632+00');
INSERT INTO public.supplier_services VALUES ('469ea4e9-6acc-4594-8cc8-0025c5d3f242', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Digital screens & AV', 2, false, '2026-09-25 12:20:11.60043+00', '2026-09-25 12:20:11.60043+00');
INSERT INTO public.supplier_services VALUES ('9ce0dfc3-2ee6-4a60-b036-0ff3671f1f37', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Rigging', 3, false, '2026-09-25 12:20:11.60183+00', '2026-09-25 12:20:11.60183+00');
INSERT INTO public.supplier_services VALUES ('d27c3a2f-592b-4f6e-8970-b934a11c6f70', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Installation', 4, false, '2026-09-25 12:20:11.603155+00', '2026-09-25 12:20:11.603155+00');
INSERT INTO public.supplier_services VALUES ('41bc5033-972d-4ff7-9d73-d7d3b701e300', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Staffing', 5, false, '2026-09-25 12:20:11.604205+00', '2026-09-25 12:20:11.604205+00');
INSERT INTO public.supplier_services VALUES ('89bcc460-8399-4f9b-a8e7-4c559fa192e9', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Furniture', 6, false, '2026-09-25 12:20:11.605435+00', '2026-09-25 12:20:11.605435+00');
INSERT INTO public.supplier_services VALUES ('cc817a64-212e-463f-aca6-db895f4d1cdb', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Structural engineering', 7, false, '2026-09-25 12:20:11.606742+00', '2026-09-25 12:20:11.606742+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('b4d07d42-62a6-4196-b341-790a3d73ab4f', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-25 12:20:11.591124+00', '2026-09-25 12:20:11.591124+00');
INSERT INTO public.suppliers VALUES ('8848f44f-6970-4681-8c5e-46b1bff7330a', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-25 12:20:11.593351+00', '2026-09-25 12:20:11.593351+00');
INSERT INTO public.suppliers VALUES ('c8060758-600f-4f50-bb12-fbf26a4e831c', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-25 12:20:11.59614+00', '2026-09-25 12:20:11.59614+00');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('cdf69333-5c4d-4294-89b9-4f0f17c33599', '2989a917-5bd2-416a-b279-1c3a4471e729', '7d266665-566a-4fdb-906e-7d52244d5a77', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-02', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'aa515a37-6899-46d3-83aa-abcfe8cebe66', NULL, '2026-09-25 12:20:12.382254+00', '2026-09-25 12:20:12.382254+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.499584+00', '2026-09-25 12:20:11.499584+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.504244+00', '2026-09-25 12:20:11.504244+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.506632+00', '2026-09-25 12:20:11.506632+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.509005+00', '2026-09-25 12:20:11.509005+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.512666+00', '2026-09-25 12:20:11.512666+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-25 12:20:11.515626+00', '2026-09-25 12:20:11.515626+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.723768+00', '2026-09-25 12:20:11.723768+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.728452+00', '2026-09-25 12:20:11.728452+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.732491+00', '2026-09-25 12:20:11.732491+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.736357+00', '2026-09-25 12:20:11.736357+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.740514+00', '2026-09-25 12:20:11.740514+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-25 12:20:11.774377+00', '2026-09-25 12:20:11.774377+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('18d48f6e-1c9c-41aa-b516-1ff896a87bba', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-25 12:20:11.527313+00', '2026-09-25 12:20:11.527313+00');
INSERT INTO public.venue_rules VALUES ('97967539-a1ef-4cdf-be6e-e66668564ddd', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-25 12:20:11.53023+00', '2026-09-25 12:20:11.53023+00');
INSERT INTO public.venue_rules VALUES ('153c2811-8344-4bc3-acf7-e9dce63c3c47', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-25 12:20:11.533112+00', '2026-09-25 12:20:11.533112+00');
INSERT INTO public.venue_rules VALUES ('57593365-a896-4607-9ad2-56cfeba1375c', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-25 12:20:11.535544+00', '2026-09-25 12:20:11.535544+00');
INSERT INTO public.venue_rules VALUES ('aa175fac-48fc-48bb-b4ca-5f50964d01e3', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-25 12:20:11.538274+00', '2026-09-25 12:20:11.538274+00');
INSERT INTO public.venue_rules VALUES ('15f429b8-2fba-4117-a079-1cc2e8030d0b', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-25 12:20:11.540368+00', '2026-09-25 12:20:11.540368+00');
INSERT INTO public.venue_rules VALUES ('470a8ae2-746d-4706-adc7-b328222cc696', '8e791b9c-1520-4e0b-8289-a3da7556e582', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-25 12:20:11.542155+00', '2026-09-25 12:20:11.542155+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('8e791b9c-1520-4e0b-8289-a3da7556e582', '2989a917-5bd2-416a-b279-1c3a4471e729', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-25 12:20:11.520428+00', '2026-09-25 12:20:11.520428+00');
INSERT INTO public.venues VALUES ('ff296b70-f3ad-4758-8ccb-7b2bb38b0fe9', '2989a917-5bd2-416a-b279-1c3a4471e729', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-25 12:20:11.522587+00', '2026-09-25 12:20:11.522587+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('22aa3822-2d16-4052-b821-29e15a27fac0', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-25 12:20:11.635734+00', '2026-09-25 12:20:11.635734+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('06ec9fc0-3129-44b2-8035-ae374e3277e6', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-25 12:20:11.638751+00', '2026-09-25 12:20:11.638751+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('709ba005-3606-4a66-a380-7f223fee7d5a', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-25 12:20:11.640318+00', '2026-09-25 12:20:11.640318+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('90e5befe-d5e3-43ed-aa1b-7758c9d8cf99', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 12:20:11.641799+00', '2026-09-25 12:20:11.641799+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('f826a881-f10d-48fc-a069-d7d88582e5f9', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 12:20:11.631081+00', '2026-09-25 12:20:11.675611+00', '{organiser,sponsor}', false, 'd93df5e4-7e59-4889-8877-d7ca47c296ce');
INSERT INTO public.workflow_steps VALUES ('c4d8153b-a943-4cc0-8317-a568dcebab00', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 12:20:11.633141+00', '2026-09-25 12:20:11.677338+00', '{organiser,sponsor}', false, 'dfb16230-b1a1-49df-88e6-605f63075d96');
INSERT INTO public.workflow_steps VALUES ('97ca0927-9de4-4c00-a611-6d70b5cdae62', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-09-25 12:20:11.634559+00', '2026-09-25 12:20:11.678533+00', '{sponsor}', false, '929b40b3-88c3-45bf-906a-ba6c9b316c12');
INSERT INTO public.workflow_steps VALUES ('cab7cad1-8dcb-4d88-83d1-8cd40ce46e68', 'd00c38db-11ad-4fdc-9d7d-52418d49f04c', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-25 12:20:11.637222+00', '2026-09-25 12:20:11.679756+00', '{organiser,sponsor}', false, 'b40757a1-2176-4375-a69d-98a98908129b');
INSERT INTO public.workflow_steps VALUES ('590712a9-3448-49b6-b1d1-e70b6b352bf0', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-25 12:20:11.685586+00', '2026-09-25 12:20:11.685586+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('75e5eed1-62fc-4298-b02d-f20e753a5d7c', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-25 12:20:11.686901+00', '2026-09-25 12:20:11.686901+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a6e43de6-ab1f-4243-9b7d-2729c7554ed1', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-25 12:20:11.688296+00', '2026-09-25 12:20:11.688296+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('97ae07ac-6a49-4cf5-9e95-5c91c9eab672', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-25 12:20:11.68974+00', '2026-09-25 12:20:11.68974+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('1e3ff1de-f51b-440a-a91f-1a2e46a7cab7', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-25 12:20:11.691208+00', '2026-09-25 12:20:11.691208+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('9571e5d9-ca38-450d-bc82-d54f0eac5467', 'ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 12:20:11.693242+00', '2026-09-25 12:20:11.693242+00', '{}', false, NULL);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('d00c38db-11ad-4fdc-9d7d-52418d49f04c', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Signage default', 'signage', true, false, '2026-09-25 12:20:11.629393+00', '2026-09-25 12:20:11.629393+00');
INSERT INTO public.workflows VALUES ('ea5a0fe5-7464-43b3-88f1-5e5ec460d9cc', '2989a917-5bd2-416a-b279-1c3a4471e729', 'Stand default', 'stand', true, false, '2026-09-25 12:20:11.684209+00', '2026-09-25 12:20:11.684209+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 7, true);


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

\unrestrict LH9ae1e0mC1ql98Gb7jbywd8IZFXhlyDfR5piLtDDmslljSQ8t5SbKvBmH0BPWf

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
