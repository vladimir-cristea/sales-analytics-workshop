#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  STEP 2 (participant): sync the gold table into YOUR branch
# ---------------------------------------------------------------------------
# This is the teaching moment: "look how easy". YOU reverse-ETL the precomputed
# gold scorecard from Unity Catalog into YOUR OWN branch's Postgres database as a
# managed, refreshable synced table. The lakehouse owns the heavy compute;
# Lakebase serves the result for low-latency point lookups, kept fresh by a
# managed Lakeflow pipeline.
#
# You create your branch first (step 1, scripts/03_branch_demo.sh), then run this
# to sync into it. The facilitator does NOT pre-sync anything.
#
# NO CREATE CATALOG, NO metastore admin, NO Lakebase-DB catalog registration.
#    The synced-table UC object is created in your OWN ws_<user> scratch schema
#    (you already have CREATE TABLE there); the Postgres target is selected with
#    spec.branch + spec.postgres_database.
#
# IMPORTANT - use the AUTOSCALE-NATIVE verb:
#   USE     databricks postgres create-synced-table            (autoscale projects)
#   NOT     databricks database create-synced-database-table   (PROVISIONED only -
#           errors "Database instance is not found" against an autoscale project)
#
# Privileges you already have (granted to workshop_participants by the bootstrap):
#   - UC: USE CATALOG; USE SCHEMA + SELECT on shared_data (the source);
#         USE SCHEMA + CREATE TABLE on your own ws_<user> schema (the target).
#   - Lakebase: the group Postgres role (inherited by your branch) + project
#     CAN_MANAGE (which also let you create the branch in step 1).
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"
MY_BRANCH="${MY_BRANCH:-dev-$(whoami)}"      # the branch you created in step 1
# Your OWN UC scratch schema (created by setup/00_bootstrap as ws_<your-email>).
# A NORMAL UC catalog/schema you can CREATE TABLE in (NOT a Lakebase catalog).
UC_CATALOG="${UC_CATALOG:-workshop}"         # adjust for your workspace
UC_SCHEMA="${UC_SCHEMA:?Set UC_SCHEMA to your own ws_<user> scratch schema, e.g. ws_alice_example_com}"
SYNCED_TABLE="${SYNCED_TABLE:-customer_scorecard_synced}"
SOURCE="${SOURCE:-${UC_CATALOG}.shared_data.gold_customer_scorecard}"

echo "Syncing ${SOURCE}"
echo "  -> UC object ${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE}"
echo "  -> YOUR branch projects/${PROJECT}/branches/${MY_BRANCH}, db databricks_postgres (SNAPSHOT)…"
databricks postgres create-synced-table "${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE}" --json "{
  \"spec\": {
    \"branch\": \"projects/${PROJECT}/branches/${MY_BRANCH}\",
    \"postgres_database\": \"databricks_postgres\",
    \"source_table_full_name\": \"${SOURCE}\",
    \"primary_key_columns\": [\"customer_id\"],
    \"scheduling_policy\": \"SNAPSHOT\",
    \"create_database_objects_if_missing\": true,
    \"new_pipeline_spec\": {\"storage_catalog\": \"${UC_CATALOG}\", \"storage_schema\": \"${UC_SCHEMA}\"}
  }
}"
# SNAPSHOT = one-time full copy (no Change Data Feed needed) - ideal for a
# periodically-rebuilt scorecard. For hands-off freshness use TRIGGERED /
# CONTINUOUS (both need CDF on the source:
#   ALTER TABLE <source> SET TBLPROPERTIES (delta.enableChangeDataFeed=true)).

echo
echo "Poll until online (NOTE the 'synced_tables/' prefix required on get):"
echo "  databricks postgres get-synced-table synced_tables/${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE} -o json"
echo "  -> wait for detailed_state = SYNCED_TABLE_ONLINE_NO_PENDING_UPDATE (~1-4 min, pipeline spin-up)"
echo
echo "Then (step 3) query it from Postgres on YOUR branch. It lands as schema"
echo "'${UC_SCHEMA}', table '${SYNCED_TABLE}' in your branch's databricks_postgres DB:"
echo "  source lakebase/scripts/01_connect.sh ${MY_BRANCH}"
echo "  psql \"\$PGURI\" -c \"SELECT count(*) FROM ${UC_SCHEMA}.${SYNCED_TABLE};\"   # expect: 70"
echo "  psql \"\$PGURI\" -c \"SELECT * FROM ${UC_SCHEMA}.${SYNCED_TABLE} WHERE customer_id = 42;\""
