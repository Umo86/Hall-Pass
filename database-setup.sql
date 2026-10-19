-- ---------------------------------------------------------------------------
-- Hall Pass database setup. Runs on any plain Postgres: paste it into the
-- SQL editor of Vercel Postgres/Neon (or Supabase), or run it with psql.
-- Creates the full schema (with row-level security and the append-only
-- audit trigger) and loads the UKCW Birmingham 2027 demo data.
-- RE-RUNNABLE: this preamble removes everything the script creates, so it is
-- safe to run again after a partial or failed earlier attempt. It only drops
-- Hall Pass objects (and the drizzle bookkeeping schema) — nothing else.
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP TABLE IF EXISTS public.users, public.external_grants, public.organisations, public.memberships, public.editions, public.edition_counters, public.edition_deadlines, public.events, public.venues, public.venue_rules, public.halls, public.locations, public.contractors, public.exhibitors, public.sponsors, public.suppliers, public.workflow_steps, public.workflows, public.artwork_annotations, public.item_types, public.documents, public.change_requests, public.comments, public.comment_attachments, public.exports, public.notifications, public.snags, public.signage_items, public.stand_submissions, public.artwork_versions, public.sponsor_entitlements, public.audit_log, public.email_log, public.reminder_log, public.approval_instances, public.tasks, public.staff_invites, public.supplier_services, public.supplier_service_links, public.departments, public.approvers, public.task_attachments, public.sponsorship_packages, public.sponsorship_package_lines CASCADE;
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

\restrict mfu4AgospXzdHsGjR4qPrKJuw4yhKDFwfvrmfCanLP92LgepBBaCJzVMVGdUv0Q

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    main_on_accept boolean DEFAULT false NOT NULL,
    main_on_accept_by uuid,
    CONSTRAINT approvers_main_on_accept_invite_only CHECK (((NOT main_on_accept) OR ((user_id IS NULL) AND (NOT is_main))))
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
    edition_ids uuid[],
    CONSTRAINT memberships_edition_ids_not_admin CHECK (((role <> 'admin'::public.staff_role) OR (edition_ids IS NULL))),
    CONSTRAINT memberships_edition_ids_not_empty CHECK (((edition_ids IS NULL) OR (cardinality(edition_ids) > 0))),
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    edition_id uuid
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
    from_package_id uuid,
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    package_id uuid,
    package_price numeric(12,2),
    package_price_note text,
    package_sold_at timestamp with time zone,
    CONSTRAINT sponsors_package_price_not_negative CHECK (((package_price IS NULL) OR (package_price >= (0)::numeric))),
    CONSTRAINT sponsors_package_sale_fields CHECK (((package_id IS NOT NULL) OR ((package_price IS NULL) AND (package_price_note IS NULL) AND (package_sold_at IS NULL))))
);


--
-- Name: sponsorship_package_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsorship_package_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    package_id uuid NOT NULL,
    description text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sponsorship_package_lines_quantity_positive CHECK ((quantity >= 1))
);


--
-- Name: sponsorship_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsorship_packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    edition_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    price numeric(12,2),
    places integer,
    sort_order integer DEFAULT 0 NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sponsorship_packages_places_positive CHECK (((places IS NULL) OR (places >= 1))),
    CONSTRAINT sponsorship_packages_price_not_negative CHECK (((price IS NULL) OR (price >= (0)::numeric)))
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
    access_ends_at timestamp with time zone,
    edition_ids uuid[],
    CONSTRAINT staff_invites_edition_ids_not_admin CHECK (((role <> 'admin'::public.staff_role) OR (edition_ids IS NULL))),
    CONSTRAINT staff_invites_edition_ids_not_empty CHECK (((edition_ids IS NULL) OR (cardinality(edition_ids) > 0)))
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
INSERT INTO drizzle.__drizzle_migrations VALUES (13, '119f9a08459f5a2d69f20cb46982997d50602c0914fed930a8b83e691c9a33b6', 1792174730034);
INSERT INTO drizzle.__drizzle_migrations VALUES (14, 'c95d7f3af4f4cddf20ec23d476b5f981c82ce7173070e8aa8de595f4cc7bd6fa', 1792400722931);


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('336a7a82-e291-4823-ac8a-ed49eb76062f', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('ae350a9e-edd7-4b19-b2da-13743b1d0dbb', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('1205849d-d1af-413c-a95f-33d7013a6829', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('5d1d4cac-ad0e-4b64-9a0d-a859efccd279', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f7738fa1-a038-4093-9b7a-d0c3892e31e0', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('96cd11ec-ceef-46d7-a4f0-2925769921a7', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f47e5870-1783-4614-89f5-d3dd0582ea2e', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('23a0b259-2e72-45b9-8afc-b8bbf774a644', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.410808+00', '2026-10-19 09:06:27.410808+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('24efbe37-8342-479e-8cfa-4a3eed8f0d85', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('b573ab1c-7c9e-4b47-8d1c-a5f976a41808', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('4dd847b3-6c4f-41b0-900e-64eefb99b985', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('f212adea-7cc3-4f68-bfa3-cc568dec3ef5', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e300e6c4-1b75-4296-8d04-5c87f3ba92fa', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('163847ca-fe23-45ae-b343-13414e75fd8e', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7fea2f33-31fa-4c09-8f89-b9846390a520', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('fee39df2-a680-4650-8592-d6c5e8ed0ba1', 'signage_item', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.436897+00', '2026-10-19 09:06:27.436897+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('86b77cbb-d8a8-4d5f-bdd8-db21070d3b48', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-07 09:06:26.855+00', '2026-10-15 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('c697f42e-f9d8-4a3f-bd93-b066276478ea', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-09 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 09:06:26.855+00', '2026-10-10 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('7b1c348b-38be-4916-886e-d1484a484fd1', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-09 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 09:06:26.855+00', '2026-10-12 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('cb7e9729-dca3-4cd0-b30f-dd4732ef4f31', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('70113bc1-e6a3-4508-8150-7cbe9ad42a00', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('682f84fa-6538-4c35-a37f-83037521b0ad', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('228f30d4-898a-4d7b-9ee9-f7da47f7a18e', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c2093465-2793-4d6f-9ced-151d1ac8e1e9', 'signage_item', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.482163+00', '2026-10-19 09:06:27.482163+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2520036f-122d-44e7-8062-973c9cc286f7', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('3fd84b22-ed93-48c7-a34e-e4f721bdab8d', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('d78bef8e-fbb2-4a05-ba63-965066501d90', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('a04d5fa7-c06b-4e5f-9881-6472e6964cc9', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b64fd0d8-a7c1-4ea1-9b67-3a0b805bf2c1', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('133f51e6-56a9-4323-a3dc-52f46ebb39be', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f51829e9-ed5b-4404-8623-75b77f8aa4f1', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('25c95de3-8d2f-4a8b-9bae-406cbb7f1dde', 'signage_item', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.529961+00', '2026-10-19 09:06:27.529961+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('626d9c68-d506-43c0-a84f-68171c1cb193', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('f385fc88-7b23-422c-92e5-f6071b8d92b3', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('a9f0565c-32b8-4069-951d-a6a083b9a1d6', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('b164ed59-e2d6-4ea2-9450-78f033b5ce52', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a88bd10-d582-4e9b-9fd9-4df4036384e5', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('c9931306-ab8f-48c5-984d-a52f2d53582f', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('29fc8198-4986-4c76-b0f6-1d50f91d94f4', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8f7d2fa-08b5-4fc6-99f5-a715fb7b1ec5', 'signage_item', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.565703+00', '2026-10-19 09:06:27.565703+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e9a5b5e3-21c8-4217-84da-c49dbefdcb20', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-09 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 09:06:26.855+00', '2026-10-10 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('c8d1a1bc-b609-4e0e-8769-00f6c01de8b6', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-09 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-07 09:06:26.855+00', '2026-10-10 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('7d34a07c-70ab-492b-9f08-73a6ff1abfb1', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('e15dde4e-fdc0-4ed5-9719-e1c8c599ea79', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('bcc0939b-6019-4024-a54c-45fb19f0fba8', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'pending', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', '2026-10-15 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('7a2b314b-798d-4f36-a5c3-daf4fa529bd7', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('74e53bf8-fee7-4622-91e9-a2c3595b0b57', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f0c605b7-d6ca-4816-b701-77ff365f1cbc', 'signage_item', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.601013+00', '2026-10-19 09:06:27.601013+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4722daf3-73c8-47ac-b26c-57bf667acbbc', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('1e6edbef-c438-46cc-8ea7-bb4008a8aec6', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('9fad1b4b-5877-4ed4-97f2-6317f290cb58', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('9b3147a8-0fe9-4a8c-988e-e190ae5655d7', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f36d9453-5c51-4ffc-b5c3-0c06abb8ab7c', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('00efb124-85b0-4056-b7a5-92306e5f6db7', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9c80dab3-26da-4497-a84a-8a4351ae50fb', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2a81a667-2d60-43d2-8286-715ba0eb30ed', 'signage_item', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.621132+00', '2026-10-19 09:06:27.621132+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3c0489b8-baf0-43bf-9f73-70b92d8dded5', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('5404279d-9174-41d8-839b-26e581309366', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('4e4431a8-07a1-4051-84b0-dc5fa106c1ce', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('15455ead-dead-4f52-bf42-ef5524b88a72', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b31f1e84-911d-4139-b0bf-2f6e997c793e', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('10720eb9-14fc-4e97-82fd-fa02a5067a4d', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7bdcfeac-b3f8-4147-8ea4-0553735eea5d', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('080551a8-3e11-4b8a-abda-cf1c19b61901', 'signage_item', '98be7515-3586-4f76-a1d7-a590058870eb', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.651507+00', '2026-10-19 09:06:27.651507+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('af6ad386-7211-418a-955d-4a52181f83af', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('68e16a9b-9a63-427e-b6ca-f2e5beb8ed8a', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('7fb7218e-1845-4ecf-b19c-0dedd7cef69d', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'approved_with_conditions', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 09:06:26.855+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('be991532-2eae-4099-a67b-32a68e0a2cdb', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8711ed9-5ece-4324-ba19-d96cdeb0e650', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('e7841228-6de7-4e5d-b098-933ca7cf0522', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7514a01b-7e66-453f-ba50-bc32aaf13ef2', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d8317c1f-909d-4af8-b6cf-33d993143189', 'signage_item', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.674009+00', '2026-10-19 09:06:27.674009+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('498c6e39-12f5-40af-a439-fb4cf42b734d', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('c922d714-8abe-4810-bb76-affc9201fe1a', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('ee58b69e-0e31-4398-ac61-1564ffadce04', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('b66df3b3-db8f-4cbc-9e81-68d62641ba78', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e0a88615-7b15-44c3-b3bb-ffed6583c78e', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('789c438d-8a49-45ad-b583-5bffd1a7a82f', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('db38a796-33a4-43ae-9d3f-ecf9584deea0', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3d855f21-2400-4bd9-bdad-beca2613158f', 'signage_item', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.693182+00', '2026-10-19 09:06:27.693182+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('16f7c145-2cf8-4b1f-8cda-eae3d83b7d45', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('a466235b-0320-4414-9342-1eda51d77603', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('5fc0b200-952b-4607-aff2-7490b5dd327a', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('ca8caef1-bdbc-4252-9700-3bc4b6d6fa66', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a3bbca08-6783-499e-b92c-9412b08b26b5', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('266a9bf9-5e3c-424e-9ad9-580dad6c7f6a', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('7e08072d-162c-48ff-8fa5-6fcca84c8c96', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f21391bf-1a71-415f-9c9d-c0b57cd06190', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('e528b8b4-0c73-463e-be71-7153cbc2c72f', 'signage_item', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.711779+00', '2026-10-19 09:06:27.711779+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('902b4952-f351-48b6-9b3c-2f7ef0e45b08', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('ec6738f2-784f-4591-a385-f760c8c43d80', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('01be3486-c64a-42c4-9cc0-eabc642986de', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('82c045b7-35cb-46db-a371-fb6117ee09e7', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('67724aec-89c9-4ef0-ab9b-2781c9bb68f4', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('11c34546-c094-4855-a875-9f78319d8cce', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4c6efa7e-40bb-483b-a6eb-1fa381004f9e', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5327f6bb-4991-495b-9ff2-64fce4869de2', 'signage_item', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.736247+00', '2026-10-19 09:06:27.736247+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('5a9395a3-4554-48d9-bb4c-ee45ca9c263d', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('c6d87497-7abc-483a-94c5-b9a5f8756308', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('6542f465-7080-4871-8d60-d75f949608ad', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('3e2bd2a8-47ea-4572-982c-b536feb62f91', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('cecd0912-0189-4ba3-b4d2-437739f020eb', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'approved', NULL, '00000000-0000-4000-8000-000000000005', NULL, '00000000-0000-4000-8000-000000000005', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('76b4d1c9-1d45-4c5b-b72a-3db024d354a7', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('169c5f3d-a293-4232-a0f1-90296fa8c6b7', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('214bf99d-40f7-4378-b20f-133c9c7e3aec', 'signage_item', 'b424149b-312e-4f74-ae8d-de2527232516', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.756854+00', '2026-10-19 09:06:27.756854+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('85737e1c-3a85-428f-bcfd-1c3a8a28dec6', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('9b3f57b6-24dc-4894-963a-d09f7a34d9f5', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('d936f00b-8655-471b-9e0e-2e2e5673acc0', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('6876d317-1434-4613-b5fc-1e300b0d7957', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6581049a-d953-4ca3-9aaf-cc57a86b901c', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('1c3637d6-08d1-4765-87fd-e922a9b17941', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6f0f9757-7c1b-4eb7-8e91-e09e4d14229d', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b9702f4e-8e71-4ddb-abb1-5b4424188b2d', 'signage_item', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.781809+00', '2026-10-19 09:06:27.781809+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a0a08c4e-a891-42e1-9adb-c7d57fe57e35', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('eeab4bfe-d02a-424c-942f-c432fc9fe5eb', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('1097bacb-7ff5-4d53-831d-a1cc2e557e48', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('f03b68b9-984d-4b92-bd18-d068117d747e', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2093f9c4-7dd3-4fc0-8ef1-aa1d89afa68c', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('fc5c8ec5-d4be-4d8f-b6dc-478ed2594760', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4b864b54-ac56-4f1a-85d6-adfbff8135c0', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dfeb5df6-3b0d-4564-bbfa-19b61d67373b', 'signage_item', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.807122+00', '2026-10-19 09:06:27.807122+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('2bf8bb07-56ee-450c-bdbd-95812513d400', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('08f79c6e-ef10-42c3-8e5f-3cd4604b3301', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('1e34b66a-7dd8-4376-9620-c726e3accdd6', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('9a90b4df-1c3f-4553-b186-0d6bf1272db2', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4248cc30-3627-4cf0-8ba0-4dbc86935851', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('f1fc9a68-704f-49cd-b338-d063bd253226', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f77e579d-72bc-4eca-ab91-049a3df5ad13', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a58f5dc6-668a-4bd3-b785-1b43ade7a075', 'signage_item', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:27.835747+00', '2026-10-19 09:06:27.835747+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6c3d1b06-e9d7-482a-be68-025d1e75bcd1', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('24f1817e-bd7c-486a-a2d5-b1d54e0665bc', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'rejected', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('fd17845c-fa7c-4892-8f73-e4307407e948', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('e2b7669c-107e-4114-95a6-fdbe64823fc4', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('f119d4c1-de71-4fac-a65a-86e406686de4', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('d940e64f-da4a-4206-879a-2d913c7c4d9f', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3fb15340-d152-429f-a0a2-e7d5c33ccc28', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a658f7a-26ea-45b8-923a-1c5f21313667', 'signage_item', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.86432+00', '2026-10-19 09:06:27.86432+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('908fdc63-49b2-4273-88fb-0fc3e7d580f3', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('85eaaa99-f3a8-4cd3-809c-928e60f35dae', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('6270a54a-f1c5-4931-8078-1cbf96a46218', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('bc8aca28-d53e-4313-9502-c66c0a210242', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a7f93d39-3c6d-4a6c-aae1-72ee1cccc055', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('45ccdc8f-18f5-4f2e-96d9-0e47d93c3895', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('941007e3-25e0-4667-b4d8-7b57162dd3ae', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ca9b1235-0b7d-4429-9874-bf964bcce50f', 'signage_item', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.884026+00', '2026-10-19 09:06:27.884026+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8eb2a97b-c3ec-48e9-8d99-38c04e9b0ded', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('494d53db-0aa4-4e6e-a56e-cda626409e3a', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 09:06:26.855+00', '2026-10-21 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('3b44a447-1511-4e17-8077-af4a16377c1d', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('7d72208c-7c23-4596-b007-2dc5167eefc2', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 09:06:26.855+00', '2026-10-21 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('86dd9fdd-3c33-4147-bad6-d033c22d6338', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'invalidated', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('fe5041a7-d3de-4770-95cd-2e9971293dea', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-18 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('39832b72-c133-4d9c-8ee6-337307aad401', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef522824-5aa1-451e-9cbe-8e85d2ee720b', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('f1e4a3cc-83a9-468c-8721-f4203572ddaa', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('9a1968e1-6d82-486b-aec1-b1e2fcf8e90f', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('55a54c2c-67c8-408c-bcbd-96959d030b49', 'signage_item', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.91789+00', '2026-10-19 09:06:27.91789+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('875802bc-5372-40a7-9359-219ad28aee92', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('09c949b3-c391-4f6e-b336-bdae15e129e7', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'changes_requested', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('fd3764c1-0e4c-4145-b731-524928206b38', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'skipped', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('e1bf1dd8-e5e1-4400-93c3-badd2c9408d9', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ff636d40-2e40-4e30-a887-fe1d4bec89bc', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('29948cd4-2a69-4953-ae96-47b29a789293', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ae7e8b3e-69e2-49b3-ba1e-271a29ceca3e', 'signage_item', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:27.989279+00', '2026-10-19 09:06:27.989279+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('138cfc3e-b63d-4df7-9dd1-95f712c8a92f', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('a416a2c9-69c0-450b-8a11-148f24a5606a', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('d1b0af1b-712a-49b6-808b-84e3b91b296c', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'approved', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('e75ff9d4-99e6-4822-ae0f-b1871b782a17', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-16 09:06:26.855+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-23 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ce274c7a-7942-4a9c-9a5c-4490aff3d7af', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('028c3860-246e-49d1-8ac5-4736fa222c25', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-18 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7a995373-b1ca-4059-83ba-e9dbb000c5ea', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('8d67c236-1694-43c1-885e-0618f01b4eb0', 'signage_item', '30453403-6081-42b5-9da3-58628c3dc043', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.010202+00', '2026-10-19 09:06:28.010202+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6a380a4d-0339-4168-8d0c-ddbf8e7be067', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, 'c5a21c20-802c-4cb7-ba7f-59d62bce5278', 'Operations sign-off', 'approval', 1, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 3, false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', NULL);
INSERT INTO public.approval_instances VALUES ('64986074-478a-446d-abb0-678746d41eeb', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', 'Marketing sign-off', 'approval', 2, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 3, false, '44d37811-42b8-4679-9304-e8f36a38324e', NULL);
INSERT INTO public.approval_instances VALUES ('6df9ed90-5434-42aa-bdbd-aa7a5b5ba800', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '381934b8-309c-437b-91e4-98998eeccca5', 'Sales sign-off', 'approval', 3, 1, 'pending', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-14 09:06:26.855+00', '2026-10-19 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 5, false, 'c619690e-4922-4ffd-969b-ea2993d9f172', NULL);
INSERT INTO public.approval_instances VALUES ('4de74135-cbd7-4f61-a658-9e05e073ecbe', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '91f2c365-b7e7-400b-86d5-5fad84231266', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('97b458f2-4bfc-48ec-9f80-3d0e1b1000fe', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', 'Senior management sign-off', 'approval', 5, NULL, 'skipped', NULL, '00000000-0000-4000-8000-000000000005', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 3, false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1', NULL);
INSERT INTO public.approval_instances VALUES ('4de33eab-8865-469a-809b-f55b705ca015', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '55cd6807-3182-4e67-857d-394a7e765acb', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7f990112-8b51-4aff-bb3f-7beb09054e07', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '1a3828a6-d242-4816-a533-5ac6fd15b604', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('d910fa63-6a24-4d41-8e49-29f326977921', 'signage_item', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, '08af7b7b-90fe-4e63-85c0-0f9d3e41411a', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.037222+00', '2026-10-19 09:06:28.037222+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('3800ac36-945e-4e8f-aef4-e1a80a6e1f45', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, 'db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 09:06:26.855+00', '2026-10-16 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b6e5f919-9a19-4a57-848f-29175a05e8c0', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, '4c2095a3-13aa-4351-8a77-d0cf66e3ec56', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 09:06:26.855+00', '2026-10-22 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0c745d9a-0f15-4bd2-9ce5-dcde8b686a2e', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, 'ef124f44-2a40-4a76-a434-adf247e0e6af', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1ef8e4a2-c61f-4a15-b9e0-fab54048e722', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, 'a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b04c100b-b019-4e67-b26b-81f3d69f0a2b', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, '98f921a2-df71-4531-8163-8d7616c0ccc5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('ef2a6148-34e1-48e3-97fb-e40756577732', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 1, '08502d14-ae0f-44ee-ae44-5fae48b42f3a', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('1b4c0d0b-89ab-40ea-a69d-0f1862238fc0', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, 'db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-13 09:06:26.855+00', '2026-10-16 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('75f991ed-8bba-455e-86c7-90adf0c20fa6', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, '4c2095a3-13aa-4351-8a77-d0cf66e3ec56', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b7e75e76-cef5-4678-bef5-2c5a0050811c', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, 'ef124f44-2a40-4a76-a434-adf247e0e6af', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('df33386f-c8c5-4dac-b97b-cbddd376589a', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, 'a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('83604997-6821-4a5a-8b67-ce707c98caa7', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, '98f921a2-df71-4531-8163-8d7616c0ccc5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('12782761-c952-4730-bbaa-3a8dabf7a91b', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 1, '08502d14-ae0f-44ee-ae44-5fae48b42f3a', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('66ef046c-1518-48ef-9764-cb0d25813d4f', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, 'db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-10-13 09:06:26.855+00', '2026-10-16 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('7f1d6e38-653b-40aa-9a21-00dfdc215174', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, '4c2095a3-13aa-4351-8a77-d0cf66e3ec56', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('c77e4f04-ae95-43e8-8e7f-d48c6ddbd2ca', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, 'ef124f44-2a40-4a76-a434-adf247e0e6af', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4638bffd-a909-4e42-ad46-cb46de889e88', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, 'a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0dc156b5-7aab-4f68-a3de-3761bcb99be4', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, '98f921a2-df71-4531-8163-8d7616c0ccc5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('dfc55bba-606b-47a7-b9d4-d29457149af0', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 1, '08502d14-ae0f-44ee-ae44-5fae48b42f3a', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('0383996e-eaa9-45b9-b977-7a777d68ab22', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, 'db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 09:06:26.855+00', '2026-10-16 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b00db43b-f9fa-474b-9258-506a8d686aeb', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, '4c2095a3-13aa-4351-8a77-d0cf66e3ec56', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('6c13b89a-0aaa-4be5-ac49-ed804543812e', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, 'ef124f44-2a40-4a76-a434-adf247e0e6af', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-20 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('09a4c90e-a41b-460b-b2c6-546f0538e876', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, 'a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-22 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('127b9271-ee84-43f1-b18c-d484d9f48a0f', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, '98f921a2-df71-4531-8163-8d7616c0ccc5', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('b2aef502-5117-4111-a470-fef404cca940', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 1, '08502d14-ae0f-44ee-ae44-5fae48b42f3a', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00', false, true, 0, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('87b8bbd7-7f19-4985-bc5d-a102f3fa3f51', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, 'db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-13 09:06:26.855+00', '2026-10-16 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', true, true, 3, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('496b032a-8599-40b3-b00d-2e4ba28d1fd8', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, '4c2095a3-13aa-4351-8a77-d0cf66e3ec56', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('42091d4f-fab3-47cf-87c9-ba17abd8c566', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, 'ef124f44-2a40-4a76-a434-adf247e0e6af', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-20 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', true, true, 5, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('30aaf7ae-5438-4bf6-a2aa-ce64b436c622', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, 'a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-22 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', true, true, 7, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('a1451ac2-33e1-4f92-a197-b3c58161e547', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, '98f921a2-df71-4531-8163-8d7616c0ccc5', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-10-15 09:06:26.855+00', NULL, NULL, 'submission_version', '1', NULL, '2026-10-15 09:06:26.855+00', '2026-10-17 09:06:26.855+00', 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', true, true, 2, false, NULL, NULL);
INSERT INTO public.approval_instances VALUES ('4ec9b199-cae5-40b3-b2ce-8e307c251ad2', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 1, '08502d14-ae0f-44ee-ae44-5fae48b42f3a', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-15 09:06:26.855+00', NULL, 0, NULL, NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00', false, true, 0, false, NULL, NULL);


--
-- Data for Name: approvers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approvers VALUES ('53915b43-f2f5-4649-8555-f2cf5d52d4d9', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', 'Olivia Ops', 'Operations Manager', 'ops@media10.test', '00000000-0000-4000-8000-000000000002', false, '2026-10-19 09:06:27.155181+00', '2026-10-19 09:06:27.155181+00', false, NULL);
INSERT INTO public.approvers VALUES ('288a0523-5b96-4ec1-a8a0-9ef84a1a953a', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', '44d37811-42b8-4679-9304-e8f36a38324e', 'Marcus Marketing', 'Marketing Manager', 'marketing@media10.test', '00000000-0000-4000-8000-000000000003', false, '2026-10-19 09:06:27.163408+00', '2026-10-19 09:06:27.163408+00', false, NULL);
INSERT INTO public.approvers VALUES ('89b07500-78e1-484a-988b-77c5c965568a', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c619690e-4922-4ffd-969b-ea2993d9f172', 'Sara Sales', 'Sponsorship Sales Manager', 'sales@media10.test', '00000000-0000-4000-8000-000000000004', false, '2026-10-19 09:06:27.170291+00', '2026-10-19 09:06:27.170291+00', false, NULL);
INSERT INTO public.approvers VALUES ('c476c61f-1559-42e6-913b-769ceeed3a1f', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', '855f43e1-cc51-40b5-afe8-6b37dac07cd1', 'Dana Director', 'Event Director', 'director@media10.test', '00000000-0000-4000-8000-000000000005', true, '2026-10-19 09:06:27.177807+00', '2026-10-19 09:06:27.177807+00', false, NULL);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('8807c1a5-7d1e-4763-ad05-de480b17c810', '6923569b-db88-4fa3-a354-e9f957b750df', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.403807+00', '2026-10-19 09:06:27.403807+00');
INSERT INTO public.artwork_versions VALUES ('2a7eca0e-5155-4922-8868-2e2caf67b5c4', '90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.433019+00', '2026-10-19 09:06:27.433019+00');
INSERT INTO public.artwork_versions VALUES ('4af6a51f-f464-4718-a91e-2953af00bf7d', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-10-19 09:06:27.474017+00', '2026-10-19 09:06:27.474017+00');
INSERT INTO public.artwork_versions VALUES ('e8ec0e3f-82c7-43f4-99da-a9a4d70be69d', '19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.476597+00', '2026-10-19 09:06:27.476597+00');
INSERT INTO public.artwork_versions VALUES ('46f7396e-c86a-4363-b788-cd6e32a16c62', 'c3d00da7-63e4-498b-a614-8373c174b43e', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.52536+00', '2026-10-19 09:06:27.52536+00');
INSERT INTO public.artwork_versions VALUES ('d38943fa-3a6a-44ec-ad0d-ea181c470415', '527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.562834+00', '2026-10-19 09:06:27.562834+00');
INSERT INTO public.artwork_versions VALUES ('3868802f-805d-4598-88aa-7acf18f1ae13', 'e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.597714+00', '2026-10-19 09:06:27.597714+00');
INSERT INTO public.artwork_versions VALUES ('a488506d-8e06-4694-9324-f46a76f54a7e', 'e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.618337+00', '2026-10-19 09:06:27.618337+00');
INSERT INTO public.artwork_versions VALUES ('718a4df2-21a0-4f03-b2e6-b7fc43025517', '98be7515-3586-4f76-a1d7-a590058870eb', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.647409+00', '2026-10-19 09:06:27.647409+00');
INSERT INTO public.artwork_versions VALUES ('1696195b-27b2-4877-92d3-d069e39d03f7', 'd0f52202-85cb-4f87-bc8a-83ed8344c4ff', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.669702+00', '2026-10-19 09:06:27.669702+00');
INSERT INTO public.artwork_versions VALUES ('69796faf-a5d7-426c-9c1a-59d611411942', 'f16d1db5-63c8-47b0-8598-b09c93608873', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.690683+00', '2026-10-19 09:06:27.690683+00');
INSERT INTO public.artwork_versions VALUES ('081edc29-1622-4fd0-b96e-e182f00af7f3', '2f880ee7-0a11-45cc-8522-6dd72d073772', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.709456+00', '2026-10-19 09:06:27.709456+00');
INSERT INTO public.artwork_versions VALUES ('c81da155-8a9a-4a60-8e90-c29714eca8f5', '629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.733695+00', '2026-10-19 09:06:27.733695+00');
INSERT INTO public.artwork_versions VALUES ('88204cf4-691e-45b9-9f8b-effecc4722c4', 'b424149b-312e-4f74-ae8d-de2527232516', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.753671+00', '2026-10-19 09:06:27.753671+00');
INSERT INTO public.artwork_versions VALUES ('9aabe569-c952-4adf-87ba-73ee9be7c990', 'c23d2bad-b880-4ada-b505-4d25e279bebf', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.778411+00', '2026-10-19 09:06:27.778411+00');
INSERT INTO public.artwork_versions VALUES ('ff4206a0-7aae-45b5-ac0e-72fec992f88d', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.803767+00', '2026-10-19 09:06:27.803767+00');
INSERT INTO public.artwork_versions VALUES ('9be5aa43-f8a5-486e-9c17-ca5f04a9e18d', '051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.832766+00', '2026-10-19 09:06:27.832766+00');
INSERT INTO public.artwork_versions VALUES ('58ae4c8c-d749-4ba6-bc0f-d026b0773991', '3ae3c06d-b95b-4616-86dd-4c715f3be109', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.861119+00', '2026-10-19 09:06:27.861119+00');
INSERT INTO public.artwork_versions VALUES ('1c9ad1e9-91dd-41f7-ae94-02f0c017409f', '68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.87954+00', '2026-10-19 09:06:27.87954+00');
INSERT INTO public.artwork_versions VALUES ('bb5732cc-4330-425d-a3bc-e8aee8b4d0b1', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-19 09:06:27.909308+00', '2026-10-19 09:06:27.909308+00');
INSERT INTO public.artwork_versions VALUES ('b918ddff-fa78-4cb9-a42c-8cdf3b39d711', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-10-19 09:06:27.911468+00', '2026-10-19 09:06:27.911468+00');
INSERT INTO public.artwork_versions VALUES ('6f8933bc-2373-46cf-910e-3839ff81cbd1', '500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:27.913993+00', '2026-10-19 09:06:27.913993+00');
INSERT INTO public.artwork_versions VALUES ('843a90fa-fe6d-4212-9a28-9bde76eaea36', '135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-10-19 09:06:27.987093+00', '2026-10-19 09:06:27.987093+00');
INSERT INTO public.artwork_versions VALUES ('c6ff2b96-7491-454a-93d0-967907ab2a7f', '30453403-6081-42b5-9da3-58628c3dc043', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:28.007459+00', '2026-10-19 09:06:28.007459+00');
INSERT INTO public.artwork_versions VALUES ('a2dee7e2-5904-4f5d-9d8a-569668832a77', 'b8aaae11-e543-48fd-a0a8-81c76c170f81', 1, 'seed/SIG-BIRM27-031-v1.pdf', 'SIG-BIRM27-031-v1.pdf', 'application/pdf', 39, 'a12d9aebf600e9397c0870441c35c96cecfafec6c885f0dbca2dacb33df52129', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-10-19 09:06:28.034599+00', '2026-10-19 09:06:28.034599+00');


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

INSERT INTO public.contractors VALUES ('becd360b-3e1f-4a36-affb-2e831fbd28c5', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-10-19 09:06:27.107236+00', '2026-10-19 09:06:27.107236+00');
INSERT INTO public.contractors VALUES ('2a6012e7-719c-4d3c-8592-0c57c3d430b6', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-10-19 09:06:27.110028+00', '2026-10-19 09:06:27.110028+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments VALUES ('b64e1d1f-f7ac-41e0-8b9b-0f83407eece5', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Operations', 1, false, '{organiser,sponsor}', false, '2026-10-19 09:06:27.150813+00', '2026-10-19 09:06:27.150813+00', true);
INSERT INTO public.departments VALUES ('44d37811-42b8-4679-9304-e8f36a38324e', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Marketing', 2, false, '{organiser,sponsor}', false, '2026-10-19 09:06:27.160048+00', '2026-10-19 09:06:27.160048+00', true);
INSERT INTO public.departments VALUES ('c619690e-4922-4ffd-969b-ea2993d9f172', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Sales', 3, false, '{sponsor}', false, '2026-10-19 09:06:27.16688+00', '2026-10-19 09:06:27.16688+00', true);
INSERT INTO public.departments VALUES ('855f43e1-cc51-40b5-afe8-6b37dac07cd1', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Senior management', 4, true, '{organiser,sponsor}', false, '2026-10-19 09:06:27.174445+00', '2026-10-19 09:06:27.174445+00', true);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('2c977261-106d-409e-aef1-9b21008d9b08', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00');
INSERT INTO public.documents VALUES ('18b8aee7-31a6-437b-949b-6d3987a6851d', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00');
INSERT INTO public.documents VALUES ('f0ae1339-ebfc-45d6-a2ac-f4062033d7ff', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00');
INSERT INTO public.documents VALUES ('d0e1a40b-bffb-418c-987a-fbeb685d41bb', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd17b24b4-aec9-40ca-beb1-031f3b26caa0', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00');
INSERT INTO public.documents VALUES ('978575a0-4b52-447c-ad84-9c1fb7fe28cb', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00');
INSERT INTO public.documents VALUES ('8a120927-581e-4b6c-9e6f-f4fb0bd8f064', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00');
INSERT INTO public.documents VALUES ('4deb9777-f9fd-44d6-8833-f7749d7d9cdd', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00');
INSERT INTO public.documents VALUES ('af817e51-4709-4cac-b427-27ad60e91c5f', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', '82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00');
INSERT INTO public.documents VALUES ('63baa822-b0b0-4f9b-b0a0-fb7934aa08e8', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00');
INSERT INTO public.documents VALUES ('5b1c6042-bbfb-4736-809f-1a15bccb3fda', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00');
INSERT INTO public.documents VALUES ('cc8ecd8d-60c8-4639-82dd-b7d727692c25', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00');
INSERT INTO public.documents VALUES ('bd6de82b-b66f-4543-bd09-a4f38147b7a6', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e48b7492-02fc-4a2b-bcb7-300ec0f69423', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00');
INSERT INTO public.documents VALUES ('43dcca95-91d5-405f-87b9-5cb0b89c0870', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00');
INSERT INTO public.documents VALUES ('409f518b-21be-479e-9310-efb9c41bc34b', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00');
INSERT INTO public.documents VALUES ('81ee1d7e-c63e-4bb1-95fe-fdc51e56016d', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00');
INSERT INTO public.documents VALUES ('d98a47ad-9c7b-4834-834e-5be14d9f17e2', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'e876aa84-e0ca-42dc-b339-047c7e97bd81', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00');
INSERT INTO public.documents VALUES ('7e72e57c-27dc-4352-90e0-d7c0dc3468de', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00');
INSERT INTO public.documents VALUES ('df8cce06-55c4-49d3-b643-8151cdcbc88f', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00');
INSERT INTO public.documents VALUES ('a6f665ac-db1b-4f33-b589-9e678d2f762a', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00');
INSERT INTO public.documents VALUES ('d92f8a7e-c925-4fd0-9991-0e64e3757cee', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_submission', 'd6506afd-0e9b-486b-9c04-7adb30a3c3fa', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('1fc7e7cb-b666-4206-a985-bf38b300decd', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'signage', 34, '2026-10-19 09:06:28.064319+00', '2026-10-19 09:06:28.069605+00');
INSERT INTO public.edition_counters VALUES ('7c02620e-e351-4d27-828e-327c574ea251', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_design', 1, '2026-10-19 09:06:28.12888+00', '2026-10-19 09:06:28.12888+00');
INSERT INTO public.edition_counters VALUES ('fb087a33-10cd-4833-a4f5-4c373836d5e1', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_item', 1, '2026-10-19 09:06:28.12888+00', '2026-10-19 09:06:28.12888+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('6ab54bfc-68ff-4718-820b-b382d43d033a', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-10-19 09:06:26.994376+00', '2026-10-19 09:06:26.994376+00');
INSERT INTO public.edition_deadlines VALUES ('0c4c7c55-592f-4e30-8fed-bd1ca88fc18e', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-10-19 09:06:26.99702+00', '2026-10-19 09:06:26.99702+00');
INSERT INTO public.edition_deadlines VALUES ('08c099a8-cf7d-4b3e-8d11-c5576240f6ed', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-10-19 09:06:26.999553+00', '2026-10-19 09:06:26.999553+00');
INSERT INTO public.edition_deadlines VALUES ('32209a4b-7e36-493a-85ec-3889859ad8a2', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'artwork_due', 'Artwork due', 21, NULL, '2026-10-19 09:06:27.00151+00', '2026-10-19 09:06:27.00151+00');
INSERT INTO public.edition_deadlines VALUES ('a49977ad-5916-4f95-8596-37a38265cdea', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'print_deadline', 'Print deadline', 14, NULL, '2026-10-19 09:06:27.00337+00', '2026-10-19 09:06:27.00337+00');
INSERT INTO public.edition_deadlines VALUES ('b6a43aa4-d300-4476-8211-e1a1a3739e5b', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'delivery', 'Delivery to venue', 3, NULL, '2026-10-19 09:06:27.005355+00', '2026-10-19 09:06:27.005355+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '8b9d56e4-5668-41e1-bb00-e30b0046fbc7', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-10-19 09:06:26.990037+00', '2026-10-19 09:06:26.990037+00', NULL, '{}');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('8b9d56e4-5668-41e1-bb00-e30b0046fbc7', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'UK Construction Week', 'UKCW', '2026-10-19 09:06:26.945224+00', '2026-10-19 09:06:26.945224+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('fb30a663-922b-477f-b934-1009acecc6f1', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Exhibitor Co', 'A10', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', '2026-10-19 09:06:27.329481+00', '2026-10-19 09:06:27.329481+00');
INSERT INTO public.exhibitors VALUES ('63ad82f5-53d7-4350-84b1-ac3f961f624d', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SteelFrame Systems', 'A20', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', '2026-10-19 09:06:27.336549+00', '2026-10-19 09:06:27.336549+00');
INSERT INTO public.exhibitors VALUES ('47b37ee8-a45a-411e-8f9b-86851ff3dbe4', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'BrickWorks UK', 'A30', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', '2026-10-19 09:06:27.342956+00', '2026-10-19 09:06:27.342956+00');
INSERT INTO public.exhibitors VALUES ('f1c6932f-060a-463c-a94d-6ebcb13f3f77', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Timber Trade Ltd', 'B10', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', '2026-10-19 09:06:27.348453+00', '2026-10-19 09:06:27.348453+00');
INSERT INTO public.exhibitors VALUES ('1436f1aa-29eb-4ae0-b1e5-50fd8b9ddaf1', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'GlassTech', 'B20', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', '2026-10-19 09:06:27.354123+00', '2026-10-19 09:06:27.354123+00');
INSERT INTO public.exhibitors VALUES ('c646f23e-2630-402f-b4e6-b7ce1efc5728', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Insulate Pro', 'B30', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', '2026-10-19 09:06:27.359849+00', '2026-10-19 09:06:27.359849+00');
INSERT INTO public.exhibitors VALUES ('bb178b28-bd7f-4492-a789-5966e2b14695', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'RoofRight', 'C10', '7c0094fe-7f17-4715-9890-e18bc086076c', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', '2026-10-19 09:06:27.365526+00', '2026-10-19 09:06:27.365526+00');
INSERT INTO public.exhibitors VALUES ('3cd13acd-8467-4d33-959e-341011e85ec3', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'PlantHire Direct', 'C20', '7c0094fe-7f17-4715-9890-e18bc086076c', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', '2026-10-19 09:06:27.371409+00', '2026-10-19 09:06:27.371409+00');
INSERT INTO public.exhibitors VALUES ('4365cc43-3844-4ced-bef3-91dfed031690', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SafetyFirst PPE', 'D10', '7c0094fe-7f17-4715-9890-e18bc086076c', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-10-19 09:06:27.376882+00', '2026-10-19 09:06:27.376882+00');
INSERT INTO public.exhibitors VALUES ('ae65c2ce-1f8b-48fc-9c69-c3721c9ac65d', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'ToolMart Retail', 'D20', '7c0094fe-7f17-4715-9890-e18bc086076c', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-10-19 09:06:27.380704+00', '2026-10-19 09:06:27.380704+00');
INSERT INTO public.exhibitors VALUES ('b31d517a-24a1-41d1-a157-4591008ed184', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'EcoBuild Materials', 'D30', '7c0094fe-7f17-4715-9890-e18bc086076c', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-10-19 09:06:27.384473+00', '2026-10-19 09:06:27.384473+00');
INSERT INTO public.exhibitors VALUES ('e92ff6d2-cd54-48d9-8527-cf0f3ac51468', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SiteWise Software', 'D40', '7c0094fe-7f17-4715-9890-e18bc086076c', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-10-19 09:06:27.386665+00', '2026-10-19 09:06:27.386665+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('be9ea4c7-37a6-40ee-b309-ab9176157ed5', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'venue', 'venue', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.290056+00', '2026-10-19 09:06:27.290056+00');
INSERT INTO public.external_grants VALUES ('08b959f3-b28a-44a9-abc2-fcd12bedf098', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.299267+00', '2026-10-19 09:06:27.299267+00');
INSERT INTO public.external_grants VALUES ('bc074d15-44ac-4b5e-9623-844dee0c1a23', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.306858+00', '2026-10-19 09:06:27.306858+00');
INSERT INTO public.external_grants VALUES ('992a8b91-fc72-4a45-8f9d-880e8248d198', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'supplier', 'supplier', 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.31554+00', '2026-10-19 09:06:27.31554+00');
INSERT INTO public.external_grants VALUES ('6ab15093-1b43-4df0-98ef-39e093ad527d', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'sponsor', 'sponsor', '51f03b45-5154-4f51-8ca9-175d0668629b', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.323224+00', '2026-10-19 09:06:27.323224+00');
INSERT INTO public.external_grants VALUES ('cfb247c7-ff2c-4b9e-ac56-a78d84c4dba3', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'exhibitor', 'exhibitor', 'fb30a663-922b-477f-b934-1009acecc6f1', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-10-19 09:06:26.855+00', NULL, '2026-10-19 09:06:27.3901+00', '2026-10-19 09:06:27.3901+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('644cab0f-b173-4b89-aaea-c858fa94e2fe', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Hall 1', NULL, NULL, NULL, 0, '2026-10-19 09:06:27.010322+00', '2026-10-19 09:06:27.010322+00');
INSERT INTO public.halls VALUES ('7c0094fe-7f17-4715-9890-e18bc086076c', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Hall 2', NULL, NULL, NULL, 1, '2026-10-19 09:06:27.014809+00', '2026-10-19 09:06:27.014809+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('7bf5286b-a243-4cad-aab2-744cad17f7f8', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Hanging banner', 'hanging_banner', '66b1f369-20d5-4e19-ac48-8140e5716008', 'rigged', true, 0, '2026-10-19 09:06:27.234413+00', '2026-10-19 09:06:27.234413+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3c00c8a4-25ca-4a84-af25-a2afea9b803e', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Foamex board', 'foamex_board', '66b1f369-20d5-4e19-ac48-8140e5716008', 'wall_mounted', false, 1, '2026-10-19 09:06:27.239195+00', '2026-10-19 09:06:27.239195+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('b8067c60-f715-4709-b777-9c53bb86b505', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Fabric graphic', 'fabric_graphic', '66b1f369-20d5-4e19-ac48-8140e5716008', 'shell_mounted', false, 2, '2026-10-19 09:06:27.241314+00', '2026-10-19 09:06:27.241314+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('22b8e7f8-59f8-4b7d-a307-03d058138708', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Floor vinyl', 'floor_vinyl', '66b1f369-20d5-4e19-ac48-8140e5716008', 'floor', false, 3, '2026-10-19 09:06:27.243395+00', '2026-10-19 09:06:27.243395+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('33170743-94de-4f76-a57c-9397b9e72153', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Aisle sign', 'aisle_sign', '66b1f369-20d5-4e19-ac48-8140e5716008', 'rigged', true, 4, '2026-10-19 09:06:27.24556+00', '2026-10-19 09:06:27.24556+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3a1b36f6-2a60-4a39-be9b-163923e7771d', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Entrance feature', 'entrance_feature', '66b1f369-20d5-4e19-ac48-8140e5716008', 'freestanding', true, 5, '2026-10-19 09:06:27.24843+00', '2026-10-19 09:06:27.24843+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('d3857fc6-8373-48d6-b9d8-6769b0b26787', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Registration', 'registration', '66b1f369-20d5-4e19-ac48-8140e5716008', 'freestanding', false, 6, '2026-10-19 09:06:27.251269+00', '2026-10-19 09:06:27.251269+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('fc9d2cb2-f2b1-4377-906f-ba5475c6c7ef', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Seminar theatre', 'seminar_theatre', '66b1f369-20d5-4e19-ac48-8140e5716008', 'freestanding', false, 7, '2026-10-19 09:06:27.253468+00', '2026-10-19 09:06:27.253468+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('0f17582d-0b09-4506-b6fb-b7e67be56e12', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Feature area', 'feature_area', '66b1f369-20d5-4e19-ac48-8140e5716008', 'freestanding', false, 8, '2026-10-19 09:06:27.255621+00', '2026-10-19 09:06:27.255621+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('48790e75-92f1-4ff2-bb55-dae62d57beee', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'External', 'external', '66b1f369-20d5-4e19-ac48-8140e5716008', 'freestanding', true, 9, '2026-10-19 09:06:27.257854+00', '2026-10-19 09:06:27.257854+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('3c5f6f36-abd0-400d-852c-ab8925d666cb', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Digital screen', 'digital_screen', '66b1f369-20d5-4e19-ac48-8140e5716008', 'digital', false, 10, '2026-10-19 09:06:27.259951+00', '2026-10-19 09:06:27.259951+00', 'signage', 'digital', false);
INSERT INTO public.item_types VALUES ('a521e899-b1cd-4157-a606-1dcfc2217c26', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Branded lanyards', 'lanyard', '66b1f369-20d5-4e19-ac48-8140e5716008', NULL, false, 11, '2026-10-19 09:06:27.262399+00', '2026-10-19 09:06:27.262399+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('05fd0f29-2ac6-4059-82f4-adbba9952057', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Show bags', 'show_bag', '66b1f369-20d5-4e19-ac48-8140e5716008', NULL, false, 12, '2026-10-19 09:06:27.265759+00', '2026-10-19 09:06:27.265759+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('9e546d36-5534-4d7b-9d3b-bf222925d037', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Registration branding', 'reg_branding', '66b1f369-20d5-4e19-ac48-8140e5716008', NULL, false, 13, '2026-10-19 09:06:27.26973+00', '2026-10-19 09:06:27.26973+00', 'sponsorship_item', NULL, false);
INSERT INTO public.item_types VALUES ('805717f2-9a19-44af-83d2-64902b39f188', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Other signage', 'other_signage', '66b1f369-20d5-4e19-ac48-8140e5716008', NULL, false, 14, '2026-10-19 09:06:27.27325+00', '2026-10-19 09:06:27.27325+00', 'signage', 'print', false);
INSERT INTO public.item_types VALUES ('620f6c27-1893-426b-9224-e34fb3501295', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Other sponsorship item', 'other_sponsorship', '66b1f369-20d5-4e19-ac48-8140e5716008', NULL, false, 15, '2026-10-19 09:06:27.27663+00', '2026-10-19 09:06:27.27663+00', 'sponsorship_item', NULL, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('af5a67b2-390e-4ea9-9ede-8079145c06d2', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-10-19 09:06:27.019292+00', '2026-10-19 09:06:27.019292+00');
INSERT INTO public.locations VALUES ('2ccda10e-a893-4023-8912-4339cd078560', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-10-19 09:06:27.024157+00', '2026-10-19 09:06:27.024157+00');
INSERT INTO public.locations VALUES ('63a14967-aa9e-4180-9e5d-67a251ec59e6', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-10-19 09:06:27.028443+00', '2026-10-19 09:06:27.028443+00');
INSERT INTO public.locations VALUES ('950310c9-123e-40c8-9c41-457fc317ca9c', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-10-19 09:06:27.032384+00', '2026-10-19 09:06:27.032384+00');
INSERT INTO public.locations VALUES ('6083ff3e-2678-4a8c-b052-71ea4f3bbcad', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-10-19 09:06:27.050541+00', '2026-10-19 09:06:27.050541+00');
INSERT INTO public.locations VALUES ('7eaf3ca8-2c3f-4f97-9092-6ec8b6933405', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-10-19 09:06:27.054966+00', '2026-10-19 09:06:27.054966+00');
INSERT INTO public.locations VALUES ('1dd4a238-dd0a-47fe-9a01-03e066e6960a', '7c0094fe-7f17-4715-9890-e18bc086076c', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-10-19 09:06:27.05853+00', '2026-10-19 09:06:27.05853+00');
INSERT INTO public.locations VALUES ('484ba8ea-da1a-4a17-907c-161f279579bb', '7c0094fe-7f17-4715-9890-e18bc086076c', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-10-19 09:06:27.061435+00', '2026-10-19 09:06:27.061435+00');
INSERT INTO public.locations VALUES ('86420bce-74bd-4c55-af49-00aaa2ab012d', '7c0094fe-7f17-4715-9890-e18bc086076c', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-10-19 09:06:27.063977+00', '2026-10-19 09:06:27.063977+00');
INSERT INTO public.locations VALUES ('6e70c741-487f-46b9-b735-6cd86ce9ffa5', '7c0094fe-7f17-4715-9890-e18bc086076c', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-10-19 09:06:27.066549+00', '2026-10-19 09:06:27.066549+00');
INSERT INTO public.locations VALUES ('eb893f46-8ba1-4bad-948b-95d2c6a044e0', '7c0094fe-7f17-4715-9890-e18bc086076c', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-10-19 09:06:27.068803+00', '2026-10-19 09:06:27.068803+00');
INSERT INTO public.locations VALUES ('2f1442aa-f8d1-43ca-b5bf-35bf0d0157a5', '7c0094fe-7f17-4715-9890-e18bc086076c', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-10-19 09:06:27.07111+00', '2026-10-19 09:06:27.07111+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('6d79be72-2d65-49ea-bedb-5037a68390cc', '00000000-0000-4000-8000-000000000001', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'admin', '2026-10-19 09:06:26.926191+00', '2026-10-19 09:06:26.926191+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('c0f74517-0724-4fa7-b970-da5eb2b56fac', '00000000-0000-4000-8000-000000000002', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'ops', '2026-10-19 09:06:26.932533+00', '2026-10-19 09:06:26.932533+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('cbf5b425-f24a-4fe2-a1c8-69862600b207', '00000000-0000-4000-8000-000000000004', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'sales', '2026-10-19 09:06:26.938646+00', '2026-10-19 09:06:26.938646+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('7fd3500a-4099-4b5b-bbe0-55ad3a7748ed', '00000000-0000-4000-8000-000000000005', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'event_director', '2026-10-19 09:06:26.941477+00', '2026-10-19 09:06:26.941477+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('7a0721ef-7646-4061-b392-aa02d7d75937', '00000000-0000-4000-8000-000000000006', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'viewer', '2026-10-19 09:06:26.943574+00', '2026-10-19 09:06:26.943574+00', '{}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.memberships VALUES ('1474abe4-c46b-4141-87f3-bed257733606', '00000000-0000-4000-8000-000000000003', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'marketing', '2026-10-19 09:06:26.93545+00', '2026-10-19 09:06:28.234767+00', '{"costs.edit": true}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-10-19 09:06:26.916368+00', '2026-10-19 09:06:26.916368+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('6923569b-db88-4fa3-a354-e9f957b750df', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '3a1b36f6-2a60-4a39-be9b-163923e7771d', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'af5a67b2-390e-4ea9-9ede-8079145c06d2', 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', 'eefa0ad3-69dc-4ea0-baee-6450ba9472e7', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '8807c1a5-7d1e-4763-ad05-de480b17c810', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.396413+00', '2026-10-19 09:06:27.407137+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('90e1e73f-6b01-4f29-ad07-f9544d89fb0d', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', 'd3857fc6-8373-48d6-b9d8-6769b0b26787', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '2ccda10e-a893-4023-8912-4339cd078560', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '2a7eca0e-5155-4922-8868-2e2caf67b5c4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.429666+00', '2026-10-19 09:06:27.434531+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('19bfd9cd-ff10-4202-9d34-18f6f9ab7347', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '7bf5286b-a243-4cad-aab2-744cad17f7f8', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '63a14967-aa9e-4180-9e5d-67a251ec59e6', 'ops', '00000000-0000-4000-8000-000000000002', '51f03b45-5154-4f51-8ca9-175d0668629b', '7a0f06a4-82ab-4666-976d-6d93fcdc5754', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'e8ec0e3f-82c7-43f4-99da-a9a4d70be69d', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.469326+00', '2026-10-19 09:06:27.479109+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c3d00da7-63e4-498b-a614-8373c174b43e', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'fc9d2cb2-f2b1-4377-906f-ba5475c6c7ef', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '950310c9-123e-40c8-9c41-457fc317ca9c', 'marketing', '00000000-0000-4000-8000-000000000003', '640a87e5-8d7f-4385-a71d-3dd6b96b2358', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '46f7396e-c86a-4363-b788-cd6e32a16c62', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.520114+00', '2026-10-19 09:06:27.527998+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('527ed50c-5a48-49b3-bb4f-cfd04558e8b1', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', '22b8e7f8-59f8-4b7d-a307-03d058138708', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '6083ff3e-2678-4a8c-b052-71ea4f3bbcad', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'd38943fa-3a6a-44ec-ad0d-ea181c470415', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.560249+00', '2026-10-19 09:06:27.564319+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e637063c-acf2-455f-8b2d-c6a8ac3bc6ec', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', '0f17582d-0b09-4506-b6fb-b7e67be56e12', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '7eaf3ca8-2c3f-4f97-9092-6ec8b6933405', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '3868802f-805d-4598-88aa-7acf18f1ae13', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.594615+00', '2026-10-19 09:06:27.59943+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e96523d1-13ed-4b3c-ae90-f1fb8bf6ea21', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '7bf5286b-a243-4cad-aab2-744cad17f7f8', '7c0094fe-7f17-4715-9890-e18bc086076c', '1dd4a238-dd0a-47fe-9a01-03e066e6960a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'a488506d-8e06-4694-9324-f46a76f54a7e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.615701+00', '2026-10-19 09:06:27.619727+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('98be7515-3586-4f76-a1d7-a590058870eb', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', '33170743-94de-4f76-a57c-9397b9e72153', '7c0094fe-7f17-4715-9890-e18bc086076c', '484ba8ea-da1a-4a17-907c-161f279579bb', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '718a4df2-21a0-4f03-b2e6-b7fc43025517', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.644002+00', '2026-10-19 09:06:27.649261+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d0f52202-85cb-4f87-bc8a-83ed8344c4ff', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'fc9d2cb2-f2b1-4377-906f-ba5475c6c7ef', '7c0094fe-7f17-4715-9890-e18bc086076c', '86420bce-74bd-4c55-af49-00aaa2ab012d', 'marketing', '00000000-0000-4000-8000-000000000003', '640a87e5-8d7f-4385-a71d-3dd6b96b2358', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '1696195b-27b2-4877-92d3-d069e39d03f7', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.66658+00', '2026-10-19 09:06:27.671704+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f16d1db5-63c8-47b0-8598-b09c93608873', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'b8067c60-f715-4709-b777-9c53bb86b505', '7c0094fe-7f17-4715-9890-e18bc086076c', '6e70c741-487f-46b9-b735-6cd86ce9ffa5', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '69796faf-a5d7-426c-9c1a-59d611411942', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.688541+00', '2026-10-19 09:06:27.693182+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL);
INSERT INTO public.signage_items VALUES ('2f880ee7-0a11-45cc-8522-6dd72d073772', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '48790e75-92f1-4ff2-bb55-dae62d57beee', '7c0094fe-7f17-4715-9890-e18bc086076c', 'eb893f46-8ba1-4bad-948b-95d2c6a044e0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '081edc29-1622-4fd0-b96e-e182f00af7f3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.707336+00', '2026-10-19 09:06:27.711779+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', NULL);
INSERT INTO public.signage_items VALUES ('629b6d08-ddd4-4dd1-9c60-b6865c5fe860', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '7c0094fe-7f17-4715-9890-e18bc086076c', '2f1442aa-f8d1-43ca-b5bf-35bf0d0157a5', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'c81da155-8a9a-4a60-8e90-c29714eca8f5', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.731571+00', '2026-10-19 09:06:27.736247+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-16 09:06:26.855+00');
INSERT INTO public.signage_items VALUES ('6b5ae5ac-12f5-48b7-89df-3b99fac82887', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-034', 34, 'Water bottles', 'Water bottles for UKCW Birmingham 2027.', '620f6c27-1893-426b-9224-e34fb3501295', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 2000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.062551+00', '2026-10-19 09:06:28.062551+00', 'sponsorship_item', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', '2026-11-06', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('54233e47-bc5f-448c-b0ee-7835edff31dc', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'STB-BIRM27-001', 1000001, 'Feature stand — main entrance', 'Organiser feature stand at the Hall 1 entrance: welcome desk and show graphics.', NULL, '644cab0f-b173-4b89-aaea-c858fa94e2fe', NULL, 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 6000, 3500, 4000, 1, 'single', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'draft', NULL, NULL, '699b5827-b294-41ef-8184-5751885d4647', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.120815+00', '2026-10-19 09:06:28.120815+00', 'stand_design', 'organiser', '[{"stepId": "b49ec007-5f18-4a8b-b6a3-0f961f3ea51c", "userId": "00000000-0000-4000-8000-000000000002"}, {"stepId": "f99235ba-8071-4e1d-a732-55706e4ceba4", "userId": null}]', NULL, NULL, NULL, NULL, 'A01', NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b424149b-312e-4f74-ae8d-de2527232516', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '3c5f6f36-abd0-400d-852c-ab8925d666cb', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '2ccda10e-a893-4023-8912-4339cd078560', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '3b97cc34-a985-4c19-8998-da867b5f4089', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '88204cf4-691e-45b9-9f8b-effecc4722c4', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.750334+00', '2026-10-19 09:06:27.756854+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-16 09:06:26.855+00');
INSERT INTO public.signage_items VALUES ('c23d2bad-b880-4ada-b505-4d25e279bebf', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', '33170743-94de-4f76-a57c-9397b9e72153', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '63a14967-aa9e-4180-9e5d-67a251ec59e6', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '9aabe569-c952-4adf-87ba-73ee9be7c990', '2026-10-16 09:06:26.855+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.775662+00', '2026-10-19 09:06:27.781809+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-16 09:06:26.855+00');
INSERT INTO public.signage_items VALUES ('00ff34cb-a06c-49a6-9e7e-10a701b881ca', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '6083ff3e-2678-4a8c-b052-71ea4f3bbcad', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'ff4206a0-7aae-45b5-ac0e-72fec992f88d', '2026-10-16 09:06:26.855+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.799791+00', '2026-10-19 09:06:27.807122+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-16 09:06:26.855+00');
INSERT INTO public.signage_items VALUES ('051bd5ea-6ff3-463e-b8e2-39d7ff8022d3', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', '0f17582d-0b09-4506-b6fb-b7e67be56e12', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '7eaf3ca8-2c3f-4f97-9092-6ec8b6933405', 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '9be5aa43-f8a5-486e-9c17-ca5f04a9e18d', '2026-10-16 09:06:26.855+00', '00000000-0000-4000-8000-000000000002', NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.8299+00', '2026-10-19 09:06:27.835747+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, '2026-10-16 09:06:26.855+00', '2026-10-16 09:06:26.855+00');
INSERT INTO public.signage_items VALUES ('3ae3c06d-b95b-4616-86dd-4c715f3be109', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '7bf5286b-a243-4cad-aab2-744cad17f7f8', '7c0094fe-7f17-4715-9890-e18bc086076c', '484ba8ea-da1a-4a17-907c-161f279579bb', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '58ae4c8c-d749-4ba6-bc0f-d026b0773991', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.858609+00', '2026-10-19 09:06:27.862916+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('68f49d89-e3ff-47e3-a79b-4b1c378b4b7f', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'b8067c60-f715-4709-b777-9c53bb86b505', '7c0094fe-7f17-4715-9890-e18bc086076c', '6e70c741-487f-46b9-b735-6cd86ce9ffa5', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '1c9ad1e9-91dd-41f7-ae94-02f0c017409f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.877484+00', '2026-10-19 09:06:27.882334+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('500a12b3-2e2e-4caf-9a35-b7d9e68edf0b', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '7bf5286b-a243-4cad-aab2-744cad17f7f8', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '63a14967-aa9e-4180-9e5d-67a251ec59e6', 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', '7a0f06a4-82ab-4666-976d-6d93fcdc5754', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '6f8933bc-2373-46cf-910e-3839ff81cbd1', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.904905+00', '2026-10-19 09:06:27.915824+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c08fd7d8-7fc4-42d8-9a4f-1629727c17ff', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '7c0094fe-7f17-4715-9890-e18bc086076c', '2f1442aa-f8d1-43ca-b5bf-35bf0d0157a5', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.942984+00', '2026-10-19 09:06:27.942984+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('f78f1739-29cc-42be-a68d-ab40e1d250ef', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '2ccda10e-a893-4023-8912-4339cd078560', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.94709+00', '2026-10-19 09:06:27.94709+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b23413ad-c2be-415a-b993-0ebe1a21a557', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', 'd3857fc6-8373-48d6-b9d8-6769b0b26787', '7c0094fe-7f17-4715-9890-e18bc086076c', '1dd4a238-dd0a-47fe-9a01-03e066e6960a', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.951826+00', '2026-10-19 09:06:27.951826+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('c3c989c5-71a8-4033-9b79-97f85c9c3c9f', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '3c5f6f36-abd0-400d-852c-ab8925d666cb', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '7eaf3ca8-2c3f-4f97-9092-6ec8b6933405', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '3b97cc34-a985-4c19-8998-da867b5f4089', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.956576+00', '2026-10-19 09:06:27.956576+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('1d78e0ba-1bc5-4e3f-a5bf-369acb798114', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', '22b8e7f8-59f8-4b7d-a307-03d058138708', '7c0094fe-7f17-4715-9890-e18bc086076c', '86420bce-74bd-4c55-af49-00aaa2ab012d', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.962576+00', '2026-10-19 09:06:27.962576+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d4762211-92ef-4b2c-8fed-fe4e7ea4d1d8', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'fc9d2cb2-f2b1-4377-906f-ba5475c6c7ef', '7c0094fe-7f17-4715-9890-e18bc086076c', '86420bce-74bd-4c55-af49-00aaa2ab012d', 'marketing', '00000000-0000-4000-8000-000000000003', '640a87e5-8d7f-4385-a71d-3dd6b96b2358', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.966623+00', '2026-10-19 09:06:27.966623+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('d523b94f-0b0d-4d91-aaec-38e699bfdb58', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '48790e75-92f1-4ff2-bb55-dae62d57beee', '7c0094fe-7f17-4715-9890-e18bc086076c', 'eb893f46-8ba1-4bad-948b-95d2c6a044e0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.970346+00', '2026-10-19 09:06:27.970346+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f", "userId": "00000000-0000-4000-8000-000000000005"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('4918176a-aa2b-4ad8-aefc-bf36a4f59710', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '7c0094fe-7f17-4715-9890-e18bc086076c', 'eb893f46-8ba1-4bad-948b-95d2c6a044e0', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.974295+00', '2026-10-19 09:06:27.974295+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('135962e4-353a-4d9f-b6c8-cb05d61f2fc9', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '644cab0f-b173-4b89-aaea-c858fa94e2fe', '6083ff3e-2678-4a8c-b052-71ea4f3bbcad', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, '843a90fa-fe6d-4212-9a28-9bde76eaea36', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:27.984769+00', '2026-10-19 09:06:27.988131+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('30453403-6081-42b5-9da3-58628c3dc043', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '3a1b36f6-2a60-4a39-be9b-163923e7771d', '644cab0f-b173-4b89-aaea-c858fa94e2fe', 'af5a67b2-390e-4ea9-9ede-8079145c06d2', 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', 'eefa0ad3-69dc-4ea0-baee-6450ba9472e7', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'c6ff2b96-7491-454a-93d0-967907ab2a7f', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.004796+00', '2026-10-19 09:06:28.008749+00', 'signage', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', NULL, NULL, NULL, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('318c9ca9-853f-4dab-84d2-5d69c9b843ac', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '3c00c8a4-25ca-4a84-af25-a2afea9b803e', '7c0094fe-7f17-4715-9890-e18bc086076c', '2f1442aa-f8d1-43ca-b5bf-35bf0d0157a5', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.02695+00', '2026-10-19 09:06:28.02695+00', 'signage', 'organiser', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b8aaae11-e543-48fd-a0a8-81c76c170f81', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-031', 31, 'Branded lanyards — BuildCo', 'Branded lanyards — BuildCo for UKCW Birmingham 2027.', 'a521e899-b1cd-4157-a606-1dcfc2217c26', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', NULL, true, NULL, NULL, NULL, 3000, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 4500.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 'a2dee7e2-5904-4f5d-9d8a-569668832a77', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.032198+00', '2026-10-19 09:06:28.035822+00', 'sponsorship_item', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', '2027-01-02', NULL, 9000.00, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('e6d5656f-da73-4597-8de0-daabb2869293', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-032', 32, 'Show bags — BuildCo', 'Show bags — BuildCo for UKCW Birmingham 2027.', '05fd0f29-2ac6-4059-82f4-adbba9952057', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', '51f03b45-5154-4f51-8ca9-175d0668629b', NULL, true, NULL, NULL, NULL, 2500, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 6200.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.053858+00', '2026-10-19 09:06:28.053858+00', 'sponsorship_item', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}, {"stepId": "381934b8-309c-437b-91e4-98998eeccca5", "userId": null}]', '2026-11-08', NULL, 12500.00, '2026-10-09 09:06:26.855+00', NULL, NULL, NULL, NULL);
INSERT INTO public.signage_items VALUES ('b523e5aa-3866-4e6a-b0d4-276c7833419e', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'SIG-BIRM27-033', 33, 'Registration desk wrap', 'Registration desk wrap for UKCW Birmingham 2027.', '9e546d36-5534-4d7b-9d3b-bf222925d037', NULL, NULL, 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, NULL, NULL, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, '66b1f369-20d5-4e19-ac48-8140e5716008', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-10-19 09:06:28.058202+00', '2026-10-19 09:06:28.058202+00', 'sponsorship_item', 'sponsor', '[{"stepId": "c5a21c20-802c-4cb7-ba7f-59d62bce5278", "userId": null}, {"stepId": "863e7cba-b57d-44e7-a6ad-c5c21a30e4a2", "userId": null}]', '2027-02-16', NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('63281dff-62d3-4698-8c77-cfcafd1d6565', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '00ff34cb-a06c-49a6-9e7e-10a701b881ca', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, 'e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', NULL, 'open', NULL, NULL, NULL, NULL, '2026-10-19 09:06:27.822987+00', '2026-10-19 09:06:27.822987+00', NULL);


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('7a0f06a4-82ab-4666-976d-6d93fcdc5754', '51f03b45-5154-4f51-8ca9-175d0668629b', 'Logo on 6 hanging banners', 6, '2026-10-19 09:06:27.117679+00', '2026-10-19 09:06:27.117679+00', NULL);
INSERT INTO public.sponsor_entitlements VALUES ('eefa0ad3-69dc-4ea0-baee-6450ba9472e7', '51f03b45-5154-4f51-8ca9-175d0668629b', 'Entrance feature branding', 1, '2026-10-19 09:06:27.119983+00', '2026-10-19 09:06:27.119983+00', NULL);
INSERT INTO public.sponsor_entitlements VALUES ('471c5883-c46c-4158-8beb-cc3a74c50c4f', '640a87e5-8d7f-4385-a71d-3dd6b96b2358', 'Seminar theatre branding', 1, '2026-10-19 09:06:27.123968+00', '2026-10-19 09:06:27.123968+00', NULL);


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('51f03b45-5154-4f51-8ca9-175d0668629b', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-10-19 09:06:27.113429+00', '2026-10-19 09:06:27.113429+00', NULL, NULL, NULL, NULL);
INSERT INTO public.sponsors VALUES ('640a87e5-8d7f-4385-a71d-3dd6b96b2358', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-10-19 09:06:27.122103+00', '2026-10-19 09:06:27.122103+00', NULL, NULL, NULL, NULL);


--
-- Data for Name: sponsorship_package_lines; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: sponsorship_packages; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: staff_invites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('d17b24b4-aec9-40ca-beb1-031f3b26caa0', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'fb30a663-922b-477f-b934-1009acecc6f1', 'STD-BIRM27-A10', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-10-13 09:06:26.855+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.132129+00', '2026-10-19 09:06:28.132129+00');
INSERT INTO public.stand_submissions VALUES ('82bf9066-8c86-4e16-9362-c1e84c8bc5c3', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '63ad82f5-53d7-4350-84b1-ac3f961f624d', 'STD-BIRM27-A20', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-10-13 09:06:26.855+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.151677+00', '2026-10-19 09:06:28.151677+00');
INSERT INTO public.stand_submissions VALUES ('e48b7492-02fc-4a2b-bcb7-300ec0f69423', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '47b37ee8-a45a-411e-8f9b-86851ff3dbe4', 'STD-BIRM27-A30', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-10-13 09:06:26.855+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.169521+00', '2026-10-19 09:06:28.169521+00');
INSERT INTO public.stand_submissions VALUES ('e876aa84-e0ca-42dc-b339-047c7e97bd81', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'f1c6932f-060a-463c-a94d-6ebcb13f3f77', 'STD-BIRM27-B10', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-10-13 09:06:26.855+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.188632+00', '2026-10-19 09:06:28.188632+00');
INSERT INTO public.stand_submissions VALUES ('d6506afd-0e9b-486b-9c04-7adb30a3c3fa', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '1436f1aa-29eb-4ae0-b1e5-50fd8b9ddaf1', 'STD-BIRM27-B20', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-10-13 09:06:26.855+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 1, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.207189+00', '2026-10-19 09:06:28.207189+00');
INSERT INTO public.stand_submissions VALUES ('6a60a61e-e56f-4b51-b623-3e9d1cbdcc08', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'c646f23e-2630-402f-b4e6-b7ce1efc5728', 'STD-BIRM27-B30', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.224335+00', '2026-10-19 09:06:28.224335+00');
INSERT INTO public.stand_submissions VALUES ('33883232-5ba9-49ae-a3c7-810b7d71b4c0', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'bb178b28-bd7f-4492-a789-5966e2b14695', 'STD-BIRM27-C10', 'becd360b-3e1f-4a36-affb-2e831fbd28c5', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.228335+00', '2026-10-19 09:06:28.228335+00');
INSERT INTO public.stand_submissions VALUES ('6e11cd1f-b1b5-462a-aed2-6fce542fb4cf', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', '3cd13acd-8467-4d33-959e-341011e85ec3', 'STD-BIRM27-C20', '2a6012e7-719c-4d3c-8592-0c57c3d430b6', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, '0599df28-0d78-4897-9f4b-f0b562d96770', 0, '00000000-0000-4000-8000-000000000002', '2026-10-19 09:06:28.231821+00', '2026-10-19 09:06:28.231821+00');


--
-- Data for Name: supplier_service_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_service_links VALUES ('e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', '37689933-0199-4772-b49e-f6ca8a39c30f');
INSERT INTO public.supplier_service_links VALUES ('e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', 'ff3b36d3-a9de-41de-96e0-b05323a2ef1b');
INSERT INTO public.supplier_service_links VALUES ('5f0db669-2891-45f7-8589-df9041474277', 'e35e27c5-f85c-49c0-a8ed-7fd4e0933daa');
INSERT INTO public.supplier_service_links VALUES ('5f0db669-2891-45f7-8589-df9041474277', 'ff3b36d3-a9de-41de-96e0-b05323a2ef1b');
INSERT INTO public.supplier_service_links VALUES ('5f0db669-2891-45f7-8589-df9041474277', '9447f92d-85cc-495d-b6a5-f67d97aad143');
INSERT INTO public.supplier_service_links VALUES ('3b97cc34-a985-4c19-8998-da867b5f4089', '526f2db9-fa4a-4bc7-b17c-dbef0c396f8c');
INSERT INTO public.supplier_service_links VALUES ('3b97cc34-a985-4c19-8998-da867b5f4089', '9447f92d-85cc-495d-b6a5-f67d97aad143');


--
-- Data for Name: supplier_services; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_services VALUES ('37689933-0199-4772-b49e-f6ca8a39c30f', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Signage print', 1, false, '2026-10-19 09:06:27.083112+00', '2026-10-19 09:06:27.083112+00');
INSERT INTO public.supplier_services VALUES ('526f2db9-fa4a-4bc7-b17c-dbef0c396f8c', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Digital screens & AV', 2, false, '2026-10-19 09:06:27.085773+00', '2026-10-19 09:06:27.085773+00');
INSERT INTO public.supplier_services VALUES ('e35e27c5-f85c-49c0-a8ed-7fd4e0933daa', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Rigging', 3, false, '2026-10-19 09:06:27.087545+00', '2026-10-19 09:06:27.087545+00');
INSERT INTO public.supplier_services VALUES ('ff3b36d3-a9de-41de-96e0-b05323a2ef1b', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Installation', 4, false, '2026-10-19 09:06:27.08931+00', '2026-10-19 09:06:27.08931+00');
INSERT INTO public.supplier_services VALUES ('9447f92d-85cc-495d-b6a5-f67d97aad143', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Staffing', 5, false, '2026-10-19 09:06:27.090927+00', '2026-10-19 09:06:27.090927+00');
INSERT INTO public.supplier_services VALUES ('c9441dfe-0b9a-48ee-9641-bfe1ae7c76e4', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Furniture', 6, false, '2026-10-19 09:06:27.092175+00', '2026-10-19 09:06:27.092175+00');
INSERT INTO public.supplier_services VALUES ('bccf4f1b-1688-49b4-83e7-f9fd479aad30', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Structural engineering', 7, false, '2026-10-19 09:06:27.093427+00', '2026-10-19 09:06:27.093427+00');
INSERT INTO public.supplier_services VALUES ('f936036d-777d-4047-aa42-c9c840cf07af', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Floor Manager', 8, false, '2026-10-19 09:06:27.094591+00', '2026-10-19 09:06:27.094591+00');
INSERT INTO public.supplier_services VALUES ('f2c25ad4-8dd9-4988-bac3-3b043934d0e7', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Security', 9, false, '2026-10-19 09:06:27.095596+00', '2026-10-19 09:06:27.095596+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('e17a3e8e-adbe-4bc0-9f1e-700c3ce6f959', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-10-19 09:06:27.073827+00', '2026-10-19 09:06:27.073827+00', false);
INSERT INTO public.suppliers VALUES ('5f0db669-2891-45f7-8589-df9041474277', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-10-19 09:06:27.07746+00', '2026-10-19 09:06:27.07746+00', false);
INSERT INTO public.suppliers VALUES ('3b97cc34-a985-4c19-8998-da867b5f4089', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-10-19 09:06:27.080807+00', '2026-10-19 09:06:27.080807+00', false);


--
-- Data for Name: task_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tasks VALUES ('9a7093ca-9725-459c-9279-f6787f4cc858', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Chase NEC about rigging slot confirmation', 'The rigging plan needs the venue''s slot confirmation before install week.', 'open', '2026-10-26', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'signage_item', '6923569b-db88-4fa3-a354-e9f957b750df', NULL, '2026-10-19 09:06:28.239592+00', '2026-10-19 09:06:28.239592+00', NULL);
INSERT INTO public.tasks VALUES ('f1917715-d638-44c0-ad9c-c94c80ee6fb3', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Finalise the Hall 1 wayfinding plan', NULL, 'in_progress', '2026-10-29', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-19 09:06:28.241875+00', '2026-10-19 09:06:28.241875+00', NULL);
INSERT INTO public.tasks VALUES ('c223f369-92fc-415e-9810-26bd45fd82cc', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Walk the hall with the venue', NULL, 'done', '2026-10-14', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, '2026-10-19 09:06:26.855+00', '2026-10-19 09:06:28.242996+00', '2026-10-19 09:06:28.242996+00', 'f1917715-d638-44c0-ad9c-c94c80ee6fb3');
INSERT INTO public.tasks VALUES ('6f3d7a19-501b-409f-af4e-8954fc4a59c6', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'c6642c0f-d1c2-4621-9be1-f69fa4823fc4', 'Send sign positions to the printer', NULL, 'open', '2026-10-18', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', NULL, NULL, NULL, '2026-10-19 09:06:28.242996+00', '2026-10-19 09:06:28.242996+00', 'f1917715-d638-44c0-ad9c-c94c80ee6fb3');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.921882+00', '2026-10-19 09:06:26.921882+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.930931+00', '2026-10-19 09:06:26.930931+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.934195+00', '2026-10-19 09:06:26.934195+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.937008+00', '2026-10-19 09:06:26.937008+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.940443+00', '2026-10-19 09:06:26.940443+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-10-19 09:06:26.942615+00', '2026-10-19 09:06:26.942615+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.27946+00', '2026-10-19 09:06:27.27946+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.294259+00', '2026-10-19 09:06:27.294259+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.301981+00', '2026-10-19 09:06:27.301981+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.309432+00', '2026-10-19 09:06:27.309432+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.318322+00', '2026-10-19 09:06:27.318322+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-10-19 09:06:27.387792+00', '2026-10-19 09:06:27.387792+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('aa91d7e6-b38a-4827-9ac5-fcc3c8115023', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-10-19 09:06:26.959139+00', '2026-10-19 09:06:26.959139+00');
INSERT INTO public.venue_rules VALUES ('54dce46c-49ba-42a2-9312-29f88c044989', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-10-19 09:06:26.963054+00', '2026-10-19 09:06:26.963054+00');
INSERT INTO public.venue_rules VALUES ('b13b96f7-f932-496b-9858-89d466fd47f8', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-10-19 09:06:26.967206+00', '2026-10-19 09:06:26.967206+00');
INSERT INTO public.venue_rules VALUES ('0c9cab9a-ed37-4e56-9454-3ca2583801e6', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-10-19 09:06:26.97105+00', '2026-10-19 09:06:26.97105+00');
INSERT INTO public.venue_rules VALUES ('e76a89c5-4d7a-499d-9728-265feff6a340', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-10-19 09:06:26.975679+00', '2026-10-19 09:06:26.975679+00');
INSERT INTO public.venue_rules VALUES ('4b13d30c-22a9-47a4-b7ac-c6f99d5747b9', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-10-19 09:06:26.980869+00', '2026-10-19 09:06:26.980869+00');
INSERT INTO public.venue_rules VALUES ('6a2c9f2b-2094-43fd-a0ae-f364587c2c08', '4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-10-19 09:06:26.98467+00', '2026-10-19 09:06:26.98467+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('4b703a8d-eee7-4631-9a06-8f80c0cfcf98', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-10-19 09:06:26.947842+00', '2026-10-19 09:06:26.947842+00', false);
INSERT INTO public.venues VALUES ('cc75a6b1-07b0-480b-b501-671c62afa552', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-10-19 09:06:26.952207+00', '2026-10-19 09:06:26.952207+00', false);


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('91f2c365-b7e7-400b-86d5-5fad84231266', '66b1f369-20d5-4e19-ac48-8140e5716008', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-10-19 09:06:27.134448+00', '2026-10-19 09:06:27.134448+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('55cd6807-3182-4e67-857d-394a7e765acb', '66b1f369-20d5-4e19-ac48-8140e5716008', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-10-19 09:06:27.13719+00', '2026-10-19 09:06:27.13719+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('1a3828a6-d242-4816-a533-5ac6fd15b604', '66b1f369-20d5-4e19-ac48-8140e5716008', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-10-19 09:06:27.13864+00', '2026-10-19 09:06:27.13864+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('08af7b7b-90fe-4e63-85c0-0f9d3e41411a', '66b1f369-20d5-4e19-ac48-8140e5716008', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-19 09:06:27.139921+00', '2026-10-19 09:06:27.139921+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('7c123770-a5c0-45a8-acd7-e0b7b9624642', '699b5827-b294-41ef-8184-5751885d4647', 4, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-19 09:06:28.089336+00', '2026-10-19 09:06:28.094891+00', '{organiser,sponsor}', false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1');
INSERT INTO public.workflow_steps VALUES ('db7303d7-94fc-4d5a-bcbb-cc837d82ee0a', '0599df28-0d78-4897-9f4b-f0b562d96770', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-10-19 09:06:27.219941+00', '2026-10-19 09:06:27.219941+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('4c2095a3-13aa-4351-8a77-d0cf66e3ec56', '0599df28-0d78-4897-9f4b-f0b562d96770', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-10-19 09:06:27.222257+00', '2026-10-19 09:06:27.222257+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('ef124f44-2a40-4a76-a434-adf247e0e6af', '0599df28-0d78-4897-9f4b-f0b562d96770', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-10-19 09:06:27.223873+00', '2026-10-19 09:06:27.223873+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('a44c9b80-6fe2-4907-8eb0-402fc6eee0ec', '0599df28-0d78-4897-9f4b-f0b562d96770', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-10-19 09:06:27.225715+00', '2026-10-19 09:06:27.225715+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('98f921a2-df71-4531-8163-8d7616c0ccc5', '0599df28-0d78-4897-9f4b-f0b562d96770', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-10-19 09:06:27.227689+00', '2026-10-19 09:06:27.227689+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('08502d14-ae0f-44ee-ae44-5fae48b42f3a', '0599df28-0d78-4897-9f4b-f0b562d96770', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-10-19 09:06:27.230008+00', '2026-10-19 09:06:27.230008+00', '{}', false, NULL);
INSERT INTO public.workflow_steps VALUES ('c5a21c20-802c-4cb7-ba7f-59d62bce5278', '66b1f369-20d5-4e19-ac48-8140e5716008', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 09:06:27.128812+00', '2026-10-19 09:06:28.077621+00', '{organiser,sponsor}', false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5');
INSERT INTO public.workflow_steps VALUES ('863e7cba-b57d-44e7-a6ad-c5c21a30e4a2', '66b1f369-20d5-4e19-ac48-8140e5716008', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 09:06:27.131561+00', '2026-10-19 09:06:28.078741+00', '{organiser,sponsor}', false, '44d37811-42b8-4679-9304-e8f36a38324e');
INSERT INTO public.workflow_steps VALUES ('381934b8-309c-437b-91e4-98998eeccca5', '66b1f369-20d5-4e19-ac48-8140e5716008', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 5, true, true, '2026-10-19 09:06:27.132995+00', '2026-10-19 09:06:28.079665+00', '{sponsor}', false, 'c619690e-4922-4ffd-969b-ea2993d9f172');
INSERT INTO public.workflow_steps VALUES ('33fb9f31-34cb-4b6f-b12f-c2a8f1c1541f', '66b1f369-20d5-4e19-ac48-8140e5716008', 5, NULL, 'Senior management sign-off', 'approval', 'user', NULL, '00000000-0000-4000-8000-000000000005', '{always}', 3, true, true, '2026-10-19 09:06:27.135759+00', '2026-10-19 09:06:28.080622+00', '{organiser,sponsor}', false, '855f43e1-cc51-40b5-afe8-6b37dac07cd1');
INSERT INTO public.workflow_steps VALUES ('b49ec007-5f18-4a8b-b6a3-0f961f3ea51c', '699b5827-b294-41ef-8184-5751885d4647', 1, 1, 'Operations sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 09:06:28.082622+00', '2026-10-19 09:06:28.09104+00', '{organiser,sponsor}', false, 'b64e1d1f-f7ac-41e0-8b9b-0f83407eece5');
INSERT INTO public.workflow_steps VALUES ('f99235ba-8071-4e1d-a732-55706e4ceba4', '699b5827-b294-41ef-8184-5751885d4647', 2, 1, 'Marketing sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 09:06:28.083923+00', '2026-10-19 09:06:28.092424+00', '{organiser,sponsor}', false, '44d37811-42b8-4679-9304-e8f36a38324e');
INSERT INTO public.workflow_steps VALUES ('f23ad645-082d-4e56-b4fa-1504388840c4', '699b5827-b294-41ef-8184-5751885d4647', 3, 1, 'Sales sign-off', 'approval', 'role', NULL, NULL, '{always}', 3, true, true, '2026-10-19 09:06:28.085402+00', '2026-10-19 09:06:28.093647+00', '{sponsor}', false, 'c619690e-4922-4ffd-969b-ea2993d9f172');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('66b1f369-20d5-4e19-ac48-8140e5716008', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Signage default', 'signage', true, false, '2026-10-19 09:06:27.126409+00', '2026-10-19 09:06:27.126409+00', NULL);
INSERT INTO public.workflows VALUES ('0599df28-0d78-4897-9f4b-f0b562d96770', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Stand default', 'stand', true, false, '2026-10-19 09:06:27.217991+00', '2026-10-19 09:06:27.217991+00', NULL);
INSERT INTO public.workflows VALUES ('699b5827-b294-41ef-8184-5751885d4647', 'db972e39-ec2b-4b3c-b5eb-43603ea24e55', 'Stand design sign-off', 'signage', false, false, '2026-10-19 09:06:28.07309+00', '2026-10-19 09:06:28.07309+00', 'stand_design');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 14, true);


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
-- Name: sponsorship_package_lines sponsorship_package_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_package_lines
    ADD CONSTRAINT sponsorship_package_lines_pkey PRIMARY KEY (id);


--
-- Name: sponsorship_packages sponsorship_packages_id_edition_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_id_edition_unique UNIQUE (id, edition_id);


--
-- Name: sponsorship_packages sponsorship_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_pkey PRIMARY KEY (id);


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
-- Name: approvers_main_on_accept_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approvers_main_on_accept_by_idx ON public.approvers USING btree (main_on_accept_by);


--
-- Name: approvers_one_main; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approvers_one_main ON public.approvers USING btree (department_id) WHERE is_main;


--
-- Name: approvers_one_main_on_accept; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approvers_one_main_on_accept ON public.approvers USING btree (department_id) WHERE main_on_accept;


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
-- Name: notifications_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_edition_idx ON public.notifications USING btree (edition_id);


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
-- Name: sponsor_entitlements_from_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsor_entitlements_from_package_idx ON public.sponsor_entitlements USING btree (from_package_id);


--
-- Name: sponsor_entitlements_sponsor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsor_entitlements_sponsor_idx ON public.sponsor_entitlements USING btree (sponsor_id);


--
-- Name: sponsors_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsors_edition_idx ON public.sponsors USING btree (edition_id);


--
-- Name: sponsors_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsors_package_idx ON public.sponsors USING btree (package_id);


--
-- Name: sponsorship_package_lines_package_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsorship_package_lines_package_idx ON public.sponsorship_package_lines USING btree (package_id, sort_order);


--
-- Name: sponsorship_packages_edition_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sponsorship_packages_edition_idx ON public.sponsorship_packages USING btree (edition_id, sort_order);


--
-- Name: sponsorship_packages_edition_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sponsorship_packages_edition_name_unique ON public.sponsorship_packages USING btree (edition_id, lower(name));


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
-- Name: sponsorship_package_lines sponsorship_package_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsorship_package_lines_set_updated_at BEFORE UPDATE ON public.sponsorship_package_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sponsorship_packages sponsorship_packages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sponsorship_packages_set_updated_at BEFORE UPDATE ON public.sponsorship_packages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: approvers approvers_main_on_accept_by_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvers
    ADD CONSTRAINT approvers_main_on_accept_by_users_id_fk FOREIGN KEY (main_on_accept_by) REFERENCES public.users(id) ON DELETE SET NULL;


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
-- Name: notifications notifications_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id) ON DELETE SET NULL;


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
-- Name: sponsor_entitlements sponsor_entitlements_from_package_id_sponsorship_packages_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsor_entitlements
    ADD CONSTRAINT sponsor_entitlements_from_package_id_sponsorship_packages_id_fk FOREIGN KEY (from_package_id) REFERENCES public.sponsorship_packages(id);


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
-- Name: sponsors sponsors_package_same_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors
    ADD CONSTRAINT sponsors_package_same_event_fk FOREIGN KEY (package_id, edition_id) REFERENCES public.sponsorship_packages(id, edition_id);


--
-- Name: sponsorship_package_lines sponsorship_package_lines_package_id_sponsorship_packages_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_package_lines
    ADD CONSTRAINT sponsorship_package_lines_package_id_sponsorship_packages_id_fk FOREIGN KEY (package_id) REFERENCES public.sponsorship_packages(id) ON DELETE CASCADE;


--
-- Name: sponsorship_packages sponsorship_packages_edition_id_editions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsorship_packages
    ADD CONSTRAINT sponsorship_packages_edition_id_editions_id_fk FOREIGN KEY (edition_id) REFERENCES public.editions(id);


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
-- Name: sponsorship_package_lines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsorship_package_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: sponsorship_packages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sponsorship_packages ENABLE ROW LEVEL SECURITY;

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

\unrestrict mfu4AgospXzdHsGjR4qPrKJuw4yhKDFwfvrmfCanLP92LgepBBaCJzVMVGdUv0Q

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
