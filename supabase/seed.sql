-- Seed data for development and testing
-- Run with: psql -f supabase/seed.sql or via Supabase dashboard

-- Note: This seed file assumes you've already signed up at least one user
-- The triggers will create their org and profile automatically

-- Insert a test warehouse for the first org (you'll need to replace the org_id)
-- This is a placeholder that should be adjusted after initial user signup

DO $$
DECLARE
  v_org_id UUID;
  v_user_id UUID;
  v_warehouse_id UUID;
  v_property_id UUID;
  v_package_id UUID;
  v_sku_id_1 UUID;
  v_sku_id_2 UUID;
  v_sku_id_3 UUID;
  v_bundle_id UUID;
BEGIN
  -- Get the first org and user (created by signup trigger)
  SELECT org_id, user_id INTO v_org_id, v_user_id
  FROM org_members
  WHERE status = 'active' AND role = 'org_admin'
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE NOTICE 'No org found. Please sign up a user first, then run this seed again.';
    RETURN;
  END IF;

  RAISE NOTICE 'Seeding data for org: %', v_org_id;

  -- Create a warehouse
  INSERT INTO warehouses (org_id, name, address, lat, lng)
  VALUES (v_org_id, 'Main Warehouse', '123 Warehouse Lane, Mumbai', 19.0760, 72.8777)
  RETURNING id INTO v_warehouse_id;

  RAISE NOTICE 'Created warehouse: %', v_warehouse_id;

  -- Create some SKUs
  INSERT INTO inventory_skus (org_id, sku_code, name, unit, min_stock, reorder_level)
  VALUES 
    (v_org_id, 'TOWEL-BATH-WHITE', 'Bath Towel (White)', 'piece', 10, 20),
    (v_org_id, 'SOAP-BAR-LUX', 'Luxury Soap Bar', 'piece', 50, 100),
    (v_org_id, 'SHAMPOO-BTL-50ML', 'Shampoo Bottle 50ml', 'piece', 30, 60)
  RETURNING id INTO v_sku_id_1;

  -- Get the SKU IDs
  SELECT id INTO v_sku_id_1 FROM inventory_skus WHERE org_id = v_org_id AND sku_code = 'TOWEL-BATH-WHITE';
  SELECT id INTO v_sku_id_2 FROM inventory_skus WHERE org_id = v_org_id AND sku_code = 'SOAP-BAR-LUX';
  SELECT id INTO v_sku_id_3 FROM inventory_skus WHERE org_id = v_org_id AND sku_code = 'SHAMPOO-BTL-50ML';

  -- Add initial stock to warehouse
  INSERT INTO warehouse_inventory (org_id, warehouse_id, sku_id, on_hand)
  VALUES 
    (v_org_id, v_warehouse_id, v_sku_id_1, 50),
    (v_org_id, v_warehouse_id, v_sku_id_2, 200),
    (v_org_id, v_warehouse_id, v_sku_id_3, 100);

  -- Create a bundle
  INSERT INTO bundles (org_id, scope, name, description, items)
  VALUES (
    v_org_id,
    'admin_global',
    'Standard Turnover Bundle',
    'Basic items for guest turnover',
    jsonb_build_array(
      jsonb_build_object('sku_id', v_sku_id_1, 'qty', 4, 'unit', 'piece'),
      jsonb_build_object('sku_id', v_sku_id_2, 'qty', 2, 'unit', 'piece'),
      jsonb_build_object('sku_id', v_sku_id_3, 'qty', 2, 'unit', 'piece')
    )
  )
  RETURNING id INTO v_bundle_id;

  RAISE NOTICE 'Created bundle: %', v_bundle_id;

  -- Create a sample property
  INSERT INTO properties (
    org_id, 
    owner_user_id, 
    name, 
    address, 
    lat, 
    lng,
    service_warehouse_id,
    access_notes,
    entry_method,
    emergency_contact
  )
  VALUES (
    v_org_id,
    v_user_id,
    'Seaside Villa',
    '42 Marine Drive, Mumbai, Maharashtra 400020',
    18.9435,
    72.8232,
    v_warehouse_id,
    'Key is in the lockbox. Code is 1234.',
    'keybox',
    '{"name": "Property Manager", "phone": "+91 98765 43210"}'::jsonb
  )
  RETURNING id INTO v_property_id;

  RAISE NOTICE 'Created property: %', v_property_id;

  -- Create a turnover package for the property
  INSERT INTO packages (
    org_id,
    property_id,
    name,
    description,
    trigger_type,
    trigger_rules,
    bundle_ids,
    checklist
  )
  VALUES (
    v_org_id,
    v_property_id,
    'Standard Turnover',
    'Automatic turnover cleaning after checkout',
    'booking_end',
    jsonb_build_object(
      'ticket_type', 'turnover_cleaning',
      'create_offset_hours', 2,
      'dedupe_strategy', 'per_booking'
    ),
    ARRAY[v_bundle_id],
    jsonb_build_array(
      jsonb_build_object('text', 'Change all linens', 'checked', false),
      jsonb_build_object('text', 'Clean bathroom thoroughly', 'checked', false),
      jsonb_build_object('text', 'Vacuum all floors', 'checked', false),
      jsonb_build_object('text', 'Restock amenities', 'checked', false),
      jsonb_build_object('text', 'Take photos of cleaned rooms', 'checked', false)
    )
  )
  RETURNING id INTO v_package_id;

  -- Link package to property as turnover package
  UPDATE properties 
  SET turnover_package_id = v_package_id 
  WHERE id = v_property_id;

  RAISE NOTICE 'Created and linked package: %', v_package_id;

  -- Create a sample ticket
  INSERT INTO tickets (
    org_id,
    property_id,
    created_by,
    title,
    description,
    type,
    priority,
    due_at,
    bundles_applied,
    checklist
  )
  VALUES (
    v_org_id,
    v_property_id,
    v_user_id,
    'Turnover Cleaning - Seaside Villa',
    'Guest checkout turnover cleaning',
    'turnover_cleaning',
    'medium',
    NOW() + INTERVAL '2 days',
    ARRAY[v_bundle_id],
    jsonb_build_array(
      jsonb_build_object('text', 'Change all linens', 'checked', false),
      jsonb_build_object('text', 'Clean bathroom thoroughly', 'checked', false),
      jsonb_build_object('text', 'Vacuum all floors', 'checked', false)
    )
  );

  RAISE NOTICE 'Seed data created successfully!';
END $$;
