# Databricks notebook source
# MAGIC %md
# MAGIC # Workshop Bootstrap - Northgate Provisions Co.
# MAGIC
# MAGIC **One action: _Run all_.** This single notebook provisions the entire workshop
# MAGIC environment and is **idempotent** (safe to re-run).
# MAGIC
# MAGIC It will:
# MAGIC 1. _(optional, documented)_ create a catalog for your workspace,
# MAGIC 2. create the `shared_data` schema and a UC volume,
# MAGIC 3. **copy the committed raw + clean JSON from this imported repo into the volume**
# MAGIC    (no manual upload),
# MAGIC 4. build the CLEAN shared tables (`customers`, `products`, `orders`),
# MAGIC 5. build the heavy-OLAP `gold_customer_scorecard` (point-lookup keyed by `customer_id`),
# MAGIC 6. create per-user schemas and grant access to the participant group,
# MAGIC 7. verify everything landed (row counts + volume file listing).
# MAGIC
# MAGIC Runs on **serverless** compute. Thin per-step scripts (`01_…` – `05_…`) mirror each
# MAGIC section for transparency; this notebook is self-contained so _Run all_ needs nothing else.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Configuration
# MAGIC
# MAGIC Defaults to the example catalog (`workshop`). For your own workspace,
# MAGIC change `catalog` here (and optionally enable catalog creation below).

# COMMAND ----------

dbutils.widgets.text("catalog", "workshop", "Catalog")
dbutils.widgets.text("schema", "shared_data", "Schema")
dbutils.widgets.text("volume", "data", "Volume")
dbutils.widgets.text("participants_group", "workshop_participants", "Participant group")
dbutils.widgets.text("participant_users", "", "Participant users (comma-separated emails; blank = just you)")
dbutils.widgets.dropdown("create_catalog", "false", ["true", "false"], "Create catalog? (only if you need a fresh one)")
dbutils.widgets.text("data_dir", "", "Override repo data dir (blank = auto-detect)")
dbutils.widgets.dropdown("provision_lakebase", "true", ["true", "false"], "Provision Lakebase project + grant group? (Practical 3 setup; on by default, degrades gracefully)")
dbutils.widgets.text("lakebase_project", "workshop-scorecard", "Lakebase project name")

CATALOG = dbutils.widgets.get("catalog").strip()
SCHEMA = dbutils.widgets.get("schema").strip()
VOLUME = dbutils.widgets.get("volume").strip()
PARTICIPANTS_GROUP = dbutils.widgets.get("participants_group").strip()
CREATE_CATALOG = dbutils.widgets.get("create_catalog").strip().lower() == "true"
PROVISION_LAKEBASE = dbutils.widgets.get("provision_lakebase").strip().lower() == "true"
LAKEBASE_PROJECT = dbutils.widgets.get("lakebase_project").strip()
_users_raw = dbutils.widgets.get("participant_users").strip()

current_user = spark.sql("SELECT current_user()").collect()[0][0]
PARTICIPANT_USERS = [u.strip() for u in _users_raw.split(",") if u.strip()] or [current_user]

VOLUME_ROOT = f"/Volumes/{CATALOG}/{SCHEMA}/{VOLUME}"
print(f"Catalog .............. {CATALOG}")
print(f"Schema ............... {SCHEMA}")
print(f"Volume ............... {VOLUME_ROOT}")
print(f"Participant group .... {PARTICIPANTS_GROUP}")
print(f"Per-user schemas ..... {PARTICIPANT_USERS}")
print(f"Create catalog? ...... {CREATE_CATALOG}")
print(f"Provision Lakebase? .. {PROVISION_LAKEBASE}  (project: {LAKEBASE_PROJECT})")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. (Optional) Create the catalog
# MAGIC
# MAGIC By default this reuses the existing `workshop`, so it is
# MAGIC skipped (`create_catalog = false`). To create a fresh catalog on your workspace, set the
# MAGIC `create_catalog` widget to `true`. A managed catalog needs no storage location on most
# MAGIC workspaces; if yours requires one, add `MANAGED LOCATION '<s3/abfss path>'`.

# COMMAND ----------

if CREATE_CATALOG:
    spark.sql(f"CREATE CATALOG IF NOT EXISTS {CATALOG} COMMENT 'Sales analytics workshop'")
    print(f"✅ Catalog {CATALOG} ready")
else:
    print(f"⏭️  Skipping catalog creation; using existing catalog {CATALOG}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Create schema + volume

# COMMAND ----------

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.{SCHEMA} COMMENT 'Shared workshop data for Northgate Provisions Co.'")
spark.sql(f"CREATE VOLUME IF NOT EXISTS {CATALOG}.{SCHEMA}.{VOLUME} COMMENT 'Landing volume for workshop raw + clean JSON'")
print(f"✅ Schema {CATALOG}.{SCHEMA} and volume {VOLUME} ready")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Copy the committed JSON from the repo into the UC volume
# MAGIC
# MAGIC **This is the key simplicity requirement - no manual upload.** We locate the `data/`
# MAGIC folder inside this imported repo (derived from the notebook's own path) and copy the
# MAGIC `raw/` and `clean/` JSON into the volume.
# MAGIC
# MAGIC ### Volume-copy robustness (known gotcha)
# MAGIC Writing repo files into a UC volume on serverless has historically been flaky. The
# MAGIC helper below is belt-and-braces: it tries a direct FUSE write, then `dbutils.fs.cp`
# MAGIC with an explicit `file:` scheme, then the SDK Files API (REST, FUSE-independent), and
# MAGIC reports which method succeeded. On this workspace the FUSE write works; the fallbacks
# MAGIC guarantee it won't be fragile elsewhere.

# COMMAND ----------

import os, io

def _detect_data_dir():
    """Find the repo's data/ folder. Override via the data_dir widget, else derive from
    the notebook path (repo_root/data), else search the user workspace."""
    override = dbutils.widgets.get("data_dir").strip()
    if override:
        return override
    try:
        nb_path = (dbutils.notebook.entry_point.getDbutils().notebook()
                   .getContext().notebookPath().get())
        # nb_path = /Workspace/.../<repo>/setup/00_bootstrap  ->  repo_root = two levels up
        repo_root = os.path.dirname(os.path.dirname(nb_path))
        candidate = f"/Workspace{repo_root}/data" if not repo_root.startswith("/Workspace") else f"{repo_root}/data"
        if os.path.isdir(candidate):
            return candidate
        # Some import layouts nest an extra folder; probe a couple of fallbacks.
        for c in (f"/Workspace{repo_root}/data", f"{repo_root}/data", f"{repo_root}/data/data"):
            if os.path.isdir(c):
                return c
    except Exception as e:
        print(f"(notebook-path detection failed: {e})")
    raise RuntimeError("Could not locate the repo data/ folder - set the 'data_dir' widget.")

DATA_DIR = _detect_data_dir()
print(f"Repo data dir: {DATA_DIR}")
assert os.path.isdir(f"{DATA_DIR}/raw") and os.path.isdir(f"{DATA_DIR}/clean"), \
    f"Expected raw/ and clean/ under {DATA_DIR}"

# COMMAND ----------

def copy_into_volume(src_file, dst_file):
    """Copy one file from /Workspace into a UC volume, trying multiple methods in order."""
    os.makedirs(os.path.dirname(dst_file), exist_ok=True)
    errs = {}
    # 1) pure-Python FUSE read + write
    try:
        with open(src_file, "rb") as f:
            data = f.read()
        with open(dst_file, "wb") as f:
            f.write(data)
        if os.path.getsize(dst_file) == len(data):
            return "fuse_open_write"
    except Exception as e:
        errs["fuse"] = repr(e)[:200]
    # 2) dbutils.fs.cp with explicit file: scheme
    try:
        dbutils.fs.cp(f"file:{src_file}", dst_file)
        return "dbutils_fs_cp"
    except Exception as e:
        errs["dbutils"] = repr(e)[:200]
    # 3) Databricks SDK Files API (REST, FUSE-independent)
    try:
        from databricks.sdk import WorkspaceClient
        with open(src_file, "rb") as f:
            data = f.read()
        WorkspaceClient().files.upload(dst_file, io.BytesIO(data), overwrite=True)
        return "sdk_files_api"
    except Exception as e:
        errs["sdk"] = repr(e)[:200]
    raise RuntimeError(f"All copy methods failed for {src_file}: {errs}")

methods_used, landed = {}, []
for flavour in ("raw", "clean"):
    for entity in ("customers", "products", "orders"):
        src = f"{DATA_DIR}/{flavour}/{entity}/{entity}.json"
        dst = f"{VOLUME_ROOT}/{flavour}/{entity}/{entity}.json"
        methods_used[f"{flavour}/{entity}"] = copy_into_volume(src, dst)
        landed.append((dst, os.path.getsize(dst)))

print("Copy methods used:", methods_used)
for dst, size in landed:
    print(f"  {size:>8,} bytes  {dst}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Build the CLEAN shared tables
# MAGIC
# MAGIC Loaded from the committed `clean/` JSON (guaranteed free of data-quality issues - the
# MAGIC dirty `raw/` data is for the SDP lab). These back the Genie practical.

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.{SCHEMA}.customers
COMMENT 'Northgate Provisions outlets (clean curated)' AS
SELECT customer_id, customer_name, region, segment, account_manager, CAST(join_date AS DATE) AS join_date
FROM read_files('{VOLUME_ROOT}/clean/customers/', format => 'json',
  schemaHints => 'customer_id INT, join_date DATE')
""")

spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.{SCHEMA}.products
COMMENT 'Northgate Provisions product catalogue (clean curated)' AS
SELECT product_id, product_name, category, CAST(list_price AS DECIMAL(10,2)) AS list_price,
       CAST(cost AS DECIMAL(10,2)) AS cost, CAST(launch_date AS DATE) AS launch_date
FROM read_files('{VOLUME_ROOT}/clean/products/', format => 'json',
  schemaHints => 'list_price DECIMAL(10,2), cost DECIMAL(10,2), launch_date DATE')
""")

spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.{SCHEMA}.orders
COMMENT 'Northgate Provisions order lines (clean curated)' AS
SELECT order_id, customer_id, product_id, CAST(order_date AS DATE) AS order_date, quantity,
       CAST(unit_price AS DECIMAL(10,2)) AS unit_price, CAST(discount_pct AS DECIMAL(5,2)) AS discount_pct, currency
FROM read_files('{VOLUME_ROOT}/clean/orders/', format => 'json',
  schemaHints => 'order_id INT, customer_id INT, quantity INT, order_date DATE, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2)')
""")
print("✅ customers, products, orders built")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Build the heavy-OLAP `gold_customer_scorecard`
# MAGIC
# MAGIC Pre-computed per-customer analytics keyed by `customer_id` for **point lookup** - the
# MAGIC kind of thing you would never run live against an OLTP store. Rolling-12-month
# MAGIC revenue/profit/margin, RFM scores, an at-risk score, peer percentile ranks, top
# MAGIC categories and a next-best-SKU cross-sell recommendation. This is the table the
# MAGIC Lakebase practical syncs to Postgres.

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE TABLE {CATALOG}.{SCHEMA}.gold_customer_scorecard
COMMENT 'Heavy-OLAP per-customer analytics scorecard, keyed by customer_id for point lookup (Lakebase source).' AS
WITH params AS (
  SELECT MAX(order_date) AS as_of_date FROM {CATALOG}.{SCHEMA}.orders
),
line_facts AS (
  SELECT o.order_id, o.customer_id, o.product_id, o.order_date, o.quantity, p.category,
         o.quantity * o.unit_price * (1 - o.discount_pct/100)                       AS revenue,
         o.quantity * o.unit_price * (1 - o.discount_pct/100) - o.quantity * p.cost  AS profit
  FROM {CATALOG}.{SCHEMA}.orders o
  JOIN {CATALOG}.{SCHEMA}.products p ON o.product_id = p.product_id
),
lifetime AS (
  SELECT customer_id,
         COUNT(order_id) AS lifetime_orders, SUM(quantity) AS lifetime_units,
         ROUND(SUM(revenue),2) AS lifetime_revenue, ROUND(SUM(profit),2) AS lifetime_profit,
         ROUND(AVG(revenue),2) AS avg_order_value, MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date
  FROM line_facts GROUP BY customer_id
),
r12 AS (
  SELECT lf.customer_id, COUNT(order_id) AS r12_orders,
         ROUND(SUM(revenue),2) AS r12_revenue, ROUND(SUM(profit),2) AS r12_profit
  FROM line_facts lf, params
  WHERE lf.order_date > add_months(params.as_of_date, -12)
  GROUP BY lf.customer_id
),
cust_cat AS (
  SELECT customer_id, category, SUM(revenue) AS cat_rev,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY SUM(revenue) DESC, category) AS rn
  FROM line_facts GROUP BY customer_id, category
),
top_cats AS (
  SELECT customer_id,
         MAX(CASE WHEN rn=1 THEN category END) AS top_category_1,
         MAX(CASE WHEN rn=2 THEN category END) AS top_category_2
  FROM cust_cat GROUP BY customer_id
),
purchased_prod AS (SELECT DISTINCT customer_id, product_id FROM line_facts),
seg_prod_pop AS (
  SELECT c.segment, lf.product_id, COUNT(DISTINCT lf.customer_id) AS cnt
  FROM line_facts lf JOIN {CATALOG}.{SCHEMA}.customers c ON lf.customer_id = c.customer_id
  GROUP BY c.segment, lf.product_id
),
cross_sell AS (
  SELECT customer_id, product_id AS cross_sell_product_id, product_name AS cross_sell_product_name FROM (
    SELECT cu.customer_id, pr.product_id, pr.product_name,
           ROW_NUMBER() OVER (PARTITION BY cu.customer_id ORDER BY COALESCE(sp.cnt,0) DESC, pr.product_id) AS rn
    FROM {CATALOG}.{SCHEMA}.customers cu
    CROSS JOIN {CATALOG}.{SCHEMA}.products pr
    LEFT JOIN purchased_prod pp ON pp.customer_id = cu.customer_id AND pp.product_id = pr.product_id
    LEFT JOIN seg_prod_pop sp ON sp.segment = cu.segment AND sp.product_id = pr.product_id
    WHERE pp.product_id IS NULL
  ) WHERE rn = 1
),
base AS (
  SELECT
    c.customer_id, c.customer_name, c.region, c.segment, c.account_manager, c.join_date,
    DATEDIFF((SELECT as_of_date FROM params), c.join_date) AS tenure_days,
    COALESCE(l.lifetime_orders,0) AS lifetime_orders, COALESCE(l.lifetime_units,0) AS lifetime_units,
    COALESCE(l.lifetime_revenue,0) AS lifetime_revenue, COALESCE(l.lifetime_profit,0) AS lifetime_profit,
    ROUND(100 * COALESCE(l.lifetime_profit,0)/NULLIF(l.lifetime_revenue,0),2) AS lifetime_margin_pct,
    COALESCE(l.avg_order_value,0) AS avg_order_value, l.first_order_date, l.last_order_date,
    COALESCE(r.r12_orders,0) AS r12_orders, COALESCE(r.r12_revenue,0) AS r12_revenue, COALESCE(r.r12_profit,0) AS r12_profit,
    ROUND(100 * COALESCE(r.r12_profit,0)/NULLIF(r.r12_revenue,0),2) AS r12_margin_pct,
    DATEDIFF((SELECT as_of_date FROM params), l.last_order_date) AS recency_days,
    COALESCE(r.r12_orders,0) AS frequency_12m, COALESCE(r.r12_revenue,0) AS monetary_12m,
    tc.top_category_1, tc.top_category_2,
    xs.cross_sell_product_id, xs.cross_sell_product_name
  FROM {CATALOG}.{SCHEMA}.customers c
  LEFT JOIN lifetime l ON c.customer_id = l.customer_id
  LEFT JOIN r12 r ON c.customer_id = r.customer_id
  LEFT JOIN top_cats tc ON c.customer_id = tc.customer_id
  LEFT JOIN cross_sell xs ON c.customer_id = xs.customer_id
),
scored AS (
  SELECT b.*,
    CONCAT_WS(' | ', b.top_category_1, b.top_category_2) AS top_categories,
    NTILE(5) OVER (ORDER BY b.recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY b.frequency_12m ASC) AS f_score,
    NTILE(5) OVER (ORDER BY b.monetary_12m ASC) AS m_score,
    ROUND(100 * PERCENT_RANK() OVER (ORDER BY b.lifetime_revenue),1) AS revenue_percentile,
    ROUND(100 * PERCENT_RANK() OVER (PARTITION BY b.segment ORDER BY b.lifetime_revenue),1) AS revenue_percentile_in_segment,
    ROUND(100 * (0.6 * (b.recency_days/NULLIF(MAX(b.recency_days) OVER (),0))
              +  0.4 * (1 - (b.frequency_12m/NULLIF(MAX(b.frequency_12m) OVER (),0)))),1) AS at_risk_score
  FROM base b
)
SELECT s.*,
  CONCAT('R', r_score, 'F', f_score, 'M', m_score) AS rfm_cell,
  CASE WHEN r_score <= 2 AND m_score >= 4 THEN true ELSE false END AS at_risk_flag,
  current_timestamp() AS computed_at
FROM scored s
""")
print("✅ gold_customer_scorecard built")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6b. Build the governed `sales_metrics` metric view
# MAGIC
# MAGIC A Unity Catalog **metric view** (DBR 17.2+) defining standardised KPIs in YAML over
# MAGIC the clean `orders` fact, joined to `customers` and `products`. It gives Genie and
# MAGIC dashboards one governed source of truth for revenue/profit/margin so every tool agrees.
# MAGIC Queried with `MEASURE(...)`. Many measures over many dimensions, so any measure can be
# MAGIC sliced by any dimension with one governed definition shared by Genie, dashboards and SQL.

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {CATALOG}.{SCHEMA}.sales_metrics
WITH METRICS
LANGUAGE YAML
COMMENT 'Governed sales KPIs for Northgate Provisions Co. (orders fact joined to customers + products).'
AS $$
version: "1.1"
source: {CATALOG}.{SCHEMA}.orders
comment: "Governed sales KPIs over clean order lines."
joins:
  - name: customers
    source: {CATALOG}.{SCHEMA}.customers
    on: source.customer_id = customers.customer_id
  - name: products
    source: {CATALOG}.{SCHEMA}.products
    on: source.product_id = products.product_id
dimensions:
  - name: Region
    expr: customers.region
  - name: Segment
    expr: customers.segment
  - name: Account Manager
    expr: customers.account_manager
  - name: Category
    expr: products.category
  - name: Order Month
    expr: DATE_TRUNC('MONTH', order_date)
measures:
  - name: Total Revenue
    expr: SUM(quantity * unit_price * (1 - discount_pct/100))
  - name: Total Profit
    expr: SUM(quantity * unit_price * (1 - discount_pct/100) - quantity * products.cost)
  - name: Profit Margin %
    expr: 100 * SUM(quantity * unit_price * (1 - discount_pct/100) - quantity * products.cost) / SUM(quantity * unit_price * (1 - discount_pct/100))
  - name: Order Count
    expr: COUNT(order_id)
  - name: Units Sold
    expr: SUM(quantity)
  - name: Avg Order Value
    expr: SUM(quantity * unit_price * (1 - discount_pct/100)) / COUNT(order_id)
  - name: Distinct Customers
    expr: COUNT(DISTINCT customer_id)
$$
""")
print("✅ sales_metrics metric view built")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Per-user schemas + participant grants
# MAGIC
# MAGIC Each participant gets their own schema (for the SDP lab, where they create their own
# MAGIC tables) and is granted read access to the shared data via the participant group.
# MAGIC Group grants are wrapped defensively: if the group does not exist yet, the bootstrap
# MAGIC reports it rather than failing - create the group and re-run.

# COMMAND ----------

import re

def _schema_for(user_email):
    # turn user@example.com into a safe schema name, e.g. user_example_com
    return "ws_" + re.sub(r"[^a-z0-9]+", "_", user_email.lower()).strip("_")

created_schemas = []
for user in PARTICIPANT_USERS:
    sch = _schema_for(user)
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.{sch} COMMENT 'Workshop scratch schema for {user}'")
    try:
        spark.sql(f"GRANT USE SCHEMA, CREATE TABLE, CREATE MATERIALIZED VIEW, SELECT, MODIFY ON SCHEMA {CATALOG}.{sch} TO `{user}`")
    except Exception as e:
        print(f"  (grant on {sch} to {user} skipped: {str(e)[:120]})")
    created_schemas.append(sch)
print(f"✅ Per-user schemas: {created_schemas}")

# COMMAND ----------

# Participant group grants on the shared data + volume (read-only).
group_grants = [
    f"GRANT USE CATALOG ON CATALOG {CATALOG} TO `{PARTICIPANTS_GROUP}`",
    f"GRANT CREATE SCHEMA ON CATALOG {CATALOG} TO `{PARTICIPANTS_GROUP}`",
    f"GRANT USE SCHEMA ON SCHEMA {CATALOG}.{SCHEMA} TO `{PARTICIPANTS_GROUP}`",
    f"GRANT SELECT ON SCHEMA {CATALOG}.{SCHEMA} TO `{PARTICIPANTS_GROUP}`",
    # SELECT on the schema already covers sales_metrics; granted explicitly for clarity.
    f"GRANT SELECT ON VIEW {CATALOG}.{SCHEMA}.sales_metrics TO `{PARTICIPANTS_GROUP}`",
    f"GRANT READ VOLUME ON VOLUME {CATALOG}.{SCHEMA}.{VOLUME} TO `{PARTICIPANTS_GROUP}`",
]
try:
    for g in group_grants:
        spark.sql(g)
    print(f"✅ Granted shared-data + volume read access to group `{PARTICIPANTS_GROUP}`")
except Exception as e:
    print(f"⚠️  Group grants skipped - does group `{PARTICIPANTS_GROUP}` exist? "
          f"Create it (Settings → Identity and Access → Groups) and re-run. Detail: {str(e)[:160]}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7b. Provision the Lakebase project for Practical 3
# MAGIC
# MAGIC Lakebase is a core practical of this workshop, so it is **provisioned by default**
# MAGIC (`provision_lakebase = true`); set `provision_lakebase = false` to skip the Lakebase lab.
# MAGIC The whole block **degrades gracefully**: if Lakebase is not enabled on this workspace, or
# MAGIC you lack permission to create projects, it prints a single warning and the bootstrap
# MAGIC carries on - the data/UC setup and the Verify section are unaffected. This is the
# MAGIC **facilitator-only** Lakebase setup - it does **not** sync any table.
# MAGIC Participants create their own branch and sync the gold table into it themselves
# MAGIC (that is the teaching moment), so all this step does is:
# MAGIC
# MAGIC 1. **Get-or-create the Lakebase Autoscaling project** (idempotent: reuse if it already
# MAGIC    exists; create it otherwise). The project ships with a `production` branch, a
# MAGIC    `primary` endpoint and a default `databricks_postgres` database - that database is
# MAGIC    sufficient, so nothing extra is created.
# MAGIC 2. **Grant the participant group exactly the permission set a participant needs to
# MAGIC    create their own branch and sync into it** (verified end-to-end as a non-admin):
# MAGIC    - Lakebase: a single group Postgres role (`identity_type=GROUP`, via the role API,
# MAGIC      never raw SQL) **and `CAN_MANAGE` on the project**. `CAN_MANAGE` is required:
# MAGIC      `CAN_USE` lets a member connect to existing branches but is rejected on branch
# MAGIC      *creation* ("not authorized ... assign 'Can Manage'").
# MAGIC    - UC: the participant reads the source gold table and writes the synced-table object
# MAGIC      into their own scratch schema. `USE CATALOG` + `USE SCHEMA`/`SELECT` on
# MAGIC      `shared_data` are already granted in section 7; `CREATE TABLE` on each `ws_<user>`
# MAGIC      schema is already granted there too. So no extra UC grant is needed here.
# MAGIC
# MAGIC Group grants need an **account-level** `workshop_participants` group; the block is
# MAGIC defensive and skips the grants (reporting why) if the group is absent.
# MAGIC
# MAGIC > GOTCHA: a deleted project/branch name stays reserved for several minutes. If you tore
# MAGIC > one down, provision with a fresh `lakebase_project` name.

# COMMAND ----------

if not PROVISION_LAKEBASE:
    print("⏭️  Skipping Lakebase provisioning (provision_lakebase=false). "
          "Set provision_lakebase=true to run the Practical 3 setup.")
else:
    # The ENTIRE Lakebase block is wrapped so that ANY failure (no Lakebase entitlement, no
    # permission to create projects, API surface unavailable, etc.) prints one clear warning
    # and CONTINUES. The core data/UC setup and the Verify section must always complete even
    # if Lakebase provisioning fails entirely. The inner try/excepts below stay as-is for the
    # finer-grained idempotency / group-grant handling.
    try:
        from databricks.sdk import WorkspaceClient

        w = WorkspaceClient()
        api = w.api_client
        proj_path = f"projects/{LAKEBASE_PROJECT}"

        # 1) Get-or-create the project (idempotent). Lakebase Autoscaling lives under the
        #    /api/2.0/postgres/* surface; create-project takes project_id as a query param.
        #    Check existence with LIST, not GET: a deleted name stays reserved for several
        #    minutes and a GET still resolves the tombstone, which would fool a GET-based
        #    check into "reusing" a project that is actually gone (every downstream role/grant
        #    call then fails with "project not found"). LIST excludes the tombstone.
        _resp = api.do("GET", "/api/2.0/postgres/projects") or {}
        _live = _resp.get("projects", _resp) if isinstance(_resp, dict) else _resp
        _live_names = {p.get("name") for p in (_live or []) if isinstance(p, dict)}
        if proj_path in _live_names:
            print(f"✅ Reusing existing Lakebase project {proj_path}")
        else:
            try:
                api.do("POST", "/api/2.0/postgres/projects",
                       query={"project_id": LAKEBASE_PROJECT},
                       body={"spec": {"display_name": "Workshop Customer Scorecard", "pg_version": "17"}})
                print(f"✅ Created Lakebase project {proj_path}")
            except Exception as ce:
                raise RuntimeError(
                    f"Could not create Lakebase project '{LAKEBASE_PROJECT}'. If you recently "
                    f"deleted a project with this name, the name stays reserved for several "
                    f"minutes - set the `lakebase_project` widget to a fresh name and re-run. "
                    f"Detail: {str(ce)[:160]}")

        # 2) Confirm the default database. The project ships with `databricks_postgres`,
        #    which is sufficient for the synced-table target - nothing to create.
        print("ℹ️  Default database `databricks_postgres` ships with the project - sufficient, "
              "no database creation needed.")

        # 3) Grant the participant group the permission set needed to branch + sync.
        #    Check the group exists FIRST: the permissions API does NOT validate the principal,
        #    so a CAN_MANAGE grant to a non-existent group "succeeds" and stores a dangling ACL
        #    entry, falsely reporting that participants can branch. (The UC GRANTs in section 7
        #    error on a missing group; this API does not, so we check explicitly here.)
        try:
            _grp_exists = bool(list(w.groups.list(filter=f'displayName eq "{PARTICIPANTS_GROUP}"')))
        except Exception:
            _grp_exists = False
        if not _grp_exists:
            print(f"⚠️  Group `{PARTICIPANTS_GROUP}` not found - skipping the Lakebase role + "
                  f"CAN_MANAGE grant. Create it as an account-level group, assign it to this "
                  f"workspace and add participants, then re-run this cell so they can create "
                  f"their own branch + sync. (Solo run: you already own the project, so you can "
                  f"branch without this.)")
        else:
          try:
            # (a) ONE group Postgres role on the production branch (COW branches inherit it).
            #     Use the role API, NOT raw SQL CREATE ROLE (raw SQL leaves NO_LOGIN, OAuth fails).
            try:
                api.do("POST", f"/api/2.0/postgres/{proj_path}/branches/production/roles",
                       body={"spec": {"auth_method": "LAKEBASE_OAUTH_V1",
                                      "identity_type": "GROUP",
                                      "postgres_role": PARTICIPANTS_GROUP}})
                print(f"✅ Created group Postgres role `{PARTICIPANTS_GROUP}` on production branch")
            except Exception as re:
                # Role already exists -> idempotent no-op.
                print(f"ℹ️  Group Postgres role already present (or: {str(re)[:120]})")

            # (b) CAN_MANAGE on the project (required for branch creation; CAN_USE is NOT enough).
            #     PATCH merges into the existing ACL rather than replacing it.
            api.do("PATCH", f"/api/2.0/permissions/database-projects/{LAKEBASE_PROJECT}",
                   body={"access_control_list": [
                       {"group_name": PARTICIPANTS_GROUP, "permission_level": "CAN_MANAGE"}]})
            print(f"✅ Granted CAN_MANAGE on project to group `{PARTICIPANTS_GROUP}` "
                  f"(enables each participant to create their own branch)")
          except Exception as e:
            print(f"⚠️  Lakebase group grants skipped - does account-level group "
                  f"`{PARTICIPANTS_GROUP}` exist? Detail: {str(e)[:180]}")

        print("🟢 Lakebase facilitator setup done. Participants now create their own branch + sync "
              "(see lakebase/README.md). The bootstrap does NOT sync any table.")
    except Exception as e:
        print(f"⚠️  Lakebase provisioning skipped/failed: {str(e)[:200]}; the data setup is "
              f"unaffected - set up Lakebase manually if needed (see lakebase/README.md).")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Verify

# COMMAND ----------

# Volume files
print("Volume files landed:")
for flavour in ("raw", "clean"):
    for entity in ("customers", "products", "orders"):
        p = f"{VOLUME_ROOT}/{flavour}/{entity}/{entity}.json"
        print(f"  {'OK ' if os.path.exists(p) else 'MISSING':<8} {p}")

# COMMAND ----------

display(spark.sql(f"""
SELECT 'customers' AS table, COUNT(*) AS rows FROM {CATALOG}.{SCHEMA}.customers
UNION ALL SELECT 'products', COUNT(*) FROM {CATALOG}.{SCHEMA}.products
UNION ALL SELECT 'orders', COUNT(*) FROM {CATALOG}.{SCHEMA}.orders
UNION ALL SELECT 'gold_customer_scorecard', COUNT(*) FROM {CATALOG}.{SCHEMA}.gold_customer_scorecard
ORDER BY table
"""))

# COMMAND ----------

# Metric view check - must be queried with MEASURE() (SELECT * is unsupported).
display(spark.sql(f"""
SELECT `Segment`,
       ROUND(MEASURE(`Total Revenue`), 2)  AS revenue,
       ROUND(MEASURE(`Profit Margin %`), 2) AS margin_pct,
       MEASURE(`Order Count`)               AS orders
FROM {CATALOG}.{SCHEMA}.sales_metrics
GROUP BY `Segment` ORDER BY revenue DESC
"""))

# COMMAND ----------

print("🎉 Bootstrap complete. The environment is ready for the workshop.")
