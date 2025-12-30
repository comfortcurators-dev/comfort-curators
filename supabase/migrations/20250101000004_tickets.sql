-- Migration: 004_tickets
-- Tickets, ticket events, and ticket evidence

-- Enums
CREATE TYPE ticket_type AS ENUM (
  'turnover_cleaning',
  'routine_cleaning',
  'restock',
  'maintenance',
  'inspection',
  'custom'
);
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE ticket_status AS ENUM (
  'created',
  'assigned',
  'accepted',
  'in_progress',
  'completed',
  'cancelled'
);

-- Tickets table
CREATE TABLE tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  type ticket_type NOT NULL,
  tags TEXT[] NOT NULL DEFAULT '{}',
  priority ticket_priority NOT NULL DEFAULT 'medium',
  due_at TIMESTAMPTZ,
  status ticket_status NOT NULL DEFAULT 'created',
  bundles_applied UUID[] NOT NULL DEFAULT '{}',
  checklist JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

CREATE INDEX idx_tickets_org_id ON tickets(org_id);
CREATE INDEX idx_tickets_property_id ON tickets(property_id);
CREATE INDEX idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_due_at ON tickets(due_at);
CREATE INDEX idx_tickets_type ON tickets(type);
CREATE INDEX idx_tickets_archived_at ON tickets(archived_at);

-- Ticket events - activity log
CREATE TABLE ticket_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ticket_events_ticket_id ON ticket_events(ticket_id);
CREATE INDEX idx_ticket_events_created_at ON ticket_events(created_at);

-- Ticket evidence - uploaded files
CREATE TABLE ticket_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ticket_evidence_ticket_id ON ticket_evidence(ticket_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_ticket_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_updated_at
  BEFORE UPDATE ON tickets
  FOR EACH ROW EXECUTE FUNCTION update_ticket_updated_at();

-- RLS Policies for tickets
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Users and admins can view all tickets in their org
CREATE POLICY "Users can view tickets in their org" ON tickets
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = tickets.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Staff can view only assigned or unassigned tickets (depends on org settings)
CREATE POLICY "Staff can view assigned or claimable tickets" ON tickets
  FOR SELECT
  USING (
    (assigned_to = auth.uid() OR assigned_to IS NULL) AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = tickets.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'staff'
        AND org_members.status = 'active'
    )
  );

-- Users can create tickets
CREATE POLICY "Users can create tickets" ON tickets
  FOR INSERT
  WITH CHECK (
    created_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = tickets.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Users and admins can update tickets
CREATE POLICY "Users can update tickets in their org" ON tickets
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = tickets.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Staff can update assigned tickets (status, checklist, evidence)
CREATE POLICY "Staff can update assigned tickets" ON tickets
  FOR UPDATE
  USING (
    assigned_to = auth.uid() AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = tickets.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'staff'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for ticket_events
ALTER TABLE ticket_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ticket events in their org" ON ticket_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = ticket_events.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for ticket_evidence
ALTER TABLE ticket_evidence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ticket evidence in their org" ON ticket_evidence
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = ticket_evidence.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Staff can upload evidence for assigned tickets" ON ticket_evidence
  FOR INSERT
  WITH CHECK (
    uploaded_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM tickets t
      WHERE t.id = ticket_evidence.ticket_id
        AND t.assigned_to = auth.uid()
    )
  );
