-- Migration: 002_properties
-- Properties and bookings tables

-- Entry method enum
CREATE TYPE entry_method AS ENUM ('keypad', 'keybox', 'doorman', 'host_meet', 'other');
CREATE TYPE booking_status AS ENUM ('confirmed', 'cancelled');

-- Properties table
CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  service_warehouse_id UUID, -- FK added after warehouses table
  turnover_package_id UUID, -- FK added after packages table
  access_notes TEXT NOT NULL DEFAULT '',
  entry_method entry_method NOT NULL DEFAULT 'other',
  entry_details_encrypted TEXT,
  emergency_contact JSONB NOT NULL DEFAULT '{}',
  ical_url_encrypted TEXT,
  ical_meta JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_properties_org_id ON properties(org_id);
CREATE INDEX idx_properties_owner_user_id ON properties(owner_user_id);
CREATE INDEX idx_properties_location ON properties USING GIST (
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)
) WHERE lng IS NOT NULL AND lat IS NOT NULL;

-- Property photos
CREATE TABLE property_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_property_photos_property_id ON property_photos(property_id);

-- Bookings from iCal sync
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  source TEXT NOT NULL DEFAULT 'airbnb_ical',
  uid TEXT NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  status booking_status NOT NULL DEFAULT 'confirmed',
  last_modified TIMESTAMPTZ,
  sequence INTEGER,
  raw_hash TEXT NOT NULL,
  raw_payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (property_id, source, uid)
);

CREATE INDEX idx_bookings_org_id ON bookings(org_id);
CREATE INDEX idx_bookings_property_id ON bookings(property_id);
CREATE INDEX idx_bookings_end_at ON bookings(end_at);
CREATE INDEX idx_bookings_status ON bookings(status);

-- RLS Policies for properties
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view properties in their org" ON properties
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = properties.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Users can create properties in their org" ON properties
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = properties.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Property owners and admins can update properties" ON properties
  FOR UPDATE
  USING (
    (owner_user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = properties.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    ))
  );

CREATE POLICY "Property owners and admins can delete properties" ON properties
  FOR DELETE
  USING (
    (owner_user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = properties.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    ))
  );

-- Staff can see limited property info for assigned tickets
CREATE POLICY "Staff can view assigned property info" ON properties
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = properties.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'staff'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for property_photos
ALTER TABLE property_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view property photos in their org" ON property_photos
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = property_photos.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Property owners and admins can manage photos" ON property_photos
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM properties p
      JOIN org_members om ON om.org_id = p.org_id
      WHERE p.id = property_photos.property_id
        AND om.user_id = auth.uid()
        AND (p.owner_user_id = auth.uid() OR om.role = 'org_admin')
        AND om.status = 'active'
    )
  );

-- RLS Policies for bookings
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view bookings in their org" ON bookings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = bookings.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Staff cannot view bookings directly (sensitive data)
