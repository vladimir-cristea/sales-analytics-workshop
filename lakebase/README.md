# lakebase/

**Practical 3 — Lakebase**: serve a pre-computed analytics scorecard from
managed PostgreSQL for low-latency point lookups, then explore branching,
point-in-time restore and read replicas.

> **The angle for this room.** You already know Postgres. Lakebase *is* real
> Postgres (v17) — same wire protocol, same `psql`, same `EXPLAIN`. What's new is
> where the data comes from and what the platform does around it: the heavy
> analytics (RFM scoring, rolling-12-month aggregates, percentiles, cross-sell)
> are computed once in the lakehouse — the kind of query you'd *never* run live
> against your OLTP source — and served here as a plain table keyed by
> `customer_id`. Plus Git-style branches, instant restore and scale-to-zero that
> a normal Postgres box doesn't give you.

---

## What we build

```
Unity Catalog (OLAP)                         Lakebase Autoscaling (OLTP)
┌──────────────────────────────┐            ┌────────────────────────────────┐
│ gold_customer_scorecard       │  reverse   │ project: workshop-scorecard     │
│  • 70 customers, 36 columns   │   ETL      │  branch: production (primary)   │
│  • heavy window/RFM compute   │  ───────▶  │   └ public.customer_scorecard   │
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
| `scripts/01_connect.sh`         | **Connection helper** — resolves the host and mints a fresh ~1h OAuth token, exports `$PGURI` for `psql`. `source` it. |
| `scripts/02_load_scorecard.py`  | Works-everywhere loader: read the UC gold table, bulk-load into Postgres (runs as a Databricks job). |
| `synced_table/create_synced_table.sh` | **Preferred** path: create a managed **synced table** (reverse ETL) into the project's `databricks_postgres`. No CREATE CATALOG. Tested ✓. |
| `sql/point_lookups.sql`         | The point-lookup exercises. |
| `scripts/03_branch_demo.sh`     | Git-style branch + isolation proof. |
| `scripts/04_pitr_demo.sh`       | Accidental-delete → point-in-time restore. |
| `scripts/05_read_replica.sh`    | (Optional) dedicated read-only endpoint. |
| `scripts/99_cleanup.sh`         | Tear the project down. |

---

## Prerequisites

- Databricks CLI ≥ 0.240, authenticated to the workshop workspace.
- `psql` (PostgreSQL 14+ client). `psql` is preferred so you don't contend with
  the browser-based SQL editor — though the editor in the Lakebase UI works too.
- The bootstrap has run, so `…shared_data.gold_customer_scorecard` exists.

---

## Walkthrough

### 1. Provision  (`scripts/00_provision.sh`)
Creates project `workshop-scorecard` with a `production` branch and a read/write
`primary` endpoint. **Gotcha:** a deleted name is reserved for a few minutes —
always use a fresh project name.

### 2. Get the data into Postgres

**Preferred — UC synced table (`synced_table/create_synced_table.sh`).** Creates a
managed synced table (`SNAPSHOT`, or `TRIGGERED`/`CONTINUOUS` with Change Data
Feed) that reverse-ETLs the gold table into the project's `databricks_postgres`
and keeps it fresh from the lakehouse. **This is the production reverse-ETL
pattern, and what each participant runs in the lab.** Tested on the build
workspace: **70 rows synced, queryable from Postgres.**

> **No CREATE CATALOG, no metastore admin.** The synced-table UC object lives in
> a *normal* UC catalog/schema you already have rights to; the Postgres target is
> selected via `spec.branch` + `spec.postgres_database`. There is **no** "register
> the Lakebase DB as a UC catalog" step (that was a provisioned-era dead end).
> Minimal per-participant grants: `USE CATALOG` + `USE SCHEMA` + `CREATE TABLE` on
> their UC schema, `SELECT` on the source, plus a Lakebase Postgres role on the
> project. Use the autoscale-native **`databricks postgres create-synced-table`**
> — *not* `databricks database create-synced-database-table` (provisioned-only;
> errors "Database instance is not found" against an autoscale project).
> Tip: `get-synced-table` needs the `synced_tables/<catalog.schema.table>` prefix.

**Works-everywhere alternative — loader (`scripts/02_load_scorecard.py`).** If you
want a no-pipeline path (or to script a custom transform on the way in), reads the
UC gold table and bulk-inserts it into `public.customer_scorecard` with a `customer_id`

**Works-everywhere — loader (`scripts/02_load_scorecard.py`).** Reads the UC gold
table and bulk-inserts it into `public.customer_scorecard` with a `customer_id`
primary key plus helper indexes. Pass the connection token via env vars (never
hard-code it). Tested: **70 rows loaded, 36 columns**.

### 3. Point lookups  (`sql/point_lookups.sql`)
```bash
source lakebase/scripts/01_connect.sh production
psql "$PGURI" -f lakebase/sql/point_lookups.sql
```
- **Point lookup by PK** (customer 42) returns one row.
- `EXPLAIN ANALYZE` (with `enable_seqscan=off`) shows
  `Index Scan using customer_scorecard_pkey … Execution Time: 0.02 ms`.
  *(At 70 rows the planner picks a seq scan by default — the whole table is one
  page — still sub-millisecond; the PK index is what keeps it O(log n) at scale.)*
- The partial index on `at_risk_flag` serves an instant churn worklist.

### 4. Branching  (`scripts/03_branch_demo.sh`)
Branch `dev-experiment` off production (copy-on-write — instant, 0 bytes). Tested:
the branch starts with all **70 rows**; after a `DELETE`/`UPDATE`/`INSERT` it has
**14 rows** with customer 42 renamed and a new customer 999 — while **production
is unchanged at 70 rows, customer 42 original, no customer 999**. Isolation proven.

### 5. Point-in-time restore  (`scripts/04_pitr_demo.sh`)
Capture `T0`, simulate an accidental `DELETE customer_id > 50` on production
(→ 50 rows), then branch from production **as of `T0`** using
`source_branch_time`. Tested: the recovery branch holds the full **70 rows**
(max_id 70) while production shows the post-delete **50** (max_id 50). No backups,
no downtime — you branch from the past.

### 6. (Optional) Read replica  (`scripts/05_read_replica.sh`)
Add a dedicated `ENDPOINT_TYPE_READ_ONLY` endpoint. Tested: reads return 70 rows
with `transaction_read_only = on`; writes are rejected with
`cannot execute UPDATE in a read-only transaction`.

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
psql "host=$HOST dbname=databricks_postgres user=<you>@company.com sslmode=require"
```
`scripts/01_connect.sh` wraps all of this — `source` it and use `$PGURI`.

---

## Optional features — what works

| Feature | Status | Notes |
|---------|--------|-------|
| Synced table (reverse ETL) | tested ✓ | `databricks postgres create-synced-table` → `databricks_postgres`; 70 rows ONLINE, queried from Postgres. **No** CREATE CATALOG / metastore admin. |
| Direct loader (job-based reverse ETL) | tested ✓ | 70 rows, point lookups confirmed. Alternative when you want a no-pipeline / custom-transform load. |
| Point lookups by `customer_id` | tested ✓ | PK index scan, ~0.02 ms. |
| Branching + isolation | tested ✓ | COW clone; parent untouched. |
| Point-in-time restore | tested ✓ | `source_branch_time`; recovered 70 vs 50. |
| Read replica | tested ✓ | Read-only endpoint; writes rejected. |
| Scale-to-zero | config shown, not observed | Controlled by `suspend_timeout_duration` (default `86400s` on a new branch endpoint; set lower to suspend sooner). Compute wakes on the next connection. Observing suspension needs idling past the timeout — impractical to watch live in the session. |
| Lakebase Data API (PostgREST/REST) | UI-enable only | Enable on the project's **Data API** page (creates the `authenticator` role + `pgrst` schema); no CLI/API to enable it. Then: `curl -H "Authorization: Bearer $TOKEN" "$REST_ENDPOINT/public/customer_scorecard?customer_id=eq.42"`. |
| CDC-to-Delta (Postgres→Delta) | Preview, not attempted | Lakebase Autoscaling currently does Delta→Postgres reverse ETL; Postgres→Delta is Preview. |

---

## Cleanup
```bash
PROJECT=workshop-scorecard bash lakebase/scripts/99_cleanup.sh
```

---

_Authored and tested on the build workspace on 2026-05-31: project
`workshop-scorecard`, Postgres 17.10, CLI 0.298, databricks-sdk 0.112. No customer
identifiers anywhere; the dataset is the fictional Northgate Provisions Co._
