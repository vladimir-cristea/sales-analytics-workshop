#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  Connection helper (psql)
# ---------------------------------------------------------------------------
# Lakebase authenticates with a short-lived (~1h) Databricks OAuth token used
# as the Postgres password, over TLS (sslmode=require). The Postgres ROLE is
# your Databricks identity (your email). NEVER hard-code a token - generate a
# fresh one each session, as below. Nothing here is a secret at rest.
#
# Usage:
#   source lakebase/scripts/01_connect.sh                 # production / primary
#   source lakebase/scripts/01_connect.sh dev-alice       # YOUR named branch
#   ENDPOINT_ID=ro-replica source lakebase/scripts/01_connect.sh   # a replica
# Then (the synced table lands in your ws_<user> schema):
#   psql "$PGURI" -c "SELECT count(*) FROM <your-ws-schema>.customer_scorecard_synced;"
# ---------------------------------------------------------------------------
PROJECT="${PROJECT:-workshop-scorecard}"
BRANCH="${1:-production}"
ENDPOINT_ID="${ENDPOINT_ID:-primary}"
ENDPOINT="projects/${PROJECT}/branches/${BRANCH}/endpoints/${ENDPOINT_ID}"

# Resolve the endpoint host (output-only; not a secret).
PGHOST=$(databricks postgres get-endpoint "${ENDPOINT}" -o json \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"]["hosts"]["host"])')

# Generate a fresh OAuth token scoped to this endpoint, valid ~1 hour.
export PGPASSWORD=$(databricks postgres generate-database-credential "${ENDPOINT}" \
  -o json | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

export PGUSER=$(databricks current-user me -o json | python3 -c 'import sys,json; print(json.load(sys.stdin)["userName"])')
export PGURI="host=${PGHOST} dbname=databricks_postgres user=${PGUSER} sslmode=require"

echo "Connected vars set for ${ENDPOINT}"
echo "  host = ${PGHOST}"
echo "  user = ${PGUSER}"
echo "Try:  psql \"\$PGURI\" -c 'SELECT current_database(), current_user;'"
