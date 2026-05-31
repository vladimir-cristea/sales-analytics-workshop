#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Step 0: provision an Autoscaling project
# ---------------------------------------------------------------------------
# Lakebase Autoscaling = managed PostgreSQL with Git-style branching, instant
# point-in-time restore, scale-to-zero and read replicas. A "project" is the
# top-level container; it ships with a default `production` branch and a
# read/write compute endpoint named `primary`.
#
# Prereqs: Databricks CLI >= 0.240, authenticated (`databricks auth login`).
# GOTCHA: a deleted project/branch name stays reserved for several minutes —
#         always provision with a FRESH name.
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

# Tested result (build workspace, 2026-05-31):
#   project: projects/workshop-scorecard
#   branch:  projects/workshop-scorecard/branches/production
#            endpoint primary -> ep-spring-waterfall-XXXX.database.us-east-1.cloud.databricks.com
