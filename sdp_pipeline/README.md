# sdp_pipeline/

Practical 2 — **Spark Declarative Pipelines (SDP)**.

Participants build a medallion pipeline from scratch (with Genie Code assistance) that:

- **Bronze** — ingests the deliberately *dirty* raw JSON from the UC volume.
- **Silver** — cleans and validates with expectations (drops/quarantines the seeded
  data-quality issues documented in [`../data/README.md`](../data/README.md)).
- **Gold** — produces business metrics (revenue, profit, margin) as materialized views.

This folder holds the reference pipeline. The participant-facing version with TODO
sections is shared to a workspace folder by the bootstrap.

> _Placeholder — owned by the pipeline teammate (Task #4)._
