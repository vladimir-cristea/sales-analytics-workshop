# genie/

Reference Genie space definitions for the Northgate Provisions Co. tables.

The Genie practical has participants **build and curate their own space** from scratch (create
it, add the data sources, then add business context: instructions, joins, SQL expressions,
sample questions, synonyms and descriptions). That hands-on build is the exercise, so these
files are **not needed to run it.**

They are an **optional facilitator reference**: a ready-made, fully-curated space to fall back
on if you are short on time, or to hold up as a worked example of what good context looks like.

## Files

| File | Purpose |
|------|---------|
| `space_definition.json` | A fully curated example space: the tables plus business context (joins, measures, synonyms, business definitions, example questions). |
| `base_only_space_definition.json` | Summary tables only, no metric view - the "without" arm if you want to demo the metric-view difference yourself. |
| `comparison_space_definition.json` | The governed `sales_metrics` metric view - the "with" arm of that same comparison. |
| `recreate_space.py` | Rebuilds these spaces from the JSON. |

## Recreating a space

Preferred path is the Databricks MCP:
`manage_genie(action="create_or_update", serialized_space=<file contents>)`.
Otherwise run `recreate_space.py`.

When editing the JSON: tables must be sorted by identifier, `column_configs` sorted by
column_name, and `instructions.text_instructions` must contain at most one item.

> `gold_customer_scorecard` is intentionally not in any space; that table belongs to the
> Lakebase topic.
