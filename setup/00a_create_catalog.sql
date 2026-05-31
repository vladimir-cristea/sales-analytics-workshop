-- Databricks notebook source
-- MAGIC %md
-- MAGIC # (Optional) Create catalog
-- MAGIC
-- MAGIC By default this reuses the existing `workshop`, so this step is
-- MAGIC **not** run by default. To create a fresh catalog on your workspace, run this once,
-- MAGIC then point the bootstrap's `catalog` widget at it.
-- MAGIC
-- MAGIC A managed catalog needs no storage location on most workspaces. If yours requires one,
-- MAGIC uncomment the `MANAGED LOCATION` line and supply an S3/ABFSS path.

-- COMMAND ----------

CREATE CATALOG IF NOT EXISTS workshop
-- MANAGED LOCATION 's3://my-bucket/workshop'   -- uncomment if your metastore requires it
COMMENT 'Sales analytics workshop (Northgate Provisions Co.)';
