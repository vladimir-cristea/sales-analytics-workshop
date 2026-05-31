# Workshop exercise text

Hands-on exercise copy for the three practicals, ready to paste into the slide deck.
Written for software engineers who are new to Databricks. The scenario throughout is
**Northgate Provisions Co.**, a fictional B2B food and beverage wholesaler supplying
outlets (pubs, cafes, delis, convenience stores) across the UK.

**Shared facts you can rely on**

- Catalog `vcr_serverless_catalog`, schema `shared_data`.
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

**Your Task:** open the **Northgate Provisions** Genie space and work through the parts
below. You are not writing SQL. You are having a conversation.

### Part 1: Get your bearings

1. Open the Genie space and read the suggested questions it offers.
2. Ask: **"How many customers, products and orders do we have?"**
3. Ask: **"Which are our top 10 customers by total revenue?"**
4. Click into one answer and open the SQL Genie generated. You did not write it, but it
   is right there if you want to check the working.

💡 Every answer is backed by real, governed SQL over Unity Catalog tables. Genie is not
guessing; it is generating queries you could have written yourself.

### Part 2: Answer real business questions

Ask these one at a time. Read each answer before moving on.

1. **Which region brings in the most revenue?**
2. **Who are our most at-risk customers?** (ones whose ordering has dropped off)
3. **Which products are discounted the most heavily?**
4. **How has revenue trended month over month over the last year?**
5. **Which account managers look after the most valuable customers?**

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
like "at-risk". You can teach it.

1. Open the space's **Instructions / Knowledge** settings.
2. Add a definition, for example: *"An at-risk customer has not ordered in the last 90
   days."* Add a synonym so "outlet" and "venue" both mean a customer.
3. Re-ask **"Who are our at-risk customers?"** and confirm the answer now follows your
   definition.

💡 This is how a Genie space goes from "clever demo" to "trusted internal tool": curated
definitions, synonyms and sample questions that encode how your business actually talks.

### Part 5: Agent mode - let Genie reason in steps

A simple question becomes one query. A *business* question often needs several steps:
filter, aggregate, compare, then conclude. Agent mode lets Genie plan and chain those
steps.

1. Make sure the space is in **Agent mode**.
2. Ask a multi-step question, for example:
   **"Which product categories are growing fastest in Scotland, and which account
   managers should push them?"**
3. Watch it break the problem down, run more than one query, and synthesise an answer.

💡 Notice the difference from Part 2: this question cannot be answered by a single
`GROUP BY`. Agent mode is doing analyst-style reasoning, not just translation.

### Part 6: The two front doors to Genie

The same space is reachable from two surfaces, aimed at two audiences.

1. **Genie space (builder surface):** what you have been using. This is where a data team
   curates instructions, sample questions and trusted assets.
2. **Genie in Databricks One (business-user surface):** open Databricks One and find the
   same space there. This is the clean, no-clutter view a non-technical colleague gets.

Open the same space both ways and notice it is one governed asset, two experiences.

### Part 7: Metric views - one number, one source of truth (must-do)

This is the most important part of the practical. We are going to see *why* governed
metrics matter.

1. **Ask without the metric view first.** In the space (sources = the base tables only),
   ask: **"What is our average profit margin by segment?"**
   Note the numbers Genie returns for National Group, Regional and Independent.
2. **Look at how Genie computed it.** Open the SQL. It almost certainly averaged the
   per-line margin percentages: `AVG(margin_pct)`. That is an *average of ratios* - every
   order line counts equally, whether it sold one case or a thousand.
3. **Now add the governed metric.** Add the `sales_metrics` metric view as a source on the
   space.
4. **Re-ask the exact same question:** **"What is our average profit margin by segment?"**
   This time Genie uses the metric view's definition,
   `Profit Margin % = SUM(profit) / SUM(revenue)` - a *ratio of sums*, weighted by actual
   money.
5. **Compare the two answers.** They are different. The first is a naive average that a
   few tiny orders can skew; the second is the real, money-weighted margin the finance
   team would recognise.

💡 The lesson: a metric view is a single, governed definition of a business number. Every
tool - Genie, dashboards, notebooks - gets the *same* answer, because the maths lives in
one place instead of being re-invented in every query.

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

💡 Ask Genie Code for an "Auto Loader streaming table" reading the volume path. If you get
stuck on schema inference, ask it to infer the schema or add schema hints.

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

💡 Ask Genie Code to express these as pipeline **expectations**
(`CONSTRAINT ... EXPECT (...) ON VIOLATION DROP ROW`). That way the rules are declarative
and the pipeline reports how many rows each rule dropped.

⚠️ Resist the urge to join here. Silver stays one-table-per-entity. Joining is gold's job
- it keeps each layer single-purpose and easy to debug.

### Part 3: Gold - join and aggregate into business metrics

Now bring the silver tables together and aggregate. Join `silver_orders` to
`silver_customers` and `silver_products` (you need `products.cost` for profit, and the
customer dimensions like region, segment and account manager for grouping), then build
gold tables such as:

- a **per-customer sales summary** (revenue, profit, order count),
- a **per-product performance** table,
- a **per-account-manager** roll-up.

Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
Line profit = revenue − `quantity * cost`.

✅ **Did it work?** Spot-check a gold number against Practical 1. Your gold per-product
revenue should line up with what Genie told you for the same product from the clean
tables. If the totals are close, your cleaning was sound.

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
