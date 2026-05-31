# sdp_pipeline/ - Practical 2: Spark Declarative Pipelines

In this practical you build a medallion pipeline **from scratch**, using **Genie Code** to
help you write it:

- **Bronze** - ingest the deliberately *dirty* raw JSON from the UC volume, as-is.
- **Silver** - clean, validate and de-duplicate with expectations: one normalised table per
  entity, no joins.
- **Gold** - join the silver tables and aggregate into business metrics.

There is **no starter file and no worked solution here on purpose** - the whole point is to
build it yourself by describing what you want to Genie Code.

The exercise instructions live in the facilitator's slide deck. Lean on the data dictionary
in [`../data/README.md`](../data/README.md) for the schema and the exact data-quality rules
your silver layer should enforce.
