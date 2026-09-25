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

\restrict s4UZ3rRoXlD0cFOPB7uKp6kHr8xUDR6OdaLzbRdZoph7hrckGCj5OsfiId7Aj7G

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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('89d4d848-68ff-4a5d-ac61-dca359a10024', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('ba7313c3-92d5-4027-9d36-765e6a894ced', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('d3aceebb-6dd7-4138-95e6-c4391ff38cb8', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('8a506d16-9495-4573-8224-d703e41f62dd', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('34ead9cc-0865-4b72-8a0e-c4a912024508', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('48a11adc-89aa-46cf-b4f6-f85675bda822', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9e86bd3f-c3a6-4333-85b1-34ac0d99d1f3', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1cc468a8-9b22-4db1-8cae-3eccb17111e1', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.642117+00', '2026-09-25 10:23:51.642117+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('5b046736-e46c-4cf8-ba54-97eea087c672', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('90c07491-27b1-4d96-a383-3ae65694986e', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('0994f8bc-edbd-47c4-80ce-5f57a177738b', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('7aa7d54b-63b3-4be6-b4c4-a3cd50e4b908', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d4f0d046-d226-480f-9830-d16daf057df2', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('fd7cc4a8-3860-4d8a-8747-a8a82c4acf95', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e09f1b3b-4463-464b-92e5-ea79b911eb22', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a000db0c-1d0e-4ba4-a815-8f32bf1470c2', 'signage_item', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.663215+00', '2026-09-25 10:23:51.663215+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6012aa58-004b-462d-9c1e-ef47c2c3e451', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 10:23:51.335+00', '2026-09-21 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('b9005b15-b99c-4635-b731-dc5c513a8c6e', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 10:23:51.335+00', '2026-09-16 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('09fc5821-36bb-42e5-8777-26ea905e522b', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 10:23:51.335+00', '2026-09-18 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('db40aeb6-f19a-41d1-99c8-81912aaf925a', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('39dffd0b-e148-4934-870c-ab432163e227', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('e85a9305-7a0a-448c-9db8-651a9022a210', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('db1769be-14f4-4ce5-93a8-c354b8c4ceef', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('de27c026-a330-4e7c-82b9-0e4ccc700ec3', 'signage_item', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.684129+00', '2026-09-25 10:23:51.684129+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('deeeccb3-1ead-4111-a914-f5c322107a5e', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('b0ae5bbf-aa3b-485d-86de-0cc68ee5d01d', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('828cfb8b-3547-46b9-809c-043c74ecc97f', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('cc4fd1c4-c97a-46f4-9870-17b45c2779f4', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0df65b82-cc38-4129-aaf6-5c8eb0239c97', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('82bb5353-84c8-46ca-812d-91a0556df9e8', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9a15e367-884d-47ae-adc6-de38bf52cd57', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('288c627d-7fba-4df4-9da7-cb8b23b94a37', 'signage_item', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.701795+00', '2026-09-25 10:23:51.701795+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a8cf2772-fdf3-47e5-a3b7-66a0cd7a64bd', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('5b2cd78a-a582-4e51-9a40-45e10411db77', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('076de0b3-86f3-4164-93f7-999c724c6894', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('1162f9c3-2e23-4ad5-8b5f-0a884cb8e816', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('08a4ce78-4517-4cfc-9f91-1ba9ef2c304a', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('e667b28f-079b-4b77-844a-2f4274c5b093', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9bab9004-a966-4b5a-8495-bb5992865c25', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('be6dc831-841f-4d10-8631-c784a44a5490', 'signage_item', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.716756+00', '2026-09-25 10:23:51.716756+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1cf9f7b8-50e7-4d5a-8dee-573879c24dad', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 10:23:51.335+00', '2026-09-16 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('8441b70e-347c-49c9-be65-9d131180df1e', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 10:23:51.335+00', '2026-09-16 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('a65a87cd-426d-4d74-9a35-1fcce593c89d', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('dadda497-c062-4222-adb0-d265d369c90f', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9c2f4214-cd02-4d07-8834-d297fae642ce', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 10:23:51.335+00', '2026-09-21 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('7e47773b-8aa2-4c0b-944c-9e7d4ae30754', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('7a1f85b2-f5f8-4f79-a435-c8a46a4520af', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ce586afe-02e9-46ac-9cc3-9af4acfe3c80', 'signage_item', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.733156+00', '2026-09-25 10:23:51.733156+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('33e82a47-80f9-401b-b1ec-bf3ed28ef867', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('8b1ee2c9-ccc5-4fdd-8be9-bce4eb83965a', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('e314d4b6-69d5-4e39-8657-a078313edac2', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('b632a53f-3a5e-4fd5-af57-0ddfcfea9744', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f95cff60-ebee-4de6-828a-6e44d0e4a455', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('1028cb64-af83-4fe0-aa4c-42e6685313da', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4452a6a9-01aa-4f92-994c-6b146699e161', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('40af5388-e61b-426c-b023-f571d2fc7674', 'signage_item', '218f4282-2335-4133-927a-e21af331d650', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.75068+00', '2026-09-25 10:23:51.75068+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('26615f31-7390-4442-8a5c-ec47d91edbf4', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('ac770269-7c52-44af-bd4b-e423ca00b812', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('cb9736c7-1a9f-43db-acd4-d039f52c88ef', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('ebd6c27a-21fa-41ef-94d3-a30a8e697230', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f1e29d9a-b220-42cf-b7e8-26f7d1a68032', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('2368fcd2-659b-4db9-8851-b352953c373e', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('133ad354-5ad6-437e-a9ed-2d87c63e0684', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('391a57e7-5631-431d-9599-405f22c59b42', 'signage_item', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.76865+00', '2026-09-25 10:23:51.76865+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6e84b00c-2a4f-43d4-817c-bd3a4b3f541e', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('a5471d09-2476-4b73-92da-0ede3cae0a91', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('9e9f36f4-b60b-49cb-a270-b243503c0f8a', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 10:23:51.335+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('7e60cfb7-f262-42e3-b283-3f7fe904e8ed', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('77e172bd-c4d6-4327-84fb-0b41c195c554', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('a2420655-22bb-4ff1-be6f-1b5726cf0112', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('b1e5d910-2237-4602-8c22-49b2d118954a', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3b12745f-65d8-428d-b7e9-10727bae4b10', 'signage_item', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.785632+00', '2026-09-25 10:23:51.785632+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('eecc6b22-15b6-497f-a99e-47a0fa62632e', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('d253181a-b7f8-43a1-87c1-0dc04b7dff52', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('8a5193b2-31e2-49a4-9bf9-10aca71032b5', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('41856c20-c22e-422c-941e-a450962f643c', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('2d01c8f3-5798-4a62-bcfd-c233da2456c7', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('08f21830-1cd7-4890-9065-9a03bbb9173f', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('58ca461d-4ecd-4aab-8f25-e80226418d38', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('001c9f79-9edf-422a-8e4c-3f5e7bac42b7', 'signage_item', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.801294+00', '2026-09-25 10:23:51.801294+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('26290a5e-6023-4200-8697-3d3b5e2b708b', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('0098635b-87df-4787-8187-77c4372cc784', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('07929754-fd93-49cf-9013-486a3f5b88c1', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('cc12b09c-67d2-4b19-a899-e84395f58a58', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0060eb3a-2599-4ba7-85ed-39b5ffb7558f', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('9aa5b8ea-e2a1-4cc9-9a50-7d62fa9c3020', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cea83f55-7820-4e4e-ac6e-c43a20216601', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0b9ead8c-322d-43d3-b2a2-0464ab826900', 'signage_item', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.814574+00', '2026-09-25 10:23:51.814574+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('decae087-3177-4af5-81f9-b1bab299c9bb', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('862e0569-2a3d-4c18-a4f9-cbc925b7b9ed', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('686b928b-b8d6-4fc1-83d8-5e39e6021675', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('cc2c0cc3-c505-4164-a1ca-95c135b62238', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('05fc88f3-9a7e-4ebd-bcd2-fd1bc4c01e08', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('e27def24-5a8d-4b7a-ae02-c14f69d96517', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d128159a-d697-4c4b-bb66-cdfb1ced3913', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('08cdbcf0-1a0f-41a7-bd50-02c72ede7aa6', 'signage_item', '336086b5-46d4-4242-b31d-ca80e6559811', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.829443+00', '2026-09-25 10:23:51.829443+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('178c169c-9e23-44f6-bc75-4341c4bab7ea', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('012a4d12-2c0a-4a7a-9860-d6e16d833b24', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('c163641f-2467-479a-8b3a-dbcde2f7900a', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('b031c106-7b6b-49c4-956c-0038a899cb18', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ee39682b-65c3-45ad-a11e-6b5d15621ce3', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('976a36e3-3ddf-439c-84e9-fdbfb232bdcc', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('b7c0d55d-eb8d-4ac9-9b09-74d79d95fde9', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cd961679-021d-4a30-8175-3c7dda518723', 'signage_item', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.8458+00', '2026-09-25 10:23:51.8458+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('081c4662-c7b2-4da8-bf07-391e5ff77db8', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('14054d3f-edd5-4ce6-9b89-bfba241c25f9', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('fdcaa3af-dbef-42cf-aef7-f53eb537ad63', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('65ac4f41-4f67-4f34-8f8b-9ba5f30aa26b', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('345bc1e9-0e97-43d4-a706-44dbb2cf9451', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('91c850ea-f172-435b-9a04-984165278c68', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f71addff-b08d-482a-82cf-fa672e39b866', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('b708e61e-4ce3-4a15-b18b-abc8bc028228', 'signage_item', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.859522+00', '2026-09-25 10:23:51.859522+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f41c1995-0434-476c-b8e1-4280c760b19d', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('8f5e3c4d-839b-4e77-b9f6-180563a89595', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('fa905fde-f09a-4243-9228-ff54515f021c', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('a07c08a0-d642-4f17-b551-87382d784262', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3c37994a-6c8c-43ee-aa0a-a2559412fb13', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('a2363156-0935-4827-b7d3-ade37d299b98', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('3f72de8d-1586-4c2b-9e2a-a9d6847b3087', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2e23bee9-e582-4ef8-996e-0a6a0e0fad59', 'signage_item', '4df60be6-7849-4315-8570-23cf54b806a1', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.874788+00', '2026-09-25 10:23:51.874788+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0d53e086-8c93-46d2-b0fb-9c92da24326f', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('59088062-d7d8-4c7d-aa5b-187288c65913', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('03a80a08-2524-4431-a4b8-20340fb7988a', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('2c48ebcf-a050-4b84-b7c3-e9ed1a8ccfb2', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d1a3e088-ed97-444e-a0c4-2b0b64e075b8', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('c7156c06-1198-4636-ba1a-bfbc69bdc442', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cd491035-c442-466e-9d0e-dd89c1217405', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('222c0521-f788-47c9-9f7a-42c0f972700f', 'signage_item', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.891712+00', '2026-09-25 10:23:51.891712+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0e14211d-21e2-4449-9f61-fc30006e35a1', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('afc68ce6-ab3e-4363-b72c-06f3b8c8c5f7', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('1cc841e1-60d9-4931-af65-ecf9d1513b45', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('885ce398-43e1-457e-a12e-e8c48790bb2b', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('8c9f4549-98eb-4ead-b9ba-666c286035b2', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('b3ff4e50-91c5-48bf-8c74-e62b0152a8bb', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('06244dbb-d15a-46c2-95cc-51bc090388d1', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2280041b-84b6-4070-b095-80cccbf5def5', 'signage_item', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.907674+00', '2026-09-25 10:23:51.907674+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a571dd9a-356f-4a58-842f-931b3f54f303', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('fb45b8d3-038a-4506-82f0-5b0c0f022a89', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('15f026ed-3a86-4677-a1d6-bf668d6ab415', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('6b0e7cde-e8f7-4832-90d9-3b232545c3b4', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('794be45b-3c0f-4101-adc0-815fbca404e4', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('76a1113b-55dd-4611-b15c-09d67b6b0c6a', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e618a2a7-4f96-4565-9257-e3dbddb24c59', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('de6512fc-b8b3-4a7f-9acc-bb6aca1cf18d', 'signage_item', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.923261+00', '2026-09-25 10:23:51.923261+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f3cb28ac-612e-4386-8f89-e0fc93692d0d', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('8287a448-bc47-417b-a1ef-4631ecae4581', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 10:23:51.335+00', '2026-09-27 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('d88b90a3-ed5c-4ead-92f2-b25225cf5dcb', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('84183fdd-e9f3-4fc2-9e10-1e7bedd98be0', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 10:23:51.335+00', '2026-09-27 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('80a0a5fa-3483-491e-bda6-99e06923e94d', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('9f3032bd-469d-49ca-9ec9-82d694cac4f4', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('c37efc17-cd6f-475a-862e-87bbe6087471', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9b520673-89a1-4c2e-9de9-102e9cfaefdf', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('f5208f71-2121-44e1-b1dc-fb38cc3a9e65', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('3dc59c7c-3876-43f8-9292-cccc2444e972', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('246f1411-34a4-4cb6-87cf-304546fc755f', 'signage_item', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.941219+00', '2026-09-25 10:23:51.941219+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('01b3777d-6a50-4907-89b3-38141e873355', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('9dbb6c5b-42cd-4739-88b8-8b52e34874b1', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('d24be077-36e2-4408-aed7-3cf97414c083', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('feebf100-253c-444b-be3d-60d0470d1dff', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a5cb34f9-3d17-43a3-9d6f-26fbe6ee002f', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('760697d3-b2c2-40d4-b9b7-cef199f06aaa', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e9517e77-bf65-40d3-b7ba-e64d6879ed79', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('07d658a9-a93f-45c2-9bc4-46908032d42d', 'signage_item', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:51.991274+00', '2026-09-25 10:23:51.991274+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ceb8e219-147d-4c59-a3f3-ca1dae11f2e0', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('d93b3320-8f31-484a-ad78-2bb25faae667', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('5f03a66c-038f-4a90-8e04-e562842d8837', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('5dc23a24-bf16-4840-ae25-1e3d6af66c1d', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 10:23:51.335+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-29 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a0d4d775-cb47-4a42-bfd1-8b570497ddd7', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('c7827ac2-c8b3-4dac-b326-199fef06e256', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 10:23:51.335+00', '2026-09-24 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('62377f48-893e-46a8-b078-98f48c9064de', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cfd3324e-0241-40cc-b83b-d4b20198b7e3', 'signage_item', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.009964+00', '2026-09-25 10:23:52.009964+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a82bc663-f115-4fa1-92b8-86de3b76020f', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, '03ce73de-e888-4460-abb9-ac76f5ceeb81', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 3, false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.approval_instances VALUES ('5eef5594-96e1-4b9b-aaad-5d7e01000db6', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, '8268feb0-4b67-49f4-a726-d51dc5701a27', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 3, false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.approval_instances VALUES ('1c4d4ada-708b-4b79-83cf-1ee58f2f268f', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, '1ce50733-5100-4589-aa13-991b38ebd302', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 10:23:51.335+00', '2026-09-25 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 5, false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.approval_instances VALUES ('288921a5-efba-4a4d-9bc0-80bb87312980', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, 'ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('7174468a-5338-4f0f-ae8e-a9d539551ebe', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, 'd913ef56-7dba-4b93-be80-bd8f40d25bf5', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 3, false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.approval_instances VALUES ('f17846f7-6c46-4ba5-abb3-e692aa28b80a', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, '6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a0b4283b-03e7-41ba-a82b-9723e7401065', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, '57ba3194-34ea-4d14-944a-71556633f47d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('b225f40f-9e8e-437b-ac02-e3aae68b0aab', 'signage_item', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, 'fb8909f4-f966-4b13-9645-e4d38854e31e', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.030912+00', '2026-09-25 10:23:52.030912+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('47b27bcb-0cd8-434e-af4e-ad9f8c6c4eee', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, '6f8572af-ba9b-451b-a90f-8db1de729545', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 10:23:51.335+00', '2026-09-22 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('4df6600c-9192-4951-8e54-6095021bc07b', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, 'd7a0aeae-41a2-4035-8f7f-7be811ca450f', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 10:23:51.335+00', '2026-09-28 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('812d0671-a2a7-41f5-8b9d-b4cd09d9a58a', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, '6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('e959ff67-2763-446a-a8c8-f0416f580657', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, '80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('18f8a651-45a8-490c-aa26-f5bc074b51a0', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, 'b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('63a2ff54-6cd9-4174-b42c-a9ab15cf47c7', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 1, '21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ac2c801f-3030-4066-98ad-24f3da844d99', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, '6f8572af-ba9b-451b-a90f-8db1de729545', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 10:23:51.335+00', '2026-09-22 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('ffa0de01-8194-4c1a-a1d1-61c66694968a', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, 'd7a0aeae-41a2-4035-8f7f-7be811ca450f', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('2f16dc97-9ccb-4228-8bfc-c04f7a92a565', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, '6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('7c96fe3b-a48b-409d-aed0-23ab3b0f7b48', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, '80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ffef08ce-ce3d-4479-ac07-5e24eab3b5a1', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, 'b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f929e843-4f83-4fd3-a41e-8d9424796aae', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 1, '21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('59e07bb6-ddc4-4e59-9c59-c88bf7dcb083', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, '6f8572af-ba9b-451b-a90f-8db1de729545', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-19 10:23:51.335+00', '2026-09-22 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('9f921a7a-c114-4a0e-8738-44265f0c039d', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, 'd7a0aeae-41a2-4035-8f7f-7be811ca450f', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('475ca779-3f76-4c61-b5df-5c4e77be2709', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, '6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('19d53c9c-c8e2-46d8-8c62-96440e405954', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, '80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('66ffbaf8-b5fb-4f90-b3bf-47e626ea511e', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, 'b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4fe9a33c-f4fb-432b-b791-cac739d3fbf5', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 1, '21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('651418e1-9be1-4440-a042-82c0bf26cfd6', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, '6f8572af-ba9b-451b-a90f-8db1de729545', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 10:23:51.335+00', '2026-09-22 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('fdacb879-6f80-4a47-928e-e943c54b125d', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, 'd7a0aeae-41a2-4035-8f7f-7be811ca450f', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('18471eb5-81f2-4033-b366-2fd1c1054988', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, '6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-26 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('dc56dcfb-4619-4030-83f1-232884c54e4d', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, '80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-28 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('88ef2766-cd0c-4fea-b719-76df4f16f189', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, 'b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('82a62651-ff2b-4b2e-95d4-722f7b7523bb', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 1, '21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 10:23:51.335+00', '2026-09-21 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2644e61f-f10b-4ce7-8365-c4f0bcbba65a', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, '6f8572af-ba9b-451b-a90f-8db1de729545', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 10:23:51.335+00', '2026-09-22 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('cf6e804f-5d95-4c8f-b03b-e9750a620019', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, 'd7a0aeae-41a2-4035-8f7f-7be811ca450f', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('6ba5fa71-00a1-43cf-af09-8a318bdc31cd', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, '6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-26 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('10730628-03f5-4623-b9fb-7e4aa5d21062', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, '80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-28 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f59d800b-507e-4f02-8fc8-c212c3301994', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, 'b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 10:23:51.335+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 10:23:51.335+00', '2026-09-23 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('5c131875-36b9-4f71-879f-b6ebd61937f5', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 1, '21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 10:23:51.335+00', '2026-09-21 10:23:51.335+00', 0, NULL, NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00', false, true, 0, false, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('5e236e8c-395c-410a-9a73-bceade3a5c67', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'e74dd437-2ba9-4103-b040-87c6e2789cc8', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-09-25 10:23:51.509052+00', '2026-09-25 10:23:51.509052+00');
INSERT INTO public.approvers VALUES ('c41b7f5d-f35f-4a1a-b751-8b220d11b8c9', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-09-25 10:23:51.513916+00', '2026-09-25 10:23:51.513916+00');
INSERT INTO public.approvers VALUES ('c2fdc067-d2e0-46b1-b97b-f0b6c9357d1f', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', '8e7f57d4-81da-4dce-95b2-0344d3684312', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-09-25 10:23:51.518073+00', '2026-09-25 10:23:51.518073+00');
INSERT INTO public.approvers VALUES ('0c2f46bb-bd64-4a15-a07d-c1bc976c22f6', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', '8265e7d0-444e-42bb-b248-91ed68a3230d', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-09-25 10:23:51.521793+00', '2026-09-25 10:23:51.521793+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('0e913e38-2d65-4da9-a128-aa50f6f25e37', 'e4267b0e-b33f-4704-b379-20f675e9b214', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.636436+00', '2026-09-25 10:23:51.636436+00');
INSERT INTO public.artwork_versions VALUES ('371c4e0c-732a-430f-8d01-548d149dd028', '2f464f9e-d06b-472d-8170-480a1fdf606d', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.65994+00', '2026-09-25 10:23:51.65994+00');
INSERT INTO public.artwork_versions VALUES ('2ceeb938-03a2-4a77-834c-8da663137d93', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-25 10:23:51.680243+00', '2026-09-25 10:23:51.680243+00');
INSERT INTO public.artwork_versions VALUES ('8e3d1702-18d0-4057-a1ce-7886a825ec85', 'c3dfbeca-4f29-44d7-aab3-6be9a553289a', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.681747+00', '2026-09-25 10:23:51.681747+00');
INSERT INTO public.artwork_versions VALUES ('55d662de-5fc4-4ff4-966b-08ced01f5d0b', 'eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.699456+00', '2026-09-25 10:23:51.699456+00');
INSERT INTO public.artwork_versions VALUES ('8c2a277f-7791-4253-8d51-20e8ab9bfa75', '7972af7b-bfee-4f23-9a16-f2bff785849e', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.714693+00', '2026-09-25 10:23:51.714693+00');
INSERT INTO public.artwork_versions VALUES ('7bdeccd0-ca54-409e-acbf-686ff85822a6', '7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.730795+00', '2026-09-25 10:23:51.730795+00');
INSERT INTO public.artwork_versions VALUES ('723f7fed-ea49-4107-bb80-c1c47e844a5a', '218f4282-2335-4133-927a-e21af331d650', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.748071+00', '2026-09-25 10:23:51.748071+00');
INSERT INTO public.artwork_versions VALUES ('c5f69965-aa15-44d6-b798-71f6012fde23', '5b9e8f52-fa46-4f81-82b0-17340f46785f', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.766703+00', '2026-09-25 10:23:51.766703+00');
INSERT INTO public.artwork_versions VALUES ('426fa4af-e984-4f8b-b433-2d1e286d3a8e', '92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.783462+00', '2026-09-25 10:23:51.783462+00');
INSERT INTO public.artwork_versions VALUES ('4d8f8535-e6e4-4291-82c0-48ea9f824973', '90212958-502b-4a6c-ab3d-eda3e6ecd033', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.799628+00', '2026-09-25 10:23:51.799628+00');
INSERT INTO public.artwork_versions VALUES ('b3b1c873-1cb4-44f1-8ea7-08d37934af7b', '11191c0f-7d11-4ac1-9a99-33fd99b84aba', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.812843+00', '2026-09-25 10:23:51.812843+00');
INSERT INTO public.artwork_versions VALUES ('82ce49e1-c056-47b0-9e18-60f0a423a0c9', '336086b5-46d4-4242-b31d-ca80e6559811', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.827507+00', '2026-09-25 10:23:51.827507+00');
INSERT INTO public.artwork_versions VALUES ('ef63fcf8-615f-41f2-aa13-b0ec281f228a', 'd4263267-6a1d-438c-a466-62f5bda6b06b', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.84358+00', '2026-09-25 10:23:51.84358+00');
INSERT INTO public.artwork_versions VALUES ('143f3053-24a1-43b9-ad84-bb3d1d101e52', 'a943a73f-52bf-4842-ab3b-6343f2d56f10', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.857374+00', '2026-09-25 10:23:51.857374+00');
INSERT INTO public.artwork_versions VALUES ('bed8a929-6b7e-47fe-bf45-c6908edc8ba7', '4df60be6-7849-4315-8570-23cf54b806a1', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.872396+00', '2026-09-25 10:23:51.872396+00');
INSERT INTO public.artwork_versions VALUES ('fcab693f-6eea-446f-8d8e-72e91b7a6bb8', 'ed202993-d7f6-4b3b-8834-b85ee5520549', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.88947+00', '2026-09-25 10:23:51.88947+00');
INSERT INTO public.artwork_versions VALUES ('57c9e41d-b705-468b-b1e0-f54d83b9dc37', '2634697d-a8bb-4760-8fb5-f7e964da1a62', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.905444+00', '2026-09-25 10:23:51.905444+00');
INSERT INTO public.artwork_versions VALUES ('8d8af556-1bda-4990-8d4c-d7d56f9f0187', 'bec9584e-16cb-4634-b8fc-99fbaaacc09c', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.921038+00', '2026-09-25 10:23:51.921038+00');
INSERT INTO public.artwork_versions VALUES ('2d4f0f68-cda3-444f-ae10-6c74bfb23803', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 10:23:51.937442+00', '2026-09-25 10:23:51.937442+00');
INSERT INTO public.artwork_versions VALUES ('eb6073b7-697e-475f-83b6-e334816ff1f6', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 10:23:51.938453+00', '2026-09-25 10:23:51.938453+00');
INSERT INTO public.artwork_versions VALUES ('41e28597-af87-4dce-8367-25cf82e35da9', '9dcf7b82-e44b-4624-97c1-263ad0d22076', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:51.939456+00', '2026-09-25 10:23:51.939456+00');
INSERT INTO public.artwork_versions VALUES ('8a2a8a60-a46c-4822-8d30-61708fe0b552', '1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 10:23:51.988541+00', '2026-09-25 10:23:51.988541+00');
INSERT INTO public.artwork_versions VALUES ('2d7c8a3d-56f3-40f4-a3f0-c8db4429a244', '32f77412-5111-4f44-a8c9-dd35778c8309', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:52.007617+00', '2026-09-25 10:23:52.007617+00');
INSERT INTO public.artwork_versions VALUES ('bb1a29cb-27ec-4285-a341-0a985bcb15cc', 'b15d3f8d-37a7-48c9-8380-6f427555d1c6', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 10:23:52.029168+00', '2026-09-25 10:23:52.029168+00');


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

INSERT INTO public.contractors VALUES ('f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-25 10:23:51.474292+00', '2026-09-25 10:23:51.474292+00');
INSERT INTO public.contractors VALUES ('ec357856-dc13-472e-92a3-651e5d1b39eb', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-25 10:23:51.476512+00', '2026-09-25 10:23:51.476512+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('e74dd437-2ba9-4103-b040-87c6e2789cc8', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-09-25 10:23:51.506498+00', '2026-09-25 10:23:51.506498+00');
INSERT INTO public.departments VALUES ('d08614f1-7c64-4ee6-bc68-b9aaae2e985c', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-09-25 10:23:51.51211+00', '2026-09-25 10:23:51.51211+00');
INSERT INTO public.departments VALUES ('8e7f57d4-81da-4dce-95b2-0344d3684312', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Sales', 3, false, '{sponsor}', false, '2026-09-25 10:23:51.516273+00', '2026-09-25 10:23:51.516273+00');
INSERT INTO public.departments VALUES ('8265e7d0-444e-42bb-b248-91ed68a3230d', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-09-25 10:23:51.520159+00', '2026-09-25 10:23:51.520159+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('25841f77-4506-41f1-aefc-079cd2e30bb7', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00');
INSERT INTO public.documents VALUES ('582b97fb-017d-4f40-a4d7-f6affd8b1021', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00');
INSERT INTO public.documents VALUES ('e3507879-377b-4e8a-b2c4-2d8dceaa1c45', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00');
INSERT INTO public.documents VALUES ('56a4326f-e20e-484f-b62e-4c44c284123e', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'def26cad-aca4-4bca-ab84-b6aa6236201b', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00');
INSERT INTO public.documents VALUES ('61537fcd-67f0-459e-866f-7a28e47c60a5', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00');
INSERT INTO public.documents VALUES ('688cc63e-832f-44d4-9fd5-8bce59c01c25', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00');
INSERT INTO public.documents VALUES ('79b63923-63e6-4939-b220-390bcba03255', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00');
INSERT INTO public.documents VALUES ('465f0315-ee2f-4264-92f9-f03bd4d34bd2', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f1bdb45-51e3-43a4-be20-a66b4d42af91', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00');
INSERT INTO public.documents VALUES ('87f1ce7a-b975-49d9-bc36-b2afbfcb7772', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00');
INSERT INTO public.documents VALUES ('4d4d1088-d288-441d-a752-fb20ae840514', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00');
INSERT INTO public.documents VALUES ('8567caf1-a5d5-46c1-b6b7-731bd4fec93d', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00');
INSERT INTO public.documents VALUES ('d7f750e2-7cf1-4cd1-baf4-88ff6326374d', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00');
INSERT INTO public.documents VALUES ('0c7eada5-7f08-48dd-9012-6e7380e832e6', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00');
INSERT INTO public.documents VALUES ('b53d19d1-c82c-4e0d-b060-f6521ad1b3ad', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00');
INSERT INTO public.documents VALUES ('6798a59e-96f4-4f7f-890d-fee241cc727a', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00');
INSERT INTO public.documents VALUES ('13667f37-142b-4602-941a-b0d2b01f8f45', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', '5c9f8bf9-523c-4977-91be-304cb56bca80', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00');
INSERT INTO public.documents VALUES ('4d23c479-a00d-4636-a1e9-1ac912c0f60e', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00');
INSERT INTO public.documents VALUES ('952751c0-8dd3-47c6-9c43-e2d028bf83c9', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00');
INSERT INTO public.documents VALUES ('ec335a12-91ea-43c2-a556-c084eb9acb12', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00');
INSERT INTO public.documents VALUES ('0f394503-face-4a50-9fc5-143760d88eb8', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_submission', 'be2a3806-2057-41da-addf-098f752b649d', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('fcb97887-0bf3-468b-9bad-7dc10b968836', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'signage', 32, '2026-09-25 10:23:52.041756+00', '2026-09-25 10:23:52.043434+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('0756ab8e-b210-4273-81bb-a666fbc92141', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-25 10:23:51.412099+00', '2026-09-25 10:23:51.412099+00');
INSERT INTO public.edition_deadlines VALUES ('b95191a0-cf16-410a-b49e-4a9c12f27081', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-25 10:23:51.413794+00', '2026-09-25 10:23:51.413794+00');
INSERT INTO public.edition_deadlines VALUES ('82d31756-261b-45e4-aa50-7c851c303233', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-25 10:23:51.415033+00', '2026-09-25 10:23:51.415033+00');
INSERT INTO public.edition_deadlines VALUES ('9172a033-a41b-4ef0-a59f-83896d1ced91', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-25 10:23:51.415924+00', '2026-09-25 10:23:51.415924+00');
INSERT INTO public.edition_deadlines VALUES ('6e215097-666a-49da-b746-11a80e6911ec', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-25 10:23:51.416965+00', '2026-09-25 10:23:51.416965+00');
INSERT INTO public.edition_deadlines VALUES ('85672b7e-e3c6-4ade-b82e-f187d71f8401', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-25 10:23:51.417994+00', '2026-09-25 10:23:51.417994+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', '5adc2ba5-d907-420d-969d-05585f6870ce', '96df2615-6790-4c34-9847-39ea937f34fc', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-25 10:23:51.409784+00', '2026-09-25 10:23:51.409784+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('5adc2ba5-d907-420d-969d-05585f6870ce', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'UK Construction Week', 'UKCW', '2026-09-25 10:23:51.386802+00', '2026-09-25 10:23:51.386802+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('bc39411d-2c61-48ba-92d8-8c2ae8cdfb78', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Exhibitor Co', 'A10', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', '2026-09-25 10:23:51.600383+00', '2026-09-25 10:23:51.600383+00');
INSERT INTO public.exhibitors VALUES ('5a59008d-32fb-4f5b-8e79-56fa2c4f1ca5', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SteelFrame Systems', 'A20', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'ec357856-dc13-472e-92a3-651e5d1b39eb', '2026-09-25 10:23:51.603301+00', '2026-09-25 10:23:51.603301+00');
INSERT INTO public.exhibitors VALUES ('e70751b5-2364-4b20-b05a-8207c5a1fe30', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'BrickWorks UK', 'A30', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', '2026-09-25 10:23:51.605795+00', '2026-09-25 10:23:51.605795+00');
INSERT INTO public.exhibitors VALUES ('25b004e7-be4e-423e-a052-24ead457d87e', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Timber Trade Ltd', 'B10', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'ec357856-dc13-472e-92a3-651e5d1b39eb', '2026-09-25 10:23:51.60803+00', '2026-09-25 10:23:51.60803+00');
INSERT INTO public.exhibitors VALUES ('aaef4b0d-ac5d-40d7-98a0-e25bb65a5875', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'GlassTech', 'B20', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', '2026-09-25 10:23:51.610587+00', '2026-09-25 10:23:51.610587+00');
INSERT INTO public.exhibitors VALUES ('f0fa7f1e-6226-46cb-97d6-dfde313099ec', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Insulate Pro', 'B30', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'ec357856-dc13-472e-92a3-651e5d1b39eb', '2026-09-25 10:23:51.612984+00', '2026-09-25 10:23:51.612984+00');
INSERT INTO public.exhibitors VALUES ('c603e2c1-4003-498d-a3af-4ca606039c68', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'RoofRight', 'C10', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', '2026-09-25 10:23:51.614873+00', '2026-09-25 10:23:51.614873+00');
INSERT INTO public.exhibitors VALUES ('23c1df58-9739-4494-994c-e31dd4035d36', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'PlantHire Direct', 'C20', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'ec357856-dc13-472e-92a3-651e5d1b39eb', '2026-09-25 10:23:51.616666+00', '2026-09-25 10:23:51.616666+00');
INSERT INTO public.exhibitors VALUES ('e6c6ed6f-4ec2-48a2-9066-e4c7c5d881a6', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SafetyFirst PPE', 'D10', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-25 10:23:51.618478+00', '2026-09-25 10:23:51.618478+00');
INSERT INTO public.exhibitors VALUES ('4bd5057c-4707-4646-9290-2080f4d315fd', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'ToolMart Retail', 'D20', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-25 10:23:51.620396+00', '2026-09-25 10:23:51.620396+00');
INSERT INTO public.exhibitors VALUES ('5f23bab4-3113-4148-9aed-84fbfe691b7c', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'EcoBuild Materials', 'D30', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-25 10:23:51.622126+00', '2026-09-25 10:23:51.622126+00');
INSERT INTO public.exhibitors VALUES ('4436f8ae-9480-4d10-9996-d4eec7bd13c2', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SiteWise Software', 'D40', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-25 10:23:51.624124+00', '2026-09-25 10:23:51.624124+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('4277aea0-a9d7-4d04-9c04-11735555bb2f', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'venue', 'venue', '96df2615-6790-4c34-9847-39ea937f34fc', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.581621+00', '2026-09-25 10:23:51.581621+00');
INSERT INTO public.external_grants VALUES ('144df319-263d-49b1-bba7-e6cdfc8ae4bd', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.585357+00', '2026-09-25 10:23:51.585357+00');
INSERT INTO public.external_grants VALUES ('2f125750-d61c-46cb-a9d9-ad62ff6adad2', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.58845+00', '2026-09-25 10:23:51.58845+00');
INSERT INTO public.external_grants VALUES ('d082b8b7-85b1-482b-89c7-626a4b70225c', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'supplier', 'supplier', '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.592095+00', '2026-09-25 10:23:51.592095+00');
INSERT INTO public.external_grants VALUES ('806dc4d5-92b9-4bb5-9445-06c0c5ad3d00', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'sponsor', 'sponsor', '459d825c-9bd2-4295-9871-cc93483c680d', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.595528+00', '2026-09-25 10:23:51.595528+00');
INSERT INTO public.external_grants VALUES ('f05b2d8c-d903-4435-a11b-9020dfddec6f', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'exhibitor', 'exhibitor', 'bc39411d-2c61-48ba-92d8-8c2ae8cdfb78', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-25 10:23:51.335+00', NULL, '2026-09-25 10:23:51.627915+00', '2026-09-25 10:23:51.627915+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-25 10:23:51.420164+00', '2026-09-25 10:23:51.420164+00');
INSERT INTO public.halls VALUES ('d73f39d3-154f-41a9-b875-6336d597ad9d', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-25 10:23:51.422486+00', '2026-09-25 10:23:51.422486+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('b6983b64-50a9-4d59-862c-c04aaabebe3f', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Hanging banner', 'hanging_banner', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'rigged', true, 0, '2026-09-25 10:23:51.550851+00', '2026-09-25 10:23:51.550851+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('68bb10c4-0163-49a5-877b-4b97ddff73c3', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Foamex board', 'foamex_board', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'wall_mounted', false, 1, '2026-09-25 10:23:51.553507+00', '2026-09-25 10:23:51.553507+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3d0f01e3-98b7-4490-a701-df9d54683a7b', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Fabric graphic', 'fabric_graphic', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'shell_mounted', false, 2, '2026-09-25 10:23:51.556022+00', '2026-09-25 10:23:51.556022+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('67d44eb3-bbda-4852-8504-b9e2c769f12b', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Floor vinyl', 'floor_vinyl', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'floor', false, 3, '2026-09-25 10:23:51.557835+00', '2026-09-25 10:23:51.557835+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('611b6811-3535-4ce3-9221-d778dc2ec2cc', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Aisle sign', 'aisle_sign', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'rigged', true, 4, '2026-09-25 10:23:51.561139+00', '2026-09-25 10:23:51.561139+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('5cc22893-414d-4c18-bfbe-784c8dc1e1ec', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Entrance feature', 'entrance_feature', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'freestanding', true, 5, '2026-09-25 10:23:51.563314+00', '2026-09-25 10:23:51.563314+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('dec6018d-bdad-4303-ae39-932c9d960a6c', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Registration', 'registration', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'freestanding', false, 6, '2026-09-25 10:23:51.564819+00', '2026-09-25 10:23:51.564819+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a794e75b-9e11-4058-a396-df52ff1c4a0a', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Seminar theatre', 'seminar_theatre', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'freestanding', false, 7, '2026-09-25 10:23:51.566277+00', '2026-09-25 10:23:51.566277+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('de590cd3-4838-44dd-ace8-bc6f45f99328', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Feature area', 'feature_area', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'freestanding', false, 8, '2026-09-25 10:23:51.567943+00', '2026-09-25 10:23:51.567943+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('ac308d9e-aebd-4605-a138-a5df9abf6223', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'External', 'external', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'freestanding', true, 9, '2026-09-25 10:23:51.569526+00', '2026-09-25 10:23:51.569526+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d3f1a940-b7fd-463c-81fc-7ad5549dcefc', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Digital screen', 'digital_screen', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'digital', false, 10, '2026-09-25 10:23:51.570919+00', '2026-09-25 10:23:51.570919+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('13293e0c-c13c-416a-bb47-3690d7c88a02', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Branded lanyards', 'lanyard', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', NULL, false, 11, '2026-09-25 10:23:51.572335+00', '2026-09-25 10:23:51.572335+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('6d81b396-bb16-499e-adbd-d9e5a7534aa4', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Show bags', 'show_bag', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', NULL, false, 12, '2026-09-25 10:23:51.57373+00', '2026-09-25 10:23:51.57373+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('c0f67214-9d84-4253-b15b-0fe724de5003', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Registration branding', 'reg_branding', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', NULL, false, 13, '2026-09-25 10:23:51.575324+00', '2026-09-25 10:23:51.575324+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('265fb136-588c-48bc-a933-47492ef3831c', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Other signage', 'other_signage', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', NULL, false, 14, '2026-09-25 10:23:51.576768+00', '2026-09-25 10:23:51.576768+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e6619069-0ec4-4190-bd3e-02480a6d9185', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Other sponsorship item', 'other_sponsorship', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', NULL, false, 15, '2026-09-25 10:23:51.577993+00', '2026-09-25 10:23:51.577993+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('461e5d43-e9ba-4514-8d72-f4d57a591b37', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-25 10:23:51.424694+00', '2026-09-25 10:23:51.424694+00');
INSERT INTO public.locations VALUES ('5b4c1c49-350f-4661-b77b-6c5bd4c5e610', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-25 10:23:51.427054+00', '2026-09-25 10:23:51.427054+00');
INSERT INTO public.locations VALUES ('d50e2818-de3d-4b49-a506-facc4ab4560f', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-25 10:23:51.429344+00', '2026-09-25 10:23:51.429344+00');
INSERT INTO public.locations VALUES ('0891ce52-6b2f-491e-8f64-7e5913a4912d', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-25 10:23:51.431574+00', '2026-09-25 10:23:51.431574+00');
INSERT INTO public.locations VALUES ('1ff1d70a-17e3-4e10-b56e-1316a20b7d59', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-25 10:23:51.433476+00', '2026-09-25 10:23:51.433476+00');
INSERT INTO public.locations VALUES ('23aedfa4-4f0c-4b05-acec-b49c23219b8e', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-25 10:23:51.435207+00', '2026-09-25 10:23:51.435207+00');
INSERT INTO public.locations VALUES ('2a5bc638-3c94-4a08-ac90-b55fdcd130f9', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-25 10:23:51.436964+00', '2026-09-25 10:23:51.436964+00');
INSERT INTO public.locations VALUES ('3496fca1-92b0-4748-8580-323afddf82b2', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-25 10:23:51.438583+00', '2026-09-25 10:23:51.438583+00');
INSERT INTO public.locations VALUES ('46cefa9c-4291-4107-b43d-127430487208', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-25 10:23:51.440421+00', '2026-09-25 10:23:51.440421+00');
INSERT INTO public.locations VALUES ('c9caa67f-0df2-4cbd-98bd-279e5d8fefef', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-25 10:23:51.442159+00', '2026-09-25 10:23:51.442159+00');
INSERT INTO public.locations VALUES ('d0a060b5-a624-479b-b9e1-486c311dc69b', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-25 10:23:51.444689+00', '2026-09-25 10:23:51.444689+00');
INSERT INTO public.locations VALUES ('f1fd6326-5dc7-4157-8147-0ff7dc054a63', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-25 10:23:51.446869+00', '2026-09-25 10:23:51.446869+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('49b969f3-f6a3-42e4-ac6f-684b80dd7a7c', '00000000-0000-4000-8000-000000000001', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'admin', '2026-09-25 10:23:51.373021+00', '2026-09-25 10:23:51.373021+00', '{}');
INSERT INTO public.memberships VALUES ('46cf457f-7eb8-40ad-a419-2917aa56c988', '00000000-0000-4000-8000-000000000002', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'ops', '2026-09-25 10:23:51.376377+00', '2026-09-25 10:23:51.376377+00', '{}');
INSERT INTO public.memberships VALUES ('ae2a96ec-737d-4a90-8125-b691d7e5d999', '00000000-0000-4000-8000-000000000004', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'sales', '2026-09-25 10:23:51.38125+00', '2026-09-25 10:23:51.38125+00', '{}');
INSERT INTO public.memberships VALUES ('2e9ee7a2-cc15-4be4-83a3-fd665776a824', '00000000-0000-4000-8000-000000000005', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'event_director', '2026-09-25 10:23:51.383655+00', '2026-09-25 10:23:51.383655+00', '{}');
INSERT INTO public.memberships VALUES ('1cb66e44-df89-47e3-84b5-35fdbaf56085', '00000000-0000-4000-8000-000000000006', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'viewer', '2026-09-25 10:23:51.385621+00', '2026-09-25 10:23:51.385621+00', '{}');
INSERT INTO public.memberships VALUES ('76f7d1ca-91e4-44a4-8999-d9cc0b46992f', '00000000-0000-4000-8000-000000000003', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'marketing', '2026-09-25 10:23:51.378677+00', '2026-09-25 10:23:52.117615+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-25 10:23:51.367286+00', '2026-09-25 10:23:51.367286+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('e4267b0e-b33f-4704-b379-20f675e9b214', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '5cc22893-414d-4c18-bfbe-784c8dc1e1ec', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '461e5d43-e9ba-4514-8d72-f4d57a591b37', 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', 'a1e90b7a-6837-46ee-9d96-fe89d6c67b13', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '0e913e38-2d65-4da9-a128-aa50f6f25e37', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.632794+00', '2026-09-25 10:23:51.638504+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('2f464f9e-d06b-472d-8170-480a1fdf606d', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', 'dec6018d-bdad-4303-ae39-932c9d960a6c', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '5b4c1c49-350f-4661-b77b-6c5bd4c5e610', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '371c4e0c-732a-430f-8d01-548d149dd028', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.657924+00', '2026-09-25 10:23:51.661145+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('c3dfbeca-4f29-44d7-aab3-6be9a553289a', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', 'b6983b64-50a9-4d59-862c-c04aaabebe3f', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'd50e2818-de3d-4b49-a506-facc4ab4560f', 'ops', '00000000-0000-4000-8000-000000000002', '459d825c-9bd2-4295-9871-cc93483c680d', '6a9e6809-4562-4e5b-b3aa-0214f95b89ca', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '8e3d1702-18d0-4057-a1ce-7886a825ec85', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.677026+00', '2026-09-25 10:23:51.682912+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('eedf67dd-3c2c-488a-bb1d-dcc0db85e9d8', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'a794e75b-9e11-4058-a396-df52ff1c4a0a', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '0891ce52-6b2f-491e-8f64-7e5913a4912d', 'marketing', '00000000-0000-4000-8000-000000000003', 'e9c91636-75e7-4b24-8eb8-e226634ee563', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '55d662de-5fc4-4ff4-966b-08ced01f5d0b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.697178+00', '2026-09-25 10:23:51.700733+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('7972af7b-bfee-4f23-9a16-f2bff785849e', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '67d44eb3-bbda-4852-8504-b9e2c769f12b', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '1ff1d70a-17e3-4e10-b56e-1316a20b7d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '8c2a277f-7791-4253-8d51-20e8ab9bfa75', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.712703+00', '2026-09-25 10:23:51.715796+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('7c0f3ee9-9adc-4be2-b774-f649262a1bc6', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', 'de590cd3-4838-44dd-ace8-bc6f45f99328', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '23aedfa4-4f0c-4b05-acec-b49c23219b8e', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '7bdeccd0-ca54-409e-acbf-686ff85822a6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.729023+00', '2026-09-25 10:23:51.731855+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "d913ef56-7dba-4b93-be80-bd8f40d25bf5", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('218f4282-2335-4133-927a-e21af331d650', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', 'b6983b64-50a9-4d59-862c-c04aaabebe3f', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '2a5bc638-3c94-4a08-ac90-b55fdcd130f9', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '723f7fed-ea49-4107-bb80-c1c47e844a5a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.746363+00', '2026-09-25 10:23:51.749204+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('5b9e8f52-fa46-4f81-82b0-17340f46785f', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '611b6811-3535-4ce3-9221-d778dc2ec2cc', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '3496fca1-92b0-4748-8580-323afddf82b2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'c5f69965-aa15-44d6-b798-71f6012fde23', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.765218+00', '2026-09-25 10:23:51.767599+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('92d232ac-6f0e-4a2b-82f1-3f8e6b6dc125', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'a794e75b-9e11-4058-a396-df52ff1c4a0a', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '46cefa9c-4291-4107-b43d-127430487208', 'marketing', '00000000-0000-4000-8000-000000000003', 'e9c91636-75e7-4b24-8eb8-e226634ee563', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '426fa4af-e984-4f8b-b433-2d1e286d3a8e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.78187+00', '2026-09-25 10:23:51.784423+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('90212958-502b-4a6c-ab3d-eda3e6ecd033', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '3d0f01e3-98b7-4490-a701-df9d54683a7b', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'c9caa67f-0df2-4cbd-98bd-279e5d8fefef', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '4d8f8535-e6e4-4291-82c0-48ea9f824973', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.79821+00', '2026-09-25 10:23:51.80043+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('11191c0f-7d11-4ac1-9a99-33fd99b84aba', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'ac308d9e-aebd-4605-a138-a5df9abf6223', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'd0a060b5-a624-479b-b9e1-486c311dc69b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'b3b1c873-1cb4-44f1-8ea7-08d37934af7b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.811437+00', '2026-09-25 10:23:51.813732+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('336086b5-46d4-4242-b31d-ca80e6559811', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'f1fd6326-5dc7-4157-8147-0ff7dc054a63', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '82ce49e1-c056-47b0-9e18-60f0a423a0c9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.825922+00', '2026-09-25 10:23:51.82842+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('d4263267-6a1d-438c-a466-62f5bda6b06b', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'd3f1a940-b7fd-463c-81fc-7ad5549dcefc', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '5b4c1c49-350f-4661-b77b-6c5bd4c5e610', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '8fd7781a-cfc0-45fa-a392-47e74d328636', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'ef63fcf8-615f-41f2-aa13-b0ec281f228a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.841305+00', '2026-09-25 10:23:51.84463+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "d913ef56-7dba-4b93-be80-bd8f40d25bf5", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('a943a73f-52bf-4842-ab3b-6343f2d56f10', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '611b6811-3535-4ce3-9221-d778dc2ec2cc', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'd50e2818-de3d-4b49-a506-facc4ab4560f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '143f3053-24a1-43b9-ad84-bb3d1d101e52', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.855906+00', '2026-09-25 10:23:51.858583+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('4df60be6-7849-4315-8570-23cf54b806a1', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '1ff1d70a-17e3-4e10-b56e-1316a20b7d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'bed8a929-6b7e-47fe-bf45-c6908edc8ba7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.870661+00', '2026-09-25 10:23:51.873787+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('ed202993-d7f6-4b3b-8834-b85ee5520549', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', 'de590cd3-4838-44dd-ace8-bc6f45f99328', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '23aedfa4-4f0c-4b05-acec-b49c23219b8e', 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'fcab693f-6eea-446f-8d8e-72e91b7a6bb8', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.887547+00', '2026-09-25 10:23:51.890751+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('2634697d-a8bb-4760-8fb5-f7e964da1a62', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', 'b6983b64-50a9-4d59-862c-c04aaabebe3f', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '3496fca1-92b0-4748-8580-323afddf82b2', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '57c9e41d-b705-468b-b1e0-f54d83b9dc37', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.903669+00', '2026-09-25 10:23:51.906549+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('bec9584e-16cb-4634-b8fc-99fbaaacc09c', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '3d0f01e3-98b7-4490-a701-df9d54683a7b', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'c9caa67f-0df2-4cbd-98bd-279e5d8fefef', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '8d8af556-1bda-4990-8d4c-d7d56f9f0187', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.919496+00', '2026-09-25 10:23:51.922218+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('9dcf7b82-e44b-4624-97c1-263ad0d22076', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', 'b6983b64-50a9-4d59-862c-c04aaabebe3f', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', 'd50e2818-de3d-4b49-a506-facc4ab4560f', 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', '6a9e6809-4562-4e5b-b3aa-0214f95b89ca', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '41e28597-af87-4dce-8367-25cf82e35da9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.935814+00', '2026-09-25 10:23:51.940143+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('422f4342-f723-4e3f-bdb9-3f887ae88430', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'f1fd6326-5dc7-4157-8147-0ff7dc054a63', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.955647+00', '2026-09-25 10:23:51.955647+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('01a64e39-2b9f-4168-9ffd-6db2746b3488', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '5b4c1c49-350f-4661-b77b-6c5bd4c5e610', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.959271+00', '2026-09-25 10:23:51.959271+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('89090fef-5d07-4dd9-bc27-ebb8e24635d8', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', 'dec6018d-bdad-4303-ae39-932c9d960a6c', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '2a5bc638-3c94-4a08-ac90-b55fdcd130f9', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.962457+00', '2026-09-25 10:23:51.962457+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('f674632f-b9cc-47a8-9823-b1e368137040', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'd3f1a940-b7fd-463c-81fc-7ad5549dcefc', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '23aedfa4-4f0c-4b05-acec-b49c23219b8e', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '8fd7781a-cfc0-45fa-a392-47e74d328636', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.966467+00', '2026-09-25 10:23:51.966467+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "d913ef56-7dba-4b93-be80-bd8f40d25bf5", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('d6803c56-8f4d-4e85-93b6-7cb69867e096', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '67d44eb3-bbda-4852-8504-b9e2c769f12b', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '46cefa9c-4291-4107-b43d-127430487208', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.970201+00', '2026-09-25 10:23:51.970201+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('0ade0b1f-5282-4a0e-b6ad-47df4f883d8f', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'a794e75b-9e11-4058-a396-df52ff1c4a0a', 'd73f39d3-154f-41a9-b875-6336d597ad9d', '46cefa9c-4291-4107-b43d-127430487208', 'marketing', '00000000-0000-4000-8000-000000000003', 'e9c91636-75e7-4b24-8eb8-e226634ee563', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.974935+00', '2026-09-25 10:23:51.974935+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('b035c06f-8038-4072-a191-2debea361203', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'ac308d9e-aebd-4605-a138-a5df9abf6223', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'd0a060b5-a624-479b-b9e1-486c311dc69b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.978526+00', '2026-09-25 10:23:51.978526+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "d913ef56-7dba-4b93-be80-bd8f40d25bf5", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('9d0385c1-d49d-4613-9766-ebc92dde6de8', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'd0a060b5-a624-479b-b9e1-486c311dc69b', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.982515+00', '2026-09-25 10:23:51.982515+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('1aed3dc8-fa7f-4496-a3f2-dd22d8b0cd26', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '1ff1d70a-17e3-4e10-b56e-1316a20b7d59', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '8a2a8a60-a46c-4822-8d30-61708fe0b552', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:51.986541+00', '2026-09-25 10:23:51.989924+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('32f77412-5111-4f44-a8c9-dd35778c8309', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '5cc22893-414d-4c18-bfbe-784c8dc1e1ec', '75e4c6a7-dfee-4a7d-8472-c2940a5e0f7e', '461e5d43-e9ba-4514-8d72-f4d57a591b37', 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', 'a1e90b7a-6837-46ee-9d96-fe89d6c67b13', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, '2d7c8a3d-56f3-40f4-a3f0-c8db4429a244', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:52.005459+00', '2026-09-25 10:23:52.008678+00', 'signage', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('9c6fe270-17f3-4064-82af-75e87165a412', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '68bb10c4-0163-49a5-877b-4b97ddff73c3', 'd73f39d3-154f-41a9-b875-6336d597ad9d', 'f1fd6326-5dc7-4157-8147-0ff7dc054a63', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:52.024442+00', '2026-09-25 10:23:52.024442+00', 'signage', 'organiser', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}]');
INSERT INTO public.signage_items VALUES ('b15d3f8d-37a7-48c9-8380-6f427555d1c6', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '13293e0c-c13c-416a-bb47-3690d7c88a02', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 'bb1a29cb-27ec-4285-a341-0a985bcb15cc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:52.027565+00', '2026-09-25 10:23:52.030154+00', 'sponsorship_item', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');
INSERT INTO public.signage_items VALUES ('b322e11f-ffff-4634-a954-6bdc82b22f98', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '6d81b396-bb16-499e-adbd-d9e5a7534aa4', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '459d825c-9bd2-4295-9871-cc93483c680d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 10:23:52.040397+00', '2026-09-25 10:23:52.040397+00', 'sponsorship_item', 'sponsor', '[{"stepId": "03ce73de-e888-4460-abb9-ac76f5ceeb81", "userId": null}, {"stepId": "8268feb0-4b67-49f4-a726-d51dc5701a27", "userId": null}, {"stepId": "1ce50733-5100-4589-aa13-991b38ebd302", "userId": null}]');


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('974cd6f6-14ee-4791-a54b-656f41872999', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', '4df60be6-7849-4315-8570-23cf54b806a1', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '769c81a5-3d8d-449c-9c27-f2e71a57c648', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-25 10:23:51.883568+00', '2026-09-25 10:23:51.883568+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('6a9e6809-4562-4e5b-b3aa-0214f95b89ca', '459d825c-9bd2-4295-9871-cc93483c680d', 'Logo on 6 hanging banners', 6, '2026-09-25 10:23:51.481563+00', '2026-09-25 10:23:51.481563+00');
INSERT INTO public.sponsor_entitlements VALUES ('a1e90b7a-6837-46ee-9d96-fe89d6c67b13', '459d825c-9bd2-4295-9871-cc93483c680d', 'Entrance feature branding', 1, '2026-09-25 10:23:51.483551+00', '2026-09-25 10:23:51.483551+00');
INSERT INTO public.sponsor_entitlements VALUES ('fb5837f9-edaa-4706-816f-953e364ba0f2', 'e9c91636-75e7-4b24-8eb8-e226634ee563', 'Seminar theatre branding', 1, '2026-09-25 10:23:51.487252+00', '2026-09-25 10:23:51.487252+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('459d825c-9bd2-4295-9871-cc93483c680d', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-25 10:23:51.478925+00', '2026-09-25 10:23:51.478925+00');
INSERT INTO public.sponsors VALUES ('e9c91636-75e7-4b24-8eb8-e226634ee563', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-25 10:23:51.485435+00', '2026-09-25 10:23:51.485435+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('def26cad-aca4-4bca-ab84-b6aa6236201b', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'bc39411d-2c61-48ba-92d8-8c2ae8cdfb78', 'STD-BIRM27-A10', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 10:23:51.335+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.046418+00', '2026-09-25 10:23:52.046418+00');
INSERT INTO public.stand_submissions VALUES ('9f1bdb45-51e3-43a4-be20-a66b4d42af91', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', '5a59008d-32fb-4f5b-8e79-56fa2c4f1ca5', 'STD-BIRM27-A20', 'ec357856-dc13-472e-92a3-651e5d1b39eb', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 10:23:51.335+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.060944+00', '2026-09-25 10:23:52.060944+00');
INSERT INTO public.stand_submissions VALUES ('9f9acc6d-81d7-4ae4-a8e0-ccb65c35daff', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'e70751b5-2364-4b20-b05a-8207c5a1fe30', 'STD-BIRM27-A30', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-19 10:23:51.335+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.072861+00', '2026-09-25 10:23:52.072861+00');
INSERT INTO public.stand_submissions VALUES ('5c9f8bf9-523c-4977-91be-304cb56bca80', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', '25b004e7-be4e-423e-a052-24ead457d87e', 'STD-BIRM27-B10', 'ec357856-dc13-472e-92a3-651e5d1b39eb', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-19 10:23:51.335+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.084912+00', '2026-09-25 10:23:52.084912+00');
INSERT INTO public.stand_submissions VALUES ('be2a3806-2057-41da-addf-098f752b649d', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'aaef4b0d-ac5d-40d7-98a0-e25bb65a5875', 'STD-BIRM27-B20', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-19 10:23:51.335+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.096961+00', '2026-09-25 10:23:52.096961+00');
INSERT INTO public.stand_submissions VALUES ('912705b8-87e3-432b-93cd-219bd23af60b', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'f0fa7f1e-6226-46cb-97d6-dfde313099ec', 'STD-BIRM27-B30', 'ec357856-dc13-472e-92a3-651e5d1b39eb', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.110596+00', '2026-09-25 10:23:52.110596+00');
INSERT INTO public.stand_submissions VALUES ('e1638824-d53f-4766-9dbe-19154599517c', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'c603e2c1-4003-498d-a3af-4ca606039c68', 'STD-BIRM27-C10', 'f27c1a2d-5206-4fcd-990a-cdb7cabb2f93', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.113233+00', '2026-09-25 10:23:52.113233+00');
INSERT INTO public.stand_submissions VALUES ('24acf142-ba5a-47c2-bdbb-eb6b3dc93df7', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', '23c1df58-9739-4494-994c-e31dd4035d36', 'STD-BIRM27-C20', 'ec357856-dc13-472e-92a3-651e5d1b39eb', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 10:23:52.115484+00', '2026-09-25 10:23:52.115484+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('769c81a5-3d8d-449c-9c27-f2e71a57c648', '95a7923f-cdc9-430e-91a1-cf56f43f8dd3');
INSERT INTO public.supplier_service_links VALUES ('769c81a5-3d8d-449c-9c27-f2e71a57c648', 'd8ece8fd-cf70-42c4-8822-5d587cc668fb');
INSERT INTO public.supplier_service_links VALUES ('8277b034-953a-45ad-82d8-6aab1f438e89', '4326e557-aefd-409e-9bc0-e68e98ab6128');
INSERT INTO public.supplier_service_links VALUES ('8277b034-953a-45ad-82d8-6aab1f438e89', 'd8ece8fd-cf70-42c4-8822-5d587cc668fb');
INSERT INTO public.supplier_service_links VALUES ('8277b034-953a-45ad-82d8-6aab1f438e89', '33004852-d4dd-451e-8e5b-2174c3b981fd');
INSERT INTO public.supplier_service_links VALUES ('8fd7781a-cfc0-45fa-a392-47e74d328636', '8ccae136-f2ac-4e95-bc41-f66e6431e2bd');
INSERT INTO public.supplier_service_links VALUES ('8fd7781a-cfc0-45fa-a392-47e74d328636', '33004852-d4dd-451e-8e5b-2174c3b981fd');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('95a7923f-cdc9-430e-91a1-cf56f43f8dd3', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Signage print', 1, false, '2026-09-25 10:23:51.456694+00', '2026-09-25 10:23:51.456694+00');
INSERT INTO public.supplier_services VALUES ('8ccae136-f2ac-4e95-bc41-f66e6431e2bd', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Digital screens & AV', 2, false, '2026-09-25 10:23:51.458392+00', '2026-09-25 10:23:51.458392+00');
INSERT INTO public.supplier_services VALUES ('4326e557-aefd-409e-9bc0-e68e98ab6128', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Rigging', 3, false, '2026-09-25 10:23:51.459654+00', '2026-09-25 10:23:51.459654+00');
INSERT INTO public.supplier_services VALUES ('d8ece8fd-cf70-42c4-8822-5d587cc668fb', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Installation', 4, false, '2026-09-25 10:23:51.461339+00', '2026-09-25 10:23:51.461339+00');
INSERT INTO public.supplier_services VALUES ('33004852-d4dd-451e-8e5b-2174c3b981fd', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Staffing', 5, false, '2026-09-25 10:23:51.462736+00', '2026-09-25 10:23:51.462736+00');
INSERT INTO public.supplier_services VALUES ('d047dcf0-20f5-40fc-bddc-1386f5c7ab45', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Furniture', 6, false, '2026-09-25 10:23:51.464156+00', '2026-09-25 10:23:51.464156+00');
INSERT INTO public.supplier_services VALUES ('ec2a9638-9b91-454b-b5d5-6870b87fedb4', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Structural engineering', 7, false, '2026-09-25 10:23:51.465515+00', '2026-09-25 10:23:51.465515+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('769c81a5-3d8d-449c-9c27-f2e71a57c648', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-25 10:23:51.448832+00', '2026-09-25 10:23:51.448832+00');
INSERT INTO public.suppliers VALUES ('8277b034-953a-45ad-82d8-6aab1f438e89', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-25 10:23:51.451721+00', '2026-09-25 10:23:51.451721+00');
INSERT INTO public.suppliers VALUES ('8fd7781a-cfc0-45fa-a392-47e74d328636', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-25 10:23:51.455258+00', '2026-09-25 10:23:51.455258+00');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('6d2c2464-fccd-4241-b330-7273e0b7a233', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'b8cc3d2e-2664-4aa5-9fcd-fdc32f7be3c5', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-02', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'e4267b0e-b33f-4704-b379-20f675e9b214', NULL, '2026-09-25 10:23:52.120701+00', '2026-09-25 10:23:52.120701+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.370863+00', '2026-09-25 10:23:51.370863+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.375354+00', '2026-09-25 10:23:51.375354+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.377671+00', '2026-09-25 10:23:51.377671+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.379933+00', '2026-09-25 10:23:51.379933+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.382636+00', '2026-09-25 10:23:51.382636+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-25 10:23:51.384842+00', '2026-09-25 10:23:51.384842+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.579236+00', '2026-09-25 10:23:51.579236+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.58325+00', '2026-09-25 10:23:51.58325+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.586605+00', '2026-09-25 10:23:51.586605+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.58987+00', '2026-09-25 10:23:51.58987+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.593529+00', '2026-09-25 10:23:51.593529+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-25 10:23:51.625561+00', '2026-09-25 10:23:51.625561+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('7201b92e-7af8-49f9-9ef7-194b221f352b', '96df2615-6790-4c34-9847-39ea937f34fc', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-25 10:23:51.395409+00', '2026-09-25 10:23:51.395409+00');
INSERT INTO public.venue_rules VALUES ('d23d9202-2018-4b4c-a4ca-4d44d2533904', '96df2615-6790-4c34-9847-39ea937f34fc', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-25 10:23:51.398193+00', '2026-09-25 10:23:51.398193+00');
INSERT INTO public.venue_rules VALUES ('706f45af-f446-4aa0-8fb9-75dec9180f8b', '96df2615-6790-4c34-9847-39ea937f34fc', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-25 10:23:51.400189+00', '2026-09-25 10:23:51.400189+00');
INSERT INTO public.venue_rules VALUES ('2730c638-e2f7-4ccd-83db-d7159087e9a7', '96df2615-6790-4c34-9847-39ea937f34fc', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-25 10:23:51.401994+00', '2026-09-25 10:23:51.401994+00');
INSERT INTO public.venue_rules VALUES ('3759277f-414b-496c-b51e-478b136ee1fe', '96df2615-6790-4c34-9847-39ea937f34fc', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-25 10:23:51.403956+00', '2026-09-25 10:23:51.403956+00');
INSERT INTO public.venue_rules VALUES ('3e86a462-a4c4-44d0-a697-2e294270e407', '96df2615-6790-4c34-9847-39ea937f34fc', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-25 10:23:51.405582+00', '2026-09-25 10:23:51.405582+00');
INSERT INTO public.venue_rules VALUES ('6142daaf-6779-44d6-b709-25bae7139846', '96df2615-6790-4c34-9847-39ea937f34fc', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-25 10:23:51.407241+00', '2026-09-25 10:23:51.407241+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('96df2615-6790-4c34-9847-39ea937f34fc', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-25 10:23:51.388786+00', '2026-09-25 10:23:51.388786+00');
INSERT INTO public.venues VALUES ('22857867-f655-473f-a4d7-5be0dc17d799', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-25 10:23:51.390743+00', '2026-09-25 10:23:51.390743+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('ac0cb016-1797-43b1-b6a9-6afaa4a2b3eb', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-25 10:23:51.495589+00', '2026-09-25 10:23:51.495589+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('6d8e1b66-5b7f-48a3-a1ac-612ace8c49c2', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-25 10:23:51.497723+00', '2026-09-25 10:23:51.497723+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('57ba3194-34ea-4d14-944a-71556633f47d', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-25 10:23:51.498864+00', '2026-09-25 10:23:51.498864+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('fb8909f4-f966-4b13-9645-e4d38854e31e', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 10:23:51.50019+00', '2026-09-25 10:23:51.50019+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('03ce73de-e888-4460-abb9-ac76f5ceeb81', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 10:23:51.49138+00', '2026-09-25 10:23:51.531282+00', '{organiser,sponsor}', false, 'e74dd437-2ba9-4103-b040-87c6e2789cc8');
INSERT INTO public.workflow_steps VALUES ('8268feb0-4b67-49f4-a726-d51dc5701a27', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 10:23:51.493203+00', '2026-09-25 10:23:51.532775+00', '{organiser,sponsor}', false, 'd08614f1-7c64-4ee6-bc68-b9aaae2e985c');
INSERT INTO public.workflow_steps VALUES ('1ce50733-5100-4589-aa13-991b38ebd302', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-09-25 10:23:51.494487+00', '2026-09-25 10:23:51.534248+00', '{sponsor}', false, '8e7f57d4-81da-4dce-95b2-0344d3684312');
INSERT INTO public.workflow_steps VALUES ('d913ef56-7dba-4b93-be80-bd8f40d25bf5', 'b52b5eaa-5423-4fbb-9ad0-ab2689434309', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-25 10:23:51.496559+00', '2026-09-25 10:23:51.535976+00', '{organiser,sponsor}', false, '8265e7d0-444e-42bb-b248-91ed68a3230d');
INSERT INTO public.workflow_steps VALUES ('6f8572af-ba9b-451b-a90f-8db1de729545', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-25 10:23:51.5425+00', '2026-09-25 10:23:51.5425+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('d7a0aeae-41a2-4035-8f7f-7be811ca450f', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-25 10:23:51.543654+00', '2026-09-25 10:23:51.543654+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('6569ecb0-c474-4abc-b9c8-28ad24e6285a', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-25 10:23:51.545029+00', '2026-09-25 10:23:51.545029+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('80b42d68-82fa-4c9d-b3ee-513352a2b13c', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-25 10:23:51.546046+00', '2026-09-25 10:23:51.546046+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('b37ec341-1e0e-4e18-b739-b3efe8ab0511', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-25 10:23:51.547097+00', '2026-09-25 10:23:51.547097+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('21959334-ebaf-4e2c-a7ce-2945c69c9ab5', 'e10c8634-8f15-4606-a4ff-cc25d8ad4029', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 10:23:51.548037+00', '2026-09-25 10:23:51.548037+00', '{}', false, NULL);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('b52b5eaa-5423-4fbb-9ad0-ab2689434309', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Signage default', 'signage', true, false, '2026-09-25 10:23:51.489655+00', '2026-09-25 10:23:51.489655+00');
INSERT INTO public.workflows VALUES ('e10c8634-8f15-4606-a4ff-cc25d8ad4029', 'df629c5a-a8c9-4030-8fd1-5c05025b4237', 'Stand default', 'stand', true, false, '2026-09-25 10:23:51.541064+00', '2026-09-25 10:23:51.541064+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 6, true);


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

\unrestrict s4UZ3rRoXlD0cFOPB7uKp6kHr8xUDR6OdaLzbRdZoph7hrckGCj5OsfiId7Aj7G

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
