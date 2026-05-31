# Reference solution - FACILITATOR ANSWER KEY (not for participants)

> ⚠️ **This folder is the answer key.** Participants do **not** receive these files.
> In Practical 2 they build their own bronze → silver → gold pipeline from scratch,
> prompting **Genie Code** against the brief in the slides and the data dictionary in
> [`../../data/README.md`](../../data/README.md). This reference exists to (a) prove the
> brief is achievable, (b) give the facilitator something to validate participant output
> against, and (c) pin the exact table definitions the lab text should teach.

A serverless **Spark Declarative Pipeline** that ingests the deliberately *dirty* raw
JSON from a Unity Catalog volume, cleans and validates it with expectations, and produces
four gold business tables.

---

## Layout

```
reference_solution/
├── README.md                     ← this file
└── transformations/
    ├── bronze.sql                ← 3 streaming tables (Auto Loader, raw, no cleaning)
    ├── silver.sql                ← 3 cleaned/validated tables (expectations; orders also de-dupes)
    └── gold.sql                  ← 4 materialized views (joins + aggregation)
```

Input volume (built by the bootstrap):
`/Volumes/vcr_serverless_catalog/shared_data/data/raw/{customers,products,orders}/`
Output schema: `vcr_serverless_catalog.pipeline_ref` (kept separate from `shared_data` so
the reference never clobbers the shared clean tables).

---

## The medallion design (this is the structure the lab teaches)

Joins are deferred to **gold**. Silver stays normalised - one clean table per entity, no
cross-entity joins. This is deliberate: it keeps each silver expectation about a single
entity, and concentrates all the join logic in one layer.

### BRONZE - raw, as-ingested (streaming tables, Auto Loader)
| Table | Notes |
|-------|-------|
| `bronze_customers` | `STREAM read_files(... customers/)`, `schemaHints 'customer_id INT, join_date DATE'` |
| `bronze_products`  | `STREAM read_files(... products/)`, `schemaHints 'list_price DECIMAL(10,2), cost DECIMAL(10,2), launch_date DATE'` |
| `bronze_orders`    | `STREAM read_files(... orders/)`, `schemaHints 'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2)'` |

No cleaning. Each row gets `_ingested_at` and `_source_file` metadata. Dirt is kept on
purpose so silver has something to drop.

### SILVER - cleaned, validated, conformed, still normalised (one per entity, no joins)
Expectations use `CONSTRAINT <name> EXPECT (<predicate>) ON VIOLATION DROP ROW`.

| Table | Type | Expectations (all `DROP ROW`) | Intrinsic columns added |
|-------|------|-------------------------------|--------------------------|
| `silver_customers` | streaming table | `customer_id IS NOT NULL`; `region IN (<11 valid UK regions>)`; `segment <> 'TEST'`; `customer_name NOT ILIKE '%test%'` | - |
| `silver_products`  | streaming table | `product_id IS NOT NULL`; `list_price > 0` | `margin_pct = 100*(list_price-cost)/list_price` |
| `silver_orders`    | **materialized view** | `order_id/customer_id/product_id IS NOT NULL`; `quantity > 0`; `discount_pct BETWEEN 0 AND 100`; `order_date <= current_date()` | `revenue = quantity*unit_price*(1-discount_pct/100)` |

**Why `silver_orders` is a materialized view, not a streaming table:** it must
**de-duplicate on `order_id`** (the raw feed re-appends 15 verbatim duplicate orders).
Picking one row per key needs a full-table window (`ROW_NUMBER() OVER (PARTITION BY
order_id ...)`), which Spark streaming queries do not support. customers and products are
pure row-level filters, so they remain streaming tables. This mixed pattern is a genuine,
teachable engineering reason - Genie Code surfaces the same trade-off.

### GOLD - business metrics, **joins live here** (materialized views)
```
line revenue = quantity * unit_price * (1 - discount_pct/100)   -- already in silver_orders
line profit  = revenue - quantity * products.cost               -- needs the join to products
```
| Table | Grain | Join |
|-------|-------|------|
| `gold_customer_sales_summary` | one row per customer | `orders ⋈ customers ⋈ products` (inner) |
| `gold_product_performance`    | one row per product  | `products ⟕ orders` (left; keeps never-sold SKUs) |
| `gold_rep_performance`        | one row per account manager | `customers ⟕ orders ⟕ products` |
| `gold_at_risk_customers`      | one row per at-risk customer | `customers ⟕ orders`; no order in last 30 days |

`gold_at_risk_customers` anchors recency on `as_of_date = MAX(order_date)` (2026-05-31).
These outlets reorder roughly fortnightly (typical gap to last order ~14 days), so "no
order in 30+ days" (> 2× the normal cadence) is the at-risk signal. Returns 9 customers.

---

## How to run (facilitator)

**Option A - MCP / databricks-spark-declarative-pipelines skill (used to build this):**
1. Upload `transformations/` to a workspace folder.
2. `manage_pipeline(action="create_or_update", name="northgate_sdp_reference",
   catalog="vcr_serverless_catalog", schema="pipeline_ref",
   workspace_file_paths=[bronze.sql, silver.sql, gold.sql], start_run=True, full_refresh=True)`.

**Option B - UI:** Workspace → New → Lakeflow Declarative Pipeline → serverless →
add the three SQL files as source → set default catalog `vcr_serverless_catalog`,
schema `pipeline_ref` → **Run (full refresh)**.

---

## Expected results (full refresh, serverless)

| Layer | Table | Rows | Check |
|-------|-------|-----:|-------|
| bronze | `bronze_customers` / `bronze_products` / `bronze_orders` | 81 / 37 / 2261 | = raw row counts (all dirt retained) |
| silver | `silver_customers` | **64** | 81 raw − 17 dirty (6 invalid region + 4 TEST segment + 5 test-named + 2 null id) |
| silver | `silver_products`  | **34** | 37 raw − 3 (null id / list_price ≤ 0) |
| silver | `silver_orders`    | **2200** | 2261 raw − 61 seeded bad rows (15 dup + 8+7 null FK + 12 qty + 10 discount + 9 future) |
| gold | `gold_customer_sales_summary` | 64 | one per valid customer |
| gold | `gold_product_performance` | 34 | one per valid product |
| gold | `gold_rep_performance` | 7 | one per account manager |
| gold | `gold_at_risk_customers` | 9 | no order in last 30 days |

Silver products and orders match the clean reference counts exactly (34 products,
2,200 orders). Silver customers come out at **64 - six fewer than the 70 clean
customers** - because the invalid-region rule drops 6 dimension rows (ids 3, 11, 19, 27,
38, 52). That is not a miscount: it is exactly the orphaned-facts teaching point below,
and it is why customer-level gold is lower than product-level gold.

### Cross-check vs the independent clean tables - and a key teaching point
Rolling the gold layer back up and comparing to totals computed directly from the clean
`shared_data` tables:

- **`gold_product_performance` matches the clean truth** - £871,821.82 revenue over 2,200
  lines (vs £871,821.43; the few-pence delta is per-line rounding of `revenue` in silver).
  No *real* product was corrupted, so every order line joins to a product.
- **`gold_customer_sales_summary` is intentionally lower** - 1,998 lines, £793,959.93.
  The missing **202 lines / £77,861.81** belong to the **6 customers (ids 3, 11, 19, 27,
  38, 52) whose `region` was corrupted** in the raw feed. Silver correctly drops those
  customer rows, so the inner join in customer/rep gold legitimately excludes their
  (otherwise clean) orders.

This is the data-modelling lesson to draw out in the lab: **dropping a dimension row
because of one bad attribute orphans its facts.** It is correct behaviour for the brief's
"drop invalid region" rule, but it shows why teams often *quarantine or repair* a
dimension (e.g. coalesce region to `'Unknown'`) instead of dropping it outright.

---

## Cleanup
```sql
DROP SCHEMA IF EXISTS vcr_serverless_catalog.pipeline_ref CASCADE;
```
(and delete the `northgate_sdp_reference` pipeline from the Pipelines UI).
