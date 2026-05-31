-- ============================================================================
-- SILVER LAYER - cleaned, validated, conformed. STILL NORMALISED: one table per
-- entity, NO cross-entity joins (those live in gold).
-- ----------------------------------------------------------------------------
-- Data quality is enforced with SDP expectations:
--     CONSTRAINT <name> EXPECT (<predicate>) ON VIOLATION DROP ROW
-- Rows that fail are dropped from the table but COUNTED in the pipeline's data
-- quality metrics, so you can see exactly how much dirt each rule removed.
--
-- customers & products are pure row-level filters, so they stay STREAMING
-- TABLES (incremental, append-only) reading from their bronze stream.
--
-- orders additionally needs DE-DUPLICATION on order_id. Picking one row per key
-- is a full-table window (ROW_NUMBER), which streaming queries don't support -
-- so silver_orders is a MATERIALIZED VIEW (batch recompute over bronze). This is
-- the one place the layer is not a streaming table, and the dedup is the reason.
-- ============================================================================

-- --- customers: drop null id, invalid region, TEST segment, %test% names ----
CREATE OR REFRESH STREAMING TABLE silver_customers (
  CONSTRAINT valid_customer_id EXPECT (customer_id IS NOT NULL)                ON VIOLATION DROP ROW,
  CONSTRAINT valid_region      EXPECT (region IN (
      'London','South East','South West','East of England','Midlands',
      'North West','North East','Yorkshire','Scotland','Wales','Northern Ireland'
  ))                                                                           ON VIOLATION DROP ROW,
  CONSTRAINT not_test_segment  EXPECT (segment <> 'TEST')                      ON VIOLATION DROP ROW,
  CONSTRAINT not_test_name     EXPECT (customer_name NOT ILIKE '%test%')       ON VIOLATION DROP ROW
)
COMMENT 'Clean, conformed customer outlets (one row per customer_id).'
AS SELECT
  customer_id, customer_name, region, segment, account_manager, join_date
FROM STREAM bronze_customers;

-- --- products: drop null id, non-positive list_price; add intrinsic margin ---
CREATE OR REFRESH STREAMING TABLE silver_products (
  CONSTRAINT valid_product_id     EXPECT (product_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT positive_list_price  EXPECT (list_price > 0)         ON VIOLATION DROP ROW
)
COMMENT 'Clean product catalogue (one row per product_id). margin_pct is intrinsic (no join).'
AS SELECT
  product_id, product_name, category, list_price, cost,
  ROUND(100 * (list_price - cost) / list_price, 2) AS margin_pct,
  launch_date
FROM STREAM bronze_products;

-- --- orders: de-duplicate on order_id, then drop invalid rows -----------------
-- Intrinsic line revenue (quantity * unit_price * (1 - discount_pct/100)) is
-- computed here; profit needs products.cost, so it is deferred to gold.
CREATE OR REFRESH MATERIALIZED VIEW silver_orders (
  CONSTRAINT valid_order_id      EXPECT (order_id IS NOT NULL)             ON VIOLATION DROP ROW,
  CONSTRAINT valid_customer_fk   EXPECT (customer_id IS NOT NULL)          ON VIOLATION DROP ROW,
  CONSTRAINT valid_product_fk    EXPECT (product_id IS NOT NULL)           ON VIOLATION DROP ROW,
  CONSTRAINT positive_quantity   EXPECT (quantity > 0)                     ON VIOLATION DROP ROW,
  CONSTRAINT valid_discount      EXPECT (discount_pct BETWEEN 0 AND 100)   ON VIOLATION DROP ROW,
  CONSTRAINT not_future_order    EXPECT (order_date <= current_date())     ON VIOLATION DROP ROW
)
COMMENT 'Clean, de-duplicated order lines (one row per order_id). revenue is intrinsic; profit is in gold.'
AS SELECT
  order_id, customer_id, product_id, order_date, quantity, unit_price, discount_pct, currency,
  ROUND(quantity * unit_price * (1 - discount_pct / 100), 2) AS revenue
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY _ingested_at) AS _rn
  FROM bronze_orders
)
WHERE _rn = 1;
