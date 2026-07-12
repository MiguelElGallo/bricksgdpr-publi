---
icon: lucide/clipboard-check
---

# Verify terminal deletion

Use this guide to prove that a source deletion is stored, independently confirmed, planned across
every governed relation, and removes original identity links only after authorization. Event and
invoice facts retain their grain under the erased member.

This verifies current-state identity unlinking in the demo. It does not prove anonymisation or
physical erasure from Delta history, caches, exports, object versions, or backups.

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
    before running it. It also rebuilds the demo request ledger from the current source fixture;
    production audit evidence must live in an append-only control system that a dbt full refresh
    cannot reset.

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
source control fixtures, confirmation gate, exact 17-target plan, accepted/quarantine partitions,
mapping exclusions, Layer2/Layer3 reassignment, and case-view exclusion.

## Inspect the control states

```bash
uv run dbt show --inline "
select
    deletion_request_id,
    decision_status,
    legal_hold,
    authorization_status
from {{ ref('customer_deletion_authorizations') }}
order by deletion_request_id
" --limit 10
```

The expected states are `CCHG-0097-D = PENDING` and `CCHG-0099-D = AUTHORIZED`.

Confirm that only the authorized request has plan rows:

```bash
uv run dbt show --inline "
select
    deletion_request_id,
    planned_action,
    count(distinct customer_key) as historical_key_count,
    count(distinct concat(target_layer, '.', target_relation)) as target_count,
    count(*) as plan_row_count
from {{ ref('int_customer_deletion_plan') }}
group by deletion_request_id, planned_action
" --limit 10
```

The rows for `CCHG-0099-D` total two historical keys, 17 targets, and 34 plan rows across delete,
reassign, and exclude actions. The pending request has no plan row and cannot enter the gate.

Confirm original modeled customer and service keys are replaced:

```bash
uv run dbt show --inline "
select 'event' as fact_name, event_key as record_key, customer_key,
    cast(null as string) as service_key, is_erased_customer
from {{ ref('fct_customer_event') }} where event_key = 'EVT-0099'
union all
select 'invoice', invoice_key, customer_key, service_key, is_erased_customer
from {{ ref('fct_invoice') }} where invoice_key = 'INV-0099'
" --limit 10
```

Both rows remain, use `customer_key = -99999`, and have `is_erased_customer = true`; the invoice's
service key is also `-99999`. Their source transaction IDs remain and can be re-linked through the
restricted source history in this demo, so these facts remain Personal Data.

## Verify the customer case view with an authorized session

In a separately authenticated `case_users` or `privacy_admins` SQL session, run this aggregate
query against the canonical demo catalog:

```sql
select
    count_if(customer_id = 'CUST-0097') as pending_customer_rows,
    count_if(customer_id = 'CUST-0099') as authorized_deleted_rows
from bricksgdpr.layer3_case.case_dim_customer
where customer_id in ('CUST-0097', 'CUST-0099');
```

The expected result is `pending_customer_rows = 1` and `authorized_deleted_rows = 0`. This proves
that confirmation, rather than mere detection, controls the authorized customer case view. It does
not independently inspect every case fact; the trusted owner-side model tests cover the underlying
Layer3 facts.

!!! warning "Current test limitation"
    Do not use an unaffiliated zero-row result as authorized evidence. The current
    `assert_case_views_terminal_deletion` singular test expands the internal pseudonymization UDF,
    but ordinary consumer personas correctly lose UDF `EXECUTE` after access reconciliation. The
    test therefore cannot provide independent persona proof in its current form and should be
    redesigned.

## Record the scope of the evidence

Record the catalog, schema prefix, build run, request and decision IDs, authorization timestamp,
plan target count, test results, and authorized identity used for the case-view assertion. Describe
the result as current-state identity unlinking with erased-member fact retention. Do not describe
the retained facts as anonymous without a separate identifiability assessment.

For production erasure claims, separately verify source purge, replay prevention, Delta retention,
caches, exports, backups, and disaster-recovery copies. Read
[Terminal deletion versus erasure](../explanation/terminal-deletion-vs-erasure.md) for the boundary.
