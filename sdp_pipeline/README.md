# sdp_pipeline/ - Practical 2: Spark Declarative Pipelines

In this practical you build a medallion pipeline **from scratch**, using **Genie Code** to
help you write it:

- **Bronze** - ingest the deliberately *dirty* raw JSON from the UC volume, as-is.
- **Silver** - clean, validate and de-duplicate with expectations: one normalised table per
  entity, no joins.
- **Gold** - join the silver tables and aggregate into business metrics.

There is **no starter file and no worked solution here on purpose** - the whole point is to
build it yourself by describing what you want to Genie Code.

See [`../data/README.md`](../data/README.md) for the data dictionary (schema, field meanings)
and the raw volume paths.
