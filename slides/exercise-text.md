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

---

## Practical 1 - Ask your data anything, with Genie

Genie lets anyone query data in plain English. No SQL, no BI tool, no waiting on a data
team. You are the new analyst at Northgate Provisions: get to know the business by asking.

**Your Task:** open the **"Northgate Provisions - Sales Analytics"** Genie space and explore.
You are not writing SQL, you are having a conversation. The prompts below are starting points,
not a script - follow whatever you find interesting.

### Warm up

Get your bearings. Ask how many customers, products and orders there are, or what the data
covers. Open the SQL behind any answer: you did not write it, but it is right there to inspect.

💡 Every answer is real, governed SQL over Unity Catalog tables - queries you could have
written yourself.

### Explore the business

Pull on a few threads and follow the answers wherever they lead:

- Who are your biggest customers? Your best-selling products?
- Which outlets are slipping - ordering less, or gone quiet?
- Where are you giving away the most discount?
- How are sales trending over the year? Which regions or segments lead?

Genie remembers the conversation, so build on an answer instead of starting over: ask
"which region leads?", then "and which segment within it?", then "show me the top customers
there". If an answer surprises you, just ask "why?".

💡 Notice Genie already understands your business vocabulary - words like "at-risk",
"key account" or "outlet". That is curated business context behind the scenes, and it is what
makes the answers trustworthy. More on that below.

### Let Genie reason for you (Agent mode)

Some questions take several steps - filter, compare, then conclude. Agent mode (the default
in the question box) plans and chains them. Try a compound question and watch it work, e.g.:

> *"Which product categories are growing fastest in Scotland, and which account managers
> should push them?"*

That cannot be answered by a single `GROUP BY` - Genie is doing analyst-style reasoning, not
just translating one question into one query.

### Two ways in

The same space has two front doors:

- **Builders and analysts** open it from the workspace: left nav → **Genie**.
- **Business users** open it from **Databricks One**: top nav → **Switch apps** → **Genie**,
  for a clean, ask-and-answer view with none of the builder chrome.

Open it both ways - one governed asset over the same governed data, two experiences.

### Why governed metrics matter

Business context is what turns Genie from a clever demo into something you can trust. Two
spaces are set up so you can feel the difference:

- Ask the **same** question on **"Northgate Provisions - Base Only (no context)"** and on
  **"Northgate Provisions - Metric View Comparison"** - something like
  *"active customers (90d) by segment"*.
- Compare the answers. The base space has no governed metric, so Genie stitches together
  pre-aggregated tables and badly over-counts - you will see totals larger than the customer
  base actually is. The metric-view space uses one governed definition and returns a count
  that can actually be true.

Open the SQL behind each to see why they differ. The lesson: a **metric view** pins a business
definition in one place, so Genie, dashboards and SQL all give the same answer.

💡 Genie is non-deterministic, so your exact numbers will vary from run to run - which is
rather the whole point of governing the definition.

### If you have time

- Add a measure of your own to a metric view, then ask Genie to use it.
- Genie is callable from code too (the Conversation API) if you fancy wiring it into an app.

---

## Practical 2 - Build a data pipeline from scratch, with Genie Code

The clean tables you queried in Practical 1 did not arrive clean. Somebody had to ingest
raw data, throw out the rubbish, and shape it into something trustworthy. That somebody is
now you.

You are going to build a **medallion pipeline** (bronze → silver → gold) on the *raw,
messy* Northgate data, using **Genie Code** to help you write it. There is no fill-in-the
blanks file: you get the brief and the rules, and *you* decide how to prompt your way there.

**Time to build!**

The raw, deliberately dirty JSON is in a volume:

```
/Volumes/vcr_serverless_catalog/shared_data/data/raw/customers/
/Volumes/vcr_serverless_catalog/shared_data/data/raw/products/
/Volumes/vcr_serverless_catalog/shared_data/data/raw/orders/
```

Build your pipeline **into your own schema** (`ws_<your-name>`) so you do not clash with
anyone else. All three layers are core; the **Bonus** at the end is optional.

💡 You are not expected to remember Spark syntax. Open **Genie Code** (the button in the
workspace top nav) and describe what you want in plain English:
*"create a streaming table that reads the JSON files in this volume path"*. Iterate: read
what it gives you, run it, fix it.

### Part 1: Bronze - land the raw data, as-is

Create one bronze table per entity (`bronze_customers`, `bronze_products`,
`bronze_orders`) that simply reads the raw JSON from the volume. **Do not clean anything
yet.** Bronze is the faithful, unaltered copy of what landed - dirt and all.

💡 Ask Genie Code for an "Auto Loader streaming table" reading the volume path. A nice
touch is to stamp each row with where and when it landed (`_ingested_at`, `_source_file`).

⚠️ Three things that commonly trip people up (let Genie Code hit them, then fix):

- A streaming table needs `FROM STREAM read_files(...)`. Plain `FROM read_files(...)` is a
  batch query and errors with *"Cannot create streaming table from batch query"*. The
  `STREAM` keyword is what makes it Auto Loader.
- Use `CREATE OR REFRESH STREAMING TABLE | MATERIALIZED VIEW`, not `CREATE OR REPLACE`
  (that is plain SQL and will not run in a pipeline).
- On dirty JSON, pin the column types with `schemaHints` (for example
  `'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2),
  discount_pct DECIMAL(5,2)'`). Without them, one garbage value can flip an inferred type.

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

⚠️ Resist the urge to join here. Silver stays one-table-per-entity. Joining is gold's job:
it keeps each layer single-purpose and easy to debug.

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
  dataset's "today"). Outlets reorder roughly fortnightly, so 30 days is a fair "gone quiet"
  signal. (This is a stricter window than the at-risk definition Genie used in Practical 1,
  so expect a different count - same idea, different threshold.)

Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
Line profit  = revenue - `quantity * cost`.

✅ **Did it work?** A good sanity check: your gold per-product revenue should line up with
what Genie told you from the clean tables in Practical 1. Products and orders should match
the clean counts once your rules have done their job.

💡 **Spot the subtlety.** Your per-*product* gold totals will match the clean reference, but
your per-*customer* totals come out a little lower. Why? Silver dropped a few customers whose
`region` was corrupted, and dropping those dimension rows orphans their (perfectly good) order
lines from the customer join. That is the classic trade-off between *dropping* a bad row and
*quarantining or repairing* it - well worth a thought for real pipelines.

### Bonus (if you finish early)

- **Schedule it.** Turn your pipeline into a Job and give it a schedule.
- **Add an expectation + alert.** Add a data-quality expectation that fails loudly, and
  wire an alert so someone is notified when bad data shows up.
- **Cross-sell table.** Build a gold table that, for each customer, recommends the most
  popular product in their segment that they have *not* yet bought.

💡 Use Genie Code throughout. The skill being practised is *describing intent and reviewing
the result*, not memorising APIs.

---

## Practical 3 - Serve analytics in milliseconds, with Lakebase

Practical 2 produced rich, heavy analytics. Brilliant for a report, far too slow to power
a live app that needs one customer's scorecard *right now*. **Lakebase** is managed
Postgres built into Databricks: you sync a gold table to it and get millisecond point
lookups, plus database superpowers like instant branching and point-in-time recovery.

The bootstrap built a heavy per-customer table, `gold_customer_scorecard` (rolling 12-month
revenue, RFM scores, at-risk flag, peer percentile ranks, cross-sell pick). Your facilitator
has already provisioned the Lakebase project **`workshop-scorecard`** (Postgres 17) and your
personal Postgres role. In this lab you sync that scorecard into Postgres and put it to work.

**Your Task:** work through the tiers below. Get the must-do done first, then go as far as
time allows. You will use the database **`databricks_postgres`** throughout.

> _Facilitator note: participants need no admin rights to self-sync. The grants can all be
> applied to the `workshop_participants` group once (no per-person work): Unity Catalog
> (USE CATALOG; USE SCHEMA + CREATE TABLE on the participant schemas; USE SCHEMA + SELECT on
> the source gold table) plus Lakebase (a Postgres role created with `identity_type=GROUP`,
> and `CAN_USE` on the `workshop-scorecard` database project). They are scripted in
> `lakebase/synced_table/facilitator_grants.sh`; run it before the session.
> `workshop_participants` must be an **account-level** group._

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
   You get that customer's full scorecard back in a single row - name, region, segment,
   lifetime and rolling-12-month revenue, RFM cell, at-risk flag and next-best cross-sell.
3. Try a few other `customer_id` values. Each single-row lookup comes back instantly.

💡 That one row was computed with heavy OLAP (RFM, rolling-12-month, cross-sell affinity),
but Postgres serves it in **sub-millisecond** time. Run
`EXPLAIN ANALYZE SELECT * FROM shared_data.customer_scorecard_synced WHERE customer_id = 42;`
- at this small row count (the table fits in one page) Postgres sensibly prefers a `Seq Scan`.
The primary-key index is what keeps the lookup fast **as the table grows**; to see that plan
now, run `SET enable_seqscan = off;` first and re-run the EXPLAIN to get an `Index Scan`.
Either way this is the OLTP serving pattern: precompute the hard stuff in the lakehouse, serve
it hot from Lakebase to thousands of concurrent app users.

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
     --json '{"spec":{"source_branch":"projects/workshop-scorecard/branches/production","source_branch_time":"<your-timestamp>","ttl":"86400s"}}'
   ```
3. Connect to `pitr-recover` and confirm the rows are back as they were at that instant.

💡 PITR means "oops" is recoverable: you can rewind to any moment inside the retention
window, served as a fresh branch you can inspect before promoting.

### Bonus / optional (if you finish early)

Pick whichever interests you:

- **Read replica.** Add a read-only endpoint and confirm reads succeed but writes are
  rejected:
  ```
  databricks postgres create-endpoint projects/workshop-scorecard/branches/production ro-replica \
    --json '{"spec":{"endpoint_type":"ENDPOINT_TYPE_READ_ONLY"}}'
  ```
- **Scale to zero.** Set `suspend_timeout_duration` on an endpoint; compute auto-suspends
  after idle and wakes on the next connection. Great for cost on bursty apps.
- **Data API.** Enable it on the project's **Data API** page, then hit the scorecard over
  REST - the path an application would actually use:
  ```
  curl -H "Authorization: Bearer $TOKEN" \
    "$REST_ENDPOINT/shared_data/customer_scorecard_synced?customer_id=eq.42"
  ```
- **CDC back to Delta.** Streaming changes made in Lakebase back into a Delta table in Unity
  Catalog closes the loop between OLTP and the lakehouse - one to watch as it matures.

💡 Ask the facilitator which of these are enabled on the day; some are quick to show, others
are discussion-only.

---

## Wrap-up

In one sitting you have:

1. **Asked** your data questions in plain English, and seen why governed business context and
   metric views give everyone the same trustworthy answer.
2. **Built** a medallion pipeline from raw, messy JSON to trustworthy gold metrics - by
   describing intent to Genie Code, not by memorising Spark.
3. **Served** heavy analytics as millisecond Postgres lookups with Lakebase, complete with
   branching and point-in-time recovery.

That is the full arc: raw data in, governed insight out, served anywhere. 🎉
