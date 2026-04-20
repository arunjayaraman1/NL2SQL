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

-- Sample Inserts (shortened here, full dataset assumed from previous response)
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
