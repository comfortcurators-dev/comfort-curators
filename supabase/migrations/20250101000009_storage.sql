-- Migration: 009_storage
-- Storage bucket policies

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES
  ('property-photos', 'property-photos', false),
  ('ticket-evidence', 'ticket-evidence', false),
  ('bills', 'bills', false),
  ('dsar-exports', 'dsar-exports', false);

-- Property photos policies
CREATE POLICY "Property owners and admins can view photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'property-photos' AND
    EXISTS (
      SELECT 1 FROM properties p
      JOIN org_members om ON om.org_id = p.org_id
      WHERE (storage.foldername(name))[1] = p.id::text
        AND om.user_id = auth.uid()
        AND (p.owner_user_id = auth.uid() OR om.role = 'org_admin')
        AND om.status = 'active'
    )
  );

CREATE POLICY "Property owners and admins can upload photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'property-photos' AND
    EXISTS (
      SELECT 1 FROM properties p
      JOIN org_members om ON om.org_id = p.org_id
      WHERE (storage.foldername(name))[1] = p.id::text
        AND om.user_id = auth.uid()
        AND (p.owner_user_id = auth.uid() OR om.role = 'org_admin')
        AND om.status = 'active'
    )
  );

CREATE POLICY "Property owners and admins can delete photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'property-photos' AND
    EXISTS (
      SELECT 1 FROM properties p
      JOIN org_members om ON om.org_id = p.org_id
      WHERE (storage.foldername(name))[1] = p.id::text
        AND om.user_id = auth.uid()
        AND (p.owner_user_id = auth.uid() OR om.role = 'org_admin')
        AND om.status = 'active'
    )
  );

-- Ticket evidence policies
CREATE POLICY "Ticket participants can view evidence"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'ticket-evidence' AND
    EXISTS (
      SELECT 1 FROM tickets t
      JOIN org_members om ON om.org_id = t.org_id
      WHERE (storage.foldername(name))[1] = t.id::text
        AND om.user_id = auth.uid()
        AND (t.created_by = auth.uid() OR t.assigned_to = auth.uid() OR om.role = 'org_admin')
        AND om.status = 'active'
    )
  );

CREATE POLICY "Assigned staff can upload evidence"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'ticket-evidence' AND
    EXISTS (
      SELECT 1 FROM tickets t
      WHERE (storage.foldername(name))[1] = t.id::text
        AND t.assigned_to = auth.uid()
    )
  );

-- Bills bucket - admin only
CREATE POLICY "Admins can manage bills"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'bills' AND
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.user_id = auth.uid()
        AND om.role = 'org_admin'
        AND om.status = 'active'
    )
  );

-- DSAR exports - user and admin only
CREATE POLICY "Users can view their own DSAR exports"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'dsar-exports' AND
    EXISTS (
      SELECT 1 FROM dsar_requests dr
      WHERE dr.result_storage_path = name
        AND dr.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage DSAR exports"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'dsar-exports' AND
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.user_id = auth.uid()
        AND om.role = 'org_admin'
        AND om.status = 'active'
    )
  );
