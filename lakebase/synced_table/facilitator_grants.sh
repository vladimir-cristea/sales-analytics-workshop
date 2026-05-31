#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Facilitator enablement: GROUP-based, run ONCE
# ---------------------------------------------------------------------------
# Goal: enable all ~12 participants to create their own synced table WITHOUT
# hand-granting each person. Everything below is granted to the
# `workshop_participants` GROUP a single time — no per-participant loop.
#
# PROVEN on the build workspace (zero-privilege identity, no workspace/metastore
# admin): given exactly these grants, a participant runs `postgres
# create-synced-table` into their own schema and reads it from Postgres.
# Verified group-grantable: the Postgres role (identity_type=GROUP) AND the
# project CAN_USE both accept a group, so even those are one-time group grants.
#
# PREREQ: `workshop_participants` must be an ACCOUNT-level group (UC resolves
# grant principals at the account level; a workspace-local group will fail with
# "Could not find principal"). The two Lakebase grants (role, project CAN_USE)
# are workspace-level and accept either, but use the account group for consistency.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT="${PROJECT:-workshop-scorecard}"
CATALOG="${CATALOG:-vcr_serverless_catalog}"           # adjust for your workspace
GROUP="${GROUP:-workshop_participants}"
SOURCE_SCHEMA="${SOURCE_SCHEMA:-${CATALOG}.shared_data}"          # shared fallback source
SOURCE_TABLE="${SOURCE_TABLE:-${CATALOG}.shared_data.gold_customer_scorecard}"

echo "== UC grants (to the group, once) =="
databricks grants update catalog "${CATALOG}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"USE CATALOG\"]}]}"
# Source access for the SHARED fallback table. (If participants sync their OWN
# gold table from the SDP lab, they already own their schema, so this and their
# target-schema CREATE TABLE are already covered — nothing extra to grant.)
databricks grants update schema "${SOURCE_SCHEMA}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"USE SCHEMA\"]}]}"
databricks grants update table "${SOURCE_TABLE}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"SELECT\"]}]}"
# If participants instead share ONE target schema, grant it once too:
#   databricks grants update schema ${CATALOG}.<shared_target_schema> \
#     --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"USE SCHEMA\",\"CREATE TABLE\"]}]}"

echo "== Lakebase grants (to the group, once) =="
# (a) ONE Postgres role for the whole group — verified working with
#     identity_type=GROUP. Use create-role, NOT raw SQL (raw SQL leaves NO_LOGIN
#     and OAuth fails).
databricks postgres create-role "projects/${PROJECT}/branches/production" --json "{
  \"spec\": {\"auth_method\": \"LAKEBASE_OAUTH_V1\", \"identity_type\": \"GROUP\", \"postgres_role\": \"${GROUP}\"}
}"
# (b) CAN_USE on the Database project (workspace permission). The permissions
#     object id is the PROJECT_ID (e.g. workshop-scorecard), not its uid.
databricks permissions update database-projects "${PROJECT}" --json "{
  \"access_control_list\": [{\"group_name\": \"${GROUP}\", \"permission_level\": \"CAN_USE\"}]
}"

echo "Done — every member of ${GROUP} can now create + read their own synced table."

# ---------------------------------------------------------------------------
# Per-identity fallback (only if you can't/won't use a group): loop the role +
# project grant over a participant list, and grant UC per principal.
#   for P in alice@co.com bob@co.com …; do
#     databricks postgres create-role projects/${PROJECT}/branches/production \
#       --json "{\"spec\":{\"auth_method\":\"LAKEBASE_OAUTH_V1\",\"identity_type\":\"USER\",\"postgres_role\":\"$P\"}}"
#     databricks permissions update database-projects ${PROJECT} \
#       --json "{\"access_control_list\":[{\"user_name\":\"$P\",\"permission_level\":\"CAN_USE\"}]}"
#   done
# ---------------------------------------------------------------------------
