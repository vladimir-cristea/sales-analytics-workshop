-- ============================================================================
-- GOLD LAYER — business metrics. THIS is where cross-entity JOINS happen.
-- ----------------------------------------------------------------------------
-- Gold reads the clean, normalised silver tables, joins them, and aggregates
-- into denormalised business tables. All four are materialized views (batch
-- recompute over silver). Money maths:
--     line revenue = quantity * unit_price * (1 - discount_pct/100)   (in silver)
--     line profit  = revenue - quantity * products.cost               (needs the join)
-- ============================================================================

-- --- per-customer sales summary ----------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW gold_customer_sales_summary
COMMENT 'Per-customer revenue, profit and margin. Joins orders -> customers + products.'
AS SELECT
  c.customer_id, c.customer_name, c.region, c.segment, c.account_manager,
  COUNT(o.order_id)                                                        AS num_order_lines,
  SUM(o.quantity)                                                          AS total_units,
  ROUND(SUM(o.revenue), 2)                                                 AS total_revenue,
  ROUND(SUM(o.revenue - o.quantity * p.cost), 2)                           AS total_profit,
  ROUND(AVG(o.discount_pct), 2)                                            AS avg_discount_pct,
  ROUND(100 * SUM(o.revenue - o.quantity * p.cost)
            / NULLIF(SUM(o.revenue), 0), 2)                                AS profit_margin_pct,
  MIN(o.order_date)                                                        AS first_order_date,
  MAX(o.order_date)                                                        AS last_order_date
FROM silver_orders o
JOIN silver_customers c ON o.customer_id = c.customer_id
JOIN silver_products  p ON o.product_id  = p.product_id
GROUP BY c.customer_id, c.customer_name, c.region, c.segment, c.account_manager;

-- --- per-product performance --------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW gold_product_performance
COMMENT 'Per-product units, revenue, profit and margin. LEFT JOIN keeps never-sold products.'
AS SELECT
  p.product_id, p.product_name, p.category, p.list_price, p.cost,
  COUNT(o.order_id)                                                        AS num_order_lines,
  COALESCE(SUM(o.quantity), 0)                                             AS total_units_sold,
  COUNT(DISTINCT o.customer_id)                                            AS unique_customers,
  ROUND(COALESCE(SUM(o.revenue), 0), 2)                                    AS total_revenue,
  ROUND(COALESCE(SUM(o.revenue - o.quantity * p.cost), 0), 2)              AS total_profit,
  ROUND(AVG(o.discount_pct), 2)                                            AS avg_discount_pct,
  ROUND(100 * SUM(o.revenue - o.quantity * p.cost)
            / NULLIF(SUM(o.revenue), 0), 2)                                AS profit_margin_pct
FROM silver_products p
LEFT JOIN silver_orders o ON p.product_id = o.product_id
GROUP BY p.product_id, p.product_name, p.category, p.list_price, p.cost;

-- --- per-account-manager (rep) performance -----------------------------------
CREATE OR REFRESH MATERIALIZED VIEW gold_rep_performance
COMMENT 'Per-account-manager book of business. LEFT JOIN keeps reps with no orders yet.'
AS SELECT
  c.account_manager,
  COUNT(DISTINCT c.customer_id)                                            AS num_customers,
  COUNT(o.order_id)                                                        AS num_order_lines,
  ROUND(COALESCE(SUM(o.revenue), 0), 2)                                    AS total_revenue,
  ROUND(COALESCE(SUM(o.revenue - o.quantity * p.cost), 0), 2)              AS total_profit,
  ROUND(100 * SUM(o.revenue - o.quantity * p.cost)
            / NULLIF(SUM(o.revenue), 0), 2)                                AS profit_margin_pct,
  ROUND(AVG(o.revenue), 2)                                                 AS avg_order_value
FROM silver_customers c
LEFT JOIN silver_orders   o ON c.customer_id = o.customer_id
LEFT JOIN silver_products p ON o.product_id  = p.product_id
GROUP BY c.account_manager;

-- --- at-risk customers --------------------------------------------------------
-- "as of" date = latest order in the clean data (2026-05-31). These outlets
-- normally reorder roughly fortnightly (typical gap to last order ~14 days), so
-- a customer is flagged at risk if they have never ordered, or have not ordered
-- in the last 30 days (more than double the normal reorder cadence).
CREATE OR REFRESH MATERIALIZED VIEW gold_at_risk_customers
COMMENT 'Customers with no orders in the last 30 days (as of the latest order date).'
AS
WITH as_of AS (
  SELECT MAX(order_date) AS as_of_date FROM silver_orders
),
per_customer AS (
  SELECT
    c.customer_id, c.customer_name, c.region, c.segment, c.account_manager,
    MAX(o.order_date)        AS last_order_date,
    COUNT(o.order_id)        AS lifetime_orders,
    ROUND(COALESCE(SUM(o.revenue), 0), 2) AS lifetime_revenue
  FROM silver_customers c
  LEFT JOIN silver_orders o ON c.customer_id = o.customer_id
  GROUP BY c.customer_id, c.customer_name, c.region, c.segment, c.account_manager
)
SELECT
  pc.*,
  (SELECT as_of_date FROM as_of)                                  AS as_of_date,
  DATEDIFF((SELECT as_of_date FROM as_of), pc.last_order_date)    AS days_since_last_order
FROM per_customer pc
WHERE pc.last_order_date IS NULL
   OR DATEDIFF((SELECT as_of_date FROM as_of), pc.last_order_date) > 30;
