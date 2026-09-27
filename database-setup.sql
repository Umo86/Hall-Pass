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

\restrict Bebinfg99VWpugzolhe1w55olikeSalIAcQBXZGMapTjC6MegI0Ou3RfcLjviNC

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
INSERT INTO drizzle.__drizzle_migrations VALUES (8, '78873a6d3c286cefc0d8ab94a074b6bad018471f9e0cfa617715f3977a630b92', 1790344364546);
INSERT INTO drizzle.__drizzle_migrations VALUES (9, '275eeed9383b78ea18fd0efcaaea9625a2947b25fc25c28cb2efa8d846ba83e3', 1790525113552);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('8b340ede-d9cb-4acf-bc07-f35b60aaa965', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('538e64bb-113b-4c22-8c6e-673e7354fc70', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('64daa47b-8836-46cf-8dac-cab9f6b108af', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('582af99c-7ac5-437d-9986-2f3333a638f4', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ede2292e-75f7-4bf0-8ceb-be014b2f5491', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('fab8e8ca-0783-4f52-807d-d0f3d9dd1aec', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('74862a1e-6fb7-4071-86f4-65bdbedd9cd4', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2145c113-8afc-48d4-a68e-1c426ab5add3', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.339528+00', '2026-09-27 16:08:10.339528+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('4e249592-056d-4ec3-a8bc-77c2e1651d9e', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('ea323233-aae7-42d5-9447-fd03640f6d74', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('47b84acd-b75d-4eb8-a183-0968c412a775', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('315b1d47-ab07-41fd-96e8-30cecb0339a5', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ceb4c40a-4fcc-4d4a-83fb-958cbb8f7a9c', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('48ee3f2c-1b21-45d0-9e54-dee53a5c712f', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1d3e0850-d4aa-4d5d-98b7-3e0426f996ef', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e7c89549-c456-4aaf-a714-c57bf034b2e0', 'signage_item', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.363472+00', '2026-09-27 16:08:10.363472+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3ee6b3ac-b2ce-405c-ba83-bd9b49b0a150', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 16:08:10.008+00', '2026-09-23 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('c23e01f1-96ab-4935-ac00-4ebe8f752faa', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-17 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 16:08:10.008+00', '2026-09-18 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('a287ba7c-4b62-4d5e-b838-d552c7cb24c2', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-17 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 16:08:10.008+00', '2026-09-20 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('e59f47d2-270f-415c-93a8-be8238300529', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('c6974440-7f3b-4830-bedd-b5cb21749652', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('f22fe530-bb68-48c6-83ea-cdbd9a0fe07d', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('99f87845-0b5f-4ff1-9066-0f94eab8071b', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c7c388a3-c55c-484d-b603-c28b56355c2c', 'signage_item', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.398809+00', '2026-09-27 16:08:10.398809+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('985f0811-198b-4d45-a2bc-122ca7af02ae', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('331dc627-940b-402e-a5b0-bd893ceecc0a', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('b9316c06-51d7-4548-86f1-4a1f22d73506', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('1d9a10bf-03e4-45bd-b6ff-89e54381864d', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a257ac07-de46-4ae8-93d5-e2b5e8a3c3a9', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('ec5ff31c-b4d8-48c4-ac1b-1bf05c5dd1c7', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('47a42b2c-2b92-4b64-9fb5-cbabba86988f', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('4f2c893a-d912-4988-a25f-b35e3d750ebd', 'signage_item', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.423678+00', '2026-09-27 16:08:10.423678+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('22311d0f-c81a-4527-9c6d-b627fb5454a0', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('2f14bbc0-a26f-448d-a834-66fdb8d70977', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('dc2d8632-2fe8-4094-8bd7-9ae3479f7917', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('4dbbefae-beda-4ebd-8726-68f449d8d889', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('c8a4ffef-62dd-43c1-b85b-c0b80ee338a3', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('c6078e31-c4fb-4968-99e7-bd1ccdfa69f8', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('cd952d2d-301b-48ff-858e-0ab8b1a896b7', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1c677eeb-c166-4d3e-a19b-e62d57d9e145', 'signage_item', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.441809+00', '2026-09-27 16:08:10.441809+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e553a8e5-2f0a-4770-b328-7c7a58836646', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-17 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 16:08:10.008+00', '2026-09-18 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('abaedeca-0828-4120-ae95-6e80cb805b23', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-17 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 16:08:10.008+00', '2026-09-18 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('d0552e5a-f909-4629-9ae7-dc448c1d612a', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('f56221db-bbf6-4409-bd24-392ff2c6257e', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d9b92d66-2117-41b9-a19c-79160416be68', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', '2026-09-23 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('3dca09ad-4799-429a-857e-1061e2e6a0a0', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e2ffc71a-f508-4c98-9627-de139c8e7a0e', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ab6c85f6-3c3d-458d-a94a-4aacce9c195d', 'signage_item', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.466119+00', '2026-09-27 16:08:10.466119+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8e2b22bb-b2a7-4339-8998-f98ec169bda3', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('742d828a-2d53-4549-a652-27150fc3080f', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('567822db-b11b-4471-a368-6f6abe2b5395', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('b1c553f2-d5c4-4630-ba19-ace8faa2d33a', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('84b2e634-2887-4e3d-86c2-ed2c77600e79', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('984ec608-a103-490f-8954-dc357d12db96', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e01f43f6-02fe-4a45-ae32-3a324f803f6b', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8395e8fb-549e-437b-a55b-4ffa92ac06b0', 'signage_item', '33d67d80-7910-456a-bc25-a418740a75d8', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.483349+00', '2026-09-27 16:08:10.483349+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7a9d7c3b-4763-4339-ad89-fe4bb7e2c742', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('0fb0d390-6d96-4dd8-a008-09a8169b8f2d', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('f9388c39-7637-4e6d-bf40-38430b7f402f', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('8f4d2ed2-7a4b-4d75-a0e7-9241e3c9ea93', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('57ae632c-8f22-4627-996f-910003fdd368', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('7b07e341-45c6-49d8-b4ae-945f0ecdb6c3', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f43f3e70-08a9-4d24-b161-1c230b2c74e6', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3e761350-773b-4b31-b8a7-18cd1f165f23', 'signage_item', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.509594+00', '2026-09-27 16:08:10.509594+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8ab775e4-2c57-4c1a-b25f-963d38553f0d', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('ceb9d4e8-6f48-4f5a-83ed-61f45caed281', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('e47edbcc-f162-4c04-8503-22a9790e058a', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-24 16:08:10.008+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('703ca709-9583-4f4b-81bf-1d28125cd4e8', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('4ed79780-080f-4054-af4f-16f15faadd83', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('1e551590-e3da-488e-9756-be4c636812f5', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c9905e2a-7400-4994-a2ce-416bd1ae3838', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('9f7df718-92e9-4979-9bcb-2eb9955675df', 'signage_item', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.531298+00', '2026-09-27 16:08:10.531298+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('97ba9867-6396-4fd9-a9ef-9ee9aa485e5d', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('94a4d673-ba47-4dcc-bd26-b8fd4ef18cf0', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('203d7f12-5ce1-47aa-8e01-744e13666f79', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('4531c40a-502c-4523-8288-aa4916dab377', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('7b6d526f-ae3a-4e7f-bf49-84417b854213', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('6cbfd882-763a-44ca-9bb4-b1c8c987bf7f', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f672b880-8f81-402a-a16e-7bab4cc1720d', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('18d7a2e9-edaf-4ddf-9e0a-22c57e766cce', 'signage_item', '7361f7df-60df-4798-95f2-4cea85b61053', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.552888+00', '2026-09-27 16:08:10.552888+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c109be1f-5ec0-4d7e-b7b4-dd68f5a89a32', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('8a25d0fd-99e7-4658-b192-5c98c323df26', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('a33d5069-6bc2-4608-91ba-ed1ea1973707', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('6ff8710d-1893-4c9d-8793-6ede4b3d6d1b', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d802f3c6-0ee6-4814-95c7-edffdda14fbf', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('0f6a799b-c795-4424-a83d-13b7618e86d3', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4c3ff283-0dcb-49d6-b1c3-80a682047306', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('257a113d-de36-40c5-ab59-2843e8c8ea44', 'signage_item', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.569557+00', '2026-09-27 16:08:10.569557+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d5046c47-6ea4-4eb7-8c51-e06adc4f492d', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('d572aa93-d0f2-46df-bb6a-9a5995816eee', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('9343227b-95c6-48ff-b2b6-c8e8418f0293', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('87b4413b-1dc2-46db-8d8d-a825e07fc63d', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('254aa825-4b4f-45a6-af81-d98516180b3c', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('0662d1ad-7586-4da0-b624-f362e22cc462', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('5954deb3-9d84-464d-bb1e-58e5d954bb72', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('05b09db6-afe2-496f-8238-dd42df75161a', 'signage_item', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.600223+00', '2026-09-27 16:08:10.600223+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0640ac7d-e5a6-4c5f-a9b2-19ecd84f4616', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('61b461eb-7843-450e-b46c-9261989b1da0', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('dd8884c4-23fc-4610-a24b-ee234b194e82', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('5f88f322-a303-4489-b616-c8c40ba01f64', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('708f0a62-ac4c-4bd7-ae6e-f975066aea7c', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('0fff4a78-b1c4-4a67-a03e-875099449e0b', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9df90c5a-7143-4ee5-8e17-4f58edea8ab9', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f03a59a1-558b-4166-935d-082f30154088', 'signage_item', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.624667+00', '2026-09-27 16:08:10.624667+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('46a51cbd-a603-48ab-a7df-2d5e57506d36', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('3a39ab69-4505-4764-af3f-a88f944c2cdb', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('d2d971b1-27dc-4c35-9c45-df5debaf3646', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('2f2bfed3-6bbb-48ee-832b-4fb076cbc64b', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ce00a691-1625-4df3-afa3-728919b71c64', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('9cf24051-0960-4583-8fa2-6d7392aa3735', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c5fcd22c-505f-45e5-8bef-c764dc167388', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('564587b3-010b-44a6-939e-fc98649f3efc', 'signage_item', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.641993+00', '2026-09-27 16:08:10.641993+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('684f5fdc-abc1-4782-b0d6-d156e59f1b78', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('9e18c60d-b3d3-45ae-9562-144e64ca9933', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('9363e895-624b-4348-a719-36f2c9b3b94d', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('9d24a3f7-5370-4032-a143-2407caa8629f', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('5934eacd-248a-4677-9ab9-8df7070e816c', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('a6a5538c-0f1b-4c88-a18a-34d207c47114', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('498f8359-baf0-49f7-a83e-fb60ad35b4b1', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f4cc4e19-4728-4081-82f7-27d0699789c0', 'signage_item', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.658468+00', '2026-09-27 16:08:10.658468+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('86a66da6-5833-4a81-87e0-864371c445ac', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('b6052bee-c7b0-4874-9cdd-fba6670a3a7c', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('d7caa294-d702-4973-9b45-c85f4f285448', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('cb81ef54-1e35-4c73-9e76-9c56f964820e', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('114b9df9-f253-4877-8bff-f83cec7160b3', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('92bae598-2a62-4411-9780-7f722d41fe00', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('63fdc3cf-afab-4b6b-9d3f-d8b1707d1fd7', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a8fe47fb-b274-4ecd-b5ce-1db54923a964', 'signage_item', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.678301+00', '2026-09-27 16:08:10.678301+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('5d55d205-26ca-4b32-959a-f6b35ab1283d', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('de384c80-184b-44e2-aee0-c9a1a1169bcc', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('dfc87aa3-a1bb-42e1-9385-e06324670af1', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('5efa8b00-9645-4edd-b6be-c7b88a9a62f8', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f5ac7430-d05d-44d8-b946-11e2437c1306', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('fe3d71b7-17b0-4487-8217-d7ea49e97aa1', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('2661dfd0-9f1e-4e18-99b9-257d3b224fa9', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('b4d1ea9c-6252-4bba-9c6a-91bed721c2e5', 'signage_item', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.69718+00', '2026-09-27 16:08:10.69718+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0478eac0-e74e-4d84-8183-ac7e006205b2', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('77df8415-9964-484c-851e-761793b9bfcc', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('f34ccbcd-1121-4616-a7cc-de3a8cb54025', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('170a8ad5-4ce4-483d-85d3-c00702597130', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d4ed7211-f5c6-4216-a2b7-b3b6b6412c52', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('6e814a1b-a3e3-4dcb-a139-659878ade260', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a682a6e1-7669-43d8-86e4-9550c218ef18', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('29a37fe3-63af-48fa-bfbd-d9c5ff08de71', 'signage_item', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.724467+00', '2026-09-27 16:08:10.724467+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cfbbb011-2fa1-440e-8f07-a5b280eab4a5', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('2bbbb8f2-d019-4e2f-be40-6546e122b74b', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 16:08:10.008+00', '2026-09-29 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('941b3521-68ad-453b-8c74-142d0fc50106', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('05c6ef4f-3758-43bd-bb79-69131d654137', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 16:08:10.008+00', '2026-09-29 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('1d79ff66-6c8f-4a84-bcc3-fad42c141ebb', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('e9dbd468-81d8-45e4-8c4c-42d55dfab57d', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-26 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('73ac43f3-3516-495f-81c7-fcac8d82990b', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0b8b1361-e1b9-4f1e-9969-4fe6f3b48c5f', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('3f9da261-6f20-4820-8ab1-c14e4a4812df', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('8976e781-55c7-4df7-ad3b-211135dbf355', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c0852173-9afc-45bd-a197-731bab6c5c50', 'signage_item', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.750266+00', '2026-09-27 16:08:10.750266+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('cb935ebc-4a52-41b7-87c2-b3c5c5dedf30', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('b92182d4-0493-46d3-b16b-f11567e93042', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('f68a6126-8c20-4c3d-b656-5b8e51f2dfb4', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('35537793-23dd-4fa0-b8b2-ebeeb9926178', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('253998a2-e342-4c0e-9e60-92154051b371', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('1365bc74-1a8a-4d2a-8e51-3f12b77389f7', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('9e9962af-8c82-4fef-9159-ec28452142a4', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('58b886c3-fc93-4706-9319-705b24930b98', 'signage_item', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.817718+00', '2026-09-27 16:08:10.817718+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3de71009-1006-4f94-b5fa-871cfa9a43ff', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('587b4517-0a02-46c6-813e-a658685bf1f4', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('e7032bc8-28a3-49c9-a1c9-19ae56a15558', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('1db52a7f-9da6-4516-aa54-851e892e5821', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-24 16:08:10.008+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-10-01 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a8f5769f-dc17-41ab-bd37-8ba4ba2b5cdd', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('9eafcc9c-f518-42b1-af64-052ecda32ece', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 16:08:10.008+00', '2026-09-26 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('212192a3-086d-4801-a49f-4b3fd5bdb24c', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3bdc55af-25d1-40c1-b7eb-2aa992a359c6', 'signage_item', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.837219+00', '2026-09-27 16:08:10.837219+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e273a683-c421-4c85-9fbd-a878c8b29d6a', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '4d79991e-67d8-4959-832a-b33e7c3f92e4', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 3, false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.approval_instances VALUES ('e41471f2-e590-4897-9891-61bf25ac19fd', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '2313f6a3-7625-4eb5-80b5-b376a98741b8', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 3, false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.approval_instances VALUES ('e6b9f642-d34c-4b88-a9d8-df5d37beb416', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '6ecba3f0-7143-462b-8e88-8d9c05792cc8', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 16:08:10.008+00', '2026-09-27 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 5, false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.approval_instances VALUES ('372fe934-d8bd-41ad-a1f2-112d595deada', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '11256f03-fcfa-4cd9-9325-b0bc8c3084a4', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('70d3309f-a046-426b-9b48-011353975191', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '4038eea7-ae9b-446e-843d-39e05e793e0a', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 3, false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.approval_instances VALUES ('9d004fc5-412c-408f-ba20-cf947db91491', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '3f3c643f-136e-411b-9442-20aeccf7d5be', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a061df3a-b899-4945-9d1f-3ce75a093d1c', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, '50d4735d-41be-44de-8705-16dcc05ec143', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('b091d8e7-bd96-4f10-92cd-8dcca732a385', 'signage_item', '3d0a8a14-e572-435f-b34d-23821accd931', 1, 'a6e03d16-da29-4020-b2a5-c7e1f117b55f', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.857007+00', '2026-09-27 16:08:10.857007+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('9db215e1-5566-485d-b27e-4edec27d5d78', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, '4d513065-e090-49c8-886e-475ee59b9520', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 16:08:10.008+00', '2026-09-24 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('3a968502-f2aa-42af-a70f-4580a3eca784', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, 'c16eeea9-703c-44a0-ad88-4c237d03e60a', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 16:08:10.008+00', '2026-09-30 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('9fc2dd8a-5aec-42be-9a19-e44534587830', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, '059bba65-6372-4d0c-a093-f0e69c2b8e91', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('b3fb3029-b8e0-4513-9136-f0b6cb862a3c', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, 'a031b2f2-ff58-41fb-b3d6-51b3e88742a7', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('167c5e22-1cda-4e45-ab25-05e470b62ec0', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, '596e2509-f5d4-453c-a99f-dbe0fdd30cf1', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('533551aa-5548-4814-9308-0c4a04333344', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 1, '02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('36aadc70-af85-4c65-a97c-50628d53ad4e', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, '4d513065-e090-49c8-886e-475ee59b9520', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 16:08:10.008+00', '2026-09-24 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('5aad51b5-5799-4aa6-99a3-a98a2dc52831', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, 'c16eeea9-703c-44a0-ad88-4c237d03e60a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('92dd27f7-950e-4343-a4c0-15122c0cacb0', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, '059bba65-6372-4d0c-a093-f0e69c2b8e91', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('b83dd6e4-2bd5-40d5-be86-d300d9fa8b59', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, 'a031b2f2-ff58-41fb-b3d6-51b3e88742a7', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('af2724af-ace9-4987-ae36-bdcf56a091f0', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, '596e2509-f5d4-453c-a99f-dbe0fdd30cf1', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e4398a90-58c4-4e04-abba-af6511928fde', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 1, '02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('9a7b47fc-56ef-49d1-bb00-6ab958f5a520', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, '4d513065-e090-49c8-886e-475ee59b9520', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-21 16:08:10.008+00', '2026-09-24 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('0513c0e3-9f93-456f-a762-b507a496c32e', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, 'c16eeea9-703c-44a0-ad88-4c237d03e60a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('62ddd613-65a1-4a6b-881f-5bf527ab7024', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, '059bba65-6372-4d0c-a093-f0e69c2b8e91', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('ad731a3a-852a-4adf-b89f-558cc5285a3b', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, 'a031b2f2-ff58-41fb-b3d6-51b3e88742a7', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('d07bdc5c-08b1-4028-8408-340ed85655d0', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, '596e2509-f5d4-453c-a99f-dbe0fdd30cf1', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('22c7fb13-7c24-49b5-bc3b-fa13331be0ed', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 1, '02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e91c2647-be00-45dd-a991-720189d5879d', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, '4d513065-e090-49c8-886e-475ee59b9520', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 16:08:10.008+00', '2026-09-24 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('30bd104c-b913-422e-97c5-58b575a17517', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, 'c16eeea9-703c-44a0-ad88-4c237d03e60a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('1bb408cc-be34-4e90-9421-168df3b2dbfe', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, '059bba65-6372-4d0c-a093-f0e69c2b8e91', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-28 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('ee6003d9-d830-48ed-8a8f-23282f79bb3e', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, 'a031b2f2-ff58-41fb-b3d6-51b3e88742a7', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-30 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('4b4aa1fa-978c-463e-846b-3ea9ddfe652b', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, '596e2509-f5d4-453c-a99f-dbe0fdd30cf1', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('236ac414-4a7a-450f-a886-dccd8a1d207e', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 1, '02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 16:08:10.008+00', '2026-09-23 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a624eee0-6fe5-478d-a723-6d27cb4d4ce6', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, '4d513065-e090-49c8-886e-475ee59b9520', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 16:08:10.008+00', '2026-09-24 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('6e23c928-589c-4be8-9cd2-8b9b5f8048e3', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, 'c16eeea9-703c-44a0-ad88-4c237d03e60a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('4cba74c8-f68a-4251-8d17-5cf4607cb90c', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, '059bba65-6372-4d0c-a093-f0e69c2b8e91', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-28 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('138808af-68a8-471f-a1a8-ed4308eb4d9c', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, 'a031b2f2-ff58-41fb-b3d6-51b3e88742a7', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-30 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('1b1d2b8f-1297-4888-9619-57b59dbe620d', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, '596e2509-f5d4-453c-a99f-dbe0fdd30cf1', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-23 16:08:10.008+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-23 16:08:10.008+00', '2026-09-25 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('001de371-0bc4-40b1-bbfb-fc82b74313d4', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 1, '02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 16:08:10.008+00', '2026-09-23 16:08:10.008+00', 0, NULL, NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00', false, true, 0, false, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('6e86300c-9216-450a-b504-d5a993a4d3f4', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'aff9b066-be83-43f3-a8df-21ffc5e3869c', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-09-27 16:08:10.210909+00', '2026-09-27 16:08:10.210909+00');
INSERT INTO public.approvers VALUES ('a4e1b42e-c08b-436a-bbfa-b4fe69935a4e', '4ab06aac-031a-4820-aa42-8c2999d6ec40', '8b37d329-54dc-40dc-a74f-316a2bdef529', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-09-27 16:08:10.2166+00', '2026-09-27 16:08:10.2166+00');
INSERT INTO public.approvers VALUES ('d95af1a3-c8fe-4754-b2ee-f62158a20ea7', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'fcc29090-5379-43f1-a749-3a0babf75c44', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-09-27 16:08:10.220776+00', '2026-09-27 16:08:10.220776+00');
INSERT INTO public.approvers VALUES ('a93f2c3c-78dc-4964-bc57-d8cabc1529d0', '4ab06aac-031a-4820-aa42-8c2999d6ec40', '94669819-1293-489e-9067-89abf7abe795', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-09-27 16:08:10.226616+00', '2026-09-27 16:08:10.226616+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('4816ab07-a2d4-4b97-b5f0-f26c442e4c2a', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.335008+00', '2026-09-27 16:08:10.335008+00');
INSERT INTO public.artwork_versions VALUES ('6c66c74a-0740-4163-b281-02d83c522fe5', '4ce10c14-c60a-432d-ab8c-6a270d325a64', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.359618+00', '2026-09-27 16:08:10.359618+00');
INSERT INTO public.artwork_versions VALUES ('03fc8586-ee1f-4337-8bc8-0a63cb815270', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-27 16:08:10.392813+00', '2026-09-27 16:08:10.392813+00');
INSERT INTO public.artwork_versions VALUES ('21f1e780-6a23-46b7-9694-d8f527cd9f38', '9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.39495+00', '2026-09-27 16:08:10.39495+00');
INSERT INTO public.artwork_versions VALUES ('9b83872d-4d4e-4d65-97fb-c88fd77b6f37', '0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.421164+00', '2026-09-27 16:08:10.421164+00');
INSERT INTO public.artwork_versions VALUES ('2cd68777-88a1-42e8-9ab9-45924487cc04', '96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.439446+00', '2026-09-27 16:08:10.439446+00');
INSERT INTO public.artwork_versions VALUES ('c4060b34-3714-46d4-b3a9-1240d99613bc', '92806015-7332-4e9a-8f03-58e5642d22ec', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.462742+00', '2026-09-27 16:08:10.462742+00');
INSERT INTO public.artwork_versions VALUES ('593c56f7-78ac-4c1b-b252-1174d031eb73', '33d67d80-7910-456a-bc25-a418740a75d8', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.481064+00', '2026-09-27 16:08:10.481064+00');
INSERT INTO public.artwork_versions VALUES ('cc83e85e-0188-48e6-ac67-8420f96f1cc8', '673cc949-fc72-4a6f-b262-83931fcc7729', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.505985+00', '2026-09-27 16:08:10.505985+00');
INSERT INTO public.artwork_versions VALUES ('f9a55c78-ffc8-4b4f-9bf2-702cda0e584d', 'c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.528512+00', '2026-09-27 16:08:10.528512+00');
INSERT INTO public.artwork_versions VALUES ('5b7f53b9-9916-4833-b3aa-9d28d0dadedf', '7361f7df-60df-4798-95f2-4cea85b61053', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.550461+00', '2026-09-27 16:08:10.550461+00');
INSERT INTO public.artwork_versions VALUES ('59a43d35-38cf-444a-8120-e4c1d14b4bf3', '1a1ea06f-ba73-4c87-9668-4534f733449d', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.566958+00', '2026-09-27 16:08:10.566958+00');
INSERT INTO public.artwork_versions VALUES ('2732d3ef-d166-442d-a29e-e0a89b3ffa86', 'a9fab03a-b502-4d0f-8c82-afe06c354141', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.596233+00', '2026-09-27 16:08:10.596233+00');
INSERT INTO public.artwork_versions VALUES ('ba31ab43-7d7e-4471-bb20-5cd166a3a708', 'dd7a33ae-0911-42b3-ad52-3cde539c2a77', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.621052+00', '2026-09-27 16:08:10.621052+00');
INSERT INTO public.artwork_versions VALUES ('3180de57-5326-4eac-9e1f-b910bf05883d', 'e2d37518-14a6-4cce-b466-5aba76d3d53f', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.639699+00', '2026-09-27 16:08:10.639699+00');
INSERT INTO public.artwork_versions VALUES ('67b2bbe4-792c-4f3c-ae46-78487c6be351', 'f4057c3c-7d10-4c44-9232-31074fe363b4', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.655947+00', '2026-09-27 16:08:10.655947+00');
INSERT INTO public.artwork_versions VALUES ('c239c79a-06cc-4d81-b5fd-a8e8069b4c9a', 'f1235bf1-4888-4082-b256-437f4e4ce836', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.675099+00', '2026-09-27 16:08:10.675099+00');
INSERT INTO public.artwork_versions VALUES ('acf8094c-7665-4fa6-b3d6-44083dab6557', 'a3de3396-deac-4099-b8ce-5411f4af5b36', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.693789+00', '2026-09-27 16:08:10.693789+00');
INSERT INTO public.artwork_versions VALUES ('30ff56ec-d0b1-4793-8295-8a2915c73515', 'e085d985-f08c-45a4-88f0-04b2227035c2', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.721388+00', '2026-09-27 16:08:10.721388+00');
INSERT INTO public.artwork_versions VALUES ('5789f209-cb48-42f5-b2f2-f6a6717b2ff9', '9151f286-92f6-4389-a811-1d7442bdaf8c', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-27 16:08:10.744359+00', '2026-09-27 16:08:10.744359+00');
INSERT INTO public.artwork_versions VALUES ('abe93bfe-466e-423c-859d-0b15b5cb94fd', '9151f286-92f6-4389-a811-1d7442bdaf8c', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-27 16:08:10.745962+00', '2026-09-27 16:08:10.745962+00');
INSERT INTO public.artwork_versions VALUES ('2afe8495-3e70-4879-9c29-2deb7b6d159d', '9151f286-92f6-4389-a811-1d7442bdaf8c', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.747291+00', '2026-09-27 16:08:10.747291+00');
INSERT INTO public.artwork_versions VALUES ('03874f4a-c8b5-4ca6-a257-9cac8f269bed', 'ac811eaf-f561-4fe1-9992-ba48cd64580d', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-27 16:08:10.815609+00', '2026-09-27 16:08:10.815609+00');
INSERT INTO public.artwork_versions VALUES ('8dee2b6d-91e1-4860-a260-70ea860c171a', '0c87b4d1-a22d-492d-86a0-fad74884b0a3', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.834908+00', '2026-09-27 16:08:10.834908+00');
INSERT INTO public.artwork_versions VALUES ('7c429c27-7f98-4475-b63c-a5dda5a53e2f', '3d0a8a14-e572-435f-b34d-23821accd931', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-27 16:08:10.854763+00', '2026-09-27 16:08:10.854763+00');


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

INSERT INTO public.contractors VALUES ('c52488ca-cbc4-4496-8ab0-3d3a47b0d692', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-27 16:08:10.177589+00', '2026-09-27 16:08:10.177589+00');
INSERT INTO public.contractors VALUES ('4715bacc-1a7e-4dd2-a628-16faae999be5', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-27 16:08:10.179968+00', '2026-09-27 16:08:10.179968+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('aff9b066-be83-43f3-a8df-21ffc5e3869c', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-09-27 16:08:10.208408+00', '2026-09-27 16:08:10.208408+00');
INSERT INTO public.departments VALUES ('8b37d329-54dc-40dc-a74f-316a2bdef529', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-09-27 16:08:10.213788+00', '2026-09-27 16:08:10.213788+00');
INSERT INTO public.departments VALUES ('fcc29090-5379-43f1-a749-3a0babf75c44', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Sales', 3, false, '{sponsor}', false, '2026-09-27 16:08:10.21897+00', '2026-09-27 16:08:10.21897+00');
INSERT INTO public.departments VALUES ('94669819-1293-489e-9067-89abf7abe795', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-09-27 16:08:10.22366+00', '2026-09-27 16:08:10.22366+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('565f3efe-3a3e-4064-9417-9a4f5f818895', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00');
INSERT INTO public.documents VALUES ('955c1cc0-a83b-4e32-912f-6c4ca9472780', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00');
INSERT INTO public.documents VALUES ('c5d3cee5-c6a0-4c20-ba23-4fbf899609df', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00');
INSERT INTO public.documents VALUES ('174fb642-33e3-422b-a855-95a70e1fa214', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'cd6fc173-4128-4e09-95cd-db9723246274', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00');
INSERT INTO public.documents VALUES ('860a99d5-f843-4079-a7ee-e599f4d5a0a3', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00');
INSERT INTO public.documents VALUES ('5fadbe39-11bf-405c-b3ae-3be2afbaf54b', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00');
INSERT INTO public.documents VALUES ('0493ba94-ab7b-48ce-bfda-7dad5fd056ec', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00');
INSERT INTO public.documents VALUES ('3aa86ed8-eaf3-4b4e-85dc-656d9363bc1d', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '6a2fb25d-0899-4932-a7df-2e5595c4fb43', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00');
INSERT INTO public.documents VALUES ('516f4275-29a0-4cdc-9937-fb43bd9be53b', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00');
INSERT INTO public.documents VALUES ('f8d3afa2-1b2c-4127-907b-e90614211af1', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00');
INSERT INTO public.documents VALUES ('0bc377b8-2e91-404b-90ab-a35e34b91882', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00');
INSERT INTO public.documents VALUES ('6312d6c3-b07a-4b78-97d1-9dcc3b43d91c', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', 'b4385826-698e-4598-a1e8-8be1dd0f3827', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00');
INSERT INTO public.documents VALUES ('cfabf734-411e-4a06-a6aa-a01fabae1c5d', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00');
INSERT INTO public.documents VALUES ('00922abf-b65b-4ba2-83c9-fb0d904688cb', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00');
INSERT INTO public.documents VALUES ('e0bd9426-bf2b-43af-810b-334998da3e08', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00');
INSERT INTO public.documents VALUES ('4cf17d26-d339-491b-8393-4005fe232763', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00');
INSERT INTO public.documents VALUES ('3b89808b-fdca-46bc-aefc-46ccf1f5d57f', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00');
INSERT INTO public.documents VALUES ('19e4c354-5339-451d-a93a-1b6928643416', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00');
INSERT INTO public.documents VALUES ('4dc18f0a-9c4c-4c81-b7ca-5eb0b3d187c9', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00');
INSERT INTO public.documents VALUES ('4ae30df6-0df2-47e8-9cde-920c09154ed5', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_submission', '0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('080c3c7d-f3d1-43be-9f26-1f92ae17cf95', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'signage', 34, '2026-09-27 16:08:10.876902+00', '2026-09-27 16:08:10.87866+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('9e7f60cd-4b50-4ef1-9ab1-d30a19ed49bd', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-27 16:08:10.10478+00', '2026-09-27 16:08:10.10478+00');
INSERT INTO public.edition_deadlines VALUES ('cbe6ae9f-8577-4e58-8e63-8aac8f9a782a', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-27 16:08:10.106576+00', '2026-09-27 16:08:10.106576+00');
INSERT INTO public.edition_deadlines VALUES ('5618b77b-b0bf-4146-b848-d9d863d2320e', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-27 16:08:10.107693+00', '2026-09-27 16:08:10.107693+00');
INSERT INTO public.edition_deadlines VALUES ('68c54347-bbe7-4bbe-8865-be0ab1710dd8', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-27 16:08:10.108612+00', '2026-09-27 16:08:10.108612+00');
INSERT INTO public.edition_deadlines VALUES ('8a58ef5f-718b-4f13-bf13-63b432640183', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-27 16:08:10.109477+00', '2026-09-27 16:08:10.109477+00');
INSERT INTO public.edition_deadlines VALUES ('b7b76b01-794d-4247-ade9-031ace209be9', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-27 16:08:10.110456+00', '2026-09-27 16:08:10.110456+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '93b57d6b-da19-4de6-8ad9-4915e0dcd56f', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-27 16:08:10.102058+00', '2026-09-27 16:08:10.102058+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('93b57d6b-da19-4de6-8ad9-4915e0dcd56f', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'UK Construction Week', 'UKCW', '2026-09-27 16:08:10.071746+00', '2026-09-27 16:08:10.071746+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('0a83805b-1eaf-4e3b-8963-f0b96a716e40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Exhibitor Co', 'A10', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', '2026-09-27 16:08:10.29394+00', '2026-09-27 16:08:10.29394+00');
INSERT INTO public.exhibitors VALUES ('7ff4f8d4-1aa1-4eb6-b97f-5b1505e43261', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SteelFrame Systems', 'A20', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '4715bacc-1a7e-4dd2-a628-16faae999be5', '2026-09-27 16:08:10.296632+00', '2026-09-27 16:08:10.296632+00');
INSERT INTO public.exhibitors VALUES ('174fd193-99ee-47a1-b1cf-d9e0a95da2ff', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'BrickWorks UK', 'A30', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', '2026-09-27 16:08:10.298577+00', '2026-09-27 16:08:10.298577+00');
INSERT INTO public.exhibitors VALUES ('5f9f1623-d5a7-4756-a6b6-9bb16cfd45f2', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Timber Trade Ltd', 'B10', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '4715bacc-1a7e-4dd2-a628-16faae999be5', '2026-09-27 16:08:10.300486+00', '2026-09-27 16:08:10.300486+00');
INSERT INTO public.exhibitors VALUES ('782b6120-75e2-4840-9f64-d848c31ac341', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'GlassTech', 'B20', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', '2026-09-27 16:08:10.302807+00', '2026-09-27 16:08:10.302807+00');
INSERT INTO public.exhibitors VALUES ('ae1d2ac8-8c98-45b4-a7e9-e6ed64554e77', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Insulate Pro', 'B30', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '4715bacc-1a7e-4dd2-a628-16faae999be5', '2026-09-27 16:08:10.30483+00', '2026-09-27 16:08:10.30483+00');
INSERT INTO public.exhibitors VALUES ('bfb33b4c-e02e-44b9-bd01-04609d73cd7c', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'RoofRight', 'C10', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', '2026-09-27 16:08:10.30674+00', '2026-09-27 16:08:10.30674+00');
INSERT INTO public.exhibitors VALUES ('efa9b277-0e88-47f8-8088-ec6a4bf889d2', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'PlantHire Direct', 'C20', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '4715bacc-1a7e-4dd2-a628-16faae999be5', '2026-09-27 16:08:10.308798+00', '2026-09-27 16:08:10.308798+00');
INSERT INTO public.exhibitors VALUES ('1b1febf3-e523-45db-8718-38589dc01d68', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SafetyFirst PPE', 'D10', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-27 16:08:10.313703+00', '2026-09-27 16:08:10.313703+00');
INSERT INTO public.exhibitors VALUES ('b62fc3dc-78af-4f60-86ac-5a57b01a181e', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'ToolMart Retail', 'D20', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-27 16:08:10.315828+00', '2026-09-27 16:08:10.315828+00');
INSERT INTO public.exhibitors VALUES ('e7bd64b0-82a4-493b-9742-00f346be9216', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'EcoBuild Materials', 'D30', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-27 16:08:10.317691+00', '2026-09-27 16:08:10.317691+00');
INSERT INTO public.exhibitors VALUES ('048a05be-2c2e-4167-9127-57380b52a84e', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SiteWise Software', 'D40', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-27 16:08:10.320441+00', '2026-09-27 16:08:10.320441+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('cec72b08-1d2d-41b1-9785-195f62be2993', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'venue', 'venue', '42462995-cbe8-4f9f-8030-1a8ef910e914', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.279067+00', '2026-09-27 16:08:10.279067+00');
INSERT INTO public.external_grants VALUES ('0623be57-e871-4734-8cf8-8cbdd4bb26ce', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.282569+00', '2026-09-27 16:08:10.282569+00');
INSERT INTO public.external_grants VALUES ('17f1c8b5-94bf-4515-8267-986c5cef22f6', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.285754+00', '2026-09-27 16:08:10.285754+00');
INSERT INTO public.external_grants VALUES ('2962df66-c113-455f-af3d-c9789e1703c5', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'supplier', 'supplier', 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.288589+00', '2026-09-27 16:08:10.288589+00');
INSERT INTO public.external_grants VALUES ('c22b4751-380a-4891-aebd-4ee520da9831', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'sponsor', 'sponsor', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.291406+00', '2026-09-27 16:08:10.291406+00');
INSERT INTO public.external_grants VALUES ('2a5a4d3c-f91b-4f1b-8937-58811ae7a935', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'exhibitor', 'exhibitor', '0a83805b-1eaf-4e3b-8963-f0b96a716e40', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-27 16:08:10.008+00', NULL, '2026-09-27 16:08:10.325434+00', '2026-09-27 16:08:10.325434+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-27 16:08:10.112921+00', '2026-09-27 16:08:10.112921+00');
INSERT INTO public.halls VALUES ('1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-27 16:08:10.115352+00', '2026-09-27 16:08:10.115352+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('6f11d5cf-4013-44f8-8dc3-b77fb194ff1d', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Hanging banner', 'hanging_banner', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'rigged', true, 0, '2026-09-27 16:08:10.253542+00', '2026-09-27 16:08:10.253542+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('54075787-0823-4d20-b718-603e62c7f5d3', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Foamex board', 'foamex_board', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'wall_mounted', false, 1, '2026-09-27 16:08:10.255715+00', '2026-09-27 16:08:10.255715+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('31e01535-673c-4ee0-ab65-08393e98c00d', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Fabric graphic', 'fabric_graphic', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'shell_mounted', false, 2, '2026-09-27 16:08:10.257035+00', '2026-09-27 16:08:10.257035+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('11ae2c79-ca07-45f5-9689-5c9406d8faa3', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Floor vinyl', 'floor_vinyl', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'floor', false, 3, '2026-09-27 16:08:10.258347+00', '2026-09-27 16:08:10.258347+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e7705e42-fa53-4e58-b67c-d43da288cab9', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Aisle sign', 'aisle_sign', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'rigged', true, 4, '2026-09-27 16:08:10.259647+00', '2026-09-27 16:08:10.259647+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('157ca8f9-036c-46d9-9281-1bd244679186', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Entrance feature', 'entrance_feature', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'freestanding', true, 5, '2026-09-27 16:08:10.261663+00', '2026-09-27 16:08:10.261663+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('133dcce5-3477-4929-9a96-4e631f617757', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Registration', 'registration', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'freestanding', false, 6, '2026-09-27 16:08:10.263521+00', '2026-09-27 16:08:10.263521+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4a02a9aa-c88a-476f-af6d-f74f0859768a', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Seminar theatre', 'seminar_theatre', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'freestanding', false, 7, '2026-09-27 16:08:10.264853+00', '2026-09-27 16:08:10.264853+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('9a6a806d-e146-4ae7-8075-e1c3e94d1368', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Feature area', 'feature_area', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'freestanding', false, 8, '2026-09-27 16:08:10.266423+00', '2026-09-27 16:08:10.266423+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('67d237be-0de4-4b7c-9160-1076332a11c2', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'External', 'external', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'freestanding', true, 9, '2026-09-27 16:08:10.267924+00', '2026-09-27 16:08:10.267924+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('03ab6e86-3fe8-4c50-a340-c72862f0d5ba', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Digital screen', 'digital_screen', '9fe2e244-dc30-48c7-b74e-814484da28e0', 'digital', false, 10, '2026-09-27 16:08:10.269293+00', '2026-09-27 16:08:10.269293+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('ba67f456-724b-470a-b51c-9d9923cd4c19', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Branded lanyards', 'lanyard', '9fe2e244-dc30-48c7-b74e-814484da28e0', NULL, false, 11, '2026-09-27 16:08:10.270804+00', '2026-09-27 16:08:10.270804+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('faa94915-004d-4f2d-91c5-47ce0283ba4f', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Show bags', 'show_bag', '9fe2e244-dc30-48c7-b74e-814484da28e0', NULL, false, 12, '2026-09-27 16:08:10.272076+00', '2026-09-27 16:08:10.272076+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('e491cc2a-d0d9-4f74-942d-bd63b6475796', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Registration branding', 'reg_branding', '9fe2e244-dc30-48c7-b74e-814484da28e0', NULL, false, 13, '2026-09-27 16:08:10.273231+00', '2026-09-27 16:08:10.273231+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('37cda674-3db8-407f-8003-4e616c4be578', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Other signage', 'other_signage', '9fe2e244-dc30-48c7-b74e-814484da28e0', NULL, false, 14, '2026-09-27 16:08:10.274352+00', '2026-09-27 16:08:10.274352+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('be2fd05e-1200-4787-a871-5982b9026c3e', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Other sponsorship item', 'other_sponsorship', '9fe2e244-dc30-48c7-b74e-814484da28e0', NULL, false, 15, '2026-09-27 16:08:10.275465+00', '2026-09-27 16:08:10.275465+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('67358afe-b3a1-4317-8bea-6b14517f5c79', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-27 16:08:10.118293+00', '2026-09-27 16:08:10.118293+00');
INSERT INTO public.locations VALUES ('64a00a28-623f-4b27-a30c-54fde3d01ab1', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-27 16:08:10.121477+00', '2026-09-27 16:08:10.121477+00');
INSERT INTO public.locations VALUES ('d7d89214-b53e-426f-9a90-60162199891d', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-27 16:08:10.123683+00', '2026-09-27 16:08:10.123683+00');
INSERT INTO public.locations VALUES ('ff8c4dcd-013d-4712-b9b9-8e880e2211b9', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-27 16:08:10.12587+00', '2026-09-27 16:08:10.12587+00');
INSERT INTO public.locations VALUES ('30b1a3e3-4b23-4b0c-896e-333db841c490', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-27 16:08:10.127947+00', '2026-09-27 16:08:10.127947+00');
INSERT INTO public.locations VALUES ('71dbe063-c46e-4ae1-8166-e2926c71606d', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-27 16:08:10.129916+00', '2026-09-27 16:08:10.129916+00');
INSERT INTO public.locations VALUES ('479c4dbf-f4ac-4175-b607-fae17bb9d77c', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-27 16:08:10.132004+00', '2026-09-27 16:08:10.132004+00');
INSERT INTO public.locations VALUES ('0aaabe5c-7bd1-41a7-9bfb-eeeec10a1849', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-27 16:08:10.133979+00', '2026-09-27 16:08:10.133979+00');
INSERT INTO public.locations VALUES ('50436fe0-e0b2-49ae-9f5d-244ec57729e1', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-27 16:08:10.138814+00', '2026-09-27 16:08:10.138814+00');
INSERT INTO public.locations VALUES ('0cea0948-3cff-495b-8b74-0a4f059660df', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-27 16:08:10.14123+00', '2026-09-27 16:08:10.14123+00');
INSERT INTO public.locations VALUES ('69cff259-ed74-4e8b-9108-a72f2529c305', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-27 16:08:10.143556+00', '2026-09-27 16:08:10.143556+00');
INSERT INTO public.locations VALUES ('f450f347-f980-46df-8881-e170ed3d7bf4', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-27 16:08:10.145646+00', '2026-09-27 16:08:10.145646+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('a5e3a3f4-988c-4d80-90a1-b2ddb9aec2a6', '00000000-0000-4000-8000-000000000001', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'admin', '2026-09-27 16:08:10.05229+00', '2026-09-27 16:08:10.05229+00', '{}');
INSERT INTO public.memberships VALUES ('4e39d6b9-9f88-431e-ab87-2388e5395013', '00000000-0000-4000-8000-000000000002', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'ops', '2026-09-27 16:08:10.057204+00', '2026-09-27 16:08:10.057204+00', '{}');
INSERT INTO public.memberships VALUES ('04ed0a3a-0051-45fc-b998-41b6aaddc5ce', '00000000-0000-4000-8000-000000000004', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'sales', '2026-09-27 16:08:10.064834+00', '2026-09-27 16:08:10.064834+00', '{}');
INSERT INTO public.memberships VALUES ('a4faca8f-3f97-4669-a73c-879cf2ac4bb7', '00000000-0000-4000-8000-000000000005', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'event_director', '2026-09-27 16:08:10.067862+00', '2026-09-27 16:08:10.067862+00', '{}');
INSERT INTO public.memberships VALUES ('067b6997-501b-4f56-a224-4bc071a4e603', '00000000-0000-4000-8000-000000000006', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'viewer', '2026-09-27 16:08:10.070081+00', '2026-09-27 16:08:10.070081+00', '{}');
INSERT INTO public.memberships VALUES ('396784e4-c9e5-421a-a3bc-424881aeb9dd', '00000000-0000-4000-8000-000000000003', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'marketing', '2026-09-27 16:08:10.060986+00', '2026-09-27 16:08:10.964622+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-27 16:08:10.044986+00', '2026-09-27 16:08:10.044986+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('cd38afe5-8570-4e8a-b55e-b0d158f5fe51', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '157ca8f9-036c-46d9-9281-1bd244679186', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '67358afe-b3a1-4317-8bea-6b14517f5c79', 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', 'c4da4c0f-ada2-404b-ba9c-f12044490a1d', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '4816ab07-a2d4-4b97-b5f0-f26c442e4c2a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.330962+00', '2026-09-27 16:08:10.337067+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('4ce10c14-c60a-432d-ab8c-6a270d325a64', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '133dcce5-3477-4929-9a96-4e631f617757', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '64a00a28-623f-4b27-a30c-54fde3d01ab1', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '6c66c74a-0740-4163-b281-02d83c522fe5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.357126+00', '2026-09-27 16:08:10.361165+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9064efc7-7f22-4dd1-a13b-e98e00dbe24d', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '6f11d5cf-4013-44f8-8dc3-b77fb194ff1d', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'd7d89214-b53e-426f-9a90-60162199891d', 'ops', '00000000-0000-4000-8000-000000000002', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', '93d6b381-0dbe-43a3-88d2-d8985e7be50e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '21f1e780-6a23-46b7-9694-d8f527cd9f38', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.388929+00', '2026-09-27 16:08:10.396766+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('0dcdf56d-ddf9-4065-8971-a3e56292b4a2', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '4a02a9aa-c88a-476f-af6d-f74f0859768a', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'ff8c4dcd-013d-4712-b9b9-8e880e2211b9', 'marketing', '00000000-0000-4000-8000-000000000003', '878ac11b-e887-47c7-a27e-b15c9b3a42a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '9b83872d-4d4e-4d65-97fb-c88fd77b6f37', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.418855+00', '2026-09-27 16:08:10.422533+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('96b6badc-4fd3-4d39-a822-5ba9e95b6f4f', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '11ae2c79-ca07-45f5-9689-5c9406d8faa3', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '30b1a3e3-4b23-4b0c-896e-333db841c490', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '2cd68777-88a1-42e8-9ab9-45924487cc04', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.436996+00', '2026-09-27 16:08:10.440722+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('92806015-7332-4e9a-8f03-58e5642d22ec', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '9a6a806d-e146-4ae7-8075-e1c3e94d1368', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '71dbe063-c46e-4ae1-8166-e2926c71606d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'c4060b34-3714-46d4-b3a9-1240d99613bc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.457623+00', '2026-09-27 16:08:10.464487+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "4038eea7-ae9b-446e-843d-39e05e793e0a", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('33d67d80-7910-456a-bc25-a418740a75d8', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '6f11d5cf-4013-44f8-8dc3-b77fb194ff1d', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '479c4dbf-f4ac-4175-b607-fae17bb9d77c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '593c56f7-78ac-4c1b-b252-1174d031eb73', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.479257+00', '2026-09-27 16:08:10.482113+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('673cc949-fc72-4a6f-b262-83931fcc7729', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', 'e7705e42-fa53-4e58-b67c-d43da288cab9', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '0aaabe5c-7bd1-41a7-9bfb-eeeec10a1849', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'cc83e85e-0188-48e6-ac67-8420f96f1cc8', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.50012+00', '2026-09-27 16:08:10.50789+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c429fb66-b5db-4ea9-bf9b-7e7d699e6f95', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '4a02a9aa-c88a-476f-af6d-f74f0859768a', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '50436fe0-e0b2-49ae-9f5d-244ec57729e1', 'marketing', '00000000-0000-4000-8000-000000000003', '878ac11b-e887-47c7-a27e-b15c9b3a42a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'f9a55c78-ffc8-4b4f-9bf2-702cda0e584d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.526221+00', '2026-09-27 16:08:10.529724+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('7361f7df-60df-4798-95f2-4cea85b61053', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '31e01535-673c-4ee0-ab65-08393e98c00d', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '0cea0948-3cff-495b-8b74-0a4f059660df', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '5b7f53b9-9916-4833-b3aa-9d28d0dadedf', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.548065+00', '2026-09-27 16:08:10.551685+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1a1ea06f-ba73-4c87-9668-4534f733449d', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '67d237be-0de4-4b7c-9160-1076332a11c2', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '69cff259-ed74-4e8b-9108-a72f2529c305', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '59a43d35-38cf-444a-8120-e4c1d14b4bf3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.564834+00', '2026-09-27 16:08:10.568247+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('a9fab03a-b502-4d0f-8c82-afe06c354141', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'f450f347-f980-46df-8881-e170ed3d7bf4', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '2732d3ef-d166-442d-a29e-e0a89b3ffa86', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.583374+00', '2026-09-27 16:08:10.598267+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dd7a33ae-0911-42b3-ad52-3cde539c2a77', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '03ab6e86-3fe8-4c50-a340-c72862f0d5ba', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '64a00a28-623f-4b27-a30c-54fde3d01ab1', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '5e65fbbd-c17f-4866-9622-cba50ec4c79a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'ba31ab43-7d7e-4471-bb20-5cd166a3a708', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.618246+00', '2026-09-27 16:08:10.622791+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "4038eea7-ae9b-446e-843d-39e05e793e0a", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e2d37518-14a6-4cce-b466-5aba76d3d53f', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', 'e7705e42-fa53-4e58-b67c-d43da288cab9', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'd7d89214-b53e-426f-9a90-60162199891d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '3180de57-5326-4eac-9e1f-b910bf05883d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.637664+00', '2026-09-27 16:08:10.640818+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f4057c3c-7d10-4c44-9232-31074fe363b4', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '30b1a3e3-4b23-4b0c-896e-333db841c490', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '67b2bbe4-792c-4f3c-ae46-78487c6be351', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.653804+00', '2026-09-27 16:08:10.657113+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f1235bf1-4888-4082-b256-437f4e4ce836', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '9a6a806d-e146-4ae7-8075-e1c3e94d1368', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '71dbe063-c46e-4ae1-8166-e2926c71606d', 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'c239c79a-06cc-4d81-b5fd-a8e8069b4c9a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.672726+00', '2026-09-27 16:08:10.676996+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('a3de3396-deac-4099-b8ce-5411f4af5b36', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '6f11d5cf-4013-44f8-8dc3-b77fb194ff1d', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '0aaabe5c-7bd1-41a7-9bfb-eeeec10a1849', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 'acf8094c-7665-4fa6-b3d6-44083dab6557', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.690959+00', '2026-09-27 16:08:10.695541+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e085d985-f08c-45a4-88f0-04b2227035c2', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '31e01535-673c-4ee0-ab65-08393e98c00d', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '0cea0948-3cff-495b-8b74-0a4f059660df', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '30ff56ec-d0b1-4793-8295-8a2915c73515', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.718689+00', '2026-09-27 16:08:10.722955+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9151f286-92f6-4389-a811-1d7442bdaf8c', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '6f11d5cf-4013-44f8-8dc3-b77fb194ff1d', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', 'd7d89214-b53e-426f-9a90-60162199891d', 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', '93d6b381-0dbe-43a3-88d2-d8985e7be50e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '2afe8495-3e70-4879-9c29-2deb7b6d159d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.741707+00', '2026-09-27 16:08:10.74871+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('e46a10bc-3673-44c6-b547-14ef29f611ea', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'f450f347-f980-46df-8881-e170ed3d7bf4', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.771235+00', '2026-09-27 16:08:10.771235+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dabdb6ac-4eef-4d35-be5e-deead5d7e127', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '64a00a28-623f-4b27-a30c-54fde3d01ab1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.781622+00', '2026-09-27 16:08:10.781622+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('10871bb9-f5b8-4cde-a68c-c8284c19ceac', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '133dcce5-3477-4929-9a96-4e631f617757', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '479c4dbf-f4ac-4175-b607-fae17bb9d77c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.786505+00', '2026-09-27 16:08:10.786505+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bb73d5b8-1867-424a-a0c7-201131f8a6df', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '03ab6e86-3fe8-4c50-a340-c72862f0d5ba', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '71dbe063-c46e-4ae1-8166-e2926c71606d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '5e65fbbd-c17f-4866-9622-cba50ec4c79a', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.791079+00', '2026-09-27 16:08:10.791079+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "4038eea7-ae9b-446e-843d-39e05e793e0a", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('678e033f-449c-4ead-8a2c-465ccfec2fa0', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '11ae2c79-ca07-45f5-9689-5c9406d8faa3', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '50436fe0-e0b2-49ae-9f5d-244ec57729e1', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.795606+00', '2026-09-27 16:08:10.795606+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c8f12226-519d-407b-b086-8fd86945a643', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '4a02a9aa-c88a-476f-af6d-f74f0859768a', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '50436fe0-e0b2-49ae-9f5d-244ec57729e1', 'marketing', '00000000-0000-4000-8000-000000000003', '878ac11b-e887-47c7-a27e-b15c9b3a42a7', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.800866+00', '2026-09-27 16:08:10.800866+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('6220272f-8324-4899-9727-14cb977f8b0a', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '67d237be-0de4-4b7c-9160-1076332a11c2', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '69cff259-ed74-4e8b-9108-a72f2529c305', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.805566+00', '2026-09-27 16:08:10.805566+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "4038eea7-ae9b-446e-843d-39e05e793e0a", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e82ea893-0fb0-4fbf-bfae-682e80643aa8', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', '69cff259-ed74-4e8b-9108-a72f2529c305', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.809929+00', '2026-09-27 16:08:10.809929+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('ac811eaf-f561-4fe1-9992-ba48cd64580d', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '30b1a3e3-4b23-4b0c-896e-333db841c490', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '03874f4a-c8b5-4ca6-a257-9cac8f269bed', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.81369+00', '2026-09-27 16:08:10.816615+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0c87b4d1-a22d-492d-86a0-fad74884b0a3', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '157ca8f9-036c-46d9-9281-1bd244679186', 'cf3831bc-5641-4899-ab3b-c4fecf0b8079', '67358afe-b3a1-4317-8bea-6b14517f5c79', 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', 'c4da4c0f-ada2-404b-ba9c-f12044490a1d', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '8dee2b6d-91e1-4860-a260-70ea860c171a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.832435+00', '2026-09-27 16:08:10.836091+00', 'signage', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', NULL, NULL, NULL, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('bd51e1a2-5cd9-498c-b1b5-4a3b184eb92e', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '54075787-0823-4d20-b718-603e62c7f5d3', '1a8b8abb-e0fd-4dbe-8f2c-a4b5b9d15090', 'f450f347-f980-46df-8881-e170ed3d7bf4', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.848327+00', '2026-09-27 16:08:10.848327+00', 'signage', 'organiser', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3d0a8a14-e572-435f-b34d-23821accd931', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'ba67f456-724b-470a-b51c-9d9923cd4c19', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, '7c429c27-7f98-4475-b63c-a5dda5a53e2f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.852791+00', '2026-09-27 16:08:10.855921+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', '2026-12-11', NULL, 9000.00, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('ac268cfb-9fad-4423-880e-2d532764f1c1', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'faa94915-004d-4f2d-91c5-47ce0283ba4f', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.868045+00', '2026-09-27 16:08:10.868045+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}, {"stepId": "6ecba3f0-7143-462b-8e88-8d9c05792cc8", "userId": null}]', '2026-10-17', NULL, 12500.00, '2026-09-17 16:08:10.008+00', NULL);
INSERT INTO public.signage_items VALUES ('77870777-0979-4e71-abd9-cbce3f16e9c5', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'e491cc2a-d0d9-4f74-942d-bd63b6475796', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.87182+00', '2026-09-27 16:08:10.87182+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', '2027-01-25', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('cf92b461-3df4-4d8b-aee2-69dc952d5f03', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', 'be2fd05e-1200-4787-a871-5982b9026c3e', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '9fe2e244-dc30-48c7-b74e-814484da28e0', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-27 16:08:10.875395+00', '2026-09-27 16:08:10.875395+00', 'sponsorship_item', 'sponsor', '[{"stepId": "4d79991e-67d8-4959-832a-b33e7c3f92e4", "userId": null}, {"stepId": "2313f6a3-7625-4eb5-80b5-b376a98741b8", "userId": null}]', '2026-10-15', NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('90ef4486-5e42-47b9-a6b5-664ba8219a96', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'f4057c3c-7d10-4c44-9232-31074fe363b4', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'd9bfd9ff-1050-4006-b27c-44c44acf2377', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-27 16:08:10.66843+00', '2026-09-27 16:08:10.66843+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('93d6b381-0dbe-43a3-88d2-d8985e7be50e', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', 'Logo on 6 hanging banners', 6, '2026-09-27 16:08:10.18485+00', '2026-09-27 16:08:10.18485+00');
INSERT INTO public.sponsor_entitlements VALUES ('c4da4c0f-ada2-404b-ba9c-f12044490a1d', 'a347a01a-d465-413b-a7a5-5e5f65998e9d', 'Entrance feature branding', 1, '2026-09-27 16:08:10.186813+00', '2026-09-27 16:08:10.186813+00');
INSERT INTO public.sponsor_entitlements VALUES ('d46f9177-1fe3-42e6-9712-85c76b7072d4', '878ac11b-e887-47c7-a27e-b15c9b3a42a7', 'Seminar theatre branding', 1, '2026-09-27 16:08:10.190287+00', '2026-09-27 16:08:10.190287+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('a347a01a-d465-413b-a7a5-5e5f65998e9d', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-27 16:08:10.182491+00', '2026-09-27 16:08:10.182491+00');
INSERT INTO public.sponsors VALUES ('878ac11b-e887-47c7-a27e-b15c9b3a42a7', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-27 16:08:10.188522+00', '2026-09-27 16:08:10.188522+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('cd6fc173-4128-4e09-95cd-db9723246274', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '0a83805b-1eaf-4e3b-8963-f0b96a716e40', 'STD-BIRM27-A10', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-21 16:08:10.008+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 1, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.881837+00', '2026-09-27 16:08:10.881837+00');
INSERT INTO public.stand_submissions VALUES ('6a2fb25d-0899-4932-a7df-2e5595c4fb43', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '7ff4f8d4-1aa1-4eb6-b97f-5b1505e43261', 'STD-BIRM27-A20', '4715bacc-1a7e-4dd2-a628-16faae999be5', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-21 16:08:10.008+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 1, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.899905+00', '2026-09-27 16:08:10.899905+00');
INSERT INTO public.stand_submissions VALUES ('b4385826-698e-4598-a1e8-8be1dd0f3827', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '174fd193-99ee-47a1-b1cf-d9e0a95da2ff', 'STD-BIRM27-A30', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-21 16:08:10.008+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 1, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.914086+00', '2026-09-27 16:08:10.914086+00');
INSERT INTO public.stand_submissions VALUES ('67d43e38-e10d-47ed-81cc-14d7da2d7cf4', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '5f9f1623-d5a7-4756-a6b6-9bb16cfd45f2', 'STD-BIRM27-B10', '4715bacc-1a7e-4dd2-a628-16faae999be5', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-21 16:08:10.008+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 1, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.927113+00', '2026-09-27 16:08:10.927113+00');
INSERT INTO public.stand_submissions VALUES ('0ec3ae66-5e89-4e7e-9929-4b9077a3d735', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', '782b6120-75e2-4840-9f64-d848c31ac341', 'STD-BIRM27-B20', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-21 16:08:10.008+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 1, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.943064+00', '2026-09-27 16:08:10.943064+00');
INSERT INTO public.stand_submissions VALUES ('3d136d97-6676-43ed-80c5-18edc469ea98', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'ae1d2ac8-8c98-45b4-a7e9-e6ed64554e77', 'STD-BIRM27-B30', '4715bacc-1a7e-4dd2-a628-16faae999be5', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 0, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.956271+00', '2026-09-27 16:08:10.956271+00');
INSERT INTO public.stand_submissions VALUES ('e84f64f9-4bd0-42e5-abd6-ac3d73772d3b', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'bfb33b4c-e02e-44b9-bd01-04609d73cd7c', 'STD-BIRM27-C10', 'c52488ca-cbc4-4496-8ab0-3d3a47b0d692', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 0, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.959429+00', '2026-09-27 16:08:10.959429+00');
INSERT INTO public.stand_submissions VALUES ('5da90dca-b335-4616-962b-cdcb0667322d', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'efa9b277-0e88-47f8-8088-ec6a4bf889d2', 'STD-BIRM27-C20', '4715bacc-1a7e-4dd2-a628-16faae999be5', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '439b41c9-01c4-40af-b71b-4f857f224178', 0, '00000000-0000-4000-8000-000000000002', '2026-09-27 16:08:10.96223+00', '2026-09-27 16:08:10.96223+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('d9bfd9ff-1050-4006-b27c-44c44acf2377', '77f01c9b-ff08-4d79-9860-d2f816f56761');
INSERT INTO public.supplier_service_links VALUES ('d9bfd9ff-1050-4006-b27c-44c44acf2377', '84f81996-c77c-4dd0-b4ce-d6d096a0120a');
INSERT INTO public.supplier_service_links VALUES ('22a918c6-e516-4fa8-a7fb-b6f3ae1cc9c2', '2c34f437-a74b-4490-bd95-58bbddabeadb');
INSERT INTO public.supplier_service_links VALUES ('22a918c6-e516-4fa8-a7fb-b6f3ae1cc9c2', '84f81996-c77c-4dd0-b4ce-d6d096a0120a');
INSERT INTO public.supplier_service_links VALUES ('22a918c6-e516-4fa8-a7fb-b6f3ae1cc9c2', '32c61b0c-8df6-4195-902e-3a796e019cff');
INSERT INTO public.supplier_service_links VALUES ('5e65fbbd-c17f-4866-9622-cba50ec4c79a', '5dbcf086-6b7c-41e5-998e-a3531c96a041');
INSERT INTO public.supplier_service_links VALUES ('5e65fbbd-c17f-4866-9622-cba50ec4c79a', '32c61b0c-8df6-4195-902e-3a796e019cff');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('77f01c9b-ff08-4d79-9860-d2f816f56761', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Signage print', 1, false, '2026-09-27 16:08:10.156086+00', '2026-09-27 16:08:10.156086+00');
INSERT INTO public.supplier_services VALUES ('5dbcf086-6b7c-41e5-998e-a3531c96a041', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Digital screens & AV', 2, false, '2026-09-27 16:08:10.158193+00', '2026-09-27 16:08:10.158193+00');
INSERT INTO public.supplier_services VALUES ('2c34f437-a74b-4490-bd95-58bbddabeadb', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Rigging', 3, false, '2026-09-27 16:08:10.159716+00', '2026-09-27 16:08:10.159716+00');
INSERT INTO public.supplier_services VALUES ('84f81996-c77c-4dd0-b4ce-d6d096a0120a', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Installation', 4, false, '2026-09-27 16:08:10.160839+00', '2026-09-27 16:08:10.160839+00');
INSERT INTO public.supplier_services VALUES ('32c61b0c-8df6-4195-902e-3a796e019cff', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Staffing', 5, false, '2026-09-27 16:08:10.162011+00', '2026-09-27 16:08:10.162011+00');
INSERT INTO public.supplier_services VALUES ('cf650b59-318e-4b06-aebf-ba03ccdb2826', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Furniture', 6, false, '2026-09-27 16:08:10.163491+00', '2026-09-27 16:08:10.163491+00');
INSERT INTO public.supplier_services VALUES ('e4bda998-ddc7-4982-9992-9a1fb83066d8', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Structural engineering', 7, false, '2026-09-27 16:08:10.164699+00', '2026-09-27 16:08:10.164699+00');
INSERT INTO public.supplier_services VALUES ('9d0e9f48-6bcb-458e-8a3c-4d64d5f1cfaa', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Floor Manager', 8, false, '2026-09-27 16:08:10.165801+00', '2026-09-27 16:08:10.165801+00');
INSERT INTO public.supplier_services VALUES ('39986624-73cb-4563-aa54-09ddb846be68', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Security', 9, false, '2026-09-27 16:08:10.167043+00', '2026-09-27 16:08:10.167043+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('d9bfd9ff-1050-4006-b27c-44c44acf2377', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-27 16:08:10.148387+00', '2026-09-27 16:08:10.148387+00');
INSERT INTO public.suppliers VALUES ('22a918c6-e516-4fa8-a7fb-b6f3ae1cc9c2', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-27 16:08:10.151966+00', '2026-09-27 16:08:10.151966+00');
INSERT INTO public.suppliers VALUES ('5e65fbbd-c17f-4866-9622-cba50ec4c79a', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-27 16:08:10.154625+00', '2026-09-27 16:08:10.154625+00');


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('e0c5309b-360e-4f1e-9545-a6bda5b5ad1e', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-04', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'cd38afe5-8570-4e8a-b55e-b0d158f5fe51', NULL, '2026-09-27 16:08:10.968356+00', '2026-09-27 16:08:10.968356+00', NULL);
INSERT INTO public.tasks VALUES ('f2f7eabd-7565-454e-9058-93564ab17065', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-07', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-27 16:08:10.970382+00', '2026-09-27 16:08:10.970382+00', NULL);
INSERT INTO public.tasks VALUES ('57ee9b59-7515-4ae2-9781-6a4b0b8a39f8', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Walk the hall with the venue', NULL, 'done', '2026-09-22', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-09-27 16:08:10.008+00', '2026-09-27 16:08:10.971942+00', '2026-09-27 16:08:10.971942+00', 'f2f7eabd-7565-454e-9058-93564ab17065');
INSERT INTO public.tasks VALUES ('acff53fc-9d16-4fa5-9879-bddb31cd6650', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'dfcd69b7-e61d-422d-b3a7-631a0f8f49f6', 'Send sign positions to the printer', NULL, 'open', '2026-09-26', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-27 16:08:10.971942+00', '2026-09-27 16:08:10.971942+00', 'f2f7eabd-7565-454e-9058-93564ab17065');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.049603+00', '2026-09-27 16:08:10.049603+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.055835+00', '2026-09-27 16:08:10.055835+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.059438+00', '2026-09-27 16:08:10.059438+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.063102+00', '2026-09-27 16:08:10.063102+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.066561+00', '2026-09-27 16:08:10.066561+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-27 16:08:10.069101+00', '2026-09-27 16:08:10.069101+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.276485+00', '2026-09-27 16:08:10.276485+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.280677+00', '2026-09-27 16:08:10.280677+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.283946+00', '2026-09-27 16:08:10.283946+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.286742+00', '2026-09-27 16:08:10.286742+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.289603+00', '2026-09-27 16:08:10.289603+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-27 16:08:10.323156+00', '2026-09-27 16:08:10.323156+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('35857600-9e0f-4dc5-8701-02f0529b3b76', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-27 16:08:10.0816+00', '2026-09-27 16:08:10.0816+00');
INSERT INTO public.venue_rules VALUES ('d138db1a-33e4-4156-98d4-c6bc73100f6b', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-27 16:08:10.084079+00', '2026-09-27 16:08:10.084079+00');
INSERT INTO public.venue_rules VALUES ('3474644c-0187-4570-9976-3c7544c803e3', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-27 16:08:10.086698+00', '2026-09-27 16:08:10.086698+00');
INSERT INTO public.venue_rules VALUES ('daf5950d-5d7c-4356-a735-ca09a2fe7e2a', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-27 16:08:10.090613+00', '2026-09-27 16:08:10.090613+00');
INSERT INTO public.venue_rules VALUES ('e4fafc10-20ea-41a1-b53e-3084c8a234a6', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-27 16:08:10.093721+00', '2026-09-27 16:08:10.093721+00');
INSERT INTO public.venue_rules VALUES ('80649c45-3e62-4885-8fa4-7d0be312df61', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-27 16:08:10.096156+00', '2026-09-27 16:08:10.096156+00');
INSERT INTO public.venue_rules VALUES ('b8aa39e4-e6d2-4272-8781-9697c77d03ff', '42462995-cbe8-4f9f-8030-1a8ef910e914', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-27 16:08:10.098539+00', '2026-09-27 16:08:10.098539+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('42462995-cbe8-4f9f-8030-1a8ef910e914', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-27 16:08:10.074541+00', '2026-09-27 16:08:10.074541+00');
INSERT INTO public.venues VALUES ('c0deaa51-df4d-435b-b50f-ea005dcacacb', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-27 16:08:10.076779+00', '2026-09-27 16:08:10.076779+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('11256f03-fcfa-4cd9-9325-b0bc8c3084a4', '9fe2e244-dc30-48c7-b74e-814484da28e0', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-27 16:08:10.198047+00', '2026-09-27 16:08:10.198047+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('3f3c643f-136e-411b-9442-20aeccf7d5be', '9fe2e244-dc30-48c7-b74e-814484da28e0', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-27 16:08:10.200206+00', '2026-09-27 16:08:10.200206+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('50d4735d-41be-44de-8705-16dcc05ec143', '9fe2e244-dc30-48c7-b74e-814484da28e0', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-27 16:08:10.201139+00', '2026-09-27 16:08:10.201139+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a6e03d16-da29-4020-b2a5-c7e1f117b55f', '9fe2e244-dc30-48c7-b74e-814484da28e0', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-27 16:08:10.202084+00', '2026-09-27 16:08:10.202084+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('4d79991e-67d8-4959-832a-b33e7c3f92e4', '9fe2e244-dc30-48c7-b74e-814484da28e0', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-27 16:08:10.194087+00', '2026-09-27 16:08:10.234599+00', '{organiser,sponsor}', false, 'aff9b066-be83-43f3-a8df-21ffc5e3869c');
INSERT INTO public.workflow_steps VALUES ('2313f6a3-7625-4eb5-80b5-b376a98741b8', '9fe2e244-dc30-48c7-b74e-814484da28e0', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-27 16:08:10.195946+00', '2026-09-27 16:08:10.236042+00', '{organiser,sponsor}', false, '8b37d329-54dc-40dc-a74f-316a2bdef529');
INSERT INTO public.workflow_steps VALUES ('6ecba3f0-7143-462b-8e88-8d9c05792cc8', '9fe2e244-dc30-48c7-b74e-814484da28e0', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-09-27 16:08:10.196985+00', '2026-09-27 16:08:10.238797+00', '{sponsor}', false, 'fcc29090-5379-43f1-a749-3a0babf75c44');
INSERT INTO public.workflow_steps VALUES ('4038eea7-ae9b-446e-843d-39e05e793e0a', '9fe2e244-dc30-48c7-b74e-814484da28e0', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-27 16:08:10.199228+00', '2026-09-27 16:08:10.239916+00', '{organiser,sponsor}', false, '94669819-1293-489e-9067-89abf7abe795');
INSERT INTO public.workflow_steps VALUES ('4d513065-e090-49c8-886e-475ee59b9520', '439b41c9-01c4-40af-b71b-4f857f224178', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-27 16:08:10.24534+00', '2026-09-27 16:08:10.24534+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('c16eeea9-703c-44a0-ad88-4c237d03e60a', '439b41c9-01c4-40af-b71b-4f857f224178', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-27 16:08:10.246548+00', '2026-09-27 16:08:10.246548+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('059bba65-6372-4d0c-a093-f0e69c2b8e91', '439b41c9-01c4-40af-b71b-4f857f224178', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-27 16:08:10.247531+00', '2026-09-27 16:08:10.247531+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a031b2f2-ff58-41fb-b3d6-51b3e88742a7', '439b41c9-01c4-40af-b71b-4f857f224178', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-27 16:08:10.248498+00', '2026-09-27 16:08:10.248498+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('596e2509-f5d4-453c-a99f-dbe0fdd30cf1', '439b41c9-01c4-40af-b71b-4f857f224178', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-27 16:08:10.249697+00', '2026-09-27 16:08:10.249697+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('02ecd8cd-968c-44e6-b8cc-84f783b0c6ba', '439b41c9-01c4-40af-b71b-4f857f224178', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-27 16:08:10.251019+00', '2026-09-27 16:08:10.251019+00', '{}', false, NULL);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('9fe2e244-dc30-48c7-b74e-814484da28e0', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Signage default', 'signage', true, false, '2026-09-27 16:08:10.192666+00', '2026-09-27 16:08:10.192666+00');
INSERT INTO public.workflows VALUES ('439b41c9-01c4-40af-b71b-4f857f224178', '4ab06aac-031a-4820-aa42-8c2999d6ec40', 'Stand default', 'stand', true, false, '2026-09-27 16:08:10.244053+00', '2026-09-27 16:08:10.244053+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 9, true);


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

\unrestrict Bebinfg99VWpugzolhe1w55olikeSalIAcQBXZGMapTjC6MegI0Ou3RfcLjviNC

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
