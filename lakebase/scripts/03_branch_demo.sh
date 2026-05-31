#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Git-style BRANCHING + isolation
# ---------------------------------------------------------------------------
# A branch is a copy-on-write clone of a branch's data + schema. Create one,
# change it, and see the parent is untouched — like `git checkout -b`, but for
# a live Postgres database. Great for dev/test against production-shaped data
# with zero copy cost.
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"

# 1) Branch off production (24h TTL so it self-cleans).
#    GOTCHA: source_branch MUST be the full resource path, and you MUST supply
#    one of ttl / expire_time / no_expiry or the create is rejected.
echo "Creating branch 'dev-experiment' from production…"
databricks postgres create-branch "projects/${PROJECT}" dev-experiment \
  --json "{\"spec\":{\"source_branch\":\"projects/${PROJECT}/branches/production\",\"ttl\":\"86400s\"}}"

# 2) Connect to the branch and to production (separate endpoints).
BRANCH_DEMO=1 source "$(dirname "$0")/01_connect.sh" dev-experiment
DEV_URI="$PGURI"
source "$(dirname "$0")/01_connect.sh" production
PROD_URI="$PGURI"

echo "=== Branch is an instant COW clone — already has all rows ==="
psql "$DEV_URI" -c "SELECT count(*) AS rows_on_branch FROM public.customer_scorecard;"   # tested: 70

echo "=== Mutate ONLY the branch ==="
psql "$DEV_URI" \
  -c "DELETE FROM public.customer_scorecard WHERE NOT at_risk_flag;" \
  -c "UPDATE public.customer_scorecard SET customer_name = customer_name || ' [BRANCH EDIT]' WHERE customer_id = 42;" \
  -c "INSERT INTO public.customer_scorecard (customer_id, customer_name, segment, at_risk_flag)
        VALUES (999, 'Branch-only Test Outlet', 'Independent', true);"

echo "=== Branch after edits (tested: 14 rows; cid 42 renamed; cid 999 present) ==="
psql "$DEV_URI" -c "SELECT count(*) FROM public.customer_scorecard;
                    SELECT customer_id, customer_name FROM public.customer_scorecard WHERE customer_id IN (42,999);"

echo "=== PRODUCTION is UNCHANGED — isolation proven (tested: 70 rows; cid 42 original; no cid 999) ==="
psql "$PROD_URI" -c "SELECT count(*) FROM public.customer_scorecard;
                     SELECT customer_id, customer_name FROM public.customer_scorecard WHERE customer_id IN (42,999);"
