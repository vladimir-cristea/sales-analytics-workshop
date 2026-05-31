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
| `comparison_space_definition.json` | Minimal space (same 5 tables **+ the `sales_metrics` metric view**, no instructions) used for the metric-view A/B. |
| `recreate_space.py` | Reference script to rebuild both spaces from the JSON. |

Recreate via MCP (preferred): `manage_genie(action="create_or_update", serialized_space=<file contents>)`.
Gotchas when editing the JSON: tables must be **sorted by identifier**, `column_configs`
**sorted by column_name**, and `instructions.text_instructions` must contain **at most one item**.

## The two spaces built

| Space | Sources | Use |
|-------|---------|-----|
| **Northgate Provisions — Sales Analytics** | 5 clean tables: `customers`, `products`, `orders`, `product_performance_summary`, `monthly_sales_summary` | The main workshop space. Curated with business context. |
| **Northgate Provisions — Metric View Comparison** | Same 5 tables **+ `sales_metrics`** (governed metric view), no instructions | Isolates what the metric view changes (Practical step 4). |

> `gold_customer_scorecard` is intentionally **not** in either space — that table belongs to
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

## Metric-view comparison (step 4) — the headline demo

Question (identical both times): **"What is the average profit margin by segment?"**
Ground-truth governed answer (direct SQL, ratio-of-sums): Independent 20.66%, Regional 20.52%,
National Group 20.18%.

### (a) WITHOUT the metric view — base tables, naive Genie
```sql
SELECT c.segment, AVG(p.profit_margin_pct) AS avg_profit_margin_pct
FROM product_performance_summary p
JOIN orders o ON p.product_id = o.product_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.segment
```
Result — **average of per-product ratios** (statistically wrong / inconsistent):

| Segment | margin % |
|---|---|
| **National Group** | **20.70** ← looks most profitable |
| Regional | 20.42 |
| Independent | 20.32 |

### (b) WITH `sales_metrics` added as a source — governed metric view
Genie generated a native `MEASURE()` query against the metric view:
```sql
SELECT `Segment`, try_divide(100 * MEASURE(`Total Profit`), MEASURE(`Total Revenue`)) AS margin_pct
FROM vcr_serverless_catalog.shared_data.sales_metrics
GROUP BY ALL ORDER BY margin_pct DESC
```
Result — **ratio of sums** (correct, matches ground truth):

| Segment | margin % |
|---|---|
| **Independent** | **20.66** ← actually most profitable |
| Regional | 20.52 |
| National Group | 20.18 ← actually **least** profitable |

### Why it matters
The **ranking flips**. Naive avg-of-ratios makes National Group look like the best-margin
segment; the governed metric view shows it is the **worst**. A wholesaler acting on the naive
number would chase exactly the wrong segment. The metric view is a single governed definition
reused identically by Genie, dashboards and SQL — and Genie consumes it natively via `MEASURE()`.

> Nuance worth mentioning: with strong written instructions, Genie *can* compute ratio-of-sums
> on the base tables too — but that depends on prompt phrasing and model choice. The metric view
> makes the correct calculation **deterministic and governed**, not a matter of luck.

---

## Entitlements & entry points

- **Genie spaces + Conversation API:** GA, fully working on this workspace (verified by every test above).
- **Agent-style multi-step reasoning:** functionally working (the Scotland compound question).
- **Named preview toggles** (Genie Agent mode, Genie Code) and the **Databricks One** business-user
  entry point: confirm in the workspace UI (Settings → Previews, and open the space in Databricks One).
  See the note in the team handover — these need a signed-in browser / workspace admin to verify.
