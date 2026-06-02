-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 3 - Build the clean shared tables
-- MAGIC
-- MAGIC Transparency copy of section 5 of `00_bootstrap`. Loads from the committed
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
