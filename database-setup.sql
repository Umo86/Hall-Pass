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

\restrict xvmUQ1Ms52aIJW1RpydhUcfPLtRejAuwqVbiZb6ybz9IiMiytl8bbbMMEbcPdsa

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
    'directional',
    'venue',
    'sponsorship'
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    kind public.item_kind DEFAULT 'signage'::public.item_kind NOT NULL
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
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organisation_id uuid NOT NULL,
    name text NOT NULL,
    kind public.supplier_kind NOT NULL,
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('8681cb36-6e09-417f-9d3b-25f1fa955a69', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5ce38340-36cb-49ea-af74-61d645888f98', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b3761331-038a-480c-a8ac-197fac17f1e0', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5d7a9d22-d6f1-4d99-bfb5-fd27e73df493', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6f25182d-6287-458e-95ab-8de730919256', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'waiting', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a8f941b1-ad0f-4239-a4b5-209bc4dc5040', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('95b84bfc-a274-4ec4-9fe0-3d3b0c745f42', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f0e57fc9-cc59-4641-b4e4-33f7cdb0baf9', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.439693+00', '2026-09-24 21:48:22.439693+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e41c0b62-fd22-4b03-8a66-09e69290d795', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7361d377-cd19-4789-9432-43f234d5cb0c', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('87c55c7c-46aa-4654-8c2d-0c04284abb14', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('408fc6c7-ffc2-4f91-abf5-0c14b1263dd4', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('07edde78-9c49-442c-95d8-07a48edfe3ec', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('982b2230-f2b8-4458-9d69-3227967e3213', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('717f59ba-681b-4332-87f6-4848ee6c932e', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('d441a7a6-bb73-4c38-a348-64bc1a2a9b66', 'signage_item', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.461215+00', '2026-09-24 21:48:22.461215+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('59b1c301-fd6e-4d63-b816-5a15287a46e9', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-14 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-12 21:48:22.187+00', '2026-09-15 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ffaff994-951e-48f9-9ce6-fca49d08af72', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-14 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-12 21:48:22.187+00', '2026-09-17 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('51ca9b67-bdc1-4df0-be61-18ad6028c979', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-14 21:48:22.187+00', '2026-09-20 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d3c1271f-574a-4437-a94a-5cffc7eda38d', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('a3b09620-f973-4782-86cd-1b019d19b070', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ad76209d-5a43-4451-a9eb-3498ab81e774', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('da1e2472-f86d-4e5f-b21e-1c072d8bb506', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ba8c68da-907e-4090-8909-c4a1089c89e5', 'signage_item', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.480262+00', '2026-09-24 21:48:22.480262+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f8bfb3ad-b6af-4eca-a825-ad7a382e6aed', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('399f282b-22fe-4358-9d76-5784c7ca67ee', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b56c7d3b-1d53-47c3-ac8a-a36d5d6aba3e', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('38d965d4-9644-4504-8f2e-58a2895f97f5', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('19619dca-70d4-42f1-8759-0f6e2bae813f', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3745cc1f-bc80-41b5-9b7b-2cc591636f71', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('3e8459bf-9df7-4550-8f3f-ce6a702a47a6', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ad62971c-cbec-497f-8c26-c3db37c5617d', 'signage_item', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.497547+00', '2026-09-24 21:48:22.497547+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3993d7f5-dbcb-49d4-a7b9-47f7149a7468', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2f53eefa-2be9-431d-8af1-732d66c164b1', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('4da29f24-42ba-4a98-acf2-ce773c32240f', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('020a4cf0-80b7-461b-aa61-2bc186232999', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('ebb22599-6cb6-4191-8e4d-22ce3e0bd35f', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('92fef137-ca43-497a-8c0f-b5e9a289c58f', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('036b6b67-d079-4f35-a254-ef63c3713603', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('05c34e9b-56bf-4df3-8d2b-db9a196cf89c', 'signage_item', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.517007+00', '2026-09-24 21:48:22.517007+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('03f33439-1f85-43db-8237-84a2edc92c12', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-14 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-12 21:48:22.187+00', '2026-09-15 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('479d7921-ea98-4951-8489-af08aa66729b', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('a49ff0d7-c27b-43e9-a69f-50165f113415', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-14 21:48:22.187+00', '2026-09-17 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('4bcf4b1d-7c4d-4188-a7f4-9475807c0d2b', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('dd01039e-fb6b-4252-a357-183fb322ee32', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a2f06fd0-4b27-40a1-a853-e948cb21e419', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-14 21:48:22.187+00', '2026-09-20 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0a616d0f-0578-4460-99e8-6511ec5deb68', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ad83987d-c806-4969-8521-463c62a74a3a', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ee3899b1-fd6b-4341-b142-2e012cb5007e', 'signage_item', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.536998+00', '2026-09-24 21:48:22.536998+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6692dc02-5224-4369-a9cc-01d91e13453a', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('50d1a1e7-b31d-497a-86c2-8163608cd1a7', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('1d3a8de6-ec80-4028-bf02-12755c1790c6', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ee7a9473-d749-4c76-a5e6-95636b39282a', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('1a28ba67-cc1f-4231-a17e-b641c1e28dfd', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('48932104-e0ef-4c85-96d8-fcd160453b18', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('9fd8e313-f4db-4f70-885d-c26e7f4cef28', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('2053a7ae-0a98-4910-abd4-067bff488111', 'signage_item', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.552716+00', '2026-09-24 21:48:22.552716+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('14b4288d-7abd-48bc-82b1-313bc7b323ee', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('dd0536a7-1583-46ae-8ef1-4a219cd449cb', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('5577d7a1-82f4-4da9-a35e-f111b052308e', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e0569198-f5ae-4b4b-a92c-8894e65bc973', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9c695f8c-5a39-4aaf-941d-9075983228ab', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('637d6e88-ebbe-456c-984c-03e63538c87b', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('0ca8ba34-a029-40ee-aa20-4cc171218b1e', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c2be3ee9-458b-4e1c-b12e-646ec2081b23', 'signage_item', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.576437+00', '2026-09-24 21:48:22.576437+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('33f58174-0f9d-40de-a4d1-a4de58c6a304', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c378256d-1ee2-4519-ad96-2107764abfb3', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'approved_with_conditions', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-21 21:48:22.187+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('213d50ea-7721-447c-bd67-4b00bbd0b59c', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('246d29e4-d041-48eb-8253-faf4fa48ecc2', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('d1688ca5-b9ef-4f6b-bb53-ce3ee890aced', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a8bf389d-51b2-49fc-a387-1de2ee0b0f27', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('3cc2c26e-0247-450e-90bb-e5723a5980d9', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('107b10e2-8548-4c4e-99be-54167dca4614', 'signage_item', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.599334+00', '2026-09-24 21:48:22.599334+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6286ae12-af5d-4206-b8d1-6e4763551cc4', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2233a621-fe33-4abb-be63-8c93421a18b4', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('99e0cd55-e5b7-4afc-81d4-beaab97eebca', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5cdae5f2-ea4f-4c89-b96e-4d4b43a99f46', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('0f1583f7-59ea-4ff3-b86e-12d1f320baca', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('53265d65-1924-41cb-a404-3aca6090d2c9', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('af6af315-a535-4f87-a43c-447cc4c27335', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b86ab464-dd1d-44c9-aa57-ca1c657f8344', 'signage_item', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.617913+00', '2026-09-24 21:48:22.617913+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3bb32223-1061-4506-bab4-c52695c623c8', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2c3c25c7-3344-449e-a540-5488c7d360fb', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('59b09618-1ee9-4fde-a75f-5e81b713edf8', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('30fa8231-cbbd-4dfe-b792-a650cde1102e', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('92028b84-4263-4f1d-b179-83396f5d6fda', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('6e9038bc-c1b3-4991-b664-6844acb201f9', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('28044883-1aa4-4fd7-94b1-37102812c384', 'signage_item', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.634769+00', '2026-09-24 21:48:22.634769+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3d712962-da5e-41c5-9af1-ff8b6052b64f', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5da3d394-2db5-4ca0-b967-512d2c93b6c8', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('e406e460-3873-42ac-92d8-e422e0abd319', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f6706f2c-376d-472d-8f72-2557502c7e08', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('7eb3c275-18ef-4868-9459-3f51dcab9693', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b4eaf976-aef7-408b-b1bd-f0b836eed1cf', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('3d647b1a-9c5c-49d5-a499-4e246687bc21', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3f56ef81-1cb0-42ea-a7b9-31f3e219fdea', 'signage_item', '95aa23c8-78bd-46b5-9972-97d893017148', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.648554+00', '2026-09-24 21:48:22.648554+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('bd97a9bc-bde9-485e-84e3-54f90fe32491', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f3e7c6c2-7f76-417e-a4ab-b448aa4e2954', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('fa3538ee-4d33-4a6e-9ee2-5906848a3c2b', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('eeb3209a-68a3-4173-8357-ca40593dba25', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8b994e66-3d17-43cd-bd82-8ba1b611e9b5', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e19444c6-60a7-4cd0-8655-fb6dc1db587b', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('2eb52960-653c-452f-875b-e08dffa6e0f7', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('67892a71-3899-4c7f-99a6-5bcafd6a01a7', 'signage_item', '46369809-1816-4f0b-9e52-5f4403887d09', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.6637+00', '2026-09-24 21:48:22.6637+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('25991b24-929e-4c3e-8b69-d751a4a603a4', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('62daa782-050e-46d5-9448-ec9be217426a', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('ebd86ebd-e6ad-4460-b3dd-7aeaf69c4cee', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a08e9c76-c3f9-49f6-999a-7833bbf18354', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('48140954-3d64-421b-9be7-bad3a47a779b', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('894946df-bd34-4045-ae76-8d085ea4a808', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('60157763-dfe6-4c0f-bd17-9d75e3e36a8b', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('858009a2-6bf6-4247-a085-f1ccfe7ad415', 'signage_item', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.680546+00', '2026-09-24 21:48:22.680546+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('62e32c77-008c-4abf-885e-69a8978f92b6', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b829beb5-1db4-454e-8a5f-9fa81e931f94', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('daef150c-e069-4c1a-9dd2-90c033381dac', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('22fb242e-9510-43fa-8ddc-65ab1935d29b', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e790f549-b8a9-4c91-bc35-bb817c80ef84', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('78c83349-b819-4e6c-aee6-ff2ddbf1b0d3', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('aa824321-1194-4d39-8ee5-f2cb324cb5bc', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('790df13a-8147-4f3a-89ae-25d625a7923c', 'signage_item', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.696334+00', '2026-09-24 21:48:22.696334+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('75505ca5-2338-4543-bae0-f78adb482c46', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b415a141-4e73-4b5d-991a-916e1489b7f1', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('a7b86e2d-4170-4c9d-a735-37502e13e4cb', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('bd04b6a7-54d7-4c06-a98e-1c232515800c', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('4298c64d-8195-4853-b9f6-799fdc0b409a', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('02cc5942-457f-4e62-98f7-e594096873b3', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-23 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('48bfd6e5-e223-49db-9f1a-d6d6aecabbe3', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('37d41416-604f-403a-902c-1c8ce7108db0', 'signage_item', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.712129+00', '2026-09-24 21:48:22.712129+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f2e54305-ee1e-40a5-b500-7a28f1ac62d5', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'rejected', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c12c7ce4-a0d7-4296-93e5-dc06faedb652', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('ce3ec7d4-5fa8-4d6e-b3cc-7c1291477d8f', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5b3a10e0-436e-4f94-9542-b97cbf49830b', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('40c3f2b5-3f32-4c5e-804d-a57c4a62f5ab', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f7364a1b-0d8f-4b04-a4ea-a4f98062f85e', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('66cf86a2-4cdb-4971-9dd7-fe27760c2614', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0edfb92a-923d-4162-86bd-6602b50569cd', 'signage_item', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.727296+00', '2026-09-24 21:48:22.727296+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('9cc67313-4f28-4d57-a919-7391b9d032d0', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('96022726-6dbc-4794-9e72-4a713a88d05d', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('5c7ed1af-34d5-41b2-bfab-d5afe176d309', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e80eadbe-1fe0-4c94-90bc-8ca6a2d2dd0e', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('11f302c3-a70b-435a-922c-078e39997972', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('50f2c5da-fe2c-49b8-b150-5c8bf9f8b221', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('491e60e8-ee28-401a-ae9a-089031adc2e5', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('69f68b77-4331-4bc2-871e-107678f04178', 'signage_item', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.742728+00', '2026-09-24 21:48:22.742728+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6ef3e47b-bf93-4e77-aab1-abbaea5053d6', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'invalidated', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a0023681-2c0b-4b88-9481-8c79bfe37b6c', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 21:48:22.187+00', '2026-09-26 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0081b0f1-9108-45e8-a29f-be30cadb52ba', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'invalidated', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b2fa8392-f1e9-4318-8c3d-6308b8d7ff0c', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-23 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('cedc9380-88ef-4582-a85e-b837dab0722a', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'invalidated', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b43a5d80-6685-44a4-ac52-2b11b715772e', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('27dfcaf6-5467-4259-85c7-cbd27e9a640f', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6feea224-f789-4b60-9120-b54ab5bd6211', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3cbf3d6a-93f6-467c-9ba4-26cc1d780236', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('07d26968-b326-49d9-9077-085da68cd14f', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('8b577ee1-57a0-4407-bc83-e51b68bf56fa', 'signage_item', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.76058+00', '2026-09-24 21:48:22.76058+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('39bb37f6-9a2e-40da-bb73-42bbd19bb045', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('feeae56b-ddeb-4d56-9aed-6e3289fe5dba', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('57c9d11a-7c6f-4c4e-94c6-16a3511ade96', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c4d441c8-e0e4-43d6-989b-bad718b38047', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('120c71e9-8372-40be-92bd-8b48a8aa53f7', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3c804651-7307-4be7-a4fc-c6958d45c843', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7570fc25-959d-42bc-a809-f778dd63f5ee', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('26de5e20-9d8e-4aa0-bbc8-432908e9fbbb', 'signage_item', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.816177+00', '2026-09-24 21:48:22.816177+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e597faff-4bdf-487c-9842-ae62751363fa', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3d2901ed-cdb9-472b-a546-78e2744f0a14', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('18176a90-910e-4cbc-b162-fdcf663b812f', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d8b48d74-c837-4774-9f85-443bc0d8696e', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 21:48:22.187+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-28 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('27c5480f-7fec-4a9e-b26a-d75f7a3fedae', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0ba1641a-4c8e-4ea3-a832-794c15bb56a3', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('edb7d6ce-3ec5-4930-a02a-8fc0ef806663', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c133e0d9-1955-4520-ad4e-62d79d82dbcb', 'signage_item', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.831517+00', '2026-09-24 21:48:22.831517+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0809715e-4bfe-4185-b2b3-cda9109146f2', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1e445e5f-954c-49de-9aad-b8a3a0e24841', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '1244b80d-38e0-44b8-a1fd-886eba41b064', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 21:48:22.187+00', '2026-09-24 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('098151a9-6f54-4516-88c2-61658321a5be', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, 'a7acc52d-93d7-4753-a01e-e600641f26ce', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('50227b30-eaac-465f-ada1-ad1b2a8a0632', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '8459e46d-52de-4a38-b71f-9ab16cdad918', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('692a1273-4867-4624-85ac-65ce9677a01f', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2bf4cc21-f1b8-49ce-8279-db8b8f79ae2c', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '3bc5a12e-7972-4677-b0e8-82f999fff2c8', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7d48503b-f8b8-4c35-abe1-dec28edcf192', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, '57a9421c-62a6-4968-9f74-543e1d1a8d6f', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('28c51555-3121-48db-a5a4-630d36e5241c', 'signage_item', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, 'f12042e6-5507-4e6f-9d40-f13a6a431fdf', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.850978+00', '2026-09-24 21:48:22.850978+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('d5995516-6604-4a49-8a7b-27b04e3dc208', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, 'fbcf6406-ce8e-425d-a266-a5ee2af75ed0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 21:48:22.187+00', '2026-09-21 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3ab65c56-b316-4e63-bf1f-137fb2cb1c4a', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, '5613f2c6-9601-4917-9a5a-06e9b920a23d', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 21:48:22.187+00', '2026-09-27 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9968664a-6687-486a-ad1d-d800d7720b46', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, 'ef14828c-7f21-4a4a-b8f4-c3b810c64c68', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('80d0d569-8983-4511-a8fb-be9ec520ad1d', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, '0e1792d5-1f9b-4fc7-babe-409d10316938', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('5dbc620a-26bb-49a7-ad0a-e1b2de0c6d5c', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, '2b8a48fe-5fdc-4db6-b968-79060904b66c', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('5a2305d5-55ea-4a7b-9e4b-b6a9efc6b47d', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 1, 'bb3cb64e-de70-4eeb-b363-cce0504f5b62', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('31b00288-b8fa-47cf-b622-73e15abe04fb', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, 'fbcf6406-ce8e-425d-a266-a5ee2af75ed0', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-18 21:48:22.187+00', '2026-09-21 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1f371e70-bb26-4db8-b7f8-38b85fd57a52', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, '5613f2c6-9601-4917-9a5a-06e9b920a23d', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('4d6d7d32-6990-4fe4-8fbf-7e9501e70edc', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, 'ef14828c-7f21-4a4a-b8f4-c3b810c64c68', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6568597c-f42f-4644-b80a-eb6b927c2fdf', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, '0e1792d5-1f9b-4fc7-babe-409d10316938', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8ca1a8e5-f348-4f34-b17c-0fae1ee81bc4', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, '2b8a48fe-5fdc-4db6-b968-79060904b66c', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('bb28acb1-c5b3-4cab-8338-f64408557597', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 1, 'bb3cb64e-de70-4eeb-b363-cce0504f5b62', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1b5e833c-e6d2-4694-a55a-fd7f396d771e', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, 'fbcf6406-ce8e-425d-a266-a5ee2af75ed0', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-18 21:48:22.187+00', '2026-09-21 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('88786578-cea9-4dc0-891c-da180dab6577', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, '5613f2c6-9601-4917-9a5a-06e9b920a23d', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('07312c2a-fd46-44a9-94e9-4c568e054b01', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, 'ef14828c-7f21-4a4a-b8f4-c3b810c64c68', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('c936d554-7d77-4fd2-b2f3-a69cc6af8538', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, '0e1792d5-1f9b-4fc7-babe-409d10316938', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('e56003e6-6595-41c1-812c-eab5c42069cc', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, '2b8a48fe-5fdc-4db6-b968-79060904b66c', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f018e4ff-a2b5-4a1f-92f2-093755c602f4', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 1, 'bb3cb64e-de70-4eeb-b363-cce0504f5b62', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('ba330a01-2042-43e0-8ee0-8b1b0c6ff328', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, 'fbcf6406-ce8e-425d-a266-a5ee2af75ed0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 21:48:22.187+00', '2026-09-21 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('83e377ac-fffa-4d9e-b29f-2a3a3203c537', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, '5613f2c6-9601-4917-9a5a-06e9b920a23d', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('71c4b0f8-6e0c-4a54-9f8c-0881dd813610', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, 'ef14828c-7f21-4a4a-b8f4-c3b810c64c68', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-25 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('ec9f6748-1939-4eda-bb53-4778306c9657', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, '0e1792d5-1f9b-4fc7-babe-409d10316938', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-27 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('454f0b02-101a-42b6-9380-3f3262884468', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, '2b8a48fe-5fdc-4db6-b968-79060904b66c', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('cfc72cca-acf8-4e3f-89a0-642316c3b358', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 1, 'bb3cb64e-de70-4eeb-b363-cce0504f5b62', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 21:48:22.187+00', '2026-09-20 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('51d8c877-9a1d-4d73-aa2a-467868c13c19', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, 'fbcf6406-ce8e-425d-a266-a5ee2af75ed0', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-18 21:48:22.187+00', '2026-09-21 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d8ee62f4-e6bf-4a98-a653-90eed394501a', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, '5613f2c6-9601-4917-9a5a-06e9b920a23d', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('bd6a1c16-f7c5-4bdf-bb90-7c8c696c63ef', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, 'ef14828c-7f21-4a4a-b8f4-c3b810c64c68', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-25 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('5b032c50-4bbb-4a82-84e2-62aac92db451', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, '0e1792d5-1f9b-4fc7-babe-409d10316938', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-27 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('81c3ac18-fb4c-4a53-a28f-dfa841c587a5', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, '2b8a48fe-5fdc-4db6-b968-79060904b66c', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-20 21:48:22.187+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-20 21:48:22.187+00', '2026-09-22 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('62180b8e-ed6e-424d-a815-7c14beca46ee', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 1, 'bb3cb64e-de70-4eeb-b363-cce0504f5b62', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 21:48:22.187+00', '2026-09-20 21:48:22.187+00', 0, NULL, NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00', false, true, 0, false);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('4ee4f716-e6f6-472b-bfda-1d2dbc8877b0', 'bd54d143-c0b6-49e4-b212-9738752ebb89', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.435404+00', '2026-09-24 21:48:22.435404+00');
INSERT INTO public.artwork_versions VALUES ('0224785f-e835-4608-a47f-f89c2e093376', '97454ec7-2a3e-40d7-8902-ab80f056c12a', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.458484+00', '2026-09-24 21:48:22.458484+00');
INSERT INTO public.artwork_versions VALUES ('9585baea-8b1b-44cf-b1f1-9bcba895c2b2', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-24 21:48:22.476719+00', '2026-09-24 21:48:22.476719+00');
INSERT INTO public.artwork_versions VALUES ('d6acafab-a6cc-483a-bf5b-a04ff809af8e', '01731f85-3c0e-4545-bd44-45b90deb1f4b', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.478175+00', '2026-09-24 21:48:22.478175+00');
INSERT INTO public.artwork_versions VALUES ('afbd0a64-a05e-4eb0-819b-42b93e2a247e', 'b8a7957e-3436-4b18-9ff7-977d0b26d359', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.495151+00', '2026-09-24 21:48:22.495151+00');
INSERT INTO public.artwork_versions VALUES ('55c48b9b-a174-4d44-b63e-163f5c15f2b1', 'c893f1cb-8559-4237-8442-f4a43e075242', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.514+00', '2026-09-24 21:48:22.514+00');
INSERT INTO public.artwork_versions VALUES ('1a0afbe0-9889-492f-bde1-ab45fba698aa', 'c15a5647-ace8-427f-ad3d-2937aed63119', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.534591+00', '2026-09-24 21:48:22.534591+00');
INSERT INTO public.artwork_versions VALUES ('660a4a9b-89a9-4a64-bdb1-1843cba769ff', 'a42c2958-f959-4e0e-ae4f-23b2613b2118', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.550497+00', '2026-09-24 21:48:22.550497+00');
INSERT INTO public.artwork_versions VALUES ('93c0bed7-5277-4c04-8ad1-133cad8e40c4', '236dbc97-0fdd-42fa-842e-337d6d6933e2', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.57257+00', '2026-09-24 21:48:22.57257+00');
INSERT INTO public.artwork_versions VALUES ('61851661-5a57-47da-aede-e934ad0c8ea5', 'f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.596685+00', '2026-09-24 21:48:22.596685+00');
INSERT INTO public.artwork_versions VALUES ('e40820bb-d153-4c88-b087-534269b95553', '1651d894-0951-4886-8c91-bc8fc91f817e', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.615799+00', '2026-09-24 21:48:22.615799+00');
INSERT INTO public.artwork_versions VALUES ('48da8dd7-af3f-413b-96a8-74044ec62fcd', 'd0d99b5a-b0d0-4548-8778-89b1e8c91660', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.632536+00', '2026-09-24 21:48:22.632536+00');
INSERT INTO public.artwork_versions VALUES ('2f558ca7-df76-4ca5-93fe-f64d674459e1', '95aa23c8-78bd-46b5-9972-97d893017148', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.646752+00', '2026-09-24 21:48:22.646752+00');
INSERT INTO public.artwork_versions VALUES ('83ef80c5-83e3-45de-a9c4-e015f93eb562', '46369809-1816-4f0b-9e52-5f4403887d09', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.661129+00', '2026-09-24 21:48:22.661129+00');
INSERT INTO public.artwork_versions VALUES ('89924c02-5500-4091-9898-d25bed51ee56', '5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.67841+00', '2026-09-24 21:48:22.67841+00');
INSERT INTO public.artwork_versions VALUES ('b6a583f2-5fbe-4685-b1dc-1f778606567c', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.69434+00', '2026-09-24 21:48:22.69434+00');
INSERT INTO public.artwork_versions VALUES ('ff849bba-bbb8-45cb-bca7-5651e1df8a06', 'ca4a7131-1bf2-4884-a873-cca18a50fbab', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.710094+00', '2026-09-24 21:48:22.710094+00');
INSERT INTO public.artwork_versions VALUES ('8f0dd885-bee9-41f2-8099-e328a44b3eb7', 'd61838c6-551a-4941-8fa3-970293eaee13', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.725337+00', '2026-09-24 21:48:22.725337+00');
INSERT INTO public.artwork_versions VALUES ('9ee1fcec-1a2f-4992-8d27-296c580fc60a', 'f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.740777+00', '2026-09-24 21:48:22.740777+00');
INSERT INTO public.artwork_versions VALUES ('c7c6ece3-7ea5-497d-a6b3-f3dbc1e77f04', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-24 21:48:22.755644+00', '2026-09-24 21:48:22.755644+00');
INSERT INTO public.artwork_versions VALUES ('92a3d56b-30a3-42d1-bec6-ea252bb1e65d', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-24 21:48:22.756699+00', '2026-09-24 21:48:22.756699+00');
INSERT INTO public.artwork_versions VALUES ('6ef331fd-fd55-4d24-964a-6df64deb9c99', 'f547331b-60ff-46f5-b01d-c85169b2bd39', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.757881+00', '2026-09-24 21:48:22.757881+00');
INSERT INTO public.artwork_versions VALUES ('7bf7a202-c27e-40e7-89fc-f87a4ecc39f7', 'e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-24 21:48:22.813903+00', '2026-09-24 21:48:22.813903+00');
INSERT INTO public.artwork_versions VALUES ('ecec2efe-6c76-40fa-b1ce-d3a2adce25d0', '8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.829453+00', '2026-09-24 21:48:22.829453+00');
INSERT INTO public.artwork_versions VALUES ('c9f7af5a-d9fd-45cc-9109-17f6834ee226', '6d73dcee-d026-4cca-8688-9e9e07e8e029', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-24 21:48:22.849021+00', '2026-09-24 21:48:22.849021+00');


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

INSERT INTO public.contractors VALUES ('45f1d3cd-c700-4af3-b96f-8048eb42668f', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-24 21:48:22.312675+00', '2026-09-24 21:48:22.312675+00');
INSERT INTO public.contractors VALUES ('3dcce876-8e47-4b84-9eef-b48044bfffc1', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-24 21:48:22.314998+00', '2026-09-24 21:48:22.314998+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('c76cb393-9c5d-429f-a41c-7ed6c0a50b55', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00');
INSERT INTO public.documents VALUES ('55a87ec7-15db-4169-ac36-eb85a5cb65c3', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00');
INSERT INTO public.documents VALUES ('2a5bb757-f768-41c3-9ee2-12665f59abae', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00');
INSERT INTO public.documents VALUES ('412e48c0-b474-4ed3-a89f-0d37a2bfcc58', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', 'efd7462b-a729-4d8a-96f8-21341850233c', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00');
INSERT INTO public.documents VALUES ('05a11593-a8f9-4589-b502-85100a54ed6e', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00');
INSERT INTO public.documents VALUES ('56c7e3d6-77fd-4570-94a4-989ec8572e7a', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00');
INSERT INTO public.documents VALUES ('6799b105-a6da-4051-8483-25ae5e917382', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00');
INSERT INTO public.documents VALUES ('4a93eb86-f5d1-46ac-a3f2-d9e5a85ff135', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '53771647-6ffd-4ef5-8c2f-b7ae810cde52', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00');
INSERT INTO public.documents VALUES ('0c013eec-2f8d-461e-accc-caaea7b41e48', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00');
INSERT INTO public.documents VALUES ('aa6a2988-2efe-4c75-9177-d37f12aa7519', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00');
INSERT INTO public.documents VALUES ('2026a402-9ae3-470e-80d7-a2dcdc7830aa', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00');
INSERT INTO public.documents VALUES ('c13c94d7-8588-4464-85bf-6818581cd9d0', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '8f2b93cd-3123-4064-94d5-4f7733ce181b', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00');
INSERT INTO public.documents VALUES ('5d1be69d-ae4d-4c0a-988a-58473e2f159c', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00');
INSERT INTO public.documents VALUES ('2c95a3c0-efec-4013-9d7a-6cc090b967d5', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00');
INSERT INTO public.documents VALUES ('60943af4-e0f7-4831-a152-6031402906e7', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00');
INSERT INTO public.documents VALUES ('a516769e-a7b8-447f-a4c0-1ec62995d2d0', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '417e55e4-a420-4864-bd60-cac9a883bba6', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00');
INSERT INTO public.documents VALUES ('29a9d37d-a30c-42bc-8d61-6d4e5d935c70', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00');
INSERT INTO public.documents VALUES ('767cd50f-ecef-4cdc-b9dc-dccdea0e816a', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00');
INSERT INTO public.documents VALUES ('2c8fd0dd-b534-4ef6-b3b0-3e9b2e3065f5', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00');
INSERT INTO public.documents VALUES ('a58632f6-3af2-45c8-8b17-f944cc2ad0f4', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_submission', '351e68eb-1d55-4404-a50f-a079b741674d', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('0bf91f4c-70d5-4dfe-98eb-405a42da7185', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'signage', 32, '2026-09-24 21:48:22.863729+00', '2026-09-24 21:48:22.865093+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('471b0b27-9da8-4987-8329-7a033caf6f0f', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-24 21:48:22.2649+00', '2026-09-24 21:48:22.2649+00');
INSERT INTO public.edition_deadlines VALUES ('56b11956-05b2-4201-bab7-cbdf26eb7fc4', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-24 21:48:22.267106+00', '2026-09-24 21:48:22.267106+00');
INSERT INTO public.edition_deadlines VALUES ('03a4ee7a-bf14-4c63-9b63-cdb58796290c', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-24 21:48:22.268165+00', '2026-09-24 21:48:22.268165+00');
INSERT INTO public.edition_deadlines VALUES ('ac5e9b5f-abd7-4a29-ade2-2d81513d5567', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-24 21:48:22.26928+00', '2026-09-24 21:48:22.26928+00');
INSERT INTO public.edition_deadlines VALUES ('a190c035-301a-4e41-bc22-ec583373a495', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-24 21:48:22.270715+00', '2026-09-24 21:48:22.270715+00');
INSERT INTO public.edition_deadlines VALUES ('ce4e66f3-2ac7-474e-b94e-eb7fbe057022', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-24 21:48:22.271824+00', '2026-09-24 21:48:22.271824+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'c994c242-6217-4cb1-b69c-38f8814c6cf4', '79d81846-29b7-485b-b431-52de1a9d2648', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-24 21:48:22.262146+00', '2026-09-24 21:48:22.262146+00');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('c994c242-6217-4cb1-b69c-38f8814c6cf4', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'UK Construction Week', 'UKCW', '2026-09-24 21:48:22.238554+00', '2026-09-24 21:48:22.238554+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('27ce8171-e08f-416c-b4ab-c53defd57c88', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Exhibitor Co', 'A10', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '45f1d3cd-c700-4af3-b96f-8048eb42668f', '2026-09-24 21:48:22.398187+00', '2026-09-24 21:48:22.398187+00');
INSERT INTO public.exhibitors VALUES ('e7d71b74-0c47-4446-8dcd-a2e1f1301616', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SteelFrame Systems', 'A20', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '3dcce876-8e47-4b84-9eef-b48044bfffc1', '2026-09-24 21:48:22.402787+00', '2026-09-24 21:48:22.402787+00');
INSERT INTO public.exhibitors VALUES ('63769ee0-c0a6-491d-9825-1f48d4a2069f', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'BrickWorks UK', 'A30', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '45f1d3cd-c700-4af3-b96f-8048eb42668f', '2026-09-24 21:48:22.404854+00', '2026-09-24 21:48:22.404854+00');
INSERT INTO public.exhibitors VALUES ('c7c98196-fb16-4fb3-a2f7-a4db1ccc8364', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Timber Trade Ltd', 'B10', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '3dcce876-8e47-4b84-9eef-b48044bfffc1', '2026-09-24 21:48:22.406991+00', '2026-09-24 21:48:22.406991+00');
INSERT INTO public.exhibitors VALUES ('61242659-9647-4591-988a-3b3142656bcb', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'GlassTech', 'B20', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '45f1d3cd-c700-4af3-b96f-8048eb42668f', '2026-09-24 21:48:22.408796+00', '2026-09-24 21:48:22.408796+00');
INSERT INTO public.exhibitors VALUES ('98a2c584-123f-4a26-ae67-4a5cb87abff1', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Insulate Pro', 'B30', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '3dcce876-8e47-4b84-9eef-b48044bfffc1', '2026-09-24 21:48:22.41097+00', '2026-09-24 21:48:22.41097+00');
INSERT INTO public.exhibitors VALUES ('2976d068-ef24-42e2-bf8a-5e7a3318ab64', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'RoofRight', 'C10', '17931f97-931a-409e-b9cf-7e3364b2268a', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '45f1d3cd-c700-4af3-b96f-8048eb42668f', '2026-09-24 21:48:22.412912+00', '2026-09-24 21:48:22.412912+00');
INSERT INTO public.exhibitors VALUES ('c636cd4f-cbca-4241-a337-d8c21cb8cdc6', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'PlantHire Direct', 'C20', '17931f97-931a-409e-b9cf-7e3364b2268a', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '3dcce876-8e47-4b84-9eef-b48044bfffc1', '2026-09-24 21:48:22.41503+00', '2026-09-24 21:48:22.41503+00');
INSERT INTO public.exhibitors VALUES ('b99fd252-1c33-4283-a64f-25cd30103dc0', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SafetyFirst PPE', 'D10', '17931f97-931a-409e-b9cf-7e3364b2268a', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-24 21:48:22.417423+00', '2026-09-24 21:48:22.417423+00');
INSERT INTO public.exhibitors VALUES ('3c226909-3677-4bf8-ac59-39f05ba2fe43', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'ToolMart Retail', 'D20', '17931f97-931a-409e-b9cf-7e3364b2268a', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-24 21:48:22.419771+00', '2026-09-24 21:48:22.419771+00');
INSERT INTO public.exhibitors VALUES ('c5d5da46-4247-431c-ba6c-9ef93cc394e3', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'EcoBuild Materials', 'D30', '17931f97-931a-409e-b9cf-7e3364b2268a', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-24 21:48:22.421652+00', '2026-09-24 21:48:22.421652+00');
INSERT INTO public.exhibitors VALUES ('baa257a1-2d79-48b7-a912-18ed0ae444da', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SiteWise Software', 'D40', '17931f97-931a-409e-b9cf-7e3364b2268a', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-24 21:48:22.423704+00', '2026-09-24 21:48:22.423704+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('05accc48-f8f8-4875-81b9-f355dde6f98c', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'venue', 'venue', '79d81846-29b7-485b-b431-52de1a9d2648', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.381039+00', '2026-09-24 21:48:22.381039+00');
INSERT INTO public.external_grants VALUES ('634a8c45-c001-46c7-b23d-b7e91e575333', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.385575+00', '2026-09-24 21:48:22.385575+00');
INSERT INTO public.external_grants VALUES ('7d5893a5-577c-42af-a915-b3607594fe30', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.389014+00', '2026-09-24 21:48:22.389014+00');
INSERT INTO public.external_grants VALUES ('4877fcbb-f3df-4efe-a537-39be68bd9883', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'supplier', 'supplier', '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.392139+00', '2026-09-24 21:48:22.392139+00');
INSERT INTO public.external_grants VALUES ('54ce0c9a-b40b-41d0-b5c8-4d5d17c6b67b', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'sponsor', 'sponsor', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.395152+00', '2026-09-24 21:48:22.395152+00');
INSERT INTO public.external_grants VALUES ('14a038ae-a3bf-4274-9f21-98eded4a6bbc', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'exhibitor', 'exhibitor', '27ce8171-e08f-416c-b4ab-c53defd57c88', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-24 21:48:22.187+00', NULL, '2026-09-24 21:48:22.426472+00', '2026-09-24 21:48:22.426472+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('d1338361-90a2-4ec3-bf45-c0851c18450a', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-24 21:48:22.274185+00', '2026-09-24 21:48:22.274185+00');
INSERT INTO public.halls VALUES ('17931f97-931a-409e-b9cf-7e3364b2268a', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-24 21:48:22.276534+00', '2026-09-24 21:48:22.276534+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('39c254af-3d5e-4403-965e-581fbb3afdce', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Hanging banner', 'hanging_banner', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'rigged', true, 0, '2026-09-24 21:48:22.357578+00', '2026-09-24 21:48:22.357578+00', 'signage');
INSERT INTO public.item_types VALUES ('14f48a40-68f3-4eec-b62f-bd30d265d524', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Foamex board', 'foamex_board', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'wall_mounted', false, 1, '2026-09-24 21:48:22.359476+00', '2026-09-24 21:48:22.359476+00', 'signage');
INSERT INTO public.item_types VALUES ('9a2fd8b5-5ea4-4ffa-af7f-484511b456c5', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Fabric graphic', 'fabric_graphic', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'shell_mounted', false, 2, '2026-09-24 21:48:22.360671+00', '2026-09-24 21:48:22.360671+00', 'signage');
INSERT INTO public.item_types VALUES ('834e5566-6610-4e68-87bd-e20de397bbdc', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Floor vinyl', 'floor_vinyl', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'floor', false, 3, '2026-09-24 21:48:22.361928+00', '2026-09-24 21:48:22.361928+00', 'signage');
INSERT INTO public.item_types VALUES ('f9f20a7c-4145-4521-894c-41d7e5bfe3e8', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Aisle sign', 'aisle_sign', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'rigged', true, 4, '2026-09-24 21:48:22.363274+00', '2026-09-24 21:48:22.363274+00', 'signage');
INSERT INTO public.item_types VALUES ('bd3d7c8c-1aa9-400a-93fb-02711d92990b', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Entrance feature', 'entrance_feature', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'freestanding', true, 5, '2026-09-24 21:48:22.364383+00', '2026-09-24 21:48:22.364383+00', 'signage');
INSERT INTO public.item_types VALUES ('32ad6ed8-6c7d-4b94-b739-b09fca9ed4dc', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Registration', 'registration', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'freestanding', false, 6, '2026-09-24 21:48:22.365544+00', '2026-09-24 21:48:22.365544+00', 'signage');
INSERT INTO public.item_types VALUES ('f85a2900-6b33-48f0-b475-119a6e762e3c', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Seminar theatre', 'seminar_theatre', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'freestanding', false, 7, '2026-09-24 21:48:22.36663+00', '2026-09-24 21:48:22.36663+00', 'signage');
INSERT INTO public.item_types VALUES ('16c730ef-8cec-4c0c-9137-255d9da5908e', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Feature area', 'feature_area', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'freestanding', false, 8, '2026-09-24 21:48:22.36759+00', '2026-09-24 21:48:22.36759+00', 'signage');
INSERT INTO public.item_types VALUES ('996937a6-65ff-464e-88dd-d1a66ebfbf83', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'External', 'external', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'freestanding', true, 9, '2026-09-24 21:48:22.368584+00', '2026-09-24 21:48:22.368584+00', 'signage');
INSERT INTO public.item_types VALUES ('ccde90be-8a90-4545-9944-54de4a3a9790', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Digital screen', 'digital_screen', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 'digital', false, 10, '2026-09-24 21:48:22.369783+00', '2026-09-24 21:48:22.369783+00', 'signage');
INSERT INTO public.item_types VALUES ('ea0bbc25-504f-4ae2-bbd5-5fe21c517542', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Branded lanyards', 'lanyard', '896857d9-22f8-4de4-9ba6-9b70ce50913f', NULL, false, 11, '2026-09-24 21:48:22.371293+00', '2026-09-24 21:48:22.371293+00', 'sponsorship_item');
INSERT INTO public.item_types VALUES ('34be14f8-c7e3-4f3a-8129-12d0d301fdbb', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Show bags', 'show_bag', '896857d9-22f8-4de4-9ba6-9b70ce50913f', NULL, false, 12, '2026-09-24 21:48:22.372471+00', '2026-09-24 21:48:22.372471+00', 'sponsorship_item');
INSERT INTO public.item_types VALUES ('3697b682-1297-4da1-ac20-2a6caeebabf0', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Registration branding', 'reg_branding', '896857d9-22f8-4de4-9ba6-9b70ce50913f', NULL, false, 13, '2026-09-24 21:48:22.373652+00', '2026-09-24 21:48:22.373652+00', 'sponsorship_item');
INSERT INTO public.item_types VALUES ('1fb7846a-cf2b-44cb-85ff-9e845c8b287d', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Other signage', 'other_signage', '896857d9-22f8-4de4-9ba6-9b70ce50913f', NULL, false, 14, '2026-09-24 21:48:22.374843+00', '2026-09-24 21:48:22.374843+00', 'signage');
INSERT INTO public.item_types VALUES ('212e4ab3-8425-44c7-af45-f874b36ea98d', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Other sponsorship item', 'other_sponsorship', '896857d9-22f8-4de4-9ba6-9b70ce50913f', NULL, false, 15, '2026-09-24 21:48:22.376303+00', '2026-09-24 21:48:22.376303+00', 'sponsorship_item');


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('b3d074a9-2db3-4d9b-8ad5-7f2a9d460e96', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-24 21:48:22.279177+00', '2026-09-24 21:48:22.279177+00');
INSERT INTO public.locations VALUES ('f1d7f8fd-9cac-4e7e-a87b-7c06f1f6170d', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-24 21:48:22.281677+00', '2026-09-24 21:48:22.281677+00');
INSERT INTO public.locations VALUES ('a437d3f8-2e8e-44e4-ab34-a6aba490e6fa', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-24 21:48:22.283798+00', '2026-09-24 21:48:22.283798+00');
INSERT INTO public.locations VALUES ('2c497242-db5b-4084-8ad1-19c79b305698', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-24 21:48:22.285908+00', '2026-09-24 21:48:22.285908+00');
INSERT INTO public.locations VALUES ('2b5575e6-6128-42b9-9039-5fe2b2db14e9', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-24 21:48:22.287982+00', '2026-09-24 21:48:22.287982+00');
INSERT INTO public.locations VALUES ('2daed6f5-2bd3-48dc-b9f1-c82e66e0eadf', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-24 21:48:22.289776+00', '2026-09-24 21:48:22.289776+00');
INSERT INTO public.locations VALUES ('9b4b9c24-6eae-4a05-8704-f92f147bba02', '17931f97-931a-409e-b9cf-7e3364b2268a', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-24 21:48:22.291786+00', '2026-09-24 21:48:22.291786+00');
INSERT INTO public.locations VALUES ('ac1d860f-1ed4-4f96-87b5-fcf6f3df70fe', '17931f97-931a-409e-b9cf-7e3364b2268a', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-24 21:48:22.293782+00', '2026-09-24 21:48:22.293782+00');
INSERT INTO public.locations VALUES ('6662788e-2240-42ab-8ef5-879911bd0547', '17931f97-931a-409e-b9cf-7e3364b2268a', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-24 21:48:22.295773+00', '2026-09-24 21:48:22.295773+00');
INSERT INTO public.locations VALUES ('380a2156-3233-4aa9-8819-374f803e8c4a', '17931f97-931a-409e-b9cf-7e3364b2268a', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-24 21:48:22.297575+00', '2026-09-24 21:48:22.297575+00');
INSERT INTO public.locations VALUES ('3ce14953-2938-4328-8116-d0d272b4d069', '17931f97-931a-409e-b9cf-7e3364b2268a', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-24 21:48:22.299409+00', '2026-09-24 21:48:22.299409+00');
INSERT INTO public.locations VALUES ('0ac0ab1e-a5c9-47b0-bb20-816171279028', '17931f97-931a-409e-b9cf-7e3364b2268a', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-24 21:48:22.301509+00', '2026-09-24 21:48:22.301509+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('3dd06e17-7fa9-4c63-a160-dcd86c1cdba0', '00000000-0000-4000-8000-000000000001', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'admin', '2026-09-24 21:48:22.223721+00', '2026-09-24 21:48:22.223721+00', '{}');
INSERT INTO public.memberships VALUES ('d2a60e27-840c-424c-a947-1add27268cb8', '00000000-0000-4000-8000-000000000002', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ops', '2026-09-24 21:48:22.227127+00', '2026-09-24 21:48:22.227127+00', '{}');
INSERT INTO public.memberships VALUES ('f424bbfe-34ea-4b89-8ceb-f7551c78ad3f', '00000000-0000-4000-8000-000000000004', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'sales', '2026-09-24 21:48:22.231991+00', '2026-09-24 21:48:22.231991+00', '{}');
INSERT INTO public.memberships VALUES ('c6929b87-af98-44ec-8e97-24871403f462', '00000000-0000-4000-8000-000000000005', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'event_director', '2026-09-24 21:48:22.234364+00', '2026-09-24 21:48:22.234364+00', '{}');
INSERT INTO public.memberships VALUES ('37e202a4-4813-45c6-b7e5-455b954041da', '00000000-0000-4000-8000-000000000006', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'viewer', '2026-09-24 21:48:22.236669+00', '2026-09-24 21:48:22.236669+00', '{}');
INSERT INTO public.memberships VALUES ('35f676a1-3134-4296-b06b-40c5799a86f9', '00000000-0000-4000-8000-000000000003', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'marketing', '2026-09-24 21:48:22.229327+00', '2026-09-24 21:48:22.941495+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-24 21:48:22.217488+00', '2026-09-24 21:48:22.217488+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('bd54d143-c0b6-49e4-b212-9738752ebb89', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', 'bd3d7c8c-1aa9-400a-93fb-02711d92990b', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'b3d074a9-2db3-4d9b-8ad5-7f2a9d460e96', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', '7f9797c7-f4aa-464b-b226-8ebce34c1129', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '4ee4f716-e6f6-472b-bfda-1d2dbc8877b0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.431654+00', '2026-09-24 21:48:22.437329+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('97454ec7-2a3e-40d7-8902-ab80f056c12a', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '32ad6ed8-6c7d-4b94-b739-b09fca9ed4dc', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'f1d7f8fd-9cac-4e7e-a87b-7c06f1f6170d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '0224785f-e835-4608-a47f-f89c2e093376', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.456319+00', '2026-09-24 21:48:22.459618+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('01731f85-3c0e-4545-bd44-45b90deb1f4b', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '39c254af-3d5e-4403-965e-581fbb3afdce', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'a437d3f8-2e8e-44e4-ab34-a6aba490e6fa', 'ops', '00000000-0000-4000-8000-000000000002', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', '7f69c12d-72e0-4a23-88eb-be78e47e357a', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'd6acafab-a6cc-483a-bf5b-a04ff809af8e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.474875+00', '2026-09-24 21:48:22.479157+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('b8a7957e-3436-4b18-9ff7-977d0b26d359', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'f85a2900-6b33-48f0-b475-119a6e762e3c', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2c497242-db5b-4084-8ad1-19c79b305698', 'marketing', '00000000-0000-4000-8000-000000000003', 'f9ac64cd-da3d-4227-8522-1a90edafc892', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'afbd0a64-a05e-4eb0-819b-42b93e2a247e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.493131+00', '2026-09-24 21:48:22.496615+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('c893f1cb-8559-4237-8442-f4a43e075242', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '834e5566-6610-4e68-87bd-e20de397bbdc', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2b5575e6-6128-42b9-9039-5fe2b2db14e9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '55c48b9b-a174-4d44-b63e-163f5c15f2b1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.509874+00', '2026-09-24 21:48:22.515612+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('c15a5647-ace8-427f-ad3d-2937aed63119', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '16c730ef-8cec-4c0c-9137-255d9da5908e', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2daed6f5-2bd3-48dc-b9f1-c82e66e0eadf', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '1a0afbe0-9889-492f-bde1-ab45fba698aa', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.531706+00', '2026-09-24 21:48:22.535794+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('a42c2958-f959-4e0e-ae4f-23b2613b2118', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '39c254af-3d5e-4403-965e-581fbb3afdce', '17931f97-931a-409e-b9cf-7e3364b2268a', '9b4b9c24-6eae-4a05-8704-f92f147bba02', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '660a4a9b-89a9-4a64-bdb1-1843cba769ff', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.548876+00', '2026-09-24 21:48:22.551467+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('236dbc97-0fdd-42fa-842e-337d6d6933e2', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', 'f9f20a7c-4145-4521-894c-41d7e5bfe3e8', '17931f97-931a-409e-b9cf-7e3364b2268a', 'ac1d860f-1ed4-4f96-87b5-fcf6f3df70fe', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '93c0bed7-5277-4c04-8ad1-133cad8e40c4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.570557+00', '2026-09-24 21:48:22.574783+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('f87787a2-a5b9-40db-95fc-2b2d9ef501ca', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'f85a2900-6b33-48f0-b475-119a6e762e3c', '17931f97-931a-409e-b9cf-7e3364b2268a', '6662788e-2240-42ab-8ef5-879911bd0547', 'marketing', '00000000-0000-4000-8000-000000000003', 'f9ac64cd-da3d-4227-8522-1a90edafc892', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '61851661-5a57-47da-aede-e934ad0c8ea5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.593848+00', '2026-09-24 21:48:22.598039+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('1651d894-0951-4886-8c91-bc8fc91f817e', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '9a2fd8b5-5ea4-4ffa-af7f-484511b456c5', '17931f97-931a-409e-b9cf-7e3364b2268a', '380a2156-3233-4aa9-8819-374f803e8c4a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'e40820bb-d153-4c88-b087-534269b95553', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.613852+00', '2026-09-24 21:48:22.616819+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('d0d99b5a-b0d0-4548-8778-89b1e8c91660', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '996937a6-65ff-464e-88dd-d1a66ebfbf83', '17931f97-931a-409e-b9cf-7e3364b2268a', '3ce14953-2938-4328-8116-d0d272b4d069', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '48da8dd7-af3f-413b-96a8-74044ec62fcd', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.630895+00', '2026-09-24 21:48:22.633555+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('95aa23c8-78bd-46b5-9972-97d893017148', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', '17931f97-931a-409e-b9cf-7e3364b2268a', '0ac0ab1e-a5c9-47b0-bb20-816171279028', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '2f558ca7-df76-4ca5-93fe-f64d674459e1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.645234+00', '2026-09-24 21:48:22.647615+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('46369809-1816-4f0b-9e52-5f4403887d09', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', 'ccde90be-8a90-4545-9944-54de4a3a9790', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'f1d7f8fd-9cac-4e7e-a87b-7c06f1f6170d', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '670b045d-bfe2-42fe-bdd7-b2f07d656f46', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '83ef80c5-83e3-45de-a9c4-e015f93eb562', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.659261+00', '2026-09-24 21:48:22.662459+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('5b4f9c6b-4b12-4cf0-88b2-d9e0a2eb54fa', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', 'f9f20a7c-4145-4521-894c-41d7e5bfe3e8', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'a437d3f8-2e8e-44e4-ab34-a6aba490e6fa', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '89924c02-5500-4091-9898-d25bed51ee56', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.676325+00', '2026-09-24 21:48:22.679517+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('9783ede9-94dc-4f49-a6bd-2fe6766f59c0', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2b5575e6-6128-42b9-9039-5fe2b2db14e9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'b6a583f2-5fbe-4685-b1dc-1f778606567c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.692614+00', '2026-09-24 21:48:22.695282+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('ca4a7131-1bf2-4884-a873-cca18a50fbab', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '16c730ef-8cec-4c0c-9137-255d9da5908e', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2daed6f5-2bd3-48dc-b9f1-c82e66e0eadf', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'ff849bba-bbb8-45cb-bca7-5651e1df8a06', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.708299+00', '2026-09-24 21:48:22.711167+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('d61838c6-551a-4941-8fa3-970293eaee13', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '39c254af-3d5e-4403-965e-581fbb3afdce', '17931f97-931a-409e-b9cf-7e3364b2268a', 'ac1d860f-1ed4-4f96-87b5-fcf6f3df70fe', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '8f0dd885-bee9-41f2-8099-e328a44b3eb7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.723499+00', '2026-09-24 21:48:22.726316+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('f3c1e01a-0144-499e-aa3b-44a5791d1aa5', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '9a2fd8b5-5ea4-4ffa-af7f-484511b456c5', '17931f97-931a-409e-b9cf-7e3364b2268a', '380a2156-3233-4aa9-8819-374f803e8c4a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '9ee1fcec-1a2f-4992-8d27-296c580fc60a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.739155+00', '2026-09-24 21:48:22.741741+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('f547331b-60ff-46f5-b01d-c85169b2bd39', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '39c254af-3d5e-4403-965e-581fbb3afdce', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'a437d3f8-2e8e-44e4-ab34-a6aba490e6fa', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', '7f69c12d-72e0-4a23-88eb-be78e47e357a', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '6ef331fd-fd55-4d24-964a-6df64deb9c99', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.753984+00', '2026-09-24 21:48:22.759136+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('d1b501b2-f234-44a9-9774-5f573cf7ae4e', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', '17931f97-931a-409e-b9cf-7e3364b2268a', '0ac0ab1e-a5c9-47b0-bb20-816171279028', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.782211+00', '2026-09-24 21:48:22.782211+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('fb56cbdf-9411-4286-9d9f-89c41663f029', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'f1d7f8fd-9cac-4e7e-a87b-7c06f1f6170d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.787607+00', '2026-09-24 21:48:22.787607+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('d875ca9b-864c-4e54-9e06-28bb837966b0', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '32ad6ed8-6c7d-4b94-b739-b09fca9ed4dc', '17931f97-931a-409e-b9cf-7e3364b2268a', '9b4b9c24-6eae-4a05-8704-f92f147bba02', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.793411+00', '2026-09-24 21:48:22.793411+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('89257c31-0b17-42e9-b7df-3044bb877479', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', 'ccde90be-8a90-4545-9944-54de4a3a9790', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2daed6f5-2bd3-48dc-b9f1-c82e66e0eadf', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '670b045d-bfe2-42fe-bdd7-b2f07d656f46', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.796849+00', '2026-09-24 21:48:22.796849+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('f2300957-6118-43f4-88ac-2726fc9682a0', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '834e5566-6610-4e68-87bd-e20de397bbdc', '17931f97-931a-409e-b9cf-7e3364b2268a', '6662788e-2240-42ab-8ef5-879911bd0547', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.800231+00', '2026-09-24 21:48:22.800231+00', 'signage', 'directional');
INSERT INTO public.signage_items VALUES ('8c298e51-349a-45b9-8db4-086e0652bf90', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'f85a2900-6b33-48f0-b475-119a6e762e3c', '17931f97-931a-409e-b9cf-7e3364b2268a', '6662788e-2240-42ab-8ef5-879911bd0547', 'marketing', '00000000-0000-4000-8000-000000000003', 'f9ac64cd-da3d-4227-8522-1a90edafc892', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.803325+00', '2026-09-24 21:48:22.803325+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('9f274a0d-e501-4edb-95f3-6d9cc7468d86', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '996937a6-65ff-464e-88dd-d1a66ebfbf83', '17931f97-931a-409e-b9cf-7e3364b2268a', '3ce14953-2938-4328-8116-d0d272b4d069', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.806489+00', '2026-09-24 21:48:22.806489+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('9f3df55f-f6a5-4ece-bcfd-bba5e81c2cd6', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', '17931f97-931a-409e-b9cf-7e3364b2268a', '3ce14953-2938-4328-8116-d0d272b4d069', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.809373+00', '2026-09-24 21:48:22.809373+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('e8c5e11e-e9f6-425d-bc0d-7ca112bc2ac9', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', 'd1338361-90a2-4ec3-bf45-c0851c18450a', '2b5575e6-6128-42b9-9039-5fe2b2db14e9', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, '7bf7a202-c27e-40e7-89fc-f87a4ecc39f7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.812412+00', '2026-09-24 21:48:22.815162+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('8c02ca69-bd01-4ab6-9c8d-a855ca5294f2', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', 'bd3d7c8c-1aa9-400a-93fb-02711d92990b', 'd1338361-90a2-4ec3-bf45-c0851c18450a', 'b3d074a9-2db3-4d9b-8ad5-7f2a9d460e96', 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', '7f9797c7-f4aa-464b-b226-8ebce34c1129', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'ecec2efe-6c76-40fa-b1ce-d3a2adce25d0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.827473+00', '2026-09-24 21:48:22.830548+00', 'signage', 'sponsorship');
INSERT INTO public.signage_items VALUES ('b9c38efe-7a97-493a-ac35-561bd00994d2', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '14f48a40-68f3-4eec-b62f-bd30d265d524', '17931f97-931a-409e-b9cf-7e3364b2268a', '0ac0ab1e-a5c9-47b0-bb20-816171279028', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.843453+00', '2026-09-24 21:48:22.843453+00', 'signage', 'venue');
INSERT INTO public.signage_items VALUES ('6d73dcee-d026-4cca-8688-9e9e07e8e029', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'ea0bbc25-504f-4ae2-bbd5-5fe21c517542', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 'c9f7af5a-d9fd-45cc-9109-17f6834ee226', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.847399+00', '2026-09-24 21:48:22.850073+00', 'sponsorship_item', NULL);
INSERT INTO public.signage_items VALUES ('40a4aa30-5652-424c-b857-610e8f656379', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '34be14f8-c7e3-4f3a-8129-12d0d301fdbb', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '896857d9-22f8-4de4-9ba6-9b70ce50913f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-24 21:48:22.862329+00', '2026-09-24 21:48:22.862329+00', 'sponsorship_item', NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('52124388-ddad-4313-8ed6-06150f1a909f', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '9783ede9-94dc-4f49-a6bd-2fe6766f59c0', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '2494e66e-51aa-475b-926f-e7c64e150c1c', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-24 21:48:22.704574+00', '2026-09-24 21:48:22.704574+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('7f69c12d-72e0-4a23-88eb-be78e47e357a', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', 'Logo on 6 hanging banners', 6, '2026-09-24 21:48:22.321327+00', '2026-09-24 21:48:22.321327+00');
INSERT INTO public.sponsor_entitlements VALUES ('7f9797c7-f4aa-464b-b226-8ebce34c1129', 'ad1a5a36-9460-47d1-9d44-144dfdf8ec83', 'Entrance feature branding', 1, '2026-09-24 21:48:22.323247+00', '2026-09-24 21:48:22.323247+00');
INSERT INTO public.sponsor_entitlements VALUES ('36e40dfe-3c6c-4bb8-96cb-180e4fb91e47', 'f9ac64cd-da3d-4227-8522-1a90edafc892', 'Seminar theatre branding', 1, '2026-09-24 21:48:22.327153+00', '2026-09-24 21:48:22.327153+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('ad1a5a36-9460-47d1-9d44-144dfdf8ec83', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-24 21:48:22.318711+00', '2026-09-24 21:48:22.318711+00');
INSERT INTO public.sponsors VALUES ('f9ac64cd-da3d-4227-8522-1a90edafc892', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-24 21:48:22.325113+00', '2026-09-24 21:48:22.325113+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('efd7462b-a729-4d8a-96f8-21341850233c', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '27ce8171-e08f-416c-b4ab-c53defd57c88', 'STD-BIRM27-A10', '45f1d3cd-c700-4af3-b96f-8048eb42668f', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-18 21:48:22.187+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 1, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.87019+00', '2026-09-24 21:48:22.87019+00');
INSERT INTO public.stand_submissions VALUES ('53771647-6ffd-4ef5-8c2f-b7ae810cde52', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'e7d71b74-0c47-4446-8dcd-a2e1f1301616', 'STD-BIRM27-A20', '3dcce876-8e47-4b84-9eef-b48044bfffc1', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-18 21:48:22.187+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 1, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.883769+00', '2026-09-24 21:48:22.883769+00');
INSERT INTO public.stand_submissions VALUES ('8f2b93cd-3123-4064-94d5-4f7733ce181b', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '63769ee0-c0a6-491d-9825-1f48d4a2069f', 'STD-BIRM27-A30', '45f1d3cd-c700-4af3-b96f-8048eb42668f', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-18 21:48:22.187+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 1, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.895587+00', '2026-09-24 21:48:22.895587+00');
INSERT INTO public.stand_submissions VALUES ('417e55e4-a420-4864-bd60-cac9a883bba6', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'c7c98196-fb16-4fb3-a2f7-a4db1ccc8364', 'STD-BIRM27-B10', '3dcce876-8e47-4b84-9eef-b48044bfffc1', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-18 21:48:22.187+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 1, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.907285+00', '2026-09-24 21:48:22.907285+00');
INSERT INTO public.stand_submissions VALUES ('351e68eb-1d55-4404-a50f-a079b741674d', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '61242659-9647-4591-988a-3b3142656bcb', 'STD-BIRM27-B20', '45f1d3cd-c700-4af3-b96f-8048eb42668f', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-18 21:48:22.187+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 1, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.92035+00', '2026-09-24 21:48:22.92035+00');
INSERT INTO public.stand_submissions VALUES ('8aee9e72-7a47-48b0-9b92-e86afed338df', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '98a2c584-123f-4a26-ae67-4a5cb87abff1', 'STD-BIRM27-B30', '3dcce876-8e47-4b84-9eef-b48044bfffc1', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 0, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.932428+00', '2026-09-24 21:48:22.932428+00');
INSERT INTO public.stand_submissions VALUES ('a5362cfb-99c2-4282-a19b-cbe84f5c3cbf', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', '2976d068-ef24-42e2-bf8a-5e7a3318ab64', 'STD-BIRM27-C10', '45f1d3cd-c700-4af3-b96f-8048eb42668f', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 0, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.935363+00', '2026-09-24 21:48:22.935363+00');
INSERT INTO public.stand_submissions VALUES ('a55627cf-e249-41b1-aff2-47fc02bf6717', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'c636cd4f-cbca-4241-a337-d8c21cb8cdc6', 'STD-BIRM27-C20', '3dcce876-8e47-4b84-9eef-b48044bfffc1', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '15cdf739-df96-4503-9c69-a6f3446e0505', 0, '00000000-0000-4000-8000-000000000002', '2026-09-24 21:48:22.937986+00', '2026-09-24 21:48:22.937986+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('2494e66e-51aa-475b-926f-e7c64e150c1c', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-24 21:48:22.303853+00', '2026-09-24 21:48:22.303853+00');
INSERT INTO public.suppliers VALUES ('73080585-5466-400e-bb8a-b034a9ba0731', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-24 21:48:22.305993+00', '2026-09-24 21:48:22.305993+00');
INSERT INTO public.suppliers VALUES ('670b045d-bfe2-42fe-bdd7-b2f07d656f46', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-24 21:48:22.30871+00', '2026-09-24 21:48:22.30871+00');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('b8f7e02a-0e5f-41dc-a82b-7a9d070d45da', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ef9a2ba2-1d6a-4cca-9213-527eaa3c6d62', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-01', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', 'bd54d143-c0b6-49e4-b212-9738752ebb89', NULL, '2026-09-24 21:48:22.945564+00', '2026-09-24 21:48:22.945564+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.221435+00', '2026-09-24 21:48:22.221435+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.225868+00', '2026-09-24 21:48:22.225868+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.228341+00', '2026-09-24 21:48:22.228341+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.230652+00', '2026-09-24 21:48:22.230652+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.233299+00', '2026-09-24 21:48:22.233299+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-24 21:48:22.235591+00', '2026-09-24 21:48:22.235591+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.377445+00', '2026-09-24 21:48:22.377445+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.383186+00', '2026-09-24 21:48:22.383186+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.386905+00', '2026-09-24 21:48:22.386905+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.3903+00', '2026-09-24 21:48:22.3903+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.393249+00', '2026-09-24 21:48:22.393249+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-24 21:48:22.424709+00', '2026-09-24 21:48:22.424709+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('239bfcc6-eda6-4be6-a1b5-deb962d66d37', '79d81846-29b7-485b-b431-52de1a9d2648', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-24 21:48:22.246827+00', '2026-09-24 21:48:22.246827+00');
INSERT INTO public.venue_rules VALUES ('10c9bc4f-e529-4eb3-805a-71fdc32aae67', '79d81846-29b7-485b-b431-52de1a9d2648', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-24 21:48:22.249226+00', '2026-09-24 21:48:22.249226+00');
INSERT INTO public.venue_rules VALUES ('da8790c1-4815-4e07-b229-311029e74553', '79d81846-29b7-485b-b431-52de1a9d2648', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-24 21:48:22.251243+00', '2026-09-24 21:48:22.251243+00');
INSERT INTO public.venue_rules VALUES ('f3711c2b-4c55-4e7f-844d-36ea44ad0c59', '79d81846-29b7-485b-b431-52de1a9d2648', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-24 21:48:22.253053+00', '2026-09-24 21:48:22.253053+00');
INSERT INTO public.venue_rules VALUES ('9460eff9-931b-402d-9f54-7c6d67ccdeb4', '79d81846-29b7-485b-b431-52de1a9d2648', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-24 21:48:22.255046+00', '2026-09-24 21:48:22.255046+00');
INSERT INTO public.venue_rules VALUES ('79307a69-784a-48bb-b566-faa6eca6fceb', '79d81846-29b7-485b-b431-52de1a9d2648', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-24 21:48:22.2567+00', '2026-09-24 21:48:22.2567+00');
INSERT INTO public.venue_rules VALUES ('6ab359d3-d9be-47ef-bb9b-9c0684df4b26', '79d81846-29b7-485b-b431-52de1a9d2648', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-24 21:48:22.258892+00', '2026-09-24 21:48:22.258892+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('79d81846-29b7-485b-b431-52de1a9d2648', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-24 21:48:22.240725+00', '2026-09-24 21:48:22.240725+00');
INSERT INTO public.venues VALUES ('242d06f7-2f2b-40d3-8541-60533f8ddf07', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-24 21:48:22.242699+00', '2026-09-24 21:48:22.242699+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('9dd4dab5-b06d-4cc8-8f76-1e97fc84fabb', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 1, 1, 'Marketing brand check', 'approval', 'role', 'marketing', NULL, '{always}', 3, true, true, '2026-09-24 21:48:22.33105+00', '2026-09-24 21:48:22.33105+00');
INSERT INTO public.workflow_steps VALUES ('1244b80d-38e0-44b8-a1fd-886eba41b064', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 2, 1, 'Sponsor approval', 'approval', 'role', 'sales', NULL, '{if_sponsored}', 5, true, true, '2026-09-24 21:48:22.334003+00', '2026-09-24 21:48:22.334003+00');
INSERT INTO public.workflow_steps VALUES ('a7acc52d-93d7-4753-a01e-e600641f26ce', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 3, NULL, 'Ops technical check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-24 21:48:22.335043+00', '2026-09-24 21:48:22.335043+00');
INSERT INTO public.workflow_steps VALUES ('8459e46d-52de-4a38-b71f-9ab16cdad918', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-24 21:48:22.335977+00', '2026-09-24 21:48:22.335977+00');
INSERT INTO public.workflow_steps VALUES ('3bc5a12e-7972-4677-b0e8-82f999fff2c8', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-24 21:48:22.33802+00', '2026-09-24 21:48:22.33802+00');
INSERT INTO public.workflow_steps VALUES ('57a9421c-62a6-4968-9f74-543e1d1a8d6f', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-24 21:48:22.338882+00', '2026-09-24 21:48:22.338882+00');
INSERT INTO public.workflow_steps VALUES ('f12042e6-5507-4e6f-9d40-f13a6a431fdf', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-24 21:48:22.339719+00', '2026-09-24 21:48:22.339719+00');
INSERT INTO public.workflow_steps VALUES ('961be73b-cce3-4e34-bdb3-ef07bb1dc2ce', '896857d9-22f8-4de4-9ba6-9b70ce50913f', 5, NULL, 'Event Director sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{if_requires_event_director,if_cost_over_threshold}', 3, true, true, '2026-09-24 21:48:22.336915+00', '2026-09-24 21:48:22.343106+00');
INSERT INTO public.workflow_steps VALUES ('fbcf6406-ce8e-425d-a266-a5ee2af75ed0', '15cdf739-df96-4503-9c69-a6f3446e0505', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-24 21:48:22.35055+00', '2026-09-24 21:48:22.35055+00');
INSERT INTO public.workflow_steps VALUES ('5613f2c6-9601-4917-9a5a-06e9b920a23d', '15cdf739-df96-4503-9c69-a6f3446e0505', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-24 21:48:22.351483+00', '2026-09-24 21:48:22.351483+00');
INSERT INTO public.workflow_steps VALUES ('ef14828c-7f21-4a4a-b8f4-c3b810c64c68', '15cdf739-df96-4503-9c69-a6f3446e0505', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-24 21:48:22.352467+00', '2026-09-24 21:48:22.352467+00');
INSERT INTO public.workflow_steps VALUES ('0e1792d5-1f9b-4fc7-babe-409d10316938', '15cdf739-df96-4503-9c69-a6f3446e0505', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-24 21:48:22.353395+00', '2026-09-24 21:48:22.353395+00');
INSERT INTO public.workflow_steps VALUES ('2b8a48fe-5fdc-4db6-b968-79060904b66c', '15cdf739-df96-4503-9c69-a6f3446e0505', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-24 21:48:22.354469+00', '2026-09-24 21:48:22.354469+00');
INSERT INTO public.workflow_steps VALUES ('bb3cb64e-de70-4eeb-b363-cce0504f5b62', '15cdf739-df96-4503-9c69-a6f3446e0505', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-24 21:48:22.355532+00', '2026-09-24 21:48:22.355532+00');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('896857d9-22f8-4de4-9ba6-9b70ce50913f', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Signage default', 'signage', true, false, '2026-09-24 21:48:22.329362+00', '2026-09-24 21:48:22.329362+00');
INSERT INTO public.workflows VALUES ('15cdf739-df96-4503-9c69-a6f3446e0505', '1cc362fb-68ad-4a76-8991-19c11b0b7e53', 'Stand default', 'stand', true, false, '2026-09-24 21:48:22.349202+00', '2026-09-24 21:48:22.349202+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 4, true);


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

\unrestrict xvmUQ1Ms52aIJW1RpydhUcfPLtRejAuwqVbiZb6ybz9IiMiytl8bbbMMEbcPdsa

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
