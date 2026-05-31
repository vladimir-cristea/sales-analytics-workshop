-- ---------------------------------------------------------------------------
-- Practical 3 — Lakebase  •  Point-lookup exercises (run from psql)
-- ---------------------------------------------------------------------------
-- The story for Postgres-fluent engineers: this scorecard was computed with
-- heavy OLAP (window functions, RFM scoring, percentiles, cross-sell) you would
-- NEVER run live against the transactional source. We precompute it in the
-- lakehouse and serve it here as a plain Postgres table keyed by customer_id —
-- single-digit-millisecond point lookups. "Look, it's real Postgres."
-- ---------------------------------------------------------------------------

-- 1) The headline OLTP pattern: point lookup by primary key.
\x on
SELECT customer_id, customer_name, region, segment,
       lifetime_revenue, r12_revenue, rfm_cell, at_risk_flag,
       cross_sell_product_name
FROM   public.customer_scorecard
WHERE  customer_id = 42;
\x off

-- 2) Prove it's an index lookup, not a scan. The PRIMARY KEY gives a btree on
--    customer_id. (On a 70-row table the planner may pick a seq scan because the
--    whole table is one page — force the index to see the plan it uses at scale.)
SET enable_seqscan = off;
EXPLAIN ANALYZE SELECT * FROM public.customer_scorecard WHERE customer_id = 42;
RESET enable_seqscan;
-- Tested plan: Index Scan using customer_scorecard_pkey … Execution Time: 0.02 ms

-- 3) Precomputed at-risk flag (partial index) — serve a churn worklist instantly.
SELECT customer_id, customer_name, at_risk_score, recency_days
FROM   public.customer_scorecard
WHERE  at_risk_flag
ORDER  BY at_risk_score DESC
LIMIT  5;

-- 4) Account-manager book of business, top customers by rolling-12m revenue.
SELECT account_manager, customer_name, r12_revenue, r12_margin_pct
FROM   public.customer_scorecard
WHERE  account_manager = 'Priya Sharma'
ORDER  BY r12_revenue DESC
LIMIT  5;

-- 5) Next-best-action: customers with a cross-sell recommendation in a category
--    they don't already buy heavily — the kind of row an app would fetch per user.
SELECT customer_id, customer_name, top_category_1, cross_sell_product_name
FROM   public.customer_scorecard
WHERE  segment = 'National Group'
ORDER  BY revenue_percentile DESC
LIMIT  10;
