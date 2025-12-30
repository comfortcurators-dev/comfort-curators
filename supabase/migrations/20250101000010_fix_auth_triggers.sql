-- Migration: 010_fix_auth_triggers
-- Fix trigger functions to bypass RLS during user creation

-- Drop existing triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created_org ON auth.users;

-- Recreate handle_new_user function with SET search_path to avoid RLS issues
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert profile bypassing RLS (SECURITY DEFINER + explicit schema)
  INSERT INTO public.profiles (user_id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log but don't fail auth if profile creation fails
  RAISE WARNING 'Profile creation failed for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate handle_org_creation_on_signup with SET search_path
CREATE OR REPLACE FUNCTION handle_org_creation_on_signup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_org_id UUID;
BEGIN
  -- Only create org if this is a new user (not via invite)
  IF NOT EXISTS (SELECT 1 FROM public.org_members WHERE user_id = NEW.id) THEN
    INSERT INTO public.orgs (name, settings)
    VALUES (
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'My Organization') || '''s Organization',
      '{"assignment_mode": "user_assign", "late_window_hours": 48}'::jsonb
    )
    RETURNING id INTO new_org_id;

    INSERT INTO public.org_members (org_id, user_id, role, status)
    VALUES (new_org_id, NEW.id, 'org_admin', 'active');
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log but don't fail auth if org creation fails
  RAISE WARNING 'Org creation failed for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER on_auth_user_created_org
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_org_creation_on_signup();

-- Grant execute permissions to authenticated role
GRANT EXECUTE ON FUNCTION handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION handle_org_creation_on_signup() TO service_role;

-- Add INSERT policy for profiles that allows service_role/postgres to insert
-- This is needed because even SECURITY DEFINER needs policies on RLS-enabled tables
CREATE POLICY "Service role can insert profiles" ON profiles
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can insert orgs" ON orgs
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can insert org_members" ON org_members
  FOR INSERT
  TO service_role
  WITH CHECK (true);
