-- Amazon-like Marketplace Synthetic Database

-- USERS
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT UNIQUE,
    role TEXT CHECK (role IN ('customer', 'seller', 'admin')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PRODUCTS
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    seller_id INT REFERENCES users(user_id),
    name TEXT,
    category TEXT,
    price NUMERIC(10,2),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ORDERS
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(user_id),
    total_amount NUMERIC(10,2),
    status TEXT CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ORDER ITEMS
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    product_id INT REFERENCES products(product_id),
    quantity INT,
    price NUMERIC(10,2)
);

-- REVIEWS
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    user_id INT REFERENCES users(user_id),
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PAYMENTS
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    payment_method TEXT,
    payment_status TEXT,
    transaction_metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed data: exactly 1000 total rows per main table (including starter rows)
INSERT INTO users (name, email, role) VALUES
('User1','user1@mail.com','customer'),
('Seller1','seller1@mail.com','seller'),
('Admin1','admin1@mail.com','admin');

INSERT INTO products (seller_id, name, category, price, metadata) VALUES
(2,'iPhone 15','electronics',799.99,'{"brand":"Apple"}');

INSERT INTO orders (customer_id, total_amount, status) VALUES
(1,799.99,'delivered');

INSERT INTO order_items (order_id, product_id, quantity, price) VALUES
(1,1,1,799.99);

INSERT INTO reviews (product_id, user_id, rating, comment) VALUES
(1,1,5,'Great product');

INSERT INTO payments (order_id, payment_method, payment_status, transaction_metadata) VALUES
(1,'card','success','{"txn_id":"tx1"}');

-- ---------------------------------------------------------------------------
-- BULK USERS (adds 997 users; with 3 starter users => 1000 total)
-- 700 additional customers
INSERT INTO users (name, email, role, created_at)
SELECT
    'Customer ' || g,
    'customer' || g || '@example.com',
    'customer',
    NOW() - ((g % 365) || ' days')::interval - ((g % 24) || ' hours')::interval
FROM generate_series(2, 701) AS g;

-- 250 additional sellers
INSERT INTO users (name, email, role, created_at)
SELECT
    'Seller ' || g,
    'seller' || g || '@marketplace.com',
    'seller',
    NOW() - ((g % 365) || ' days')::interval - ((g % 24) || ' hours')::interval
FROM generate_series(2, 251) AS g;

-- 47 additional admins
INSERT INTO users (name, email, role, created_at)
SELECT
    'Admin ' || g,
    'admin' || g || '@marketplace.com',
    'admin',
    NOW() - ((g % 365) || ' days')::interval
FROM generate_series(2, 48) AS g;

-- ---------------------------------------------------------------------------
-- BULK PRODUCTS (adds 999; with 1 starter product => 1000 total)
INSERT INTO products (seller_id, name, category, price, metadata, created_at)
SELECT
    seller_ids.ids[((g - 1) % array_length(seller_ids.ids, 1)) + 1],
    (ARRAY[
        'Wireless Earbuds', 'Gaming Mouse', 'Yoga Mat', 'Smartwatch',
        'Office Chair', 'Coffee Maker', 'Bluetooth Speaker', 'Laptop Stand',
        'Air Purifier', 'Running Shoes', 'Mechanical Keyboard', 'Webcam',
        'Portable SSD', 'Water Bottle', 'Phone Case', 'Robot Vacuum',
        'Monitor Arm', 'Standing Desk', 'LED Light Strip', 'Backpack'
    ])[((g - 1) % 20) + 1] || ' ' || g,
    (ARRAY[
        'electronics', 'home', 'sports', 'fashion', 'beauty',
        'books', 'toys', 'kitchen', 'office', 'automotive'
    ])[((g - 1) % 10) + 1],
    ROUND((9.99 + random() * 1990.00)::numeric, 2),
    jsonb_build_object(
        'brand', (ARRAY[
            'Apple', 'Samsung', 'Sony', 'Logitech', 'Nike',
            'Philips', 'Anker', 'Acer', 'Dell', 'AmazonBasics'
        ])[((g - 1) % 10) + 1],
        'rating', ROUND((3.2 + random() * 1.8)::numeric, 1),
        'stock', (20 + floor(random() * 980))::int,
        'shipping_days', (1 + floor(random() * 6))::int
    ),
    NOW() - ((g % 540) || ' days')::interval
FROM generate_series(2, 1000) AS g
CROSS JOIN (
    SELECT array_agg(user_id ORDER BY user_id) AS ids
    FROM users
    WHERE role = 'seller'
) AS seller_ids;

-- ---------------------------------------------------------------------------
-- BULK ORDERS (adds 999; with 1 starter order => 1000 total)
INSERT INTO orders (customer_id, total_amount, status, created_at)
SELECT
    customer_ids.ids[((g - 1) % array_length(customer_ids.ids, 1)) + 1],
    ROUND((18.00 + random() * 1800.00)::numeric, 2),
    CASE
        WHEN random() < 0.10 THEN 'pending'
        WHEN random() < 0.20 THEN 'cancelled'
        WHEN random() < 0.55 THEN 'shipped'
        ELSE 'delivered'
    END,
    NOW() - ((g % 450) || ' days')::interval - ((g % 24) || ' hours')::interval
FROM generate_series(2, 1000) AS g
CROSS JOIN (
    SELECT array_agg(user_id ORDER BY user_id) AS ids
    FROM users
    WHERE role = 'customer'
) AS customer_ids;

-- ---------------------------------------------------------------------------
-- BULK ORDER ITEMS (adds 999; with 1 starter item => 1000 total)
INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT
    order_ids.ids[((g - 1) % array_length(order_ids.ids, 1)) + 1],
    product_ids.ids[((g - 1) % array_length(product_ids.ids, 1)) + 1],
    (1 + floor(random() * 4))::int,
    ROUND((6.00 + random() * 1200.00)::numeric, 2)
FROM generate_series(2, 1000) AS g
CROSS JOIN (
    SELECT array_agg(order_id ORDER BY order_id) AS ids
    FROM orders
) AS order_ids
CROSS JOIN (
    SELECT array_agg(product_id ORDER BY product_id) AS ids
    FROM products
) AS product_ids;

-- ---------------------------------------------------------------------------
-- BULK REVIEWS (adds 999; with 1 starter review => 1000 total)
INSERT INTO reviews (product_id, user_id, rating, comment, created_at)
SELECT
    product_ids.ids[((g - 1) % array_length(product_ids.ids, 1)) + 1],
    customer_ids.ids[((g * 3 - 1) % array_length(customer_ids.ids, 1)) + 1],
    (1 + floor(random() * 5))::int,
    (ARRAY[
        'Great value for money',
        'Works as expected',
        'Packaging was excellent',
        'Could be better but acceptable',
        'Fast delivery and quality product',
        'Not what I expected',
        'Highly recommended',
        'Build quality is solid',
        'Customer support was helpful',
        'Would buy again'
    ])[((g - 1) % 10) + 1],
    NOW() - ((g % 300) || ' days')::interval
FROM generate_series(2, 1000) AS g
CROSS JOIN (
    SELECT array_agg(product_id ORDER BY product_id) AS ids
    FROM products
) AS product_ids
CROSS JOIN (
    SELECT array_agg(user_id ORDER BY user_id) AS ids
    FROM users
    WHERE role = 'customer'
) AS customer_ids;

-- ---------------------------------------------------------------------------
-- BULK PAYMENTS (adds 999; with 1 starter payment => 1000 total)
INSERT INTO payments (order_id, payment_method, payment_status, transaction_metadata, created_at)
SELECT
    o.order_id,
    (ARRAY['card', 'upi', 'wallet', 'net_banking', 'cod'])[((o.order_id - 1) % 5) + 1],
    CASE
        WHEN o.status = 'cancelled' THEN 'refunded'
        WHEN o.status = 'pending' THEN 'pending'
        WHEN random() < 0.95 THEN 'success'
        ELSE 'failed'
    END,
    jsonb_build_object(
        'txn_id', 'txn_' || o.order_id,
        'gateway', (ARRAY['stripe', 'razorpay', 'paypal'])[((o.order_id - 1) % 3) + 1],
        'currency', 'USD',
        'fraud_score', ROUND((random() * 0.25)::numeric, 3)
    ),
    o.created_at + ((1 + (o.order_id % 6)) || ' minutes')::interval
FROM orders o
WHERE o.order_id > 1;
