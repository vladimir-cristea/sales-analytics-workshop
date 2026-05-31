# Sales Analytics Workshop

A hands-on Databricks workshop built around **Northgate Provisions Co.**, a fictional
B2B food & beverage wholesaler. Designed for software engineers who are new to
Databricks, it walks through three practicals on a single shared dataset:

1. **Genie** - ask business questions of curated tables in natural language.
2. **Spark Declarative Pipelines (SDP)** - build a medallion pipeline from scratch
   (with Genie Code assistance) that ingests deliberately *dirty* raw JSON, cleans and
   validates it, and produces gold business metrics.
3. **Lakebase** - serve a pre-computed analytics scorecard from Postgres for low-latency
   point lookups, and explore branching / PITR / the Data API.

---

## One-action setup (for the workshop facilitator)

The whole environment is provisioned by importing this repo and running a single
bootstrap notebook - **no manual data upload**. The committed raw JSON files are copied
from the imported repo path straight into a Unity Catalog volume by the bootstrap itself.

1. **Create the participant group first.** Go to *Settings → Identity and Access →
   Groups*, create a group named **`workshop_participants`**, and add every attendee's
   email to it. _(This is the only manual prerequisite - do it before running the
   bootstrap so the access grants apply. If you forget, the bootstrap still completes and
   just skips the group grants; create the group and re-run to apply them.)_
2. **Import this repo** into the Databricks workspace
   (*Workspace → Create → Git folder →* paste the repo URL).
3. **Open `setup/00_bootstrap`** and click **Run all**.
4. Done. The bootstrap is idempotent - safe to re-run.

The bootstrap creates the schema and UC volume, lands the raw JSON, builds the clean
shared tables, builds the heavy-OLAP `gold_customer_scorecard` and the governed
`sales_metrics` metric view, creates a scratch schema per participant, and grants the
group read access to it all. See [`setup/README.md`](setup/README.md) for details and the
documented catalog-creation cell for your own workspace.

---

## Prerequisites

- A Databricks workspace with **Unity Catalog** and **serverless** compute enabled.
- A **SQL warehouse** (serverless). Grant `CAN USE` to the participant group.
- A **participant group** named **`workshop_participants`** containing all attendee
  emails (*Settings → Identity and Access → Groups*). **This is the only manual setup
  step** - create it before running the bootstrap (see step 1 above).
- Permission to create a catalog (or an existing catalog you can build into). The scripts
  default to the example catalog `workshop`; change it to your own. The
  bootstrap has a documented cell for creating a fresh catalog if you need one.

**What each participant needs:** a Databricks account that is a member of the
`workshop_participants` group, and a modern web browser. That's it - no local install,
nothing to download, nothing to bring. There is zero per-participant setup.

---

## Repository layout

| Path             | Contents                                                                 |
|------------------|--------------------------------------------------------------------------|
| `setup/`         | Idempotent bootstrap notebook + thin per-step scripts (schema, volume, tables, scorecard, `sales_metrics` metric view, grants). |
| `data/`          | Deterministic dataset generator + committed CLEAN and RAW DIRTY JSON, plus the data dictionary and seeded DQ-issue list. |
| `sdp_pipeline/`  | Practical 2 brief: build the medallion pipeline (bronze → silver → gold) yourself with Genie Code. |
| `lakebase/`      | Lakebase provisioning, sync of `gold_customer_scorecard`, and branch/PITR/Data API exercises. |
| `genie/`         | Genie space definition, instructions, and example questions for practical 1. |
| `slides/`        | Workshop slides / exercise walkthrough content.                          |

---

## Agenda

A suggested half-day shape. **Example timings - adjust to your event** (length, breaks,
and depth are all flexible).

| Duration | Session                                          | Materials                |
|----------|--------------------------------------------------|--------------------------|
| 30 min   | Welcome & platform overview                      | `slides/`                |
| 60 min   | **Practical 1 - Genie & AI/BI**                  | `genie/`                 |
| 15 min   | Break                                            | -                        |
| 75 min   | **Practical 2 - Spark Declarative Pipelines (with Genie Code)** | `sdp_pipeline/`, `data/` |
| 15 min   | Break                                            | -                        |
| 60 min   | **Practical 3 - Lakebase**                       | `lakebase/`              |
| 15 min   | Wrap-up & Q&A                                    | `slides/`                |

_Total ≈ 4½ hours including two breaks. Trim a practical or shorten the overview for a
shorter session; extend the hands-on time if you have a full day._

---

## The dataset - Northgate Provisions Co.

A B2B food & beverage wholesaler serving outlets across the UK. Three core entities:

- **customers** - the outlets Northgate supplies (region, segment, account manager).
- **products** - the SKUs in the catalogue (category, list price, cost).
- **orders** - order lines (quantity, unit price, discount, currency).

Full schema and the precise list of seeded data-quality issues live in
[`data/README.md`](data/README.md).

---

## Cleanup

```sql
-- Drops everything the workshop created. (Adjust the catalog name for your environment.)
DROP SCHEMA IF EXISTS workshop.shared_data CASCADE;
```
