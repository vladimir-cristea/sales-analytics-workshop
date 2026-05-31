-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 1 - Create schema and volume
-- MAGIC
-- MAGIC Transparency copy of section 3 of `00_bootstrap`. Change the catalog to use your own.

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS vcr_serverless_catalog.shared_data
COMMENT 'Shared workshop data for Northgate Provisions Co.';

-- COMMAND ----------

CREATE VOLUME IF NOT EXISTS vcr_serverless_catalog.shared_data.data
COMMENT 'Landing volume for workshop raw + clean JSON';
