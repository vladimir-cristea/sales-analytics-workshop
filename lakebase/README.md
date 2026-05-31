# lakebase/

Serve the pre-computed `gold_customer_scorecard` from managed Lakebase PostgreSQL for
low-latency point lookups, then explore branching and point-in-time restore. Lakebase is
real Postgres (v17): same wire protocol, same `psql`, same `EXPLAIN`.

`gold_customer_scorecard` is guaranteed to exist in UC by `setup/00_bootstrap`. The Lakebase
project and the participant group grants are also set up by the bootstrap (the opt-in
`provision_lakebase` step). Everything else in this practical is a **participant action**.

## The model

- **Facilitator (setup only).** Run `setup/00_bootstrap` with `provision_lakebase=true`. It
  get-or-creates the Lakebase Autoscaling project, confirms the default `databricks_postgres`
  database, and grants the `workshop_participants` group exactly the permissions a participant
  needs. The facilitator does **not** sync any table.
- **Each participant (hands-on).** You create your **own branch**, sync the gold Delta table
  into it yourself, then query it with point lookups and explore point-in-time restore. The
  sync is the teaching moment ("look how easy"), so it is your action, not a pre-baked one.

## Prerequisites

- Databricks CLI >= 0.240, authenticated to your workspace.
- `psql` (PostgreSQL 14+ client).
- The bootstrap has run with `provision_lakebase=true`, so the `workshop-scorecard` project
  exists, the `workshop_participants` group has its grants, and
  `…shared_data.gold_customer_scorecard` exists in UC.
- You are a member of the `workshop_participants` group.

## Participant steps (run in order)

| Step | Path | What you do |
|------|------|-------------|
| 1. Create your own branch | `scripts/03_branch_demo.sh` | Branch off `production` into your own copy-on-write branch (name it after yourself). This is yours to break. |
| 2. Sync the gold table into your branch | `synced_table/create_synced_table.sh` | Create a managed synced table (reverse ETL) of the gold table into `databricks_postgres` on **your** branch. The lakehouse owns the heavy compute; Lakebase serves the result. |
| 3. Query it (point lookups) | `scripts/01_connect.sh` + `sql/point_lookups.sql` | Connect to your branch and run single-digit-millisecond point lookups by `customer_id`. "Look, it's real Postgres." |
| 4. Explore point-in-time restore | `scripts/04_pitr_demo.sh` | Simulate an accidental delete and recover by branching from a past moment. |

The works-everywhere alternative loader (`scripts/02_load_scorecard.py`) and the optional
read replica (`scripts/05_read_replica.sh`) are kept for reference.

Use the autoscale-native `databricks postgres create-synced-table` (not
`databricks database create-synced-database-table`, which is provisioned-only).

## Participant permission set (what the bootstrap grants the group)

Verified end-to-end as a non-admin: with exactly these grants a participant who is only a
member of `workshop_participants` can create their own branch, sync the gold table into it,
and read it from Postgres. No workspace-admin or metastore-admin rights.

- **Lakebase:**
  - One group Postgres role on the `production` branch, `identity_type=GROUP`, created with
    `databricks postgres create-role` (never raw SQL `CREATE ROLE`, which leaves the role
    `NO_LOGIN` so OAuth fails). Copy-on-write branches inherit this role, so a participant's
    own branch is reachable without any extra role.
  - **`CAN_MANAGE` on the Database project.** This is the easy-to-miss, must-get-right grant:
    branch *creation* requires `CAN_MANAGE`. `CAN_USE` only lets a member connect to existing
    branches; an attempt to create a branch with `CAN_USE` is rejected with "not authorized
    ... assign 'Can Manage' for Database project".
- **Unity Catalog (already granted by `setup/00_bootstrap` section 8):**
  - `USE CATALOG` on the catalog.
  - `USE SCHEMA` + `SELECT` on `shared_data` (to read the source gold table).
  - `USE SCHEMA` + `CREATE TABLE` on the participant's own `ws_<user>` scratch schema (where
    the synced-table UC object is created).

`workshop_participants` must be an **account-level** group (UC resolves grant principals at
the account level; a workspace-local group fails with "Could not find principal"). The
Lakebase grants (role, project `CAN_MANAGE`) accept either, but use the account group for
consistency.

## Connecting (token auth, no secrets)

Lakebase auth is a short-lived (~1h) Databricks OAuth token used as the Postgres password,
over TLS. The Postgres role is your Databricks identity (your email). Never store a token;
`scripts/01_connect.sh` mints one per session and exports `$PGURI`.

```bash
# Connect to YOUR branch (use the branch name you created in step 1).
source lakebase/scripts/01_connect.sh my-branch
psql "$PGURI" -f lakebase/sql/point_lookups.sql
```

## Cleanup

Drop your own branch and synced table when done. The facilitator tears down the whole project:

```bash
PROJECT=workshop-scorecard bash lakebase/scripts/99_cleanup.sh
```
