# genie/

Genie space definitions for natural-language analytics over the Northgate Provisions Co.
tables, plus a script to recreate the spaces.

## Files

| File | Purpose |
|------|---------|
| `space_definition.json` | The main curated space: 5 tables plus business context (joins, measures, synonyms, business definitions, example questions). |
| `base_only_space_definition.json` | The "without" arm of the metric-view comparison: pre-aggregated summary tables only, no metric view. |
| `comparison_space_definition.json` | The "with" arm: the governed `sales_metrics` metric view only. |
| `recreate_space.py` | Rebuilds the spaces from the JSON. |

## Recreating a space

Preferred path is the Databricks MCP:
`manage_genie(action="create_or_update", serialized_space=<file contents>)`.
Otherwise run `recreate_space.py`.

When editing the JSON: tables must be sorted by identifier, `column_configs` sorted by
column_name, and `instructions.text_instructions` must contain at most one item.

> `gold_customer_scorecard` is intentionally not in any space; that table belongs to the
> Lakebase topic.
