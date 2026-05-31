#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  STEP 1 (participant): create your OWN branch
# ---------------------------------------------------------------------------
# A branch is a copy-on-write clone of a branch's data + schema - like
# `git checkout -b`, but for a live Postgres database, with zero copy cost.
#
# In this workshop YOU create your own branch off `production`, then (step 2)
# sync the gold table into it yourself. Name the branch after yourself so the
# cohort doesn't collide, e.g. MY_BRANCH=dev-alice.
#
# You can do this because the facilitator granted the workshop_participants group
# CAN_MANAGE on the project (branch creation needs CAN_MANAGE; CAN_USE is not
# enough). No workspace-admin rights required.
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"
MY_BRANCH="${MY_BRANCH:-dev-$(whoami)}"

# Branch off production (24h TTL so it self-cleans).
#   GOTCHA: source_branch MUST be the full resource path, and you MUST supply one
#   of ttl / expire_time / no_expiry or the create is rejected.
echo "Creating YOUR branch '${MY_BRANCH}' from production…"
databricks postgres create-branch "projects/${PROJECT}" "${MY_BRANCH}" \
  --json "{\"spec\":{\"source_branch\":\"projects/${PROJECT}/branches/production\",\"ttl\":\"86400s\"}}"

echo
echo "Branch created. It gets its own 'primary' endpoint automatically and inherits"
echo "the group Postgres role from production, so you can connect straight away."
echo
echo "Next (step 2): sync the gold table into THIS branch:"
echo "  PROJECT=${PROJECT} MY_BRANCH=${MY_BRANCH} bash lakebase/synced_table/create_synced_table.sh"
echo
echo "Then (step 3) connect to your branch and run point lookups:"
echo "  source lakebase/scripts/01_connect.sh ${MY_BRANCH}"
echo "  psql \"\$PGURI\" -f lakebase/sql/point_lookups.sql"
echo
echo "--- Optional: see copy-on-write isolation ---"
echo "After step 2 has synced data into your branch, you can mutate your branch and"
echo "confirm production (and every other participant's branch) is untouched. The synced"
echo "table lands in your own ws_<user> schema, so use that prefix:"
echo "  source lakebase/scripts/01_connect.sh ${MY_BRANCH}"
echo "  psql \"\$PGURI\" -c \"DELETE FROM <your-ws-schema>.customer_scorecard_synced WHERE NOT at_risk_flag;\""
echo "  psql \"\$PGURI\" -c \"SELECT count(*) FROM <your-ws-schema>.customer_scorecard_synced;\"   # fewer rows on YOUR branch only"
