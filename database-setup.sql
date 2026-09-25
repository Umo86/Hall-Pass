-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites CASCADE;
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

\restrict sZylTQjzaQ9tcaAl6uSkFAZvzt9ea7Ts2ptQtpWJNzxhhmcChDqAdszFZb0RllC

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
    no_supplier_fallback boolean DEFAULT false NOT NULL
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
    is_archived boolean DEFAULT false NOT NULL
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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('f4d28f20-8196-480e-8368-b136ec2c8965', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0ff02f30-91fb-48db-91b9-398d05ff568b', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('28ae36d4-06ca-4edc-abdb-33ead502f0e7', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('0c2bf2b1-9fca-4437-ae42-b7d090d7d1b3', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('78b2c8c0-a11c-4ec1-a87a-f80e6068e96f', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5eb7179b-476d-4202-8de0-a66ebefc6958', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('1d5dc19f-b07b-4b2d-93f7-6bd50a75e2f8', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('dd487abd-8827-4614-af80-0653b0386698', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.782305+00', '2026-09-25 09:07:51.782305+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('7c9c5e4c-c396-401b-9d77-55d2d494fdb7', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d61ae4ab-a3a8-4f7e-be8c-51df7226270d', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f58bc57d-148e-4836-959d-a173a98ad71d', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('baa7b15e-9d80-4e52-a395-4eb61e03b08c', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('1db525a4-c03e-4411-86a8-220cf709298f', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('89673c77-8c74-4842-8252-5e9b4c2b60d1', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f063da35-9423-482c-97a3-c94e9d74e937', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('cec60440-09cc-4c5a-9e46-63262c0430fd', 'signage_item', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.807174+00', '2026-09-25 09:07:51.807174+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6612463e-e460-45c5-ae9f-904760401e25', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 09:07:51.461+00', '2026-09-21 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('46c4e7c9-db53-4c99-9f28-ded2165451f1', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 09:07:51.461+00', '2026-09-16 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('8ac4abb0-e78a-4fe4-80f7-0e788562b799', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 09:07:51.461+00', '2026-09-18 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b774635d-0009-4f6c-b131-178c3a476b77', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('640fcdc1-19e7-4aba-9b63-84da9a326461', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('244e19b0-c3a0-42d0-ac13-aab9980d3d89', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('5b7b0e86-179e-49aa-b7d3-b4d478423bce', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0fec4fc1-442d-4166-af54-889d47b606b5', 'signage_item', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.827976+00', '2026-09-25 09:07:51.827976+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0a3b5836-ee1f-4a26-bd09-f5d1270c70be', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('372ce8e1-9d74-40af-bd6d-bdaee025fac8', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('8937b29e-251d-4f25-b74d-80b40347786e', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('20a71a90-548c-403a-a29b-7cc06eccf86f', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6c808b92-f5ee-4a23-bf66-1b714fc995e0', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7e16302f-2533-49c2-a186-44d53d95a9b6', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('1d291fad-b908-4bd9-bd49-a0a6802e522a', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('d4071f12-5846-4219-9e76-758fec3ab295', 'signage_item', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.847492+00', '2026-09-25 09:07:51.847492+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0c1de42a-cc00-4349-bd65-bf17fad3263d', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('99094724-550b-477c-8c7f-a81b509ed869', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0b69ff32-df61-4730-9f68-9b22436e0041', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('2c4240eb-dadf-427a-901f-2d72533319c2', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('bc366b06-c02c-4ef3-80dc-17f393d6753a', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7f888dc2-73bd-4494-9923-8d07f3185281', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('2498a3d9-dca4-4b3f-a42c-02e596100669', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('979b7482-b7ca-4955-84d6-1f9e8e633bf4', 'signage_item', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.869125+00', '2026-09-25 09:07:51.869125+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('4b17f515-8d5d-45b2-bb5c-f2c80ec87e26', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 09:07:51.461+00', '2026-09-16 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('63de1a22-e8ab-43ff-be42-612598d3a983', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 09:07:51.461+00', '2026-09-16 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e4331c88-b7e4-4d85-89c8-1affc93962d1', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('659950ee-52c7-40de-9b70-260bd0b9536e', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('512e065a-20a9-4d58-93ee-00a07e936acb', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 09:07:51.461+00', '2026-09-21 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c7927983-3422-4baf-b1c5-6f33bcc13725', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('e12ab7da-d401-4b1b-af84-f5b15cff975f', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('bfd707cb-2582-4016-bb45-128bd8ada075', 'signage_item', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.888204+00', '2026-09-25 09:07:51.888204+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('95657ce1-17ba-4f12-acc1-0e3d921fa1c9', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('50ce7a19-dcb9-40de-ae4b-5df70c7f37c9', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('54ddce0f-5205-4522-a01a-8f21960cb37a', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('4d9138a3-b084-44bb-8ae3-c715058a6e4d', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b9ff9c00-2e09-4b77-b34b-243a18651e16', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1fb42048-9d19-40a5-a31e-46abbf13eed5', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('a177d178-77e9-4efd-a0d5-0457a02aa066', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b5cb0cb7-c232-4d7d-84d3-35068b9a054e', 'signage_item', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.906164+00', '2026-09-25 09:07:51.906164+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b45a80f2-ff4c-4cd3-a90c-aabaa8f2ac38', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7cda5d0c-05d3-4551-ac70-a6b89ca83c5d', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e5408e92-d52f-4bb6-bdc1-4526431fc187', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6b145f28-fb87-4d20-a453-b7e889a38540', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('65fc3ec8-3bd3-4fb2-bc32-3076f668b2a8', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a47738a0-cb90-4d3c-af5d-4d9264d2e35a', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ab0d19a0-edf1-4c90-ae4e-4b452c986205', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('fdca1270-047e-47c0-9c81-bcd3a963e116', 'signage_item', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.92643+00', '2026-09-25 09:07:51.92643+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c92058d0-8c29-4732-baa4-e662e0f53a9a', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('03f7bf76-8390-46f7-8f32-051557a731ea', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('94f64302-dfb9-4f4a-8cc4-3c35a0839624', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 09:07:51.461+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('89bed718-b761-47d8-a40d-96c1fd8c8ff3', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('c9810b3b-5c84-4413-a310-b813ff269fed', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0fe9ef9b-073d-4c7e-9d38-5790d731ab96', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('30d211ba-8bef-4dcf-8b2c-57325cad36f1', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6dfd49ae-efe7-4c5d-b571-7d8187ad00ea', 'signage_item', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.948347+00', '2026-09-25 09:07:51.948347+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0306f9a5-b448-4fa9-b361-e85cf8283ae2', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('bb60e1a0-f630-4574-a2b5-d5de5e3eac99', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('289b6aa5-d4e0-4e5c-b65b-42148f63d087', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('3dc89efc-3b87-44f7-952b-cab61c7f835e', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('4c909e94-4633-4075-b3b5-1d305dfff2e1', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a511235e-79a1-4f6d-8385-1135649da203', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ec6c3ba5-cd29-4512-a405-86ab19c62d10', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a14e0099-4310-49bc-933f-4fa444055c55', 'signage_item', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.973589+00', '2026-09-25 09:07:51.973589+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('00ccd770-9e52-47a7-8e00-f99726dc994f', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('12b13cbc-03b1-4356-a623-f3bb149e737b', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7b08be2a-0265-4794-aafe-2db8f6ee5fca', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('bfcad264-57c3-4029-aace-36ae86556a14', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('282900cb-52b6-4e11-b4fa-d00946a32b69', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('57ede1d7-1039-4760-b025-9d214dc42916', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('5f3f0678-8809-4fd1-a1ae-f34f22cb2762', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('defb3ef1-9089-49b9-81bf-9cbb7664af4c', 'signage_item', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:51.997096+00', '2026-09-25 09:07:51.997096+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('737179c6-03ba-44e4-8f4f-bec0722fe3bc', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c9efb91e-4676-4eb5-ae1d-00cbac5d6b69', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('de83fa65-250b-4bd7-a6a7-5a2b65d3a891', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('001143d8-64d4-4991-ac04-29fa3e98715b', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e5b48fd2-45f8-4ee8-b84c-08eb1b79ba92', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('09a39676-48bc-43e7-97b3-5766274d0411', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('85ec01c6-fb02-44b0-b0af-a7683ef30cf1', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c5a5d8c3-ee31-459c-8f06-12dd85200390', 'signage_item', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.016879+00', '2026-09-25 09:07:52.016879+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5a298291-a6c9-4219-9c7b-4d867b5445fe', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('096cf2dd-03cf-430d-9995-1aea7244319b', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('75faa346-aee7-4dee-bbca-8d88ebbfc4d7', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('bc57a994-6fe6-4876-8be9-c8cd012025c4', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9d8ff055-a86b-4c18-8558-bcdb9b76fe8b', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5869abe3-89bf-420b-9fee-061ea5ac2972', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7f713565-baed-4b11-a4be-b6ef79a882d8', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('47c26b5a-5327-4ca2-a368-e07ff1174454', 'signage_item', 'df808d6c-c058-4696-9001-163c94f1393b', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.03571+00', '2026-09-25 09:07:52.03571+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c6f0287b-9061-428a-946a-91f65b8c5a1d', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b5d9cfd0-f27c-4c4f-b8e4-019f92a37657', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1816a50b-b8f7-476b-be72-357f876f00b9', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('e208b8be-4076-4edd-ba2e-ff72b3511683', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('1de73ece-d1c6-4e73-a03f-ccd4740e3cb2', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('da95b969-98d1-4cd7-b68f-63af9093bd20', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ad47ad8c-f4d4-431c-ab67-616f912050d3', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6a18048c-b97b-42da-af9f-374b3b383d7a', 'signage_item', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.055534+00', '2026-09-25 09:07:52.055534+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('07b056f7-4486-4651-b248-87225143822e', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('34ae5a7f-c65f-4242-9bc0-3824229185d1', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d74476fa-7710-4a4e-a6fb-b32ca7a17f6f', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('eec0ea3b-398e-4629-9867-ffcdcf26dcac', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('36c9d053-7f16-4d0c-9523-887cd8cc9ffb', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7ec92954-e6e4-4307-a89c-cf08e915db44', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('9593f448-2984-4904-ae15-52583c6db0a0', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('9333608b-a1c1-4042-a912-740322f5890d', 'signage_item', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.071488+00', '2026-09-25 09:07:52.071488+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('548e102c-65e6-45f7-a79b-a07791a15559', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b1bc21ae-da90-40e5-adae-2a48a94f9122', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f3a1c227-a416-4779-8551-58c4e1dae098', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('903b09e8-cf16-4fc9-907c-5f24cc9ad013', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9d82d4c1-72c0-424f-b6e1-3ef76dff227a', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e680714c-c91d-4358-9031-b5993c42cb74', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('67dc2472-9751-4bae-bb7f-963a0ba14832', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6a745c71-cd29-4f9e-988d-f53126024748', 'signage_item', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.092389+00', '2026-09-25 09:07:52.092389+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('7d6e9c0d-3a14-44ff-861b-fdbf0bdc807a', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('220c695b-633b-4173-9c85-aa4cf93a9ef5', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'rejected', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e7bab574-ff95-446e-82cf-1f97cb4531a3', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('8f6f5a95-6030-4729-aac9-976bf17ce731', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b8535959-4759-4fae-8d0a-0a62e28f6f64', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5ace9809-ceb9-4ce9-a8cf-21c8624d106f', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7e4ffff8-6b79-40ae-a3c0-669aaa774563', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('907edfcf-aa74-43d5-928a-352726ee9354', 'signage_item', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.109563+00', '2026-09-25 09:07:52.109563+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('269b9742-e889-4614-886b-7cf3124aed17', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('95126406-7fce-4cde-b0bf-9b365662dc09', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b77f3439-415f-45e3-898d-3d1553a89b62', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('a7377e8c-9b25-4307-afab-2e0d730f8a55', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('38eb3630-a270-4bec-ad91-220f1787c55c', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('129ae394-778c-4b18-89ed-eb3bcc2025a6', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('6dd72edb-4fe1-46cc-9e3e-2615212f740c', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('8bcd2159-af54-417b-8c4b-30345be6b976', 'signage_item', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.128137+00', '2026-09-25 09:07:52.128137+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('08161ac3-aabf-48e3-82be-f46c10f230bd', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'invalidated', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('fcdf67aa-bae9-4092-b992-6e72168188fc', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 09:07:51.461+00', '2026-09-27 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('20033596-815c-41d4-ab7d-82b80def4043', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c8637c3f-b329-4656-97a4-85021fd63620', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 09:07:51.461+00', '2026-09-27 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('364d8571-d732-445d-8fa2-1af7b048c71d', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'invalidated', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b46225fc-41ff-46b8-b5e2-844c8832b21b', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('9523e173-4392-4635-bac4-231ceb18f27c', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('5e0c3614-8674-472f-9bf8-1f94fb195c54', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b5731e57-f5b6-4631-a8c0-9a03485c57bf', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('b55d852b-6704-40b9-b5d6-63cc9e370b89', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6a30eee3-36a2-4894-8b96-ca7e07a8532f', 'signage_item', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.150004+00', '2026-09-25 09:07:52.150004+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c63b36cb-e54c-4223-bb73-7b4373cf84fc', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a8544c38-3e89-4cae-878d-3359e87995b8', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('4edbbfd8-c932-44cb-962d-2d6feac6bfc5', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('1f1f502f-f867-47e3-9a85-90fee5664b99', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('40f510a5-e5c5-4179-b51b-6776b75b962f', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('df58a412-8096-428b-bf2e-021f3a6bc4d3', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('4f2019b0-699e-4f30-8428-eff957b9fe74', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3e86ad6f-ae6f-47b8-a952-0f17c385b826', 'signage_item', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.212552+00', '2026-09-25 09:07:52.212552+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c46fed81-dd04-422e-bded-4627cb81033f', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f1229212-74ae-4e5c-bef4-bcc16fb6fd03', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('eca9f34b-6afa-4ff3-8f1f-5e2bc5c123d4', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('02803e64-e632-4474-8728-b7ba7be20c1b', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 09:07:51.461+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-29 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('22e71f7c-39c0-466f-bd88-54f452edc6ee', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3263d277-212d-4b54-ba61-51488d779060', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 09:07:51.461+00', '2026-09-24 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ad06ec4d-9110-43a1-add0-c3e5ebb5c183', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b03539b6-1240-4e97-ac25-fb11973341e6', 'signage_item', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.239645+00', '2026-09-25 09:07:52.239645+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('32c4674f-28a1-4dcd-8860-5152fd76db44', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'Operations sign-off', 'approval', 1, 1, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9b802018-30a5-40c9-abba-176d6bc2d316', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '9810bb49-e881-4fe8-80b5-03f23e5429d6', 'Marketing sign-off', 'approval', 2, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0bb2f8fb-f180-409c-9986-eb02a18656ab', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'Sales sign-off', 'approval', 3, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 09:07:51.461+00', '2026-09-25 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('bba82c47-bc6c-4f51-90f0-798ef7691e2d', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('371cae12-9f6a-4b5f-805e-fc70e435a17e', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, 'ccde4a57-9587-485b-8298-d55285faf0e3', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('13538507-6871-42b0-b6a6-8842c5c0611a', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, 'c889029e-f8a3-4721-be31-2da328ae1c8c', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('5dd6059c-2b57-4d46-b684-dc7b8dde5e9d', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '96add679-b202-4e0b-9570-54ea24861b5e', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ceab4402-5112-4bad-acd3-a0e3ba5922f2', 'signage_item', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, '7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.264219+00', '2026-09-25 09:07:52.264219+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('274966a7-b13c-4289-b5b0-e5c02bc919ae', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, 'cc09062a-a88e-4722-a476-10f84ac3d6cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 09:07:51.461+00', '2026-09-22 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('80ea0a38-16b8-46ae-8cf9-7cc4558d58d5', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, '2fc4b179-4ac1-4211-a94e-3e4657785bb5', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 09:07:51.461+00', '2026-09-28 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('018179d2-4f80-4574-baf9-4adcc48919ce', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, 'e6f0b196-b968-4307-9254-36f07e1df5ab', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('f071da05-162e-41c9-996e-fa58ec9aa7da', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, '52809c58-529a-4a39-901e-09f5f7628836', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('7882af3a-b5d7-4393-a276-f85e158dac28', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, '8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('49225a2f-d222-4f19-bfd3-df8bc4323fc5', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 1, '5efa9bef-e6c7-49d8-88e3-af0e6f21e156', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ef64a4e1-5c08-45f7-84d1-3b17b9837e02', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, 'cc09062a-a88e-4722-a476-10f84ac3d6cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 09:07:51.461+00', '2026-09-22 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('fe4db7b1-03c5-4841-bf92-028d4120d4d8', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, '2fc4b179-4ac1-4211-a94e-3e4657785bb5', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('442ad081-cae4-43cd-8d50-b640a88ec4d5', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, 'e6f0b196-b968-4307-9254-36f07e1df5ab', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('943d3f1c-dab9-4ce6-88e6-7196d124df10', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, '52809c58-529a-4a39-901e-09f5f7628836', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('21f96338-9680-4fc7-aef4-594af2010471', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, '8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('45e69a65-6800-4ae7-9c8c-fcaf34efddc9', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 1, '5efa9bef-e6c7-49d8-88e3-af0e6f21e156', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('be6d4059-2c26-4ade-bb9c-42a502f56aa4', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, 'cc09062a-a88e-4722-a476-10f84ac3d6cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-19 09:07:51.461+00', '2026-09-22 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('fc803675-ce2b-47bf-9c5c-145f2197011b', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, '2fc4b179-4ac1-4211-a94e-3e4657785bb5', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('395019a9-ed94-4782-a9ec-818700c26b7c', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, 'e6f0b196-b968-4307-9254-36f07e1df5ab', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('5fb0c1c6-4a04-4f34-9ef3-573b4c350650', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, '52809c58-529a-4a39-901e-09f5f7628836', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8d232905-96dc-4da0-8752-f7039bfa5858', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, '8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('4fc3cdd8-dd3a-462e-b306-f0e8e14cdcfc', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 1, '5efa9bef-e6c7-49d8-88e3-af0e6f21e156', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5a18c73f-0960-4308-9f8d-ed4a7a6e5859', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, 'cc09062a-a88e-4722-a476-10f84ac3d6cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 09:07:51.461+00', '2026-09-22 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7cab2625-65a5-4039-9a4e-c5fb6601ab2a', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, '2fc4b179-4ac1-4211-a94e-3e4657785bb5', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('3abd8354-69fe-4cb4-95b8-11bd268cb7b5', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, 'e6f0b196-b968-4307-9254-36f07e1df5ab', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-26 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('c9729b85-9970-4ac7-898c-4926a5d760cc', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, '52809c58-529a-4a39-901e-09f5f7628836', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-28 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('a9eec1df-9ce4-4e59-9d9d-57aeb12612e4', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, '8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('79673326-204d-4227-b60c-f49ae07eba96', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 1, '5efa9bef-e6c7-49d8-88e3-af0e6f21e156', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 09:07:51.461+00', '2026-09-21 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e1de5122-ce38-41b6-ada8-f542132e6386', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, 'cc09062a-a88e-4722-a476-10f84ac3d6cb', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 09:07:51.461+00', '2026-09-22 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d3a90e6b-3fbd-41e6-82bf-5b8a73f14531', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, '2fc4b179-4ac1-4211-a94e-3e4657785bb5', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e74cb990-9d70-440c-b96c-214f2459890a', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, 'e6f0b196-b968-4307-9254-36f07e1df5ab', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-26 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('cba3b187-23f0-464f-8035-1d9cc473fc12', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, '52809c58-529a-4a39-901e-09f5f7628836', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-28 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('77b7c5d8-c1cb-4c00-97d1-e31c88970c7e', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, '8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 09:07:51.461+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 09:07:51.461+00', '2026-09-23 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('76dceb7b-fca1-43f4-9ad0-5e171b7396bd', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 1, '5efa9bef-e6c7-49d8-88e3-af0e6f21e156', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 09:07:51.461+00', '2026-09-21 09:07:51.461+00', 0, NULL, NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00', false, true, 0, false);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('7e5d7dd0-bfd0-4747-a05d-1a6b8a7e732d', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.778232+00', '2026-09-25 09:07:51.778232+00');
INSERT INTO public.artwork_versions VALUES ('e2b3eeef-4716-429c-af75-a974536e4206', 'bc2af7d9-5627-4783-be11-da3471623eec', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.804356+00', '2026-09-25 09:07:51.804356+00');
INSERT INTO public.artwork_versions VALUES ('dfc965db-296b-44ed-8c5f-4fa2ce2c0db8', '6c2c7a08-7e60-414a-85c9-785a804e556a', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-25 09:07:51.823558+00', '2026-09-25 09:07:51.823558+00');
INSERT INTO public.artwork_versions VALUES ('3a9d3285-83a8-4b3a-b24d-09204a9a71a9', '6c2c7a08-7e60-414a-85c9-785a804e556a', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:51.8252+00', '2026-09-25 09:07:51.8252+00');
INSERT INTO public.artwork_versions VALUES ('6502bded-13bd-40b6-98ce-078245d1a202', '0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.844829+00', '2026-09-25 09:07:51.844829+00');
INSERT INTO public.artwork_versions VALUES ('4c4638b3-9344-4a98-b0ce-c5bb000a0ba4', '4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:51.86557+00', '2026-09-25 09:07:51.86557+00');
INSERT INTO public.artwork_versions VALUES ('886c7b29-3a22-4af9-a043-042738e3f6cb', 'ea02d77c-96db-41f3-8077-1b661b76d4ac', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:51.885908+00', '2026-09-25 09:07:51.885908+00');
INSERT INTO public.artwork_versions VALUES ('ba9aced1-136f-4c5c-a8e5-67af7660afac', '075a8442-d635-4c09-93e0-933e6ab7b38c', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.903323+00', '2026-09-25 09:07:51.903323+00');
INSERT INTO public.artwork_versions VALUES ('3a09b4b1-43a4-4c2f-8964-d61a9e91fdaa', '05d6d75c-cc59-442f-a4bd-f408376ccb52', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:51.923192+00', '2026-09-25 09:07:51.923192+00');
INSERT INTO public.artwork_versions VALUES ('04fe3e86-52a4-4a0c-af50-df9a668759bd', '66597286-19c5-4f3b-afb7-32ebc6f3eb4b', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.944908+00', '2026-09-25 09:07:51.944908+00');
INSERT INTO public.artwork_versions VALUES ('001bcc44-b89d-4c7a-aa86-fbab79e302cb', 'c4fecc92-63d6-49a2-8bbe-30f8c2996921', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:51.970469+00', '2026-09-25 09:07:51.970469+00');
INSERT INTO public.artwork_versions VALUES ('ea9add58-9590-409f-84d1-1a03a83e9b56', '4b54b697-6f59-4931-8703-130a2fa3e1b7', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:51.993565+00', '2026-09-25 09:07:51.993565+00');
INSERT INTO public.artwork_versions VALUES ('835794f5-5efb-4c96-bd9e-102d45a8be7e', 'f5748252-a140-4ca7-a8c9-dba42b1215b3', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:52.014335+00', '2026-09-25 09:07:52.014335+00');
INSERT INTO public.artwork_versions VALUES ('6a2f49b5-9e80-445f-8ecd-31f25274fcfc', 'df808d6c-c058-4696-9001-163c94f1393b', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.030228+00', '2026-09-25 09:07:52.030228+00');
INSERT INTO public.artwork_versions VALUES ('cff2f285-0949-4b75-a264-98c56963a669', 'd7e17fbf-72c1-4fb2-b490-64f24b4963a1', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:52.05239+00', '2026-09-25 09:07:52.05239+00');
INSERT INTO public.artwork_versions VALUES ('113f21bb-43c3-490b-8918-bb4c6b117524', '7a19d181-98f1-46fd-8a0c-4be677603f8d', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:52.068849+00', '2026-09-25 09:07:52.068849+00');
INSERT INTO public.artwork_versions VALUES ('b660a270-d67e-4a95-a481-97e133b9832c', '6bd912ad-fc12-411d-9d41-3900ae81a663', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.089645+00', '2026-09-25 09:07:52.089645+00');
INSERT INTO public.artwork_versions VALUES ('1c943884-9b54-4cb5-98af-c0ed2ec13683', 'e01b2421-e723-4f67-85a2-9168eff64e8a', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:52.107443+00', '2026-09-25 09:07:52.107443+00');
INSERT INTO public.artwork_versions VALUES ('c94d831d-1b59-4569-8333-91dec4ac45f0', 'f4d33d6c-3481-4ab2-b751-2c0755383959', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.125397+00', '2026-09-25 09:07:52.125397+00');
INSERT INTO public.artwork_versions VALUES ('442a6e6c-25e4-4f8f-ad4a-1f4bb32bd1bf', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 09:07:52.142443+00', '2026-09-25 09:07:52.142443+00');
INSERT INTO public.artwork_versions VALUES ('1bcd636d-77b4-496f-ab0e-95660ac9c50d', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 09:07:52.144258+00', '2026-09-25 09:07:52.144258+00');
INSERT INTO public.artwork_versions VALUES ('89e72021-ace4-4b62-8a6a-67369bc8c73a', '2fe0c64e-d843-4dd3-acd5-92c19b1538d2', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.146169+00', '2026-09-25 09:07:52.146169+00');
INSERT INTO public.artwork_versions VALUES ('d11a82d3-9587-4be2-8104-f7d0e246bf06', 'beae97b9-e11a-4848-a5da-dc76d7ed6e61', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 09:07:52.209029+00', '2026-09-25 09:07:52.209029+00');
INSERT INTO public.artwork_versions VALUES ('9c1139e4-d2ca-48b5-a7f8-0a6089864866', '29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.236198+00', '2026-09-25 09:07:52.236198+00');
INSERT INTO public.artwork_versions VALUES ('c15348dd-fa5c-444d-a9c3-e9411e151a79', 'bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 09:07:52.26168+00', '2026-09-25 09:07:52.26168+00');


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

INSERT INTO public.contractors VALUES ('beae1626-52f3-4bea-bb83-392f58f67e30', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-25 09:07:51.632657+00', '2026-09-25 09:07:51.632657+00');
INSERT INTO public.contractors VALUES ('eba07fab-06b9-493d-a2d8-c89982b37e10', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-25 09:07:51.635845+00', '2026-09-25 09:07:51.635845+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('a6a3f7f8-e959-48bf-a9e7-06f1d02ee57d', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00');
INSERT INTO public.documents VALUES ('b96646ce-6e4b-403b-917f-9fd4afeb037f', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00');
INSERT INTO public.documents VALUES ('1442dcd6-515c-4818-b566-0f039752300a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00');
INSERT INTO public.documents VALUES ('884b76d6-1a2f-46e5-bf69-7bee275165dd', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '8f495dc6-c3cb-43c0-be5e-8f72eef433f0', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00');
INSERT INTO public.documents VALUES ('3d1fdc6f-7792-4d78-9422-257694b3f094', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00');
INSERT INTO public.documents VALUES ('4b1bd0d9-0ee9-4fda-a133-f8b83c51a073', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00');
INSERT INTO public.documents VALUES ('49617f19-3bf2-4b12-b3af-992f239b232a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00');
INSERT INTO public.documents VALUES ('ece9a729-5bab-4a16-9ee7-3cf7653ba48a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '169a77f2-41f9-461c-bbf9-83eb0b90f01d', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00');
INSERT INTO public.documents VALUES ('4e56a364-7eb1-4b40-b258-02b31873af31', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00');
INSERT INTO public.documents VALUES ('f19d36c8-f9e6-4fab-ba40-ccd05cd758bd', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00');
INSERT INTO public.documents VALUES ('47c43004-b6c9-4e6a-883e-71bf0de0dd88', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00');
INSERT INTO public.documents VALUES ('4413f3a9-ab59-4774-a952-86a481a01000', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', 'db692544-6fc9-4a89-b924-4e66e3c66d39', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00');
INSERT INTO public.documents VALUES ('8749e732-119f-41eb-b3a5-428e089b2e18', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00');
INSERT INTO public.documents VALUES ('7bac65bb-c07a-4641-9acc-fb2b95474076', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00');
INSERT INTO public.documents VALUES ('a5d68487-6b78-4b1c-94ef-e7dd7a5afbb7', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00');
INSERT INTO public.documents VALUES ('ec67a787-29e1-4bc2-835c-9d40c3b3bc16', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '48804e0a-cef2-4ee0-b104-cbb1ead3384f', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00');
INSERT INTO public.documents VALUES ('d9f929a0-2ac6-4390-93c3-a18a911bde91', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00');
INSERT INTO public.documents VALUES ('39b8e232-af89-43f3-bfdd-537272e939a8', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00');
INSERT INTO public.documents VALUES ('972d0602-3fb7-444f-8722-0c9467677810', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00');
INSERT INTO public.documents VALUES ('86837c92-e12d-4e0d-a0f0-4f2077570a4a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_submission', '5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('a9ebf65e-ffd1-41c2-bd10-b14b15e7750f', '4138f476-8908-4a46-a623-f5f430a5d777', 'signage', 32, '2026-09-25 09:07:52.282533+00', '2026-09-25 09:07:52.284787+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('289ecf5c-3646-44bd-896c-f695c40d3a07', '4138f476-8908-4a46-a623-f5f430a5d777', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-25 09:07:51.553061+00', '2026-09-25 09:07:51.553061+00');
INSERT INTO public.edition_deadlines VALUES ('2ec757e5-d4cd-47c3-9b49-81d87d18a308', '4138f476-8908-4a46-a623-f5f430a5d777', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-25 09:07:51.555174+00', '2026-09-25 09:07:51.555174+00');
INSERT INTO public.edition_deadlines VALUES ('6b577065-75a7-43db-9329-336a65851b37', '4138f476-8908-4a46-a623-f5f430a5d777', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-25 09:07:51.556733+00', '2026-09-25 09:07:51.556733+00');
INSERT INTO public.edition_deadlines VALUES ('396ced6c-01fc-4549-914f-48f7f7e8ed0e', '4138f476-8908-4a46-a623-f5f430a5d777', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-25 09:07:51.558307+00', '2026-09-25 09:07:51.558307+00');
INSERT INTO public.edition_deadlines VALUES ('9ea74fbf-7a59-4c99-a452-37e0e2261062', '4138f476-8908-4a46-a623-f5f430a5d777', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-25 09:07:51.559848+00', '2026-09-25 09:07:51.559848+00');
INSERT INTO public.edition_deadlines VALUES ('10a5104c-d4bb-464f-b886-ed86f5420ab1', '4138f476-8908-4a46-a623-f5f430a5d777', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-25 09:07:51.561302+00', '2026-09-25 09:07:51.561302+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('4138f476-8908-4a46-a623-f5f430a5d777', 'f031e9c3-9259-430c-978c-1955c31e6ded', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-25 09:07:51.549471+00', '2026-09-25 09:07:51.549471+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('f031e9c3-9259-430c-978c-1955c31e6ded', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'UK Construction Week', 'UKCW', '2026-09-25 09:07:51.519272+00', '2026-09-25 09:07:51.519272+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('73222469-6759-48dc-b196-7f106ee5276b', '4138f476-8908-4a46-a623-f5f430a5d777', 'Exhibitor Co', 'A10', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'beae1626-52f3-4bea-bb83-392f58f67e30', '2026-09-25 09:07:51.734851+00', '2026-09-25 09:07:51.734851+00');
INSERT INTO public.exhibitors VALUES ('1ecf9340-566c-4203-8eae-e4fa10574283', '4138f476-8908-4a46-a623-f5f430a5d777', 'SteelFrame Systems', 'A20', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'eba07fab-06b9-493d-a2d8-c89982b37e10', '2026-09-25 09:07:51.738688+00', '2026-09-25 09:07:51.738688+00');
INSERT INTO public.exhibitors VALUES ('ca3b973e-7e49-4f52-a66b-9dfa9cc8df54', '4138f476-8908-4a46-a623-f5f430a5d777', 'BrickWorks UK', 'A30', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'beae1626-52f3-4bea-bb83-392f58f67e30', '2026-09-25 09:07:51.742161+00', '2026-09-25 09:07:51.742161+00');
INSERT INTO public.exhibitors VALUES ('e854e371-ac48-40af-a5d0-dfc52acae3ed', '4138f476-8908-4a46-a623-f5f430a5d777', 'Timber Trade Ltd', 'B10', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'eba07fab-06b9-493d-a2d8-c89982b37e10', '2026-09-25 09:07:51.745172+00', '2026-09-25 09:07:51.745172+00');
INSERT INTO public.exhibitors VALUES ('7de0ca16-8325-4ca2-8fc2-ffda0379e15b', '4138f476-8908-4a46-a623-f5f430a5d777', 'GlassTech', 'B20', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'beae1626-52f3-4bea-bb83-392f58f67e30', '2026-09-25 09:07:51.748109+00', '2026-09-25 09:07:51.748109+00');
INSERT INTO public.exhibitors VALUES ('001d23ac-3da6-44f7-add8-99336b718228', '4138f476-8908-4a46-a623-f5f430a5d777', 'Insulate Pro', 'B30', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'eba07fab-06b9-493d-a2d8-c89982b37e10', '2026-09-25 09:07:51.751071+00', '2026-09-25 09:07:51.751071+00');
INSERT INTO public.exhibitors VALUES ('64392770-38f4-4571-9221-e26434c778bd', '4138f476-8908-4a46-a623-f5f430a5d777', 'RoofRight', 'C10', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'beae1626-52f3-4bea-bb83-392f58f67e30', '2026-09-25 09:07:51.754116+00', '2026-09-25 09:07:51.754116+00');
INSERT INTO public.exhibitors VALUES ('b7feaeca-8087-4e19-b0b4-00824e921961', '4138f476-8908-4a46-a623-f5f430a5d777', 'PlantHire Direct', 'C20', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'eba07fab-06b9-493d-a2d8-c89982b37e10', '2026-09-25 09:07:51.757224+00', '2026-09-25 09:07:51.757224+00');
INSERT INTO public.exhibitors VALUES ('c91e6de5-adf0-4dcc-930c-fb21c2aed06d', '4138f476-8908-4a46-a623-f5f430a5d777', 'SafetyFirst PPE', 'D10', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-25 09:07:51.760086+00', '2026-09-25 09:07:51.760086+00');
INSERT INTO public.exhibitors VALUES ('b88d7b8d-7de1-4347-87bc-92c0b706a02b', '4138f476-8908-4a46-a623-f5f430a5d777', 'ToolMart Retail', 'D20', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-25 09:07:51.762469+00', '2026-09-25 09:07:51.762469+00');
INSERT INTO public.exhibitors VALUES ('86d2308d-2aa5-4092-8d0e-9644c3851bfb', '4138f476-8908-4a46-a623-f5f430a5d777', 'EcoBuild Materials', 'D30', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-25 09:07:51.764783+00', '2026-09-25 09:07:51.764783+00');
INSERT INTO public.exhibitors VALUES ('0349cf17-e430-4e0b-a8da-51a144c5a425', '4138f476-8908-4a46-a623-f5f430a5d777', 'SiteWise Software', 'D40', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-25 09:07:51.76667+00', '2026-09-25 09:07:51.76667+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('24199cc6-2c25-4b6c-8456-b33a4782f54c', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'venue', 'venue', '3aa02667-0068-41d3-b5b6-eaec64a59b63', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.720113+00', '2026-09-25 09:07:51.720113+00');
INSERT INTO public.external_grants VALUES ('117b0e44-508b-4942-a5ab-0599c1642f9c', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.723782+00', '2026-09-25 09:07:51.723782+00');
INSERT INTO public.external_grants VALUES ('0afcb80d-b2f7-41e2-9a6f-547390e9308f', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.726706+00', '2026-09-25 09:07:51.726706+00');
INSERT INTO public.external_grants VALUES ('60f42a44-07b7-44f5-a63d-c98e171396bb', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'supplier', 'supplier', 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.729517+00', '2026-09-25 09:07:51.729517+00');
INSERT INTO public.external_grants VALUES ('b2d5f7ac-1782-4c21-9d67-4f0a648b6ddf', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'sponsor', 'sponsor', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.732319+00', '2026-09-25 09:07:51.732319+00');
INSERT INTO public.external_grants VALUES ('e510d090-0516-4e61-af2c-a88eea0b26c5', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'exhibitor', 'exhibitor', '73222469-6759-48dc-b196-7f106ee5276b', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-25 09:07:51.461+00', NULL, '2026-09-25 09:07:51.769581+00', '2026-09-25 09:07:51.769581+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '4138f476-8908-4a46-a623-f5f430a5d777', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-25 09:07:51.564325+00', '2026-09-25 09:07:51.564325+00');
INSERT INTO public.halls VALUES ('513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '4138f476-8908-4a46-a623-f5f430a5d777', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-25 09:07:51.567361+00', '2026-09-25 09:07:51.567361+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('afa9bfba-3f12-41c4-8fe0-dfe2b762b4b7', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Hanging banner', 'hanging_banner', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'rigged', true, 0, '2026-09-25 09:07:51.686328+00', '2026-09-25 09:07:51.686328+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('89133fca-dea5-4747-bf6a-64593be2628e', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Foamex board', 'foamex_board', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'wall_mounted', false, 1, '2026-09-25 09:07:51.688732+00', '2026-09-25 09:07:51.688732+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('bc27d33b-55c1-4a70-8e1b-868ec75683be', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Fabric graphic', 'fabric_graphic', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'shell_mounted', false, 2, '2026-09-25 09:07:51.690645+00', '2026-09-25 09:07:51.690645+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('40d4c26e-dd96-4415-bf15-ee12823d5b94', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Floor vinyl', 'floor_vinyl', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'floor', false, 3, '2026-09-25 09:07:51.69243+00', '2026-09-25 09:07:51.69243+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('16309605-bbf2-43ae-909c-7f9303c7b789', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Aisle sign', 'aisle_sign', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'rigged', true, 4, '2026-09-25 09:07:51.694419+00', '2026-09-25 09:07:51.694419+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('69b209a9-4be5-4633-92c4-eac332568ce0', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Entrance feature', 'entrance_feature', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'freestanding', true, 5, '2026-09-25 09:07:51.696416+00', '2026-09-25 09:07:51.696416+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('49ddbcb6-7443-4b93-80b5-5325ecef626a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Registration', 'registration', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'freestanding', false, 6, '2026-09-25 09:07:51.698426+00', '2026-09-25 09:07:51.698426+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('c84fe634-a869-48a9-b816-366cd862fc27', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Seminar theatre', 'seminar_theatre', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'freestanding', false, 7, '2026-09-25 09:07:51.70015+00', '2026-09-25 09:07:51.70015+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('da95cd9a-839e-430e-a4a5-a0c10cf34e4d', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Feature area', 'feature_area', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'freestanding', false, 8, '2026-09-25 09:07:51.701916+00', '2026-09-25 09:07:51.701916+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('a5ed94c7-00fd-47d4-a9f5-65e87b927ba9', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'External', 'external', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'freestanding', true, 9, '2026-09-25 09:07:51.703721+00', '2026-09-25 09:07:51.703721+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('bfe219c3-4def-425d-9f5c-3472e8675ec2', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Digital screen', 'digital_screen', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 'digital', false, 10, '2026-09-25 09:07:51.705431+00', '2026-09-25 09:07:51.705431+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('02ffed0d-13a6-467f-a31f-8e292e1e174e', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Branded lanyards', 'lanyard', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', NULL, false, 11, '2026-09-25 09:07:51.707465+00', '2026-09-25 09:07:51.707465+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('30928dc1-a09e-457e-9676-b977b12f5cc0', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Show bags', 'show_bag', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', NULL, false, 12, '2026-09-25 09:07:51.708837+00', '2026-09-25 09:07:51.708837+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('54db259b-6a47-43fb-925a-52262bc25c09', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Registration branding', 'reg_branding', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', NULL, false, 13, '2026-09-25 09:07:51.710203+00', '2026-09-25 09:07:51.710203+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('e88eae0e-d92e-4385-b930-890b5e767c36', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Other signage', 'other_signage', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', NULL, false, 14, '2026-09-25 09:07:51.71146+00', '2026-09-25 09:07:51.71146+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('2fe22bf4-322c-49a9-82ba-d78baccb59cb', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Other sponsorship item', 'other_sponsorship', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', NULL, false, 15, '2026-09-25 09:07:51.712964+00', '2026-09-25 09:07:51.712964+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('62ea45b8-72b3-4354-ab74-d80bd26ba061', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-25 09:07:51.570956+00', '2026-09-25 09:07:51.570956+00');
INSERT INTO public.locations VALUES ('2fbe67d0-0772-4967-a6b9-11934c6c54f4', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-25 09:07:51.575133+00', '2026-09-25 09:07:51.575133+00');
INSERT INTO public.locations VALUES ('553e6f18-8f63-4ca3-89a0-06c217b6094f', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-25 09:07:51.577939+00', '2026-09-25 09:07:51.577939+00');
INSERT INTO public.locations VALUES ('82b9f128-95c8-44b9-9adc-5cd3f1a08b0b', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-25 09:07:51.580587+00', '2026-09-25 09:07:51.580587+00');
INSERT INTO public.locations VALUES ('4bfda264-f5c9-4da8-963d-a257bf640f6a', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-25 09:07:51.583035+00', '2026-09-25 09:07:51.583035+00');
INSERT INTO public.locations VALUES ('68d18351-8431-4968-bb2e-dc0d83c6671d', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-25 09:07:51.585596+00', '2026-09-25 09:07:51.585596+00');
INSERT INTO public.locations VALUES ('b40ad58c-b751-41ab-9b6e-dacb0081ae10', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-25 09:07:51.588261+00', '2026-09-25 09:07:51.588261+00');
INSERT INTO public.locations VALUES ('c51fd2c0-2eba-4548-8a0a-8a1d48678e6d', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-25 09:07:51.590837+00', '2026-09-25 09:07:51.590837+00');
INSERT INTO public.locations VALUES ('3d948a6a-3448-4f20-83d6-12371b44c4f6', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-25 09:07:51.593429+00', '2026-09-25 09:07:51.593429+00');
INSERT INTO public.locations VALUES ('5d2edeec-6895-4d9b-aa62-c2f8d6f88fbf', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-25 09:07:51.595871+00', '2026-09-25 09:07:51.595871+00');
INSERT INTO public.locations VALUES ('733fdbae-c9c2-4a2f-b427-2dc84814c032', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-25 09:07:51.598437+00', '2026-09-25 09:07:51.598437+00');
INSERT INTO public.locations VALUES ('8ff07995-5f37-4ac8-bac5-29376e29e595', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-25 09:07:51.601049+00', '2026-09-25 09:07:51.601049+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('d18f6a3a-cb1f-4877-9a51-337e18de8cc6', '00000000-0000-4000-8000-000000000001', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'admin', '2026-09-25 09:07:51.502907+00', '2026-09-25 09:07:51.502907+00', '{}');
INSERT INTO public.memberships VALUES ('589d1169-53e8-4f58-abf6-3f206437a5f8', '00000000-0000-4000-8000-000000000002', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'ops', '2026-09-25 09:07:51.506348+00', '2026-09-25 09:07:51.506348+00', '{}');
INSERT INTO public.memberships VALUES ('72451d3d-beeb-4093-8d08-19561ecb4233', '00000000-0000-4000-8000-000000000004', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'sales', '2026-09-25 09:07:51.511831+00', '2026-09-25 09:07:51.511831+00', '{}');
INSERT INTO public.memberships VALUES ('1a2f07a5-dcca-45e2-bdf5-55e7e1cea8e6', '00000000-0000-4000-8000-000000000005', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'event_director', '2026-09-25 09:07:51.51431+00', '2026-09-25 09:07:51.51431+00', '{}');
INSERT INTO public.memberships VALUES ('e53d1329-0b03-4735-9b65-70588b827ced', '00000000-0000-4000-8000-000000000006', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'viewer', '2026-09-25 09:07:51.517411+00', '2026-09-25 09:07:51.517411+00', '{}');
INSERT INTO public.memberships VALUES ('f5033c3b-d17e-443e-b9dd-a0daf0d3839f', '00000000-0000-4000-8000-000000000003', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'marketing', '2026-09-25 09:07:51.508786+00', '2026-09-25 09:07:52.392808+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-25 09:07:51.49579+00', '2026-09-25 09:07:51.49579+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('0e238745-02ea-45e5-9f3b-e29547d8e3b0', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '69b209a9-4be5-4633-92c4-eac332568ce0', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '62ea45b8-72b3-4354-ab74-d80bd26ba061', 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', '842374cc-5f51-46ec-a3b6-468a84ae6f8e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '7e5d7dd0-bfd0-4747-a05d-1a6b8a7e732d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.774631+00', '2026-09-25 09:07:51.780095+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('bc2af7d9-5627-4783-be11-da3471623eec', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '49ddbcb6-7443-4b93-80b5-5325ecef626a', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '2fbe67d0-0772-4967-a6b9-11934c6c54f4', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'e2b3eeef-4716-429c-af75-a974536e4206', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.801362+00', '2026-09-25 09:07:51.805563+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('6c2c7a08-7e60-414a-85c9-785a804e556a', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', 'afa9bfba-3f12-41c4-8fe0-dfe2b762b4b7', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '553e6f18-8f63-4ca3-89a0-06c217b6094f', 'ops', '00000000-0000-4000-8000-000000000002', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', 'e354f3b2-f825-4e0a-bae6-0331d63d9839', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '3a9d3285-83a8-4b3a-b24d-09204a9a71a9', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.821606+00', '2026-09-25 09:07:51.826659+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('0fa7ffb7-0d33-4063-a5b1-7bfef014cd7a', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'c84fe634-a869-48a9-b816-366cd862fc27', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '82b9f128-95c8-44b9-9adc-5cd3f1a08b0b', 'marketing', '00000000-0000-4000-8000-000000000003', '72d7cb7e-ad4f-46d2-97ec-2ca33c6f7e80', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '6502bded-13bd-40b6-98ce-078245d1a202', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.842483+00', '2026-09-25 09:07:51.846143+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('4190ec67-fd3e-45d8-87ed-6ebf50c43ffe', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '40d4c26e-dd96-4415-bf15-ee12823d5b94', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '4bfda264-f5c9-4da8-963d-a257bf640f6a', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '4c4638b3-9344-4a98-b0ce-c5bb000a0ba4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.862976+00', '2026-09-25 09:07:51.867345+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('ea02d77c-96db-41f3-8077-1b661b76d4ac', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', 'da95cd9a-839e-430e-a4a5-a0c10cf34e4d', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '68d18351-8431-4968-bb2e-dc0d83c6671d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '886c7b29-3a22-4af9-a043-042738e3f6cb', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.883654+00', '2026-09-25 09:07:51.887075+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "ccde4a57-9587-485b-8298-d55285faf0e3", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('075a8442-d635-4c09-93e0-933e6ab7b38c', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', 'afa9bfba-3f12-41c4-8fe0-dfe2b762b4b7', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'b40ad58c-b751-41ab-9b6e-dacb0081ae10', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'ba9aced1-136f-4c5c-a8e5-67af7660afac', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.901687+00', '2026-09-25 09:07:51.904737+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('05d6d75c-cc59-442f-a4bd-f408376ccb52', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '16309605-bbf2-43ae-909c-7f9303c7b789', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'c51fd2c0-2eba-4548-8a0a-8a1d48678e6d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '3a09b4b1-43a4-4c2f-8964-d61a9e91fdaa', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.921438+00', '2026-09-25 09:07:51.924741+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('66597286-19c5-4f3b-afb7-32ebc6f3eb4b', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'c84fe634-a869-48a9-b816-366cd862fc27', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '3d948a6a-3448-4f20-83d6-12371b44c4f6', 'marketing', '00000000-0000-4000-8000-000000000003', '72d7cb7e-ad4f-46d2-97ec-2ca33c6f7e80', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '04fe3e86-52a4-4a0c-af50-df9a668759bd', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.943021+00', '2026-09-25 09:07:51.946526+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('c4fecc92-63d6-49a2-8bbe-30f8c2996921', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'bc27d33b-55c1-4a70-8e1b-868ec75683be', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '5d2edeec-6895-4d9b-aa62-c2f8d6f88fbf', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '001bcc44-b89d-4c7a-aa86-fbab79e302cb', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.968045+00', '2026-09-25 09:07:51.972106+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('4b54b697-6f59-4931-8703-130a2fa3e1b7', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'a5ed94c7-00fd-47d4-a9f5-65e87b927ba9', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '733fdbae-c9c2-4a2f-b427-2dc84814c032', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'ea9add58-9590-409f-84d1-1a03a83e9b56', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:51.991669+00', '2026-09-25 09:07:51.995097+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('f5748252-a140-4ca7-a8c9-dba42b1215b3', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '8ff07995-5f37-4ac8-bac5-29376e29e595', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '835794f5-5efb-4c96-bd9e-102d45a8be7e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.012167+00', '2026-09-25 09:07:52.015806+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('df808d6c-c058-4696-9001-163c94f1393b', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'bfe219c3-4def-425d-9f5c-3472e8675ec2', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '2fbe67d0-0772-4967-a6b9-11934c6c54f4', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '57525ee6-5859-4c16-9a8e-b1ee34c6c3f0', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '6a2f49b5-9e80-445f-8ecd-31f25274fcfc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.027646+00', '2026-09-25 09:07:52.032004+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "ccde4a57-9587-485b-8298-d55285faf0e3", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('d7e17fbf-72c1-4fb2-b490-64f24b4963a1', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '16309605-bbf2-43ae-909c-7f9303c7b789', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '553e6f18-8f63-4ca3-89a0-06c217b6094f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'cff2f285-0949-4b75-a264-98c56963a669', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.050278+00', '2026-09-25 09:07:52.05399+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('7a19d181-98f1-46fd-8a0c-4be677603f8d', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '4bfda264-f5c9-4da8-963d-a257bf640f6a', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '113f21bb-43c3-490b-8918-bb4c6b117524', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.066985+00', '2026-09-25 09:07:52.07015+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('6bd912ad-fc12-411d-9d41-3900ae81a663', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', 'da95cd9a-839e-430e-a4a5-a0c10cf34e4d', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '68d18351-8431-4968-bb2e-dc0d83c6671d', 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'b660a270-d67e-4a95-a481-97e133b9832c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.087417+00', '2026-09-25 09:07:52.091129+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('e01b2421-e723-4f67-85a2-9168eff64e8a', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', 'afa9bfba-3f12-41c4-8fe0-dfe2b762b4b7', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'c51fd2c0-2eba-4548-8a0a-8a1d48678e6d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '1c943884-9b54-4cb5-98af-c0ed2ec13683', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.1058+00', '2026-09-25 09:07:52.108341+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('f4d33d6c-3481-4ab2-b751-2c0755383959', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'bc27d33b-55c1-4a70-8e1b-868ec75683be', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '5d2edeec-6895-4d9b-aa62-c2f8d6f88fbf', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'c94d831d-1b59-4569-8333-91dec4ac45f0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.123136+00', '2026-09-25 09:07:52.126703+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('2fe0c64e-d843-4dd3-acd5-92c19b1538d2', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', 'afa9bfba-3f12-41c4-8fe0-dfe2b762b4b7', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '553e6f18-8f63-4ca3-89a0-06c217b6094f', 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', 'e354f3b2-f825-4e0a-bae6-0331d63d9839', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '89e72021-ace4-4b62-8a6a-67369bc8c73a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.139645+00', '2026-09-25 09:07:52.147945+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('06861d16-56db-45e4-8979-04e582fcfc00', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '8ff07995-5f37-4ac8-bac5-29376e29e595', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.170784+00', '2026-09-25 09:07:52.170784+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('9d70bcd2-2d71-4a41-a563-c97a82dd65f0', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '2fbe67d0-0772-4967-a6b9-11934c6c54f4', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.174364+00', '2026-09-25 09:07:52.174364+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('70baaa2e-08ec-4dfe-98be-e591114b6e38', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '49ddbcb6-7443-4b93-80b5-5325ecef626a', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', 'b40ad58c-b751-41ab-9b6e-dacb0081ae10', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.178041+00', '2026-09-25 09:07:52.178041+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('53c8f56a-d03d-48f4-8eaa-46bbe0ff4298', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'bfe219c3-4def-425d-9f5c-3472e8675ec2', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '68d18351-8431-4968-bb2e-dc0d83c6671d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '57525ee6-5859-4c16-9a8e-b1ee34c6c3f0', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.18239+00', '2026-09-25 09:07:52.18239+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "ccde4a57-9587-485b-8298-d55285faf0e3", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('aa685f12-55bf-4595-a41e-47acef4d2338', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '40d4c26e-dd96-4415-bf15-ee12823d5b94', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '3d948a6a-3448-4f20-83d6-12371b44c4f6', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.186902+00', '2026-09-25 09:07:52.186902+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('66f0f7d2-cfdf-4a6c-8900-9563341529c5', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'c84fe634-a869-48a9-b816-366cd862fc27', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '3d948a6a-3448-4f20-83d6-12371b44c4f6', 'marketing', '00000000-0000-4000-8000-000000000003', '72d7cb7e-ad4f-46d2-97ec-2ca33c6f7e80', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.191756+00', '2026-09-25 09:07:52.191756+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('2b5778a1-a679-4b74-9407-c49af61c5906', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'a5ed94c7-00fd-47d4-a9f5-65e87b927ba9', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '733fdbae-c9c2-4a2f-b427-2dc84814c032', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.196614+00', '2026-09-25 09:07:52.196614+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "ccde4a57-9587-485b-8298-d55285faf0e3", "userId": "00000000-0000-4000-8000-000000000005"}]');
INSERT INTO public.signage_items VALUES ('70d49eae-9fa4-46f5-93e3-e394a5b7a11d', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '733fdbae-c9c2-4a2f-b427-2dc84814c032', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.201661+00', '2026-09-25 09:07:52.201661+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('beae97b9-e11a-4848-a5da-dc76d7ed6e61', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '4bfda264-f5c9-4da8-963d-a257bf640f6a', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'd11a82d3-9587-4be2-8104-f7d0e246bf06', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.206441+00', '2026-09-25 09:07:52.210772+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('29fc11a0-62ef-4cb1-9099-0ba948b0a6e4', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '69b209a9-4be5-4633-92c4-eac332568ce0', '97c6f90d-e3ce-43f6-9351-f826e3bed7b5', '62ea45b8-72b3-4354-ab74-d80bd26ba061', 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', '842374cc-5f51-46ec-a3b6-468a84ae6f8e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, '9c1139e4-d2ca-48b5-a7f8-0a6089864866', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.233384+00', '2026-09-25 09:07:52.238062+00', 'signage', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('1a2bd64f-45bc-4722-9a7b-529e584e2685', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '89133fca-dea5-4747-bf6a-64593be2628e', '513e7bdc-de44-4fe0-8d9d-afc1d21d7c48', '8ff07995-5f37-4ac8-bac5-29376e29e595', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.255017+00', '2026-09-25 09:07:52.255017+00', 'signage', 'organiser', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}]');
INSERT INTO public.signage_items VALUES ('bf5d1b9b-01bb-497d-8ec0-672e9ac081fc', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '02ffed0d-13a6-467f-a31f-8e292e1e174e', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 'c15348dd-fa5c-444d-a9c3-e9411e151a79', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.259389+00', '2026-09-25 09:07:52.263138+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');
INSERT INTO public.signage_items VALUES ('f9724379-9c40-4a75-a75e-adceeae9c3fe', '4138f476-8908-4a46-a623-f5f430a5d777', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '30928dc1-a09e-457e-9676-b977b12f5cc0', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 09:07:52.28035+00', '2026-09-25 09:07:52.28035+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3a0156da-62f1-43dd-b057-3eaaf0cd6bdb", "userId": null}, {"stepId": "9810bb49-e881-4fe8-80b5-03f23e5429d6", "userId": null}, {"stepId": "93bf59a4-23ba-4b1b-aaf5-a635219b3578", "userId": null}]');


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('41bb5306-a36f-405f-a9e7-9cc521736a2e', '4138f476-8908-4a46-a623-f5f430a5d777', '7a19d181-98f1-46fd-8a0c-4be677603f8d', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'ff71ef63-e5f8-46a2-8e2c-c274efe368f8', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-25 09:07:52.083172+00', '2026-09-25 09:07:52.083172+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('e354f3b2-f825-4e0a-bae6-0331d63d9839', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', 'Logo on 6 hanging banners', 6, '2026-09-25 09:07:51.642328+00', '2026-09-25 09:07:51.642328+00');
INSERT INTO public.sponsor_entitlements VALUES ('842374cc-5f51-46ec-a3b6-468a84ae6f8e', 'a7e2ef91-9536-452a-b6ad-19a09d3237dd', 'Entrance feature branding', 1, '2026-09-25 09:07:51.645075+00', '2026-09-25 09:07:51.645075+00');
INSERT INTO public.sponsor_entitlements VALUES ('716d32d7-bf76-46fc-b1e2-215b5d119c4a', '72d7cb7e-ad4f-46d2-97ec-2ca33c6f7e80', 'Seminar theatre branding', 1, '2026-09-25 09:07:51.650302+00', '2026-09-25 09:07:51.650302+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('a7e2ef91-9536-452a-b6ad-19a09d3237dd', '4138f476-8908-4a46-a623-f5f430a5d777', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-25 09:07:51.638868+00', '2026-09-25 09:07:51.638868+00');
INSERT INTO public.sponsors VALUES ('72d7cb7e-ad4f-46d2-97ec-2ca33c6f7e80', '4138f476-8908-4a46-a623-f5f430a5d777', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-25 09:07:51.647642+00', '2026-09-25 09:07:51.647642+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('8f495dc6-c3cb-43c0-be5e-8f72eef433f0', '4138f476-8908-4a46-a623-f5f430a5d777', '73222469-6759-48dc-b196-7f106ee5276b', 'STD-BIRM27-A10', 'beae1626-52f3-4bea-bb83-392f58f67e30', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 09:07:51.461+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.288635+00', '2026-09-25 09:07:52.288635+00');
INSERT INTO public.stand_submissions VALUES ('169a77f2-41f9-461c-bbf9-83eb0b90f01d', '4138f476-8908-4a46-a623-f5f430a5d777', '1ecf9340-566c-4203-8eae-e4fa10574283', 'STD-BIRM27-A20', 'eba07fab-06b9-493d-a2d8-c89982b37e10', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 09:07:51.461+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.309247+00', '2026-09-25 09:07:52.309247+00');
INSERT INTO public.stand_submissions VALUES ('db692544-6fc9-4a89-b924-4e66e3c66d39', '4138f476-8908-4a46-a623-f5f430a5d777', 'ca3b973e-7e49-4f52-a66b-9dfa9cc8df54', 'STD-BIRM27-A30', 'beae1626-52f3-4bea-bb83-392f58f67e30', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-19 09:07:51.461+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.328327+00', '2026-09-25 09:07:52.328327+00');
INSERT INTO public.stand_submissions VALUES ('48804e0a-cef2-4ee0-b104-cbb1ead3384f', '4138f476-8908-4a46-a623-f5f430a5d777', 'e854e371-ac48-40af-a5d0-dfc52acae3ed', 'STD-BIRM27-B10', 'eba07fab-06b9-493d-a2d8-c89982b37e10', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-19 09:07:51.461+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.343119+00', '2026-09-25 09:07:52.343119+00');
INSERT INTO public.stand_submissions VALUES ('5659ea33-12fb-4038-a7a9-b4f4a7ae0e0f', '4138f476-8908-4a46-a623-f5f430a5d777', '7de0ca16-8325-4ca2-8fc2-ffda0379e15b', 'STD-BIRM27-B20', 'beae1626-52f3-4bea-bb83-392f58f67e30', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-19 09:07:51.461+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.364141+00', '2026-09-25 09:07:52.364141+00');
INSERT INTO public.stand_submissions VALUES ('cea796e9-22e3-490f-98dd-4235cbc41971', '4138f476-8908-4a46-a623-f5f430a5d777', '001d23ac-3da6-44f7-add8-99336b718228', 'STD-BIRM27-B30', 'eba07fab-06b9-493d-a2d8-c89982b37e10', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.381961+00', '2026-09-25 09:07:52.381961+00');
INSERT INTO public.stand_submissions VALUES ('f108d197-46c2-40fb-91d7-922337b561b4', '4138f476-8908-4a46-a623-f5f430a5d777', '64392770-38f4-4571-9221-e26434c778bd', 'STD-BIRM27-C10', 'beae1626-52f3-4bea-bb83-392f58f67e30', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.386488+00', '2026-09-25 09:07:52.386488+00');
INSERT INTO public.stand_submissions VALUES ('d0440094-cee8-4e8b-9fef-24e61d412ecf', '4138f476-8908-4a46-a623-f5f430a5d777', 'b7feaeca-8087-4e19-b0b4-00824e921961', 'STD-BIRM27-C20', 'eba07fab-06b9-493d-a2d8-c89982b37e10', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '9177de5a-9963-4897-a2a4-67824d5810ea', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 09:07:52.38977+00', '2026-09-25 09:07:52.38977+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('ff71ef63-e5f8-46a2-8e2c-c274efe368f8', '8c8cf955-776e-470e-936f-a0a92b28b8a7');
INSERT INTO public.supplier_service_links VALUES ('ff71ef63-e5f8-46a2-8e2c-c274efe368f8', '4f88effc-15a7-420c-bdd1-25a5fb848d30');
INSERT INTO public.supplier_service_links VALUES ('18757ba1-1ea8-4b07-a30f-1cfabb486e9f', 'e115af20-f5b9-43ef-956c-509abc66859c');
INSERT INTO public.supplier_service_links VALUES ('18757ba1-1ea8-4b07-a30f-1cfabb486e9f', '4f88effc-15a7-420c-bdd1-25a5fb848d30');
INSERT INTO public.supplier_service_links VALUES ('18757ba1-1ea8-4b07-a30f-1cfabb486e9f', '0880f537-c0c3-4903-b53e-1812669fd5ef');
INSERT INTO public.supplier_service_links VALUES ('57525ee6-5859-4c16-9a8e-b1ee34c6c3f0', '36392d9b-ebdd-49d6-870e-08926a84478a');
INSERT INTO public.supplier_service_links VALUES ('57525ee6-5859-4c16-9a8e-b1ee34c6c3f0', '0880f537-c0c3-4903-b53e-1812669fd5ef');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('8c8cf955-776e-470e-936f-a0a92b28b8a7', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Signage print', 1, false, '2026-09-25 09:07:51.612632+00', '2026-09-25 09:07:51.612632+00');
INSERT INTO public.supplier_services VALUES ('36392d9b-ebdd-49d6-870e-08926a84478a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Digital screens & AV', 2, false, '2026-09-25 09:07:51.614285+00', '2026-09-25 09:07:51.614285+00');
INSERT INTO public.supplier_services VALUES ('e115af20-f5b9-43ef-956c-509abc66859c', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Rigging', 3, false, '2026-09-25 09:07:51.615881+00', '2026-09-25 09:07:51.615881+00');
INSERT INTO public.supplier_services VALUES ('4f88effc-15a7-420c-bdd1-25a5fb848d30', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Installation', 4, false, '2026-09-25 09:07:51.617067+00', '2026-09-25 09:07:51.617067+00');
INSERT INTO public.supplier_services VALUES ('0880f537-c0c3-4903-b53e-1812669fd5ef', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Staffing', 5, false, '2026-09-25 09:07:51.618115+00', '2026-09-25 09:07:51.618115+00');
INSERT INTO public.supplier_services VALUES ('b9a4efbd-82d6-4602-8de7-4821b8ea15dd', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Furniture', 6, false, '2026-09-25 09:07:51.619275+00', '2026-09-25 09:07:51.619275+00');
INSERT INTO public.supplier_services VALUES ('a22d064a-3c8e-4db0-8265-ea6146fe6519', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Structural engineering', 7, false, '2026-09-25 09:07:51.620694+00', '2026-09-25 09:07:51.620694+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('ff71ef63-e5f8-46a2-8e2c-c274efe368f8', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-25 09:07:51.603959+00', '2026-09-25 09:07:51.603959+00');
INSERT INTO public.suppliers VALUES ('18757ba1-1ea8-4b07-a30f-1cfabb486e9f', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-25 09:07:51.607096+00', '2026-09-25 09:07:51.607096+00');
INSERT INTO public.suppliers VALUES ('57525ee6-5859-4c16-9a8e-b1ee34c6c3f0', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-25 09:07:51.610112+00', '2026-09-25 09:07:51.610112+00');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('29268fd9-0a88-4126-b40f-e7ddf58073e7', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', '4138f476-8908-4a46-a623-f5f430a5d777', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-02', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '0e238745-02ea-45e5-9f3b-e29547d8e3b0', NULL, '2026-09-25 09:07:52.398079+00', '2026-09-25 09:07:52.398079+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.500273+00', '2026-09-25 09:07:51.500273+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.505268+00', '2026-09-25 09:07:51.505268+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.50768+00', '2026-09-25 09:07:51.50768+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.510271+00', '2026-09-25 09:07:51.510271+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.513241+00', '2026-09-25 09:07:51.513241+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-25 09:07:51.516059+00', '2026-09-25 09:07:51.516059+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.714886+00', '2026-09-25 09:07:51.714886+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.721903+00', '2026-09-25 09:07:51.721903+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.724708+00', '2026-09-25 09:07:51.724708+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.727896+00', '2026-09-25 09:07:51.727896+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.730709+00', '2026-09-25 09:07:51.730709+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-25 09:07:51.767932+00', '2026-09-25 09:07:51.767932+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('75dbe4be-d9fc-4bbf-a63c-25c725f6ee97', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-25 09:07:51.529764+00', '2026-09-25 09:07:51.529764+00');
INSERT INTO public.venue_rules VALUES ('44e8b305-2a0c-4f41-b6d5-b046aa23da03', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-25 09:07:51.532849+00', '2026-09-25 09:07:51.532849+00');
INSERT INTO public.venue_rules VALUES ('e740362b-3dab-4bc5-a52a-b077aca8d0bb', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-25 09:07:51.535609+00', '2026-09-25 09:07:51.535609+00');
INSERT INTO public.venue_rules VALUES ('a798d38e-9e24-4a13-9512-15233cf0eb96', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-25 09:07:51.538182+00', '2026-09-25 09:07:51.538182+00');
INSERT INTO public.venue_rules VALUES ('90e3badb-63ee-4919-a1a7-a9269d842823', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-25 09:07:51.541034+00', '2026-09-25 09:07:51.541034+00');
INSERT INTO public.venue_rules VALUES ('7cdcf199-2d4d-45e3-82ea-00b1b37c8899', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-25 09:07:51.543496+00', '2026-09-25 09:07:51.543496+00');
INSERT INTO public.venue_rules VALUES ('d35f7960-9d05-439f-9204-7bc42cbe42e8', '3aa02667-0068-41d3-b5b6-eaec64a59b63', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-25 09:07:51.546127+00', '2026-09-25 09:07:51.546127+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('3aa02667-0068-41d3-b5b6-eaec64a59b63', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-25 09:07:51.521925+00', '2026-09-25 09:07:51.521925+00');
INSERT INTO public.venues VALUES ('15b1a334-7709-490a-85a6-50636a6d220a', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-25 09:07:51.524327+00', '2026-09-25 09:07:51.524327+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('3a0156da-62f1-43dd-b057-3eaaf0cd6bdb', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 1, 1, 'Operations sign-off', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-25 09:07:51.656043+00', '2026-09-25 09:07:51.656043+00', '{organiser,sponsor}', false);
INSERT INTO public.workflow_steps VALUES ('9810bb49-e881-4fe8-80b5-03f23e5429d6', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 2, 1, 'Marketing sign-off', 'approval', 'role', 'marketing', NULL, '{always}', 3, true, true, '2026-09-25 09:07:51.65811+00', '2026-09-25 09:07:51.65811+00', '{organiser,sponsor}', false);
INSERT INTO public.workflow_steps VALUES ('93bf59a4-23ba-4b1b-aaf5-a635219b3578', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 3, 1, 'Sales sign-off', 'approval', 'role', 'sales', NULL, '{always}', 5, true, true, '2026-09-25 09:07:51.659594+00', '2026-09-25 09:07:51.659594+00', '{sponsor}', false);
INSERT INTO public.workflow_steps VALUES ('3d25a3d7-ff5c-4822-8ec3-d16d3b952fd3', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-25 09:07:51.660599+00', '2026-09-25 09:07:51.660599+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('c889029e-f8a3-4721-be31-2da328ae1c8c', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-25 09:07:51.662593+00', '2026-09-25 09:07:51.662593+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('96add679-b202-4e0b-9570-54ea24861b5e', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-25 09:07:51.66368+00', '2026-09-25 09:07:51.66368+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('7358ed4b-fd5c-4457-98b2-c3fed5f9fafd', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 09:07:51.664642+00', '2026-09-25 09:07:51.664642+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('ccde4a57-9587-485b-8298-d55285faf0e3', 'baaa432e-c7fc-40ab-8ae3-79632a462bae', 5, NULL, 'Senior management sign-off', 'approval', 'user', 'event_director', '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-25 09:07:51.661528+00', '2026-09-25 09:07:51.668386+00', '{organiser,sponsor}', false);
INSERT INTO public.workflow_steps VALUES ('cc09062a-a88e-4722-a476-10f84ac3d6cb', '9177de5a-9963-4897-a2a4-67824d5810ea', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-25 09:07:51.676008+00', '2026-09-25 09:07:51.676008+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('2fc4b179-4ac1-4211-a94e-3e4657785bb5', '9177de5a-9963-4897-a2a4-67824d5810ea', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-25 09:07:51.677342+00', '2026-09-25 09:07:51.677342+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('e6f0b196-b968-4307-9254-36f07e1df5ab', '9177de5a-9963-4897-a2a4-67824d5810ea', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-25 09:07:51.678787+00', '2026-09-25 09:07:51.678787+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('52809c58-529a-4a39-901e-09f5f7628836', '9177de5a-9963-4897-a2a4-67824d5810ea', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-25 09:07:51.680146+00', '2026-09-25 09:07:51.680146+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('8541c5dc-2c9a-4ce4-b08c-37cca8ac8d28', '9177de5a-9963-4897-a2a4-67824d5810ea', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-25 09:07:51.681626+00', '2026-09-25 09:07:51.681626+00', '{}', false);
INSERT INTO public.workflow_steps VALUES ('5efa9bef-e6c7-49d8-88e3-af0e6f21e156', '9177de5a-9963-4897-a2a4-67824d5810ea', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 09:07:51.683249+00', '2026-09-25 09:07:51.683249+00', '{}', false);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('baaa432e-c7fc-40ab-8ae3-79632a462bae', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Signage default', 'signage', true, false, '2026-09-25 09:07:51.653773+00', '2026-09-25 09:07:51.653773+00');
INSERT INTO public.workflows VALUES ('9177de5a-9963-4897-a2a4-67824d5810ea', 'a758fa69-2eed-44ec-8ed6-a45ed25ac109', 'Stand default', 'stand', true, false, '2026-09-25 09:07:51.674151+00', '2026-09-25 09:07:51.674151+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 5, true);


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

\unrestrict sZylTQjzaQ9tcaAl6uSkFAZvzt9ea7Ts2ptQtpWJNzxhhmcChDqAdszFZb0RllC

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
