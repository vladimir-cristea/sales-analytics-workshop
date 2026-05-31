# Sales Analytics Workshop

Generates a synthetic single-company B2B food & beverage sales dataset (fictional
**Northgate Provisions Co.**) and provides Databricks workshop materials for three topics:
Genie, Spark Declarative Pipelines (SDP), and Lakebase.

The exercise instructions participants follow live in the facilitator's slide deck, not in
this repo.

## Setup

The whole environment is provisioned by importing this repo and running a single bootstrap
notebook. The committed raw JSON is copied straight into a Unity Catalog volume by the
bootstrap, so there is no manual data upload.

1. Create an account-level group named **`workshop_participants`** and add every attendee's
   email (*Settings → Identity and Access → Groups*). This is the only manual prerequisite.
2. Import this repo into the workspace (*Workspace → Create → Git folder →* paste the repo URL).
3. Open `setup/00_bootstrap` and click **Run all**.
4. Done. The bootstrap is idempotent and safe to re-run.

If the group does not exist when the bootstrap runs, it completes and skips the group grants;
create the group and re-run to apply them. See [`setup/README.md`](setup/README.md) for detail.

Lakebase (Practical 3) is provisioned by default; set `provision_lakebase=false` to skip the
Lakebase lab. The step degrades gracefully: if Lakebase is not enabled on the workspace, the
bootstrap prints a warning and carries on, leaving the rest of the environment intact.

## Prerequisites

- A Databricks workspace with Unity Catalog and serverless compute enabled.
- A serverless SQL warehouse, with `CAN USE` granted to the participant group.
- An account-level group named `workshop_participants` containing all attendee emails.
- A Unity Catalog catalog to build into. The scripts default to an example catalog named
  `workshop`. On a brand-new workspace, set the bootstrap's `create_catalog` widget to
  `true` on the first run (this needs the `CREATE CATALOG` privilege), or create the catalog
  beforehand. To use a catalog you already have, point the `catalog` widget at it and leave
  `create_catalog` as `false`.

Each participant needs a Databricks account in the `workshop_participants` group and a modern
web browser. There is no local install and no per-participant setup.

## Repository layout

| Path            | Contents                                                                 |
|-----------------|--------------------------------------------------------------------------|
| `setup/`        | Idempotent bootstrap notebook plus thin per-step scripts (schema, volume, tables, scorecard, metric view, grants). |
| `data/`         | Deterministic dataset generator plus committed clean and raw (dirty) JSON, with the schema and seeded data-quality list. |
| `genie/`        | Genie space-definition JSON files and a script to recreate the spaces. |
| `sdp_pipeline/` | Pointer for the Spark Declarative Pipelines topic (built live with Genie Code). |
| `lakebase/`     | Lakebase facilitator setup (provisioned by default; group grants) plus the participant flow: create your own branch, sync `gold_customer_scorecard` into it, point-lookup queries, and PITR. |

## Cleanup

```sql
-- Drops everything the workshop created. (Adjust the catalog name for your environment.)
DROP SCHEMA IF EXISTS workshop.shared_data CASCADE;
```
