# genie/ — Practical 1: Genie

Natural-language analytics over the **clean curated tables** for Northgate Provisions Co.
This is the first practical and the biggest "wow": business users ask questions in plain
English and Genie writes and runs the SQL.

Everything here was **built and tested live** against
`vcr_serverless_catalog.shared_data`. Reference "today" = **2026-05-31**. Currency = **GBP (£)**.

## Files

| File | Purpose |
|------|---------|
| `space_definition.json` | Full serialized definition of the curated space (5 tables + instructions, joins, measures, synonyms, 6 certified SQLs). Reproducible. |
| `comparison_space_definition.json` | Same 5 tables **+ the `sales_metrics` metric view**, no instructions — the **WITH** arm of the metric-view A/B. |
| `base_only_space_definition.json` | The 5 base tables, no instructions, no metric view — the **WITHOUT** arm of the A/B (naive Genie). |
| `recreate_space.py` | Reference script to rebuild the spaces from the JSON. |

The WITHOUT/WITH pair (`base_only` vs `comparison`) differ by **exactly one thing — the metric view** — so any divergence is attributable to it alone.

Recreate via MCP (preferred): `manage_genie(action="create_or_update", serialized_space=<file contents>)`.
Gotchas when editing the JSON: tables must be **sorted by identifier**, `column_configs`
**sorted by column_name**, and `instructions.text_instructions` must contain **at most one item**.

## The three spaces built

| Space | Sources | Use |
|-------|---------|-----|
| **Northgate Provisions — Sales Analytics** | 5 clean tables: `customers`, `products`, `orders`, `product_performance_summary`, `monthly_sales_summary` | The main workshop space. Curated with business context. |
| **Northgate Provisions — Base Only (no context)** | Same 5 tables, no instructions, no metric view | **WITHOUT** arm of the metric-view A/B (naive Genie). |
| **Northgate Provisions — Metric View Comparison** | Same 5 tables **+ `sales_metrics`** (governed metric view), no instructions | **WITH** arm of the A/B (Practical step 4). |

> `gold_customer_scorecard` is intentionally **not** in any space — that table belongs to
> the Lakebase practical.

---

## Business context added (the curation that makes Genie reliable)

**Text instructions** (single block):
- **Grain & currency:** `orders` is at order-LINE grain (one row per product per order).
  All money is GBP (£); never label with `$`/USD. Reference "today" = 2026-05-31.
- **Discount scale (the critical fix):** `discount_pct` is a **whole-number percentage 0–20**
  (20 = 20%), **not** a fraction. Net line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
  Net line profit = net revenue − `quantity * cost`. "Revenue"/"sales"/"turnover" = **net**.
- **Vocabulary / synonyms:** outlet / venue / account / site / pub / café = a `customers` row;
  rep / account manager / AM = `account_manager`; SKU / item / line = `products`.
- **Table usage:** `product_performance_summary` and `monthly_sales_summary` are pre-aggregated —
  don't re-join to `orders`. Use `monthly_sales_summary` for trends.

**Business definitions** (used verbatim in certified SQL):

| Term | Definition |
|------|------------|
| **Key account** | `National Group` segment **OR** total net revenue in the top 10% of all customers |
| **At-risk customer** | active customer whose most recent order is **> 45 days** before 2026-05-31 |
| **Underperforming customer** | total net revenue in the **bottom quartile within its own segment** |
| **Discount-heavy buyer** | average `discount_pct` across order lines **≥ 11.5%** |
| **Growing fastest** | net revenue last 3 months vs prior 3 months; growth = (recent − prior)/prior |

**Also configured:** join specs (`orders`→`customers`, `orders`→`products`, many-to-one),
measures (Net Revenue, Net Profit), an expression (Net line revenue), column descriptions &
entity matching, and **6 certified example SQLs** (one per business question).

---

## Tested questions — before vs after business context

All run live via the Conversation API. "Before" = bare space (tables only, no context).
"After" = curated space.

| Question | Before (no context) | After (curated) |
|----------|---------------------|-----------------|
| **Top 10 customers by revenue** | ❌ **All revenue negative** — Genie used `(1 - discount_pct)` without `/100`, so 20% → `(1-20) = -19`. Top "customer" showed −£87k. | ✅ Positive net revenue. Willow Eatery **£21,817.96**, Bridge Street Bistro £19,423.34, Corner Eatery £18,175.56 … |
| **Customers at risk of churning** | ❌ **0 rows** — no definition, guessed "no order in 12 months" (nobody qualifies). | ✅ **4 outlets** (recency > 45d): The Anchor Eatery (71d), Market Square Bistro (50d), Ashfield Deli (47d), Station Grill (46d). |
| **Discount-heavy buyers** | ⚠️ Ran but no definition of "discount-heavy" (returned all 70 ranked). | ✅ **9 outlets** with avg discount ≥ 11.5%: Royal Oak Diner 12.50%, Harbour Grill 12.00%, Harbour Pantry 11.95% … |
| **Key accounts** | (not meaningful without a definition) | ✅ **19 accounts** = National Group ∪ top-10% revenue. |
| **Underperforming customers** | (not meaningful without a definition) | ✅ Bottom revenue quartile **within each segment**. |
| **Sales revenue trend (12 months)** | ✅ OK, but labelled amounts as `$`. | ✅ Same trend, GBP. Low £35.1k (Feb-26) → high £61.0k (May-26); rising recent quarter. |

**Agent-mode multi-step reasoning (step 3)** — compound question:
*"Which product categories are growing fastest in Scotland, and which account managers cover
the most customers there so they can push those categories?"*
→ Genie chained **two** analyses in one query (category growth + AM coverage, UNION ALL):
- Fastest-growing in Scotland: **Frozen +85.0%**, Alcohol +25.7% (Chilled −16.8%, Ambient −28.8%, Beverages −49.7%).
- AM coverage in Scotland: **Priya Sharma 4**, Yusuf Khan 2, Sophie Laurent 1, Marcus Reid 1.
- Takeaway Genie surfaces: push **Frozen** in Scotland; **Priya Sharma** has the widest coverage to drive it.

---

## Metric-view comparison (step 4) — WITH vs WITHOUT `sales_metrics`

Two metrics were tested live on the controlled pair (Base Only vs Metric View Comparison —
identical except for the metric view). Both diverge; **#1 is the headline** (the naive answer
is provably impossible), **#2 is the business-conclusion flip**.

### #1 (HEADLINE) — "How many active customers in the last 90 days, by segment?"
Same prompt both spaces.

**WITHOUT** the metric view — Genie reaches for `monthly_sales_summary.active_customers` and **SUMs** it across months:
```sql
SELECT segment, SUM(active_customers) AS active_customers_last_90_days
FROM monthly_sales_summary
WHERE month BETWEEN date_sub(current_date,89) AND current_date
GROUP BY segment ORDER BY 2 DESC
```
| Segment | naive answer | total customers in segment |
|---|---|---|
| Independent | **69** | 41 |
| Regional | **32** | 17 |
| National Group | **20** | 12 |

Every number is **impossible** — you cannot have 69 active Independent customers when only 41
exist. Monthly active-customer counts are summed, so a customer active in 3 months is counted 3×.

**WITH** `sales_metrics` — Genie writes a native `MEASURE()` over the governed distinct-count:
```sql
SELECT `Segment`, MEASURE(`Active Customers (90d)`) AS active_customers_90d
FROM vcr_serverless_catalog.shared_data.sales_metrics
GROUP BY ALL ORDER BY 2 DESC
```
| Segment | governed answer |
|---|---|
| Independent | **41** |
| Regional | **17** |
| National Group | **12** |

Correct distinct counts (`Active Customers (90d)` = `COUNT(DISTINCT customer_id) FILTER (WHERE order_date >= current_date()-90)`), matched against direct SQL.

### #2 — "What is the average profit margin by segment?"
Ground-truth governed answer (ratio-of-sums): Independent 20.66%, Regional 20.52%, National Group 20.18%.

**WITHOUT** (base tables, naive `AVG(profit_margin_pct)` = average of per-product ratios):

| Segment | margin % |
|---|---|
| **National Group** | **20.70** ← looks most profitable |
| Regional | 20.42 |
| Independent | 20.32 |

**WITH** `sales_metrics` (`try_divide(100*MEASURE(Total Profit), MEASURE(Total Revenue))` = ratio of sums):

| Segment | margin % |
|---|---|
| **Independent** | **20.66** ← actually most profitable |
| Regional | 20.52 |
| National Group | 20.18 ← actually **least** profitable |

The **ranking flips**: naive avg-of-ratios makes National Group look best; the governed view shows
it is the **worst**. A wholesaler acting on the naive number would chase the wrong segment. (Absolute
gap is small because the data is homogeneous — the *flip* is the teaching point.)

### Why it matters
A metric view is one governed definition reused identically by Genie, dashboards and SQL, and Genie
consumes it natively via `MEASURE()`. WITHOUT it, naive NL→SQL either **double-counts** (#1) or
**averages ratios** (#2) — and in #1 the error is large enough to be obviously wrong.

> Nuance: with strong written instructions Genie *can* get the base-table calc right too, but that
> depends on prompt phrasing and model choice. The metric view makes it **deterministic and governed**,
> not a matter of luck.

---

## Entitlements & entry points

- **Genie spaces + Conversation API:** GA, fully working on this workspace (verified by every test above).
- **Agent-style multi-step reasoning:** functionally working (the Scotland compound question).
- **Named preview toggles** (Genie Agent mode, Genie Code): confirm in the workspace UI under
  **Settings → Previews** — not exposed by any public API. Needs a signed-in browser / workspace admin.

**Two entry points** (documented navigation; final label check pending UI sign-in):

| Surface | Who | How to reach it |
|---------|-----|-----------------|
| **Genie space (builder)** | Builders / analysts | Workspace left nav → **Genie** → open *Northgate Provisions — Sales Analytics*. Direct URL: `/genie/rooms/<space_id>` (this space: `01f15d2bcc96149bbe3494375ce128a2`). Full builder chrome: edit Instructions, SQL examples, Monitoring. |
| **Genie in Databricks One** | Business users | Open **Databricks One** (the simplified business-user home) → **Genie** → the same space, shared with the participant group. No SQL/builder chrome — just ask-and-answer. |

> Both surfaces query the *same* space and the *same* governed tables/metric view; only the
> chrome differs. The space is confirmed working via the API; the visual two-surface walk-through
> still needs a signed-in browser.
