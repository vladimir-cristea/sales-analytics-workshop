# genie/ - Practical 1: Genie

Natural-language analytics over the clean curated tables for Northgate Provisions Co. This is
the first practical: ask business questions in plain English and Genie writes and runs the SQL.
Reference "today" = **2026-05-31**. Currency = **GBP (£)**.

## Files

| File | Purpose |
|------|---------|
| `space_definition.json` | Full definition of the curated space (5 tables + business context, joins, measures, synonyms, example questions). Reproducible. |
| `base_only_space_definition.json` | "Without" arm of the metric-view comparison: pre-aggregated summary tables only, no metric view. |
| `comparison_space_definition.json` | "With" arm: the governed `sales_metrics` metric view only. |
| `recreate_space.py` | Rebuild the spaces from the JSON. |

Recreate via the Databricks MCP (preferred):
`manage_genie(action="create_or_update", serialized_space=<file contents>)`. When editing the
JSON: tables must be sorted by identifier, `column_configs` sorted by column_name, and
`instructions.text_instructions` must contain at most one item.

## The three spaces

| Space | Sources | Use |
|-------|---------|-----|
| **Northgate Provisions - Sales Analytics** | the 5 clean tables (`customers`, `products`, `orders`, `product_performance_summary`, `monthly_sales_summary`) | the main workshop space, curated with business context |
| **Northgate Provisions - Base Only (no context)** | summary tables only | the "without" arm of the metric-view comparison |
| **Northgate Provisions - Metric View Comparison** | the `sales_metrics` metric view only | the "with" arm |

> `gold_customer_scorecard` is intentionally **not** in any space - that table belongs to the
> Lakebase practical.

## Business context (the curation that makes Genie reliable)

The curated space encodes the context that turns Genie into a trustworthy tool:

- **Grain & currency:** `orders` is at order-line grain; all money is GBP (£); "today" = 2026-05-31.
- **Discount scale:** `discount_pct` is a whole-number percentage (20 = 20%). Net line revenue =
  `quantity * unit_price * (1 - discount_pct/100)`; net line profit = net revenue − `quantity * cost`.
- **Vocabulary / synonyms:** outlet / venue / account / site = a `customers` row; rep / account
  manager = `account_manager`; SKU / item / line = `products`.
- **Business definitions:** key account, at-risk customer, underperforming customer,
  discount-heavy buyer, growing-fastest - each defined once so Genie answers consistently.
- Plus join specs, measures (Net Revenue, Net Profit), column descriptions and example questions.

## Two entry points

- **Genie space (builder / analyst):** workspace left nav → **Genie Spaces** → open the space.
  Full builder chrome.
- **Genie in Databricks One (business user):** top nav → **Switch apps** → **Genie** → open the
  same space. A clean ask-and-answer view over the same governed data.

## The metric-view comparison

Two small spaces show why a governed metric matters. Ask the same question - for example
*"active customers (90d) by segment"* - on the Base Only space and the Metric View Comparison
space:

- **Without** the metric view, Genie can only stitch together the pre-aggregated summary
  tables and over-counts (it sums monthly active-customer counts, double-counting repeat
  orderers), giving impossible totals.
- **With** `sales_metrics`, Genie uses a native `MEASURE()` over the governed distinct-count
  and returns a count that can actually be true.

The lesson: a metric view pins a business definition in one place, consumed identically by
Genie, dashboards and SQL. Genie is non-deterministic, so exact figures vary from run to run -
which is itself the argument for governing the definition.
