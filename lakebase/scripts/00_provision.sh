#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  Step 0 (FACILITATOR): provision an Autoscaling project
# ---------------------------------------------------------------------------
# FACILITATOR-ONLY. setup/00_bootstrap with provision_lakebase=true already does
# this (and grants the group). Run this script only if you prefer the manual CLI
# route or are setting up outside the bootstrap. Participants do NOT run this -
# they create their own branch (scripts/03_branch_demo.sh) on the project you
# provision here.
#
# Lakebase Autoscaling = managed PostgreSQL with Git-style branching, instant
# point-in-time restore, scale-to-zero and read replicas. A "project" is the
# top-level container; it ships with a default `production` branch, a read/write
# compute endpoint named `primary`, and a default `databricks_postgres` database
# (sufficient for the synced-table target - nothing extra to create).
#
# Prereqs: Databricks CLI >= 0.240, authenticated (`databricks auth login`).
# GOTCHA: a deleted project/branch name stays reserved for several minutes -
#         always provision with a FRESH name.
# After provisioning, grant the group: bash ../synced_table/facilitator_grants.sh
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT="${PROJECT:-workshop-scorecard}"

echo "Creating Lakebase Autoscaling project '${PROJECT}' (Postgres 17)…"
databricks postgres create-project "${PROJECT}" \
  --json '{"spec": {"display_name": "Workshop Customer Scorecard", "pg_version": "17"}}'

echo
echo "Project details (branches + endpoint hosts):"
databricks postgres get-project "projects/${PROJECT}" -o json \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); \
print("project:", d["name"]); \
[print(" branch:", b["name"], "->", [e.get("status",{}).get("hosts",{}).get("host") for e in b.get("endpoints",[])]) for b in d.get("branches",[])]'

# Example output:
#   project: projects/workshop-scorecard
#   branch:  projects/workshop-scorecard/branches/production
#            endpoint primary -> ep-<your-endpoint>.database.<region>.cloud.databricks.com
