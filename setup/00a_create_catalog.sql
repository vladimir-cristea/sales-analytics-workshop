-- Databricks notebook source
-- MAGIC %md
-- MAGIC # (Optional) Create catalog — customer workspace only
-- MAGIC
-- MAGIC On the build workspace we reuse the existing `vcr_serverless_catalog`, so this step is
-- MAGIC **not** run by default. On a customer's own workspace, run this once to create a fresh
-- MAGIC catalog, then point the bootstrap's `catalog` widget at it.
-- MAGIC
-- MAGIC A managed catalog needs no storage location on most workspaces. If yours requires one,
-- MAGIC uncomment the `MANAGED LOCATION` line and supply an S3/ABFSS path.

-- COMMAND ----------

CREATE CATALOG IF NOT EXISTS sales_analytics_workshop
-- MANAGED LOCATION 's3://my-bucket/workshop'   -- uncomment if your metastore requires it
COMMENT 'Sales analytics workshop (Northgate Provisions Co.)';
