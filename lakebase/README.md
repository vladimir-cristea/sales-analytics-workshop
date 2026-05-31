# lakebase/

Serve the pre-computed `gold_customer_scorecard` from managed Lakebase PostgreSQL for
low-latency point lookups, then explore branching, point-in-time restore and read replicas.
Lakebase is real Postgres (v17): same wire protocol, same `psql`, same `EXPLAIN`.

`gold_customer_scorecard` is guaranteed to exist in UC by `setup/00_bootstrap`. Everything
else is created by the scripts here.

## Prerequisites

- Databricks CLI >= 0.240, authenticated to your workspace.
- `psql` (PostgreSQL 14+ client).
- The bootstrap has run, so `…shared_data.gold_customer_scorecard` exists.

## Scripts (run in order)

| Path | What it does |
|------|--------------|
| `scripts/00_provision.sh` | Create the Lakebase Autoscaling project (pg17) with a `production` branch and primary endpoint. |
| `scripts/01_connect.sh` | Connection helper: resolves the host and mints a fresh ~1h OAuth token, exports `$PGURI` for `psql`. `source` it. |
| `synced_table/create_synced_table.sh` | Preferred: create a managed synced table (reverse ETL) of the gold table into `databricks_postgres`. No CREATE CATALOG / metastore admin. |
| `scripts/02_load_scorecard.py` | Works-everywhere alternative: read the UC gold table and bulk-load into Postgres as a Databricks job. |
| `sql/point_lookups.sql` | Point-lookup queries by `customer_id`. |
| `scripts/03_branch_demo.sh` | Git-style copy-on-write branch plus isolation check. |
| `scripts/04_pitr_demo.sh` | Accidental delete then point-in-time restore via `source_branch_time`. |
| `scripts/05_read_replica.sh` | (Optional) dedicated read-only endpoint. |
| `scripts/99_cleanup.sh` | Tear the project down. |

Use the autoscale-native `databricks postgres create-synced-table` (not
`databricks database create-synced-database-table`, which is provisioned-only).

## Facilitator grants (run once)

`synced_table/facilitator_grants.sh` enables the whole cohort to create their own synced
tables without workspace-admin or metastore-admin rights, by granting to the
`workshop_participants` group a single time (no per-participant loop):
- UC: `USE CATALOG`; `USE SCHEMA` + `CREATE TABLE` on the participant schema; `USE SCHEMA` +
  `SELECT` on the source gold table.
- Lakebase: one Postgres role with `identity_type=GROUP` via `databricks postgres create-role`
  (not raw SQL), and `CAN_USE` on the database project via `databricks permissions update`.

`workshop_participants` must be an account-level group (UC resolves grant principals at the
account level). The project `CAN_USE` grant is the easy-to-miss one.

## Connecting (token auth, no secrets)

Lakebase auth is a short-lived (~1h) Databricks OAuth token used as the Postgres password,
over TLS. The Postgres role is your Databricks identity (your email). Never store a token;
`scripts/01_connect.sh` mints one per session and exports `$PGURI`.

```bash
source lakebase/scripts/01_connect.sh production
psql "$PGURI" -f lakebase/sql/point_lookups.sql
```

## Cleanup

```bash
PROJECT=workshop-scorecard bash lakebase/scripts/99_cleanup.sh
```
