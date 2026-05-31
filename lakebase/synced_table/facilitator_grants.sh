#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  Facilitator enablement: GROUP-based, run ONCE
# ---------------------------------------------------------------------------
# This is the standalone CLI equivalent of the opt-in Lakebase step in
# setup/00_bootstrap (provision_lakebase=true). Use whichever you prefer - the
# notebook widget or this script. It does SETUP ONLY and syncs NOTHING.
#
# Goal: enable all ~12 participants to create their OWN branch and sync the gold
# table into it WITHOUT hand-granting each person. Everything below is granted to
# the `workshop_participants` GROUP a single time - no per-participant loop.
#
# Verified end-to-end as a non-admin: with exactly these grants, a participant
# who is only a group member can (a) create their own branch and (b) create a
# synced table into that branch, then read it from Postgres.
#
# THE GRANT THAT MATTERS MOST: project CAN_MANAGE (not CAN_USE).
#   Branch CREATION requires CAN_MANAGE. CAN_USE only lets a member connect to
#   existing branches; creating a branch with CAN_USE is rejected with
#   "not authorized ... assign 'Can Manage' for Database project".
#
# PREREQ: `workshop_participants` must be an ACCOUNT-level group (UC resolves
# grant principals at the account level; a workspace-local group fails with
# "Could not find principal"). The two Lakebase grants accept either, but use the
# account group for consistency.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT="${PROJECT:-workshop-scorecard}"
CATALOG="${CATALOG:-workshop}"           # adjust for your workspace
GROUP="${GROUP:-workshop_participants}"
SOURCE_SCHEMA="${SOURCE_SCHEMA:-${CATALOG}.shared_data}"
SOURCE_TABLE="${SOURCE_TABLE:-${CATALOG}.shared_data.gold_customer_scorecard}"

echo "== UC grants (to the group, once) =="
# A participant reads the source gold table and writes the synced-table UC object
# into their OWN ws_<user> scratch schema. setup/00_bootstrap already grants
# USE CATALOG, USE SCHEMA+SELECT on shared_data, and USE SCHEMA+CREATE TABLE on
# each ws_<user> schema. These two lines make this script self-sufficient if you
# run it instead of the bootstrap step.
databricks grants update catalog "${CATALOG}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"USE CATALOG\"]}]}"
databricks grants update schema "${SOURCE_SCHEMA}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"USE SCHEMA\",\"SELECT\"]}]}"
databricks grants update table "${SOURCE_TABLE}" \
  --json "{\"changes\":[{\"principal\":\"${GROUP}\",\"add\":[\"SELECT\"]}]}"

echo "== Lakebase grants (to the group, once) =="
# (a) ONE Postgres role for the whole group, identity_type=GROUP. Use create-role,
#     NOT raw SQL (raw SQL leaves NO_LOGIN and OAuth fails). Copy-on-write branches
#     inherit this role, so a participant's own branch is reachable with no extra role.
databricks postgres create-role "projects/${PROJECT}/branches/production" --json "{
  \"spec\": {\"auth_method\": \"LAKEBASE_OAUTH_V1\", \"identity_type\": \"GROUP\", \"postgres_role\": \"${GROUP}\"}
}"
# (b) CAN_MANAGE on the Database project. REQUIRED for branch creation (CAN_USE is
#     NOT enough). The permissions object id is the PROJECT_ID, not its uid.
databricks permissions update database-projects "${PROJECT}" --json "{
  \"access_control_list\": [{\"group_name\": \"${GROUP}\", \"permission_level\": \"CAN_MANAGE\"}]
}"

echo "Done - every member of ${GROUP} can now create their OWN branch and sync the gold table into it."

# ---------------------------------------------------------------------------
# Per-identity fallback (only if you can't/won't use a group): loop the role +
# project grant over a participant list, and grant UC per principal.
#   for P in alice@co.com bob@co.com …; do
#     databricks postgres create-role projects/${PROJECT}/branches/production \
#       --json "{\"spec\":{\"auth_method\":\"LAKEBASE_OAUTH_V1\",\"identity_type\":\"USER\",\"postgres_role\":\"$P\"}}"
#     databricks permissions update database-projects ${PROJECT} \
#       --json "{\"access_control_list\":[{\"user_name\":\"$P\",\"permission_level\":\"CAN_MANAGE\"}]}"
#   done
# ---------------------------------------------------------------------------
