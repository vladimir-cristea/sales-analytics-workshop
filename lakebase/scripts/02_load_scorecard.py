#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Load the gold scorecard into Postgres
# ---------------------------------------------------------------------------
# The PREFERRED workshop path is a Unity Catalog SYNCED TABLE (reverse ETL) —
# see ../synced_table/create_synced_table.sh. Synced tables require CREATE
# CATALOG on the metastore to register the Lakebase-backed UC catalog.
#
# This script is the works-everywhere fallback: it reads the precomputed OLAP
# table from Unity Catalog and bulk-loads it into Lakebase Postgres as a
# point-lookup serving table. It tells the SAME story — "compute heavy
# analytics in the lakehouse, serve them as fast OLTP lookups" — and runs as a
# normal Databricks (serverless) job, which is itself a legitimate reverse-ETL
# pattern.
#
# Run on Databricks (serverless or a cluster). psycopg2 ships in the runtime.
# Pass the connection token in via the env var below (do NOT hard-code it):
#   LAKEBASE_HOST  = ep-...database.us-east-1.cloud.databricks.com
#   LAKEBASE_USER  = your-email@company.com
#   LAKEBASE_TOKEN = output of `databricks postgres generate-database-credential`
# ---------------------------------------------------------------------------
import os
import psycopg2
from psycopg2.extras import execute_values

SOURCE = "vcr_serverless_catalog.shared_data.gold_customer_scorecard"  # adjust catalog for your workspace
HOST   = os.environ["LAKEBASE_HOST"]
USER   = os.environ["LAKEBASE_USER"]
TOKEN  = os.environ["LAKEBASE_TOKEN"]

# Postgres DDL mirrors the UC schema (UC->PG type mapping: STRING->TEXT,
# DECIMAL->NUMERIC, DOUBLE->DOUBLE PRECISION, TIMESTAMP->TIMESTAMP).
DDL = """
DROP TABLE IF EXISTS public.customer_scorecard;
CREATE TABLE public.customer_scorecard (
  customer_id INTEGER PRIMARY KEY,
  customer_name TEXT, region TEXT, segment TEXT, account_manager TEXT,
  join_date DATE, tenure_days INTEGER,
  lifetime_orders BIGINT, lifetime_units BIGINT,
  lifetime_revenue NUMERIC(33,2), lifetime_profit NUMERIC(33,2), lifetime_margin_pct NUMERIC(35,2),
  avg_order_value NUMERIC(27,2), first_order_date DATE, last_order_date DATE,
  r12_orders BIGINT, r12_revenue NUMERIC(33,2), r12_profit NUMERIC(33,2), r12_margin_pct NUMERIC(35,2),
  recency_days INTEGER, frequency_12m BIGINT, monetary_12m NUMERIC(33,2),
  top_category_1 TEXT, top_category_2 TEXT,
  cross_sell_product_id TEXT, cross_sell_product_name TEXT, top_categories TEXT,
  r_score INTEGER, f_score INTEGER, m_score INTEGER,
  revenue_percentile DOUBLE PRECISION, revenue_percentile_in_segment DOUBLE PRECISION,
  at_risk_score DOUBLE PRECISION, rfm_cell TEXT, at_risk_flag BOOLEAN, computed_at TIMESTAMP
);
"""

df   = spark.table(SOURCE)                       # noqa: F821 (spark provided by runtime)
cols = df.columns
rows = [tuple(r) for r in df.collect()]          # 70 rows — small, fine to collect

conn = psycopg2.connect(host=HOST, dbname="databricks_postgres",
                        user=USER, password=TOKEN, sslmode="require")
conn.autocommit = True
cur = conn.cursor()
cur.execute(DDL)
execute_values(cur,
    f"INSERT INTO public.customer_scorecard ({','.join(cols)}) VALUES %s", rows)
# Indexes that make point-lookup / dashboard serving fast at scale.
cur.execute("CREATE INDEX IF NOT EXISTS idx_scorecard_segment ON public.customer_scorecard(segment);")
cur.execute("CREATE INDEX IF NOT EXISTS idx_scorecard_atrisk  ON public.customer_scorecard(at_risk_flag) WHERE at_risk_flag;")
cur.execute("SELECT count(*) FROM public.customer_scorecard;")
print("Loaded rows:", cur.fetchone()[0])         # tested: 70
cur.close(); conn.close()
