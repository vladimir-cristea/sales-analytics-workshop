#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Practical 3 - Lakebase  •  Cleanup
# ---------------------------------------------------------------------------
# Deletes the whole project (all branches, endpoints, data). The project name
# stays reserved for a few minutes after deletion - use a fresh name next time.
# ---------------------------------------------------------------------------
set -euo pipefail
PROJECT="${PROJECT:-workshop-scorecard}"

# Child branches must go before the project if deleting individually; deleting the
# project cascades everything in one call:
databricks postgres delete-project "projects/${PROJECT}"
echo "Deleted projects/${PROJECT}."

# If you created a UC synced table + Lakebase catalog (see ../synced_table), also:
#   databricks postgres delete-synced-table {catalog}.{schema}.{table}
#   databricks postgres delete-catalog catalogs/{catalog_id}
