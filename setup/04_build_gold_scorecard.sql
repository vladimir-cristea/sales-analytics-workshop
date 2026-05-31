-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 4 — Build the heavy-OLAP gold_customer_scorecard
-- MAGIC
-- MAGIC Transparency copy of section 7 of `00_bootstrap`. Pre-computed per-customer analytics
-- MAGIC keyed by `customer_id` for point lookup — rolling-12-month revenue/profit/margin, RFM
-- MAGIC scores, an at-risk score/flag, peer percentile ranks, top categories, and a
-- MAGIC next-best-SKU cross-sell recommendation. This is the table the Lakebase practical syncs
-- MAGIC to Postgres. Change the catalog if not on the build workspace.

-- COMMAND ----------

CREATE OR REPLACE TABLE vcr_serverless_catalog.shared_data.gold_customer_scorecard
COMMENT 'Heavy-OLAP per-customer analytics scorecard, keyed by customer_id for point lookup (Lakebase source).' AS
WITH params AS (
  SELECT MAX(order_date) AS as_of_date FROM vcr_serverless_catalog.shared_data.orders
),
line_facts AS (
  SELECT o.order_id, o.customer_id, o.product_id, o.order_date, o.quantity, p.category,
         o.quantity * o.unit_price * (1 - o.discount_pct/100)                       AS revenue,
         o.quantity * o.unit_price * (1 - o.discount_pct/100) - o.quantity * p.cost  AS profit
  FROM vcr_serverless_catalog.shared_data.orders o
  JOIN vcr_serverless_catalog.shared_data.products p ON o.product_id = p.product_id
),
lifetime AS (
  SELECT customer_id,
         COUNT(order_id) AS lifetime_orders, SUM(quantity) AS lifetime_units,
         ROUND(SUM(revenue),2) AS lifetime_revenue, ROUND(SUM(profit),2) AS lifetime_profit,
         ROUND(AVG(revenue),2) AS avg_order_value, MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date
  FROM line_facts GROUP BY customer_id
),
r12 AS (
  SELECT lf.customer_id, COUNT(order_id) AS r12_orders,
         ROUND(SUM(revenue),2) AS r12_revenue, ROUND(SUM(profit),2) AS r12_profit
  FROM line_facts lf, params
  WHERE lf.order_date > add_months(params.as_of_date, -12)
  GROUP BY lf.customer_id
),
cust_cat AS (
  SELECT customer_id, category, SUM(revenue) AS cat_rev,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY SUM(revenue) DESC, category) AS rn
  FROM line_facts GROUP BY customer_id, category
),
top_cats AS (
  SELECT customer_id,
         MAX(CASE WHEN rn=1 THEN category END) AS top_category_1,
         MAX(CASE WHEN rn=2 THEN category END) AS top_category_2
  FROM cust_cat GROUP BY customer_id
),
purchased_prod AS (SELECT DISTINCT customer_id, product_id FROM line_facts),
seg_prod_pop AS (
  SELECT c.segment, lf.product_id, COUNT(DISTINCT lf.customer_id) AS cnt
  FROM line_facts lf JOIN vcr_serverless_catalog.shared_data.customers c ON lf.customer_id = c.customer_id
  GROUP BY c.segment, lf.product_id
),
cross_sell AS (
  SELECT customer_id, product_id AS cross_sell_product_id, product_name AS cross_sell_product_name FROM (
    SELECT cu.customer_id, pr.product_id, pr.product_name,
           ROW_NUMBER() OVER (PARTITION BY cu.customer_id ORDER BY COALESCE(sp.cnt,0) DESC, pr.product_id) AS rn
    FROM vcr_serverless_catalog.shared_data.customers cu
    CROSS JOIN vcr_serverless_catalog.shared_data.products pr
    LEFT JOIN purchased_prod pp ON pp.customer_id = cu.customer_id AND pp.product_id = pr.product_id
    LEFT JOIN seg_prod_pop sp ON sp.segment = cu.segment AND sp.product_id = pr.product_id
    WHERE pp.product_id IS NULL
  ) WHERE rn = 1
),
base AS (
  SELECT
    c.customer_id, c.customer_name, c.region, c.segment, c.account_manager, c.join_date,
    DATEDIFF((SELECT as_of_date FROM params), c.join_date) AS tenure_days,
    COALESCE(l.lifetime_orders,0) AS lifetime_orders, COALESCE(l.lifetime_units,0) AS lifetime_units,
    COALESCE(l.lifetime_revenue,0) AS lifetime_revenue, COALESCE(l.lifetime_profit,0) AS lifetime_profit,
    ROUND(100 * COALESCE(l.lifetime_profit,0)/NULLIF(l.lifetime_revenue,0),2) AS lifetime_margin_pct,
    COALESCE(l.avg_order_value,0) AS avg_order_value, l.first_order_date, l.last_order_date,
    COALESCE(r.r12_orders,0) AS r12_orders, COALESCE(r.r12_revenue,0) AS r12_revenue, COALESCE(r.r12_profit,0) AS r12_profit,
    ROUND(100 * COALESCE(r.r12_profit,0)/NULLIF(r.r12_revenue,0),2) AS r12_margin_pct,
    DATEDIFF((SELECT as_of_date FROM params), l.last_order_date) AS recency_days,
    COALESCE(r.r12_orders,0) AS frequency_12m, COALESCE(r.r12_revenue,0) AS monetary_12m,
    tc.top_category_1, tc.top_category_2,
    xs.cross_sell_product_id, xs.cross_sell_product_name
  FROM vcr_serverless_catalog.shared_data.customers c
  LEFT JOIN lifetime l ON c.customer_id = l.customer_id
  LEFT JOIN r12 r ON c.customer_id = r.customer_id
  LEFT JOIN top_cats tc ON c.customer_id = tc.customer_id
  LEFT JOIN cross_sell xs ON c.customer_id = xs.customer_id
),
scored AS (
  SELECT b.*,
    CONCAT_WS(' | ', b.top_category_1, b.top_category_2) AS top_categories,
    NTILE(5) OVER (ORDER BY b.recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY b.frequency_12m ASC) AS f_score,
    NTILE(5) OVER (ORDER BY b.monetary_12m ASC) AS m_score,
    ROUND(100 * PERCENT_RANK() OVER (ORDER BY b.lifetime_revenue),1) AS revenue_percentile,
    ROUND(100 * PERCENT_RANK() OVER (PARTITION BY b.segment ORDER BY b.lifetime_revenue),1) AS revenue_percentile_in_segment,
    ROUND(100 * (0.6 * (b.recency_days/NULLIF(MAX(b.recency_days) OVER (),0))
              +  0.4 * (1 - (b.frequency_12m/NULLIF(MAX(b.frequency_12m) OVER (),0)))),1) AS at_risk_score
  FROM base b
)
SELECT s.*,
  CONCAT('R', r_score, 'F', f_score, 'M', m_score) AS rfm_cell,
  CASE WHEN r_score <= 2 AND m_score >= 4 THEN true ELSE false END AS at_risk_flag,
  current_timestamp() AS computed_at
FROM scored s;
