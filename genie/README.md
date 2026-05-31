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
| `base_only_space_definition.json` | **WITHOUT** arm: pre-aggregated SUMMARY tables only (`monthly_sales_summary`, `product_performance_summary`, `products`) — no `orders`/`customers`, no metric view. |
| `comparison_space_definition.json` | **WITH** arm: the governed `sales_metrics` metric view **only**. |
| `recreate_space.py` | Reference script to rebuild the spaces from the JSON. |

**Why these exact source sets (important — this is what makes the demo reproducible):** the
WITHOUT space deliberately has **no row-level table** (no `orders`/`customers`), so Genie has
**no `COUNT(DISTINCT)` path** and is forced down the naive `SUM(monthly_sales_summary.active_customers)`
route → the impossible overcount. The WITH space has **only** the metric view, so Genie **must** use
`MEASURE()` → the governed answer. (An earlier design that left `orders`+`customers` in the WITHOUT
space did **not** reproduce: Genie just counted distinct off `orders` and got the right answer,
collapsing the contrast. Thanks QA.)

Recreate via MCP (preferred): `manage_genie(action="create_or_update", serialized_space=<file contents>)`.
Gotchas when editing the JSON: tables must be **sorted by identifier**, `column_configs`
**sorted by column_name**, and `instructions.text_instructions` must contain **at most one item**.

## The three spaces built

| Space | Sources | Use |
|-------|---------|-----|
| **Northgate Provisions — Sales Analytics** | 5 clean tables: `customers`, `products`, `orders`, `product_performance_summary`, `monthly_sales_summary` | The main workshop space (Parts 1–6). Curated with business context. |
| **Northgate Provisions — Base Only (no context)** | Summary tables only: `monthly_sales_summary`, `product_performance_summary`, `products` | **WITHOUT** arm of the metric-view A/B (naive Genie, no distinct-count path). |
| **Northgate Provisions — Metric View Comparison** | `sales_metrics` (governed metric view) **only** | **WITH** arm of the A/B (Part 7). |

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

Tested live on the controlled pair (Base Only = summary tables only; Metric View Comparison =
metric view only). **#1 is the headline** (the naive answer is provably impossible). #2 (margin
flip) is included as a concept but is **model-dependent** — see the note at the end.

> Re-tested 2026-05-31 after the QA finding: with the WITHOUT space carrying **no** `orders`/`customers`,
> the overcount now reproduces **deterministically** (verified via the Conversation API; structurally
> forced, so UI behaves identically — QA to re-confirm in the Agent-mode UI).

### #1 (HEADLINE) — "How many active customers in the last 90 days, by segment?"
Same prompt on both spaces.

**WITHOUT** the metric view (summary tables only) — Genie's only path is `monthly_sales_summary.active_customers`, which it **SUMs** across months:
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

> **Prompt note:** the exact wording *"active customers (90d) by segment"* returns the clean **41 / 17 / 12**
> (the measure self-windows). The phrasing *"…in the last 90 days…"* makes Genie add a redundant
> `Order Month` window filter on top of the measure; because `Order Month` is month-truncated, one
> National Group customer (only recent order in early March) falls outside the window → **11** instead of 12.
> Either way the WITH answer is ~correct and nowhere near the naive 69/32/20. Recommend the slide use
> *"active customers (90d) by segment"* for a clean 41/17/12.

### #2 (secondary, MODEL-DEPENDENT) — "What is the average profit margin by segment?"
Ground-truth governed (ratio-of-sums): Independent 20.66%, Regional 20.52%, National Group 20.18%.
The **governed/WITH** answer is reliable (metric view → `MEASURE()`). The **naive/WITHOUT** answer is
**not deterministic** and is **not** reproduced on the summary-only Base Only space (which has no
per-product-ratio × segment join path). It was observed once on the original all-tables bare space,
where Genie joined `product_performance_summary` to `customers` and did `AVG(profit_margin_pct)`:

| Segment | naive avg-of-ratios (observed once) | governed ratio-of-sums (reliable) |
|---|---|---|
| National Group | 20.70 ← *looks* best | **20.18 ← actually worst** |
| Regional | 20.42 | 20.52 |
| Independent | 20.32 | **20.66 ← actually best** |

When it does occur the **ranking flips** (NG best→worst) — a nice "even subtle ratios bite" point —
but treat it as an *optional* illustration, not the guaranteed live beat. **#1 is the reliable headline.**

### Why it matters
A metric view is one governed definition reused identically by Genie, dashboards and SQL, consumed
natively via `MEASURE()`. WITHOUT it, naive NL→SQL **double-counts** a pre-aggregated distinct measure
(#1) — and the error is large enough (69 > 41 customers that exist) to be **obviously, demonstrably wrong**.

> Nuance: with strong written instructions Genie *can* get the base-table calc right too, but that
> depends on prompt phrasing and model choice. The metric view makes it **deterministic and governed**,
> not a matter of luck.

---

## Entitlements & entry points (verified live in the UI)

**Entitlements — both confirmed ENABLED:**
- **Genie Agent mode:** ✅ ON. The Genie space's question box has an **Agent | Chat** toggle with
  **Agent selected by default**, plus a **Deep Research** chat type (`ct=DEEP_RESEARCH`). The
  multi-step Scotland question above runs in this mode.
- **Genie Code:** ✅ ENABLED. A **Genie Code** button sits in the workspace top nav on every page →
  opens *"Genie Code — Run multi-step data and AI tasks"* (agent input with `@` for objects, `/` for
  commands; its own Agent selector). This is the assistant used for "Genie Code assistance" in Practical 2.
- **Genie spaces + Conversation API:** GA, fully working (every test above ran clean).

> There is no separate **Settings → Previews** tab visible to a workspace (non-account) admin here;
> entitlement was confirmed directly from the live product surfaces, which is stronger than a toggle.

**Two entry points — both confirmed:**

| Surface | Who | Exact navigation |
|---------|-----|------------------|
| **Genie space (builder)** | Builders / analysts | Workspace left nav → **Genie Spaces** → open *Northgate Provisions — Sales Analytics*. URL `/genie/rooms/01f15d2bcc96149bbe3494375ce128a2`. Full chrome: **Configure / Monitor / Benchmark** tabs, Agent\|Chat toggle, Share. |
| **Genie in Databricks One** | Business users | Top nav → **Switch apps** (grid icon) → **Genie — Business insights from data and AI** → lands on **Databricks One** (`/one`): *"What would you like to know?"* ask box + Home / Dashboards / Genie Spaces / Apps rail. Click the space card → opens `/genie/rooms/<id>?isDbOne=true` with simplified business chrome (no SQL editor). |

> Both surfaces query the *same* space and the *same* governed tables/metric view — same space, two
> doors. Builders enter via Genie Spaces in the workspace; business users via Databricks One → Genie.
