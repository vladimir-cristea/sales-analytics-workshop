# lakebase/

**Practical 3 - Lakebase**: serve a pre-computed analytics scorecard from
managed PostgreSQL for low-latency point lookups, then explore branching,
point-in-time restore and read replicas.

> **The angle for this room.** You already know Postgres. Lakebase *is* real
> Postgres (v17) - same wire protocol, same `psql`, same `EXPLAIN`. What's new is
> where the data comes from and what the platform does around it: the heavy
> analytics (RFM scoring, rolling-12-month aggregates, percentiles, cross-sell)
> are computed once in the lakehouse - the kind of query you'd *never* run live
> against your OLTP source - and served here as a plain table keyed by
> `customer_id`. Plus Git-style branches, instant restore and scale-to-zero that
> a normal Postgres box doesn't give you.

---

## What we build

```
Unity Catalog (OLAP)                         Lakebase Autoscaling (OLTP)
┌──────────────────────────────┐            ┌────────────────────────────────┐
│ gold_customer_scorecard       │  reverse   │ project: workshop-scorecard     │
│  • per-customer, heavy RFM     │   ETL      │  branch: production (primary)   │
│  • rolling-12m, percentiles   │  ───────▶  │   └ customer_scorecard (synced) │
│  • rebuilt by the bootstrap   │            │      PK(customer_id) + indexes  │
└──────────────────────────────┘            │  branch: dev-experiment (COW)   │
                                             │  branch: pitr-recover (as-of T0)│
                                             │  endpoint: ro-replica (read-only)│
                                             └────────────────────────────────┘
                                                  ▲ psql / app / Data API (REST)
```

`gold_customer_scorecard` is guaranteed to exist in UC by `setup/00_bootstrap`.
Everything else is created by the scripts in this folder.

---

## Files

| Path | What it does |
|------|--------------|
| `scripts/00_provision.sh`       | Create the Lakebase Autoscaling project (pg17). |
| `scripts/01_connect.sh`         | **Connection helper** - resolves the host and mints a fresh ~1h OAuth token, exports `$PGURI` for `psql`. `source` it. |
| `scripts/02_load_scorecard.py`  | Works-everywhere loader: read the UC gold table, bulk-load into Postgres (runs as a Databricks job). |
| `synced_table/create_synced_table.sh` | **Preferred** path: create a managed **synced table** (reverse ETL) into the project's `databricks_postgres`. No CREATE CATALOG. |
| `synced_table/facilitator_grants.sh` | The minimal grants that let a **non-admin** participant create their own synced table. |
| `sql/point_lookups.sql`         | The point-lookup exercises. |
| `scripts/03_branch_demo.sh`     | Git-style branch + isolation check. |
| `scripts/04_pitr_demo.sh`       | Accidental-delete → point-in-time restore. |
| `scripts/05_read_replica.sh`    | (Optional) dedicated read-only endpoint. |
| `scripts/99_cleanup.sh`         | Tear the project down. |

---

## Prerequisites

- Databricks CLI ≥ 0.240, authenticated to your workspace.
- `psql` (PostgreSQL 14+ client). `psql` is preferred so you don't contend with
  the browser-based SQL editor - though the editor in the Lakebase UI works too.
- The bootstrap has run, so `…shared_data.gold_customer_scorecard` exists.

---

## Walkthrough

### 1. Provision  (`scripts/00_provision.sh`)
Creates project `workshop-scorecard` with a `production` branch and a read/write
`primary` endpoint. **Gotcha:** a deleted name is reserved for a few minutes -
always use a fresh project name.

### 2. Get the data into Postgres

**Preferred - UC synced table (`synced_table/create_synced_table.sh`).** Creates a
managed synced table (`SNAPSHOT`, or `TRIGGERED`/`CONTINUOUS` with Change Data
Feed) that reverse-ETLs the gold table into the project's `databricks_postgres`
and keeps it fresh from the lakehouse. This is the production reverse-ETL pattern,
and what each participant runs in the lab.

> **No CREATE CATALOG, no metastore admin.** The synced-table UC object lives in
> a *normal* UC catalog/schema you already have rights to; the Postgres target is
> selected via `spec.branch` + `spec.postgres_database`. Use the autoscale-native
> **`databricks postgres create-synced-table`** - *not*
> `databricks database create-synced-database-table` (provisioned-only; errors
> "Database instance is not found" against an autoscale project). Tip:
> `get-synced-table` needs the `synced_tables/<catalog.schema.table>` prefix.

**Participant self-serve - group-based enablement, run ONCE (`synced_table/facilitator_grants.sh`).**
A participant with no workspace-admin and no metastore-admin can create their own
synced table and read it from Postgres. The facilitator enables the whole cohort
by granting to the `workshop_participants` **group** a single time (no per-participant
loop - even the Lakebase Postgres role and the project `CAN_USE` accept a group):
- **UC:** `USE CATALOG`; `USE SCHEMA` + `CREATE TABLE` on the participant schema;
  `USE SCHEMA` + `SELECT` on the source gold table.
- **Lakebase:** one Postgres role with `identity_type=GROUP` via
  `databricks postgres create-role` (NOT raw SQL), **and** `CAN_USE` on the Database
  project via `databricks permissions update database-projects <project_id> …`.

The two Lakebase grants - especially the project `CAN_USE` - are the easy-to-miss
ones. Prereq: `workshop_participants` must be an **account-level** group (UC
resolves grant principals at the account level).

**Works-everywhere alternative - loader (`scripts/02_load_scorecard.py`).** A
no-pipeline path (or to script a custom transform on the way in): reads the UC gold
table and bulk-inserts it into `public.customer_scorecard` with a `customer_id`
primary key plus helper indexes. Pass the connection token via env vars (never
hard-code it).

### 3. Point lookups  (`sql/point_lookups.sql`)
```bash
source lakebase/scripts/01_connect.sh production
psql "$PGURI" -f lakebase/sql/point_lookups.sql
```
- **Point lookup by PK** (customer 42) returns one row, sub-millisecond.
- **`EXPLAIN` at this data size shows a `Seq Scan`, not an `Index Scan` - and that's
  expected.** At this row count the whole table fits in a single page, so the planner
  correctly prefers a seq scan (the synced table is range-partitioned on the PK). The
  PK index exists and is what keeps lookups fast *at scale*; to see the index plan
  explicitly, force it: `SET enable_seqscan = off;` → `Index Scan using …_pkey`. The
  honest line for attendees is "sub-millisecond serving; the index proves itself at scale".
- The loader table (`public.customer_scorecard`) is unpartitioned with a partial
  index on `at_risk_flag` for an instant churn worklist.

### 4. Branching  (`scripts/03_branch_demo.sh`)
> **Gotcha:** a branch is a copy-on-write snapshot of the parent *at branch time*.
> Create any pre-baked demo branch **after** the synced table reaches ONLINE -
> a branch taken before the sync finished won't contain the table.

Branch `dev-experiment` off production (copy-on-write - instant, 0 bytes). Change a
row on the branch and confirm production is untouched: the branch is fully isolated.

### 5. Point-in-time restore  (`scripts/04_pitr_demo.sh`)
Capture `T0`, simulate an accidental `DELETE` on production, then branch from
production **as of `T0`** using `source_branch_time`. The recovery branch holds the
data as it was at that instant. No backups, no downtime - you branch from the past.

### 6. (Optional) Read replica  (`scripts/05_read_replica.sh`)
Add a dedicated `ENDPOINT_TYPE_READ_ONLY` endpoint: reads succeed; writes are
rejected with `cannot execute UPDATE in a read-only transaction`.

---

## Connecting (token auth, no secrets)

Lakebase auth = a short-lived (~1h) Databricks **OAuth token used as the Postgres
password**, over TLS. The Postgres **role is your Databricks identity** (your
email). Never store a token; mint one per session:

```bash
EP=projects/workshop-scorecard/branches/production/endpoints/primary
export PGPASSWORD=$(databricks postgres generate-database-credential "$EP" \
  -o json | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
HOST=$(databricks postgres get-endpoint "$EP" -o json \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["status"]["hosts"]["host"])')
psql "host=$HOST dbname=databricks_postgres user=<you>@your-company.com sslmode=require"
```
`scripts/01_connect.sh` wraps all of this - `source` it and use `$PGURI`.

---

## Optional features

| Feature | Status | Notes |
|---------|--------|-------|
| Synced table (reverse ETL) | supported | `databricks postgres create-synced-table` → `databricks_postgres`; queried from Postgres. No CREATE CATALOG / metastore admin. |
| Direct loader (job-based reverse ETL) | supported | Alternative when you want a no-pipeline / custom-transform load. |
| Point lookups by `customer_id` | supported | PK lookup, sub-millisecond. |
| Branching + isolation | supported | Copy-on-write clone; parent untouched. |
| Point-in-time restore | supported | Branch from the past via `source_branch_time`. |
| Read replica | supported | Read-only endpoint; writes rejected. |
| Scale-to-zero | config | Controlled by `suspend_timeout_duration` (default `86400s` on a new branch endpoint; set lower to suspend sooner). Compute wakes on the next connection. |
| Lakebase Data API (PostgREST/REST) | UI-enable | Enable on the project's **Data API** page (creates the `authenticator` role + `pgrst` schema). Then: `curl -H "Authorization: Bearer $TOKEN" "$REST_ENDPOINT/public/customer_scorecard?customer_id=eq.42"`. |
| CDC-to-Delta (Postgres→Delta) | preview | Lakebase Autoscaling does Delta→Postgres reverse ETL today; Postgres→Delta is Preview. |

---

## Cleanup
```bash
PROJECT=workshop-scorecard bash lakebase/scripts/99_cleanup.sh
```
