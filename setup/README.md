# setup/

One-action bootstrap for the workshop environment.

The facilitator imports the repo and runs **`00_bootstrap`** (Run all). It is
idempotent and safe to re-run. It:

1. (Documented, optional) creates a fresh catalog for a customer workspace.
2. Creates the `shared_data` schema and a UC volume.
3. Copies the committed raw JSON from the imported repo path into the UC volume —
   **no manual upload**.
4. Builds the CLEAN shared tables (`customers`, `products`, `orders`) and summary tables.
5. Builds the heavy-OLAP `gold_customer_scorecard` (point-lookup keyed by `customer_id`).
6. Creates per-user schemas and grants for the participant group.

Thin per-step scripts live alongside the bootstrap for transparency.

> _Owned by the `data` teammate (Task #3). Lakebase provisioning + sync of the scorecard
> is handled separately by the `lakebase` teammate._
