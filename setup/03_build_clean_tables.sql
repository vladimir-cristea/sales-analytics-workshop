-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 3 - Build the clean shared + summary tables
-- MAGIC
-- MAGIC Transparency copy of sections 5–6 of `00_bootstrap`. Loads from the committed
-- MAGIC `clean/` JSON in the volume. Change the catalog to use your own.

-- COMMAND ----------

CREATE OR REPLACE TABLE workshop.shared_data.customers
COMMENT 'Northgate Provisions outlets (clean curated)' AS
SELECT customer_id, customer_name, region, segment, account_manager, CAST(join_date AS DATE) AS join_date
FROM read_files('/Volumes/workshop/shared_data/data/clean/customers/', format => 'json',
  schemaHints => 'customer_id INT, join_date DATE');

-- COMMAND ----------

CREATE OR REPLACE TABLE workshop.shared_data.products
COMMENT 'Northgate Provisions product catalogue (clean curated)' AS
SELECT product_id, product_name, category, CAST(list_price AS DECIMAL(10,2)) AS list_price,
       CAST(cost AS DECIMAL(10,2)) AS cost, CAST(launch_date AS DATE) AS launch_date
FROM read_files('/Volumes/workshop/shared_data/data/clean/products/', format => 'json',
  schemaHints => 'list_price DECIMAL(10,2), cost DECIMAL(10,2), launch_date DATE');

-- COMMAND ----------

CREATE OR REPLACE TABLE workshop.shared_data.orders
COMMENT 'Northgate Provisions order lines (clean curated)' AS
SELECT order_id, customer_id, product_id, CAST(order_date AS DATE) AS order_date, quantity,
       CAST(unit_price AS DECIMAL(10,2)) AS unit_price, CAST(discount_pct AS DECIMAL(5,2)) AS discount_pct, currency
FROM read_files('/Volumes/workshop/shared_data/data/clean/orders/', format => 'json',
  schemaHints => 'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2)');

-- COMMAND ----------

CREATE OR REPLACE TABLE workshop.shared_data.product_performance_summary
COMMENT 'Per-product performance (clean, pre-aggregated for Genie)' AS
SELECT
  p.product_id, p.product_name, p.category, p.list_price, p.cost,
  COUNT(o.order_id)                                                  AS num_order_lines,
  COALESCE(SUM(o.quantity), 0)                                       AS total_units_sold,
  COUNT(DISTINCT o.customer_id)                                      AS unique_customers,
  ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100)), 2) AS total_revenue,
  ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100) - o.quantity * p.cost), 2) AS total_profit,
  ROUND(AVG(o.discount_pct), 2)                                      AS avg_discount_pct,
  ROUND(100 * SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100) - o.quantity * p.cost)
        / NULLIF(SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100)), 0), 2) AS profit_margin_pct
FROM workshop.shared_data.products p
LEFT JOIN workshop.shared_data.orders o ON p.product_id = o.product_id
GROUP BY p.product_id, p.product_name, p.category, p.list_price, p.cost;

-- COMMAND ----------

CREATE OR REPLACE TABLE workshop.shared_data.monthly_sales_summary
COMMENT 'Monthly sales trend by region and segment (clean, pre-aggregated for Genie)' AS
SELECT
  DATE_TRUNC('MONTH', o.order_date) AS month, c.region, c.segment,
  COUNT(o.order_id)             AS num_order_lines,
  COUNT(DISTINCT o.customer_id) AS active_customers,
  SUM(o.quantity)               AS total_units,
  ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100)), 2)                       AS total_revenue,
  ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount_pct/100) - o.quantity * p.cost), 2) AS total_profit
FROM workshop.shared_data.orders o
JOIN workshop.shared_data.customers c ON o.customer_id = c.customer_id
JOIN workshop.shared_data.products  p ON o.product_id  = p.product_id
GROUP BY DATE_TRUNC('MONTH', o.order_date), c.region, c.segment;
