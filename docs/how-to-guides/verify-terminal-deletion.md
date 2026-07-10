---
icon: lucide/clipboard-check
---

# Verify terminal deletion

Use this guide to prove that the checked-in deletion fixtures are absent from every current
governed relation after a full replacement build.

This verifies logical current-state deletion in the demo. It does not prove physical erasure from
Delta history, caches, exports, object versions, or backups.

## Load the target

```bash
set -a
source .env
set +a
```

Confirm that the checked-in synthetic seeds have not been modified.

## Replace the current relations

```bash
uv run dbt build --full-refresh --exclude tag:access_control
```

!!! warning
    `--full-refresh` replaces current governed tables in `DBT_PROJECT_CATALOG`. Confirm the target
    before running it.

## Reconcile and verify access

```bash
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
```

This prevents a deletion check from being accepted against relations with a drifted access
contract.

## Run the deletion assertions

```bash
uv run dbt test --select tag:deletion_control
uv run dbt test --select assert_priva_map_contract
uv run dbt test --select assert_layer2_terminal_deletion
uv run dbt test --select assert_layer3_terminal_deletion
```

Every command should pass in the trusted deployment or owner session. Together they check the
source control fixtures, accepted/quarantine partitions, mapping exclusions, Layer2, and Layer3.

## Verify the customer case view with an authorized session

In a separately authenticated `case_users` or `privacy_admins` SQL session, run this aggregate
query against the canonical demo catalog:

```sql
select count(*) as deleted_customer_rows
from bricksgdpr.layer3_case.case_dim_customer
where customer_id in ('CUST-0097', 'CUST-0099');
```

The expected result is `0`. This proves the absence of the two terminal-deletion fixtures from the
authorized customer case view. It does not independently inspect every case fact; the trusted
owner-side model tests cover the underlying Layer3 facts.

!!! warning "Current test limitation"
    Do not use an unaffiliated zero-row result as authorized evidence. The current
    `assert_case_views_terminal_deletion` singular test expands the internal pseudonymization UDF,
    but ordinary consumer personas correctly lose UDF `EXECUTE` after access reconciliation. The
    test therefore cannot provide independent persona proof in its current form and should be
    redesigned.

## Record the scope of the evidence

Record the catalog, schema prefix, build run, test results, and authorized identity used for the
case-view assertion. Describe the result as current-state logical deletion.

For production erasure claims, separately verify source purge, replay prevention, Delta retention,
caches, exports, backups, and disaster-recovery copies. Read
[Terminal deletion versus erasure](../explanation/terminal-deletion-vs-erasure.md) for the boundary.
