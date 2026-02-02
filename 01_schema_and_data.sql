-- ═══════════════════════════════════════════════════════════
-- E-COMMERCE ANALYTICS DATABASE SCHEMA
-- Complete SQL-Only Analytics Project
-- ═══════════════════════════════════════════════════════════

-- Database: ecommerce_analytics
-- Purpose: Advanced SQL analytics for online retail business
-- Features: Sales analysis, customer segmentation, product performance, 
--           inventory management, marketing attribution

-- ═══════════════════════════════════════════════════════════
-- DROP EXISTING TABLES (IF ANY)
-- ═══════════════════════════════════════════════════════════

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS marketing_campaigns CASCADE;
DROP TABLE IF EXISTS customer_campaigns CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS shipping CASCADE;

-- ═══════════════════════════════════════════════════════════
-- CREATE TABLES
-- ═══════════════════════════════════════════════════════════

-- Categories Table
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INTEGER REFERENCES categories(category_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products Table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2) NOT NULL,
    supplier VARCHAR(100),
    weight_kg DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Inventory Table
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id),
    warehouse_location VARCHAR(100),
    quantity_available INTEGER NOT NULL,
    reorder_level INTEGER DEFAULT 50,
    last_restock_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers Table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    country VARCHAR(50),
    state VARCHAR(50),
    city VARCHAR(100),
    signup_date DATE NOT NULL,
    customer_segment VARCHAR(50), -- VIP, Regular, New
    is_active BOOLEAN DEFAULT TRUE
);

-- Marketing Campaigns Table
CREATE TABLE marketing_campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(200) NOT NULL,
    campaign_type VARCHAR(50), -- Email, Social, PPC, Referral
    start_date DATE NOT NULL,
    end_date DATE,
    budget DECIMAL(10, 2),
    channel VARCHAR(50) -- Facebook, Google, Instagram, Email
);

-- Customer Campaigns (Attribution)
CREATE TABLE customer_campaigns (
    attribution_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    campaign_id INTEGER REFERENCES marketing_campaigns(campaign_id),
    interaction_date TIMESTAMP NOT NULL,
    conversion_date TIMESTAMP
);

-- Orders Table
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date TIMESTAMP NOT NULL,
    order_status VARCHAR(50), -- Pending, Shipped, Delivered, Cancelled
    payment_method VARCHAR(50), -- Credit Card, PayPal, Bank Transfer
    campaign_id INTEGER REFERENCES marketing_campaigns(campaign_id),
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL
);

-- Order Items Table
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount DECIMAL(10, 2) DEFAULT 0,
    subtotal DECIMAL(10, 2) NOT NULL
);

-- Shipping Table
CREATE TABLE shipping (
    shipping_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    shipping_date DATE,
    delivery_date DATE,
    estimated_delivery DATE,
    carrier VARCHAR(50), -- FedEx, UPS, USPS, DHL
    tracking_number VARCHAR(100),
    shipping_address TEXT
);

-- Reviews Table
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    order_id INTEGER REFERENCES orders(order_id),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_verified_purchase BOOLEAN DEFAULT TRUE
);

-- ═══════════════════════════════════════════════════════════
-- CREATE INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_customers_segment ON customers(customer_segment);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_inventory_product ON inventory(product_id);

-- ═══════════════════════════════════════════════════════════
-- INSERT SAMPLE DATA
-- ═══════════════════════════════════════════════════════════

-- Categories
INSERT INTO categories (category_name, parent_category_id) VALUES
('Electronics', NULL),
('Computers', 1),
('Phones & Tablets', 1),
('Audio', 1),
('Clothing', NULL),
('Men''s Clothing', 5),
('Women''s Clothing', 5),
('Home & Garden', NULL),
('Furniture', 8),
('Kitchen', 8),
('Sports & Outdoors', NULL),
('Fitness', 11),
('Camping', 11),
('Books', NULL),
('Toys & Games', NULL);

-- Products (50 products)
INSERT INTO products (product_name, category_id, price, cost, supplier, weight_kg) VALUES
-- Electronics
('Laptop Pro 15"', 2, 1299.99, 800.00, 'TechCorp', 2.5),
('Gaming Laptop', 2, 1899.99, 1200.00, 'TechCorp', 3.2),
('Wireless Mouse', 2, 29.99, 12.00, 'AccessoriesCo', 0.2),
('Mechanical Keyboard', 2, 89.99, 45.00, 'AccessoriesCo', 1.1),
('27" Monitor', 2, 349.99, 200.00, 'DisplayTech', 6.5),
('Smartphone X', 3, 899.99, 550.00, 'MobileTech', 0.18),
('Tablet Pro', 3, 499.99, 300.00, 'MobileTech', 0.45),
('Phone Case Premium', 3, 24.99, 8.00, 'AccessoriesCo', 0.05),
('Wireless Earbuds', 4, 149.99, 70.00, 'AudioMaster', 0.08),
('Noise-Cancelling Headphones', 4, 279.99, 140.00, 'AudioMaster', 0.35),
-- Clothing
('Men''s Cotton T-Shirt', 6, 19.99, 8.00, 'FashionHub', 0.2),
('Men''s Jeans', 6, 59.99, 25.00, 'FashionHub', 0.7),
('Men''s Jacket', 6, 89.99, 40.00, 'FashionHub', 1.2),
('Women''s Dress', 7, 79.99, 35.00, 'StyleWorld', 0.4),
('Women''s Blouse', 7, 39.99, 18.00, 'StyleWorld', 0.25),
('Women''s Sneakers', 7, 69.99, 30.00, 'FootwearPlus', 0.6),
-- Home & Garden
('Dining Table Set', 9, 599.99, 300.00, 'FurniturePro', 45.0),
('Office Chair', 9, 199.99, 100.00, 'FurniturePro', 15.0),
('Coffee Maker', 10, 79.99, 40.00, 'KitchenKing', 3.5),
('Blender', 10, 49.99, 25.00, 'KitchenKing', 2.8),
('Cookware Set', 10, 129.99, 60.00, 'KitchenKing', 8.5),
-- Sports & Outdoors
('Yoga Mat', 12, 29.99, 12.00, 'FitLife', 1.5),
('Dumbbell Set', 12, 149.99, 75.00, 'FitLife', 20.0),
('Exercise Bike', 12, 399.99, 200.00, 'FitLife', 35.0),
('Camping Tent', 13, 199.99, 100.00, 'OutdoorGear', 5.5),
('Sleeping Bag', 13, 79.99, 40.00, 'OutdoorGear', 2.2),
('Hiking Backpack', 13, 89.99, 45.00, 'OutdoorGear', 1.8),
-- Books
('Business Strategy Book', 14, 24.99, 10.00, 'BookWorld', 0.5),
('Fiction Novel', 14, 14.99, 6.00, 'BookWorld', 0.4),
('Cookbook', 14, 29.99, 12.00, 'BookWorld', 0.8),
-- Toys
('Board Game', 15, 39.99, 18.00, 'ToysRUs', 1.2),
('Action Figure', 15, 19.99, 8.00, 'ToysRUs', 0.3),
('LEGO Set', 15, 89.99, 40.00, 'ToysRUs', 2.5),
-- More Electronics
('Smart Watch', 1, 299.99, 150.00, 'TechCorp', 0.15),
('USB-C Cable', 2, 12.99, 5.00, 'AccessoriesCo', 0.05),
('Portable SSD 1TB', 2, 129.99, 65.00, 'TechCorp', 0.1),
('Webcam HD', 2, 69.99, 35.00, 'TechCorp', 0.25),
('Gaming Console', 1, 499.99, 300.00, 'GamingCorp', 4.5),
('VR Headset', 1, 399.99, 200.00, 'TechCorp', 0.6),
('Bluetooth Speaker', 4, 79.99, 40.00, 'AudioMaster', 0.7),
-- More Clothing
('Men''s Shorts', 6, 34.99, 15.00, 'FashionHub', 0.3),
('Women''s Leggings', 7, 29.99, 12.00, 'StyleWorld', 0.2),
('Winter Coat', 7, 149.99, 70.00, 'StyleWorld', 2.0),
('Sports Bra', 7, 39.99, 18.00, 'FitLife', 0.15),
-- Home items
('Vacuum Cleaner', 8, 199.99, 100.00, 'HomeTech', 6.5),
('Air Purifier', 8, 149.99, 75.00, 'HomeTech', 4.0),
('Desk Lamp', 8, 34.99, 18.00, 'HomeTech', 1.2),
('Storage Bins Set', 8, 44.99, 20.00, 'FurniturePro', 3.5),
('Bedding Set', 8, 79.99, 40.00, 'HomeTech', 2.8),
('Wall Art', 8, 49.99, 25.00, 'DecorPlus', 1.5);

-- Inventory
INSERT INTO inventory (product_id, warehouse_location, quantity_available, reorder_level, last_restock_date)
SELECT 
    product_id,
    CASE (product_id % 3)
        WHEN 0 THEN 'East Warehouse'
        WHEN 1 THEN 'West Warehouse'
        ELSE 'Central Warehouse'
    END,
    FLOOR(RANDOM() * 500 + 50)::INTEGER,
    50,
    CURRENT_DATE - (RANDOM() * 90)::INTEGER
FROM products;

-- Customers (200 customers)
INSERT INTO customers (first_name, last_name, email, phone, country, state, city, signup_date, customer_segment)
SELECT
    CASE (id % 20)
        WHEN 0 THEN 'John' WHEN 1 THEN 'Jane' WHEN 2 THEN 'Michael' 
        WHEN 3 THEN 'Sarah' WHEN 4 THEN 'David' WHEN 5 THEN 'Emily'
        WHEN 6 THEN 'Chris' WHEN 7 THEN 'Jessica' WHEN 8 THEN 'Daniel'
        WHEN 9 THEN 'Ashley' WHEN 10 THEN 'Matthew' WHEN 11 THEN 'Amanda'
        WHEN 12 THEN 'James' WHEN 13 THEN 'Melissa' WHEN 14 THEN 'Robert'
        WHEN 15 THEN 'Linda' WHEN 16 THEN 'William' WHEN 17 THEN 'Jennifer'
        WHEN 18 THEN 'Richard' ELSE 'Lisa'
    END,
    CASE (id % 15)
        WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams'
        WHEN 3 THEN 'Brown' WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia'
        WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis' WHEN 8 THEN 'Rodriguez'
        WHEN 9 THEN 'Martinez' WHEN 10 THEN 'Hernandez' WHEN 11 THEN 'Lopez'
        WHEN 12 THEN 'Gonzalez' WHEN 13 THEN 'Wilson' ELSE 'Anderson'
    END,
    'customer' || id || '@email.com',
    '+1-555-' || LPAD(id::TEXT, 4, '0'),
    'USA',
    CASE (id % 5)
        WHEN 0 THEN 'California' WHEN 1 THEN 'Texas' 
        WHEN 2 THEN 'New York' WHEN 3 THEN 'Florida'
        ELSE 'Illinois'
    END,
    CASE (id % 5)
        WHEN 0 THEN 'Los Angeles' WHEN 1 THEN 'Houston'
        WHEN 2 THEN 'New York City' WHEN 3 THEN 'Miami'
        ELSE 'Chicago'
    END,
    CURRENT_DATE - (RANDOM() * 730 + 30)::INTEGER,
    CASE 
        WHEN RANDOM() < 0.1 THEN 'VIP'
        WHEN RANDOM() < 0.3 THEN 'New'
        ELSE 'Regular'
    END
FROM generate_series(1, 200) AS id;

-- Marketing Campaigns
INSERT INTO marketing_campaigns (campaign_name, campaign_type, start_date, end_date, budget, channel) VALUES
('Summer Sale 2024', 'Email', '2024-06-01', '2024-08-31', 50000.00, 'Email'),
('Back to School', 'Social', '2024-08-01', '2024-09-30', 75000.00, 'Facebook'),
('Black Friday', 'PPC', '2024-11-15', '2024-11-30', 100000.00, 'Google'),
('Holiday Special', 'Email', '2024-12-01', '2024-12-31', 80000.00, 'Email'),
('New Year Deals', 'Social', '2025-01-01', '2025-01-15', 60000.00, 'Instagram'),
('Spring Collection', 'PPC', '2024-03-01', '2024-05-31', 45000.00, 'Google'),
('Referral Program', 'Referral', '2024-01-01', '2024-12-31', 30000.00, 'Email'),
('Flash Sale Week', 'Social', '2024-10-01', '2024-10-07', 40000.00, 'Facebook'),
('Cyber Monday', 'PPC', '2024-11-25', '2024-11-26', 90000.00, 'Google'),
('Loyalty Rewards', 'Email', '2024-01-01', '2024-12-31', 25000.00, 'Email');

-- Customer Campaign Attribution (300 interactions)
INSERT INTO customer_campaigns (customer_id, campaign_id, interaction_date, conversion_date)
SELECT 
    FLOOR(RANDOM() * 200 + 1)::INTEGER,
    FLOOR(RANDOM() * 10 + 1)::INTEGER,
    TIMESTAMP '2024-01-01' + (RANDOM() * 365)::INTEGER * INTERVAL '1 day',
    CASE WHEN RANDOM() < 0.6 
        THEN TIMESTAMP '2024-01-01' + (RANDOM() * 365)::INTEGER * INTERVAL '1 day'
        ELSE NULL
    END
FROM generate_series(1, 300);

-- ═══════════════════════════════════════════════════════════
-- GENERATE ORDERS AND ORDER ITEMS
-- ═══════════════════════════════════════════════════════════

-- Generate 1000 orders
DO $$
DECLARE
    v_order_id INTEGER;
    v_customer_id INTEGER;
    v_order_date TIMESTAMP;
    v_num_items INTEGER;
    v_product_id INTEGER;
    v_quantity INTEGER;
    v_unit_price DECIMAL(10, 2);
    v_discount DECIMAL(10, 2);
    v_subtotal DECIMAL(10, 2);
    v_order_total DECIMAL(10, 2);
    v_campaign_id INTEGER;
BEGIN
    FOR i IN 1..1000 LOOP
        -- Random customer
        v_customer_id := FLOOR(RANDOM() * 200 + 1)::INTEGER;
        
        -- Random order date in last year
        v_order_date := TIMESTAMP '2024-01-01' + (RANDOM() * 365)::INTEGER * INTERVAL '1 day';
        
        -- Random campaign (70% chance)
        IF RANDOM() < 0.7 THEN
            v_campaign_id := FLOOR(RANDOM() * 10 + 1)::INTEGER;
        ELSE
            v_campaign_id := NULL;
        END IF;
        
        -- Insert order (we'll update total later)
        INSERT INTO orders (
            customer_id, order_date, order_status, payment_method, 
            campaign_id, discount_amount, shipping_cost, tax_amount, total_amount
        ) VALUES (
            v_customer_id,
            v_order_date,
            CASE FLOOR(RANDOM() * 10)
                WHEN 0 THEN 'Cancelled'
                WHEN 1 THEN 'Pending'
                ELSE 'Delivered'
            END,
            CASE FLOOR(RANDOM() * 3)
                WHEN 0 THEN 'Credit Card'
                WHEN 1 THEN 'PayPal'
                ELSE 'Bank Transfer'
            END,
            v_campaign_id,
            CASE WHEN RANDOM() < 0.3 THEN ROUND((RANDOM() * 50)::NUMERIC, 2) ELSE 0 END,
            ROUND((RANDOM() * 20 + 5)::NUMERIC, 2),
            0, -- Will calculate
            0  -- Will calculate
        ) RETURNING order_id INTO v_order_id;
        
        -- Random number of items (1-5)
        v_num_items := FLOOR(RANDOM() * 5 + 1)::INTEGER;
        v_order_total := 0;
        
        -- Add order items
        FOR j IN 1..v_num_items LOOP
            v_product_id := FLOOR(RANDOM() * 50 + 1)::INTEGER;
            v_quantity := FLOOR(RANDOM() * 3 + 1)::INTEGER;
            
            SELECT price INTO v_unit_price FROM products WHERE product_id = v_product_id;
            
            v_discount := CASE WHEN RANDOM() < 0.2 
                THEN ROUND((RANDOM() * 0.2 * v_unit_price)::NUMERIC, 2) 
                ELSE 0 
            END;
            
            v_subtotal := ROUND((v_unit_price * v_quantity - v_discount)::NUMERIC, 2);
            v_order_total := v_order_total + v_subtotal;
            
            INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount, subtotal)
            VALUES (v_order_id, v_product_id, v_quantity, v_unit_price, v_discount, v_subtotal);
        END LOOP;
        
        -- Update order total
        UPDATE orders 
        SET 
            tax_amount = ROUND((v_order_total * 0.08)::NUMERIC, 2),
            total_amount = ROUND((v_order_total * 1.08 + shipping_cost)::NUMERIC, 2)
        WHERE order_id = v_order_id;
        
        -- Insert shipping info (if delivered or shipped)
        IF (SELECT order_status FROM orders WHERE order_id = v_order_id) IN ('Delivered', 'Shipped') THEN
            INSERT INTO shipping (
                order_id, shipping_date, delivery_date, estimated_delivery, 
                carrier, tracking_number, shipping_address
            ) VALUES (
                v_order_id,
                v_order_date + INTERVAL '1 day',
                v_order_date + (RANDOM() * 7 + 2)::INTEGER * INTERVAL '1 day',
                v_order_date + INTERVAL '5 days',
                CASE FLOOR(RANDOM() * 4)
                    WHEN 0 THEN 'FedEx' WHEN 1 THEN 'UPS'
                    WHEN 2 THEN 'USPS' ELSE 'DHL'
                END,
                'TRK' || LPAD(v_order_id::TEXT, 10, '0'),
                '123 Main St, City, State, ZIP'
            );
        END IF;
    END LOOP;
END $$;

-- Reviews (500 reviews)
INSERT INTO reviews (product_id, customer_id, order_id, rating, review_text, review_date)
SELECT 
    oi.product_id,
    o.customer_id,
    o.order_id,
    FLOOR(RANDOM() * 3 + 3)::INTEGER, -- 3-5 stars (mostly positive)
    CASE FLOOR(RANDOM() * 5)
        WHEN 0 THEN 'Great product! Highly recommend.'
        WHEN 1 THEN 'Good quality for the price.'
        WHEN 2 THEN 'Exactly as described. Fast shipping.'
        WHEN 3 THEN 'Love it! Will buy again.'
        ELSE 'Perfect! Exceeded expectations.'
    END,
    o.order_date + (RANDOM() * 30)::INTEGER * INTERVAL '1 day'
FROM (
    SELECT DISTINCT ON (oi.order_id, oi.product_id)
        oi.order_id,
        oi.product_id
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Delivered'
    AND RANDOM() < 0.6 -- 60% of delivered items get reviewed
    ORDER BY oi.order_id, oi.product_id, RANDOM()
    LIMIT 500
) oi
JOIN orders o ON oi.order_id = o.order_id;

-- ═══════════════════════════════════════════════════════════
-- VERIFY DATA
-- ═══════════════════════════════════════════════════════════

SELECT 'Data Load Summary' AS summary;
SELECT 'Categories: ' || COUNT(*) AS count FROM categories;
SELECT 'Products: ' || COUNT(*) AS count FROM products;
SELECT 'Customers: ' || COUNT(*) AS count FROM customers;
SELECT 'Orders: ' || COUNT(*) AS count FROM orders;
SELECT 'Order Items: ' || COUNT(*) AS count FROM order_items;
SELECT 'Reviews: ' || COUNT(*) AS count FROM reviews;
SELECT 'Marketing Campaigns: ' || COUNT(*) AS count FROM marketing_campaigns;

-- ═══════════════════════════════════════════════════════════
-- END OF SCHEMA CREATION
-- ═══════════════════════════════════════════════════════════
