-- Migration: 007_billing
-- Subscriptions, invoices, and billing profiles

-- Subscriptions
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_customer_id TEXT NOT NULL,
  stripe_subscription_id TEXT NOT NULL,
  plan TEXT NOT NULL, -- 'basic' or 'smart'
  status TEXT NOT NULL, -- 'active', 'past_due', 'cancelled', etc.
  current_period_end TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_org_id ON subscriptions(org_id);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE UNIQUE INDEX idx_subscriptions_stripe_subscription ON subscriptions(stripe_subscription_id);

-- Invoices
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_invoice_id TEXT,
  invoice_number TEXT NOT NULL UNIQUE,
  financial_year TEXT NOT NULL, -- e.g., 'FY2025-2026'
  gst_fields JSONB NOT NULL DEFAULT '{}', -- Snapshot of GST info at invoice time
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL, -- 'draft', 'paid', 'void'
  pdf_storage_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoices_org_id ON invoices(org_id);
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_financial_year ON invoices(financial_year);
CREATE INDEX idx_invoices_status ON invoices(status);

-- Invoice counters for sequential numbering
CREATE TABLE invoice_counters (
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  financial_year TEXT NOT NULL,
  last_seq INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (org_id, financial_year)
);

-- Organization billing profiles
CREATE TABLE org_billing_profiles (
  org_id UUID PRIMARY KEY REFERENCES orgs(id) ON DELETE CASCADE,
  legal_name TEXT NOT NULL,
  gstin TEXT, -- GST number
  address JSONB NOT NULL DEFAULT '{}',
  state_code TEXT,
  invoice_prefix TEXT NOT NULL DEFAULT 'CC',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User billing profiles
CREATE TABLE user_billing_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  legal_name TEXT NOT NULL,
  gstin TEXT,
  address JSONB NOT NULL DEFAULT '{}',
  place_of_supply_state_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_billing_profiles_org_id ON user_billing_profiles(org_id);
CREATE INDEX idx_user_billing_profiles_user_id ON user_billing_profiles(user_id);

-- Function to get next invoice number
CREATE OR REPLACE FUNCTION get_next_invoice_number(
  p_org_id UUID,
  p_financial_year TEXT
)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_seq INTEGER;
BEGIN
  -- Get or default prefix
  SELECT COALESCE(invoice_prefix, 'CC') INTO v_prefix
  FROM org_billing_profiles
  WHERE org_id = p_org_id;

  IF v_prefix IS NULL THEN
    v_prefix := 'CC';
  END IF;

  -- Lock and increment counter
  INSERT INTO invoice_counters (org_id, financial_year, last_seq)
  VALUES (p_org_id, p_financial_year, 1)
  ON CONFLICT (org_id, financial_year)
  DO UPDATE SET last_seq = invoice_counters.last_seq + 1
  RETURNING last_seq INTO v_seq;

  -- Return formatted invoice number
  RETURN v_prefix || '/' || p_financial_year || '/' || LPAD(v_seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- RLS Policies for subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their org subscriptions" ON subscriptions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = subscriptions.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for invoices
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their org invoices" ON invoices
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = invoices.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role IN ('org_admin', 'user')
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for org_billing_profiles
ALTER TABLE org_billing_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage org billing profile" ON org_billing_profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = org_billing_profiles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for user_billing_profiles
ALTER TABLE user_billing_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own billing profile" ON user_billing_profiles
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can manage their own billing profile" ON user_billing_profiles
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Admins can view user billing profiles" ON user_billing_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = user_billing_profiles.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );
