-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 6 - Build the governed `sales_metrics` metric view
-- MAGIC
-- MAGIC Transparency copy of section 7b of `00_bootstrap`. A Unity Catalog **metric view**
-- MAGIC (DBR 17.2+) that defines standardised sales KPIs in YAML over the clean `orders` fact,
-- MAGIC joined to `customers` and `products` - one governed source of truth shared by Genie,
-- MAGIC dashboards and SQL. Query it with `MEASURE(...)` (a plain `SELECT *` is not supported).
-- MAGIC Change the catalog to use your own.

-- COMMAND ----------

CREATE OR REPLACE VIEW vcr_serverless_catalog.shared_data.sales_metrics
WITH METRICS
LANGUAGE YAML
COMMENT 'Governed sales KPIs for Northgate Provisions Co. (orders fact joined to customers + products).'
AS $$
version: "1.1"
source: vcr_serverless_catalog.shared_data.orders
comment: "Governed sales KPIs over clean order lines."
joins:
  - name: customers
    source: vcr_serverless_catalog.shared_data.customers
    on: source.customer_id = customers.customer_id
  - name: products
    source: vcr_serverless_catalog.shared_data.products
    on: source.product_id = products.product_id
dimensions:
  - name: Region
    expr: customers.region
  - name: Segment
    expr: customers.segment
  - name: Account Manager
    expr: customers.account_manager
  - name: Category
    expr: products.category
  - name: Order Month
    expr: DATE_TRUNC('MONTH', order_date)
measures:
  - name: Total Revenue
    expr: SUM(quantity * unit_price * (1 - discount_pct/100))
  - name: Total Profit
    expr: SUM(quantity * unit_price * (1 - discount_pct/100) - quantity * products.cost)
  - name: Profit Margin %
    expr: 100 * SUM(quantity * unit_price * (1 - discount_pct/100) - quantity * products.cost) / SUM(quantity * unit_price * (1 - discount_pct/100))
  - name: Order Count
    expr: COUNT(order_id)
  - name: Units Sold
    expr: SUM(quantity)
  - name: Avg Order Value
    expr: SUM(quantity * unit_price * (1 - discount_pct/100)) / COUNT(order_id)
  - name: Active Customers (90d)
    expr: COUNT(DISTINCT customer_id) FILTER (WHERE order_date >= current_date() - INTERVAL 90 DAYS)
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Verify with a MEASURE() query - profit margin by segment

-- COMMAND ----------

SELECT `Segment`,
       ROUND(MEASURE(`Total Revenue`), 2)   AS revenue,
       ROUND(MEASURE(`Total Profit`), 2)    AS profit,
       ROUND(MEASURE(`Profit Margin %`), 2) AS margin_pct,
       MEASURE(`Order Count`)               AS orders
FROM vcr_serverless_catalog.shared_data.sales_metrics
GROUP BY `Segment` ORDER BY revenue DESC;

-- COMMAND ----------

-- Grant SELECT to the participant group (SELECT on the schema already covers it).
GRANT SELECT ON VIEW vcr_serverless_catalog.shared_data.sales_metrics TO `workshop_participants`;
