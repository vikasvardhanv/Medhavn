create extension if not exists pgcrypto;

create table if not exists medication_plans (
  id uuid primary key,
  user_id uuid not null,
  created_at timestamptz not null,
  source text not null,
  source_text text not null,
  parsed_json text not null,
  patient_directions text not null,
  rationale text not null,
  needs_confirmation boolean not null default false
);

create table if not exists dose_logs (
  id uuid primary key,
  user_id uuid not null,
  plan_id uuid not null references medication_plans(id) on delete cascade,
  timestamp timestamptz not null,
  dose double precision not null,
  units text not null,
  is_prn boolean not null default false
);

create table if not exists user_settings (
  user_id uuid primary key,
  cloud_consent boolean not null default false,
  disclaimer_accepted boolean not null default false,
  privacy_policy_accepted boolean not null default false,
  processing_consent_accepted boolean not null default false,
  consent_checklist_completed boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  educational_only_ack boolean not null,
  confirm_clinician_ack boolean not null,
  privacy_policy_ack boolean not null,
  processing_consent_ack boolean not null,
  policy_version text not null,
  accepted_at timestamptz not null default now()
);