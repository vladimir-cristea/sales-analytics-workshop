#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  (Optional) Read replica
# ---------------------------------------------------------------------------
# Add a dedicated READ-ONLY compute endpoint to a branch to offload read traffic
# (e.g. dashboards, the Data API) from the primary. Reads succeed; writes are
# rejected with "cannot execute … in a read-only transaction".
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"

echo "Creating read-only endpoint 'ro-replica' on production…"
databricks postgres create-endpoint "projects/${PROJECT}/branches/production" ro-replica \
  --json '{"spec":{"endpoint_type":"ENDPOINT_TYPE_READ_ONLY","autoscaling_limit_min_cu":0.5,"autoscaling_limit_max_cu":1}}'

# Connect to the replica endpoint.
ENDPOINT_ID=ro-replica source "$(dirname "$0")/01_connect.sh" production

echo "=== Read via replica (expect: 70; transaction_read_only = on) ==="
psql "$PGURI" -c "SELECT count(*) AS rows_via_replica FROM public.customer_scorecard;
                  SHOW transaction_read_only;"

echo "=== Write via replica (expect: rejected) ==="
psql "$PGURI" -c "UPDATE public.customer_scorecard SET at_risk_flag = true WHERE customer_id = 1;" || \
  echo "  -> ERROR: cannot execute UPDATE in a read-only transaction (expected)"
