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

> _Facilitator note: numbers quoted in the metric-view step are illustrative. Read the
> exact figures off your own space on the day; the teaching point is that the two answers
> diverge, not the specific values._

---

## Practical 1 - Ask your data anything, with Genie

Genie lets anyone query data in plain English. No SQL, no BI tool, no waiting on a data
team. You are the new analyst at Northgate Provisions and your job is to understand the
business by simply asking.

**Your Task:** open the **"Northgate Provisions - Sales Analytics"** Genie space and work
through the parts below. You are not writing SQL. You are having a conversation.

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
   led by Royal Oak Diner at 12.5%.)
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

### Part 4: Teach Genie your business (business context)

Out of the box Genie knows your tables. It does not know what *your team means* by a word
like "at-risk", or quirks like "discount is stored as a percentage". You can teach it, and
the difference is dramatic.

1. **See it get things wrong first.** Open the space's **Instructions / Knowledge**
   settings and temporarily remove (or note the absence of) the business context. Now ask
   **"Which customers are at risk of churning?"** With no definition of "at-risk", Genie
   returns nothing useful (0 rows).
2. **Teach it a definition.** Add: *"An at-risk customer has not ordered in the last 45
   days."* Add a synonym so "outlet" and "venue" both mean a customer. Re-ask the same
   question - now you get the 4 quiet outlets. The definition lives in the semantic layer,
   not in each person's head.
3. **Repeat with an expression rule.** Add the rule that revenue must apply the discount as
   `discount_pct / 100`, then re-ask **"Who are our top 10 customers by revenue?"**

⚠️ Why step 3 matters: without that rule Genie reads `discount_pct = 20` as "subtract 20",
not "subtract 20%", and every revenue figure comes back **negative**. One line of business
context turns nonsense into the correct ranking. This is the single best illustration of
why a curated Genie space beats a raw one.

💡 This is how a Genie space goes from "clever demo" to "trusted internal tool": curated
definitions, synonyms, expression rules and sample questions that encode how your business
actually talks.

⚠️ If everyone is sharing one space, treat the "remove context, see it break, add it back"
steps as a facilitator-led demo rather than 12 people editing the same instructions at once.

### Part 5: Agent mode - let Genie reason in steps

A simple question becomes one query. A *business* question often needs several steps:
filter, aggregate, compare, then conclude. Agent mode lets Genie plan and chain those
steps.

1. Ask a multi-step question, for example:
   **"Which product categories are growing fastest in Scotland, and which account managers
   cover the most customers there so they can push those categories?"**
2. Watch Genie's agent reasoning break the problem down, run more than one analysis, and
   synthesise an answer. Expect something like: *Frozen is growing fastest (+85%), then
   Alcohol (+26%); Priya Sharma covers the most Scottish outlets, so she should lead the
   push.*

💡 If your workspace has the **Genie Agent mode** preview enabled (Settings → Previews) you
will see the steps laid out explicitly. Even without that named toggle, Genie's multi-step
reasoning still answers questions like this in one go - ask your facilitator which is on.

💡 Notice the difference from Part 2: this question cannot be answered by a single
`GROUP BY`. It needs a growth analysis, a coverage analysis, and then a recommendation that
ties them together. Agent mode is doing analyst-style reasoning, not just translation.

### Part 6: The two front doors to Genie

The same space is reachable from two surfaces, aimed at two audiences.

1. **Genie space (builder surface):** what you have been using. Left nav → **Genie** →
   **"Northgate Provisions - Sales Analytics"**. This is the full builder, where a data team
   curates instructions, sample questions and trusted assets.
2. **Genie in Databricks One (business-user surface):** open **Databricks One** (the
   simplified business-user home) → **Genie** → the same space. Ask-and-answer only, none of
   the SQL or builder chrome - the clean view a non-technical colleague gets.

Open the same space both ways: it is one governed asset over the same governed tables, just
two different experiences. (Your facilitator will share the direct link.)

### Part 7: Metric views - one number, one source of truth (must-do)

This is the most important part of the practical. We are going to see *why* governed
metrics matter.

**Step 1 - watch a simple question give an impossible answer.**

1. With the space on the base tables only, ask: **"How many active customers in the last 90
   days, by segment?"**
2. Genie returns something like **Independent 69, Regional 32, National Group 20**. That is
   *impossible* - there are only 41 Independent, 17 Regional and 12 National Group customers
   in total. Open the SQL: it summed monthly active counts, double-counting anyone who
   ordered in more than one month.

**Step 2 - add the governed metric.**

3. Add the `sales_metrics` metric view as a source on the space. It already defines the
   measures your business cares about - `Total Revenue`, `Total Profit`, `Profit Margin %`,
   `Order Count`, `Units Sold`, `Avg Order Value`, `Active Customers (90d)` - sliceable by
   `Region`, `Segment`, `Account Manager`, `Category` and `Order Month`.
4. Re-ask the exact same question. Now Genie uses the governed `Active Customers (90d)`
   measure (a proper distinct count) and returns **Independent 41, Regional 17, National
   Group 12** - numbers that can actually be true.

**Step 3 - the subtle one still flips the ranking.**

5. Try a harder-to-spot case. Ask **"What is the average profit margin by segment?"**
   - Without the metric view (avg-of-ratios): **National Group 20.70%, Regional 20.42%,
     Independent 20.32%** - National Group looks the most profitable.
   - With the governed `Profit Margin %` measure (`SUM(profit)/SUM(revenue)`, a ratio of
     sums): **Independent 20.66%, Regional 20.52%, National Group 20.18%** - the ranking
     *flips*, National Group is actually the least profitable.
   The gap is small because the data is homogeneous, which is exactly why it is dangerous:
   nobody would have queried it, yet the business conclusion is the opposite.

💡 The lesson: a metric view is a single, governed definition of a business number. Every
tool - Genie, dashboards, notebooks - gets the *same* answer, because the maths lives in
one place instead of being re-invented in every query. In SQL you would pull a measure out
with `MEASURE("Profit Margin %")`; Genie does that for you under the hood.

⚠️ Avg-of-ratios vs ratio-of-sums is one of the most common ways analysts quietly
disagree on "the same" KPI. Metric views end that argument.

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
anyone else.

💡 You are not expected to remember Spark syntax. Open **Genie Code** (the assistant in the
editor) and describe what you want in English: *"create a streaming table that reads the
JSON files in this volume path"*. Iterate. Read what it gives you, run it, fix it.

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
- Drop `discount_pct` outside 0–100.
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

You should end up with roughly **64 customers, 34 products, 2,200 orders** in silver -
exactly the clean reference counts, which is the sign your rules caught all the dirt.

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
  more than twice their normal cadence - a fair "gone quiet" signal.

Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
Line profit  = revenue - `quantity * cost`.

✅ **Did it work?** Numbers to check against: **34** products in `gold_product_performance`,
**7** account managers in `gold_rep_performance`, and **9** at-risk customers. Total product
revenue should be **about £871.8k** across 2,200 order lines - lining up with the clean
tables from Practical 1 (to the penny it depends on where you round, but it lands at
£871,821). Your top product by revenue should be **Prosecco 750ml x6 (£60,693.48)** and
your top account manager **Aisha Bello (£66,573.98)**.

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

We have pre-computed a heavy per-customer table, `gold_customer_scorecard` (rolling
12-month revenue, RFM scores, at-risk flag, peer percentile ranks, cross-sell pick), and
synced it to Lakebase for you.

**Your Task:** work through the tiers below. Get the must-do done first, then go as far as
time allows.

### Part 1: Query the scorecard from Postgres (must-do)

1. Open the Lakebase instance and its SQL editor / query surface.
2. Run a **point lookup** for a single customer, for example:

   ```sql
   SELECT customer_id, customer_name, segment,
          r12_revenue, at_risk_flag, cross_sell_product_name
   FROM gold_customer_scorecard
   WHERE customer_id = 1;
   ```
3. Try a few different `customer_id` values. Notice how fast a single-row lookup comes
   back - this is the OLTP serving pattern, not analytics.

💡 This is the same data you could compute in Spark, but served from Postgres it returns
in milliseconds and scales to thousands of concurrent app users.

### Part 2: Create a branch (must-do)

Lakebase can branch the whole database instantly, like Git for your data.

1. Create a **branch** of the database from the Lakebase UI.
2. On the branch, make a change (update or delete a row).
3. Confirm the original (parent) is untouched.

💡 Branching gives every developer a full, isolated copy in seconds with no data copy
cost - perfect for testing a migration or a risky change safely.

### Part 3: Point-in-time recovery (near-must)

1. Note the current time, then make a destructive change (for example delete several
   rows).
2. Use **point-in-time recovery** to restore the database to just before that change.
3. Confirm the rows are back.

💡 PITR means "oops" is recoverable. You can rewind the database to any moment in its
retention window.

### Bonus / optional (if you finish early)

Pick whichever interests you:

- **Data API.** Hit the scorecard over Lakebase's REST Data API instead of SQL - the path
  an application would actually use.
- **Scale to zero.** Find the instance's scale-to-zero setting and see how it idles down to
  save cost, then wakes on the next query.
- **Read replica.** Add a read replica and understand when you would route reads to it.
- **CDC back to Delta.** Discuss / try streaming changes made in Lakebase back into a Delta
  table in Unity Catalog, closing the loop between OLTP and the lakehouse.

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
