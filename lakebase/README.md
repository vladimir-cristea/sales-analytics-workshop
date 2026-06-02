# lakebase/ - facilitator infra for the Lakebase practical

The Lakebase practical is built entirely by participants in the UI: each person creates their
own branch, syncs the gold table into it, queries it with point lookups, and tries point-in-time
restore. Nothing in that practical is run from this repo.

This folder is the **facilitator infra** behind it: provisioning the Lakebase project and granting
the participant group what it needs. `setup/00_bootstrap` already does all of this for you (its
`provision_lakebase` step, on by default), and it builds the source `gold_customer_scorecard`
table in Unity Catalog, so normally you run nothing here. The scripts below are the standalone
CLI equivalents, plus teardown.

## Files

| File | Purpose |
|------|---------|
| `scripts/00_provision.sh` | Provision the Lakebase Autoscaling project (CLI equivalent of the bootstrap's `provision_lakebase` step). |
| `synced_table/facilitator_grants.sh` | Grant the `workshop_participants` group the branch-and-sync permission set (CLI equivalent of the bootstrap's Lakebase grants). |
| `scripts/99_cleanup.sh` | Tear the project down after the session. |

## What the participant group is granted (and why)

Verified end-to-end as a non-admin: with exactly these grants a member of `workshop_participants`
can create their own branch, sync the gold table into it, and read it from Postgres, with no
workspace-admin or metastore-admin rights.

- **Lakebase:**
  - One group Postgres role on the `production` branch, `identity_type=GROUP`, created with
    `databricks postgres create-role` (never raw SQL `CREATE ROLE`, which leaves the role
    `NO_LOGIN` so OAuth fails). Copy-on-write branches inherit it.
  - **`CAN_MANAGE` on the project.** Branch *creation* needs `CAN_MANAGE`; `CAN_USE` only lets a
    member connect to existing branches.
- **Unity Catalog (granted by `setup/00_bootstrap`):**
  - `USE CATALOG` on the catalog; `USE SCHEMA` + `SELECT` on `shared_data` (to read the source
    gold table); `USE SCHEMA` + `CREATE TABLE` on each participant's own `ws_<user>` schema
    (where the synced-table UC object lands).

`workshop_participants` must be an **account-level** group (UC resolves grant principals at the
account level; a workspace-local group fails with "Could not find principal").

## Teardown

```bash
PROJECT=workshop-scorecard bash lakebase/scripts/99_cleanup.sh
```
