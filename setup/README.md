# setup/ - one-action bootstrap

The facilitator imports the repo and runs **`00_bootstrap`** (open it, then **Run all**). It
is idempotent, safe to re-run, and runs on serverless. The committed `data/` JSON is copied
into the UC volume by the notebook itself, so there is no manual upload.

## What it does

1. Configuration: widgets for `catalog`, `schema`, `volume`, `participants_group`,
   `participant_users`, `create_catalog`, `data_dir`. Defaults to the example catalog
   `workshop`; change it to your own.
2. (Optional) create catalog: skipped by default; set `create_catalog=true` to create one.
3. Create the `shared_data` schema and `data` volume.
4. Copy the committed `data/raw` and `data/clean` JSON into the volume.
5. Build the clean tables (`customers`, `products`, `orders`) from `clean/` JSON.
6. Build the summary tables (`product_performance_summary`, `monthly_sales_summary`).
7. Build `gold_customer_scorecard`, the heavy-OLAP point-lookup table keyed by `customer_id`.
8. Build the governed `sales_metrics` metric view (queried with `MEASURE(...)`).
9. Create one `ws_<user>` scratch schema per participant and grant the group read access.
10. Verify: print volume files and row counts.

Group grants are skipped gracefully when the `workshop_participants` group does not exist;
create it and re-run.

## Files

- `00_bootstrap.py` - the single Run-all notebook (the only thing the facilitator runs).
- `00a_create_catalog.sql` - optional catalog creation for your workspace.
- `01_create_schema_and_volume.sql`
- `02_land_raw_data.py` - the repo-to-volume copy step.
- `03_build_clean_tables.sql`
- `04_build_gold_scorecard.sql`
- `05_grants_and_user_schemas.sql`
- `06_build_metric_view.sql` - the governed `sales_metrics` metric view plus a `MEASURE()` check.

The thin per-step scripts (`00a` … `06`) mirror each notebook section for transparency.
`00_bootstrap` is self-contained, so *Run all* needs nothing else.

> Lakebase provisioning and the sync of `gold_customer_scorecard` are handled by the scripts
> in `lakebase/`. This bootstrap only guarantees the table exists in UC.
