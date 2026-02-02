-- ═══════════════════════════════════════════════════════════
-- E-COMMERCE ANALYTICS VIEWS & FUNCTIONS
-- Reusable Database Objects for Quick Analytics
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════
-- VIEWS FOR COMMON METRICS
-- ═══════════════════════════════════════════════════════════

-- View 1: Sales Summary View
CREATE OR REPLACE VIEW vw_sales_summary AS
SELECT 
    o.order_id,
    o.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    o.order_date,
    DATE_TRUNC('month', o.order_date) AS order_month,
    o.order_status,
    o.payment_method,
    o.total_amount,
    o.discount_amount,
    o.shipping_cost,
    o.tax_amount,
    COUNT(oi.order_item_id) AS items_count,
    SUM(oi.quantity) AS total_units,
    mc.campaign_name,
    mc.campaign_type
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN marketing_campaigns mc ON o.campaign_id = mc.campaign_id
GROUP BY o.order_id, o.customer_id, c.first_name, c.last_name, c.email,
         o.order_date, o.order_status, o.payment_method, o.total_amount,
         o.discount_amount, o.shipping_cost, o.tax_amount,
         mc.campaign_name, mc.campaign_type;

COMMENT ON VIEW vw_sales_summary IS 'Comprehensive sales summary with customer and campaign information';

-- View 2: Product Performance View
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.price AS current_price,
    p.cost,
    p.price - p.cost AS profit_per_unit,
    ROUND((p.price - p.cost) * 100.0 / NULLIF(p.price, 0), 2) AS profit_margin_pct,
    COUNT(DISTINCT oi.order_id) AS orders,
    COALESCE(SUM(oi.quantity), 0) AS units_sold,
    COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
    COALESCE(ROUND(AVG(r.rating), 2), 0) AS avg_rating,
    COUNT(r.review_id) AS review_count,
    i.quantity_available AS stock_level,
    p.is_active
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'Cancelled'
LEFT JOIN reviews r ON p.product_id = r.product_id
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, c.category_name, p.price, p.cost, 
         i.quantity_available, p.is_active;

COMMENT ON VIEW vw_product_performance IS 'Product metrics including sales, reviews, and inventory';

-- View 3: Customer Metrics View
CREATE OR REPLACE VIEW vw_customer_metrics AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.customer_segment,
    c.signup_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent,
    ROUND(COALESCE(AVG(o.total_amount), 0), 2) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) AS days_since_last_order,
    CASE 
        WHEN MAX(o.order_date) >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
        WHEN MAX(o.order_date) >= CURRENT_DATE - INTERVAL '90 days' THEN 'At Risk'
        WHEN MAX(o.order_date) IS NOT NULL THEN 'Churned'
        ELSE 'Never Purchased'
    END AS customer_status
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id 
    AND o.order_status != 'Cancelled'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, 
         c.customer_segment, c.signup_date;

COMMENT ON VIEW vw_customer_metrics IS 'Customer-level metrics for segmentation and analysis';

-- View 4: Marketing Performance View
CREATE OR REPLACE VIEW vw_marketing_performance AS
SELECT 
    mc.campaign_id,
    mc.campaign_name,
    mc.campaign_type,
    mc.channel,
    mc.start_date,
    mc.end_date,
    mc.budget,
    COUNT(DISTINCT o.order_id) AS orders,
    COALESCE(SUM(o.total_amount), 0) AS revenue,
    ROUND(COALESCE(AVG(o.total_amount), 0), 2) AS avg_order_value,
    ROUND(
        (COALESCE(SUM(o.total_amount), 0) - mc.budget) * 100.0 / 
        NULLIF(mc.budget, 0), 
        2
    ) AS roi_pct,
    ROUND(
        COALESCE(SUM(o.total_amount), 0) / NULLIF(mc.budget, 0), 
        2
    ) AS roas
FROM marketing_campaigns mc
LEFT JOIN orders o ON mc.campaign_id = o.campaign_id 
    AND o.order_status != 'Cancelled'
GROUP BY mc.campaign_id, mc.campaign_name, mc.campaign_type, 
         mc.channel, mc.start_date, mc.end_date, mc.budget;

COMMENT ON VIEW vw_marketing_performance IS 'Campaign performance with ROI and ROAS metrics';

-- View 5: Daily Sales Dashboard
CREATE OR REPLACE VIEW vw_daily_sales_dashboard AS
SELECT 
    DATE(order_date) AS sale_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(total_amount) AS revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    SUM(discount_amount) AS total_discounts,
    SUM(shipping_cost) AS total_shipping,
    COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders
FROM orders
WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE(order_date)
ORDER BY sale_date DESC;

COMMENT ON VIEW vw_daily_sales_dashboard IS 'Daily sales metrics for the last 90 days';

-- ═══════════════════════════════════════════════════════════
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════

-- Materialized View 1: Monthly Revenue Report (Updated weekly)
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_amount) AS revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(discount_amount) AS total_discounts,
    SUM(tax_amount) AS total_tax,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders
FROM orders
WHERE order_status != 'Cancelled'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month DESC;

CREATE UNIQUE INDEX idx_mv_monthly_revenue_month ON mv_monthly_revenue(month);

-- Materialized View 2: Product Category Performance
CREATE MATERIALIZED VIEW mv_category_performance AS
SELECT 
    c.category_id,
    c.category_name,
    COUNT(DISTINCT p.product_id) AS total_products,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.subtotal) AS revenue,
    ROUND(AVG(oi.subtotal / oi.quantity), 2) AS avg_price_per_unit,
    SUM(i.quantity_available) AS total_inventory
FROM categories c
JOIN products p ON c.category_id = p.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'Cancelled'
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC NULLS LAST;

CREATE UNIQUE INDEX idx_mv_category_performance_id ON mv_category_performance(category_id);

-- ═══════════════════════════════════════════════════════════
-- FUNCTIONS & PROCEDURES
-- ═══════════════════════════════════════════════════════════

-- Function 1: Calculate Customer Lifetime Value
CREATE OR REPLACE FUNCTION calculate_customer_ltv(p_customer_id INTEGER)
RETURNS TABLE (
    customer_id INTEGER,
    customer_name TEXT,
    total_orders BIGINT,
    total_revenue NUMERIC,
    avg_order_value NUMERIC,
    predicted_ltv NUMERIC,
    customer_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        COUNT(DISTINCT o.order_id)::BIGINT AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue,
        ROUND(COALESCE(AVG(o.total_amount), 0), 2) AS avg_order_value,
        -- Simple LTV prediction: avg_order_value * (total_orders * 1.5)
        ROUND(
            COALESCE(AVG(o.total_amount), 0) * 
            (COUNT(DISTINCT o.order_id) * 1.5), 
            2
        ) AS predicted_ltv,
        CASE 
            WHEN MAX(o.order_date) >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
            WHEN MAX(o.order_date) >= CURRENT_DATE - INTERVAL '90 days' THEN 'At Risk'
            WHEN MAX(o.order_date) IS NOT NULL THEN 'Churned'
            ELSE 'Never Purchased'
        END AS customer_status
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id 
        AND o.order_status != 'Cancelled'
    WHERE c.customer_id = p_customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_customer_ltv IS 'Calculate Customer Lifetime Value for a specific customer';

-- Function 2: Get Top Products by Category
CREATE OR REPLACE FUNCTION get_top_products_by_category(
    p_category_id INTEGER,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id INTEGER,
    product_name VARCHAR,
    price NUMERIC,
    units_sold BIGINT,
    revenue NUMERIC,
    avg_rating NUMERIC,
    stock_level INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.product_id,
        p.product_name,
        p.price,
        COALESCE(SUM(oi.quantity), 0)::BIGINT AS units_sold,
        COALESCE(SUM(oi.subtotal), 0) AS revenue,
        ROUND(COALESCE(AVG(r.rating), 0), 2) AS avg_rating,
        COALESCE(i.quantity_available, 0) AS stock_level
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'Cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
    LEFT JOIN inventory i ON p.product_id = i.product_id
    WHERE p.category_id = p_category_id
    GROUP BY p.product_id, p.product_name, p.price, i.quantity_available
    ORDER BY revenue DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_top_products_by_category IS 'Get top selling products for a specific category';

-- Function 3: Calculate Campaign ROI
CREATE OR REPLACE FUNCTION calculate_campaign_roi(p_campaign_id INTEGER)
RETURNS TABLE (
    campaign_id INTEGER,
    campaign_name VARCHAR,
    budget NUMERIC,
    revenue NUMERIC,
    roi_percentage NUMERIC,
    total_orders BIGINT,
    conversion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mc.campaign_id,
        mc.campaign_name,
        mc.budget,
        COALESCE(SUM(o.total_amount), 0) AS revenue,
        ROUND(
            (COALESCE(SUM(o.total_amount), 0) - mc.budget) * 100.0 / 
            NULLIF(mc.budget, 0), 
            2
        ) AS roi_percentage,
        COUNT(DISTINCT o.order_id)::BIGINT AS total_orders,
        ROUND(
            COUNT(DISTINCT CASE WHEN cc.conversion_date IS NOT NULL THEN cc.customer_id END) * 100.0 /
            NULLIF(COUNT(DISTINCT cc.customer_id), 0),
            2
        ) AS conversion_rate
    FROM marketing_campaigns mc
    LEFT JOIN orders o ON mc.campaign_id = o.campaign_id 
        AND o.order_status != 'Cancelled'
    LEFT JOIN customer_campaigns cc ON mc.campaign_id = cc.campaign_id
    WHERE mc.campaign_id = p_campaign_id
    GROUP BY mc.campaign_id, mc.campaign_name, mc.budget;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_campaign_roi IS 'Calculate ROI and metrics for a specific marketing campaign';

-- Function 4: Get Customer Purchase History
CREATE OR REPLACE FUNCTION get_customer_purchase_history(
    p_customer_id INTEGER,
    p_days INTEGER DEFAULT 365
)
RETURNS TABLE (
    order_id INTEGER,
    order_date TIMESTAMP,
    order_status VARCHAR,
    total_amount NUMERIC,
    items_count BIGINT,
    products TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.order_id,
        o.order_date,
        o.order_status,
        o.total_amount,
        COUNT(oi.order_item_id)::BIGINT AS items_count,
        STRING_AGG(p.product_name, ', ') AS products
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    WHERE o.customer_id = p_customer_id
        AND o.order_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY o.order_id, o.order_date, o.order_status, o.total_amount
    ORDER BY o.order_date DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_customer_purchase_history IS 'Get purchase history for a customer within specified days';

-- Function 5: Product Recommendation
CREATE OR REPLACE FUNCTION recommend_products(
    p_product_id INTEGER,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    recommended_product_id INTEGER,
    recommended_product_name VARCHAR,
    times_bought_together BIGINT,
    affinity_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH product_pairs AS (
        SELECT 
            oi2.product_id,
            COUNT(DISTINCT oi1.order_id)::BIGINT AS co_occurrence
        FROM order_items oi1
        JOIN order_items oi2 ON oi1.order_id = oi2.order_id 
            AND oi1.product_id != oi2.product_id
        JOIN orders o ON oi1.order_id = o.order_id
        WHERE oi1.product_id = p_product_id
            AND o.order_status != 'Cancelled'
        GROUP BY oi2.product_id
    )
    SELECT 
        p.product_id,
        p.product_name,
        pp.co_occurrence,
        ROUND(
            pp.co_occurrence * 100.0 / 
            (SELECT COUNT(DISTINCT order_id) FROM order_items WHERE product_id = p_product_id),
            2
        ) AS affinity_score
    FROM product_pairs pp
    JOIN products p ON pp.product_id = p.product_id
    ORDER BY pp.co_occurrence DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION recommend_products IS 'Get product recommendations based on purchase patterns';

-- ═══════════════════════════════════════════════════════════
-- STORED PROCEDURES
-- ═══════════════════════════════════════════════════════════

-- Procedure 1: Refresh All Materialized Views
CREATE OR REPLACE PROCEDURE refresh_all_materialized_views()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_performance;
    RAISE NOTICE 'All materialized views refreshed successfully';
END;
$$;

COMMENT ON PROCEDURE refresh_all_materialized_views IS 'Refresh all materialized views in the database';

-- Procedure 2: Update Customer Segments
CREATE OR REPLACE PROCEDURE update_customer_segments()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update customer segments based on spending
    UPDATE customers c
    SET customer_segment = CASE 
        WHEN COALESCE(spending.total, 0) >= 5000 THEN 'VIP'
        WHEN COALESCE(spending.total, 0) >= 1000 THEN 'Regular'
        ELSE 'New'
    END
    FROM (
        SELECT 
            customer_id,
            SUM(total_amount) AS total
        FROM orders
        WHERE order_status != 'Cancelled'
        GROUP BY customer_id
    ) spending
    WHERE c.customer_id = spending.customer_id;
    
    RAISE NOTICE 'Customer segments updated successfully';
END;
$$;

COMMENT ON PROCEDURE update_customer_segments IS 'Update customer segments based on spending patterns';

-- Procedure 3: Generate Sales Report
CREATE OR REPLACE PROCEDURE generate_sales_report(
    p_start_date DATE,
    p_end_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_revenue NUMERIC;
    v_total_orders INTEGER;
    v_avg_order_value NUMERIC;
BEGIN
    SELECT 
        SUM(total_amount),
        COUNT(*),
        AVG(total_amount)
    INTO v_total_revenue, v_total_orders, v_avg_order_value
    FROM orders
    WHERE order_date BETWEEN p_start_date AND p_end_date
        AND order_status != 'Cancelled';
    
    RAISE NOTICE 'Sales Report for % to %', p_start_date, p_end_date;
    RAISE NOTICE 'Total Revenue: $%', v_total_revenue;
    RAISE NOTICE 'Total Orders: %', v_total_orders;
    RAISE NOTICE 'Average Order Value: $%', ROUND(v_avg_order_value, 2);
END;
$$;

COMMENT ON PROCEDURE generate_sales_report IS 'Generate a sales summary report for a date range';

-- ═══════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════

-- Trigger 1: Update Inventory After Order
CREATE OR REPLACE FUNCTION update_inventory_after_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrease inventory when order is placed
    IF TG_OP = 'INSERT' THEN
        UPDATE inventory
        SET quantity_available = quantity_available - NEW.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE product_id = NEW.product_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_after_order();

COMMENT ON TRIGGER trg_update_inventory ON order_items IS 'Automatically update inventory when order is placed';

-- Trigger 2: Set Order Updated Timestamp
CREATE OR REPLACE FUNCTION set_order_updated_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.order_date = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: You would need an updated_at column in orders table for this trigger

-- ═══════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════

-- Function: Get Business Metrics Summary
CREATE OR REPLACE FUNCTION get_business_metrics_summary()
RETURNS TABLE (
    metric_name TEXT,
    metric_value TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total Revenue'::TEXT, 
           TO_CHAR(SUM(total_amount), 'FM$999,999,999.00')
    FROM orders WHERE order_status != 'Cancelled'
    UNION ALL
    SELECT 'Total Orders'::TEXT, 
           COUNT(*)::TEXT
    FROM orders WHERE order_status != 'Cancelled'
    UNION ALL
    SELECT 'Active Customers'::TEXT, 
           COUNT(DISTINCT customer_id)::TEXT
    FROM orders 
    WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
        AND order_status != 'Cancelled'
    UNION ALL
    SELECT 'Average Order Value'::TEXT, 
           TO_CHAR(AVG(total_amount), 'FM$999,999.00')
    FROM orders WHERE order_status != 'Cancelled'
    UNION ALL
    SELECT 'Total Products'::TEXT, 
           COUNT(*)::TEXT
    FROM products WHERE is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_business_metrics_summary IS 'Get quick summary of key business metrics';

-- ═══════════════════════════════════════════════════════════
-- EXAMPLE USAGE
-- ═══════════════════════════════════════════════════════════

-- Using the views:
-- SELECT * FROM vw_sales_summary WHERE order_month = '2024-01-01';
-- SELECT * FROM vw_product_performance ORDER BY revenue DESC LIMIT 10;
-- SELECT * FROM vw_customer_metrics WHERE customer_status = 'At Risk';

-- Using the functions:
-- SELECT * FROM calculate_customer_ltv(1);
-- SELECT * FROM get_top_products_by_category(2, 5);
-- SELECT * FROM calculate_campaign_roi(1);
-- SELECT * FROM get_customer_purchase_history(1, 180);
-- SELECT * FROM recommend_products(1, 5);

-- Using procedures:
-- CALL refresh_all_materialized_views();
-- CALL update_customer_segments();
-- CALL generate_sales_report('2024-01-01', '2024-12-31');

-- Get business summary:
-- SELECT * FROM get_business_metrics_summary();

-- ═══════════════════════════════════════════════════════════
-- END OF VIEWS & FUNCTIONS
-- ═══════════════════════════════════════════════════════════
