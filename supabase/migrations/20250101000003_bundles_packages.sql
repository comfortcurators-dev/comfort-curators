-- Migration: 003_bundles_packages
-- Bundles, packages, and package runs

-- Enums
CREATE TYPE bundle_scope AS ENUM ('admin_global', 'user_private');
CREATE TYPE trigger_type AS ENUM ('booking_end', 'daily', 'weekly', 'custom');
CREATE TYPE package_run_status AS ENUM ('created', 'ticket_created', 'skipped');

-- Bundles - reusable item collections
CREATE TABLE bundles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  scope bundle_scope NOT NULL,
  owner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  items JSONB NOT NULL, -- Array of {sku_id, qty, unit}
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bundles_org_id ON bundles(org_id);
CREATE INDEX idx_bundles_scope ON bundles(scope);
CREATE INDEX idx_bundles_owner_user_id ON bundles(owner_user_id);

-- Packages - scheduled templates that create tickets
CREATE TABLE packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  trigger_type trigger_type NOT NULL,
  trigger_rules JSONB NOT NULL, -- Must include ticket_type
  bundle_ids UUID[] NOT NULL DEFAULT '{}',
  checklist JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT trigger_rules_has_ticket_type CHECK (trigger_rules ? 'ticket_type')
);

CREATE INDEX idx_packages_org_id ON packages(org_id);
CREATE INDEX idx_packages_property_id ON packages(property_id);
CREATE INDEX idx_packages_trigger_type ON packages(trigger_type);

-- Package runs - tracks execution of packages
CREATE TABLE package_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  trigger_type trigger_type NOT NULL,
  trigger_ref TEXT NOT NULL, -- e.g., 'booking:uuid' or 'day:2025-01-15'
  status package_run_status NOT NULL DEFAULT 'created',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (property_id, package_id, trigger_type, trigger_ref)
);

CREATE INDEX idx_package_runs_org_id ON package_runs(org_id);
CREATE INDEX idx_package_runs_package_id ON package_runs(package_id);
CREATE INDEX idx_package_runs_status ON package_runs(status);

-- Add FK from properties to packages for turnover_package_id
ALTER TABLE properties
  ADD CONSTRAINT fk_properties_turnover_package
  FOREIGN KEY (turnover_package_id) REFERENCES packages(id) ON DELETE SET NULL;

-- RLS Policies for bundles
ALTER TABLE bundles ENABLE ROW LEVEL SECURITY;

-- Admin global bundles visible to all in org
CREATE POLICY "Users can view admin_global bundles in their org" ON bundles
  FOR SELECT
  USING (
    scope = 'admin_global' AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = bundles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

-- User private bundles visible only to owner
CREATE POLICY "Users can view their own private bundles" ON bundles
  FOR SELECT
  USING (
    scope = 'user_private' AND owner_user_id = auth.uid()
  );

-- Users can create private bundles
CREATE POLICY "Users can create private bundles" ON bundles
  FOR INSERT
  WITH CHECK (
    scope = 'user_private' AND
    owner_user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = bundles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Org admins can create global bundles
CREATE POLICY "Org admins can create global bundles" ON bundles
  FOR INSERT
  WITH CHECK (
    scope = 'admin_global' AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = bundles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- Users can update their own bundles
CREATE POLICY "Users can update their own bundles" ON bundles
  FOR UPDATE
  USING (
    owner_user_id = auth.uid() OR
    (scope = 'admin_global' AND EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = bundles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    ))
  );

-- RLS Policies for packages
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view packages in their org" ON packages
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = packages.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Users can create packages in their org" ON packages
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = packages.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Users can update packages in their org" ON packages
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = packages.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for package_runs
ALTER TABLE package_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view package runs in their org" ON package_runs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = package_runs.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );
