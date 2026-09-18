--
-- PostgreSQL database dump
--


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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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


--
-- Data for Name: approval_instances; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.approval_instances VALUES ('79bedb68-0ecd-4316-bdf0-25cd376dc9e1', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('071539f9-eb2e-4437-b840-3aad18309bb8', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('0b4148ba-0621-4c2b-b151-3a5d9a5eefa2', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1bdc8024-a6db-4106-95c2-fbf538b9f320', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('dc67de12-5e84-47b1-8234-b84d5985a439', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'waiting', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('20d8b052-b5ad-46d5-aff9-2916c463152c', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('c59431c9-af3e-4ac7-8300-959176110501', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('8e4f4516-37fc-4458-bacd-c794d343feea', 'signage_item', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.282489+00', '2026-09-18 13:21:21.282489+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('6dc1fa5f-96c6-47fe-82c5-e56fb26b61eb', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('4af18784-b433-432f-9709-2dfc2f65167f', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('59d0ba53-c385-4619-ba39-814f9524b631', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('fbf19504-8e21-4073-8600-e5439bfdbb93', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('95bad893-d5b6-4910-b934-7d26904bb010', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('457fdf54-47ec-490d-acb8-28c209205d21', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('86c546bb-cfde-44bc-81df-eab38376d5ea', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('56bd3d8c-074a-4513-b56d-ccaecb83adff', 'signage_item', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.301709+00', '2026-09-18 13:21:21.301709+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5b57ab15-921e-4819-a809-9c5af03d65a5', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-08 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-06 13:21:21.074+00', '2026-09-09 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3c8dcd16-495f-48e4-8be6-9262e863cfd4', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-08 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-06 13:21:21.074+00', '2026-09-11 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('b15977fb-3ec7-4cb7-8874-d15250c667db', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-08 13:21:21.074+00', '2026-09-14 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('255b9992-a67a-4890-9e9a-6774ac0517c5', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('722c2a4e-280e-4432-ac85-abb6604d9a49', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('33cc0e5a-a467-474d-b867-b36b21c44be3', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('38d71d66-72b4-4286-b0de-9febb0ae75eb', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a19f3e65-bbbe-4dd9-aa60-a930dce56c44', 'signage_item', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.321128+00', '2026-09-18 13:21:21.321128+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1fcaf6ae-8edd-4221-a09a-1f0093f5c94b', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('72e77190-1708-4fe2-b5ce-ce850ee2f5c8', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6e37ebe6-6423-4417-898e-aa37418f6841', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b4c21d0f-518f-486c-9169-0ec1bedb0b64', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('308dc1c5-81e2-4bf4-8182-18b244dbce15', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('6f88c456-ab1a-4787-94e2-40835e50a5e2', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('8f84335f-384c-48a8-9424-5da076c5e233', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5fa78cb7-2698-4949-aff9-7ab36448bba1', 'signage_item', '17698db9-5eec-4349-9466-254352c486e0', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.335814+00', '2026-09-18 13:21:21.335814+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('77312116-5254-4733-82b5-cfa7b9ad0269', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('cff21fb8-49ee-4e1d-b929-bf4b20946e75', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6e0ae97d-fcd6-49fd-bef5-3b769dba540d', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2cdd9188-15b4-41c4-aa64-237b9a92432b', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('ec155126-c07e-4da4-984d-e7f11f78db02', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('727547fc-808b-494a-a312-e47b58424626', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('cce1029d-d401-489d-8ada-016e0da8c0cd', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3b053259-f932-4877-ae65-cf14632f4302', 'signage_item', '0101d403-92e7-4332-88fa-afc0251141d1', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.353553+00', '2026-09-18 13:21:21.353553+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('485745fa-901d-4df4-954d-c5259431a98d', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-08 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-06 13:21:21.074+00', '2026-09-09 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('f8c9998d-35c5-4919-a005-69a4896cba1e', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('e23957b3-93b8-49de-8d67-358500043f89', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-08 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-08 13:21:21.074+00', '2026-09-11 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d64b708f-cc45-4c5b-9fe3-1695943a950e', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('93457654-9c06-4b51-976b-36516e4717ed', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'pending', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-08 13:21:21.074+00', '2026-09-14 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9499acad-c436-45fa-9838-88bda28989d1', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('c7c3e8b1-1860-441e-95cd-9b2ca5386998', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('de42f244-a10f-4be5-ad2e-c3f9f9bb3913', 'signage_item', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.368663+00', '2026-09-18 13:21:21.368663+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('283f624a-3e9d-48c0-aeb4-92f6ac37fc49', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0ea68a42-86d6-4560-8223-e58c13eb3cd9', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('9e50fbe0-8101-4356-b95c-830ea147121d', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7ffa95c8-5e50-4d9d-8e20-1539c3a50c51', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'pending', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('39eec7cb-d8f2-49b7-84b4-0fbd36a71a1d', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('35056916-c4d8-46e1-826d-b5914f2e5683', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('0b6da0d4-c0e3-4dfe-a8c2-3dd6392dff45', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f042ecd4-da15-4fd9-9cf8-a69e7f40c378', 'signage_item', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.383007+00', '2026-09-18 13:21:21.383007+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('b3dbadd2-9454-45df-829b-36cae1b0d58b', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('25b30256-c986-4a92-b90c-abe61c54464b', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('379f5e07-094c-4991-9ab8-edd68542e7c2', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('d31753c4-9c72-4f70-a36e-7204f7ef2472', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('78809e45-4f67-4219-81fe-f464fc6d2f95', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('bda7828c-8c79-4172-bbea-57b68b0cb5fe', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7efa7d33-ead5-4621-91d9-6e3aec44e132', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('e9c57f6d-f6b3-4b1a-bc80-af150a7fa663', 'signage_item', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.396039+00', '2026-09-18 13:21:21.396039+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('638a1c85-992b-4c0f-8c2c-9f6b4aa41795', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c06cb4c0-f287-477e-a88f-bacb5d52df66', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'approved_with_conditions', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 13:21:21.074+00', NULL, 'Amend per attached notes before install.', 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('138d35e9-4c58-42e1-aa39-664910d11334', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7107bb31-bd31-44fa-a941-5aae5558d218', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('c2ec1216-9b6e-4846-b4ec-08677cd7a1a6', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3778fc40-5849-4c0f-8b28-a15e3ec285e9', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('fc20947b-f475-4ccb-b525-410bc6bba684', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('15873d5c-ed49-40b8-918d-445f386e3411', 'signage_item', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.410256+00', '2026-09-18 13:21:21.410256+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('cc098bac-7cf7-4c31-b5ac-08cc2bec1f78', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e435b6a9-95df-4426-875b-a2881e77ea06', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('97aa1618-9f24-482a-92e4-3d3e28464c12', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ac9f8161-4eec-46d0-a0a2-8eaf9d32c5dd', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('d204c1ff-1b57-4bff-81dc-4d28e482cce9', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('30216bbc-7cfa-42c6-84ad-b27336592f72', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f6340715-c04e-45c7-b886-a29f6cf56e66', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3334e89e-c771-445d-b028-abb535c4e8f2', 'signage_item', 'af643de0-462e-4912-9580-32618678f41a', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.426474+00', '2026-09-18 13:21:21.426474+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('617b4e22-bc33-4f00-9fdb-227d3fbd5705', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ab123456-c5cc-4f06-8346-89f58b52d27b', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('f5b3391f-ae90-4024-bf9b-989072675116', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('57b16f25-4bbd-4359-ac2c-21e68bdc2106', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('923fabc0-8f2c-412d-a9de-36000c1ee4f3', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ce7c086b-afb3-4404-94b0-27c5e88a6c17', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f581c6b8-cdcf-44ad-95a7-efa4dff7f053', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'pending', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('fdc9904b-1c2e-400a-875d-fe6a6bd58dac', 'signage_item', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.438554+00', '2026-09-18 13:21:21.438554+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('1bf652c8-e2cd-44a7-9477-9274196fe883', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('6f0954aa-10ee-4586-8328-94c9926e7453', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6b8d724b-4d97-4b81-8eb9-784e2ee2a2f8', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c94b97fd-486c-40c2-bb2b-e6ce02103e79', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('515728ba-9a8a-4cdc-8a54-f4061ddf208b', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('cca2719c-0f57-4b50-aced-1b623771b470', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('0a0f7e7f-b946-4372-b492-1b1faf2ed3f2', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('d5845ff7-be61-4e78-bc4d-a3aacdc1cec2', 'signage_item', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.452371+00', '2026-09-18 13:21:21.452371+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('dcbcce6d-53e0-47e7-9107-bdb256bcbe34', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a483764c-eead-4455-8e9b-c75a0e80535d', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('eb1d0637-0727-4ce2-a626-64fa5301b217', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('b6844de1-7136-42d9-9d07-975b2bba3827', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('f9362537-7a1d-40a0-a7ff-329b57e9dccb', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'approved', 'event_director', NULL, NULL, '00000000-0000-4000-8000-000000000005', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5e436acd-46a8-4306-ae31-71de33e9b6cc', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('82f53a6e-40ad-418f-a698-5856ac825d7f', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('c5c1243e-8111-4123-a57a-bcca1e9b51b8', 'signage_item', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.464313+00', '2026-09-18 13:21:21.464313+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('cd197582-b7df-4cc0-ab68-a93390805055', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c16b829e-6c1f-4e56-bbf0-1fd2e2550493', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('146a69cf-d7ca-4038-b76f-5f29a9e16977', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e85477d8-fa02-4406-abd4-cc3441722989', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('67212ff1-d138-40e2-8780-cbf5d4123eb8', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5de91191-2784-4fc3-98ae-cd382608ec6d', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('4aae0e59-fe7f-4c19-b3be-c46b1c614aeb', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('2264de0d-30fe-4e77-be8f-d5223449cb86', 'signage_item', 'a9afb4e3-3072-48d5-9277-211709056071', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.476047+00', '2026-09-18 13:21:21.476047+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a323e54e-a7f8-4a03-9e6f-e9c1abe19398', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('1024e01e-6d4b-480d-9c70-064b11814573', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('61711a64-058d-492e-b3a1-2c47104ea34f', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('397182f4-1849-4908-bbcf-52da5b3c70d5', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('522d495e-d31d-43bc-b382-a7e79b916abe', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9230d9b1-d8d7-4d1c-9a9f-8992bb02307c', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('30c55bec-a82f-4cba-a4c6-b12b46b89072', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('99cde730-ed24-4001-aeea-cc9e526ea958', 'signage_item', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.490155+00', '2026-09-18 13:21:21.490155+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('0cbaeda0-b87b-407d-ad46-f6f301a97563', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('e03d069f-1e0e-4b55-9dc2-e97eeb9592a1', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('4897c910-c98d-409e-8490-81f6d86d859b', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('cbb79fc5-d92a-4ab7-bafa-2cfac0304ae3', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('98b6fa9b-8d55-4ddd-9954-b813ba598308', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('17dd9852-f2cb-4f58-8b38-752821553547', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-17 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('17d90ae3-de97-4209-9a64-95598ebd82cc', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'confirmed', 'supplier', NULL, NULL, '00000000-0000-4000-8000-000000000014', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('77258c7c-8dcb-4b0e-81fd-3bda5d696900', 'signage_item', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'confirmed', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.504079+00', '2026-09-18 13:21:21.504079+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('05b050a0-e607-4bd7-b9a0-64f60e946be9', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'rejected', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', 'Does not meet the brand guidelines.', NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('ae19bb0e-d442-46f3-94a3-a21581093bd1', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('d40f1e3e-bcea-4691-aca7-c4a54ccacf1a', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('7c7cff05-7a47-43b8-830c-e32754e38652', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('dde1995b-9f9f-4779-98b2-b7c051bdc3c4', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9141a72d-9635-45a0-8d21-b83d0379bc4b', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('f658eb34-6974-4e91-a70c-430ba58827d2', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('22c422dc-b7d9-4843-8518-16ef51f8ed7e', 'signage_item', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.516928+00', '2026-09-18 13:21:21.516928+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('4935df79-b35f-4ced-832a-4d6f716093f2', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('68bc6a9d-44d5-4897-bb16-b7921dbb7c17', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('14519b4c-30af-439c-9dca-909bf5259f5a', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('868d79f4-7e4f-426b-add6-eb35f874dd6b', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9657b65b-f502-4f72-b584-72c234dc6c40', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3309c3a3-216f-4832-8c8f-f363aaa4e764', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('31ecb34e-0883-4d2d-944e-ada77e7f6009', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a66233f1-0d5e-4e78-bd54-196c84841246', 'signage_item', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.529173+00', '2026-09-18 13:21:21.529173+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('55b51a26-e09e-4bb8-889f-4bf22099bf56', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'invalidated', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('730f38d8-4546-4865-8470-fabbe0f2be68', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'pending', 'marketing', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 13:21:21.074+00', '2026-09-20 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('19e9b455-067a-44e4-b04d-de5c1e7de6b9', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'invalidated', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('c5b8e6ee-8422-47c9-a0c7-0feebde709ba', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'pending', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-17 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('6e06f841-42fe-4ea9-97a6-49aa9ecd4f21', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'invalidated', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('2d9a3356-e2a7-42b5-91cc-8efedc375f52', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('904546e8-4244-4725-a5f1-89a9f7d1e15f', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('efaa9924-6bf6-4d46-8101-4a27d1db1f41', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('5b24493d-3350-48a6-8da9-cafd6ec4cbe9', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('5a8cadd7-24b4-4bbb-9eee-5ba37d6ab6eb', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('3ae1e659-4194-49eb-b666-7b3fe15b1d92', 'signage_item', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.544391+00', '2026-09-18 13:21:21.544391+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('5ef3d9d8-8c06-4d66-86d2-8b2a47e1a836', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'changes_requested', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', 'Please revise — see comments.', NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('181cfb74-f811-4350-9c85-4c43f31e549f', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'skipped', 'sales', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('988e695a-0998-4916-89be-b5830b3a9f46', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('0690727b-0ee8-4004-8b84-35662caae027', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'skipped', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6bdd936c-5fb9-4273-971e-7895c9f2ff5e', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'skipped', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('17314757-8d5e-4942-8503-9aa9adabceec', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('75ef56ed-912e-429a-bd59-8d44c2b05608', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('4faf77ff-0746-4fe8-b8da-d36bb6220181', 'signage_item', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.585146+00', '2026-09-18 13:21:21.585146+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('9462cb5b-7b8e-4fd0-8f88-ba1dff6f4da3', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, '88eff8c9-9d3d-4be2-a772-2566110c5cda', 'Marketing brand check', 'approval', 1, 1, 'approved', 'marketing', NULL, NULL, '00000000-0000-4000-8000-000000000003', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('08fa6501-d597-40c7-9bd9-047eca3b4615', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, 'db269dc8-b2d4-4a17-a507-2ce6a719836b', 'Sponsor approval', 'approval', 2, 1, 'approved', 'sales', NULL, NULL, '00000000-0000-4000-8000-000000000004', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-13 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('52d6789d-6b97-4d5a-ad5d-4d2db26cbb24', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, 'f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'Ops technical check', 'approval', 3, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('cffeda21-310a-4d17-84a6-6daf2f2334c3', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, '04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-15 13:21:21.074+00', NULL, NULL, 'artwork_version', NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-22 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('8eac839a-2a0b-4cc6-9fd6-9d21f9fed663', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, 'e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'Event Director sign-off', 'approval', 5, NULL, 'pending', 'event_director', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-15 13:21:21.074+00', '2026-09-18 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('9f3642a7-d6d1-4819-a1ae-6d1865d325a9', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, '908ed962-6a58-4efc-9878-b523219b8194', 'Sent to print', 'confirmation', 6, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('e77b6373-b660-4070-b045-d903b8f7b63d', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, '36e4407e-6bba-4982-86c1-26e124cedaa0', 'Delivered', 'confirmation', 7, NULL, 'waiting', 'supplier', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('49a7d69c-86b4-4a20-8f15-86a6e42d1b03', 'signage_item', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, 'c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'Installed', 'confirmation', 8, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.597876+00', '2026-09-18 13:21:21.597876+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('2c96b5dd-f491-44a8-b5b2-4bc37e614bc1', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, '0e5560b0-7327-4565-84b9-883ed7c07ee9', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-12 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('3feab668-05af-4b71-89fa-faf6ffbd559b', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, '3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'Structural engineer review', 'approval', 2, NULL, 'pending', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-14 13:21:21.074+00', '2026-09-21 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('06d87c62-1707-44f8-89cb-27d7184442c3', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, '3b83bd0c-ad58-4f86-b74d-0fce52692925', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('d80a2743-8c8d-4728-92af-eb8c2eb2dec1', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, 'a14332e2-3376-4682-895f-8243b2e535b8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('6768d722-dc16-4b14-a9e4-856b7e8c1010', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, '9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('ffa3effc-1e15-40f8-af76-3cf00af733d2', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 1, '10519af4-6085-4836-89b8-1dc875154392', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('74eddb1c-52ea-4f6c-bd97-e8720b06384d', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, '0e5560b0-7327-4565-84b9-883ed7c07ee9', 'Ops completeness and rules check', 'approval', 1, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-12 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('c8ebb462-1d77-4e8a-a55b-a5b2519bdce3', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, '3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('c2aad0b0-7e89-4799-a553-ca75bbcffbcb', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, '3b83bd0c-ad58-4f86-b74d-0fce52692925', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('62656c44-4f3c-4908-88e5-70378562b655', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, 'a14332e2-3376-4682-895f-8243b2e535b8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('a5c1e20b-5393-4142-ac15-0682c7ea4a61', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, '9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('a7fdc2a0-0d33-450e-9259-c2a603596788', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 1, '10519af4-6085-4836-89b8-1dc875154392', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('15df5468-6249-4f75-8ef8-64dd34587287', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, '0e5560b0-7327-4565-84b9-883ed7c07ee9', 'Ops completeness and rules check', 'approval', 1, NULL, 'changes_requested', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', 'Structural calculations are missing for the raised floor.', NULL, 'submission_version', '1', NULL, '2026-09-12 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('608bef4c-b273-4750-b3f7-8d0b4f17c216', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, '3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('80181e9a-d831-43c6-901f-64c3c5fc42c0', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, '3b83bd0c-ad58-4f86-b74d-0fce52692925', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'waiting', 'hs', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('e41f6e38-5a0e-42c0-a876-3c6b46086133', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, 'a14332e2-3376-4682-895f-8243b2e535b8', 'Venue approval', 'approval', 4, NULL, 'waiting', 'venue', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('9791714c-9097-4c4e-a7db-1c1315a059a8', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, '9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'Ops final outcome', 'approval', 5, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('79f30551-ec61-42d9-ab91-59944509ab52', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 1, '10519af4-6085-4836-89b8-1dc875154392', 'Onsite build check', 'confirmation', 6, NULL, 'waiting', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('a786e37e-32cd-4fd5-95ee-687dce77408b', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, '0e5560b0-7327-4565-84b9-883ed7c07ee9', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-12 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('847cf16b-2ca8-4624-952f-6380f03d3e32', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, '3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('b85f5f0b-e93d-44c6-83e1-5d02b51902ec', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, '3b83bd0c-ad58-4f86-b74d-0fce52692925', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-19 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('78a50104-faa5-47dd-9be7-9a5f8534f615', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, 'a14332e2-3376-4682-895f-8243b2e535b8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-21 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('37b322ec-4666-4cc4-9268-0886b125035f', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, '9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'Ops final outcome', 'approval', 5, NULL, 'approved_with_conditions', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', NULL, 'Handrail detail to be verified onsite before opening.', 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('7247e934-bd6f-4b64-a362-c2cfaaac8614', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 1, '10519af4-6085-4836-89b8-1dc875154392', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-14 13:21:21.074+00', '2026-09-14 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00', false, true, 0, false);
INSERT INTO public.approval_instances VALUES ('f55a950a-ac25-4084-a6c8-86dd28ff699c', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, '0e5560b0-7327-4565-84b9-883ed7c07ee9', 'Ops completeness and rules check', 'approval', 1, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-12 13:21:21.074+00', '2026-09-15 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', true, true, 3, false);
INSERT INTO public.approval_instances VALUES ('a0c86858-64ed-4417-b0c8-c2365844da69', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, '3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'Structural engineer review', 'approval', 2, NULL, 'skipped', 'structural_engineer', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('cd3aa288-e5e2-4295-9d63-f27dce29cccb', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, '3b83bd0c-ad58-4f86-b74d-0fce52692925', 'H&S review (RAMS, insurance)', 'approval', 3, NULL, 'approved', 'hs', NULL, NULL, '00000000-0000-4000-8000-000000000013', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-19 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', true, true, 5, false);
INSERT INTO public.approval_instances VALUES ('06097728-db47-488f-8082-4b4d5a036220', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, 'a14332e2-3376-4682-895f-8243b2e535b8', 'Venue approval', 'approval', 4, NULL, 'approved', 'venue', NULL, NULL, '00000000-0000-4000-8000-000000000011', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-21 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', true, true, 7, false);
INSERT INTO public.approval_instances VALUES ('1a5ccb58-5514-4ff2-bbed-cce911711c1b', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, '9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'Ops final outcome', 'approval', 5, NULL, 'approved', 'ops', NULL, NULL, '00000000-0000-4000-8000-000000000002', '2026-09-14 13:21:21.074+00', NULL, NULL, 'submission_version', '1', NULL, '2026-09-14 13:21:21.074+00', '2026-09-16 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', true, true, 2, false);
INSERT INTO public.approval_instances VALUES ('29cf9256-fbf7-4f17-8dca-afd3b0522625', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 1, '10519af4-6085-4836-89b8-1dc875154392', 'Onsite build check', 'confirmation', 6, NULL, 'pending', 'ops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-09-14 13:21:21.074+00', '2026-09-14 13:21:21.074+00', 0, NULL, NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00', false, true, 0, false);


--
-- Data for Name: artwork_annotations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: artwork_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.artwork_versions VALUES ('4a6d270f-508d-4292-81cd-d579304c6eff', 'c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 1, 'seed/SIG-BIRM27-001-v1.pdf', 'SIG-BIRM27-001-v1.pdf', 'application/pdf', 38, '581714c7a9aa680b6514a19e094a9158f8fc4c3b51db429c853f17ac8043b20c', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.27757+00', '2026-09-18 13:21:21.27757+00');
INSERT INTO public.artwork_versions VALUES ('e47e43ae-6023-4033-a11f-5ea23acdb615', '9e97e6bc-f5b4-4c56-9448-612d81bc270f', 1, 'seed/SIG-BIRM27-002-v1.pdf', 'SIG-BIRM27-002-v1.pdf', 'application/pdf', 37, '2ceba11e2c4e46c76976a3c3ab08a0d7dd06dd64494679e0831329e413c7741b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.298981+00', '2026-09-18 13:21:21.298981+00');
INSERT INTO public.artwork_versions VALUES ('4d92cd6c-fe95-4b64-9b96-57383557e95e', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 1, 'seed/SIG-BIRM27-003-v1.pdf', 'SIG-BIRM27-003-v1.pdf', 'application/pdf', 35, '46977b64309320203c34eb95a101b3458b54610a575fefbf5f544b98fd376cc7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'draft', NULL, '2026-09-18 13:21:21.317545+00', '2026-09-18 13:21:21.317545+00');
INSERT INTO public.artwork_versions VALUES ('be3e4520-4c8e-4b4b-8f11-ee5db948e38a', 'b3688fcc-8a99-4495-ba9a-23f2be370504', 2, 'seed/SIG-BIRM27-003-v2.pdf', 'SIG-BIRM27-003-v2.pdf', 'application/pdf', 35, '79ac611073ce1e8f0475e08d665a5a71267518975c9eeefdee248423b9b0b2e7', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.318902+00', '2026-09-18 13:21:21.318902+00');
INSERT INTO public.artwork_versions VALUES ('06dd72d0-ee9a-460c-8cc1-7ed96899d1c3', '17698db9-5eec-4349-9466-254352c486e0', 1, 'seed/SIG-BIRM27-004-v1.pdf', 'SIG-BIRM27-004-v1.pdf', 'application/pdf', 39, '4ba3b13baf86c5bf8503561cfce90fe8cb1fe06c00b70062f229087d87dc9f10', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.333817+00', '2026-09-18 13:21:21.333817+00');
INSERT INTO public.artwork_versions VALUES ('a42e47f9-050c-496d-8de3-f8817ede4b90', '0101d403-92e7-4332-88fa-afc0251141d1', 1, 'seed/SIG-BIRM27-005-v1.pdf', 'SIG-BIRM27-005-v1.pdf', 'application/pdf', 39, 'd184918ea4729ae48a6cbec9a2978f244661dbe74295cd0ce9063b5294281fbc', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.351662+00', '2026-09-18 13:21:21.351662+00');
INSERT INTO public.artwork_versions VALUES ('a045ff19-2e84-4be7-b451-18cabc33b4d6', '502779cf-4e02-454a-bd99-dc8424fb1592', 1, 'seed/SIG-BIRM27-006-v1.pdf', 'SIG-BIRM27-006-v1.pdf', 'application/pdf', 31, '82160f7807c9a16af5777935200eb4c6702640a27a12cc1ed2887344b1582700', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.366868+00', '2026-09-18 13:21:21.366868+00');
INSERT INTO public.artwork_versions VALUES ('94895de5-c87b-410f-af01-68c92fe848f3', 'c4a1e111-db42-4763-9c29-1b242dce0a06', 1, 'seed/SIG-BIRM27-007-v1.pdf', 'SIG-BIRM27-007-v1.pdf', 'application/pdf', 35, '413d9b389d00a7618b5b53e11615b0fc1eac391f62e91834d0c530452ed04b3d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.381183+00', '2026-09-18 13:21:21.381183+00');
INSERT INTO public.artwork_versions VALUES ('44226770-2cdd-4e26-b6c8-3ff4f44f527e', '3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 1, 'seed/SIG-BIRM27-008-v1.pdf', 'SIG-BIRM27-008-v1.pdf', 'application/pdf', 35, 'd69a901d0771ac69b77e8d098894fa9e1462dc9fbab7ccf6da67f85f3a7bbe86', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.393982+00', '2026-09-18 13:21:21.393982+00');
INSERT INTO public.artwork_versions VALUES ('d097178f-75a9-4101-89cc-349cbb03cba3', '346f10cc-4295-4b83-b817-d0fddd887ecd', 1, 'seed/SIG-BIRM27-009-v1.pdf', 'SIG-BIRM27-009-v1.pdf', 'application/pdf', 44, '45b48a6f3ad6fe04640615d2ba991a97274dbc19a258aeefdfb2a31f5fdea077', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.408536+00', '2026-09-18 13:21:21.408536+00');
INSERT INTO public.artwork_versions VALUES ('b8482dc4-d44f-4ce5-86ae-8f739173d0f8', 'af643de0-462e-4912-9580-32618678f41a', 1, 'seed/SIG-BIRM27-010-v1.pdf', 'SIG-BIRM27-010-v1.pdf', 'application/pdf', 42, '7b2d48219e9ec69fe14cc2ca27dfca250e0c01cd9c96ecf483074b8e6124ac14', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.424795+00', '2026-09-18 13:21:21.424795+00');
INSERT INTO public.artwork_versions VALUES ('ab48c351-e4a5-4fad-8580-70d28102c057', 'dbc2c242-50af-4851-aca1-6ebf19a09151', 1, 'seed/SIG-BIRM27-011-v1.pdf', 'SIG-BIRM27-011-v1.pdf', 'application/pdf', 36, '4861e664d6b8334b7655862437baab6e3a783c5232455000494cbf921ef9e27d', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.43701+00', '2026-09-18 13:21:21.43701+00');
INSERT INTO public.artwork_versions VALUES ('4104b7d1-6ed4-4e43-adaa-acf24c4ee0bc', 'c5ed600d-1073-47d2-afca-56e41fae400c', 1, 'seed/SIG-BIRM27-012-v1.pdf', 'SIG-BIRM27-012-v1.pdf', 'application/pdf', 37, '835c6fc371b7f635ae1d39c3b1e29ceecbad8fc92d98bd44d3af2201b4045f80', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.45049+00', '2026-09-18 13:21:21.45049+00');
INSERT INTO public.artwork_versions VALUES ('04e7b610-ed05-4ff6-8cf8-3c66c598989a', '6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 1, 'seed/SIG-BIRM27-013-v1.pdf', 'SIG-BIRM27-013-v1.pdf', 'application/pdf', 39, '34f6afe4e558322dfde465b99bc85a1d7bd35a71fb870b9d502253b51a51e02b', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.462595+00', '2026-09-18 13:21:21.462595+00');
INSERT INTO public.artwork_versions VALUES ('e2be6581-9f2a-4819-bc98-6a34f370e353', 'a9afb4e3-3072-48d5-9277-211709056071', 1, 'seed/SIG-BIRM27-014-v1.pdf', 'SIG-BIRM27-014-v1.pdf', 'application/pdf', 35, '11ab8f68d3c51a3030202e28cc9c0bccc74b0fab6dc270520d28ec966f8341a5', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.474219+00', '2026-09-18 13:21:21.474219+00');
INSERT INTO public.artwork_versions VALUES ('7f2f3ff2-b9ef-4b3c-8dab-c9fe4d051b93', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 1, 'seed/SIG-BIRM27-015-v1.pdf', 'SIG-BIRM27-015-v1.pdf', 'application/pdf', 34, '84ea6e735cbfd9fd052de9f595e0e4f702c0c4cbc3db3a88fc85ebeeec8250cf', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.488599+00', '2026-09-18 13:21:21.488599+00');
INSERT INTO public.artwork_versions VALUES ('9e977154-c0b2-4ed2-9b45-1154323455fe', '4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 1, 'seed/SIG-BIRM27-016-v1.pdf', 'SIG-BIRM27-016-v1.pdf', 'application/pdf', 32, '2d23d8288e17672b12272c74b1c5430e6e966b4deeffd8537f2d1cfbf89bc20d', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.501849+00', '2026-09-18 13:21:21.501849+00');
INSERT INTO public.artwork_versions VALUES ('a1df5b34-d931-4da8-9dae-2b31023211c0', '4b0d0cd0-e0ba-486c-8c28-389f83cad435', 1, 'seed/SIG-BIRM27-017-v1.pdf', 'SIG-BIRM27-017-v1.pdf', 'application/pdf', 39, '2a241d237ec94cb11031c9aec7e869dc2195f83216635b2a6986c0c4537cd895', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.515254+00', '2026-09-18 13:21:21.515254+00');
INSERT INTO public.artwork_versions VALUES ('aecf118f-0531-4ce4-8254-671bcd77150c', '4e08254a-6ecc-413f-a2f4-dfeccf420658', 1, 'seed/SIG-BIRM27-018-v1.pdf', 'SIG-BIRM27-018-v1.pdf', 'application/pdf', 37, 'b90a3997e35e51fcca3126be835eccbcb44adb0d10f562315efda782c49ba009', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.52763+00', '2026-09-18 13:21:21.52763+00');
INSERT INTO public.artwork_versions VALUES ('e9b97f0e-0f5f-4bef-96e6-885f334f36e0', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 1, 'seed/SIG-BIRM27-019-v1.pdf', 'SIG-BIRM27-019-v1.pdf', 'application/pdf', 40, 'c3d113fc3e08ab4218be34d56d4d3f3f88d6d3cf9052d4333c4c22cdc13e1ca5', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-18 13:21:21.540592+00', '2026-09-18 13:21:21.540592+00');
INSERT INTO public.artwork_versions VALUES ('74b2ad95-660c-4d97-b04c-e12f4cb902df', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 2, 'seed/SIG-BIRM27-019-v2.pdf', 'SIG-BIRM27-019-v2.pdf', 'application/pdf', 40, '493b2c4e18b67cd6761468a739ee1891081223cac831975b87c0e40adf43e750', 1, NULL, '00000000-0000-4000-8000-000000000003', 'draft', NULL, '2026-09-18 13:21:21.541569+00', '2026-09-18 13:21:21.541569+00');
INSERT INTO public.artwork_versions VALUES ('a7cdd3f8-2df3-4711-b398-06070c0b2337', '6642459d-0d7e-44b9-9e4c-2a2be0982aba', 3, 'seed/SIG-BIRM27-019-v3.pdf', 'SIG-BIRM27-019-v3.pdf', 'application/pdf', 40, 'd605264fb9218391c3870dd34e5a7d2361648109e3874781ab83dd53bbef3acc', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.542495+00', '2026-09-18 13:21:21.542495+00');
INSERT INTO public.artwork_versions VALUES ('cbdf1101-48c1-482e-b767-905fc441bf09', '06d7b78e-d62d-418d-9e2a-7456659d0ff4', 1, 'seed/SIG-BIRM27-028-v1.pdf', 'SIG-BIRM27-028-v1.pdf', 'application/pdf', 34, 'df85006065910caaf521ec12005026c0deeb4c199b6ae2a5a7067955a823b024', 1, NULL, '00000000-0000-4000-8000-000000000002', 'proof', NULL, '2026-09-18 13:21:21.583269+00', '2026-09-18 13:21:21.583269+00');
INSERT INTO public.artwork_versions VALUES ('9526cf2e-f6c6-4e73-a1af-68a85a916928', '3d3c0434-10e6-44b1-83c8-39aed9e898ba', 1, 'seed/SIG-BIRM27-029-v1.pdf', 'SIG-BIRM27-029-v1.pdf', 'application/pdf', 46, '3cf043662ed0b457a6e13d332535fd4417329b43c98109e2a8a34a523fe477f4', 1, NULL, '00000000-0000-4000-8000-000000000003', 'proof', NULL, '2026-09-18 13:21:21.596083+00', '2026-09-18 13:21:21.596083+00');


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

INSERT INTO public.contractors VALUES ('3a19357b-397d-4dbd-b8e5-56588a804db8', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Stand Builders Ltd', NULL, 'team@standbuilders.test', NULL, '2028-06-30', '2026-09-18 13:21:21.183108+00', '2026-09-18 13:21:21.183108+00');
INSERT INTO public.contractors VALUES ('65e8e271-0d6e-44f8-afa9-6ad621b14016', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Custom Stands Co', NULL, 'info@customstands.test', NULL, '2027-09-15', '2026-09-18 13:21:21.185142+00', '2026-09-18 13:21:21.185142+00');


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.documents VALUES ('7476b128-a938-4ebf-beed-8d2f59f0cb06', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 'plan', 'seed/STD-BIRM27-A10-plan.pdf', 'STD-BIRM27-A10-plan.pdf', 'application/pdf', 19, '7079b744f32a5c161ba55a3f39409e36a8ca6b00c642fde327c3c51307af8ea0', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00');
INSERT INTO public.documents VALUES ('eebe6354-67bc-4d4c-9069-48eb922d1a26', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 'elevation', 'seed/STD-BIRM27-A10-elevation.pdf', 'STD-BIRM27-A10-elevation.pdf', 'application/pdf', 24, 'b10bd34b66551b0a267ecbdceca9ee77c871efe9a9178a9b8f92b961c685258d', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00');
INSERT INTO public.documents VALUES ('1defa2b7-7bce-4613-b48d-a0ed6a778ccd', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 'rams', 'seed/STD-BIRM27-A10-rams.pdf', 'STD-BIRM27-A10-rams.pdf', 'application/pdf', 19, 'e3c8aade8de4a31c7084193ab4882bb63720abb90571b4e329a26670a896e52e', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00');
INSERT INTO public.documents VALUES ('961ae1dc-c7d3-4933-adf5-2c5809b0dfca', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'a6470fc1-6ec4-4e70-9364-2cea39a88a85', 'insurance_pl', 'seed/STD-BIRM27-A10-insurance_pl.pdf', 'STD-BIRM27-A10-insurance_pl.pdf', 'application/pdf', 27, 'cbf2af2a3d98111fadc78e804001245485b84a4739208c0e3c98071818d010ba', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00');
INSERT INTO public.documents VALUES ('15cbf2bd-c29a-46d1-b57b-25893aa4b72f', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 'plan', 'seed/STD-BIRM27-A20-plan.pdf', 'STD-BIRM27-A20-plan.pdf', 'application/pdf', 19, 'c22516467286d3fefe95651d91b3aecc4cb62826ba7a316e2129b0c84d0366b7', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00');
INSERT INTO public.documents VALUES ('474f37b9-ee6d-4254-8d67-e204963d411f', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 'elevation', 'seed/STD-BIRM27-A20-elevation.pdf', 'STD-BIRM27-A20-elevation.pdf', 'application/pdf', 24, '01e14bfecce98375246317d261f0fa295b15bea73949ae1e0574e7b9a3392d75', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00');
INSERT INTO public.documents VALUES ('852db531-4371-45fb-a94c-ef3ed92254e2', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 'rams', 'seed/STD-BIRM27-A20-rams.pdf', 'STD-BIRM27-A20-rams.pdf', 'application/pdf', 19, '61a0188fdec0c4ac0481e0faad0b9f4e573b16228965dca07d9b21c3bd011005', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00');
INSERT INTO public.documents VALUES ('2115e348-3aae-4d6a-b854-fc160d288819', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'd10c1ee3-908b-4938-bc6e-221af2a2fc30', 'insurance_pl', 'seed/STD-BIRM27-A20-insurance_pl.pdf', 'STD-BIRM27-A20-insurance_pl.pdf', 'application/pdf', 27, '4fe6b2b159e42db1851119bb48a543c90a7ab56c6fa16971163c6cd915307942', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00');
INSERT INTO public.documents VALUES ('85e63a19-9f1d-4106-9133-516bf4d37d46', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 'plan', 'seed/STD-BIRM27-A30-plan.pdf', 'STD-BIRM27-A30-plan.pdf', 'application/pdf', 19, '02c622bcbc53f9c3f9533ca31c05490da5b5285bc0daedcee55e749015a5018f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00');
INSERT INTO public.documents VALUES ('395184e0-8128-4cef-8ece-a2dcaa3f8676', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 'elevation', 'seed/STD-BIRM27-A30-elevation.pdf', 'STD-BIRM27-A30-elevation.pdf', 'application/pdf', 24, 'd3cf1779d1419fdf0e68663af204340606bec4ce4684c114b308a1cec6a8299f', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00');
INSERT INTO public.documents VALUES ('b1d6f7e3-d541-496a-8c23-9807b71f1178', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 'rams', 'seed/STD-BIRM27-A30-rams.pdf', 'STD-BIRM27-A30-rams.pdf', 'application/pdf', 19, '5fd6b11ce9422bf1a7ae9425cb8f3cd1191edab35fd9661a092bc3522d3788be', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00');
INSERT INTO public.documents VALUES ('3271b6b6-d517-4351-8e05-aaff851a56cb', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 'insurance_pl', 'seed/STD-BIRM27-A30-insurance_pl.pdf', 'STD-BIRM27-A30-insurance_pl.pdf', 'application/pdf', 27, '24bd66f197b315b6df093d55c0b2ba53ea4e48cd611fbcbeb435bd9edd6df08f', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00');
INSERT INTO public.documents VALUES ('4441062b-6946-49de-a8f5-53f2f52ebadf', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 'plan', 'seed/STD-BIRM27-B10-plan.pdf', 'STD-BIRM27-B10-plan.pdf', 'application/pdf', 19, '968795b0a2e0c1b1692e0765090d7f205e221960f505ede7ac14748ef27fa0d4', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00');
INSERT INTO public.documents VALUES ('076479da-1f35-4ae1-bbc4-72f7d6408541', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 'elevation', 'seed/STD-BIRM27-B10-elevation.pdf', 'STD-BIRM27-B10-elevation.pdf', 'application/pdf', 24, 'ae897d58560da121b22834ff25944b0b651092dd3fb577af1b7cffe638b78784', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00');
INSERT INTO public.documents VALUES ('ef835414-2c1e-4e29-bf44-1ba2e70ca6cf', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 'rams', 'seed/STD-BIRM27-B10-rams.pdf', 'STD-BIRM27-B10-rams.pdf', 'application/pdf', 19, 'f30d1e0b85a09cfcdb988a5e81d2822bff5cc6f34f73fbadeeadde0d40c0bae8', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00');
INSERT INTO public.documents VALUES ('5fe670c6-15f6-4ce2-9945-f6aadd90c77c', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', '20f24aed-02bf-4d83-adc1-2bedb79545a1', 'insurance_pl', 'seed/STD-BIRM27-B10-insurance_pl.pdf', 'STD-BIRM27-B10-insurance_pl.pdf', 'application/pdf', 27, '1d5058f6d4b2b7af60f4ac9a40056d6eb0b92a3396cffa1dc202b33070984ce7', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00');
INSERT INTO public.documents VALUES ('6d184aa8-1381-4c37-a18b-6d69ae1c1c08', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 'plan', 'seed/STD-BIRM27-B20-plan.pdf', 'STD-BIRM27-B20-plan.pdf', 'application/pdf', 19, '9ea022bee49124bb4ef02acd3e9af9415b3048254fd6abaf0fb7e04fa5345c21', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00');
INSERT INTO public.documents VALUES ('df941997-29c7-42dc-95fc-0fa71efd0d6d', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 'elevation', 'seed/STD-BIRM27-B20-elevation.pdf', 'STD-BIRM27-B20-elevation.pdf', 'application/pdf', 24, '795d5eb763ed4b0fa946e8f7ad7424fa0c24b24ade047aa1b949ac2dab21b382', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00');
INSERT INTO public.documents VALUES ('0cd34ebd-a29a-4273-bb80-1550591191c8', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 'rams', 'seed/STD-BIRM27-B20-rams.pdf', 'STD-BIRM27-B20-rams.pdf', 'application/pdf', 19, '59b2aa3231d8d6c4de484ce8bd1f19f8e1a0f2d674c421c3e90a2a108870e11b', 1, NULL, '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00');
INSERT INTO public.documents VALUES ('e2f8066e-0807-4aa9-ab39-e6e5d9b36ba7', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_submission', 'fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 'insurance_pl', 'seed/STD-BIRM27-B20-insurance_pl.pdf', 'STD-BIRM27-B20-insurance_pl.pdf', 'application/pdf', 27, '23b7bb570c50c4743c36a7436194e3bb7fa61aa45e9324cfb5a05f06b9824620', 1, '2027-09-20', '00000000-0000-4000-8000-000000000015', true, 'received', NULL, '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00');


--
-- Data for Name: edition_counters; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_counters VALUES ('55ea9e56-b155-4602-a685-b4048b945b6d', 'b787777a-adde-4647-802f-56676d5025ba', 'signage', 30, '2026-09-18 13:21:21.609977+00', '2026-09-18 13:21:22.618868+00');


--
-- Data for Name: edition_deadlines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.edition_deadlines VALUES ('d55c50d2-70ea-4d38-a4e9-40d94ed716a5', 'b787777a-adde-4647-802f-56676d5025ba', 'stand_design_due', 'Stand designs due', 42, NULL, '2026-09-18 13:21:21.141029+00', '2026-09-18 13:21:22.509108+00');
INSERT INTO public.edition_deadlines VALUES ('7f0c0cb3-3bbd-457d-a0a1-19398811a076', 'b787777a-adde-4647-802f-56676d5025ba', 'insurance_due', 'Insurance documents due', 28, NULL, '2026-09-18 13:21:21.142367+00', '2026-09-18 13:21:22.51063+00');
INSERT INTO public.edition_deadlines VALUES ('236d4453-76a0-4349-98a7-77ef0519a0b8', 'b787777a-adde-4647-802f-56676d5025ba', 'venue_rigging_submission', 'Venue rigging submission', 28, NULL, '2026-09-18 13:21:21.143503+00', '2026-09-18 13:21:22.511576+00');
INSERT INTO public.edition_deadlines VALUES ('fabb2288-f086-430e-8019-1406f736bacf', 'b787777a-adde-4647-802f-56676d5025ba', 'artwork_due', 'Artwork due', 21, NULL, '2026-09-18 13:21:21.144521+00', '2026-09-18 13:21:22.512442+00');
INSERT INTO public.edition_deadlines VALUES ('44f2fa66-28e6-4421-800b-22e5bfedc014', 'b787777a-adde-4647-802f-56676d5025ba', 'print_deadline', 'Print deadline', 14, NULL, '2026-09-18 13:21:21.145441+00', '2026-09-18 13:21:22.513292+00');
INSERT INTO public.edition_deadlines VALUES ('57752e2e-3efb-412e-a417-4fa4e1b91cc9', 'b787777a-adde-4647-802f-56676d5025ba', 'delivery', 'Delivery to venue', 3, NULL, '2026-09-18 13:21:21.146392+00', '2026-09-18 13:21:22.514087+00');


--
-- Data for Name: editions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.editions VALUES ('b787777a-adde-4647-802f-56676d5025ba', 'ad116343-8e6f-4b14-8504-a3ecc7c2daf1', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'UKCW Birmingham 2027', 'BIRM27', '2027-10-01', '2027-10-04', '2027-10-05', '2027-10-07', '2027-10-08', 'planning', NULL, 85000.00, '{plan,elevation,rams,insurance_pl}', '[{"key": "double_deck", "label": "Double deck"}, {"key": "over_4000mm", "label": "Over 4000 mm high"}, {"key": "platform_over_600mm", "label": "Platform or stage over 600 mm"}, {"key": "ramped_raised_floor", "label": "Ramped raised floor"}, {"key": "rigging", "label": "Rigging or suspended items"}, {"key": "ceiling_or_roof", "label": "Ceiling or roof"}, {"key": "tiered_seating", "label": "Tiered seating"}]', '2026-09-18 13:21:21.138999+00', '2026-09-18 13:21:21.138999+00');


--
-- Data for Name: email_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.events VALUES ('ad116343-8e6f-4b14-8504-a3ecc7c2daf1', '26ffafac-2a6a-413d-b489-bf6377546dea', 'UK Construction Week', 'UKCW', '2026-09-18 13:21:21.117995+00', '2026-09-18 13:21:22.49373+00');


--
-- Data for Name: exhibitors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.exhibitors VALUES ('c814dbb5-0d14-4b87-a9e5-a6ea392d54f8', 'b787777a-adde-4647-802f-56676d5025ba', 'Exhibitor Co', 'A10', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 24.00, 'space_only', 'Exhibitor Co events team', 'stand@exhibitorco.test', '3a19357b-397d-4dbd-b8e5-56588a804db8', '2026-09-18 13:21:21.243829+00', '2026-09-18 13:21:21.243829+00');
INSERT INTO public.exhibitors VALUES ('72cf5b12-f8fc-476d-9ba0-40a04709ca73', 'b787777a-adde-4647-802f-56676d5025ba', 'SteelFrame Systems', 'A20', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 30.00, 'space_only', 'SteelFrame Systems events team', 'expo@steelframe.test', '65e8e271-0d6e-44f8-afa9-6ad621b14016', '2026-09-18 13:21:21.246667+00', '2026-09-18 13:21:21.246667+00');
INSERT INTO public.exhibitors VALUES ('65218b38-4dd2-41f7-a6ef-edb906c8b445', 'b787777a-adde-4647-802f-56676d5025ba', 'BrickWorks UK', 'A30', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 36.00, 'space_only', 'BrickWorks UK events team', 'events@brickworks.test', '3a19357b-397d-4dbd-b8e5-56588a804db8', '2026-09-18 13:21:21.248761+00', '2026-09-18 13:21:21.248761+00');
INSERT INTO public.exhibitors VALUES ('41acf345-b894-47f1-8992-a4469fa128b5', 'b787777a-adde-4647-802f-56676d5025ba', 'Timber Trade Ltd', 'B10', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 42.00, 'space_only', 'Timber Trade Ltd events team', 'shows@timbertrade.test', '65e8e271-0d6e-44f8-afa9-6ad621b14016', '2026-09-18 13:21:21.250753+00', '2026-09-18 13:21:21.250753+00');
INSERT INTO public.exhibitors VALUES ('59c0f91a-14f5-468e-9c49-b17785300b44', 'b787777a-adde-4647-802f-56676d5025ba', 'GlassTech', 'B20', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 48.00, 'space_only', 'GlassTech events team', 'marketing@glasstech.test', '3a19357b-397d-4dbd-b8e5-56588a804db8', '2026-09-18 13:21:21.252742+00', '2026-09-18 13:21:21.252742+00');
INSERT INTO public.exhibitors VALUES ('5b86202d-eee7-4511-950c-b69b91ea4b75', 'b787777a-adde-4647-802f-56676d5025ba', 'Insulate Pro', 'B30', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 54.00, 'space_only', 'Insulate Pro events team', 'expo@insulatepro.test', '65e8e271-0d6e-44f8-afa9-6ad621b14016', '2026-09-18 13:21:21.255147+00', '2026-09-18 13:21:21.255147+00');
INSERT INTO public.exhibitors VALUES ('990299bb-5105-4a2e-bde8-cca48fd3ef3f', 'b787777a-adde-4647-802f-56676d5025ba', 'RoofRight', 'C10', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 60.00, 'space_only', 'RoofRight events team', 'events@roofright.test', '3a19357b-397d-4dbd-b8e5-56588a804db8', '2026-09-18 13:21:21.258708+00', '2026-09-18 13:21:21.258708+00');
INSERT INTO public.exhibitors VALUES ('80101c96-a16a-4135-baf6-69a43b25fa1e', 'b787777a-adde-4647-802f-56676d5025ba', 'PlantHire Direct', 'C20', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 66.00, 'space_only', 'PlantHire Direct events team', 'shows@planthire.test', '65e8e271-0d6e-44f8-afa9-6ad621b14016', '2026-09-18 13:21:21.26044+00', '2026-09-18 13:21:21.26044+00');
INSERT INTO public.exhibitors VALUES ('b43ff914-db92-42f2-be13-124858be1a95', 'b787777a-adde-4647-802f-56676d5025ba', 'SafetyFirst PPE', 'D10', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 72.00, 'shell', 'SafetyFirst PPE events team', 'expo@safetyfirst.test', NULL, '2026-09-18 13:21:21.262305+00', '2026-09-18 13:21:21.262305+00');
INSERT INTO public.exhibitors VALUES ('f3ed8d86-1010-4f0a-a390-533fbe1a73db', 'b787777a-adde-4647-802f-56676d5025ba', 'ToolMart Retail', 'D20', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 78.00, 'shell', 'ToolMart Retail events team', 'events@toolmart.test', NULL, '2026-09-18 13:21:21.2643+00', '2026-09-18 13:21:21.2643+00');
INSERT INTO public.exhibitors VALUES ('7dfab7a8-04dc-43ba-a2a6-1de2f9f61b03', 'b787777a-adde-4647-802f-56676d5025ba', 'EcoBuild Materials', 'D30', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 84.00, 'shell', 'EcoBuild Materials events team', 'expo@ecobuild.test', NULL, '2026-09-18 13:21:21.266173+00', '2026-09-18 13:21:21.266173+00');
INSERT INTO public.exhibitors VALUES ('e41956df-c1a8-40d5-80b2-3356f04374db', 'b787777a-adde-4647-802f-56676d5025ba', 'SiteWise Software', 'D40', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 90.00, 'shell', 'SiteWise Software events team', 'hello@sitewise.test', NULL, '2026-09-18 13:21:21.26799+00', '2026-09-18 13:21:21.26799+00');


--
-- Data for Name: exports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: external_grants; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.external_grants VALUES ('1101bf13-f3c1-43e7-829d-ca3910c1c17c', '00000000-0000-4000-8000-000000000011', 'venue@nec.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'venue', 'venue', '5d91fbca-7e35-47df-ae8f-5e45ee657551', NULL, '00000000-0000-4000-8000-000000000001', '2f86d575bd18c035cc84dc8efe5ba1d835368a07c1286246611fd73ab5afa382', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.230238+00', '2026-09-18 13:21:21.230238+00');
INSERT INTO public.external_grants VALUES ('3f485bcb-92c0-4d41-83e1-40bfeb63836f', '00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'structural_engineer', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'f7337373ab722d4b7df723052a0e77ed15a4b6e1a2f37251c89f8e9057b2795b', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.233512+00', '2026-09-18 13:21:21.233512+00');
INSERT INTO public.external_grants VALUES ('7dd774bf-8e1d-49f3-8e92-34a2fc910986', '00000000-0000-4000-8000-000000000013', 'hs@safety.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'hs', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000001', 'd288dfd82c7e5b8545ce839b4ee9cb78dfda32d92011d00516df14bf8f4a4010', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.236216+00', '2026-09-18 13:21:21.236216+00');
INSERT INTO public.external_grants VALUES ('63d4a657-ea6c-4bf7-9dc4-4c8f042aa620', '00000000-0000-4000-8000-000000000014', 'print@bigprint.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'supplier', 'supplier', '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, '00000000-0000-4000-8000-000000000001', 'd99134c399d196d5d74baf6a400ce013a2f0716766541f815978dddec4ec8dd8', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.238973+00', '2026-09-18 13:21:21.238973+00');
INSERT INTO public.external_grants VALUES ('bd1df489-b46c-4e7a-a811-f841fb2bcf89', '00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'sponsor', 'sponsor', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', NULL, '00000000-0000-4000-8000-000000000001', '30f307889fc8a928cca7461a254e9ab16138f76b613a90ce2a4884631734ab08', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.241563+00', '2026-09-18 13:21:21.241563+00');
INSERT INTO public.external_grants VALUES ('0c254b63-898b-4227-8887-89d024e13e14', '00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', '26ffafac-2a6a-413d-b489-bf6377546dea', 'b787777a-adde-4647-802f-56676d5025ba', 'exhibitor', 'exhibitor', 'c814dbb5-0d14-4b87-a9e5-a6ea392d54f8', NULL, '00000000-0000-4000-8000-000000000001', 'a928d070152c282c11028e59d8fb318e5ac3b551bc4396611fb1a7f6ae1f0f47', '2026-09-18 13:21:21.074+00', NULL, '2026-09-18 13:21:21.270831+00', '2026-09-18 13:21:21.270831+00');


--
-- Data for Name: halls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.halls VALUES ('7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'b787777a-adde-4647-802f-56676d5025ba', 'Hall 1', NULL, NULL, NULL, 0, '2026-09-18 13:21:21.148544+00', '2026-09-18 13:21:21.148544+00');
INSERT INTO public.halls VALUES ('18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'b787777a-adde-4647-802f-56676d5025ba', 'Hall 2', NULL, NULL, NULL, 1, '2026-09-18 13:21:21.15053+00', '2026-09-18 13:21:21.15053+00');


--
-- Data for Name: item_types; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.item_types VALUES ('2a54ef73-23ad-4acf-8612-8798a6c344e9', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Hanging banner', 'hanging_banner', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'rigged', true, 0, '2026-09-18 13:21:21.215743+00', '2026-09-18 13:21:22.540001+00');
INSERT INTO public.item_types VALUES ('6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Foamex board', 'foamex_board', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'wall_mounted', false, 1, '2026-09-18 13:21:21.217303+00', '2026-09-18 13:21:22.541844+00');
INSERT INTO public.item_types VALUES ('d3e8b530-d5c7-4327-bdc1-338a24cc045a', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Fabric graphic', 'fabric_graphic', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'shell_mounted', false, 2, '2026-09-18 13:21:21.218319+00', '2026-09-18 13:21:22.543132+00');
INSERT INTO public.item_types VALUES ('ac0e4e8d-91db-4e20-8d10-b6acf31efa14', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Floor vinyl', 'floor_vinyl', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'floor', false, 3, '2026-09-18 13:21:21.219423+00', '2026-09-18 13:21:22.544448+00');
INSERT INTO public.item_types VALUES ('ec77b0d3-06fd-4b6c-a32b-855af277699b', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Aisle sign', 'aisle_sign', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'rigged', true, 4, '2026-09-18 13:21:21.220455+00', '2026-09-18 13:21:22.545653+00');
INSERT INTO public.item_types VALUES ('020d652d-a2aa-4354-810a-3d9bc90cfdf4', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Entrance feature', 'entrance_feature', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'freestanding', true, 5, '2026-09-18 13:21:21.221526+00', '2026-09-18 13:21:22.546867+00');
INSERT INTO public.item_types VALUES ('b3bdc8c8-074b-4787-a748-df3edf7b9f60', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Registration', 'registration', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'freestanding', false, 6, '2026-09-18 13:21:21.222708+00', '2026-09-18 13:21:22.548039+00');
INSERT INTO public.item_types VALUES ('ddf0e319-1963-4880-bce0-c413dcf1645c', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Seminar theatre', 'seminar_theatre', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'freestanding', false, 7, '2026-09-18 13:21:21.223747+00', '2026-09-18 13:21:22.549748+00');
INSERT INTO public.item_types VALUES ('ec3089f5-4664-4066-b90a-f79402df76ed', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Feature area', 'feature_area', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'freestanding', false, 8, '2026-09-18 13:21:21.224705+00', '2026-09-18 13:21:22.550864+00');
INSERT INTO public.item_types VALUES ('94bcbbca-f1c6-41a2-adca-05208c736a42', '26ffafac-2a6a-413d-b489-bf6377546dea', 'External', 'external', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'freestanding', true, 9, '2026-09-18 13:21:21.225724+00', '2026-09-18 13:21:22.551915+00');
INSERT INTO public.item_types VALUES ('7ff13093-0cdb-4663-9fa4-f18ef8c381bb', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Digital screen', 'digital_screen', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 'digital', false, 10, '2026-09-18 13:21:21.226758+00', '2026-09-18 13:21:22.552963+00');


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.locations VALUES ('239b833b-5097-4685-ac18-836e4869b865', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Main entrance', 'North', 0.10000, 0.05000, NULL, '2026-09-18 13:21:21.152913+00', '2026-09-18 13:21:21.152913+00');
INSERT INTO public.locations VALUES ('8889c425-c75b-44e5-bfaf-dbac2e02e91f', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Registration', 'North', 0.20000, 0.10000, NULL, '2026-09-18 13:21:21.154954+00', '2026-09-18 13:21:21.154954+00');
INSERT INTO public.locations VALUES ('c1f92c76-cba7-494f-9a4c-bd954d1303d8', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Central aisle A', 'Centre', 0.50000, 0.50000, NULL, '2026-09-18 13:21:21.1569+00', '2026-09-18 13:21:21.1569+00');
INSERT INTO public.locations VALUES ('3f2efaa5-7e62-43b9-ae37-29c4c3e517ef', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Seminar theatre 1', 'East', 0.80000, 0.30000, NULL, '2026-09-18 13:21:21.158936+00', '2026-09-18 13:21:21.158936+00');
INSERT INTO public.locations VALUES ('765a8aac-5aab-4056-a8cc-5f09f4a2d0a3', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Catering court', 'South', 0.40000, 0.85000, NULL, '2026-09-18 13:21:21.160825+00', '2026-09-18 13:21:21.160825+00');
INSERT INTO public.locations VALUES ('ef03d1db-a886-40b4-9b8f-95fd84313a1c', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'Feature area', 'Centre', 0.55000, 0.40000, NULL, '2026-09-18 13:21:21.162687+00', '2026-09-18 13:21:21.162687+00');
INSERT INTO public.locations VALUES ('7191ffbf-bac9-42c2-b1cb-3c1d8dbfd2ba', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'Hall 2 entrance', 'West', 0.05000, 0.50000, NULL, '2026-09-18 13:21:21.164758+00', '2026-09-18 13:21:21.164758+00');
INSERT INTO public.locations VALUES ('cd094d99-85d8-4d88-ba7c-b9101777db13', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'Central aisle B', 'Centre', 0.50000, 0.45000, NULL, '2026-09-18 13:21:21.166516+00', '2026-09-18 13:21:21.166516+00');
INSERT INTO public.locations VALUES ('0cf3917e-d862-4183-ac0c-4e8d4edb8441', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'Seminar theatre 2', 'East', 0.85000, 0.60000, NULL, '2026-09-18 13:21:21.168409+00', '2026-09-18 13:21:21.168409+00');
INSERT INTO public.locations VALUES ('bd87ffd0-1159-493d-bd28-07c3a988c12b', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'Networking lounge', 'South', 0.30000, 0.80000, NULL, '2026-09-18 13:21:21.170062+00', '2026-09-18 13:21:21.170062+00');
INSERT INTO public.locations VALUES ('59ad1ac2-e1a8-42ba-848a-b0de13489d7c', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'External approach', 'Outside', 0.50000, 0.02000, NULL, '2026-09-18 13:21:21.171748+00', '2026-09-18 13:21:21.171748+00');
INSERT INTO public.locations VALUES ('e139f1c5-3229-4659-b392-4e7d91c9ba0f', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'Link corridor', 'North', 0.50000, 0.95000, NULL, '2026-09-18 13:21:21.173538+00', '2026-09-18 13:21:21.173538+00');


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.memberships VALUES ('e9dc9648-3166-4053-a147-e07b930a4b1b', '00000000-0000-4000-8000-000000000001', '26ffafac-2a6a-413d-b489-bf6377546dea', 'admin', '2026-09-18 13:21:21.104943+00', '2026-09-18 13:21:21.104943+00');
INSERT INTO public.memberships VALUES ('02d43532-d1d0-43ab-b1c6-9f658f16753b', '00000000-0000-4000-8000-000000000002', '26ffafac-2a6a-413d-b489-bf6377546dea', 'ops', '2026-09-18 13:21:21.107969+00', '2026-09-18 13:21:21.107969+00');
INSERT INTO public.memberships VALUES ('70d35271-b595-4012-89cb-24fdfded2b37', '00000000-0000-4000-8000-000000000003', '26ffafac-2a6a-413d-b489-bf6377546dea', 'marketing', '2026-09-18 13:21:21.109966+00', '2026-09-18 13:21:21.109966+00');
INSERT INTO public.memberships VALUES ('ffd5d946-069f-4981-aa2a-a9121680501e', '00000000-0000-4000-8000-000000000004', '26ffafac-2a6a-413d-b489-bf6377546dea', 'sales', '2026-09-18 13:21:21.112491+00', '2026-09-18 13:21:21.112491+00');
INSERT INTO public.memberships VALUES ('ad822289-821c-4c8d-a89b-1a105eaaaece', '00000000-0000-4000-8000-000000000005', '26ffafac-2a6a-413d-b489-bf6377546dea', 'event_director', '2026-09-18 13:21:21.114733+00', '2026-09-18 13:21:21.114733+00');
INSERT INTO public.memberships VALUES ('54d9c6ff-80fe-4cf2-a44a-daf2400787fe', '00000000-0000-4000-8000-000000000006', '26ffafac-2a6a-413d-b489-bf6377546dea', 'viewer', '2026-09-18 13:21:21.11685+00', '2026-09-18 13:21:21.11685+00');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: organisations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.organisations VALUES ('26ffafac-2a6a-413d-b489-bf6377546dea', 'Media10', 'media10', 'Hall Pass', NULL, '{"currency": "GBP", "escalate_after_days": 2, "install_photo_required": true, "cost_threshold_for_director": 5000}', '2026-09-18 13:21:21.0999+00', '2026-09-18 13:21:22.478399+00');


--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: signage_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.signage_items VALUES ('c2f7f5f6-d55f-430b-9799-bb87aa8fad6f', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-001', 1, 'Main entrance arch banner', 'Main entrance arch banner for UKCW Birmingham 2027.', '020d652d-a2aa-4354-810a-3d9bc90cfdf4', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '239b833b-5097-4685-ac18-836e4869b865', 'marketing', '00000000-0000-4000-8000-000000000003', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', '9e144312-5787-4dcd-bc11-c9021178f7d5', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 12000.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '4a6d270f-508d-4292-81cd-d579304c6eff', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.27482+00', '2026-09-18 13:21:21.279784+00');
INSERT INTO public.signage_items VALUES ('9e97e6bc-f5b4-4c56-9448-612d81bc270f', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-002', 2, 'Registration desk fascia', 'Registration desk fascia for UKCW Birmingham 2027.', 'b3bdc8c8-074b-4787-a748-df3edf7b9f60', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '8889c425-c75b-44e5-bfaf-dbac2e02e91f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 1800.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'e47e43ae-6023-4033-a11f-5ea23acdb615', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.296964+00', '2026-09-18 13:21:21.300212+00');
INSERT INTO public.signage_items VALUES ('b3688fcc-8a99-4495-ba9a-23f2be370504', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-003', 3, 'Aisle A hanging banner', 'Aisle A hanging banner for UKCW Birmingham 2027.', '2a54ef73-23ad-4acf-8612-8798a6c344e9', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'c1f92c76-cba7-494f-9a4c-bd954d1303d8', 'ops', '00000000-0000-4000-8000-000000000002', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', 'de033850-a142-4718-b104-12201ad6a7d5', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'be3e4520-4c8e-4b4b-8f11-ee5db948e38a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.315588+00', '2026-09-18 13:21:21.320042+00');
INSERT INTO public.signage_items VALUES ('17698db9-5eec-4349-9466-254352c486e0', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-004', 4, 'Seminar theatre 1 backdrop', 'Seminar theatre 1 backdrop for UKCW Birmingham 2027.', 'ddf0e319-1963-4880-bce0-c413dcf1645c', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '3f2efaa5-7e62-43b9-ae37-29c4c3e517ef', 'marketing', '00000000-0000-4000-8000-000000000003', 'd2c9b31c-0465-4350-b177-40854f4db19d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 3200.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '06dd72d0-ee9a-460c-8cc1-7ed96899d1c3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.332043+00', '2026-09-18 13:21:21.334838+00');
INSERT INTO public.signage_items VALUES ('0101d403-92e7-4332-88fa-afc0251141d1', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-005', 5, 'Catering court floor vinyl', 'Catering court floor vinyl for UKCW Birmingham 2027.', 'ac0e4e8d-91db-4e20-8d10-b6acf31efa14', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '765a8aac-5aab-4056-a8cc-5f09f4a2d0a3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 900.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'changes_requested', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'a42e47f9-050c-496d-8de3-f8817ede4b90', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.349994+00', '2026-09-18 13:21:21.352628+00');
INSERT INTO public.signage_items VALUES ('502779cf-4e02-454a-bd99-dc8424fb1592', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-006', 6, 'Feature area totem', 'Feature area totem for UKCW Birmingham 2027.', 'ec3089f5-4664-4066-b90a-f79402df76ed', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'ef03d1db-a886-40b4-9b8f-95fd84313a1c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, true, NULL, 8000.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'a045ff19-2e84-4be7-b451-18cabc33b4d6', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.36531+00', '2026-09-18 13:21:21.367773+00');
INSERT INTO public.signage_items VALUES ('c4a1e111-db42-4763-9c29-1b242dce0a06', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-007', 7, 'Hall 2 entrance banner', 'Hall 2 entrance banner for UKCW Birmingham 2027.', '2a54ef73-23ad-4acf-8612-8798a6c344e9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '7191ffbf-bac9-42c2-b1cb-3c1d8dbfd2ba', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2100.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '94895de5-c87b-410f-af01-68c92fe848f3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.379821+00', '2026-09-18 13:21:21.382069+00');
INSERT INTO public.signage_items VALUES ('3403a9c0-9a59-4028-92b2-06c2c7e0b78d', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-008', 8, 'Aisle B hanging banner', 'Aisle B hanging banner for UKCW Birmingham 2027.', 'ec77b0d3-06fd-4b6c-a32b-855af277699b', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'cd094d99-85d8-4d88-ba7c-b9101777db13', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 1500.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'approved', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '44226770-2cdd-4e26-b6c8-3ff4f44f527e', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.392577+00', '2026-09-18 13:21:21.394972+00');
INSERT INTO public.signage_items VALUES ('346f10cc-4295-4b83-b817-d0fddd887ecd', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-009', 9, 'Seminar theatre 2 entrance sign', 'Seminar theatre 2 entrance sign for UKCW Birmingham 2027.', 'ddf0e319-1963-4880-bce0-c413dcf1645c', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '0cf3917e-d862-4183-ac0c-4e8d4edb8441', 'marketing', '00000000-0000-4000-8000-000000000003', 'd2c9b31c-0465-4350-b177-40854f4db19d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2800.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'approved_with_conditions', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'd097178f-75a9-4101-89cc-349cbb03cba3', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.407168+00', '2026-09-18 13:21:21.409472+00');
INSERT INTO public.signage_items VALUES ('af643de0-462e-4912-9580-32618678f41a', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-010', 10, 'Networking lounge fabric wall', 'Networking lounge fabric wall for UKCW Birmingham 2027.', 'd3e8b530-d5c7-4327-bdc1-338a24cc045a', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'bd87ffd0-1159-493d-bd28-07c3a988c12b', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 3600.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'in_production', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'b8482dc4-d44f-4ce5-86ae-8f739173d0f8', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.42351+00', '2026-09-18 13:21:21.425668+00');
INSERT INTO public.signage_items VALUES ('dbc2c242-50af-4851-aca1-6ebf19a09151', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-011', 11, 'External approach flags', 'External approach flags for UKCW Birmingham 2027.', '94bcbbca-f1c6-41a2-adca-05208c736a42', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '59ad1ac2-e1a8-42ba-848a-b0de13489d7c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 4200.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_production', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'ab48c351-e4a5-4fad-8580-70d28102c057', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.43586+00', '2026-09-18 13:21:21.437794+00');
INSERT INTO public.signage_items VALUES ('c5ed600d-1073-47d2-afca-56e41fae400c', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-012', 12, 'Link corridor wayfinding', 'Link corridor wayfinding for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'e139f1c5-3229-4659-b392-4e7d91c9ba0f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 700.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'delivered', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '4104b7d1-6ed4-4e43-adaa-acf24c4ee0bc', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.449201+00', '2026-09-18 13:21:21.451518+00');
INSERT INTO public.signage_items VALUES ('6f01bf2d-1fce-4eba-8355-8bf55abebc4f', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-013', 13, 'Registration totem screens', 'Registration totem screens for UKCW Birmingham 2027.', '7ff13093-0cdb-4663-9fa4-f18ef8c381bb', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '8889c425-c75b-44e5-bfaf-dbac2e02e91f', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 5200.00, NULL, NULL, '88a3aeeb-a45f-45c6-b857-3f452c17f78c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'delivered', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '04e7b610-ed05-4ff6-8cf8-3c66c598989a', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.461426+00', '2026-09-18 13:21:21.463544+00');
INSERT INTO public.signage_items VALUES ('a9afb4e3-3072-48d5-9277-211709056071', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-014', 14, 'Hall 1 aisle signs set', 'Hall 1 aisle signs set for UKCW Birmingham 2027.', 'ec77b0d3-06fd-4b6c-a32b-855af277699b', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'c1f92c76-cba7-494f-9a4c-bd954d1303d8', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 3900.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'installed', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'e2be6581-9f2a-4819-bc98-6a34f370e353', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.472912+00', '2026-09-18 13:21:21.475051+00');
INSERT INTO public.signage_items VALUES ('9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-015', 15, 'Catering signage pack', 'Catering signage pack for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '765a8aac-5aab-4056-a8cc-5f09f4a2d0a3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 1100.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'snagged', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '7f2f3ff2-b9ef-4b3c-8dab-c9fe4d051b93', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.487427+00', '2026-09-18 13:21:21.489391+00');
INSERT INTO public.signage_items VALUES ('4a1a94ae-be4d-46d0-9e9d-0c0b9ee15339', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-016', 16, 'Sponsor wall Hall 1', 'Sponsor wall Hall 1 for UKCW Birmingham 2027.', 'ec3089f5-4664-4066-b90a-f79402df76ed', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'ef03d1db-a886-40b4-9b8f-95fd84313a1c', 'marketing', '00000000-0000-4000-8000-000000000003', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 2600.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'closed', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '9e977154-c0b2-4ed2-9b45-1154323455fe', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.500688+00', '2026-09-18 13:21:21.503068+00');
INSERT INTO public.signage_items VALUES ('4b0d0cd0-e0ba-486c-8c28-389f83cad435', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-017', 17, 'Gantry banner over aisle C', 'Gantry banner over aisle C for UKCW Birmingham 2027.', '2a54ef73-23ad-4acf-8612-8798a6c344e9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'cd094d99-85d8-4d88-ba7c-b9101777db13', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2000.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'rejected', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'a1df5b34-d931-4da8-9dae-2b31023211c0', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.513937+00', '2026-09-18 13:21:21.516121+00');
INSERT INTO public.signage_items VALUES ('4e08254a-6ecc-413f-a2f4-dfeccf420658', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-018', 18, 'VIP lounge entrance sign', 'VIP lounge entrance sign for UKCW Birmingham 2027.', 'd3e8b530-d5c7-4327-bdc1-338a24cc045a', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'bd87ffd0-1159-493d-bd28-07c3a988c12b', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'shell_mounted', NULL, false, false, NULL, 1400.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'on_hold', 'in_review', 'Awaiting sponsor confirmation', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'aecf118f-0531-4ce4-8254-671bcd77150c', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.526299+00', '2026-09-18 13:21:21.528441+00');
INSERT INTO public.signage_items VALUES ('6642459d-0d7e-44b9-9e4c-2a2be0982aba', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-019', 19, 'BuildCo banner — north hall', 'BuildCo banner — north hall for UKCW Birmingham 2027.', '2a54ef73-23ad-4acf-8612-8798a6c344e9', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'c1f92c76-cba7-494f-9a4c-bd954d1303d8', 'marketing', '00000000-0000-4000-8000-000000000003', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', 'de033850-a142-4718-b104-12201ad6a7d5', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'rigged', NULL, true, false, NULL, 2400.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'a7cdd3f8-2df3-4711-b398-06070c0b2337', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.539027+00', '2026-09-18 13:21:21.543373+00');
INSERT INTO public.signage_items VALUES ('6b312db5-9d27-43e0-b59b-730bcdb29dd3', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-020', 20, 'Organiser office door signs', 'Organiser office door signs for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'e139f1c5-3229-4659-b392-4e7d91c9ba0f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 300.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.556181+00', '2026-09-18 13:21:21.556181+00');
INSERT INTO public.signage_items VALUES ('3686ca31-2442-4f9e-b566-2a7987752d45', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-021', 21, 'Cloakroom signage', 'Cloakroom signage for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '8889c425-c75b-44e5-bfaf-dbac2e02e91f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 250.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'awaiting_artwork', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.558982+00', '2026-09-18 13:21:21.558982+00');
INSERT INTO public.signage_items VALUES ('5ab496cc-6c2b-4c29-8907-4c93f7a83552', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-022', 22, 'Press office fascia', 'Press office fascia for UKCW Birmingham 2027.', 'b3bdc8c8-074b-4787-a748-df3edf7b9f60', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '7191ffbf-bac9-42c2-b1cb-3c1d8dbfd2ba', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 800.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'awaiting_artwork', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.562817+00', '2026-09-18 13:21:21.562817+00');
INSERT INTO public.signage_items VALUES ('b950ee49-3ab8-444f-a5a5-a90ad5ce7975', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-023', 23, 'Hall 1 big screen content loop', 'Hall 1 big screen content loop for UKCW Birmingham 2027.', '7ff13093-0cdb-4663-9fa4-f18ef8c381bb', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', 'ef03d1db-a886-40b4-9b8f-95fd84313a1c', 'marketing', '00000000-0000-4000-8000-000000000003', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'digital', NULL, false, true, NULL, 6000.00, NULL, NULL, '88a3aeeb-a45f-45c6-b857-3f452c17f78c', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.567468+00', '2026-09-18 13:21:21.567468+00');
INSERT INTO public.signage_items VALUES ('f58fcbef-9c1c-4058-8c5c-ea2ae3154436', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-024', 24, 'Wayfinding floor arrows', 'Wayfinding floor arrows for UKCW Birmingham 2027.', 'ac0e4e8d-91db-4e20-8d10-b6acf31efa14', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '0cf3917e-d862-4183-ac0c-4e8d4edb8441', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'floor', NULL, false, false, NULL, 450.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.569883+00', '2026-09-18 13:21:21.569883+00');
INSERT INTO public.signage_items VALUES ('c77a4d96-eb16-4483-991d-d3f1156b5681', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-025', 25, 'ToolMart seminar bunting', 'ToolMart seminar bunting for UKCW Birmingham 2027.', 'ddf0e319-1963-4880-bce0-c413dcf1645c', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '0cf3917e-d862-4183-ac0c-4e8d4edb8441', 'marketing', '00000000-0000-4000-8000-000000000003', 'd2c9b31c-0465-4350-b177-40854f4db19d', NULL, true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, false, false, NULL, 600.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.572882+00', '2026-09-18 13:21:21.572882+00');
INSERT INTO public.signage_items VALUES ('3f737f58-0b81-466a-aada-1c9fdd1a6a8d', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-026', 26, 'External car park totems', 'External car park totems for UKCW Birmingham 2027.', '94bcbbca-f1c6-41a2-adca-05208c736a42', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '59ad1ac2-e1a8-42ba-848a-b0de13489d7c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, true, NULL, 5400.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.575738+00', '2026-09-18 13:21:21.575738+00');
INSERT INTO public.signage_items VALUES ('cd0c9a56-1acd-483c-b153-bd554a2b6582', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-027', 27, 'Smoking area signage', 'Smoking area signage for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', '59ad1ac2-e1a8-42ba-848a-b0de13489d7c', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 150.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.579087+00', '2026-09-18 13:21:21.579087+00');
INSERT INTO public.signage_items VALUES ('06d7b78e-d62d-418d-9e2a-7456659d0ff4', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-028', 28, 'First aid point signs', 'First aid point signs for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '765a8aac-5aab-4056-a8cc-5f09f4a2d0a3', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 320.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'changes_requested', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 'cbdf1101-48c1-482e-b767-905fc441bf09', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.581913+00', '2026-09-18 13:21:21.584263+00');
INSERT INTO public.signage_items VALUES ('3d3c0434-10e6-44b1-83c8-39aed9e898ba', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-029', 29, 'BuildCo entrance feature cladding', 'BuildCo entrance feature cladding for UKCW Birmingham 2027.', '020d652d-a2aa-4354-810a-3d9bc90cfdf4', '7d46a2df-f969-4d8e-96ce-dfd3679bdbaa', '239b833b-5097-4685-ac18-836e4869b865', 'marketing', '00000000-0000-4000-8000-000000000003', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', '9e144312-5787-4dcd-bc11-c9021178f7d5', true, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'freestanding', NULL, true, false, NULL, 15000.00, NULL, NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, NULL, NULL, '2027-10-02', 'pm', NULL, 'in_review', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, '9526cf2e-f6c6-4e73-a1af-68a85a916928', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.594591+00', '2026-09-18 13:21:21.596973+00');
INSERT INTO public.signage_items VALUES ('00d5515a-0d37-4320-9b82-c4165aca02c3', 'b787777a-adde-4647-802f-56676d5025ba', 'SIG-BIRM27-030', 30, 'Recycling point signage', 'Recycling point signage for UKCW Birmingham 2027.', '6504cffd-8b15-4ba3-b78b-a4903f24e6d9', '18e58ef2-15e0-4ec3-acb4-9749fbeb43b3', 'e139f1c5-3229-4659-b392-4e7d91c9ba0f', 'ops', '00000000-0000-4000-8000-000000000002', NULL, NULL, false, 3000, 1000, NULL, 1, 'single', 'Tension fabric', 'Matt', 'wall_mounted', NULL, false, false, NULL, 200.00, NULL, NULL, NULL, NULL, NULL, NULL, '2027-10-02', 'am', NULL, 'draft', NULL, NULL, 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 0, NULL, NULL, NULL, NULL, '00000000-0000-4000-8000-000000000002', NULL, '2026-09-18 13:21:21.608572+00', '2026-09-18 13:21:21.608572+00');


--
-- Data for Name: snags; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.snags VALUES ('fb2a5f1d-865d-47e8-9feb-ccf037cf0d43', 'b787777a-adde-4647-802f-56676d5025ba', '9d2e85fc-0745-44ec-be18-1fb3ecfb7f3e', NULL, 'Corner delaminating on the catering court panel.', NULL, 'medium', NULL, '8ab01bdd-8208-4b93-a4a2-ddc302e93e06', NULL, 'open', NULL, NULL, NULL, NULL, '2026-09-18 13:21:21.497647+00', '2026-09-18 13:21:21.497647+00');


--
-- Data for Name: sponsor_entitlements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsor_entitlements VALUES ('de033850-a142-4718-b104-12201ad6a7d5', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', 'Logo on 6 hanging banners', 6, '2026-09-18 13:21:21.189172+00', '2026-09-18 13:21:21.189172+00');
INSERT INTO public.sponsor_entitlements VALUES ('9e144312-5787-4dcd-bc11-c9021178f7d5', '478347e9-0eb5-45c9-94dd-18a4b00b34a6', 'Entrance feature branding', 1, '2026-09-18 13:21:21.190985+00', '2026-09-18 13:21:21.190985+00');
INSERT INTO public.sponsor_entitlements VALUES ('a1e7695f-78a3-47e2-ac95-4cdcb0c47915', 'd2c9b31c-0465-4350-b177-40854f4db19d', 'Seminar theatre branding', 1, '2026-09-18 13:21:21.194657+00', '2026-09-18 13:21:21.194657+00');


--
-- Data for Name: sponsors; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sponsors VALUES ('478347e9-0eb5-45c9-94dd-18a4b00b34a6', 'b787777a-adde-4647-802f-56676d5025ba', 'BuildCo', NULL, 'sponsor@buildco.test', 'Headline sponsor', NULL, '2026-09-18 13:21:21.187174+00', '2026-09-18 13:21:21.187174+00');
INSERT INTO public.sponsors VALUES ('d2c9b31c-0465-4350-b177-40854f4db19d', 'b787777a-adde-4647-802f-56676d5025ba', 'ToolMart', NULL, 'brand@toolmart.test', 'Seminar theatre sponsor', NULL, '2026-09-18 13:21:21.192974+00', '2026-09-18 13:21:21.192974+00');


--
-- Data for Name: stand_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.stand_submissions VALUES ('a6470fc1-6ec4-4e70-9364-2cea39a88a85', 'b787777a-adde-4647-802f-56676d5025ba', 'c814dbb5-0d14-4b87-a9e5-a6ea392d54f8', 'STD-BIRM27-A10', '3a19357b-397d-4dbd-b8e5-56588a804db8', 1, 5200, false, false, false, true, false, false, NULL, true, 'in_review', NULL, NULL, NULL, NULL, '2026-09-12 13:21:21.074+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.612761+00', '2026-09-18 13:21:21.612761+00');
INSERT INTO public.stand_submissions VALUES ('d10c1ee3-908b-4938-bc6e-221af2a2fc30', 'b787777a-adde-4647-802f-56676d5025ba', '72cf5b12-f8fc-476d-9ba0-40a04709ca73', 'STD-BIRM27-A20', '65e8e271-0d6e-44f8-afa9-6ad621b14016', 1, 3400, false, false, false, false, false, false, NULL, false, 'in_review', NULL, NULL, NULL, NULL, '2026-09-12 13:21:21.074+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.626296+00', '2026-09-18 13:21:21.626296+00');
INSERT INTO public.stand_submissions VALUES ('39f78f51-209f-46b2-8d4a-d5ee7f9f889c', 'b787777a-adde-4647-802f-56676d5025ba', '65218b38-4dd2-41f7-a6ef-edb906c8b445', 'STD-BIRM27-A30', '3a19357b-397d-4dbd-b8e5-56588a804db8', 1, 3800, false, false, false, false, false, false, NULL, false, 'changes_requested', NULL, NULL, NULL, NULL, '2026-09-12 13:21:21.074+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.639007+00', '2026-09-18 13:21:21.639007+00');
INSERT INTO public.stand_submissions VALUES ('20f24aed-02bf-4d83-adc1-2bedb79545a1', 'b787777a-adde-4647-802f-56676d5025ba', '41acf345-b894-47f1-8992-a4469fa128b5', 'STD-BIRM27-B10', '65e8e271-0d6e-44f8-afa9-6ad621b14016', 1, 3000, false, false, false, false, false, false, NULL, false, 'approved_with_conditions', NULL, NULL, 'approved_with_conditions', 'Handrail detail to be verified onsite before opening.', '2026-09-12 13:21:21.074+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.65145+00', '2026-09-18 13:21:21.65145+00');
INSERT INTO public.stand_submissions VALUES ('fe1d6ed4-4aba-4cee-b28c-923f67804ecb', 'b787777a-adde-4647-802f-56676d5025ba', '59c0f91a-14f5-468e-9c49-b17785300b44', 'STD-BIRM27-B20', '3a19357b-397d-4dbd-b8e5-56588a804db8', 1, 2900, false, false, false, false, false, false, NULL, false, 'approved', NULL, NULL, 'approved', NULL, '2026-09-12 13:21:21.074+00', '00000000-0000-4000-8000-000000000015', '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.662217+00', '2026-09-18 13:21:21.662217+00');
INSERT INTO public.stand_submissions VALUES ('40b3489c-1d79-4031-bd7c-7e30405a6a66', 'b787777a-adde-4647-802f-56676d5025ba', '5b86202d-eee7-4511-950c-b69b91ea4b75', 'STD-BIRM27-B30', '65e8e271-0d6e-44f8-afa9-6ad621b14016', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 0, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.672614+00', '2026-09-18 13:21:21.672614+00');
INSERT INTO public.stand_submissions VALUES ('eb8e6cf5-5f0c-4e7e-8665-cfaa4acf551e', 'b787777a-adde-4647-802f-56676d5025ba', '990299bb-5105-4a2e-bde8-cca48fd3ef3f', 'STD-BIRM27-C10', '3a19357b-397d-4dbd-b8e5-56588a804db8', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 0, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.675543+00', '2026-09-18 13:21:21.675543+00');
INSERT INTO public.stand_submissions VALUES ('6399643e-75dc-4faa-8f59-e3940374ad3a', 'b787777a-adde-4647-802f-56676d5025ba', '80101c96-a16a-4135-baf6-69a43b25fa1e', 'STD-BIRM27-C20', '65e8e271-0d6e-44f8-afa9-6ad621b14016', 1, NULL, false, false, false, false, false, false, NULL, false, 'not_submitted', NULL, NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 0, '00000000-0000-4000-8000-000000000002', '2026-09-18 13:21:21.678411+00', '2026-09-18 13:21:21.678411+00');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('8ab01bdd-8208-4b93-a4a2-ddc302e93e06', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Big Print Co', 'print', NULL, 'print@bigprint.test', NULL, NULL, '2026-09-18 13:21:21.17552+00', '2026-09-18 13:21:21.17552+00');
INSERT INTO public.suppliers VALUES ('83483659-bb30-4380-ac38-a6fcddef8730', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Rig Right', 'rigging', NULL, 'hello@rigright.test', NULL, NULL, '2026-09-18 13:21:21.177638+00', '2026-09-18 13:21:21.177638+00');
INSERT INTO public.suppliers VALUES ('88a3aeeb-a45f-45c6-b857-3f452c17f78c', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Screen Hire Ltd', 'av', NULL, 'hire@screenhire.test', NULL, NULL, '2026-09-18 13:21:21.179811+00', '2026-09-18 13:21:21.179811+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000015', 'stand@exhibitorco.test', 'Erin at Exhibitor Co', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.268998+00', '2026-09-18 13:21:21.268998+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000001', 'admin@media10.test', 'Alex Admin', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.10317+00', '2026-09-18 13:21:22.482036+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000002', 'ops@media10.test', 'Olivia Ops', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.106819+00', '2026-09-18 13:21:22.484677+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000003', 'marketing@media10.test', 'Marcus Marketing', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.109109+00', '2026-09-18 13:21:22.486428+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000004', 'sales@media10.test', 'Sara Sales', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.111147+00', '2026-09-18 13:21:22.488135+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000005', 'director@media10.test', 'Dana Director', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.113687+00', '2026-09-18 13:21:22.490027+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000006', 'viewer@media10.test', 'Vic Viewer', NULL, NULL, false, '{}', NULL, '2026-09-18 13:21:21.115916+00', '2026-09-18 13:21:22.491847+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000011', 'venue@nec.test', 'Nina at NEC', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.227934+00', '2026-09-18 13:21:22.554037+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000012', 'engineer@calcs.test', 'Ed Engineer', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.231667+00', '2026-09-18 13:21:22.556154+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000013', 'hs@safety.test', 'Harri Safety', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.234477+00', '2026-09-18 13:21:22.558008+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000014', 'print@bigprint.test', 'Petra at Big Print', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.237189+00', '2026-09-18 13:21:22.559761+00');
INSERT INTO public.users VALUES ('00000000-0000-4000-8000-000000000016', 'sponsor@buildco.test', 'Ben at BuildCo', NULL, NULL, true, '{}', NULL, '2026-09-18 13:21:21.239943+00', '2026-09-18 13:21:22.561618+00');


--
-- Data for Name: venue_rules; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venue_rules VALUES ('dfe4ef16-42a0-4641-9533-17262b7361d3', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'height', 'EXAMPLE: Maximum stand height 4000 mm', 'Stands above 4000 mm require complex-structure approval.', 'stand', true, 0, '2026-09-18 13:21:21.12548+00', '2026-09-18 13:21:21.12548+00');
INSERT INTO public.venue_rules VALUES ('22e0c99e-30dc-4d33-bb04-649da11aadc7', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'rigging', 'EXAMPLE: Rigged items via venue rigging team', 'Any rigged or suspended item goes through the venue''s rigging team.', 'both', true, 1, '2026-09-18 13:21:21.12759+00', '2026-09-18 13:21:21.12759+00');
INSERT INTO public.venue_rules VALUES ('f0d5a094-d1e1-46f9-822c-4b6fa0b37731', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'walls', 'EXAMPLE: Walls over 2500 mm finished on reverse', 'Walls over 2500 mm facing a neighbouring stand must be finished on the reverse side.', 'stand', true, 2, '2026-09-18 13:21:21.129621+00', '2026-09-18 13:21:21.129621+00');
INSERT INTO public.venue_rules VALUES ('e7d5ea06-d858-4edf-8fb4-26bbb1f8f181', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'gangways', 'EXAMPLE: No encroachment into gangways', 'No part of a stand or sign may encroach into gangways.', 'both', true, 3, '2026-09-18 13:21:21.131318+00', '2026-09-18 13:21:21.131318+00');
INSERT INTO public.venue_rules VALUES ('27d29cf3-a177-44f8-aa4b-dc507b865bb8', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'fire', 'EXAMPLE: Fire-retardancy certification', 'All materials need fire-retardancy certification.', 'both', true, 4, '2026-09-18 13:21:21.133178+00', '2026-09-18 13:21:21.133178+00');
INSERT INTO public.venue_rules VALUES ('f450a4b6-672f-4a7f-bb1d-96343ecce331', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'structure', 'EXAMPLE: Double-deck stands need engineer sign-off', 'Double-deck stands need structural calculations and engineer sign-off.', 'stand', true, 5, '2026-09-18 13:21:21.134858+00', '2026-09-18 13:21:21.134858+00');
INSERT INTO public.venue_rules VALUES ('2fe0e84f-1c10-497f-8033-54914c878045', '5d91fbca-7e35-47df-ae8f-5e45ee657551', 'structure', 'EXAMPLE: Platforms over 600 mm need handrails', 'Platforms over 600 mm need handrails and structural calculations.', 'stand', true, 6, '2026-09-18 13:21:21.136548+00', '2026-09-18 13:21:21.136548+00');


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.venues VALUES ('5d91fbca-7e35-47df-ae8f-5e45ee657551', '26ffafac-2a6a-413d-b489-bf6377546dea', 'NEC Birmingham', 'NEC', NULL, NULL, NULL, true, NULL, '2026-09-18 13:21:21.119767+00', '2026-09-18 13:21:22.495296+00');
INSERT INTO public.venues VALUES ('94f9e47d-9457-4e36-9c80-ec49c9e37aa1', '26ffafac-2a6a-413d-b489-bf6377546dea', 'ExCeL London', 'EXCEL', NULL, NULL, NULL, true, NULL, '2026-09-18 13:21:21.121278+00', '2026-09-18 13:21:22.496762+00');


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflow_steps VALUES ('88eff8c9-9d3d-4be2-a772-2566110c5cda', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 1, 1, 'Marketing brand check', 'approval', 'role', 'marketing', NULL, '{always}', 3, true, true, '2026-09-18 13:21:21.197967+00', '2026-09-18 13:21:21.197967+00');
INSERT INTO public.workflow_steps VALUES ('db269dc8-b2d4-4a17-a507-2ce6a719836b', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 2, 1, 'Sponsor approval', 'approval', 'role', 'sales', NULL, '{if_sponsored}', 5, true, true, '2026-09-18 13:21:21.199506+00', '2026-09-18 13:21:21.199506+00');
INSERT INTO public.workflow_steps VALUES ('f4708191-1c9e-48eb-bd41-b7b3c8635c7a', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 3, NULL, 'Ops technical check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-18 13:21:21.200398+00', '2026-09-18 13:21:21.200398+00');
INSERT INTO public.workflow_steps VALUES ('04b67a44-4130-48b5-95d9-e4d61ba68d4f', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_requires_venue_approval}', 7, true, true, '2026-09-18 13:21:21.201229+00', '2026-09-18 13:21:21.201229+00');
INSERT INTO public.workflow_steps VALUES ('e0a9bcd5-9f6d-4cac-93da-ad0232c184d1', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 5, NULL, 'Event Director sign-off', 'approval', 'role', 'event_director', NULL, '{if_requires_event_director,if_cost_over_threshold}', 3, true, true, '2026-09-18 13:21:21.202065+00', '2026-09-18 13:21:21.202065+00');
INSERT INTO public.workflow_steps VALUES ('908ed962-6a58-4efc-9878-b523219b8194', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 6, NULL, 'Sent to print', 'confirmation', 'role', 'supplier', NULL, '{always}', 2, true, true, '2026-09-18 13:21:21.202994+00', '2026-09-18 13:21:21.202994+00');
INSERT INTO public.workflow_steps VALUES ('36e4407e-6bba-4982-86c1-26e124cedaa0', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 7, NULL, 'Delivered', 'confirmation', 'role', 'supplier', NULL, '{always}', 0, false, true, '2026-09-18 13:21:21.204019+00', '2026-09-18 13:21:21.204019+00');
INSERT INTO public.workflow_steps VALUES ('c38a6cf8-f839-4bb0-9905-3e644c96cd4c', 'ace4f384-2ebe-41f6-9240-c67bfb4a146f', 8, NULL, 'Installed', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-18 13:21:21.204871+00', '2026-09-18 13:21:21.204871+00');
INSERT INTO public.workflow_steps VALUES ('0e5560b0-7327-4565-84b9-883ed7c07ee9', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 1, NULL, 'Ops completeness and rules check', 'approval', 'role', 'ops', NULL, '{always}', 3, true, true, '2026-09-18 13:21:21.20944+00', '2026-09-18 13:21:21.20944+00');
INSERT INTO public.workflow_steps VALUES ('3fea2e1d-e338-4fae-8d8e-04323a432d2a', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 2, NULL, 'Structural engineer review', 'approval', 'role', 'structural_engineer', NULL, '{if_complex_structure}', 7, true, true, '2026-09-18 13:21:21.210274+00', '2026-09-18 13:21:21.210274+00');
INSERT INTO public.workflow_steps VALUES ('3b83bd0c-ad58-4f86-b74d-0fce52692925', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 3, NULL, 'H&S review (RAMS, insurance)', 'approval', 'role', 'hs', NULL, '{always}', 5, true, true, '2026-09-18 13:21:21.211195+00', '2026-09-18 13:21:21.211195+00');
INSERT INTO public.workflow_steps VALUES ('a14332e2-3376-4682-895f-8243b2e535b8', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 4, NULL, 'Venue approval', 'approval', 'role', 'venue', NULL, '{if_venue_requires_stand_approval}', 7, true, true, '2026-09-18 13:21:21.212077+00', '2026-09-18 13:21:21.212077+00');
INSERT INTO public.workflow_steps VALUES ('9853fa4e-63dd-46f1-b4bf-512993f1cef5', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 5, NULL, 'Ops final outcome', 'approval', 'role', 'ops', NULL, '{always}', 2, true, true, '2026-09-18 13:21:21.212914+00', '2026-09-18 13:21:21.212914+00');
INSERT INTO public.workflow_steps VALUES ('10519af4-6085-4836-89b8-1dc875154392', 'ecfdfc98-5c28-42d8-a228-a73b372a9e45', 6, NULL, 'Onsite build check', 'confirmation', 'role', 'ops', NULL, '{always}', 0, false, true, '2026-09-18 13:21:21.213745+00', '2026-09-18 13:21:21.213745+00');


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.workflows VALUES ('ace4f384-2ebe-41f6-9240-c67bfb4a146f', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Signage default', 'signage', true, false, '2026-09-18 13:21:21.196747+00', '2026-09-18 13:21:21.196747+00');
INSERT INTO public.workflows VALUES ('ecfdfc98-5c28-42d8-a228-a73b372a9e45', '26ffafac-2a6a-413d-b489-bf6377546dea', 'Stand default', 'stand', true, false, '2026-09-18 13:21:21.208384+00', '2026-09-18 13:21:21.208384+00');


--
-- Name: __drizzle_migrations_id_seq; Type: SEQUENCE SET; Schema: drizzle; Owner: -
--

SELECT pg_catalog.setval('drizzle.__drizzle_migrations_id_seq', 3, true);


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
-- Name: stand_submissions stand_submissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stand_submissions_set_updated_at BEFORE UPDATE ON public.stand_submissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: suppliers suppliers_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suppliers_set_updated_at BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: stand_submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stand_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: suppliers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

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
