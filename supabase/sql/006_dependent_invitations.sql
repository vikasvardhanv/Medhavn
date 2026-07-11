-- Migration: Create dependent invitations table
-- Enable RLS and setup policies

CREATE TABLE IF NOT EXISTS medhavn.dependent_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitee_contact TEXT NOT NULL, -- Email or phone number
  status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, declined
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE medhavn.dependent_invitations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "inviter own rows" ON medhavn.dependent_invitations;
DROP POLICY IF EXISTS "invitee match contact" ON medhavn.dependent_invitations;

-- Only inviter can perform full operations on their invitations
CREATE POLICY "inviter own rows"
  ON medhavn.dependent_invitations
  FOR ALL
  USING ((select auth.uid()) = inviter_id)
  WITH CHECK ((select auth.uid()) = inviter_id);

-- Invitees can view or update status if they match the email
CREATE POLICY "invitee match contact"
  ON medhavn.dependent_invitations
  FOR SELECT
  USING (
    invitee_contact = (select email from auth.users where id = auth.uid())
  );
