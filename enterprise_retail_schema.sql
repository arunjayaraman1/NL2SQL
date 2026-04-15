-- =============================================================================
-- Enterprise Retail Operations Schema + Synthetic Data (PostgreSQL)
-- =============================================================================
-- Characteristics:
-- - Multi-domain model: sales, logistics, finance, support, procurement
-- - Complex joins across orders, shipments, payments, returns, and tickets
-- - Realistic imperfections: NULLs, pending states, failures, partial fulfillment
-- =============================================================================

-- Drop tables in dependency-safe order
DROP TABLE IF EXISTS purchase_order_items;
DROP TABLE IF EXISTS purchase_orders;
DROP TABLE IF EXISTS inventory_snapshots;
DROP TABLE IF EXISTS ticket_events;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS sales_reps;
DROP TABLE IF EXISTS customer_addresses;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS warehouses;
DROP TABLE IF EXISTS regions;

-- -----------------------------------------------------------------------------
-- Master tables
-- -----------------------------------------------------------------------------

CREATE TABLE regions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) UNIQUE NOT NULL,
    country_code CHAR(2) NOT NULL,
    timezone VARCHAR(64) NOT NULL
);

CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES regions(id),
    warehouse_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(120) NOT NULL,
    city VARCHAR(80) NOT NULL,
    capacity_units INTEGER NOT NULL CHECK (capacity_units > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    opened_on DATE NOT NULL
);

CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(140) NOT NULL,
    supplier_tier VARCHAR(20) NOT NULL CHECK (supplier_tier IN ('gold', 'silver', 'bronze')),
    contact_email VARCHAR(120),
    contact_phone VARCHAR(30),
    payment_terms_days INTEGER NOT NULL DEFAULT 30,
    risk_score NUMERIC(5,2) CHECK (risk_score BETWEEN 0 AND 100)
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(30) UNIQUE NOT NULL,
    product_name VARCHAR(160) NOT NULL,
    category VARCHAR(60) NOT NULL,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
    list_price NUMERIC(12,2) NOT NULL CHECK (list_price >= 0),
    cost_price NUMERIC(12,2) NOT NULL CHECK (cost_price >= 0),
    launch_date DATE NOT NULL,
    discontinued_at TIMESTAMP,
    hazardous_material BOOLEAN NOT NULL DEFAULT FALSE,
    warranty_months INTEGER
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    customer_code VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    phone VARCHAR(30),
    date_of_birth DATE,
    loyalty_tier VARCHAR(20) NOT NULL CHECK (loyalty_tier IN ('basic', 'silver', 'gold', 'platinum')),
    signup_date DATE NOT NULL,
    preferred_warehouse_id INTEGER REFERENCES warehouses(id),
    marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE customer_addresses (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    label VARCHAR(30) NOT NULL,
    line1 VARCHAR(180) NOT NULL,
    line2 VARCHAR(180),
    city VARCHAR(80) NOT NULL,
    state_or_region VARCHAR(80),
    postal_code VARCHAR(20),
    country_code CHAR(2) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE sales_reps (
    id SERIAL PRIMARY KEY,
    rep_code VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    team VARCHAR(60) NOT NULL,
    manager_id INTEGER REFERENCES sales_reps(id),
    hired_at DATE NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- Transactional tables
-- -----------------------------------------------------------------------------

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(30) UNIQUE NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    shipping_address_id INTEGER REFERENCES customer_addresses(id),
    sales_rep_id INTEGER REFERENCES sales_reps(id),
    order_status VARCHAR(20) NOT NULL CHECK (order_status IN ('draft', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'returned')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    ordered_at TIMESTAMP NOT NULL,
    required_by DATE,
    fulfilled_at TIMESTAMP,
    cancelled_reason TEXT,
    channel VARCHAR(30) NOT NULL CHECK (channel IN ('web', 'mobile', 'marketplace', 'inside_sales')),
    notes TEXT
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_pct NUMERIC(5,2) CHECK (discount_pct BETWEEN 0 AND 100),
    tax_pct NUMERIC(5,2) NOT NULL DEFAULT 8.25,
    backordered_qty INTEGER NOT NULL DEFAULT 0 CHECK (backordered_qty >= 0),
    UNIQUE(order_id, product_id)
);

CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
    carrier VARCHAR(60),
    service_level VARCHAR(30) CHECK (service_level IN ('standard', 'expedited', 'overnight')),
    tracking_number VARCHAR(80),
    shipping_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    shipment_status VARCHAR(20) NOT NULL CHECK (shipment_status IN ('pending', 'packed', 'in_transit', 'delivered', 'lost', 'returned_to_sender'))
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('card', 'wire', 'wallet', 'invoice')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    paid_at TIMESTAMP,
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('authorized', 'captured', 'failed', 'refunded', 'pending')),
    transaction_ref VARCHAR(120),
    failure_reason TEXT
);

CREATE TABLE returns (
    id SERIAL PRIMARY KEY,
    order_item_id INTEGER NOT NULL REFERENCES order_items(id),
    approved_by_rep_id INTEGER REFERENCES sales_reps(id),
    requested_at TIMESTAMP NOT NULL,
    approved_at TIMESTAMP,
    received_at TIMESTAMP,
    reason_code VARCHAR(30) NOT NULL CHECK (reason_code IN ('damaged', 'wrong_item', 'late_delivery', 'quality_issue', 'changed_mind')),
    return_status VARCHAR(20) NOT NULL CHECK (return_status IN ('requested', 'approved', 'received', 'rejected', 'refunded')),
    refund_amount NUMERIC(12,2),
    notes TEXT
);

CREATE TABLE support_tickets (
    id SERIAL PRIMARY KEY,
    ticket_number VARCHAR(30) UNIQUE NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    order_id INTEGER REFERENCES orders(id),
    assigned_rep_id INTEGER REFERENCES sales_reps(id),
    category VARCHAR(40) NOT NULL CHECK (category IN ('billing', 'delivery', 'technical', 'return', 'account')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    ticket_status VARCHAR(20) NOT NULL CHECK (ticket_status IN ('open', 'waiting_customer', 'in_progress', 'resolved', 'closed')),
    opened_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    satisfaction_rating INTEGER CHECK (satisfaction_rating BETWEEN 1 AND 5),
    summary TEXT NOT NULL
);

CREATE TABLE ticket_events (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL REFERENCES support_tickets(id),
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN ('created', 'assignment', 'customer_reply', 'internal_note', 'status_change', 'resolution')),
    actor_type VARCHAR(20) NOT NULL CHECK (actor_type IN ('customer', 'rep', 'system')),
    actor_id INTEGER,
    note TEXT,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE inventory_snapshots (
    id SERIAL PRIMARY KEY,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    snapshot_date DATE NOT NULL,
    on_hand_qty INTEGER NOT NULL CHECK (on_hand_qty >= 0),
    reserved_qty INTEGER NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
    in_transit_qty INTEGER NOT NULL DEFAULT 0 CHECK (in_transit_qty >= 0),
    damaged_qty INTEGER NOT NULL DEFAULT 0 CHECK (damaged_qty >= 0),
    UNIQUE (warehouse_id, product_id, snapshot_date)
);

CREATE TABLE purchase_orders (
    id SERIAL PRIMARY KEY,
    po_number VARCHAR(30) UNIQUE NOT NULL,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
    destination_warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
    created_by_rep_id INTEGER REFERENCES sales_reps(id),
    po_status VARCHAR(20) NOT NULL CHECK (po_status IN ('draft', 'submitted', 'partially_received', 'received', 'cancelled')),
    created_at TIMESTAMP NOT NULL,
    expected_arrival DATE,
    received_at TIMESTAMP,
    total_amount NUMERIC(14,2) NOT NULL CHECK (total_amount >= 0)
);

CREATE TABLE purchase_order_items (
    id SERIAL PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL REFERENCES purchase_orders(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity_ordered INTEGER NOT NULL CHECK (quantity_ordered > 0),
    quantity_received INTEGER CHECK (quantity_received >= 0),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    UNIQUE (purchase_order_id, product_id)
);

-- -----------------------------------------------------------------------------
-- Synthetic data inserts
-- -----------------------------------------------------------------------------

INSERT INTO regions (name, country_code, timezone) VALUES
('North America East', 'US', 'America/New_York'),
('North America West', 'US', 'America/Los_Angeles'),
('Europe Central', 'DE', 'Europe/Berlin');

INSERT INTO warehouses (region_id, warehouse_code, name, city, capacity_units, is_active, opened_on) VALUES
(1, 'WHS-NJ-01', 'New Jersey Fulfillment Center', 'Newark', 200000, TRUE, '2018-04-15'),
(2, 'WHS-CA-01', 'California Distribution Hub', 'Fresno', 250000, TRUE, '2019-07-02'),
(3, 'WHS-DE-01', 'Berlin Crossdock', 'Berlin', 90000, TRUE, '2021-01-20'),
(2, 'WHS-NV-02', 'Nevada Overflow Storage', 'Reno', 60000, FALSE, '2020-10-10');

INSERT INTO suppliers (supplier_name, supplier_tier, contact_email, contact_phone, payment_terms_days, risk_score) VALUES
('Orion Components Ltd', 'gold', 'ops@orioncomponents.com', '+1-212-555-0100', 45, 12.20),
('Nova Industrial Supply', 'silver', 'sales@novasupply.io', NULL, 30, 36.80),
('Helix Smart Devices', 'gold', 'account-mgr@helix.dev', '+49-30-555-1900', 60, 18.10),
('Vertex Basic Goods', 'bronze', NULL, '+1-650-555-7711', 15, 62.90);

INSERT INTO products (sku, product_name, category, supplier_id, list_price, cost_price, launch_date, discontinued_at, hazardous_material, warranty_months) VALUES
('SKU-1001', 'AeroNoise Cancelling Headphones', 'electronics', 1, 199.99, 109.00, '2022-03-11', NULL, FALSE, 24),
('SKU-1002', 'Pulse Fitness Watch X', 'wearables', 3, 249.00, 134.50, '2023-01-15', NULL, FALSE, 18),
('SKU-1003', 'Home Mesh Router Pro', 'networking', 1, 179.00, 92.40, '2021-06-30', NULL, FALSE, 36),
('SKU-1004', 'Ergo Office Chair Plus', 'furniture', 2, 329.00, 201.00, '2020-09-18', NULL, FALSE, 48),
('SKU-1005', 'Portable Power Bank 20k', 'accessories', 4, 59.00, 28.10, '2021-11-02', NULL, TRUE, 12),
('SKU-1006', 'Smart LED Desk Lamp', 'home_office', 2, 89.00, 44.20, '2019-04-17', '2025-02-01 00:00:00', FALSE, 12),
('SKU-1007', '4K Webcam Studio', 'electronics', 1, 139.00, 74.00, '2023-07-09', NULL, FALSE, 24),
('SKU-1008', 'Mechanical Keyboard TKL', 'peripherals', 3, 119.00, 58.75, '2022-10-21', NULL, FALSE, 24),
('SKU-1009', 'USB-C Dock 12-in-1', 'peripherals', 2, 149.00, 82.00, '2024-02-12', NULL, FALSE, 18),
('SKU-1010', 'Compact Air Purifier Mini', 'home', 4, 99.00, 51.30, '2020-12-03', NULL, FALSE, 24);

INSERT INTO customers (customer_code, full_name, email, phone, date_of_birth, loyalty_tier, signup_date, preferred_warehouse_id, marketing_opt_in) VALUES
('CUST-0001', 'Maya Thompson', 'maya.thompson@example.com', '+1-408-555-1122', '1990-05-11', 'gold', '2021-01-08', 2, TRUE),
('CUST-0002', 'Ethan Rivera', 'ethan.rivera@example.com', NULL, '1985-09-17', 'silver', '2022-07-19', 1, FALSE),
('CUST-0003', 'Priya Nair', 'priya.nair@example.com', '+1-917-555-2911', NULL, 'platinum', '2020-03-25', 1, TRUE),
('CUST-0004', 'Lucas Meyer', 'lucas.meyer@example.de', '+49-30-444-8821', '1994-12-02', 'basic', '2024-04-04', 3, TRUE),
('CUST-0005', 'Sofia Alvarez', 'sofia.alvarez@example.com', '+1-646-555-3422', '1998-01-30', 'silver', '2023-06-14', NULL, FALSE),
('CUST-0006', 'Noah Brooks', 'noah.brooks@example.com', NULL, '1989-08-03', 'basic', '2022-11-22', 2, TRUE),
('CUST-0007', 'Amelia Chen', 'amelia.chen@example.com', '+1-310-555-0881', '1992-02-14', 'gold', '2021-09-30', 2, TRUE),
('CUST-0008', 'Oliver Grant', 'oliver.grant@example.com', '+1-212-555-7730', NULL, 'silver', '2024-01-12', 1, FALSE);

INSERT INTO customer_addresses (customer_id, label, line1, line2, city, state_or_region, postal_code, country_code, is_default) VALUES
(1, 'home', '112 Market St', 'Apt 4B', 'San Jose', 'CA', '95113', 'US', TRUE),
(1, 'office', '540 Howard St', NULL, 'San Francisco', 'CA', '94105', 'US', FALSE),
(2, 'home', '91 Pine Avenue', NULL, 'Jersey City', 'NJ', '07302', 'US', TRUE),
(3, 'home', '8 Lexington Ave', NULL, 'New York', 'NY', '10010', 'US', TRUE),
(4, 'home', 'Brunnenstrasse 14', NULL, 'Berlin', NULL, '10119', 'DE', TRUE),
(5, 'home', '77 Ocean Dr', NULL, 'Miami', 'FL', '33139', 'US', TRUE),
(6, 'home', '650 Mission Blvd', 'Unit 9', 'Los Angeles', 'CA', '90012', 'US', TRUE),
(7, 'home', '389 Sunset Blvd', NULL, 'Santa Monica', 'CA', '90401', 'US', TRUE),
(8, 'home', '44 W 56th St', NULL, 'New York', 'NY', '10019', 'US', TRUE);

INSERT INTO sales_reps (rep_code, full_name, email, team, manager_id, hired_at, active) VALUES
('REP-100', 'Hannah Cole', 'hannah.cole@retailcorp.com', 'enterprise', NULL, '2018-02-12', TRUE),
('REP-101', 'Jon Park', 'jon.park@retailcorp.com', 'enterprise', 1, '2019-06-18', TRUE),
('REP-102', 'Leah Morgan', 'leah.morgan@retailcorp.com', 'smb', 1, '2020-01-09', TRUE),
('REP-103', 'Ravi Patel', 'ravi.patel@retailcorp.com', 'smb', 3, '2021-05-03', TRUE),
('REP-104', 'Claire Dubois', 'claire.dubois@retailcorp.com', 'international', 1, '2022-02-21', TRUE),
('REP-105', 'Miguel Santos', 'miguel.santos@retailcorp.com', 'support_liaison', 2, '2023-08-14', TRUE),
('REP-106', 'Dana Kim', 'dana.kim@retailcorp.com', 'enterprise', 2, '2024-02-05', FALSE);

INSERT INTO orders (order_number, customer_id, shipping_address_id, sales_rep_id, order_status, priority, currency, ordered_at, required_by, fulfilled_at, cancelled_reason, channel, notes) VALUES
('ORD-2025-0001', 1, 1, 2, 'delivered', 'normal', 'USD', '2025-01-06 09:22:00', '2025-01-14', '2025-01-10 16:05:00', NULL, 'web', NULL),
('ORD-2025-0002', 2, 3, 3, 'shipped', 'high', 'USD', '2025-01-08 15:11:00', '2025-01-15', NULL, NULL, 'mobile', 'Gift wrap requested'),
('ORD-2025-0003', 3, 4, 2, 'processing', 'urgent', 'USD', '2025-01-09 11:35:00', '2025-01-12', NULL, NULL, 'inside_sales', 'Customer requested partial delivery'),
('ORD-2025-0004', 4, 5, 5, 'cancelled', 'normal', 'EUR', '2025-01-10 08:40:00', '2025-01-20', NULL, 'Payment authorization timeout', 'marketplace', NULL),
('ORD-2025-0005', 5, 6, NULL, 'confirmed', 'low', 'USD', '2025-01-11 20:04:00', NULL, NULL, NULL, 'web', NULL),
('ORD-2025-0006', 6, 7, 4, 'delivered', 'normal', 'USD', '2025-01-12 13:49:00', '2025-01-18', '2025-01-16 09:00:00', NULL, 'mobile', NULL),
('ORD-2025-0007', 7, 8, 2, 'returned', 'high', 'USD', '2025-01-13 10:10:00', '2025-01-19', '2025-01-15 18:45:00', NULL, 'web', 'Return initiated after delivery'),
('ORD-2025-0008', 8, 9, 3, 'draft', 'low', 'USD', '2025-01-14 17:30:00', NULL, NULL, NULL, 'inside_sales', 'Pending customer confirmation'),
('ORD-2025-0009', 3, 4, 6, 'confirmed', 'normal', 'USD', '2025-01-15 12:05:00', '2025-01-23', NULL, NULL, 'marketplace', NULL),
('ORD-2025-0010', 1, 2, 2, 'processing', 'high', 'USD', '2025-01-16 09:42:00', '2025-01-19', NULL, NULL, 'web', 'Ship to office'),
('ORD-2025-0011', 4, 5, 5, 'delivered', 'normal', 'EUR', '2025-01-16 07:50:00', '2025-01-24', '2025-01-21 15:20:00', NULL, 'marketplace', NULL),
('ORD-2025-0012', 6, 7, 4, 'shipped', 'urgent', 'USD', '2025-01-17 18:14:00', '2025-01-20', NULL, NULL, 'mobile', 'Customer travelling; expedite if possible');

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct, tax_pct, backordered_qty) VALUES
(1, 1, 1, 189.99, 5.00, 8.25, 0),
(1, 8, 1, 109.00, NULL, 8.25, 0),
(2, 2, 1, 249.00, 0.00, 8.25, 0),
(2, 9, 2, 139.00, 6.00, 8.25, 1),
(3, 4, 1, 319.00, 3.00, 8.25, 0),
(3, 5, 3, 54.00, NULL, 8.25, 2),
(4, 3, 1, 179.00, 0.00, 19.00, 0),
(5, 10, 2, 94.00, 5.00, 8.25, 0),
(5, 7, 1, 129.00, NULL, 8.25, 0),
(6, 3, 1, 175.00, 2.00, 8.25, 0),
(6, 5, 1, 59.00, 0.00, 8.25, 0),
(7, 2, 1, 239.00, 4.00, 8.25, 0),
(7, 9, 1, 149.00, NULL, 8.25, 0),
(8, 1, 1, 199.99, NULL, 8.25, 0),
(9, 8, 2, 119.00, 10.00, 8.25, 0),
(9, 4, 1, 329.00, 0.00, 8.25, 0),
(10, 7, 2, 134.00, 8.00, 8.25, 1),
(10, 5, 2, 57.00, 0.00, 8.25, 0),
(11, 10, 1, 99.00, 0.00, 19.00, 0),
(11, 6, 1, 79.00, 0.00, 19.00, 0),
(12, 3, 1, 179.00, NULL, 8.25, 0),
(12, 2, 1, 249.00, 3.50, 8.25, 0);

INSERT INTO shipments (order_id, warehouse_id, carrier, service_level, tracking_number, shipping_cost, shipped_at, delivered_at, shipment_status) VALUES
(1, 2, 'ShipFast', 'standard', 'TRK-000001', 12.40, '2025-01-08 07:20:00', '2025-01-10 11:02:00', 'delivered'),
(2, 1, 'ShipFast', 'expedited', 'TRK-000002', 19.90, '2025-01-09 16:30:00', NULL, 'in_transit'),
(3, 1, 'RapidPost', 'overnight', NULL, 27.00, NULL, NULL, 'pending'),
(4, 3, 'EuroCarrier', 'standard', NULL, 0.00, NULL, NULL, 'pending'),
(6, 2, 'ShipFast', 'standard', 'TRK-000006', 10.20, '2025-01-14 06:50:00', '2025-01-16 08:41:00', 'delivered'),
(7, 2, 'RapidPost', 'expedited', 'TRK-000007', 17.50, '2025-01-14 11:11:00', '2025-01-15 17:05:00', 'delivered'),
(11, 3, 'EuroCarrier', 'standard', 'TRK-000011', 9.10, '2025-01-18 09:00:00', '2025-01-21 14:10:00', 'delivered'),
(12, 2, 'ShipFast', 'overnight', 'TRK-000012', 28.75, '2025-01-18 22:00:00', NULL, 'in_transit');

INSERT INTO payments (order_id, payment_method, amount, paid_at, payment_status, transaction_ref, failure_reason) VALUES
(1, 'card', 324.80, '2025-01-06 09:25:00', 'captured', 'TXN-1A2B3C', NULL),
(2, 'wallet', 536.22, '2025-01-08 15:12:00', 'captured', 'TXN-2D3E4F', NULL),
(3, 'invoice', 512.13, NULL, 'pending', NULL, NULL),
(4, 'card', 213.01, NULL, 'failed', NULL, '3DS verification timeout'),
(5, 'card', 348.61, '2025-01-11 20:05:00', 'authorized', 'TXN-5P6Q7R', NULL),
(6, 'wire', 253.78, '2025-01-12 14:00:00', 'captured', 'WIRE-889210', NULL),
(7, 'card', 410.90, '2025-01-13 10:11:00', 'refunded', 'TXN-7K8L9M', NULL),
(8, 'invoice', 216.49, NULL, 'pending', NULL, NULL),
(9, 'wallet', 593.05, '2025-01-15 12:08:00', 'captured', 'TXN-9N0P1Q', NULL),
(10, 'card', 422.37, '2025-01-16 09:43:00', 'captured', 'TXN-10R2S3', NULL),
(11, 'card', 212.31, '2025-01-16 07:52:00', 'captured', 'TXN-11T4U5', NULL),
(12, 'wallet', 460.84, '2025-01-17 18:16:00', 'captured', 'TXN-12V6W7', NULL);

INSERT INTO returns (order_item_id, approved_by_rep_id, requested_at, approved_at, received_at, reason_code, return_status, refund_amount, notes) VALUES
(12, 6, '2025-01-18 10:30:00', '2025-01-18 11:05:00', '2025-01-21 13:00:00', 'quality_issue', 'refunded', 229.44, 'Screen flickering after setup'),
(13, NULL, '2025-01-18 10:50:00', NULL, NULL, 'changed_mind', 'requested', NULL, 'Customer opened but did not use'),
(20, 5, '2025-01-22 09:12:00', '2025-01-22 14:00:00', NULL, 'late_delivery', 'approved', 79.00, 'Still waiting for reverse pickup');

INSERT INTO support_tickets (ticket_number, customer_id, order_id, assigned_rep_id, category, priority, ticket_status, opened_at, resolved_at, satisfaction_rating, summary) VALUES
('TCK-9001', 2, 2, 6, 'delivery', 'high', 'in_progress', '2025-01-11 09:00:00', NULL, NULL, 'Tracking has not updated for 48 hours'),
('TCK-9002', 3, 3, 2, 'billing', 'normal', 'waiting_customer', '2025-01-12 16:35:00', NULL, NULL, 'Invoice amount differs from checkout'),
('TCK-9003', 7, 7, 6, 'return', 'critical', 'resolved', '2025-01-18 10:31:00', '2025-01-23 10:10:00', 4, 'Defective watch requested replacement'),
('TCK-9004', 4, 4, 5, 'billing', 'high', 'closed', '2025-01-10 10:20:00', '2025-01-10 16:40:00', 5, 'Payment failure on cancelled marketplace order'),
('TCK-9005', 8, NULL, NULL, 'account', 'low', 'open', '2025-01-19 08:40:00', NULL, NULL, 'Unable to update phone number'),
('TCK-9006', 1, 10, 2, 'delivery', 'normal', 'open', '2025-01-18 12:18:00', NULL, NULL, 'Split shipment requested by customer');

INSERT INTO ticket_events (ticket_id, event_type, actor_type, actor_id, note, created_at) VALUES
(1, 'created', 'customer', 2, 'Where is my package?', '2025-01-11 09:00:00'),
(1, 'assignment', 'system', NULL, 'Assigned to REP-105', '2025-01-11 09:05:00'),
(1, 'internal_note', 'rep', 6, 'Carrier escalation raised', '2025-01-12 10:12:00'),
(2, 'created', 'customer', 3, 'Invoice amount mismatch noticed', '2025-01-12 16:35:00'),
(2, 'customer_reply', 'customer', 3, 'Attached screenshot of checkout page', '2025-01-12 17:02:00'),
(3, 'created', 'customer', 7, 'Watch screen issue, wants replacement', '2025-01-18 10:31:00'),
(3, 'status_change', 'rep', 6, 'Marked as resolved after refund + replacement', '2025-01-23 10:10:00'),
(4, 'created', 'customer', 4, 'Card payment declined on checkout', '2025-01-10 10:20:00'),
(4, 'resolution', 'rep', 5, 'Order cancelled, customer informed', '2025-01-10 16:40:00'),
(5, 'created', 'customer', 8, 'Cannot update profile contact details', '2025-01-19 08:40:00'),
(6, 'created', 'customer', 1, 'Need one item delivered to office', '2025-01-18 12:18:00');

INSERT INTO inventory_snapshots (warehouse_id, product_id, snapshot_date, on_hand_qty, reserved_qty, in_transit_qty, damaged_qty) VALUES
(1, 1, '2025-01-20', 340, 45, 20, 3),
(1, 2, '2025-01-20', 290, 58, 40, 2),
(1, 3, '2025-01-20', 410, 39, 0, 1),
(1, 9, '2025-01-20', 125, 62, 80, 4),
(2, 1, '2025-01-20', 510, 70, 10, 5),
(2, 4, '2025-01-20', 140, 29, 15, 1),
(2, 5, '2025-01-20', 620, 41, 0, 9),
(2, 7, '2025-01-20', 275, 64, 25, 0),
(3, 10, '2025-01-20', 180, 9, 0, 1),
(3, 6, '2025-01-20', 12, 0, 0, 0),
(3, 3, '2025-01-20', 88, 12, 30, 0),
(4, 2, '2025-01-20', 0, 0, 0, 0);

INSERT INTO purchase_orders (po_number, supplier_id, destination_warehouse_id, created_by_rep_id, po_status, created_at, expected_arrival, received_at, total_amount) VALUES
('PO-2025-3001', 1, 1, 2, 'received', '2025-01-05 10:00:00', '2025-01-12', '2025-01-12 14:00:00', 42800.00),
('PO-2025-3002', 2, 2, 3, 'partially_received', '2025-01-09 09:20:00', '2025-01-17', NULL, 31750.00),
('PO-2025-3003', 4, 3, 5, 'submitted', '2025-01-15 11:05:00', '2025-01-27', NULL, 15840.00),
('PO-2025-3004', 3, 1, 2, 'cancelled', '2025-01-16 13:40:00', '2025-01-25', NULL, 22600.00);

INSERT INTO purchase_order_items (purchase_order_id, product_id, quantity_ordered, quantity_received, unit_cost) VALUES
(1, 1, 150, 150, 103.00),
(1, 3, 120, 120, 88.50),
(1, 7, 140, 140, 70.00),
(2, 4, 80, 50, 196.00),
(2, 9, 200, 120, 79.50),
(3, 10, 180, NULL, 48.00),
(3, 5, 260, NULL, 27.00),
(4, 2, 160, 0, 132.00),
(4, 8, 220, 0, 56.00);

-- -----------------------------------------------------------------------------
-- Optional verification queries
-- -----------------------------------------------------------------------------
-- 1) Revenue vs refunds by customer
-- SELECT c.customer_code, c.full_name,
--        SUM(CASE WHEN p.payment_status IN ('captured','authorized') THEN p.amount ELSE 0 END) AS paid_amount,
--        SUM(COALESCE(r.refund_amount, 0)) AS refunded_amount
-- FROM customers c
-- LEFT JOIN orders o ON o.customer_id = c.id
-- LEFT JOIN payments p ON p.order_id = o.id
-- LEFT JOIN order_items oi ON oi.order_id = o.id
-- LEFT JOIN returns r ON r.order_item_id = oi.id
-- GROUP BY c.customer_code, c.full_name
-- ORDER BY paid_amount DESC;

-- 2) Open ticket backlog with shipment status context
-- SELECT t.ticket_number, t.priority, t.ticket_status, o.order_number, s.shipment_status, s.tracking_number
-- FROM support_tickets t
-- LEFT JOIN orders o ON t.order_id = o.id
-- LEFT JOIN shipments s ON s.order_id = o.id
-- WHERE t.ticket_status NOT IN ('resolved', 'closed')
-- ORDER BY t.priority DESC, t.opened_at;
