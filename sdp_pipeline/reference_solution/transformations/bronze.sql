-- ============================================================================
-- BRONZE LAYER - raw, as-ingested, one streaming table per entity.
-- ----------------------------------------------------------------------------
-- Auto Loader (STREAM read_files) incrementally ingests the deliberately DIRTY
-- raw JSON from the Unity Catalog volume. NO cleaning happens here: bronze is a
-- faithful, append-only copy of the source plus ingestion metadata. All data
-- quality work is deferred to silver.
--
-- schemaHints pin the column types so a dirty value (e.g. a null customer_id or
-- a negative quantity) lands as a typed NULL / number rather than silently
-- changing the inferred schema. Bad rows are KEPT here on purpose so the silver
-- expectations have something to drop.
-- ============================================================================

CREATE OR REFRESH STREAMING TABLE bronze_customers
COMMENT 'Raw customer outlets as ingested from the volume (dirty, no cleaning).'
AS SELECT
  *,
  current_timestamp()  AS _ingested_at,
  _metadata.file_path  AS _source_file
FROM STREAM read_files(
  '/Volumes/vcr_serverless_catalog/shared_data/data/raw/customers/',
  format      => 'json',
  schemaHints => 'customer_id INT, join_date DATE'
);

CREATE OR REFRESH STREAMING TABLE bronze_products
COMMENT 'Raw product catalogue as ingested from the volume (dirty, no cleaning).'
AS SELECT
  *,
  current_timestamp()  AS _ingested_at,
  _metadata.file_path  AS _source_file
FROM STREAM read_files(
  '/Volumes/vcr_serverless_catalog/shared_data/data/raw/products/',
  format      => 'json',
  schemaHints => 'list_price DECIMAL(10,2), cost DECIMAL(10,2), launch_date DATE'
);

CREATE OR REFRESH STREAMING TABLE bronze_orders
COMMENT 'Raw order lines as ingested from the volume (dirty, duplicates kept).'
AS SELECT
  *,
  current_timestamp()  AS _ingested_at,
  _metadata.file_path  AS _source_file
FROM STREAM read_files(
  '/Volumes/vcr_serverless_catalog/shared_data/data/raw/orders/',
  format      => 'json',
  schemaHints => 'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2)'
);
