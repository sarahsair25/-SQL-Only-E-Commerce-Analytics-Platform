-- ═══════════════════════════════════════════════════════════
-- E-COMMERCE ANALYTICS QUERIES
-- Advanced SQL Analytics for Business Intelligence
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════
-- SECTION 1: SALES ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 1.1 Monthly Revenue Trend
-- Shows revenue, orders, and average order value by month
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(total_amount) / COUNT(DISTINCT customer_id), 2) AS revenue_per_customer
FROM orders
WHERE order_status != 'Cancelled'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month DESC;

-- 1.2 Daily Sales Performance (Last 30 Days)
-- Tracks daily sales with running totals
SELECT 
    DATE(order_date) AS sale_date,
    COUNT(order_id) AS orders,
    SUM(total_amount) AS daily_revenue,
    SUM(SUM(total_amount)) OVER (ORDER BY DATE(order_date)) AS running_total,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    -- Compare with previous day
    LAG(SUM(total_amount)) OVER (ORDER BY DATE(order_date)) AS prev_day_revenue,
    ROUND(
        ((SUM(total_amount) - LAG(SUM(total_amount)) OVER (ORDER BY DATE(order_date))) 
        / NULLIF(LAG(SUM(total_amount)) OVER (ORDER BY DATE(order_date)), 0) * 100), 
        2
    ) AS revenue_growth_pct
FROM orders
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
    AND order_status != 'Cancelled'
GROUP BY DATE(order_date)
ORDER BY sale_date DESC;

-- 1.3 Revenue by Payment Method
-- Analyzes revenue distribution across payment methods
SELECT 
    payment_method,
    COUNT(order_id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER (), 2) AS revenue_percentage,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders,
    ROUND(
        COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) AS cancellation_rate
FROM orders
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- 1.4 Top Revenue Days (Best Performing Days)
SELECT 
    DATE(order_date) AS sale_date,
    TO_CHAR(order_date, 'Day') AS day_of_week,
    COUNT(order_id) AS orders,
    SUM(total_amount) AS revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value
FROM orders
WHERE order_status != 'Cancelled'
GROUP BY DATE(order_date), TO_CHAR(order_date, 'Day')
ORDER BY revenue DESC
LIMIT 10;

-- 1.5 Revenue by Order Status
SELECT 
    order_status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS order_percentage,
    MIN(total_amount) AS min_order,
    MAX(total_amount) AS max_order
FROM orders
GROUP BY order_status
ORDER BY total_revenue DESC;

-- ═══════════════════════════════════════════════════════════
-- SECTION 2: PRODUCT ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 2.1 Best Selling Products (By Revenue)
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.subtotal) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_price,
    ROUND(SUM(oi.subtotal) / SUM(oi.quantity), 2) AS revenue_per_unit,
    -- Profit calculation
    SUM(oi.quantity) * p.cost AS total_cost,
    SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost) AS total_profit,
    ROUND(
        (SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost)) * 100.0 / NULLIF(SUM(oi.subtotal), 0), 
        2
    ) AS profit_margin_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'Cancelled'
GROUP BY p.product_id, p.product_name, c.category_name, p.cost
ORDER BY total_revenue DESC
LIMIT 20;

-- 2.2 Product Performance by Category
SELECT 
    c.category_name,
    COUNT(DISTINCT p.product_id) AS products_in_category,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.subtotal) AS total_revenue,
    ROUND(AVG(oi.subtotal / oi.quantity), 2) AS avg_price_per_unit,
    ROUND(SUM(oi.subtotal) * 100.0 / SUM(SUM(oi.subtotal)) OVER (), 2) AS revenue_share_pct
FROM categories c
LEFT JOIN products p ON c.category_id = p.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'Cancelled' OR o.order_status IS NULL
GROUP BY c.category_name
ORDER BY total_revenue DESC NULLS LAST;

-- 2.3 Products with Low Stock (Inventory Alert)
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    i.warehouse_location,
    i.quantity_available,
    i.reorder_level,
    i.quantity_available - i.reorder_level AS stock_diff,
    -- Calculate 30-day sales velocity
    COALESCE(sales.units_sold_30d, 0) AS units_sold_last_30d,
    ROUND(COALESCE(sales.units_sold_30d / 30.0, 0), 2) AS daily_sales_rate,
    -- Days until stockout
    CASE 
        WHEN COALESCE(sales.units_sold_30d / 30.0, 0) > 0 
        THEN ROUND(i.quantity_available / (sales.units_sold_30d / 30.0), 0)
        ELSE NULL
    END AS days_until_stockout,
    i.last_restock_date
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) AS units_sold_30d
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
        AND o.order_status != 'Cancelled'
    GROUP BY oi.product_id
) sales ON p.product_id = sales.product_id
WHERE i.quantity_available <= i.reorder_level * 1.2  -- Alert when within 120% of reorder level
ORDER BY days_until_stockout ASC NULLS LAST, i.quantity_available ASC;

-- 2.4 Product Return Rate Analysis (Using Cancelled Orders as Proxy)
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN o.order_status = 'Cancelled' THEN oi.order_id END) AS cancelled_orders,
        SUM(oi.quantity) AS total_units,
        SUM(CASE WHEN o.order_status = 'Cancelled' THEN oi.quantity ELSE 0 END) AS cancelled_units
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    GROUP BY p.product_id, p.product_name
)
SELECT 
    product_id,
    product_name,
    total_orders,
    cancelled_orders,
    ROUND(cancelled_orders * 100.0 / NULLIF(total_orders, 0), 2) AS cancellation_rate_pct,
    total_units,
    cancelled_units
FROM product_sales
WHERE total_orders >= 5  -- Only products with significant sales
ORDER BY cancellation_rate_pct DESC NULLS LAST
LIMIT 20;

-- 2.5 Product Review Analysis
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.rating), 2) AS avg_rating,
    COUNT(CASE WHEN r.rating = 5 THEN 1 END) AS five_star,
    COUNT(CASE WHEN r.rating = 4 THEN 1 END) AS four_star,
    COUNT(CASE WHEN r.rating = 3 THEN 1 END) AS three_star,
    COUNT(CASE WHEN r.rating <= 2 THEN 1 END) AS low_rating,
    ROUND(
        COUNT(CASE WHEN r.rating >= 4 THEN 1 END) * 100.0 / COUNT(r.review_id), 
        2
    ) AS positive_review_pct,
    -- Sales correlation
    SUM(oi.quantity) AS units_sold
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN reviews r ON p.product_id = r.product_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'Cancelled' OR o.order_status IS NULL
GROUP BY p.product_id, p.product_name, c.category_name
HAVING COUNT(r.review_id) > 0
ORDER BY avg_rating DESC, total_reviews DESC;

-- ═══════════════════════════════════════════════════════════
-- SECTION 3: CUSTOMER ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 3.1 Customer Lifetime Value (CLV)
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.email,
        c.customer_segment,
        c.signup_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_revenue,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value,
        MAX(o.order_date) AS last_order_date,
        MIN(o.order_date) AS first_order_date,
        EXTRACT(DAY FROM MAX(o.order_date) - MIN(o.order_date)) AS customer_lifespan_days,
        -- Recency (days since last order)
        EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) AS days_since_last_order
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled' OR o.order_status IS NULL
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.customer_segment, c.signup_date
)
SELECT 
    customer_id,
    customer_name,
    email,
    customer_segment,
    total_orders,
    total_revenue,
    avg_order_value,
    last_order_date,
    days_since_last_order,
    -- Predicted CLV (simple calculation: avg order value * expected future orders)
    ROUND(avg_order_value * (total_orders * 1.5), 2) AS predicted_clv,
    -- Customer status
    CASE 
        WHEN days_since_last_order <= 30 THEN 'Active'
        WHEN days_since_last_order <= 90 THEN 'At Risk'
        WHEN days_since_last_order <= 180 THEN 'Churned'
        ELSE 'Lost'
    END AS customer_status
FROM customer_metrics
WHERE total_orders > 0
ORDER BY total_revenue DESC
LIMIT 50;

-- 3.2 Customer Segmentation (RFM Analysis)
-- Recency, Frequency, Monetary value
WITH rfm_calc AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.email,
        -- Recency: Days since last purchase
        EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) AS recency_days,
        -- Frequency: Number of orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: Total spend
        SUM(o.total_amount) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
),
rfm_scores AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,  -- Lower recency = better
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,    -- Higher frequency = better
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score      -- Higher monetary = better
    FROM rfm_calc
)
SELECT 
    customer_id,
    customer_name,
    email,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total,
    -- Customer segment based on RFM
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 4 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 4 THEN 'Need Attention'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Other'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC, monetary DESC;

-- 3.3 Customer Acquisition by Month
SELECT 
    DATE_TRUNC('month', signup_date) AS month,
    COUNT(*) AS new_customers,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', signup_date)) AS cumulative_customers,
    -- Calculate acquisition cost (assuming $50 per customer)
    COUNT(*) * 50 AS estimated_acquisition_cost
FROM customers
GROUP BY DATE_TRUNC('month', signup_date)
ORDER BY month DESC;

-- 3.4 Customer Purchase Frequency Distribution
SELECT 
    order_count,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_percentage,
    SUM(total_spent) AS total_revenue,
    ROUND(AVG(total_spent), 2) AS avg_spent
FROM (
    SELECT 
        c.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled' OR o.order_status IS NULL
    GROUP BY c.customer_id
) customer_orders
WHERE order_count > 0
GROUP BY order_count
ORDER BY order_count DESC;

-- 3.5 Top Customers by Revenue (VIP List)
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.customer_segment,
    c.city,
    c.state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_spent,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    -- Calculate percentile
    PERCENT_RANK() OVER (ORDER BY SUM(o.total_amount)) AS revenue_percentile
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status != 'Cancelled'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, 
         c.customer_segment, c.city, c.state
ORDER BY total_spent DESC
LIMIT 30;

-- ═══════════════════════════════════════════════════════════
-- SECTION 4: MARKETING ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 4.1 Campaign Performance (ROI Analysis)
SELECT 
    mc.campaign_id,
    mc.campaign_name,
    mc.campaign_type,
    mc.channel,
    mc.budget,
    mc.start_date,
    mc.end_date,
    -- Campaign metrics
    COUNT(DISTINCT cc.customer_id) AS total_interactions,
    COUNT(DISTINCT CASE WHEN cc.conversion_date IS NOT NULL THEN cc.customer_id END) AS conversions,
    ROUND(
        COUNT(DISTINCT CASE WHEN cc.conversion_date IS NOT NULL THEN cc.customer_id END) * 100.0 / 
        NULLIF(COUNT(DISTINCT cc.customer_id), 0), 
        2
    ) AS conversion_rate_pct,
    -- Revenue from campaign
    COALESCE(SUM(o.total_amount), 0) AS campaign_revenue,
    -- ROI calculation
    ROUND(
        (COALESCE(SUM(o.total_amount), 0) - mc.budget) * 100.0 / NULLIF(mc.budget, 0), 
        2
    ) AS roi_percentage,
    ROUND(COALESCE(SUM(o.total_amount), 0) / NULLIF(mc.budget, 0), 2) AS revenue_per_dollar_spent,
    -- Average order value from campaign
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM marketing_campaigns mc
LEFT JOIN customer_campaigns cc ON mc.campaign_id = cc.campaign_id
LEFT JOIN orders o ON cc.customer_id = o.customer_id 
    AND o.campaign_id = mc.campaign_id
    AND o.order_status != 'Cancelled'
GROUP BY mc.campaign_id, mc.campaign_name, mc.campaign_type, 
         mc.channel, mc.budget, mc.start_date, mc.end_date
ORDER BY campaign_revenue DESC;

-- 4.2 Marketing Channel Effectiveness
SELECT 
    mc.channel,
    COUNT(DISTINCT mc.campaign_id) AS campaigns,
    SUM(mc.budget) AS total_budget,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total_amount) AS revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    ROUND(SUM(o.total_amount) / NULLIF(SUM(mc.budget), 0), 2) AS roas, -- Return on Ad Spend
    ROUND(
        (SUM(o.total_amount) - SUM(mc.budget)) / NULLIF(SUM(mc.budget), 0) * 100, 
        2
    ) AS roi_pct
FROM marketing_campaigns mc
LEFT JOIN orders o ON mc.campaign_id = o.campaign_id
    AND o.order_status != 'Cancelled'
GROUP BY mc.channel
ORDER BY revenue DESC;

-- 4.3 Customer Attribution Analysis
SELECT 
    cc.campaign_id,
    mc.campaign_name,
    mc.campaign_type,
    COUNT(DISTINCT cc.customer_id) AS customers_reached,
    COUNT(DISTINCT CASE WHEN cc.conversion_date IS NOT NULL THEN cc.customer_id END) AS converted_customers,
    -- Time to conversion
    ROUND(
        AVG(EXTRACT(DAY FROM cc.conversion_date - cc.interaction_date)), 
        1
    ) AS avg_days_to_conversion,
    -- Revenue attribution
    SUM(o.total_amount) AS attributed_revenue
FROM customer_campaigns cc
JOIN marketing_campaigns mc ON cc.campaign_id = mc.campaign_id
LEFT JOIN orders o ON cc.customer_id = o.customer_id 
    AND o.campaign_id = mc.campaign_id
    AND o.order_status != 'Cancelled'
GROUP BY cc.campaign_id, mc.campaign_name, mc.campaign_type
ORDER BY attributed_revenue DESC NULLS LAST;

-- 4.4 Campaign Performance Over Time
SELECT 
    DATE_TRUNC('week', o.order_date) AS week,
    mc.campaign_name,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total_amount) AS revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM orders o
JOIN marketing_campaigns mc ON o.campaign_id = mc.campaign_id
WHERE o.order_status != 'Cancelled'
    AND o.order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('week', o.order_date), mc.campaign_name
ORDER BY week DESC, revenue DESC;

-- ═══════════════════════════════════════════════════════════
-- SECTION 5: OPERATIONAL ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 5.1 Shipping Performance Analysis
SELECT 
    s.carrier,
    COUNT(*) AS total_shipments,
    -- Delivery performance
    ROUND(
        AVG(EXTRACT(DAY FROM s.delivery_date - s.shipping_date)), 
        1
    ) AS avg_delivery_days,
    -- On-time delivery
    COUNT(CASE WHEN s.delivery_date <= s.estimated_delivery THEN 1 END) AS on_time_deliveries,
    ROUND(
        COUNT(CASE WHEN s.delivery_date <= s.estimated_delivery THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) AS on_time_pct,
    -- Delayed deliveries
    COUNT(CASE WHEN s.delivery_date > s.estimated_delivery THEN 1 END) AS delayed_deliveries,
    ROUND(
        AVG(CASE 
            WHEN s.delivery_date > s.estimated_delivery 
            THEN EXTRACT(DAY FROM s.delivery_date - s.estimated_delivery) 
        END), 
        1
    ) AS avg_delay_days
FROM shipping s
WHERE s.delivery_date IS NOT NULL
GROUP BY s.carrier
ORDER BY on_time_pct DESC;

-- 5.2 Order Fulfillment Metrics
SELECT 
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END) AS delivered,
    COUNT(CASE WHEN o.order_status = 'Cancelled' THEN 1 END) AS cancelled,
    COUNT(CASE WHEN o.order_status = 'Pending' THEN 1 END) AS pending,
    ROUND(
        COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) AS fulfillment_rate_pct,
    ROUND(
        COUNT(CASE WHEN o.order_status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) AS cancellation_rate_pct
FROM orders o
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month DESC;

-- 5.3 Inventory Turnover by Category
SELECT 
    c.category_name,
    SUM(i.quantity_available) AS current_stock,
    COALESCE(SUM(sales.units_sold), 0) AS units_sold_last_90d,
    ROUND(
        COALESCE(SUM(sales.units_sold), 0) * 365.0 / 90.0 / 
        NULLIF(SUM(i.quantity_available), 0), 
        2
    ) AS inventory_turnover_ratio,
    ROUND(
        365.0 / NULLIF(
            COALESCE(SUM(sales.units_sold), 0) * 365.0 / 90.0 / 
            NULLIF(SUM(i.quantity_available), 0)
        , 0), 
        1
    ) AS days_inventory_outstanding
FROM categories c
JOIN products p ON c.category_id = p.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
        AND o.order_status != 'Cancelled'
    GROUP BY oi.product_id
) sales ON p.product_id = sales.product_id
GROUP BY c.category_name
ORDER BY inventory_turnover_ratio DESC NULLS LAST;

-- 5.4 Geographic Sales Distribution
SELECT 
    c.state,
    c.city,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total_amount) AS revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    ROUND(SUM(o.total_amount) * 100.0 / SUM(SUM(o.total_amount)) OVER (), 2) AS revenue_share_pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status != 'Cancelled'
GROUP BY c.state, c.city
ORDER BY revenue DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════
-- SECTION 6: ADVANCED ANALYTICS
-- ═══════════════════════════════════════════════════════════

-- 6.1 Cohort Analysis (Monthly Customer Retention)
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM orders
    WHERE order_status != 'Cancelled'
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT 
        cc.cohort_month,
        DATE_TRUNC('month', o.order_date) AS activity_month,
        COUNT(DISTINCT o.customer_id) AS active_customers
    FROM customer_cohorts cc
    JOIN orders o ON cc.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY cc.cohort_month, DATE_TRUNC('month', o.order_date)
)
SELECT 
    cohort_month,
    COUNT(*) FILTER (WHERE activity_month = cohort_month) AS month_0,
    COUNT(*) FILTER (WHERE activity_month = cohort_month + INTERVAL '1 month') AS month_1,
    COUNT(*) FILTER (WHERE activity_month = cohort_month + INTERVAL '2 months') AS month_2,
    COUNT(*) FILTER (WHERE activity_month = cohort_month + INTERVAL '3 months') AS month_3,
    -- Retention rates
    ROUND(
        COUNT(*) FILTER (WHERE activity_month = cohort_month + INTERVAL '1 month') * 100.0 / 
        NULLIF(COUNT(*) FILTER (WHERE activity_month = cohort_month), 0), 
        2
    ) AS retention_month_1_pct
FROM cohort_activity
GROUP BY cohort_month
ORDER BY cohort_month DESC;

-- 6.2 Market Basket Analysis (Products Bought Together)
SELECT 
    p1.product_name AS product_1,
    p2.product_name AS product_2,
    COUNT(*) AS times_bought_together,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    ROUND(
        COUNT(*) * 100.0 / 
        (SELECT COUNT(DISTINCT order_id) FROM order_items WHERE product_id = oi1.product_id), 
        2
    ) AS support_pct
FROM order_items oi1
JOIN order_items oi2 ON oi1.order_id = oi2.order_id 
    AND oi1.product_id < oi2.product_id
JOIN products p1 ON oi1.product_id = p1.product_id
JOIN products p2 ON oi2.product_id = p2.product_id
JOIN orders o ON oi1.order_id = o.order_id
WHERE o.order_status != 'Cancelled'
GROUP BY p1.product_name, p2.product_name, oi1.product_id
HAVING COUNT(*) >= 3  -- Only show if bought together at least 3 times
ORDER BY times_bought_together DESC
LIMIT 20;

-- 6.3 Customer Churn Prediction Data
WITH customer_behavior AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) AS days_since_last_order,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_spent,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value,
        ROUND(
            AVG(EXTRACT(DAY FROM o.order_date - LAG(o.order_date) OVER (PARTITION BY c.customer_id ORDER BY o.order_date))), 
            1
        ) AS avg_days_between_orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
    customer_id,
    customer_name,
    days_since_last_order,
    total_orders,
    total_spent,
    avg_order_value,
    avg_days_between_orders,
    -- Churn risk score (simple scoring)
    CASE 
        WHEN days_since_last_order > avg_days_between_orders * 2 THEN 'High Risk'
        WHEN days_since_last_order > avg_days_between_orders * 1.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS churn_risk,
    -- Expected next purchase date
    MAX(order_date) + (avg_days_between_orders || ' days')::INTERVAL AS expected_next_purchase
FROM customer_behavior cb
JOIN orders o ON cb.customer_id = o.customer_id
WHERE avg_days_between_orders IS NOT NULL
GROUP BY cb.customer_id, cb.customer_name, cb.days_since_last_order, 
         cb.total_orders, cb.total_spent, cb.avg_order_value, cb.avg_days_between_orders
ORDER BY days_since_last_order DESC;

-- 6.4 Product Affinity Score (Recommendation Engine Data)
WITH product_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(DISTINCT oi1.order_id) AS co_occurrence
    FROM order_items oi1
    JOIN order_items oi2 ON oi1.order_id = oi2.order_id 
        AND oi1.product_id != oi2.product_id
    JOIN orders o ON oi1.order_id = o.order_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY oi1.product_id, oi2.product_id
),
product_totals AS (
    SELECT 
        oi.product_id,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY oi.product_id
)
SELECT 
    pa.product_name AS product,
    pb.product_name AS recommended_product,
    pp.co_occurrence,
    pta.total_orders AS product_a_orders,
    ptb.total_orders AS product_b_orders,
    ROUND(pp.co_occurrence * 100.0 / pta.total_orders, 2) AS affinity_score_pct,
    ROUND(
        pp.co_occurrence::NUMERIC / 
        SQRT(pta.total_orders::NUMERIC * ptb.total_orders::NUMERIC), 
        4
    ) AS cosine_similarity
FROM product_pairs pp
JOIN products pa ON pp.product_a = pa.product_id
JOIN products pb ON pp.product_b = pb.product_id
JOIN product_totals pta ON pp.product_a = pta.product_id
JOIN product_totals ptb ON pp.product_b = ptb.product_id
WHERE pp.co_occurrence >= 3
ORDER BY cosine_similarity DESC
LIMIT 30;

-- ═══════════════════════════════════════════════════════════
-- END OF ANALYTICS QUERIES
-- ═══════════════════════════════════════════════════════════
