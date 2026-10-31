-- Sex, collected at sign-up. Decides which health sections the app shows.
ALTER TABLE medhavn.user_profiles ADD COLUMN IF NOT EXISTS sex TEXT
  CHECK (sex IN ('female','male','other','prefer_not'));
