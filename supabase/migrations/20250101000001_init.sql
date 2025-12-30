-- Migration: 001_init
-- Core identity and tenancy tables

-- Enable necessary extensions
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- Replaced by gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Enum types
CREATE TYPE org_member_role AS ENUM ('org_admin', 'user', 'staff');
CREATE TYPE org_member_status AS ENUM ('active', 'invited', 'suspended', 'removed');

-- Organizations table
CREATE TABLE orgs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  settings JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Organization members - links users to orgs with roles
CREATE TABLE org_members (
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role org_member_role NOT NULL,
  status org_member_status NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (org_id, user_id)
);

CREATE INDEX idx_org_members_user_id ON org_members(user_id);
CREATE INDEX idx_org_members_status ON org_members(status);

-- Platform administrators - special cross-org access
CREATE TABLE platform_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);

-- User profiles
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Staff profiles - additional info for staff members
CREATE TABLE staff_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  skills TEXT[] DEFAULT '{}',
  home_warehouse_id UUID, -- FK added after warehouses table
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_staff_profiles_org_id ON staff_profiles(org_id);

-- RLS Policies for orgs
ALTER TABLE orgs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view orgs they belong to" ON orgs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = orgs.id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Org admins can update their orgs" ON orgs
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = orgs.id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for org_members
ALTER TABLE org_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view members of their orgs" ON org_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members AS om
      WHERE om.org_id = org_members.org_id
        AND om.user_id = auth.uid()
        AND om.status = 'active'
    )
  );

CREATE POLICY "Org admins can manage org members" ON org_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM org_members AS om
      WHERE om.org_id = org_members.org_id
        AND om.user_id = auth.uid()
        AND om.role = 'org_admin'
        AND om.status = 'active'
    )
  );

-- RLS Policies for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile" ON profiles
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- RLS Policies for staff_profiles
ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view their own staff profile" ON staff_profiles
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Org admins can view staff profiles in their org" ON staff_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = staff_profiles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Org admins can manage staff profiles in their org" ON staff_profiles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = staff_profiles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- Function to create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (user_id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to create org on first signup (user becomes org_admin)
CREATE OR REPLACE FUNCTION handle_org_creation_on_signup()
RETURNS TRIGGER AS $$
DECLARE
  new_org_id UUID;
BEGIN
  -- Only create org if this is a new user (not via invite)
  IF NOT EXISTS (SELECT 1 FROM org_members WHERE user_id = NEW.id) THEN
    INSERT INTO orgs (name, settings)
    VALUES (
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'My Organization') || '''s Organization',
      '{"assignment_mode": "user_assign", "late_window_hours": 48}'::jsonb
    )
    RETURNING id INTO new_org_id;

    INSERT INTO org_members (org_id, user_id, role, status)
    VALUES (new_org_id, NEW.id, 'org_admin', 'active');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created_org
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_org_creation_on_signup();
