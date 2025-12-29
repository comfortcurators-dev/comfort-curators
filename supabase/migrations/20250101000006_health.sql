-- Migration: 006_health
-- Property health scoring and events

-- Property health - cached scores
CREATE TABLE property_health (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL UNIQUE REFERENCES properties(id) ON DELETE CASCADE,
  health_score INTEGER NOT NULL CHECK (health_score >= 0 AND health_score <= 100),
  dimensions JSONB NOT NULL DEFAULT '{
    "cleanliness": {"score": 100, "weight": 0.35},
    "consumables": {"score": 100, "weight": 0.25},
    "maintenance": {"score": 100, "weight": 0.25},
    "ticket_debt": {"score": 100, "weight": 0.15}
  }',
  explanation JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_property_health_org_id ON property_health(org_id);
CREATE INDEX idx_property_health_property_id ON property_health(property_id);
CREATE INDEX idx_property_health_score ON property_health(health_score);

-- Health events - recomputation log
CREATE TABLE health_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  cause TEXT NOT NULL, -- e.g., 'booking_sync', 'ticket_update', 'inventory_change', 'scheduled'
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_health_events_org_id ON health_events(org_id);
CREATE INDEX idx_health_events_property_id ON health_events(property_id);
CREATE INDEX idx_health_events_created_at ON health_events(created_at);

-- RLS Policies for property_health
ALTER TABLE property_health ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view property health in their org" ON property_health
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = property_health.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for health_events
ALTER TABLE health_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view health events in their org" ON health_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = health_events.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- Function to initialize property health on property creation
CREATE OR REPLACE FUNCTION init_property_health()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO property_health (org_id, property_id, health_score, dimensions, explanation)
  VALUES (
    NEW.org_id,
    NEW.id,
    100,
    '{
      "cleanliness": {"score": 100, "weight": 0.35, "reasons": []},
      "consumables": {"score": 100, "weight": 0.25, "reasons": ["Turnover package not configured"]},
      "maintenance": {"score": 100, "weight": 0.25, "reasons": []},
      "ticket_debt": {"score": 100, "weight": 0.15, "reasons": []}
    }',
    '{"summary": "New property - health score initialized"}'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_property_created_init_health
  AFTER INSERT ON properties
  FOR EACH ROW EXECUTE FUNCTION init_property_health();
