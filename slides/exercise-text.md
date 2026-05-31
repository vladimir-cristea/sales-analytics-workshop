# Workshop exercise text

Hands-on exercise copy for the three practicals, ready to paste into the slide deck.
Written for software engineers who are new to Databricks. The scenario throughout is
**Northgate Provisions Co.**, a fictional B2B food and beverage wholesaler supplying
outlets (pubs, cafes, delis, convenience stores) across the UK.

**Shared facts you can rely on**

- Catalog `vcr_serverless_catalog`, schema `shared_data` (the catalog name may differ on
  your workspace - the facilitator will tell you).
- Clean curated tables: `customers`, `products`, `orders`, plus pre-aggregated
  `product_performance_summary` and `monthly_sales_summary`.
- Governed metric view: `sales_metrics`.
- Raw, deliberately messy JSON lives in a volume at
  `/Volumes/vcr_serverless_catalog/shared_data/data/raw/`.
- Your personal scratch schema is `ws_<your-name>` (created for you by the setup).
- Segments: National Group, Regional, Independent. Categories: Beverages, Ambient,
  Chilled, Frozen, Alcohol. Everything is in GBP. "Today" for this dataset is
  **31 May 2026**.

> _Facilitator note: the figures quoted throughout were tested live on the build workspace
> with this exact dataset. They should reproduce as-is; if the data is ever regenerated they
> may shift slightly, so confirm the headline numbers before the session. The teaching points
> (the ranking flips, the impossible counts, the orphaned facts) hold regardless._

---

## Practical 1 - Ask your data anything, with Genie

Genie lets anyone query data in plain English. No SQL, no BI tool, no waiting on a data
team. You are the new analyst at Northgate Provisions and your job is to understand the
business by simply asking.

**Your Task:** open the **"Northgate Provisions - Sales Analytics"** Genie space and work
through the parts below. You are not writing SQL. You are having a conversation. Parts 1 to 6
are the guided tour; **Part 7 (metric views) is the must-do highlight**, and there is an
optional Bonus at the end.

> _Facilitator note: this practical uses three Genie spaces - the curated "Northgate
> Provisions - Sales Analytics" (Parts 1-6) and two A/B spaces, "Northgate Provisions - Base
> Only (no context)" and "Northgate Provisions - Metric View Comparison" (Parts 4 and 7).
> Have all three open before the session (search by name, or share the direct links)._

### Part 1: Get your bearings

1. Open the Genie space and read the suggested questions it offers.
2. Ask: **"How many customers, products and orders do we have?"**
3. Click into the answer and open the SQL Genie generated. You did not write it, but it
   is right there if you want to check the working.

💡 Every answer is backed by real, governed SQL over Unity Catalog tables. Genie is not
guessing; it is generating queries you could have written yourself.

### Part 2: Answer real business questions

Ask these one at a time. Read each answer before moving on. Sample answers from the dataset
are shown so you can sanity-check yours.

1. **"Who are our top 10 customers by revenue?"** (Willow Eatery tops it at ~£21,818,
   then Bridge Street Bistro ~£19,423.)
2. **"Which customers are at risk of churning?"** (4 outlets that have gone quiet: The
   Anchor Eatery, Market Square Bistro, Ashfield Deli, Station Grill.)
3. **"Which outlets are discount-heavy buyers?"** (9 outlets averaging 11.5%+ discount,
   led by The Royal Oak Diner at 12.5%.)
4. **"Who are our key accounts?"** (19 of them: National Group outlets plus anyone in the
   top 10% by revenue.)
5. **"How has total sales revenue trended over the last 12 months?"** (Rising into the
   recent quarter, from a ~£35k low to a ~£61k high.)
6. **"Which customers are underperforming?"** (The bottom revenue quartile within each
   segment.)

💡 Use the AI Assistant or the "Explain" option if an answer surprises you. Ask Genie a
follow-up like "why?" or "show me the breakdown" and it keeps the context.

### Part 3: Have a conversation

Genie remembers what you just asked. Build on a previous answer instead of starting over.

1. Ask: **"Which region has the highest revenue?"**
2. Then follow up: **"And which segment within that region?"**
3. Then: **"Show me the top 5 customers there."**

Notice you never repeated the region. That is conversational analytics.

### Part 4: Why business context matters

Out of the box Genie knows your tables. It does not know what *your team means* by "at-risk",
or quirks like "discount is stored as a percentage". The curated "Sales Analytics" space you
have been using already has that context baked in - which is exactly why your answers in
Parts 1 to 3 were sensible. To feel the difference, compare it against the no-context space.

1. **See it without context.** On **"Northgate Provisions - Base Only (no context)"**, ask
   **"Which customers are at risk of churning?"** With no definition of "at-risk", Genie has
   nothing to anchor on and typically returns nothing useful (often 0 rows).
2. **See it with context.** Ask the same question on the curated **"Northgate Provisions -
   Sales Analytics"** space. Because someone defined "at-risk" (no order in the last 45 days)
   in the semantic layer, you get the 4 quiet outlets. The definition lives in the space, not
   in each person's head.
3. **The other kind of context: expression rules.** The curated space also encodes that
   revenue must apply the discount as `discount_pct / 100`. Without that rule, Genie can read
   `discount_pct = 20` as "subtract 20" instead of "subtract 20%", and revenue comes back
   wildly wrong (often **negative**) - try **"Who are our top 10 customers by revenue?"** on
   each space and compare.

💡 This is how a Genie space goes from "clever demo" to "trusted internal tool": curated
definitions, synonyms, expression rules and sample questions that encode how your business
actually talks. Everything in this part is pre-built on the two spaces, so there is nothing
to edit - just compare the answers.

### Part 5: Agent mode - let Genie reason in steps

A simple question becomes one query. A *business* question often needs several steps:
filter, aggregate, compare, then conclude. Agent mode lets Genie plan and chain those
steps.

1. Check the question box is set to **Agent** (the toggle reads **Agent | Chat**, and Agent
   is the default). There is also a "Deep Research" mode if you want to go further.
2. Ask a multi-step question, for example:
   **"Which product categories are growing fastest in Scotland, and which account managers
   cover the most customers there so they can push those categories?"**
3. Watch Genie break the problem down, run more than one analysis, and synthesise an answer.
   Expect something like: *Frozen is growing fastest (+85%), then Alcohol (+26%); Priya
   Sharma covers the most Scottish outlets, so she should lead the push.*

💡 Notice the difference from Part 2: this question cannot be answered by a single
`GROUP BY`. It needs a growth analysis, a coverage analysis, and then a recommendation that
ties them together. Agent mode is doing analyst-style reasoning, not just translation.

### Part 6: The two front doors to Genie

The same space is reachable from two surfaces, aimed at two audiences.

1. **Genie space (builder / analyst surface):** what you have been using. Left sidebar →
   **Genie Spaces** → open **"Northgate Provisions - Sales Analytics"**. Full chrome:
   Configure / Monitor / Benchmark tabs, the Agent | Chat toggle, Share - where a data team
   curates instructions, sample questions and trusted assets.
2. **Genie in Databricks One (business-user surface):** top nav → **Switch apps** (the grid
   icon) → **"Genie - Business insights from data and AI"**. This opens **Databricks One**
   (a clean home with an "What would you like to know?" Ask box and Home / Dashboards /
   Genie Spaces / Apps in the left rail). Click the **"Northgate Provisions - Sales
   Analytics"** card to chat. Same space, same governed data, no SQL editor or builder
   chrome - the view a non-technical colleague gets.

Same space, two doors: builders enter via Genie Spaces in the workspace; business users
enter via Databricks One.

### Part 7: Metric views - one number, one source of truth (must-do)

This is the most important part of the practical. We are going to see *why* governed metrics
matter, using two purpose-built spaces side by side:

- **"Northgate Provisions - Base Only (no context)"** - the summary tables, no governed
  metric. The *without* arm.
- **"Northgate Provisions - Metric View Comparison"** - the governed `sales_metrics` metric
  view. The *with* arm.

(These are separate from the curated "Sales Analytics" space you used in Parts 1-6, which is
already governed and would not visibly "break".)

**Step 1 - ask the without-metric space and get an impossible answer.**

1. Open **"Northgate Provisions - Base Only (no context)"** and ask exactly:
   **"active customers (90d) by segment"**.
2. Genie returns badly inflated counts - something like **Independent 69, Regional 32,
   National Group 20**, though you may see even larger numbers (e.g. 131/61/38) on another
   run. Either way it is *impossible*: every figure far exceeds the true segment totals of
   **41 / 17 / 12**. Open the SQL: this space has only the pre-aggregated summary tables, no
   customer-level table, so Genie can only **sum monthly active-customer counts** - it has no
   way to count distinct customers, and double-counts anyone who ordered in more than one
   month (and how many months it sums varies from run to run, which is why the exact figure
   wanders).

**Step 2 - ask the with-metric space and get the truth.**

3. Open **"Northgate Provisions - Metric View Comparison"** and ask the same thing:
   **"active customers (90d) by segment"**.
4. Now Genie uses the governed `Active Customers (90d)` measure (a proper distinct count) and
   returns **Independent 41, Regional 17, National Group 12** - numbers that can actually be
   true. Same question, two spaces, one of them simply cannot be wrong.

💡 Use that exact phrasing, **"active customers (90d) by segment"**. If you instead say
"...in the last 90 days...", the governed side may answer National Group **11** (a
month-grain edge effect) rather than 12. The teaching point is identical; the round numbers
are just cleaner with the short phrasing.

⚠️ The deeper problem: with no governed measure, the *definition* of "active customer" lives
in whatever SQL Genie improvises - and it will even shift with how you phrase the question
(ask for "distinct" customers and the summary-only space still sums, just over a different
window). When the definition lives in the query, every asker can get a different number. A
metric view pins it in **one** governed place, so `sales_metrics` returns the same answer
every time - to Genie, to dashboards, to notebooks. In SQL you would pull a measure out with
`MEASURE("Active Customers (90d)")`; Genie does that for you under the hood.

💡 Optional aside - it is not just counts. Ratios are governed too: `Profit Margin %` is
defined once as `SUM(profit)/SUM(revenue)` (a ratio of sums), so it cannot drift into the
naive average-of-per-line-ratios that quietly mis-ranks segments. Same principle, subtler
symptom.

### Bonus (if you finish early)

- **Build your own metric.** Create a metric view that adds a measure of your own (for
  example *average order value* = `SUM(revenue) / COUNT(DISTINCT order_id)`), add it as a
  source, and ask Genie to use it.
- **Conversation API.** Genie is also callable from code, so you can embed it in an app.
  Note: this needs a little CLI/token setup, so treat it as a stretch goal. Ask the
  facilitator for the endpoint snippet if you want to try it.

---

## Practical 2 - Build a data pipeline from scratch, with Genie Code

The clean tables you queried in Practical 1 did not arrive clean. Somebody had to ingest
raw data, throw out the rubbish, and shape it into something trustworthy. That somebody is
now you.

You are going to build a **medallion pipeline** (bronze → silver → gold) on the *raw,
messy* Northgate data, using **Genie Code** to help you write it. There is no fill-in-the
blanks file. You get the brief and the rules; *you* decide how to prompt your way there.

**Time to build!**

The raw, deliberately dirty JSON is in a volume:

```
/Volumes/vcr_serverless_catalog/shared_data/data/raw/customers/
/Volumes/vcr_serverless_catalog/shared_data/data/raw/products/
/Volumes/vcr_serverless_catalog/shared_data/data/raw/orders/
```

Build your pipeline **into your own schema** (`ws_<your-name>`) so you do not clash with
anyone else. All three layers - bronze, silver and gold - are core; build all three. The
**Bonus** at the end is optional.

💡 You are not expected to remember Spark syntax. Open **Genie Code** (the button in the
workspace top nav - "Run multi-step data and AI tasks") and describe what you want in
English: *"create a streaming table that reads the JSON files in this volume path"*.
Iterate. Read what it gives you, run it, fix it.

### Part 1: Bronze - land the raw data, as-is

Create one bronze table per entity (`bronze_customers`, `bronze_products`,
`bronze_orders`) that simply reads the raw JSON from the volume. **Do not clean anything
yet.** Bronze is the faithful, unaltered copy of what landed.

💡 Ask Genie Code for an "Auto Loader streaming table" reading the volume path. A nice
touch is to stamp each row with where and when it landed (`_ingested_at`, `_source_file`).

⚠️ Three things that trip people up in a pipeline (let Genie Code hit them, then fix):
- A streaming table needs `FROM STREAM read_files(...)`. Plain `FROM read_files(...)` is a
  batch query and errors with *"Cannot create streaming table from batch query"*. The
  `STREAM` keyword is what makes it Auto Loader.
- Use `CREATE OR REFRESH STREAMING TABLE | MATERIALIZED VIEW`, not `CREATE OR REPLACE`
  (that is plain SQL and will not run in a pipeline).
- On dirty JSON, pin the column types with `schemaHints` (for example
  `'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2),
  discount_pct DECIMAL(5,2)'`). Without them, one garbage value can flip an inferred type.

You should land roughly **81 customers, 37 products, 2,261 orders** in bronze - more than
the clean counts, because the dirt is still in.

### Part 2: Silver - clean, validate and de-duplicate

Create one silver table per entity (`silver_customers`, `silver_products`,
`silver_orders`), cleaned and **kept normalised** (still one table per entity, no joins
yet). Enforce these data-quality rules - drop or quarantine anything that fails:

**customers**
- Drop rows with a null `customer_id`.
- Keep only valid UK regions (drop values like `EMEA`, `Atlantis`, `Unknown`, `MARS`,
  `n/a`, `Europe`).
- Drop `segment = 'TEST'`.
- Drop test outlets where `customer_name` looks like `%test%`.

**products**
- Drop rows with a null `product_id`.
- Drop rows where `list_price <= 0`.

**orders**
- Drop rows with a null `order_id`, `customer_id` or `product_id`.
- Drop `quantity <= 0`.
- Drop `discount_pct` outside 0-100.
- Drop future orders (`order_date` after today).
- **De-duplicate** on `order_id` (the raw data has exact duplicate order lines).

💡 Ask Genie Code to express these as pipeline **expectations**. The syntax is
`CONSTRAINT <name> EXPECT (<predicate>) ON VIOLATION DROP ROW`, declared in parentheses
right after the table name, before `AS SELECT`. That way the rules are declarative and the
pipeline reports how many rows each rule dropped.

💡 The customers and products rules are pure row filters, so those silver tables can stay
**streaming tables**. De-duplicating orders is different: picking one row per `order_id`
needs a window function over the whole table, which a streaming query cannot do. So
`silver_orders` is best built as a **materialized view**. If Genie Code's first attempt
errors on the de-dup, that is why - ask it to make that table a materialized view.

You should end up with roughly **64 customers, 34 products and 2,200 orders** in silver.
Products and orders match the clean reference exactly (34 and 2,200). Customers come out
**6 lower** than the 70 clean customers, because 6 rows had corrupted regions and were
dropped - you will see why that matters in Part 3. (So do not be alarmed that
`SELECT COUNT(*)` on the clean `customers` table shows 70: silver is meant to be lower.)

⚠️ Resist the urge to join here. Silver stays one-table-per-entity. Joining is gold's job
- it keeps each layer single-purpose and easy to debug.

### Part 3: Gold - join and aggregate into business metrics

Now bring the silver tables together and aggregate. Join `silver_orders` to
`silver_customers` and `silver_products` (you need `products.cost` for profit, and the
customer dimensions like region, segment and account manager for grouping). These gold
tables are usually best as **materialized views**. Build:

- **`gold_customer_sales_summary`** - per customer: revenue, profit, margin, units, first
  and last order date.
- **`gold_product_performance`** - per product: units sold, unique customers, revenue,
  profit, margin.
- **`gold_rep_performance`** - per account manager: revenue, profit, margin, average order
  value, number of customers.
- **`gold_at_risk_customers`** - customers with no order in the last 30 days (against the
  dataset's "today" of 2026-05-31). Outlets reorder roughly fortnightly, so 30 days is
  more than twice their normal cadence - a fair "gone quiet" signal. (This is a stricter
  30-day window than Practical 1's 45-day churn definition, so you will get **9** here, not
  the 4 from Genie - same idea, different threshold.)

Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
Line profit  = revenue - `quantity * cost`.

✅ **Did it work?** Numbers to check against: **34** products in `gold_product_performance`,
**7** account managers in `gold_rep_performance`, and **9** at-risk customers. Total product
revenue should be **about £871.8k** across 2,200 order lines - lining up with the clean
tables from Practical 1 (to the penny it depends on where you round, but it lands at
£871,821). Your top product by revenue should be **Prosecco 750ml x6 (£60,693.48)** and
your top account manager **Priya Sharma (£207,304.23)**.

💡 **Spot the subtlety.** Your per-product gold revenue lines up with the clean reference
(about £871.8k), but your per-*customer* gold revenue comes out lower (**£793,959.93**). Why?
Silver dropped 6 customers with corrupted region values, and dropping those dimension rows
orphaned their (perfectly good) **£77,861** of order lines from the customer join. That is
the classic trade-off between *dropping* a bad row and *quarantining or repairing* it -
well worth a thought for real pipelines.

### Bonus (if you finish early)

- **Schedule it.** Turn your pipeline into a Job and give it a schedule.
- **Add an expectation + alert.** Add a data-quality expectation that fails loudly, and
  wire an alert so someone is notified when bad data shows up.
- **Cross-sell table.** Build a gold table that, for each customer, recommends the most
  popular product in their segment that they have *not* yet bought.

💡 Use Genie Code throughout. The skill being practised is *describing intent and
reviewing the result*, not memorising APIs.

---

## Practical 3 - Serve analytics in milliseconds, with Lakebase

Practical 2 produced rich, heavy analytics. Brilliant for a report, far too slow to power
a live app that needs one customer's scorecard *right now*. **Lakebase** is managed
Postgres built into Databricks: you sync a gold table to it and get millisecond point
lookups, plus database superpowers like instant branching and point-in-time recovery.

The bootstrap built a heavy per-customer table, `gold_customer_scorecard` (rolling 12-month
revenue, RFM scores, at-risk flag, peer percentile ranks, cross-sell pick). Your facilitator
has already provisioned the Lakebase project **`workshop-scorecard`** (Postgres 17) and your
personal Postgres role. In this lab you will sync that scorecard into Postgres and put it to
work.

**Your Task:** work through the tiers below. Get the must-do done first, then go as far as
time allows. You will use the database **`databricks_postgres`** throughout.

> _Facilitator note: participants need no admin rights to self-sync. All six grants apply
> to the `workshop_participants` group **once** (no per-person work): 4 in Unity Catalog
> (USE CATALOG; USE SCHEMA + CREATE TABLE on the participant schemas; USE SCHEMA + SELECT on
> the source gold table) plus 2 in Lakebase (a Postgres role created with
> `identity_type=GROUP`, and `CAN_USE` on the `workshop-scorecard` database project). They
> are scripted in `lakebase/synced_table/facilitator_grants.sh`; run it before the session.
> `workshop_participants` must be an **account-level** group (Unity Catalog requires that)._

### Part 1: Sync the scorecard into Lakebase (must-do)

Create a **synced table** from your gold scorecard in Unity Catalog into Postgres. The
easiest way is Catalog Explorer: find your scorecard table → **Create → Synced table** →
target the `workshop-scorecard` instance and database `databricks_postgres` (there is also a
one-line CLI command if you prefer). It lands as `<your_schema>.<your_table>`.

💡 If your own sync is still building, you can use the shared fallback that is already there:
`shared_data.customer_scorecard_synced`.

### Part 2: Query the scorecard from Postgres (must-do)

1. Open the query surface: left nav → **Compute → Database instances → `workshop-scorecard`**
   → the **SQL editor** tab.
2. Run a **point lookup** for a single customer:

   ```sql
   SELECT customer_id, customer_name, region, segment,
          lifetime_revenue, r12_revenue, rfm_cell, at_risk_flag, cross_sell_product_name
   FROM   shared_data.customer_scorecard_synced   -- or your own <schema>.<table>
   WHERE  customer_id = 42;
   ```
   You should get back: **42 | The Bell Bistro | North East | National Group | 12701.01 |
   10417.51 | R2F5M4 | true | Mature Cheddar 5kg**.
3. Try a few other `customer_id` values (1-70). Each single-row lookup comes back instantly.

💡 That one row was computed with heavy OLAP (RFM, rolling-12-month, cross-sell affinity),
but Postgres serves it in **sub-millisecond** time. Run
`EXPLAIN ANALYZE SELECT * FROM shared_data.customer_scorecard_synced WHERE customer_id = 42;`
- at this tiny row count (the table is one page) Postgres correctly prefers a `Seq Scan`
(execution time ~0.2 ms). The primary-key index is what keeps the lookup O(log n) **as the
table grows**; to see that plan now, run `SET enable_seqscan = off;` first and re-run the
EXPLAIN to get an `Index Scan using ..._pkey`. Either way this is the OLTP serving pattern:
precompute the hard stuff in the lakehouse, serve it hot from Lakebase to thousands of
concurrent app users.

💡 Prefer the command line? Connect with `psql` using your Databricks identity as the
Postgres role and a short-lived token as the password:
```
EP=projects/workshop-scorecard/branches/production/endpoints/primary
export PGPASSWORD=$(databricks postgres generate-database-credential "$EP" -o json \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
HOST=$(databricks postgres get-endpoint "$EP" -o json \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["status"]["hosts"]["host"])')
psql "host=$HOST dbname=databricks_postgres user=<you>@your-company.com sslmode=require"
```

### Part 3: Create a branch (must-do)

Lakebase can branch the whole database instantly - copy-on-write, like Git for your data.

1. Create a **branch** off `production`:
   ```
   databricks postgres create-branch projects/workshop-scorecard dev-experiment \
     --json '{"spec":{"source_branch":"projects/workshop-scorecard/branches/production","ttl":"86400s"}}'
   ```
2. The branch gets its **own endpoint host** - reconnect to it (same token flow as above),
   then change a row (`UPDATE` or `DELETE`).
3. Query `production` again and confirm it is untouched. Your edit is isolated to the branch.

💡 Branching gives every developer a full, isolated copy in seconds with no data-copy cost -
perfect for testing a migration or a risky change safely.

### Part 4: Point-in-time recovery (near-must)

1. Capture the current time, then make a destructive change on a branch (for example delete
   several rows).
2. Restore by branching *from the past* - point `source_branch_time` at your captured
   timestamp:
   ```
   databricks postgres create-branch projects/workshop-scorecard pitr-recover \
     --json '{"spec":{"source_branch":"projects/workshop-scorecard/branches/production","source_branch_time":"<your-timestamp, e.g. 2026-05-31T20:18:05Z>","ttl":"86400s"}}'
   ```
3. Connect to `pitr-recover` and confirm the rows are back as they were at that instant.

💡 PITR means "oops" is recoverable: you can rewind to any moment inside the retention
window, served as a fresh branch you can inspect before promoting.

### Bonus / optional (if you finish early)

Pick whichever interests you:

- **Read replica** (works today). Add a read-only endpoint and confirm reads succeed but
  writes are rejected:
  ```
  databricks postgres create-endpoint projects/workshop-scorecard/branches/production ro-replica \
    --json '{"spec":{"endpoint_type":"ENDPOINT_TYPE_READ_ONLY"}}'
  ```
- **Scale to zero** (config). Set `suspend_timeout_duration` on an endpoint; compute
  auto-suspends after idle and wakes on the next connection. Great for cost on bursty apps.
- **Data API** (enable in the UI). Project → **Data API** page → **Enable**, then hit it
  over REST - the path an application would actually use:
  ```
  curl -H "Authorization: Bearer $TOKEN" \
    "$REST_ENDPOINT/shared_data/customer_scorecard_synced?customer_id=eq.42"
  ```
- **CDC back to Delta** (preview). Streaming changes made in Lakebase back into a Delta table
  in Unity Catalog closes the loop between OLTP and the lakehouse - one to watch as it comes
  out of preview.

💡 Ask the facilitator which of these are enabled on the day; some are quick to show, others
are discussion-only.

---

## Wrap-up

In one sitting you have:

1. **Asked** your data questions in plain English, taught Genie your business vocabulary,
   and seen why a governed metric view gives everyone the same number.
2. **Built** a medallion pipeline from raw, messy JSON to trustworthy gold metrics - by
   describing intent to Genie Code, not by memorising Spark.
3. **Served** heavy analytics as millisecond Postgres lookups with Lakebase, complete with
   branching and point-in-time recovery.

That is the full arc: raw data in, governed insight out, served anywhere. 🎉
