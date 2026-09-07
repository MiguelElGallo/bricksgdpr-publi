---
title: "Customer deletion: before and after"
icon: lucide/trash-2
---

# Customer deletion: before and after

This tutorial builds the real Layer3 tables in three states and shows the exact difference between
the two deletion modes.

- `CUST-0095` has a source tombstone but no decision. It must remain everywhere.
- `CUST-0097` is authorized for `SPECIAL_DELETION`. Its dimensions disappear; its facts remain
  under `-99999`.
- `CUST-0099` starts as SPECIAL and then escalates to
  `FULL_GOVERNED_OUTPUT_DELETION`. All of its governed Layer3 rows disappear.

## The result at a glance

| Layer3 table | Before any decision | After SPECIAL for `0099` | Final mixed modes | Final meaning |
| --- | ---: | ---: | ---: | --- |
| `dim_customer` | 18 | 17 | 16 | Real rows for `0097` and `0099` are gone; shared erased member remains |
| `dim_service` | 20 | 19 | 18 | Their real services are gone; shared erased service remains |
| `dim_date` | 1,461 | 1,461 | 1,461 | No customer dependency |
| `fct_customer_event` | 31 | 31 | 30 | `EVT-0097` remains under `-99999`; `EVT-0099` is gone |
| `fct_invoice` | 28 | 28 | 27 | `INV-0097` remains under `-99999`; `INV-0099` is gone |

“Final mixed modes” means SPECIAL for `CUST-0097` and FULL for `CUST-0099`. The unconfirmed
`CUST-0095`, `SVC-0095-A`, `EVT-0095`, and `INV-0095` remain ordinary linked rows throughout.

!!! warning "Governed current outputs, not every physical copy"
    FULL rebuilds all 17 governed outputs without the subject's rows. It does not prove removal
    from source history, Delta history, caches, exports, backups, or recipients.

## Understand the source and decisions

| Customer | Source request | Dependent fixture | Decision history |
| --- | --- | --- | --- |
| `CUST-0095` | `CCHG-0095-D` | `SVC-0095-A`, `EVT-0095`, `INV-0095` | None |
| `CUST-0097` | `CCHG-0097-D` | `SVC-0097-A`, `EVT-0097`, `INV-0097` | SPECIAL at `2026-02-21`; same-mode review at `2026-02-23` |
| `CUST-0099` | `CCHG-0099-D` | `SVC-0099-A`, `EVT-0099`, `INV-0099` | SPECIAL at `2026-02-16`; FULL at `2026-02-25` |

`CUST-0099` has two historical SSNs. The plan expands the stable customer ID to both keys, so a
change of identifier cannot evade deletion.

## Build state 1: detected but not authorized

Use a new, previously unused prefix for each walkthrough. The cutoff is one second before the
first decision. Reusing a prefix preserves its terminal controls even with full refresh.

```bash
export DBT_SCHEMA_PREFIX="deletion_walkthrough_$(date +%Y%m%d%H%M%S)"
uv run dbt run-operation bootstrap_project_catalog

uv run dbt seed --full-refresh \
  --vars '{deletion_decision_as_of: "2026-02-16 07:59:59"}'
uv run dbt run --full-refresh \
  --vars '{deletion_decision_as_of: "2026-02-16 07:59:59"}'
uv run dbt test --select assert_layer3_deletion_walkthrough_fixture \
  --vars '{deletion_decision_as_of: "2026-02-16 07:59:59"}'
```

The source requests are detected, but no key is in the terminal ledger. All active dependent rows
remain.

### All five Layer3 tables before deletion

| Table | Grain | Total | `CUST-0097` rows | `CUST-0099` rows | Erased member/facts |
| --- | --- | ---: | ---: | ---: | ---: |
| `dim_customer` | customer key | 18 | 1 | 1 | 1 special dimension row |
| `dim_service` | service-version key | 20 | 1 | 1 | 1 special dimension row |
| `dim_date` | calendar date | 1,461 | 0 | 0 | Not applicable |
| `fct_customer_event` | event ID | 31 | 1 | 1 | 0 erased facts |
| `fct_invoice` | invoice ID | 28 | 1 | 1 | 0 erased facts |

The permanent special dimension members exist before they are used. This prevents null foreign
keys later; they do not represent a real customer or service.

#### `dim_customer` before

Each subject has a real pseudonymous row. `CUST-0099` looks like this:

| Column | Before value |
| --- | --- |
| `customer_key` | `<v1 key for historical customer SSN>` |
| `customer_pk_key`, `customer_id_key` | `<domain-separated v1 keys>` |
| name, email, phone, birth-date, address keys | `<domain-separated v1 keys>` |
| `customer_segment` | `household` |
| `is_active` | `true` |

The shared special row has every identity key equal to `-99999`, segment `ERASED_SUBJECT`, and
`is_active = false`.

#### `dim_service` before

| Column | `SVC-0099-A` before value |
| --- | --- |
| `customer_key` | `<real CUST-0099 key>` |
| `service_key` | `<v1 key for SVC-0099-A>` |
| `service_version_key` | `<v1 key for service + valid_from>` |
| `installation_address_key` | `<v1 address key>` |
| `service_type` | `INTERNET` |
| `is_valid` | `true` |

The shared erased service row uses `-99999` for customer, service, version, and address keys.

#### `dim_date` before

`dim_date` contains one row per date from `2025-01-01` through `2028-12-31`. It contains no
customer key, so neither deletion mode changes it.

#### `fct_customer_event` before

| Column | `EVT-0099` before value |
| --- | --- |
| `event_key` | `EVT-0099` |
| `customer_key` | `<real CUST-0099 key>` |
| `event_date_key` | `20260220` |
| `event_type` | `USAGE` |
| `measure_value`, `measure_unit` | `9.50`, `GB` |
| `is_erased_customer` | `false` |

#### `fct_invoice` before

| Column | `INV-0099` before value |
| --- | --- |
| `invoice_key` | `INV-0099` |
| customer/service/version keys | `<real pseudonymous keys>` |
| `issue_date_key`, `due_date_key` | `20260201`, `20260303` |
| `amount`, `currency_code` | `99.00`, `EUR` |
| `is_erased_customer` | `false` |

## Build state 2: SPECIAL deletion

Expose only the first `CUST-0099` decision and run incrementally.

```bash
uv run dbt run \
  --vars '{deletion_decision_as_of: "2026-02-20 23:59:59"}'
uv run dbt test --select assert_layer3_deletion_walkthrough_fixture \
  --vars '{deletion_decision_as_of: "2026-02-20 23:59:59"}'
```

The plan contains 34 rows for `CUST-0099`: two historical keys times 17 targets. The ledger holds
both keys in `SPECIAL_DELETION`.

### Layer3 after SPECIAL

| Table | What changed for `CUST-0099` | Total |
| --- | --- | ---: |
| `dim_customer` | Real customer row deleted | 17 |
| `dim_service` | Real service row deleted | 19 |
| `dim_date` | Nothing | 1,461 |
| `fct_customer_event` | `EVT-0099` retained; `customer_key = -99999` | 31 |
| `fct_invoice` | `INV-0099` retained; customer/service/version keys = `-99999` | 28 |

The retained fact rows set `is_erased_customer = true`. They are excluded from every case view.
Their transaction IDs and other attributes still exist, so the documentation continues to call
them Personal Data rather than anonymous data.

## Exercise same-mode revision handling

First admit `CUST-0097` under its initial SPECIAL revision:

```bash
uv run dbt run \
  --vars '{deletion_decision_as_of: "2026-02-21 23:59:59"}'
```

Then expose the later SPECIAL review:

```bash
uv run dbt run \
  --vars '{deletion_decision_as_of: "2026-02-23 23:59:59"}'

uv run dbt show --inline "
select decision_revision_id, initial_decision_revision_id,
       deletion_mode, deletion_policy_version,
       authorization_recorded_at, initial_authorization_recorded_at
from {{ ref('int_terminal_deleted_customer_keys') }}
where deletion_request_id = 'CCHG-0097-D'
" --limit 10
```

Expected effective evidence:

| Field | Value |
| --- | --- |
| `decision_revision_id` | `DEC-0097-SPECIAL-REVIEW` |
| `initial_decision_revision_id` | `DEC-0097-SPECIAL` |
| `deletion_mode` | `SPECIAL_DELETION` |
| effective `authorization_recorded_at` | `2026-02-23 08:00:00` |
| initial `authorization_recorded_at` | `2026-02-21 08:00:00` |

The effective review advances; first-admission evidence remains unchanged.

## Build state 3: final mixed modes

Expose the FULL escalation for `CUST-0099`:

```bash
uv run dbt run \
  --vars '{deletion_decision_as_of: "9999-12-31 23:59:59"}'
uv run dbt test --select tag:deletion_control
```

The final ledger contains three historical keys:

| Customer | Key count | Initial mode | Effective mode |
| --- | ---: | --- | --- |
| `CUST-0097` | 1 | SPECIAL | SPECIAL |
| `CUST-0099` | 2 | SPECIAL | FULL |

### All five Layer3 tables after final execution

| Table | Final total | `CUST-0097` original rows | `CUST-0097` erased facts | `CUST-0099` rows |
| --- | ---: | ---: | ---: | ---: |
| `dim_customer` | 16 | 0 | Special dimension is shared | 0 |
| `dim_service` | 18 | 0 | Special dimension is shared | 0 |
| `dim_date` | 1,461 | 0 | Not applicable | 0 |
| `fct_customer_event` | 30 | 0 | 1 (`EVT-0097`) | 0 |
| `fct_invoice` | 27 | 0 | 1 (`INV-0097`) | 0 |

#### `dim_customer` after

Neither subject has a real row. The single `-99999` `ERASED_SUBJECT` member remains for SPECIAL
facts. It has no readable `priva_map` entry.

#### `dim_service` after

Neither real service remains. The single `-99999` erased service member remains so
`INV-0097` preserves referential integrity.

#### `dim_date` after

Still 1,461 rows, unchanged.

#### `fct_customer_event` after

| Fixture | Result |
| --- | --- |
| `EVT-0095` | Present with its ordinary customer key (`PENDING` request) |
| `EVT-0097` | Present with `customer_key = -99999`, `is_erased_customer = true` |
| `EVT-0099` | Absent (`FULL_GOVERNED_OUTPUT_DELETION`) |

#### `fct_invoice` after

| Fixture | Result |
| --- | --- |
| `INV-0095` | Present with ordinary customer/service keys |
| `INV-0097` | Present with customer/service/version keys `-99999`, erased flag true |
| `INV-0099` | Absent |

## Prove FULL cannot downgrade

Move the cutoff backward after FULL has been admitted, but use an ordinary incremental run:

```bash
uv run dbt run \
  --vars '{deletion_decision_as_of: "2026-02-20 23:59:59"}'

uv run dbt show --inline "
select deletion_mode, initial_deletion_mode, mode_escalated_at
from {{ ref('int_terminal_deleted_customer_keys') }}
where deletion_request_id = 'CCHG-0099-D'
order by customer_key
" --limit 10

uv run dbt test --select assert_layer3_deletion_walkthrough_fixture \
  --vars '{deletion_decision_as_of: "2026-02-20 23:59:59"}'
```

Both keys remain FULL, their initial mode remains SPECIAL, and the final Layer3 totals do not
revert. The three durable controls also resist `--full-refresh`. Start a fresh walkthrough in a new
isolated prefix; never delete ledger rows to reset a retained identity. See
[Deletion operations and recovery](../reference/deletion-operations.md).

## Query the summary yourself

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

You have now observed detection without authorization, SPECIAL fact retention, same-mode evidence
advancement, FULL escalation, and downgrade protection. The exact control and macro parameters are
in [Customer deletion control](../reference/deletion-control.md).

## Reset subsequent shell targeting

```bash
unset DBT_SCHEMA_PREFIX
```

This prevents later dbt commands in the same shell from silently targeting the walkthrough
schemas. It does not drop the prefixed schemas or their relations.
