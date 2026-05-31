#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  Point-in-time restore (PITR / instant restore)
# ---------------------------------------------------------------------------
# Lakebase keeps continuous history. You "restore" by branching from a PAST
# moment - no backup files, no downtime. Here we simulate an accidental DELETE
# on production and recover the lost rows by branching from just before it.
#   PITR field: BranchSpec.source_branch_time (RFC3339 UTC).
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"

source "$(dirname "$0")/01_connect.sh" production
PROD_URI="$PGURI"

# 1) Capture a restore point, then wait a beat so it is safely in the past.
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Restore point T0 = $T0"
sleep 8

# 2) Oops - accidental destructive change on production.
echo "Simulating accidental deletion (customer_id > 50)…"
psql "$PROD_URI" -c "DELETE FROM public.customer_scorecard WHERE customer_id > 50;"
psql "$PROD_URI" -c "SELECT count(*) AS rows_after_oops FROM public.customer_scorecard;"  # expect: 50

# 3) Recover: branch from production AS OF T0 (before the delete).
echo "Creating recovery branch 'pitr-recover' as of $T0…"
databricks postgres create-branch "projects/${PROJECT}" pitr-recover \
  --json "{\"spec\":{\"source_branch\":\"projects/${PROJECT}/branches/production\",\"source_branch_time\":\"${T0}\",\"ttl\":\"86400s\"}}"

# 4) The recovery branch holds the pre-deletion data.
source "$(dirname "$0")/01_connect.sh" pitr-recover
psql "$PGURI" -c "SELECT count(*) AS recovered_rows, max(customer_id) AS max_id FROM public.customer_scorecard;"  # expect: 70 / 50->70

echo
echo "Recover the lost rows back into production by reading across branches, e.g.:"
echo "  pg_dump the missing rows from the recovery branch and \\copy them into production,"
echo "  or simply promote the recovery branch. Production stays online throughout."
