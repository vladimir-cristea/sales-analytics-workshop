# lakebase/

Practical 3 — **Lakebase**.

Provisions a Lakebase (managed Postgres) instance, syncs the heavy-OLAP
`gold_customer_scorecard` table from Unity Catalog for low-latency point lookups, and
explores branching, point-in-time recovery (PITR), and the Data API.

The bootstrap guarantees `gold_customer_scorecard` exists in UC; provisioning and sync
are handled here.

> _Placeholder — owned by the lakebase teammate (Task #6)._
