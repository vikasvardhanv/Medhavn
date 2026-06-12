-- Medhavn Database Schema
-- Create the medhavn schema and all necessary tables

-- 1. Create the new schema
CREATE SCHEMA IF NOT EXISTS medhavn;

-- 2. Create the tables in the 'medhavn' schema

-- Users profile table (extends auth.users)
CREATE TABLE IF NOT EXISTS medhavn.user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  language TEXT DEFAULT 'en',
  timezone TEXT DEFAULT 'UTC',
  avatar_symbol TEXT DEFAULT 'person.circle',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Medication plans
CREATE TABLE IF NOT EXISTS medhavn.medication_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source TEXT NOT NULL,
  source_text TEXT NOT NULL,
  parsed_json TEXT NOT NULL,
  patient_directions TEXT NOT NULL,
  rationale TEXT NOT NULL,
  needs_confirmation BOOLEAN NOT NULL DEFAULT false
);

-- Dose logs
CREATE TABLE IF NOT EXISTS medhavn.dose_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES medhavn.medication_plans(id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ NOT NULL,
  dose DOUBLE PRECISION NOT NULL,
  units TEXT NOT NULL,
  is_prn BOOLEAN NOT NULL DEFAULT false
);

-- User settings
CREATE TABLE IF NOT EXISTS medhavn.user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  cloud_consent BOOLEAN NOT NULL DEFAULT false,
  disclaimer_accepted BOOLEAN NOT NULL DEFAULT false,
  privacy_policy_accepted BOOLEAN NOT NULL DEFAULT false,
  processing_consent_accepted BOOLEAN NOT NULL DEFAULT false,
  consent_checklist_completed BOOLEAN NOT NULL DEFAULT false,
  reminders_enabled BOOLEAN NOT NULL DEFAULT true,
  pin_lock_enabled BOOLEAN NOT NULL DEFAULT false,
  pin_hash TEXT,
  biometric_lock_enabled BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User consents
CREATE TABLE IF NOT EXISTS medhavn.user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  educational_only_ack BOOLEAN NOT NULL,
  confirm_clinician_ack BOOLEAN NOT NULL,
  privacy_policy_ack BOOLEAN NOT NULL,
  processing_consent_ack BOOLEAN NOT NULL,
  policy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Medication cabinet items
CREATE TABLE IF NOT EXISTS medhavn.med_cabinet_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dosage_text TEXT NOT NULL,
  schedule_blocks TEXT NOT NULL, -- JSON array of DayTimeBlock
  remaining_pills INTEGER NOT NULL DEFAULT 30,
  refill_threshold INTEGER NOT NULL DEFAULT 5,
  pill_shape TEXT NOT NULL DEFAULT 'capsule',
  pill_color_hex TEXT NOT NULL DEFAULT '#2F80ED',
  contraindication_tags TEXT NOT NULL DEFAULT '[]', -- JSON array
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  frequency TEXT NOT NULL DEFAULT 'everyDay',
  scheduled_times TEXT NOT NULL DEFAULT '[]', -- JSON array of ScheduledTime
  schedule_start_date TIMESTAMPTZ,
  schedule_end_date TIMESTAMPTZ,
  specific_days TEXT NOT NULL DEFAULT '[]', -- JSON array of integers
  interval_days INTEGER NOT NULL DEFAULT 1,
  rx_number TEXT DEFAULT '',
  pills_left INTEGER DEFAULT 0,
  refill_reminder_enabled BOOLEAN NOT NULL DEFAULT false
);

-- Pill dose statuses
CREATE TABLE IF NOT EXISTS medhavn.pill_dose_statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  status TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Health metrics
CREATE TABLE IF NOT EXISTS medhavn.health_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  value TEXT NOT NULL,
  unit TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Diary entries
CREATE TABLE IF NOT EXISTS medhavn.diary_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Allergies
CREATE TABLE IF NOT EXISTS medhavn.allergies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  substance TEXT NOT NULL,
  reaction TEXT NOT NULL,
  notes TEXT DEFAULT '',
  date_added TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Safe circle contacts
CREATE TABLE IF NOT EXISTS medhavn.safe_circle_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_info TEXT NOT NULL,
  relationship TEXT NOT NULL
);

-- Dependent profiles
CREATE TABLE IF NOT EXISTS medhavn.dependent_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  gender TEXT NOT NULL,
  birth_year INTEGER NOT NULL,
  avatar_color TEXT NOT NULL
);

-- Appointments
CREATE TABLE IF NOT EXISTS medhavn.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  doctor_name TEXT NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  notes TEXT DEFAULT ''
);

-- Doctors
CREATE TABLE IF NOT EXISTS medhavn.doctors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  specialty TEXT NOT NULL,
  phone TEXT NOT NULL,
  notes TEXT DEFAULT ''
);

-- Drug interactions
CREATE TABLE IF NOT EXISTS medhavn.drug_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  drug1 TEXT NOT NULL,
  drug2 TEXT NOT NULL,
  severity TEXT NOT NULL,
  detail TEXT NOT NULL
);

-- Daily insight notes
CREATE TABLE IF NOT EXISTS medhavn.daily_insight_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES medhavn.medication_plans(id) ON DELETE CASCADE,
  day_start TIMESTAMPTZ NOT NULL,
  note_body TEXT NOT NULL,
  model_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Update feed items
CREATE TABLE IF NOT EXISTS medhavn.update_feed_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  detail TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- App logs (exported from client for debugging and diagnostics)
CREATE TABLE IF NOT EXISTS medhavn.app_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  app_version TEXT NOT NULL,
  device_model TEXT,
  os_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index for efficient querying by user and date
CREATE INDEX IF NOT EXISTS idx_app_logs_user_date ON medhavn.app_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_level ON medhavn.app_logs(level);