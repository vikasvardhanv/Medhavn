-- Medhavn Schema RLS Policies
-- Enable Row Level Security and create policies for all tables in medhavn schema

-- Enable RLS on all tables
ALTER TABLE medhavn.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.medication_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.dose_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.user_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.med_cabinet_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.pill_dose_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.diary_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.allergies ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.safe_circle_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.dependent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.drug_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.daily_insight_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.update_feed_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.app_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "user_profiles own rows" ON medhavn.user_profiles;
DROP POLICY IF EXISTS "medication_plans own rows" ON medhavn.medication_plans;
DROP POLICY IF EXISTS "dose_logs own rows" ON medhavn.dose_logs;
DROP POLICY IF EXISTS "user_settings own row" ON medhavn.user_settings;
DROP POLICY IF EXISTS "user_consents own rows" ON medhavn.user_consents;
DROP POLICY IF EXISTS "med_cabinet_items own rows" ON medhavn.med_cabinet_items;
DROP POLICY IF EXISTS "pill_dose_statuses own rows" ON medhavn.pill_dose_statuses;
DROP POLICY IF EXISTS "health_metrics own rows" ON medhavn.health_metrics;
DROP POLICY IF EXISTS "diary_entries own rows" ON medhavn.diary_entries;
DROP POLICY IF EXISTS "allergies own rows" ON medhavn.allergies;
DROP POLICY IF EXISTS "safe_circle_contacts own rows" ON medhavn.safe_circle_contacts;
DROP POLICY IF EXISTS "dependent_profiles own rows" ON medhavn.dependent_profiles;
DROP POLICY IF EXISTS "appointments own rows" ON medhavn.appointments;
DROP POLICY IF EXISTS "doctors own rows" ON medhavn.doctors;
DROP POLICY IF EXISTS "drug_interactions own rows" ON medhavn.drug_interactions;
DROP POLICY IF EXISTS "daily_insight_notes own rows" ON medhavn.daily_insight_notes;
DROP POLICY IF EXISTS "update_feed_items own rows" ON medhavn.update_feed_items;
DROP POLICY IF EXISTS "app_logs own rows" ON medhavn.app_logs;

-- Create policies for user_profiles
CREATE POLICY "user_profiles own rows"
  ON medhavn.user_profiles
  FOR ALL
  USING ((select auth.uid()) = auth_id)
  WITH CHECK ((select auth.uid()) = auth_id);

-- Create policies for medication_plans
CREATE POLICY "medication_plans own rows"
  ON medhavn.medication_plans
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for dose_logs
CREATE POLICY "dose_logs own rows"
  ON medhavn.dose_logs
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for user_settings
CREATE POLICY "user_settings own row"
  ON medhavn.user_settings
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for user_consents
CREATE POLICY "user_consents own rows"
  ON medhavn.user_consents
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for med_cabinet_items
CREATE POLICY "med_cabinet_items own rows"
  ON medhavn.med_cabinet_items
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for pill_dose_statuses
CREATE POLICY "pill_dose_statuses own rows"
  ON medhavn.pill_dose_statuses
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for health_metrics
CREATE POLICY "health_metrics own rows"
  ON medhavn.health_metrics
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for diary_entries
CREATE POLICY "diary_entries own rows"
  ON medhavn.diary_entries
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for allergies
CREATE POLICY "allergies own rows"
  ON medhavn.allergies
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for safe_circle_contacts
CREATE POLICY "safe_circle_contacts own rows"
  ON medhavn.safe_circle_contacts
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for dependent_profiles
CREATE POLICY "dependent_profiles own rows"
  ON medhavn.dependent_profiles
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for appointments
CREATE POLICY "appointments own rows"
  ON medhavn.appointments
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for doctors
CREATE POLICY "doctors own rows"
  ON medhavn.doctors
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for drug_interactions
CREATE POLICY "drug_interactions own rows"
  ON medhavn.drug_interactions
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for daily_insight_notes
CREATE POLICY "daily_insight_notes own rows"
  ON medhavn.daily_insight_notes
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for update_feed_items
CREATE POLICY "update_feed_items own rows"
  ON medhavn.update_feed_items
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- Create policies for app_logs
CREATE POLICY "app_logs own rows"
  ON medhavn.app_logs
  FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);