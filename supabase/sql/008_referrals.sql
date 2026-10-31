-- Referral tracking and family links.
-- Writes go through the backend service role. App users may only read their own rows.

ALTER TABLE medhavn.user_profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;

-- One row per invited person. `relationship` is what the invitee is to the inviter.
CREATE TABLE IF NOT EXISTS medhavn.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_email TEXT NOT NULL,
  relationship TEXT NOT NULL DEFAULT 'friend'
    CHECK (relationship IN ('friend','parent','child','spouse','sibling','other')),
  status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','signed_up')),
  referee_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  signed_up_at TIMESTAMPTZ,
  UNIQUE (referrer_id, referee_email)
);
CREATE INDEX IF NOT EXISTS idx_referrals_referee_email ON medhavn.referrals(referee_email) WHERE status = 'invited';

-- A proposed connection between two accounts (parent, child, spouse, sibling).
-- It grants NO access to health data. Sharing needs a separate, explicit accept step.
CREATE TABLE IF NOT EXISTS medhavn.family_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,        -- the inviter
  linked_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- the invitee
  relationship TEXT NOT NULL CHECK (relationship IN ('parent','child','spouse','sibling')), -- what linked_user is to user
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, linked_user_id),
  CHECK (user_id <> linked_user_id)
);

ALTER TABLE medhavn.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.family_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referrals read own" ON medhavn.referrals;
CREATE POLICY "referrals read own" ON medhavn.referrals FOR SELECT
  USING ((select auth.uid()) IN (referrer_id, referee_id));

DROP POLICY IF EXISTS "family_links read own" ON medhavn.family_links;
CREATE POLICY "family_links read own" ON medhavn.family_links FOR SELECT
  USING ((select auth.uid()) IN (user_id, linked_user_id));

GRANT ALL ON medhavn.referrals, medhavn.family_links TO service_role;
GRANT SELECT ON medhavn.referrals, medhavn.family_links TO authenticated;
