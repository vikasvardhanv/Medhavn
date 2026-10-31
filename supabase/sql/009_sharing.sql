-- Connections between accounts and consent-based data sharing. Run 008 first.
-- All reads of another person's data go through the backend, which checks an ACTIVE share.
-- App users can only read rows that involve them; they never read other users' health tables.

-- 008 created family_links for family only; it now holds every kind of connection.
ALTER TABLE IF EXISTS medhavn.family_links RENAME TO connections;

DO $$
DECLARE c TEXT;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'medhavn.connections'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%relationship%'
  LOOP
    EXECUTE format('ALTER TABLE medhavn.connections DROP CONSTRAINT %I', c);
  END LOOP;
END $$;

ALTER TABLE medhavn.connections
  ADD CONSTRAINT connections_relationship_check
  CHECK (relationship IN ('friend','parent','child','spouse','sibling','other'));
ALTER TABLE medhavn.connections ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

DROP POLICY IF EXISTS "family_links read own" ON medhavn.connections;
DROP POLICY IF EXISTS "connections read own" ON medhavn.connections;
CREATE POLICY "connections read own" ON medhavn.connections FOR SELECT
  USING ((select auth.uid()) IN (user_id, linked_user_id));

-- One row per (owner, viewer). The owner's data is visible to the viewer for the listed scopes.
--   alerts      missed-dose alert emails
--   adherence   taken/missed counts, no medicine names
--   medications medicine names, doses, schedules
-- initiated_by is whoever proposed it; the OTHER person must accept. The owner always consents.
CREATE TABLE IF NOT EXISTS medhavn.data_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scopes TEXT[] NOT NULL CHECK (cardinality(scopes) > 0 AND scopes <@ ARRAY['alerts','adherence','medications']),
  initiated_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','declined','revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  UNIQUE (owner_id, viewer_id),
  CHECK (owner_id <> viewer_id),
  CHECK (initiated_by IN (owner_id, viewer_id))
);
CREATE INDEX IF NOT EXISTS idx_data_shares_viewer ON medhavn.data_shares(viewer_id);

-- Who changed what, and when. Never holds health data.
CREATE TABLE IF NOT EXISTS medhavn.share_audit (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  share_id UUID NOT NULL REFERENCES medhavn.data_shares(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL,
  event TEXT NOT NULL,
  detail JSONB,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE medhavn.data_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE medhavn.share_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shares read own" ON medhavn.data_shares;
CREATE POLICY "shares read own" ON medhavn.data_shares FOR SELECT
  USING ((select auth.uid()) IN (owner_id, viewer_id));

DROP POLICY IF EXISTS "audit read as owner" ON medhavn.share_audit;
CREATE POLICY "audit read as owner" ON medhavn.share_audit FOR SELECT
  USING (EXISTS (SELECT 1 FROM medhavn.data_shares s WHERE s.id = share_id AND s.owner_id = (select auth.uid())));

GRANT ALL ON medhavn.connections, medhavn.data_shares, medhavn.share_audit TO service_role;
GRANT SELECT ON medhavn.connections, medhavn.data_shares, medhavn.share_audit TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA medhavn TO service_role;
