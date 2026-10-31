-- Tables owned by the Medhavn backend service. No RLS policies on purpose:
-- only the service role (which bypasses RLS) touches them, so app users get no access.

CREATE TABLE IF NOT EXISTS medhavn.email_otps (
  email TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medhavn.missed_dose_alerts (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL, -- itemId|yyyy-MM-dd|block, same format as pill_dose_statuses.key
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);

ALTER TABLE medhavn.email_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.missed_dose_alerts ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA medhavn TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA medhavn TO service_role;

-- Housekeeping: expired codes are useless.
CREATE INDEX IF NOT EXISTS idx_email_otps_expires ON medhavn.email_otps(expires_at);
