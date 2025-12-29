-- Migration: 005_inventory
-- Warehouses, SKUs, inventory, and transactions

-- Enums
CREATE TYPE item_line_status AS ENUM (
  'needed',
  'shortage',
  'reserved',
  'picked',
  'consumed',
  'returned'
);
CREATE TYPE inventory_transaction_type AS ENUM (
  'stock_in',
  'reserve',
  'release',
  'deduct',
  'adjust'
);
CREATE TYPE substitution_status AS ENUM ('requested', 'approved', 'rejected');

-- Warehouses
CREATE TABLE warehouses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_warehouses_org_id ON warehouses(org_id);

-- Add FK from staff_profiles to warehouses
ALTER TABLE staff_profiles
  ADD CONSTRAINT fk_staff_profiles_home_warehouse
  FOREIGN KEY (home_warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL;

-- Add FK from properties to warehouses
ALTER TABLE properties
  ADD CONSTRAINT fk_properties_service_warehouse
  FOREIGN KEY (service_warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL;

-- Inventory SKUs
CREATE TABLE inventory_skus (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  sku_code TEXT NOT NULL,
  name TEXT NOT NULL,
  unit TEXT NOT NULL,
  min_stock NUMERIC NOT NULL DEFAULT 0,
  reorder_level NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (org_id, sku_code)
);

CREATE INDEX idx_inventory_skus_org_id ON inventory_skus(org_id);

-- Warehouse inventory - stock levels per warehouse
CREATE TABLE warehouse_inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  sku_id UUID NOT NULL REFERENCES inventory_skus(id) ON DELETE CASCADE,
  on_hand NUMERIC NOT NULL DEFAULT 0 CHECK (on_hand >= 0),
  reserved NUMERIC NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (warehouse_id, sku_id),
  CONSTRAINT check_reserved_lte_on_hand CHECK (reserved <= on_hand)
);

CREATE INDEX idx_warehouse_inventory_warehouse_id ON warehouse_inventory(warehouse_id);
CREATE INDEX idx_warehouse_inventory_sku_id ON warehouse_inventory(sku_id);

-- Inventory transactions - movement log
CREATE TABLE inventory_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  sku_id UUID NOT NULL REFERENCES inventory_skus(id) ON DELETE CASCADE,
  type inventory_transaction_type NOT NULL,
  qty NUMERIC NOT NULL,
  reference_type TEXT, -- e.g., 'ticket', 'bill', 'manual'
  reference_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inventory_transactions_warehouse_id ON inventory_transactions(warehouse_id);
CREATE INDEX idx_inventory_transactions_sku_id ON inventory_transactions(sku_id);
CREATE INDEX idx_inventory_transactions_type ON inventory_transactions(type);
CREATE INDEX idx_inventory_transactions_created_at ON inventory_transactions(created_at);

-- Ticket item lines - SKU requirements per ticket
CREATE TABLE ticket_item_lines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  sku_id UUID NOT NULL REFERENCES inventory_skus(id) ON DELETE CASCADE,
  unit TEXT NOT NULL,
  qty_required NUMERIC NOT NULL,
  qty_reserved NUMERIC NOT NULL DEFAULT 0,
  qty_picked NUMERIC NOT NULL DEFAULT 0,
  qty_used NUMERIC NOT NULL DEFAULT 0,
  qty_returned NUMERIC NOT NULL DEFAULT 0,
  status item_line_status NOT NULL DEFAULT 'needed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ticket_item_lines_ticket_id ON ticket_item_lines(ticket_id);
CREATE INDEX idx_ticket_item_lines_sku_id ON ticket_item_lines(sku_id);
CREATE INDEX idx_ticket_item_lines_status ON ticket_item_lines(status);

-- Item substitution requests
CREATE TABLE item_substitution_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  ticket_item_line_id UUID NOT NULL REFERENCES ticket_item_lines(id) ON DELETE CASCADE,
  proposed_sku_id UUID NOT NULL REFERENCES inventory_skus(id) ON DELETE CASCADE,
  proposed_qty NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  status substitution_status NOT NULL DEFAULT 'requested',
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  decided_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  decided_at TIMESTAMPTZ
);

CREATE INDEX idx_item_substitution_requests_ticket_item_line_id ON item_substitution_requests(ticket_item_line_id);
CREATE INDEX idx_item_substitution_requests_status ON item_substitution_requests(status);

-- RLS Policies for warehouses
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view warehouses in their org" ON warehouses
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = warehouses.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Admins can manage warehouses" ON warehouses
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = warehouses.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for inventory_skus
ALTER TABLE inventory_skus ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view SKUs in their org" ON inventory_skus
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = inventory_skus.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Admins can manage SKUs" ON inventory_skus
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = inventory_skus.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for warehouse_inventory
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view inventory in their org" ON warehouse_inventory
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = warehouse_inventory.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for ticket_item_lines
ALTER TABLE ticket_item_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ticket item lines in their org" ON ticket_item_lines
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = ticket_item_lines.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for inventory_transactions
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view inventory transactions" ON inventory_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = inventory_transactions.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.role = 'org_admin'
        AND org_members.status = 'active'
    )
  );

-- RLS Policies for item_substitution_requests
ALTER TABLE item_substitution_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view substitution requests in their org" ON item_substitution_requests
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = item_substitution_requests.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );

CREATE POLICY "Staff can create substitution requests" ON item_substitution_requests
  FOR INSERT WITH CHECK (
    requested_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_members.org_id = item_substitution_requests.org_id
        AND org_members.user_id = auth.uid()
        AND org_members.status = 'active'
    )
  );
