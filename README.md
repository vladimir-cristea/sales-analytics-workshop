# Sales Analytics Workshop

A hands-on Databricks workshop built around **Northgate Provisions Co.**, a fictional
B2B food & beverage wholesaler. Designed for software engineers who are new to
Databricks, it walks through three practicals on a single shared dataset:

1. **Genie** — ask business questions of curated tables in natural language.
2. **Spark Declarative Pipelines (SDP)** — build a medallion pipeline from scratch
   (with Genie Code assistance) that ingests deliberately *dirty* raw JSON, cleans and
   validates it, and produces gold business metrics.
3. **Lakebase** — serve a pre-computed analytics scorecard from Postgres for low-latency
   point lookups, and explore branching / PITR / the Data API.

The repository is branding-neutral and reusable: no customer name appears anywhere in it.

---

## One-action setup (for the workshop facilitator)

The whole environment is provisioned by importing this repo and running a single
bootstrap notebook — **no manual data upload**. The committed raw JSON files are copied
from the imported repo path straight into a Unity Catalog volume by the bootstrap itself.

1. **Create the participant group first.** Go to *Settings → Identity and Access →
   Groups*, create a group named **`workshop_participants`**, and add every attendee's
   email to it. _(This is the only manual prerequisite — do it before running the
   bootstrap so the access grants apply. If you forget, the bootstrap still completes and
   just skips the group grants; create the group and re-run to apply them.)_
2. **Import this repo** into the Databricks workspace
   (*Workspace → Create → Git folder →* paste the repo URL).
3. **Open `setup/00_bootstrap`** and click **Run all**.
4. Done. The bootstrap is idempotent — safe to re-run.

The bootstrap creates the schema and UC volume, lands the raw JSON, builds the clean
shared tables, builds the heavy-OLAP `gold_customer_scorecard` and the governed
`sales_metrics` metric view, creates a scratch schema per participant, and grants the
group read access to it all. See [`setup/README.md`](setup/README.md) for details and the
documented catalog-creation cell for a customer's own workspace.

---

## Prerequisites

- A Databricks workspace with **Unity Catalog** and **serverless** compute enabled.
- A **SQL warehouse** (serverless). Grant `CAN USE` to the participant group.
- A **participant group** named **`workshop_participants`** containing all attendee
  emails (*Settings → Identity and Access → Groups*). **This is the only manual setup
  step** — create it before running the bootstrap (see step 1 above).
- Permission to create a catalog (or an existing catalog you can build into). On the
  build workspace we use `vcr_serverless_catalog`; the bootstrap has a documented cell
  for creating a fresh catalog on the customer's workspace.

---

## Repository layout

| Path             | Contents                                                                 |
|------------------|--------------------------------------------------------------------------|
| `setup/`         | Idempotent bootstrap notebook + thin per-step scripts (schema, volume, tables, scorecard, `sales_metrics` metric view, grants). |
| `data/`          | Deterministic dataset generator + committed CLEAN and RAW DIRTY JSON, plus the data dictionary and seeded DQ-issue list. |
| `sdp_pipeline/`  | Reference Spark Declarative Pipeline (bronze → silver → gold) for practical 2. |
| `lakebase/`      | Lakebase provisioning, sync of `gold_customer_scorecard`, and branch/PITR/Data API exercises. |
| `genie/`         | Genie space definition, instructions, and example questions for practical 1. |
| `slides/`        | Workshop slides / exercise walkthrough content.                          |

---

## Agenda mapping

> _Placeholder — to be finalised by the content team._

| Time slot      | Session                              | Materials            |
|----------------|--------------------------------------|----------------------|
| _TBD_          | Welcome & platform overview          | `slides/`            |
| _TBD_          | **Practical 1 — Genie**              | `genie/`             |
| _TBD_          | **Practical 2 — Spark Declarative Pipelines** | `sdp_pipeline/`, `data/` |
| _TBD_          | **Practical 3 — Lakebase**           | `lakebase/`          |
| _TBD_          | Wrap-up & Q&A                        | `slides/`            |

---

## The dataset — Northgate Provisions Co.

A B2B food & beverage wholesaler serving outlets across the UK. Three core entities:

- **customers** — the outlets Northgate supplies (region, segment, account manager).
- **products** — the SKUs in the catalogue (category, list price, cost).
- **orders** — order lines (quantity, unit price, discount, currency).

Full schema and the precise list of seeded data-quality issues live in
[`data/README.md`](data/README.md).

---

## Cleanup

```sql
-- Drops everything the workshop created in the build catalog.
-- (Adjust the catalog name for your environment.)
DROP SCHEMA IF EXISTS vcr_serverless_catalog.shared_data CASCADE;
```
