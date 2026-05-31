#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Unity Catalog SYNCED TABLE (reverse ETL)  [TESTED]
# ---------------------------------------------------------------------------
# Reverse ETL the precomputed gold scorecard from Unity Catalog into the
# Lakebase project's Postgres database as a managed, refreshable synced table.
# This is the production pattern AND the per-participant workshop pattern: the
# lakehouse owns the heavy compute; Lakebase serves the result for low-latency
# point lookups, kept fresh by a managed Lakeflow pipeline.
#
# NO CREATE CATALOG, NO metastore admin, NO Lakebase-DB catalog registration.
#    The synced-table UC object is created in a NORMAL UC catalog/schema you
#    already have rights to; the Postgres target is selected with spec.branch +
#    spec.postgres_database. Verified on the build workspace as a non-metastore
#    admin: 70 rows synced and queried from Postgres.
#
# IMPORTANT — use the AUTOSCALE-NATIVE verb:
#   USE     databricks postgres create-synced-table            (autoscale projects)
#   NOT     databricks database create-synced-database-table   (PROVISIONED only —
#           errors "Database instance is not found" against an autoscale project)
#
# Minimal privileges (facilitator grants per participant):
#   - UC: USE CATALOG + USE SCHEMA + CREATE TABLE on the schema below,
#         SELECT on the source gold table.
#   - Lakebase: a Postgres role on the project that can write into
#     databricks_postgres. For a service principal create it with
#     `databricks postgres create-role` (auth_method LAKEBASE_OAUTH_V1,
#     identity_type SERVICE_PRINCIPAL) — NOT raw SQL CREATE ROLE.
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"
# A NORMAL UC catalog/schema you can CREATE TABLE in (NOT a Lakebase catalog).
# In the per-participant design, point these at the participant's OWN schema.
UC_CATALOG="${UC_CATALOG:-vcr_serverless_catalog}"     # adjust for your workspace
UC_SCHEMA="${UC_SCHEMA:-shared_data}"
SYNCED_TABLE="${SYNCED_TABLE:-customer_scorecard_synced}"
SOURCE="${SOURCE:-vcr_serverless_catalog.shared_data.gold_customer_scorecard}"

echo "Creating synced table ${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE} (SNAPSHOT)…"
databricks postgres create-synced-table "${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE}" --json "{
  \"spec\": {
    \"branch\": \"projects/${PROJECT}/branches/production\",
    \"postgres_database\": \"databricks_postgres\",
    \"source_table_full_name\": \"${SOURCE}\",
    \"primary_key_columns\": [\"customer_id\"],
    \"scheduling_policy\": \"SNAPSHOT\",
    \"create_database_objects_if_missing\": true,
    \"new_pipeline_spec\": {\"storage_catalog\": \"${UC_CATALOG}\", \"storage_schema\": \"${UC_SCHEMA}\"}
  }
}"
# SNAPSHOT = one-time full copy (no Change Data Feed needed) — ideal for a
# periodically-rebuilt scorecard. For hands-off freshness use TRIGGERED /
# CONTINUOUS (both need CDF on the source:
#   ALTER TABLE <source> SET TBLPROPERTIES (delta.enableChangeDataFeed=true)).

echo
echo "Poll until online (NOTE the 'synced_tables/' prefix required on get):"
echo "  databricks postgres get-synced-table synced_tables/${UC_CATALOG}.${UC_SCHEMA}.${SYNCED_TABLE} -o json"
echo "  -> wait for detailed_state = SYNCED_TABLE_ONLINE_NO_PENDING_UPDATE (~2-4 min, pipeline spin-up)"
echo
echo "Then query it from Postgres — it lands as schema '${UC_SCHEMA}', table '${SYNCED_TABLE}'"
echo "in the project's databricks_postgres DB:"
echo "  source ../scripts/01_connect.sh production"
echo "  psql \"\$PGURI\" -c \"SELECT count(*) FROM ${UC_SCHEMA}.${SYNCED_TABLE};\"   # tested: 70"
echo "  psql \"\$PGURI\" -c \"SELECT * FROM ${UC_SCHEMA}.${SYNCED_TABLE} WHERE customer_id = 42;\""
