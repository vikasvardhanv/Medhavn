-- Auto-create a medhavn.user_profiles row when a new Supabase auth user signs up.
-- full_name is sourced from auth.users.raw_user_meta_data which Supabase populates
-- from the "data": {"full_name": "..."} field in the signup request body.

CREATE OR REPLACE FUNCTION medhavn.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO medhavn.user_profiles (auth_id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  )
  ON CONFLICT (auth_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION medhavn.handle_new_user();
