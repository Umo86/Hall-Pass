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

\restrict 2cv8E3YWK47xscB50cNQfAqzYoIlzzM6su0n7qQkH9NDMGaGZc22GeYvTQbKHDb

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
INSERT INTO drizzle.__drizzle_migrations VALUES (11, '25f41827c7ab1b63530a494f6bb6b6e05f89c092c59c006d46c8a47d2d009851', 1790765456233);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('a1d6db21-1c92-4ef9-b83f-a97c75120797', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('f0c21fed-5d9a-4b70-93d9-f2907f591430', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('4b033799-660b-407d-a8de-cbd19c5456ea', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('f65d2ccd-e040-4008-ba3c-81d8320a9d80', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4ef83aca-108a-45a4-9f4c-e3211bbe4a66', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('289fcd90-5fed-4ae2-930c-e6dcaed88a42', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fb659807-bb63-475e-a5fb-dd764d600aa4', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('60c5e5af-6ac5-4f77-bdde-e3ae44789a06', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.131742+00', '2026-10-09 13:48:11.131742+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7e7c2a39-4792-4f35-ace2-ce3ae4559855', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('cd6b56ec-6834-4b6f-b831-4e3b951a05be', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('24907b01-dad6-44e2-8f25-2f94c267040f', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('3c9c21c5-480a-461a-9663-b5bb6860feec', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ace0b949-c11a-4b86-962e-5f78df8986aa', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('537ae969-09a5-4690-9103-d3f57f03baa7', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('321e823c-d990-40e6-83b6-577cd55bb0e5', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('63ecc9a8-9933-4b67-90bb-9eedc4d18b23', 'signage_item', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.160783+00', '2026-10-09 13:48:11.160783+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('48936eca-c53d-4942-b4e0-c118bffe11a2', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-27 13:48:10.74+00', '2026-10-05 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('4b494b35-1d14-471a-bb8c-450ca9ab7663', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-29 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-27 13:48:10.74+00', '2026-09-30 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('50739923-ca2b-4ee0-888b-87a9d75b6ccc', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-29 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-27 13:48:10.74+00', '2026-10-02 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('3a8467ba-c6f2-43e4-8899-924f84009189', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('be40b9f5-d956-4f07-b180-95e437aaf7ac', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('9e4b28e2-1a9a-481b-8021-ea283bc081c1', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f5a31ab0-0218-4e4f-8bec-a5c9b6dd3823', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eec7e8c7-a8b3-4cf6-a669-d1f80370b23c', 'signage_item', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.193543+00', '2026-10-09 13:48:11.193543+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9b2d8588-0da3-4be8-b380-ef4fe5653cc1', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('b04c09b1-d5de-425c-9f0a-5abac30b8d92', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('100bf89c-b4d0-4212-a9cf-72e8c82fbb0c', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('ce06d61e-b219-483a-b4d9-3aa01d343a99', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4c577866-678d-4525-8257-9788c0daeeb3', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('1f5e17fe-f476-473a-9e89-bc4f219078cd', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e22869a3-ddea-4620-9a7d-dd3dcc56d9f1', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4813a0e7-ea65-4f23-a9ad-8192a503e22e', 'signage_item', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.225067+00', '2026-10-09 13:48:11.225067+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('df823b15-f73e-48a6-99af-676db5599edb', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('cee604d6-9d2d-4ecb-a832-3f30fe25345d', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('f80451f3-452d-4967-99c2-160e137ac91f', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('21a718a4-b1bc-4ff5-abec-ee4c29cb7a70', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3d4fb6b9-309e-467f-adcb-c7ee908b594b', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('fa60edf9-9397-42de-99fa-ec2f10f2e5be', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('debdecfb-1e0c-4801-b37a-a61d22a5ffb0', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b8df9c5b-e5eb-4707-b6ff-451e3f9b995f', 'signage_item', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.255237+00', '2026-10-09 13:48:11.255237+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('afd6d029-c374-4b01-8106-345c63ee18ab', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-29 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-27 13:48:10.74+00', '2026-09-30 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('552f6317-de9d-40ef-8218-61e0e9931b7b', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-29 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-27 13:48:10.74+00', '2026-09-30 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('f997fb64-f597-4526-a557-731ef393ec1e', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('a3c3faf9-5c22-4fc8-9f66-8b55445dc594', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('439f02f6-61e2-40e7-8b32-20bb44b35dde', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', '2026-10-05 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('456b1bd5-9080-46db-92c7-7b0babed08bb', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7c306656-cd10-4c0a-8482-b689927348bb', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fbd1fd41-dc61-41e1-aacc-49ba834a5d9e', 'signage_item', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.281916+00', '2026-10-09 13:48:11.281916+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('976f9d29-f9f2-4bcd-a237-ec31f154b52c', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('4fad0e27-5933-4191-b1f1-99b4ee69bde0', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('a8be1920-1be3-4e07-bd78-d93d9b2dec86', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('0ae0b590-ad8f-496e-817a-14368f627307', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('05eabbd1-2fbe-4e12-a17e-c3a7d1433fb2', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('341a1ae3-06d0-4367-9bef-a52fe31d779c', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('770bc8e6-4a95-475c-a27e-c8c55b81a53f', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9c105b6a-2a08-49cf-aa59-9d6e835e086f', 'signage_item', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.305376+00', '2026-10-09 13:48:11.305376+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0bb70ee0-522e-4098-9d7d-267a37c98eab', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('645a2e04-ad87-49fa-97cb-3a896d76d490', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('914355f6-e908-4170-bd52-006cd800cf99', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('06e2a734-283e-47d1-ab06-72d146a4c3c5', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b68f3e32-5616-42eb-bf28-26b4e06656f5', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('ab965408-e2e2-4695-8f9a-c00a3f5c9286', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e20c372d-a015-4bac-a23f-2fd5ad9e9018', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('49d7479f-321c-4868-a347-82cb13e2b584', 'signage_item', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.328721+00', '2026-10-09 13:48:11.328721+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('35383ac9-83b6-4feb-9c1a-3a6f25e83142', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('2b684cf0-72e3-4d43-abae-37aac282e2fe', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('b091cd3b-3ff5-45a2-9d67-be6c62e12725', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-06 13:48:10.74+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('5628eb8f-68fd-41c6-99ea-8c4c6a053f11', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('82e46914-7cd4-44ba-b10d-8f9842a499bd', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('96aa0078-c26d-43c8-b17e-54541d91ae7f', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('666524db-c8dd-4720-90f9-744720c2872e', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('189a4edc-96b3-4f4a-9d17-1f3e7d52356b', 'signage_item', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.356894+00', '2026-10-09 13:48:11.356894+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('468bdcc9-e5cb-4024-9213-05793f8181ff', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('bd9f8169-16ee-4891-869d-17103ba031ae', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('c8b1fbf3-78c8-4ac6-8729-b89999c39f4a', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('acf082c4-ccc4-4f3b-898e-d712e0cbc7d4', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('621f9958-8c12-49dd-b5fc-4cb471d1c240', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('dc267089-5b2e-458c-a3e4-f41b5db56cd8', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b77cd61c-c9a8-49f7-8376-d030bfb4fb3e', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('43b645ee-eff7-460c-9d62-c01f182eedd8', 'signage_item', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.378066+00', '2026-10-09 13:48:11.378066+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8f0a1414-5c32-4949-9fa3-02fffa32bfd0', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('a2089733-ddb1-4ccd-877b-749b36a8360b', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('6970d7f0-85a0-4a1f-9cda-57d065c0a13d', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('aea2dca5-222e-4a62-b9f2-c21e7e153236', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('52bc2b0c-24ff-44a2-9f4d-954df1f0d5ad', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('ead993e7-b8c3-48ee-9f1a-43c3414dddd2', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('47b4be2a-f138-4e42-82ec-82efda4860a6', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('97cdc54b-d67c-4f5f-919b-f498b5b2b387', 'signage_item', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.402568+00', '2026-10-09 13:48:11.402568+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fdb5fefb-fe20-4b56-bb86-5e2e870dc4c5', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('1dd353bd-628d-46c8-a157-2c5c4c9466b4', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('9e4ef32a-e955-4f52-ad80-7524e0246dab', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('98fca7bb-6834-4420-be38-5438803f9380', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('335bbbee-e4d0-4b5d-80cf-dd71c0490a86', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('08bd3f03-564d-412c-92a0-3dca864f9736', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0e1c0591-59c7-47fc-8586-aad89a150419', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d6cc7b20-68b0-4c60-a93a-800f9c3b2f94', 'signage_item', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.420686+00', '2026-10-09 13:48:11.420686+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dbca0726-800f-4d12-8346-4abe9e971281', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('986a2fd9-e18f-483f-a0a3-64140b475fc8', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('f7524b93-c186-4a67-a2cd-47da87c36781', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('43b49896-f4f3-462e-88fc-daaa9cccaf2d', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d57934e6-a782-4013-bf5e-59192868c4e4', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('7e028227-92e8-42bd-aa28-7352b1b7f08d', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('03a17787-ff47-42df-88f6-ea65ce6b1dd8', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b24c84bc-f7de-42ef-ad7e-d9c8c966d603', 'signage_item', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.437618+00', '2026-10-09 13:48:11.437618+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a23ae86f-48ed-4843-bdd8-0c38345aa9e2', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('8ee3b616-7d1c-4db4-af43-8c62398828aa', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('8fa505ef-2254-47ac-a898-a3d3c2fa04b5', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('c03454c4-314f-4518-9dfe-bb42dcbc0ab7', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('38e98110-36ad-44a0-95a5-8ca405aa6c58', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('46d9fb6a-e874-43bd-a5be-f926bd092f5e', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c4cd472c-e592-4da5-9757-b7b6d90075f3', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ee5f7ce-b6cf-46d9-bc18-7902de402c96', 'signage_item', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.45512+00', '2026-10-09 13:48:11.45512+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('da312080-b95d-4c79-892e-978de6a365b5', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('6196a9fc-c931-4c00-b48f-639359a522b7', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('59de5dda-c3f5-4593-aad2-2de311ec0fcb', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('863542d0-623b-4289-9307-c8d3634228f3', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f8b9d36e-55cf-41e1-9de7-eb1497bd9ef5', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('55c387bb-4e4b-418e-b8df-e3f5e96b3185', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6394ea23-6b69-4e6f-9bfc-d1983b374a46', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('19da6280-4e8b-4ecb-a6ab-192b06ae4b17', 'signage_item', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.474718+00', '2026-10-09 13:48:11.474718+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6d303d0a-9216-4b0b-ae8c-e3ec25f2dce5', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('90469804-fc61-46e0-9c65-63f5a2cf2086', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('a60c0872-93c6-4dfb-925f-e5997e5e997c', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('6de3c9e6-7f7a-4ea5-b5bc-7f4642a101d9', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d9602205-78df-49bd-92b6-750baa08def3', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('24fee58a-47f5-4594-b0f8-5b2294aec0af', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('26d08a71-69ff-4be8-af48-8ebb98716aad', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('13b8f207-6254-410a-991c-66597907cd4a', 'signage_item', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.505967+00', '2026-10-09 13:48:11.505967+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5c3a8c7e-33c7-47e9-b11f-1ef1f8d95bb0', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('3a5338fb-789a-4184-abdd-a773fa7bf2b2', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('104ddfc1-0a04-4dae-b812-8a72a5fb7e0a', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('ff2030ab-9dfb-4caa-8cf7-9fa7a2afcc8a', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ccbdbf54-5a15-47f1-b361-afa6718d66a6', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('cea6c539-a563-41f3-82e6-6deb3d823db6', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2abbf604-c4bd-45fe-add9-047cbcaa9214', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('71b055b9-bd61-431a-af87-c7ab42f11151', 'signage_item', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.530203+00', '2026-10-09 13:48:11.530203+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('658ceb14-19ba-4d16-9446-c06007d90f76', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('f0e863b0-224c-475c-8ad0-803e924bf4b5', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('882c484a-3956-4038-9750-b2a5eebe5002', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('6b0bf4a2-70fa-4f04-ba8e-a88f333c57a1', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2f1c8a2e-6263-4d11-a896-90ac2275a720', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('08379552-d8ec-4a32-8395-5edaa4ab83cb', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0cc908fe-1cd1-446a-8aac-86cd29d49b71', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cb8e6730-f7f7-43f1-af3d-f9b408408250', 'signage_item', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.556002+00', '2026-10-09 13:48:11.556002+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0ba3b809-818f-4172-8b94-6782cdecc18a', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('779161bb-4984-45d8-917e-745c53a18d41', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 13:48:10.74+00', '2026-10-11 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('801fa33f-35f2-4292-8371-e4c701871374', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('9f4dd3cb-52d7-44e8-a372-166c04e6e356', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 13:48:10.74+00', '2026-10-11 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('d0720017-78da-4a8d-b05c-fc3847e9f1db', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('8697f0d9-1430-4ff9-ac34-a058c58a3350', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-08 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('b36c0e5c-f277-41ab-bc80-149f96240b26', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('da8936e0-3a32-4a8b-9d4c-fd8d05df0409', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('ef57d986-b273-4cdb-a218-3f2a54fea728', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('844800a7-0021-49fb-ac86-560548876b5b', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('553ef6a8-7e3b-4e3e-b73a-9b1070b820aa', 'signage_item', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.580328+00', '2026-10-09 13:48:11.580328+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7fb1049e-e7e5-425c-bd52-303c62c9f943', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('f93ddb9b-db3d-43fc-b81b-cd5bbfd175b7', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('eb631cd1-1d96-46a4-81a0-7aecf8273a79', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('71da521a-ff6a-49c6-a32f-6d2ffa456b4e', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d0186b6a-fd22-442f-a22e-538a19b0b2e8', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('74994bd4-8396-427e-9213-5d4053f3b892', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b56accc8-0bbc-4dff-9441-1e1ed65d89da', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2b02d23e-adb5-49b5-98c6-eb0bcaebe105', 'signage_item', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.642426+00', '2026-10-09 13:48:11.642426+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('549c2142-ade0-46bc-a390-d31b5e36d2bb', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('ff9ef311-386f-4d08-83ac-2a1bcde334ef', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('5f359619-b452-443e-85ea-cc5dfde67847', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('f6e4a071-885b-4487-bdec-82b8dd6937f1', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-06 13:48:10.74+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-13 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5eed1349-a3c4-49be-ae9e-eb23cefbde02', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('ec91e505-688b-4ae9-bd8c-04ff89c85071', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-06 13:48:10.74+00', '2026-10-08 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('775b1cd7-2f7f-465d-851c-0de6f4320fa4', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('29c97905-e0b0-442f-aa82-29a242fc1000', 'signage_item', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.665249+00', '2026-10-09 13:48:11.665249+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('949a725d-e92e-41c0-b5b8-35dc6da4c87c', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, 'b0f51330-e18b-4aa2-a20e-6f057e1cfa50', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 3, false, 'fec6133b-00d3-4360-ac04-34e473870a48', NULL);
INSERT INTO public.approval_instances VALUES ('6a46845e-862f-44ab-b0ed-1f7571ec7938', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, '159f93d1-e469-46de-852f-e328c5e283cc', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 3, false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', NULL);
INSERT INTO public.approval_instances VALUES ('61b31819-02e3-4cb1-8d4d-2f0815384608', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, 'e4f35ab3-455b-4f19-b995-a9ad50cc51ca', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-04 13:48:10.74+00', '2026-10-09 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 5, false, '39cad744-d0b7-4660-bf4b-b8c870b2a346', NULL);
INSERT INTO public.approval_instances VALUES ('6f5cf100-4579-468d-9173-a539c8375e6c', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, '73a8f620-8898-4960-b63a-47b1c17ccb38', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3955186a-0b2a-49de-abf4-65da741f9181', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, '15fc4233-f82f-4756-b264-ea7ff66f010d', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 3, false, 'f5073613-7428-424a-9003-573f52fa3e5c', NULL);
INSERT INTO public.approval_instances VALUES ('97b33a36-458e-40ab-b1f8-047404ddd487', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, 'e66dbe1b-1da7-43a5-a956-ce621f1c987e', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('01c9a8c3-3e52-4567-bf08-b6c144c8fe0c', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, 'd0fdc706-96de-4063-b457-e86dbe95b8f0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('95809377-a0b8-4bba-b705-001d1b412b17', 'signage_item', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, '34d05e18-ca4a-4983-8fb8-759c568913cc', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.690331+00', '2026-10-09 13:48:11.690331+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ac73e57f-6dee-4dd8-9a56-518a25260ec5', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, '410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-03 13:48:10.74+00', '2026-10-06 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('26ab5041-834f-433c-a51c-789213449d70', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, '2efd9e43-9914-4900-9ad4-17652c7508cb', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-05 13:48:10.74+00', '2026-10-12 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fb1499cf-4a5e-4463-a786-b547047e993e', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, '7170ad22-0bf4-40ce-85ae-d2bbc867221b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5e077e32-a733-4b85-84de-af676007fdec', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, '0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('46fd3875-6a47-4033-af04-3a2be13224c4', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, 'ff3be54d-0f57-4d89-903f-40c25c46c68e', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f6f4a88d-9e06-4e62-9a2a-22b55809e5f3', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 1, 'a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f2bef448-2245-4d2a-be3a-1d4391f48284', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, '410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-03 13:48:10.74+00', '2026-10-06 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e2b7ad59-cae3-4749-ab6b-d7612dc86511', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, '2efd9e43-9914-4900-9ad4-17652c7508cb', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5b82fe1b-3fb0-4169-aab3-b1dd3f87a32a', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, '7170ad22-0bf4-40ce-85ae-d2bbc867221b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e23bd3ea-4e9b-43da-b890-325c58246e7b', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, '0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0c56c680-60fc-4ca0-bb9e-939c3ffe40e4', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, 'ff3be54d-0f57-4d89-903f-40c25c46c68e', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e6e894e4-3c98-4315-99e9-bf2064247a76', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 1, 'a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a120bb5f-9d0c-43c6-93ef-b2d9545c9c1f', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, '410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-03 13:48:10.74+00', '2026-10-06 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fd15903d-adb4-4bbf-ab81-76ca52d0c25b', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, '2efd9e43-9914-4900-9ad4-17652c7508cb', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('adf72eca-fb09-4480-a6aa-65d8a4a4e7b2', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, '7170ad22-0bf4-40ce-85ae-d2bbc867221b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4c8c3cfc-8b9d-411d-b860-99d77d3078f9', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, '0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c8ad5a3a-82c2-4946-bd55-9c4bd0bb4a9c', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, 'ff3be54d-0f57-4d89-903f-40c25c46c68e', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('147af1d1-cdca-4808-8916-7f726c0ef199', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 1, 'a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e0f8e016-bffc-45d5-ad06-799c96f5a927', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, '410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-03 13:48:10.74+00', '2026-10-06 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c025bfb2-7e49-423a-89ad-420b88cff359', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, '2efd9e43-9914-4900-9ad4-17652c7508cb', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('23c50f78-ff5a-477a-8de2-e36c4e5926cd', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, '7170ad22-0bf4-40ce-85ae-d2bbc867221b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-10 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6ee99d5e-adda-4836-998d-83d374d29d64', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, '0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-12 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2928b36d-d6b5-4a1c-8268-61a298da2506', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, 'ff3be54d-0f57-4d89-903f-40c25c46c68e', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9b5c9bd9-839b-460c-9505-0629a77c4ded', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 1, 'a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-05 13:48:10.74+00', NULL, 0, NULL, NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('eb7409d2-d398-446f-9f7a-899574a5efae', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, '410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-03 13:48:10.74+00', '2026-10-06 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('334dcc2f-d740-4ca9-87e0-b72da8c7aa6a', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, '2efd9e43-9914-4900-9ad4-17652c7508cb', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6aa18764-91f3-4a94-be3a-13fb8ed7a51b', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, '7170ad22-0bf4-40ce-85ae-d2bbc867221b', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-10 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6dd6cd75-1d4c-4fc4-8b10-93ab7f343842', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, '0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-12 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7dbe6540-ed0a-412f-b912-5b1ac9a74ed8', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, 'ff3be54d-0f57-4d89-903f-40c25c46c68e', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-05 13:48:10.74+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-05 13:48:10.74+00', '2026-10-07 13:48:10.74+00', 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9e1c2b67-0421-4533-be84-5e2b9f5f1cc0', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 1, 'a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-05 13:48:10.74+00', NULL, 0, NULL, NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('baf231d7-6f76-4fe0-a05d-306ae0026e19', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'fec6133b-00d3-4360-ac04-34e473870a48', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-09 13:48:10.961135+00', '2026-10-09 13:48:10.961135+00');
INSERT INTO public.approvers VALUES ('7a3f350c-22b0-4956-ac70-8132869e324a', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'b273ccad-c56e-4b0b-ae8c-48abb70321e1', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-09 13:48:10.966408+00', '2026-10-09 13:48:10.966408+00');
INSERT INTO public.approvers VALUES ('a2141035-1bb7-4883-b073-d7af2845f6a5', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '39cad744-d0b7-4660-bf4b-b8c870b2a346', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-09 13:48:10.971864+00', '2026-10-09 13:48:10.971864+00');
INSERT INTO public.approvers VALUES ('efcf0fc5-817c-4949-ab69-6c75fa2b4650', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'f5073613-7428-424a-9003-573f52fa3e5c', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-09 13:48:10.975837+00', '2026-10-09 13:48:10.975837+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('0447826f-cd1a-4f72-9a1d-f5d293e4dace', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.123116+00', '2026-10-09 13:48:11.123116+00');
INSERT INTO public.artwork_versions VALUES ('da1d0e1f-6358-4fd7-a3a3-add0af7ae168', '450fd633-39dd-49ae-b2f4-098234c983a5', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.155967+00', '2026-10-09 13:48:11.155967+00');
INSERT INTO public.artwork_versions VALUES ('73bd9803-e676-4d14-b0b0-5f090b9d97f7', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-09 13:48:11.186895+00', '2026-10-09 13:48:11.186895+00');
INSERT INTO public.artwork_versions VALUES ('4b73597a-68cd-4a5f-97fb-d4b6cd284eab', '3b19ec99-2cbf-400a-9b3a-4f614872bba1', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.189513+00', '2026-10-09 13:48:11.189513+00');
INSERT INTO public.artwork_versions VALUES ('ce446612-bd3a-4e21-990f-a6c90442c990', 'c2175d09-20c8-4676-8257-5f29f1f87916', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.221132+00', '2026-10-09 13:48:11.221132+00');
INSERT INTO public.artwork_versions VALUES ('f6e0de46-8acf-4e7f-8093-1586c1f895a3', '2d54ec06-a0c8-4a3b-be69-e64f59f05e68', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.251308+00', '2026-10-09 13:48:11.251308+00');
INSERT INTO public.artwork_versions VALUES ('9ebc022c-1049-49a7-a20e-36084b8ea892', '759638b7-d8e2-46fd-a4bc-38d5314fc635', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.278456+00', '2026-10-09 13:48:11.278456+00');
INSERT INTO public.artwork_versions VALUES ('86c3e251-a126-4d70-b6d5-fa83f37fb138', '867ee9ff-905d-4d49-b50d-f55564e798b6', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.302226+00', '2026-10-09 13:48:11.302226+00');
INSERT INTO public.artwork_versions VALUES ('da3ff179-a095-41af-a424-a726003a65e9', '030dacbb-8128-4829-8629-6143d28ebfa2', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.324417+00', '2026-10-09 13:48:11.324417+00');
INSERT INTO public.artwork_versions VALUES ('3ae2e66c-c4ff-49d0-8e40-5e6b97ea0249', 'b9848622-6748-4487-8fd8-38f7608195ff', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.353133+00', '2026-10-09 13:48:11.353133+00');
INSERT INTO public.artwork_versions VALUES ('e18887c5-4d3d-4040-83d5-c9044bbe528a', '4730e624-9a82-45ee-ad4f-998e75e48858', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.375063+00', '2026-10-09 13:48:11.375063+00');
INSERT INTO public.artwork_versions VALUES ('c0a14416-e3ac-45e0-a17a-010e25944f80', 'e360fa9d-79de-486d-9021-16e27e75eca3', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.399265+00', '2026-10-09 13:48:11.399265+00');
INSERT INTO public.artwork_versions VALUES ('b5aabf95-afd4-40e1-91bd-ee59e49b58e1', '4563d353-3e13-4d5b-b51e-a516fb5b5014', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.418347+00', '2026-10-09 13:48:11.418347+00');
INSERT INTO public.artwork_versions VALUES ('1810f42b-9415-46bd-a2ce-ae11b188765c', '7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.435177+00', '2026-10-09 13:48:11.435177+00');
INSERT INTO public.artwork_versions VALUES ('b008912c-cefe-48d4-8426-a80644310f84', 'd1626922-8b03-4cfd-a08f-c97d3df5c297', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.452601+00', '2026-10-09 13:48:11.452601+00');
INSERT INTO public.artwork_versions VALUES ('4c85074a-5772-418c-ad99-09a9ff75086d', '7faf4764-2a67-4aca-8802-972557c7b04f', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.471614+00', '2026-10-09 13:48:11.471614+00');
INSERT INTO public.artwork_versions VALUES ('3281914a-565b-4fae-af36-3f8d05c6fe4f', '280173b7-7b35-433e-a8ae-a003e4d8e574', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.502836+00', '2026-10-09 13:48:11.502836+00');
INSERT INTO public.artwork_versions VALUES ('072e39e0-f90a-408f-bcb7-0f84e71d6b00', 'cf056985-7382-48e6-be23-2ddcb12f12b9', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.526389+00', '2026-10-09 13:48:11.526389+00');
INSERT INTO public.artwork_versions VALUES ('a8773538-091a-45b0-8147-a651621da24a', '04846bd2-7223-4aff-bcc5-b970cd5f17ff', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.552483+00', '2026-10-09 13:48:11.552483+00');
INSERT INTO public.artwork_versions VALUES ('6eeb9b86-086a-4ba6-aa8c-b6bf7e6ed5e8', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-09 13:48:11.574649+00', '2026-10-09 13:48:11.574649+00');
INSERT INTO public.artwork_versions VALUES ('338c480e-b9bc-4943-b97e-793705b4e508', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-09 13:48:11.576091+00', '2026-10-09 13:48:11.576091+00');
INSERT INTO public.artwork_versions VALUES ('493461d0-af67-42c5-88b6-2c6f395bdd62', 'b5ff6394-e557-43ea-b48f-b52fc496e125', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.577353+00', '2026-10-09 13:48:11.577353+00');
INSERT INTO public.artwork_versions VALUES ('e04881c6-d765-4371-a594-21490c119d34', '33dfbb9e-5cee-43dd-a531-39e78e4bd096', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-09 13:48:11.639266+00', '2026-10-09 13:48:11.639266+00');
INSERT INTO public.artwork_versions VALUES ('82ebe6a6-10bb-44a6-a56b-7838cf6a1b60', 'd7741809-285d-4265-8ae9-37753dc74e26', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.662541+00', '2026-10-09 13:48:11.662541+00');
INSERT INTO public.artwork_versions VALUES ('0eca2b04-9a63-4769-aaaf-09ce28f030ed', '43e7274e-028c-46f4-a1be-fda37e4883f0', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-09 13:48:11.687384+00', '2026-10-09 13:48:11.687384+00');


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

INSERT INTO public.contractors VALUES ('9555d72b-c450-4297-bd99-24455c83141e', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-09 13:48:10.918494+00', '2026-10-09 13:48:10.918494+00');
INSERT INTO public.contractors VALUES ('eb5b89b8-5032-4be0-b3ba-31701702c3fe', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-09 13:48:10.921283+00', '2026-10-09 13:48:10.921283+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('fec6133b-00d3-4360-ac04-34e473870a48', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-09 13:48:10.957597+00', '2026-10-09 13:48:10.957597+00');
INSERT INTO public.departments VALUES ('b273ccad-c56e-4b0b-ae8c-48abb70321e1', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-09 13:48:10.96438+00', '2026-10-09 13:48:10.96438+00');
INSERT INTO public.departments VALUES ('39cad744-d0b7-4660-bf4b-b8c870b2a346', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Sales', 3, false, '{sponsor}', false, '2026-10-09 13:48:10.969662+00', '2026-10-09 13:48:10.969662+00');
INSERT INTO public.departments VALUES ('f5073613-7428-424a-9003-573f52fa3e5c', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-09 13:48:10.97407+00', '2026-10-09 13:48:10.97407+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('fb05397d-9004-45fc-8771-f0cb0f5b1e54', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00');
INSERT INTO public.documents VALUES ('a1dcfd09-c7b3-429b-ae08-95c77eb1bc2c', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00');
INSERT INTO public.documents VALUES ('e2842139-144e-403a-9d76-f76a442725e3', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00');
INSERT INTO public.documents VALUES ('c5158aca-5142-4cef-8db5-f189f97e710e', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '655cf663-c074-4734-b667-02b0aea41d19', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00');
INSERT INTO public.documents VALUES ('059fe6f4-903d-45b1-94fd-57c3e647cfaf', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00');
INSERT INTO public.documents VALUES ('ce71aacb-e19d-4253-a4b7-3c929c39f9fc', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00');
INSERT INTO public.documents VALUES ('dea420db-0280-401d-9600-d17a0c703684', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00');
INSERT INTO public.documents VALUES ('5760de16-2e19-40eb-9673-d1e5fdd3ca24', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '2f120370-cf83-4f13-bd16-cafb76876f73', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00');
INSERT INTO public.documents VALUES ('10dd4fcb-f6f0-4e89-8303-be11006ecacf', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00');
INSERT INTO public.documents VALUES ('26965e80-8ea7-442b-8291-40e4e2f303e0', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00');
INSERT INTO public.documents VALUES ('d844c48b-9b2f-4207-ad8c-abf4d866ac32', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00');
INSERT INTO public.documents VALUES ('12ea5725-6573-4cca-a2df-bd2f496d9885', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '8ba26d67-f577-4337-92ad-4676a60dfb62', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00');
INSERT INTO public.documents VALUES ('386d17fe-f21b-494f-ac65-76fb410c7b4b', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00');
INSERT INTO public.documents VALUES ('881f1fb6-83c2-47e5-bd31-96a358857727', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00');
INSERT INTO public.documents VALUES ('96403690-6bab-47df-ba36-86d4a9e55f66', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00');
INSERT INTO public.documents VALUES ('2d4a318c-38c7-45de-ad70-e4be3ff347d5', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', 'b6d25fee-f0ab-4949-83d3-b71f8c5e0000', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00');
INSERT INTO public.documents VALUES ('2a0e339e-6036-4ea2-8de7-c5bf52b1b5d4', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00');
INSERT INTO public.documents VALUES ('6fa6de30-67fe-4591-85a9-213e32d1ac6e', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00');
INSERT INTO public.documents VALUES ('c6f4d39a-2ab8-4b92-94b5-3b1ffb4d80d7', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00');
INSERT INTO public.documents VALUES ('0ed7cc22-4ad3-4044-bac8-fd29be3c6238', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_submission', '6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('df7d419d-2a88-4543-9b60-ffd77e71f754', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'signage', 34, '2026-10-09 13:48:11.713612+00', '2026-10-09 13:48:11.71537+00');
INSERT INTO public.edition_counters VALUES ('4c306222-894e-4a29-a399-db209921fe43', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_design', 1, '2026-10-09 13:48:11.74532+00', '2026-10-09 13:48:11.74532+00');
INSERT INTO public.edition_counters VALUES ('5d20570f-2808-48e3-962c-48c0c6aac022', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_item', 1, '2026-10-09 13:48:11.74532+00', '2026-10-09 13:48:11.74532+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('802df4cd-c305-4cde-9429-ad9f85c050fd', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-09 13:48:10.846539+00', '2026-10-09 13:48:10.846539+00');
INSERT INTO public.edition_deadlines VALUES ('d99959d9-0362-44e0-a951-217bc544f374', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-09 13:48:10.848269+00', '2026-10-09 13:48:10.848269+00');
INSERT INTO public.edition_deadlines VALUES ('db7a1855-338a-43e2-971c-5fa8440d5a41', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-09 13:48:10.849466+00', '2026-10-09 13:48:10.849466+00');
INSERT INTO public.edition_deadlines VALUES ('759000f7-6b35-4c33-950c-3aa0d3e4d892', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-09 13:48:10.850747+00', '2026-10-09 13:48:10.850747+00');
INSERT INTO public.edition_deadlines VALUES ('a42ba33a-b326-49a8-b8dc-5e5b3eefd789', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-09 13:48:10.852089+00', '2026-10-09 13:48:10.852089+00');
INSERT INTO public.edition_deadlines VALUES ('e32eefaa-5da8-4b0f-8798-dedaf77a854e', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-09 13:48:10.853268+00', '2026-10-09 13:48:10.853268+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'cb69dd55-7125-4044-a6dd-359db70f1e65', '9e81670d-3888-456c-a8e2-712f7f989995', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-09 13:48:10.843891+00', '2026-10-09 13:48:10.843891+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('cb69dd55-7125-4044-a6dd-359db70f1e65', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'UK Construction Week', 'UKCW', '2026-10-09 13:48:10.813108+00', '2026-10-09 13:48:10.813108+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('4da7198b-0656-4e23-bd0b-0147b96a3a3b', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Exhibitor Co', 'A10', 'e17730c6-2402-4825-a44c-00861567e199', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '9555d72b-c450-4297-bd99-24455c83141e', '2026-10-09 13:48:11.050797+00', '2026-10-09 13:48:11.050797+00');
INSERT INTO public.exhibitors VALUES ('8d9f98d9-334c-413c-80b0-729a368e4114', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SteelFrame Systems', 'A20', 'e17730c6-2402-4825-a44c-00861567e199', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', '2026-10-09 13:48:11.054413+00', '2026-10-09 13:48:11.054413+00');
INSERT INTO public.exhibitors VALUES ('1971867e-dcae-41af-97de-74577a59f1d9', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'BrickWorks UK', 'A30', 'e17730c6-2402-4825-a44c-00861567e199', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '9555d72b-c450-4297-bd99-24455c83141e', '2026-10-09 13:48:11.057384+00', '2026-10-09 13:48:11.057384+00');
INSERT INTO public.exhibitors VALUES ('f31cb5ce-6c81-452d-894a-203f0d35ad2d', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Timber Trade Ltd', 'B10', 'e17730c6-2402-4825-a44c-00861567e199', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', '2026-10-09 13:48:11.061555+00', '2026-10-09 13:48:11.061555+00');
INSERT INTO public.exhibitors VALUES ('7a20f232-9005-4a6a-90c0-1b758006028d', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'GlassTech', 'B20', 'e17730c6-2402-4825-a44c-00861567e199', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '9555d72b-c450-4297-bd99-24455c83141e', '2026-10-09 13:48:11.06531+00', '2026-10-09 13:48:11.06531+00');
INSERT INTO public.exhibitors VALUES ('552dfcd4-14ba-4232-b960-abfbbe467d06', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Insulate Pro', 'B30', 'e17730c6-2402-4825-a44c-00861567e199', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', '2026-10-09 13:48:11.067793+00', '2026-10-09 13:48:11.067793+00');
INSERT INTO public.exhibitors VALUES ('aba30abf-8133-46cb-8a94-7bd49a066111', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'RoofRight', 'C10', '3f25ae72-4ac3-48b2-b541-57fe29274185', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '9555d72b-c450-4297-bd99-24455c83141e', '2026-10-09 13:48:11.070253+00', '2026-10-09 13:48:11.070253+00');
INSERT INTO public.exhibitors VALUES ('4b842305-091c-474a-8a06-26e2fde4f25e', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'PlantHire Direct', 'C20', '3f25ae72-4ac3-48b2-b541-57fe29274185', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', '2026-10-09 13:48:11.072507+00', '2026-10-09 13:48:11.072507+00');
INSERT INTO public.exhibitors VALUES ('af3b52fe-e0d5-4cb2-9773-c22d1972abfc', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SafetyFirst PPE', 'D10', '3f25ae72-4ac3-48b2-b541-57fe29274185', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-09 13:48:11.095973+00', '2026-10-09 13:48:11.095973+00');
INSERT INTO public.exhibitors VALUES ('0dc10db9-bda4-4897-b2c4-b2f88046af27', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'ToolMart Retail', 'D20', '3f25ae72-4ac3-48b2-b541-57fe29274185', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-09 13:48:11.104954+00', '2026-10-09 13:48:11.104954+00');
INSERT INTO public.exhibitors VALUES ('dec673ba-3d88-488f-8b68-552c290ee6c7', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'EcoBuild Materials', 'D30', '3f25ae72-4ac3-48b2-b541-57fe29274185', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-09 13:48:11.107813+00', '2026-10-09 13:48:11.107813+00');
INSERT INTO public.exhibitors VALUES ('649ab2db-c645-46fb-8701-a905e86addbe', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SiteWise Software', 'D40', '3f25ae72-4ac3-48b2-b541-57fe29274185', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-09 13:48:11.11037+00', '2026-10-09 13:48:11.11037+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('859c372c-4aea-4258-b96d-59a8694ab3e0', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'venue', 'venue', '9e81670d-3888-456c-a8e2-712f7f989995', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.030149+00', '2026-10-09 13:48:11.030149+00');
INSERT INTO public.external_grants VALUES ('ce186c08-434b-4fa4-a83d-634c6b164ea5', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.033996+00', '2026-10-09 13:48:11.033996+00');
INSERT INTO public.external_grants VALUES ('cbe42bd8-a80d-4f3c-a1d9-fe880a73f21c', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.040245+00', '2026-10-09 13:48:11.040245+00');
INSERT INTO public.external_grants VALUES ('79f12ffa-139f-4b38-8ed2-502d5b427d12', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'supplier', 'supplier', '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.044123+00', '2026-10-09 13:48:11.044123+00');
INSERT INTO public.external_grants VALUES ('f64b6941-84b6-44b6-851f-cccdf1d694ec', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'sponsor', 'sponsor', '9ebe2395-4c98-47be-8356-f91c4ec322ca', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.047649+00', '2026-10-09 13:48:11.047649+00');
INSERT INTO public.external_grants VALUES ('865d754c-89c5-4d5e-a1db-acc0933bc699', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'exhibitor', 'exhibitor', '4da7198b-0656-4e23-bd0b-0147b96a3a3b', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-09 13:48:10.74+00', NULL, '2026-10-09 13:48:11.113652+00', '2026-10-09 13:48:11.113652+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('e17730c6-2402-4825-a44c-00861567e199', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-09 13:48:10.855724+00', '2026-10-09 13:48:10.855724+00');
INSERT INTO public.halls VALUES ('3f25ae72-4ac3-48b2-b541-57fe29274185', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-09 13:48:10.858175+00', '2026-10-09 13:48:10.858175+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('24fd38db-891e-4640-a97b-60dcda34f47d', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Hanging banner', 'hanging_banner', '0472f3db-c181-4c52-95e0-45247331fdcb', 'rigged', true, 0, '2026-10-09 13:48:11.002629+00', '2026-10-09 13:48:11.002629+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('050bae4e-40c1-4dd5-9a09-45b71583bcd4', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Foamex board', 'foamex_board', '0472f3db-c181-4c52-95e0-45247331fdcb', 'wall_mounted', false, 1, '2026-10-09 13:48:11.004779+00', '2026-10-09 13:48:11.004779+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3cd3fb44-51c9-403f-b67f-e43fdebf88f2', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Fabric graphic', 'fabric_graphic', '0472f3db-c181-4c52-95e0-45247331fdcb', 'shell_mounted', false, 2, '2026-10-09 13:48:11.006371+00', '2026-10-09 13:48:11.006371+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('4f48840a-3d38-4033-a5e7-6b13c0ef587a', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Floor vinyl', 'floor_vinyl', '0472f3db-c181-4c52-95e0-45247331fdcb', 'floor', false, 3, '2026-10-09 13:48:11.007818+00', '2026-10-09 13:48:11.007818+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('010672d5-b489-470c-b541-bf6c867e14d2', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Aisle sign', 'aisle_sign', '0472f3db-c181-4c52-95e0-45247331fdcb', 'rigged', true, 4, '2026-10-09 13:48:11.009065+00', '2026-10-09 13:48:11.009065+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('997c0294-4feb-4442-9d54-fe3f550f0b48', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Entrance feature', 'entrance_feature', '0472f3db-c181-4c52-95e0-45247331fdcb', 'freestanding', true, 5, '2026-10-09 13:48:11.01028+00', '2026-10-09 13:48:11.01028+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('06a0e238-1d49-4521-b26f-50bab173c772', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Registration', 'registration', '0472f3db-c181-4c52-95e0-45247331fdcb', 'freestanding', false, 6, '2026-10-09 13:48:11.011617+00', '2026-10-09 13:48:11.011617+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('16711f95-0718-4f5f-bf80-ef3b31444ab8', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Seminar theatre', 'seminar_theatre', '0472f3db-c181-4c52-95e0-45247331fdcb', 'freestanding', false, 7, '2026-10-09 13:48:11.012886+00', '2026-10-09 13:48:11.012886+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('5230ab9e-ac59-433b-886c-e6034ce071ea', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Feature area', 'feature_area', '0472f3db-c181-4c52-95e0-45247331fdcb', 'freestanding', false, 8, '2026-10-09 13:48:11.014446+00', '2026-10-09 13:48:11.014446+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e9cdb3d4-6640-4916-98ad-c2096000c7f2', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'External', 'external', '0472f3db-c181-4c52-95e0-45247331fdcb', 'freestanding', true, 9, '2026-10-09 13:48:11.015902+00', '2026-10-09 13:48:11.015902+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a6422c2a-c739-44ca-8952-c9956a2e25f4', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Digital screen', 'digital_screen', '0472f3db-c181-4c52-95e0-45247331fdcb', 'digital', false, 10, '2026-10-09 13:48:11.017298+00', '2026-10-09 13:48:11.017298+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('c67f3178-f7c4-4126-98cc-9e2401efcee0', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Branded lanyards', 'lanyard', '0472f3db-c181-4c52-95e0-45247331fdcb', NULL, false, 11, '2026-10-09 13:48:11.01917+00', '2026-10-09 13:48:11.01917+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('b69f7558-b2de-489f-a995-5636882226a4', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Show bags', 'show_bag', '0472f3db-c181-4c52-95e0-45247331fdcb', NULL, false, 12, '2026-10-09 13:48:11.020793+00', '2026-10-09 13:48:11.020793+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('54453ef5-c6d1-458e-ada9-71f1c3e6cfbe', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Registration branding', 'reg_branding', '0472f3db-c181-4c52-95e0-45247331fdcb', NULL, false, 13, '2026-10-09 13:48:11.022102+00', '2026-10-09 13:48:11.022102+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('f61f4ea2-b142-4a29-b716-9394161f669e', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Other signage', 'other_signage', '0472f3db-c181-4c52-95e0-45247331fdcb', NULL, false, 14, '2026-10-09 13:48:11.024268+00', '2026-10-09 13:48:11.024268+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('6a404c48-42ef-40d9-b11c-a4aab217116d', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Other sponsorship item', 'other_sponsorship', '0472f3db-c181-4c52-95e0-45247331fdcb', NULL, false, 15, '2026-10-09 13:48:11.025836+00', '2026-10-09 13:48:11.025836+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('067bf810-ae71-4264-b7ea-4355b81e3e95', 'e17730c6-2402-4825-a44c-00861567e199', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-09 13:48:10.86066+00', '2026-10-09 13:48:10.86066+00');
INSERT INTO public.locations VALUES ('94e4e6f8-edc7-4e80-9134-80fec289e572', 'e17730c6-2402-4825-a44c-00861567e199', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-09 13:48:10.863006+00', '2026-10-09 13:48:10.863006+00');
INSERT INTO public.locations VALUES ('c8e8fa09-f39a-4224-8d93-12288ed192ab', 'e17730c6-2402-4825-a44c-00861567e199', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-09 13:48:10.865022+00', '2026-10-09 13:48:10.865022+00');
INSERT INTO public.locations VALUES ('4ef47dfc-593b-4cd3-8996-8ee6ff4d4d96', 'e17730c6-2402-4825-a44c-00861567e199', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-09 13:48:10.867161+00', '2026-10-09 13:48:10.867161+00');
INSERT INTO public.locations VALUES ('7601afb5-4da6-49b5-867a-7124165819a8', 'e17730c6-2402-4825-a44c-00861567e199', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-09 13:48:10.869315+00', '2026-10-09 13:48:10.869315+00');
INSERT INTO public.locations VALUES ('4dfbae37-3aba-41de-8cb9-25c0cf9e17ad', 'e17730c6-2402-4825-a44c-00861567e199', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-09 13:48:10.871872+00', '2026-10-09 13:48:10.871872+00');
INSERT INTO public.locations VALUES ('79624991-57cf-4454-80e2-4b4a2e52691c', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-09 13:48:10.874396+00', '2026-10-09 13:48:10.874396+00');
INSERT INTO public.locations VALUES ('2eb1aafa-2dad-4ac7-ba66-8b8e0f91fdce', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-09 13:48:10.876601+00', '2026-10-09 13:48:10.876601+00');
INSERT INTO public.locations VALUES ('6d70ccd1-42eb-4310-b522-86ef14a31eac', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-09 13:48:10.878819+00', '2026-10-09 13:48:10.878819+00');
INSERT INTO public.locations VALUES ('8bc91e36-62e8-488a-b144-a5cbb97491c5', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-09 13:48:10.880798+00', '2026-10-09 13:48:10.880798+00');
INSERT INTO public.locations VALUES ('e9977813-3f76-4f5e-b08b-2a583d6f41a0', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-09 13:48:10.883193+00', '2026-10-09 13:48:10.883193+00');
INSERT INTO public.locations VALUES ('e6649bfe-57d5-4520-89bf-f3e753427345', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-09 13:48:10.886371+00', '2026-10-09 13:48:10.886371+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('09763dde-aa9a-4217-bd4a-54a8ea4d999f', '00000000-0000-4000-8000-000000000001', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'admin', '2026-10-09 13:48:10.794109+00', '2026-10-09 13:48:10.794109+00', '{}');
INSERT INTO public.memberships VALUES ('e658a8f7-1874-4be8-8f3c-19c878f1d824', '00000000-0000-4000-8000-000000000002', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'ops', '2026-10-09 13:48:10.798402+00', '2026-10-09 13:48:10.798402+00', '{}');
INSERT INTO public.memberships VALUES ('93f4829d-65b2-4087-b5ff-18760f3d4738', '00000000-0000-4000-8000-000000000004', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'sales', '2026-10-09 13:48:10.805715+00', '2026-10-09 13:48:10.805715+00', '{}');
INSERT INTO public.memberships VALUES ('dcb19671-fd05-4654-9bc5-e035f70a7cc2', '00000000-0000-4000-8000-000000000005', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'event_director', '2026-10-09 13:48:10.809117+00', '2026-10-09 13:48:10.809117+00', '{}');
INSERT INTO public.memberships VALUES ('605d3153-ebb0-4e16-968a-612d6daa94a2', '00000000-0000-4000-8000-000000000006', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'viewer', '2026-10-09 13:48:10.81163+00', '2026-10-09 13:48:10.81163+00', '{}');
INSERT INTO public.memberships VALUES ('f5cbd0a6-4139-4612-bee6-8dfb42e6f336', '00000000-0000-4000-8000-000000000003', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'marketing', '2026-10-09 13:48:10.802822+00', '2026-10-09 13:48:11.83825+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-09 13:48:10.787241+00', '2026-10-09 13:48:10.787241+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('f134bc58-34c0-49e7-9f8d-e8830c12c7ed', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '997c0294-4feb-4442-9d54-fe3f550f0b48', 'e17730c6-2402-4825-a44c-00861567e199', '067bf810-ae71-4264-b7ea-4355b81e3e95', 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', '86f13d12-f4b8-49f3-b7f9-d884d15cd233', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '0447826f-cd1a-4f72-9a1d-f5d293e4dace', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.119212+00', '2026-10-09 13:48:11.127271+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('450fd633-39dd-49ae-b2f4-098234c983a5', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '06a0e238-1d49-4521-b26f-50bab173c772', 'e17730c6-2402-4825-a44c-00861567e199', '94e4e6f8-edc7-4e80-9134-80fec289e572', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'da1d0e1f-6358-4fd7-a3a3-add0af7ae168', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.152766+00', '2026-10-09 13:48:11.157861+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3b19ec99-2cbf-400a-9b3a-4f614872bba1', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '24fd38db-891e-4640-a97b-60dcda34f47d', 'e17730c6-2402-4825-a44c-00861567e199', 'c8e8fa09-f39a-4224-8d93-12288ed192ab', 'ops', '00000000-0000-4000-8000-000000000002', '9ebe2395-4c98-47be-8356-f91c4ec322ca', '41c6f1cd-df2b-41e1-9ac2-3bd3e7a813b3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '4b73597a-68cd-4a5f-97fb-d4b6cd284eab', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.183174+00', '2026-10-09 13:48:11.191338+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c2175d09-20c8-4676-8257-5f29f1f87916', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '16711f95-0718-4f5f-bf80-ef3b31444ab8', 'e17730c6-2402-4825-a44c-00861567e199', '4ef47dfc-593b-4cd3-8996-8ee6ff4d4d96', 'marketing', '00000000-0000-4000-8000-000000000003', '21fb8b79-c72e-44c6-973d-98396bdc1d1d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'ce446612-bd3a-4e21-990f-a6c90442c990', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.217649+00', '2026-10-09 13:48:11.223157+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2d54ec06-a0c8-4a3b-be69-e64f59f05e68', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '4f48840a-3d38-4033-a5e7-6b13c0ef587a', 'e17730c6-2402-4825-a44c-00861567e199', '7601afb5-4da6-49b5-867a-7124165819a8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'f6e0de46-8acf-4e7f-8093-1586c1f895a3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.247695+00', '2026-10-09 13:48:11.253425+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('759638b7-d8e2-46fd-a4bc-38d5314fc635', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '5230ab9e-ac59-433b-886c-e6034ce071ea', 'e17730c6-2402-4825-a44c-00861567e199', '4dfbae37-3aba-41de-8cb9-25c0cf9e17ad', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '9ebc022c-1049-49a7-a20e-36084b8ea892', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.275409+00', '2026-10-09 13:48:11.279837+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "15fc4233-f82f-4756-b264-ea7ff66f010d", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('867ee9ff-905d-4d49-b50d-f55564e798b6', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '24fd38db-891e-4640-a97b-60dcda34f47d', '3f25ae72-4ac3-48b2-b541-57fe29274185', '79624991-57cf-4454-80e2-4b4a2e52691c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '86c3e251-a126-4d70-b6d5-fa83f37fb138', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.299297+00', '2026-10-09 13:48:11.303852+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('030dacbb-8128-4829-8629-6143d28ebfa2', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '010672d5-b489-470c-b541-bf6c867e14d2', '3f25ae72-4ac3-48b2-b541-57fe29274185', '2eb1aafa-2dad-4ac7-ba66-8b8e0f91fdce', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'da3ff179-a095-41af-a424-a726003a65e9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.321627+00', '2026-10-09 13:48:11.326552+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b9848622-6748-4487-8fd8-38f7608195ff', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '16711f95-0718-4f5f-bf80-ef3b31444ab8', '3f25ae72-4ac3-48b2-b541-57fe29274185', '6d70ccd1-42eb-4310-b522-86ef14a31eac', 'marketing', '00000000-0000-4000-8000-000000000003', '21fb8b79-c72e-44c6-973d-98396bdc1d1d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '3ae2e66c-c4ff-49d0-8e40-5e6b97ea0249', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.350318+00', '2026-10-09 13:48:11.354866+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4730e624-9a82-45ee-ad4f-998e75e48858', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '3cd3fb44-51c9-403f-b67f-e43fdebf88f2', '3f25ae72-4ac3-48b2-b541-57fe29274185', '8bc91e36-62e8-488a-b144-a5cbb97491c5', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'e18887c5-4d3d-4040-83d5-c9044bbe528a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.372844+00', '2026-10-09 13:48:11.376488+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e360fa9d-79de-486d-9021-16e27e75eca3', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'e9cdb3d4-6640-4916-98ad-c2096000c7f2', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e9977813-3f76-4f5e-b08b-2a583d6f41a0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'c0a14416-e3ac-45e0-a17a-010e25944f80', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.396646+00', '2026-10-09 13:48:11.401053+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4563d353-3e13-4d5b-b51e-a516fb5b5014', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e6649bfe-57d5-4520-89bf-f3e753427345', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'b5aabf95-afd4-40e1-91bd-ee59e49b58e1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.416202+00', '2026-10-09 13:48:11.419517+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7c7a7fae-3cc9-448f-ae9f-5a1aea82323f', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'a6422c2a-c739-44ca-8952-c9956a2e25f4', 'e17730c6-2402-4825-a44c-00861567e199', '94e4e6f8-edc7-4e80-9134-80fec289e572', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, 'd494988d-5ee0-495a-ac87-5af6943d98c0', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '1810f42b-9415-46bd-a2ce-ae11b188765c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.432528+00', '2026-10-09 13:48:11.436411+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "15fc4233-f82f-4756-b264-ea7ff66f010d", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d1626922-8b03-4cfd-a08f-c97d3df5c297', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '010672d5-b489-470c-b541-bf6c867e14d2', 'e17730c6-2402-4825-a44c-00861567e199', 'c8e8fa09-f39a-4224-8d93-12288ed192ab', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'b008912c-cefe-48d4-8426-a80644310f84', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.450055+00', '2026-10-09 13:48:11.453667+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7faf4764-2a67-4aca-8802-972557c7b04f', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', 'e17730c6-2402-4825-a44c-00861567e199', '7601afb5-4da6-49b5-867a-7124165819a8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '4c85074a-5772-418c-ad99-09a9ff75086d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.469172+00', '2026-10-09 13:48:11.473023+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('280173b7-7b35-433e-a8ae-a003e4d8e574', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '5230ab9e-ac59-433b-886c-e6034ce071ea', 'e17730c6-2402-4825-a44c-00861567e199', '4dfbae37-3aba-41de-8cb9-25c0cf9e17ad', 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '3281914a-565b-4fae-af36-3f8d05c6fe4f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.499862+00', '2026-10-09 13:48:11.504447+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('cf056985-7382-48e6-be23-2ddcb12f12b9', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '24fd38db-891e-4640-a97b-60dcda34f47d', '3f25ae72-4ac3-48b2-b541-57fe29274185', '2eb1aafa-2dad-4ac7-ba66-8b8e0f91fdce', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '072e39e0-f90a-408f-bcb7-0f84e71d6b00', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.523347+00', '2026-10-09 13:48:11.528113+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('04846bd2-7223-4aff-bcc5-b970cd5f17ff', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '3cd3fb44-51c9-403f-b67f-e43fdebf88f2', '3f25ae72-4ac3-48b2-b541-57fe29274185', '8bc91e36-62e8-488a-b144-a5cbb97491c5', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'a8773538-091a-45b0-8147-a651621da24a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.549862+00', '2026-10-09 13:48:11.554172+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b5ff6394-e557-43ea-b48f-b52fc496e125', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '24fd38db-891e-4640-a97b-60dcda34f47d', 'e17730c6-2402-4825-a44c-00861567e199', 'c8e8fa09-f39a-4224-8d93-12288ed192ab', 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', '41c6f1cd-df2b-41e1-9ac2-3bd3e7a813b3', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '493461d0-af67-42c5-88b6-2c6f395bdd62', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.57206+00', '2026-10-09 13:48:11.578575+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('62d28cfa-6dcb-4758-98c1-ae6bcc856ee0', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e6649bfe-57d5-4520-89bf-f3e753427345', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.599452+00', '2026-10-09 13:48:11.599452+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('2590ca47-e3f1-45a3-a81b-399a16fef1eb', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', 'e17730c6-2402-4825-a44c-00861567e199', '94e4e6f8-edc7-4e80-9134-80fec289e572', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.60456+00', '2026-10-09 13:48:11.60456+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('691d8f6f-29db-4de1-b42e-0f313cf959a4', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '06a0e238-1d49-4521-b26f-50bab173c772', '3f25ae72-4ac3-48b2-b541-57fe29274185', '79624991-57cf-4454-80e2-4b4a2e52691c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.60863+00', '2026-10-09 13:48:11.60863+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e8d1d3bb-eb6d-4a3e-8b85-7a841a129651', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'a6422c2a-c739-44ca-8952-c9956a2e25f4', 'e17730c6-2402-4825-a44c-00861567e199', '4dfbae37-3aba-41de-8cb9-25c0cf9e17ad', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, 'd494988d-5ee0-495a-ac87-5af6943d98c0', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.612271+00', '2026-10-09 13:48:11.612271+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "15fc4233-f82f-4756-b264-ea7ff66f010d", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0304998f-b773-47a7-906a-a6c403de63ed', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '4f48840a-3d38-4033-a5e7-6b13c0ef587a', '3f25ae72-4ac3-48b2-b541-57fe29274185', '6d70ccd1-42eb-4310-b522-86ef14a31eac', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.616387+00', '2026-10-09 13:48:11.616387+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8e0e5fc4-5e81-4227-8297-a42d7427dbc2', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '16711f95-0718-4f5f-bf80-ef3b31444ab8', '3f25ae72-4ac3-48b2-b541-57fe29274185', '6d70ccd1-42eb-4310-b522-86ef14a31eac', 'marketing', '00000000-0000-4000-8000-000000000003', '21fb8b79-c72e-44c6-973d-98396bdc1d1d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.623245+00', '2026-10-09 13:48:11.623245+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('6afaaacd-4af6-4394-b958-7388038c615c', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'e9cdb3d4-6640-4916-98ad-c2096000c7f2', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e9977813-3f76-4f5e-b08b-2a583d6f41a0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.62744+00', '2026-10-09 13:48:11.62744+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "15fc4233-f82f-4756-b264-ea7ff66f010d", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('caf8e00c-9d4e-4a80-804b-616fa8775be4', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e9977813-3f76-4f5e-b08b-2a583d6f41a0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.632427+00', '2026-10-09 13:48:11.632427+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('33dfbb9e-5cee-43dd-a531-39e78e4bd096', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', 'e17730c6-2402-4825-a44c-00861567e199', '7601afb5-4da6-49b5-867a-7124165819a8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 'e04881c6-d765-4371-a594-21490c119d34', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.63629+00', '2026-10-09 13:48:11.640976+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d7741809-285d-4265-8ae9-37753dc74e26', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '997c0294-4feb-4442-9d54-fe3f550f0b48', 'e17730c6-2402-4825-a44c-00861567e199', '067bf810-ae71-4264-b7ea-4355b81e3e95', 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', '86f13d12-f4b8-49f3-b7f9-d884d15cd233', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '82ebe6a6-10bb-44a6-a56b-7838cf6a1b60', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.66005+00', '2026-10-09 13:48:11.664079+00', 'signage', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', NULL, NULL, NULL, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1d749c1d-4280-4871-8a00-091af508a0df', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '050bae4e-40c1-4dd5-9a09-45b71583bcd4', '3f25ae72-4ac3-48b2-b541-57fe29274185', 'e6649bfe-57d5-4520-89bf-f3e753427345', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.679014+00', '2026-10-09 13:48:11.679014+00', 'signage', 'organiser', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('43e7274e-028c-46f4-a1be-fda37e4883f0', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'c67f3178-f7c4-4126-98cc-9e2401efcee0', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 1, '0eca2b04-9a63-4769-aaaf-09ce28f030ed', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.684207+00', '2026-10-09 13:48:11.688865+00', 'sponsorship_item', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', '2026-12-23', NULL, 9000.00, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('3b954c31-9b4f-4956-88f8-77cb5bf51be5', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', 'b69f7558-b2de-489f-a995-5636882226a4', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '9ebe2395-4c98-47be-8356-f91c4ec322ca', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.702476+00', '2026-10-09 13:48:11.702476+00', 'sponsorship_item', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}, {"stepId": "e4f35ab3-455b-4f19-b995-a9ad50cc51ca", "userId": null}]', '2026-10-29', NULL, 12500.00, '2026-09-29 13:48:10.74+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bbe0ad17-9890-4aaa-aee1-d9b8bf1c5dfd', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '54453ef5-c6d1-458e-ada9-71f1c3e6cfbe', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.707411+00', '2026-10-09 13:48:11.707411+00', 'sponsorship_item', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', '2027-02-06', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b413cb2a-58cb-46af-a07e-07b860f9c6d9', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '6a404c48-42ef-40d9-b11c-a4aab217116d', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '0472f3db-c181-4c52-95e0-45247331fdcb', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.711902+00', '2026-10-09 13:48:11.711902+00', 'sponsorship_item', 'sponsor', '[{"stepId": "b0f51330-e18b-4aa2-a20e-6f057e1cfa50", "userId": null}, {"stepId": "159f93d1-e469-46de-852f-e328c5e283cc", "userId": null}]', '2026-10-27', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('66c03747-155d-4687-a118-1c1afafd212a', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, 'e17730c6-2402-4825-a44c-00861567e199', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '9ed3abb7-6ce7-4243-a9e6-f42660385018', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-09 13:48:11.743791+00', '2026-10-09 13:48:11.743791+00', 'stand_design', 'organiser', '[{"stepId": "ea6b8fbb-0809-4cef-9907-8c27139d4c2f", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "3e37ef04-f06d-44ef-a38f-56e713c04d7e", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('7664f439-99b4-4d30-8784-2a7a118911ad', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '7faf4764-2a67-4aca-8802-972557c7b04f', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '92b34485-fde2-4320-a628-bdef8f90d0b9', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-09 13:48:11.489911+00', '2026-10-09 13:48:11.489911+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('41c6f1cd-df2b-41e1-9ac2-3bd3e7a813b3', '9ebe2395-4c98-47be-8356-f91c4ec322ca', 'Logo on 6 hanging banners', 6, '2026-10-09 13:48:10.926425+00', '2026-10-09 13:48:10.926425+00');
INSERT INTO public.sponsor_entitlements VALUES ('86f13d12-f4b8-49f3-b7f9-d884d15cd233', '9ebe2395-4c98-47be-8356-f91c4ec322ca', 'Entrance feature branding', 1, '2026-10-09 13:48:10.928714+00', '2026-10-09 13:48:10.928714+00');
INSERT INTO public.sponsor_entitlements VALUES ('21e45341-e905-4f28-91e9-d7ec04d273d2', '21fb8b79-c72e-44c6-973d-98396bdc1d1d', 'Seminar theatre branding', 1, '2026-10-09 13:48:10.93269+00', '2026-10-09 13:48:10.93269+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('9ebe2395-4c98-47be-8356-f91c4ec322ca', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-09 13:48:10.92397+00', '2026-10-09 13:48:10.92397+00');
INSERT INTO public.sponsors VALUES ('21fb8b79-c72e-44c6-973d-98396bdc1d1d', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-09 13:48:10.93068+00', '2026-10-09 13:48:10.93068+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('655cf663-c074-4734-b667-02b0aea41d19', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '4da7198b-0656-4e23-bd0b-0147b96a3a3b', 'STD-BIRM27-A10', '9555d72b-c450-4297-bd99-24455c83141e', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-03 13:48:10.74+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.747839+00', '2026-10-09 13:48:11.747839+00');
INSERT INTO public.stand_submissions VALUES ('2f120370-cf83-4f13-bd16-cafb76876f73', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '8d9f98d9-334c-413c-80b0-729a368e4114', 'STD-BIRM27-A20', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-03 13:48:10.74+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.765832+00', '2026-10-09 13:48:11.765832+00');
INSERT INTO public.stand_submissions VALUES ('8ba26d67-f577-4337-92ad-4676a60dfb62', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '1971867e-dcae-41af-97de-74577a59f1d9', 'STD-BIRM27-A30', '9555d72b-c450-4297-bd99-24455c83141e', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-03 13:48:10.74+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.78128+00', '2026-10-09 13:48:11.78128+00');
INSERT INTO public.stand_submissions VALUES ('b6d25fee-f0ab-4949-83d3-b71f8c5e0000', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'f31cb5ce-6c81-452d-894a-203f0d35ad2d', 'STD-BIRM27-B10', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-03 13:48:10.74+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.795753+00', '2026-10-09 13:48:11.795753+00');
INSERT INTO public.stand_submissions VALUES ('6ae10a3c-4802-49f1-b4c5-2dc45a1d5ee1', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '7a20f232-9005-4a6a-90c0-1b758006028d', 'STD-BIRM27-B20', '9555d72b-c450-4297-bd99-24455c83141e', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-03 13:48:10.74+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.810072+00', '2026-10-09 13:48:11.810072+00');
INSERT INTO public.stand_submissions VALUES ('97c6ac9c-895c-42e8-8b0b-d51a7c786608', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '552dfcd4-14ba-4232-b960-abfbbe467d06', 'STD-BIRM27-B30', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.825498+00', '2026-10-09 13:48:11.825498+00');
INSERT INTO public.stand_submissions VALUES ('a0cac265-815d-46c7-8879-75731ccfb3ff', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'aba30abf-8133-46cb-8a94-7bd49a066111', 'STD-BIRM27-C10', '9555d72b-c450-4297-bd99-24455c83141e', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.830097+00', '2026-10-09 13:48:11.830097+00');
INSERT INTO public.stand_submissions VALUES ('1a07ea77-2a10-41fc-b2ce-bb2cc7774500', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', '4b842305-091c-474a-8a06-26e2fde4f25e', 'STD-BIRM27-C20', 'eb5b89b8-5032-4be0-b3ba-31701702c3fe', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 0, '00000000-0000-4000-8000-000000000002', '2026-10-09 13:48:11.834524+00', '2026-10-09 13:48:11.834524+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('92b34485-fde2-4320-a628-bdef8f90d0b9', '8a0c5dc1-8514-4e0c-95aa-2d02a146cbcb');
INSERT INTO public.supplier_service_links VALUES ('92b34485-fde2-4320-a628-bdef8f90d0b9', '10b14f8b-5458-482d-bace-112a5d1c22e7');
INSERT INTO public.supplier_service_links VALUES ('fd5fb547-1664-4328-a7fa-b3bc4cef013c', 'a6abeaad-6c52-4661-9c91-66d4ea880cd2');
INSERT INTO public.supplier_service_links VALUES ('fd5fb547-1664-4328-a7fa-b3bc4cef013c', '10b14f8b-5458-482d-bace-112a5d1c22e7');
INSERT INTO public.supplier_service_links VALUES ('fd5fb547-1664-4328-a7fa-b3bc4cef013c', '20a0c2f8-326e-471b-8272-3daa2f62febe');
INSERT INTO public.supplier_service_links VALUES ('d494988d-5ee0-495a-ac87-5af6943d98c0', '43fc296b-7f6d-4ddb-8ec6-3568de3c4888');
INSERT INTO public.supplier_service_links VALUES ('d494988d-5ee0-495a-ac87-5af6943d98c0', '20a0c2f8-326e-471b-8272-3daa2f62febe');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('8a0c5dc1-8514-4e0c-95aa-2d02a146cbcb', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Signage print', 1, false, '2026-10-09 13:48:10.895967+00', '2026-10-09 13:48:10.895967+00');
INSERT INTO public.supplier_services VALUES ('43fc296b-7f6d-4ddb-8ec6-3568de3c4888', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Digital screens & AV', 2, false, '2026-10-09 13:48:10.897851+00', '2026-10-09 13:48:10.897851+00');
INSERT INTO public.supplier_services VALUES ('a6abeaad-6c52-4661-9c91-66d4ea880cd2', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Rigging', 3, false, '2026-10-09 13:48:10.899535+00', '2026-10-09 13:48:10.899535+00');
INSERT INTO public.supplier_services VALUES ('10b14f8b-5458-482d-bace-112a5d1c22e7', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Installation', 4, false, '2026-10-09 13:48:10.901072+00', '2026-10-09 13:48:10.901072+00');
INSERT INTO public.supplier_services VALUES ('20a0c2f8-326e-471b-8272-3daa2f62febe', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Staffing', 5, false, '2026-10-09 13:48:10.902803+00', '2026-10-09 13:48:10.902803+00');
INSERT INTO public.supplier_services VALUES ('b06a8791-c5de-48b9-a722-00c81909454c', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Furniture', 6, false, '2026-10-09 13:48:10.9045+00', '2026-10-09 13:48:10.9045+00');
INSERT INTO public.supplier_services VALUES ('1b81cd7a-6214-499c-b582-eb34b654c0e0', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Structural engineering', 7, false, '2026-10-09 13:48:10.905841+00', '2026-10-09 13:48:10.905841+00');
INSERT INTO public.supplier_services VALUES ('f4edb385-c470-4278-8361-24b503c209e0', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Floor Manager', 8, false, '2026-10-09 13:48:10.90702+00', '2026-10-09 13:48:10.90702+00');
INSERT INTO public.supplier_services VALUES ('f9e324e6-af6a-4d73-8d22-efd65b4e7492', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Security', 9, false, '2026-10-09 13:48:10.908044+00', '2026-10-09 13:48:10.908044+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('92b34485-fde2-4320-a628-bdef8f90d0b9', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-09 13:48:10.888974+00', '2026-10-09 13:48:10.888974+00');
INSERT INTO public.suppliers VALUES ('fd5fb547-1664-4328-a7fa-b3bc4cef013c', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-09 13:48:10.891542+00', '2026-10-09 13:48:10.891542+00');
INSERT INTO public.suppliers VALUES ('d494988d-5ee0-495a-ac87-5af6943d98c0', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-09 13:48:10.894376+00', '2026-10-09 13:48:10.894376+00');


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('8a7e5147-7ace-4a1a-b1d2-b16b4a74fc2b', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-16', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'f134bc58-34c0-49e7-9f8d-e8830c12c7ed', NULL, '2026-10-09 13:48:11.843829+00', '2026-10-09 13:48:11.843829+00', NULL);
INSERT INTO public.tasks VALUES ('8aec7c27-9f73-45a1-a548-33e6bc0e8674', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-19', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-09 13:48:11.846299+00', '2026-10-09 13:48:11.846299+00', NULL);
INSERT INTO public.tasks VALUES ('1285bc9b-abe8-4dc7-86c4-896030ce2895', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Walk the hall with the venue', NULL, 'done', '2026-10-04', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-09 13:48:10.74+00', '2026-10-09 13:48:11.84825+00', '2026-10-09 13:48:11.84825+00', '8aec7c27-9f73-45a1-a548-33e6bc0e8674');
INSERT INTO public.tasks VALUES ('519a53c5-dd44-41bf-a0d7-2089438020ec', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', '640e9f33-f32c-4c7f-b313-a5d196d1ffdc', 'Send sign positions to the printer', NULL, 'open', '2026-10-08', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-09 13:48:11.84825+00', '2026-10-09 13:48:11.84825+00', '8aec7c27-9f73-45a1-a548-33e6bc0e8674');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.791629+00', '2026-10-09 13:48:10.791629+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.796786+00', '2026-10-09 13:48:10.796786+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.800083+00', '2026-10-09 13:48:10.800083+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.804384+00', '2026-10-09 13:48:10.804384+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.807614+00', '2026-10-09 13:48:10.807614+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-09 13:48:10.810485+00', '2026-10-09 13:48:10.810485+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.02716+00', '2026-10-09 13:48:11.02716+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.032009+00', '2026-10-09 13:48:11.032009+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.035625+00', '2026-10-09 13:48:11.035625+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.041677+00', '2026-10-09 13:48:11.041677+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.045582+00', '2026-10-09 13:48:11.045582+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-09 13:48:11.111473+00', '2026-10-09 13:48:11.111473+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('34095f42-bbd8-436d-9902-05e176218d61', '9e81670d-3888-456c-a8e2-712f7f989995', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-09 13:48:10.822733+00', '2026-10-09 13:48:10.822733+00');
INSERT INTO public.venue_rules VALUES ('c7ada215-805e-40f7-9915-f063aed3c52b', '9e81670d-3888-456c-a8e2-712f7f989995', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-09 13:48:10.825345+00', '2026-10-09 13:48:10.825345+00');
INSERT INTO public.venue_rules VALUES ('137812e1-cd64-49b3-949e-39223051f508', '9e81670d-3888-456c-a8e2-712f7f989995', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-09 13:48:10.827433+00', '2026-10-09 13:48:10.827433+00');
INSERT INTO public.venue_rules VALUES ('45a14dbb-9f70-4678-8c27-82596da1bcf2', '9e81670d-3888-456c-a8e2-712f7f989995', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-09 13:48:10.8296+00', '2026-10-09 13:48:10.8296+00');
INSERT INTO public.venue_rules VALUES ('5b98c90c-6e74-4a4d-b4bb-ddbb86392458', '9e81670d-3888-456c-a8e2-712f7f989995', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-09 13:48:10.832295+00', '2026-10-09 13:48:10.832295+00');
INSERT INTO public.venue_rules VALUES ('2a6f4ef8-13d4-466e-8ee3-6cc560fc8ee8', '9e81670d-3888-456c-a8e2-712f7f989995', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-09 13:48:10.835607+00', '2026-10-09 13:48:10.835607+00');
INSERT INTO public.venue_rules VALUES ('3046a961-f732-4fe3-a2fd-b0af901a965a', '9e81670d-3888-456c-a8e2-712f7f989995', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-09 13:48:10.839678+00', '2026-10-09 13:48:10.839678+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('9e81670d-3888-456c-a8e2-712f7f989995', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-09 13:48:10.815387+00', '2026-10-09 13:48:10.815387+00');
INSERT INTO public.venues VALUES ('8ee945ce-7d37-4c46-9d81-88fd54887df5', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-09 13:48:10.81726+00', '2026-10-09 13:48:10.81726+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('73a8f620-8898-4960-b63a-47b1c17ccb38', '0472f3db-c181-4c52-95e0-45247331fdcb', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-09 13:48:10.944243+00', '2026-10-09 13:48:10.944243+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e66dbe1b-1da7-43a5-a956-ce621f1c987e', '0472f3db-c181-4c52-95e0-45247331fdcb', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-09 13:48:10.946518+00', '2026-10-09 13:48:10.946518+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('d0fdc706-96de-4063-b457-e86dbe95b8f0', '0472f3db-c181-4c52-95e0-45247331fdcb', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-09 13:48:10.94761+00', '2026-10-09 13:48:10.94761+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('34d05e18-ca4a-4983-8fb8-759c568913cc', '0472f3db-c181-4c52-95e0-45247331fdcb', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-09 13:48:10.948619+00', '2026-10-09 13:48:10.948619+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('25c69884-3a88-4979-8204-78ffabe64752', '9ed3abb7-6ce7-4243-a9e6-f42660385018', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-09 13:48:11.730894+00', '2026-10-09 13:48:11.738313+00', '{organiser,sponsor}', false, 'f5073613-7428-424a-9003-573f52fa3e5c');
INSERT INTO public.workflow_steps VALUES ('410fa269-7d39-4b1f-b0b7-8ccea90ba8a3', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-09 13:48:10.993217+00', '2026-10-09 13:48:10.993217+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('2efd9e43-9914-4900-9ad4-17652c7508cb', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-09 13:48:10.994392+00', '2026-10-09 13:48:10.994392+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('7170ad22-0bf4-40ce-85ae-d2bbc867221b', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-09 13:48:10.99559+00', '2026-10-09 13:48:10.99559+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('0c5f9251-e8ff-4bf3-9df8-28045a90c6b2', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-09 13:48:10.996781+00', '2026-10-09 13:48:10.996781+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('ff3be54d-0f57-4d89-903f-40c25c46c68e', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-09 13:48:10.998426+00', '2026-10-09 13:48:10.998426+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a8e0fd54-01d9-4fa5-badc-56dadc9d58f8', '015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-09 13:48:10.999526+00', '2026-10-09 13:48:10.999526+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('b0f51330-e18b-4aa2-a20e-6f057e1cfa50', '0472f3db-c181-4c52-95e0-45247331fdcb', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-09 13:48:10.939484+00', '2026-10-09 13:48:11.722744+00', '{organiser,sponsor}', false, 'fec6133b-00d3-4360-ac04-34e473870a48');
INSERT INTO public.workflow_steps VALUES ('159f93d1-e469-46de-852f-e328c5e283cc', '0472f3db-c181-4c52-95e0-45247331fdcb', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-09 13:48:10.941435+00', '2026-10-09 13:48:11.723818+00', '{organiser,sponsor}', false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1');
INSERT INTO public.workflow_steps VALUES ('e4f35ab3-455b-4f19-b995-a9ad50cc51ca', '0472f3db-c181-4c52-95e0-45247331fdcb', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-09 13:48:10.943157+00', '2026-10-09 13:48:11.724626+00', '{sponsor}', false, '39cad744-d0b7-4660-bf4b-b8c870b2a346');
INSERT INTO public.workflow_steps VALUES ('15fc4233-f82f-4756-b264-ea7ff66f010d', '0472f3db-c181-4c52-95e0-45247331fdcb', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-09 13:48:10.945254+00', '2026-10-09 13:48:11.725437+00', '{organiser,sponsor}', false, 'f5073613-7428-424a-9003-573f52fa3e5c');
INSERT INTO public.workflow_steps VALUES ('ea6b8fbb-0809-4cef-9907-8c27139d4c2f', '9ed3abb7-6ce7-4243-a9e6-f42660385018', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-09 13:48:11.727249+00', '2026-10-09 13:48:11.73199+00', '{organiser,sponsor}', false, 'fec6133b-00d3-4360-ac04-34e473870a48');
INSERT INTO public.workflow_steps VALUES ('3e37ef04-f06d-44ef-a38f-56e713c04d7e', '9ed3abb7-6ce7-4243-a9e6-f42660385018', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-09 13:48:11.728633+00', '2026-10-09 13:48:11.733186+00', '{organiser,sponsor}', false, 'b273ccad-c56e-4b0b-ae8c-48abb70321e1');
INSERT INTO public.workflow_steps VALUES ('2946346f-123b-453f-acca-7d95dd9b83fe', '9ed3abb7-6ce7-4243-a9e6-f42660385018', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-09 13:48:11.729671+00', '2026-10-09 13:48:11.736881+00', '{sponsor}', false, '39cad744-d0b7-4660-bf4b-b8c870b2a346');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('0472f3db-c181-4c52-95e0-45247331fdcb', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Signage default', 'signage', true, false, '2026-10-09 13:48:10.937211+00', '2026-10-09 13:48:10.937211+00', NULL);
INSERT INTO public.workflows VALUES ('015f1c2c-0520-42f1-91e4-3ec4bb8909d7', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Stand default', 'stand', true, false, '2026-10-09 13:48:10.991753+00', '2026-10-09 13:48:10.991753+00', NULL);
INSERT INTO public.workflows VALUES ('9ed3abb7-6ce7-4243-a9e6-f42660385018', 'cfb0b433-ad6d-4c35-ac5c-c22fa10fb450', 'Stand design sign-off', 'signage', false, false, '2026-10-09 13:48:11.718165+00', '2026-10-09 13:48:11.718165+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 11, true);


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

\unrestrict 2cv8E3YWK47xscB50cNQfAqzYoIlzzM6su0n7qQkH9NDMGaGZc22GeYvTQbKHDb

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
