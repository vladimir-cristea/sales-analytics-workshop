#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  STEP 4 (participant): point-in-time restore (PITR)
# ---------------------------------------------------------------------------
# Lakebase keeps continuous history. You "restore" by branching from a PAST
# moment - no backup files, no downtime. Here you simulate an accidental DELETE
# on YOUR branch and recover the lost rows by branching from just before it.
#   PITR field: BranchSpec.source_branch_time (RFC3339 UTC).
#
# Run this after step 2 has synced the scorecard into your branch. Set
# MY_BRANCH and UC_SCHEMA to the same values you used in steps 1-2.
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"
MY_BRANCH="${MY_BRANCH:-dev-$(whoami)}"
UC_SCHEMA="${UC_SCHEMA:?Set UC_SCHEMA to your own ws_<user> schema, e.g. ws_alice_example_com}"
TABLE="${UC_SCHEMA}.customer_scorecard_synced"

source "$(dirname "$0")/01_connect.sh" "${MY_BRANCH}"
MY_URI="$PGURI"

# 1) Capture a restore point, then wait a beat so it is safely in the past.
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Restore point T0 = $T0"
sleep 8

# 2) Oops - accidental destructive change on your branch.
echo "Simulating accidental deletion (customer_id > 50)…"
psql "$MY_URI" -c "DELETE FROM ${TABLE} WHERE customer_id > 50;"
psql "$MY_URI" -c "SELECT count(*) AS rows_after_oops FROM ${TABLE};"  # expect: 50

# 3) Recover: branch from YOUR branch AS OF T0 (before the delete).
echo "Creating recovery branch '${MY_BRANCH}-recover' as of $T0…"
databricks postgres create-branch "projects/${PROJECT}" "${MY_BRANCH}-recover" \
  --json "{\"spec\":{\"source_branch\":\"projects/${PROJECT}/branches/${MY_BRANCH}\",\"source_branch_time\":\"${T0}\",\"ttl\":\"86400s\"}}"

# 4) The recovery branch holds the pre-deletion data.
source "$(dirname "$0")/01_connect.sh" "${MY_BRANCH}-recover"
psql "$PGURI" -c "SELECT count(*) AS recovered_rows, max(customer_id) AS max_id FROM ${TABLE};"  # expect: 70 / 70

echo
echo "Recover the lost rows back into your branch by reading across branches, e.g.:"
echo "  pg_dump the missing rows from the recovery branch and \\copy them into your branch,"
echo "  or simply promote the recovery branch. Your branch stays online throughout."
