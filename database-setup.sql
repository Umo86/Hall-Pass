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

\restrict OWdcSdCZ4c4aj46Gz6sXXbLaoJ3XbqXKlFEyhDnwPoHa4GFfmHgPpUOJWjDO7qy

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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('9c9eebfb-1492-4015-a455-d89a564f872c', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('d37c1f94-2a20-47ab-b1c2-3b82d1c74d18', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('832f1087-fd08-44ff-8907-bcc03e6027d0', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('bfa09fad-e7e1-4206-9855-be0278e8d57d', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3c270e1a-c598-422d-92b5-fab146bb48cd', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('282e046b-868c-40cf-83c1-569afad09def', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('59dedbd2-26c4-439e-8ca8-3c59478b3c68', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f0e303c9-3c0c-4037-98d2-e815c70fd81c', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.384047+00', '2026-09-25 14:24:47.384047+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('4d883985-63cd-4e66-9259-2827eb936759', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('abc25a7f-a070-402f-af88-48da878dfff9', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('8c61c78b-eba4-4f91-a459-0c468494328e', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('cae1a744-6482-49a1-b760-23b888e7a605', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3dfb35eb-0610-4277-800c-b7f8a1390b52', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('600ad3f5-b6b5-43c9-b58f-076a791acd67', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('4d9621dd-98fc-4200-bd54-db1fee5564e1', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a37bdbfd-2ff8-4d27-b986-5acf8d6c7d03', 'signage_item', '74d757ff-dda9-470d-96bb-d51498b25331', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.412409+00', '2026-09-25 14:24:47.412409+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ccf39e43-1090-4828-8eb7-3e32fac61f9e', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 14:24:46.968+00', '2026-09-21 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('a559ccf5-f674-44b4-85ab-a9958fdac8f7', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 14:24:46.968+00', '2026-09-16 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('ebb564d1-f71c-4dfe-aa6b-f969b4c50061', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 14:24:46.968+00', '2026-09-18 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('6568ad71-1659-48b6-98b7-ba90f5a22ce0', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('0aa689da-99c9-4a2c-9b5c-9046c3d8e644', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('4d62efde-42e4-41d4-8df0-2e77495fe916', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a89716b4-6254-49a7-ad05-5019ed8d4e7f', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('e02a2bba-39bd-47d7-90fd-e8d840f270f0', 'signage_item', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.44029+00', '2026-09-25 14:24:47.44029+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('955bc344-782f-4ce9-bece-39e49c990985', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('10f692ee-254f-46cd-aff6-dfacb1c69483', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('22508e4a-821a-4950-9c6e-b9fbc66d4bef', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('4a94c102-f5b9-44ff-b632-45cd33206550', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('ae4efa5e-0eea-4b39-aa3b-dcd70085bd44', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('aff71a69-9065-4f4a-bc21-37193ba5f021', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('ea430734-9c14-48dd-88ac-7b032bab4e61', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a79d0aaa-05ef-49dd-b597-9b1795cc377f', 'signage_item', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.47193+00', '2026-09-25 14:24:47.47193+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6771cf93-3533-4c65-a8bf-ac8310f8cbde', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('a2f8d12a-4027-4005-b213-39c18b5c4cd9', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('6edc79bb-beeb-479b-83a1-72568f2f4e40', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('58881108-1836-4b4f-8dec-3a5dac301896', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('c4a80423-e8b7-441f-b6e2-7499f927d744', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('17474d70-0c96-49a5-ab6d-ca1dea15685d', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('6f358ef2-720a-48f7-8e67-705f756e4651', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('27970c57-6f45-4931-bc4e-4f3b316e9bf0', 'signage_item', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.492579+00', '2026-09-25 14:24:47.492579+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('8e61f863-8c32-4794-90fe-262b80baef5f', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 14:24:46.968+00', '2026-09-16 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('fa0aa92f-1f7b-4b37-b795-85bfd4513577', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 14:24:46.968+00', '2026-09-16 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('c5e260b0-647c-48e8-99fe-845ef84f50f8', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('0162cda3-3135-4779-93dd-54dff4224da0', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('1dc1dc38-5110-4c57-9503-f36bec87eb7f', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 14:24:46.968+00', '2026-09-21 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('5cfe9236-dcf8-4f1c-91e5-b18fdc43d8ba', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('e281db55-21ee-443d-b1cd-3b4b52af0cbe', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('09c9ca1b-14e7-40a1-b372-d9c389fca6e4', 'signage_item', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.519411+00', '2026-09-25 14:24:47.519411+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('67bfaf33-74d2-4e2e-9ba5-24de399bbae5', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('c8cb5fd8-cf97-495a-b2d9-e5c40a488517', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('23c7b2b5-f3cc-49f9-9a7c-abc7a2f53a42', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('78d7c1ba-a9c3-445e-8bc3-a647a2eaef49', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('16535642-c938-4b00-be62-81f7f064c33a', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('7c7756d1-7f02-47fe-aa61-ea2b2dccee25', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('48628c45-ecb4-4b3c-b3d0-a0b8f0caa025', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('24ea3d9b-d1c8-415f-a677-d8a9ad4716c7', 'signage_item', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.570392+00', '2026-09-25 14:24:47.570392+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('739b3591-1120-4f6f-b2ed-2aa07547477a', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('5e7533af-30cd-497c-abae-4a297564287c', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('471d80ac-1ab0-442e-9f24-7e17264c80bd', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('3660c4d0-8f4c-42f6-be89-ad057ddca08a', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('64b665a4-4346-4ec6-824d-6d8583dccae6', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('498c61e6-5afc-4eb7-8ab9-b38a8b8a3cff', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('18169f2e-deb5-469a-b624-1be6f2344275', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('a402ad1e-884b-4b0a-9468-c246e0c9e2c6', 'signage_item', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.602342+00', '2026-09-25 14:24:47.602342+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('b28ff8f9-540a-4c2d-b59c-8e9ee37284ac', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('b3c614b4-24e7-4ee6-8ada-4a983b6bfbe5', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('b981cda4-2106-46cd-9a3c-d134ae9e9294', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 14:24:46.968+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('4e383f7d-30b2-4729-abf7-d3365e7db66e', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a8b73aeb-8b88-41c8-8ee7-d38ba9a4da6d', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('886e0b24-33b2-4a77-a4df-771074af896e', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('847abbce-8b52-4c3a-8926-8cc98fd905ba', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('13cc9ec2-a3dc-40a7-b006-acd61e3421df', 'signage_item', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.629986+00', '2026-09-25 14:24:47.629986+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('67c433a1-e811-4afc-84b3-b84a4a6827e2', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('60c9a407-4fae-4654-b16f-fd2efcf6b0ea', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('30e60e86-6892-4eac-b706-aecc5fe8d010', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('ff21ca28-b705-46b4-a327-8d43ae132a29', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('adbfff7f-7a2c-4716-873b-4d5507e9af8a', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('730af7f6-5e40-4b98-9efe-821b2f87b8d5', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('c5980677-8d42-41ab-a80d-fe061bccf669', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('9c08979e-f824-419f-93d9-364012fd70a6', 'signage_item', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.65691+00', '2026-09-25 14:24:47.65691+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('151ababa-9821-433d-8b65-9f2f1bad6582', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('dc944749-7549-4a85-ae1a-94e5d89f2a72', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('70af8d17-c911-4233-bccd-6b8d60bdc30c', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('293d3049-50f1-40c7-9b50-854f48c16b82', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('02136a08-a6b2-4e4e-94d8-a738f377c065', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('9f1d80f6-ee21-41b8-965b-97637e017934', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('6152c783-b1d7-4dd1-b64a-4f010536e28a', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1e76c3ed-aefd-4abb-acff-6ee94bba79f3', 'signage_item', '4db924d6-c43c-43e4-928e-206997e7053b', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.68112+00', '2026-09-25 14:24:47.68112+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('2fc12f19-65ce-4981-967f-633c00827f4b', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('47f5f33c-014f-4feb-af57-5d4f1b7701d0', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('f12e3f54-a1ce-403b-b848-e3eb7db1a217', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('bbf64fc6-cd57-4bce-90c9-63dc7b3202f1', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a857c21a-c59f-405e-a037-34e30756ab62', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('e05a5ab6-119e-4189-b8e1-4e350b411cb5', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('fe634406-43f5-4083-99e7-193bd31d950c', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('6d305ece-97df-4cf9-af47-fb37ed4608f1', 'signage_item', '8201756c-108e-443e-9614-585e2828d2ab', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.704713+00', '2026-09-25 14:24:47.704713+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d507ba63-7067-4326-a970-3c8cfedbbbdb', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('36fb0ddd-ae6f-4c26-a3dc-79205470031a', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('9d40d514-2d45-4fe7-8154-ffcd9723947b', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('e0c5a4f3-ae23-4fa8-8412-f7bef2d23dc7', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('a15b8a66-5de5-468e-892f-cacc3ed4206b', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('feb80647-c2d3-46f3-9ad4-a47ce7f51874', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d6fe3799-164e-4da7-abac-45a611ae66c9', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('40ee41ff-bcab-4a88-872e-1f9f9c47c80c', 'signage_item', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.733917+00', '2026-09-25 14:24:47.733917+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f0508e6f-7d70-4c7e-993f-cd14cd9ad511', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('3cc3dd69-ec20-45fe-a979-4570560bead2', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('01e1a3a3-00f8-441e-a740-c193397457e2', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('2bc74acc-8015-4ebb-9fa7-1a064a879795', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('5f1674a9-f634-48db-9412-ba86de7f11b2', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('f129c598-5b13-4f7e-8765-394e3dff5938', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d5383154-372c-4372-b902-1b6879458b98', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('792ffff3-17af-4f39-a84f-28987fe90118', 'signage_item', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.754425+00', '2026-09-25 14:24:47.754425+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('bda8688d-06e9-4d09-a4b8-64e3701ffcfd', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('834f9f61-577a-417f-be48-d23d81b7c0cd', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('3d31da1d-3b0f-42d6-bdb3-a0d7609a933e', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('12287750-6550-4a42-8ed0-4d6f94b7012d', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('74462cba-59c0-469f-8843-44ca1a46b115', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('17587db8-6179-48cd-ab44-897f15b4c50f', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('f5a76ad4-8254-4117-a9f9-ffe4003ddb76', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c5797ae8-2c6c-462a-880a-2c21e79b8e31', 'signage_item', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.77493+00', '2026-09-25 14:24:47.77493+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('3f0237c9-3483-4e33-8081-e56eac5c793f', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('ed355ef8-8d20-4453-bf60-d63e999ae809', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('542fd870-a114-45d7-863f-8f113d53ddf5', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('20fd8bff-188e-4f2c-903f-78755ede9ca0', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f77d0395-1954-4a6e-a3b8-d01a6b4fc340', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('8ffd24fc-5715-43ac-aaee-2b0a2f8b4279', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1a7973bc-67a5-418c-915e-ebb057805160', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('ae7947ce-363d-4eeb-92ae-07827afacc90', 'signage_item', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.798116+00', '2026-09-25 14:24:47.798116+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('c0fa2900-3b9a-419c-a84e-2c1abdf745f9', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('68f47b4c-daac-49d5-9a11-ff19e577e93b', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('9d5120eb-a454-498f-8387-d9e0fcf1544f', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('55603a23-b0c4-4138-bc8f-f5e17d832aa7', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('dea2deed-2294-400b-85ad-9db3957b7bb5', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('79e924a3-40ca-4e4c-97e5-1caeea2a69c8', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('759ecbd8-453c-478d-b170-fa48569cdbd5', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('19e42598-56b0-4f02-af59-23d44f0ed44f', 'signage_item', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.828384+00', '2026-09-25 14:24:47.828384+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('1c7de049-76ea-4ace-88de-d4889a5bbec5', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('974efd76-5fc5-4c33-8f50-f34df60575b1', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('421a250e-8074-4cba-b9c0-23e837a6fc35', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('bb05d63b-3e0e-47e5-b49c-281bbe486fe5', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('c5d4bed4-644b-42b3-b928-b7079b0f852e', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('34a1d786-d8b0-4153-a871-f1a1626484ca', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('aa0356b9-14b8-454b-b07a-9f2d0ccca4a2', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('eceee3d4-5d7d-49a9-9b7f-b9aa34c45c9a', 'signage_item', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.849183+00', '2026-09-25 14:24:47.849183+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('fec97b06-8043-4aa0-b006-c4d1b05bd8e0', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('880df05e-e06d-4b63-93fc-f699d1a9f15f', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 14:24:46.968+00', '2026-09-27 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('77582270-a85c-458c-9d87-1cd344140427', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('9fafce29-2032-41a5-9513-daa6d6d18cba', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 14:24:46.968+00', '2026-09-27 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('98933682-4c0a-4fa0-8a8e-a747cd96f352', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('5ad80b14-1096-46ea-901d-03df9953a8a4', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-24 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('b718fdc4-ab20-4a97-88e9-f7429511be4c', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('e7ff6272-9f68-49f9-b2ed-3ee6cf2474bf', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('94f46669-6398-4a14-89a3-1d3eebba199f', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('001ee4ad-5c92-4bba-aead-04460dca5fab', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('7d6dff58-a956-49c8-8061-2bf95e62af7c', 'signage_item', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.874408+00', '2026-09-25 14:24:47.874408+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('f8a4ee36-7302-428b-8227-bce45ef97ebd', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('c932e729-9390-4dca-b720-8766721e92b3', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('d30ac30c-8f0b-487e-8e2d-b6dfbdcbc3dd', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('17357eec-7c3b-49c8-b566-837319e00120', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3d2cb2d9-476a-4681-9040-2f428c891a0c', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('fca8aac7-ef2c-4efd-a52c-3750e93384c1', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d2838cf6-436b-433c-97ef-4b769402cd59', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('62c961d3-f513-473b-8fe3-3c60929b13da', 'signage_item', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.940309+00', '2026-09-25 14:24:47.940309+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('de8ac15f-a42b-4dc4-99df-ce75786fba82', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('fb6d9dd6-603c-4d4e-b954-029033e200e9', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('411d3fdf-5bf0-4363-a210-1c6099238778', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('09302023-84dd-43d7-8151-fe8082e175a3', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-22 14:24:46.968+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-29 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('b3d0f445-6b52-4c98-bc97-fe26b0f4dfa1', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('5633b499-1877-46b9-a64d-e284f1265bac', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-22 14:24:46.968+00', '2026-09-24 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('d0d8ce85-07cb-4881-b02c-5da967ad00ec', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('74725192-78dd-4c2a-9483-28d61562c7f4', 'signage_item', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.963008+00', '2026-09-25 14:24:47.963008+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('46ac37ed-ebed-497c-a342-de7c6aa3fc78', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '3d9c7dc9-907e-491a-aacf-159d9dfec648', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 3, false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.approval_instances VALUES ('2d465fb6-9cf6-4438-9676-f9783f47f237', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 3, false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.approval_instances VALUES ('ab3fcf6c-31f1-43bc-93ac-4625b9b0e751', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-20 14:24:46.968+00', '2026-09-25 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 5, false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.approval_instances VALUES ('c8663bc2-375d-436c-9522-ef3cdad9f248', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, 'c8c5f213-7f33-484f-a241-667bd5a2d19d', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('734bf708-e5c6-4430-b193-4ffc021abc52', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, 'f95fe170-a978-4977-8370-6f8c4de58a41', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 3, false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.approval_instances VALUES ('648fa738-f5f1-4d44-abcc-207d5a0a87d7', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '817da419-b4ab-4739-a63d-8601ab706d8b', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('1a080025-e5bd-46b7-9ca6-d8795cd0b7cf', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '320c012d-30af-4ec1-9b71-c840e4ba959d', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('70b6e862-bed9-433d-b26c-bd19c6bc693e', 'signage_item', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, '71426f9a-130e-4b16-80eb-6fa0493236e9', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:47.995327+00', '2026-09-25 14:24:47.995327+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('d46a774b-1eda-480c-9f72-917c4bc7fed7', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, '1e5c6e55-de44-4439-8e04-3c0c958d1053', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 14:24:46.968+00', '2026-09-22 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('ea501203-4193-478d-b746-3433aaa6ebf1', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, '8bea74a2-f696-44bf-96bb-6494b05c8429', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 14:24:46.968+00', '2026-09-28 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('75fe108c-b862-40ce-be37-40934c9a09d6', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, 'd9c195b4-70c5-411e-9578-9e3b5797bc86', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('9c22b69a-b4df-4e1d-96d4-2db277de22a8', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, 'e0ae8bed-9603-4e5a-89fd-214fac9abe70', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('25939af6-9c10-46b6-83bb-274ad974ba94', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, 'f14f6f13-72c0-4548-8676-18bc6f2f73c8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('ffad33ac-8349-460f-97bb-dfa382bbae80', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 1, '34ea6fc2-2232-4f55-a768-a9a913a56232', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('87cd09dc-09ee-4915-aba5-f736fedd543a', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, '1e5c6e55-de44-4439-8e04-3c0c958d1053', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-19 14:24:46.968+00', '2026-09-22 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('c4389cf1-e37f-4605-8505-11cb844312e0', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, '8bea74a2-f696-44bf-96bb-6494b05c8429', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('8f6fd2c9-c4d1-49d0-b9a9-570d45062641', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, 'd9c195b4-70c5-411e-9578-9e3b5797bc86', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('54786a93-8e98-4943-924f-064235175a45', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, 'e0ae8bed-9603-4e5a-89fd-214fac9abe70', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3be0f628-c00d-4466-9e87-4bd4f2ca4770', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, 'f14f6f13-72c0-4548-8676-18bc6f2f73c8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a2966650-4532-414f-9fac-31c5e1548b06', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 1, '34ea6fc2-2232-4f55-a768-a9a913a56232', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('0ae45f8c-1676-4315-8c6d-efb63b4aef51', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, '1e5c6e55-de44-4439-8e04-3c0c958d1053', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-19 14:24:46.968+00', '2026-09-22 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('b0a35be3-2fba-4746-bc0d-9b419bcc10bb', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, '8bea74a2-f696-44bf-96bb-6494b05c8429', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('3a624607-53a6-4d2b-9e68-7cfe0c70998c', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, 'd9c195b4-70c5-411e-9578-9e3b5797bc86', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('46d01936-3d45-4063-92d9-48168fdc98a3', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, 'e0ae8bed-9603-4e5a-89fd-214fac9abe70', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('79c1b4e4-2dfa-4a23-8be2-1b30ec656255', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, 'f14f6f13-72c0-4548-8676-18bc6f2f73c8', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('a6a84bc6-4972-49da-b14d-11b3ed6cf1ea', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 1, '34ea6fc2-2232-4f55-a768-a9a913a56232', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('181e3d88-e21e-45dd-9eb3-293f6973e61b', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, '1e5c6e55-de44-4439-8e04-3c0c958d1053', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 14:24:46.968+00', '2026-09-22 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('75f566e5-f46e-49dd-9517-4486c605818e', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, '8bea74a2-f696-44bf-96bb-6494b05c8429', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('81df6c68-2ca0-4c63-bc2b-ea03101b058a', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, 'd9c195b4-70c5-411e-9578-9e3b5797bc86', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-26 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('43f5b40b-6b2c-403d-98ba-f44199b474ce', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, 'e0ae8bed-9603-4e5a-89fd-214fac9abe70', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-28 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('e46b51c1-16b4-460e-879a-f73354aafefa', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, 'f14f6f13-72c0-4548-8676-18bc6f2f73c8', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('db47716f-6c60-4400-ae00-32f3a42ee23e', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 1, '34ea6fc2-2232-4f55-a768-a9a913a56232', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 14:24:46.968+00', '2026-09-21 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00', false, true, 0, false, NULL);
INSERT INTO public.approval_instances VALUES ('711a9565-975d-4aa8-9ff8-59ac69f30ddd', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, '1e5c6e55-de44-4439-8e04-3c0c958d1053', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-19 14:24:46.968+00', '2026-09-22 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', true, true, 3, false, NULL);
INSERT INTO public.approval_instances VALUES ('2a363846-3a0e-42e9-a38a-74008aa70ce1', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, '8bea74a2-f696-44bf-96bb-6494b05c8429', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f5af4d22-631f-422c-8860-2ebffa6be502', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, 'd9c195b4-70c5-411e-9578-9e3b5797bc86', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-26 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', true, true, 5, false, NULL);
INSERT INTO public.approval_instances VALUES ('72a24288-03c2-4b8b-b0d5-e90fd510223f', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, 'e0ae8bed-9603-4e5a-89fd-214fac9abe70', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-28 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', true, true, 7, false, NULL);
INSERT INTO public.approval_instances VALUES ('f20bd5cb-39e2-4524-897e-d0927d850f89', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, 'f14f6f13-72c0-4548-8676-18bc6f2f73c8', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-21 14:24:46.968+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-21 14:24:46.968+00', '2026-09-23 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', true, true, 2, false, NULL);
INSERT INTO public.approval_instances VALUES ('172a957b-1014-48af-a40b-38f6f4a6309c', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 1, '34ea6fc2-2232-4f55-a768-a9a913a56232', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-21 14:24:46.968+00', '2026-09-21 14:24:46.968+00', 0, NULL, NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00', false, true, 0, false, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('3f6bcf75-7a1a-4d67-b179-018173f6081b', 'e8081d8f-1886-42af-b834-d2307992fa84', '141db612-17a9-480c-a4c2-ff309760818c', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-09-25 14:24:47.210471+00', '2026-09-25 14:24:47.210471+00');
INSERT INTO public.approvers VALUES ('bf6c84a3-5cfb-4922-b1d0-6a034cc49c4d', 'e8081d8f-1886-42af-b834-d2307992fa84', 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-09-25 14:24:47.217457+00', '2026-09-25 14:24:47.217457+00');
INSERT INTO public.approvers VALUES ('a87b178e-bdfe-44f5-b358-714580bc401b', 'e8081d8f-1886-42af-b834-d2307992fa84', '8dbd062d-07da-403a-86dd-de93adc87639', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-09-25 14:24:47.223931+00', '2026-09-25 14:24:47.223931+00');
INSERT INTO public.approvers VALUES ('07e62967-3f41-4d60-93ab-96c3d2fbf8c9', 'e8081d8f-1886-42af-b834-d2307992fa84', 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-09-25 14:24:47.229665+00', '2026-09-25 14:24:47.229665+00');


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('60a51412-462f-44e4-bff0-1399a6a32c19', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.378605+00', '2026-09-25 14:24:47.378605+00');
INSERT INTO public.artwork_versions VALUES ('390aeef7-40b5-42e8-ae11-2717537ad27d', '74d757ff-dda9-470d-96bb-d51498b25331', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.408482+00', '2026-09-25 14:24:47.408482+00');
INSERT INTO public.artwork_versions VALUES ('1fa3cc7a-a317-47d5-82b4-a844877dc176', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-25 14:24:47.433329+00', '2026-09-25 14:24:47.433329+00');
INSERT INTO public.artwork_versions VALUES ('7e465a6f-3e02-410d-bfba-bc98f27dde9c', '5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.435826+00', '2026-09-25 14:24:47.435826+00');
INSERT INTO public.artwork_versions VALUES ('624ab016-0594-4e15-b498-c151330d5ad5', '4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.466318+00', '2026-09-25 14:24:47.466318+00');
INSERT INTO public.artwork_versions VALUES ('455cab51-4ef0-4672-a355-115ea8734654', 'f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.489298+00', '2026-09-25 14:24:47.489298+00');
INSERT INTO public.artwork_versions VALUES ('76677e98-a1df-4889-b53f-6f1133445350', 'b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.515587+00', '2026-09-25 14:24:47.515587+00');
INSERT INTO public.artwork_versions VALUES ('9d81f49c-a3a1-4569-981a-2d96058f46e5', '63dfdb31-1e91-4661-ae45-30dc93060107', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.566677+00', '2026-09-25 14:24:47.566677+00');
INSERT INTO public.artwork_versions VALUES ('3bb522d6-5135-434f-a272-0794108d210d', '55338848-e3dd-482f-83e4-bc8d1576f12f', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.596127+00', '2026-09-25 14:24:47.596127+00');
INSERT INTO public.artwork_versions VALUES ('5b9b429b-e46a-45a6-8b04-95d859a91a9b', 'dc86850b-3426-4f35-b9e0-6a18ffc940cc', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.625269+00', '2026-09-25 14:24:47.625269+00');
INSERT INTO public.artwork_versions VALUES ('47c3851e-c5b7-47d3-8585-f3bffb4ef7bc', '8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.653218+00', '2026-09-25 14:24:47.653218+00');
INSERT INTO public.artwork_versions VALUES ('d3383f5c-74fb-4d7b-8ff1-614bc5cf6309', '4db924d6-c43c-43e4-928e-206997e7053b', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.67746+00', '2026-09-25 14:24:47.67746+00');
INSERT INTO public.artwork_versions VALUES ('741c54c4-7156-4de8-988f-71776e325d87', '8201756c-108e-443e-9614-585e2828d2ab', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.701163+00', '2026-09-25 14:24:47.701163+00');
INSERT INTO public.artwork_versions VALUES ('1708ab59-31d5-4496-94b8-8b35c74d34d7', '9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.730147+00', '2026-09-25 14:24:47.730147+00');
INSERT INTO public.artwork_versions VALUES ('cb62da5f-cd9c-411f-9e96-9c993d55e425', '862f9edd-5618-4cfe-9ea2-21f0908f1363', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.751275+00', '2026-09-25 14:24:47.751275+00');
INSERT INTO public.artwork_versions VALUES ('7c864f68-52ae-4b6f-acd7-a77acedba933', '7162150a-b10d-496c-a4a6-cb06bcfe0504', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.771318+00', '2026-09-25 14:24:47.771318+00');
INSERT INTO public.artwork_versions VALUES ('e62d99c7-8413-40bf-bedd-1a1eeff59485', 'e2574f6d-dc00-4c77-85ab-c05b1c152412', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.795073+00', '2026-09-25 14:24:47.795073+00');
INSERT INTO public.artwork_versions VALUES ('1ae4dea3-9693-4458-960c-07d6514cb69f', '0f09cdb4-2da1-44c2-a252-dac972a562a2', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.82443+00', '2026-09-25 14:24:47.82443+00');
INSERT INTO public.artwork_versions VALUES ('365972f5-e7f9-4e00-b9a8-975e816829c3', '8d7d39f4-160d-405f-875f-2c186f0ee680', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.846058+00', '2026-09-25 14:24:47.846058+00');
INSERT INTO public.artwork_versions VALUES ('39378a37-c617-4234-aeda-48e7af668582', '36c29871-c8e9-483f-84a8-ed607e71418e', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 14:24:47.867533+00', '2026-09-25 14:24:47.867533+00');
INSERT INTO public.artwork_versions VALUES ('9154854a-1e27-46d0-9199-33294b6222ba', '36c29871-c8e9-483f-84a8-ed607e71418e', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-25 14:24:47.869148+00', '2026-09-25 14:24:47.869148+00');
INSERT INTO public.artwork_versions VALUES ('974473b6-155b-4957-b325-5f045caf7b31', '36c29871-c8e9-483f-84a8-ed607e71418e', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.870404+00', '2026-09-25 14:24:47.870404+00');
INSERT INTO public.artwork_versions VALUES ('9cac6840-edc5-40fc-91fc-b3edf1c00684', '5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-25 14:24:47.936548+00', '2026-09-25 14:24:47.936548+00');
INSERT INTO public.artwork_versions VALUES ('75ac3ab4-6ff9-4a39-a0fd-83678894f8f7', '9ffa2807-fb75-480a-86fd-27b2ee9a3224', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.959642+00', '2026-09-25 14:24:47.959642+00');
INSERT INTO public.artwork_versions VALUES ('1bea46f2-2548-4578-acc8-e596d6497244', '11dd69c3-7142-4670-be01-6d12963e59ac', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-25 14:24:47.9908+00', '2026-09-25 14:24:47.9908+00');


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

INSERT INTO public.contractors VALUES ('399664d6-0d81-4190-aaa6-843fe7abceb0', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-25 14:24:47.161109+00', '2026-09-25 14:24:47.161109+00');
INSERT INTO public.contractors VALUES ('bd521445-f497-4e90-b0dd-4f62bbe5b16a', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-25 14:24:47.165138+00', '2026-09-25 14:24:47.165138+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('141db612-17a9-480c-a4c2-ff309760818c', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-09-25 14:24:47.206353+00', '2026-09-25 14:24:47.206353+00');
INSERT INTO public.departments VALUES ('b7e20ffa-82c7-42bb-8b7d-488e5fb0a762', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-09-25 14:24:47.214837+00', '2026-09-25 14:24:47.214837+00');
INSERT INTO public.departments VALUES ('8dbd062d-07da-403a-86dd-de93adc87639', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Sales', 3, false, '{sponsor}', false, '2026-09-25 14:24:47.220866+00', '2026-09-25 14:24:47.220866+00');
INSERT INTO public.departments VALUES ('cb934c07-8f3a-4663-8e1f-4e44e4038cb0', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-09-25 14:24:47.227106+00', '2026-09-25 14:24:47.227106+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('9624b3ec-e570-4fb6-9628-2dc170b14cd7', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00');
INSERT INTO public.documents VALUES ('5647c654-f84f-41c7-8ef5-1ba21553e26f', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00');
INSERT INTO public.documents VALUES ('607709b5-422e-4b74-8885-e88b4c0031cb', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00');
INSERT INTO public.documents VALUES ('86fc7ed8-2a6a-4113-a397-f5dfd71a4fc2', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '93e2a4da-2f99-4d00-80e9-501572508ade', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00');
INSERT INTO public.documents VALUES ('13edc146-4e32-419d-bd7b-1005d369e70c', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00');
INSERT INTO public.documents VALUES ('45b608be-c9e5-47af-a603-e9aefc93b492', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00');
INSERT INTO public.documents VALUES ('7c29f11a-6b88-49de-9ef5-47ae1c244e6f', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00');
INSERT INTO public.documents VALUES ('8e4654a4-b3b8-49bf-9696-3300ac1b59d5', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '6362ac48-990a-4ee8-b2d0-179276deb0b6', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00');
INSERT INTO public.documents VALUES ('e600d8ca-a0aa-4147-a8b0-97b4c8cdd4ff', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00');
INSERT INTO public.documents VALUES ('1c30e6f1-c72a-4c17-8d56-d80ffb53eabf', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00');
INSERT INTO public.documents VALUES ('56f33b88-5014-4404-bf80-af3279a9ca08', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00');
INSERT INTO public.documents VALUES ('5a8e8eb4-03b6-477b-b77f-022ee21568f7', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00');
INSERT INTO public.documents VALUES ('e53b029a-befb-48c8-a5f5-85fcdb0cce26', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00');
INSERT INTO public.documents VALUES ('0b9e521b-95f0-4bac-8eec-792d5e38496c', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00');
INSERT INTO public.documents VALUES ('e9942cda-3853-489a-8376-7e302b8c7271', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00');
INSERT INTO public.documents VALUES ('5931b203-bb6c-4f13-b7ff-96db835276ad', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', '7e062199-f333-4bec-b2b2-16f8929df51c', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00');
INSERT INTO public.documents VALUES ('4ac8332d-8403-43c2-adff-ee276dbe131a', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00');
INSERT INTO public.documents VALUES ('448891bc-43ef-4563-927b-e4205fbcc17f', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00');
INSERT INTO public.documents VALUES ('2fb28978-ef59-433b-836d-409cf72684c6', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00');
INSERT INTO public.documents VALUES ('12cb3486-78d0-4b44-ba97-92b6fbfa5a41', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_submission', 'c26d60c0-126a-45c3-a10b-89bebab1f8b1', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('54ed4e01-08da-4e1f-a787-b9927b984b93', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'signage', 34, '2026-09-25 14:24:48.026878+00', '2026-09-25 14:24:48.031599+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('28d82c70-5a32-4286-9ff9-a6005aefd79e', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-25 14:24:47.073619+00', '2026-09-25 14:24:47.073619+00');
INSERT INTO public.edition_deadlines VALUES ('4203e411-d1f9-4388-945f-757ac399c700', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-25 14:24:47.076124+00', '2026-09-25 14:24:47.076124+00');
INSERT INTO public.edition_deadlines VALUES ('e804ff0e-4079-4269-b2d2-ae812246e892', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-25 14:24:47.077813+00', '2026-09-25 14:24:47.077813+00');
INSERT INTO public.edition_deadlines VALUES ('858cc79a-b27c-4b3e-89a7-df97ffd81b5c', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-25 14:24:47.079373+00', '2026-09-25 14:24:47.079373+00');
INSERT INTO public.edition_deadlines VALUES ('98dac97c-56f4-4848-b1bb-bd20f28dabd8', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-25 14:24:47.081072+00', '2026-09-25 14:24:47.081072+00');
INSERT INTO public.edition_deadlines VALUES ('b436d1f9-be45-4e3d-bc04-9355aa3fca69', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-25 14:24:47.083186+00', '2026-09-25 14:24:47.083186+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '358d86da-5983-48ed-aa87-e29cfd3d1235', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-25 14:24:47.070379+00', '2026-09-25 14:24:47.070379+00', NULL);


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('358d86da-5983-48ed-aa87-e29cfd3d1235', 'e8081d8f-1886-42af-b834-d2307992fa84', 'UK Construction Week', 'UKCW', '2026-09-25 14:24:47.037063+00', '2026-09-25 14:24:47.037063+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('1ac2ff18-4bdf-40d5-9e99-bbb886c4c81f', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Exhibitor Co', 'A10', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '399664d6-0d81-4190-aaa6-843fe7abceb0', '2026-09-25 14:24:47.332553+00', '2026-09-25 14:24:47.332553+00');
INSERT INTO public.exhibitors VALUES ('bdf5cdee-2015-486d-a855-afda0476b9cd', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SteelFrame Systems', 'A20', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', '2026-09-25 14:24:47.335409+00', '2026-09-25 14:24:47.335409+00');
INSERT INTO public.exhibitors VALUES ('d43a05a6-38b7-45fa-8a47-b4f59a56ee91', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'BrickWorks UK', 'A30', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '399664d6-0d81-4190-aaa6-843fe7abceb0', '2026-09-25 14:24:47.338115+00', '2026-09-25 14:24:47.338115+00');
INSERT INTO public.exhibitors VALUES ('0258e6af-588d-44c4-9c8f-13b85a0238ce', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Timber Trade Ltd', 'B10', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', '2026-09-25 14:24:47.340728+00', '2026-09-25 14:24:47.340728+00');
INSERT INTO public.exhibitors VALUES ('98d7ae36-c07d-4ae6-852b-0a64fd10c36d', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'GlassTech', 'B20', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '399664d6-0d81-4190-aaa6-843fe7abceb0', '2026-09-25 14:24:47.343362+00', '2026-09-25 14:24:47.343362+00');
INSERT INTO public.exhibitors VALUES ('ed462519-fca1-4882-9e3b-27ccd33337d2', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Insulate Pro', 'B30', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', '2026-09-25 14:24:47.345714+00', '2026-09-25 14:24:47.345714+00');
INSERT INTO public.exhibitors VALUES ('19beedf5-ccff-46f4-a50e-f10e7c0542a6', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'RoofRight', 'C10', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '399664d6-0d81-4190-aaa6-843fe7abceb0', '2026-09-25 14:24:47.348005+00', '2026-09-25 14:24:47.348005+00');
INSERT INTO public.exhibitors VALUES ('0e21fc91-1bdf-4548-965e-a2f4d41d0ade', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'PlantHire Direct', 'C20', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', '2026-09-25 14:24:47.350258+00', '2026-09-25 14:24:47.350258+00');
INSERT INTO public.exhibitors VALUES ('628a70a8-c0b9-490b-8ae2-657123ecb13f', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SafetyFirst PPE', 'D10', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-25 14:24:47.354336+00', '2026-09-25 14:24:47.354336+00');
INSERT INTO public.exhibitors VALUES ('fbc5d08f-ee3b-4db6-91cf-53ab286c48d8', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'ToolMart Retail', 'D20', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-25 14:24:47.358025+00', '2026-09-25 14:24:47.358025+00');
INSERT INTO public.exhibitors VALUES ('dc105d75-00ea-4244-94b0-c3dd6993c3f5', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'EcoBuild Materials', 'D30', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-25 14:24:47.360973+00', '2026-09-25 14:24:47.360973+00');
INSERT INTO public.exhibitors VALUES ('dde3a626-8996-4fd5-8ffc-a42802b0ba84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SiteWise Software', 'D40', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-25 14:24:47.364419+00', '2026-09-25 14:24:47.364419+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('42d4354b-3787-46c4-901e-f9da9cc986ee', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'venue', 'venue', '4de90ffd-2dc3-4000-b3e5-503173a40817', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.308661+00', '2026-09-25 14:24:47.308661+00');
INSERT INTO public.external_grants VALUES ('cbbeeeba-1700-428f-8f48-71ce52613dd6', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.31549+00', '2026-09-25 14:24:47.31549+00');
INSERT INTO public.external_grants VALUES ('6534e6d8-cd17-4617-a3f2-c4e6ced3b0bf', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.320228+00', '2026-09-25 14:24:47.320228+00');
INSERT INTO public.external_grants VALUES ('109ba288-b2fc-4ed2-bd46-7f6856aae1d2', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'supplier', 'supplier', '3f442670-a6c6-41ca-9627-100326afd637', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.325766+00', '2026-09-25 14:24:47.325766+00');
INSERT INTO public.external_grants VALUES ('2a88ab9f-c1be-4ffe-8d0e-226f613efeb1', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'sponsor', 'sponsor', '8d0ba254-e673-4406-aab8-f72afa0df47c', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.329815+00', '2026-09-25 14:24:47.329815+00');
INSERT INTO public.external_grants VALUES ('7566d9fa-7784-473d-92bb-58c32addfff9', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'exhibitor', 'exhibitor', '1ac2ff18-4bdf-40d5-9e99-bbb886c4c81f', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-25 14:24:46.968+00', NULL, '2026-09-25 14:24:47.368478+00', '2026-09-25 14:24:47.368478+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-25 14:24:47.086733+00', '2026-09-25 14:24:47.086733+00');
INSERT INTO public.halls VALUES ('7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-25 14:24:47.091031+00', '2026-09-25 14:24:47.091031+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('c6b3d593-84b8-478c-a37c-b9541b78fa5c', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Hanging banner', 'hanging_banner', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'rigged', true, 0, '2026-09-25 14:24:47.263919+00', '2026-09-25 14:24:47.263919+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d3628e05-ca26-42f7-a963-a62efd37148d', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Foamex board', 'foamex_board', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'wall_mounted', false, 1, '2026-09-25 14:24:47.266719+00', '2026-09-25 14:24:47.266719+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('0b3ad1b7-fa15-40f9-8b63-bf30890bf609', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Fabric graphic', 'fabric_graphic', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'shell_mounted', false, 2, '2026-09-25 14:24:47.26882+00', '2026-09-25 14:24:47.26882+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('097aaa61-f412-44f3-bd8b-dff1a08cb552', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Floor vinyl', 'floor_vinyl', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'floor', false, 3, '2026-09-25 14:24:47.273841+00', '2026-09-25 14:24:47.273841+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('dc07d14f-0b4f-4944-8fa9-1f00725da31f', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Aisle sign', 'aisle_sign', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'rigged', true, 4, '2026-09-25 14:24:47.277611+00', '2026-09-25 14:24:47.277611+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('08740f9f-5804-45bb-b0eb-543ee7047682', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Entrance feature', 'entrance_feature', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'freestanding', true, 5, '2026-09-25 14:24:47.280085+00', '2026-09-25 14:24:47.280085+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('0d42da43-188e-4042-b3ba-e5d8a4e56f4d', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Registration', 'registration', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'freestanding', false, 6, '2026-09-25 14:24:47.282089+00', '2026-09-25 14:24:47.282089+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('8bc82607-5414-4eb4-9406-681dfabf3df1', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Seminar theatre', 'seminar_theatre', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'freestanding', false, 7, '2026-09-25 14:24:47.28398+00', '2026-09-25 14:24:47.28398+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('8e7acd61-1927-4d54-8904-7cc573a041a4', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Feature area', 'feature_area', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'freestanding', false, 8, '2026-09-25 14:24:47.285725+00', '2026-09-25 14:24:47.285725+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('cec8d13b-fb13-4541-9899-00ab9c8f301e', 'e8081d8f-1886-42af-b834-d2307992fa84', 'External', 'external', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'freestanding', true, 9, '2026-09-25 14:24:47.287392+00', '2026-09-25 14:24:47.287392+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('995c38d5-6207-4e7f-960b-993fe74ece70', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Digital screen', 'digital_screen', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 'digital', false, 10, '2026-09-25 14:24:47.289205+00', '2026-09-25 14:24:47.289205+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('40f28ef7-21ad-4b5e-b499-82a10e5ffb87', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Branded lanyards', 'lanyard', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', NULL, false, 11, '2026-09-25 14:24:47.291472+00', '2026-09-25 14:24:47.291472+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('0ec1605f-e4f2-449d-b59f-69eedacc9cd9', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Show bags', 'show_bag', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', NULL, false, 12, '2026-09-25 14:24:47.293757+00', '2026-09-25 14:24:47.293757+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('b9625214-4e3a-44c3-ac83-1cd677fb233a', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Registration branding', 'reg_branding', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', NULL, false, 13, '2026-09-25 14:24:47.295781+00', '2026-09-25 14:24:47.295781+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('1fc94ad4-cc7d-4e9e-b48b-e76a410e4f09', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Other signage', 'other_signage', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', NULL, false, 14, '2026-09-25 14:24:47.297917+00', '2026-09-25 14:24:47.297917+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('e4dbb7fe-7130-4241-867e-e6c836b0818b', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Other sponsorship item', 'other_sponsorship', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', NULL, false, 15, '2026-09-25 14:24:47.300076+00', '2026-09-25 14:24:47.300076+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('244e9f96-5b3d-4359-9f67-93563af9c7df', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-25 14:24:47.094863+00', '2026-09-25 14:24:47.094863+00');
INSERT INTO public.locations VALUES ('a7446e61-2233-427a-97ca-da0a171adf50', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-25 14:24:47.098094+00', '2026-09-25 14:24:47.098094+00');
INSERT INTO public.locations VALUES ('1b80b2b6-ebd6-42e6-968b-67a2cccb2675', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-25 14:24:47.100815+00', '2026-09-25 14:24:47.100815+00');
INSERT INTO public.locations VALUES ('26812c98-534f-493c-8585-6b1bf2c61a31', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-25 14:24:47.103708+00', '2026-09-25 14:24:47.103708+00');
INSERT INTO public.locations VALUES ('fb787c95-3e8f-4b8f-8c36-e52c175b5456', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-25 14:24:47.106373+00', '2026-09-25 14:24:47.106373+00');
INSERT INTO public.locations VALUES ('86f98537-adc3-410b-8bc4-e930dfe85613', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-25 14:24:47.10892+00', '2026-09-25 14:24:47.10892+00');
INSERT INTO public.locations VALUES ('0d7cf24c-b65c-431a-bea9-73b23d7880ef', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-25 14:24:47.111764+00', '2026-09-25 14:24:47.111764+00');
INSERT INTO public.locations VALUES ('5fd06eb5-0057-4c05-8d48-46688d2f8e93', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-25 14:24:47.11395+00', '2026-09-25 14:24:47.11395+00');
INSERT INTO public.locations VALUES ('97e96685-7380-4e76-b834-0569987dba70', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-25 14:24:47.116036+00', '2026-09-25 14:24:47.116036+00');
INSERT INTO public.locations VALUES ('ee167359-15c8-404e-b146-8d88bb6aca5c', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-25 14:24:47.118371+00', '2026-09-25 14:24:47.118371+00');
INSERT INTO public.locations VALUES ('0d3946c9-8a3e-406c-9a40-40b239c9d635', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-25 14:24:47.121431+00', '2026-09-25 14:24:47.121431+00');
INSERT INTO public.locations VALUES ('05db9768-6140-4664-9a9e-a0c85c02a603', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-25 14:24:47.12466+00', '2026-09-25 14:24:47.12466+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('56a10d1d-4bda-40ab-8ea6-d1fa439c84fc', '00000000-0000-4000-8000-000000000001', 'e8081d8f-1886-42af-b834-d2307992fa84', 'admin', '2026-09-25 14:24:47.01282+00', '2026-09-25 14:24:47.01282+00', '{}');
INSERT INTO public.memberships VALUES ('60971e11-ff51-4b09-818e-046cd0c7ed67', '00000000-0000-4000-8000-000000000002', 'e8081d8f-1886-42af-b834-d2307992fa84', 'ops', '2026-09-25 14:24:47.017676+00', '2026-09-25 14:24:47.017676+00', '{}');
INSERT INTO public.memberships VALUES ('e7e56472-885b-4e2e-8d83-ab47a58d63be', '00000000-0000-4000-8000-000000000004', 'e8081d8f-1886-42af-b834-d2307992fa84', 'sales', '2026-09-25 14:24:47.025476+00', '2026-09-25 14:24:47.025476+00', '{}');
INSERT INTO public.memberships VALUES ('5622be9c-32ef-4536-891d-577c04f7fd45', '00000000-0000-4000-8000-000000000005', 'e8081d8f-1886-42af-b834-d2307992fa84', 'event_director', '2026-09-25 14:24:47.030176+00', '2026-09-25 14:24:47.030176+00', '{}');
INSERT INTO public.memberships VALUES ('6979d80a-9401-4010-b0cb-5f830dce3b6b', '00000000-0000-4000-8000-000000000006', 'e8081d8f-1886-42af-b834-d2307992fa84', 'viewer', '2026-09-25 14:24:47.034798+00', '2026-09-25 14:24:47.034798+00', '{}');
INSERT INTO public.memberships VALUES ('b3ecc667-bc1f-431a-b17b-4c871ad5cdf0', '00000000-0000-4000-8000-000000000003', 'e8081d8f-1886-42af-b834-d2307992fa84', 'marketing', '2026-09-25 14:24:47.021761+00', '2026-09-25 14:24:48.171929+00', '{"costs.edit": true}');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('e8081d8f-1886-42af-b834-d2307992fa84', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-25 14:24:47.004248+00', '2026-09-25 14:24:47.004248+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '08740f9f-5804-45bb-b0eb-543ee7047682', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '244e9f96-5b3d-4359-9f67-93563af9c7df', 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', '6ba3db22-bf86-480e-a833-ea45bb2bad6e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '60a51412-462f-44e4-bff0-1399a6a32c19', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.37431+00', '2026-09-25 14:24:47.38106+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('74d757ff-dda9-470d-96bb-d51498b25331', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', '0d42da43-188e-4042-b3ba-e5d8a4e56f4d', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'a7446e61-2233-427a-97ca-da0a171adf50', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '390aeef7-40b5-42e8-ae11-2717537ad27d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.405841+00', '2026-09-25 14:24:47.409955+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5ec53b63-0b6a-4d49-aee2-f19b4d7194cd', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', 'c6b3d593-84b8-478c-a37c-b9541b78fa5c', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '1b80b2b6-ebd6-42e6-968b-67a2cccb2675', 'ops', '00000000-0000-4000-8000-000000000002', '8d0ba254-e673-4406-aab8-f72afa0df47c', '0edc1c95-e6d3-4ecd-8e62-a65d2f8129dd', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '7e465a6f-3e02-410d-bfba-bc98f27dde9c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.4301+00', '2026-09-25 14:24:47.437774+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('4773a829-2ddd-4f1d-a68f-97f6d7fce94e', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', '8bc82607-5414-4eb4-9406-681dfabf3df1', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '26812c98-534f-493c-8585-6b1bf2c61a31', 'marketing', '00000000-0000-4000-8000-000000000003', 'bff0dc05-7cfc-445e-a322-0b4474602afa', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '624ab016-0594-4e15-b498-c151330d5ad5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.462468+00', '2026-09-25 14:24:47.470152+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('f0e4b4f1-b755-470b-ac80-4cb5c5d211f3', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '097aaa61-f412-44f3-bd8b-dff1a08cb552', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'fb787c95-3e8f-4b8f-8c36-e52c175b5456', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '455cab51-4ef0-4672-a355-115ea8734654', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.487046+00', '2026-09-25 14:24:47.491154+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b9ac5544-a3d5-4f9e-a65e-ba36de0a00f5', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '8e7acd61-1927-4d54-8904-7cc573a041a4', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '86f98537-adc3-410b-8bc4-e930dfe85613', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '76677e98-a1df-4889-b53f-6f1133445350', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.51209+00', '2026-09-25 14:24:47.517422+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "f95fe170-a978-4977-8370-6f8c4de58a41", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('63dfdb31-1e91-4661-ae45-30dc93060107', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', 'c6b3d593-84b8-478c-a37c-b9541b78fa5c', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '0d7cf24c-b65c-431a-bea9-73b23d7880ef', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '9d81f49c-a3a1-4569-981a-2d96058f46e5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.564042+00', '2026-09-25 14:24:47.568556+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('55338848-e3dd-482f-83e4-bc8d1576f12f', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', 'dc07d14f-0b4f-4944-8fa9-1f00725da31f', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '5fd06eb5-0057-4c05-8d48-46688d2f8e93', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '3bb522d6-5135-434f-a272-0794108d210d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.59367+00', '2026-09-25 14:24:47.598552+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('dc86850b-3426-4f35-b9e0-6a18ffc940cc', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', '8bc82607-5414-4eb4-9406-681dfabf3df1', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '97e96685-7380-4e76-b834-0569987dba70', 'marketing', '00000000-0000-4000-8000-000000000003', 'bff0dc05-7cfc-445e-a322-0b4474602afa', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '5b9b429b-e46a-45a6-8b04-95d859a91a9b', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.621612+00', '2026-09-25 14:24:47.627337+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('8edaf5e8-f7d3-4cb8-97e5-06bf673eb491', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', '0b3ad1b7-fa15-40f9-8b63-bf30890bf609', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'ee167359-15c8-404e-b146-8d88bb6aca5c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '47c3851e-c5b7-47d3-8585-f3bffb4ef7bc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.650458+00', '2026-09-25 14:24:47.655106+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4db924d6-c43c-43e4-928e-206997e7053b', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', 'cec8d13b-fb13-4541-9899-00ab9c8f301e', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '0d3946c9-8a3e-406c-9a40-40b239c9d635', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, 'd3383f5c-74fb-4d7b-8ff1-614bc5cf6309', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.674826+00', '2026-09-25 14:24:47.679353+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8201756c-108e-443e-9614-585e2828d2ab', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '05db9768-6140-4664-9a9e-a0c85c02a603', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '741c54c4-7156-4de8-988f-71776e325d87', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.698443+00', '2026-09-25 14:24:47.702976+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9fc7508d-a5be-4e6b-a3b4-98eb4437ad67', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '995c38d5-6207-4e7f-960b-993fe74ece70', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'a7446e61-2233-427a-97ca-da0a171adf50', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '6e723216-1a02-4b22-bf83-2f00f7b89d31', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '1708ab59-31d5-4496-94b8-8b35c74d34d7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.726018+00', '2026-09-25 14:24:47.732238+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "f95fe170-a978-4977-8370-6f8c4de58a41", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('862f9edd-5618-4cfe-9ea2-21f0908f1363', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', 'dc07d14f-0b4f-4944-8fa9-1f00725da31f', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '1b80b2b6-ebd6-42e6-968b-67a2cccb2675', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, 'cb62da5f-cd9c-411f-9e96-9c993d55e425', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.748872+00', '2026-09-25 14:24:47.752765+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('7162150a-b10d-496c-a4a6-cb06bcfe0504', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'fb787c95-3e8f-4b8f-8c36-e52c175b5456', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '7c864f68-52ae-4b6f-acd7-a77acedba933', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.768672+00', '2026-09-25 14:24:47.772935+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e2574f6d-dc00-4c77-85ab-c05b1c152412', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '8e7acd61-1927-4d54-8904-7cc573a041a4', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '86f98537-adc3-410b-8bc4-e930dfe85613', 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, 'e62d99c7-8413-40bf-bedd-1a1eeff59485', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.79278+00', '2026-09-25 14:24:47.796353+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('0f09cdb4-2da1-44c2-a252-dac972a562a2', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', 'c6b3d593-84b8-478c-a37c-b9541b78fa5c', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '5fd06eb5-0057-4c05-8d48-46688d2f8e93', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '1ae4dea3-9693-4458-960c-07d6514cb69f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.814964+00', '2026-09-25 14:24:47.826558+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('8d7d39f4-160d-405f-875f-2c186f0ee680', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', '0b3ad1b7-fa15-40f9-8b63-bf30890bf609', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', 'ee167359-15c8-404e-b146-8d88bb6aca5c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '365972f5-e7f9-4e00-b9a8-975e816829c3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.843774+00', '2026-09-25 14:24:47.847556+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('36c29871-c8e9-483f-84a8-ed607e71418e', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', 'c6b3d593-84b8-478c-a37c-b9541b78fa5c', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '1b80b2b6-ebd6-42e6-968b-67a2cccb2675', 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', '0edc1c95-e6d3-4ecd-8e62-a65d2f8129dd', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '974473b6-155b-4957-b325-5f045caf7b31', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.865354+00', '2026-09-25 14:24:47.87174+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('8a4b4285-420e-453b-9911-1b6ab204aaf2', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '05db9768-6140-4664-9a9e-a0c85c02a603', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.895828+00', '2026-09-25 14:24:47.895828+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('be117c1d-a8f1-4285-af27-b686f9501b9f', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'a7446e61-2233-427a-97ca-da0a171adf50', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.900563+00', '2026-09-25 14:24:47.900563+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('10173480-6615-4412-9889-2a38e8864509', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', '0d42da43-188e-4042-b3ba-e5d8a4e56f4d', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '0d7cf24c-b65c-431a-bea9-73b23d7880ef', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.905563+00', '2026-09-25 14:24:47.905563+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('bc88e2f4-2aaa-4c1a-ba7e-ce2227366aca', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '995c38d5-6207-4e7f-960b-993fe74ece70', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '86f98537-adc3-410b-8bc4-e930dfe85613', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '6e723216-1a02-4b22-bf83-2f00f7b89d31', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.910825+00', '2026-09-25 14:24:47.910825+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "f95fe170-a978-4977-8370-6f8c4de58a41", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('42adbdaa-bf68-41d9-b6c2-0e137aafbb74', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '097aaa61-f412-44f3-bd8b-dff1a08cb552', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '97e96685-7380-4e76-b834-0569987dba70', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.915235+00', '2026-09-25 14:24:47.915235+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('aef84a97-a5a5-4a29-bba4-2640a61d4aac', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', '8bc82607-5414-4eb4-9406-681dfabf3df1', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '97e96685-7380-4e76-b834-0569987dba70', 'marketing', '00000000-0000-4000-8000-000000000003', 'bff0dc05-7cfc-445e-a322-0b4474602afa', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.921045+00', '2026-09-25 14:24:47.921045+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('3ddc22e6-2121-4992-8824-f5f8a81cb5d3', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', 'cec8d13b-fb13-4541-9899-00ab9c8f301e', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '0d3946c9-8a3e-406c-9a40-40b239c9d635', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.926122+00', '2026-09-25 14:24:47.926122+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "f95fe170-a978-4977-8370-6f8c4de58a41", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('0a55da9d-fb5e-4807-b4b0-6db3d8d9f13a', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '0d3946c9-8a3e-406c-9a40-40b239c9d635', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.930261+00', '2026-09-25 14:24:47.930261+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('5cb805b2-96e3-459f-9bb2-bb56ac1bbeb7', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', 'fb787c95-3e8f-4b8f-8c36-e52c175b5456', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '9cac6840-edc5-40fc-91fc-b3edf1c00684', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.934215+00', '2026-09-25 14:24:47.938325+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('9ffa2807-fb75-480a-86fd-27b2ee9a3224', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '08740f9f-5804-45bb-b0eb-543ee7047682', '8cb3eb8f-9235-480f-bf71-bc54da0d92ee', '244e9f96-5b3d-4359-9f67-93563af9c7df', 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', '6ba3db22-bf86-480e-a833-ea45bb2bad6e', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '75ac3ab4-6ff9-4a39-a0fd-83678894f8f7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.957291+00', '2026-09-25 14:24:47.961283+00', 'signage', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', NULL, NULL, NULL, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('8da666e6-4011-4950-ab4d-eecf55ca8724', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', 'd3628e05-ca26-42f7-a963-a62efd37148d', '7993f40f-2fd4-4c84-85c5-844fe0479e6b', '05db9768-6140-4664-9a9e-a0c85c02a603', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.982223+00', '2026-09-25 14:24:47.982223+00', 'signage', 'organiser', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('11dd69c3-7142-4670-be01-6d12963e59ac', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', '40f28ef7-21ad-4b5e-b499-82a10e5ffb87', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, '1bea46f2-2548-4578-acc8-e596d6497244', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:47.986908+00', '2026-09-25 14:24:47.993557+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', '2026-12-09', NULL, 9000.00, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('eb066104-2418-4964-b398-f3fbf93225c5', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '0ec1605f-e4f2-449d-b59f-69eedacc9cd9', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '8d0ba254-e673-4406-aab8-f72afa0df47c', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:48.016175+00', '2026-09-25 14:24:48.016175+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}, {"stepId": "5cfbfaeb-5d05-4517-a7ee-c2618dfd8475", "userId": null}]', '2026-10-15', NULL, 12500.00, '2026-09-15 14:24:46.968+00');
INSERT INTO public.signage_items VALUES ('f7ff77cd-82c0-4c95-b145-53f2241a440b', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', 'b9625214-4e3a-44c3-ac83-1cd677fb233a', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:48.020005+00', '2026-09-25 14:24:48.020005+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', '2027-01-23', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1da6cf7e-ef85-4731-bc4b-e10fd66749e4', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', 'e4dbb7fe-7130-4241-867e-e6c836b0818b', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-25 14:24:48.024516+00', '2026-09-25 14:24:48.024516+00', 'sponsorship_item', 'sponsor', '[{"stepId": "3d9c7dc9-907e-491a-aacf-159d9dfec648", "userId": null}, {"stepId": "9ccacdf1-ff30-4050-9bef-617b808d1cbd", "userId": null}]', '2026-10-13', NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('e09ac083-ade4-4d55-a715-65aa8b645097', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '7162150a-b10d-496c-a4a6-cb06bcfe0504', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '3f442670-a6c6-41ca-9627-100326afd637', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-25 14:24:47.78775+00', '2026-09-25 14:24:47.78775+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('0edc1c95-e6d3-4ecd-8e62-a65d2f8129dd', '8d0ba254-e673-4406-aab8-f72afa0df47c', 'Logo on 6 hanging banners', 6, '2026-09-25 14:24:47.172343+00', '2026-09-25 14:24:47.172343+00');
INSERT INTO public.sponsor_entitlements VALUES ('6ba3db22-bf86-480e-a833-ea45bb2bad6e', '8d0ba254-e673-4406-aab8-f72afa0df47c', 'Entrance feature branding', 1, '2026-09-25 14:24:47.175034+00', '2026-09-25 14:24:47.175034+00');
INSERT INTO public.sponsor_entitlements VALUES ('d05f0e79-52bc-4bbe-a1f1-1c78d162fc51', 'bff0dc05-7cfc-445e-a322-0b4474602afa', 'Seminar theatre branding', 1, '2026-09-25 14:24:47.179606+00', '2026-09-25 14:24:47.179606+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('8d0ba254-e673-4406-aab8-f72afa0df47c', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-25 14:24:47.16852+00', '2026-09-25 14:24:47.16852+00');
INSERT INTO public.sponsors VALUES ('bff0dc05-7cfc-445e-a322-0b4474602afa', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-25 14:24:47.177398+00', '2026-09-25 14:24:47.177398+00');


--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('93e2a4da-2f99-4d00-80e9-501572508ade', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '1ac2ff18-4bdf-40d5-9e99-bbb886c4c81f', 'STD-BIRM27-A10', '399664d6-0d81-4190-aaa6-843fe7abceb0', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 14:24:46.968+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.035871+00', '2026-09-25 14:24:48.035871+00');
INSERT INTO public.stand_submissions VALUES ('6362ac48-990a-4ee8-b2d0-179276deb0b6', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'bdf5cdee-2015-486d-a855-afda0476b9cd', 'STD-BIRM27-A20', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-19 14:24:46.968+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.059252+00', '2026-09-25 14:24:48.059252+00');
INSERT INTO public.stand_submissions VALUES ('b9835fa8-4fa3-4b0c-a73c-501a72c97d1b', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'd43a05a6-38b7-45fa-8a47-b4f59a56ee91', 'STD-BIRM27-A30', '399664d6-0d81-4190-aaa6-843fe7abceb0', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-19 14:24:46.968+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.081166+00', '2026-09-25 14:24:48.081166+00');
INSERT INTO public.stand_submissions VALUES ('7e062199-f333-4bec-b2b2-16f8929df51c', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '0258e6af-588d-44c4-9c8f-13b85a0238ce', 'STD-BIRM27-B10', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-19 14:24:46.968+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.100099+00', '2026-09-25 14:24:48.100099+00');
INSERT INTO public.stand_submissions VALUES ('c26d60c0-126a-45c3-a10b-89bebab1f8b1', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '98d7ae36-c07d-4ae6-852b-0a64fd10c36d', 'STD-BIRM27-B20', '399664d6-0d81-4190-aaa6-843fe7abceb0', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-19 14:24:46.968+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 1, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.124962+00', '2026-09-25 14:24:48.124962+00');
INSERT INTO public.stand_submissions VALUES ('f0c9d6af-c567-4c7f-b0b9-6ad11371dda5', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'ed462519-fca1-4882-9e3b-27ccd33337d2', 'STD-BIRM27-B30', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.152302+00', '2026-09-25 14:24:48.152302+00');
INSERT INTO public.stand_submissions VALUES ('2ffdf996-76ac-4e47-95a2-c3fd6ce743e9', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '19beedf5-ccff-46f4-a50e-f10e7c0542a6', 'STD-BIRM27-C10', '399664d6-0d81-4190-aaa6-843fe7abceb0', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.159295+00', '2026-09-25 14:24:48.159295+00');
INSERT INTO public.stand_submissions VALUES ('c6e1d664-f58b-4f4c-9f55-07320c9829ac', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', '0e21fc91-1bdf-4548-965e-a2f4d41d0ade', 'STD-BIRM27-C20', 'bd521445-f497-4e90-b0dd-4f62bbe5b16a', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '67cd5377-7788-4572-978f-a49d411ddded', 0, '00000000-0000-4000-8000-000000000002', '2026-09-25 14:24:48.165357+00', '2026-09-25 14:24:48.165357+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('3f442670-a6c6-41ca-9627-100326afd637', '0575ca31-fa78-445b-aa3f-4f94f7c0cc35');
INSERT INTO public.supplier_service_links VALUES ('3f442670-a6c6-41ca-9627-100326afd637', '41635ec0-b2e7-4682-888c-3eda1e17ba26');
INSERT INTO public.supplier_service_links VALUES ('0bf3640d-3e05-4bb7-bc82-365633c58659', '7270a10e-f34f-4e0c-851b-769ebac65649');
INSERT INTO public.supplier_service_links VALUES ('0bf3640d-3e05-4bb7-bc82-365633c58659', '41635ec0-b2e7-4682-888c-3eda1e17ba26');
INSERT INTO public.supplier_service_links VALUES ('0bf3640d-3e05-4bb7-bc82-365633c58659', '6fb89009-7e3d-4160-aae5-c0541874a8f3');
INSERT INTO public.supplier_service_links VALUES ('6e723216-1a02-4b22-bf83-2f00f7b89d31', '50ff8638-68c8-4251-b393-71d61945d0d8');
INSERT INTO public.supplier_service_links VALUES ('6e723216-1a02-4b22-bf83-2f00f7b89d31', '6fb89009-7e3d-4160-aae5-c0541874a8f3');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('0575ca31-fa78-445b-aa3f-4f94f7c0cc35', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Signage print', 1, false, '2026-09-25 14:24:47.138167+00', '2026-09-25 14:24:47.138167+00');
INSERT INTO public.supplier_services VALUES ('50ff8638-68c8-4251-b393-71d61945d0d8', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Digital screens & AV', 2, false, '2026-09-25 14:24:47.140534+00', '2026-09-25 14:24:47.140534+00');
INSERT INTO public.supplier_services VALUES ('7270a10e-f34f-4e0c-851b-769ebac65649', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Rigging', 3, false, '2026-09-25 14:24:47.142286+00', '2026-09-25 14:24:47.142286+00');
INSERT INTO public.supplier_services VALUES ('41635ec0-b2e7-4682-888c-3eda1e17ba26', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Installation', 4, false, '2026-09-25 14:24:47.14375+00', '2026-09-25 14:24:47.14375+00');
INSERT INTO public.supplier_services VALUES ('6fb89009-7e3d-4160-aae5-c0541874a8f3', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Staffing', 5, false, '2026-09-25 14:24:47.145137+00', '2026-09-25 14:24:47.145137+00');
INSERT INTO public.supplier_services VALUES ('609a0265-c543-4b0e-8eac-bf812e8cf61d', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Furniture', 6, false, '2026-09-25 14:24:47.147134+00', '2026-09-25 14:24:47.147134+00');
INSERT INTO public.supplier_services VALUES ('f3e01585-9962-45cf-826e-460c65026e72', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Structural engineering', 7, false, '2026-09-25 14:24:47.148592+00', '2026-09-25 14:24:47.148592+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('3f442670-a6c6-41ca-9627-100326afd637', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-25 14:24:47.127756+00', '2026-09-25 14:24:47.127756+00');
INSERT INTO public.suppliers VALUES ('0bf3640d-3e05-4bb7-bc82-365633c58659', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-25 14:24:47.131325+00', '2026-09-25 14:24:47.131325+00');
INSERT INTO public.suppliers VALUES ('6e723216-1a02-4b22-bf83-2f00f7b89d31', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-25 14:24:47.135021+00', '2026-09-25 14:24:47.135021+00');


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('f83adb40-55c5-4807-8df4-12c98484b2cf', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-02', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '1adb31b2-5fda-4e84-8bca-da1c0ecbf32b', NULL, '2026-09-25 14:24:48.178142+00', '2026-09-25 14:24:48.178142+00', NULL);
INSERT INTO public.tasks VALUES ('854fc1e7-a286-4713-8713-02d6010c0232', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-05', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-25 14:24:48.181104+00', '2026-09-25 14:24:48.181104+00', NULL);
INSERT INTO public.tasks VALUES ('7abbfef9-b28d-457f-b19a-72e37dd9543a', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Walk the hall with the venue', NULL, 'done', '2026-09-20', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-09-25 14:24:46.968+00', '2026-09-25 14:24:48.183763+00', '2026-09-25 14:24:48.183763+00', '854fc1e7-a286-4713-8713-02d6010c0232');
INSERT INTO public.tasks VALUES ('a939cc11-5e96-4e1b-99ca-179a8892e3f3', 'e8081d8f-1886-42af-b834-d2307992fa84', 'fc96b280-f7bc-4dc1-8fe5-c830ea15a46f', 'Send sign positions to the printer', NULL, 'open', '2026-09-24', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-09-25 14:24:48.183763+00', '2026-09-25 14:24:48.183763+00', '854fc1e7-a286-4713-8713-02d6010c0232');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.0093+00', '2026-09-25 14:24:47.0093+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.015898+00', '2026-09-25 14:24:47.015898+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.01953+00', '2026-09-25 14:24:47.01953+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.023518+00', '2026-09-25 14:24:47.023518+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.028131+00', '2026-09-25 14:24:47.028131+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-25 14:24:47.032388+00', '2026-09-25 14:24:47.032388+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.302382+00', '2026-09-25 14:24:47.302382+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.311858+00', '2026-09-25 14:24:47.311858+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.317464+00', '2026-09-25 14:24:47.317464+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.32266+00', '2026-09-25 14:24:47.32266+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.327541+00', '2026-09-25 14:24:47.327541+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-25 14:24:47.36631+00', '2026-09-25 14:24:47.36631+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('60e794a0-9805-4e69-9549-1480f0c925d5', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-25 14:24:47.047886+00', '2026-09-25 14:24:47.047886+00');
INSERT INTO public.venue_rules VALUES ('eae39fb7-b81e-4bdf-aedb-b49eb9073223', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-25 14:24:47.051304+00', '2026-09-25 14:24:47.051304+00');
INSERT INTO public.venue_rules VALUES ('85059d17-1b38-4f3c-b4c6-2200ed206458', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-25 14:24:47.054536+00', '2026-09-25 14:24:47.054536+00');
INSERT INTO public.venue_rules VALUES ('e774c822-1e69-4dd8-ae02-a5540bc7fdc2', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-25 14:24:47.057889+00', '2026-09-25 14:24:47.057889+00');
INSERT INTO public.venue_rules VALUES ('cf3500d9-e5e8-4d64-9ae1-1a27b16a1ef3', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-25 14:24:47.061312+00', '2026-09-25 14:24:47.061312+00');
INSERT INTO public.venue_rules VALUES ('93676d54-30cf-4c7d-96ce-653ab08526c3', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-25 14:24:47.064232+00', '2026-09-25 14:24:47.064232+00');
INSERT INTO public.venue_rules VALUES ('67f69e18-e706-46f5-a647-e7d27e41c229', '4de90ffd-2dc3-4000-b3e5-503173a40817', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-25 14:24:47.066674+00', '2026-09-25 14:24:47.066674+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('4de90ffd-2dc3-4000-b3e5-503173a40817', 'e8081d8f-1886-42af-b834-d2307992fa84', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-25 14:24:47.039735+00', '2026-09-25 14:24:47.039735+00');
INSERT INTO public.venues VALUES ('61e24e28-8920-4407-b9b6-408f0b7bbaa7', 'e8081d8f-1886-42af-b834-d2307992fa84', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-25 14:24:47.04237+00', '2026-09-25 14:24:47.04237+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('c8c5f213-7f33-484f-a241-667bd5a2d19d', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-25 14:24:47.191175+00', '2026-09-25 14:24:47.191175+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('817da419-b4ab-4739-a63d-8601ab706d8b', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-25 14:24:47.194433+00', '2026-09-25 14:24:47.194433+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('320c012d-30af-4ec1-9b71-c840e4ba959d', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-25 14:24:47.196474+00', '2026-09-25 14:24:47.196474+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('71426f9a-130e-4b16-80eb-6fa0493236e9', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 14:24:47.198326+00', '2026-09-25 14:24:47.198326+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('3d9c7dc9-907e-491a-aacf-159d9dfec648', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 14:24:47.184916+00', '2026-09-25 14:24:47.238428+00', '{organiser,sponsor}', false, '141db612-17a9-480c-a4c2-ff309760818c');
INSERT INTO public.workflow_steps VALUES ('9ccacdf1-ff30-4050-9bef-617b808d1cbd', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-09-25 14:24:47.187299+00', '2026-09-25 14:24:47.240154+00', '{organiser,sponsor}', false, 'b7e20ffa-82c7-42bb-8b7d-488e5fb0a762');
INSERT INTO public.workflow_steps VALUES ('5cfbfaeb-5d05-4517-a7ee-c2618dfd8475', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-09-25 14:24:47.189099+00', '2026-09-25 14:24:47.24171+00', '{sponsor}', false, '8dbd062d-07da-403a-86dd-de93adc87639');
INSERT INTO public.workflow_steps VALUES ('f95fe170-a978-4977-8370-6f8c4de58a41', 'ae9cfa87-3292-498c-8942-40f5a9aa8001', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-09-25 14:24:47.192668+00', '2026-09-25 14:24:47.243116+00', '{organiser,sponsor}', false, 'cb934c07-8f3a-4663-8e1f-4e44e4038cb0');
INSERT INTO public.workflow_steps VALUES ('1e5c6e55-de44-4439-8e04-3c0c958d1053', '67cd5377-7788-4572-978f-a49d411ddded', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-25 14:24:47.251033+00', '2026-09-25 14:24:47.251033+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('8bea74a2-f696-44bf-96bb-6494b05c8429', '67cd5377-7788-4572-978f-a49d411ddded', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-25 14:24:47.253046+00', '2026-09-25 14:24:47.253046+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('d9c195b4-70c5-411e-9578-9e3b5797bc86', '67cd5377-7788-4572-978f-a49d411ddded', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-25 14:24:47.255253+00', '2026-09-25 14:24:47.255253+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('e0ae8bed-9603-4e5a-89fd-214fac9abe70', '67cd5377-7788-4572-978f-a49d411ddded', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-25 14:24:47.256826+00', '2026-09-25 14:24:47.256826+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('f14f6f13-72c0-4548-8676-18bc6f2f73c8', '67cd5377-7788-4572-978f-a49d411ddded', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-25 14:24:47.258442+00', '2026-09-25 14:24:47.258442+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('34ea6fc2-2232-4f55-a768-a9a913a56232', '67cd5377-7788-4572-978f-a49d411ddded', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-25 14:24:47.260538+00', '2026-09-25 14:24:47.260538+00', '{}', false, NULL);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('ae9cfa87-3292-498c-8942-40f5a9aa8001', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Signage default', 'signage', true, false, '2026-09-25 14:24:47.182682+00', '2026-09-25 14:24:47.182682+00');
INSERT INTO public.workflows VALUES ('67cd5377-7788-4572-978f-a49d411ddded', 'e8081d8f-1886-42af-b834-d2307992fa84', 'Stand default', 'stand', true, false, '2026-09-25 14:24:47.249342+00', '2026-09-25 14:24:47.249342+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 8, true);


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

\unrestrict OWdcSdCZ4c4aj46Gz6sXXbLaoJ3XbqXKlFEyhDnwPoHa4GFfmHgPpUOJWjDO7qy

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
