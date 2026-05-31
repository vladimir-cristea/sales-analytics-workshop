# setup/ - one-action bootstrap

The facilitator imports the repo and runs **`00_bootstrap`** (open it → **Run all**). It is
idempotent and safe to re-run. Runs on **serverless**.

## What it does

| § | Step | Notes |
|---|------|-------|
| 1 | Configuration | Widgets for `catalog`, `schema`, `volume`, `participants_group`, `participant_users`, `create_catalog`, `data_dir`. Defaults to the example catalog `vcr_serverless_catalog`; change it to your own. |
| 2 | _(optional)_ create catalog | Skipped by default; set `create_catalog=true` to create a fresh catalog on your workspace. |
| 3 | Create schema + volume | `shared_data` schema + `data` volume. |
| 4 | **Copy committed JSON → volume** | Reads the repo's `data/raw` + `data/clean` and copies into the volume - **no manual upload**. See the gotcha note below. |
| 5 | Build clean tables | `customers`, `products`, `orders` from `clean/` JSON. |
| 6 | Build summary tables | `product_performance_summary`, `monthly_sales_summary`. |
| 7 | Build `gold_customer_scorecard` | Heavy-OLAP point-lookup table keyed by `customer_id`. |
| 7b | Build `sales_metrics` metric view | Governed UC metric view (YAML) of KPIs over `orders` joined to `customers` + `products`. Queried with `MEASURE(...)`. |
| 8 | Per-user schemas + grants | One `ws_<user>` scratch schema per participant; read grants to the group (incl. `sales_metrics`). |
| 9 | Verify | Prints volume files + row counts. |

Thin per-step scripts (`00a` … `05`) mirror each section for transparency. `00_bootstrap`
is self-contained, so _Run all_ needs nothing else.

## Files

- `00_bootstrap.py` - the single Run-all notebook (the only thing the facilitator runs).
- `00a_create_catalog.sql` - optional catalog creation for your workspace.
- `01_create_schema_and_volume.sql`
- `02_land_raw_data.py` - the repo→volume copy step.
- `03_build_clean_tables.sql`
- `04_build_gold_scorecard.sql`
- `05_grants_and_user_schemas.sql`
- `06_build_metric_view.sql` - the governed `sales_metrics` metric view + a `MEASURE()` check.

## Volume-copy gotcha - what worked

Copying repo files into a UC volume on serverless has historically been flaky. The
`copy_into_volume` helper is belt-and-braces: it tries three methods **in order** and
records which succeeded:

1. **FUSE write** - `with open(volume_path, "wb") as f: f.write(bytes)` after reading the
   source from `/Workspace/...`. ← the method used by default.
2. **`dbutils.fs.cp(f"file:{src}", dst)`** - explicit `file:` scheme. (fallback)
3. **SDK Files API** - `WorkspaceClient().files.upload(dst, BytesIO(bytes), overwrite=True)`,
   a REST upload that is FUSE-independent. (fallback)

Method 1 is used by default; the fallbacks make the step robust on workspaces where direct
FUSE writes to `/Volumes` fail.

The repo's `data/` folder is located automatically from the notebook's own path
(`repo_root/data`), so the copy works regardless of who imports the repo or where. An
explicit `data_dir` widget is available as an override.

## What the bootstrap produces

After _Run all_ (idempotent, safe to re-run from a clean slate via `DROP SCHEMA … CASCADE`):

| Object | Rows |
|--------|-----:|
| customers | 70 |
| products | 34 |
| orders | 2,200 |
| product_performance_summary | 34 |
| monthly_sales_summary | 459 |
| gold_customer_scorecard | 70 |

The `sales_metrics` metric view exposes the governed KPIs (queried with `MEASURE(...)`).

All 6 JSON files land under `/Volumes/<catalog>/shared_data/data/{raw,clean}/`. Per-user
scratch schemas are created. Group grants are skipped gracefully when the
`workshop_participants` group does not exist (create it and re-run).

> Lakebase instance provisioning + sync of `gold_customer_scorecard` is handled by the
> `lakebase` teammate. This bootstrap only guarantees the table exists in UC.
