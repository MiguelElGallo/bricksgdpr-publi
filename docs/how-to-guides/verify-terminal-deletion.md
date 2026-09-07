---
icon: lucide/clipboard-check
---

# Verify customer deletion

Use this checklist after changing the deletion control, adding a customer-dependent model, or
deploying the project.

## 1. Load and verify the target

```bash
set -a
source .env
set +a

uv run databricks auth describe --profile "$DATABRICKS_CONFIG_PROFILE"
uv run databricks current-user me --profile "$DATABRICKS_CONFIG_PROFILE"
```

Confirm the expected workspace, identity, catalog, and optional schema prefix before replacing
relations.

## 2. Build the canonical final state

```bash
uv run dbt run-operation bootstrap_project_catalog
uv run dbt build --select '*' --exclude tag:access_control
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
uv run dbt build --select '*'
```

!!! warning
    Full refresh cannot reset the three durable controls. Evidence is archived outside the model
    graph. Use the [operations workflow](../reference/deletion-operations.md) for tracked execution
    and recovery; the manual commands here verify the fixture without a shared execution ID.

## 3. Check the authorization states

```bash
uv run dbt show --inline "
select deletion_request_id, decision_revision_id, deletion_mode,
       deletion_policy_version, authorization_status
from {{ ref('customer_deletion_authorizations') }}
order by deletion_request_id
" --limit 10
```

Expected current state:

| Request | Status | Mode |
| --- | --- | --- |
| `CCHG-0095-D` | `PENDING` | null |
| `CCHG-0097-D` | `AUTHORIZED` | `SPECIAL_DELETION` |
| `CCHG-0099-D` | `AUTHORIZED` | `FULL_GOVERNED_OUTPUT_DELETION` |

The unconfirmed `0095` fixture must still exist in mapping, Layer2, and Layer3. Detection alone
must never delete it.

## 4. Check plan coverage

```bash
uv run dbt show --inline "
select deletion_mode, planned_action,
       count(distinct concat(target_layer, '.', target_relation)) as target_count,
       count(*) as plan_rows
from {{ ref('int_customer_deletion_plan') }}
group by deletion_mode, planned_action
order by deletion_mode, planned_action
" --limit 20
```

The fixed target inventory is:

| Mode | Action | Distinct targets |
| --- | --- | ---: |
| FULL | `DELETE_CURRENT_ROWS` | 13 |
| FULL | `EXCLUDE_DELETED_ROWS` | 4 |
| SPECIAL | `DELETE_CURRENT_ROWS` | 9 |
| SPECIAL | `REASSIGN_TO_ERASED_MEMBER` | 4 |
| SPECIAL | `EXCLUDE_ERASED_ROWS` | 4 |

The canonical fixture produces 102 plan rows across four authorized decision revisions and their
historical customer keys.

## 5. Check the terminal ledger

```bash
uv run dbt show --inline "
select decision_revision_id, deletion_request_id, deletion_mode,
       initial_decision_revision_id, initial_deletion_mode,
       deletion_policy_version, authorization_recorded_at,
       initial_authorization_recorded_at, mode_escalated_at
from {{ ref('int_terminal_deleted_customer_keys') }}
order by deletion_request_id, customer_key
" --limit 10
```

Expected:

- one SPECIAL key for `CCHG-0097-D`, with the later same-mode review effective and the first
  SPECIAL revision preserved as initial evidence;
- two FULL keys for `CCHG-0099-D`, both initially SPECIAL and both with escalation evidence;
- no key for `CCHG-0095-D`.

## 6. Check every Layer3 table

```bash
uv run dbt show --inline "
select 'dim_customer' as relation_name, count(*) as row_count from {{ ref('dim_customer') }}
union all select 'dim_service', count(*) from {{ ref('dim_service') }}
union all select 'dim_date', count(*) from {{ ref('dim_date') }}
union all select 'fct_customer_event', count(*) from {{ ref('fct_customer_event') }}
union all select 'fct_invoice', count(*) from {{ ref('fct_invoice') }}
order by relation_name
" --limit 10
```

Expected final totals are 16 customers, 18 services, 1,461 dates, 30 events, and 27 invoices.

Then inspect the three fixture outcomes:

```bash
uv run dbt show --inline "
select event_key as record_key, customer_key,
       cast(null as string) as service_key, is_erased_customer
from {{ ref('fct_customer_event') }}
where event_key in ('EVT-0095', 'EVT-0097', 'EVT-0099')
union all
select invoice_key, customer_key, service_key, is_erased_customer
from {{ ref('fct_invoice') }}
where invoice_key in ('INV-0095', 'INV-0097', 'INV-0099')
order by record_key
" --limit 10
```

- `0095` rows are present and ordinary;
- `0097` rows are present under `-99999` with the erased flag;
- `0099` rows are absent.

## 7. Run the executable controls

```bash
uv run dbt test --select tag:deletion_control
uv run dbt test --select assert_priva_map_contract
uv run dbt test --select assert_layer2_terminal_deletion
uv run dbt test --select assert_layer3_terminal_deletion
uv run dbt test --select test_type:unit
```

These tests cover fail-closed authorization, exact action inventory, ordinary/SPECIAL/FULL model
behavior, fact/quarantine partitions, same-mode evidence selection, mapping removal, erased-member
invariants, and Layer3 outcomes.

## 8. Adding another customer-dependent table

Before merging a new table:

1. Run the layer-specific generator with its kind, grain, source, explicit columns, and deletion
   specification. Use `generate_customer_deletion_scaffold` only when adding the deletion contract
   to an already-handwritten model. Set `deletion.register_target: true` when the generated
   physical model or CASE_VIEW must join the governed deletion inventory.
2. For `priva_map`, declare column tags and masks for every readable Personal Data column and keep
   the model materialized as a table or incremental relation.
3. Copy the generated SQL and schema YAML into the correct model directory.
4. If the operation logged a declarative registration, append it; do not hand-write action strings.
   Registration is valid only for a physical table/incremental model or CASE_VIEW.
5. Compile the pasted model and run its generated schema tests. The layer scaffold does not emit
   `customer_deletion_generated_contract`; add deletion-outcome and model-specific tests when the
   business logic requires them.
6. Update the fixed target counts and Layer3 walkthrough if the governed inventory changes.

Use the [Macro API reference](../reference/macro-api.md) for the scaffold command, generated
artifacts, and every public model-generation parameter.

## 9. Record the evidence boundary

Record the catalog, schema prefix, build run, decision revisions, policy version, ledger state, test
results, and operator identity. Describe FULL as deletion from governed current outputs and SPECIAL
as erased-member fact retention. Do not claim physical erasure or anonymisation without separate
source, Delta-retention, export, backup, recipient, and identifiability evidence.
