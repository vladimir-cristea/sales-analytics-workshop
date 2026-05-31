# sdp_pipeline/

Practical 2 — **Spark Declarative Pipelines (SDP)**.

Participants build a medallion pipeline from scratch (with Genie Code assistance) that:

- **Bronze** — ingests the deliberately *dirty* raw JSON from the UC volume.
- **Silver** — cleans and validates with expectations (drops/quarantines the seeded
  data-quality issues documented in [`../data/README.md`](../data/README.md)).
- **Gold** — produces business metrics (revenue, profit, margin) as materialized views.

Participants build their pipeline **from scratch** with Genie Code — there is no starter
file to hand out. They work from the brief in the slides and the data dictionary in
[`../data/README.md`](../data/README.md).

## `reference_solution/` — facilitator answer key

[`reference_solution/`](reference_solution/) holds the complete, verified reference
pipeline (three SQL files: `bronze.sql`, `silver.sql`, `gold.sql`) plus a README with the
exact table definitions, the silver/gold split, run instructions, and the validated row
counts. It is the facilitator's answer key for validating participant output — **not** a
participant handout. See [`reference_solution/README.md`](reference_solution/README.md).

Design in one line: **bronze** streaming tables ingest the dirty JSON (Auto Loader, no
cleaning) → **silver** cleans/validates/de-duplicates with expectations, one normalised
table per entity, no joins → **gold** materialized views join the silver tables and
aggregate into four business tables. Output lands in its own `pipeline_ref` schema.
