-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 5 - Participant grants (+ per-user schemas)
-- MAGIC
-- MAGIC Transparency copy of section 8 of `00_bootstrap`. The bootstrap creates one scratch
-- MAGIC schema **per participant** (driven by the `participant_users` widget) in Python; the
-- MAGIC group grants below are the shared-data read access. Replace `workshop_participants`
-- MAGIC with your group name and change the catalog to use your own.
-- MAGIC
-- MAGIC **Prerequisite:** the group must exist (Settings → Identity and Access → Groups).

-- COMMAND ----------

GRANT USE CATALOG   ON CATALOG vcr_serverless_catalog                        TO `workshop_participants`;
GRANT CREATE SCHEMA ON CATALOG vcr_serverless_catalog                        TO `workshop_participants`;
GRANT USE SCHEMA    ON SCHEMA  vcr_serverless_catalog.shared_data            TO `workshop_participants`;
GRANT SELECT        ON SCHEMA  vcr_serverless_catalog.shared_data            TO `workshop_participants`;
GRANT READ VOLUME   ON VOLUME  vcr_serverless_catalog.shared_data.data       TO `workshop_participants`;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Per-user scratch schema (example)
-- MAGIC The bootstrap generates one of these per participant automatically. Manual equivalent:

-- COMMAND ----------

-- CREATE SCHEMA IF NOT EXISTS vcr_serverless_catalog.ws_someone_example_com
--   COMMENT 'Workshop scratch schema for someone@example.com';
-- GRANT USE SCHEMA, CREATE TABLE, CREATE MATERIALIZED VIEW, SELECT, MODIFY
--   ON SCHEMA vcr_serverless_catalog.ws_someone_example_com TO `someone@example.com`;
