-- Migration: 008_compliance
-- Compliance, audit logs, notifications, and cron cursors

-- Consent status enum
CREATE TYPE consent_status AS ENUM ('granted', 'revoked');
CREATE TYPE dsar_type AS ENUM ('export', 'delete');
CREATE TYPE dsar_status AS ENUM ('requested', 'in_review', 'completed', 'rejected');

-- Consent logs
CREATE TABLE consent_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL, -- e.g., 'marketing', 'analytics'
  status consent_status NOT NULL,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consent_logs_org_id ON consent_logs(org_id);
CREATE INDEX idx_consent_logs_user_id ON consent_logs(user_id);
CREATE INDEX idx_consent_logs_purpose ON consent_logs(purpose);

-- DSAR (Data Subject Access Request) requests
CREATE TABLE dsar_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type dsar_type NOT NULL,
  status dsar_status NOT NULL DEFAULT 'requested',
  result_storage_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_dsar_requests_org_id ON dsar_requests(org_id);
CREATE INDEX idx_dsar_requests_user_id ON dsar_requests(user_id);
CREATE INDEX idx_dsar_requests_status ON dsar_requests(status);

-- Audit logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity TEXT NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}',
  ip TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_org_id ON audit_logs(org_id);
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read_at ON notifications(read_at);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Cron cursors for batch processing
CREATE TABLE cron_cursors (
  name TEXT PRIMARY KEY,
  cursor JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies for consent_logs
ALTER TABLE consent_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own consent logs" ON consent_logs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can create their own consent logs" ON consent_logs
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view consent logs in their org" ON consent_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = consent_logs.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for dsar_requests
ALTER TABLE dsar_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own DSAR requests" ON dsar_requests
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can create their own DSAR requests" ON dsar_requests
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view and manage DSAR requests in their org" ON dsar_requests
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = dsar_requests.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs in their org" ON audit_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = audit_logs.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

-- Function to log audit events
CREATE OR REPLACE FUNCTION log_audit_event(
  p_org_id UUID,
  p_actor_id UUID,
  p_action TEXT,
  p_entity TEXT,
  p_entity_id UUID,
  p_metadata JSONB DEFAULT '{}',
  p_ip TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO audit_logs (org_id, actor_id, action, entity, entity_id, metadata, ip, user_agent)
  VALUES (p_org_id, p_actor_id, p_action, p_entity, p_entity_id, p_metadata, p_ip, p_user_agent)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create notification
CREATE OR REPLACE FUNCTION create_notification(
  p_org_id UUID,
  p_user_id UUID,
  p_type TEXT,
  p_payload JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO notifications (org_id, user_id, type, payload)
  VALUES (p_org_id, p_user_id, p_type, p_payload)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
