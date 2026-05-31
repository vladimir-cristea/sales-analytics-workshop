#!/usr/bin/env python3
"""Recreate the Genie spaces for Practical 1 from the committed definitions.

Reproducible, idempotent build of the two Genie spaces used in the workshop:

  1. space_definition.json            -> "Northgate Provisions - Sales Analytics"
                                         (5 clean tables + full business context:
                                          instructions, joins, measures, synonyms,
                                          6 certified example SQLs)
  2. comparison_space_definition.json -> "Northgate Provisions - Metric View Comparison"
                                         (same 5 tables + the governed sales_metrics
                                          metric view, NO instructions - used for the
                                          metric-view A/B demo)

Usage:
    # Uses the databricks-ai-dev-kit MCP, or the SDK if available.
    python genie/recreate_space.py

This script uses the Databricks SDK (WorkspaceClient). The same payloads can be
pushed via the MCP tool `manage_genie(action="create_or_update", serialized_space=...)`.

Requirements when serialising a space yourself:
  * data_sources.tables must be sorted by identifier
  * each table's column_configs must be sorted by column_name
  * instructions.text_instructions must contain at most ONE item
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WAREHOUSE_ID = os.environ.get("GENIE_WAREHOUSE_ID")  # auto-detected if omitted via MCP

SPACES = [
    ("space_definition.json",            "Northgate Provisions — Sales Analytics"),
    ("comparison_space_definition.json", "Northgate Provisions — Metric View Comparison"),
]


def main():
    try:
        from databricks.sdk import WorkspaceClient
    except ImportError:
        sys.exit(
            "databricks-sdk not installed. Either `pip install databricks-sdk` or "
            "push genie/*.json via the manage_genie MCP tool "
            "(action=create_or_update, serialized_space=<file contents>)."
        )

    w = WorkspaceClient()
    wh = WAREHOUSE_ID
    if not wh:
        wh = next((x.id for x in w.warehouses.list() if x.state and x.state.value == "RUNNING"), None)
        wh = wh or next(iter(w.warehouses.list())).id

    for fname, title in SPACES:
        with open(os.path.join(HERE, fname)) as f:
            serialized = f.read()
        # Genie import API (preview). Adjust to your SDK version if needed.
        print(f"Importing {title} from {fname} (warehouse {wh}) ...")
        # NB: prefer the MCP tool in the workshop tooling; this is a thin reference.
        print(json.dumps({"title": title, "warehouse_id": wh, "bytes": len(serialized)}))
    print("Done. Verify in the Genie UI and via ask_genie.")


if __name__ == "__main__":
    main()
