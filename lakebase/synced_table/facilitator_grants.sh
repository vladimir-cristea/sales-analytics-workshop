#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 — Lakebase  •  Facilitator: grants that let a participant self-sync
# ---------------------------------------------------------------------------
# PROVEN on the build workspace: a principal with NO workspace-admin and NO
# metastore-admin can create its own synced table and read it from Postgres,
# given exactly the grants below. Run ONCE per participant (as the facilitator).
#
# Two groups: Unity Catalog grants + two Lakebase/project grants. The second
# group is the part people miss — a synced table needs BOTH a Postgres role on
# the branch AND `CAN_USE` on the Database project.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT="${PROJECT:-workshop-scorecard}"
CATALOG="${CATALOG:-vcr_serverless_catalog}"            # adjust for your workspace
PARTICIPANT_SCHEMA="${PARTICIPANT_SCHEMA:?e.g. ${CATALOG}.alice}"   # their target schema (catalog.schema)
SOURCE_SCHEMA="${SOURCE_SCHEMA:-${CATALOG}.shared_data}"           # schema of the source gold table
SOURCE_TABLE="${SOURCE_TABLE:-${CATALOG}.shared_data.gold_customer_scorecard}"
PRINCIPAL="${PRINCIPAL:?participant email (USER) or service-principal applicationId}"
# For a human participant use identity_type USER + user_name in the ACL;
# for a service principal use SERVICE_PRINCIPAL + service_principal_name.
IDENTITY_TYPE="${IDENTITY_TYPE:-USER}"
ACL_KEY="${ACL_KEY:-user_name}"   # set to service_principal_name for an SP

echo "== UC grants =="
databricks grants update catalog "${CATALOG}" --json "{\"changes\":[{\"principal\":\"${PRINCIPAL}\",\"add\":[\"USE CATALOG\"]}]}"
databricks grants update schema  "${PARTICIPANT_SCHEMA}" --json "{\"changes\":[{\"principal\":\"${PRINCIPAL}\",\"add\":[\"USE SCHEMA\",\"CREATE TABLE\"]}]}"
# Source access — only needed explicitly for the SHARED fallback source;
# if the participant syncs their OWN gold table (in PARTICIPANT_SCHEMA) this is already covered.
databricks grants update schema "${SOURCE_SCHEMA}" --json "{\"changes\":[{\"principal\":\"${PRINCIPAL}\",\"add\":[\"USE SCHEMA\"]}]}"
databricks grants update table  "${SOURCE_TABLE}"  --json "{\"changes\":[{\"principal\":\"${PRINCIPAL}\",\"add\":[\"SELECT\"]}]}"

echo "== Lakebase grants =="
# (a) a Postgres role on the branch — use create-role, NOT raw SQL CREATE ROLE
#     (raw SQL leaves NO_LOGIN and OAuth fails).
databricks postgres create-role "projects/${PROJECT}/branches/production" --json "{
  \"spec\": {\"auth_method\": \"LAKEBASE_OAUTH_V1\", \"identity_type\": \"${IDENTITY_TYPE}\", \"postgres_role\": \"${PRINCIPAL}\"}
}"
# (b) CAN_USE on the Database project (workspace permission). NOTE: the
#     permissions object id is the PROJECT_ID (e.g. workshop-scorecard), not its uid.
databricks permissions update database-projects "${PROJECT}" --json "{
  \"access_control_list\": [{\"${ACL_KEY}\": \"${PRINCIPAL}\", \"permission_level\": \"CAN_USE\"}]
}"

echo "Done. ${PRINCIPAL} can now run: databricks postgres create-synced-table ${PARTICIPANT_SCHEMA}.<table> …"
